local Data={
["FactoryControl.Server.__main"] = [==========[
---@using DNS.Client

local Config = require("FactoryControl.Core.Config")
local Usage = require("Core.Usage.init")

local DatabaseAccessLayer = require("FactoryControl.Server.DatabaseAccessLayer")

local ControllerEndpoints = require("FactoryControl.Server.Endpoints.Controller")
local FeatureEndpoints = require("FactoryControl.Server.Endpoints.Feature")

local CallbackService = require("Services.Callback.Server.CallbackService")
local FeatureService = require("FactoryControl.Server.Services.FeatureService")

local Host = require("Hosting.Host")

---@class FactoryControl.Server.Main : Github_Loading.Entities.Main
---@field private m_host Hosting.Host
---@field private m_databaseAccessLayer FactoryControl.Server.DatabaseAccessLayer
local Main = {}

function Main:Configure()
	self.m_host = Host(self.Logger:subLogger("Host"), "FactoryControl Server")

	self.m_databaseAccessLayer = DatabaseAccessLayer(self.Logger:subLogger("DatabaseAccessLayer"))

	local networkClient = self.m_host:GetNetworkClient()
	local callbackService = CallbackService(self.m_host:CreateLogger("CallbackService"), networkClient)
	local featureService = FeatureService(callbackService, self.m_databaseAccessLayer, networkClient)
	self.m_host.Services:AddService(featureService)
	self.m_host:AddCallableEventTask(
		Usage.Events.FactoryControl_Feature_Update,
		Usage.Ports.FactoryControl,
		featureService.OnFeatureInvoked
	)

	self.Logger:LogDebug("started services")

	self.m_host:AddEndpoint(Usage.Ports.HTTP,
		"Controller",
		ControllerEndpoints,
		self.m_databaseAccessLayer
	)

	self.m_host:AddEndpoint(Usage.Ports.HTTP,
		"Feature",
		FeatureEndpoints,
		self.m_databaseAccessLayer,
		featureService
	)

	self.Logger:LogDebug("setup endpoints")

	self.m_host:RegisterAddress(Config.DOMAIN)
end

function Main:Run()
	self.m_host:Ready()

	local networkClient = self.m_host:GetNetworkClient()
	while true do
		networkClient:BroadCast(
			Usage.Ports.FactoryControl_Heartbeat,
			Usage.Events.FactoryControl_Heartbeat
		)

		self.m_host:RunCycle(1)

		self.m_databaseAccessLayer:Save()
	end
end

return Main

]==========],
["FactoryControl.Server.DatabaseAccessLayer"] = [==========[
local DbTable = require("Database.DbTable")
local Path = require("Core.FileSystem.Path")
local UUID = require("Core.Common.UUID")

local ControllerDto = require("FactoryControl.Core.Entities.Controller.ControllerDto")

---@class FactoryControl.Server.DatabaseAccessLayer : object
---@field private m_controllers Database.DbTable
---@field private m_features Database.DbTable
---@field private m_logger Core.Logger
---@overload fun(logger: Core.Logger) : FactoryControl.Server.DatabaseAccessLayer
local DatabaseAccessLayer = {}

---@private
---@param logger Core.Logger
function DatabaseAccessLayer:__init(logger)
    self.m_controllers = DbTable(Path("/Database/Controllers/"), logger:subLogger("ControllerTable"))
    self.m_features = DbTable(Path("/Database/Features/"), logger:subLogger("FeaturesTable"))
    self.m_logger = logger

    self.m_controllers:Load()
    self.m_features:Load()
end

function DatabaseAccessLayer:Save()
    self.m_controllers:Save()
    self.m_features:Save()
end

--------------------------------------------------------------
-- Controller
--------------------------------------------------------------

---@param createController FactoryControl.Core.Entities.Controller.CreateDto
---@return FactoryControl.Core.Entities.ControllerDto? controller
function DatabaseAccessLayer:CreateController(createController)
    local controller = ControllerDto(UUID.Static__New(), createController.Name,
        createController.IPAddress, createController.Features)

    if self:GetControllerByName(createController.Name) then
        return nil
    end

    self.m_controllers:Set(controller.Id:ToString(), controller)

    return controller
end

---@param controllerId Core.UUID
function DatabaseAccessLayer:DeleteController(controllerId)
    self.m_controllers:Delete(controllerId:ToString())
end

---@param controllerId Core.UUID
---@return FactoryControl.Core.Entities.ControllerDto? controller
function DatabaseAccessLayer:GetControllerById(controllerId)
    return self.m_controllers:Get(controllerId:ToString())
end

---@param controllerName string
---@return FactoryControl.Core.Entities.ControllerDto? controller
function DatabaseAccessLayer:GetControllerByName(controllerName)
    for _, controller in pairs(self.m_controllers) do
        ---@cast controller FactoryControl.Core.Entities.ControllerDto

        if controller.Name == controllerName then
            return controller
        end
    end
end

--------------------------------------------------------------
-- Feature
--------------------------------------------------------------

---@param feature FactoryControl.Core.Entities.Controller.FeatureDto
---@return FactoryControl.Core.Entities.Controller.FeatureDto feature
function DatabaseAccessLayer:CreateFeature(feature)
    if self:GetFeatureById(feature.Id) then
        feature.Id = UUID.Static__New()
    end

    self.m_features:Set(feature.Id:ToString(), feature)

    return feature
end

---@param featureId Core.UUID
---@return boolean success
function DatabaseAccessLayer:DeleteFeature(featureId)
    return self.m_features:Delete(featureId:ToString())
end

---@param featureId Core.UUID
---@return FactoryControl.Core.Entities.Controller.FeatureDto feature
function DatabaseAccessLayer:GetFeatureById(featureId)
    return self.m_features:Get(featureId:ToString())
end

---@param featureIds Core.UUID[]
---@return FactoryControl.Core.Entities.Controller.FeatureDto[] features
function DatabaseAccessLayer:GetFeatureByIds(featureIds)
    ---@type FactoryControl.Core.Entities.Controller.FeatureDto[]
    local features = {}

    for _, id in pairs(featureIds) do
        table.insert(features, self:GetFeatureById(id))
    end

    return features
end

return class("FactoryControl.Server.Database", DatabaseAccessLayer)

]==========],
["FactoryControl.Server.Endpoints.Controller"] = [==========[
local ControllerUrlTemplates = require("FactoryControl.Core.EndpointUrls")[1].Controller

---@class FactoryControl.Server.Endpoints.Controller : Net.Rest.Api.Server.EndpointBase
---@field private m_databaseAccessLayer FactoryControl.Server.DatabaseAccessLayer
---@field private m_logger Core.Logger
---@overload fun(logger: Core.Logger, apiController: Net.Rest.Api.Server.Controller, databaseAccessLayer: FactoryControl.Server.DatabaseAccessLayer) : FactoryControl.Server.Endpoints.Controller
local ControllerEndpoints = {}

---@private
---@param logger Core.Logger
---@param apiController Net.Rest.Api.Server.Controller
---@param databaseAccessLayer FactoryControl.Server.DatabaseAccessLayer
---@param super fun(endpointLogger: Core.Logger, apiController: Net.Rest.Api.Server.Controller)
function ControllerEndpoints:__init(super, logger, apiController, databaseAccessLayer)
	super(logger, apiController)

	self.m_databaseAccessLayer = databaseAccessLayer

	self:AddEndpoint("CONNECT", ControllerUrlTemplates.Connect, self.Connect)

	self:AddEndpoint("CREATE", ControllerUrlTemplates.Create, self.Create)
	self:AddEndpoint("DELETE", ControllerUrlTemplates.Delete, self.Delete)
	self:AddEndpoint("POST", ControllerUrlTemplates.Modify, self.Modify)
	self:AddEndpoint("GET", ControllerUrlTemplates.GetById, self.GetById)
	self:AddEndpoint("GET", ControllerUrlTemplates.GetByName, self.GetByName)
end

---@param connect FactoryControl.Core.Entities.Controller.ConnectDto
---@return Net.Rest.Api.Response response
function ControllerEndpoints:Connect(connect)
	local controller = self.m_databaseAccessLayer:GetControllerByName(connect.Name)
	if not controller then
		return self.Templates:NotFound("Controller with Name: " .. connect.Name .. " was not found.")
	end

	if controller.IPAddress ~= connect.IPAddress then
		controller.IPAddress = connect.IPAddress
	end

	return self.Templates:Ok(controller)
end

---@param createController FactoryControl.Core.Entities.Controller.CreateDto
---@return Net.Rest.Api.Response response
function ControllerEndpoints:Create(createController)
	local controller = self.m_databaseAccessLayer:CreateController(createController)

	if not controller then
		return self.Templates:BadRequest("Controller with Name: " .. createController.Name .. " already exists.")
	end

	return self.Templates:Ok(controller)
end

---@param id Core.UUID
---@return Net.Rest.Api.Response response
function ControllerEndpoints:Delete(id)
	self.m_databaseAccessLayer:DeleteController(id)

	return self.Templates:Ok(true)
end

---@param id Core.UUID
---@param modifyController FactoryControl.Core.Entities.Controller.ModifyDto
---@return Net.Rest.Api.Response response
function ControllerEndpoints:Modify(id, modifyController)
	local controller = self.m_databaseAccessLayer:GetControllerById(id)

	if not controller then
		return self.Templates:NotFound("Controller with id: " .. tostring(id) .. " was not found.")
	end

	controller.Features = modifyController.Features

	return self.Templates:Ok(controller)
end

---@param id Core.UUID
---@return Net.Rest.Api.Response response
function ControllerEndpoints:GetById(id)
	local controller = self.m_databaseAccessLayer:GetControllerById(id)

	if not controller then
		return self.Templates:NotFound("Controller with id: " .. tostring(id) .. " was not found.")
	end

	return self.Templates:Ok(controller)
end

---@param name string
---@return Net.Rest.Api.Response response
function ControllerEndpoints:GetByName(name)
	local controller = self.m_databaseAccessLayer:GetControllerByName(name)

	if not controller then
		return self.Templates:NotFound("Controller with name: " .. name .. " was not found.")
	end

	return self.Templates:Ok(controller)
end

return class("FactoryControl.Server.Endpoints.Controller", ControllerEndpoints,
	{ Inherit = require("Net.Rest.Api.Server.EndpointBase") })

]==========],
["FactoryControl.Server.Endpoints.Feature"] = [==========[
local FeatureUrlTemplates = require("FactoryControl.Core.EndpointUrls")[1].Feature

---@class FactoryControl.Server.Endpoints.Feature : Net.Rest.Api.Server.EndpointBase
---@field m_databaseAccessLayer FactoryControl.Server.DatabaseAccessLayer
---@field m_featureService FactoryControl.Server.Services.FeatureService
local FeatureEndpoints = {}

---@private
---@param logger Core.Logger
---@param apiController Net.Rest.Api.Server.Controller
---@param databaseAccessLayer FactoryControl.Server.DatabaseAccessLayer
---@param featureService FactoryControl.Server.Services.FeatureService
---@param super Net.Rest.Api.Server.EndpointBase.Constructor
function FeatureEndpoints:__init(super, logger, apiController, databaseAccessLayer, featureService)
    super(logger, apiController)

    self.m_databaseAccessLayer = databaseAccessLayer
    self.m_featureService = featureService

    self:AddEndpoint("POST", FeatureUrlTemplates.Watch, self.Watch)
    self:AddEndpoint("POST", FeatureUrlTemplates.Unwatch, self.Unwatch)

    self:AddEndpoint("CREATE", FeatureUrlTemplates.Create, self.Create)
    self:AddEndpoint("DELETE", FeatureUrlTemplates.Delete, self.Delete)
    self:AddEndpoint("GET", FeatureUrlTemplates.GetById, self.GetByIds)
end

---@param featureId Core.UUID
---@param ipAddress Net.IPAddress
---@return Net.Rest.Api.Response response
function FeatureEndpoints:Watch(featureId, ipAddress)
    self.m_featureService:Watch(featureId, ipAddress)
    return self.Templates:Ok(true)
end

---@param featureId Core.UUID
---@param ipAddress Net.IPAddress
---@return Net.Rest.Api.Response response
function FeatureEndpoints:Unwatch(featureId, ipAddress)
    self.m_featureService:Unwatch(featureId, ipAddress)
    return self.Templates:Ok(true)
end

---@param feature FactoryControl.Core.Entities.Controller.FeatureDto
---@return Net.Rest.Api.Response response
function FeatureEndpoints:Create(feature)
    feature = self.m_databaseAccessLayer:CreateFeature(feature)
    return self.Templates:Ok(feature)
end

---@param id Core.UUID
---@return Net.Rest.Api.Response response
function FeatureEndpoints:Delete(id)
    self.m_databaseAccessLayer:DeleteFeature(id)
    return self.Templates:Ok(true)
end

---@param featureIds Core.UUID[]
---@return Net.Rest.Api.Response response
function FeatureEndpoints:GetByIds(featureIds)
    local features = self.m_databaseAccessLayer:GetFeatureByIds(featureIds)

    return self.Templates:Ok(features)
end

return class("FactoryControl.Server.Endpoints.Feature", FeatureEndpoints,
    { Inherit =  require("Net.Rest.Api.Server.EndpointBase") })

]==========],
["FactoryControl.Server.Services.FeatureService"] = [==========[
local Usage = require("Core.Usage.init")
local Config = require("FactoryControl.Core.Config")

local Task = require("Core.Common.Task")

---@class FactoryControl.Server.Services.FeatureService : object
---@field OnFeatureInvoked Core.Task<Net.Core.NetworkContext>
---@field private m_watchedFeatures table<string, Net.IPAddress[]>
---@field private m_callbackService Services.Callback.Server.CallbackService
---@field private m_databaseAccessLayer FactoryControl.Server.DatabaseAccessLayer
---@field private m_networkClient Net.Core.NetworkClient
---@overload fun(callbackService: Services.Callback.Server.CallbackService, databaseAccessLayer: FactoryControl.Server.DatabaseAccessLayer, networkClient: Net.Core.NetworkClient) : FactoryControl.Server.Services.FeatureService
local FeatureService = {}

---@private
---@param callbackService Services.Callback.Server.CallbackService
---@param databaseAccessLayer FactoryControl.Server.DatabaseAccessLayer
---@param networkClient Net.Core.NetworkClient
function FeatureService:__init(callbackService, databaseAccessLayer, networkClient)
    self.m_watchedFeatures = {}
    self.m_callbackService = callbackService
    self.m_databaseAccessLayer = databaseAccessLayer
    self.m_networkClient = networkClient

    self.OnFeatureInvoked = Task(function(...)
        self:onFeatureInvoked(...)
    end)
end

---@param featureId Core.UUID
---@param ipAddress Net.IPAddress
function FeatureService:Watch(featureId, ipAddress)
    local ipAddresses = self.m_watchedFeatures[featureId:ToString()]
    if not ipAddresses then
        ipAddresses = {}
        self.m_watchedFeatures[featureId:ToString()] = ipAddresses
    end

    table.insert(ipAddresses, ipAddress)
end

---@param featureId Core.UUID
---@param ipAddress Net.IPAddress
function FeatureService:Unwatch(featureId, ipAddress)
    local ipAddresses = self.m_watchedFeatures[featureId:ToString()]
    if not ipAddresses then
        return
    end

    for i, ip in ipairs(ipAddresses) do
        if ip == ipAddress then
            table.remove(ipAddresses, i)
            return
        end
    end
end

---@private
---@param context Net.Core.NetworkContext
function FeatureService:onFeatureInvoked(context)
    local featureUpdate = context:GetFeatureUpdate()

    local feature = self.m_databaseAccessLayer:GetFeatureById(featureUpdate.FeatureId)
    if not feature then
        self.m_watchedFeatures[featureUpdate.FeatureId:ToString()] = nil
    end

    feature:OnUpdate(featureUpdate)

    self:SendToController(feature, featureUpdate)
    self:SendToWachters(featureUpdate)
end

---@param feature FactoryControl.Core.Entities.Controller.FeatureDto
---@param featureUpdate FactoryControl.Core.Entities.Controller.Feature.Update
function FeatureService:SendToController(feature, featureUpdate)
    local controller = self.m_databaseAccessLayer:GetControllerById(feature.ControllerId)
    if not controller then
        return
    end

    self.m_callbackService:Send(
        feature.Id,
        Usage.Events.FactoryControl_Feature_Update,
        Config.CallbackServiceNameForFeatures,
        controller.IPAddress,
        { featureUpdate }
    )
end

---@param featureUpdate FactoryControl.Core.Entities.Controller.Feature.Update
function FeatureService:SendToWachters(featureUpdate)
    local ipAddresses = self.m_watchedFeatures[featureUpdate.FeatureId:ToString()]
    if not ipAddresses then
        return
    end

    for _, ipAddress in ipairs(ipAddresses) do
        self.m_callbackService:Send(
            featureUpdate.FeatureId,
            Usage.Events.FactoryControl_Feature_Update,
            Config.CallbackServiceNameForFeatures,
            ipAddress,
            { featureUpdate }
        )
    end
end

return class("FactoryControl.Server.Services.FeatureService", FeatureService)

]==========],
}

return Data
