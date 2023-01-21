--------------------------------------------------------------------------------------
-- Celu.lua
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 12 January, 2019
--------------------------------------------------------------------------------------
local _, CombatSimulator = ...
CombatSimulator.Celu = {}
-- comlog = CombatSimulator.Celu
celu = CombatSimulator.Celu

local timestamp = core.timestamp

local sprintf = _G.string.format
local L = CombatSimulator.L

local EMPTY_STR = core.EMPTY_STR
local SUCCESS   = threadErrors.SUCCESS
local E = threadErrors

-- NOTE:
-- SIG_TERMINATE - returns thread from yield() immediately but doesn't require recipient to exit while loop
-- SIG_ALERT - requires recipient to return from yield() and exit while loop.
-- SIG_TERMINATE - requires thread to cleanup state and complete.
local SIG_ALERT            = thread.SIG_ALERT          -- You've returned prematurely from a yield. Do what's appropriate.
local SIG_JOIN_DATA_READY   = thread.SIG_JOIN_DATA_READY
local SIG_TERMINATE         = thread.SIG_TERMINATE
local SIG_METRICS           = thread.SIG_METRICS
local SIG_NONE_PENDING      = thread.SIG_NONE_PENDING -- default value. Means the handle's signal queue is empty

celu.RANGE_DAMAGE 	= 1
celu.SWING_DAMAGE 	= 2 
celu.SPELL_DAMAGE 	= 3 
celu.SPELL_HEALS 	= 4                         
celu.RANGE_MISS 	= 5 
celu.SWING_MISS 	= 6 
celu.SPELL_MISS 	= 7 

local RANGE_DAMAGE	= celu.RANGE_DAMAGE
local SWING_DAMAGE	= celu.SWING_DAMAGE 
local SPELL_DAMAGE  = celu.SPELL_DAMAGE 
local SPELL_HEALS	= celu.SPELL_HEALS                         
local RANGE_MISS	= celu.RANGE_MISS 
local SWING_MISS	= celu.SWING_MISS 
local SPELL_MISS	= celu.SPELL_MISS 

-- a database of stats from CombatLogEventUnfiltered
local combatEventDB = {}
function celu:getDbEntry()
	if #combatEventDB == 0 then return nil, 0 end

	local dbEntry = table.remove( combatEventDB, 1 )
	return dbEntry, #combatEventDB
end

local format_h = nil
function celu:setFormatThread( thread_h )
	assert( thread_h ~= nil, "ASSERT_FAILED: " .. L["THREAD_HANDLE_NIL"])
	format_h = thread_h
end
celu.LOGGING_ENABLED = false
local LOGGING_ENABLED = celu.LOGGING_ENABLED
celu.ADDON_ENABLED = true
local ADDON_ENABLED = celu.ADDON_ENABLED
local ENCOUNTER_START_TIME = -1
local elapsedTime = 0

function celu:getElapsedTime()
	return elapsedTime
end
local function isUnitInParty( flags )
	return -- NOT YET IMPLEMENTED
end
local function isGuardianType( flags )
	return bit.band( flags, COMBATLOG_OBJECT_TYPE_MASK ) == bit.band( flags, COMBATLOG_OBJECT_TYPE_GUARDIAN )
end
local function isPetType( flags )
	return bit.band( flags, COMBATLOG_OBJECT_TYPE_MASK ) == bit.band( flags, COMBATLOG_OBJECT_TYPE_PET )
end
local function isPlayerType( flags )
	return bit.band( flags, COMBATLOG_OBJECT_TYPE_MASK ) == bit.band( flags, COMBATLOG_OBJECT_TYPE_PLAYER )
end
local function isPlayersGuardian( flags )
	if isGuardianType( flags ) == false then
		return false
	end
	-- 	Is this guardian affiliated with (belong to) the player
	return bit.band( flags, COMBATLOG_OBJECT_AFFILIATION_MASK) == bit.band( flags, COMBATLOG_OBJECT_AFFILIATION_MINE)
end
local function isPlayersPet( flags )
	if isPetType( flags ) == false then
		return false
	end
	return bit.band( flags, COMBATLOG_OBJECT_AFFILIATION_MASK) == bit.band( flags, COMBATLOG_OBJECT_AFFILIATION_MINE)
