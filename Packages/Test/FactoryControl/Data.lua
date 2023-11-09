---@meta
local PackageData = {}

PackageData["TestFactoryControl__main"] = {
    Location = "Test.FactoryControl.__main",
    Namespace = "Test.FactoryControl.__main",
    IsRunnable = true,
    Data = [[
local Framework = require("Test.Framework.Framework")
local Host = require("Hosting.Host")

---@class FactoryControl.Test.Main : Github_Loading.Entities.Main
---@field private m_host Hosting.Host
---@field private m_testFramework Test.Framework
local Main = {}

function Main:Configure()
    self.m_host = Host(self.Logger:subLogger("Host"), "Host")

    self.m_testFramework = self.m_host:AddTesting()
end

function Main:Run()
    self.m_testFramework:Run(self.Logger:subLogger("TestFramework"))
end

return Main
]]
}

PackageData["TestFactoryControlHelper"] = {
    Location = "Test.FactoryControl.Helper",
    Namespace = "Test.FactoryControl.Helper",
    IsRunnable = true,
    Data = [[
local NetworkClient = require("Net.Core.NetworkClient")

local FacotryControlClient = require("FactoryControl.Client.Client")

---@class Test.FacotryControl.Helper : object
local Helper = {}

---@param logger Core.Logger
---@return FactoryControl.Client
function Helper.CreateFactoryControlClient(logger)
    return FacotryControlClient(logger:subLogger("Client"), nil, NetworkClient(logger:subLogger("NetworkClient")))
end

---@param logger Core.Logger
---@param name string
---@return FactoryControl.Client.Entities.Controller
function Helper.CreateController(logger, name)
    local client = Helper.CreateFactoryControlClient(logger)
    return client:Connect(name)
end

return Helper
]]
}

PackageData["TestFactoryControlTestsConnection"] = {
    Location = "Test.FactoryControl.Tests.Connection",
    Namespace = "Test.FactoryControl.Tests.Connection",
    IsRunnable = true,
    Data = [[
local TestFramework = require("Test.Framework.Framework")
local Helper = require("Test.FactoryControl.Helper")

---@param logger Core.Logger
local function connection(logger)
    local client = Helper.CreateFactoryControlClient(logger)

    local controller = client:Connect("Connection")

    assert(controller.IPAddress:Equals(client.NetClient:GetIPAddress()), "IP Address mismatch")
end
TestFramework:AddTest("Connection", connection)
]]
}

PackageData["TestFactoryControlTestsControlling"] = {
    Location = "Test.FactoryControl.Tests.Controlling",
    Namespace = "Test.FactoryControl.Tests.Controlling",
    IsRunnable = true,
    Data = [[
local TestFramework = require("Test.Framework.Framework")
local Helper = require("Test.FactoryControl.Helper")

local EventPullAdapter = require("Core.Event.EventPullAdapter")

---@param logger Core.Logger
local function controlling(logger)
    local client = Helper.CreateFactoryControlClient(logger)

    local controller = client:Connect("Controlling")

    local featureName = "test"
    local button = controller:AddButton(featureName)
    assert(button, "could not add button")
    local pressed = false
    button.OnChanged:AddListener(function()
        pressed = true
    end)

    local getedController = client:GetControllerByName("Controlling") or client:GetControllerById(controller.Id)
    assert(getedController, "could not get controller")

    local features = getedController:GetFeatures()
    for _, feature in pairs(features) do
        if feature.Name == featureName then
            ---@cast feature FactoryControl.Client.Entities.Controller.Feature.Button
            feature:Press()
        end
    end

    button:Press()
    while not pressed do
        EventPullAdapter:Wait()
    end
end
TestFramework:AddTest("Controlling", controlling)
]]
}

PackageData["TestFactoryControlTestsFeaturesButton"] = {
    Location = "Test.FactoryControl.Tests.Features.Button",
    Namespace = "Test.FactoryControl.Tests.Features.Button",
    IsRunnable = true,
    Data = [[
local TestFramework = require("Test.Framework.Framework")
local Helper = require("Test.FactoryControl.Helper")

local EventPullAdapter = require("Core.Event.EventPullAdapter")

---@param logger Core.Logger
local function overall(logger)
    local controller = Helper.CreateController(logger, "Button")

    -- Test: adding button

    local button = controller:AddButton("Test")
    assert(button, "button is nil")

    log("passed test: adding button")


    -- Test: pressing button

    local pressed = false
    button.OnChanged:AddListener(function()
        pressed = true
    end)

    button:Press()
    while not pressed do
        EventPullAdapter:Wait()
    end

    log("passed test: pressing button")
end
TestFramework:AddTest("Button Overall", overall)
]]
}

