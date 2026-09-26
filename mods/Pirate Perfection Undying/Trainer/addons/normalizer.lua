--Purpose: restore modified by Trainer functions

local tr = Localization.translate
local executewithdelay = executewithdelay
local plugins = plugins
local ppr_dofile = ppr_dofile
local ppr_require = ppr_require
local M_player = managers.player
local tweak_data = tweak_data
local restore_all_func
do
	local backuper = backuper
	local restore_all = backuper.restore_all
	restore_all_func = function( ... )
		return restore_all(backuper, ...)
	end
end

ppr_require 'Trainer/tools/new_menu/menu'
local open_menu
do
	local Menu = Menu
	local open = Menu.open
	open_menu = function( ... )
		return open(Menu, ...)
	end
end

local function restore()
	do
		--Toggle off xray, if it exists
		local xray_state = gxray_Toggle
		if (xray_state) then
			local func, state = xray_state()
			if ( state ) then
				func()
			end
		end
	end
		
	-- Round 3: count what gets turned off, so it is clear something happened. Only toggled
	-- features (plugins) can be turned off; money, levels, unlocks etc. are saved changes.
	local count = 0
	if plugins then
		for _, p in pairs( plugins.plugins or {} ) do
			if p.loaded and p.cat ~= "no_reload" then
				count = count + 1
			end
		end
		plugins:unload_except_by_cat("no_reload", true)
	end
	ppu_feedback("Turned off " .. count .. " trainer feature(s). Saved changes (money, level, unlocks) stay.")
	
	--[[local restore_hacked_upgrades = M_player.restore_hacked_upgrades
	if ( restore_hacked_upgrades ) then
		restore_hacked_upgrades(M_player)
	end]]
end

local function reboot()
	restore()
	ppr_dofile('Trainer/Setup/auto_config') --Thank you Simplity, your idea made it easier
	ppu_feedback("Trainer changes turned off, config loaded again")
end

local main

local menu_data = {
	{ text = tr.normalizer_restore, callback = restore, switch_back = true, ask = "Turn off all trainer features?", meta = "turns off all trainer features" },
	{ text = tr.normalizer_reboot, callback = reboot, switch_back = true },
}
menu_data = { title = tr.Normalizer, description = tr.Normalizer_desc, button_list = menu_data, w_mul = 2.5, h_mul = 3.2 }

main = function()
	open_menu(menu_data)
end
return main