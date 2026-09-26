--Purpose: F2 > Theme. Colours of every trainer window (Undying menu redesign, stage 3).
--Each colour row opens R / G / B sliders; changes show live and are saved in the active
--config as cfg.PPU_Theme (see ppu_theme_* in Trainer/tools/new_menu/menu.lua).

local ppr_require = ppr_require
ppr_require 'Trainer/tools/new_menu/menu'

local Menu = Menu
local ipairs = ipairs
local tostring = tostring

local theme_menu = function()
	local list = {}
	for _, role in ipairs( PPU_THEME_ROLES ) do
		list[ #list + 1 ] = { text = role[2], type = "rgb", role = role[1] }
	end
	list[ #list + 1 ] = {}
	list[ #list + 1 ] = { text = "Reset theme to default", ask = "Reset all six colors?", switch_back = true,
		callback = function()
			ppu_theme_reset()
			ppu_feedback( "Theme reset to default" )
		end }

	local active = ppr_config and rawget( ppr_config, "DefaultConfig" ) or "default_config"
	Menu.open( Menu, {
		title = "Theme",
		description = "Colors for every trainer window. Changes show live and are saved in the active config. Active config: " .. tostring( active ) .. ".",
		button_list = list,
	} )
end

return theme_menu
