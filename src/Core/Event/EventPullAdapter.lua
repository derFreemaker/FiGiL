local Event = require("Core.Event.init")

--- Handles events from `event.pull()`.
---
---@class Core.EventPullAdapter
---@field OnEventPull Core.Event
---@field private m_events table<string, Core.Event>
---@field private m_logger Core.Logger
local EventPullAdapter = {}

---@private
---@param eventPullData any[]
function EventPullAdapter:onEventPull(eventPullData)
	local eventName = eventPullData[1]

	local allEvent = self.m_events["*"]
	if allEvent then
		allEvent:Trigger(self.m_logger, eventPullData)
		if allEvent:Count() == 0 then
			self.m_events["*"] = nil
		end
	end

	local event = self.m_events[eventName]
	if not event then
		return
	end

	event:Trigger(self.m_logger, eventPullData)
	if event:Count() == 0 then
		self.m_events[eventName] = nil
	end
end

---@param logger Core.Logger
---@return Core.EventPullAdapter
function EventPullAdapter:Initialize(logger)
	self.m_events = {}
	self.m_logger = logger
	self.OnEventPull = Event()

	return self
end

---@param signalName string | "*"
---@return Core.Event
function EventPullAdapter:GetEvent(signalName)
	local event = self.m_events[signalName]
	if event then
		return event
	end

	event = Event()
	self.m_events[signalName] = event
	return event
end

---@param signalName string | "*"
---@param task Core.Task
---@return integer index
function EventPullAdapter:AddTask(signalName, task)
	local event = self:GetEvent(signalName)
	return event:AddTask(task)
end

---@param signalName string | "*"
---@param task Core.Task
---@return integer index
function EventPullAdapter:AddTaskOnce(signalName, task)
	local event = self:GetEvent(signalName)
	return event:AddTaskOnce(task)
end

---@param signalName string | "*"
---@param index integer
function EventPullAdapter:Remove(signalName, index)
	local event = self.m_events[signalName]
	if not event then
		return
	end

	event:Remove(index)
end

--- Waits for an event to be handled or timeout
--- Returns true if event was handled and false if it timeout
---
---@async
---@param timeoutSeconds number?
---@return boolean gotEvent
function EventPullAdapter:Wait(timeoutSeconds)
	self.m_logger:LogTrace("## waiting for event pull ##")
	---@type table?
	local eventPullData = nil
	if timeoutSeconds == nil then
		eventPullData = { event.pull() }
	else
		eventPullData = { event.pull(timeoutSeconds) }
	end
	if #eventPullData == 0 then
		return false
	end

	self.m_logger:LogDebug("event with signalName: "
		.. eventPullData[1] .. " was received from component: "
		.. tostring(eventPullData[2]))

	self.OnEventPull:Trigger(self.m_logger, eventPullData)
	self:onEventPull(eventPullData)
	return true
end

--- Waits for all events in the event queue to be handled or timeout
---
---@async
---@param timeoutSeconds number?
function EventPullAdapter:WaitForAll(timeoutSeconds)
	while self:Wait(timeoutSeconds) do
	end
end

--- Starts event pull loop
--- ## will never return
---@async
function EventPullAdapter:Run()
	self.m_logger:LogDebug("## started event pull loop ##")
	while true do
		self:Wait()
	end
end

return EventPullAdapter
