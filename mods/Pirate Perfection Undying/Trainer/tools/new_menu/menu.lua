-- Menu class by Simplity
-- Undying menu redesign (2026-09-26): drawn to BearThatRun's design PPU_Menu_Redesign.html,
-- using the design's own sizes: 420 px window (resizable), tab bar, header with key badge,
-- breadcrumbs, title, description, message line and search, 36 px rows, pill switches,
-- < value > choices, sliders with Apply, footer with Back / Exit and key hints.
-- Text is Barlow Semi Condensed drawn from glyph textures (see ppu_draw.lua).
-- Keyboard: Up/Down move, Enter select, Left/Right change (Shift x10 on sliders),
-- Backspace back, Esc close, / search. Mouse wheel scrolls the list and the tab bar.
-- Menu files don't change: same button_list format, Menu.open / Menu:new as before.

local pairs = pairs
local ipairs = ipairs
local ppr_require = ppr_require
local type = type
local tostring = tostring
local safecall = safecall
local unpack = unpack
local table = table
local tab_insert = table.insert
local math_max = math.max
local math_min = math.min
local math_floor = math.floor
local math_abs = math.abs

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
-- Theme (design defaults = PAYDAY 2 blue). Saved colours come from ppr_config.PPU_Theme.
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

-- Order and names from the design's Theme page
PPU_THEME_ROLES = {
	{ "bg", "Window background" }, { "surf", "Row highlight" }, { "text", "Text" },
	{ "muted", "Secondary text" }, { "acc", "Accent" }, { "warn", "Warning" },
}

-- Saved in the active config as one string, because the config writer (configmt.lua) can
-- only write strings, numbers and booleans: cfg.PPU_Theme = "7,9,12;22,38,54;..."
local function theme_parse( s )
	if type( s ) ~= "string" then return nil end
	local out, i = {}, 0
	for grp in s:gmatch( "[^;]+" ) do
		i = i + 1
		local r, g, b = grp:match( "^%s*(%d+)%s*,%s*(%d+)%s*,%s*(%d+)%s*$" )
		local role = PPU_THEME_ROLES[ i ]
		if not ( r and role ) then return nil end
		out[ role[1] ] = { math.min( 255, tonumber( r ) ), math.min( 255, tonumber( g ) ), math.min( 255, tonumber( b ) ) }
	end
	return i == #PPU_THEME_ROLES and out or nil
end

local function theme_string( t )
	local parts = {}
	for i, role in ipairs( PPU_THEME_ROLES ) do
		local c = t[ role[1] ]
		parts[ i ] = c[1] .. "," .. c[2] .. "," .. c[3]
	end
	return table.concat( parts, ";" )
end

local function game_cfg()
	return rawget( _G, "game_config" )
end

