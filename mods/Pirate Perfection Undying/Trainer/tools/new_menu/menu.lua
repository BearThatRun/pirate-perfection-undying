-- Menu class by Simplity
-- Undying menu redesign, stage 1 (2026-09-26): new look from BearThatRun's design
-- (PPU_Menu_Redesign.html): tab bar, header with key badge + context + big title,
-- restyled rows (switches, chevrons, choice arrows, sliders), highlight bar, footer.
-- Behaviour (paging, mouse, save rows, callbacks) is unchanged; menu files don't change.

local pairs = pairs
local ipairs = ipairs
local ppr_require = ppr_require
local type = type
local safecall = safecall
local unpack = unpack
local table = table
local tab_insert = table.insert
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local io_open = ppr_io.open

local tr = Localization.translate

-- x64 port: mouse position in the menus' 1280 layout workspace (fixes ultrawide hit areas)
function ppr_menu_mouse_pos()
	local mp = managers.mouse_pointer
	local x, y = mp._mouse:world_position()
	if mp.convert_1280_mouse_pos then
		return mp:convert_1280_mouse_pos( x, y )
	end
	return x, y
end

---------------------------------------------------------------------------------------------
-- Theme (design defaults = PAYDAY 2 blue). Stage 3 will let the player edit and save these.
---------------------------------------------------------------------------------------------
PPU_THEME_DEFAULT = PPU_THEME_DEFAULT or {
	bg = { 7, 9, 12 },
	surf = { 22, 38, 54 },
	text = { 255, 255, 255 },
	muted = { 150, 162, 175 },
	acc = { 48, 172, 255 },
	warn = { 255, 72, 60 },
}

local function rgb( t, a )
	local c = Color( t[1] / 255, t[2] / 255, t[3] / 255 )
	if a then
		c = c:with_alpha( a )
	end
	return c
end

