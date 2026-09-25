--Purpose: Instantly win any game, host only. Also secures the most valuable bags up to the
--map's limit and 50 small loot, so the payout is bigger.
--Round 5: the old file only returned the function (a BLT keybind ignores that, so the key did
--nothing) and picked a price category instead of a real bag.

if ( not GameSetup ) then
	return
end
if not ( inGame() and isPlaying() and not inChat() ) then
	return
end
if not is_server() then
	show_hint( "Instant win: host only" )
	return
end

local managers = managers
local M_loot = managers.loot
local M_money = managers.money

local function best_bag()
	local best_val, best = -1, nil
	local small_loot = tweak_data.carry.small_loot or {}
	for carry_id, data in pairs( tweak_data.carry ) do
		if type( data ) == "table" and data.bag_value and data.name_id and not data.is_vehicle
			and not small_loot[ carry_id ] and data.type ~= "being" then
			local ok, val = pcall( M_money.get_bag_value, M_money, carry_id, 1 )
			if ok and type( val ) == "number" and val > best_val then
				best_val, best = val, carry_id
			end
		end
	end
	return best or "gold"
end

local level = Global.game_settings.level_id
local bag_limit = level and tweak_data.levels[ level ] and tweak_data.levels[ level ].max_bags or 20
local bag = best_bag()
for i = M_loot:get_secured_bonus_bags_amount() + 1, bag_limit do
	M_loot:secure( bag, 1, true )
end
for i = 1, 50 do
	M_loot:secure_small_loot( "gen_atm", 3 )
end

local num_winners = managers.network:session():amount_of_alive_players()
managers.network:session():send_to_peers( "mission_ended", true, num_winners )
game_state_machine:change_state_by_name( "victoryscreen", { num_winners = num_winners, personal_win = true } )
