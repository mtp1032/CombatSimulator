--------------------------------------------------------------------------------------
-- FormatEvent.lua 
-- AUTHOR: Michael Peterson 
-- ORIGINAL DATE: 5 October, 2022
--------------------------------------------------------------------------------------
local _, CombatSimulator = ...
CombatSimulator.FormatEvent = {}
fmt = CombatSimulator.FormatEvent

local sprintf = _G.string.format
local L = CombatSimulator.L
local sprintf = _G.string.format

-- ******************************************************
--      IMPORT THESE CONSTANTS FROM WOWTHREADS
-- ******************************************************
local SIG_ALERT             = simcore.SIG_ALERT
local SIG_JOIN_DATA_READY   = simcore.SIG_JOIN_DATA_READY
local SIG_TERMINATE         = simcore.SIG_TERMINATE
local SIG_METRICS           = simcore.SIG_METRICS
local SIG_NONE_PENDING      = simcore.SIG_NONE_PENDING

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

local formattedEntryDB = {}
local publisher_h = nil
function fmt:setPublisherThread( thread_h )
    publisher_h = thread_h
    assert( publisher_h ~= nil, "ASSERT_FAILED" .. L["THREAD_HANDLE_NIL"])
end

-- returns entry, #remainingElements
local function getFormattedEntry()
    if #formattedEntryDB == 0 then return nil, 0 end

    local entry = table.remove( formattedEntryDB, 1 )
    return entry, #formattedEntryDB
end


local function getSubevent( stats )
    return stats[2]
end
local function getIsCrit( stats )
    local subEvent = stats[2]

    if subEvent == "SWING_DAMAGE" then
        return stats[18]
    end
    return stats[21]
end
local function getAmount( stats )
    local subEvent = stats[2]

    if subEvent == "SWING_DAMAGE" then
        return stats[12]
    end
    return stats[15]
end
function fmt:formatEntry( stats )

    -- entry = { combatType, isCrit, amount }

    local combatType    = getSubevent( stats )
    local isCrit        = getIsCrit( stats )
    local amount        = getAmount( stats )

    local entry = { combatType, isCrit, amount }
    return entry
end

-- format_h action routine
function fmt:stats()
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
	local signal = SIG_NONE_PENDING
    -- dbg:print( "ENTERED fmt:stats() ")
    local self_h, threadId = thread:self()
    dbg:print("Format_h Id " .. tostring(threadId ))

	while signal ~= SIG_TERMINATE do
        -- dbg:print()
        thread:yield()
		signal, sender_h = thread:getSignal()
        -- mf:postMsg( sprintf("%s received %s.\n", E:prefix() , thread:getSignalName(signal) ))
        if signal == SIG_ALERT then
		
			local stats, count = celu:getDbEntry()
            if stats == nil then dbg:print( "stats are nil") end
            while stats ~= nil do
                local entry = formatEntry( stats )
                table.insert( formattedEntryDB, entry )
                result = thread:sendSignal( publisher_h, SIG_ALERT )
                if not result[1] then mf:postResult( result ) end
            end
		end
        -- dbg:print()
    end
    dbg:print(" EXITED WHILE-LOOP, EXITING fmt:stats() ")
end

local fileName = "FormatEvent.lua"
if simcore:debuggingIsEnabled() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded.", fileName ), 0.0, 1.0, 0.0 )
end
