--------------------------------------------------------------------------------------
-- SimCore.lua
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 9 October, 2019
local _, CombatSimulator = ...
CombatSimulator.SimCore = {}
simcore = CombatSimulator.SimCore

local L = CombatSimulator.L
local sprintf = _G.string.format
-- ******************************************************
--      IMPORT THESE CONSTANTS FROM WOWTHREADS
-- ******************************************************
simcore.SIG_ALERT             = thread.SIG_ALERT
simcore.SIG_JOIN_DATA_READY   = thread.SIG_JOIN_DATA_READY
simcore.SIG_TERMINATE         = thread.SIG_TERMINATE
simcore.SIG_METRICS           = thread.SIG_METRICS
simcore.SIG_NONE_PENDING      = thread.SIG_NONE_PENDING

local SIG_ALERT             = simcore.SIG_ALERT
local SIG_JOIN_DATA_READY   = simcore.SIG_JOIN_DATA_READY
local SIG_TERMINATE         = simcore.SIG_TERMINATE
local SIG_METRICS           = simcore.SIG_METRICS
local SIG_NONE_PENDING      = simcore.SIG_NONE_PENDING

simcore.EMPTY_STR 			= ""
simcore.SUCCESS 			= true
simcore.FAILURE 			= false
simcore.DEBUGGING_ENABLED	= true
simcore.ADDON_NAME 			= nil
simcore.ADDON_VERSION		= nil

local EMPTY_STR 		= simcore.EMPTY_STR
local SUCCESS			= simcore.SUCCESS
local FAILURE			= simcore.FAILURE
local DEBUGGING_ENABLED = simcore.DEBUGGING_ENABLED

simcore.EXPANSION_NAME 	= nil
simcore.EXPANSION_LEVEL	= nil

local function setExpansionName()
	local isValid = false
	simcore.EXPANSION_LEVEL = GetServerExpansionLevel()

	if simcore.EXPANSION_LEVEL == LE_EXPANSION_CLASSIC then
		simcore.EXPANSION_NAME = "Classic (Vanilla)"
		isValid = true
	end
	if simcore.EXPANSION_LEVEL == LE_EXPANSION_WRATH_OF_THE_LICH_KING then
		simcore.EXPANSION_NAME = "Classic (WotLK)"
		isValid = true
	end
	if simcore.EXPANSION_LEVEL == LE_EXPANSION_DRAGONFLIGHT then
		simcore.EXPANSION_NAME = "Dragon Flight"
		isValid = true
	end

	if isValid == false then
		local errMsg = sprintf("Invalid Expansion Code, %d", simcore.EXPANSION )
		DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s", errMsg), 1.0, 1.0, 0.0 )
		return nil
	end
end
setExpansionName()
simcore.ADDON_NAME = "CombatSimulator"
simcore.ADDON_VERSION = GetAddOnMetadata( simcore.ADDON_NAME, "Version")

-----------------------------------------------------------------------------------------------------------
--                      The infoTable
--                      Indices into the infoTable table
-----------------------------------------------------------------------------------------------------------
local INTERFACE_VERSION = 1		-- string
local BUILD_NUMBER 		= 2		-- string
local BUILD_DATE 		= 3		-- string
local TOC_VERSION		= 4		-- number
local ADDON_NAME 		= 5		-- string

--****************************************************************************************
--                      Game/Build/AddOn Info (from Blizzard's GetBuildInfo())
--****************************************************************************************
local infoTable = { GetBuildInfo() }			-- BLIZZ
infoTable[ADDON_NAME] = "CombatSimulator"

function simcore:getAddonName()
	return infoTable[ADDON_NAME]
end
function simcore:getReleaseVersion()
    return infoTable[INTERFACE_VERSION]
end
function simcore:getBuildNumber()
    return infoTable[BUILD_NUMBER]
end
function simcore:getBuildDate()
    return infoTable[BUILD_DATE]
end
function simcore:getTocVersion()
    return infoTable[TOC_VERSION]	-- e.g., 90001
end
function simcore:enableDebugging()
	DEBUGGING_ENABLED = true
	DEFAULT_CHAT_FRAME:AddMessage( "Debugging is Now ENABLED", 0.0, 1.0, 1.0 )
end
function simcore:disableDebugging()
	DEBUGGING_ENABLED = false
	DEFAULT_CHAT_FRAME:AddMessage( "Debugging is Now DISABLED", 0.0, 1.0, 1.0 )
end
-- RETURNS: boolean true if enabled, false otherwise
function simcore:debuggingIsEnabled()
	return DEBUGGING_ENABLED
end
-- ********************* TABLE FUNCTIONS *****************************
function simcore:sortHighToLow( entry1, entry2 )
    return entry1[2] > entry2[2]
end
function simcore:sortLowToHigh( entry1, entry2 )
    return entry1[2] < entry2[2]
end
function simcore:tableInsert( t, entry )
	table.insert( t, entry )
end
-- RETURNS: entry, count of remaining entries
function simcore:tableRemove( t, num )
	local entry = table.remove( t, num )
	return entry,#t
end
local fileName = "SimCore.lua"
if simcore:debuggingIsEnabled() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded", fileName), 1.0, 1.0, 0.0 )
end
