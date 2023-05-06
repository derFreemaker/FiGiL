local Utils = require("src (Outdated).Core.shared.Utils.Index")

---@class OptionOld
---@field Name string
---@field Url string
local OptionOld = {}
OptionOld.__index = OptionOld

---@param name string
---@param url string
---@return OptionOld
function OptionOld.new(name, url)
    return setmetatable({
        Name = name,
        Url = url
    }, OptionOld)
end

---@param extended boolean
function OptionOld:Print(extended)
    ---@type string
    local output
    if extended == true and type(self.Url) == "string" then
        output = self.Name .. " -> " .. self.Url
    end
    print(output)
end

---@class GithubLoaderOld
---@field private forceDownloadLoaderFiles boolean
---@field private options OptionOld[]
---@field private currentOption OptionOld
---@field private currentProgramInfo ProgramInfo
---@field private mainProgramModule Main
---@field private logger Logger
---@field private fileLoader GithubFileLoader
local GithubLoaderOld = {}
GithubLoaderOld.__index = GithubLoaderOld

local GithubLoaderFilesUrl = GithubLoaderBaseUrl .. "Github/"
local GithubLoaderFilesPath = "GithubLoaderFiles"
local OptionsUrl = GithubLoaderFilesUrl .. "Options.lua"
local OptionsPath = filesystem.path(GithubLoaderFilesPath, "Options.lua")
local GithubFileLoaderUrl = GithubLoaderFilesUrl .. "GithubFileLoader.lua"
local GithubFileLoaderPath = filesystem.path(GithubLoaderFilesPath, "GithubFileLoader.lua")

local SharedFolderUrl = GithubLoaderBaseUrl .. "shared/"
local SharedFolderPath = "shared"
local ModuleFileLoaderUrl = SharedFolderUrl .. "ModuleLoader.lua"
local ModuleFileLoaderPath = filesystem.path(SharedFolderPath, "ModuleLoader.lua")
local LoggerUrl = SharedFolderUrl .. "Logger.lua"
local LoggerPath = filesystem.path(SharedFolderPath, "Logger.lua")
local UtilsUrl = SharedFolderUrl .. "Utils.lua"
local UtilsPath = filesystem.path(SharedFolderPath, "Utils.lua")

local VersionFilePath = "Version.lua"
local MainFilePath = "Program.lua"

---@private
---@param url string
---@param path string
---@param forceDownload boolean
---@return boolean
function GithubLoaderOld:internalDownload(url, path, forceDownload)
    if forceDownload == nil then forceDownload = false end
    if filesystem.exists(path) and not forceDownload then
        return true
    end
    if self.logger ~= nil then
        self.logger:LogTrace("downloading '" .. path .. "' from: '" .. url .. "'...")
    end
    local req = InternetCard:request(url, "GET", "")
    local code, data = req:await()
    if code ~= 200 or data == nil then return false end
    local file = filesystem.open(path, "w")
    file:write(data)
    file:close()
    if self.logger ~= nil then
        self.logger:LogTrace("downloaded '" .. path .. "' from: '" .. url .. "'")
    end
    return true
end

---@private
function GithubLoaderOld:createLoaderFilesFolders()
    if not filesystem.exists(GithubLoaderFilesPath) then
        filesystem.createDir(GithubLoaderFilesPath)
    end
    if not filesystem.exists(SharedFolderPath) then
        filesystem.createDir(SharedFolderPath)
    end
end

---@private
---@return boolean
function GithubLoaderOld:loadUtils()
    if not self:internalDownload(UtilsUrl, UtilsPath, self.forceDownloadLoaderFiles) then
        return false
    end
    filesystem.doFile(UtilsPath)
    return true
end

---@private
---@param logLevel number
---@return boolean
function GithubLoaderOld:loadLogger(logLevel)
    if not filesystem.exists("log") then
        filesystem.createDir("log")
    end
    if not self:internalDownload(LoggerUrl, LoggerPath, self.forceDownloadLoaderFiles) then return false end
    self.logger = filesystem.doFile(LoggerPath).new("Loader", logLevel)
    if self.logger == nil then
        return false
    end
    self.logger:ClearLog(true)
    return true
