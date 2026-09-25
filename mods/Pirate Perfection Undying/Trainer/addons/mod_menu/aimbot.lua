--Aimbot script
--Author: Main code: Simplity, fixes: **** & baldwin

local plugins = plugins
plugins:new_plugin('aimbot')

CATEGORY = 'mods'

VERSION = '1.0'

local managers = managers
local get_ray = get_ray
local ppr_config = ppr_config
local pmanager = managers.player
local pairs = pairs
local mvector3 = mvector3
local Rotation = Rotation
local alive = alive

local mouse = Input:mouse()
local mouse_down = mouse.down
local rmb = Idstring("1")

local get_safe_ray, check_wall, auto_shoot, auto_aim, aimbot_update

--Private methods
function get_safe_ray()
	local col_ray = get_ray(nil, "enemies")
	local unit = col_ray and col_ray.unit
	if alive( unit ) then
		local team = unit:movement():team()
		local team_id = team.id
		local in_slot = unit:in_slot( managers.slot:get_mask( "enemies" ) )
		
		if ( team_id == "mobster1" or team_id == "law1" ) and in_slot then
			return col_ray
		end
	end
	
	return nil
end

function check_wall( _unit )
	local unit	
	if _unit then
		unit = _unit
	else
		local col_ray = get_safe_ray()
		unit = col_ray and col_ray.unit
	end
	local check = unit and ( ppr_config.ShootThroughWalls and true or not unit:raycast( "ray", unit:movement():m_com(), managers.viewport:get_current_camera_position(), "slot_mask", managers.slot:get_mask( "world_geometry" ), "report" ) )
	return check
end

function auto_shoot( player )
	local camera = player:camera()
	local equipped_unit_base = player:inventory():equipped_unit():base()
	local _, ammo = equipped_unit_base:ammo_info()
	
	if ppr_config.AimbotInfAmmo then
		equipped_unit_base:replenish()
	end
	
	if ammo == 0 then
		return
	end
	
	local damage_mul = ppr_config.AimbotDamageMul or equipped_unit_base:damage_multiplier()
	equipped_unit_base:trigger_held( camera:position(), camera:forward(), damage_mul, nil, 0, 0, 0 )
	managers.rumble:play("weapon_fire")
	camera:play_shaker( "fire_weapon_rot", 1 )
	camera:play_shaker( "fire_weapon_kick", 1, 1, 0.15 )
	equipped_unit_base:tweak_data_anim_play( "fire", 20)
	managers.hud:set_ammo_amount( equipped_unit_base:selection_index(), equipped_unit_base:ammo_info() )
end

function auto_aim( player )
	-- Round 9: aim by setting the first-person camera's spin/pitch (what the mouse changes).
	-- The old code forced the camera and the arms to one bare rotation after the game's own
	-- update: the arms lost their stance offset (gun at a weird angle in first person) and the
	-- view snapped back when the target was lost. It also took the FIRST enemy in the list,
	-- even one behind you; now it takes the one closest to your crosshair.
	local camera = player:camera()
	local cam_base = camera and camera:camera_unit() and camera:camera_unit():base()
	if not cam_base or not cam_base.set_spin or cam_base._limits then
		return -- no camera, or a state with view limits (bipod, turret, vehicle)
	end
	local cam_pos = camera:position()
	local cam_fwd = camera:forward()
	local max_dist = ppr_config.MaxAimDist or 5000
	local best_target, best_dot
	for _,data in pairs( managers.enemy:all_enemies() ) do
		local u = data.unit
		if alive( u ) then
			local team_id = u:movement():team().id
			if team_id == "mobster1" or team_id == "law1" then
				local u_pos = u:position()
				if mvector3.distance( player:position(), u_pos ) < max_dist and check_wall( u ) then
					local char_damage = u:character_damage()
					local body = char_damage and char_damage._head_body_name and u:body( char_damage._head_body_name )
					local target = body and body:position() or u_pos
					local dir = target - cam_pos
					mvector3.normalize( dir )
					local dot = mvector3.dot( dir, cam_fwd )
					if not best_dot or dot > best_dot then
						best_dot = dot
						best_target = target
					end
				end
			end
		end
	end
	if best_target then
		local polar = ( best_target - cam_pos ):to_polar()
		cam_base:set_spin( polar.spin % 360 )
		cam_base:set_pitch( math.clamp( polar.pitch, -85, 85 ) )
	end
end

function aimbot_update()
	if not ppr_config.RightClick or mouse_down(mouse, rmb) then
		local player = pmanager:player_unit()
		if not alive( player ) then
			return
		end

		if ppr_config.AimMode ~= 2 and check_wall() then
			auto_shoot( player )
		end

		if ppr_config.AimMode ~= 1 then
			auto_aim( player )
		end
	end
end

local function start_aimbot()
	local player = pmanager:player_unit()
	if alive( player ) then
		player:inventory():equipped_unit():base()._can_shoot_through_shield = true
	end

	if ppr_config.ShootThroughWalls and not plugins:g_loaded( "shoot_through_walls" ) then
		plugins:ppr_require( 'Trainer/addons/charmenu/shoot_through_walls', true )
	end
	
	RunNewLoopIdent("aimbot", aimbot_update)
end

local function stop_aimbot()
	StopLoopIdent( "aimbot" )
end

function MAIN()
	start_aimbot()
end

function UNLOAD()
	stop_aimbot()
end

FINALIZE()