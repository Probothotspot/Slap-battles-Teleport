--[[
═══════════════════════════════════════════════════════════════════════════════
       BARREL MASTERY · Quest 4 (Reliable Ability Spammer / Main Account)
═══════════════════════════════════════════════════════════════════════════════
]]

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService          = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.BHUB_FLAGS = GENV.BHUB_FLAGS or {}

GENV.BHUB_Q4_RUNNING = true
if GENV.BHUB_Q4_THREAD then
    pcall(task.cancel, GENV.BHUB_Q4_THREAD)
    GENV.BHUB_Q4_THREAD = nil
end

local GeneralAbility = ReplicatedStorage:WaitForChild("GeneralAbility", 5)

GENV.BHUB_Q4_THREAD = task.spawn(function()
    while GENV.BHUB_FLAGS.MasterRunning and GENV.BHUB_Q4_RUNNING do
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChild("Barrel")

        if hum and hum.Health > 0 and hrp and hrp.Position.Y < -35000 then
            
            -- 1. Экипировка перчатки
            if not tool then
                local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
                local bagTool = backpack and backpack:FindFirstChild("Barrel")
                if bagTool then
                    hum:EquipTool(bagTool)
                    task.wait(0.1)
                end
            end

            -- 2. Тройной гарантированный запуск способности
            pcall(function()
                -- А: Прямой RemoteEvent
                if not GeneralAbility then
                    GeneralAbility = ReplicatedStorage:FindFirstChild("GeneralAbility")
                end
                if GeneralAbility then
                    GeneralAbility:FireServer()
                end

                -- Б: Эмуляция нажатия E
                VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                task.wait(0.04)
                VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)

                -- В: Активация инструмента
                local currentTool = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Tool")
                if currentTool then
                    currentTool:Activate()
                end
            end)

            -- 3. Таймер кулдауна 1.0 сек
            local start = os.clock()
            while (os.clock() - start < 1.0) and GENV.BHUB_FLAGS.MasterRunning and GENV.BHUB_Q4_RUNNING do
                RunService.Heartbeat:Wait()
            end
        else
            task.wait(0.2)
        end
    end
end)
