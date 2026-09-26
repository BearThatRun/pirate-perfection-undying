--Menu component. Shows extra menu with variants
--Author: Simplity
--Undying redesign stage 1: < value > on the right of the row, value in the accent colour.

local pairs = pairs

local Input = Input
local mouse = Input:mouse()
local keyboard = Input:keyboard()
local mouse_pressed = mouse.pressed
local keyboard_pressed = keyboard.pressed
local Idstring = Idstring
local left_click = Idstring("0")
local left_arrow_btn = Idstring("left")
local right_arrow_btn = Idstring("right")

local callback = callback
local managers = managers
local M_mouse_pointer = managers.mouse_pointer
local gui_mouse = M_mouse_pointer._mouse
local pd2_medium_font = tweak_data.menu.pd2_medium_font

local ppr_config = ppr_config
local RunNewLoop = RunNewLoop

local ARROW_TEX = "guis/textures/menu_arrows"
local VALUE_W = 150 -- space for the value between the arrows

local MultiChoice = class()

local function index_from_value(self, val)
	for i, data in pairs( self.data ) do
		if data.value == val then
			return i
		end
	end
end

function MultiChoice:init( panel, button )
	self.panel = panel
	self.button = button
	self.data = button.multi_choice_data
	self.name = button.name
	self.callback = button.multi_callback
	local val = button.value
	if (not val) then
		--Or get value from function. This way comfortable for dynamic values
		local func = button.value_func
		if (func) then
			val = func()
		end
	end
	self.index = ( val and index_from_value( self, val ) or button.index ) or 1

	self:create_gui()
	self.id = RunNewLoop( callback( self, self, "update" ) )
end

function MultiChoice:create_gui()
	local panel = self.panel
	local T = PPU_T
	local h = panel:h()

	local multi_choice = panel:panel( { name = "multi_choice", w = panel:w(), h = h, layer = 3 } )

	local arrow_right = multi_choice:bitmap( { texture = ARROW_TEX, texture_rect = {0,0,24,24}, w = 18, h = 18, rotation = 180, color = T.muted, layer = 2 } )
	arrow_right:set_right( panel:w() - 14 )
	arrow_right:set_center_y( h / 2 )

	local arrow_left = multi_choice:bitmap( { texture = ARROW_TEX, texture_rect = {0,0,24,24}, w = 18, h = 18, color = T.muted, layer = 2 } )
	arrow_left:set_right( arrow_right:x() - VALUE_W )
	arrow_left:set_center_y( h / 2 )

	local text_panel = multi_choice:text( { name = "text", text = "", layer = 1, wrap = false, word_wrap = false, visible = true,
										font = pd2_medium_font, font_size = 19, color = T.acc,
										align = "left", vertical = "top", blend_mode = "normal" } )
	self.text_panel = text_panel

	self.arrow_left = arrow_left
	self.arrow_right = arrow_right

	self:set_text_index()
end

function MultiChoice:set_text_index( index )
	index = index or self.index
	local entry = self.data[ index ]
	self:safe_set_text( entry and entry.text or "" )
end

function MultiChoice:update()
	local T = PPU_T
	local arrow_left, arrow_right = self.arrow_left, self.arrow_right
	local x, y = ppr_menu_mouse_pos()
	local left_moved = keyboard_pressed( keyboard, left_arrow_btn )
	local right_moved
	if ( not left_moved ) then
		right_moved = keyboard_pressed( keyboard, right_arrow_btn )
	end
	local clicked = mouse_pressed( mouse, left_click )
	local inside_panel = self.panel:inside(x,y)

	if arrow_left:inside( x, y ) then
		arrow_left:set_color( T.text )
		if (clicked or left_moved) then
			self:previous_option()
		end
	else
		if (inside_panel and left_moved) then
			self:previous_option( x, y )
		end
		arrow_left:set_color( T.muted )
	end

	if arrow_right:inside( x, y ) then
		arrow_right:set_color( T.text )
		if (clicked or right_moved) then
			self:next_option()
		end
	else
		if (inside_panel and right_moved) then
			self:next_option()
		end
		arrow_right:set_color( T.muted )
	end
end

function MultiChoice:previous_option()
	local data = self.data
	local new_index = self.index - 1
	local index = ( new_index < 1 ) and #data or new_index

	self:change_option( index )
end

function MultiChoice:next_option()
	local data = self.data
	local new_index = self.index + 1
	local index = data[ new_index ] and new_index or 1

	self:change_option( index )
end

function MultiChoice:change_option( index )
	local data = self.data[ index ]

	self.index = index
	local clbk = self.callback
	if (clbk) then
		clbk( self.name, data.value )
	end

	self:safe_set_text( data.text )
end

function MultiChoice:safe_set_text( text )
	local text_panel = self.text_panel

	text_panel:set_text( text or "" )
	local _,_,w,h = text_panel:text_rect()
	text_panel:set_size( w, h )
	text_panel:set_center_x( ( self.arrow_left:right() + self.arrow_right:left() ) / 2 )
	text_panel:set_center_y( self.panel:h() / 2 )
end

function MultiChoice:close()
	StopLoopIdent( self.id )
end

local G = getfenv(0)
G.MultiChoice = MultiChoice
