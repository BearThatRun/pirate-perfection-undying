--  Authors:  Configuration method by baldwin and ThisJazzman, menu by Davy Jones
--  Purpose:  Change base options in the game
local insert = table.insert
local pairs = pairs
local round = math.round
local len = string.len
local size = table.size
local sub = string.sub
local type = type
local unpack = unpack

local managers = managers
local M_experience = managers.experience
local M_localization = managers.localization

local T_economy = tweak_data.economy

local ApplyConfigExtension = ApplyConfigExtension
local rlist_files = rlist_files

local tr = Localization.translate

local Menu = Menu
local Menu_open = Menu.open

local togg_vars = togg_vars
local ppr_config = ppr_config

local main_menu

-- Undying round 11: Back goes one level up. Every submenu used to get back = main_menu,
-- so Back from e.g. Fixes & Tweaks > Tweaks > Weapon Tweaks jumped to the top.
-- Each submenu now gets the function that reopens the menu it was opened from.
local is_legacy

local prefix = "base_"

local options = {
	{name = "General_Sub", desc = true, sub = {
		{name = "Crosshair"},
		{name = "NoStatsSynced"},
		{name = "AllPerks"},
		{name = "Extend_Inventory_Slots"},
		{},
		{name = "FreeBlackMarket"},
		{name = "FreeAssets"},
		{name = "FreePreplanning"},
		{name = "FreeCrimeSpree"},		
		{},
		{name = "StraightToMainMenu"},
		{name = "NoDropinPause"},
		{name = "HostMatters", host = true},
		{name = "DisableAutoKick", host = true},
		{},
		{name = "ReduceDetectionLevel"},
	}},
	{name = "Unlocker_Sub", desc = true, sub = {
		{name = "unlocked_hoxton"},
		{name = "unlocked_arbiter"},
		{name = "unlocked_aldstone_items"},
		{name = "CrewUnlocker"},
		{name = "NoSkinMods"},
	}},
	{name = "Anticheat_Sub", desc = true, sub = {
		{name = "ControlCheats", desc = true, choice = {
			{"base_ControlCheats_1", 1},
			{"base_ControlCheats_false", false},
			{"base_ControlCheats_2", 2},
		}},
	}},
	{name = "Equipment_Sub", desc = true, sub = {
		{name = "far_placements"},
		{},
		{name = "equipment_place_key", type = "key"},
	}},
	{name = "Misc_Sub", desc = true, sub = {
		{name = "LaserColor", lasercolor = true, disable = true},
		{},
		{name = "SecureAll"},
		{name = "NoCivilianPenality"},
		{},
		{name = "NoInvisibleWalls", host = true},
		{name = "RestartProMissions", host = true},
		{name = "RestartJobs", host = true},
		{name = "NoEscapeTimer", host = true},
		{},
		{name = "DontFreezeRagdolls"},
		{name = "DontDisposeRagdolls"},
	}},
	{name = "flying_sub", desc = true, sub = {
		{name = "FreeFlightTeleport"},
		{},
		{name = "NoClipSpeed", type = "slider", max = 50},
		{},
		{name = "TeleportPenetrate"},
	}},
	{name = "KillAll_sub", desc = true, sub = {
		{name = "KillAllIgnoreTied"},
		{},
		{name = "KillAllIgnoreCivilians"},
		{},
		{name = "KillAllIgnoreEnemies"},
		{},
		{name = "KillAllTouchCameras"},
	}},
	{name = "character_sub", desc = true, sub = {
		{},
		{name = "JumpHeightMultiplier", type = "slider", max = 100},
		{},
		{},
		{},
		{name = "RunSpeed", type = "slider", max = 500},
		{},
	}},
	{name = "job_sub", desc = true, sub = {
		-- Undying 4b: the value is the game's difficulty id (the old list saved "Overkill" etc.,
		-- which the Job Menu passed on as a difficulty id)
		{name = "jobmenu_def_difficulty", choice = {
			{"Easy", "easy"},
			{"Normal", "normal"},
			{"Hard", "hard"},
			{"Very Hard", "overkill"},
			{"Overkill", "overkill_145"},
			{"Mayhem", "easy_wish"},
			{"Deathwish", "overkill_290"},
			{"One Down", "sm_wish"},
		}},
		{},
		{name = "jobmenu_singleplayer"},
		{},
		{name = "EnableJobFix"},
	}},
	{name = "Spawn_sub", desc = true, sub = {
		{name = "SpawnUnitsAmount", type = "slider", max = 100},
		{},
		{name = "SpawnPos", choice = {
			{"base_SpawnPos_ray", "ray"},
			{"base_SpawnPos_spawn_point", "spawn_point"},
			{"base_SpawnPos_random_spawn_point", "random_spawn_point"},
		}},
		{},
		{name = "SpawnUnitKey", type = "key"},
	}},
	{name = "inventory_sub", desc = true, sub = {
		{name = "rain_bags_amount", type = "slider", max = 1000},
		{name = "SpawnBagsAmount", type = "slider", max = 100},
		{name = "SpawnBagKey", type = "key"},
	}},
	{name = "slow_sub", desc = true, sub = {
		{name = "SmSpeed", type = "slider", max = 100},
		{name = "SmSlowPlayer"},
		{},
	}},
	{name = "xray_sub", desc = true, sub = {
		{name = "xray_Cams"},
		{name = "xray_CamsCol", color_xray = true},
		{},
		{name = "xray_Civ"},
		{name = "xray_CivCol", color_xray = true},
		{name = "xray_CivKeyCol", color_xray = true},
		{},
		{name = "xray_Cops"},
		{name = "xray_CopsCol", color_xray = true},
		{name = "xray_CopsKeyCol", color_xray = true},
		{name = "xray_SpecialCol", color_xray = true},
		{name = "xray_SniperCol", color_xray = true},
		{name = "xray_Friendly", color_xray = true},
		{},
		{name = "xray_Items"},
	}},
	{name = "aimbot_sub", desc = true, sub = {
		{name = "AimMode", choice = {
			{"base_AimMode_2", 2},
			{"base_AimMode_3", 3},
			{"base_AimMode_1", 1},
		}},
		{name = "RightClick"},
		{name = "AimbotInfAmmo"},
		{name = "ShootThroughWalls"},
		{name = "MaxAimDist", type = "slider", max = 10000},
		{name = "AimbotDamageMul", type = "slider", max = 100},
	}},
	{name = "Debug_Sub", desc = true, sub = {
		{name = "DebugConsole"},
		{},
		{name = "DebugDramaDraw"},
		{name = "DebugStateDraw"},
		{},
		{name = "DebugAdditionalEsp"},
		{name = "DebugMissionElements"},
		{name = "DebugElementsAdditional"},
		{},
		{name = "EnableDebug"},
		{},
		{name = "LegacyMenu", forceout = false},
	}},
	{name = "Fixes_Tweaks_Sub", desc = true, sub = {
		{name = "Fixes_Sub", desc = true, sub = {
			{name = "CheckLobbyHandler"},
			{name = "CheckMeleeAttack"},
		}},
		{name = "Tweaks_Sub", desc = true, sub = {
			{name = "armor_tweaks_Sub", desc = true, sub = {
				{name = "armor_tweaks"},
			},},
			{name = "vehicle_tweaks_Sub", desc = true, sub = {
				{name = "vehicle_tweaks"},
			},},
			{name = "weapon_tweaks_Sub", desc = true, sub = {
				{name = "melee_weapons_tweaks_Sub", desc = true, sub = {
				{name = "iceaxe_tweaks"},
			},},
			{name = "primary_weapons_tweaks_Sub", desc = true, sub = {
				{name = "CAR4_tweaks"},
				{name = "M79_tweaks"},
			},},
			{name = "secondary_weapons_tweaks_Sub", desc = true, sub = {
				{name = "Bernetti9mm_tweaks"},
				{name = "ChinaPuff_tweaks"},
				{name = "Glock18c_tweaks"},
			},},
			{name = "throwable_weapons_tweaks_Sub", desc = true, sub = {
				{name = "Ace_tweaks"},
			},},
			{name = "general_weapons_tweaks_Sub", desc = true, sub = {
				{name = "Bipod_Standing"},
				{name = "Gadget_Always_On"},
				{name = "projectiles_Tweaks"},
				{name = "Rocket_Jump"},
				{name = "Sentry_Gun_Tweaks"},
				{name = "Shotgun_Physics"},
				{name = "Weapon_Parts_Tweaks"},
			},},
	},}, },}, },},
	{name = "custom_safehouse_Sub", desc = true, sub = {
		{name = "SafeHouseDoors"},
		{name = "SafeHouseInvest"},
		{name = "SafeHouseInvestAmt", type = "multi_choice", choices = function()
			local data = {}
			for i = 1, 7 do
				insert(data, {text = M_experience:cash_string(100 * (10^i)), value = i})
			end
			return data
		end},
	}},
}