end

---@private
---@return boolean
function GithubLoaderOld:loadGithubFileLoader()
    self.logger:LogTrace("loading github file loader...")
    if not self:internalDownload(GithubFileLoaderUrl, GithubFileLoaderPath, self.forceDownloadLoaderFiles) then
        return false
    end
    self.fileLoader = filesystem.doFile(GithubFileLoaderPath).new(self.logger)
    if self.fileLoader == nil then
        return false
    end
    self.logger:LogTrace("loaded github file loader")
    return true
end

---@private
---@return boolean
function GithubLoaderOld:loadModuleLoader()
    self.logger:LogTrace("loading module loader...")
    if not self:internalDownload(ModuleFileLoaderUrl, ModuleFileLoaderPath, self.forceDownloadLoaderFiles) then
        return false
    end
    filesystem.doFile(ModuleFileLoaderPath)
    self.logger:LogTrace("loaded module loader")
    return true
end

---@private
---@return boolean
function GithubLoaderOld:loadOptions()
    if not self.options == nil then return true end
    if not self:internalDownload(OptionsUrl, OptionsPath, true) then return false end
    self.logger:LogTrace("loading options...")

    for name, url in pairs(filesystem.doFile(OptionsPath)) do
        ---@cast name string
        ---@cast url string
        table.insert(self.options, OptionOld.new(name, url))
    end
    self.logger:LogTrace("loaded options")
    return true
end

---@private
---@param optionName string
---@return boolean
function GithubLoaderOld:loadOption(optionName)
    if not self:loadOptions() then return false end
    self.logger:LogTrace("loading option: " .. optionName)
    for _, option in pairs(self.options) do
        if option.Name == optionName then
            self.currentOption = option
            self.logger:LogTrace("loaded option: " .. option.Name)
            return true
        end
    end
    return false
end

---@private
---@return boolean
function GithubLoaderOld:isVersionTheSame()
    self.logger:LogTrace("loading info data...")
    local versionFileExists = filesystem.exists(VersionFilePath)
    if versionFileExists then
        local currentProgramInfo = filesystem.doFile(VersionFilePath)
        self.currentProgramInfo = Utils.ProgramInfo.new(currentProgramInfo.Name, currentProgramInfo.Version)
    else
        self.logger:LogTrace("no version file found")
    end

    if not self:internalDownload(GithubLoaderBaseUrl .. self.currentOption.Url .. "/Version.lua", VersionFilePath, true) then return false end

    local versionFile = filesystem.doFile(VersionFilePath)
    local newProgramInfo = Utils.ProgramInfo.new(versionFile.Name, versionFile.Version)

    if newProgramInfo == nil then
        return false
    end

    if not versionFileExists then
        self.currentProgramInfo = newProgramInfo
    end

    self.logger:LogTrace("loaded info data")
    local isSame = self.currentProgramInfo:Compare(newProgramInfo)
    if not isSame then
        self.currentProgramInfo = newProgramInfo
    end
    return isSame
end

---@private
---@param forceDownload boolean
---@return boolean
function GithubLoaderOld:loadOptionFiles(forceDownload)
    self.logger:LogTrace("loading main program file...")
    if not filesystem.exists(MainFilePath) or forceDownload then
        if not self:internalDownload(GithubLoaderBaseUrl .. self.currentOption.Url .. "/Main.lua", MainFilePath, forceDownload) then
            self.logger:LogError("Unable to download main program file")
            return false
        end
    end
    self.mainProgramModule = Utils.Main.new(filesystem.doFile(MainFilePath))
    self.logger:LogTrace("parsing setup files...")
    local parsedSetupFileTree, success = Utils.Entry.Parse(self.mainProgramModule.SetupFilesTree)
    if not success then
        return false
    end
    ---@cast parsedSetupFileTree Entry
    self.mainProgramModule.SetupFilesTree = parsedSetupFileTree
    self.logger:LogTrace("loaded main program file")
    return true
