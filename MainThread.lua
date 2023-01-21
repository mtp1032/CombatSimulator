--------------------------------------------------------------------------------------
-- MainThread.lua 
-- AUTHOR: Michael Peterson 
-- ORIGINAL DATE: 5 October, 2022
--------------------------------------------------------------------------------------
local _, CombatSimulator = ...
CombatSimulator.MainThread = {}
main = CombatSimulator.MainThread

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

local main_h      = nil
local publisher_h = nil
local format_h    = nil

local function main()
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
    local yieldInterval = 90   -- about 6 seconds

        ----------------------------------------------------------------------
    --                  create the publisher thread
    --   signaled by format_h when formattedEntry is ready for display
    ----------------------------------------------------------------------
    publisher_h, result = thread:create( yieldInterval, function()publish:celuEntry() end )
    if not result[1] then mf:postResult( result ) return end
    celu:setPublisherThread( publisher_h )
    ----------------------------------------------------------------------
    --                  create the formatting thread
    --          signaled by Celu when stats entered into DB
    ----------------------------------------------------------------------
    -- format_h, result = thread:create( yieldInterval, function() fmt:stats() end )
    -- assert( format_h ~= nil,"ASSERT_FAILED: " .. result[2] )
    -- assert( result[1] == SUCCESS, "ASSERT_FAILED: " .. result[2])
    -- if not result[1] then mf:postResult( result ) return end
    -- celu:setFormatThread( format_h )
    


    while signal ~= SIG_TERMINATE do
      thread:yield()
      signal, sender_h = thread:getSignal()
    end

    -- we're here because we've received a SIG_TERMINATE signal
    result = thread:sendSignal( format_h, SIG_TERMINATE )
    if not result[1] then mf:postResult( result ) end
    
    result = thread:sendSignal( publisher_h, SIG_TERMINATE )
    if not result[1] then mf:postResult( result ) end
end

-- *** FIRE UP THE MAIN THREAD ***
local yieldInterval = 600    -- ~ 6 seconds
local threadId = 0
main_h, result = thread:create( yieldInterval, main )
if not result[1] then mf:postResult( result ) return end

-- **********************************************************
--            SLASH COMMANDS
--***********************************************************
local function validateCmd( msg )
  local isValid = true
  
  if msg == nil then
      isValid = false
  end
  if msg == EMPTY_STR then
      isValid = false
  end
  return isValid
end
SLASH_CSIM_COMMANDS1 = "/run"
SLASH_CSIM_COMMANDS2 = "/do"

SlashCmdList["SLASH_CSIM_COMMANDS"] = function( msg )
  local isValid = validateCmd( msg )

  msg = string.lower( msg )

  ---------------------- TEST 1 -----------------------------
  if msg == "term" or msg == "terminate" or msg == "quit" or msg == "exit" then
    local result = {SUCCESS, EMPTY_STR, EMPTY_STR}

    result = thread:sendSignal( main_h, SIG_TERMINATE )
    if not result[1] then mf:postResult( result ) return end
  end
end

local fileName = "MainThread.lua"

if simcore:debuggingIsEnabled() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded.", fileName ), 0.0, 1.0, 0.0 )
end

