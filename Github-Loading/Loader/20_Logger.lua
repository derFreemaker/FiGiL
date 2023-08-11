local LoadedLoaderFiles = table.pack(...)[1]
---@type Utils
local Utils = LoadedLoaderFiles["/Github-Loading/Loader/10_Utils.lua"][1]
---@type Github_Loading.Event
local Event = LoadedLoaderFiles["/Github-Loading/Loader/10_Event.lua"][1]

---@alias Github_Loading.Logger.LogLevel
---|0 Trace
---|1 Debug
---|2 Info
---|3 Warning
---|4 Error

---@class Github_Loading.Logger
---@field OnLog Github_Loading.Event
---@field OnClear Github_Loading.Event
---@field Name string
---@field private logLevel number
local Logger = {}

---@private
---@param node table
---@param maxLevel number?
---@param properties string[]?
---@param logFunc function
---@param logFuncParent table
---@param level number?
---@param padding string?
---@return string[]
function Logger.tableToLineTree(node, maxLevel, properties, logFunc, logFuncParent, level, padding)
    padding = padding or '     '
    maxLevel = maxLevel or 5
    level = level or 1
    local lines = {}

    if type(node) == 'table' then
        local keys = {}
        if type(properties) == 'string' then
            local propSet = {}
            for p in string.gmatch(properties, "%b{}") do
                local propName = string.sub(p, 2, -2)
                for k in string.gmatch(propName, "[^,%s]+") do
                    propSet[k] = true
                end
            end
            for k in pairs(node) do
                if propSet[k] then
                    keys[#keys + 1] = k
                end
            end
        else
            for k in pairs(node) do
                if not properties or properties[k] then
                    keys[#keys + 1] = k
                end
            end
        end
        table.sort(keys)

        for i, k in ipairs(keys) do
            local line = ''
            if i == #keys then
                line = padding .. '└── ' .. tostring(k)
            else
                line = padding .. '├── ' .. tostring(k)
            end
            table.insert(lines, line)

            if level < maxLevel then
                ---@cast properties string[]
                local childLines = Logger.tableToLineTree(node[k], maxLevel, properties, logFunc, logFuncParent,
                    level + 1,
                    padding .. (i == #keys and '    ' or '│   '))
                for _, l in ipairs(childLines) do
                    table.insert(lines, l)
                end
            elseif i == #keys then
                table.insert(lines, padding .. '└── ...')
            end
        end
    else
        table.insert(lines, padding .. tostring(node))
    end

    if level == 1 then
        if logFuncParent == nil then
            for line in pairs(lines) do
                logFunc(line)
            end
        elseif type(logFuncParent) ~= "table" then
            error("logFuncParent was not a table", 2)
        else
            for line in pairs(lines) do
                logFunc(logFuncParent, line)
            end
        end
    end

    return lines
end

---@param name string
---@param logLevel Github_Loading.Logger.LogLevel
---@return Github_Loading.Logger
function Logger.new(name, logLevel)
    local metatable = Logger
    metatable.__index = Logger
    return setmetatable({
        logLevel = logLevel,
        Name = (string.gsub(name, " ", "_") or ""),
        OnLog = Event.new(),
        OnClear = Event.new()
    }, metatable)
end

---@param name string
---@return Github_Loading.Logger
function Logger:create(name)
    name = self.Name .. "." .. name
    local metatable = Logger
    metatable.__index = Logger
    return setmetatable({
        logLevel = self.logLevel,
        Name = name:gsub(" ", "_"),
        OnLog = Utils.Table.Copy(self.OnLog),
        OnClear = Utils.Table.Copy(self.OnClear)
    }, metatable)
end

---@private
---@param message string
---@param logLevel Github_Loading.Logger.LogLevel
function Logger:Log(message, logLevel)
    if logLevel < self.logLevel then
        return
    end

    message = "[" .. self.Name .. "] " .. message
    self.OnLog:Trigger(message)
end

---@param message any
function Logger:LogTrace(message)
    if message == nil then return end
    self:Log("TRACE! " .. tostring(message), 0)
end

---@param table table | any
---@param maxLevel number?
---@param properties table?
function Logger:LogTableTrace(table, maxLevel, properties)
    if table == nil or type(table) ~= "table" then return end
    Logger.tableToLineTree(table, maxLevel, properties, self.LogTrace, self)
end

---@param message any
function Logger:LogDebug(message)
    if message == nil then return end
    self:Log("DEBUG! " .. tostring(message), 1)
end

---@param table table | any
---@param maxLevel number?
---@param properties table?
function Logger:LogTableDebug(table, maxLevel, properties)
    if table == nil or type(table) ~= "table" then return end
    Logger.tableToLineTree(table, maxLevel, properties, self.LogDebug, self)
end

---@param message any
function Logger:LogInfo(message)
    if message == nil then return end
    self:Log("INFO! " .. tostring(message), 2)
end

---@param table table | any
---@param maxLevel number?
---@param properties table?
function Logger:LogTableInfo(table, maxLevel, properties)
    if table == nil or type(table) ~= "table" then return end
    Logger.tableToLineTree(table, maxLevel, properties, self.LogInfo, self)
end

---@param message any
function Logger:LogWarning(message)
    if message == nil then return end
    self:Log("WARN! " .. tostring(message), 3)
end

---@param table table | any
---@param maxLevel number?
---@param properties table?
function Logger:LogTableWarning(table, maxLevel, properties)
    if table == nil or type(table) ~= "table" then return end
    Logger.tableToLineTree(table, maxLevel, properties, self.LogWarning, self)
end

---@param message any
function Logger:LogError(message)
    if message == nil then return end
    self:Log("ERROR! " .. tostring(message), 4)
end

---@param table table | any
---@param maxLevel number?
---@param properties table?
function Logger:LogTableError(table, maxLevel, properties)
    if table == nil or type(table) ~= "table" then return end
    Logger.tableToLineTree(table, maxLevel, properties, self.LogError, self)
end

function Logger:Clear()
    self.OnClear:Trigger()
end

return Logger