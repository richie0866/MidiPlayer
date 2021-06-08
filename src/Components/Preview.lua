-- Preview
-- 0866
-- November 04, 2020



local midiPlayer = script:FindFirstAncestor("MidiPlayer")
local Input = require(midiPlayer.Input)

local Preview = {}

local genv = getgenv()

local colors = {
    --Color3.fromRGB(128, 128, 128),
    Color3.fromRGB(254, 122, 122),
    Color3.fromRGB(254, 234, 122),
    Color3.fromRGB(122, 224, 122),
    Color3.fromRGB(37, 171, 254),
}

local c3White = Color3.new(1, 1, 1)

local preview, notes, noteTemplate


function Preview:Draw(song)
    notes:ClearAllChildren()

    notes.Parent = nil

    for i, track in next, song._score, 1 do
        local color = colors[(i % #colors) + 1]

        for _,event in ipairs(track) do
            if (event[1] == "note") then
                local pitch = event[5]
                local note = noteTemplate:Clone()
                if (Input.IsUpper(pitch)) then
                    note.BackgroundColor3 = color:Lerp(c3White, 0.25)
                else
                    note.BackgroundColor3 = color
                end
                note.Position = UDim2.new((pitch - 36) / 61, 0, 0, -event[2] / 2)
                note.Size = UDim2.new(0.016, 0, 0, math.max(event[3] / 2, 1))
                note.Parent = notes
            end
        end
    end

    if (not genv._hideSongPreview) then
        notes.Parent = preview
    end
end


function Preview:Clear()
    notes:ClearAllChildren()
end


function Preview:Update(position)
    if (not genv._hideSongPreview) then
        if (position) then
            notes.Position = UDim2.new(0, 0, 1, position / 2)
        end
        if (notes.Parent == nil) then
            notes.Parent = preview
        end
    else
        notes.Parent = nil
    end
end


function Preview:Init(frame)

    preview = frame.Preview
    notes = preview.Notes

    noteTemplate = notes.Note
    noteTemplate.Parent = nil

end


return Preview
