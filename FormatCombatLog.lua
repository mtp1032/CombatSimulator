--------------------------------------------------------------------------------------
-- FormatCombatLog.lua
-- AUTHOR: Michael Peterson
-- ORIGINAL DATE: 10 October, 2019
--------------------------------------------------------------------------------------
local _, CombatSimulator = ...
CombatSimulator.FormatCombatLog = {}
fmtlog = CombatSimulator.FormatCombatLog

local L = CombatSimulator.L
local sprintf = _G.string.format

-- ******************************************************
--      IMPORT THESE CONSTANTS FROM WOWTHREADS
-- ******************************************************
local EMPTY_STR             = thread.EMPTY_STR
local SUCCESS               = thread.SUCCESS
local FAILURE               = thread.FAILURE
local EXPANSION_NAME        = thread.EXPANSION_NAME
local SIG_ALERT             = thread.SIG_ALERT
local SIG_JOIN_DATA_READY   = thread.SIG_JOIN_DATA_READY
local SIG_TERMINATE         = thread.SIG_TERMINATE
local SIG_METRICS           = thread.SIG_METRICS
local SIG_NONE_PENDING      = thread.SIG_NONE_PENDING

-- https://wow.gamepedia.com/API_UnitHealth
-- https://wow.gamepedia.com/API_UnitHealthMax

-- https://wow.gamepedia.com/API_UnitInParty
-- https://wow.gamepedia.com/UnitFlag
-- https://wow.gamepedia.com/API_UnitPlayerOrPetInParty


local DAMAGE 			= float.DAMAGE
local PERIODIC_DMG		= float.PERIODIC_DMG
local HEALING			= float.HEALING
local PERIODIC_HEALING 	= float.PERIODIC_HEALING
local MISS 				= float.MISS

local damageThread_h	= nil
local healThread_h     	= nil
local auraThread_h      = nil
local missThread_h      = nil

local dmgEventTable 	= {}
local healEventTable 	= {}
local auraEventTable 	= {}
local missEventTable 	= {}
local subEventTable		= {}local DAMAGE 			= float.DAMAGE
local PERIODIC_DMG		= float.PERIODIC_DMG
local HEALING			= float.HEALING
local PERIODIC_HEALING 	= float.PERIODIC_HEALING
local MISS 				= float.MISS


local function isDamageEv( stats )
	isDamage = true
	subEvent = stats[2]

	-- damage subEvents
	if subEvent ~= "RANGE_DAMAGE" and
		subEvent ~= "SPELL_DAMAGE" and 
		subEvent ~= "SWING_DAMAGE" and
		subEvent ~= "SPELL_PERIODIC_DAMAGE" then
			return false
		end			
	return isDamage
end
local function isHealEv( stats )
	isHeal = true
	subEvent = stats[2]
	-- heal subevents
	if subEvent ~= "SPELL_HEAL" and
		subEvent ~= "SPELL_PERIODIC_HEAL" then
			return false
	end	
	return isHeal
end
local function isMissEv( stats )
	isMiss = true

	subEvent = stats[2]
	-- miss subevents
		if subEvent ~= "SWING_MISSED" and
			subEvent ~= "RANGE_MISSED" and
			subEvent ~= "SPELL_MISSED" and 
			subEvent ~= "SPELL_PERIODIC_MISSED" then
				return false
		end

			
	return isMiss
end
function fmtlog:logSubevent( combatType, stats ) 
	local dbEntry = {}
	if combatType == DAMAGE then
		dbEntry = createDmgEntry( stats )
	end
	if combatType == HEALING then
		dbEntry = createHealingEntry( stats )
	end
	if combatType == MISS then
		dbEntry = createMissEntry( stats )
	end
	return dbEntry
end
function fmtlog:formatSubevent( stats )
	table.insert( combatEventLog, stats )
end

function fmtlog:getNumDmgEntries()
	return #dmgEventTable
end
function fmtlog:getNumHealEntries()
	return #healEventTable
end
function fmtlog:getNumAuraEntries()
	return #auraEventTable
end
function fmtlog:getNumMissEntries()
	return #missEventTable
end

function fmtlog:getDamageEntry()
	if #dmgEventTable == 0 then return 0 end
	local entry = table.remove( dmgEventTable, 1)
	return entry
end
function fmtlog:getHealEntry()
	if #healEventTable == 0 then return 0 end
	local entry = table.remove( healEventTable, 1)
	return entry
end
function fmtlog:getAuraEntry()
	if #auraEventTable == 0 then return 0 end
	local entry = table.remove( auraEventTable, 1)
	return entry
end
function fmtlog:getMissEntry()
	if #missEventTable == 0 then return 0 end
	local entry = table.remove( missEventTable, 1)
	return entry
end

function fmtlog:setDamageThread( thread_h )
	damageThread_h = thread_h
end
function fmtlog:setHealThread( thread_h )
	healsThread_h = thread_h
end
function fmtlog:setAuraThread( thread_h )
	auraThread_h = thread_h
end
function fmtlog:setMissThread( thread_h )
	missThread_h = thread_h
end

-- ********************************************************************************
--						CONSTANTS AND VARIABLES
-- ********************************************************************************
local SUCCESS = E.SUCCESS
local FAILURE = E.FAILURE

-- CELU base parameters
local TIMESTAMP			= 1		-- valid for all subEvents
local SUBEVENT    		= 2		-- valid for all subEvents
local HIDECASTER      	= 3		-- valid for all subEvents
local SOURCEGUID      	= 4 	-- valid for all subEvents
local SOURCENAME      	= 5 	-- valid for all subEvents
local SOURCEFLAGS     	= 6 	-- valid for all subEvents
local SOURCERAIDFLAGS 	= 7 	-- valid for all subEvents
local TARGETGUID      	= 8 	-- valid for all subEvents
local TARGETNAME      	= 9 	-- valid for all subEvents
local TARGETFLAGS     	= 10 	-- valid for all subEvents
local TARGETRAIDFLAGS 	= 11	-- valid for all subEvents

local SPELLID         	= 12 	-- amountDmg
local SPELLNAME       	= 13  	-- overKill
local SCHOOL		    = 14 	-- schoolIndex
local AMOUNT_DAMAGED	= 15
local AMOUNT_HEALED		= 15
local MISSTYPE			= 15    
local OVERKILL        	= 16	-- absorbed  (integer)
local OVERHEALED		= 16
local SCHOOL_INDEX    	= 17	-- critical  (boolean)
local RESISTED        	= 18 	-- glancing  (boolean)
local BLOCKED         	= 19 	-- crushing  (boolean)
local ABSORBED        	= 20 	-- isOffHand (boolean)
local CRITICAL        	= 21	-- <unused>
local GLANCING        	= 22	-- <unused>
local CRUSHING        	= 23	-- <unused>
local OFFHAND			= 24

local helpFrame			= nil

local spellSchoolNames = {
	{1, "Physical"},
	{2, "Holy"},
	{3, "Holystrike"},
	{4, "Fire"},
	{5, "Flamestrike"},
	{6, "Holyfire (Radiant"},
	{8, "Nature"},
	{9, "Stormstrike"},
	{10, "Holystorm"},
	{12, "Firestorm"},
	{16, "Frost"},
	{17, "Froststrike"},
	{18, "Holyfrost"},
	{20, "Frostfire"},
	{24, "Froststorm"},
	{28, "Elemental"},
	{32, "Shadow"},
	{33, "Shadowstrike"},
	{34, "Shadowlight"},
	{36, "Shadowflame"},
	{40, "Shadowstorm(Plague)"},
	{48, "Shadowfrost"},
	{64, "Arcane"},
	{65, "Spellstrike"},
	{66, "Divine"},
	{68, "Spellfire"},
	{72, "Spellstorm"},
	{80, "Spellfrost"},
	{96, "Spellshadow"},
	{124, "Chromatic(Chaos)"},
	{126, "Magic"},
	{127, "Chaos"}
}

