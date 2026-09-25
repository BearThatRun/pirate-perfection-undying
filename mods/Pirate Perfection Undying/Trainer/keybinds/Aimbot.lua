-- AIMBOT (BLT keybind)
-- Round 5: turns the F11 AimBot on/off. The old keybind installed a second aimbot whose
-- on-switch was never set, so pressing the key did nothing.
if inGame() and isPlaying() and not inChat() then
	load_plugin( "Trainer/addons/mod_menu/" )( "aimbot" )
	show_hint( plugins:g_loaded( "aimbot" ) and "AimBot ON (hold right mouse)" or "AimBot OFF" )
end
