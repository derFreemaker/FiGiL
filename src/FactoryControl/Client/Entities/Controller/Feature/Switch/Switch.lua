local Update = require("FactoryControl.Client.Entities.Controller.Feature.Switch.Update")

---@class FactoryControl.Client.Entities.Controller.Feature.Switch : FactoryControl.Client.Entities.Controller.Feature
---@field private _IsEnabled boolean
---@field private _Old_IsEnabled boolean
---@overload fun(switchDto: FactoryControl.Core.Entities.Controller.Feature.SwitchDto, controller: FactoryControl.Client.Entities.Controller) : FactoryControl.Client.Entities.Controller.Feature.Switch
local Switch = {}

---@private
---@param switchDto FactoryControl.Core.Entities.Controller.Feature.SwitchDto
---@param controller FactoryControl.Client.Entities.Controller
---@param baseFunc fun(id: Core.UUID, name: string, type: FactoryControl.Core.Entities.Controller.Feature.Type, controller: FactoryControl.Client.Entities.Controller)
function Switch:__init(baseFunc, switchDto, controller)
    baseFunc(switchDto.Id, switchDto.Name, "Button", controller)

    self._IsEnabled = switchDto.IsEnabled
    self._Old_IsEnabled = switchDto.IsEnabled
end

---@private
function Switch:Update()
    if self._IsEnabled == self._Old_IsEnabled then
        return
    end

    local update = Update(self.Id, self._IsEnabled)

    self._Client:UpdateSwitch(self.Owner.IPAddress, update)
end

---@return boolean isEnabled
function Switch:IsEnabled()
    return self._IsEnabled
end

function Switch:Enable()
    self._IsEnabled = true

    self:Update()
end

function Switch:Disable()
    self._IsEnabled = false

    self:Update()
end

function Switch:Toggle()
    self._IsEnabled = not self._IsEnabled

    self:Update()
end

return Utils.Class.CreateClass(Switch, "FactoryControl.Client.Entities.Controller.Feature.Switch",
    require("FactoryControl.Client.Entities.Controller.Feature.Feature") --[[@as FactoryControl.Client.Entities.Controller.Feature]])