local spellTable 	= {}
local instantCastTable	= {}
local timedCastTable 	= {}
local elapsedTime 		= 0
local initialTimeStamp 	= 0
local totalCasts		= 0

-- The entry format is the same for all 10 tables
-- entry = { spellName, damage, overKill, resisted, blocked, absorbed, 1}
-- insertEntryIntoDmgTable( entry)
local dmgCastTimeSpells	= {}	
local dmgPeriodicSpells	= {}	
local dmgRangedSpells 	= {}	
local dmgSwingSpells 	= {}	
local dmgPetSpells 		= {}	-- used when source == playersPet
local critSpellDmg		= {}	
local critRangeDmg		= {}	
local critSwingDmg		= {}	
local critPetDmg		= {}

-- entry = {spellName, amountHealed, overHealed, absorbed, 1}
-- insertEntryIntoHealTable( entry )
local healSpells			= {}	-- iff SPELL_HEAL
local periodicHealSpells	= {}	-- iff SPELL_PERIODIC_HEAL
local critHealSpells		= {}	-- includes all healing spells (periodic and normal)

-- { schoolName, damageAmount, healAmount, castCounter }
local spellSchools 	= {}

-- entry = {missType, amountMissed, isOffHand, 1 } 
missTypes 	= {
	{"ABSORB", 	0, 0 },		-- {spellName, count, damage }
	{"BLOCK", 	0, 0 },
	{"DEFLECT", 0, 0 },
	{"DODGE", 	0, 0 },
	{"IMMUNE", 	0, 0 },
	{"MISS", 	0, 0 },
	{"PARRY", 	0, 0 },
	{"REFLECT", 0, 0 },
	{"RESIST", 	0, 0 }
}

local CELU_Table = {}
local combatEventLog = comlog:getCelu()

-- ***************************************************************************
--						MITIGATION
-- ***************************************************************************

-- indicies into the mitigation table
local ABSORB 	= 1
local BLOCK 	= 2
local DEFLECT 	= 3
local DODGE 	= 4
local IMMUNE 	= 5
local MISS 		= 6
local PARRY 	= 7
local REFLECT 	= 8
local RESIST 	= 9

local mitigationNames = {
	"ABSORB",
	"BLOCK",
	"DEFLECT",
	"DODGE",
	"IMMUNE",
	"MISS",
	"PARRY",
	"REFLECT",
	"RESIST",
}

--********************************************************************************
-- 							FUNCTIONS
--********************************************************************************
-- returns an array of values for the specified spell
local function missTypeIsValid( mType )
	local isValidType = false
	local t = missTypes

	for _, v in ipairs(t) do
		if  v[1] == mType then
			return true
		end
	end
	return isValidType
end  	-- Check that missTypes are equal
local function getSpellDataSet( spellName )
	local spellFound = false
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR }

	local dataSet = {}
	for _, v in ipairs( spellTable ) do
		if v[1] == spellName then
			table.insert( dataSet, v )
			spellFound = true
		end
	end

	if not spellFound then
		result = E:setResult( result )
		result = {FAILURE, sprintf("Spell, %s, not found.\n", spellName), debugstack() }
		dataSet = nil
	end

	return dataSet, result
end
-- a dataset is an array of spell damages, i.e., t = {N1, N2,..,Nn}
local function calculateStats( dataSet )

	local sum = 0
	local mean = 0
	local variance = 0
	local stdDev = 0
	local n = 0

	if dataSet == nil then
		return mean, stdDev
	end
	if #dataSet == 0 then
		return mean, stdDev
	end

	-- calculate the mean
	for _, v in ipairs( dataSet ) do
		n = n + 1
		sum = sum + v[2]	-- ERROR HERE. See Lua Error stack trace below
	end
	mean = sum/n

	-- calculate the variance
	local residual = 9
	for _, v in ipairs(dataSet) do
		local residual =  (v[2] - mean)^2
		variance = variance + residual
	end

	if n == 1 then
		stdDev = 0.0
	else
		variance = variance/(n-1)
		stdDev = math.sqrt( variance )/n
	end

	return mean, stdDev
end
-- For correlation coefficient see https://www.youtube.com/watch?v=lVOzlHx_15s
-- A dataset is given by a set of x values and a set of y values.
local function getCorrelation( dataSet )
	local n = #dataset
	if n == 0 then return end

	local r = 0
	sumX = 0
	sumY = 0
	local dsX = 0
	local dsY = 0

	for _, xyPair in ipairs(dataSet) do
		sumX = sumX + xyPair[1]
		sumY = sumY + xyPair[2]
	end
	local xavg = sumX/n
	local yavg = sumY/n
	local ssX = 0
	local ssY = 0
	local sp = 0

	for _, xyPair in ipairs(dataSet) do
		ssX = ssX + (xyPair[1] - xavg)^2		-- sum of the squares for the x elements
		ssY = ssY + (xyPair[2] - yavg)^2		-- sum of the squares for the y elements
		sp = sp + (ssX * ssY)
	end

	r = sp /(sqrt(ssX) * sqrt(ssY))
	return r
