-- Increase bag throw force
-- Author: Simplity

plugins:new_plugin('bag_throw_force')

local pairs = pairs
local game_config = game_config
local types = tweak_data.carry.types

VERSION = '1.0'

function MAIN()
	-- Undying: read the slider value when turned on, not once when the file loads
	local distance = togg_vars['bag_throw_power'] or game_config['bag_throw_power'] or 2
	for carry_type in pairs( types ) do
		carry_type = types[carry_type]
		if carry_type._throw_distance_multiplier == nil then
			carry_type._throw_distance_multiplier = carry_type.throw_distance_multiplier or 1 -- backup (only once)
		end
		carry_type.throw_distance_multiplier = distance
	end
end

function UNLOAD()
	for carry_type in pairs( types ) do
		local carry_type = types[carry_type]
		local backuped_throw_distance = carry_type._throw_distance_multiplier or 1
		carry_type.throw_distance_multiplier = backuped_throw_distance
	end
end

FINALIZE()