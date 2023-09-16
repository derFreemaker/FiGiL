---@class Test.Tester
---@field private loadedLoaderFiles any[]
local Tester = {}

---@private
function Tester:LoadLoaderFiles()
    self.loadedLoaderFiles = {}

    self.loadedLoaderFiles["/Github-Loading/Loader/Utils/File"] = { require("Github-Loading.Loader.Utils.10_File") }
    self.loadedLoaderFiles["/Github-Loading/Loader/Utils/Function"] = { require("Github-Loading.Loader.Utils.10_Function") }
    self.loadedLoaderFiles["/Github-Loading/Loader/Utils/Object"] = { require("Github-Loading.Loader.Utils.10_Object") }
    self.loadedLoaderFiles["/Github-Loading/Loader/Utils/String"] = { require("Github-Loading.Loader.Utils.10_String") }
    self.loadedLoaderFiles["/Github-Loading/Loader/Utils/Table"] = { require("Github-Loading.Loader.Utils.10_Table") }
    self.loadedLoaderFiles["/Github-Loading/Loader/Utils/Class"] = { loadfile("Github-Loading/Loader/Utils/20_Class.lua")(self.loadedLoaderFiles) }
    Utils = loadfile("Github-Loading/Loader/Utils/30_Index.lua")(self.loadedLoaderFiles) --[[@as Utils]]

    -- //TODO: load other files
end

---@private
function Tester:OverrideRequire()
    local requireFunc = require
    ---@param moduleToGet string
    function require(moduleToGet)
        if requireFunc == nil then
            error("require Func was nil")
        end
        return requireFunc("src." .. moduleToGet)
    end
end

---@private
function Tester:Prepare()
    self:LoadLoaderFiles()
    self:OverrideRequire()
end

---@return Test.Tester
function Tester:Initialize()
    self:Prepare()
    return self
end

return Tester