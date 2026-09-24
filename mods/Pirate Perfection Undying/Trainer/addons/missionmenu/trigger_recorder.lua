-- Trigger Recorder
-- Round 3 rewrite. The old version replaced MissionScriptElement.on_executed outright and,
-- when turned off, replaced it with an EMPTY function, which stops mission scripting for the
-- rest of the heist. It also only logged unit-sequence triggers (the file stayed empty).
-- Now: hooks with backuper (restored on unload) and logs every mission element that runs:
-- heist time, element id, element name, and unit sequences it triggers.
-- The file is started fresh at the beginning of every heist.
-- Undying test phase: ON by default (configs/blank_config/blank.lua). Turn off before publishing.

plugins:new_plugin('trigger_recorder')

VERSION = '2.0'

local file_name = 'Logfiles/Trigger List.txt'
local fh

local function time_string()
	local ok, t = pcall( function() return managers.game_play_central:get_heist_timer() end )
	t = ok and tonumber( t ) or 0
	t = math.floor( t )
	return string.format( "%02d:%02d:%02d", math.floor( t / 3600 ), math.floor( t / 60 ) % 60, t % 60 )
end

local function write_line( element )
	local line = time_string() .. "  #" .. tostring( element._id ) .. "  " .. tostring( element._editor_name )
	local values = element._values
	if values and values.trigger_list then
		for _, trigger in pairs( values.trigger_list ) do
			if trigger.notify_unit_sequence then
				line = line .. "  [seq " .. tostring( trigger.notify_unit_sequence ) .. "]"
			end
		end
	end
	fh:write( line .. "\n" )
	fh:flush()
end

local hooked = false

function MAIN()
	-- Only in a heist (config loading in the main menu runs this too; no mission classes there)
	if not ( rawget( _G, 'GameSetup' ) and rawget( _G, 'MissionScriptElement' ) ) then
		return
	end
	fh = ppr_io.open( file_name, 'w' )
	if fh then
		fh:write( "Heist: " .. tostring( Global.game_settings and Global.game_settings.level_id ) .. "  (started " .. os.date( "%Y-%m-%d %H:%M" ) .. ")\n" )
		fh:flush()
	end
	backuper:hijack( 'MissionScriptElement.on_executed', function( o, self, ... )
		if fh then
			pcall( write_line, self )
		end
		return o( self, ... )
	end )
	hooked = true
end

function UNLOAD()
	if hooked then
		backuper:restore( 'MissionScriptElement.on_executed' )
		hooked = false
	end
	if fh then
		fh:close()
		fh = nil
	end
end

FINALIZE()
