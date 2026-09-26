-- Undying menu drawing helpers (redesign): text in Barlow Semi Condensed drawn from glyph atlases,
-- rounded boxes, rings, circles, fades and the window shadow drawn from a shape atlas.
-- The game's GUI can only draw square boxes and its own fonts, so both come from textures
-- (Assets/guis/textures/ppu/*.png, loaded by BeardLib from main.xml).
-- If those textures are missing, text falls back to the game font and shapes to square boxes.

ppr_require 'Trainer/tools/new_menu/ppu_assets'

local A = PPU_ASSETS
local SC = A.scale
local S = A.shapes
local SHAPE_TEX = A.shape_tex
local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring
local math_floor, math_max, math_min = math.floor, math.max, math.min
local str_byte, str_gmatch, str_upper = string.byte, string.gmatch, string.upper

local D = {}
PPUDraw = D

-- Are our textures known to the game? (BeardLib registers them in the DB.)
local function tex_ok( path )
	local ok, res = pcall( function()
		local ext, ids = Idstring( "texture" ), Idstring( path )
		if DB:has( ext, ids ) then
			return true
		end
		-- files added by BeardLib (main.xml <AddFiles>) are listed in its file manager
		local fm = rawget( _G, "BeardLib" ) and BeardLib.Managers and BeardLib.Managers.File
		return fm and fm.Has and fm:Has( ext, ids ) or false
	end )
	return ok and res and true or false
end
-- Checked again on every menu draw until found: BeardLib may register the files after this
-- file is loaded.
function D.check()
	if not D.fonts_ok then
		D.fonts_ok = tex_ok( "guis/textures/ppu/font_r" ) and tex_ok( "guis/textures/ppu/font_s" ) and tex_ok( "guis/textures/ppu/font_b" )
	end
	if not D.shapes_ok then
		D.shapes_ok = tex_ok( SHAPE_TEX )
	end
	return D.fonts_ok, D.shapes_ok
end
D.check()

local GAME_FONT = tweak_data.menu.pd2_medium_font

---------------------------------------------------------------------------------------------
-- Text
---------------------------------------------------------------------------------------------

local UTF8 = "[%z\1-\127\194-\244][\128-\191]*"

local function chars( s )
	local t = {}
	for ch in str_gmatch( s, UTF8 ) do
		t[ #t + 1 ] = ch
	end
	return t
end

local function upper( s )
	if utf8 and utf8.to_upper then
		return utf8.to_upper( s )
	end
	return str_upper( s )
end

-- Advance width of a list of characters in a font (layout px)
local function run_width( F, kern, list, i1, i2, ls )
	local g = F.g
	local size = F.size
	local w = 0
	local prev
	for i = i1, i2 do
		local ch = list[ i ]
		local gl = g[ ch ] or g[ "?" ]
		if prev then
			local k = kern[ prev .. ch ]
			if k then
				w = w + k * size
			end
		end
		w = w + gl[1] + ls
		prev = ch
	end
	return w
end

local function round( v )
	return math_floor( v + 0.5 )
end

-- Line box height and baseline, like Chrome: ascent/descent rounded to whole px (typo metrics),
-- line-height "normal" = ascent + descent + gap, otherwise half-leading around the content box.
function D.line_metrics( F, mult )
	local a, d = round( F.asc ), round( F.desc )
	local lh = mult and ( mult * F.size ) or ( a + d + round( F.gap ) )
	return lh, ( lh - ( a + d ) ) / 2 + a
end

-- Height of one line box in a font key
function D.lh( fkey, mult )
	local lh = D.line_metrics( D.font( fkey ), mult )
	return lh
end

function D.font( key )
	return A.fonts[ key ] or A.fonts.r16
end

-- Width of text in a font, same rules as drawing (letter spacing in em, like CSS)
function D.measure( fkey, text, ls_em, up )
	local F = D.font( fkey )
	text = tostring( text or "" )
	if up then
		text = upper( text )
	end
	local list = chars( text )
	return run_width( F, A.kern[ fkey:sub( 1, 1 ) ] or {}, list, 1, #list, ( ls_em or 0 ) * F.size )
end

-- Split into lines that fit max_w (greedy, on spaces, like the browser without text-wrap tricks)
local function wrap_lines( F, kern, list, max_w, ls )
	local lines = {}
	if not max_w then
		lines[1] = { 1, #list }
		return lines
	end
	local start = 1
	local last_space
	local i = 1
	while i <= #list do
		local ch = list[ i ]
		if ch == "\n" then
			lines[ #lines + 1 ] = { start, i - 1 }
			start = i + 1
			last_space = nil
		else
			if ch == " " then
				last_space = i
			end
			if run_width( F, kern, list, start, i, ls ) > max_w and i > start then
				if last_space and last_space > start then
					lines[ #lines + 1 ] = { start, last_space - 1 }
					start = last_space + 1
				else
					lines[ #lines + 1 ] = { start, i - 1 }
					start = i
				end
				last_space = nil
			end
		end
		i = i + 1
	end
	lines[ #lines + 1 ] = { start, #list }
	return lines
end

local Text = {}
Text.__index = Text

-- cfg: name, text, font ("r16", "s14", "b23"...), color, alpha, x, y, w (wrap/align width), wrap,
--      align ("left"/"center"/"right"), upper, ls (letter spacing in em), lh (line-height multiplier), layer
function D.text( parent, cfg )
	local self = setmetatable( {}, Text )
	self.cfg = cfg
	self.fkey = cfg.font or "r16"
	self.F = D.font( self.fkey )
	self.kern = A.kern[ self.fkey:sub( 1, 1 ) ] or {}
	self.color = cfg.color or Color.white
	self.panel = parent:panel( { name = cfg.name or "ppu_text", x = cfg.x or 0, y = cfg.y or 0, w = cfg.w or 10, h = 10, layer = cfg.layer or 3 } )
	if cfg.alpha then
		self.panel:set_alpha( cfg.alpha )
	end
	self:set_text( cfg.text or "" )
	return self
end

function Text:set_text( text )
	text = tostring( text or "" )
	self._text = text
	local cfg = self.cfg
	local F = self.F
	local panel = self.panel
	panel:clear()
	self._glyphs = {}

	local shown = cfg.upper and upper( text ) or text
	local ls = ( cfg.ls or 0 ) * F.size
	local lh, base = D.line_metrics( F, cfg.lh )
	local list = chars( shown )
	local max_w = cfg.wrap and cfg.w or nil
	local lines = wrap_lines( F, self.kern, list, max_w, ls )

	if not D.fonts_ok then
		-- Fallback: game font in one text object
		local t = panel:text( { name = "fallback", text = shown, font = GAME_FONT, font_size = F.size + 1, color = self.color,
			wrap = cfg.wrap and true or false, word_wrap = cfg.wrap and true or false, w = cfg.w or 1000, h = 1000,
			align = cfg.align or "left", vertical = "top", blend_mode = "normal", layer = 1 } )
		local _, _, tw, th = t:text_rect()
		self._w = cfg.w or tw
		self._h = th
		panel:set_size( self._w, self._h )
		t:set_size( self._w, self._h )
		self._fallback = t
		return
	end

	local maxw = 0
	local widths = {}
	for li, ln in ipairs( lines ) do
		local w = ln[2] >= ln[1] and run_width( F, self.kern, list, ln[1], ln[2], ls ) or 0
		widths[ li ] = w
		maxw = math_max( maxw, w )
	end
	local box_w = cfg.w or maxw
	local g = F.g
	local tex = F.tex
	for li, ln in ipairs( lines ) do
		local x = 0
		if cfg.align == "center" then
			x = ( box_w - widths[ li ] ) / 2
		elseif cfg.align == "right" then
			x = box_w - widths[ li ]
		end
		local by = ( li - 1 ) * lh + base
		local prev
		for i = ln[1], ln[2] do
			local ch = list[ i ]
			local gl = g[ ch ] or g[ "?" ]
			if prev then
				local k = self.kern[ prev .. ch ]
				if k then
					x = x + k * F.size
				end
			end
			if gl[4] then
				local b = panel:bitmap( { texture = tex, texture_rect = { gl[4], gl[5], gl[6], gl[7] },
					x = x + gl[2], y = by + gl[3], w = gl[6] / SC, h = gl[7] / SC, color = self.color, layer = 1, blend_mode = "normal" } )
				self._glyphs[ #self._glyphs + 1 ] = b
			end
			x = x + gl[1] + ls
			prev = ch
		end
	end
	self._w = box_w
	self._h = #lines * lh
	self._text_w = maxw
	panel:set_size( math_max( box_w, 1 ), math_max( self._h, 1 ) )
end

function Text:text() return self._text end
function Text:w() return self._w end
function Text:h() return self._h end
function Text:text_w() return self._text_w or self._w end
function Text:x() return self.panel:x() end
function Text:y() return self.panel:y() end
function Text:left() return self.panel:left() end
function Text:right() return self.panel:right() end
function Text:top() return self.panel:top() end
function Text:bottom() return self.panel:bottom() end
function Text:set_x( v ) self.panel:set_x( v ) end
function Text:set_y( v ) self.panel:set_y( v ) end
function Text:set_left( v ) self.panel:set_left( v ) end
function Text:set_right( v ) self.panel:set_right( v ) end
function Text:set_top( v ) self.panel:set_top( v ) end
function Text:set_center_x( v ) self.panel:set_center_x( v ) end
function Text:set_center_y( v ) self.panel:set_center_y( v ) end
function Text:set_visible( v ) self.panel:set_visible( v ) end
function Text:visible() return self.panel:visible() end
function Text:inside( x, y ) return self.panel:inside( x, y ) end
function Text:set_layer( l ) self.panel:set_layer( l ) end
function Text:set_alpha( a ) self.panel:set_alpha( a ) end
function Text:set_color( c )
	self.color = c
	if self._fallback then
		self._fallback:set_color( c )
		return
	end
	for _, b in ipairs( self._glyphs ) do
		b:set_color( c )
	end
end
-- Vertically centre the first line box on y (like align-items:center on a single line)
function Text:center_line_on( y )
	local lh = D.line_metrics( self.F, self.cfg.lh )
	self.panel:set_y( y - lh / 2 )
end

---------------------------------------------------------------------------------------------
-- Shapes
---------------------------------------------------------------------------------------------

local function sbitmap( panel, key, x, y, w, h, color, layer )
	local s = S[ key ]
	return panel:bitmap( { texture = SHAPE_TEX, texture_rect = { s[1], s[2], s[3], s[4] }, x = x, y = y,
		w = w or s[5], h = h or s[6], color = color, layer = layer or 0, blend_mode = "normal" } )
end
D.sbitmap = sbitmap

local Shape = {}
Shape.__index = Shape
function Shape:set_color( c )
	self.color = c
	for _, o in ipairs( self.parts ) do
		o:set_color( c )
	end
end
function Shape:set_visible( v ) self.panel:set_visible( v ) end
function Shape:visible() return self.panel:visible() end
function Shape:inside( x, y ) return self.panel:inside( x, y ) end

local function nearest_r( r )
	if r <= 2 then return 2 elseif r <= 3 then return 3 elseif r <= 4 then return 4 elseif r <= 10 then return 10 end
	return 12
end

-- Filled rounded box. cfg: x, y, w, h, r, color, layer, name
function D.box( parent, cfg )
	local self = setmetatable( { parts = {}, color = cfg.color }, Shape )
	local w, h = cfg.w, cfg.h
	local p = parent:panel( { name = cfg.name or "ppu_box", x = cfg.x or 0, y = cfg.y or 0, w = w, h = h, layer = cfg.layer or 0 } )
	self.panel = p
	local c = cfg.color
	local r = cfg.r or 0
	if r > 0 then
		r = math_min( nearest_r( r ), math_floor( math_min( w, h ) / 2 ) )
	end
	local parts = self.parts
	if r <= 0 or not D.shapes_ok then
		parts[1] = p:rect( { color = c, layer = 0 } )
		return self
	end
	local R = nearest_r( r )
	-- middle column, full height
	parts[ #parts + 1 ] = p:rect( { x = r, y = 0, w = w - 2 * r, h = h, color = c, layer = 0 } )
	if h - 2 * r > 0 then
		parts[ #parts + 1 ] = p:rect( { x = 0, y = r, w = r, h = h - 2 * r, color = c, layer = 0 } )
		parts[ #parts + 1 ] = p:rect( { x = w - r, y = r, w = r, h = h - 2 * r, color = c, layer = 0 } )
	end
	parts[ #parts + 1 ] = sbitmap( p, "corner" .. R .. "_tl", 0, 0, r, r, c )
	parts[ #parts + 1 ] = sbitmap( p, "corner" .. R .. "_tr", w - r, 0, r, r, c )
	parts[ #parts + 1 ] = sbitmap( p, "corner" .. R .. "_bl", 0, h - r, r, r, c )
	parts[ #parts + 1 ] = sbitmap( p, "corner" .. R .. "_br", w - r, h - r, r, r, c )
	return self
end

-- 1px rounded border. cfg: x, y, w, h, r, color, layer, bottom (bottom border width, e.g. 2 for key caps)
function D.border( parent, cfg )
	local self = setmetatable( { parts = {}, color = cfg.color }, Shape )
	local w, h = cfg.w, cfg.h
	local p = parent:panel( { name = cfg.name or "ppu_border", x = cfg.x or 0, y = cfg.y or 0, w = w, h = h, layer = cfg.layer or 0 } )
	self.panel = p
	local c = cfg.color
	local r = cfg.r or 0
	local parts = self.parts
	if r > 0 and D.shapes_ok then
		r = nearest_r( r )
	else
		r = 0
	end
	local function line( x, y, lw, lh )
		if lw > 0 and lh > 0 then
			parts[ #parts + 1 ] = p:rect( { x = x, y = y, w = lw, h = lh, color = c, layer = 0 } )
		end
	end
	line( r, 0, w - 2 * r, 1 )
	line( r, h - 1, w - 2 * r, 1 )
	line( 0, r, 1, h - 2 * r )
	line( w - 1, r, 1, h - 2 * r )
	if cfg.bottom and cfg.bottom > 1 then
		line( r > 0 and 1 or 0, h - cfg.bottom, w - ( r > 0 and 2 or 0 ), cfg.bottom - 1 )
	end
	if r > 0 then
		parts[ #parts + 1 ] = sbitmap( p, "ring" .. r .. "_tl", 0, 0, r, r, c )
		parts[ #parts + 1 ] = sbitmap( p, "ring" .. r .. "_tr", w - r, 0, r, r, c )
		parts[ #parts + 1 ] = sbitmap( p, "ring" .. r .. "_bl", 0, h - r, r, r, c )
		parts[ #parts + 1 ] = sbitmap( p, "ring" .. r .. "_br", w - r, h - r, r, r, c )
	end
	return self
end

-- Circle of diameter 14 or 16
function D.circle( parent, cfg )
	local self = setmetatable( { parts = {}, color = cfg.color }, Shape )
	local d = cfg.d or 16
	local p = parent:panel( { name = cfg.name or "ppu_circle", x = cfg.x or 0, y = cfg.y or 0, w = d, h = d, layer = cfg.layer or 0 } )
	self.panel = p
	if D.shapes_ok then
		self.parts[1] = sbitmap( p, "circle" .. ( d <= 14 and 14 or 16 ), 0, 0, d, d, cfg.color )
	else
		self.parts[1] = p:rect( { color = cfg.color } )
	end
	return self
end

-- Horizontal fade (solid bg 55% then transparent). side "l" = solid on the left.
function D.fade( parent, cfg )
	if not D.shapes_ok then
		return parent:rect( { name = cfg.name, x = cfg.x, y = cfg.y, w = cfg.w, h = cfg.h, color = cfg.color, layer = cfg.layer } )
	end
	return sbitmap( parent, "fade_" .. ( cfg.side or "l" ), cfg.x, cfg.y, cfg.w, cfg.h, cfg.color, cfg.layer )
end

-- Window shadow: 0 14px 44px rgba(0,0,0,.5) around a box at (x, y, w, h)
function D.shadow( parent, x, y, w, h, layer )
	if not D.shapes_ok then
		return
	end
	local s = S.shadow
	local M = A.shadow_margin
	local SL = A.shadow_slice
	local TW = s[3]
	local p = parent:panel( { name = "ppu_shadow", x = x - M, y = y + 14 - M, w = w + 2 * M, h = h + 2 * M, layer = layer or 0 } )
	local col = Color.black:with_alpha( 0.5 )
	local pw, ph = w + 2 * M, h + 2 * M
	local mid_w, mid_h = pw - 2 * SL, ph - 2 * SL
	local tmid = TW - 2 * SL
	local function piece( tx, ty, tw, th, x0, y0, w0, h0 )
		if w0 > 0 and h0 > 0 then
			p:bitmap( { texture = SHAPE_TEX, texture_rect = { s[1] + tx, s[2] + ty, tw, th }, x = x0, y = y0, w = w0, h = h0, color = col, layer = 0, blend_mode = "normal" } )
		end
	end
	piece( 0, 0, SL, SL, 0, 0, SL, SL )
	piece( TW - SL, 0, SL, SL, pw - SL, 0, SL, SL )
	piece( 0, TW - SL, SL, SL, 0, ph - SL, SL, SL )
	piece( TW - SL, TW - SL, SL, SL, pw - SL, ph - SL, SL, SL )
	piece( SL, 0, tmid, SL, SL, 0, mid_w, SL )
	piece( SL, TW - SL, tmid, SL, SL, ph - SL, mid_w, SL )
	piece( 0, SL, SL, tmid, 0, SL, SL, mid_h )
	piece( TW - SL, SL, SL, tmid, pw - SL, SL, SL, mid_h )
	-- centre is covered by the window
	return p
end

return D
