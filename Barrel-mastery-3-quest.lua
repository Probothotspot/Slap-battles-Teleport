--[[
═══════════════════════════════════════════════════════════════════════════════
       BARREL MASTERY · Quest 3 (GeneralAbility & Target Slap Aura)
═══════════════════════════════════════════════════════════════════════════════
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.BHUB_FLAGS = GENV.BHUB_FLAGS or {}

local method = GENV.BHUB_Q3_METHOD or "Ability"

local GeneralAbility = ReplicatedStorage:WaitForChild("GeneralAbility", 5)
local GeneralHit     = ReplicatedStorage:WaitForChild("GeneralHit", 5)

-- Функция поиска альт-аккаунта
local function getAltPlayer()
    local altQuery = tostring(GENV.BHUB_ALT_NAME or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    
    -- 1. Поиск по указанному нику
    if altQuery ~= "" then
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                if plr.Name:lower() == altQuery or plr.DisplayName:lower() == altQuery then
                    return plr
                end
            end
        end
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer then
                if plr.Name:lower():find(altQuery, 1, true) or plr.DisplayName:lower():find(altQuery, 1, true) then
                    return plr
                end
            end
        end
    end

    -- 2. Запасной поиск: любой игрок на 3-м этаже (Y: от -28000 до -32000)
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local hrp = plr.Character:FindFirstChild("HumanoidRootPart")
            if hrp and hrp.Position.Y < -28000 and hrp.Position.Y > -32000 then
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

-- ==================== ОСНОВНОЙ ЦИКЛ 3 КВЕСТА ====================
task.spawn(function()
    local lastAbilityTime = 0
    local lastHitTime = 0

    while GENV.BHUB_FLAGS.MasterRunning do
        local char = LocalPlayer.Character
        local hum  = char and char:FindFirstChildOfClass("Humanoid")
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local tool = char and char:FindFirstChild("Barrel")

        -- Проверяем, что Main находится на 3 этаже (-30000) и жив
        if hum and hum.Health > 0 and hrp and hrp.Position.Y < -25000 and hrp.Position.Y > -35000 then
            
            -- Авто-экипировка перчатки Barrel в руку
            if not tool then
                local bagTool = LocalPlayer.Backpack:FindFirstChild("Barrel")
                if bagTool then hum:EquipTool(bagTool) end
            end

            -- ════════════════ МЕТОД 1: СПОСОБНОСТЬ (КАЖДУЮ 1.0 СЕК) ════════════════
            if method == "Ability" then
                if tick() - lastAbilityTime >= 1.0 then
                    if not GeneralAbility then
                        GeneralAbility = ReplicatedStorage:FindFirstChild("GeneralAbility")
                    end
                    if GeneralAbility then
                        pcall(function()
                            GeneralAbility:FireServer()
                        end)
                    end
                    lastAbilityTime = tick()
                end

            -- ════════════════ МЕТОД 2: ТАРГЕТ СЛАП АУРА ПО АЛЬТУ ════════════════
            elseif method == "Slap" then
                if tick() - lastHitTime >= 0.25 then
                    local altPlr = getAltPlayer()
                    if altPlr and altPlr.Character then
                        local altHum = altPlr.Character:FindFirstChildOfClass("Humanoid")
                        local altHrp = altPlr.Character:FindFirstChild("HumanoidRootPart")
                        local hitPart = getHitPart(altPlr.Character)

                        if altHum and altHum.Health > 0 and altHrp and hitPart then
                            local dist = (hrp.Position - altHrp.Position).Magnitude
                            if dist <= 30 then
                                if not GeneralHit then
                                    GeneralHit = ReplicatedStorage:FindFirstChild("GeneralHit")
                                end
                                if GeneralHit then
                                    pcall(function()
                                        GeneralHit:FireServer(hitPart)
                                    end)
                                end
                                lastHitTime = tick()
                            end
                        end
                    end
                end
            end
        end

        task.wait(0.05)
    end
end)
