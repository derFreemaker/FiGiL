local Data={
["DNS.Client.__events"] = [==========[
---@class DNS.Client.Events : Github_Loading.Entities.Events
local Events = {}

function Events:OnLoaded()
    require("DNS.Client.Hosting.HostExtensions")
end

return Events

]==========],
["DNS.Client.Client"] = [==========[
local Usage = require("Core.Usage.init")

local IPAddress = require("Net.Core.IPAddress")
local NetworkClient = require("Net.Core.NetworkClient")
local ApiClient = require("Net.Rest.Api.Client.Client")
local ApiRequest = require("Net.Rest.Api.Core.Request")

local CreateAddress = require("DNS.Core.Entities.Address.Create")

local Uri = require("Net.Core.Uri")

---@class DNS.Client : object
---@field private m_networkClient Net.Core.NetworkClient
---@field private m_apiClient Net.Rest.Api.Client
---@field private m_logger Core.Logger
---@overload fun(networkClient: Net.Core.NetworkClient, logger: Core.Logger) : DNS.Client
local Client = {}

---@private
---@param networkClient Net.Core.NetworkClient?
---@param logger Core.Logger
function Client:__init(networkClient, logger)
	self.m_networkClient = networkClient or NetworkClient(logger:subLogger("NetworkClient"))
	self.m_logger = logger
end

---@return Net.Core.NetworkClient
function Client:GetNetClient()
	return self.m_networkClient
end

---@param networkClient Net.Core.NetworkClient
function Client.Static__WaitForHeartbeat(networkClient)
	networkClient:WaitForEvent(Usage.Events.DNS_Heartbeat, Usage.Ports.DNS_Heartbeat)
end

---@param networkClient Net.Core.NetworkClient
---@return Net.IPAddress id
function Client.Static__GetServerAddress(networkClient)
	local netPort = networkClient:GetOrCreateNetworkPort(Usage.Ports.DNS)

	netPort:BroadCastMessage(Usage.Events.DNS_GetServerAddress, nil, nil)
	---@type Net.Core.NetworkContext?
	local response
	local try = 0
	repeat
		try = try + 1
		response = netPort:WaitForEvent(Usage.Events.DNS_ReturnServerAddress, 10)
	until response ~= nil or try == 10
	if try == 10 then
		error("unable to get dns server address")
	end
	---@cast response Net.Core.NetworkContext
	return IPAddress(response.Body)
end

---@return Net.IPAddress id
function Client:GetOrRequestDNSServerIP()
	if not self.m_apiClient then
		local serverIPAddress = Client.Static__GetServerAddress(self.m_networkClient)
		self.m_apiClient = ApiClient(serverIPAddress, Usage.Ports.HTTP, Usage.Ports.HTTP, self.m_networkClient,
			self.m_logger:subLogger("ApiClient"))
	end

	return self.m_apiClient.ServerIPAddress
end

---@private
---@param method Net.Core.Method
---@param url string
---@param body any
---@param headers table<string, any>?
function Client:InternalRequest(method, url, body, headers)
	self:GetOrRequestDNSServerIP()

	local request = ApiRequest(method, Uri.Static__Parse(url), body, headers)
	return self.m_apiClient:Send(request)
end

---@param url string
---@param ipAddress Net.IPAddress
---@return boolean success
function Client:CreateAddress(url, ipAddress)
	local createAddress = CreateAddress(url, ipAddress)

	local response = self:InternalRequest("CREATE", "/Address/Create/", createAddress)

	if not response.WasSuccessful then
		return false
	end
	return response.Body
end

---@param id Core.UUID
---@return boolean success
function Client:DeleteAddress(id)
	local response = self:InternalRequest("DELETE", "/Address/" .. tostring(id) .. "/Delete/")

	if not response.WasSuccessful then
		return false
	end
	return response.Body
end

---@param id Core.UUID
---@return DNS.Core.Entities.Address? address
function Client:GetWithId(id)
	local response = self:InternalRequest("GET", "/Address/Id/" .. tostring(id) .. "/")

	if not response.WasSuccessful then
		return nil
	end
	return response.Body
end

---@param domain string
---@return DNS.Core.Entities.Address? address
function Client:GetWithDomain(domain)
	local response = self:InternalRequest("GET", "/Address/Domain/" .. domain .. "/")

	if not response.WasSuccessful then
		return nil
	end
	return response.Body
end

return class("DNS.Client", Client)

]==========],
["DNS.Client.Hosting.HostExtensions"] = [==========[
---@type Out<Github_Loading.Module>
local Host = {}
if not PackageLoader:TryGetModule("Hosting.Host", Host) then
    return
end
---@type Hosting.Host
Host = Host.Value:Load()

local Task = require("Core.Common.Task")

local DNSClient = require("DNS.Client.Client")

---@param host Hosting.Host
local function readyTaskWaitForDNSServer(host)
    DNSClient.Static__WaitForHeartbeat(host:GetNetworkClient())
end

table.insert(Host.Static__ReadyTasks, Task(readyTaskWaitForDNSServer))

---@class Hosting.Host
---@field package m_dnsClient DNS.Client
local HostExtensions = {}

function HostExtensions:GetDNSClient()
    if not self.m_dnsClient then
        self.m_dnsClient = DNSClient(self:GetNetworkClient(), self:CreateLogger("DNSClient"))
    end

    return self.m_dnsClient
end

---@param url string
---@param ipAddress Net.IPAddress?
function HostExtensions:RegisterAddress(url, ipAddress)
    local dnsClient = self:GetDNSClient()

    if not ipAddress then
        ipAddress = self:GetNetworkClient():GetIPAddress()
    end

    if dnsClient:CreateAddress(url, ipAddress) then
        self:GetHostLogger():LogDebug("Registered address " .. url .. " on DNS server.")
    else
        self:GetHostLogger():LogWarning("Failed to register address " .. url .. " on DNS server or already exists.")
    end
end

Utils.Class.Extend(Host, HostExtensions)

]==========],
}

return Data
