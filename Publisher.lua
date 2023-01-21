--------------------------------------------------------------------------------------
-- Publisher.lua 
-- AUTHOR: Michael Peterson 
-- ORIGINAL DATE: 5 October, 2022
--------------------------------------------------------------------------------------
local _, CombatSimulator = ...
CombatSimulator.publisher = {}
publish = CombatSimulator.publisher

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

local DAMAGE    = 1
local HEALING	= 2
local MISS		= 3

local framePool = {}

local function createNewFrame()
  local f = CreateFrame( "Frame" )
  f.Text = f:CreateFontString("Bazooka")
  f.Text:SetFont( "Interface\\Addons\\CombatSimulator\\Fonts\\Bazooka.ttf", 16 )

  f.Text:SetWidth( 600 )
  f.Text:SetJustifyH("LEFT")
  f.Text:SetJustifyV("TOP")
  f.Text:SetText("")

  f.Text:SetJustifyH("LEFT")
  f.Text:SetJustifyV("TOP")
  f.Done = false
  f.TotalTicks = 0
  f.UpdateTicks = 2 -- Move the frame once every 2 ticks
  f.UpdateTickCount = f.UpdateTicks
  return f
end
local function releaseFrame( f ) 
    f.Text:SetText("")
    table.insert( framePool, f )
end
local function initFramePool()
  local f = createNewFrame()
  table.insert( framePool, f )
end
local function acquireFrame()
  local f = table.remove( framePool )
  if f == nil then 
      f = createNewFrame() 
    end
	f.Text:SetFont( "Interface\\Addons\\CombatSimulator\\Fonts\\Bazooka.ttf", 16 )
    return f
end
local function getTextStartPosition( combatType )
	local xPos = 0
	local yPos = 0
	local anchor = nil
  
	-- NOTE: `increasing yPos negatively moves the starting position downward
	--        moving xPos negatively moves the starting position leftward.
  
	if combatType == DAMAGE then   -- Center, 200 up from the center
	  anchor = "CENTER"
	  xPos = 290
	  yPos = 100
	end
	if combatType == HEALING then  -- 400 pixels right of center, 200 pixels above center
		anchor = "CENTER"
		xPos = 390
		yPos = 200
	end 
	if combatType == MISS then    -- -400 pixels left of center, 200 pixels above center
		anchor = "CENTER"
		xPos = 200
	  yPos = 200
	end
	return anchor, xPos, yPos
end

-- entry = { combatType, isCrit, amount }
local function floatEntry( entry )
	local combatType 	= entry[1]
	local isCrit 		= entry[2]
	local amount		= entry[3]

	local f = acquireFrame()
	-- set the color
	-- f.Text:SetTextColor( 1.0, 1.0, 1.0 )  -- white
	-- f.Text:SetTextColor( 0.0, 1.0, 0.0 )  -- green
	-- f.Text:SetTextColor( 1.0, 1.0, 0.0 )  -- yellow
	-- f.Text:SetTextColor( 0.0, 1.0, 1.0 )  -- turquoise
	-- f.Text:SetTextColor( 0.0, 0.0, 1.0 )  -- blue
	-- f.Text:SetTextColor( 1.0, 0.0, 0.0 )  -- red
	if  entry[1] == "SPELL_DAMAGE" or
		entry[1] == "SPELL_PERIODIC_DAMAGE" or
		entry[1] == "SWING_DAMAGE" or
		entry[1] == "RANGE_DAMAGE" then
			combatType = DAMAGE
			f.Text:SetTextColor( 1.0, 0.0, 0.0 )	-- red
	end

	if entry[1] == "SPELL_HEAL" or entry[1] == "SPELL_PERIODIC_HEAL" then
		combatType = HEALING
		f.Text:SetTextColor( 0.0, 1.0, 0.0 ) -- green
	end
	if  entry[1] == "SPELL_MISSED" or
		entry[1] == "SPELL_PERIODIC_MISSED" or
		entry[1] == "RANGE_MISSED" or
		entry[1] == "SWING_MISSED" then
			combatType = MISS
			f.Text:SetTextColor( 0.0, 0.0, 1.0 )  -- blue
	end

	-- Sets the size depending on whether the accack hit critcally
	if isCrit then
			f.Text:SetFont( "Interface\\Addons\\CombatSimulator\\Fonts\\Bazooka.ttf", 32 )
	else
			f.Text:SetFont( "Interface\\Addons\\CombatSimulator\\Fonts\\Bazooka.ttf", 16 )
	end

	f.Text:SetText( amount )

	local anchor, xPos, yPos = getTextStartPosition( combatType )

	local yDelta = 2.0 -- move this much each update
	local xDelta = 0.0 -- this means the text will scroll vertically

	if combatType == DAMAGE then
		yDelta = 2.0
		if rightSide then
			xDelta = 2.0
		else
			xDelta = 0.0
		end	
	end
	if combatType == MISS then -- scroll the text faster at a 45 degree angle.
		if rightSide then
			xDelta = 2.0
		else
			xDelta = 0.0
		end	
	end

  	f:ClearAllPoints()
  	f.Text:SetPoint("CENTER", "UIParent", xPos, yPos )
  	f.Done = false

  	f.TotalTicks = 0
  	f.UpdateTicks = 4 -- Move the frame once every 4 ticks
  	f.UpdateTickCount = f.UpdateTicks
  	f:Show()
  	f:SetScript("OnUpdate", 
  
    	function(self, elapsed)
    		self.UpdateTickCount = self.UpdateTickCount - 1
      		if self.UpdateTickCount > 0 then
        		return
      		end

      		self.UpdateTickCount = self.UpdateTicks
      		self.TotalTicks = self.TotalTicks + 1
      		if self.TotalTicks == 40 then f:SetAlpha( 1.0 ) end
      		if self.TotalTicks == 45 then f:SetAlpha( 0.7 ) end
      		if self.TotalTicks == 50 then f:SetAlpha( 0.4 ) end
      		if self.TotalTicks == 55 then f:SetAlpha( 0.1 ) end
      		if self.TotalTicks >= 60 then 
      			f:Hide()
        		f.Done = true
    		else
        		yPos = yPos + yDelta
        		xPos = xPos + xDelta
        		f:ClearAllPoints()
        		f.Text:SetPoint("CENTER", "UIParent", xPos, yPos ) -- reposition the text to its new location
      		end
    	end
	)
    if f.Done == true then
      	releaseFrame(f)
    end
end

initFramePool()

------------------------------------------------------------------
-- thread function
------------------------------------------------------------------
function publish:celuEntry()
	local result = {SUCCESS, EMPTY_STR, EMPTY_STR}
	local done = false
	local signal = SIG_NONE_PENDING
	local done = false

	local self_h, selfId = thread:self()

	while not done do
		thread:yield()
		signal, sender_h = thread:getSignal()
		if signal == SIG_ALERT then
			local stats, dbCount = celu:getDbEntry()
			while dbCount > 0 do 
				local entry = fmt:formatEntry( stats)
				floatEntry(entry)
				stats, dbCount = celu:getDbEntry()
			end
		end
		if signal == SIG_TERMINATE then
			done = true
		end
	end
end

local fileName = "Publisher.lua"
if simcore:debuggingIsEnabled() then
	DEFAULT_CHAT_FRAME:AddMessage( sprintf("%s loaded.", fileName ), 0.0, 1.0, 0.0 )
end