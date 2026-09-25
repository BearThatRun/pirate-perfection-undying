-- Use all perk decks at once, excluding Negative Perks
-- Undying: a DLC perk deck only counts if you have that DLC. managers.dlc:is_dlc_unlocked
-- is the game's own check, and it also passes free DLC (tweak_data.dlc[id].free).
local M_dlc = managers.dlc
for _, specialization in pairs( tweak_data.skilltree.specializations ) do
	local deck_dlc = specialization.dlc
	if not deck_dlc or ( M_dlc and M_dlc:is_dlc_unlocked( deck_dlc ) ) then
		for _, tree in ipairs( specialization ) do
			if type( tree ) == "table" and tree.upgrades then
				for _, upgrade in ipairs( tree.upgrades ) do
--					if ( (not upgrade:find("loss")) and (not upgrade:find("penalty")) ) then -- Removes Negative Perks
						managers.upgrades:aquire( upgrade,false )
--					end
				end
			end
		end
	end
end
