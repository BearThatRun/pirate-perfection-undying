--HUD stuff here

--TO DO: Remake it from whitelist

ppr_require('Trainer/tools/workspace')

local ppr_dofile = ppr_dofile
local ppr_config = ppr_config
local ExGUIObject = ExGUIObject

local managers = managers
local M_gui = managers.gui_data

--Init object
--Confused about choose of workspace, seems 16_9 like a correct one since menu uses cutted workspace size
local ppr_obj = ExGUIObject:new( GameSetup and M_gui:create_fullscreen_workspace() or M_gui:create_fullscreen_16_9_workspace() )

local G = getfenv(0)
G.ppr_obj = ppr_obj

ppr_obj.__elements = {}

--ppr_obj:setup_mouse() --Temporary debug

--Wrapped requires into separate function for update_object()
local function exec()
	-- x64 port: the version text and the scrolling announcement banner were removed.
end

--Called when resolution changed
function ppr_obj:update_object()
	ppr_obj:destroy()
	ppr_obj = ExGUIObject:new( GameSetup and M_gui:create_fullscreen_workspace() or M_gui:create_fullscreen_16_9_workspace() )
	G.ppr_obj = ppr_obj
	ppr_obj.__elements = {}
	--ppr_obj:setup_mouse() --Temporary debug
	exec()
end

exec()