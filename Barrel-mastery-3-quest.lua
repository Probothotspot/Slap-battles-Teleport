--[[
═══════════════════════════════════════════════════════════════════════════════
       BARREL MASTERY · Quest 3 (Slap Aura & Ability Execution)
═══════════════════════════════════════════════════════════════════════════════
]]

local Players             = game:GetService("Players")
local ReplicatedStorage   = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local RunService          = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.BHUB_FLAGS = GENV.BHUB_FLAGS or {}

local method = GENV.BHUB_Q3_METHOD or "Ability"
local GeneralAbility = ReplicatedStorage:WaitForChild("GeneralAbility", 5)
local GeneralHit     = ReplicatedStorage:WaitForChild("GeneralHit", 5)

local function getAltPlayer()
    local altQuery = tostring(GENV.BHUB_ALT_NAME or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if altQuery ~= "" then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and (plr.Name:lower() == altQuery or plr.DisplayName:lower() == altQuery) then
                return plr
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and (plr.Name:lower():find(altQuery, 1, true) or plr.DisplayName:lower():find(altQuery, 1, true)) then
                return plr
            end
        end
    end

    -- Запасной поиск: игрок рядом на той же платформе 3 этажа
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp and math.abs(hrp.Position.Y - (-30000)) < 1500 then
                return plr
            end
        end
    end
    return nil
end

local function getHitPart(char)
    if not char then return nil end
    return char:FindFirstChild("HumanoidRootPart") 
        or char:FindFirstChild("Torso") 
        or char:FindFirstChild("UpperTorso") 
        or char:FindFirstChild("Head")
end

task.spawn(function()
    local lastAbility = 0
    local lastHit = 0

    while GENV.BHUB_FLAGS.MasterRunning do
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChild("Barrel")

        if hum and hum.Health > 0 and hrp and math.abs(hrp.Position.Y - (-30000)) < 1500 then
            
            if not tool then
                local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
                local bagTool = backpack and backpack:FindFirstChild("Barrel")
                if bagTool then hum:EquipTool(bagTool) end
            end

            -- Метод 1: Способность
            if method == "Ability" then
                if tick() - lastAbility >= 1.0 then
                    pcall(function()
                        if not GeneralAbility then GeneralAbility = ReplicatedStorage:FindFirstChild("GeneralAbility") end
                        if GeneralAbility then GeneralAbility:FireServer() end
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                        task.wait(0.04)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    end)
                    lastAbility = tick()
                end

            -- Метод 2: Слап Аура
            elseif method == "Slap" then
                if tick() - lastHit >= 0.2 then
                    local altPlr = getAltPlayer()
                    if altPlr and altPlr.Character then
                        local altHum = altPlr.Character:FindFirstChildOfClass("Humanoid")
                        local altHrp = altPlr.Character:FindFirstChild("HumanoidRootPart")
                        local hitPart = getHitPart(altPlr.Character)

                        if altHum and altHum.Health > 0 and altHrp and hitPart then
                            if not GeneralHit then GeneralHit = ReplicatedStorage:FindFirstChild("GeneralHit") end
                            if GeneralHit then
                                pcall(function()
                                    GeneralHit:FireServer(hitPart)
                                end)
                            end
                            lastHit = tick()
                        end
                    end
                end
            end
        end
        task.wait(0.05)
    end
end)
