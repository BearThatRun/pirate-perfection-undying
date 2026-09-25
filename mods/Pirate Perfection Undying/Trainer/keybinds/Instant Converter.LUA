-- INSTANT INTIMIDATE (BLT keybind)
-- Round 5: turns F6 'Instant intimidation' on/off (host only). The old keybind replaced the
-- enemy AI's surrender code with a copy that called functions that don't exist, which errors
-- as soon as a bot or another player intimidates someone.
if inGame() and isPlaying() and not inChat() then
	if not is_server() then
		show_hint( "Host only" )
		return
	end
	load_plugin( "Trainer/addons/interactions/" )( "instant_intimidation" )
	show_hint( plugins:g_loaded( "instant_intimidation" ) and "Instant intimidation ON" or "Instant intimidation OFF" )
end