end
local function isUnitValid( stats )		
	local sourceName 		= stats[5]
	local sourceFlags 		= stats[6]
	local sourceRaidFlags 	= stats[7]
	local targetName 		= stats[9]
	local targetFlags 		= stats[10]
	local targetRaidFlags 	= stats[11]

	local unitIsValid = false
	local _, _, _, _, _, playerName, _, petName = GetPlayerInfoByGUID( UnitGUID("Player"))
	
	-- is this unit a playersPet and, if so, does the pet belong to the
	-- player?
	if playersPet ~= nil then
		if isPlayersPet( sourceFlags) or isPlayersPet( targetFlags ) then
			dbg:print()
			unitIsValid = true
		end
	end
	-- is this unit the player's guardian (e.g., the Warlock's Darkglare)?
	if unitIsValid == false then
		if isPlayersGuardian( sourceFlags) or isPlayersGuardian( targetFlags ) then
			unitIsValid = true
		end
	end
	-- is this unit the source or target of the attack?
	if unitIsValid == false then
		if playerName == sourceName or playerName == targetName then
			if targetName == nil then targetName = EMPTY_STR end
			unitIsValid = true
		end
	end
	return unitIsValid
end

local eventFrame = CreateFrame("Frame" )
eventFrame:RegisterEvent( "ADDON_LOADED")
eventFrame:RegisterEvent( "COMBAT_LOG_EVENT_UNFILTERED") 

eventFrame:SetScript("Celu", 
function( self, event, ... )
	local arg1, arg2, arg3, arg4, arg5 = ...

	-- if CombatSimulator is disabled (i.e. ADDON_ENABLED == false ) then
	-- 	it will not allow events to pass this point.
	if not ADDON_ENABLED then
		return
	end
	if event == "ADDON_LOADED" and arg1 == L["ADDON_AND_VERSION"] then
		core:printMsg( L["ADDON_LOADED_MSG"])
		return
	end

	if event == "COMBAT_LOG_EVENT_UNFILTERED" then	

		local stats = {CombatLogGetCurrentEventInfo()}		-- BLIZZ API

		-- filter all units except subEvents involving the player and/or his/her pet
		if not isUnitValid( stats ) then
			local _, _, _, _, _, playerName, _, petName = GetPlayerInfoByGUID( UnitGUID("Player"))
			return
		end
	
		local subEvent = stats[2]

		-- log each of the following subEvents
		if 	-- miss subevents
			-- subEvent ~= "SPELL_CAST_START" and
			-- subEvent ~= "SPELL_CAST_SUCCESS" and

			subEvent ~= "SWING_MISSED" and
			subEvent ~= "RANGE_MISSED" and
			subEvent ~= "SPELL_MISSED" and 
			subEvent ~= "SPELL_PERIODIC_MISSED" and

			-- heal subevents
			subEvent ~= "SPELL_HEAL" and
			subEvent ~= "SPELL_PERIODIC_HEAL" and

			-- damage subEvents
			subEvent ~= "RANGE_DAMAGE" and
			subEvent ~= "SPELL_DAMAGE" and 
			subEvent ~= "SWING_DAMAGE" and
			subEvent ~= "SPELL_PERIODIC_DAMAGE" then	
			-- do nothing. It's an event of no interest
			return
		end
		local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
		table.insert( combatEventDB, stats )
		assert( format_h ~= nil, "ASSERT_FAILED: " .. L["THREAD_HANDLE_NIL"])

		result = thread:sendSignal( format_h, SIG_ALERT)
		if not result[1] then mf:postResult( result ) return end
		-- mf:postMsg(sprintf("%s Sent SIG_ALERT to format_h\n", E:prefix(), subEvent ))
	end
end)
-- local combatEventLog = fm:createCombatEventLog( L["ADDON_AND_VERSION"])

-- function comlog:getCombatEventLog()
-- 	return combatEventLog
-- end
-- function comlog:hideFrame()
--     fm:hideFrame( combatEventLog )
-- end
-- function comlog:showFrame()
--     fm:showFrame( combatEventLog )
-- end
-- function comlog:clearFrameText()
--     fm:clearFrameText( combatEventLog )
-- end
-- function comlog:postLogEntry( isCritical, logEntry, isDamage )
-- 	float:scrollFloatingText( logEntry, isDamage, isCritical )
-- end

local fileName = "Celu.lua"
if dbg:debuggingIsEnabled() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded.", fileName ), 0.0, 1.0, 0.0 )
end