-- Current colours (copy): saved theme of the active config, else the defaults
function ppu_theme_raw()
	local saved
	pcall( function()
		local gc = game_cfg()
		saved = theme_parse( gc and rawget( gc, "PPU_Theme" ) )
		if not saved then
			-- rawget: ppr_config warns in the log for every missing key
			local old = ppr_config and rawget( ppr_config, "PPU_Theme" )
			if type( old ) == "table" then saved = old end
		end
	end )
	local src = {}
	for _, role in ipairs( PPU_THEME_ROLES ) do
		local k = role[1]
		local s = saved and saved[ k ]
		local v = ( type( s ) == "table" and #s == 3 ) and s or PPU_THEME_DEFAULT[ k ]
		src[ k ] = { v[1], v[2], v[3] }
	end
	return src
end

function ppu_theme()
	local src = ppu_theme_raw()
	local T = { raw = src }
	for k, v in pairs( src ) do
		T[k] = rgb( v )
	end
	T.line = rgb( src.text, 0.10 )
	T.line2 = rgb( src.text, 0.22 )
	T.accsoft = rgb( src.acc, 0.16 )
	T.warnsoft = rgb( src.warn, 0.16 )
	T.tabbar = Color.black:with_alpha( 0.28 )
	T.placeholder = rgb( src.muted, 0.8 )
	return T
end

-- Change one channel (1-3) of one colour; the open menu redraws in the new colours
function ppu_theme_set( role, ch, v )
	local t = ppu_theme_raw()
	if not t[ role ] then return end
	t[ role ][ ch ] = math.max( 0, math.min( 255, math.floor( v + 0.5 ) ) )
	local gc = game_cfg()
	if gc then
		rawset( gc, "PPU_Theme", theme_string( t ) )
	end
	local m = tweak_data.menu_active
	if m and m.apply_theme then m:apply_theme() end
end

function ppu_theme_reset()
	local gc = game_cfg()
	if gc then
		rawset( gc, "PPU_Theme", nil )
	end
	ppu_theme_save()
	local m = tweak_data.menu_active
	if m and m.apply_theme then m:apply_theme() end
end

-- Write only the PPU_Theme line into the active config file (the rest of the file is kept)
function ppu_theme_save()
	local gc = game_cfg()
	local path = gc and rawget( gc, "auto_config" )
	if type( path ) ~= "string" then return false end
	local ok, err = pcall( function()
		local f = ppr_io.open( path, "r" )
		if not f then return end
		local src = f:read( "*a" )
		f:close()
		local body = src:gsub( "\r?\n[ \t]*cfg%.PPU_Theme[ \t]*=[^\n]*", "" )
		local value = rawget( gc, "PPU_Theme" )
		if value then
			local head, tail = body:match( "^(.*)(\r?\nend%s*)$" )
			if not head then return end -- not the usual "return function( cfg ) ... end" file: leave it alone
			body = head .. "\n\tcfg.PPU_Theme = " .. string.format( "%q", value ) .. tail
		end
		if body == src then return end
		if not loadstring( body ) then return end -- never write a config that wouldn't load
		local w = ppr_io.open( path, "w" )
		if w then
			w:write( body )
			w:close()
		end
	end )
	return ok
end

---------------------------------------------------------------------------------------------
-- Sizes from the design (CSS px = layout px of the 1280x720 workspace)
---------------------------------------------------------------------------------------------
local WIN_W = 420       -- window width (design default), resizable 340..1000
local ROW_H = 36        -- --rowh
local PAD = 16
local LIST_MAX = 520    -- list max-height
local TAB_H = 44        -- 7 + 13 + 1 + 16 + 5 + 2
local ARROW_W = 34
local HOST_TIP = "Host only. You're a client in this lobby, so this does nothing."

---------------------------------------------------------------------------------------------
-- Tabs: the same callbacks the F-keys run (KeyInput.keys[key].callback)
---------------------------------------------------------------------------------------------
local TABS_MENU = {
	{ "f1", "F1", "Help" }, { "f2", "F2", "Config" }, { "f3", "F3", "Pre-game" }, { "f4", "F4", "Job" },
	{ "page up", "PgUp", "Tools" }, { "page down", "PgDn", "Music" }, { "home", "Home", "Normalizer" },
}
local TABS_HEIST = {
	{ "f1", "F1", "Help" }, { "f2", "F2", "Config" }, { "f3", "F3", "Character" }, { "f4", "F4", "Stealth" },
	{ "f5", "F5", "Troll" }, { "f6", "F6", "Interaction" }, { "f7", "F7", "Inventory" }, { "f8", "F8", "Equipment" },
	{ "f10", "F10", "Mission" }, { "f11", "F11", "Mod" }, { "f12", "F12", "Spawn" },
	{ "page up", "PgUp", "Tools" }, { "page down", "PgDn", "Music" }, { "home", "Home", "Normalizer" },
}
local BOTH_CTX = { f1 = true, ["page up"] = true, ["page down"] = true, home = true }

local function in_heist()
	return rawget( _G, "GameSetup" ) and true or false
end

local function current_tabs()
	local list = in_heist() and TABS_HEIST or TABS_MENU
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

-- Remember which key opened the menu (tab highlight + key badge) and start a new breadcrumb path.
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
					PPU_nav_mode = "reset"
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

ppr_require 'Trainer/tools/new_menu/ppu_draw'
ppr_require 'Trainer/tools/new_menu/tickbox'
ppr_require 'Trainer/tools/new_menu/slider'
ppr_require 'Trainer/tools/new_menu/multi_choice'
ppr_require 'Trainer/tools/new_menu/text_input'
ppr_require 'Trainer/tools/new_menu/save_button'
ppr_require 'Trainer/experimental/dev/pluginmanager'

local D = PPUDraw
local Tickbox = Tickbox
local MultiChoice = MultiChoice
local Slider = Slider
local TextInput = TextInput
local SaveButton = SaveButton

local mouse = Input:mouse()
local keyboard = Input:keyboard()
local mouse_pressed = mouse.pressed
local mouse_down = mouse.down
local kb_pressed = keyboard.pressed
local kb_down = keyboard.down
local Idstring = Idstring
local left_click = Idstring('0')
local right_click = Idstring('1')
local WHEEL_UP = Idstring('mouse wheel up')
local WHEEL_DOWN = Idstring('mouse wheel down')
local K_UP, K_DOWN, K_LEFT, K_RIGHT = Idstring("up"), Idstring("down"), Idstring("left"), Idstring("right")
local K_ENTER, K_BACK = Idstring("enter"), Idstring("backspace")
local K_LSHIFT, K_RSHIFT = Idstring("left shift"), Idstring("right shift")
local K_LCTRL, K_RCTRL = Idstring("left ctrl"), Idstring("right ctrl")
local K_ZERO = Idstring("0")
-- "/" has no key name used in the game's code; try likely names once, keep the ones accepted
local K_SLASH = {}
for _, n in ipairs( { "/", "num /" } ) do
	local id = Idstring( n )
	if pcall( kb_pressed, keyboard, id ) then
		K_SLASH[ #K_SLASH + 1 ] = id
	end
end

local clone = clone
local managers = managers
local M_mouse_pointer = managers.mouse_pointer
local M_controller = managers.controller

local tweak_data = tweak_data
local T_gui = tweak_data.gui
local callback = callback
local __load_plugin = load_plugin
local OverlayGui = Overlay:gui()
local RunNewLoopIdent = RunNewLoopIdent
local StopLoopIdent = StopLoopIdent
local executewithdelay = executewithdelay
local plugins = plugins
local is_client = is_client

local function now()
	local ok, t = pcall( function() return Application:time() end )
	if ok and t then
		return t
	end
	return os and os.clock and os.clock() or 0
end

local function fmt_num( n )
	local s = tostring( n )
	local neg, int, rest = s:match( "^(-?)(%d+)(.*)$" )
	if not int then
		return s
	end
	int = int:reverse():gsub( "(%d%d%d)", "%1," ):reverse():gsub( "^,", "" )
	return neg .. int .. rest
end

---------------------------------------------------------------------------------------------
-- Window state that survives restarts: UI scale, position (screen pixels), width, list height.
-- Kept in its own small file so no user config is touched.
---------------------------------------------------------------------------------------------
local UI_FILE = "Trainer/configs/menu_ui.lua"
local UI_MIN_SCALE, UI_MAX_SCALE = 0.75, 2

local function load_ui_state()
	if PPU_ui then return PPU_ui end
	PPU_ui = { scale = 1 }
	pcall( function()
		local f = ppr_io.open( UI_FILE, "r" )
		if not f then return end
		local src = f:read( "*a" )
		f:close()
		local fn = loadstring( src )
		local ok, t = pcall( fn )
		if ok and type( t ) == "table" then
			for k, v in pairs( t ) do
				if type( v ) == "number" then PPU_ui[ k ] = v end
			end
		end
	end )
	PPU_ui.scale = math_max( UI_MIN_SCALE, math_min( PPU_ui.scale or 1, UI_MAX_SCALE ) )
	PPU_win_w = PPU_win_w or PPU_ui.w
	PPU_list_h = PPU_list_h or PPU_ui.list_h
	return PPU_ui
end

local function save_ui_state()
	local u = PPU_ui
	if not u then return end
	u.w, u.list_h = PPU_win_w, PPU_list_h
	pcall( function()
		local f = ppr_io.open( UI_FILE, "w" )
		if not f then return end
		local parts = {}
		for _, k in ipairs( { "scale", "x", "y", "w", "list_h" } ) do
			if u[ k ] then
				parts[ #parts + 1 ] = string.format( "\t%s = %s,", k, tostring( u[ k ] ) )
			end
		end
		f:write( "-- Pirate Perfection Undying menu window: size (UI px), position (screen px), scale.\n-- Written by the menu; delete this file to reset.\nreturn {\n" .. table.concat( parts, "\n" ) .. "\n}\n" )
		f:close()
	end )
end

local Menu = class()

---------------------------------------------------------------------------------------------
-- Open / init
---------------------------------------------------------------------------------------------

function Menu:init( data )
	local active_menu = tweak_data.menu_active
	if active_menu then
		active_menu:close( true )
	end

	ensure_key_hooks()
	self.T = ppu_theme()
	_G.PPU_T = self.T

	self._data = data
	-- a fresh open forgets values that were moved but not applied last time
	for _, b in ipairs( data.button_list or {} ) do
		if type( b ) == "table" then
			b._ppu_val, b._ppu_applied, b._ppu_index, b._ppu_text = nil, nil, nil, nil
		end
	end
	self:update_nav_stack()

	local ws = OverlayGui:create_screen_workspace()
	self._ws = ws
	load_ui_state()
	self:layout_ws()
	tweak_data.menu_active = self
	self.close_clbks = {}
	-- persistent object that receives typed text (the rest is redrawn often)
	self.kb_panel = ws:panel():panel( { name = "ppu_kb", w = 1, h = 1, visible = false } )

	self.W = math_max( 340, math_min( PPU_win_w or WIN_W, 1000 ) )
	self.q = ""
	self.fi = 1
	self.scroll = 0
	self.scroll_target = 0
	self.tab_off = nil
	self.msg = ""
	self.tweens = {}
	self.keyrep = {}

	self:build()
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

-- Breadcrumb path (design: stack of opened menus). Row presses push, Back / crumbs pop,
-- F-keys and tabs start a new path.
-- One UI pixel = ui_scale screen pixels (1 = the design's size on screen, like a browser at 100%).
-- The game's own menus use a 1280x720 layout stretched to the screen (1.5x at 1080p).
function Menu:layout_ws()
	local ws = self._ws
	local s = PPU_ui.scale
	local ok = pcall( function()
		local res = RenderSettings.resolution
		ws:set_screen( res.x / s, res.y / s, 0, 0, res.x )
		self.res = { x = res.x, y = res.y }
	end )
	if not ok then
		managers.gui_data:layout_1280_workspace( ws )
		self.res = nil
		s = 2
	end
	self.ui_scale = s
	D.set_scale( s )
end

-- Mouse position in this workspace. The pointer lives in the game's fullscreen workspace.
function Menu:mouse_pos()
	local mp = managers.mouse_pointer
	local x, y = mp._mouse:world_position()
	if self.res then
		local full = managers.gui_data:full_scaled_size()
		local k = self.res.x / full.w / self.ui_scale
		return x * k, y * k
	end
	return ppr_menu_mouse_pos()
end

-- Ctrl + mouse wheel over the window: make the whole menu smaller / bigger (0.75x - 2x)
function Menu:change_scale( d )
	local old = PPU_ui.scale
	local new = math_floor( ( old + d ) * 20 + 0.5 ) / 20
	new = math_max( UI_MIN_SCALE, math_min( new, UI_MAX_SCALE ) )
	if new == old then return end
	-- keep the window's top-left corner where it is on screen
	local px = PPU_ui.x or ( self.win_x or 0 ) * old
	local py = PPU_ui.y or ( self.win_y or 0 ) * old
	PPU_ui.x, PPU_ui.y = math_floor( px + 0.5 ), math_floor( py + 0.5 )
	PPU_ui.scale = new
	self:layout_ws()
	self.win_x, self.win_y = math_floor( px / new ), math_floor( py / new )
	self:build()
	self:set_description( "Menu size " .. math_floor( new * 100 + 0.5 ) .. "%  (Ctrl + mouse wheel, Ctrl + 0 resets)" )
	save_ui_state()
end

function Menu:remember_position()
	PPU_ui.x = math_floor( ( self.win_x or 0 ) * self.ui_scale + 0.5 )
	PPU_ui.y = math_floor( ( self.win_y or 0 ) * self.ui_scale + 0.5 )
	save_ui_state()
end

function Menu:update_nav_stack()
	local data = self._data
	local title = tostring( data.title or "" )
	local mode = PPU_nav_mode
	PPU_nav_mode = nil
	local stack = PPU_nav_stack or {}
	local function find( t )
		for j = #stack, 1, -1 do
			if stack[ j ].title == t then
				return j
			end
		end
	end
	if mode == "reset" then
		stack = {}
	elseif mode == "back" then
		local j = find( title )
		if j then
			for k = #stack, j, -1 do stack[ k ] = nil end
		else
			stack = {}
		end
	elseif mode == "push" then
		if stack[ #stack ] and stack[ #stack ].title == title then
			stack[ #stack ] = nil
		end
	else
		local j = find( title )
		if j then
			for k = #stack, j, -1 do stack[ k ] = nil end
		end
	end
	stack[ #stack + 1 ] = { title = title, data = data._src or data }
	PPU_nav_stack = stack
	self.stack = stack
end

local preload_plugin = plugins.pre_require

function Menu.open( _, data, n ) -- n (page start) is no longer used: the list scrolls
	local menu_data = clone( data )
	local list = {}
	local plug_path = data.plugin_path
	for _, button in ipairs( data.button_list or {} ) do
		--This will validate if some plugin exists on harddrive. If not, button will not be added.
		--Also it preloads plugins
		local have_plugin = button.plugin
		local selected_path = button.plugin_path or plug_path
		if ( not have_plugin or not selected_path or preload_plugin( plugins, selected_path..have_plugin ) ) then
			tab_insert( list, button )
		end
	end
	menu_data.button_list = list
	menu_data._src = data
	menu_data.next = nil
	return Menu:new( menu_data )
end

---------------------------------------------------------------------------------------------
-- Row model
---------------------------------------------------------------------------------------------

local function is_spacer( b )
	return b.text == nil and not b.type and not b.callback and not b.plugin and not b.menu and not b.box
end

-- kind: sp, tog, sld, cho, inp, sub, save, act
local function row_kind( b )
	if is_spacer( b ) then return "sp" end
	if b.type == "rgb" then return "rgb" end
	if b.type == "slider" then return "sld" end
	if b.type == "multi_choice" then return "cho" end
	if b.type == "input" then return "inp" end
	if b.type == "toggle" or b.plugin then return "tog" end
	if b.type == "save_button" then return "save" end
	if b.menu or b.box then return "sub" end
	return "act"
end

local function label_of( b )
	return tostring( b.text or b.name or "" )
end

function Menu:visible_buttons()
	local out = {}
	local q = self.q:lower()
	for i, b in ipairs( self._data.button_list or {} ) do
		local kind = row_kind( b )
		if q == "" or ( kind ~= "sp" and label_of( b ):lower():find( q, 1, true ) ) then
			out[ #out + 1 ] = { index = i, button = b, kind = kind }
		end
	end
	return out
end

---------------------------------------------------------------------------------------------
-- Build (the whole window is redrawn when its layout changes)
---------------------------------------------------------------------------------------------

-- True when the window was closed or redrawn since `gen` was taken. The game crashes (not a Lua
-- error) when a removed GUI object is touched, so code that runs a row's callback must check this
-- before touching any of the old objects again.
function Menu:stale( gen )
	return not self._ws or self._gen ~= gen
end

function Menu:destroy_gui()
	self._gen = ( self._gen or 0 ) + 1
	for _, r in ipairs( self.rows or {} ) do
		local w = r.input
		if w then
			w.on_focus = nil
			w.on_change = nil
			w:close()
		end
	end
	if self.search_input then
		self.search_input.on_focus = nil
		self.search_input.on_change = nil
		self.search_input:close()
		self.search_input = nil
	end
	self.tweens = {}
	local root = self._ws and self._ws:panel()
	if root then
		if self.main then root:remove( self.main ) end
		if self.shadow then root:remove( self.shadow ) end
	end
	self.main, self.shadow = nil, nil
end

function Menu:build()
	local T = self.T
	local was_input = TextInput.active and TextInput.active.button
	local was_search = self.search_focused
	self:destroy_gui()

	local root = self._ws:panel()
	local W = self.W
	self.client = is_client()
	D.check()

	local main = root:panel( { name = "ppu_window", x = 0, y = 0, w = W + 2, h = 100, layer = T_gui.DIALOG_LAYER } )
	self.main = main
	local content = main:panel( { name = "content", x = 1, y = 1, w = W, h = 100, layer = 1 } )
	self.content = content

	local y = 0
	y = self:add_tabs( y )
	y = self:add_header( y )
	y = self:add_list( y )
	y = self:add_navigation( y )

	-- keep the whole window on screen (the list gets shorter if needed)
	local over = ( y + 2 ) - ( root:h() - 20 )
	if over > 0 and not self.list_h_limit and self.list_h - over >= 60 then
		self.list_h_limit = self.list_h - over
		self:build()
		self.list_h_limit = nil
		return
	end

	local H = y
	content:set_h( H )
	main:set_h( H + 2 )
	D.box( main, { name = "win_bg", x = 0, y = 0, w = W + 2, h = H + 2, r = 4, color = T.bg, layer = 0 } )
	D.border( main, { name = "win_border", x = 0, y = 0, w = W + 2, h = H + 2, r = 4, color = T.line, layer = 50 } )
	self:add_resize_handles( main, W, H )

	-- position: centred on first open, then kept (resizing grows right/down like the design)
	if not self.win_x then
		if PPU_ui.x and PPU_ui.y then
			-- same place as last time (saved in screen pixels)
			self.win_x = math_floor( PPU_ui.x / self.ui_scale )
			self.win_y = math_floor( PPU_ui.y / self.ui_scale )
		else
			self.win_x = math_floor( ( root:w() - ( W + 2 ) ) / 2 )
			self.win_y = math_floor( ( root:h() - ( H + 2 ) ) / 2 )
		end
	end
	self.win_x = math_max( 0, math_min( self.win_x, root:w() - ( W + 2 ) ) )
	self.win_y = math_max( 0, math_min( self.win_y, root:h() - ( H + 2 ) ) )
	main:set_x( self.win_x )
	main:set_y( self.win_y )
	self.shadow = D.shadow( root, self.win_x, self.win_y, W + 2, H + 2, T_gui.DIALOG_LAYER - 1 )

	-- give text focus back after a redraw
	if was_search and self.search_input then
		self.search_input:activate_input()
	elseif was_input then
		for _, r in ipairs( self.rows ) do
			if r.button == was_input and r.input then
				r.input:activate_input()
			end
		end
	end
	self:refresh_focus()
	if self._scroll_to_focus then
		self._scroll_to_focus = nil
		self:scroll_to_focus()
	end
end

-- Tab bar -----------------------------------------------------------------------------------

function Menu:add_tabs( y )
	local T = self.T
	local content = self.content
	local W = self.W
	local tabs = current_tabs()
	self.tabs = tabs
	self.tab_panels = {}
	self.tab_arrows = nil
	if #tabs == 0 then
		self.tabs_panel = nil
		self.tab_inner = nil
		return y
	end

	local bar = content:panel( { name = "tabs_panel", x = 0, y = y, w = W, h = TAB_H + 1, layer = 2 } )
	self.tabs_panel = bar
	bar:rect( { name = "tabs_bg", color = T.tabbar, layer = 0 } )
	bar:rect( { name = "tabs_line", x = 0, y = TAB_H, w = W, h = 1, color = T.line, layer = 3 } )

	local strip = bar:panel( { name = "tab_strip", x = 0, y = 0, w = W, h = TAB_H, layer = 1 } )
	self.tab_strip = strip
	local inner = strip:panel( { name = "tab_inner", x = 0, y = 0, w = 10, h = TAB_H } )
	self.tab_inner = inner

	local x = 0
	local active
	for i, t in ipairs( tabs ) do
		local on = PPU_current_tab == t[1]
		local kw = D.measure( "b11", t[2], 0.04 )
		local nw = D.measure( "r13", t[3] )
		local tw = math_max( kw, nw ) + 20
		local tp = inner:panel( { name = "tab_" .. i, x = x, y = 0, w = tw, h = TAB_H } )
		if on then
			tp:rect( { name = "tab_bg", color = T.accsoft, layer = 0 } )
			tp:rect( { name = "tab_line", x = 0, y = TAB_H - 2, w = tw, h = 2, color = T.acc, layer = 1 } )
			active = { x = x, w = tw }
		end
		local col = on and T.text or T.muted
		local kt = D.text( tp, { name = "key", text = t[2], font = "b11", ls = 0.04, color = col, x = 0, y = 7, w = tw, align = "center" } )
		local nt = D.text( tp, { name = "label", text = t[3], font = "r13", color = col, x = 0, y = 7 + D.lh( "b11" ) + 1, w = tw, align = "center" } )
		self.tab_panels[ i ] = { panel = tp, tab = t, on = on, key = kt, label = nt }
		x = x + tw
	end
	inner:set_w( x )
	self.tab_total = x
	local maxo = math_max( 0, x - W )

	-- first draw: scroll so the active tab is centred (design centerTab)
	if self.tab_off == nil then
		local off = 0
		if active then
			off = active.x - ( W - active.w ) / 2
		end
		self.tab_off = off
		self.tab_target = off
	end
	self.tab_off = math_max( 0, math_min( self.tab_off, maxo ) )
	self.tab_target = math_max( 0, math_min( self.tab_target or self.tab_off, maxo ) )
	inner:set_x( -self.tab_off )

	-- arrows over the ends (gradient fade + ◂ / ▸)
	self.tab_arrows = {}
	for _, side in ipairs( { "l", "r" } ) do
		local ap = bar:panel( { name = "tab_arrow_" .. side, x = side == "l" and 0 or W - ARROW_W, y = 0, w = ARROW_W, h = TAB_H, layer = 5 } )
		D.fade( ap, { x = 0, y = 0, w = ARROW_W, h = TAB_H, color = T.bg, side = side, layer = 0 } )
		local glyph = D.text( ap, { name = "glyph", text = side == "l" and "◂" or "▸", font = "r16", color = T.text, x = 0, y = 0, layer = 1 } )
		glyph:center_line_on( TAB_H / 2 )
		if side == "l" then
			glyph:set_x( 4 )
		else
			glyph:set_right( ARROW_W - 4 )
		end
		self.tab_arrows[ side ] = { panel = ap, glyph = glyph }
	end
	self:update_tab_arrows()
	return y + TAB_H + 1
end

function Menu:update_tab_arrows()
	if not self.tab_arrows then return end
	local off = self.tab_off or 0
	self.tab_arrows.l.panel:set_visible( off > 2 )
	self.tab_arrows.r.panel:set_visible( off + self.W < ( self.tab_total or 0 ) - 2 )
end

function Menu:scroll_tabs( delta )
	local maxo = math_max( 0, ( self.tab_total or 0 ) - self.W )
	self.tab_target = math_max( 0, math_min( ( self.tab_target or self.tab_off or 0 ) + delta, maxo ) )
end

-- Header ------------------------------------------------------------------------------------

function Menu:tab_for_current()
	for _, t in ipairs( self.tabs or {} ) do
		if t[1] == PPU_current_tab then
			return t
		end
	end
end

function Menu:add_header( y )
	local T = self.T
	local content = self.content
	local data = self._data
	local W = self.W
	local IW = W - PAD * 2

	local hp = content:panel( { name = "header_panel", x = 0, y = y, w = W, h = 100, layer = 2 } )
	self.header_panel = hp
	local hy = 14
	local items = 0
	local function gap()
		if items > 0 then hy = hy + 8 end
		items = items + 1
	end

	-- context row: key badge, context or breadcrumbs, "N on"
	gap()
	local row_h = 16
	local cx = PAD
	local tab = self:tab_for_current()
	if tab then
		local bw = D.measure( "b12", tab[2], 0.06, true ) + 12
		D.box( hp, { name = "badge_bg", x = cx, y = hy, w = bw, h = 16, r = 2, color = T.acc, layer = 1 } )
		D.text( hp, { name = "badge", text = tab[2], font = "b12", ls = 0.06, upper = true, color = T.bg, x = cx + 6, y = hy + 1, layer = 2 } )
		cx = cx + bw + 6
	end
	self.crumbs = {}
	if #self.stack < 2 then
		local key = tab and tab[1]
		local ctx = ( key and BOTH_CTX[ key ] ) and "Main menu + heist" or ( in_heist() and "In heist" or "Main menu" )
		D.text( hp, { name = "ctx", text = ctx, font = "r12", ls = 0.06, upper = true, color = T.muted, x = cx, y = hy + 1 } )
	else
		for j, level in ipairs( self.stack ) do
			local last = j == #self.stack
			local t = D.text( hp, { name = "crumb_" .. j, text = level.title, font = "r12", ls = 0.06, upper = true,
				color = last and T.text or T.muted, x = cx, y = hy + 1 } )
			self.crumbs[ j ] = { text = t, last = last }
			cx = cx + t:w() + 6
			if not last then
				local sep = D.text( hp, { name = "crumb_sep_" .. j, text = "›", font = "r12", color = T.muted, x = cx, y = hy + 1 } )
				cx = cx + sep:w() + 6
			end
		end
	end
	local on = self:count_on()
	if on > 0 then
		local ot = D.text( hp, { name = "on_count", text = on .. " on", font = "r13", color = T.acc, x = 0, y = hy } )
		ot:set_right( W - PAD )
	end
	hy = hy + row_h

	-- title
	gap()
	local title = D.text( hp, { name = "title", text = tostring( data.title or "" ), font = "b23", upper = true, ls = 0.02, lh = 1.1,
		color = T.text, x = PAD, y = hy, w = IW, wrap = true } )
	hy = hy + title:h()
	hy = math_floor( hy + 0.5 )

	-- description
	local desc = data.description
	if desc and desc ~= "" then
		gap()
		local dt = D.text( hp, { name = "description", text = tostring( desc ), font = "r14", lh = 1.4, color = T.muted, x = PAD, y = hy, w = IW, wrap = true } )
		hy = hy + dt:h()
		hy = math_floor( hy + 0.5 )
	end

	-- message line (Menu:set_description / ppu_feedback)
	if self.msg and self.msg ~= "" then
		gap()
		local mt = D.text( hp, { name = "msg", text = self.msg, font = "r14", color = T.acc, x = PAD, y = hy, w = IW, wrap = true } )
		hy = hy + mt:h()
		hy = math_floor( hy + 0.5 )
	end

	-- search (shown when there are more than 8 rows)
	self.search_box = nil
	local n_rows = 0
	for _, b in ipairs( data.button_list or {} ) do
		if not is_spacer( b ) then n_rows = n_rows + 1 end
	end
	self.n_rows = n_rows
	if n_rows > 8 or self.q ~= "" then
		gap()
		-- height 30 + 1 px border (content-box, like the design) = 32
		local SH = 32
		local sb = hp:panel( { name = "search", x = PAD, y = hy, w = IW, h = SH, layer = 2 } )
		D.box( sb, { x = 0, y = 0, w = IW, h = SH, r = 3, color = T.surf, layer = 0 } )
		local border = D.border( sb, { x = 0, y = 0, w = IW, h = SH, r = 3, color = self.search_focused and T.acc or T.line2, layer = 1 } )
		-- "/" key cap: min-width 18, height 18, border 1 (bottom 2) -> 20 x 21
		local kw = math_max( 18, D.measure( "r11", "/" ) ) + 2
		local kh = 21
		local kx = IW - 1 - 10 - kw
		local ky = ( SH - kh ) / 2
		D.border( sb, { x = kx, y = ky, w = kw, h = kh, r = 3, color = T.line2, bottom = 2, layer = 2 } )
		local kt = D.text( sb, { text = "/", font = "r11", color = T.muted, x = kx, w = kw, align = "center", y = 0, layer = 3 } )
		kt:center_line_on( ky + 1 + 9 )
		local shown = self.q ~= "" and self.q or ( "Search " .. n_rows .. " rows" )
		local qt = D.text( sb, { name = "q", text = shown, font = "r15", color = self.q ~= "" and T.text or T.placeholder, x = 11, y = 0, layer = 3 } )
		qt:center_line_on( SH / 2 )
		local caret = sb:rect( { name = "caret", x = 11 + ( self.q ~= "" and qt:w() or 0 ), y = 8, w = 1, h = 16, color = T.text, visible = self.search_focused and true or false, layer = 4 } )
		self.search_box = { panel = sb, border = border, caret = caret }
		-- the typing object for the search field
		local si = TextInput:new( sb, { value = self.q }, self._ws, self.kb_panel )
		si.on_change = function( s )
			if s ~= self.q then
				self.q = s
				self.fi = 1
				self.scroll, self.scroll_target = 0, 0
				self._dirty = true
			end
		end
		si.on_focus = function( f )
			if self.search_focused ~= f then
				self.search_focused = f
				self._dirty = true
			end
		end
		self.search_input = si
		hy = hy + SH
	end

	hy = hy + 12
	hp:set_h( hy + 1 )
	hp:rect( { name = "header_line", x = 0, y = hy, w = W, h = 1, color = T.line, layer = 1 } )
	return y + hy + 1
end

function Menu:count_on()
	local n = 0
	for _, b in ipairs( self._data.button_list or {} ) do
		if row_kind( b ) == "tog" then
			local tb = Tickbox:new( nil, b, b.plugin_path or self._data.plugin_path )
			if tb:get_state() then
				n = n + 1
			end
		end
	end
	return n
end

-- List ---------------------------------------------------------------------------------------

function Menu:add_list( y )
	local T = self.T
	local W = self.W
	local content = self.content
	local vis = self:visible_buttons()
	self.vis = vis

	-- panels clip their children (the game's ScrollablePanel relies on this)
	local clip = content:panel( { name = "list_clip", x = 0, y = y, w = W, h = 10, layer = 1 } )
	self.list_clip = clip
	local canvas = clip:panel( { name = "list_canvas", x = 0, y = 0, w = W, h = 10 } )
	self.canvas = canvas

	self.rows = {}
	local ry = 6
	for vi, v in ipairs( vis ) do
		local r = self:build_row( canvas, vi, v, ry )
		self.rows[ vi ] = r
		ry = ry + r.h
	end
	if #vis == 0 then
		local et = D.text( canvas, { name = "empty", text = self.q ~= "" and "No matches" or "Nothing here", font = "r15", color = T.muted, x = PAD, y = 14 } )
		ry = 14 + et:h() + 14
	else
		ry = ry + 6
	end
	canvas:set_h( ry )
	self.content_h = ry

	local h = math_min( ry, LIST_MAX )
	if PPU_list_h then
		h = PPU_list_h
	end
	if self.list_h_limit then
		h = math_min( h, self.list_h_limit )
	end
	self.list_h = h
	clip:set_h( h )
	self:clamp_scroll()
	canvas:set_y( -self.scroll )
	return y + h
end

function Menu:clamp_scroll()
	local maxs = math_max( 0, ( self.content_h or 0 ) - ( self.list_h or 0 ) )
	self.scroll = math_max( 0, math_min( self.scroll or 0, maxs ) )
	self.scroll_target = math_max( 0, math_min( self.scroll_target or 0, maxs ) )
end

-- One row. Returns { panel, h, kind, button, index, focusable, ... }
function Menu:build_row( canvas, vi, v, y )
	local T = self.T
	local W = self.W
	local b = v.button
	local kind = v.kind
	local r = { kind = kind, button = b, index = v.index, vi = vi }
	local plug_path = b.plugin_path or self._data.plugin_path

	if kind == "sp" then
		local p = canvas:panel( { name = "row_" .. vi, x = 0, y = y, w = W, h = 13 } )
		p:rect( { x = PAD, y = 6, w = W - PAD * 2, h = 1, color = T.line } )
		r.panel, r.h, r.focusable = p, 13, false
		return r
	end

	r.focusable = true
	r.locked = b.host_only and self.client
	local p = canvas:panel( { name = "row_" .. vi, x = 0, y = y, w = W, h = ROW_H } )
	r.panel = p
	r.focus_bg = p:rect( { name = "focus_bg", color = T.accsoft, visible = false, layer = 0 } )
	r.focus_bar = p:rect( { name = "focus_bar", x = 0, y = 0, w = 3, h = ROW_H, color = T.acc, visible = false, layer = 1 } )

	if kind == "sld" and not r.locked then
		return self:build_slider_row( p, r )
	elseif kind == "inp" and not r.locked then
		return self:build_input_row( p, r )
	elseif kind == "rgb" then
		return self:build_rgb_row( p, r )
	elseif b.ask and self.confirm == b and not r.locked then
		return self:build_ask_row( p, r )
	end

	-- Line row: [lock] label ........ [switch | < value > | ›]
	local right = W - PAD
	local parts = {}
	if not r.locked then
		if kind == "tog" then
			local tb = Tickbox:new( p, b, plug_path )
			b.tickbox = tb
			r.tickbox = tb
			right = right - 38
			parts.switch_x = right
			right = right - 10
		elseif kind == "cho" then
			local mc = MultiChoice:new( p, b )
			b.multi_choice = mc
			r.choice = mc
			local vw = math_max( 120, D.measure( "s16", mc:text() ) )
			local cw = 24 + 2 + vw + 2 + 24
			right = right - cw
			parts.cho_x = right
			parts.cho_vw = vw
			right = right - 10
		elseif kind == "sub" then
			local aw = D.measure( "r18", "›" )
			right = right - aw
			parts.arrow_x = right
			right = right - 10
		end
	end
	if kind == "save" then
		b.save_button = SaveButton:new( p, b )
	end
	-- meta: small grey note on the right (design r.meta)
	local meta
	if b.meta and b.meta ~= "" then
		meta = D.text( p, { name = "meta", text = tostring( b.meta ), font = "r13", color = T.muted, x = 0, y = 0, layer = 3 } )
		right = right - meta:w()
		meta:set_x( right )
		right = right - 10
	end

	local lx = PAD
	if r.locked then
		lx = lx + 12 + 10
	end
	local color = r.locked and T.muted or ( b.danger and T.warn or T.text )
	local label = D.text( p, { name = "text", text = label_of( b ), font = "r16", color = color, x = lx, y = 0, w = math_max( 20, right - lx ), wrap = true, layer = 2 } )
	r.label = label
	-- min-height 36 + padding 3 top/bottom (content-box, as in the design) = 42
	local line_h = math_max( ROW_H, label:h() ) + 6

	-- the design shows a tip under a focused locked row
	local tip_h = 0
	if r.locked and self.fi == vi then
		local tw = W - 38 - PAD
		local tt = D.text( p, { name = "tip_text", text = HOST_TIP, font = "r13", lh = 1.35, color = T.bg, x = 38 + 9, y = line_h + 6, w = tw - 18, wrap = true, layer = 3 } )
		local bh = tt:h() + 12
		D.box( p, { name = "tip_bg", x = 38, y = line_h, w = tw, h = bh, r = 3, color = T.text, layer = 2 } )
		tip_h = bh + 8
	end
	local h = line_h + tip_h
	p:set_h( h )
	r.focus_bar:set_h( h )
	r.focus_bg:set_h( h )
	r.h = h
	if label:h() > ROW_H then
		label:set_y( 3 )
	else
		label:center_line_on( line_h / 2 )
	end
	if r.locked then
		D.sbitmap( p, "lock", PAD, ( line_h - 12 ) / 2, 12, 12, T.muted, 3 )
	end
	if meta then
		meta:center_line_on( line_h / 2 )
	end

	if parts.switch_x then
		local on = r.tickbox:get_state()
		local sy = ( line_h - 20 ) / 2
		local sw = { x0 = parts.switch_x }
		sw.track = D.box( p, { name = "switch_track", x = parts.switch_x, y = sy, w = 38, h = 20, r = 10, color = on and T.acc or T.line2, layer = 2 } )
		sw.knob = D.circle( p, { name = "switch_knob", x = parts.switch_x + ( on and 20 or 2 ), y = sy + 2, d = 16, color = T.text, layer = 3 } )
		r.switch = sw
		r.tickbox.on_change = function( state )
			self:set_switch( r, state, true )
		end
	elseif parts.cho_x then
		local cy = ( line_h - 24 ) / 2
		local mc = r.choice
		local function arrow_btn( name, x, glyph )
			local bp = p:panel( { name = name, x = x, y = cy, w = 24, h = 24, layer = 3 } )
			local bg = D.box( bp, { x = 0, y = 0, w = 24, h = 24, r = 3, color = T.line, layer = 0 } )
			bg:set_visible( false )
			local gt = D.text( bp, { text = glyph, font = "r14", color = T.muted, x = 0, y = 0, w = 24, align = "center", layer = 1 } )
			gt:center_line_on( 12 )
			return { panel = bp, bg = bg, glyph = gt }
		end
		r.cho_prev = arrow_btn( "cho_prev", parts.cho_x, "◂" )
		r.cho_next = arrow_btn( "cho_next", parts.cho_x + 24 + 2 + parts.cho_vw + 2, "▸" )
		local vt = D.text( p, { name = "cho_value", text = mc:text(), font = "s16", color = T.acc, x = parts.cho_x + 26, y = 0, w = parts.cho_vw, align = "center", layer = 3 } )
		vt:center_line_on( line_h / 2 )
		r.cho_value = vt
		mc.on_change = function()
			self._dirty = true -- the value width can change the layout
		end
	elseif parts.arrow_x then
		local at = D.text( p, { name = "arrow", text = "›", font = "r18", color = T.muted, x = parts.arrow_x, y = 0, layer = 3 } )
		at:center_line_on( line_h / 2 )
	end
	return r
end


-- Ask row (design "ask"): the row turns red and asks before a destructive action runs.
function Menu:build_ask_row( p, r )
	local T = self.T
	local W = self.W
	local b = r.button
	local RH0 = ROW_H + 8 -- min-height 36 + padding 4 top/bottom
	-- buttons: Yes (warn fill) and No (outline)
	local nw = D.measure( "r14", "No" ) + 24 + 2
	local yw = D.measure( "s14", "Yes" ) + 24 + 2
	local bh = D.lh( "s14" ) + 4 + 2
	local nx = W - PAD - nw
	local yx = nx - 8 - yw
	local q = D.text( p, { name = "ask_q", text = tostring( b.ask ), font = "r16", color = T.text, x = PAD, y = 0, w = math_max( 20, yx - 8 - PAD ), wrap = true, layer = 2 } )
	local RH = math_max( ROW_H, q:h() ) + 8
	if q:h() > ROW_H then q:set_y( 4 ) else q:center_line_on( RH / 2 ) end
	local function btn( name, x, w, label, font, fill, border, color )
		local bp = p:panel( { name = name, x = x, y = ( RH - bh ) / 2, w = w, h = bh, layer = 3 } )
		if fill then
			D.box( bp, { x = 0, y = 0, w = w, h = bh, r = 3, color = fill, layer = 0 } )
		end
		D.border( bp, { x = 0, y = 0, w = w, h = bh, r = 3, color = border, layer = 1 } )
		D.text( bp, { text = label, font = font, color = color, x = 0, y = 2, w = w, align = "center", layer = 2 } )
		return bp
	end
	r.ask_yes = btn( "ask_yes", yx, yw, "Yes", "s14", T.warn, T.warn, T.bg )
	r.ask_no = btn( "ask_no", nx, nw, "No", "r14", nil, T.line2, T.text )
	r.asking = true
	-- red background and bar whether focused or not
	r.focus_bg:set_color( T.warnsoft )
	r.focus_bar:set_color( T.warn )
	r.focus_bg:set_visible( true )
	r.focus_bar:set_visible( true )
	p:set_h( RH )
	r.focus_bg:set_h( RH )
	r.focus_bar:set_h( RH )
	r.h = RH
	return r
end

-- Colour row (design "trgb"): swatch, name, "r, g, b", ▸ / ▾; open shows R, G, B sliders.
local CHANNELS = { "R", "G", "B" }
function Menu:build_rgb_row( p, r )
	local T = self.T
	local W = self.W
	local b = r.button
	local c = T.raw[ b.role ] or { 0, 0, 0 }
	local open = self.open_rgb == b
	r.open = open
	local line_h = ROW_H + 6

	-- open rows sit on the surface colour (the focus colour wins when focused)
	r.open_bg = p:rect( { name = "open_bg", color = T.surf, visible = open, layer = 0 } )

	local x = PAD
	D.box( p, { name = "swatch", x = x, y = ( line_h - 20 ) / 2, w = 20, h = 20, r = 3, color = rgb( c ), layer = 2 } )
	D.border( p, { name = "swatch_border", x = x, y = ( line_h - 20 ) / 2, w = 20, h = 20, r = 3, color = T.line2, layer = 3 } )
	x = x + 20 + 10
	local arrow = D.text( p, { name = "arrow", text = open and "▾" or "▸", font = "r18", color = T.muted, x = 0, y = 0, layer = 3 } )
	arrow:set_right( W - PAD )
	arrow:center_line_on( line_h / 2 )
	local meta = D.text( p, { name = "meta", text = c[1] .. ", " .. c[2] .. ", " .. c[3], font = "r13", color = T.muted, x = 0, y = 0, layer = 3 } )
	meta:set_right( arrow:x() - 10 )
	meta:center_line_on( line_h / 2 )
	local label = D.text( p, { name = "text", text = label_of( b ), font = "r16", color = T.text, x = x, y = 0, layer = 2 } )
	label:center_line_on( line_h / 2 )
	r.line_h = line_h

	local h = line_h
	r.channels = {}
	if open then
		-- padding 2 16 12 44, three rows of 20 with 8 between
		local cy = line_h + 2
		for ci, name in ipairs( CHANNELS ) do
			local rowp = p:panel( { name = "chan_" .. ci, x = 44, y = cy, w = W - 44 - PAD, h = 20, layer = 3 } )
			local nm = D.text( rowp, { text = name, font = "s14", color = T.muted, x = 0, y = 0, layer = 1 } )
			nm:center_line_on( 10 )
			local val = D.text( rowp, { text = tostring( c[ ci ] ), font = "r14", color = T.text, x = 0, y = 0, w = 30, align = "right", layer = 1 } )
			val:set_x( rowp:w() - 30 )
			val:center_line_on( 10 )
			local tx = 12 + 10
			local tw = rowp:w() - 30 - 10 - tx
			-- track panel is 10 px wider on each side so the knob isn't clipped at the ends
			local TP = 10
			local track = rowp:panel( { name = "track", x = tx - TP, y = 0, w = tw + TP * 2, h = 20, layer = 1 } )
			local lo, hi = { c[1], c[2], c[3] }, { c[1], c[2], c[3] }
			lo[ ci ], hi[ ci ] = 0, 255
			-- gradient bar with rounded ends (solid end caps in the end colours)
			D.box( track, { x = TP, y = 6, w = 4, h = 8, r = 4, color = rgb( lo ), layer = 0 } )
			D.box( track, { x = TP + tw - 4, y = 6, w = 4, h = 8, r = 4, color = rgb( hi ), layer = 0 } )
			track:gradient( { name = "grad", x = TP + 4, y = 6, w = tw - 8, h = 8, layer = 0,
				gradient_points = { 0, rgb( lo ), 1, rgb( hi ) } } )
			D.border( track, { x = TP, y = 6, w = tw, h = 8, r = 4, color = T.line, layer = 1 } )
			local kx = TP + tw * c[ ci ] / 255 - 7
			D.circle( track, { name = "ring", x = kx - 2, y = 1, d = 18, color = T.bg, layer = 2 } )
			D.circle( track, { name = "knob", x = kx, y = 3, d = 14, color = T.text, layer = 3 } )
			r.channels[ ci ] = { track = track, pad = TP, w = tw }
			cy = cy + 20 + ( ci < 3 and 8 or 0 )
		end
		h = cy + 12
	end
	p:set_h( h )
	r.focus_bg:set_h( h )
	r.focus_bar:set_h( h )
	r.open_bg:set_h( h )
	r.h = h
	return r
end

function Menu:toggle_rgb( r )
	self.open_rgb = ( self.open_rgb ~= r.button ) and r.button or nil
	self._dirty = true
end

-- Yes runs the row as usual (skipping the question), No just closes the question
function Menu:answer_ask( r, yes )
	self.confirm = nil
	self._dirty = true
	if yes then
		local msg = self.msg
		self:button_pressed( r.index, nil, true )
		if tweak_data.menu_active == self and self._ws and self.msg == msg then
			self:set_description( label_of( r.button ) .. ": done" )
		end
	end
end

function Menu:apply_theme()
	self.T = ppu_theme()
	_G.PPU_T = self.T
	self._dirty = true
end

function Menu:set_switch( r, on, animate )
	local T = self.T
	local sw = r.switch
	if not sw then return end
	sw.track:set_color( on and T.acc or T.line2 )
	local tx = sw.x0 + ( on and 20 or 2 )
	if animate then
		self:tween( sw.knob.panel, tx, 0.15 )
	else
		sw.knob.panel:set_x( tx )
	end
end

-- Slider row (design sld): label + value, track + Apply, min/max labels
function Menu:build_slider_row( p, r )
	local T = self.T
	local W = self.W
	local b = r.button
	local sl = Slider:new( p, b )
	b.slider = sl
	r.slider = sl

	local y = 8
	D.text( p, { name = "text", text = label_of( b ), font = "r16", color = T.text, x = PAD, y = y, layer = 2 } )
	local vt = D.text( p, { name = "slider_value", text = fmt_num( sl.value ), font = "s16", color = T.text, x = 0, y = y, layer = 2 } )
	vt:set_right( W - PAD )
	r.value_text = vt
	y = y + D.lh( "r16" ) + 5

	-- Apply button
	local aw = D.measure( "s14", "Apply" ) + 24 + 2
	local ah = D.lh( "s14" ) + 6 + 2
	local ax = W - PAD - aw
	local row2_h = math_max( 20, ah )
	local track_w = ax - 12 - PAD
	-- the knob may stick out 10 px past either end (panels clip), so the panel is wider
	local TP = 10
	r.track_pad = TP
	local track = p:panel( { name = "slider_track", x = PAD - TP, y = y + ( row2_h - 20 ) / 2, w = track_w + TP * 2, h = 20, layer = 2 } )
	D.box( track, { x = TP, y = 8, w = track_w, h = 4, r = 2, color = T.line2, layer = 0 } )
	r.knob_ring = D.circle( track, { x = 0, y = 0, d = 20, color = T.accsoft, layer = 2 } )
	r.knob = D.circle( track, { x = 0, y = 3, d = 14, color = T.text, layer = 3 } )
	r.track = track
	r.track_w = track_w

	local abtn = p:panel( { name = "apply", x = ax, y = y + ( row2_h - ah ) / 2, w = aw, h = ah, layer = 2 } )
	r.apply = abtn
	r.apply_parts = {
		bg = D.box( abtn, { x = 0, y = 0, w = aw, h = ah, r = 3, color = T.acc, layer = 0 } ),
		border = D.border( abtn, { x = 0, y = 0, w = aw, h = ah, r = 3, color = T.acc, layer = 1 } ),
		text = D.text( abtn, { text = "Apply", font = "s14", color = T.bg, x = 0, y = 4, w = aw, align = "center", layer = 2 } ),
	}
	y = y + row2_h + 5

	D.text( p, { text = fmt_num( sl.min ), font = "r12", color = T.muted, x = PAD, y = y, layer = 2 } )
	local maxl = D.text( p, { text = fmt_num( sl.max ), font = "r12", color = T.muted, x = 0, y = y, layer = 2 } )
	maxl:set_right( W - PAD - ( aw + 12 ) )
	y = y + D.lh( "r12" ) + 10

	p:set_h( y )
	r.focus_bar:set_h( y )
	r.focus_bg:set_h( y )
	r.h = y
	self:refresh_slider( r )
	return r
end

function Menu:refresh_slider( r )
	local T = self.T
	local sl = r.slider
	local f = sl:fraction()
	local tw = r.track_w
	-- redraw the fill so its rounded ends match the new width
	if r.fill then
		r.track:remove( r.fill.panel )
	end
	local TP = r.track_pad
	r.fill = D.box( r.track, { x = TP, y = 8, w = math_max( 4, tw * f ), h = 4, r = 2, color = T.acc, layer = 1 } )
	r.fill:set_visible( f > 0 )
	local kx = TP + tw * f - 7
	r.knob.panel:set_x( kx )
	r.knob_ring.panel:set_x( kx - 3 )
	r.value_text:set_text( fmt_num( sl.value ) )
	r.value_text:set_right( self.W - PAD )
	local can = sl:can_apply()
	r.apply_parts.bg:set_visible( can )
	r.apply_parts.border:set_color( can and T.acc or T.line2 )
	r.apply_parts.text:set_color( can and T.bg or T.muted )
end

-- Input row (design inp): field + Confirm
function Menu:build_input_row( p, r )
	local T = self.T
	local W = self.W
	local b = r.button
	local ti = TextInput:new( p, b, self._ws, self.kb_panel )
	b.input = ti
	r.input = ti
	local active = TextInput.active and TextInput.active.button == b

	local label = b.confirm_label or "Confirm"
	local bw = D.measure( "s14", label ) + 24 + 2
	local bh = D.lh( "s14" ) + 4 + 2
	local bx = W - PAD - bw
	local fx, fw = PAD, bx - 8 - PAD
	local RH = ROW_H + 8 -- min-height 36 + padding 4 top/bottom
	local FH = 30 -- height 28 + 1 px border
	local field = p:panel( { name = "field", x = fx, y = ( RH - FH ) / 2, w = fw, h = FH, layer = 2 } )
	r.field = field
	local has = ti:text() ~= ""
	-- idle: outline in line2, typing: accent outline on the surface colour (design cfgnew / rename)
	r.field_bg = D.box( field, { x = 0, y = 0, w = fw, h = FH, r = 3, color = T.surf, layer = 0 } )
	r.field_bg:set_visible( active )
	r.field_border = D.border( field, { x = 0, y = 0, w = fw, h = FH, r = 3, color = active and T.acc or T.line2, layer = 1 } )
	local ph = b.placeholder or ( label_of( b ):gsub( ":%s*$", "" ) )
	local ft = D.text( field, { name = "field_text", text = has and ti:text() or ph, font = "r15", color = has and T.text or T.placeholder, x = 9, y = 0, layer = 2 } )
	ft:center_line_on( FH / 2 )
	r.field_text = ft
	r.caret = field:rect( { name = "caret", x = 9 + ( has and ft:w() or 0 ), y = 7, w = 1, h = 16, color = T.text, visible = active and true or false, layer = 3 } )

	local btn = p:panel( { name = "confirm", x = bx, y = ( RH - bh ) / 2, w = bw, h = bh, layer = 2 } )
	r.confirm = btn
	r.confirm_parts = {
		bg = D.box( btn, { x = 0, y = 0, w = bw, h = bh, r = 3, color = T.acc, layer = 0 } ),
		border = D.border( btn, { x = 0, y = 0, w = bw, h = bh, r = 3, color = has and T.acc or T.line2, layer = 1 } ),
		text = D.text( btn, { text = label, font = "s14", color = has and T.bg or T.muted, x = 0, y = 2, w = bw, align = "center", layer = 2 } ),
	}
	r.confirm_parts.bg:set_visible( has )

	ti.on_change = function( s )
		local has2 = s ~= ""
		ft:set_text( has2 and s or ph )
		ft:set_color( has2 and T.text or T.placeholder )
		r.caret:set_x( 9 + ( has2 and ft:w() or 0 ) )
		r.confirm_parts.bg:set_visible( has2 )
		r.confirm_parts.border:set_color( has2 and T.acc or T.line2 )
		r.confirm_parts.text:set_color( has2 and T.bg or T.muted )
	end
	ti.on_focus = function( f )
		r.field_bg:set_visible( f )
		r.field_border:set_color( f and T.acc or T.line2 )
		r.caret:set_visible( f )
	end

	p:set_h( RH )
	r.focus_bar:set_h( RH )
	r.focus_bg:set_h( RH )
	r.h = RH
	return r
end

-- Footer -------------------------------------------------------------------------------------

function Menu:foot_button( panel, name, text, x, enabled )
	local T = self.T
	local tw = D.measure( "r14", text )
	local w = tw + 24 + 2
	local h = D.lh( "r14" ) + 8 + 2
	local bp = panel:panel( { name = name, x = x, y = 10, w = w, h = h, layer = 1 } )
	local hover = D.box( bp, { x = 0, y = 0, w = w, h = h, r = 3, color = T.surf, layer = 0 } )
	hover:set_visible( false )
	D.border( bp, { x = 0, y = 0, w = w, h = h, r = 3, color = T.line2, layer = 1 } )
	D.text( bp, { text = text, font = "r14", color = T.text, x = 0, y = 5, w = w, align = "center", layer = 2 } )
	if not enabled then
		bp:set_alpha( 0.4 )
	end
	return { panel = bp, hover = hover, name = name, enabled = enabled }
end

function Menu:has_change_rows()
	for _, r in ipairs( self.rows or {} ) do
		if ( r.kind == "cho" or r.kind == "sld" ) and not r.locked then
			return true
		end
	end
end

function Menu:add_navigation( y )
	local T = self.T
	local content = self.content
	local W = self.W

	local np = content:panel( { name = "navigation_panel", x = 0, y = y, w = W, h = 48, layer = 2 } )
	self.navigation_panel = np
	np:rect( { name = "foot_line", x = 0, y = 0, w = W, h = 1, color = T.line, layer = 0 } )

	local at_root = #self.stack < 2 and not ( self._data.back and not self._data.back_is_page )
	self.at_root = at_root
	local b1 = self:foot_button( np, "back", "‹ Back", PAD, not at_root )
	local b2 = self:foot_button( np, "close_button", tr['exit'] or "Exit", PAD + b1.panel:w() + 6, true )
	self.foot_buttons = { b1, b2 }
	local left_w = b1.panel:w() + 6 + b2.panel:w()
	local bh = b1.panel:h()

	-- key hints
	local hints = { { "↑↓", "Move" }, { "Enter", "Select" } }
	if self:has_change_rows() then
		hints[ #hints + 1 ] = { "◂▸", "Change" }
	end
	hints[ #hints + 1 ] = at_root and { "Esc", "Close" } or { "Bksp", "Back" }
	local items = {}
	local hw = 0
	for i, h in ipairs( hints ) do
		local kw = D.measure( "r12", h[1] ) + 8 + 2
		local lw = D.measure( "r12", h[2] )
		items[ i ] = { k = h[1], l = h[2], kw = kw, lw = lw, w = kw + 4 + lw }
		hw = hw + items[ i ].w + ( i > 1 and 10 or 0 )
	end
	local hx, hy, total_h
	if left_w + 12 + hw <= W - PAD * 2 then
		hx = W - PAD - hw
		hy = 10 + ( bh - 20 ) / 2
		total_h = 10 + bh + 10
	else
		-- wraps to its own line (flex-wrap)
		hx = PAD
		hy = 10 + bh + 12
		total_h = hy + 20 + 10
	end
	for _, it in ipairs( items ) do
		D.border( np, { x = hx, y = hy, w = it.kw, h = 20, r = 3, color = T.line2, bottom = 2, layer = 1 } )
		local kt = D.text( np, { text = it.k, font = "r12", color = T.text, x = hx, y = hy, w = it.kw, align = "center", layer = 2 } )
		kt:center_line_on( hy + 1 + 8.5 )
		local lt = D.text( np, { text = it.l, font = "r12", color = T.muted, x = hx + it.kw + 4, y = hy, layer = 2 } )
		lt:center_line_on( hy + 10 )
		hx = hx + it.w + 10
	end
	np:set_h( total_h )
	return y + total_h
end

-- Resize handles (design: right edge, bottom edge, corner) ------------------------------------

function Menu:add_resize_handles( main, W, H )
	local T = self.T
	self.handles = {}
	local function handle( name, x, y, w, h, mode )
		local hp = main:panel( { name = name, x = 1 + x, y = 1 + y, w = w, h = h, layer = 60 } )
		local bg = hp:rect( { color = T.accsoft, visible = false } )
		self.handles[ #self.handles + 1 ] = { panel = hp, bg = bg, mode = mode }
		return hp
	end
	handle( "resize_r", W - 6, 0, 6, H - 12, "r" )
	handle( "resize_b", 0, H - 6, W - 12, 6, "b" )
	local c = handle( "resize_rb", W - 14, H - 14, 14, 14, "rb" )
	c:rect( { x = 4 + 5, y = 4, w = 2, h = 7, color = T.line2, layer = 1 } )
	c:rect( { x = 4, y = 4 + 5, w = 7, h = 2, color = T.line2, layer = 1 } )
end

---------------------------------------------------------------------------------------------
-- Focus / scroll
---------------------------------------------------------------------------------------------

function Menu:focusable_list()
	local out = {}
	for vi, r in ipairs( self.rows or {} ) do
		if r.focusable then
			out[ #out + 1 ] = vi
		end
	end
	return out
end

function Menu:refresh_focus()
	local rows = self.rows or {}
	if not rows[ self.fi ] or not rows[ self.fi ].focusable then
		local f = self:focusable_list()
		self.fi = f[1] or 1
	end
	for vi, r in ipairs( rows ) do
		local on = vi == self.fi and r.focusable
		if r.focus_bg and not r.asking then -- an ask row stays red
			r.focus_bg:set_visible( on and true or false )
			r.focus_bar:set_visible( on and true or false )
		end
		if r.open_bg then
			r.open_bg:set_visible( r.open and not on )
		end
	end
	self._focus_button = rows[ self.fi ] and rows[ self.fi ].index
end

function Menu:set_focus( vi, from_keyboard )
	if vi == self.fi then return end
	local old = self.rows[ self.fi ]
	local new = self.rows[ vi ]
	self.fi = vi
	-- a locked row shows its tip when focused, which changes the layout
	if ( old and old.locked ) or ( new and new.locked ) then
		self._dirty = true
	else
		self:refresh_focus()
	end
	if from_keyboard then
		if self._dirty then
			self._scroll_to_focus = true -- after the redraw, when row heights are known
		else
			self:scroll_to_focus()
		end
	end
end

-- design: keyboard focus scrolls the row into view with 6 px to spare
function Menu:scroll_to_focus()
	local r = self.rows and self.rows[ self.fi ]
	if not r then return end
	local t = r.panel:y()
	local b = t + r.h
	if t < self.scroll_target then
		self.scroll_target = t - 6
	elseif b > self.scroll_target + self.list_h then
		self.scroll_target = b - self.list_h + 6
	end
	self:clamp_scroll()
end

function Menu:move_focus( d )
	local f = self:focusable_list()
	if #f == 0 then return end
	local idx = 0
	for i, vi in ipairs( f ) do
		if vi == self.fi then idx = i end
	end
	local n = math_max( 1, math_min( #f, idx + d ) )
	self:set_focus( f[ n ], true )
end

---------------------------------------------------------------------------------------------
-- Set up input
---------------------------------------------------------------------------------------------

function Menu:setup_mouse()
	self._mouse_id = M_mouse_pointer:get_id()
	local data = {}
	data.id = self._mouse_id
	-- the game's own way to get wheel events (menucomponentmanager / chatmanager use it too)
	data.mouse_press = function( o, button, x, y )
		self:on_mouse_press( button )
	end
	M_mouse_pointer:use_mouse( data )
end

function Menu:on_mouse_press( button )
	if button ~= WHEEL_UP and button ~= WHEEL_DOWN then
		return
	end
	local x, y = self:mouse_pos()
	local d = button == WHEEL_UP and -1 or 1
	if self.main and self.main:inside( x, y ) and ( kb_down( keyboard, K_LCTRL ) or kb_down( keyboard, K_RCTRL ) ) then
		self:change_scale( -d * 0.05 )
		return
	end
	if self.tabs_panel and self.tabs_panel:inside( x, y ) then
		self:scroll_tabs( d * 80 )
	elseif self.list_clip and self.list_clip:inside( x, y ) then
		self.scroll_target = ( self.scroll_target or 0 ) + d * 100
		self:clamp_scroll()
	end
end

function Menu:add_controller()
	self.controller = M_controller:get_controller_by_name( "Menu" ) or M_controller:create_controller( "Menu", M_controller:get_default_wrapper_index(), false )
	self.controller:enable()

	self._cancel_func = callback( self, self, "cancel_pressed" )
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

-- Esc: leave a text field first, otherwise close
function Menu:cancel_pressed()
	if TextInput.active then
		TextInput.active:disable_input()
		return
	end
	self:close()
end

---------------------------------------------------------------------------------------------
-- Update loop
---------------------------------------------------------------------------------------------

function Menu:tween( obj, to_x, dur )
	self.tweens[ obj ] = { from = obj:x(), to = to_x, t0 = now(), dur = dur }
end

function Menu:run_tweens()
	local t = now()
	for obj, tw in pairs( self.tweens ) do
		local k = math_min( 1, ( t - tw.t0 ) / tw.dur )
		obj:set_x( tw.from + ( tw.to - tw.from ) * k )
		if k >= 1 then
			self.tweens[ obj ] = nil
		end
	end
end

-- key pressed now, or held (repeats like a keyboard: 0.4 s delay, then every 0.05 s)
function Menu:key_rep( id )
	local t = now()
	local rep = self.keyrep
	if kb_pressed( keyboard, id ) then
		rep[ id ] = t + 0.4
		return true
	end
	if kb_down( keyboard, id ) then
		if rep[ id ] and t >= rep[ id ] then
			rep[ id ] = t + 0.05
			return true
		end
	else
		rep[ id ] = nil
	end
end

function Menu:update()
	if not self._ws then return end
	if self._dirty then
		self._dirty = false
		self:build()
	end
	self:run_tweens()

	-- smooth scrolling (list + tabs)
	if self.scroll ~= self.scroll_target then
		local d = self.scroll_target - self.scroll
		self.scroll = math_abs( d ) < 1 and self.scroll_target or ( self.scroll + d * 0.35 )
		self.canvas:set_y( -self.scroll )
	end
	if self.tab_inner and self.tab_target and self.tab_off ~= self.tab_target then
		local d = self.tab_target - self.tab_off
		self.tab_off = math_abs( d ) < 1 and self.tab_target or ( self.tab_off + d * 0.35 )
		self.tab_inner:set_x( -self.tab_off )
		self:update_tab_arrows()
	end

	local ptr = self:mouse_update()
	if not self._ws then return end
	self:keyboard_update()
	if not self._ws then return end
	M_mouse_pointer:set_pointer_image( type( ptr ) == "string" and ptr or ( ptr and "link" or "arrow" ) )
end

function Menu:keyboard_update()
	local input = TextInput.active
	if input then
		if input:update_keys() then
			self._enter_t = now()
			if input == self.search_input then
				input:disable_input()
			else
				self:confirm_input( input )
			end
		end
		return
	end
	local shift = kb_down( keyboard, K_LSHIFT ) or kb_down( keyboard, K_RSHIFT )
	local ctrl = kb_down( keyboard, K_LCTRL ) or kb_down( keyboard, K_RCTRL )
	if ctrl and kb_pressed( keyboard, K_ZERO ) then
		self:change_scale( 1 - PPU_ui.scale ) -- Ctrl + 0: back to 100 %
		return
	end
	if self:key_rep( K_UP ) then
		self:move_focus( -1 )
	elseif self:key_rep( K_DOWN ) then
		self:move_focus( 1 )
	elseif self:key_rep( K_LEFT ) then
		self:row_lr( -1, shift )
	elseif self:key_rep( K_RIGHT ) then
		self:row_lr( 1, shift )
	elseif kb_pressed( keyboard, K_ENTER ) then
		self._enter_t = now()
		self:row_enter()
	elseif kb_pressed( keyboard, K_BACK ) then
		self:go_back()
	else
		for _, id in ipairs( K_SLASH ) do
			if kb_pressed( keyboard, id ) and self.search_input then
				self.search_input:activate_input()
				return
			end
		end
	end
end

function Menu:row_lr( d, big )
	local r = self.rows and self.rows[ self.fi ]
	if not r or r.locked then return end
	if r.kind == "cho" then
		if d < 0 then r.choice:previous_option() else r.choice:next_option() end
	elseif r.kind == "sld" then
		local sl = r.slider
		sl:set_value( sl.value + d * sl.step * ( big and 10 or 1 ) )
		self:refresh_slider( r )
	end
end

function Menu:row_enter()
	local r = self.rows and self.rows[ self.fi ]
	if not r or r.locked or not r.focusable then return end
	if r.asking then
		self:answer_ask( r, true )
	elseif r.kind == "rgb" then
		self:toggle_rgb( r )
	elseif r.kind == "cho" then
		r.choice:next_option()
	elseif r.kind == "sld" then
		self:apply_slider( r )
	elseif r.kind == "inp" then
		if r.input.input_enabled then
			self:confirm_input( r.input )
		else
			r.input:activate_input()
		end
	else
		self:button_pressed( r.index )
	end
end

function Menu:apply_slider( r )
	local gen = self._gen
	local sl = r.slider
	local applied = sl:apply()
	if self:stale( gen ) then
		return
	end
	if applied then
		local label = label_of( r.button ):gsub( ":%s*$", "" )
		self:set_description( label .. " " .. fmt_num( sl.value ) )
	end
	if not self:stale( gen ) then
		self:refresh_slider( r )
	end
end

function Menu:confirm_input( input )
	if input:text() == "" then
		return
	end
	-- leave the field first: the callback may close or replace this window
	input:disable_input()
	input:do_callback()
end

-- Controller "confirm" (Enter / gamepad A). Enter is also read directly; don't run twice.
function Menu:enter_button_pressed()
	if self._enter_t and now() - self._enter_t < 0.2 then
		return
	end
	if TextInput.active then
		return
	end
	self._enter_t = now()
	self:row_enter()
end

function Menu:mouse_update()
	local gen = self._gen
	local x, y = self:mouse_pos()
	local T = self.T
	local clicked = mouse_pressed( mouse, left_click )
	local rclicked = not clicked and mouse_pressed( mouse, right_click )
	local held = mouse_down( mouse, left_click )
	local link = false

	-- window resizing in progress
	if self.resizing then
		if held then
			local rs = self.resizing
			local W, LH = self.W, PPU_list_h
			if rs.mode ~= "b" then
				W = math_max( 340, math_min( 1000, rs.w0 + x - rs.x0, self._ws:panel():w() - 20 ) )
			end
			if rs.mode ~= "r" then
				LH = math_max( 160, math_min( 1200, rs.h0 + y - rs.y0 ) )
			end
			W = math_floor( W )
			LH = LH and math_floor( LH ) or nil
			if W ~= self.W or LH ~= PPU_list_h then
				self.W = W
				PPU_win_w = W
				PPU_list_h = LH
				self:build()
			end
			return true
		end
		self.resizing = nil
		save_ui_state()
	end
	-- moving the window (drag the header)
	if self.moving then
		if held then
			local mv = self.moving
			local root = self._ws:panel()
			local nx = math_max( 0, math_min( math_floor( mv.wx + x - mv.x0 ), root:w() - self.main:w() ) )
			local ny = math_max( 0, math_min( math_floor( mv.wy + y - mv.y0 ), root:h() - self.main:h() ) )
			if nx ~= self.win_x or ny ~= self.win_y then
				local dx, dy = nx - self.win_x, ny - self.win_y
				self.win_x, self.win_y = nx, ny
				self.main:set_x( nx )
				self.main:set_y( ny )
				if self.shadow then
					self.shadow:set_x( self.shadow:x() + dx )
					self.shadow:set_y( self.shadow:y() + dy )
				end
			end
			return "grab"
		end
		self.moving = nil
		self:remember_position()
	end
	-- slider drag in progress
	-- dragging a colour channel (Theme page)
	if self.drag_rgb then
		if held then
			local d = self.drag_rgb
			local ch
			for _, nr in ipairs( self.rows or {} ) do
				if nr.button == d.button and nr.channels then
					ch = nr.channels[ d.ci ]
				end
			end
			if ch then
				local f = ( x - ch.track:world_x() - ch.pad ) / ch.w
				local v = math_floor( math_max( 0, math_min( 1, f ) ) * 255 + 0.5 )
				if v ~= d.last then
					d.last = v
					ppu_theme_set( d.button.role, d.ci, v )
					self.theme_changed = true
				end
			end
			return true
		end
		self.drag_rgb = nil
		if self.theme_changed then
			self.theme_changed = nil
			ppu_theme_save()
		end
	end
	if self.drag_slider and self.drag_gen ~= self._gen then
		-- the window was redrawn while dragging: follow the same slider in the new rows
		local b = self.drag_slider.button
		self.drag_slider = nil
		for _, nr in ipairs( self.rows or {} ) do
			if nr.button == b and nr.kind == "sld" and nr.track then
				self.drag_slider = nr
			end
		end
		self.drag_gen = self._gen
	end
	if self.drag_slider then
		if held then
			local r = self.drag_slider
			local f = ( x - r.track:world_x() - r.track_pad ) / r.track_w
			local sl = r.slider
			sl:set_value( sl.min + ( sl.max - sl.min ) * math_max( 0, math_min( 1, f ) ) )
			self:refresh_slider( r )
			return true
		end
		self.drag_slider = nil
	end

	-- a click outside the active text field leaves it
	if clicked and TextInput.active then
		local ai = TextInput.active
		local keep = false
		if ai == self.search_input then
			keep = self.search_box and self.search_box.panel:inside( x, y )
		else
			for _, r in ipairs( self.rows ) do
				if r.input == ai and ( r.field:inside( x, y ) or r.confirm:inside( x, y ) ) then
					keep = true
				end
			end
		end
		if not keep then
			ai:disable_input()
		end
	end

	-- resize handles
	for _, hd in ipairs( self.handles or {} ) do
		local inside = hd.panel:inside( x, y )
		hd.bg:set_visible( inside )
		if inside then
			if clicked then
				self.resizing = { mode = hd.mode, x0 = x, y0 = y, w0 = self.W, h0 = PPU_list_h or self.list_h }
			end
			return true
		end
	end

	-- tabs
	if self.tabs_panel and self.tabs_panel:inside( x, y ) then
		for side, a in pairs( self.tab_arrows or {} ) do
			local over = a.panel:visible() and a.panel:inside( x, y )
			a.glyph:set_color( over and T.acc or T.text )
			if over then
				if clicked then
					self:scroll_tabs( ( side == "l" and -1 or 1 ) * math_max( 120, self.W * 0.6 ) )
				end
				return true
			end
		end
		for _, tp in ipairs( self.tab_panels ) do
			local over = tp.panel:inside( x, y ) and self.tab_strip:inside( x, y )
			if not tp.on then
				local c = over and T.text or T.muted
				tp.key:set_color( c )
				tp.label:set_color( c )
			end
			if over then
				link = true
				if clicked then
					local v = rawget( _G, "KeyInput" ) and KeyInput.keys[ tp.tab[1] ]
					if v and v.callback then
						PPU_current_tab = tp.tab[1]
						PPU_nav_mode = "reset"
						safecall( v.callback )
						return true
					end
				end
			end
		end
		return link
	end
	for _, tp in ipairs( self.tab_panels or {} ) do
		if not tp.on then
			tp.key:set_color( T.muted )
			tp.label:set_color( T.muted )
		end
	end
	for _, a in pairs( self.tab_arrows or {} ) do
		a.glyph:set_color( T.text )
	end

	-- header: breadcrumbs, search field
	for j, c in ipairs( self.crumbs or {} ) do
		if not c.last then
			local over = c.text:inside( x, y )
			c.text:set_color( over and T.text or T.muted )
			if over then
				link = true
				if clicked then
					self:open_level( j )
					return true
				end
			end
		end
	end
	if self.search_box and self.search_box.panel:inside( x, y ) then
		if clicked and self.search_input then
			self.search_input:activate_input()
		end
		return true
	end
	if link then
		return true
	end
	-- the rest of the header moves the window
	if self.header_panel and self.header_panel:inside( x, y ) then
		if clicked then
			self.moving = { x0 = x, y0 = y, wx = self.win_x, wy = self.win_y }
			return "grab"
		end
		return "hand"
	end

	-- footer buttons
	for _, fb in ipairs( self.foot_buttons or {} ) do
		local over = fb.enabled and fb.panel:inside( x, y )
		fb.hover:set_visible( over and true or false )
		if over then
			link = true
			if clicked then
				if fb.name == "close_button" then
					self:close()
				else
					self:go_back()
				end
				return true
			end
		end
	end

	-- rows (only the part inside the list viewport counts)
	-- the pointer focuses a row when it moves onto it (design: mouseenter), so a still
	-- pointer doesn't fight the arrow keys
	local moved = x ~= self._mx or y ~= self._my
	self._mx, self._my = x, y
	local over_row
	if self.list_clip and self.list_clip:inside( x, y ) then
		for vi, r in ipairs( self.rows ) do
			if r.focusable and r.panel:inside( x, y ) then
				over_row = r
				if moved or clicked or rclicked then
					self:set_focus( vi, false )
				end
				link = self:row_mouse( r, x, y, clicked, rclicked ) or link
				if self:stale( gen ) then
					return link -- the row closed or replaced this window
				end
				break
			end
		end
	end
	-- choice arrows lose their hover when the pointer leaves them
	for _, r in ipairs( self.rows or {} ) do
		if r.cho_prev and r ~= over_row then
			for _, a in ipairs( { r.cho_prev, r.cho_next } ) do
				a.bg:set_visible( false )
				a.glyph:set_color( T.muted )
			end
		end
	end
	return link
end

-- mouse over / click on one row; returns true when the pointer should be a hand
function Menu:row_mouse( r, x, y, clicked, rclicked )
	local T = self.T
	if r.locked then
		return false
	end
	local kind = r.kind
	if r.asking then
		local yes = r.ask_yes:inside( x, y )
		local no = r.ask_no:inside( x, y )
		if clicked and ( yes or no ) then
			self:answer_ask( r, yes )
		end
		return yes or no
	elseif kind == "rgb" then
		for ci, ch in ipairs( r.channels or {} ) do
			if ch.track:inside( x, y ) then
				if clicked then
					self.drag_rgb = { button = r.button, ci = ci, gen = self._gen }
				end
				return true
			end
		end
		if y < r.panel:world_y() + r.line_h then
			if clicked then
				self:toggle_rgb( r )
			end
			return true
		end
		return false
	elseif kind == "cho" then
		local hit
		for _, a in ipairs( { r.cho_prev, r.cho_next } ) do
			local over = a.panel:inside( x, y )
			a.bg:set_visible( over )
			a.glyph:set_color( over and T.text or T.muted )
			if over then
				hit = a
			end
		end
		if hit and clicked then
			if hit == r.cho_prev then r.choice:previous_option() else r.choice:next_option() end
		end
		return hit and true or false
	elseif kind == "sld" then
		if r.apply:inside( x, y ) then
			if clicked then
				self:apply_slider( r )
			end
			return r.slider:can_apply()
		end
		if r.track:inside( x, y ) then
			if clicked then
				self.drag_slider = r
				self.drag_gen = self._gen
			end
			return true
		end
		return false
	elseif kind == "inp" then
		if r.field:inside( x, y ) then
			if clicked then
				r.input:activate_input()
			end
			return true
		end
		if r.confirm:inside( x, y ) then
			if clicked then
				self:confirm_input( r.input )
			end
			return r.input:text() ~= ""
		end
		return false
	end
	if clicked or rclicked then
		self:button_pressed( r.index, rclicked )
	end
	return true
end

---------------------------------------------------------------------------------------------
-- Navigation
---------------------------------------------------------------------------------------------

function Menu:go_back()
	if self.at_root then
		return
	end
	local data = self._data
	if data.back and not data.back_is_page then
		PPU_nav_mode = "back"
		safecall( data.back )
		return
	end
	local stack = self.stack
	if #stack >= 2 then
		self:open_level( #stack - 1 )
	end
end

function Menu:open_level( j )
	local level = self.stack[ j ]
	if not level then return end
	PPU_nav_mode = "back"
	Menu.open( Menu, level.data )
end

function Menu:navigation_button_pressed( button_name )
	if button_name == "close_button" then
		self:close()
	elseif button_name == "previous_page" or button_name == "back" then
		self:go_back()
	end
end

-- kept for other files; the redesign shows host-only rows locked instead of renaming them
function Menu:host_only_button( button )
end

-- highlight helpers kept for compatibility
function Menu:enable_highlight_button()
	self:refresh_focus()
end

function Menu:disable_highlight_button()
end

function Menu:button_pressed( button_index, alt, confirmed )
	local button = self._data.button_list[ button_index ]

	if not button then
		return
	end
	if button.host_only and is_client() then
		return
	end
	-- rows with an "ask" question ask inside the row first (design: inline Yes / No)
	if button.ask and not confirmed and not alt then
		self.confirm = button
		self._dirty = true
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

	-- Undying: Save keeps the menu open and can be pressed again
	local is_save = button.type == "save_button"
	if is_save and button.save_button then
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
		PPU_nav_mode = "push" -- a submenu opened by this row goes under this one in the breadcrumbs
		local data = button.data
		if type(data) == 'table' then
			safecall( btn_callback, unpack( data ) )
		else
			safecall( btn_callback, data )
		end
		PPU_nav_mode = nil
	end

	if tweak_data.menu_active ~= self then
		return -- the row opened another menu
	end

	local switch_back = button.switch_back
	if switch_back and ( button.type == "toggle" or have_plugin ) and button.tickbox then
		button.tickbox:toggle()
		self._dirty = true -- "N on" in the header
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

function Menu:close( replaced )
	if not self._ws then
		return
	end

	M_mouse_pointer:remove_mouse( self._mouse_id )
	self.controller:remove_trigger( "cancel", self._cancel_func )
	self.controller:remove_trigger( "confirm", self._confirm_func )
	self.controller:disable()
	executewithdelay( { func = self.disable_controllers, params = {self} }, 0.23, 'disable_cont_clbk' )

	self:stop_loops()
	self:destroy_gui()
	OverlayGui:destroy_workspace( self._ws )
	self._ws = nil
	tweak_data.menu_active = nil
	for id,clbk in pairs(self.close_clbks) do
		clbk()
	end
end

-- Live feedback inside the open menu (accent line under the description)
function Menu:set_description( text )
	if not self._ws then return end
	self.msg = tostring( text or "" )
	self._dirty = true
end

function Menu:set_button_text( button, text )
	for _, b in ipairs( self._data.button_list or {} ) do
		if b == button then
			b.text = text
			self._dirty = true
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
		local input = button.input
		if input then
			input.on_focus = nil
			input.on_change = nil
			input:close()
		end
	end
end

local G = getfenv(0)
G.Menu = Menu
return Menu
