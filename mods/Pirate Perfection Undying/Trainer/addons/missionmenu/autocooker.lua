--  Authors:  Originally by baldwin, re-write by Davy Jones
--  Purpose:  Cooks meth on Rats, Cook-Off and (Undying, round 10) Lab Rats for you... infinitely.

local plugins = plugins
plugins:new_plugin('autocooker')

local alive = alive
local pairs = pairs
local random = math.random
local type = type
local Vector3 = Vector3

local Global = Global
local G_game_settings = Global.game_settings

local managers = managers
local M_interaction = managers.interaction
local M_player = managers.player

local backuper = backuper
local add_clbk = backuper.add_clbk
local remove_clbk = backuper.remove_clbk

local executewithdelay = executewithdelay

local GetNetSession = GetNetSession
local is_client = is_client

FULL_NAME = "Meth Auto-Cooker"

VERSION = "2.1"

DESCRIPTION = "Cooks and bags up meth for you.  Originally by baldwin, re-written by Davy Jones."

local _interactive_units = M_interaction._interactive_units
local _players = M_player._players
local clear_carry = M_player.clear_carry
local level_id = G_game_settings.level_id
local server_drop_carry = M_player.server_drop_carry

local UP = Vector3(0, 0, 1)

local needed_chem = {'methlab_bubbling', 'methlab_caustic_cooler', 'methlab_gas_to_salt'}

local spawn_meth_pos


local function true_func()
	return true
end

local function cook_meth(chemical)
	local player = _players[1]
	if alive(player) then
		local interaction
		if type(chemical) == 'string' then
			for _, unit in pairs(_interactive_units) do
				interaction = unit:interaction()
				if interaction.tweak_data == chemical then
					break
				end
			end
		end
		interaction.can_interact = true_func
		interaction:interact(player)
	end
end

