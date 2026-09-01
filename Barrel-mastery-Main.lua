--[[
═══════════════════════════════════════════════════════════════════════════════
       BARREL MASTERY HUB · Controller v4.4 (Proximity Barrel Detection)
═══════════════════════════════════════════════════════════════════════════════
]]

local Players           = game:GetService("Players")
local VirtualUser       = game:GetService("VirtualUser")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.BHUB_FLAGS = GENV.BHUB_FLAGS or {}

-- 1. Координаты этажей квестов
local QUEST_FLOORS = {
    [1] = -10000,
    [2] = -20000,
    [3] = -30000,
    [4] = -40000,
}

local SavedQueries = {
    MainRole_AltQuery = "",
    AltRole_MainQuery = ""
}

-- 2. Очистка памяти
if type(GENV.BHUB_CLEANUP) == "function" then pcall(GENV.BHUB_CLEANUP) end
local Cleanups = {}
local function cleanAll() 
    for _, fn in ipairs(Cleanups) do pcall(fn) end 
    table.clear(Cleanups) 
end
GENV.BHUB_CLEANUP = cleanAll

local function give(item)
    local t = typeof(item)
    if t == "RBXScriptConnection" then table.insert(Cleanups, function() item:Disconnect() end)
    elseif t == "thread" then table.insert(Cleanups, function() task.cancel(item) end)
    elseif t == "Instance" then table.insert(Cleanups, function() item:Destroy() end)
    elseif t == "function" then table.insert(Cleanups, item) end
    return item
end

-- Anti-AFK
give(LocalPlayer.Idled:Connect(function() 
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.zero) 
end))

-- Порталы
local function getPortalPart(name)
    local lobby = Workspace:FindFirstChild("Lobby")
    if lobby then
        local inLobby = lobby:FindFirstChild(name, true)
        if inLobby and inLobby:IsA("BasePart") then return inLobby end
    end
    for _, descendant in ipairs(Workspace:GetDescendants()) do
        if descendant.Name == name and descendant:IsA("BasePart") then
            return descendant
        end
    end
    return nil
end

local function doTouch(name)
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 4)
    local portal = getPortalPart(name)
    
    if not (hrp and portal) then return false, name .. " not found" end
    if firetouchinterest then
        firetouchinterest(hrp, portal, 0)
        task.wait(0.05)
        firetouchinterest(hrp, portal, 1)
    else
        portal.CFrame = hrp.CFrame
    end
    return true
end

local function loadPlatform()
    local platUrl = "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Platform.lua?t=" .. tostring(os.time())
    pcall(function() loadstring(game:HttpGet(platUrl))() end)
end

local function loadAutoEquip()
    local equipUrl = "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Auto-equip-barrel.lua?t=" .. tostring(os.time())
    pcall(function() loadstring(game:HttpGet(equipUrl))() end)
end

-- 3. Улучшенный глубокий поиск бочки по близости к основе (Proximity Search)
local function getSpawnedBarrel(mainHrp)
    if not mainHrp then return nil end
    local mainPos = mainHrp.Position

    -- 1. Проход по прямому Workspace
    for _, obj in ipairs(Workspace:GetChildren()) do
        if not Players:GetPlayerFromCharacter(obj) then
            local name = obj.Name:lower()
            if name:find("barrel") or name:find("roll") then
                if obj:IsA("BasePart") then
                    if (obj.Position - mainPos).Magnitude <= 100 then
                        return obj
                    end
                elseif obj:IsA("Model") and not obj:FindFirstChildOfClass("Humanoid") then
                    local p = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart")
                    if p and (p.Position - mainPos).Magnitude <= 100 then
                        return p
                    end
                end
            end
        end
    end

    -- 2. Глубокий поиск среди всех дескендантов Workspace (на случай папок Debris / Effects / Spawns)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if obj:IsA("BasePart") and not obj:IsDescendantOf(Workspace.Terrain) then
            local parentModel = obj:FindFirstAncestorOfClass("Model")
            if not (parentModel and parentModel:FindFirstChildOfClass("Humanoid")) then
                local name = obj.Name:lower()
                local parentName = obj.Parent and obj.Parent.Name:lower() or ""
                if name:find("barrel") or name:find("roll") or parentName:find("barrel") then
                    if (obj.Position - mainPos).Magnitude <= 100 then
                        return obj
                    end
                end
            end
        end
    end

    return nil
