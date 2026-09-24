-- Pirate Perfection Undying: small always-on fixes for the x64 game.

-- Picking up a sentry gun you no longer have in your equipment slot (for example after
-- F7 "Change equipment" or a spawned sentry) crashed in PlayerManager:add_sentry_gun.
if PlayerManager and PlayerManager.add_sentry_gun and not PlayerManager._undying_sentry_fix then
	PlayerManager._undying_sentry_fix = true
	local add_sentry_gun = PlayerManager.add_sentry_gun
	function PlayerManager:add_sentry_gun( num, sentry_type, ... )
		if not self:equipment_data_by_name( sentry_type ) then
			return
		end
		return add_sentry_gun( self, num, sentry_type, ... )
	end
end
