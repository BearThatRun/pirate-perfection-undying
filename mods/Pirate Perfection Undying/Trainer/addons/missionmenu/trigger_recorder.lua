-- Trigger Recorder
-- Round 3 rewrite. The old version replaced MissionScriptElement.on_executed outright and,
-- when turned off, replaced it with an EMPTY function, which stops mission scripting for the
-- rest of the heist. It also only logged unit-sequence triggers (the file stayed empty).
-- Now: hooks with backuper (restored on unload) and logs every mission element that runs:
-- heist time, element id, element name, and unit sequences it triggers.
-- Round 9: one file PER HEIST ("Trigger List - <heist id>.txt"), and each run is ADDED to the
-- end of it (a new "=== Run" header), so playing another heist can't wipe a recording.
-- Also logs what the auto-cooker needs: Bain's voice lines (DIALOG), what you interact with
-- (INTERACT = pressed, DONE = finished), and bags you pick up / drop / throw (CARRY).
-- Undying test phase: ON by default (configs/blank_config/blank.lua). Turn off before publishing.

plugins:new_plugin('trigger_recorder')

VERSION = '2.1'

local fh

local function time_string()
	local ok, t = pcall( function() return managers.game_play_central:get_heist_timer() end )
	t = ok and tonumber( t ) or 0
	t = math.floor( t )
	return string.format( "%02d:%02d:%02d", math.floor( t / 3600 ), math.floor( t / 60 ) % 60, t % 60 )
end

local function log_line( text )
	if fh then
		fh:write( time_string() .. "  " .. text .. "\n" )
		fh:flush()
	end
end

local function write_line( element )
	local line = "#" .. tostring( element._id ) .. "  " .. tostring( element._editor_name )
	local values = element._values
	if values then
		if values.dialogue and values.dialogue ~= "none" then
			line = line .. "  [dialog " .. tostring( values.dialogue ) .. "]"
		end
		if values.trigger_list then
			for _, trigger in pairs( values.trigger_list ) do
				if trigger.notify_unit_sequence then
					line = line .. "  [seq " .. tostring( trigger.notify_unit_sequence ) .. "]"
				end
			end
		end
	end
	log_line( line )
end

local function interaction_name( unit )
	local int = unit and alive( unit ) and unit:interaction()
	return int and tostring( int.tweak_data ) or "?"
end

-- Round 9: wrap whatever function is installed right now, instead of backuper:hijack.
-- hijack always wraps the game's ORIGINAL function, so it replaced the Bag Stacking
-- set_carry/drop_carry and knocked out the auto-cooker's dialog callback.
-- On unload a function is only put back if nothing wrapped it after us; otherwise our
-- wrapper just stops logging (active = false) and passes calls through.
local active = false
local wrapped = {}

local function wrap( class, name, logger )
	local cur = class and class[name]
	if type( cur ) ~= 'function' then
		return
	end
	local new = function( self, ... )
		if active then
			pcall( logger, self, ... )
		end
		return cur( self, ... )
	end
	class[name] = new
	wrapped[#wrapped + 1] = { class, name, cur, new }
end

function MAIN()
	-- Only in a heist (config loading in the main menu runs this too; no mission classes there)
	if not ( rawget( _G, 'GameSetup' ) and rawget( _G, 'MissionScriptElement' ) ) then
		return
	end
	local level_id = tostring( Global.game_settings and Global.game_settings.level_id )
	fh = ppr_io.open( 'Logfiles/Trigger List - ' .. level_id .. '.txt', 'a' )
	if fh then
		-- Round 6: no os.date here, the game's Lua has no 'os' library
		fh:write( "\n=== Run  Heist: " .. level_id .. "\n" )
		fh:flush()
	end
	active = true
	wrap( MissionScriptElement, 'on_executed', function( self )
		write_line( self )
	end )
	wrap( DialogManager, 'queue_dialog', function( self, id )
		log_line( "DIALOG " .. tostring( id ) )
	end )
	wrap( ObjectInteractionManager, 'interact', function( self )
		log_line( "INTERACT " .. interaction_name( self._active_unit ) )
	end )
	wrap( ObjectInteractionManager, 'end_action_interact', function( self )
		log_line( "DONE " .. interaction_name( self._active_unit ) )
	end )
	wrap( PlayerManager, 'set_carry', function( self, carry_id )
		log_line( "CARRY pick up " .. tostring( carry_id ) )
	end )
	wrap( PlayerManager, 'drop_carry', function( self )
		local c = self:get_my_carry_data()
		log_line( "CARRY drop/throw " .. tostring( type( c ) == 'table' and c.carry_id ) )
	end )
end

function UNLOAD()
	active = false
	for i = #wrapped, 1, -1 do
		local w = wrapped[i]
		if w[1][w[2]] == w[4] then
			w[1][w[2]] = w[3]
		end
	end
	wrapped = {}
	if fh then
		fh:close()
		fh = nil
	end
end

FINALIZE()
