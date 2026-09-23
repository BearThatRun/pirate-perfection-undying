--Purpose: Toggle crazy firerate.
--Author: baldwin
--x64 rewrite (Pirate Perfection Undying): the old version forced fire_mode() to 'auto' and replaced
--NewRaycastWeaponBase.trigger_held with a raw fire() for every weapon (NPC weapons included).
--That crashed the x64 game on the first shot. This version keeps the game's own fire path:
--  * no delay between shots for the local player's weapons (max one shot per frame)
--  * semi-auto weapons keep firing while the trigger is held (vanilla single_shot_autofire)

plugins:new_plugin('extreme_firerate')

VERSION = '1.1'

CATEGORY = 'character'

local backuper = backuper
local hijack = backuper.hijack
local restore = backuper.restore

local function is_local_player_weapon( weap_base )
	local setup = weap_base._setup
	local user_unit = setup and setup.user_unit
	return user_unit ~= nil and user_unit == managers.player:player_unit()
end

local function set_autofire_on_player_states( value )
	local ply = managers.player and managers.player:player_unit()
	if not ply or not alive(ply) then
		return
	end
	local states = ply:movement() and ply:movement()._states
	if not states then
		return
	end
	for _, state in pairs(states) do
		if type(state) == 'table' and state._single_shot_autofire ~= nil then
			state._single_shot_autofire = value
		end
	end
end

function MAIN()
	hijack(backuper, 'RaycastWeaponBase.update_next_shooting_time', function( o, self, ... )
		if not is_local_player_weapon(self) or self:gadget_overrides_weapon_functions() then
			return o(self, ...)
		end
		self._next_fire_allowed = self._unit:timer():time()
	end)

	hijack(backuper, 'PlayerStandard._get_input', function( o, self, ... )
		self._single_shot_autofire = true
		return o(self, ...)
	end)
end

function UNLOAD()
	restore(backuper, 'RaycastWeaponBase.update_next_shooting_time')
	restore(backuper, 'PlayerStandard._get_input')
	set_autofire_on_player_states(tweak_data.player.single_shot_autofire or Global.single_shot_autofire or false)
end

FINALIZE()
