---@class Core.PCIDeviceReference<T> : Core.IReference<T>
---@field m_class FIN.Class
---@field m_index integer
---@overload fun(class: FIN.Class, index: integer) : Core.PCIDeviceReference
local PCIDeviceReference = {}

---@private
---@param class FIN.Class
---@param index integer
function PCIDeviceReference:__init(class, index)
    self.m_class = class
    self.m_index = index
end

---@return boolean found
function PCIDeviceReference:Fetch()
    local obj = computer.getPCIDevices(self.m_class)[self.m_index]
    self.m_obj = obj
    return obj ~= nil
end

return Utils.Class.Create(PCIDeviceReference, "Core.PCIDeviceReference",
    require("Core.References.IReference"))