end

-- Состояние
local Runtime = {
    IsRunning       = false,
    CurrentRole     = "Main",
    ActiveQuestNum  = nil,
    Q3Method        = "Ability",
    Accounts        = {
        Main = { Query = "", Target = nil },
        Alt  = { Query = "", Target = nil }
    },
    Loops           = {},
    AltDaemon       = nil,
}

local UI_URL = "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Barrel-mastery-GUI.lua"
local ok, UIModule = pcall(function() 
    return loadstring(game:HttpGet(UI_URL .. "?t=" .. tostring(os.time())))() 
end)
assert(ok and type(UIModule) == "table", "UI Module failed to load: " .. tostring(UIModule))

local startQuests, stopQuests, updateAccountBindings, setRole, findPlr, setupAltDaemon, stopAltDaemon

local UI = UIModule.new({
    Maid = { Give = function(_, x) return give(x) end, Clean = cleanAll },
    OnStartMaster = function(selectedQuest, q3Method) 
        Runtime.ActiveQuestNum = selectedQuest
        Runtime.Q3Method = q3Method or "Ability"
        GENV.BHUB_Q3_METHOD = Runtime.Q3Method
        GENV.BHUB_ALT_NAME  = Runtime.Accounts.Alt.Query
        startQuests(selectedQuest) 
    end,
    OnStopMaster  = function() stopQuests() end,
    OnRoleSelect  = function(role) setRole(role) end,
    OnQuestToggle = function(chosenQuest) Runtime.ActiveQuestNum = chosenQuest end,
    OnQ3MethodSelect = function(method) 
        Runtime.Q3Method = method
        GENV.BHUB_Q3_METHOD = method
    end,
    OnAccountInput = function(slot, text) 
        if Runtime.CurrentRole == "Main" and slot == "Alt" then
            SavedQueries.MainRole_AltQuery = text
        elseif Runtime.CurrentRole == "Alt" and slot == "Main" then
            SavedQueries.AltRole_MainQuery = text
        end
        updateAccountBindings()
    end,
    OnShutdown = function()
        stopQuests()
        stopAltDaemon()
        UI:Destroy()
        cleanAll()
        GENV.BHUB_CLEANUP = nil
    end,
})

findPlr = function(query)
    query = query:lower():gsub("^%s+", ""):gsub("%s+$", "")
    if query == "" then return nil end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower() == query or plr.DisplayName:lower() == query then 
            return plr 
        end
    end
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr.Name:lower():find(query, 1, true) or plr.DisplayName:lower():find(query, 1, true) then 
            return plr 
        end
    end
    return nil
end

updateAccountBindings = function()
    if Runtime.CurrentRole == "Main" then
        Runtime.Accounts.Main.Target = LocalPlayer
        Runtime.Accounts.Main.Query  = LocalPlayer.Name
        UI:SetAccountTag("Main", "you", "Found: You ✅")
        UI:SetAccountBox("Main", LocalPlayer.Name, false, true)

        local altQuery = SavedQueries.MainRole_AltQuery
        if altQuery == "" then
            Runtime.Accounts.Alt.Target = nil
            Runtime.Accounts.Alt.Query  = ""
            UI:SetAccountTag("Alt", "idle", "Not set")
            UI:SetAccountBox("Alt", "", true, false)
            UI:SetPartnerStatus(false, "ENTER ALT USERNAME")
        else
            local target = findPlr(altQuery)
            Runtime.Accounts.Alt.Target = target
            Runtime.Accounts.Alt.Query  = altQuery
            if target and target ~= LocalPlayer then
                UI:SetAccountTag("Alt", "ok", "Player found ✅")
                UI:SetAccountBox("Alt", altQuery, true, false)
                UI:SetPartnerStatus(true)
            elseif target == LocalPlayer then
                UI:SetAccountTag("Alt", "err", "Cannot be self ❌")
                UI:SetAccountBox("Alt", altQuery, true, false)
                UI:SetPartnerStatus(false, "ALT CANNOT BE YOU")
            else
                UI:SetAccountTag("Alt", "err", "Player not in server ❌")
                UI:SetAccountBox("Alt", altQuery, true, false)
                UI:SetPartnerStatus(false, "ALT NOT FOUND")
            end
        end

    elseif Runtime.CurrentRole == "Alt" then
        Runtime.Accounts.Alt.Target = LocalPlayer
        Runtime.Accounts.Alt.Query  = LocalPlayer.Name
        UI:SetAccountTag("Alt", "you", "Found: You ✅")
        UI:SetAccountBox("Alt", LocalPlayer.Name, false, true)

        local mainQuery = SavedQueries.AltRole_MainQuery
        if mainQuery == "" then
            Runtime.Accounts.Main.Target = nil
            Runtime.Accounts.Main.Query  = ""
            UI:SetAccountTag("Main", "idle", "Not set")
            UI:SetAccountBox("Main", "", true, false)
            UI:SetPartnerStatus(false, "ENTER MAIN USERNAME")
        else
            local target = findPlr(mainQuery)
            Runtime.Accounts.Main.Target = target
            Runtime.Accounts.Main.Query  = mainQuery
            if target and target ~= LocalPlayer then
                UI:SetAccountTag("Main", "ok", "Player found ✅")
                UI:SetAccountBox("Main", mainQuery, true, false)
                UI:SetPartnerStatus(true)
            elseif target == LocalPlayer then
                UI:SetAccountTag("Main", "err", "Cannot be self ❌")
                UI:SetAccountBox("Main", mainQuery, true, false)
                UI:SetPartnerStatus(false, "MAIN CANNOT BE YOU")
            else
                UI:SetAccountTag("Main", "err", "Player not in server ❌")
                UI:SetAccountBox("Main", mainQuery, true, false)
                UI:SetPartnerStatus(false, "MAIN NOT FOUND")
            end
        end
    end
