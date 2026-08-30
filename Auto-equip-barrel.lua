--[[
    BARREL AUTO-EQUIP MODULE (Slap Battles)
    Target: Workspace.Lobby.Barrel (Pos: -136.95, 322.87, 14.73)
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local function getBarrelStand()
    local lobby = Workspace:FindFirstChild("Lobby")
    if lobby then
        local stand = lobby:FindFirstChild("Barrel")
        if stand and stand:IsA("BasePart") then return stand end
    end
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj.Name == "Barrel" and obj:IsA("BasePart") and obj.Parent and obj.Parent.Name == "Lobby" then
            return obj
        end
    end
    return nil
end

local function equipBarrel()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hum = char:WaitForChild("Humanoid", 4)
    local hrp = char:WaitForChild("HumanoidRootPart", 4)
    local backpack = LocalPlayer:WaitForChild("Backpack", 4)

    if not (hum and hrp and backpack) then return false end

    -- Проверка: если перчатка уже в руках или в рюкзаке
    local inHand = char:FindFirstChild("Barrel")
    local inBag  = backpack:FindFirstChild("Barrel")
    if inHand then
        return true
    elseif inBag then
        hum:EquipTool(inBag)
        return true
    end

    local stand = getBarrelStand()
    if not stand then
        warn("[Barrel Equip] Стойка Barrel не найдена в Lobby!")
        return false
    end

    -- 1. Срабатывание через Touch
    if typeof(firetouchinterest) == "function" then
        firetouchinterest(hrp, stand, 0)
        task.wait(0.05)
        firetouchinterest(hrp, stand, 1)
    else
        local prevCF = hrp.CFrame
        hrp.CFrame = stand.CFrame
        task.wait(0.1)
        hrp.CFrame = prevCF
    end

    -- 2. Срабатывание через ClickDetector (если присутствует)
    local cd = stand:FindFirstChildWhichIsA("ClickDetector", true)
    if cd and typeof(fireclickdetector) == "function" then
        fireclickdetector(cd)
    end

    task.wait(0.25)

    -- Берем перчатку в руку из рюкзака
    local tool = backpack:FindFirstChild("Barrel") or char:FindFirstChild("Barrel")
    if tool and tool:IsA("Tool") and tool.Parent == backpack then
        hum:EquipTool(tool)
    end

    return (char:FindFirstChild("Barrel") ~= nil or backpack:FindFirstChild("Barrel") ~= nil)
end

-- Авто-экипировка при каждом возрождении персонажа
local function enableAutoEquip()
    equipBarrel()
    LocalPlayer.CharacterAdded:Connect(function(newChar)
        newChar:WaitForChild("HumanoidRootPart", 5)
        task.wait(0.2)
        equipBarrel()
    end)
end

enableAutoEquip()
