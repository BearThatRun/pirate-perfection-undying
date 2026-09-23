--Purpose: unlocks all blackmarket items.
--Author: Simplity

local pairs = pairs

local unlock_items_category, unlock_all_items, unlock_weapons, get_global_value

unlock_items = function( item_type )
	if item_type == "all" then
		unlock_all_items()
	elseif item_type == "weapons" then
		unlock_weapons()
	else
		unlock_items_category( item_type )
	end
end

unlock_all_items = function()
	local types = { "weapon_mods", "masks", "materials", "textures", "colors" }
	
	for _, item_type in pairs( types ) do
		unlock_items_category( item_type )
	end
	
	unlock_weapons()
end

unlock_weapons = function()
	local weapons = Global.blackmarket_manager.weapons
	for weapon_id in pairs( weapons ) do
		-- x64 port: leave weapons from unowned DLCs locked
		local def = tweak_data.upgrades.definitions[ weapon_id ]
		local dlc = def and def.dlc
		if not dlc or managers.dlc:is_dlc_unlocked( dlc ) then
			managers.upgrades:aquire( weapon_id )
			weapons[ weapon_id ].unlocked = true
		end
	end
end

unlock_items_category = function( item_type )
	for id, data in pairs( tweak_data.blackmarket[ item_type ] ) do
		if data.infamy_lock then
			data.infamy_lock = false
		end
		
		local global_value = get_global_value( data )
		-- x64 port: skip items that belong to a DLC the player does not own
		local gv_tweak = tweak_data.lootdrop.global_values[ global_value ]
		local dlc_locked = gv_tweak and gv_tweak.dlc and not managers.dlc:is_dlc_unlocked( global_value )
		if not dlc_locked then
			managers.blackmarket:add_to_inventory( global_value, item_type, id )
		end
	end
end

get_global_value = function( data )
	if data.global_value then
		return data.global_value
	elseif data.infamous then
		return "infamous"
	elseif data.dlcs or data.dlc then
		local dlcs = data.dlcs or {}
		
		if data.dlc then 
			table.insert( dlcs, data.dlc )
		end
		
		return dlcs[ math.random( #dlcs ) ]
	else
		return "normal"
	end
end