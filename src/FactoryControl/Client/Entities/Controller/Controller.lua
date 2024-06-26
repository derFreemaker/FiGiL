local UUID = require("Core.Common.UUID")

local Modify = require("FactoryControl.Client.Entities.Controller.Modify")

local ButtonDto = require("FactoryControl.Core.Entities.Controller.Feature.Button.ButtonDto")
local Button = require("FactoryControl.Client.Entities.Controller.Feature.Button.Button")

local SwitchDto = require("FactoryControl.Core.Entities.Controller.Feature.Switch.SwitchDto")
local Switch = require("FactoryControl.Client.Entities.Controller.Feature.Switch.Switch")

local RadialDto = require("FactoryControl.Core.Entities.Controller.Feature.Radial.RadialDto")
local Radial = require("FactoryControl.Client.Entities.Controller.Feature.Radial.Radial")

local ChartDto = require("FactoryControl.Core.Entities.Controller.Feature.Chart.ChartDto")
local Chart = require("FactoryControl.Client.Entities.Controller.Feature.Chart.Chart")

---@class FactoryControl.Client.Entities.Controller : FactoryControl.Client.Entities.Entity
---@field Name string
---@field IPAddress Net.IPAddress
---@field private m_featuresIds Core.UUID[]
---@field private m_features table<string, FactoryControl.Client.Entities.Controller.Feature>
---@overload fun(controllerDto: FactoryControl.Core.Entities.ControllerDto, client: FactoryControl.Client) : FactoryControl.Client.Entities.Controller
local Controller = {}

---@private
---@param controllerDto FactoryControl.Core.Entities.ControllerDto
---@param client FactoryControl.Client
---@param super FactoryControl.Client.Entities.Entity.Constructor
function Controller:__init(super, controllerDto, client)
    super(controllerDto.Id, client)

    self.Name = controllerDto.Name
    self.IPAddress = controllerDto.IPAddress
    self.m_featuresIds = controllerDto.Features
end

---@param func fun(modify: FactoryControl.Client.Entities.Controller.Modify)
function Controller:Modify(func)
    local modify = Modify(self.Name, self.IPAddress, self.m_featuresIds)

    func(modify)

    self.m_client:ModfiyControllerById(self.Id, modify:ToDto())
end

---@return Core.UUID[]
function Controller:GetFeatureIds()
    return self.m_featuresIds
end

---@return FactoryControl.Client.Entities.Controller.Feature[]
function Controller:GetFeatures()
    if self.m_features then
        return self.m_features
    end

    local features = {}
    for _, feature in pairs(self.m_client:GetFeatureByIds(self.m_featuresIds) or {}) do
        features[feature.Id:ToString()] = feature
    end

    self.m_features = features
    return self.m_features
end

---@param name string
---@return FactoryControl.Client.Entities.Controller.Feature | nil feature
function Controller:GetFeatureByName(name)
    for _, feature in pairs(self:GetFeatures()) do
        if feature.Name == name then
            return feature
        end
    end
end

---@param name string
---@return FactoryControl.Client.Entities.Controller.Feature.Button | nil button
function Controller:AddButton(name)
    local buttonDto = ButtonDto(UUID.Static__New(), name, self.Id)
    local button = self.m_client:CreateFeature(Button(buttonDto, self.m_client))
    ---@cast button FactoryControl.Client.Entities.Controller.Feature.Button | nil
    return button
end

---@param name string
---@param isEnabled boolean?
---@return FactoryControl.Client.Entities.Controller.Feature.Switch | nil switch
function Controller:AddSwitch(name, isEnabled)
    if isEnabled == nil then
        isEnabled = false
    end

    local switchDto = SwitchDto(UUID.Static__New(), name, self.Id, isEnabled)
    local switch = self.m_client:CreateFeature(Switch(switchDto, self.m_client))
    ---@cast switch FactoryControl.Client.Entities.Controller.Feature.Switch | nil
    return switch
end

---@param name string
---@param data FactoryControl.Client.Entities.Controller.Feature.Radial.Data?
---@return FactoryControl.Client.Entities.Controller.Feature.Radial | nil radial
function Controller:AddRadial(name, data)
    if data == nil then
        data = {}
    end
    local min = data.Min or 0
    local max = data.Max or 1
    local setting = data.Setting or 1

    if max < min then
        error("max (" .. max .. ") cannot be smaller then min (" .. min .. ")", 2)
    end

    if setting < min or setting > max then
        error("setting (" .. setting .. ") is out of bounds of " .. min .. " - " .. max, 2)
    end

    local radialDto = RadialDto(UUID.Static__New(), name, self.Id, min, max, setting)
    local radial = self.m_client:CreateFeature(Radial(radialDto, self.m_client))
    ---@cast radial FactoryControl.Client.Entities.Controller.Feature.Radial | nil
    return radial
end

---@param name string
---@param data FactoryControl.Client.Entities.Controller.Feature.Chart.Data | nil
---@return FactoryControl.Client.Entities.Controller.Feature.Chart | nil chart
function Controller:AddChart(name, data)
    data = data or {}
    local xAxisName = data.XAxisName or "X"
    local yAxisName = data.YAxisName or "Y"
    data = data.Data or {}

    local chartDto = ChartDto(UUID.Static__New(), name, self.Id, xAxisName, yAxisName, data)
    local chart = self.m_client:CreateFeature(Chart(chartDto, self.m_client))
    ---@cast chart FactoryControl.Client.Entities.Controller.Feature.Chart | nil
    return chart
end

return class("FactoryControl.Client.Entities.Controller", Controller,
    { Inherit = require("FactoryControl.Client.Entities.Entity") })

-- //TODO: implement some kind of status like online and offline
