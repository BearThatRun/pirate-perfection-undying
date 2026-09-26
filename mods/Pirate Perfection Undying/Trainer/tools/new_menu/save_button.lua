--Menu component. Represents button with text in the middle
--Author: Simplity
--Undying redesign stage 1: drawn as a filled accent button on the right of its row.

local SaveButton = class()

local togg_vars = togg_vars

function SaveButton:init( panel, button )
	self.button = button
	local T = PPU_T

	local text = panel:child( "text" )
	local bw = text:w() + 28
	local bp = panel:panel( { name = "save_btn", w = bw, h = 24, layer = 2 } )
	bp:set_right( panel:w() - 16 )
	bp:set_center_y( panel:h() / 2 )
	bp:rect( { name = "save_bg", color = T.acc, layer = 0 } )

	text:set_color( T.bg )
	text:set_layer( 5 )
	text:set_center_x( bp:center_x() )
	text:set_center_y( bp:center_y() )
end

function SaveButton:save()
	local button = self.button
	local callback = button.callback
	local name = button.name
	local value = togg_vars[ name ]

	if callback and value then
		callback( value )
		if ppu_feedback then
			ppu_feedback( "Saved: " .. tostring( value ) )
		elseif show_hint then
			show_hint( "Saved: " .. tostring( value ) )
		end
	end
end

local G = getfenv(0)
G.SaveButton = SaveButton