function ppu_theme()
	local ok_s, saved = pcall( function() return ppr_config and ppr_config.PPU_Theme end )
	saved = ok_s and saved or nil
	local src = {}
	for k, v in pairs( PPU_THEME_DEFAULT ) do
		local s = type( saved ) == "table" and saved[k]
		src[k] = ( type( s ) == "table" and #s == 3 ) and s or v
	end
	local T = { raw = src }
	for k, v in pairs( src ) do
		T[k] = rgb( v )
	end
	T.line = rgb( src.text, 0.10 )
	T.line2 = rgb( src.text, 0.22 )
	T.accsoft = rgb( src.acc, 0.16 )
	T.warnsoft = rgb( src.warn, 0.16 )
	T.tabbar = Color.black:with_alpha( 0.28 )
	return T
end

-- Layout constants (1280x720 layout workspace)
local WIN_W = 560
local PAD = 16
local ROW_H = 30
local SLIDER_H = 50
local SPACER_H = 13
local TAB_H = 42
local FOOT_H = 46
PPU_PAGE_ROWS = 14 -- rows per page until stage 2 adds scrolling

---------------------------------------------------------------------------------------------
-- Tabs: the same callbacks the F-keys run (KeyInput.keys[key].callback)
---------------------------------------------------------------------------------------------
local TABS_MENU = {
	{ "f1", "F1", "Help" }, { "f2", "F2", "Config" }, { "f3", "F3", "Pre-game" }, { "f4", "F4", "Job" },
	{ "page up", "PGUP", "Tools" }, { "page down", "PGDN", "Music" }, { "home", "HOME", "Normalizer" },
}
local TABS_HEIST = {
	{ "f1", "F1", "Help" }, { "f2", "F2", "Config" }, { "f3", "F3", "Character" }, { "f4", "F4", "Stealth" },
	{ "f5", "F5", "Troll" }, { "f6", "F6", "Interaction" }, { "f7", "F7", "Inventory" }, { "f8", "F8", "Equipment" },
	{ "f10", "F10", "Mission" }, { "f11", "F11", "Mod" }, { "f12", "F12", "Spawn" },
	{ "page up", "PGUP", "Tools" }, { "page down", "PGDN", "Music" }, { "home", "HOME", "Normalizer" },
}

local function current_tabs()
	local list = rawget( _G, "GameSetup" ) and TABS_HEIST or TABS_MENU
	local keys = rawget( _G, "KeyInput" ) and KeyInput.keys or {}
	local out = {}
	for _, t in ipairs( list ) do
		local v = keys[ t[1] ]
		if v and v.callback then
			out[ #out + 1 ] = t
		end
	end
	return out
end

-- Remember which key opened the menu, so its tab is highlighted.
local function ensure_key_hooks()
	local keys = rawget( _G, "KeyInput" ) and KeyInput.keys
	if not keys then
		return
	end
	for _, list in ipairs( { TABS_MENU, TABS_HEIST } ) do
		for _, t in ipairs( list ) do
			local key = t[1]
			local v = keys[ key ]
			if v and v.callback and not v.__ppu_tab then
				local orig = v.callback
				v.callback = function( ... )
					PPU_current_tab = key
					return orig( ... )
				end
				v.__ppu_tab = true
			end
		end
	end
end
if executewithdelay then
	executewithdelay( { func = ensure_key_hooks, params = {} }, 0.1, "ppu_key_hooks" )
end

---------------------------------------------------------------------------------------------

ppr_require 'Trainer/tools/new_menu/tickbox'
ppr_require 'Trainer/tools/new_menu/slider'
ppr_require 'Trainer/tools/new_menu/multi_choice'
ppr_require 'Trainer/tools/new_menu/text_input'
ppr_require 'Trainer/tools/new_menu/save_button'
ppr_require 'Trainer/experimental/dev/pluginmanager'

local Tickbox = Tickbox
local MultiChoice = MultiChoice
local Slider = Slider
local TextInput = TextInput
local SaveButton = SaveButton

local mouse = Input:mouse()
local mouse_pressed = mouse.pressed
local Idstring = Idstring
local left_click = Idstring('0')
local right_click = Idstring('1')
local wheel_up = Idstring('mouse wheel up')
local wheel_down = Idstring('mouse wheel down')
-- Not sure every mouse device accepts the wheel as a 'button'; test once, use only if it works.
local wheel_ok = pcall( mouse_pressed, mouse, wheel_up )
local function wheel( id )
	return wheel_ok and mouse_pressed( mouse, id )
end

local clone = clone
local managers = managers
local M_mouse_pointer = managers.mouse_pointer
local M_controller = managers.controller

local tweak_data = tweak_data
local T_menu = tweak_data.menu
local T_gui = tweak_data.gui
local callback = callback
local __load_plugin = load_plugin
local OverlayGui = Overlay:gui()
local RunNewLoopIdent = RunNewLoopIdent
local StopLoopIdent = StopLoopIdent
local executewithdelay = executewithdelay
local backuper = backuper
local restore = backuper.restore
local backup = backuper.backup
local m_log_error = m_log_error
local m_log_vs = m_log_vs
local plugins = plugins
local is_client = is_client

local void = void

local FONT_L = T_menu.pd2_large_font
local FONT_M = T_menu.pd2_medium_font
local FONT_S = T_menu.pd2_small_font
local ARROW_TEX = "guis/textures/menu_arrows"

local Menu = class()

-- Small drawing helpers
local function outline( panel, color, layer )
	local w, h = panel:w(), panel:h()
	panel:rect( { name = "ol_t", x = 0, y = 0, w = w, h = 1, color = color, layer = layer } )
	panel:rect( { name = "ol_b", x = 0, y = h - 1, w = w, h = 1, color = color, layer = layer } )
	panel:rect( { name = "ol_l", x = 0, y = 0, w = 1, h = h, color = color, layer = layer } )
	panel:rect( { name = "ol_r", x = w - 1, y = 0, w = 1, h = h, color = color, layer = layer } )
end

local function set_outline_color( panel, color )
	for _, n in ipairs( { "ol_t", "ol_b", "ol_l", "ol_r" } ) do
		local r = panel:child( n )
		if r then
			r:set_color( color )
		end
	end
end

local function make_text( panel, cfg )
	cfg.layer = cfg.layer or 3
	cfg.wrap = cfg.wrap or false
	cfg.word_wrap = cfg.word_wrap or false
	cfg.blend_mode = "normal"
	cfg.visible = true
	local t = panel:text( cfg )
	local _, _, tw, th = t:text_rect()
	if not cfg.w then
		t:set_w( tw )
	end
	if not cfg.h then
		t:set_h( th )
	end
	return t, tw, th
end
PPU_make_text = make_text

function Menu:init( data )
	local active_menu = tweak_data.menu_active
	if active_menu then
		active_menu:close()
	end

	ensure_key_hooks()
	self.T = ppu_theme()
	_G.PPU_T = self.T

	self._data = data
	local ws = OverlayGui:create_screen_workspace()
	self._ws = ws
	managers.gui_data:layout_1280_workspace( ws )
	tweak_data.menu_active = self
	self.close_clbks = {}

	self:create_menu()
	self:setup_mouse()
	self:disable_controllers( true )
	self:add_controller()
	RunNewLoopIdent( "menu_update", self.update, self )

	if data.plugin_path then
		self.load_plugin = __load_plugin( data.plugin_path )
	end

--Stop disable_controllers delayed callback, created by previous menu to prevent stupid bugs
	StopLoopIdent( 'disable_cont_clbk' )
end

local preload_plugin = plugins.pre_require

function Menu.open( _, data, n ) -- sorted dialog
	local max_entries = PPU_PAGE_ROWS

	if not n or n < 1 then
		n = 1
	end

	local n_data = {}
	local menu_data = clone( data )
	local button_list = menu_data.button_list
	local open = Menu.open
	if n > 1 then
		menu_data.back = function() open( Menu, data, n - max_entries ) end
		menu_data.back_is_page = true
	end

	local delta = 0 --This will help to resort list, if some button failed validation
	local plug_path = data.plugin_path
	for i = n, #button_list do
		local button = button_list[i]
		if ( delta ~= 0 ) then
			i = i - delta
			button_list[i] = button
		end
		--This will validate if some plugin exists on harddrive. If not, button will not be added.
		--Also it preloads plugins
		local have_plugin = button.plugin
		local selected_path = button.plugin_path or plug_path
		if (not have_plugin or not selected_path or preload_plugin( plugins, selected_path..have_plugin )) then
			if i >= ( max_entries + n ) then
				menu_data.next = function() open( Menu, data, i ) end
				break
			end
			tab_insert( n_data, button )
		else
			delta = delta + 1
		end
	end

	menu_data.button_list = n_data
	menu_data.page_from = n
	menu_data.page_total = #button_list
	return Menu:new( menu_data )
end

---------------------------------------------------------------------------------------------
-- Draw menu
---------------------------------------------------------------------------------------------

function Menu:create_menu()
	local scaled_size = managers.gui_data:scaled_size()
	local data = self._data
	local T = self.T
	local w = WIN_W
	if data.w_mul then
		w = math_max( WIN_W, math_floor( scaled_size.width / data.w_mul ) )
	end
	w = math_min( w, scaled_size.width - 40 )
	self.win_w = w

	local main = self._ws:panel():panel( { visible = true, x = 0, y = 0, w = w, h = 100, layer = T_gui.DIALOG_LAYER } )
	self.main = main

	local y = 0
	y = self:add_tabs( y )
	y = self:add_header( y )
	y = self:add_buttons( y )
	y = self:add_navigation( y )

	main:set_h( y )
	main:rect( { name = "win_bg", x = 0, y = 0, w = w, h = y, color = T.bg, alpha = 0.97, layer = 0 } )
	outline( main, T.line, 10 )

	local ws_panel = self._ws:panel()
	main:set_center( ws_panel:center() )
	if main:top() < 10 then
		main:set_top( 10 )
	end
end

function Menu:add_tabs( y )
	local T = self.T
	local main = self.main
	local w = self.win_w
	local tabs = current_tabs()
	self.tabs = tabs
	if #tabs == 0 then
		return y
	end

	local bar = main:panel( { name = "tabs_panel", x = 0, y = y, w = w, h = TAB_H, layer = 1 } )
	self.tabs_panel = bar
	bar:rect( { name = "tabs_bg", color = T.tabbar, layer = 0 } )
	bar:rect( { name = "tabs_line", x = 0, y = TAB_H - 1, w = w, h = 1, color = T.line, layer = 1 } )

	local strip = bar:panel( { name = "tab_strip", x = 0, y = 0, w = w, h = TAB_H, layer = 2 } )
	self.tab_strip = strip
	local inner = strip:panel( { name = "tab_inner", x = 0, y = 0, w = 10, h = TAB_H } )
	self.tab_inner = inner

	local x = 0
	local active_x, active_w
	self.tab_map = {}
	for i, t in ipairs( tabs ) do
		local on = PPU_current_tab == t[1]
		local tp = inner:panel( { name = "tab_" .. i, x = x, y = 0, w = 60, h = TAB_H } )
		local kt, kw = make_text( tp, { name = "key", text = t[2], font = FONT_S, font_size = 13, color = on and T.text or T.muted, y = 5 } )
		local nt, nw = make_text( tp, { name = "label", text = t[3], font = FONT_S, font_size = 16, color = on and T.text or T.muted, y = 19 } )
		local tw = math_max( kw, nw ) + 20
		tp:set_w( tw )
		kt:set_center_x( tw / 2 )
		nt:set_center_x( tw / 2 )
		if on then
			tp:rect( { name = "tab_bg", color = T.accsoft, layer = 1 } )
			tp:rect( { name = "tab_line", x = 0, y = TAB_H - 2, w = tw, h = 2, color = T.acc, layer = 2 } )
			active_x, active_w = x, tw
		end
		self.tab_map[ "tab_" .. i ] = t
		x = x + tw
	end
	inner:set_w( x )
	self.tab_total = x

	-- Overflow arrows
	if x > w then
		for _, side in ipairs( { "left", "right" } ) do
			local ap = bar:panel( { name = "tab_" .. side, x = side == "left" and 0 or w - 28, y = 0, w = 28, h = TAB_H - 1, layer = 5 } )
			ap:rect( { name = "arrow_bg", color = T.bg, alpha = 0.92, layer = 0 } )
			ap:bitmap( { name = "arrow", texture = ARROW_TEX, texture_rect = { 0, 0, 24, 24 }, w = 18, h = 18, x = 5, y = ( TAB_H - 18 ) / 2,
				color = T.text, layer = 1, rotation = side == "right" and 180 or 0 } )
		end
		self.tab_overflow = true
		local off = PPU_tab_offset or 0
		if active_x then
			if active_x - off < 28 or active_x + active_w - off > w - 28 then
				off = active_x - ( w - active_w ) / 2
			end
		end
		self:set_tab_offset( off )
	end

	return y + TAB_H
end

function Menu:set_tab_offset( off )
	local w = self.win_w
	local max_off = math_max( 0, ( self.tab_total or 0 ) - w + 28 )
	off = math_max( 0, math_min( off, max_off ) )
	PPU_tab_offset = off
	local inner = self.tab_inner
	if inner then
		local ix = ( off > 0 and 28 or 0 ) - off
		inner:set_x( ix )
		-- Don't rely on panels clipping their children: hide tabs that don't fully fit.
		local left_bound = off > 0 and 28 or 0
		local right_bound = ( self.tab_overflow and off < max_off ) and ( w - 28 ) or w
		for _, tp in ipairs( inner:children() ) do
			if tp.child then
				local l = ix + tp:x()
				tp:set_visible( l >= left_bound - 0.5 and l + tp:w() <= right_bound + 0.5 )
			end
		end
	end
	local bar = self.tabs_panel
	if bar and self.tab_overflow then
		bar:child( "tab_left" ):set_visible( off > 0 )
		bar:child( "tab_right" ):set_visible( off < max_off )
	end
end

function Menu:add_header( y )
	local T = self.T
	local main = self.main
	local data = self._data
	local w = self.win_w

	local hp = main:panel( { name = "header_panel", x = 0, y = y, w = w, h = 100, layer = 1 } )
	self.header_panel = hp
	local hy = 14

	-- Key badge + context
	local key_label
	for _, t in ipairs( self.tabs or {} ) do
		if t[1] == PPU_current_tab then
			key_label = t[2]
		end
	end
	local bx = PAD
	if key_label then
		local badge = hp:panel( { name = "badge", x = PAD, y = hy, w = 30, h = 18 } )
		local bt, bw = make_text( badge, { name = "badge_text", text = key_label, font = FONT_S, font_size = 14, color = T.bg, y = 1, x = 5 } )
		badge:set_w( bw + 10 )
		badge:rect( { name = "badge_bg", color = T.acc, layer = 1 } )
		bx = badge:right() + 8
	end
	local ctx = rawget( _G, "GameSetup" ) and "IN HEIST" or "MAIN MENU"
	if data.page_total and data.page_total > PPU_PAGE_ROWS then
		local last = math_min( data.page_total, ( data.page_from or 1 ) + #( data.button_list or {} ) - 1 )
		ctx = ctx .. "   |   " .. tostring( data.page_from or 1 ) .. "-" .. tostring( last ) .. " OF " .. tostring( data.page_total )
	end
	make_text( hp, { name = "ctx", text = ctx, font = FONT_S, font_size = 14, color = T.muted, x = bx, y = hy + 1 } )
	hy = hy + 24

	-- Title
	local title = tostring( data.title or "" )
	local tt, _, th = make_text( hp, { name = "title", text = utf8.to_upper and utf8.to_upper( title ) or title:upper(), font = FONT_L, font_size = 26,
		color = T.text, x = PAD, y = hy, w = w - PAD * 2, wrap = true, word_wrap = true } )
	local _, _, _, th2 = tt:text_rect()
	tt:set_h( th2 )
	self.title_text = tt
	hy = hy + th2 + 4

	-- Description
	local desc = data.description
	local dt = hp:text( { name = "description", text = desc or "", font = FONT_S, font_size = 17, color = T.muted,
		x = PAD, y = hy, w = w - PAD * 2, h = 10, wrap = true, word_wrap = true, layer = 3, blend_mode = "normal" } )
	local _, _, _, dh = dt:text_rect()
	if not desc or desc == "" then
		dh = 0
	end
	dt:set_h( dh )
	self.desc_panel = dt
	hy = hy + dh + ( dh > 0 and 4 or 0 )

	-- Feedback line (Menu:set_description / ppu_feedback)
	local mt = hp:text( { name = "msg", text = "", font = FONT_S, font_size = 17, color = T.acc,
		x = PAD, y = hy, w = w - PAD * 2, h = 20, wrap = true, word_wrap = true, layer = 3, blend_mode = "normal" } )
	self.msg_text = mt
	hy = hy + 20 + 6

	hp:set_h( hy )
	hp:rect( { name = "header_line", x = 0, y = hy - 1, w = w, h = 1, color = T.line, layer = 1 } )
	return y + hy
end

function Menu:add_buttons( y )
	local T = self.T
	local main = self.main
	local w = self.win_w
	local button_list = self._data.button_list

	local buttons_panel = main:panel( { name = "buttons_panel", x = 0, y = y + 6, w = w, h = 10, layer = 1 } )
	self.buttons_panel = buttons_panel
	local ws = self._ws

	if not button_list or #button_list == 0 then
		local et = make_text( buttons_panel, { name = "empty", text = "Nothing here", font = FONT_M, font_size = 19, color = T.muted, x = PAD, y = 6 } )
		buttons_panel:set_h( 34 )
		return y + 6 + 34 + 6
	end

	local client = is_client()
	local plug_path = self._data.plugin_path
	local ry = 0
	self.spacers = {}
	for i, button in ipairs( button_list ) do
		local have_plugin = button.plugin
		local selected_path = button.plugin_path or plug_path
		local locked = false

		if button.host_only and client then
			self:host_only_button( button )
			locked = true
		end

		local is_spacer = button.text == nil and not button.type and not button.callback and not have_plugin
		local rh = is_spacer and SPACER_H or ( button.type == "slider" and SLIDER_H or ROW_H )
		local row = buttons_panel:panel( { name = "button_text_" .. i, x = 0, y = ry, w = w, h = rh } )
		self.spacers[ i ] = is_spacer
		ry = ry + rh

		if is_spacer then
			row:rect( { name = "spacer_line", x = PAD, y = math_floor( rh / 2 ), w = w - PAD * 2, h = 1, color = T.line, layer = 1 } )
		else
			-- highlight (hidden until hovered)
			row:rect( { name = "selected", color = T.accsoft, visible = false, layer = 1 } )
			row:rect( { name = "selected_bar", x = 0, y = 0, w = 3, h = rh, color = T.acc, visible = false, layer = 2 } )

			local text_y = button.type == "slider" and 6 or nil
			local label = make_text( row, { name = "text", text = button.text or "", font = FONT_M, font_size = 19,
				color = locked and T.muted or T.text, x = PAD, y = text_y or 0 } )
			if not text_y then
				label:set_center_y( rh / 2 )
			end

			if have_plugin or button.type == "toggle" then
				button.tickbox = Tickbox:new( row, button, selected_path )
			end

			if button.type == "multi_choice" then
				button.multi_choice = MultiChoice:new( row, button )
			end

			if button.type == "slider" then
				button.slider = Slider:new( row, button )
			elseif button.type == "input" then
				button.input = TextInput:new( row, button, ws )
			end

			if button.type == "save_button" then
				button.save_button = SaveButton:new( row, button )
			end

			if button.menu or button.box then
				row:bitmap( { name = "chevron", texture = ARROW_TEX, texture_rect = { 0, 0, 24, 24 }, w = 16, h = 16, rotation = 180,
					x = w - PAD - 16, y = ( rh - 16 ) / 2, color = T.muted, layer = 3 } )
			end
		end
	end

	buttons_panel:set_h( ry )
	return y + 6 + ry + 6
end

function Menu:_foot_button( panel, name, text, x, primary )
	local T = self.T
	local bp = panel:panel( { name = name, x = x, y = 9, w = 60, h = 28 } )
	local t, tw = make_text( bp, { name = "text", text = text, font = FONT_S, font_size = 17, color = T.text, y = 5 } )
	bp:set_w( tw + 22 )
	t:set_center_x( bp:w() / 2 )
	outline( bp, T.line2, 1 )
	bp:rect( { name = "hover_bg", color = T.accsoft, visible = false, layer = 0 } )
	return bp
end

function Menu:add_navigation( y )
	local T = self.T
	local main = self.main
	local w = self.win_w
	local data = self._data

	local np = main:panel( { name = "navigation_panel", x = 0, y = y, w = w, h = FOOT_H, layer = 1 } )
	self.navigation_panel = np
	main:rect( { name = "foot_line", x = 0, y = y, w = w, h = 1, color = T.line, layer = 1 } )

	local x = PAD
	if data.back then
		local b = self:_foot_button( np, "previous_page", data.back_is_page and tr['prev_page'] or "< Back", x )
		x = b:right() + 8
	end
	self:_foot_button( np, "close_button", tr['exit'], x )

	if data.next then
		local nb = self:_foot_button( np, "next_page", tr['next_page'] .. " >", 0 )
		nb:set_right( w - PAD )
	else
		make_text( np, { name = "hint", text = "Esc  Close", font = FONT_S, font_size = 14, color = T.muted, y = 16, x = 0 } )
		local h = np:child( "hint" )
		h:set_right( w - PAD )
	end

	return y + FOOT_H
end

function Menu:host_only_button( button )
	button.text = tr['host_only'] .. button.text
	button.callback = void
	button.plugin = nil
end

-- Set up menu

function Menu:setup_mouse()
	self._mouse_id = M_mouse_pointer:get_id()
	local data = {}
	data.id = self._mouse_id
	M_mouse_pointer:use_mouse( data )
end

function Menu:add_controller()
	self.controller = M_controller:get_controller_by_name( "Menu" ) or M_controller:create_controller( "Menu", M_controller:get_default_wrapper_index(), false )
	self.controller:enable()

	self._cancel_func = callback( self, self, "close" )
	self._confirm_func = callback( self, self, "enter_button_pressed" )

	self.controller:add_trigger( "cancel", self._cancel_func )
	self.controller:add_trigger( "confirm", self._confirm_func )
end

local GenSysMenuManager = SystemMenuManager.GenericSystemMenuManager
local o__is_active = GenSysMenuManager.o__is_active
if ( not o__is_active ) then
	o__is_active = GenSysMenuManager.is_active
	GenSysMenuManager.o__is_active = o__is_active
end

function Menu:disable_controllers( state )
	if state then
		GenSysMenuManager.is_active = function()
			return true
		end
	elseif not state then
		GenSysMenuManager.is_active = o__is_active
	end
end

function Menu:update()
	if self:mouse_update() then
		M_mouse_pointer:set_pointer_image( "link" )
	else
		M_mouse_pointer:set_pointer_image( "arrow" )
	end
end

function Menu:mouse_update()
	local x, y = ppr_menu_mouse_pos()

	local is_left_click		=	mouse_pressed( mouse, left_click )
	local is_right_click	=	not is_left_click and mouse_pressed( mouse, right_click )

	if self:_tabs_moved( x, y, is_left_click ) then
		return true
	end
	if self:_navigation_button_moved( x, y, is_left_click ) then
		return true
	end
	if self:_button_moved( x, y, is_left_click, is_right_click ) then
		return true
	end
end

function Menu:_tabs_moved( x, y, clicked )
	local bar = self.tabs_panel
	if not bar or not bar:inside( x, y ) then
		self:_hover_tab( nil )
		return
	end
	local T = self.T

	if self.tab_overflow then
		if wheel( wheel_up ) then
			self:set_tab_offset( ( PPU_tab_offset or 0 ) - 80 )
		elseif wheel( wheel_down ) then
			self:set_tab_offset( ( PPU_tab_offset or 0 ) + 80 )
		end
		for _, side in ipairs( { "left", "right" } ) do
			local ap = bar:child( "tab_" .. side )
			if ap and ap:visible() and ap:inside( x, y ) then
				if clicked then
					local step = math_max( 120, self.win_w * 0.6 )
					self:set_tab_offset( ( PPU_tab_offset or 0 ) + ( side == "left" and -step or step ) )
				end
				return true
			end
		end
	end

	for _, tp in ipairs( self.tab_inner:children() ) do
		local t = tp.child and self.tab_map[ tp:name() ]
		if t and tp:visible() and tp:inside( x, y ) then
			self:_hover_tab( tp )
			if clicked then
				local v = rawget( _G, "KeyInput" ) and KeyInput.keys[ t[1] ]
				if v and v.callback then
					PPU_current_tab = t[1]
					safecall( v.callback )
				end
			end
			return true
		end
	end
	self:_hover_tab( nil )
end

function Menu:_hover_tab( tp )
	if self._hover_tab_panel == tp then
		return
	end
	local T = self.T
	local prev = self._hover_tab_panel
	local pt = prev and self.tab_map and self.tab_map[ prev:name() ]
	if pt and PPU_current_tab ~= pt[1] and alive( prev ) then
		prev:child( "key" ):set_color( T.muted )
		prev:child( "label" ):set_color( T.muted )
	end
	if tp then
		tp:child( "key" ):set_color( T.text )
		tp:child( "label" ):set_color( T.text )
	end
	self._hover_tab_panel = tp
end

function Menu:_navigation_button_moved( x, y, clicked )
	local T = self.T
	local hit
	for i, panel in ipairs( self.navigation_panel:children() ) do
		if panel.child and panel:child( "hover_bg" ) then
			local inside = panel:inside( x, y )
			panel:child( "hover_bg" ):set_visible( inside )
			set_outline_color( panel, inside and T.acc or T.line2 )
			if inside then
				if clicked then
					self:navigation_button_pressed( panel:name() )
				end
				hit = true
			end
		end
	end
	return hit
end

function Menu:_button_moved( x, y, clicked, alt_clicked )
	for i, panel in ipairs( self.buttons_panel:children() ) do
		if panel.child and not self.spacers[ i ] and panel:name() == "button_text_" .. i and panel:inside( x, y ) then
			self._focus_button = i
			self:enable_highlight_button()

			if clicked or alt_clicked then
				self:button_pressed(i,  alt_clicked)
			end
			return true
		end
	end
end

function Menu:_set_row_highlight( index, state )
	local row = self.buttons_panel:child( "button_text_" .. index )
	if row and row.child then
		local rect = row:child( "selected" )
		if rect then
			rect:set_visible( state )
		end
		local bar = row:child( "selected_bar" )
		if bar then
			bar:set_visible( state )
		end
	end
end

function Menu:enable_highlight_button()
	local prev_focus_button = self._prev_focus_button
	if prev_focus_button and prev_focus_button ~= self._focus_button then
		self:disable_highlight_button()
	end
	self:_set_row_highlight( self._focus_button, true )
	self._prev_focus_button = self._focus_button
end

function Menu:disable_highlight_button()
	if self._prev_focus_button then
		self:_set_row_highlight( self._prev_focus_button, false )
	end
end

function Menu:navigation_button_pressed( button_name )
	if button_name == "close_button" then
		self:close()
	elseif button_name == "previous_page" then
		self._data.back()
	elseif button_name == "next_page" then
		self._data.next()
	end
end

function Menu:enter_button_pressed()
	if self._focus_button then
		self:button_pressed( self._focus_button )
	end
end

function Menu:button_pressed( button_index, alt )
	local button = self._data.button_list[ button_index ]

	if not button then
		return
	end

	if alt then --Right click, use alternative callback
		local clbk = button.alt_callback
		if clbk then
			local data = button.data
			if type(data) == 'table' then
				safecall( clbk, unpack( data ) )
			else
				safecall( clbk, data )
			end
			local switch_back = button.switch_back_alt
			if not switch_back then
				self:close()
			elseif type( switch_back ) == "function" then
				switch_back()
			end
		end
		return --And stop here
	end

	-- Undying: Save keeps the menu open and can be pressed again (it used to close the menu
	-- and clear its own callback, so values looked like they weren't saved)
	local is_save = button.type == "save_button"
	if is_save then
		button.save_button:save()
	end

	local have_plugin = button.plugin
	local custom_path = button.plugin_path
	local load_plugin = custom_path and __load_plugin( custom_path ) or self.load_plugin
	if have_plugin and load_plugin then
		load_plugin( have_plugin )
	end

	local btn_callback = not is_save and button.callback
	if btn_callback then
		local data = button.data
		if type(data) == 'table' then
			safecall( btn_callback, unpack( data ) )
		else
			safecall( btn_callback, data )
		end
	end

	local switch_back = button.switch_back
	if switch_back and ( button.type == "toggle" or have_plugin ) then
		button.tickbox:toggle()
	end

	if not switch_back then
		--Very dirty fix
		if button.type ~= 'input' and not is_save then
			self:close()
		end
	elseif type( switch_back ) == "function" then
		switch_back()
	end
end

function Menu:close()
	if not self._ws then
		return
	end

	M_mouse_pointer:remove_mouse( self._mouse_id )
	self.controller:remove_trigger( "cancel", self._cancel_func )
	self.controller:remove_trigger( "confirm", self._confirm_func )
	self.controller:disable()
	executewithdelay( { func = self.disable_controllers, params = {self} }, 0.23, 'disable_cont_clbk' )

	self:stop_loops()
	self._ws:panel():remove( self.main )
	OverlayGui:destroy_workspace( self._ws )
	self._ws = nil
	tweak_data.menu_active = nil
	for id,clbk in pairs(self.close_clbks) do
		clbk()
	end
end

-- Round 3: live feedback inside the open menu. HUD hints don't exist in the main menu,
-- so actions there looked like they did nothing. Redesign: shown on its own line under the description.
function Menu:set_description( text )
	local m = self.msg_text
	if m and self._ws then
		m:set_text( text or "" )
	end
end

function Menu:set_button_text( button, text )
	for i, b in ipairs( self._data.button_list or {} ) do
		if b == button then
			b.text = text
			local panel = self.buttons_panel and self.buttons_panel:child( "button_text_" .. i )
			local t = panel and panel.child and panel:child( "text" )
			if t then
				t:set_text( text )
				local _,_,w,h = t:text_rect()
				t:set_size( math.max( w, t:w() ), h )
			end
			return
		end
	end
end

function ppu_feedback( msg )
	local m = tweak_data.menu_active
	if m and m.set_description then
		m:set_description( msg )
	end
	if managers.hud and show_hint then
		show_hint( msg )
	end
end

function Menu:stop_loops()
	StopLoopIdent("menu_update")

	for _, button in pairs( self._data.button_list ) do
		local slider = button.slider
		if slider then
			slider:close()
		else
			local multi_choice = button.multi_choice
			if multi_choice then
				multi_choice:close()
			else
				local input = button.input
				if input then
					input:close()
				end
			end
		end
	end
end

local G = getfenv(0)
G.Menu = Menu
return Menu
