--Menu component. Represents field, where you can enter your text
--Author: Simplity
--Undying redesign: the field is drawn by menu.lua; this keeps the text and reads the keyboard.
--The typed text is also kept in a hidden game text object called "input_text" inside
--input_panel, because config_menu.lua reads it from there.

local kb = Input:keyboard()
local kb_pressed = kb.pressed
local kb_down = kb.down

local pcall = pcall
local safecall = safecall
local Idstring = Idstring

local bkspace = Idstring("backspace")
local enter = Idstring("enter")

local m_log_error = m_log_error
local str_gmatch = string.gmatch

local UTF8 = "[%z\1-\127\194-\244][\128-\191]*"

local function now()
	local ok, t = pcall( function() return Application:time() end )
	if ok and t then
		return t
	end
	return os and os.clock and os.clock() or 0
end

local function drop_last_char( s )
	local list = {}
	for ch in str_gmatch( s, UTF8 ) do
		list[ #list + 1 ] = ch
	end
	list[ #list ] = nil
	return table.concat( list )
end

local TextInput = class()

function TextInput:init( panel, button, ws, kb_panel )
	self.panel = panel
	self.kb_panel = kb_panel or panel -- object that receives typed text (kept alive while the menu redraws)
	self.button = button
	self.ws = ws
	if ws then
		ws:connect_keyboard( kb )
	end
	-- hidden mirror for config_menu.lua
	self.input_panel = panel:panel( { name = "input_panel", w = 1, h = 1, visible = false } )
	self.mirror = self.input_panel:text( { name = "input_text", text = "", font = tweak_data.menu.pd2_small_font, font_size = 10, visible = false } )
	self:set_text( button._ppu_text or button.value or "" )
end

function TextInput:text()
	return self._text or ""
end

function TextInput:set_text( s )
	s = tostring( s or "" )
	self._text = s
	self.button._ppu_text = s
	self.mirror:set_text( s )
	if self.on_change then
		self.on_change( s )
	end
end

function TextInput:enter_text( o, s )
	if s == nil or s == "" then
		return
	end
	-- ignore control characters (Enter, Backspace, Tab come as keys)
	if s:byte( 1 ) and s:byte( 1 ) < 32 then
		return
	end
	self:set_text( self:text() .. s )
	self:on_text()
end

function TextInput:activate_input()
	if self.input_enabled then
		return
	end
	if TextInput.active and TextInput.active ~= self then
		TextInput.active:disable_input()
	end
	local ok = pcall( function()
		self.kb_panel:enter_text( function( o, s ) self:enter_text( o, s ) end )
	end )
	self.input_enabled = true
	TextInput.active = self
	self._bk_t = nil
	if self.on_focus then
		self.on_focus( true )
	end
end

function TextInput:disable_input()
	if not self.input_enabled then
		return
	end
	pcall( function() self.kb_panel:enter_text( nil ) end )
	self.input_enabled = false
	self.button.value = self:text()
	if TextInput.active == self then
		TextInput.active = nil
	end
	if self.on_focus then
		self.on_focus( false )
	end
end

-- Called every frame by the menu while this field is active. Returns true when Enter was pressed.
function TextInput:update_keys()
	if not self.input_enabled then
		return
	end
	-- Backspace, repeating while held
	local t = now()
	if kb_pressed( kb, bkspace ) then
		self:remove_text()
		self._bk_t = t + 0.45
	elseif kb_down( kb, bkspace ) then
		if self._bk_t and t >= self._bk_t then
			self:remove_text()
			self._bk_t = t + 0.04
		end
	else
		self._bk_t = nil
	end
	if kb_pressed( kb, enter ) then
		return true
	end
end

function TextInput:remove_text()
	local s = self:text()
	if s ~= "" then
		self:set_text( drop_last_char( s ) )
		self:on_text()
	end
end

function TextInput:on_text()
	local on_text_clbk = self.button.on_text_clbk
	if ( on_text_clbk ) then
		safecall( on_text_clbk, self:text() )
	end
end

function TextInput:do_callback()
	local clbk_input = self.button.callback_input
	if clbk_input then
		local s, e = pcall( clbk_input, self:text() )
		if not s then
			m_log_error('TextInput:do_callback()', e)
		end
	end
end

function TextInput:close()
	self:disable_input()
end

local G = getfenv(0)
G.TextInput = TextInput
