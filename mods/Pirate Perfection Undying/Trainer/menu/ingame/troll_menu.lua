if ( not GameSetup ) then
	return
end

local ppr_require = ppr_require
ppr_require 'Trainer/tools/new_menu/menu'

local main_menu, interaction_with_other, interaction_with_id_menu, release_player, interaction_with_self, activate_elements, interaction_with_team, give_equipments, give_bags, give_items

local path = "Trainer/addons/troll_menu/"

local managers = managers
local M_navigation = managers.navigation
local M_network = managers.network
local M_net_session = M_network:session()
local M_localization = managers.localization
local M_Mission = managers.mission
local locale_text = M_localization.text
local locale_exists = M_localization.exists

local tweak_data = tweak_data
local T_equipments = tweak_data.equipments
local T_E_specials = T_equipments.specials

local M_enemy = managers.enemy
local M_fire = managers.fire
local G_timer = TimerManager:game()
local togg_vars = togg_vars
local scripts = M_Mission._scripts

local World = World
local W_spawn_unit = World.spawn_unit
local M_groupAI = managers.groupai
local T_levels = tweak_data.levels
local team_id = T_levels:get_default_team_ID("combatant")
local team_data = M_groupAI:state():team_data( team_id )
local spook_id = Idstring( "units/payday2/characters/ene_spook_1/ene_spook_1" )

togg_vars.reduce_damage = {}

-- Functions

local alive = alive
local m_log_error = m_log_error

function unit_from_id( id )
	local unit = M_net_session:peer( id ):unit()
	if alive(unit) then
		return unit
	else
		m_log_error('unit_from_id()','Peer',id,'is dead')
	end
end
local unit_from_id = unit_from_id

local pairs = pairs
local all_ladders = Ladder.ladders

local increase_ladder = function()
	for _,unit in pairs( all_ladders )  do
		local ladder = unit:ladder()
		if ladder then
			ladder:set_height( 10000 )
			ladder:set_width( 10000 )
		end
	end
end

local GetPlayerUnit = GetPlayerUnit
local M_player = managers.player

local function verify_player_id(id) --Verify, that player in-game and entered it
	if not managers.network:session() then 
		return false 
	end  
	return managers.network:session():peer(id) and managers.criminals:character_name_by_peer_id(id)
end

local trigger_client = function(id)
	M_net_session:send_to_host("to_server_mission_element_trigger", id, M_player:player_unit())
end

local PackageManager = PackageManager
local package_udata = PackageManager.unit_data

local World = World
local find_units_quick = World.find_units_quick
local delete_unit = World.delete_unit

local delete_units = function()
	for _,unit_data in pairs(find_units_quick(World, "all"))  do
		if package_udata( PackageManager, unit_data:name() ):network_sync() == "spawn" then
			delete_unit(World, unit_data)
		end
	end
end

-- Undying: only states that can be entered from anywhere. jerry1/jerry2 (skydive, parachute)
-- crash when you leave them on a map without the parachute unit; carry, bipod, turret,
-- driving and custody need something the menu can't give them.
local self_states = { "standard", "mask_off", "clean", "civilian", "tased", "incapacitated", "arrested" }

local change_own_state = function(state)
	local player = GetPlayerUnit()
	if not alive( player ) then
		m_log_error('change_own_state()','You are dead.')
		return
	end
	if state == "tased" then
		-- Round 4: use the game's own self-tase (non-lethal, you recover after a few seconds).
		-- The game only lets you be tased with the mask on, and not with god mode / while downed.
		local cur = M_player:current_state()
		if cur == "mask_off" or cur == "clean" or cur == "civilian" then
			show_hint("Tase only works with your mask on")
			return
		end
		local dmg = player:character_damage()
		if dmg.can_be_tased and not dmg:can_be_tased() then
			show_hint("Can't be tased right now (god mode on, downed, or already tased)")
			return
		end
		if dmg.on_self_tased then
			dmg:on_self_tased(1)
		else
			player:movement():on_non_lethal_electrocution(1)
			M_player:set_player_state("tased")
		end
		return
	end
	M_player:set_player_state(state)
