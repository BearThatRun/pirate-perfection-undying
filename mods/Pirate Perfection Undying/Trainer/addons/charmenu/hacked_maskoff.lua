--Purpose: lets you jump, crouch and run while your mask is off (casing mode).
--Undying rewrite: the old file replaced most of PlayerMaskOff with code from an old game
--version and could not be turned off. This version only unblocks jump, crouch and run
--(the game already lets you interact while casing) and restores them when turned off.

plugins:new_plugin('hacked_maskoff')

VERSION = '2.0'

CATEGORY = 'character'

local backuper = backuper
local hijack = backuper.hijack
local restore = backuper.restore

local unblock = { '_check_action_jump', '_check_action_duck', '_check_action_run' }

local hooked = false

function MAIN()
	if not rawget( _G, 'PlayerMaskOff' ) then -- main menu: nothing to hook
		return
	end
	hooked = true
	for _, fname in ipairs(unblock) do
		local std = PlayerStandard[fname]
		hijack(backuper, 'PlayerMaskOff.' .. fname, function( o, self, ... )
			return std(self, ...)
		end)
	end
end

function UNLOAD()
	if not hooked then
		return
	end
	hooked = false
	for _, fname in ipairs(unblock) do
		restore(backuper, 'PlayerMaskOff.' .. fname)
	end
end

FINALIZE()
