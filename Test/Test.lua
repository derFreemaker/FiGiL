local Tester = require("Test.Tester"):Initialize()

local Task = require("Core.Task")
local Logger = require("Core.Logger")

local testLogger = Logger("Test", 0)
testLogger.OnLog:AddListener(Task(print))

-- local function testFunc()
--     print("hi")
--     error("Test")
-- end

-- local test = Task(testFunc)

-- test:Execute()
-- test:LogError(testLogger)

local AddressDatabase = require("DNS.Server.AddressDatabase")

local test = AddressDatabase(testLogger)

print(test:GetWithId("Hi"))

print("#### END ####")