end

-- Undying: FireManager:add_doted_enemy now takes one data table (U248).
local set_cops_on_fire = function()
	local player = GetPlayerUnit()
	if not alive(player) then
		return
	end
	local dot_tweak = tweak_data.dot and tweak_data.dot:get_dot_data("default_fire")
	if not dot_tweak then
		m_log_error('set_cops_on_fire()','no default_fire dot data')
		return
	end
	local dot_data = deep_clone(dot_tweak)
	dot_data.dot_length = 10
	dot_data.dot_trigger_chance = nil
	dot_data.dot_trigger_max_distance = nil
	local weapon_unit = player:inventory():equipped_unit()
	for _, u_data in pairs( M_enemy:all_enemies() ) do
		local unit = u_data.unit
		if alive(unit) and unit:character_damage() and not unit:character_damage():dead() then
			pcall( M_fire.add_doted_enemy, M_fire, {
				unit = unit,
				dot_data = dot_data,
				weapon_unit = weapon_unit,
				attacker_unit = player,
				hurt_animation = true,
			} )
		end
	end
end

-- Interact with other players


local teleport_to_player = function(id)
	local unit = unit_from_id(id)
	if unit then
		M_player:warp_to( unit:position(), rot0 )
	end
end

-- Give equipments
local give_equipment = ppr_require( path .. 'spawn_equipments' )

-- Spawn bag
local give_bag = ppr_require( path .. 'spawn_bags' )

-- Interact with players
local sync_movement = ppr_require( path .. 'sync_movement' )

-- Release Player
release_player = function(id)
	if id == "all" then
		local s = managers.network:session()
		if not s then
			return
		end
		for _, peer in pairs(s._peers) do
			if peer:id() ~= s:local_peer():id() and verify_player_id(peer:id()) then 
				release_player(peer:id())
			end
		end
		return
	end
	IngameWaitingForRespawnState.request_player_spawn(id)
end

-- Activate element
local run_element = ppr_require( path .. 'activate_element' )

-- Add item
local add_item = ppr_require( path .. 'add_items' )

-- Run Trigger
local run_trigger = function(id)
	for _, a in pairs( scripts ) do
		for b, c in pairs( a:element_groups() ) do
			if b == id then
				for _, d in ipairs( c ) do
					if is_server() then
						d:on_executed( )
					else
						trigger_client(d:id())
					end
				end
				
				break
			end
		end
	end
end






local reduce_damage_all = function()
	togg_vars.reduce_damage.all = not togg_vars.reduce_damage.all
	
	local dmg = togg_vars.reduce_damage.all and 100 or -1
	for _, peer in pairs(M_net_session._peers) do
		peer:send_queued_sync("sync_damage_reduction_buff", dmg)
	end
end

local reduce_damage = function( id )
	if id == "all" then
		reduce_damage_all()
		return
	end
	
	togg_vars.reduce_damage[id] = not togg_vars.reduce_damage[id]
	
	local dmg = togg_vars.reduce_damage[id] and 100 or -1
	for i, peer in pairs(M_net_session._peers) do
		if i == id then
			peer:send_queued_sync("sync_damage_reduction_buff", dmg)
			
			break
		end
	end
end

local sub = string.sub

local RunNewLoopIdent = RunNewLoopIdent
local StopLoopIdent = StopLoopIdent
local AllRunningLoops = AllRunningLoops

local Localization = Localization
local tr = Localization.translate

local backuper = backuper
local restore = backuper.restore
local hijack = backuper.hijack

