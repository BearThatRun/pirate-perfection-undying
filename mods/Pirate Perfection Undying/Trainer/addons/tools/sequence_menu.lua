-- Sequencer Menu

local M_network = managers.network
local find_units_quick = World.find_units_quick
local insert = table.insert
local Menu_open = Menu.open

local tr = Localization.translate

local togg_vars = togg_vars

local _activate_element = function( unit, name )
	local damage = unit:damage()
	
	if damage and damage:has_sequence( name ) then
		local session = M_network:session()
		damage:run_sequence_simple( name ) 
		session:send_to_peers_synched( "run_mission_door_device_sequence", unit, name )
	end
end

local activate_element = function( unit, name )
	if togg_vars.seq_single then
		_activate_element(unit, name)
	else
		for _, unit in pairs( find_units_quick(World, "all") ) do
			_activate_element(unit, name)
		end
	end
end

-- Undying: say why nothing opens instead of failing silently.
local no_sequences = function()
	show_hint("Sequencer: aim at an object (door, window, vault, car...) and press 9")
end

local open_menu = function()
	local ray = get_ray()
	if not ray or not alive(ray.unit) then
		return no_sequences()
	end

	local unit = ray.unit
	local elem = unit.damage and unit:damage() and unit:damage()._unit_element
	local elements = elem and elem._sequence_elements
	if not elements or not next(elements) then
		return no_sequences()
	end
	
	local data = {{ text = "Only this object (off = every object with the same sequence)", type = "toggle", toggle = "seq_single", callback = function() togg_vars.seq_single = not togg_vars.seq_single end, switch_back = true}, {}}

	local ids = {}
	for id in pairs( elements ) do
		insert(ids, id)
	end
	table.sort(ids)
	for _, id in ipairs( ids ) do
		insert(data, { text = id, callback = activate_element, data = {unit, id}, switch_back = true })
	end

	Menu_open(Menu, { title = tr.sequencer_menu, button_list = data } )
end

do
	local edit_key = KeyInput.edit_key
	edit_key(KeyInput, "9", { callback = open_menu })
end

open_menu()