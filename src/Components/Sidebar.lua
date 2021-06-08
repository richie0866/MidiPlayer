-- Sidebar
-- 0866
-- November 03, 2020



local midiPlayer = script:FindFirstAncestor("MidiPlayer")
local Thread = require(midiPlayer.Util.Thread)
local Controller = require(midiPlayer.Components.Controller)
local FastTween = require(midiPlayer.FastTween)

local Sidebar = {}

local tweenInfo = { 0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out }

local sidebar, template


function Sidebar:CreateElement(filePath)
    
    local fullname = filePath:match("([^\\]+)$")
    local name = fullname:match("^([^%.]+)") or ""
    local extension = fullname:match("([^%.]+)$")

    if (extension ~= "mid") then
        return
    end

    local element = template:Clone()
    element.Name = filePath
    element.Title.Text = name

    if (Controller.CurrentFile == filePath) then
        element.Selection.Size = UDim2.fromOffset(3, 16)
    else
        element.Selection.Size = UDim2.fromOffset(3, 0)
    end

    element.InputBegan:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1) then
            FastTween(element, tweenInfo, { BackgroundTransparency = 0.5 })
            Controller:Select(filePath)
        end
    end)

    element.InputEnded:Connect(function(input)
        if (input.UserInputType == Enum.UserInputType.MouseButton1) then
            FastTween(element, tweenInfo, { BackgroundTransparency = 0.75 })
        end
    end)

    element.MouseEnter:Connect(function()
        FastTween(element, tweenInfo, { BackgroundTransparency = 0.75 })
    end)

    element.MouseLeave:Connect(function()
        FastTween(element, tweenInfo, { BackgroundTransparency = 1 })
    end)

    element.Parent = sidebar.Songs
    sidebar.Songs.CanvasSize = UDim2.new(0, 0, 0, #sidebar.Songs:GetChildren() * element.AbsoluteSize.Y)

end


function Sidebar:Update()
    
    local files = listfiles("midi")

    for _,element in ipairs(sidebar.Songs:GetChildren()) do
        if (element:IsA("Frame") and not table.find(files, element.Name)) then
            element:Destroy()
        end
    end

    for _,filePath in ipairs(files) do
        if (not sidebar.Songs:FindFirstChild(filePath)) then
            self:CreateElement(filePath)
        end
    end

end


function Sidebar:Init(frame)

    sidebar = frame.Sidebar

    template = sidebar.Songs.Song
    template.Parent = nil

    Controller.FileLoaded:Connect(function(song)
        for _,element in ipairs(sidebar.Songs:GetChildren()) do
            if (element:IsA("Frame")) then
                if (element.Name == song.Path) then
                    FastTween(element.Selection, tweenInfo, { Size = UDim2.fromOffset(3, 16) })
                else
                    FastTween(element.Selection, tweenInfo, { Size = UDim2.fromOffset(3, 0) })
                end
            end
        end
    end)

    Thread.DelayRepeat(1, self.Update, self)
    self:Update()

end


return Sidebar