local function dmg_melee(unit)
	if unit then
		local action_data = {
			damage = math.huge,
			damage_effect = unit:character_damage()._HEALTH_INIT * 2,
			attacker_unit = M_player:player_unit(),
			attack_dir = Vector3(0,0,0),
			name_id = 'rambo',
			col_ray = {
				position = unit:position(),
				body = unit:body( "body" ),
			}
		}
		unit:character_damage():damage_melee(action_data)
	end
end

-- Undying: kill every enemy, then push the ragdolls up (same physics effect explosions use).
-- Ragdolls are not synced, so other players see the bodies drop normally.
local body_explosion = Idstring("physic_effects/body_explosion")
local push_up = function(unit)
	if not alive(unit) then
		return
	end
	local mov = unit:movement()
	local action = mov and mov._active_actions and mov._active_actions[1]
	if action and action.type and action:type() == "hurt" and action.force_ragdoll then
		action:force_ragdoll(true)
	end
	local rot_acc = Vector3(1 - math.rand(2), 1 - math.rand(2), 1 - math.rand(2)) * 10
	for i = 0, unit:num_bodies() - 1 do
		local body = unit:body(i)
		if body and body:enabled() and body:dynamic() then
			local vel = Vector3(math.rand(-150, 150), math.rand(-150, 150), 1400)
			World:play_physic_effect(body_explosion, body, vel, body:mass(), body:position(), rot_acc, 1)
		end
	end
end

local launch_cops = function()
	local launched = {}
	for _,ud in pairs(M_enemy:all_enemies()) do
		if alive(ud.unit) then
			table.insert(launched, ud.unit)
			pcall(dmg_melee,ud.unit)
		end
	end
	-- The ragdoll only exists a moment after death.
	DelayedCalls:Add("ppu_launch_cops", 0.15, function()
		for _, unit in ipairs(launched) do
			pcall(push_up, unit)
		end
	end)
end

local open_menu
do
	local Menu = Menu
	local open = Menu.open
	open_menu = function( ... )
		return open(Menu, ...)
	end
end

local spawn_deposit_money_box = function()
	local chance_text = tr['chance']
	local data = {
		{ text = chance_text .. " 25%", callback = run_element, data = { "spawn_special_money", 4 } },
		{ text = chance_text .. " 50%", callback = run_element, data = { "spawn_special_money", 2 } },
		{ text = chance_text .. " 100%", callback = run_element, data = { "spawn_special_money", 1 } },
	}

	open_menu( { title = tr['troll_fill_deposits_money'], button_list = data, back = activate_elements } )
end

local tab_insert = table.insert

-- Menu

local text_x = "x"

--TO DO: Catch these details from tweak_data ?
give_equipments = function( id, back_f )
	local data = {
		{ text = tr['troll_give'] .. " " .. locale_text(M_localization, "debug_ammo_bag"), callback = give_equipment, data = { id, "ammo" } },
		{ text = tr['troll_give'] .. " " .. locale_text(M_localization, "debug_doctor_bag"), callback = give_equipment, data = { id, "medic" } },
		{ text = tr['troll_give'] .. " " .. locale_text(M_localization, "debug_equipment_ecm_jammer"), callback = give_equipment, data = { id, "ecm" } },
		{ text = tr['troll_give'] .. " " .. locale_text(M_localization, "debug_trip_mine"), callback = give_equipment, data = { id, "trip_mine" } },
		{ text = tr['troll_give'] .. " " .. locale_text(M_localization, "debug_sentry_gun"), callback = give_equipment, data = { id, "sentry" } },
		{ text = tr['troll_give'] .. " " .. locale_text(M_localization, "debug_equipment_bodybags_bag"), callback = give_equipment, data = { id, "bodybag" } },
	}
	
	open_menu( { title = tr['troll_give_equipments'], button_list = data, back = back_f } )
end

