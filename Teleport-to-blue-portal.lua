-- [[ AutoPortal Touch Module (Teleport2 / Blue Portal) ]] --
local AutoPortal = {}
AutoPortal.__index = AutoPortal

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local isRunning = false
local spawnConnection = nil
local loopThread = nil

-- Безопасный поиск HumanoidRootPart при смерти/респавне
function AutoPortal.GetHRP(timeout)
    timeout = timeout or 5
    local character = player.Character or player.CharacterAdded:Wait()
    local hrp = character:FindFirstChild("HumanoidRootPart")
    if not hrp and timeout > 0 then
        hrp = character:WaitForChild("HumanoidRootPart", timeout)
    end
    return hrp
end

-- Адаптивный поиск портала (приоритет на Workspace.Lobby.Teleport2)
function AutoPortal.ResolvePortal(target)
    if typeof(target) == "Instance" then
        if target:IsA("BasePart") then return target end
        return target:FindFirstChildWhichIsA("BasePart", true)
    end

    local targetName = tostring(target or "Teleport2")

    -- 1. Проверяем точный путь в Lobby
    local lobby = Workspace:FindFirstChild("Lobby")
    if lobby then
        local p = lobby:FindFirstChild(targetName)
        if p and p:IsA("BasePart") then return p end
    end

    -- 2. Прямой поиск по всему Workspace
    local found = Workspace:FindFirstChild(targetName, true)
    if found then
        if found:IsA("BasePart") then return found end
        local subPart = found:FindFirstChildWhichIsA("BasePart", true)
        if subPart then return subPart end
    end

    -- 3. Регистронезависимый поиск
    for _, desc in ipairs(Workspace:GetDescendants()) do
        if desc.Name:lower() == targetName:lower() and desc:IsA("BasePart") then
            return desc
        end
    end

    return nil
end

-- Мгновенный Touch синего портала через firetouchinterest
function AutoPortal.Touch(target, touchDelay)
    if not firetouchinterest then
        return false, "firetouchinterest не поддерживается эксплоитом"
    end

    local portal = AutoPortal.ResolvePortal(target or "Teleport2")
    local hrp = AutoPortal.GetHRP()
    touchDelay = touchDelay or 0.05

    if not portal or not hrp then 
        return false, "Синий портал или персонаж не найден" 
    end

    firetouchinterest(hrp, portal, 0)
    task.wait(touchDelay)
    firetouchinterest(hrp, portal, 1)
    return true, portal
end

-- Запуск авто-тача (постоянный цикл + реакция на спавн Teleport2)
function AutoPortal.Start(config)
    config = config or {}
    local targetName = config.Target or "Teleport2"
    local interval = config.Interval or 0.5
    local touchDelay = config.TouchDelay or 0.05
    local callback = config.OnTrigger

    if isRunning then AutoPortal.Stop() end
    isRunning = true

    -- Фоновый опрос
    loopThread = task.spawn(function()
        while isRunning do
            local portal = AutoPortal.ResolvePortal(targetName)
            if portal then
                local success = AutoPortal.Touch(portal, touchDelay)
                if success and callback and type(callback) == "function" then
                    task.spawn(callback, portal)
                end
            end
            task.wait(interval)
        end
    end)

    -- Моментальная реакция на спавн синего портала
    spawnConnection = Workspace.DescendantAdded:Connect(function(desc)
        if not isRunning then return end
        if desc.Name == targetName or desc.Name:lower() == targetName:lower() then
            task.wait(0.05)
            local success, portal = AutoPortal.Touch(desc, touchDelay)
            if success and callback and type(callback) == "function" then
                task.spawn(callback, portal)
            end
        end
    end)

    return true
end

-- Остановка авто-тача
function AutoPortal.Stop()
    isRunning = false
    if spawnConnection then
        spawnConnection:Disconnect()
        spawnConnection = nil
    end
    if loopThread then
        task.cancel(loopThread)
        loopThread = nil
    end
end

return AutoPortal
