---@meta
local PackageData = {}

PackageData["AdapterComputerInternetCard"] = {
    Location = "Adapter.Computer.InternetCard",
    Namespace = "Adapter.Computer.InternetCard",
    IsRunnable = true,
    Data = [[
---@class Adapter.InternetCard : object
---@field m_internetCard FIN.Components.FINComputerMod.InternetCard_C
local InternetCard = {}

---@param indexOrInternetCard number | FIN.Components.FINComputerMod.InternetCard_C
function InternetCard:__init(indexOrInternetCard)
    if not indexOrInternetCard then
        indexOrInternetCard = 1
    end

    if type(indexOrInternetCard) == "number" then
        self.m_internetCard = computer.getPCIDevices(findClass('InternetCard_C'))[indexOrInternetCard]
        if self.m_internetCard == nil then
            error('no internetCard was found')
        end
        return
    end

    ---@cast indexOrInternetCard FIN.Components.FINComputerMod.InternetCard_C
    self.m_internetCard = indexOrInternetCard
end

---@param url string
---@param logger Core.Logger?
---@return boolean success, string? data, number statusCode
function InternetCard:Download(url, logger)
    if logger then
        logger:LogTrace("downloading from: '" .. url .. "'...")
    end

    local req = self.m_internetCard:request(url, 'GET', '')
    repeat until req:canGet()

    local code, data = req:get()

    if logger then
        logger:LogTrace("downloaded from: '" .. url .. "'")
    end

    if code > 302 then
        return false, data, code
    end

    return true, data, code
end

return Utils.Class.CreateClass(InternetCard, "Adapter.InternetCard")
]]
}

PackageData["AdapterComputerNetworkCard"] = {
    Location = "Adapter.Computer.NetworkCard",
    Namespace = "Adapter.Computer.NetworkCard",
    IsRunnable = true,
    Data = [[
---@class Adapter.Computer.NetworkCard : object
---@field private m_networkCard FIN.Components.FINComputerMod.NetworkCard_C
---@field private m_openPorts table<integer, true>
---@overload fun(idOrIndexOrNetworkCard: FIN.UUID | integer | FIN.Components.FINComputerMod.NetworkCard_C) : Adapter.Computer.NetworkCard
local NetworkCard = {}

---@param index integer
function NetworkCard.Static__GetNetworkCardByIndex(index)
	return computer.getPCIDevices(findClass('NetworkCard_C'))[index]
end

local firstNetworkCard = true
---@private
---@param idOrIndexOrNetworkCard FIN.UUID | integer | FIN.Components.FINComputerMod.NetworkCard_C
function NetworkCard:__init(idOrIndexOrNetworkCard)
	self.m_openPorts = {}

	if not idOrIndexOrNetworkCard then
		idOrIndexOrNetworkCard = 1
	end

	if type(idOrIndexOrNetworkCard) == 'string' then
		---@cast idOrIndexOrNetworkCard FIN.UUID
		self.m_networkCard = component.proxy(idOrIndexOrNetworkCard) --{{{@as FIN.Components.FINComputerMod.NetworkCard_C}}}
		if self.m_networkCard == nil then
			error('no networkCard was found')
		end
		return
	end

	if type(idOrIndexOrNetworkCard) == 'number' then
		self.m_networkCard = computer.getPCIDevices(findClass('NetworkCard_C'))[idOrIndexOrNetworkCard]
		if self.m_networkCard == nil then
			error('no networkCard was found')
		end
		return
	end

	---@cast idOrIndexOrNetworkCard FIN.Components.FINComputerMod.NetworkCard_C
	self.m_networkCard = idOrIndexOrNetworkCard

	if firstNetworkCard then
		self:CloseAllPorts()
		firstNetworkCard = false
	end
end

---@return FIN.UUID
function NetworkCard:GetIPAddress()
	return self.m_networkCard.id
end

---@return string nick
function NetworkCard:GetNick()
	return self.m_networkCard.nick
end

function NetworkCard:Listen()
	event.listen(self.m_networkCard)
end

---@param port integer
---@return boolean openedPort
function NetworkCard:OpenPort(port)
	if self.m_openPorts[port] then
		return false
	end

	self.m_networkCard:open(port)
	self.m_openPorts[port] = true
	return true
end

---@param port integer
function NetworkCard:ClosePort(port)
	self.m_openPorts[port] = nil

	self.m_networkCard:close(port)
end

function NetworkCard:CloseAllPorts()
	self.m_openPorts = {}

	self.m_networkCard:closeAll()
end

---@param address Net.Core.IPAddress
---@param port integer
---@param ... any
function NetworkCard:Send(address, port, ...)
	self.m_networkCard:send(address:GetAddress(), port, ...)
end

---@param port integer
---@param ... any
function NetworkCard:BroadCast(port, ...)
	self.m_networkCard:broadcast(port, ...)
end

return Utils.Class.CreateClass(NetworkCard, 'Adapter.Computer.NetworkCard')
]]
}

return PackageData
