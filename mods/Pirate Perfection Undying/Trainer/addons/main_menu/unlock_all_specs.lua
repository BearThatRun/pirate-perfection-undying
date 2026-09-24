--Unlocks all specializations.
--Author: ThisJazzman
--Undying: the old version gave points for 19 perk decks (13700 each). The game has more decks
--now, so the last ones (Hacker, Leech) ran out of points. The cost is now read from the game.
--Decks from a DLC you don't own stay locked (the game itself refuses to spend points on them).

local managers = managers
local M_skilltree = managers.skilltree
local tweak_data = tweak_data

local G_specs = Global.skilltree_manager.specializations
local specs = tweak_data.skilltree.specializations
local spend_spec_points = M_skilltree.spend_specialization_points

local cost_per_tree = {}
local total = 0
for tree, tiers in ipairs( specs ) do
	local cost = 0
	for _, tier in ipairs( tiers ) do
		cost = cost + ( tier.cost or 0 )
	end
	cost_per_tree[tree] = cost
	total = total + cost
end

G_specs.total_points = total
G_specs.points = total

for tree, cost in ipairs( cost_per_tree ) do
	if G_specs[tree] and cost > 0 then
		spend_spec_points( M_skilltree, cost, tree )
	end
end
