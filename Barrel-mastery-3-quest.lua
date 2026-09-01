--[[
═══════════════════════════════════════════════════════════════════════════════
       BARREL MASTERY · Quest 3 Execution Script (Main Account Only)
═══════════════════════════════════════════════════════════════════════════════
]]

local Players             = game:GetService("Players")
local VirtualInputManager = game:GetService("VirtualInputManager")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local RunService          = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.BHUB_FLAGS = GENV.BHUB_FLAGS or {}

local method = GENV.BHUB_Q3_METHOD or "Ability"

task.spawn(function()
    while GENV.BHUB_FLAGS.MasterRunning do
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChild("Barrel")

        if hum and hum.Health > 0 and hrp and hrp.Position.Y < -25000 and hrp.Position.Y > -35000 then
            -- Экипировка перчатки в руку, если она в рюкзаке
            if not tool then
                local bagTool = LocalPlayer.Backpack:FindFirstChild("Barrel")
                if bagTool then hum:EquipTool(bagTool) end
            end

            if method == "Ability" then
                -- ════════════════ МЕТОД 1: СПОСОБНОСТЬ (КАЖДЫЕ 0.5 СЕК) ════════════════
                pcall(function()
                    local barrelEvent = ReplicatedStorage:FindFirstChild("BarrelHit") or ReplicatedStorage:FindFirstChild("Barrel")
                    if barrelEvent and barrelEvent:IsA("RemoteEvent") then
                        barrelEvent:FireServer()
                    end
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    task.wait(0.04)
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end)

                -- Точный таймер задержки в 0.5 сек
                local startTime = os.clock()
                while os.clock() - startTime < 0.5 and GENV.BHUB_FLAGS.MasterRunning do
                    RunService.Heartbeat:Wait()
                end

            elseif method == "Slap" then
                -- ════════════════ МЕТОД 2: УДАРЫ (SLAP) ════════════════
                pcall(function()
                    if tool and tool:IsA("Tool") then
                        tool:Activate()
                    end
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 1)
                    task.wait(0.04)
                    VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 1)
                end)
                task.wait(0.3)
            end
        else
            task.wait(0.2)
        end
    end
end)
