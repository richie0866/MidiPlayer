-- App
-- 0866
-- November 03, 2020



local App = {}

local CoreGui = game:GetService("CoreGui")

local midiPlayer = script:FindFirstAncestor("MidiPlayer")

local FastDraggable = require(midiPlayer.FastDraggable)
local Controller = require(midiPlayer.Components.Controller)
local Sidebar = require(midiPlayer.Components.Sidebar)
local Preview = require(midiPlayer.Components.Preview)

local gui = midiPlayer.Assets.ScreenGui


function App:GetGUI()
    return gui
end


function App:Init()

    FastDraggable(gui.Frame, gui.Frame.Handle)
    gui.Parent = CoreGui

    Controller:Init(gui.Frame)
    Sidebar:Init(gui.Frame)
    Preview:Init(gui.Frame)

end


return App
