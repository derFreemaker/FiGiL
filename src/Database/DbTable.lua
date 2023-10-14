local Json = require("Core.Json.Json")
local File = require("Core.FileSystem.File")

local Dto = require("Database.Dto")

---@class Database.DbTable : object
---@field private name string
---@field private path Core.Path
---@field private data Dictionary<string | number, table>
---@field private dataChanged (string | number)[]
---@field private logger Core.Logger
---@overload fun(name: string, path: Core.Path, logger: Core.Logger) : Database.DbTable
local DbTable = {}

---@private
---@param name string
---@param path Core.Path
---@param logger Core.Logger
function DbTable:__init(name, path, logger)
    if not path:IsDir() then
        error("path needs to be a folder: " .. path:GetPath())
    end

    self.name = name
    self.path = path
    self.logger = logger
    self.data = {}
end

function DbTable:Load()
    self.logger:LogTrace("loading Database Table: '" .. self.name .. "'...")
    local parentFolder = self.path:GetParentFolderPath()
    if not filesystem.exists(parentFolder:GetPath()) then
        filesystem.createDir(parentFolder:GetPath(), true)
    end

    for _, fileName in ipairs(filesystem.childs(self.path:GetPath())) do
        local path = self.path:Extend(fileName)

        if path:IsFile() then
            local data = File.Static__ReadAll(path)

            local key = fileName:match("^(.+)%.dto%.json$")
            self.data[key] = Json.decode(data)
        end
    end

    self.logger:LogTrace("loaded Database Table")
end

function DbTable:Save()
    self.logger:LogTrace("saving Database Table: '" .. self.name .. "'...")

    for _, key in pairs(self.dataChanged) do
        local path = self.path:Extend(tostring(key) .. ".dto.json")
        local data = self.data[key]

        if not data then
            filesystem.remove(path:GetPath())
        else
            File.Static__WriteAll(path, Json.encode(data))
        end
    end

    self.logger:LogTrace("saved Database Table")
end

---@param key string | number
function DbTable:ObjectChanged(key)
    for _, value in pairs(self.dataChanged) do
        if value == key then
            return
        end
    end

    table.insert(self.dataChanged, key)
end

---@param key string | number
---@param value table
function DbTable:Set(key, value)
    self.data[key] = value
    self:ObjectChanged(key)
end

---@param key string | number
function DbTable:Delete(key)
    self.data[key] = nil
    self:ObjectChanged(key)
end

---@param key string | number
---@return table value
function DbTable:Get(key)
    local data = self.data[key]
    return Dto(key, data, self)
end

---@private
---@return (fun(t: table, key: any) : key: any, value: any), table t, any startKey
function DbTable:__pairs()
    return next, self.data, nil
end

return Utils.Class.CreateClass(DbTable, "Database.DbTable")
