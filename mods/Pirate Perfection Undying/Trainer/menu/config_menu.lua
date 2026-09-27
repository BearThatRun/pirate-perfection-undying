--Purpose: configuration menu
--Authors: Simplity - idea, lua stub and logic. JazzyDude - finishing and fixing
--Undying menu redesign (stage 4b): one page with the config list (ACTIVE / DEFAULT badges,
--Load / Rename / Delete on each row, "+ New config" field, overwrite / delete asked inside the row).

local ppr_require = ppr_require
ppr_require 'Trainer/tools/new_menu/menu'

local Menu = Menu
local Menu_open = Menu.open
local tr = Localization.translate
local io_open = ppr_io.open
local rlist_files = rlist_files
local insert = table.insert
local ppr_dofile = ppr_dofile
local pairs = pairs
local ipairs = ipairs
local rawget = rawget
local getmetatable = getmetatable
local tostring = tostring
local plugins = plugins
local ppr_config = ppr_config
-- x64: os.remove/os.rename don't know the mod folder, so prefix it like ppr_io.open does
local os_remove = function( p ) return os.remove( ppr_io.root .. p ) end
local os_rename = function( a, b ) return os.rename( ppr_io.root .. a, ppr_io.root .. b ) end

local CFG_DIR = "Trainer/configs/"
-- files in Trainer/configs that are not game configs
local NOT_CONFIGS = { blank = true, menu_config = true, menu_ui = true }
-- the trainer falls back to this file when a config is missing, so it can't be renamed or deleted
local PROTECTED = "default_config"

local function cfg_path( name )
	return CFG_DIR .. name .. ".lua"
end

local function clean_name( name )
	name = tostring( name or "" ):gsub( "^%s+", "" ):gsub( "%s+$", "" ):gsub( '[\\/:%*%?"<>|]', "_" )
	return name
end

local function read_file( path )
	local f = io_open( path, "r" )
	if not f then return nil end
	local s = f:read( "*all" )
	f:close()
	return s
end

local function write_file( path, s )
	local f = io_open( path, "w" )
	if not f then return false end
	f:write( s )
	f:close()
	return true
end

-- game_config exists after a config was loaded (in a heist, or after Load); calling it saves it
local function game_cfg()
	local gc = rawget( _G, "game_config" )
	local mt = type( gc ) == "table" and getmetatable( gc )
	if mt and mt.__call then
		return gc
	end
end

-- The config in use: the file game_config writes to (after a config was loaded: in a heist or
-- after Load), else the one the trainer will load (ppr_config.DefaultConfig).
local function active_name()
	local gc = game_cfg()
	local p = gc and rawget( gc, "auto_config" )
	if type( p ) == "string" then
		local n = p:match( "([^/\\]+)%.lua$" )
		if n then return n end
	end
	local n = rawget( ppr_config, "DefaultConfig" )
	return type( n ) == "string" and n or PROTECTED
end

-- The default saved in Trainer/configs/menu_config.lua (what the game loads on start)
local function saved_default()
	local src = read_file( "Trainer/configs/menu_config.lua" )
	local n = src and ( src:match( 'cfg%.DefaultConfig%s*=%s*"([^"]*)"' ) or src:match( "cfg%.DefaultConfig%s*=%s*'([^']*)'" ) )
	if n then return n end
	local cloned = rawget( ppr_config, "__cloned" )
	n = cloned and rawget( cloned, "DefaultConfig" )
	return type( n ) == "string" and n or PROTECTED
end

local function get_configs_list()
	-- rlist_files also lists sub folders (secret_skills/skills_config), which are not configs
	local out = {}
	for _, name in pairs( rlist_files( "Trainer/configs", "lua" ) or {} ) do
		if not NOT_CONFIGS[ name ] and file_exists( cfg_path( name ) ) then
			insert( out, name )
		end
	end
	table.sort( out, function( a, b )
		if a == PROTECTED then return b ~= PROTECTED end
		if b == PROTECTED then return false end
		return a:lower() < b:lower()
	end )
	return out
end

-- state of the page: { name = ..., kind = "rename" | "delete" }, pending overwrite name
local mode = {}
local overwrite_name
local new_row -- kept between redraws so the typed text stays

local function refresh()
	ppu_menu_rebuild()
end

-- Save the setting that the game loads on start (menu_config.lua) as `name`,
-- without changing the config in use for this session.
local function save_default_as( name )
	local cur = rawget( ppr_config, "DefaultConfig" )
	ppr_config.DefaultConfig = name
	ppr_config()
	ppr_config.DefaultConfig = cur
end

local load_config = function( name )
	plugins:unload_except_by_cat("no_reload", true) --normalizer
	ppr_config.DefaultConfig = name
	ppr_dofile('Trainer/Setup/auto_config')
	mode = {}
	refresh()
	ppu_feedback("Config loaded: " .. tostring(name))
end