end

give(Players.PlayerAdded:Connect(function() task.defer(updateAccountBindings) end))
give(Players.PlayerRemoving:Connect(function() task.defer(updateAccountBindings) end))

-- Логика Main
local function executeMainFloorSequence(questNum)
    if not Runtime.IsRunning or Runtime.CurrentRole ~= "Main" then return end
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrp = char:WaitForChild("HumanoidRootPart", 5)
    if not hrp then return end

    local targetY = QUEST_FLOORS[questNum] or -10000

    UI:SetStatus("[Main] Equipping Barrel…")
    loadAutoEquip()
    task.wait(0.3)
    if not Runtime.IsRunning then return end

    UI:SetStatus("[Main] Entering Red Portal…")
    doTouch("Teleport1")
    task.wait(0.6)
    if not Runtime.IsRunning then return end

    char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    hrp = char:WaitForChild("HumanoidRootPart", 5)
    if hrp and Runtime.IsRunning then
        hrp.CFrame = CFrame.new(0, targetY + 3, 0)
        UI:SetStatus("[Main] Active on Floor " .. questNum)
    end
end

local function detectMainQuestFloor(mainHrp)
    if not mainHrp then return nil end
    local y = mainHrp.Position.Y
    for qNum, floorY in pairs(QUEST_FLOORS) do
        if math.abs(y - floorY) < 2000 then
            return qNum, floorY
        end
    end
    return nil
end

-- Логика Alt
stopAltDaemon = function()
    if Runtime.AltDaemon then
        pcall(task.cancel, Runtime.AltDaemon)
        Runtime.AltDaemon = nil
    end
end

