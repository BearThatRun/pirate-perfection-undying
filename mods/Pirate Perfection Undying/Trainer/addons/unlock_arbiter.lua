-- Unlock the Arbiter without doing Gage's challenges.
-- Undying: still needs the Gage Spec Ops Pack. can_progress() is the game's own ownership check.
backuper:backup('TangoManager.has_unlocked_arbiter')
function TangoManager:has_unlocked_arbiter()
	if not self:can_progress() then
		return nil
	end
	return true
end