-- Lab Rats (map id nail), Undying round 10. Host only.
-- From a recorded Lab Rats run (Trigger List - nail.txt, 2026-09-26):
--   the mission picks one chemical (elements set_add_mu / set_add_cs / set_add_hcl), Bain asks
--   for it (pln_rt1_20/22/24, repeated every 20 s), a correct bag thrown into the lab fires
--   money_correct_trigger / coke_correct_trigger / HCL_correct_trigger, and after 3 correct bags
--   ingredients_added runs. A wrong bag runs fail_start (boom).
-- This watches those mission elements (matched by id AND name, so a changed map fails safely),
-- and moves ONE bag of the right chemical at a time into the centre of that chemical's
-- "correct" trigger zone, using the game's own synced bag move (CarryData:set_position_and_throw).
-- It never moves a bag while no chemical is requested, and never a bag of another chemical.
-- Round 10b: the request is ALSO taken from Bain's repeated lines (every 20 s), so turning it on
-- after the heist picked the chemical works (round 10 waited for the next pick = forever).
-- The last steps are kept in memory and written to Logfiles/Autocooker.log only when something
-- goes wrong (v1.0: errors only, so the file doesn't grow on every run).
local NAIL = {
	set_add_mu  = { id = 101819, carry = 'nail_muriatic_acid',     trigger = 101726, trigger_name = 'money_correct_trigger', label = 'Muriatic Acid',     dialogs = { 'pln_rt1_20', 'pln_rat_stage1_20' } },
	set_add_cs  = { id = 101827, carry = 'nail_caustic_soda',      trigger = 101729, trigger_name = 'coke_correct_trigger',  label = 'Caustic Soda',      dialogs = { 'pln_rt1_22', 'pln_rat_stage1_22' } },
	set_add_hcl = { id = 101834, carry = 'nail_hydrogen_chloride', trigger = 101732, trigger_name = 'HCL_correct_trigger',   label = 'Hydrogen Chloride', dialogs = { 'pln_rt1_24', 'pln_rat_stage1_24' } },
}
local NAIL_STOP = { ingredients_added = 101812, fail_start = 100577 }
local NAIL_WRONG = { id = 101739, name = 'money_wrong_trigger' }
local FEED_DELAY = 1.5		-- seconds between two bags
local MAX_TRIES_PER_BAG = 3	-- same bag moved this often without counting -> give up on it

local nail_need			-- entry of NAIL while a chemical is requested
local nail_next_t = 0
local nail_tries = {}		-- unit key -> times moved
local nail_wrapped = {}		-- elements whose on_executed we wrapped
local nail_hinted
local nail_active = false

local log_fh
local log_buf = {}		-- recent steps, written out together with an error
local LOG_KEEP = 40
local function nlog( msg, is_error )
	local ok, t = pcall( function() return managers.game_play_central:get_heist_timer() end )
	t = ok and math.floor( tonumber( t ) or 0 ) or 0
	log_buf[ #log_buf + 1 ] = string.format( '%02d:%02d  ', math.floor( t / 60 ), t % 60 ) .. tostring( msg )
	if #log_buf > LOG_KEEP then
		table.remove( log_buf, 1 )
	end
	if not is_error then
		return
	end
	if not log_fh then
		log_fh = ppr_io.open( 'Logfiles/Autocooker.log', 'a' )
		if not log_fh then
			return
		end
	end
	log_fh:write( '--- error (level ' .. tostring( level_id ) .. '), last steps:\n' .. table.concat( log_buf, '\n' ) .. '\n' )
	log_fh:flush()
	log_buf = {}
end

local function hint( msg )
	nlog( 'HINT ' .. msg )
	if show_hint then
		show_hint( 'Auto-cook: ' .. msg )
	end
end

local function set_need( e, source )
	if nail_need ~= e then
		nlog( 'request: ' .. ( e and e.label or 'none' ) .. ' (from ' .. source .. ')' )
		nail_tries = {}
		nail_hinted = nil
		nail_next_t = TimerManager:game():time() + FEED_DELAY
	end
	nail_need = e
end

local function find_element( id, name )
	for _, script in pairs( managers.mission:scripts() ) do
		local el = script:elements()[id]
		if el then
			if el._editor_name == name then
				return el
			end
			return nil, 'element #' .. id .. ' is "' .. tostring( el._editor_name ) .. '", expected "' .. name .. '"'
		end
	end
	return nil, 'element #' .. id .. ' (' .. name .. ') not found'
end

-- A point inside the trigger zone, taken from the zone's own shape and checked with its own test.
local function zone_point( el )
	local shapes = {}
	for _, sh in ipairs( el._shapes or {} ) do
		shapes[#shapes + 1] = sh
	end
	for _, se in ipairs( el._shape_elements or {} ) do
		for _, sh in ipairs( se._shapes or {} ) do
			shapes[#shapes + 1] = sh
		end
	end
	for _, sh in ipairs( shapes ) do
		local pos = sh.position and sh:position()
		if pos and el._is_inside and el:_is_inside( pos ) then
			return mvector3.copy( pos )
		end
	end
end

local function wrap_element( el, on_run )
	local new = function( self, ... )
		if nail_active then
			pcall( on_run, self )
		end
		return getmetatable( self ).on_executed( self, ... )
	end
	el.on_executed = new
	nail_wrapped[#nail_wrapped + 1] = { el, new }
end

local function find_bag( carry_id )
	for _, unit in ipairs( World:find_units_quick( 'all', 14 ) ) do
		local cd = alive( unit ) and unit:carry_data()
		if cd and cd:carry_id() == carry_id and not cd._linked_to and not cd._zipline_unit
			and ( nail_tries[unit:key()] or 0 ) < MAX_TRIES_PER_BAG then
			return unit, cd
		end
	end
end

local function nail_update()
	local need = nail_need
	if not need then
		return
	end
	local t = TimerManager:game():time()
	if t < nail_next_t then
		return
	end
	nail_next_t = t + FEED_DELAY
	if need.el_trigger._values and need.el_trigger._values.enabled == false then
		if nail_hinted ~= 'disabled' then
			nail_hinted = 'disabled'
			nlog( need.trigger_name .. ' is disabled, waiting' )
		end
		return -- the lab isn't accepting this chemical right now
	end
	local unit, cd = find_bag( need.carry )
	if not unit then
		if nail_hinted ~= need then
			nail_hinted = need
			hint( 'no ' .. need.label .. ' bag on the map yet, waiting for the next drop' )
		end
		return
	end
	local key = unit:key()
	nail_tries[key] = ( nail_tries[key] or 0 ) + 1
	nlog( 'move ' .. need.carry .. ' bag ' .. tostring( key ) .. ' (try ' .. nail_tries[key] .. ') from ' .. tostring( unit:position() ) .. ' to ' .. tostring( need.point ) )
	cd:set_position_and_throw( need.point, Vector3( 0, 0, 0 ), 0 )
end

local nail_update_err
local function nail_update_safe()
	local ok, err = pcall( nail_update )
	if not ok and err ~= nail_update_err then
		nail_update_err = err
		nlog( 'ERROR in update: ' .. tostring( err ), true )
	end
end

local function nail_start()
	nlog( 'step 1: host check' )
	if is_client() then
		hint( 'Lab Rats cooking only works when you are the host' )
		return false
	end
	nlog( 'step 2: find elements (scripts: ' .. tostring( managers.mission and managers.mission.scripts ~= nil ) .. ')' )
	local found = {}
	for name, e in pairs( NAIL ) do
		local el, err = find_element( e.id, name )
		local trig, err2 = find_element( e.trigger, e.trigger_name )
		if not el or not trig then
			hint( 'Lab Rats not supported on this version of the map (' .. ( err or err2 ) .. ')' )
			return false
		end
		local point = zone_point( trig )
		nlog( e.trigger_name .. ': area=' .. tostring( trig.update_area ~= nil ) .. ' shapes=' .. #( trig._shapes or {} )
			.. ' shape_elements=' .. #( trig._shape_elements or {} ) .. ' enabled=' .. tostring( trig._values and trig._values.enabled )
			.. ' point=' .. tostring( point ) )
		if not point then
			hint( 'Lab Rats: could not find the lab drop zone for ' .. e.label )
			return false
		end
		found[name] = { el = el, trig = trig, point = point }
	end
	local stops = {}
	for name, id in pairs( NAIL_STOP ) do
		local el, err = find_element( id, name )
		if not el then
			hint( 'Lab Rats not supported on this version of the map (' .. err .. ')' )
			return false
		end
		stops[name] = el
	end
	nlog( 'step 3: hooks' )
	nail_active = true
	for name, e in pairs( NAIL ) do
		e.el_trigger = found[name].trig
		e.point = found[name].point
		wrap_element( found[name].el, function()
			set_need( e, name )
		end )
		wrap_element( found[name].trig, function()
			nlog( 'correct ' .. e.label .. ' bag counted' )
		end )
	end
	for sname, el in pairs( stops ) do
		wrap_element( el, function()
			nlog( sname )
			set_need( nil, sname )
		end )
	end
	local wrong = find_element( NAIL_WRONG.id, NAIL_WRONG.name )
	if wrong then
		wrap_element( wrong, function()
			nlog( 'WRONG bag thrown in (' .. NAIL_WRONG.name .. ')', true )
		end )
	end
	local by_dialog = {}
	for _, e in pairs( NAIL ) do
		for _, d in ipairs( e.dialogs ) do
			by_dialog[d] = e
		end
	end
	add_clbk( backuper, 'DialogManager.queue_dialog', function( o, self, id )
		local e = nail_active and by_dialog[id]
		if e then
			set_need( e, 'Bain ' .. tostring( id ) )
		end
	end, 'nail_dialog_hook', 1 )
	nlog( 'step 4: loop' )
	RunNewLoopIdent( 'autocooker_nail', nail_update_safe )
	hint( 'Lab Rats ON: it adds the right chemicals; you still bag and carry out the meth' )
	return true
end

local function nail_stop()
	nlog( 'OFF' )
	nail_active = false
	nail_need = nil
	StopLoopIdent( 'autocooker_nail' )
	remove_clbk( backuper, 'DialogManager.queue_dialog', 'nail_dialog_hook', 1 )
	for i = #nail_wrapped, 1, -1 do
		local el, fn = nail_wrapped[i][1], nail_wrapped[i][2]
		if rawget( el, 'on_executed' ) == fn then
			el.on_executed = nil
		end
	end
	nail_wrapped = {}
end

function MAIN()
	if level_id == 'nail' then
		nlog( '=== ON  (host: ' .. tostring( not is_client() ) .. ')' )
		-- Round 10c: plain pcall (10b used xpcall + debug.traceback and the toggle failed with a nil error)
		local ok, err = pcall( nail_start )
		nlog( 'start returned ok=' .. tostring( ok ) .. ' result=' .. tostring( err ) .. ' (' .. type( err ) .. ')', not ok or ( err ~= true and not is_client() ) )
		if not ok then
			hint( 'Lab Rats: error while starting, see Logfiles/Autocooker.log' )
		end
		return
	end
	add_clbk(backuper, 'DialogManager.queue_dialog', function(o, self, id)
		if id == 'pln_rt1_20' then
			cook_meth(needed_chem[1])
		elseif id == 'pln_rt1_22' then
			cook_meth(needed_chem[2])
		elseif id == 'pln_rt1_24' then
			cook_meth(needed_chem[3])
		end
	end, 'chemical_hook', 1)
	add_clbk(backuper, 'ObjectInteractionManager.add_unit', function(o, self, unit)
		executewithdelay(function()
			local interaction = alive(unit) and unit:interaction()
			if interaction and interaction.tweak_data == 'taking_meth' then
				if not spawn_meth_pos then
					local pos = interaction:interact_position()
					spawn_meth_pos = Vector3(pos.x + (level_id == 'alex_1' and -50 or 0), pos.y, pos.z + 10)
				end
				interaction:interact(_players[1])
				-- Round 6: rotation must be a Rotation (was a Vector3) and the throw upgrade level 0 (was 100)
				local rot = Rotation(random(-180, 180), 0, 0)
				if is_client() then
					GetNetSession():send_to_host('server_drop_carry', 'meth', 1, false, false, 1, spawn_meth_pos, rot, UP, 0, nil)
				else
					server_drop_carry(M_player, 'meth', 1, false, false, 1, spawn_meth_pos, rot, UP, 0, nil)
				end
				clear_carry(M_player)
			end
		end, 0.4)
	end, 'bag_meth_hook', 2)
end

function UNLOAD()
	if level_id == 'nail' then
		nail_stop()
		return
	end
	remove_clbk(backuper, 'DialogManager.queue_dialog', 'chemical_hook', 1)
	remove_clbk(backuper, 'ObjectInteractionManager.add_unit', 'bag_meth_hook', 2)
end

FINALIZE()