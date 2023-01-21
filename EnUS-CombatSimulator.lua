----------------------------------------------------------------------------------------
-- enUS.lua
-- AUTHOR: mtpeterson1948 at gmail dot com
-- ORIGINAL DATE: 28 December, 2018
----------------------------------------------------------------------------------------

local _, CombatSimulator = ...
CombatSimulator.enUS = {}

local L = setmetatable({}, { __index = function(t, k)
	local v = tostring(k)
	rawset(t, k, v)
	return v
end })

CombatSimulator.L = L
local sprintf = _G.string.format

-- English translations
local LOCALE = GetLocale()      -- BLIZZ
if LOCALE == "enUS" then

	L["ADDON_NAME"]				= simcore.ADDON_NAME
	L["VERSION"] 				= simcore.ADDON_VERSION
	L["EXPANSION_NAME"]			= simcore.EXPANSION_NAME
	L["ADDON_NAME_AND_VERSION"] = sprintf("%s, V%s %s", L["ADDON_NAME"], L["VERSION"], L["EXPANSION_NAME"] )
	L["ADDON_LOADED_MESSAGE"] 	= sprintf("%s loaded", L["ADDON_NAME_AND_VERSION"] )
	
	L["PARAM_NIL"]				= "Invalid Parameter - Was nil."
	L["PARAM_OUTOFRANGE"]		= "Invalid Parameter - Out-of-range."
	L["PARAM_WRONGTYPE"]		= "Invalid Parameter - Wrong type."
end

print( L["ADDON_LOADED_MESSAGE"])
