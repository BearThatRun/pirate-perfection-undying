--Menu component. Represents tickbox.
--Author: Simplity
--Undying redesign: state only. The switch (38x20 pill + 16px knob) is drawn by menu.lua.

local type = type

local togg_vars = togg_vars
local plugins = plugins
local required_plugins = plugins.required
local loaded = plugins.g_loaded

local Tickbox = class()

function Tickbox:init( panel, button, plugin_path )
	self.panel = panel
	self.button = button
	self.plugin_path = plugin_path
end

-- Called after the state may have changed: redraw the switch
function Tickbox:toggle()
	if self.on_change then
		self.on_change( self:get_state() )
	end
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
				return loaded( plugins, real_name ) and true or false
			end
		end
	end
	if toggle ~= 'nil' then
		if toggle == "string" then
			return togg_vars[ obj_toggle ] and true or false
		elseif toggle == "function" then
			return obj_toggle() and true or false
		end
	end
	return false
end

local G = getfenv(0)
G.Tickbox = Tickbox
