--Evil sentry guns

plugins:new_plugin('evil_sentries')

local backuper = backuper
local M_state = managers.groupai:state()
local levels = tweak_data.levels

VERSION = '1.0'

function MAIN()
	local combatant_team = M_state:team_data(levels:get_default_team_ID("combatant"))
	
	local update = backuper:backup('SentryGunMovement.update')
	function SentryGunMovement:update(unit, t, dt)
		if not (other_players_present and other_players_present()) then -- Undying: solo games only
			unit:movement():set_team(combatant_team)
		end
		
		return update(self, unit, t, dt)
	end
end

function UNLOAD()
	backuper:restore('SentryGunMovement.update')
end

FINALIZE()