--Purpose: restores drill once it's jammed.
--Author: baldwin
--Round 3 fix: the hook also ran when the game called set_jammed(false) (drill un-jamming,
--e.g. melee auto-repair), re-placing a drill that wasn't jammed. That crashed the game in
--Drill:set_alert_radius (_nav_tracker nil). Now: only for real jams, one frame later, and
--only if the drill is still jammed.

plugins:new_plugin('drill_auto_service')

local alive = alive
local managers = managers
local M_player = managers.player

FULL_NAME = 'Drill auto service'

VERSION = '1.1'

DESCRIPTION = 'Automatically restores drill when it jams'

local fix_id = 0

local function fix_drill( drill )
	local unit = drill and drill._unit
	if not alive( unit ) or not drill._jammed then
		return
	end
	local interaction = unit.interaction and unit:interaction()
	if interaction and interaction.interact then
		interaction:interact( M_player:local_player() )
	end
end

function MAIN()
	backuper:hijack('Drill.set_jammed',function(o,self, jammed, ... )
		local r = o(self,jammed, ...)
		if jammed then
			fix_id = fix_id + 1
			local drill = self
			DelayedCalls:Add( "ppu_drill_fix_" .. fix_id, 0.1, function()
				local ok, err = pcall( fix_drill, drill )
				if not ok then
					m_log_error( 'drill_auto_service', tostring( err ) )
				end
			end )
		end
		return r
	end)
end

function UNLOAD()
	backuper:restore('Drill.set_jammed')
end

FINALIZE()
