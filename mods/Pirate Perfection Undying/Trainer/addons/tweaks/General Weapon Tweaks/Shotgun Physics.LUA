-- SHOTGUN PHYSICS (Undying rewrite, round 9)
-- The old version replaced NewShotgunBase:_fire_raycast. That class is gone in the x64 game,
-- so it silently did nothing. It also multiplied shotgun damage by 5 (x100 for HE rounds) and
-- made the spread 5x wider, which is a damage cheat, not physics; that part is not kept.
-- The game itself now throws ragdolls on shotgun kills, but only within 5 m and gently.
-- This makes YOUR shotgun kills throw bodies from further away and harder.
-- Other players see the push too (the game syncs it; they see it a bit weaker at long range).

if not ( GamePlayCentralManager and GamePlayCentralManager._do_shotgun_push ) then
	return -- main menu: the class only exists in a heist
end

local PUSH_RANGE = 3000	-- cm (30 m). Game default: 500 (5 m)
local PUSH_FORCE = 2	-- x2 push strength

local function is_local_player( attacker )
	local player = managers.player and managers.player:player_unit()
	return attacker and alive( attacker ) and alive( player ) and attacker:key() == player:key()
end

backuper:hijack( 'GamePlayCentralManager.get_shotgun_push_range', function( o, self, attacker, ... )
	local range = o( self, attacker, ... )
	if is_local_player( attacker ) then
		return math.max( range, PUSH_RANGE )
	end
	return range
end )

backuper:hijack( 'GamePlayCentralManager._do_shotgun_push', function( o, self, unit, hit_pos, dir, distance, attacker, ... )
	if dir and is_local_player( attacker ) then
		dir = mvector3.copy( dir )
		mvector3.multiply( dir, PUSH_FORCE )
	end
	return o( self, unit, hit_pos, dir, distance, attacker, ... )
end )
