-- Always dismember cops
-- Undying rewrite: the old version passed "head"/"body" as plain strings where the game
-- needs an Idstring (error on every death) and replaced _check_special_death_conditions
-- with an old copy. Now: every enemy that dies loses its head or upper body, if its model
-- has that dismember sequence (not every enemy model has one). Local visual only.

plugins:new_plugin('always_dismember')

VERSION = '2.0'

local backuper = backuper
local random = math.random

local parts = { Idstring("head"), Idstring("body") }

local function try_dismember( self, attack_data )
	local dmg = self._unit:damage()
	if not dmg then
		return
	end
	local part = parts[ random( #parts ) ]
	local seq = part == parts[1] and "dismember_head" or "dismember_body_top"
	if not dmg:has_sequence( seq ) then
		part = part == parts[1] and parts[2] or parts[1]
		seq = part == parts[1] and "dismember_head" or "dismember_body_top"
		if not dmg:has_sequence( seq ) then
			return
		end
	end
	self:_dismember_body_part( { body_name = part } )
end

function MAIN()
	backuper:hijack('CopDamage.die', function( o, self, attack_data, ... )
		if not self._dead then
			pcall( try_dismember, self, attack_data )
		end
		return o( self, attack_data, ... )
	end)
end

function UNLOAD()
	backuper:restore('CopDamage.die')
end

FINALIZE()