give_bags = function( id, back_f )
	local data = {}
	local data_carry = tweak_data.carry
	local locale_text = M_localization.text
	local locale_exists = M_localization.exists
	
	for bag_id, bag_data in pairs( data_carry ) do
		local name_id = bag_data.name_id
		if name_id and locale_exists( M_localization, name_id ) then
			tab_insert( data, { text = tr['troll_give'] .. " " .. locale_text( M_localization, name_id ), callback = give_bag, data = { id, bag_id }, switch_back = true } )
		end
	end
	
	open_menu( { title = tr['troll_give_bags'], button_list = data, back = back_f } )
end

give_items = function( id, back_f )
	local data = {}
	
	local locale_text = locale_text
	local locale_exists = locale_exists
	
	for item_id, item_data in pairs( T_E_specials ) do
		local text_id = item_data.text_id
		if text_id and locale_exists( M_localization, text_id ) then
			tab_insert( data, { text = tr['troll_give'] .. " " .. locale_text( M_localization, text_id ), callback = add_item, data = { id, item_id }, switch_back = true } )
		end
	end
	
	open_menu( { title = tr['troll_give_bags'], button_list = data, back = back_f } )
end


-- Round 3: one button that raises the alarm directly (host only). The 4 'report' alerts
-- only made guards/civilians react and did nothing once everyone was tied up.
local raise_alarm = function()
	local state = M_groupAI:state()
	if not state:enemy_weapons_hot() then
		state:on_police_called("alarm_pager_not_answered")
		show_hint("Alarm raised")
	else
		show_hint("The alarm is already going")
	end
end

interaction_with_self = function()
	local data = {}
	for _,state in ipairs( self_states ) do
		local label = tr['troll_state_' .. state]
		tab_insert(data, { text = (label and label ~= "" and label ~= ('troll_state_' .. state)) and label or state, callback = change_own_state, data = state })
	end
	
	open_menu( { title = tr['troll_change_own_state'], button_list = data, back = main_menu } )
end

local format_loc = Localization.text

interaction_with_id_menu = function( id, name )
	local back_f = function() interaction_with_id_menu( id, name ) end
	
	-- Undying: only actions that help or don't affect the other player.
	-- Custody/tase/arrest/down/kick/slap/spook/time control/ride were removed.
	local data = { 
		{ text = tr['troll_release_player'], callback = sync_movement, data = { id, "release" } },
		{ text = tr['troll_standart_player'], callback = sync_movement, data = { id, "standard" } },
		{ text = tr['troll_teleport_to'], callback = teleport_to_player, data = id },
		{ text = tr['troll_reduce_damage'], type = "toggle", toggle = function() return togg_vars.reduce_damage[id] end, callback = reduce_damage, data = id, host_only = true },
		{},
		{ text = tr['troll_give_equipments'], callback = give_equipments, data = { id, back_f }, menu = true },
		{ text = tr['troll_give_bags'], callback = give_bags, data = { id, back_f }, menu = true },
		{ text = tr['troll_give_items'], callback = give_items, data = { id, back_f }, host_only = true, menu = true },
	}
	
	open_menu( { title = format_loc(Localization, 'troll_interact_with', name, id), button_list = data, back = interaction_with_other } )
end

interaction_with_team = function()
	local data = { 
		{ text = tr['troll_team_god_mode'], host_only = true, plugin = "team_god_mode", switch_back = true },
		{ text = tr['troll_reduce_damage'], type = "toggle", toggle = function() return togg_vars.reduce_damage.all end, callback = reduce_damage, data = "all", host_only = true, switch_back = true },
		{},
		{ text = tr['troll_give_equipments'], callback = give_equipments, data = { "all", interaction_with_team }, menu = true },
		{ text = tr['troll_give_bags'], callback = give_bags, data = { "all", interaction_with_team }, menu = true },
		{ text = tr['troll_give_items'], callback = give_items, data = { "all", interaction_with_team }, host_only = true, menu = true },
		{},
		{ text = tr['troll_release_tm_from_jail'], callback = sync_movement, data = { "all", "release" } },
		{ text = tr['troll_standard_tm'], callback = sync_movement, data = { "all", "standard" } },
	}
	
	open_menu( { title = tr['troll_interact_team'], button_list = data, plugin_path = path, back = interaction_with_other } )