setupAltDaemon = function()
    stopAltDaemon()
    if Runtime.CurrentRole ~= "Alt" then return end

    Runtime.AltDaemon = task.spawn(function()
        local isAltActive = false
        local altWorkerThread = nil
        local currentFloorY = nil
        local currentQuestNum = nil

        while Runtime.CurrentRole == "Alt" do
            task.wait(0.05)

            local mainPlr = Runtime.Accounts.Main.Target or findPlr(Runtime.Accounts.Main.Query)
            if mainPlr == LocalPlayer then mainPlr = nil end

            local mainChar = mainPlr and mainPlr.Character
            local mainHrp  = mainChar and mainChar:FindFirstChild("HumanoidRootPart")

            local detectedQuest, floorY = detectMainQuestFloor(mainHrp)

            if detectedQuest and (not isAltActive or currentQuestNum ~= detectedQuest) then
                isAltActive = true
                currentQuestNum = detectedQuest
                currentFloorY = floorY
                UI:SetMasterState(true)
                UI:SetStatus("[Alt] Detected Quest " .. detectedQuest .. "! Running…")

                if altWorkerThread then pcall(task.cancel, altWorkerThread) end

                altWorkerThread = task.spawn(function()
                    loadPlatform()

                    local function enterBluePortal()
                        UI:SetStatus("[Alt] Entering Blue Portal…")
                        doTouch("Teleport2")
                        task.wait(0.6)
                        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                        local hrp = char:WaitForChild("HumanoidRootPart", 5)
                        if hrp then
                            hrp.CFrame = CFrame.new(0, currentFloorY + 3, 0)
                        end
                    end

                    local generalHitEvent = ReplicatedStorage:FindFirstChild("GeneralHit")
                    local lastHitTime = 0
                    if generalHitEvent and generalHitEvent:IsA("RemoteEvent") then
                        give(generalHitEvent.OnClientEvent:Connect(function(...)
                            lastHitTime = tick()
                        end))
                    end

                    while isAltActive and Runtime.CurrentRole == "Alt" do
                        local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                        local hrp = char:WaitForChild("HumanoidRootPart", 5)
                        local hum = char:WaitForChild("Humanoid", 5)

                        if hrp and hum and hum.Health > 0 then
                            -- Возврат на этаж при респавне в лобби
                            if hrp.Position.Y >= 200 and hrp.Position.Y <= 500 then
                                enterBluePortal()
                            else
                                local mainTarget = Runtime.Accounts.Main.Target or findPlr(Runtime.Accounts.Main.Query)
                                local mChar = mainTarget and mainTarget.Character
                                local mHrp = mChar and mChar:FindFirstChild("HumanoidRootPart")

                                if currentQuestNum == 4 then
                                    -- ════════════════ КВЕСТ 4: МОМЕНТАЛЬНЫЙ СНЕП НА БОЧКУ ════════════════
                                    local barrel = getSpawnedBarrel(mHrp)
                                    if barrel then
                                        hrp.CFrame = barrel.CFrame * CFrame.new(0, 0.5, 0)
                                        UI:SetStatus("[Alt] Q4: Snapped inside Barrel! 💥")
                                    elseif mHrp then
                                        -- Стоим перед лицом Main спиной к нему (в упор 2 студа)
                                        hrp.CFrame = mHrp.CFrame * CFrame.new(0, 0, -2.2) * CFrame.Angles(0, math.rad(180), 0)
                                        UI:SetStatus("[Alt] Q4: Ready in front of Main…")
                                    end

                                elseif currentQuestNum == 3 then
                                    -- ════════════════ КВЕСТ 3: ABILITY / SLAP ════════════════
                                    if mHrp then
                                        hrp.CFrame = mHrp.CFrame * CFrame.new(0, 0, -2.5) * CFrame.Angles(0, math.rad(180), 0)
                                    end

                                    local barrel = getSpawnedBarrel(mHrp)
                                    if barrel then
                                        UI:SetStatus("[Alt] Q3: Barrel detected! Waiting 1s…")
                                        task.wait(1.0)
                                        if isAltActive and hum.Health > 0 and barrel.Parent then
                                            hrp.CFrame = barrel.CFrame * CFrame.new(0, 0.5, 0)
                                            UI:SetStatus("[Alt] Q3: Snapped! 0.5s timer…")
                                            task.wait(0.5)
                                            if hum and hum.Health > 0 then hum.Health = 0 end
                                        end
                                    end

                                    if tick() - lastHitTime < 0.6 then
                                        UI:SetStatus("[Alt] Q3 (Slap): Hit registered! Resetting…")
                                        task.wait(0.1)
                                        if hum and hum.Health > 0 then hum.Health = 0 end
                                    end
                                else
                                    if mHrp then
                                        hrp.CFrame = mHrp.CFrame * CFrame.new(0, 0, -2.5) * CFrame.Angles(0, math.rad(180), 0)
                                    end
                                end
                            end
                        end

                        if hum then
                            hum.Died:Wait()
                            task.wait(0.3)
                        else
                            task.wait(0.04)
                        end
                    end
                end)

            elseif not detectedQuest and isAltActive then
                isAltActive = false
                currentQuestNum = nil
                currentFloorY = nil
                if altWorkerThread then
                    pcall(task.cancel, altWorkerThread)
                    altWorkerThread = nil
                end

                local char = LocalPlayer.Character
                local hum = char and char:FindFirstChildOfClass("Humanoid")
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hum and hrp and hrp.Position.Y < 0 then hum.Health = 0 end

                UI:SetMasterState(false)
                UI:SetStatus("[Alt] Main idle. Waiting in Lobby…")
            end
        end
    end)
    give(Runtime.AltDaemon)
