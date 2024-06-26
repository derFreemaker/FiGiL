local Usage = require("Core.Usage.init")

local Task = require("Core.Common.Task")

local Host = require("Hosting.Host")

local DNSEndpoints = require("DNS.Server.Endpoints")

---@class DNS.Main : Github_Loading.Entities.Main
---@field private m_netClient Net.Core.NetworkClient
---@field private m_host Hosting.Host
local Main = {}

---@param context Net.Core.NetworkContext
function Main:GetDNSServerAddress(context)
	local id = self.m_netClient:GetIPAddress():GetAddress()
	self.Logger:LogDebug(context.SenderIPAddress:GetAddress(), "requested DNS Server IP Address")
	self.m_netClient:Send(context.SenderIPAddress, Usage.Ports.DNS, Usage.Events.DNS_ReturnServerAddress, id)
end

function Main:Configure()
	self.m_host = Host(self.Logger:subLogger("Host"), "DNS Server")

	self.m_host:AddCallableEventListener(
		Usage.Events.DNS_GetServerAddress,
		Usage.Ports.DNS,
		function(context)
			self:GetDNSServerAddress(context)
		end
	)
	self.Logger:LogDebug("setup Get DNS Server IP Address")

	self.m_host:AddEndpoint(Usage.Ports.HTTP, "Endpoints", DNSEndpoints)
	self.Logger:LogDebug("setup DNS Server endpoints")

	self.m_netClient = self.m_host:GetNetworkClient()
end

function Main:Run()
	self.m_host:Ready()
	while true do
		self.m_netClient:BroadCast(Usage.Ports.DNS_Heartbeat, "DNS")
		self.m_host:RunCycle(3)
	end
end

return Main
