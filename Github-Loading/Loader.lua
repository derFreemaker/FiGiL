-- //TODO: hold up-to-date
local LoaderFiles = {
    "Github-Loading",
    {
        "Loader",
        { "10_Entities.lua" },
        { "10_Event.lua" },
        { "10_Module.lua" },
        { "10_Object.lua" },
        { "10_Option.lua" },
        { "20_Package.lua" },
        { "20_Utils.lua" },
        { "30_Listener.lua" },
        { "30_Logger.lua" },
        { "70_PackageLoader.lua" },
    },
    { "Version.latest.json" },
    { "100_Options.lua" },
}


---@param url string
---@param path string
---@param forceDownload boolean
---@param internetCard FicsIt_Networks.Components.FINComputerMod.InternetCard_C
---@return boolean
local function internalDownload(url, path, forceDownload, internetCard)
    if forceDownload == nil then forceDownload = false end
    if filesystem.exists(path) and not forceDownload then
        return true
    end
    local req = internetCard:request(url, "GET", "")
    local code, data = req:await()
    if code ~= 200 or data == nil then return false end
    local file = filesystem.open(path, "w")
    if file == nil then
        return false
    end
    file:write(data)
    file:close()
    return true
end


---@class Github_Loading.FilesTreeTools
local FileTreeTools = {}

---@private
---@param parentPath string
---@param entry table | string
---@param fileFunc fun(path: string) : boolean
---@param folderFunc fun(path: string) : boolean
---@return boolean
function FileTreeTools:doEntry(parentPath, entry, fileFunc, folderFunc)
    if #entry == 1 then
        ---@cast entry string
        return self:doFile(parentPath, entry, fileFunc)
    else
        ---@cast entry table
        return self:doFolder(parentPath, entry, fileFunc, folderFunc)
    end
end

---@private
---@param parentPath string
---@param file string
---@param func fun(path: string) : boolean
---@return boolean
function FileTreeTools:doFile(parentPath, file, func)
    local path = filesystem.path(parentPath, file[1])
    return func(path)
end

---@param parentPath string
---@param folder table
---@param fileFunc fun(path: string) : boolean
---@param folderFunc fun(path: string) : boolean
---@return boolean
function FileTreeTools:doFolder(parentPath, folder, fileFunc, folderFunc)
    local path = filesystem.path(parentPath, folder[1])
    if not folderFunc(path) then
        return false
    end
    for index, child in pairs(folder) do
        if index ~= 1 then
            local success = self:doEntry(path, child, fileFunc, folderFunc)
            if not success then
                return false
            end
        end
    end
    return true
end


---@param loaderBaseUrl string
---@param loaderBasePath string
---@param forceDownload boolean
---@param internetCard FicsIt_Networks.Components.FINComputerMod.InternetCard_C
---@return boolean
local function downloadFiles(loaderBaseUrl, loaderBasePath, forceDownload, internetCard)
    ---@param path string
    ---@return boolean success
    local function downloadFile(path)
        local url = loaderBaseUrl .. path
        path = loaderBasePath .. path
        assert(internalDownload(url, path, forceDownload, internetCard), "Unable to download file: '".. path .."'")
        return true
    end

    ---@param path string
    ---@return boolean success
    local function createFolder(path)
        if not filesystem.exists(loaderBasePath .. path) then
            return filesystem.createDir(loaderBasePath .. path)
        end
        return true
    end

    return FileTreeTools:doFolder("/", LoaderFiles, downloadFile, createFolder)
end


