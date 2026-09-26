--Menu component. Save row: saves the value of the slider/input with the same name.
--Author: Simplity
--Undying redesign: drawn by menu.lua as a normal action row.

local SaveButton = class()

local togg_vars = togg_vars

function SaveButton:init( panel, button )
	self.button = button
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
