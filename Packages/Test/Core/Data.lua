Data={
["Test.Core.__main"] = [[
---@using Test.Framework

local Host = require("Hosting.Host")

---@class Test.Core.Main : Github_Loading.Entities.Main
---@field private m_host Hosting.Host
---@field private m_testFramework Test.Framework
local Main = {}

function Main:Configure()
    log("called configure")

    self.m_host = Host(self.Logger:subLogger("Host"), "Host")

    self.m_testFramework = self.m_host:AddTesting()
end

function Main:Run()
    log("called run")

    self.m_testFramework:Run(self.Logger:subLogger("TestFramework"))
end

return Main

]],
["Test.Core.Tests.NetworkCard"] = [[
local Framework = require("Test.Framework.init")

local NetworkCard = require("Adapter.Computer.NetworkCard")

local EventPullAdapter = require("Core.Event.EventPullAdapter")

local function test()
    local networkCard = NetworkCard()
    networkCard:Listen()

    networkCard:OpenPort(1)
    networkCard:Send(networkCard:GetIPAddress(), 1, "test")

    local gotEvent = false
    EventPullAdapter:AddListener("NetworkMessage", function(data)
        log(data)
        if data[5] == "test" then
            gotEvent = true
        end
    end)

    EventPullAdapter:Wait(5)

    assert(gotEvent, "did not get networkCard message")
end
Framework:AddTest("NetworkCard", test)

]],
}

return Data
