--Purpose: initiates autostart scripts here, depending on configuration.
--Note: Scripts here being executed both in game and in pre-game.

--Preloading values from table. You will face more of these preloads in other script files.
--This should increase speed of executing script at all trading off some RAM, because accessing locals & upvalues are much faster, than iterating and comparing with each hash from current table.
local ppr_require = ppr_require

local managers = managers
local tweak_data = tweak_data
local Global = Global
local backuper = backuper
local backup = backuper.backup
local hijack = backuper.hijack
local os_clock = os.clock
local io_open = ppr_io.open
local tab_insert = table.insert
local ppr_dofile = ppr_dofile
local pairs = pairs

local weapon_skins = tweak_data.blackmarket.weapon_skins

local NetworkMatchMakingSTEAM = NetworkMatchMakingSTEAM
local M_N_matchmake = managers.network.matchmake

local is_server = is_server()

local cfg = ppr_config
local togg_vars = togg_vars

if cfg.StraightToMainMenu then
	ppr_require('Trainer/addons/StraightToMainMenu')
end

if cfg.EnableDebug then
	ppr_require 'Trainer/addons/debugenable'
end

-- Fixes
if cfg.CheckLobbyHandler then
	ppr_require 'Trainer/addons/fixes/Check Lobby Handler'
end

if cfg.CheckMeleeAttack then
	ppr_require 'Trainer/addons/fixes/Check Melee Attack'
end

-- Tweaks
if cfg.armor_tweaks then
	ppr_require 'Trainer/addons/tweaks/Armor Tweaks/Armor Tweaks'
end

if cfg.vehicle_tweaks then
	ppr_require 'Trainer/addons/tweaks/Vehicle Tweaks/Vehicle Tweaks'
end

if cfg.iceaxe_tweaks then
	ppr_require 'Trainer/addons/tweaks/Melee Weapons/Iceaxe Tweaks'
end

if cfg.CAR4_tweaks then
	ppr_require 'Trainer/addons/tweaks/Primary Weapons/CAR4 Tweak'
end

if cfg.M79_tweaks then
	ppr_require 'Trainer/addons/tweaks/Primary Weapons/M79 Tweaks'
end

if cfg.Bernetti9mm_tweaks then
	ppr_require 'Trainer/addons/tweaks/Secondary Weapons/Bernetti 9mm Tweaks'
end

if cfg.ChinaPuff_tweaks then
	ppr_require 'Trainer/addons/tweaks/Secondary Weapons/China Puff Tweaks'
end

if cfg.Glock18c_tweaks then
	ppr_require 'Trainer/addons/tweaks/Secondary Weapons/Glock 18c Tweaks'
end

if cfg.Ace_tweaks then
	ppr_require 'Trainer/addons/tweaks/Throwable Weapons/Ace Tweaks'
end

if cfg.Bipod_Standing then
	ppr_require 'Trainer/addons/tweaks/General Weapon Tweaks/Bipod Standing'
end

if cfg.Gadget_Always_On then
	ppr_require 'Trainer/addons/tweaks/General Weapon Tweaks/Gadget Always On'
end

if cfg.projectiles_Tweaks then
	ppr_require 'Trainer/addons/tweaks/General Weapon Tweaks/projectiles Tweaks'
end

if cfg.Rocket_Jump then
	ppr_require 'Trainer/addons/tweaks/General Weapon Tweaks/Rocket Jump'
end

if cfg.Sentry_Gun_Tweaks then
	ppr_require 'Trainer/addons/tweaks/General Weapon Tweaks/Sentry Gun Tweaks'
end

if cfg.Shotgun_Physics then
	ppr_require 'Trainer/addons/tweaks/General Weapon Tweaks/Shotgun Physics'
end

if cfg.Weapon_Parts_Tweaks then
	ppr_require 'Trainer/addons/tweaks/General Weapon Tweaks/Weapon Parts Tweaks'
end

if cfg.FreeAssets then
	backup(backuper, 'MoneyManager.get_mission_asset_cost_by_id')
	function MoneyManager.get_mission_asset_cost_by_id()return
		0
	end
	for _, asset in pairs(tweak_data.crime_spree.assets) do
		asset.cost = 0
	end
end

if cfg.FreeBlackMarket then
	ppr_require 'Trainer/addons/FreeBlackMarket'
end

if cfg.FreePreplanning then
	ppr_require 'Trainer/addons/freepreplanning'
end

if cfg.FreeCrimeSpree then
	ppr_require 'Trainer/addons/freecrimespree'
end

if cfg.HostMatters and is_server then
	ppr_require 'Trainer/addons/hostchooseplan'
end

if cfg.NoDropinPause then
	ppr_require('Trainer/addons/nopause')
end

if cfg.NoStatsSynced then
	function NetworkAccountSTEAM.publish_statistics() end
end

if cfg.AllPerks then
	ppr_require 'Trainer/addons/all_perks'
end

if cfg.DisableAutoKick then
	Global.game_settings.auto_kick = false
end

if cfg.CrewUnlocker then
	ppr_require 'Trainer/addons/crew_unlocker'
end

if cfg.unlocked_aldstone_items then
	ppr_require 'Trainer/addons/unlock_aldstone_items'
end

if cfg.EnableJobFix then
	ppr_require 'Trainer/addons/jobfix'
end

if cfg.unlocked_hoxton then
	ppr_require 'Trainer/addons/unlock_hoxton'
end

if cfg.unlocked_arbiter then
	ppr_require 'Trainer/addons/unlock_arbiter'
end

if cfg.Extend_Inventory_Slots then
	ppr_require 'Trainer/addons/Extend_Inventory_Slots'
end

if cfg.DebugConsole then
	console.CreateConsole()
end

--Notices users, if crash happened.
if cfg.ExceptionsCrashDetect and managers.exception then
	ppr_require 'Trainer/menu/crashnoticer'
end

-- Enables Secret Skills to work
hijack(backuper, 'PlayerManager.aquire_default_upgrades', function(o, self, ...)
	local skills_path = "Trainer/configs/secret_skills/skills_config.lua"
	local f = io_open(skills_path, "r")
	if f then
		f:close()
		local _, secret_skills, ver = ppr_dofile(skills_path)
		if ver == 2 then
			for _, upgrade in pairs(secret_skills) do
				tab_insert(tweak_data.skilltree.default_upgrades, upgrade)
			end
		end
	end
	o(self, ...)
end)


if cfg.NoSkinMods then
	for _, skin in pairs(weapon_skins) do
		if skin.rarity ~= "legendary" then
			skin.default_blueprint = nil
		end
	end
end

--Requires user scripts
ppr_require 'Trainer/custom_auto'