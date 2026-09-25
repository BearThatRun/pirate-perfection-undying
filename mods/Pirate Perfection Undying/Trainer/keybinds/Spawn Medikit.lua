-- Spawn DoctorBag (BLT keybind)
-- Round 5: uses the game's own placement (use_doctor_bag), so it works as host and as client and uses
-- your upgrades. The old version called DoctorBagBase.spawn with arguments from an old game version.
if inGame() and isPlaying() and not inChat() then
	local ply = managers.player:player_unit()
	if alive(ply) and ply:equipment() then
		local ok, placed = pcall(ply:equipment().use_doctor_bag, ply:equipment())
		if not ok or not placed then
			show_hint("Can't place it here: aim at the floor or a wall close to you")
		end
	end
end