---@param loaderBasePath string
---@return Dictionary<string, any> loadedLoaderFiles
local function loadFiles(loaderBasePath)
    ---@type string[][]
    local loadEntries = {}
    ---@type integer[]
    local loadOrder = {}
    ---@type Dictionary<string, any>
    local loadedLoaderFiles = {}

    ---@param path string
    ---@return boolean success
    local function retrivePath(path)
        local fileName = filesystem.path(4, path)
        local num = fileName:match("^(%d+)_.+$")
        if num then
            num = tonumber(num)
            ---@cast num integer
            local entries = loadEntries[num]
            if not entries then
                entries = {}
                loadEntries[num] = entries
                table.insert(loadOrder, num)
            end
            table.insert(entries, path)
        else
            local file = filesystem.open(loaderBasePath .. path, "r")
            local str = ""
            while true do
                local buf = file:read(8192)
                if not buf then
                    break
                end
                str = str .. buf
            end
            loadedLoaderFiles[path] = { str }
            file:close()
        end
        return true
    end

    assert(FileTreeTools:doFolder("/", LoaderFiles, retrivePath, function() return true end),
            "Unable to load loader Files")

    table.sort(loadOrder)
    for _, num in ipairs(loadOrder) do
        for _, path in pairs(loadEntries[num]) do
            local loadedFile = table.pack(filesystem.loadFile(loaderBasePath .. path)(loadedLoaderFiles))
            loadedLoaderFiles[path] = loadedFile
        end
    end

    return loadedLoaderFiles
end


---@class Github_Loading.Loader
---@field private loaderBaseUrl string
---@field private loaderBasePath string
---@field private forceDownload boolean
---@field private internetCard FicsIt_Networks.Components.FINComputerMod.InternetCard_C
---@field private loadedLoaderFiles Dictionary<string, any>
---@field Logger Github_Loading.Logger
local Loader = {}

---@param loaderBaseUrl string
---@param loaderBasePath string
---@param forceDownload boolean
---@param internetCard FicsIt_Networks.Components.FINComputerMod.InternetCard_C
---@return Github_Loading.Loader
function Loader.new(loaderBaseUrl, loaderBasePath, forceDownload, internetCard)
    local loader = Loader
    loader.__index = loader
    return setmetatable({
        loaderBaseUrl = loaderBaseUrl,
        loaderBasePath = loaderBasePath,
        forceDownload = forceDownload,
        internetCard = internetCard,
        loadedLoaderFiles = {}
    }, loader)
end


function Loader:Download()
    assert(downloadFiles(self.loaderBaseUrl, self.loaderBasePath, self.forceDownload, self.internetCard),
        "Unable to download loader Files")
end



function Loader:LoadFiles()
    self.loadedLoaderFiles = loadFiles(self.loaderBasePath)
end


---@param moduleToGet string
---@return any ...
function Loader:Get(moduleToGet)
    local module = self.loadedLoaderFiles[moduleToGet]
    if not module then
        return
    end
    return table.unpack(module)
end


---@private
---@param logLevel Github_Loading.Logger.LogLevel
function Loader:setupLogger(logLevel)
    local function log(message)
        print(message)
        Utils.File.Write("/Logs/main.log", "+a", message .. "\n", true)
    end
    local function clear()
        Utils.File.Clear("/Logs/main.log")
    end

    ---@type Github_Loading.Listener
    local Listener = self:Get("/Github-Loading/Loader/30_Listener.lua")
    ---@type Github_Loading.Logger
    local Logger = self:Get("/Github-Loading/Loader/30_Logger.lua")
    self.Logger = Logger.new("Github Loader", logLevel)
    self.Logger.OnLog:AddListener(Listener.new(log))
    self.Logger.OnClear:AddListener(Listener.new(clear))
    self.Logger:setErrorLogger()
    self.Logger:Clear()
    self.Logger:LogDebug("###### LOG START ######")
end


---@param logLevel Github_Loading.Logger.LogLevel
function Loader:Load(logLevel)
    self:LoadFiles()

    ---@type Utils
    Utils = self:Get("/Github-Loading/Loader/20_Utils.lua")

    self:setupLogger(logLevel)
end


