--Evil Criminals

plugins:new_plugin('evil_criminals')

local backuper = backuper
local M_state = managers.groupai:state()
local levels = tweak_data.levels

VERSION = '1.0'

function MAIN()
	if (other_players_present and other_players_present()) then return end -- Undying: solo games only
	local combatant_team = M_state:team_data(levels:get_default_team_ID("combatant"))
	
	local criminals = M_state:all_criminals()
	for _, data in pairs(criminals) do
		if data.unit:base()._tweak_table then
			data.unit:movement():set_team(combatant_team)
		end
	end
end

function UNLOAD()
	local combatant_team = M_state:team_data(levels:get_default_team_ID("player"))
	
	local criminals = M_state:all_criminals()
	for _, data in pairs(criminals) do
		if data.unit:base()._tweak_table then
			data.unit:movement():set_team(combatant_team)
		end
	end
end

FINALIZE()