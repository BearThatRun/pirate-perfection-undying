-- No bag cooldown
-- Author: Simplity

plugins:new_plugin('no_bag_cooldown')

VERSION = '1.0'

CATEGORY = 'character'

function MAIN()
	backuper:backup('PlayerManager.carry_blocked_by_cooldown')
	function PlayerManager.carry_blocked_by_cooldown() return false end 
end

function UNLOAD()
	backuper:restore('PlayerManager.carry_blocked_by_cooldown')
end

FINALIZE()