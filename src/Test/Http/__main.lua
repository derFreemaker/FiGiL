local Uri = require('Net.Rest.Uri')

local EventPullAdapter = require('Core.Event.EventPullAdapter')
local NetworkClient = require('Net.Core.NetworkClient')
local DNSClient = require('DNS.Client.Client')
local HttpClient = require('Net.Http.Client')
local HttpRequest = require('Net.Http.Request')

---@class Test.Http.Main : Github_Loading.Entities.Main
---@field private m_netClient Net.Core.NetworkClient
---@field private m_dnsClient DNS.Client
---@field private m_httpClient Net.Http.Client
local Main = {}

function Main:Configure()
	EventPullAdapter:Initialize(self.Logger:subLogger('EventPullAdapter'))

	self.m_netClient = NetworkClient(self.Logger:subLogger('NetworkClient'))
	self.m_dnsClient = DNSClient(self.m_netClient, self.Logger:subLogger('DNSClient'))
	self.m_httpClient = HttpClient(self.Logger:subLogger('HttpClient'), self.m_dnsClient)
end

function Main:Run()
	local domain = 'factoryControl.de'

	log("waiting for heartbeat")
	self.m_dnsClient.Static__WaitForHeartbeat(self.m_netClient)
	log("got heartbeat")

	local ipAddress = self.m_dnsClient:GetOrRequestDNSServerIP()
	log(ipAddress)



	log("creating address")
	local success = self.m_dnsClient:CreateAddress(domain, self.m_netClient:GetIPAddress())
	if not success then
		log('unable to create address on dns server or allready exists')
	else
		log("created address")
	end

	local dnsServerAddress = self.m_dnsClient:GetOrRequestDNSServerIP()
	log("dns server address", dnsServerAddress)

	local request = HttpRequest('GET', 'AddressWithAddress', Uri.Static__Parse(dnsServerAddress:GetAddress()), domain)
	local response = self.m_httpClient:Send(request)
	assert(response:IsSuccess(), 'http request was not successfull')

	---@type DNS.Core.Entities.Address
	local address = response:GetBody()
	assert(address.IPAddress:Equals(self.m_netClient:GetIPAddress()),
		"got wrong address id back from dns server '" .. tostring(address.Id) .. "'")

	log(address.Id, address.Url, address.IPAddress)
end

return Main