-- New config from the current settings: in a heist (or after Load) the settings in use,
-- in the main menu a copy of the active config file.
local create_config = function( name, overwrite )
	name = clean_name( name )
	if name == "" or NOT_CONFIGS[ name ] then
		ppu_feedback( "Pick another name" )
		return
	end
	local path = cfg_path( name )
	local exists = file_exists( path )
	if exists and not overwrite then
		overwrite_name = name
		refresh()
		return
	end
	local ok
	local gc = game_cfg()
	if name == active_name() then
		-- overwriting the config in use with the settings in use
		if gc then gc() end
		ok = true
	elseif gc then
		write_file( path, "return function( cfg )\nend\n" )
		local old = rawget( gc, "auto_config" )
		gc.auto_config = path
		gc() -- write the settings in use into the new file
		gc.auto_config = old
		ok = true
	else
		local src = read_file( cfg_path( active_name() ) ) or "return function( cfg )\nend\n"
		ok = write_file( path, src )
	end
	overwrite_name = nil
	if new_row then new_row._ppu_text = nil end
	refresh()
	if ok then
		ppu_feedback( exists and ( "Overwrote '" .. name .. "'" ) or ( "Created '" .. name .. "' from current settings" ) )
	else
		ppu_feedback( "Couldn't write " .. path )
	end
end

local rename_config = function( name, new_name )
	new_name = clean_name( new_name )
	if new_name == "" or new_name == name then
		mode = {}
		refresh()
		return
	end
	if NOT_CONFIGS[ new_name ] or file_exists( cfg_path( new_name ) ) then
		ppu_feedback( "A config named '" .. new_name .. "' already exists" )
		return
	end
	local was_default = saved_default() == name
	local was_active = active_name() == name
	os_rename( cfg_path( name ), cfg_path( new_name ) )
	if was_active then
		ppr_config.DefaultConfig = new_name
		local gc = game_cfg()
		if gc then gc.auto_config = cfg_path( new_name ) end
	end
	if was_default then
		save_default_as( new_name )
	end
	mode = {}
	refresh()
	ppu_feedback( "Renamed '" .. name .. "' to '" .. new_name .. "'" )
end

local delete_config = function( name )
	local was_default = saved_default() == name
	local was_active = active_name() == name
	os_remove( cfg_path( name ) )
	mode = {}
	if was_default then
		save_default_as( PROTECTED )
	end
	if was_active then
		load_config( PROTECTED ) -- the deleted one was in use: switch to default_config
	end
	refresh()
	ppu_feedback( "Deleted '" .. name .. "'" )
end

local save_settings = function()
	local gc = game_cfg()
	if not gc then
		ppu_feedback( "Nothing to save yet: settings are saved from a heist (or after Load)" )
		return
	end
	gc() -- write changed settings into the active config file
	ppu_feedback( "Settings saved to " .. active_name() )
end

local set_default = function()
	save_default_as( active_name() )
	refresh()
	ppu_feedback( "Default config: " .. active_name() )
end

-- Page

local function build_list()
	local list = {}
	if GameSetup then
		-- the WayPoints menu only works in a heist
		insert( list, { text = tr['wp_title'], callback = ppr_require("Trainer/menu/waypoints_settings"), menu = true } )
	end
	-- Undying redesign: colours of every trainer window, saved in the active config
	insert( list, { text = "Theme", callback = ppr_require("Trainer/menu/theme_menu"), menu = true } )
	insert( list, { type = "header", text = "Configs" } )

	local active = active_name()
	local default = saved_default()
	local names = get_configs_list()
	for _, name in ipairs( names ) do
		if mode.name == name and mode.kind == "rename" then
			insert( list, { type = "input", text = "Rename " .. name, value = name, placeholder = tr['config_type'],
				confirm_label = "Confirm", selected = true, autofocus = true, switch_back = true,
				callback_input = function( s ) rename_config( name, s ) end,
				cancel = function() mode = {} refresh() end } )
		elseif mode.name == name and mode.kind == "delete" then
			insert( list, { text = name, ask = "Delete '" .. name .. "'?", ask_open = true, switch_back = true,
				callback = function() delete_config( name ) end,
				on_no = function() mode = {} refresh() end } )
		else
			local editable = name ~= PROTECTED
			insert( list, { type = "config", text = name, active = name == active, default = name == default,
				load = function() load_config( name ) end,
				rename = editable and function() mode = { name = name, kind = "rename" } refresh() end or nil,
				delete = editable and function() mode = { name = name, kind = "delete" } refresh() end or nil } )
		end
	end
	if #names == 0 then
		insert( list, { type = "info", text = tr['config_empty'] } )
	end
	if overwrite_name then
		local name = overwrite_name
		insert( list, { text = name, ask = tr['config_are_you_sure'], ask_open = true, switch_back = true,
			callback = function() create_config( name, true ) end,
			on_no = function() overwrite_name = nil refresh() end } )
	else
		new_row = new_row or { type = "input", text = "New config", placeholder = "+ New config: type name",
			confirm_label = "Create", dashed = true, switch_back = true,
			callback_input = function( s ) create_config( s ) end }
		insert( list, new_row )
	end
	insert( list, {} )
	insert( list, { text = tr['config_save_all'], callback = save_settings, switch_back = true } )
	insert( list, { text = tr['config_save_default'], callback = set_default, switch_back = true } )

	local desc = tr['config_current'] .. ': ' .. active .. ". " .. tr['config_what']
	return list, desc
end

local main_menu = function()
	mode = {}
	overwrite_name = nil
	Menu_open( Menu, { title = tr['config_menu'], rebuild = build_list, button_list = {} } )
end

return main_menu
