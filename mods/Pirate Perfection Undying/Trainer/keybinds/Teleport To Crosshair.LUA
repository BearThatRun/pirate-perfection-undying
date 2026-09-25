-- TELEPORT/PENETRATE SCRIPT (BLT keybind)
-- Round 5: keeps your view direction (it used to reset it to a fixed angle).
if inGame() and isPlaying() and not inChat() and not InOverlay() then
	local ply = managers.player:player_unit()
	local ray = get_ray( ppr_config.TeleportPenetrate )
	if ray and alive( ply ) then
		managers.player:warp_to( ray.hit_position, ply:camera():rotation() )
		show_mid_text("Teleport","Penetrative",0.25)
		beep()
	end
end
