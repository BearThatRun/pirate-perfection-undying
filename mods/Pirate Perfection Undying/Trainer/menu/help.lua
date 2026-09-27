local ppr_require = ppr_require
local setmetatable = setmetatable
local ipairs = ipairs
local pairs = pairs
local tostring = tostring
local tab_insert = table.insert
local tab_sort = table.sort

ppr_require 'Trainer/tools/new_menu/menu'

local KeyInput = KeyInput
local tr = Localization.translate
local open_menu
do
	local Menu = Menu
	local open = Menu.open
	open_menu = function( ... )
		return open(Menu, ...)
	end
end

local main,credits,keybinds,cheatertag

-- Undying menu redesign (stage 4): Keybinds is a list of key rows read from the real key
-- config, Cheater tag and Credits are text pages. Back is the footer button / Backspace.

-- Script file (without .lua) -> { group, label }. Groups: 1 both, 2 main menu, 3 in a heist.
-- Files that open one menu in the main menu and another in a heist are listed twice.
local KNOWN = {
	{ "help", 1, "Help Menu" },
	{ "config_menu", 1, "Configuration Menu" },
	{ "tools", 1, "Tools Menu" },
	{ "music_menu", 1, "Music Menu" },
	{ "normalizer", 1, "Normalizer Menu" },
	{ "user_script", 1, "User script" },
	{ "main_menu-charmenu", 2, "Main pre-game Menu" },
	{ "jobmenu-stealthmenu", 2, "Job Menu" },
	{ "main_menu-charmenu", 3, "Character Menu" },
	{ "jobmenu-stealthmenu", 3, "Stealth Menu" },
	{ "troll_menu_key", 3, "Troll Menu" },
	{ "interactions", 3, "Interaction Menu" },
	{ "inventory_menu", 3, "Inventory Menu" },
	{ "equipment_menu", 3, "Equipment Menu" },
	{ "missionmenu", 3, "Mission Menu" },
	{ "mod_menu", 3, "Mod Menu" },
	{ "spawn_menu", 3, "Spawn Menu" },
	{ "instant_win", 3, "Instant Win" },
	{ "carrystacker", 3, "Carry Stacker Control" },
	{ "xray", 3, "X-Ray" },
	{ "replenish", 3, "Replenish" },
	{ "place_equipment", 3, "Place equipment" },
	{ "teleport", 3, "Teleport" },
	{ "slowmotion", 3, "Slow motion" },
	{ "spawngagepackage", 3, "Spawn gage package" },
}

-- "page up" -> "Page Up", "f1" -> "F1"
local function key_name( key )
	key = tostring( key )
	return ( key:gsub( "(%a)([%w_]*)", function( a, b ) return a:upper() .. b end ) )
end

keybinds = function()
	local fn = rawget( KeyInput, "filenames" ) or {}
	local groups = { {}, {}, {} }
	local known = {}
	for _, k in ipairs( KNOWN ) do
		known[ k[1] ] = true
		local key = rawget( fn, k[1] )
		if key then
			tab_insert( groups[ k[2] ], { type = "kv", key = key_name( key ), text = k[3] } )
		end
	end
	-- keys the player added to keyconfig.lua that aren't in the list above
	local extra = {}
	for file, key in pairs( fn ) do
		if not known[ file ] then
			tab_insert( extra, { type = "kv", key = key_name( key ), text = file } )
		end
	end
	tab_sort( extra, function( a, b ) return a.text < b.text end )
	for _, row in ipairs( extra ) do
		tab_insert( groups[3], row )
	end
	-- the Sequencer binds 9 once it has been opened (Trainer/addons/tools/sequence_menu.lua)
	tab_insert( groups[3], { type = "kv", key = "9", text = "Reopen Sequencer Menu" } )

	local list = {}
	local names = { "Both", "Main menu", "In a heist" }
	for i, g in ipairs( groups ) do
		if #g > 0 then
			tab_insert( list, { type = "header", text = names[i] } )
			for _, row in ipairs( g ) do
				tab_insert( list, row )
			end
		end
	end
	open_menu( {
		title = tr.help_keybinds,
		description = "Carry stacker, X-ray, replenish, teleport, slow motion and equipment spawning have no default key. Set them in Options > Mod Keybinds.",
		button_list = list,
	} )
end

-- Text with blank lines between paragraphs -> list of paragraphs (single line breaks stay)
local function paragraphs( text )
	local out = {}
	text = tostring( text or "" ):gsub( "\r", "" )
	for para in ( text .. "\n\n" ):gmatch( "(.-)\n%s*\n" ) do
		para = para:gsub( "^%s+", "" ):gsub( "%s+$", "" )
		if para ~= "" then
			tab_insert( out, para )
		end
	end
	return out
end

cheatertag = function()
	open_menu( { title = tr.help_cheatertag, body = paragraphs( tr.help_cheatertag_desc ), button_list = {} } )
end

credits = function()
	local body = { "x64 port (Pirate Perfection Undying): BearThatRun" }
	for _, p in ipairs( paragraphs( tr.help_credits_desc ) ) do
		tab_insert( body, p )
	end
	open_menu( { title = tr.help_credits, body = body, button_list = {} } )
end

main = function()
	open_menu( {
		title = tr.help_title,
		description = tostring( tr.help_desc ):gsub( "\n", " " ),
		button_list = {
			{ text = tr.help_keybinds, callback = keybinds, menu = true },
			{ text = tr.help_cheatertag, callback = cheatertag, menu = true },
			{ text = tr.help_credits, callback = credits, menu = true },
		},
	} )
end

return main
