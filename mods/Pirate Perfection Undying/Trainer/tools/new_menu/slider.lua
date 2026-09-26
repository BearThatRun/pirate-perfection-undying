--Menu component. Represents progress bar, that can be changed by user
--Author: Simplity
--Undying redesign stage 1: label + live value on top, thin track with fill and knob below.

local mouse = Input:mouse()
local mouse_down = mouse.down
local Idstring = Idstring
local left_click = Idstring('0')
local right_click = Idstring('1')
local ceil = math.ceil

local managers = managers
local M_mouse_pointer = managers.mouse_pointer

local game_config = game_config
local togg_vars = togg_vars
local RunNewLoop = RunNewLoop
local callback = callback
local tweak_data = tweak_data
local pd2_small_font = tweak_data.menu.pd2_small_font
local plugins = plugins

local KNOB = 12

-- 1234567 -> "1,234,567"
local function fmt( n )
	local s = tostring( n )
	local neg, int, rest = s:match( "^(-?)(%d+)(.*)$" )
	if not int then
		return s
	end
	int = int:reverse():gsub( "(%d%d%d)", "%1," ):reverse():gsub( "^,", "" )
	return neg .. int .. rest
end

local Slider = class()

function Slider:init( panel, button )
	local data = button.slider_data

	self.panel = panel
	self.button = button
	self.name = data.name
	self.max = data.max -- maximum value
	local name = self.name
	self.value = togg_vars[ name ] or data.value or 0 -- current value
	togg_vars[ name ] = self.value

	self:create_gui()
	self.id = RunNewLoop( callback( self, self, "update" ) )
end

function Slider:create_gui()
	local panel = self.panel
	local T = PPU_T

	local slider = panel:panel( { name = "slider", x = 16, y = 24, w = panel:w() - 32, h = 20, layer = 3 } )
	self.slider = slider

	slider:rect( { name = "track", x = 0, y = 8, w = slider:w(), h = 4, color = T.line2, layer = 0 } )
	self.slider_bg = slider:rect( { name = "slider_bg", x = 0, y = 8, w = 0, h = 4, color = T.acc, layer = 1 } )
	self.knob = slider:rect( { name = "knob", x = 0, y = 4, w = KNOB, h = KNOB, color = T.text, layer = 2 } )

	self.slider_text = panel:text( { name = "slider_text", text = "", layer = 3, wrap = false, word_wrap = false, visible = true,
						  font = pd2_small_font, font_size = 18, color = T.text, y = 6,
						  align = "left", vertical = "top", blend_mode = "normal" } )

	self:set_default_value()
end

function Slider:_draw( where )
	local slider = self.slider
	self.slider_bg:set_w( slider:w() * where )
	self.knob:set_x( ( slider:w() - KNOB ) * where )
end

function Slider:set_default_value()
	local where = self.max > 0 and ( self.value / self.max ) or 0
	if where < 0 then where = 0 elseif where > 1 then where = 1 end
	self:_draw( where )
	self:safe_set_text( self.value )
end

function Slider:update()
	local x, y = ppr_menu_mouse_pos()
	local held = ( not self.button.plugin and mouse_down( mouse, left_click ) ) or mouse_down( mouse, right_click )

	-- Round 4: once you press on the bar you keep dragging while the button is held, even
	-- outside the bar, so dragging past either end gives the exact min / max.
	if held and ( self.dragging or self.slider:inside( x, y ) ) then
		self.dragging = true
		self:on_slider( x )
	elseif not held then
		self.dragging = false
	end
end

function Slider:on_slider( x )
	local slider = self.slider

	local where = ( x - slider:world_left() ) / ( slider:world_right() - slider:world_left() )

	-- Round 4: no snap zone any more (it blocked values near the ends); just clamp.
	if where < 0 then
		where = 0
	elseif where > 1 then
		where = 1
	end

	self:_draw( where )

	self.value = math.floor( self.max * where + 0.5 )
	self:safe_set_text( self.value )

	self:do_callback()
end

function Slider:do_callback()
	if self.button.plugin then
		self:callback_plugin()
	else
		self:callback_button()
	end
end

function Slider:callback_plugin()
	local callback_func = self.button.slider_callback

	if callback_func then
		callback_func( self.value )
	end

	togg_vars[ self.name ] = self.value -- save current value

	if game_config then
		game_config[ self.name ] = self.value
	end
end

function Slider:callback_button()
	togg_vars[ self.name ] = self.value

	local callback_func = self.button.slider_callback -- Undying: live callback for non-plugin sliders too
	if callback_func then
		callback_func( self.value )
	end

	if game_config then
		game_config[ self.name ] = self.value
	end
end

function Slider:safe_set_text( text )
	local slider_text = self.slider_text

	slider_text:set_text( fmt( text ) )
	local _,_,w,h = slider_text:text_rect()
	slider_text:set_size( w, h )
	slider_text:set_right( self.panel:w() - 16 )
end

function Slider:close()
	StopLoopIdent( self.id )
end

local G = getfenv(0)
G.Slider = Slider
