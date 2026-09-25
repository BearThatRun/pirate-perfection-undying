--Translation class by baldwin
--Purpose: Translate text using text ids
--Instructions: localisation file must look like this: { text_id = 'Localised string', text_id2 = 'Another string', ... }
--Once any language translation was implemented, add the name of language txt file into available_languages list
--To get text of your language from id, use next format: localizator.translate[text_id]

--Uncommon errors and their solutions:
--If console says that here is unknown symbol before some other unicode symbol, change translation's encoding to ASCII (faced in turkish translation)

--For writing translation files I suggest to use ZeroBrane editor and temporary change txt extension to lua to easier detect mistakes.

local loadstring_execute = loadstring_execute
local setmetatable = setmetatable
local m_log_error = m_log_error
local m_log_vs = m_log_vs
local next = next
local io_open = ppr_io.open
local string = string
local str_format = string.format
local ppr_config = ppr_config

local DEFAULT_LANGUAGE = 'english'
--[[
local available_languages = {
	english = true,
	russian = true,
	german = true,
	portuguese = true,
	turkish = true,
	italian = true,
	spanish = true,
}
]]

local localizator = class()

local init, mt_table, text, load_language, change_language, _load_language

init = function(self, language)
	self.lan = language or DEFAULT_LANGUAGE
	self.translate = {}
	load_language( self )
end
localizator.init = init

mt_table = function(self)
	local default = self.default_lan
	if ( not default ) then
		default = _load_language(DEFAULT_LANGUAGE)
		self.default_lan = default
	end
	
	local mt = {
		__index = 
		function(_,k)
			local language = self.lan
			if language ~= DEFAULT_LANGUAGE then
				local def_str = default[k]
				if ( def_str ) then
					m_log_error('localizator.translate','definition for',k,'isn\'t found in', language, 'translation. Using', DEFAULT_LANGUAGE, 'string instead')
					return def_str
				end
			end
			m_log_error('localizator.translate','definition for',k,'isn\'t found!')
			return k --If no localisation string in english localisation was found, then table returns id, that was queried.
		end
	}
	setmetatable(self.translate, mt)
end
localizator.mt_table = mt_table

_load_language = function( language )
	local path = 'Trainer/translations/'..language..'.txt'
	local f = io_open(path,'rb')
	if f then
		local contents = f:read('*all')
		f:close()
		if contents then
			return loadstring_execute('return '..contents, {}, path) or {}
		end
	end
end
localizator._load_language = _load_language

text = function( self, id, ...)
	return str_format(self.translate[id], ...)
end
localizator.text = text

--Tries to load language inputed into "lan" key.
--Returns true, if language exists and it was loaded successfully.
load_language = function( self )
	local language = self.lan
	local result = _load_language( language )
	if ( result ) then
		self.translate = result
	end
	mt_table( self )
	if not next(self.translate) then
		m_log_error('localizator:load_language()','Localization failed to load or empty')
		if language ~= DEFAULT_LANGUAGE then
			m_log_vs('Loading', DEFAULT_LANGUAGE, 'localization.')
			change_language(self, DEFAULT_LANGUAGE)
		end
		return false
	end
	return true
end
localizator.load_language = load_language

change_language = function( self, language, saveme )
	self.lan = language
	
	if load_language( self ) and saveme then
		--Average solution. What if ppr_config have changes user don't want to accept ?
		--Will be great to implement function, that change only 1 value
		ppr_config.Language = language
		ppr_config()
	end
end
localizator.change_language = change_language

return localizator