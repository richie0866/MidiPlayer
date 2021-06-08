local tweenService = game:GetService("TweenService")

return function(obj, info, goal)
    local tween = tweenService:Create(obj, TweenInfo.new(table.unpack(info)), goal)
    tween.Completed:Connect(function()
        tween:Destroy()
    end)
    tween:Play()
    return tween
end