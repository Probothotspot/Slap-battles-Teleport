--[[
═══════════════════════════════════════════════════════════════════════════════
       BARREL MASTERY · Quest 4 (Auto-Ability Spammer / Main Account)
═══════════════════════════════════════════════════════════════════════════════
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.BHUB_FLAGS = GENV.BHUB_FLAGS or {}

-- Остановка предыдущего потока 4 квеста при перезапуске
GENV.BHUB_Q4_RUNNING = true
if GENV.BHUB_Q4_THREAD then
    pcall(task.cancel, GENV.BHUB_Q4_THREAD)
    GENV.BHUB_Q4_THREAD = nil
end

local GeneralAbility = ReplicatedStorage:WaitForChild("GeneralAbility", 5)

-- Основной цикл применения способности основы на 4 этаже
GENV.BHUB_Q4_THREAD = task.spawn(function()
    while GENV.BHUB_FLAGS.MasterRunning and GENV.BHUB_Q4_RUNNING do
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChild("Barrel")

        -- Проверка: Main жив и стоит на 4 этаже (высота ниже -35000)
        if hum and hum.Health > 0 and hrp and hrp.Position.Y < -35000 then
            
            -- 1. Экипировка перчатки Barrel в руку, если она в рюкзаке
            if not tool then
                local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
                local bagTool = backpack and backpack:FindFirstChild("Barrel")
                if bagTool then
                    hum:EquipTool(bagTool)
                end
            end

            -- 2. Применение способности через RemoteEvent
            if not GeneralAbility then
                GeneralAbility = ReplicatedStorage:FindFirstChild("GeneralAbility")
            end

            if GeneralAbility then
                pcall(function()
                    GeneralAbility:FireServer()
                end)
            end

            -- 3. Точный таймер 1.0 секунда между спавнами бочек
            local startTime = os.clock()
            while (os.clock() - startTime < 1.0) and GENV.BHUB_FLAGS.MasterRunning and GENV.BHUB_Q4_RUNNING do
                RunService.Heartbeat:Wait()
            end
        else
            task.wait(0.2)
        end
    end
end)
