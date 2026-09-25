-- WARP TO BULLET (BLT keybind)
-- Round 5: the first press starts remembering where your bullets hit; every press after that
-- teleports you to the last hit. The old version passed your position as the rotation.
if inGame() and isPlaying() and not inChat() and not InOverlay() then
	if not _ppu_bullet_hooked then
		_ppu_bullet_hooked = true
		local orig = InstantBulletBase.on_collision
		function InstantBulletBase:on_collision( col_ray, weapon_unit, user_unit, ... )
			if user_unit == managers.player:player_unit() and col_ray and col_ray.hit_position then
				_lastBullet = mvector3.copy( col_ray.hit_position )
			end
			return orig( self, col_ray, weapon_unit, user_unit, ... )
		end
	end
	local ply = managers.player:player_unit()
	if _lastBullet and alive( ply ) then
		managers.player:warp_to( _lastBullet, ply:camera():rotation() )
		show_mid_text("To Bullet","Teleport",0.25)
		beep()
	else
		show_hint("Shoot somewhere first, then press again to teleport there")
	end
end