end

---@private
---@param option string
---@param forceDownload boolean
---@return boolean
function GithubLoaderOld:download(option, forceDownload)
    if not self:loadOption(option) then
        self.logger:LogError("Unable not find option: " .. option)
        return false
    end
    local loadProgramFiles = self:isVersionTheSame()
    if not loadProgramFiles then
        self.logger:LogInfo("new Version of '" .. option .. "' found or diffrent program")
        forceDownload = true
    else
        self.logger:LogInfo("no new Version available")
    end
    if not self:loadOptionFiles(forceDownload) then
        self.logger:LogError("Unable to load option files")
        return false
    end
    if forceDownload then
        loadProgramFiles = true
    end
    if not self.fileLoader:DownloadFileTree(GithubLoaderBaseUrl, self.mainProgramModule.SetupFilesTree, loadProgramFiles) then
        self.logger:LogError("Unable to load setup files")
        return false
    end
    return true
end

---@private
---@param logLevel number
---@return boolean
function GithubLoaderOld:runConfigureFunction(logLevel)
    self.logger:LogTrace("configuring program...")
    self.mainProgramModule.Logger = self.logger.new("Program", logLevel)
    local thread, success, error = Utils.ExecuteFunction(self.mainProgramModule.Configure, self.mainProgramModule)
    if success and error ~= "not found" then
        self.logger:LogTrace("configured program")
    elseif error ~= "$%not found%$" then
        self.logger:LogError("configuration failed")
        self.logger:LogError(debug.traceback(thread, error) .. debug.traceback():sub(17))
        return false
    else
        self.logger:LogTrace("no configure function found")
        return false
    end
    return true
end

---@private
---@return boolean
function GithubLoaderOld:runMainFunction()
    self.logger:LogTrace("running program...")
    local thread, success, result = Utils.ExecuteFunction(self.mainProgramModule.Run, self.mainProgramModule)
    if result == "$%not found%$" then
        self.logger:LogError("no main run function found")
        return false
    end
    if not success then
        self.logger:LogError("program stoped running")
        self.logger:LogError(debug.traceback(thread, result) .. debug.traceback():sub(17))
        return false
    else
        self.logger:LogInfo("program stoped running: " .. tostring(result))
    end
    return true
end

---@param logLevel number
---@param forceDownload boolean
function GithubLoaderOld:Initialize(logLevel, forceDownload)
    self.forceDownloadLoaderFiles = forceDownload or false
    self.options = {}
    self.currentOption = {}
    self.currentProgramInfo = {}
    self.mainProgramModule = {}
    self.logger = nil
    self.fileLoader = nil
    self:createLoaderFilesFolders()
    if not self:loadUtils() then
        computer.panic("Unable to load utils")
    end
    if not self:loadLogger(logLevel) then
        computer.panic("Unable to load logger")
    end
    if not self:loadGithubFileLoader() then
        computer.panic("Unable to load github file loader")
    end
    if not self:loadModuleLoader() then
        computer.panic("Unable to load module loader")
    end
    if self.forceDownloadLoaderFiles then
        self.logger:LogInfo("loaded loader files")
    end
    return self
end

---@param extended boolean
function GithubLoaderOld:ShowOptions(extended)
    if not self:loadOptions() then
        self.logger:LogError("Unable to load options")
    end
    print()
    print("Options:")
    for _, option in pairs(self.options) do
        if option.Name ~= "//index" then
            option:Print(extended)
        end
    end
end

---@param option string
---@param logLevel number
---@param forceDownload boolean
---@return boolean
function GithubLoaderOld:Run(option, logLevel, forceDownload)
    self.logger:LogTrace("downloading program data...")
    if not self:download(option, forceDownload) then
        self.logger:LogError("Unable to download '" .. option .. "'")
        return false
    end
    self.logger:LogTrace("downloaded program data")
    print()

    if not self:runConfigureFunction(logLevel) then return false end
    if not self:runMainFunction() then return false end
    return true
end

return GithubLoaderOld
