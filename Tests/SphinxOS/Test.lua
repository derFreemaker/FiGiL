local luaunit = require('Tools.Testing.Luaunit')

local Curl = require("Tools.Curl")
local Installer = require("SphinxOS.misc.installer")

local FileSystem = require("Tools.Freemaker.bin.filesystem")
local currentPath = FileSystem:GetCurrentDirectory()
local FileSystemPath = currentPath .. "/Sim-Files/Test_LoaderLoad"

local bootFilePath = currentPath .. "/../../SphinxOS/boot/boot.lua"
local eepromFile = io.open(currentPath .. "/../../SphinxOS/misc/install.eeprom.lua", "r")
if not eepromFile then
    error("unable to open install.eeprom")
end
local eeprom = eepromFile:read("a")
eepromFile:close()

local Sim = require('Tools.Testing.Simulator'):Initialize(1, FileSystemPath, eeprom)

local BASE_URL = "http://localhost"
-- local BASE_URL = "https://raw.githubusercontent.com/derFreemaker/Satisfactory/main"
local BASE_PATH = ""

-- Urls
local OS_URL = BASE_URL .. "/SphinxOS"

local MISC_URL = OS_URL .. "/misc"
local INSTALLER_URL = MISC_URL .. "/installer.lua"

-- Paths
local OS_PATH = "/SphinxOS"

local INSTALL_PATH = "/install"
local INSTALL_EEPROM_PATH = INSTALL_PATH .. "/install.eeprom.lua"
local INSTALLER_PATH = INSTALL_PATH .. "/installer.lua"

local BOOT_PATH = OS_PATH .. "/boot/boot.lua"

function Test()
    if not filesystem.exists(INSTALL_PATH) and not filesystem.createDir(INSTALL_PATH) then
        error("unable to create install folder")
    end

    local installer = Installer.new(BASE_URL, BASE_PATH, "/SphinxOS/boot/boot.lua", Curl)

    print("downloading OS files...")
    installer:Download()

    print("saving current eeprom to " .. INSTALL_EEPROM_PATH .. " for later use...")
    local installFile = filesystem.open(INSTALL_EEPROM_PATH, "w")
    installFile:write(computer.getEEPROM())
    installFile:close()

    print("writing boot loader to eeprom...")
    installer:LoadBootLoader()

    print("installed!")

    dofile(bootFilePath)
end

os.exit(luaunit.LuaUnit.run())