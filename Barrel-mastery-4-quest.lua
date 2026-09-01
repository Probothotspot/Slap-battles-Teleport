--[[
═══════════════════════════════════════════════════════════════════════════════
       BARREL MASTERY · Quest 4 (GeneralAbility Spammer every 1.0s)
═══════════════════════════════════════════════════════════════════════════════
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.BHUB_FLAGS = GENV.BHUB_FLAGS or {}

local GeneralAbility = ReplicatedStorage:WaitForChild("GeneralAbility", 5)

task.spawn(function()
    while GENV.BHUB_FLAGS.MasterRunning do
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChild("Barrel")

        -- Проверяем, что Main находится на 4 этаже (-40000) и жив
        if hum and hum.Health > 0 and hrp and hrp.Position.Y < -35000 then
            
            -- Экипировка перчатки Barrel в руку
            if not tool then
                local bagTool = LocalPlayer.Backpack:FindFirstChild("Barrel")
                if bagTool then hum:EquipTool(bagTool) end
            end

            -- Вызов способности через RemoteEvent
            if not GeneralAbility then
                GeneralAbility = ReplicatedStorage:FindFirstChild("GeneralAbility")
            end

            if GeneralAbility then
                pcall(function()
                    GeneralAbility:FireServer()
                end)
            end

            -- Ровно 1 секунда кулдауна
            task.wait(1.0)
        else
            task.wait(0.2)
        end
    end
end)
