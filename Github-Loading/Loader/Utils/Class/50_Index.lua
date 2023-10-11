local LoadedLoaderFiles = ({ ... })[1]
---@type Utils.Table
local Table = LoadedLoaderFiles["/Github-Loading/Loader/Utils/Table"][1]
---@type Utils.Class.MembersHandler
local MembersHandler = LoadedLoaderFiles['/Github-Loading/Loader/Utils/Class/MembersHandler'][1]
---@type Utils.Class.TypeHandler
local TypeHandler = LoadedLoaderFiles['/Github-Loading/Loader/Utils/Class/TypeHandler'][1]
---@type Utils.Class.ConstructionHandler
local ConstructionHandler = LoadedLoaderFiles['/Github-Loading/Loader/Utils/Class/ConstructionHandler'][1]

---@class Utils.Class
local Class = {}

---@generic TClass
---@param data TClass
---@param name string
---@param baseClass object?
---@return TClass
function Class.CreateClass(data, name, baseClass)
    local typeInfo = TypeHandler.CreateType(name, baseClass)

    MembersHandler.SortMembers(data, typeInfo)

    ConstructionHandler.ConstructTemplate(typeInfo, data)
    return data
end

---@generic TClass
---@param class TClass
function Class.Deconstruct(class)
    ---@type Utils.Class.Metatable
    local metatable = getmetatable(class)
    local typeInfo = metatable.Type

    if metatable.__gc then
        metatable.__gc(class)
    end

    Table.Clear(class)
    Table.Clear(metatable)

    local function blockedNewIndex()
        error("cannot assign values to deconstruct class: " .. typeInfo.Name, 2)
    end
    metatable.__newindex = blockedNewIndex

    local function blockedIndex()
        error("cannot get values from deconstruct class: " .. typeInfo.Name, 2)
    end
    metatable.__index = blockedIndex

    setmetatable(class, metatable)
end

return Class