-- Change spawn position for new players
-- Author: Simplity
-- x64 rewrite (Pirate Perfection Undying): NetworkMember no longer exists, so instead of replacing
-- the whole spawn function this wraps NetworkPeer.spawn_unit and only swaps the spawn position.

local player = managers.player:player_unit()
if not alive( player ) then
	return
end

local pos_s = player:position()
local rot_s = player:rotation()
local rawget = rawget
local pcall = pcall
local error = error

backuper:hijack( 'NetworkPeer.spawn_unit', function( o, self, ... )
	local M_net = managers.network
	local M_crim = managers.criminals
	local had_spawn_point = rawget( M_net, 'spawn_point' )
	local had_valid_pos = rawget( M_crim, 'get_valid_player_spawn_pos_rot' )
	local fixed = { pos_rot = { pos_s, rot_s } }

	M_net.spawn_point = function() return fixed end
	M_crim.get_valid_player_spawn_pos_rot = function() return { pos_s, rot_s } end

	local ok, res = pcall( o, self, ... )

	M_net.spawn_point = had_spawn_point
	M_crim.get_valid_player_spawn_pos_rot = had_valid_pos

	if not ok then
		error( res )
	end
	return res
end )
