--Menu component. Represents tickbox.
--Author: Simplity
--Undying redesign stage 1: drawn as a switch (track + knob) in the theme colours.

local type = type

local togg_vars = togg_vars
local plugins = plugins
local required_plugins = plugins.required
local loaded = plugins.g_loaded

local Tickbox = class()

local TRACK_W, TRACK_H, KNOB = 34, 18, 14

function Tickbox:init( panel, button, plugin_path )
	self.panel = panel
	self.button = button
	self.plugin_path = plugin_path

	self:create_gui()
end

function Tickbox:create_gui()
	local panel = self.panel
	local T = PPU_T

	local sw = panel:panel( { name = "tickbox", w = TRACK_W, h = TRACK_H, layer = 3 } )
	sw:set_right( panel:w() - 16 )
	sw:set_center_y( panel:h() / 2 )
	sw:rect( { name = "track", color = T.line2, layer = 0 } )
	sw:rect( { name = "knob", x = 2, y = 2, w = KNOB, h = KNOB, color = T.text, layer = 1 } )
	self.tickbox = sw

	self:toggle()
end

function Tickbox:toggle()
	local on = self:get_state()
	local T = PPU_T
	local sw = self.tickbox
	sw:child( "track" ):set_color( on and T.acc or T.line2 )
	sw:child( "knob" ):set_x( on and ( TRACK_W - KNOB - 2 ) or 2 )
end

function Tickbox:get_state()
	local button = self.button

	local obj_toggle = button.toggle
	local toggle = type( obj_toggle )
	local plug = button.plugin
	if ( plug ) then
		local path = self.plugin_path
		if ( path ) then
			local real_name = required_plugins[path..plug]
			if ( real_name ) then
				return loaded( plugins, real_name )
			end
		end
	end
	if toggle ~= 'nil' then
		if toggle == "string" then
			return togg_vars[ obj_toggle ]
		elseif toggle == "function" then
			return obj_toggle()
		end
	end
	return false
end

local G = getfenv(0)
G.Tickbox = Tickbox
