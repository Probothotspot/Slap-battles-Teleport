--[[
    BARREL MASTERY · Quest 4 Ability Spammer (Main Only)
    Только спавн бочек без телепортации основы!
]]

local Players = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LocalPlayer = Players.LocalPlayer
local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()

local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.BHUB_FLAGS = GENV.BHUB_FLAGS or {}

-- Цикл применения способности бочки
task.spawn(function()
    while GENV.BHUB_FLAGS.MasterRunning do
        local cChar = LocalPlayer.Character
        local hum = cChar and cChar:FindFirstChildOfClass("Humanoid")
        local hrp = cChar and cChar:FindFirstChild("HumanoidRootPart")
        local tool = cChar and cChar:FindFirstChild("Barrel")

        if hum and hum.Health > 0 and hrp and hrp.Position.Y < -5000 then
            -- 1. Экипируем перчатку в руку, если она в рюкзаке
            if not tool then
                local bagTool = LocalPlayer.Backpack:FindFirstChild("Barrel")
                if bagTool then hum:EquipTool(bagTool) end
            end

            -- 2. Активация способности (E)
            pcall(function()
                -- Попытка через RemoteEvent
                local barrelEvent = ReplicatedStorage:FindFirstChild("BarrelHit") or ReplicatedStorage:FindFirstChild("Barrel")
                if barrelEvent and barrelEvent:IsA("RemoteEvent") then
                    barrelEvent:FireServer()
                end
                -- Симуляция нажатия клавиши E
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.05)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
            end)

            -- 3. Клик мышью для детонации/броска
            pcall(function()
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                task.wait(0.05)
                VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
            end)
        end
        task.wait(0.5)
    end
end)
