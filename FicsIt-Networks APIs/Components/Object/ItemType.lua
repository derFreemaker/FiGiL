---@meta

---@alias FicsIt_Networks.Components.ItemType.Form
---|1 Solid
---|2 Liquid
---|3 Gas
---|4 Heat

--- The type of an item (iron plate, iron rod, leaves)
---@class FicsIt_Networks.Components.ItemType : FicsIt_Networks.Components.Object
local ItemType = {}

--- The matter state of this resource.
--- ### Flags:
--- * Runtime Synchronous - Can be called/changed in Game Tick
--- * Runtime Parallel - Can be called/changed in Satisfactory Factory Tick
--- * Read Only - The value of this property can not be changed by code
---@type FicsIt_Networks.Components.ItemType.Form
ItemType.form = nil

--- How much energy this resource provides if used as fuel.
--- ### Flags:
--- * Runtime Synchronous - Can be called/changed in Game Tick
--- * Runtime Parallel - Can be called/changed in Satisfactory Factory Tick
--- * Read Only - The value of this property can not be changed by code
---@type float
ItemType.energy = nil

--- The amount of radiation this item radiates.
--- ### Flags:
--- * Runtime Synchronous - Can be called/changed in Game Tick
--- * Runtime Parallel - Can be called/changed in Satisfactory Factory Tick
--- * Read Only - The value of this property can not be changed by code
---@type float
ItemType.radioactiveDecay = nil

--- The name of the item.
--- ### Flags:
--- * Runtime Synchronous - Can be called/changed in Game Tick
--- * Runtime Parallel - Can be called/changed in Satisfactory Factory Tick
--- * Read Only - The value of this property can not be changed by code
---@type string
ItemType.name = nil

--- The description of this item.
--- ### Flags:
--- * Runtime Synchronous - Can be called/changed in Game Tick
--- * Runtime Parallel - Can be called/changed in Satisfactory Factory Tick
--- * Read Only - The value of this property can not be changed by code
---@type string
ItemType.description = nil

--- The maximum stack size of this item.
--- ### Flags:
--- * Runtime Synchronous - Can be called/changed in Game Tick
--- * Runtime Parallel - Can be called/changed in Satisfactory Factory Tick
--- * Read Only - The value of this property can not be changed by code
---@type integer
ItemType.max = nil

--- True if this item can be discarded.
--- ### Flags:
--- * Runtime Synchronous - Can be called/changed in Game Tick
--- * Runtime Parallel - Can be called/changed in Satisfactory Factory Tick
--- * Read Only - The value of this property can not be changed by code
---@type boolean
ItemType.canBeDiscarded = nil

--- The category in which this item is in.
--- ### Flags:
--- * Runtime Synchronous - Can be called/changed in Game Tick
--- * Runtime Parallel - Can be called/changed in Satisfactory Factory Tick
--- * Read Only - The value of this property can not be changed by code
---@type FicsIt_Networks.Components.ItemCategory
ItemType.category = nil

--- The color of this fuild.
--- ### Flags:
--- * Runtime Synchronous - Can be called/changed in Game Tick
--- * Runtime Parallel - Can be called/changed in Satisfactory Factory Tick
--- * Read Only - The value of this property can not be changed by code
---@type FicsIt_Networks.Components.Color
ItemType.fluidColor = nil
