--Menu component. Represents progress bar, that can be changed by user
--Author: Simplity
--Undying redesign: state only (drawn by menu.lua). Like the design, moving the slider only
--changes the shown value; Apply (or Enter) runs the slider's callback.

local game_config = game_config
local togg_vars = togg_vars
local math_floor = math.floor

local Slider = class()

function Slider:init( panel, button )
	local data = button.slider_data

	self.panel = panel
	self.button = button
	self.name = data.name
	self.min = data.min or 0
	self.max = data.max or 100
	self.step = data.step or 1
	-- add = true: the button adds the amount and the slider goes back to the start (money, XP)
	self.add = data.add and true or false
	self.prefix = data.prefix or ""
	local name = self.name
	local cur = togg_vars[ name ] or data.value or self.min
	if self.add then
		cur = button._ppu_val or self.min
	end
	if button._ppu_applied == nil then
		button._ppu_applied = cur
	end
	self.applied = button._ppu_applied
	-- keep a value the player moved to but didn't apply yet (the menu is redrawn often)
	self.value = button._ppu_val or cur
	togg_vars[ name ] = togg_vars[ name ] or cur
end

function Slider:set_value( v )
	local step = self.step
	v = math_floor( v / step + 0.5 ) * step
	if v < self.min then v = self.min elseif v > self.max then v = self.max end
	self.value = v
	self.button._ppu_val = v
	togg_vars[ self.name ] = v -- Save rows read this
	return v
end

function Slider:fraction()
	local span = self.max - self.min
	if span <= 0 then
		return 0
	end
	return ( self.value - self.min ) / span
end

function Slider:can_apply()
	if self.add then
		return self.value > self.min
	end
	return self.value ~= self.applied
end

function Slider:apply()
	if not self:can_apply() then
		return false
	end
	self:do_callback()
	self.applied = self.value
	self.button._ppu_applied = self.value
	if self.add then
		-- added: back to the start for the next amount
		self.value = self.min
		self.button._ppu_val = nil
		togg_vars[ self.name ] = self.min
	end
	return true
end

function Slider:do_callback()
	local callback_func = self.button.slider_callback
	if callback_func then
		callback_func( self.value )
	end
	togg_vars[ self.name ] = self.value
	if game_config then
		game_config[ self.name ] = self.value
	end
end

function Slider:close()
end

local G = getfenv(0)
G.Slider = Slider