end
--********************************************************************************
--							DEBUG SERVICES
-- *******************************************************************************
-- { schoolName, damageAmount, healAmount, 1 }
local function dbgCheckSchoolEntry( nvp )
	local isValid = true
	local errString = nil 
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR }

	if nvp == nil then 
		errString= sprintf( "nvp was nil\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if type(nvp) ~= "table" then
		errString= sprintf( "nvp was a %s, not a table.\n", type(nvp))
		result = E:setResult( errString, debugstack() )
		return false, result
	end
	if #nvp ~= 4 then
		errString= sprintf( "nvp has %d elements, not 4\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	-- CHECK SCHOOL NAME
	if nvp[1] == nil then
		errString= sprintf("nvp[1] is nil\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if type( nvp[1]) ~= "string" then
		errString= sprintf("nvp[1] is not a string\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	schoolName = nvp[1]
	isValid = false
	for _, v in ipairs( spellSchoolNames ) do
		if v[2] == schoolName then
			isValid = true
		end
	end
	if not isValid then
		errString= sprintf( "nvp[1] (%s) invalid school name\n", schoolName )
		result = E:setResult( errString, debugstack())
		return false, result
	end
	return true, result
end
-- entry = {spellName, damage, overKill, resisted, blocked, absorbed, 1 }
local function dbgCheckDmgTableEntry( nvp )
	local isValid = true
	local errString= nil
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR }

	if nvp == nil then 
		errString = sprintf( "nvp was nil\n" )
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if type(nvp) ~= "table" then
		errString = sprintf( "nvp was not a table\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if #nvp ~= 7 then
		errString = sprintf( "Not required number of elements\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	-- SPELLNAME
	if nvp[1] == nil then
		errString = sprintf("nvp[1] is nil\n" )
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if type( nvp[1]) ~= "string" then
		errString = sprintf("nvp[1] is not a string\n" )
		result = E:setResult( errString, debugstack())
		return false, result
	end
	-- DAMAGE
	if nvp[2] == nil then
		errString = sprintf("nvp[2] is nil\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if type(nvp[2]) ~= "number" then
		errStringing = sprintf("nvp[2] is not a number\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	-- OVERKILL
	if nvp[3] == nil then
		errString = sprintf("nvp[3] is nil, should be 1\n")
		return false, errString
	end
	if type(nvp[3]) ~= "number" then
		errString = sprintf("nvp[3] is not a number\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	-- RESISTED
	if nvp[3] == nil then
		errString = sprintf("nvp[3] is nil, should be 1\n")
		return false, errString
	end
	if type(nvp[3]) ~= "number" then
		errString = sprintf("nvp[3] is not a number\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	-- BLOCKED
	if nvp[4] == nil then
		errString = sprintf("nvp[4] is nil, should be 1\n")
		return false, errString
	end
	if type(nvp[4]) ~= "number" then
		errString = sprintf("nvp[3] is not a number\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	-- ABSORBED
	if nvp[5] == nil then
		errString = sprintf("nvp[5] is nil, should be 1\n")
		return false, errString
	end
	if type(nvp[6]) ~= "number" then
		errString = sprintf("nvp[6] is not a number\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if nvp[7] ~= nil and type(nvp[7]) ~= "number" and nvp[7] ~= 1 then
		errString = sprintf("nvp[5] is invalid.\n")
		result = E:setResult( errString, debugstack())
		return isValid, result
	end
	return isValid, result
end
-- entry = {spellName, amount, overhealing, absorbed, 1 }
local function dbgCheckHealEntry( nvp )
	local isValid 	= true
	local errString = nil
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR }

	if nvp == nil then 
		errString = sprintf( "nvp was nil\n")
		result = E:setResult(errString, debugstack() )
		return false, result
	end
	if type(nvp) ~= "table" then
		errString = sprintf( "nvp was not a table\n")
		result = E:setResult(errString, debugstack() )
		return false, result
	end
	if #nvp ~= 5 then
		errString = sprintf( "nvp has %d elements, not 5", #nvp )
		result = E:setResult( errString, debugstack())
		return false, result
	end

	-- Check spellName
	if type( nvp[1]) == nil then
		errString = sprintf("nvp[1] (spellName) is nil\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if type( nvp[1]) ~= "string" then
		errString = sprintf("nvp[1] is not a string\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if dbgCheckSchoolEntry( nvp[1]) then
		errString = sprintf("nvp[1] unknown spell\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end

	-- check the amount element
	if nvp[2] == nil then
		errString = sprintf("nvp[2] (= amountHealed) is nil\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if type(nvp[2]) ~= "number" then
		errString = sprintf("nvp[2] is not a number\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end

	-- check the overhealing element
	if nvp[3] == nil then
		errString = sprintf("nvp[3] (overHealed) is nil\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	if type(nvp[3]) ~= "number" then
		errString = sprintf("nvp[3] (overhealed) not a number\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	
	-- check the absorbed element
	if nvp[4] ~= nil and type(nvp[4]) ~= "number" then
		errString = sprintf("nvp[4] is invalid.\n")
		result = E:setResult( errString, debugstack())
		return fasle, result
	end
	if nvp[5] ~= nil and type(nvp[5]) ~= "number" and nvp[5] ~= 1 then
		errString = sprintf("nvp[5] is invalid.\n")
		result = E:setResult( errString, debugstack())
		return false, result
	end
	return true, result
end
-- entry = {missType, amountMissed, 1 }
local function dbgCheckMissTypeEntry( nvp )
	local isValid = true
	local errString = nil
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR }

	-- CHECK THAT THE TABLE IS PROPERLY CONFORMED
	if nvp == nil then 
		errString = sprintf( "nvp was nil\n" )
		isValid = false
		result = E:setResult( errString, debugstack())
		return isValid, result
	end
	if type(nvp) ~= "table" then
		errString = sprintf("nvp not a table\n")
		isValid = false
		result = E:setResult( errString, debugstack())
		return isValid, result
	end
	if #nvp ~= 3 then
		errString = sprintf( "nvp has %d elements, not 3\n", #nvp )
		isValid = false
		result = E:setResult( errString, debugstack())
		return isValid, result
	end
	-- CHECK THAT THE MISSTYPE IS VALID
	if not missTypeIsValid( nvp[1] ) then
		errString = sprintf("%s is not a valid mitigation type.\n", nvp[1])
		isValid = false
		result = E:setResult( errString, debugstack())
		return isValid, result
	end
	-- CHECK THAT THE AMOUNT IS CORRECTLY FORMED
	if nvp[2] == nil then
		errString = sprintf("nvp[2] for %s is nil\n", nvp[1])
		isValid = false
		result = E:setResult( errString, debugstack())
		return isValid, result
	end
	if type(nvp[2]) ~= "number" then
		errString = sprintf("nvp[2] is not a number\n")
		isValid = false
		result = E:setResult( errString, debugstack())
		return isValid, result
	end
	-- CHECK THEN INCREMENTOR
	if nvp[3] ~= 1 then
		errString = sprintf("nvp[3] not equal to 1\n")
		isValid = false
		result = E:setResult( errString, debugstack())
		return isValid, result
	end
	return isValid, result
end
local function dbgDumpSubEvent( stats )

	-- DUMPS A SUB EVENT IN A COMMA DELIMITED FORMAT.
	for i = 1, 24 do
		if i ~= 4 and i ~= 6 and i ~= 7 and i ~= 8 and i ~= 10 and i~= 11 then
			if stats[i] ~= nil then
				local value = nil
				dataType = type(stats[i])

				if dataType ~= "string" then
					value = tostring( stats[i] )
				else
					value = stats[i]
				end
				msgframe:postMsg( sprintf("arg[%d] %s, ", i, value ))
			else
				msgframe:postMsg( sprintf("arg[%d] nil, ", i))
			end
		end
	end
	msgframe:postMsg( sprintf("\n\n"))
end	
local function dbgDumpCELU()
	local num = #CELU_Table
	for _, stats in ipairs( CELU_Table ) do
		dbgDumpSubEvent( stats )
	end
end
local function tableCopy( originalTable )
	if #originalTable == 0 then return nil end
	local tCopy = {}
	for key, value in ipairs( originalTable ) do
		tCopy[key] = value
	end
	return tCopy
end
-- ********************************************************************************
--							TABLE SERVICES
-- ********************************************************************************
local function highToLow( nvp1, nvp2 )
	-- sort on the damage entry
	return nvp1[2] > nvp2[2]
end 
local function lowToHigh( nvp1, nvp2 )
	return nvp2[1] > nvp1[1]
end
local function printHealTable( t )

	table.sort(t, highToLow )
	local dataSet = {}
	for _,v in ipairs(t) do	
		-- entry = { spellName, damage, overKill, resisted, blocked, absorbed, 1}
		local spellName = v[1]
			
		-- dataSet = {spellName, amount }
		dataSet, result = getSpellDataSet( spellName )
		if dataSet == nil then
			emf:postErrorResult( result )
			return
		end
		if #dataSet > 0 then
			local mean, stdDev = calculateStats( dataSet )
			local str = sprintf("   %s: %d, Avg %0.1f healing per cast/tick (+/- %0.2f), %d casts.\n", v[1], v[2], mean, stdDev, v[5] )
			combatEventLog.Text:Insert( str )
		end
	end
end
local function printDmgTable( t )

	table.sort(t, highToLow )
	local dataSet = {}
	for _,v in ipairs(t) do	
		-- entry = { spellName, damage, overKill, resisted, blocked, absorbed, 1}
		if v[1] ~= nil then
			local spellName = v[1]
			
			-- dataSet = {spellName, amount }
			dataSet, result = getSpellDataSet( spellName )
			if #dataSet > 0 then
				local mean, stdDev = calculateStats( dataSet )
				local str = sprintf("   %s: %d, Avg %0.1f damage per hit (+/- %0.2f), %d casts.\n", v[1], v[2], mean, stdDev, v[7] )
				combatEventLog.Text:Insert( str )
			end
		end
	end
end
local function printSchoolTable()
	local t = spellSchools
	table.sort( t, highToLow)

	-- {schoolName, damage, healing, casts }
	for _,v in ipairs(t) do
		local schoolName = v[1]
		local damageDone = v[2]
		local healingDone = v[3]
		local castCount = v[4]
		local strDamage = sprintf( "   Damage %d\n", damageDone )
		local strHealing = sprintf("   Healing %d/n", healingDone)
		
		local str = nil
		if damageDone > 0 and healingDone > 0 then
			str = sprintf("    %s: Damage %d, Healing %d, Casts %d\n", schoolName, damageDone, healingDone, castCount )
		end
		if damageDone > 0 and healingDone == 0 then
			str = sprintf("    %s: Damage %d, Casts %d\n", schoolName, damageDone, castCount )
		end
		if damageDone == 0 and healingDone > 0 then
			str = sprintf("    %s: Healing %d, Casts %s\n", schoolName, healingDone, castCount )
		end
		combatEventLog.Text:Insert( str )
	end
end
local function mitigationEntryToString( entry )
	local missType = entry[1]
	local damageMitigated = entry[2]
	local count = entry[3]

	local s = nil
	if damageMitigated > 0 then
		s = sprintf("    %s: Total damage mitigated %d, Cast count %d\n", missType, damageMitigated, count )
	else
		s = sprintf("    %s: count %d\n", missType, count )
	end
end
local function printMissTypeEntries()
	if #missTypes == 0 then
		return
	end
	local t = missTypes
	local str = EMPTY_STR
	for i = ABSORB, RESIST do
		local entry = t[i]

		if entry[2] > 0 then
			local s = mitigationEntryToString( entry )
			if s ~= nil then	-- @@@
				str = str..s
			end
		end
	end
	if str == EMPTY_STR then
		return nil
	end
	local header = "Miss Type\n"..str
	combatEventLog.Text:Insert(sprintf("\n%s\n", header, str))
end
function fmtlog:dumpTables()

	if #spellSchools > 0 then
		combatEventLog.Text:Insert(sprintf("\nSCHOOL DAMAGE\n"))
		printSchoolTable()
	end
	if #dmgCastTimeSpells > 0 then
		combatEventLog.Text:Insert(sprintf("\nDAMAGE BY SPELL (ordered high to low):\n"))
		printDmgTable( dmgCastTimeSpells  )
	end
	if #dmgPeriodicSpells > 0 then
		combatEventLog.Text:Insert(sprintf("\nSpell periodic damage\n"))
		printDmgTable( dmgPeriodicSpells)
	end	
	if #dmgRangedSpells > 0 then
		combatEventLog.Text:Insert(sprintf("\nRanged damage\n"))
		printDmgTable( dmgRangedSpells )
	end
	if #dmgSwingSpells > 0 then
		combatEventLog.Text:Insert(sprintf("\nSwing damage\n"))
		printDmgTable( dmgSwingSpells )
	end
	if #dmgPetSpells > 0 then
		combatEventLog.Text:Insert(sprintf("\nPet damage\n"))
		printDmgTable( dmgPetSpells)
	end
	if #healSpells > 0 then
		combatEventLog.Text:Insert(sprintf("\nHealing spells\n"))
		printHealTable( healSpells )
	end
	if #periodicHealSpells > 0 then
		combatEventLog.Text:Insert(sprintf("\nPeriodic Spell Heals\n"))
		printHealTable( periodicHealSpells )
	end
	printMissTypeEntries()
	-- if missedTable> 0 then
	-- 	combatEventLog.Text:Insert( sprintf("\nMissed attacks (MISS, BLOCK, PARRY, etc.\n"))
	-- 	printMissedTableEntries()
	-- end
end
local function insertIntoSpellTable( spellName, amount )
	if amount == 0 then return end

	local entry = {spellName, amount }
	table.insert( spellTable, entry )	-- spellTable contains all spells
end
-- missedEntry = {missType, amountMissed, isOffHand, 1 }
local function insertEntryIntoMissTypes( entry )
	local isValid = false
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR }
	if dbg:debuggingIsEnabled() then
		isValid, result = dbgCheckMissTypeEntry( entry )
		if not isValid then
			return isValid, result
		end		
	end
	local t = missTypes

	if #t == 0 then
		table.insert(t, entry )
		return true, result
	end
	-- find the entry (if has already been entered) and update
	-- the entry's stats
	for _, v in ipairs(t) do
		if  v[1] == entry[1] then  	-- we've found the entry
			v[2] = v[2] + entry[2]	-- increase the amountMissed accumulator
			v[3] = v[3] + 1			-- cast counter
			return true, result
		end
	end
	-- we're here because this entry is not yet in the table.
	table.insert(t, entry)
	return true, result
end
-- 	local entry = {spellName, amount, overKill, resisted, blocked, absorbed, 1 }
local function insertEntryIntoDmgTable( t, entry )
	local isValid = true
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
	if dbg:debuggingIsEnabled() then
		isValid, result = dbgCheckDmgTableEntry( entry )
		if not isValid then
			return isValid, result
		end		
	end

	if #t == 0 then
		table.insert(t, entry )
		return isValid, result
	end
	-- this for-loop overwrites members of the existing entry
	for _, v in ipairs(t) do		
			if  v[1] == entry[1] then  	-- add the entry values to the entry's existing values
				v[2] = v[2] + entry[2]		-- accumulates the damage amount
				v[3] = entry[3]				-- overKill (amount)
				v[4] = entry[4]				-- resisted (amount)
				v[5] = entry[5]				-- blocked (amount)
				v[6] = entry[6]				-- absorbed (amount)
				v[7] = v[7] + 1				-- increments the number of casts or ticks
			return isValid, result
		end
	end
	-- we're here because this entry is not yet in the table.
	table.insert(t, entry)
	return isValid, result
end
-- entry = {spellName, amount, overhealing, absorbed, 1 }
local function insertEntryIntoHealTable( t, entry )	
	local isValid = false
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR }
	if dbg:debuggingIsEnabled() then
		isValid, result = dbgCheckHealEntry( entry )
		if not isValid then
			return isValid, result
		end
	end
	local wasEntered = false
	
	-- if this is the first entry
	if #t == 0 then
		table.insert(t, entry )
		isValid = true
		return isValid, result
	end

	wasEntered = false
	for _, v in ipairs(t) do
		if  v[1] == entry[1] then	-- spellName
			v[2] = v[2] + entry[2]	-- amount healed
			v[3] = v[3] + entry[3]	-- overHealing accumulator
			v[4] = v[4] + entry[4]	-- increment the absorbed accumulator
			v[5] = v[5] + 1			-- increment the cast counter
			isValid = true
			wasEntered = true
		end
	end
		-- we're here because this entry was not found in the table.
	if wasEntered == false then
		table.insert(t, entry )
		isValid = true
	end
	return isValid, result
end
-- entry = { schoolName, damageAmount, healAmount, 1 }
local function insertEntryIntoSchoolTable( entry )
	local isValid = true
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR }

	if dbg:debuggingIsEnabled() then
		isValid, result = dbgCheckSchoolEntry( entry )
		if not isValid then
			return isValid, result
		end
	end

	if #spellSchools == 0 then
		table.insert( spellSchools, entry )
		return isValid, result
	end

	isValid = false
	for _, v in ipairs(spellSchools) do
		if  v[1] == entry[1] then		-- schoolName of spell
			v[2] = v[2] + entry[2]	-- damage accumulator (healing or damage)
			v[3] = v[3] + entry[3]	-- healing accumulator
			v[4] = v[4] + 1			-- increment the cast counter
			isValid = true
		end
	end
		
	-- we're here because this must be new entry, i.e., not
	-- yet entered in the table
	if not isValid then
		table.insert(spellSchools, entry )
		isValid = true
	end
	return isValid, result
end
-- totalDmg, totalCritDmg = getDamageByTable(t)
-- where totalDmg includes the totalCritDmg
local function getDamageByTable(t)
	local totalDmg = 0
	local totalCritDmg = 0
	local overKill = 0
	local resisted = 0
	local blocked = 0
	local absorbed = 0

	-- 	local entry = {spellName, amount, overKill, resisted, blocked, absorbed, 1 }
	for _,v in ipairs(t) do
		totalDmg = totalDmg + v[2]
		if v[7] == true then
			totalCritDmg = totalCritDmg + v[2]
		end
	end
	return totalDmg, totalCritDmg 
end
local function getHealingByTable(t)
	local healing = 0

	-- entry = {spellName, amount, overhealing, absorbed, 1 }
	for _,v in ipairs(t) do
		healing = healing + v[2]
	end
	return healing
end
local function getDmgCastsByTable(t)
	local casts = 0
	for _,v in ipairs(t) do
		casts = casts + v[7]		
	end
	return casts
end
local function getHealCastsByTable(t)
	local casts = 0
	if #t == 0 then
		return casts
	end
	for _,v in ipairs(t) do
		casts = casts + v[5]
	end
	return casts
end

local function totalDamage()
	local dmg = 0

	-- NOTE: getDamageByTable returns dmg, overKill, resisted, blocked, absorbed
	local totalDmg = 0
	local totalCritDmg = 0
	local dmg = 0
	local critDmg = 0

	dmg, critDmg = getDamageByTable( dmgCastTimeSpells )
	totalDmg = dmg + totalDmg
	totalCritDmg = totalCritDmg + critDmg
	
	dmg, critDmg = getDamageByTable( dmgPeriodicSpells)	
	totalDmg = dmg + totalDmg
	totalCritDmg = totalCritDmg + critDmg

	dmg, critDmg = getDamageByTable( dmgRangedSpells )
	totalDmg = dmg + totalDmg
	totalCritDmg = totalCritDmg + critDmg

	dmg, critDmg = getDamageByTable( dmgSwingSpells )
	totalDmg = dmg + totalDmg
	totalCritDmg = totalCritDmg + critDmg

	dmg, critDmg = getDamageByTable( dmgPetSpells )
	totalDmg = dmg + totalDmg
	totalCritDmg = totalCritDmg + critDmg

	return totalDmg, totalCritDmg
end
local function totalDmgCasts()
	local casts = 0
	local   casts = casts + getDmgCastsByTable( dmgCastTimeSpells )
	casts = casts + getDmgCastsByTable( dmgPeriodicSpells)	
	casts = casts + getDmgCastsByTable( dmgRangedSpells )
	casts = casts + getDmgCastsByTable( dmgPetSpells )
	casts = casts + getDmgCastsByTable( dmgSwingSpells )
	return casts
end
local function spellPower()
	return totalDamage() / totalDmgCasts()
end
-- returns totalHealing, periodicHealing, and critHealing
local function totalHealing()
	local totalHealing = getHealingByTable( healSpells )
	local periodicHealing = getHealingByTable( periodicHealSpells )
	local critHealing = getHealingByTable( critHealSpells )

	return totalHealing, periodicHealing, critHealing
end
local function totalHealingCasts()
	local total 	= getHealCastsByTable( healSpells )
	local periodic 	= getHealCastsByTable( periodicHealSpells )
	local crit 		= getHealCastsByTable( critHealSpells )
	return total, periodic, crit
end
local function healingPower()
	local totalHealing = getHealingByTable( healSpells )
	local totalCasts = getHealCastsByTable( healSpells )
	if totalCasts == 0 then
		return 0.00
	end

	return totalHealing/totalCasts
end
function fmtlog:resetGlobals()
	totalCasts 			= 0
	elapsedTime			= 0
	initialTimeStamp 	= 0

	spellTable 		= {}
	spellTableCrits 	= {}
	instantCastTable 	= {}
	timedCastTable 		= {}
   
	CELU_Table			= {}
end
local function getSpellSchoolName( spellSchoolIndex )
	local spellSchoolName = nil
	for _, v in ipairs(spellSchoolNames) do
		if v[1] == spellSchoolIndex then
			spellSchoolName = v[2]
		end
	end
	return spellSchoolName
end	
local function processStats( stats )

end
-- ********************************************************************
--				COLLECT AND LOGGING SUBEVENT FUNCTIONS
-- ********************************************************************
local function collectAuraEntries( stats )
	local subEvent		= stats[SUBEVENT]
	local spellName 	= stats[SPELLNAME]
	local auraType		= stats[15]
	local auraAmount	= stats[16] 
	local sourceName 	= stats[SOURCENAME]
	local targetName	= stats[TARGETNAME]
	local logEntry		= nil
	local reason 		= sprintf("OPERATION FAILED: Entry for key %s not found. - \n%sSTACK TRACE:\n", spellName, debugstack()  )

	if auraAmount == nil then auraAmount = 0 end
			
	-- Triggered when an aura is removed by melee damage. The source is the name of the caster who applied the aura. The destination
	-- is the target from which the aura was removed.
	if subEvent == "SPELL_AURA_BROKEN" then
		-- dbgDumpSubEvent( stats )
		auraType = stats[15]
		logEntry = sprintf("%s broken\n", spellName )
	end

	-- Triggered when a spell is broken by another spell (in extraSpell field)
	-- brokenSpellId = stats[15], brokenSpellName = stats[16], brokenSpellSchool = stats[17], brokenAuraType = stats[18]
	if subEvent == "SPELL_AURA_BROKEN_SPELL" then
		-- dbgDumpSubEvent( stats )
		local brokenSpellName 		= stats[16]
		local brokenSpellSchool 	= stats[17]
		local brokenAuraType 		= stats[18]
		logEntry = sprintf("%s removed from %s\n",  brokenSpellName, targetName )
	end
	if subEvent == "SPELL_AURA_BROKEN" then
		-- dbgDumpSubEvent( stats )
		local brokenSpellName 		= stats[16]
		local brokenSpellSchool 	= stats[17]
		local brokenAuraType 		= stats[18]
		logEntry = sprintf("%s removed from %s\n",  brokenSpellName, targetName )
	end

	if subEvent == "SPELL_AURA_APPLIED" then 
		-- dbgDumpSubEvent( stats )
		if auraAmount > 0 then
			if auraType == "BUFF" then
				logEntry = sprintf("%s gains %s (%d HP)\n", targetName, spellName, auraAmount  )
			else
				logEntry = sprintf("%s debuffed by %s (%d HP)\n", targetName, spellName, auraAmount  )
			end
		else
			if auraType == "BUFF" then
				logEntry = sprintf("%s gains %s (Crusader Proc)\n", targetName, spellName )
				UIErrorsFrame:AddMessage( "Crusader Proc", 1.0, 1.0, 0.0, 8 ) 

			else
				logEntry = sprintf("%s applied to %s\n", spellName, targetName )
			end
		end
	end
	if subEvent == "SPELL_AURA_APPLIED_DOSE" then 
		-- dbgDumpSubEvent( stats )
		if auraAmount > 0 then
			if auraType == "BUFF" then
				logEntry = sprintf("%s buffed targetName by %d\n", spellName, targetname, auraAmount )
			else
				logEntry = sprintf("%s applied %d to %s\n", spellName, auraAmount, targetName  )
			end
		else
			if auraType == "BUFF" then
				logEntry = sprintf("%s gains %s\n", sourceName, spellName )
			else
				logEntry = sprintf("%s applied to %s\n",  spellName, targetName )
			end
		end
	end

	-- triggered when buffs/debuffs expire. The source is the caster of the aura and the destination is the target from which
	-- the aura was removed.
	if subEvent == "SPELL_AURA_REMOVED" then 	
		-- dbgDumpSubEvent( stats )
		-- if auraAmount > 0 then
		-- 					-- Warfie removed 7 (DEBUFF) from enemy
		-- 	logEntry = sprintf("%s removed %d HP from %s\n", spellName, auraAmount, auraType, targetName ) 
		-- else
							-- Warfie removed DEBUFF from Enemy
			if spellName == "Holy Strength" then
				UIErrorsFrame:AddMessage( "Crusader Proc Expired", 1.0, 1.0, 0.0, 8 ) 
			end
			logEntry = sprintf("%s expired or removed\n",spellName, targetName ) 
		-- end
	end
	if subEvent == "SPELL_AURA_REMOVED_DOSE" then
		-- dbgDumpSubEvent( stats )
		-- if auraAmount > 0 then
		-- 					-- Frostbolt remove 7 (DEBUFF) from Enemy
		-- 	logEntry = sprintf("%s removed %d (%s) from %s\n",  spellName, auraAmount, auraType, targetName ) 
		-- else
		-- 					-- Frostbolt removed from Enemy
			logEntry = sprintf("%s expired\n", spellName ) 
		-- end
	end
	return logEntry
end
-- A miss is a failed attack; it deals no damage and will not proc any mechanic 
-- that may have resulted from a successful attack.
local function createMissedEntry( stats )
	local subEvent 		= stats[SUBEVENT]
	local sourceName 	= stats[SOURCENAME]
	local targetName 	= stats[TARGETNAME]
	local spellName 	= stats[SPELLNAME]
	local missType		= stats[15]
	local isOffHand		= stats[16]
	local amountMissed 	= stats[17]
	local isCritical	= stats[18]
	local isValid 		= true
	local result		={SUCCESS, EMPTY_STR, EMPTY_STR }

	if stats[SUBEVENT] == "SWING_MISSED" then
		spellName 		= "melee swing"
		missType		= stats[12]
		amountMissed 	= stats[14]
		isCritical	= stats[15]
	end

	if amountMissed == nil or amountMissed == EMPTY_STR then
		amountMissed = 0
	end

	local missEntry = {missType, amountMissed, 1 }
	isValid, result = insertEntryIntoMissTypes( missEntry )
	if not isValid then
		return nil, result
	end

	return missEntry, result
end
local function collectMissedEntries( stats)
	local subEvent = stats[SUBEVENT]
	local sourceName 	= stats[SOURCENAME]
	local targetName 	= stats[TARGETNAME]
	local spellName 	= stats[SPELLNAME]
	local logEntry		= nil
	local result		= {SUCCESS, EMPTY_STR, EMPTY_STR}

	if subEvent == "SWING_MISSED" then
		spellName = "melee swing"
	end		
	local missEntry, result = createMissedEntry( stats )
	if missEntry == nil then
		return nil, result
	end

	local amountMissed = missEntry[2]
	local missType = missEntry[1]

 	local missStr = nil
	if missType == "ABSORB" then
		missStr = "absorbed"
	end
	if missType == "BLOCK" then
		missStr = "blocked"
	end
	if missType == "DEFLECT" then
		missStr = "deflected"
	end
	if missType == "IMMUNE" then
		missStr = "was immune"
	end
	if missType == "DODGE" then
		missStr = "dodged"
	end
	if missType == "MISS" then
		missStr = "missed"
	end
	if missType == "PARRY" then
		missStr = "parried"
	end
	if missType == "REFLECT" then
		missStr = "reflected"
	end
	if missType == "RESIST" then
		missStr = "resisted"
	end
	--[[
	-- ]]

	if amountMissed > 0 then
		logEntry = sprintf("%s avoided %s's %s by %d damage (%s)\n", targetName, sourceName, spellName, amountMissed, missType )
	end
	if amountMissed == 0 then
		logEntry = sprintf("%s avoided %s's %s (%s)\n", targetName, sourceName, spellName, missType )
	end
	return logEntry, result
end
local function createRangedEntry( stats )
	local spellName 	= stats[13]
	local schoolId		= stats[14]
	local damage		= stats[15] 
	local blocked		= stats[16]
	local resisted		= stats[18]
	local overKill		= stats[19]
	local absorbed		= stats[20]
	local isCritical	= stats[21]
	local isValid 		= true
	local result		= {SUCCESS, EMPTY_STR, EMPTY_STR }

	insertIntoSpellTable( spellName, damage )

	local schoolName = getSpellSchoolName( schoolId )
	local schoolEntry = {schoolName, damage, 0, 1}
	isValid, result = insertEntryIntoSchoolTable( schoolEntry)
	if not isValid then
		return isValid, result
	end

	if overKill == nil then overKill = 0 end
	if resisted == nil then resisted = 0 end
	if blocked  == nil then blocked  = 0 end
	if absorbed == nil then absorbed = 0 end

	local entry = {spellName, damage, overKill, resisted, blocked, absorbed, 1 }

	isValid, result = insertEntryIntoDmgTable( dmgRangedSpells, entry )
	if not isValid then
		return isValid, result
	end

	if isCritical then
		isValid, result = insertEntryIntoDmgTable( critRangeDmg, entry )
		if not isValid then
			return isValid, result
		end	
	end

	return isValid, result
end
local function collectRangedEntries(stats)
	return (createRangedEntry( stats ))
end
local function createSwingEntry( stats )
	local spellName 	= "melee swing"
	local damage		= stats[12] 
	local overKill		= stats[13]
	local schoolId		= stats[14]
	local resisted		= stats[15]
	local blocked		= stats[16]
	local absorbed		= stats[17]
	local isCritical	= stats[18]
	local isValid 		= true
	local result		= {SUCCESS, EMPTY_STR, EMPTY_STR }

	insertIntoSpellTable( spellName, damage )


	local schoolName = getSpellSchoolName( schoolId )
	local schoolEntry = {schoolName, damage, 0, 1}
	isValid, result = insertEntryIntoSchoolTable( schoolEntry)
	if not isValid then
		return isValid, result, nil
	end

	if overKill == nil then overKill = 0 end
	if resisted == nil then resisted = 0 end
	if blocked  == nil then blocked  = 0 end
	if absorbed == nil then absorbed = 0 end

	local entry = {spellName, damage, overKill, resisted, blocked, absorbed, 1 }
	isValid, result = insertEntryIntoDmgTable( dmgSwingSpells, entry )
	if not isValid then
		return isValid, result
	end
	if isCritical then
		isValid, result = insertEntryIntoDmgTable( critSwingDmg, entry )
		if not isValid then
			return isValid, result
		end	
	end

	local _, _, playersPet = eqs:getPlayerInfo()
	if stats[SOURCENAME] == playersPet then
		isValid, result = insertEntryIntoDmgTable( dmgPetSpells, entry )
		if not isValid then
			return isValid, result
		end
		if isCritical then
			isValid, result = insertEntryIntoDmgTable( critPetDmg, entry )
			if not isValid then
				return isValid, result
			end
		end
	end
	return isValid, result
end
local function collectSwingEntries(stats)
	return (createSwingEntry( stats ))
end
local function createHealEntry( stats )
	local subEvent		= stats[SUBEVENT]
	local spellName 	= stats[SPELLNAME]
	local amountHealed	= stats[AMOUNT_HEALED] 
	local overHealed	= stats[16]
	local absorbed		= stats[17]/898
	local isCritical	= stats[18]

	local isValid		= false
	local result		= {SUCCESS, EMPTY_STR, EMPTY_STR}

	if overHealed == nil then overHealed = 0 end
	if absorbed == nil then absorbed = 0 end
	if amountHealed == nil then amountHealed = 0 end

	local entry = {spellName, amountHealed, overHealed, absorbed, 1 }
	insertIntoSpellTable( spellName, amountHealed )
	
	-- all spells (normal, dot, and crit spells)
	isValid, result = insertEntryIntoHealTable( healSpells, entry )
	if not isValid then
		return isValid, result
	end
	if subEvent == "SPELL_PERIODIC_HEAL" then
		isValid, result = insertEntryIntoHealTable( periodicHealSpells, entry )
		if not isValid then
			return isValid, result
		end
	end
	return isValid, result
end
local function collectHealEntries( stats )
	return (createHealEntry(stats))
end
-- called by collectSpellEntries()
local function createSpellEntry( stats )
	local subEvent 		= stats[SUBEVENT]
	local sourceName	= stats[SOURCENAME]
	local spellName 	= stats[SPELLNAME]
	local spellSchool 	= getSpellSchoolName( stats[SCHOOL_INDEX])
	local damage		= stats[AMOUNT_DAMAGED] 
	local overKill		= stats[OVERKILL]
	local resisted		= stats[RESISTED]
	local blocked		= stats[BLOCKED]
	local absorbed		= stats[ABSORBED]
	local isCritical	= stats[CRITICAL]
	local isValid 		= true
	local result		= {SUCCESS, EMPTY_STR, EMPTY_STR }
	local isValid 		= true

	if overKill == nil then overKill = 0 end
	if resisted == nil then resisted = 0 end
	if blocked  == nil then blocked  = 0 end
	if absorbed == nil then absorbed = 0 end

	local entry = {spellName, damage, overKill, resisted, blocked, absorbed, 1 }
	isValid, result = dbgCheckDmgTableEntry( entry )
	if not isValid then
		return isValid, result
	end

	insertIntoSpellTable( spellName, damage )

	local t = dmgCastTimeSpells
	if subEvent == "SPELL_PERIODIC_DAMAGE" then
		t = dmgPeriodicSpells
	end
	isValid, result = insertEntryIntoDmgTable( t, entry )
	if not isValid then
		return isValid, result
	end
	if isCritical then
		isValid, result = insertEntryIntoDmgTable( critSpellDmg, entry )
		if not isValid then
			return isValid, result
		end
	end
	if sourceName == playersPet then
		isValid, result = insertEntryIntoDmgTable( dmgPetSpells, entry )
		if not isValid then
			return isValid, result
		end
		if isCritical then
			isValid, result = insertEntryIntoDmgTable( critPetDmg, entry )
			if not isValid then
				return isValid, result
			end
		end
	end
	return isValid, result
end
local function collectSpellEntries(stats)
	return ( createSpellEntry( stats ))
end
-- -- see https://wow.gamepedia.com/Detecting_an_instant_cast_spell
-- 	-- instantCast is {spellName, nil, "SPELL_CAST_SUCCESS"}
-- 	-- timedCast is   {spellName, "SPELL_CAST_START", "SPELL_CAST_SUCCESS"}
local function updateCastTable( stats )

	local sourceName = stats[SOURCENAME]
	local subEvent = stats[SUBEVENT]
	local spellName = stats[SPELLNAME]
	local targetName = stats[TARGETNAME]
	local isInstant = false

	-- Cast Descriptor for timed cast is castDescr = {spellName, "SPELL_CAST_START", "SPELL_CAST_SUCCESS"}
	local castDescr = { spellName, nil, nil }
	if subEvent == "SPELL_CAST_START" then	
		castDescr = {spellName, subEvent, nil}
		table.insert( timedCastTable, castDescr )
		totalCasts = totalCasts + 1
		return isInstant
	end

	-- Cast Descriptor for an instantCast is castDescr = {spellName, "SPELL_CAST_SUCCESS", nil }
	isInstant = true
	if subEvent == "SPELL_CAST_SUCCESS" or subEvent == "SPELL_CAST_FAILED" or subEvent == "SPELL_INTERRUPT" then
		-- check whether this spell is in the cast table. If it's not, then
		-- it's an instant spell.
		castDescr = {spellName, nil, subEvent }
		if #timedCastTable == 0 then
			table.insert( instantCastTable, castDescr )
			totalCasts = totalCasts + 1
			return isInstant
		end

		for _, v in ipairs( timedCastTable ) do
			if v[1] == spellName then
				isInstant = false
				return isInstant
			end
		end

		if instant then
			castDescr = {spellName, nil, subEvent }
			table.insert( instantCastTable, castDescr )
			totalCasts = totalCasts + 1
		end
	end 
end
local function getCountInstantCasts()
	return #instantCastTable
end
local function printPlayerStats()
    local playersName, playersClass, petsName, iLevel, equipSetName, equipStats = eqs:getPlayerInfo()
    if petName == nil then
        petName = "No pet present."
	end
	local str = nil
	
	if equipSetName ~= nil then
		str = sprintf("%s - An iLevel %0.1d %s\n    Equipment Set *** %s ***\n", string.upper(playersName), iLevel, playersClass, equipSetName )
	else
		str = sprintf("%s - An iLevel %0.1d %s\n", string.upper(playersName), iLevel, playersClass )
	end
	local _, spellCritBonus = eqs:getCombatRatings( CR_CRIT_SPELL)
	local spellCritChance = GetCritChance()
	str = str..sprintf("    Critical strike (theoretical) %0.2f%% (+%0.2f%%)\n", spellCritChance, spellCritBonus )

    for i = 1, 7 do
        local nvp = equipStats[i]
        if nvp[2] > 0 then
            str = str..sprintf("    %s, %.2d\n", nvp[1], nvp[2])
        end
	end
	
	return str
end
function fmtlog:summarizeEncounter()

	-- damage stats
	local totalDmg, totalCritDmg = totalDamage()
	local encounterElapsedTime = comlog:getElapsedTime()
	if totalDmg > 0 then
		
		local header = printPlayerStats()	
		local periodicDmg, periodicCritDmg 	= getDamageByTable( dmgPeriodicSpells )

		local castDmg, critCastDmg	= getDamageByTable( dmgCastTimeSpells ) 
		local petDmg, critPetDmg 		= getDamageByTable( dmgPetSpells )
		local physicalDmg, critPhysicalDmg	= getDamageByTable( dmgSwingSpells )

		if totalCasts == 0 then
			spellPwr = 0
		else
			spellPwr = totalDmg/totalCasts
		end
		
		local critPercent	= ( totalCritDmg/totalDmg ) * 100

		local dataStr = nil

		local s1 = sprintf("\nTOTAL DAMAGE: %d, Elapsed Time: %0.1f seconds.\n", totalDmg, encounterElapsedTime )
		if castDmg > 0 then
			local s2 = sprintf("    Cast Damage: %d\n", castDmg )
			dataStr = s1..s2
		end

		if periodicDmg > 0 then
			local s = sprintf("    Dot Damage: %d\n", periodicDmg )
			dataStr = dataStr..s
		end
		if petDmg > 0 then
			local s = sprintf("    Pet Damage: %d (%0.1f%% of total\n", petDmg, (petDmg/totalDmg)*100 )
			dataStr = dataStr..s
		end
		if totalCritDmg > 0 then
			local s = sprintf("    Critical damage: %d (%0.1f%% of total)\n", totalCritDmg, (totalCritDmg/totalDmg)*100 )
			dataStr = dataStr..s
		end
		if physicalDmg > 0 then
			local s = sprintf("    Physical Damage: %d\n", physicalDmg )
			dataStr = dataStr..s
		end
		if spellPwr > 0 then
			local s = sprintf("    Spell Power: %0.1f\n", spellPwr )
			dataStr = dataStr..s
		end
		if totalCasts > 1 then
			local s = sprintf("    Damage Per Second (DPS): %0.1f\n", totalDmg/encounterElapsedTime )
			dataStr = dataStr..s
		end

		combatEventLog.Text:Insert(sprintf("%s\n", header))
		combatEventLog.Text:Insert( sprintf("----------------------------\n"))
		combatEventLog.Text:Insert( sprintf("COMBAT PERFORMANCE\n"))
		combatEventLog.Text:Insert( sprintf("----------------------------\n"))
		combatEventLog.Text:Insert( dataStr )
		printSchoolTable()
	end

	-- returns totalHealing, periodicHealing, and critHealing
	local healingTotal, periodicHealing, critHealing = totalHealing()
	local totalCasts, periodicCasts, critCasts = totalHealingCasts()
	if healingTotal > 0 then

		if healingTotal > 0 then
			local tmpStr = sprintf("\nTOTAL HEALING: %d (%d casts)",  healingTotal, totalCasts )
			combatEventLog.Text:Insert(sprintf("%s\n", tmpStr))
			if periodicHealing > 0 then
				local s = sprintf("    Periodic Healing: %d (%d casts)", periodicHealing, periodicCasts )
				combatEventLog.Text:Insert(sprintf("%s\n", s))
			end
			if critHealing > 0 then
				local s = sprintf("    Critical Healing: %d (%d casts)", critHealing, critCasts )
				combatEventLog.Text:Insert(sprintf("%s\n", s))
			end
			local s = sprintf("    Healing Spell Power: %0.1f", healingPower() ) 
			combatEventLog.Text:Insert(sprintf("%s\n", s))
		end
	end
end
-- -- { order, timeStamp, stats }
function insertStatsCELU( stats )
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR }

	local entry = { stats[TIMESTAMP], stats }
	table.insert(CELU_Table, entry )
	return stats[SUBEVENT], result
end
function fmtlog:handleEvent( stats )

	local subEvent, result = insertStatsCELU( stats )	
	-- ***********************************************************
	--				COLLECT SPELL_LEECH SUBEVENTS
	-- ***********************************************************
	if subEvent == "SPELL_LEECH" then
		--dbgDumpSubEvent( stats )
		-- stats[15] = amount leeched
		-- stats[16] = what was leeched
		-- stats[17] = extra amount
		return
	end
	-- ***********************************************************
	--				COLLECT SPELL_SUMMON SUBEVENTS
	-- ***********************************************************
	if subEvent == "SPELL_SUMMON" then
		return
	end
	-- ***********************************************************
	--				COLLECT ALL SPELL_MISSED EVENTS
	-- ***********************************************************
	if  subEvent 	== "SPELL_MISSED" or
		subEvent 	== "RANGE_MISSED" or
		subEvent 	== "SWING_MISSED" or
		subEvent 	== "SPELL_PERIODIC_MISSED" then
			
			isValid, result = collectMissedEntries( stats )
			local logEntry = tostring( stats[15])
			-- comlog:postLogEntry( stats[21], stats[15], true )
	end

	-- ***********************************************************
	--				COLLECT ALL AURA SUBEVENTS
	-- ***********************************************************
	-- if  subEvent == "SPELL_AURA_APPLIED" or
	-- 	subEvent == "SPELL_AURA_APPLIED_DOSE" or
	-- 	subEvent == "SPELL_AURA_REMOVED" or
	-- 	subEvent == "SPELL_AURA_REMOVED_DOSE" or
	-- 	subEvent == "SPELL_AURA_BROKEN" or
	-- 	subEvent == "SPELL_AURA_BROKEN_SPELL" then
			-- local isCritical, logEntry = collectAuraEntries( stats )
			-- comlog:postLogEntry( false, logEntry )
	-- 		return
	-- end
		-- ***********************************************************
	--				COLLECT ALL HEAL SUBEVENTS
	-- ***********************************************************
	if subEvent == "SPELL_HEAL" or subEvent == "SPELL_PERIODIC_HEAL" then
		local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

		local isCritical = stats[21]
		local logEntry = tostring(stats[15])
		comlog:postLogEntry( isCritical, logEntry, false )

		table.insert( subEventTable, subEvent )
	end
	-- ***********************************************************
	--				COLLECT ALL SPELL DAMAGE SUBEVENTS
	-- ***********************************************************
	if 	subEvent == "SPELL_DAMAGE" or subEvent == "SPELL_PERIODIC_DAMAGE" then
		local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

		local isCritical = stats[21]
		local logEntry = tostring(stats[15])
		comlog:postLogEntry( isCritical, logEntry, true )

		table.insert( subEventTable, subEvent )
	end
	-- ***********************************************************
	--				COLLECT ALL RANGE DAMAGE SUBEVENTS
	-- ***********************************************************
	if 	subEvent == "RANGE_DAMAGE" then
		local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

		local isCritical = stats[21]
		local logEntry = tostring(stats[15])
		comlog:postLogEntry( isCritical, logEntry, true )

		table.insert( subEventTable, subEvent )
	end
	-- ***********************************************************
	--				COLLECT ALL SWING DAMAGE SUBEVENTS
	-- ***********************************************************
	if 	subEvent == "SWING_DAMAGE" then
		local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

		local isCritical = stats[18]
		local logEntry = tostring(stats[12])
		comlog:postLogEntry( isCrital, logEntry, true )

		table.insert( subEventTable, subEvent )
end
-- **************************************************************************************
--						SLASH COMMANDS
-- **************************************************************************************
-- function fmtlog:hideHelpFrame()
-- 	if helpFrame == nil then
-- 		return
-- 	end
-- 	if helpFrame:IsVisible() == true then
-- 		helpFrame:Hide()
-- 	end
-- end
-- function fmtlog:showHelpFrame()
-- 	if helpFrame == nil then
-- 		helpFrame = comlog:createHelpFrame()
-- 	end
-- 	if helpFrame:IsVisible() == false then
-- 		helpFrame:Show()
-- 	end
-- end
-- function fmtlog:clearHelpText()
-- 	if helpFrame == nil then
-- 		return
-- 	end
-- 	helpFrame.Text:EnableMouse( false )    
-- 	helpFrame.Text:EnableKeyboard( false )   
-- 	helpFrame.Text:SetText(EMPTY_STR) 
-- 	helpFrame.Text:ClearFocus()
-- end

-- local line1  = sprintf("\n%s: slash commands\n", L["ADDON_NAME"])
-- local line2  = sprintf("   help - This message\n")
-- local line3  = sprintf("   replay - Replays events of the most recent combat encounter.\n")
-- local helpMsg = line1..line2..line3

-- local function postHelpMsg( helpMsg )
-- 	if helpFrame == nil then
-- 		helpFrame = fm:createHelpFrame( L["HELP_FRAME_TITLE"])
-- 	end
-- 	fm:showFrame( helpFrame )
-- 	helpFrame.Text:Insert( helpMsg )
-- end
-- SLASH_CombatSimulator1 = "/caar"
-- SlashCmdList["CombatSimulator"] = function( msg )
-- 	if msg == nil then
-- 		msg = "help"
-- 	end
-- 	if msg == EMPTY_STR then
-- 		msg = "help"
-- 	end

-- 	msg = string.upper( msg )

-- 	if msg == "HELP" then
-- 		postHelpMsg( helpMsg )

-- 	elseif msg == "REPLAY" then
-- 		local tCopy = tableCopy( CELU_Table )
-- 		fmtlog:resetGlobals()
-- 		for _, v in ipairs( tCopy ) do
-- 			local stats = v[2]
-- 			fmtlog:handleEvent( stats )	
-- 		end
-- 		CELU_Table = tableCopy( tCopy )
-- 	else
-- 		local s = sprintf("CombatSimulator: '%s' - unknown or invalid command.\n", msg)
-- 		postHelpMsg( s..helpMsg )
-- 	end
-- 	-- end
-- end

local fileName = "FormatCombatLog.lua"
if simcore:debuggingIsEnabled() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded.", fileName ), 0.0, 1.0, 0.0 )
end
