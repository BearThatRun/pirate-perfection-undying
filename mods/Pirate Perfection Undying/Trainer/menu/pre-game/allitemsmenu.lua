--All items menu by baldwin w/ Davy Jones weapon filter
--Purpose: Displays menu with all available items and allows you to add some into inventory.

ppr_require 'Trainer/tools/new_menu/menu'

local pairs = pairs
local tab_insert = table.insert
local managers = managers
local tweak_data = tweak_data
local T_L_global_values = tweak_data.lootdrop.global_values
local T_weapon = tweak_data.weapon
local T_W_Factory = T_weapon.factory
local T_W_F_parts = T_W_Factory.parts
local T_blackmarket = tweak_data.blackmarket
local T_B_weapon_mods = T_blackmarket.weapon_mods
local T_upgrades = tweak_data.upgrades
local M_localization = managers.localization
local M_blackmarket = managers.blackmarket

local locale_exists = M_localization.exists
local locale_text = M_localization.text

local specific_menu,main_menu,weapon_category_menu,weapon_mods_menu,weapon_platform_menu,weapon_platform_mods_menu

local tr = Localization.translate

local open_menu
do
	local Menu = Menu
	local open = Menu.open
	open_menu = function( ... )
		return open(Menu, ...)
	end
end

local __add_to_inventory = M_blackmarket.add_to_inventory
-- Round 3: show how many you now have (in the menu description and in the button label)
local function item_amount( special, category, name )
	local ok, n = pcall( M_blackmarket.get_item_amount, M_blackmarket, special or 'normal', category or 'masks', name, true )
	return ok and n or 0
end

local function label( text, special, category, name )
	return text .. "  [x" .. tostring( item_amount( special, category, name ) ) .. "]"
end

local function add_item( special, category, name, text )
	__add_to_inventory( M_blackmarket, special or 'normal', category or 'masks', name )
	local n = item_amount( special, category, name )
	local m = tweak_data.menu_active
	if m and text then
		for _, b in ipairs( m._data.button_list or {} ) do
			if b.data and b.data[3] == name and b.data[2] == category then
				m:set_button_text( b, text .. "  [x" .. tostring( n ) .. "]" )
				break
			end
		end
	end
	ppu_feedback( tostring( text or name ) .. ": you now have " .. tostring( n ) )
end

local function is_special(e)
	local dlcs = e.dlcs
	return e.infamous and 'infamous' or e.global_value or e.dlc or dlcs and dlcs[1]
end

-- Menu
weapon_platform_mods_menu = function(weapon_id, name)
	local data = {}
	for _, part_id in pairs(T_W_Factory[T_upgrades.definitions[weapon_id].factory_id].uses_parts) do
		local part_data = T_B_weapon_mods[part_id]
		if not part_data.unatainable and part_data.pcs then
			local txt = locale_text(M_localization, part_data.name_id)..(part_data.dlc and T_L_global_values[part_data.dlc] and "    -    "..locale_text(M_localization, T_L_global_values[part_data.dlc].name_id) or "")
			local gv = is_special(part_data)
			tab_insert(data, {text = label(txt, gv, 'weapon_mods', part_id), callback = add_item, data = {gv, 'weapon_mods', part_id, txt}, switch_back = true})
		end
	end

	open_menu({title = name, description = tr.inv_spec_weapon_mods_title, button_list = data, back = weapon_platform_menu})
end

weapon_platform_menu = function()
	local data = {}
	for weapon_id, weapon in pairs(T_weapon) do
		if weapon.name_id then
			local name = locale_text(M_localization, weapon.name_id)
			tab_insert(data, {text = name, callback = weapon_platform_mods_menu, data = {weapon_id, name}, menu = true})
		end
	end

	open_menu({title = tr.inv_spec_weapon_search, button_list = data, back = weapon_category_menu})
end

weapon_mods_menu = function( part_type )
	local data = {}
	
	for part_id, part_data in pairs( T_B_weapon_mods ) do
		local name_id = part_data.name_id
		
		if name_id and T_W_F_parts[ part_id ].type == part_type and locale_exists( M_localization, name_id ) then
			local txt = locale_text( M_localization, name_id )
				local gv = is_special( part_data )
				tab_insert( data, { text = label( txt, gv, 'weapon_mods', part_id ), callback = add_item, data = { gv, 'weapon_mods', part_id, txt }, switch_back = true} )
		end
	end
	
	open_menu( { title = locale_text( M_localization, "bm_menu_" .. part_type), button_list = data, back = weapon_category_menu } )
end

weapon_category_menu = function()
	local data = {
		{text = tr.inv_spec_weapon_search, callback = weapon_platform_menu, menu = true},
		{},
	}
	local part_category = {}
	
	for part_id, part_data in pairs( T_B_weapon_mods ) do
		local type = T_W_F_parts[ part_id ].type
		local cat_type = "bm_menu_" .. type
		
		if not part_category[ type ] and locale_exists(M_localization, cat_type) then
			part_category[ type ] = true
			tab_insert( data, { text = locale_text(M_localization, cat_type), callback = weapon_mods_menu, data = type, menu = true } )
		end		
	end
	
	open_menu( { title = tr.inv_spec_weapon_mods_title, button_list = data, back = main_menu } )
end

specific_menu = function( name, disp_name )
	local data = {}
	
	for v_name, v_data in pairs( T_blackmarket[ name ] ) do
		local name_id = v_data.name_id
		if name_id and locale_exists( M_localization, name_id ) then
			local txt = locale_text( M_localization, name_id )
			local gv = is_special( v_data )
			tab_insert( data, { text = label( txt, gv, name, v_name ), callback = add_item, data = { gv, name, v_name, txt }, switch_back = true} )
		end
	end
	
	open_menu( { title = disp_name, button_list = data, back = main_menu } )
end

main_menu = function()
	local data = {
		{ text = tr.inv_spec_masks, callback = specific_menu, data = { 'masks', tr.inv_spec_masks_title }, menu = true },
		{ text = tr.inv_spec_colors, callback = specific_menu, data = { 'colors', tr.inv_spec_colors_title }, menu = true },
		{ text = tr.inv_spec_materials, callback = specific_menu, data = { 'materials', tr.inv_spec_materials_title }, menu = true },
		{ text = tr.inv_spec_textures, callback = specific_menu, data = { 'textures', tr.inv_spec_textures_title }, menu = true },
		{ text = tr.inv_spec_weapon_mods, callback = weapon_category_menu, menu = true },
	}
	
	open_menu( { title = tr.inv_spec_menu, description = tr.inv_spec_menu_desc, button_list = data } )
end

main_menu()