---@nodiscard
---@return boolean diffrentVersionFound
function Loader:CheckVersion()
    local versionFilePath = self.loaderBasePath .. "/Github-Loading/Version.now.json"
    local OldVersionString = Utils.File.ReadAll(versionFilePath)
    local NewVersionString = self:Get("/Github-Loading/Version.latest.json")
    Utils.File.Write(versionFilePath, "w", NewVersionString, true)
    return OldVersionString ~= NewVersionString
end


---@param option string
---@param extendOptionDetails boolean
---@return Github_Loading.Option chosenOption
function Loader:LoadOption(option, extendOptionDetails)
    ---@type Github_Loading.Option
    local Option = self:Get("/Github-Loading/Loader/10_Option.lua")
    local options = self:Get("/Github-Loading/100_Options.lua")
    ---@type Github_Loading.Option[]
    local mappedOptions = {}
    for name, url in pairs(options) do
        local optionObj = Option.new(name, url)
        table.insert(mappedOptions, optionObj)
    end
    if option == nil then
        print("\nOptions:")
        for _, optionObj in ipairs(mappedOptions) do
            optionObj:Print(extendOptionDetails)
        end
        computer.stop()
        return {}
    end

    ---@param optionName string
    ---@return Github_Loading.Option?
    local function getOption(optionName)
        for _, optionObj in ipairs(mappedOptions) do
            if optionObj.Name == optionName then
                return optionObj
            end
        end
    end
    local chosenOption = getOption(option)
    if not chosenOption then
        computer.panic("Option: '" .. option .. "' not found")
        return {}
    end
    return chosenOption
end


---@param option Github_Loading.Option
---@param baseUrl string
---@param forceDownload boolean
---@return Github_Loading.Entities.Main program
function Loader:LoadProgram(option, baseUrl, forceDownload)
    ---@type Github_Loading.PackageLoader
    local PackageLoader = self:Get("/Github-Loading/Loader/70_PackageLoader.lua")
    PackageLoader = PackageLoader.new(baseUrl .. "/Packages", self.loaderBasePath .. "/Packages",
        self.Logger:create("PackageLoader"), self.internetCard)
    PackageLoader:setGlobal()

    local package = PackageLoader:LoadPackage(option.Url, forceDownload)

    local mainModule = package:GetModule(package.Name .. ".Main")
    assert(mainModule, "Unable to get main module from option")
    assert(mainModule.IsRunnable, "main module from option is not runnable")

    ---@type Github_Loading.Entities.Main
    local mainModuleData = mainModule:Load()

    ---@type Github_Loading.Entities
    local Entities = self:Get("/Github-Loading/Loader/10_Entities.lua")
    return Entities.newMain(mainModuleData)
end


---@param program Github_Loading.Entities.Main
---@param logLevel Github_Loading.Logger.LogLevel
function Loader:Configure(program, logLevel)
    self.Logger:LogTrace("configuring program...")
    local Listener = self:Get("/Github-Loading/Loader/30_Listener.lua")
    local Logger = require("Core.Logger")
    program.Logger = Logger("Program", logLevel)

    local function log(message)
        print(message)
        Utils.File.Write("/Logs/main.log", "+a", message .. "\n", true)
    end
    local function clear()
        Utils.File.Clear("/Logs/main.log")
    end

    program.Logger.OnLog:AddListener(Listener.new(log))
    program.Logger.OnClear:AddListener(Listener.new(clear))
    program.Logger:setErrorLogger()
    local errorMsg = program:Configure()
    self.Logger:setErrorLogger()
    if errorMsg ~= "not found" then
        self.Logger:LogTrace("configured program")
    else
        self.Logger:LogTrace("no configure function found")
    end
end


---@param program Github_Loading.Entities.Main
function Loader:Run(program)
    self.Logger:LogTrace("running program...")
    program.Logger:setErrorLogger()
    local result = program:Run()
    self.Logger:setErrorLogger()
    if result == "$%not found%$" then
        error("no main run function found")
    end
    self.Logger:LogInfo("program stoped running: " .. tostring(result))
end


return Loader