PackageData["TestFactoryControlTestsFeaturesChart"] = {
    Location = "Test.FactoryControl.Tests.Features.Chart",
    Namespace = "Test.FactoryControl.Tests.Features.Chart",
    IsRunnable = true,
    Data = [[
local TestFramework = require("Test.Framework.Framework")
local Helper = require("Test.FactoryControl.Helper")

local EventPullAdapter = require("Core.Event.EventPullAdapter")

---@param logger Core.Logger
local function overall(logger)
    local controller = Helper.CreateController(logger, "Chart")

    -- Test: adding switch

    local chart = controller:AddChart(
        "Test",
        {
            Data = { [2] = "lol2" }
        }
    )
    assert(chart, "chart is nil")

    log("passed test: adding chart")

    -- Test: flipping switch

    local called = false
    local dataCount = 0
    ---@param featureUpdate FactoryControl.Core.Entities.Controller.Feature.Chart.Update
    chart.OnChanged:AddListener(function(featureUpdate)
        called = true
        dataCount = #chart:GetData() - #featureUpdate.Data
    end)

    chart:Modify(function(modify)
        modify.Data = { [1] = "lol1" }
    end)
    while not called do
        EventPullAdapter:Wait()
    end
    assert(dataCount == 1, "dataCount is not 1")

    log("passed test: update chart")
end
TestFramework:AddTest("Chart Overall", overall)
]]
}

PackageData["TestFactoryControlTestsFeaturesRadial"] = {
    Location = "Test.FactoryControl.Tests.Features.Radial",
    Namespace = "Test.FactoryControl.Tests.Features.Radial",
    IsRunnable = true,
    Data = [[
local TestFramework = require("Test.Framework.Framework")
local Helper = require("Test.FactoryControl.Helper")

local EventPullAdapter = require("Core.Event.EventPullAdapter")

---@param logger Core.Logger
local function overall(logger)
    local controller = Helper.CreateController(logger, "Radial")

    -- Test: adding switch

    local radial = controller:AddRadial("Test")
    assert(radial, "radial is nil")

    log("passed test: adding radial")

    -- Test: flipping switch

    local called = false
    local setting = 0
    ---@param featureUpdate FactoryControl.Core.Entities.Controller.Feature.Radial.Update
    radial.OnChanged:AddListener(function(featureUpdate)
        called = true
        setting = featureUpdate.Setting
    end)

    radial:Modify(function(modify)
        modify.Setting = 1
    end)
    while not called do
        EventPullAdapter:Wait()
    end
    assert(setting == 1, "setting is not 1")

    log("passed test: update radial")
end
TestFramework:AddTest("Radial Overall", overall)
]]
}

PackageData["TestFactoryControlTestsFeaturesSwitch"] = {
    Location = "Test.FactoryControl.Tests.Features.Switch",
    Namespace = "Test.FactoryControl.Tests.Features.Switch",
    IsRunnable = true,
    Data = [[
local TestFramework = require("Test.Framework.Framework")
local Helper = require("Test.FactoryControl.Helper")

local EventPullAdapter = require("Core.Event.EventPullAdapter")

---@param logger Core.Logger
local function overall(logger)
    local controller = Helper.CreateController(logger, "Switch")

    -- Test: adding switch

    local switch = controller:AddSwitch("Test")
    assert(switch, "switch is nil")

    log("passed test: adding switch")

    -- Test: flipping switch

    local called = false
    local switched = false
    switch.OnChanged:AddListener(function(isEnabled)
        called = true
        if isEnabled then
            switched = isEnabled
        end
    end)

    switch:Toggle()
    while not called do
        EventPullAdapter:Wait()
    end
    assert(switched, "switched is false")

    log("passed test: flipping switch")
end
TestFramework:AddTest("Switch Overall", overall)
]]
}

return PackageData