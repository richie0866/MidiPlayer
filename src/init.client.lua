-- Main
-- 0866
-- October 31, 2020

local App = require(script.Components.App)

if (not isfolder("midi")) then
    makefolder("midi")
end

App:Init()