local function get_value(id)
	local pre_id = prefix..id
	return (togg_vars[pre_id] ~= nil and togg_vars[pre_id]) or (togg_vars[pre_id] == nil and ppr_config[id])
end

local function config_edit(id, val, back)
	val = val == nil and not get_value(id) or val ~= nil and (val ~= "" and val or false)
	togg_vars[prefix..id] = val
	if back then
		if type(back) == "function" then
			back()
		else
			main_menu()
		end
	end
end

local create_item, create_sub

local c_tab = {"R", "G", "B"}

-- Colour options (laser, X-ray): shown as one colour row with R / G / B sliders (menu redesign).
-- false in a channel = colour turned off.
local function color_row(name, text)
	return {
		text = text,
		type = "rgb",
		get_rgb = function()
			local out = {}
			for i, c in pairs(c_tab) do
				local v = get_value(name..c)
				out[i] = type(v) == "number" and v or 0
			end
			return out
		end,
		set_rgb = function(ci, v)
			for i, c in pairs(c_tab) do
				local pre = prefix..name..c
				if type(get_value(name..c)) ~= "number" then
					togg_vars[pre] = 0
				end
				if i == ci then
					togg_vars[pre] = v
				end
			end
		end,
	}
end

create_item = function(opt, parent)
	local name = opt.name
	if not name then
		return {}
	end
	local pre_name = prefix..name
	local is_color = opt.lasercolor or opt.color_xray
	if togg_vars[pre_name] == nil and not opt.sub and not is_color then
		togg_vars[pre_name] = ppr_config[name]
	end
	local label = (opt.disp or is_legacy and not (opt.sub or opt.notlegacy) and name or tr[pre_name])..(opt.host and " "..tr.host_only or "")
	if is_color then
		return color_row(name, label)
	end
	local opt_val = not opt.sub and get_value(name)
	if opt.type == "key" then
		-- design "key": press the row, then the key
		return {
			text = label,
			type = "key",
			key_value = opt_val or nil,
			key_callback = function(k) config_edit(name, k) end,
			switch_back = true,
		}
	end
	if opt.choice then
		local data, index = {}, 1
		for i, c in pairs(opt.choice) do
			insert(data, {text = tr[c[1]] ~= c[1] and tr[c[1]] or c[1], value = c[2]})
			if c[2] == opt_val then
				index = i
			end
		end
		return {
			text = label,
			type = "multi_choice",
			name = name,
			multi_choice_data = data,
			index = index,
			multi_callback = config_edit,
			switch_back = true,
		}
	end
	local is_slider = opt.type == "slider"
	local is_multi = opt.type == "multi_choice"
	local is_sub = opt.sub
	local is_toggle = not is_sub and not opt.type
	return {
		text = label,
		type = (is_toggle and "toggle") or opt.type or nil,
		name = is_multi and name or nil,
		toggle = (is_toggle and pre_name) or nil,
		slider_data = is_slider and {name = pre_name, value = opt_val, max = opt.max} or nil,
		callback = (is_toggle and config_edit) or (is_sub and create_sub) or nil,
		multi_callback = is_multi and config_edit or nil,
		data = (is_toggle and name) or (is_sub and {pre_name, opt, parent}) or nil,
		multi_choice_data = is_multi and opt.choices() or nil,
		value = is_multi and opt_val or nil,
		switch_back = not opt.forceout and (is_toggle or is_slider or is_multi) or nil,
		menu = is_sub or nil,
	}
