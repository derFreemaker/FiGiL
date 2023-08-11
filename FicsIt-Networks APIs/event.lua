---@diagnostic disable

--- Computer Api from Documentation and in Code found.
--- [Documentation](https://docs.ficsit.app/ficsit-networks/latest/index.html)
--- [Code](https://github.com/Panakotta00/FicsIt-Networks/tree/master)
--- Date: 08.09.2023
---@class FicsIt_Networks.Event.Api
event = {}


--- Adds the running lua context to the listen queue of the given component.
---@param component FicsIt_Networks.Component The network component lua representation the computer should now listen to.
function event.listen(component) end


--- Returns all signal senders this computer is listening to.
---@return FicsIt_Networks.Component[] components An array containing instances to all sginal senders this computer is listening too.
function event.listening() end


--- Waits for a signal in the queue. Blocks the execution until a signal got pushed to the signal queue.
--- Returns directly if there is already a signal in the queue (the tick doesn’t get yielded).
---@return string signalName The name of the returned signal.
---@return FicsIt_Networks.Component component The component representation of the signal sender.
---@return ... The parameters passed to the signal.
function event.pull() end

--- Waits for a signal in the queue. Blocks the execution until a signal got pushed to the signal queue, or the timeout is reached.
--- Returns directly if there is already a signal in the queue (the tick doesn’t get yielded).
---@param timeout number The amount of time needs to pass until pull unblocks when no signal got pushed.
---@return string signalName The name of the returned signal.
---@return FicsIt_Networks.Component component The component representation of the signal sender.
---@return ... The parameters passed to the signal.
function event.pull(timeout) end


--- Removes the running lua context from the listen queue of the given components. Basically the opposite of listen.
---@param component FicsIt_Networks.Component The network component lua representations the computer should stop listening to.
function event.ignore(component) end


--- Stops listening to any signal sender. If afterwards there are still coming signals in, it might be the system itself or caching bug.
function event.ignoreAll() end


--- Clears every signal from the signal queue.
function event.clear() end