end

interaction_with_other = function()
	local data = { 
		{ text = tr['troll_interact_team'], callback = interaction_with_team, menu = true },
		{},
	}
	
	local count_data = #data
	
	local session = M_network._session
	local lpeer_id = session._local_peer._id
	for _, peer in pairs( session._peers ) do
		local peer_id = peer._id
		if peer_id ~= lpeer_id then
			local peer_name = peer._name
			tab_insert( data, { text = format_loc(Localization, 'troll_interact_with', peer_name, peer_id ), callback = interaction_with_id_menu, data = { peer_id, peer_name }, menu = true } )
		end
	end
	
	if #data == count_data then
		tab_insert(data, { text = tr['troll_no_players'], callback = void })
	end
	
	open_menu( { title = tr['troll_interaction_with_other'], button_list = data, plugin_path = path, back = main_menu } )
end

activate_elements = function()
	local data = {
		{ text = tr['troll_open_doors'], callback = run_element, data = "anim_open_door" },
		{ text = tr['troll_close_doors'], callback = run_element, data = "anim_close_door" },
		{},
		{ text = tr['troll_Hide_doors'], callback = run_element, data = "state_door_hide" },
		{ text = tr['troll_Show_doors'], callback = run_element, data = "state_door_show" },
		{},
		{ text = tr['troll_open_vault'], callback = run_element, data = "anim_open" },
		{ text = tr['troll_close_vault'], callback = run_element, data = "state_closed" },
		{},
		{ text = tr['troll_open_van_doors'], callback = run_element, data = "anim_door_rear_both_open" },
		{ text = tr['troll_close_van_doors'], callback = run_element, data = "state_door_rear_both_close" },
		{},
		{ text = tr['troll_Upgrade_cameras'], callback = run_element, data = "deathwish" },
		{ text = tr['troll_fill_deposits_money'], callback = spawn_deposit_money_box, box = true },
	}
	
	open_menu( { title = tr['troll_activate_elements'], button_list = data, back = main_menu } )
end


local ppr_dofile = ppr_dofile

main_menu = function()
	local data = { 
		{ text = tr['troll_interaction_with_other'], callback = interaction_with_other, menu = true },
		{ text = tr['troll_change_own_state'], callback = interaction_with_self, menu = true },
		{ text = tr['troll_activate_elements'], callback = activate_elements, host_only = true, menu = true},
		{ text = tr['troll_End_mission'], callback = run_trigger, data = "ElementMissionEnd" }, -- Round 4: straight here, no Triggers submenu
		{ text = tr['troll_raise_alarm'], callback = raise_alarm, host_only = true },
		{},
		{ text = tr['troll_cops_to_bulld'], host_only = true, plugin = "cops_to_bulld", switch_back = true },
		{ text = tr['troll_replace_cops'], host_only = true, plugin = "replace_cops", switch_back = true },
		{ text = tr['troll_exploding_enemies'], host_only = true, plugin = "exploding_enemies", switch_back = true },
		{ text = tr['troll_change_spawn_pos'], host_only = true, callback = ppr_dofile, data = path .. "change_spawn_pos" },
		{ text = tr['troll_increase_ladder'], callback = increase_ladder },
		{ text = tr['troll_del_units'], host_only = true, callback = delete_units },
		{ text = tr['troll_take_mask'], callback = change_own_state, data = "mask_off" },
		{ text = tr['troll_set_cops_on_fire'], callback = set_cops_on_fire },
		{ text = tr['Launch_cops_to_air'], callback = launch_cops },
	}
	
	open_menu( { title = tr['troll_menu'], plugin_path = path, button_list = data } )
end

return main_menu