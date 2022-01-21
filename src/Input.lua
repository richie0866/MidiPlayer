-- Input
-- 0866
-- January 20th, 2022


local Input = {}

local vim = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")

-- This allows you to type in chat while playing, but when you type in chat it makes you play notes. Not sure if it can be fixed. Still going to leave here in case anyone wants it
--if syn then
--	for i, v in pairs(getconnections(UserInputService.TextBoxFocused)) do
--   		v:Disable() 
--	end	
--end

local NOTE_MAP = "1!2@34$5%6^78*9(0qQwWeErtTyYuiIoOpPasSdDfgGhHjJklLzZxcCvVbBnm"
local UPPER_MAP = "!@ $%^ *( QWE TY IOP SD GHJ LZ CVB"
local LOWER_MAP = "1234567890qwertyuiopasdfghjklzxcvbnm"

local Thread = require(script.Parent.Util.Thread)
local Maid = require(script.Parent.Util.Maid)

local inputMaid = Maid.new()


local function GetKey(pitch)
    local idx = (pitch + 1 - 36)
    if (idx > #NOTE_MAP or idx < 1) then
        return
    else
        local key = NOTE_MAP:sub(idx, idx)
        return key, UPPER_MAP:find(key, 1, true)
    end
end


function Input.IsUpper(pitch)
    local key, upperMapIdx = GetKey(pitch)
    if (not key) then return end
    return upperMapIdx
end

function readnumbertome(n)
	n = tostring(n or ""):match("^0*(.*)$")
	if #n == 0 then return "Zero" end
	local a = {"One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine"}
	local b = {"", "Twenty", "Thirty", "Forty", "Fifty", "Sixty", "Seventy", "Eighty", "Ninety"}
	local c = {[0] = "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen", "Sixteen", "Seventeen", "Eighteen", "Nineteen"}
	if #n == 1 then
		return a[tonumber(n)]
	elseif #n == 2 then
		local ones = tonumber(n:sub(2, 2))
		local tens = tonumber(n:sub(1, 1))
		if tens == 1 then
			return c[ones]
		elseif ones == 0 then
			return b[tens]
		else
			return b[tens].." "..a[ones]
		end
	end
end


function Input.Press(pitch)
    local key, upperMapIdx = GetKey(pitch)
    if (not key) then return end
    if (upperMapIdx) then
        local keyToPress = LOWER_MAP:sub(upperMapIdx, upperMapIdx)

        vim:SendKeyEvent(true, Enum.KeyCode.LeftShift, false, game)
        if tonumber(keyToPress) then
        local resultofnumbertext = readnumbertome(tonumber(keyToPress))
        vim:SendKeyEvent(true, Enum.KeyCode[resultofnumbertext], false, game)
        else
        vim:SendKeyEvent(true, tostring(keyToPress):upper(), false, game)
        end
        vim:SendKeyEvent(false, Enum.KeyCode.LeftShift, false, game)
    else
        if tonumber(key) then
        local resultofnumbertext = readnumbertome(tonumber(key))
        vim:SendKeyEvent(true, Enum.KeyCode[resultofnumbertext], false, game)        
        else
        vim:SendKeyEvent(true, tostring(key):upper(), false, game)
        end
    end
end


function Input.Release(pitch)
    local key, upperMapIdx = GetKey(pitch)
    if (not key) then return end
    if (upperMapIdx) then
        local keyToPress = LOWER_MAP:sub(upperMapIdx, upperMapIdx)
        
        if tonumber(keyToPress) then
              local resultofnumbertext = readnumbertome(tonumber(keyToPress))
              vim:SendKeyEvent(false, Enum.KeyCode[resultofnumbertext], false, game)
        else
        vim:SendKeyEvent(false, tostring(keyToPress):upper(), false, game)
        end
    else
        if tonumber(key) then
        local resultofnumbertext = readnumbertome(tonumber(key))
        vim:SendKeyEvent(false, Enum.KeyCode[resultofnumbertext], false, game)
        else
        vim:SendKeyEvent(false, tostring(key):upper(), false, game)
        end
    end
end


function Input.Hold(pitch, duration)
    if (inputMaid[pitch]) then
        inputMaid[pitch] = nil
    end
    Input.Release(pitch)
    Input.Press(pitch)
    inputMaid[pitch] = Thread.Delay(duration, Input.Release, pitch)
end

return Input