end

-- Старт / Стоп
stopQuests = function()
    if not Runtime.IsRunning then return end
    Runtime.IsRunning = false
    Runtime.ActiveQuestNum = nil
    GENV.BHUB_FLAGS.MasterRunning = false

    for _, thread in ipairs(Runtime.Loops) do
        pcall(task.cancel, thread)
    end
    table.clear(Runtime.Loops)

    local char = LocalPlayer.Character
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if hum then hum.Health = 0 end

    UI:SetMasterState(false)
    UI:SetStatus("Quests stopped. Reset executed.")
end

startQuests = function(chosenQuest)
    if Runtime.CurrentRole ~= "Main" or not chosenQuest then return end

    if Runtime.IsRunning then return end
    Runtime.IsRunning = true
    Runtime.ActiveQuestNum = chosenQuest
    GENV.BHUB_FLAGS.MasterRunning = true

    UI:SetMasterState(true)
    UI:SetStatus("Starting Quest " .. chosenQuest .. " on Floor " .. chosenQuest .. "…")

    loadPlatform()
    task.spawn(function() executeMainFloorSequence(chosenQuest) end)

    local stateWatcher = task.spawn(function()
        while Runtime.IsRunning do
            local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
            local hrp = char:WaitForChild("HumanoidRootPart", 5)
            local hum = char:WaitForChild("Humanoid", 5)

            if hrp and hum and hum.Health > 0 and Runtime.IsRunning then
                if hrp.Position.Y >= 200 and hrp.Position.Y <= 500 then
                    task.wait(0.5)
                    if Runtime.IsRunning and Runtime.CurrentRole == "Main" then
                        executeMainFloorSequence(Runtime.ActiveQuestNum)
                    end
                end
            end

            if hum then
                hum.Died:Wait()
                if Runtime.IsRunning then
                    LocalPlayer.CharacterAdded:Wait()
                    task.wait(0.5)
                end
            else
                task.wait(0.5)
            end
        end
    end)
    table.insert(Runtime.Loops, stateWatcher)
    give(stateWatcher)

    -- Подгрузка скрипта квеста
    if chosenQuest == 3 and Runtime.CurrentRole == "Main" then
        local q3Worker = task.spawn(function()
            task.wait(1.8)
            if Runtime.IsRunning then
                local q3Url = "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Barrel-mastery-3-quest.lua?t=" .. tostring(os.time())
                pcall(function() loadstring(game:HttpGet(q3Url))() end)
            end
        end)
        table.insert(Runtime.Loops, q3Worker)
        give(q3Worker)
    elseif chosenQuest == 4 and Runtime.CurrentRole == "Main" then
        local q4Worker = task.spawn(function()
            task.wait(1.8)
            if Runtime.IsRunning then
                local q4Url = "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Barrel-mastery-4-quest.lua?t=" .. tostring(os.time())
                pcall(function() loadstring(game:HttpGet(q4Url))() end)
            end
        end)
        table.insert(Runtime.Loops, q4Worker)
        give(q4Worker)
    end
end

setRole = function(role)
    Runtime.CurrentRole = role
    UI:SelectRole(role)
    updateAccountBindings()
    UI:SetStatus("Role selected: " .. role)
    if role == "Alt" then
        setupAltDaemon()
    else
        stopAltDaemon()
    end
end

-- Инициализация
UI:RunPreloader({
    { key = "game",      label = "Game Loaded",         fn = function() return game:IsLoaded() end },
    { key = "player",    label = "LocalPlayer Ready",   fn = function() return LocalPlayer.Parent == Players end },
    { key = "workspace", label = "Workspace Valid",     fn = function() return Workspace ~= nil end },
    { key = "network",   label = "GitHub Connectivity", fn = function() return #game:HttpGet("https://raw.githubusercontent.com/octocat/Hello-World/master/README") > 0 end },
}, function()
    loadPlatform()
    UI:BuildMain()
    setRole("Main")
    UI:SetStatus("Hub ready — Configure Alt & Quest.")
end)
