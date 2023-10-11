local LoadedLoaderFiles = ({...})[1]
---@type Utils
local Utils = LoadedLoaderFiles["/Github-Loading/Loader/Utils"][1]

---@class Github_Loading.Event
---@field private funcs Github_Loading.Listener[]
---@field private onceFuncs Github_Loading.Listener[]
local Event = {}

---@return Github_Loading.Event
function Event.new()
    return setmetatable({
        funcs = {},
        onceFuncs = {}
    }, { __index = Event })
end

---@param listener Github_Loading.Listener
---@return Github_Loading.Event
function Event:AddListener(listener)
    table.insert(self.funcs, listener)
    return self
end

Event.On = Event.AddListener

---@param listener Github_Loading.Listener
---@return Github_Loading.Event
function Event:AddListenerOnce(listener)
    table.insert(self.onceFuncs, listener)
    return self
end

Event.Once = Event.AddListenerOnce

---@param logger Github_Loading.Logger?
---@param ... any
function Event:Trigger(logger, ...)
    for _, listener in ipairs(self.funcs) do
        listener:Execute(logger, ...)
    end

    for _, listener in ipairs(self.onceFuncs) do
        listener:Execute(logger, ...)
    end
    self.OnceFuncs = {}
end

---@return Github_Loading.Listener[]
function Event:Listeners()
    local clone = {}

    for _, listener in ipairs(self.funcs) do
        table.insert(clone, { Mode = "Permanent", Listener = listener })
    end
    for _, listener in ipairs(self.onceFuncs) do
        table.insert(clone, { Mode = "Once", Listener = listener })
    end

    return clone
end

---@param event Github_Loading.Event
---@return Github_Loading.Event event
function Event:CopyTo(event)
    for _, listener in ipairs(self.funcs) do
        event:AddListener(listener)
    end
    for _, listener in ipairs(self.onceFuncs) do
        event:AddListenerOnce(listener)
    end
    return event
end

---@param Task Core.Task | fun(func: function, parent: table?) : Core.Task
---@param event Core.Event
---@return Core.Event
function Event:CopyToCoreEvent(Task, event)
    for _, listener in ipairs(self.funcs) do
        event:AddListener(listener:convertToTask(Task))
    end
    for _, listener in ipairs(self.onceFuncs) do
        event:AddListenerOnce(listener:convertToTask(Task))
    end
    return event
end

return Event