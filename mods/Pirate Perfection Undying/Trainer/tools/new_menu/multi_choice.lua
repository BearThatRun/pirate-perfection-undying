--Menu component. Shows extra menu with variants
--Author: Simplity
--Undying redesign: state only. The row (◂ value ▸) is drawn by menu.lua.

local pairs = pairs

local MultiChoice = class()

local function index_from_value(self, val)
	for i, data in pairs( self.data ) do
		if data.value == val then
			return i
		end
	end
end

function MultiChoice:init( panel, button )
	self.panel = panel
	self.button = button
	self.data = button.multi_choice_data or {}
	self.name = button.name
	self.callback = button.multi_callback
	local val = button.value
	if (not val) then
		--Or get value from function. This way comfortable for dynamic values
		local func = button.value_func
		if (func) then
			val = func()
		end
	end
	self.index = button._ppu_index or ( val and index_from_value( self, val ) or button.index ) or 1
end

function MultiChoice:text()
	local entry = self.data[ self.index ]
	return entry and tostring( entry.text or "" ) or ""
end

function MultiChoice:previous_option()
	local n = #self.data
	if n == 0 then return end
	local new_index = self.index - 1
	self:change_option( new_index < 1 and n or new_index )
end

function MultiChoice:next_option()
	local n = #self.data
	if n == 0 then return end
	local new_index = self.index + 1
	self:change_option( self.data[ new_index ] and new_index or 1 )
end

function MultiChoice:change_option( index )
	local data = self.data[ index ]
	self.index = index
	self.button._ppu_index = index
	local clbk = self.callback
	if clbk and data then
		clbk( self.name, data.value )
	end
	if self.on_change then
		self.on_change()
	end
end

function MultiChoice:close()
end

local G = getfenv(0)
G.MultiChoice = MultiChoice