end

-- Settings changed in this menu and not saved yet (the Save bar counts them)
local function count_changes()
	local n = 0
	local pre_len = len(prefix)
	for id, val in pairs(togg_vars) do
		if sub(id, 1, pre_len) == prefix and id ~= prefix.."menu_save" then
			local cur = rawget(ppr_config, sub(id, pre_len + 1))
			if (val or false) ~= (cur or false) then
				n = n + 1
			end
		end
	end
	return n
end

local function save_config()
	local pre_len = len(prefix)
	for id, val in pairs(togg_vars) do
		local check = sub(id, 1, pre_len)
		if check == prefix and id ~= prefix.."menu_save" then
			id = sub(id, pre_len + 1)
			ppr_config[id] = val
		end
	end
	ppr_config()
	ppu_feedback("Saved. Restart the game to apply.")
end

-- design: one Save bar at the bottom of every PPR Setup page (no Save rows)
local save_bar = {text = "Save, then restart the game to apply", count = count_changes, save = save_config}

create_sub = function(pre_id, menu, parent)
	local reopen = function() create_sub(pre_id, menu, parent) end
	local opts = menu.sub
	if type(opts) == "function" then
		opts = opts()
	end
	local data = {}
	for _, opt in pairs(opts) do
		insert(data, create_item(opt, reopen))
		if opt.lasercolor and opt.disable then
			local name = opt.name
			insert(data, {text = "Disable laser color", switch_back = true, callback = function()
				for _, c in pairs(c_tab) do
					togg_vars[prefix..name..c] = false
				end
				ppu_feedback("Laser color off (save to keep it)")
			end})
		end
	end

	local desc = menu.desc and tr[pre_id.."_desc"] or nil
	if pre_id == prefix.."menu" then
		desc = "Every option here needs Save, then a game restart."
	end
	Menu_open(Menu, {title = tr[pre_id]..(menu.host and "    "..tr.host_only or ""), description = desc, button_list = data, back = parent or main_menu, save_bar = save_bar})
end

is_legacy = get_value("LegacyMenu")
togg_vars[prefix.."menu_save"] = true
local base_name = prefix.."menu"
main_menu = function() create_sub(base_name, {name = base_name, sub = options}) end
main_menu()