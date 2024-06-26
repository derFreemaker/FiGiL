local Data={
["FactoryControl.Core.__events"] = [==========[
local JsonSerializer = require("Core.Json.JsonSerializer")

---@class FactoryControl.Core.Events : Github_Loading.Entities.Events
local Events = {}

function Events:OnLoaded()
    JsonSerializer.Static__Serializer:AddClasses({
        -- ControllerDto"s
        require("FactoryControl.Core.Entities.Controller.ControllerDto"),
        require("FactoryControl.Core.Entities.Controller.ConnectDto"),
        require("FactoryControl.Core.Entities.Controller.CreateDto"),
        require("FactoryControl.Core.Entities.Controller.ModifyDto"),

        -- FeatureDto"s
        require("FactoryControl.Core.Entities.Controller.Feature.Switch.SwitchDto"),
        require("FactoryControl.Core.Entities.Controller.Feature.Button.ButtonDto"),
        require("FactoryControl.Core.Entities.Controller.Feature.Radial.RadialDto"),
        require("FactoryControl.Core.Entities.Controller.Feature.Chart.ChartDto"),

        -- Feature Updates
        require("FactoryControl.Core.Entities.Controller.Feature.Button.Update"),
        require("FactoryControl.Core.Entities.Controller.Feature.Switch.Update"),
        require("FactoryControl.Core.Entities.Controller.Feature.Radial.Update"),
        require("FactoryControl.Core.Entities.Controller.Feature.Chart.Update"),
    })

    require("FactoryControl.Core.Extensions.NetworkContextExtensions")
end

return Events

]==========],
["FactoryControl.Core.Config"] = [==========[
return {
	DOMAIN = "FactoryControl.com",
	CallbackServiceNameForFeatures = "Features",
}

]==========],
["FactoryControl.Core.EndpointUrls"] = [==========[
---@class FactoryControl.Core.EndpointUrlTemplates
local EndpointUrlTemplates = {}

---@class FactoryControl.Core.EndpointUrlConstructors
local EndpointUrlConstructors = {}

--------------------------------------------------------------
-- Controller
--------------------------------------------------------------

---@class FactoryControl.Core.EndpointUrlTemplates.Controller
local ControllerTemplates = {}

---@class FactoryControl.Core.EndpointUrlConstructors.Controller
local ControllerConstructors = {}

ControllerTemplates.Connect = "/Controller/Connect"
function ControllerConstructors.Connect()
    return "/Controller/Connect"
end

ControllerTemplates.Create = "/Controller/Create"
function ControllerConstructors.Create()
    return "/Controller/Create"
end

ControllerTemplates.Delete = "/Controller/{id:Core.UUID}/Delete"
---@param id Core.UUID
function ControllerConstructors.Delete(id)
    return "/Controller/" .. id:ToString() .. "/Delete"
end

ControllerTemplates.Modify = "/Controller/{id:Core.UUID}/Modify"
---@param id Core.UUID
function ControllerConstructors.Modify(id)
    return "/Controller/" .. id:ToString() .. "/Modify"
end

ControllerTemplates.GetById = "/Controller/{id:Core.UUID}"
---@param id Core.UUID
function ControllerConstructors.GetById(id)
    return "/Controller/" .. id:ToString()
end

ControllerTemplates.GetByName = "/Controller/GetWithName/{name:string}"
---@param name string
function ControllerConstructors.GetByName(name)
    return "/Controller/GetWithName/" .. name
end

EndpointUrlTemplates.Controller = ControllerTemplates
EndpointUrlConstructors.Controller = ControllerConstructors

--------------------------------------------------------------
-- Features
--------------------------------------------------------------

---@class FactoryControl.Core.EndpointUrlTemplates.Feature
local FeatureTemplates = {}

---@class FactoryControl.Core.EndpointUrlConstructors.Feature
local FeatureConstructors = {}

FeatureTemplates.Watch = "/Feature/{id:Core.UUID}/Watch"
---@param featureId Core.UUID
function FeatureConstructors.Watch(featureId)
    return "/Feature/" .. featureId:ToString() .. "/Watch"
end

FeatureTemplates.Unwatch = "/Feature/{id:Core.UUID}/Unwatch"
---@param featureId Core.UUID
function FeatureConstructors.Unwatch(featureId)
    return "/Feature/" .. featureId:ToString() .. "/Unwatch"
end

FeatureTemplates.Create = "/Feature/Create"
function FeatureConstructors.Create()
    return "/Feature/Create"
end

FeatureTemplates.Delete = "/Feature/{id:Core.UUID}/Delete"
---@param id Core.UUID
function FeatureConstructors.Delete(id)
    return "/Feature/" .. id:ToString() .. "/Delete"
end

FeatureTemplates.GetById = "/Feature/GetByIds"
function FeatureConstructors.GetByIds()
    return "/Feature/GetByIds"
end

EndpointUrlTemplates.Feature = FeatureTemplates
EndpointUrlConstructors.Feature = FeatureConstructors

return { EndpointUrlTemplates, EndpointUrlConstructors }

]==========],
["FactoryControl.Core.Entities.Controller.ConnectDto"] = [==========[
---@class FactoryControl.Core.Entities.Controller.ConnectDto : object, Core.Json.Serializable
---@field Name string
---@field IPAddress Net.IPAddress
---@overload fun(name: string, ipAddress: Net.IPAddress) : FactoryControl.Core.Entities.Controller.ConnectDto
local ConnectDto = {}

---@private
---@param name string
---@param ipAddress Net.IPAddress
function ConnectDto:__init(name, ipAddress)
    self.Name = name
    self.IPAddress = ipAddress
end

---@return string name, Net.IPAddress ipAddress
function ConnectDto:Serialize()
    return self.Name, self.IPAddress
end

return class("FactoryControl.Core.Entities.Controller.ConnectDto", ConnectDto,
    { Inherit = require("Core.Json.Serializable") })

]==========],
["FactoryControl.Core.Entities.Controller.ControllerDto"] = [==========[
---@class FactoryControl.Core.Entities.ControllerDto : object, Core.Json.Serializable
---@field Id Core.UUID
---@field Name string
---@field IPAddress Net.IPAddress
---@field Features Core.UUID[]
---@overload fun(id: Core.UUID, name: string, ipAddress: Net.IPAddress, features: Core.UUID[]?) : FactoryControl.Core.Entities.ControllerDto
local ControllerDto = {}

---@alias FactoryControl.Core.Entities.ControllerDto.Constructor fun(id: Core.UUID, name: string, ipAddress: Net.IPAddress, features: Core.UUID[]?) : FactoryControl.Core.Entities.ControllerDto

---@private
---@param id Core.UUID
---@param name string
---@param ipAddress Net.IPAddress
---@param features Core.UUID[]?
function ControllerDto:__init(id, name, ipAddress, features)
    self.Id = id
    self.Name = name
    self.IPAddress = ipAddress
    self.Features = features or {}
end

---@return Core.UUID id, string name, Net.IPAddress ipAddress, Core.UUID[] features
function ControllerDto:Serialize()
    return self.Id, self.Name, self.IPAddress, self.Features
end

return class("FactoryControl.Core.Entities.ControllerDto", ControllerDto,
    { IsAbstract = true, Inherit = require("Core.Json.Serializable") })

]==========],
["FactoryControl.Core.Entities.Controller.CreateDto"] = [==========[
---@class FactoryControl.Core.Entities.Controller.CreateDto : object, Core.Json.Serializable
---@field Name string
---@field IPAddress Net.IPAddress
---@field Features table<string, FactoryControl.Core.Entities.Controller.FeatureDto>
---@overload fun(name: string, ipAddress: Net.IPAddress, features: table<string, FactoryControl.Core.Entities.Controller.FeatureDto>?) : FactoryControl.Core.Entities.Controller.CreateDto
local ControllerDto = {}

---@private
---@param name string
---@param ipAddress Net.IPAddress
---@param features table<string, FactoryControl.Core.Entities.Controller.FeatureDto>?
function ControllerDto:__init(name, ipAddress, features)
    self.Name = name
    self.IPAddress = ipAddress
    self.Features = features or {}
end

---@return string name, Net.IPAddress ipAddress, table<string, FactoryControl.Core.Entities.Controller.FeatureDto> features
function ControllerDto:Serialize()
    return self.Name, self.IPAddress, self.Features
end

return class("FactoryControl.Core.Entities.Controller.CreateDto", ControllerDto,
    { Inherit = require("Core.Json.Serializable") })

]==========],
["FactoryControl.Core.Entities.Controller.ModifyDto"] = [==========[
---@class FactoryControl.Core.Entities.Controller.ModifyDto : object, Core.Json.Serializable
---@field Name string
---@field IPAddress Net.IPAddress
---@field Features Core.UUID[]
---@overload fun(name: string, ipAddress: Net.IPAddress, features: Core.UUID[]) : FactoryControl.Core.Entities.Controller.ModifyDto
local ModifyDto = {}

---@private
---@param name string
---@param ipAddress Net.IPAddress
---@param features Core.UUID[]
function ModifyDto:__init(name, ipAddress, features)
    self.Name = name
    self.IPAddress = ipAddress
    self.Features = features
end

---@return string name, Net.IPAddress ipAddress, table<Core.UUID, FactoryControl.Core.Entities.Controller.FeatureDto> features
function ModifyDto:Serialize()
    return self.Name, self.IPAddress, self.Features
end

return class("FactoryControl.Core.Entities.Controller.ModifyDto", ModifyDto,
    { Inherit = require("Core.Json.Serializable") })

]==========],
["FactoryControl.Core.Entities.Controller.Feature.Dto"] = [==========[
---@alias FactoryControl.Core.Entities.Controller.Feature.Type
---|"Switch"
---|"Button"
---|"Radial"
---|"Chart"

---@class FactoryControl.Core.Entities.Controller.FeatureDto : object, Core.Json.Serializable
---@field Id Core.UUID
---@field Name string
---@field Type FactoryControl.Core.Entities.Controller.Feature.Type
---@field ControllerId Core.UUID
---@overload fun(id: Core.UUID, name: string, type: FactoryControl.Core.Entities.Controller.Feature.Type) : FactoryControl.Core.Entities.Controller.FeatureDto
local FeatureDto = {}

---@alias FactoryControl.Core.Entities.Controller.FeatureDto.Constructor fun(id: Core.UUID, name: string, type: FactoryControl.Core.Entities.Controller.Feature.Type, controllerId: Core.UUID)

---@private
---@param id Core.UUID
---@param name string
---@param type FactoryControl.Core.Entities.Controller.Feature.Type
---@param controllerId Core.UUID
function FeatureDto:__init(id, name, type, controllerId)
    self.Id = id
    self.Name = name
    self.Type = type
    self.ControllerId = controllerId
end

---@param featureUpdate FactoryControl.Core.Entities.Controller.Feature.Update
function FeatureDto:OnUpdate(featureUpdate)
    error("OnUpdate not implemented")
end
FeatureDto.OnUpdate = Utils.Class.IsAbstract

return class("FactoryControl.Core.Entities.Controller.FeatureDto", FeatureDto,
    { IsAbstract = true, Inherit = require("Core.Json.Serializable") })

]==========],
["FactoryControl.Core.Entities.Controller.Feature.Update"] = [==========[
---@class FactoryControl.Core.Entities.Controller.Feature.Update : object, Core.Json.Serializable
---@field FeatureId Core.UUID
local Update = {}

---@alias FactoryControl.Core.Entities.Controller.Feature.Update.Constructor fun(featureId: Core.UUID) : FactoryControl.Core.Entities.Controller.Feature.Update

---@private
---@param featureId Core.UUID
function Update:__init(featureId)
    self.FeatureId = featureId
end

return class("FactoryControl.Core.Entities.Controller.Feature.Update", Update,
    { IsAbstract = true, Inherit = require("Core.Json.Serializable") })

]==========],
["FactoryControl.Core.Entities.Controller.Feature.Button.ButtonDto"] = [==========[
---@class FactoryControl.Core.Entities.Controller.Feature.ButtonDto : FactoryControl.Core.Entities.Controller.FeatureDto
---@overload fun(id: Core.UUID, name: string, controllerId: Core.UUID) : FactoryControl.Core.Entities.Controller.Feature.ButtonDto
local ButtonDto = {}

---@private
---@param id Core.UUID
---@param name string
---@param controllerId Core.UUID
---@param super FactoryControl.Core.Entities.Controller.FeatureDto.Constructor
function ButtonDto:__init(super, id, name, controllerId)
    super(id, name, "Button", controllerId)
end

---@param featureUpdate FactoryControl.Core.Entities.Controller.Feature.Button.Update
function ButtonDto:OnUpdate(featureUpdate)
end

---@return Core.UUID id, string name, Core.UUID controllerId
function ButtonDto:Serialize()
    return self.Id, self.Name, self.ControllerId
end

return class("FactoryControl.Core.Entities.Controller.Feature.ButtonDto", ButtonDto,
    { Inherit = require("FactoryControl.Core.Entities.Controller.Feature.Dto") })

]==========],
["FactoryControl.Core.Entities.Controller.Feature.Button.Update"] = [==========[
---@class FactoryControl.Core.Entities.Controller.Feature.Button.Update : FactoryControl.Core.Entities.Controller.Feature.Update
---@overload fun(id: Core.UUID) : FactoryControl.Core.Entities.Controller.Feature.Button.Update
local Update = {}

---@private
---@param id Core.UUID
---@param super FactoryControl.Core.Entities.Controller.Feature.Update.Constructor
function Update:__init(super, id)
    super(id)
end

---@return Core.UUID id
function Update:Serialize()
    return self.FeatureId
end

return class("FactoryControl.Core.Entities.Controller.Feature.Button.Update", Update,
    { Inherit = require("FactoryControl.Core.Entities.Controller.Feature.Update") })

]==========],
["FactoryControl.Core.Entities.Controller.Feature.Chart.ChartDto"] = [==========[
---@class FactoryControl.Core.Entities.Controller.Feature.ChartDto : FactoryControl.Core.Entities.Controller.FeatureDto
---@field XAxisName string
---@field YAxisName string
---@field Data FactoryControl.Core.Entities.Controller.Feature.ChartDto.DataType | nil
---@overload fun(id: Core.UUID, name: string, controllerId: Core.UUID, xAxisName: string, yAxisName: string, data: FactoryControl.Core.Entities.Controller.Feature.ChartDto.DataType | nil) : FactoryControl.Core.Entities.Controller.Feature.ChartDto
local ChartDto = {}

---@alias FactoryControl.Core.Entities.Controller.Feature.ChartDto.DataType table<number, number>

---@private
---@param id Core.UUID
---@param name string
---@param controllerId Core.UUID
---@param xAxisName string
---@param yAxisName string
---@param data FactoryControl.Core.Entities.Controller.Feature.ChartDto.DataType | nil
---@param super FactoryControl.Core.Entities.Controller.FeatureDto.Constructor
function ChartDto:__init(super, id, name, controllerId, xAxisName, yAxisName, data)
    super(id, name, "Chart", controllerId)

    self.XAxisName = xAxisName
    self.YAxisName = yAxisName
    self.Data = data or {}
end

---@param featureUpdate FactoryControl.Core.Entities.Controller.Feature.Chart.Update
function ChartDto:OnUpdate(featureUpdate)
    self.Data = featureUpdate.Data or {}
end

---@return Core.UUID id, string name, Core.UUID controllerId, string xAxisName, string yAxisName, FactoryControl.Core.Entities.Controller.Feature.ChartDto.DataType data
function ChartDto:Serialize()
    return self.Id, self.Name, self.ControllerId, self.XAxisName, self.YAxisName, self.Data
end

return class("FactoryControl.Core.Entities.Controller.Feature.ChartDto", ChartDto,
    { Inherit = require("FactoryControl.Core.Entities.Controller.Feature.Dto") })

]==========],
["FactoryControl.Core.Entities.Controller.Feature.Chart.Update"] = [==========[
---@class FactoryControl.Core.Entities.Controller.Feature.Chart.Update : FactoryControl.Core.Entities.Controller.Feature.Update
---@field Data FactoryControl.Core.Entities.Controller.Feature.ChartDto.DataType | nil
---@overload fun(id: Core.UUID, data: FactoryControl.Core.Entities.Controller.Feature.ChartDto.DataType) : FactoryControl.Core.Entities.Controller.Feature.Chart.Update
local Update = {}

---@private
---@param id Core.UUID
---@param data FactoryControl.Core.Entities.Controller.Feature.ChartDto.DataType | nil
---@param super FactoryControl.Core.Entities.Controller.Feature.Update.Constructor
function Update:__init(super, id, data)
    super(id)
    self.Data = data
end

---@return Core.UUID id, FactoryControl.Core.Entities.Controller.Feature.ChartDto.DataType | nil data
function Update:Serialize()
    return self.FeatureId, self.Data
end

return class("FactoryControl.Core.Entities.Controller.Feature.Chart.Update", Update,
    { Inherit = require("FactoryControl.Core.Entities.Controller.Feature.Update") })

]==========],
["FactoryControl.Core.Entities.Controller.Feature.Radial.RadialDto"] = [==========[
---@class FactoryControl.Core.Entities.Controller.Feature.RadialDto : FactoryControl.Core.Entities.Controller.FeatureDto
---@field Min number
---@field Max number
---@field Setting number
---@overload fun(id: Core.UUID, name: string, controllerId: Core.UUID, min: number?, max: number?, setting: number?) : FactoryControl.Core.Entities.Controller.Feature.RadialDto
local RadialDto = {}

---@private
---@param id Core.UUID
---@param name string
---@param controllerId Core.UUID
---@param min number
---@param max number
---@param setting number
---@param super FactoryControl.Core.Entities.Controller.FeatureDto.Constructor
function RadialDto:__init(super, id, name, controllerId, min, max, setting)
    super(id, name, "Radial", controllerId)

    self.Min = min or 0
    self.Max = max or 1

    -- //TODO: put some where else
    -- if self.Min > self.Max then
    --     error("min: " .. self.Min .. " cannot be bigger then max: " .. self.Max)
    --     return
    -- end

    -- if setting == nil then
    --     setting = self.Min
    -- else
    --     if self.Min > setting or self.Max < setting then
    --         error("setting: " .. setting .. " is out of range: " .. self.Min .. " - " .. self.Max)
    --         return
    --     end
    -- end

    self.Setting = setting
end

---@param featureUpdate FactoryControl.Core.Entities.Controller.Feature.Radial.Update
function RadialDto:OnUpdate(featureUpdate)
    self.Min = featureUpdate.Min
    self.Max = featureUpdate.Max
    self.Setting = featureUpdate.Setting
end

---@return Core.UUID id, string name, Core.UUID controllerId, number min, number max, number setting
function RadialDto:Serialize()
    return self.Id, self.Name, self.ControllerId, self.Min, self.Max, self.Setting
end

return class("FactoryControl.Core.Entities.Controller.Feature.RadialDto", RadialDto,
    { Inherit = require("FactoryControl.Core.Entities.Controller.Feature.Dto") })

]==========],
["FactoryControl.Core.Entities.Controller.Feature.Radial.Update"] = [==========[
---@class FactoryControl.Core.Entities.Controller.Feature.Radial.Update : FactoryControl.Core.Entities.Controller.Feature.Update
---@field Min number
---@field Max number
---@field Setting number
---@overload fun(id: Core.UUID, min: number, max: number, setting: number) : FactoryControl.Core.Entities.Controller.Feature.Radial.Update
local Update = {}

---@private
---@param id Core.UUID
---@param min number
---@param max number
---@param setting number
---@param super FactoryControl.Core.Entities.Controller.Feature.Update.Constructor
function Update:__init(super, id, min, max, setting)
    super(id)

    self.Min = min
    self.Max = max
    self.Setting = setting
end

---@return Core.UUID id, number min, number max, number setting
function Update:Serialize()
    return self.FeatureId, self.Min, self.Max, self.Setting
end

return class("FactoryControl.Core.Entities.Controller.Feature.Radial.Update", Update,
    { Inherit = require("FactoryControl.Core.Entities.Controller.Feature.Update") })

]==========],
["FactoryControl.Core.Entities.Controller.Feature.Switch.SwitchDto"] = [==========[
---@class FactoryControl.Core.Entities.Controller.Feature.SwitchDto : FactoryControl.Core.Entities.Controller.FeatureDto
---@field IsEnabled boolean
---@overload fun(id: Core.UUID, name: string, controllerId: Core.UUID, isEnabled: boolean) : FactoryControl.Core.Entities.Controller.Feature.SwitchDto
local SwitchDto = {}

---@private
---@param id Core.UUID
---@param name string
---@param controllerId Core.UUID
---@param isEnabled boolean?
---@param super FactoryControl.Core.Entities.Controller.FeatureDto.Constructor
function SwitchDto:__init(super, id, name, controllerId, isEnabled)
    super(id, name, "Switch", controllerId)

    if isEnabled == nil then
        self.IsEnabled = false
        return
    end
    self.IsEnabled = isEnabled
end

---@param featureUpdate FactoryControl.Core.Entities.Controller.Feature.Switch.Update
function SwitchDto:OnUpdate(featureUpdate)
    self.IsEnabled = featureUpdate.IsEnabled
end

---@return Core.UUID id, string name, Core.UUID controllerId, boolean isEnabled
function SwitchDto:Serialize()
    return self.Id, self.Name, self.ControllerId, self.IsEnabled
end

return class("FactoryControl.Core.Entities.Controller.Feature.SwitchDto", SwitchDto,
    { Inherit = require("FactoryControl.Core.Entities.Controller.Feature.Dto") })

]==========],
["FactoryControl.Core.Entities.Controller.Feature.Switch.Update"] = [==========[
---@class FactoryControl.Core.Entities.Controller.Feature.Switch.Update : FactoryControl.Core.Entities.Controller.Feature.Update
---@field IsEnabled boolean
---@overload fun(id: Core.UUID, isEnabled: boolean) : FactoryControl.Core.Entities.Controller.Feature.Switch.Update
local Update = {}

---@private
---@param featureId Core.UUID
---@param IsEnabled boolean
---@param super FactoryControl.Core.Entities.Controller.Feature.Update.Constructor
function Update:__init(super, featureId, IsEnabled)
    super(featureId)
    self.IsEnabled = IsEnabled
end

---@return Core.UUID id, boolean isEnabled
function Update:Serialize()
    return self.FeatureId, self.IsEnabled
end

return class("FactoryControl.Core.Entities.Controller.Feature.Switch.Update", Update,
    { Inherit = require("FactoryControl.Core.Entities.Controller.Feature.Update") })

]==========],
["FactoryControl.Core.Extensions.NetworkContextExtensions"] = [==========[
---@class Net.Core.NetworkContext
local NetworkContextExtensions = {}

---@return FactoryControl.Core.Entities.Controller.Feature.Update
function NetworkContextExtensions:GetFeatureUpdate()
    return self.Body
end

Utils.Class.Extend(require("Net.Core.NetworkContext"), NetworkContextExtensions)

]==========],
}

return Data
