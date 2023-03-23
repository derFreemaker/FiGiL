Utils = {}

---@param ms number defines how long the function will wait in Milliseconds
function Utils.Sleep(ms)
    if type(ms) ~= "number" then error("ms was not a number", 1) end
    local startTime = computer.millis()
    local endTime = startTime + ms
    while startTime <= endTime do startTime = computer.millis() end
end

---@param func function
---@param object table | nil
---@param ... any | nil
---@return thread, boolean, 'result'
function Utils.ExecuteFunction(func, object, ...)
    local thread = coroutine.create(func)
    if object == nil then
        return thread, coroutine.resume(thread, ...)
    else
        return thread, coroutine.resume(thread, object, ...)
    end
end

Utils.File = {}

---@param path string
---@param mode string
---@param data string | nil
function Utils.File.Write(path, mode, data)
    if data == nil then return end
    local file = filesystem.open(path, mode)
    file:write(data)
    file:close()
end

---@param path string
---@return string
function Utils.File.Read(path)
    local file = filesystem.open(path, "r")
    local str = ""
    while true do
        local buf = file:read(256)
        if not buf then
            break
        end
        str = str .. buf
    end
    return str
end


---@class Entry
---@field Name string
---@field FullName string
---@field IsFolder boolean
---@field IgnoreDownload boolean
---@field IgnoreLoad boolean
---@field Path string
---@field Childs Entry[]
local Entry = {}
Entry.__index = Entry

---@param name string
---@param fullName string
---@param isFolder boolean
---@param ignoreDownload boolean
---@param ignoreLoad boolean
---@param path string
---@param chidls Entry[]
---@return Entry
function Entry.new(name, fullName, isFolder, ignoreDownload, ignoreLoad, path, chidls)
    return setmetatable({
        Name = name,
        FullName = fullName,
        IsFolder = isFolder,
        IgnoreDownload = ignoreDownload,
        IgnoreLoad = ignoreLoad,
        Path = path,
        Childs = chidls
    }, Entry)
end

---@param entryData table
---@return Entry
function Entry.newWithDataTable(entryData)
    return setmetatable({
        Name = entryData.name,
        FullName = entryData.fullName,
        IsFolder = entryData.isFolder,
        IgnoreDownload = entryData.ignoreDownload,
        IgnoreLoad = entryData.ignoreLoad,
        Path = entryData.path,
        Childs = entryData.chidls
    }, Entry)
end

---@param entry table
---@param parentEntry Entry | nil
---@return Entry
function Entry.Check(entry, parentEntry)
    parentEntry = parentEntry or Entry.new("", "", true, false, false, "", {})

    entry.Name = entry.Name or entry.FullName or entry[1]
    entry.FullName = entry.FullName or entry.Name

    if entry.IsFolder == nil then
        local childs = 0
        for _, child in pairs(entry) do
            if type(child) == "table" then
                childs = childs + 1
            end
        end
        if childs == 0 then
            entry.IsFolder = false
        else
            entry.IsFolder = true
        end
    end

    entry.IgnoreDownload = entry.IgnoreDownload or false
    entry.IgnoreLoad = entry.IgnoreLoad or false

    if entry.IsFolder then
        entry.Path = entry.Path or filesystem.path(parentEntry.Path, entry.FullName)
        local childs = {}
        for _, child in pairs(entry) do
            if type(child) == "table" then
                table.insert(childs, Utils.Entry.Check(child, entry.Path))
            end
        end
        return {
            Name = entry.Name,
            FullName = entry.FullName,
            IsFolder = entry.IsFolder,
            IgnoreDownload = entry.IgnoreDownload,
            IgnoreLoad = entry.IgnoreLoad,
            Path = entry.Path,
            Childs = childs
        }
    end

    local nameLength = entry.Name:len()
    if entry.Name:sub(nameLength - 3, nameLength) == ".lua" then
        entry.Name = entry.Name:sub(0, nameLength - 4)
    end
    nameLength = entry.FullName:len()
    if entry.FullName:sub(nameLength - 3, nameLength) ~= ".lua" then
        entry.FullName = entry.FullName .. ".lua"
    end

    entry.Path = entry.Path or filesystem.path(parentEntry.Path, entry.FullName)

    return Entry.newWithDataTable(entry)
end

---@param parentEntry Entry
---@return Entry
function Entry:SelfCheck(parentEntry)
    return Entry.Check(self, parentEntry)
end

Utils.Entry = Entry


---@class ProgramInfo
---@field Name string
---@field Version string
local ProgramInfo = {}
ProgramInfo.__index = ProgramInfo

---@param name string
---@param version string
---@return ProgramInfo
function ProgramInfo.new(name, version)
    return setmetatable({
        Name = name,
        Version = version
    }, ProgramInfo)
end

---@param programInfo ProgramInfo
function ProgramInfo:Compare(programInfo)
    if self.Name ~= programInfo.Name
        or self.Version ~= programInfo.Version then
        return false
    end
    return true
end

Utils.ProgramInfo = ProgramInfo


---@class Main
---@field Logger Logger
---@field SetupFilesTree table
local Main = {}
Main.__index = Main

---@param mainModule table
function Main.new(mainModule)
    return setmetatable({
        Logger = mainModule.Logger or {},
        SetupFilesTree = mainModule.SetupFilesTree or {},
        Configure = mainModule.Configure,
        Run = mainModule.Run
    }, Main)
end

---@return string | any
function Main:Configure()
    return "$%not found%$"
end

---@return string | any
function Main:Run()
    return "$%not found%$"
end

Utils.Main = Main
