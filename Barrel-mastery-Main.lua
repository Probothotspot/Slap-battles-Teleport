--[[
═══════════════════════════════════════════════════════════════════════════════
       BARREL MASTERY HUB · Core Orchestrator (Lightweight Edition)
═══════════════════════════════════════════════════════════════════════════════
]]

repeat task.wait() until game:IsLoaded()

local Players     = game:GetService("Players")
local Workspace   = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

local GENV = (typeof(getgenv) == "function" and getgenv()) or _G
GENV.BHUB_FLAGS = GENV.BHUB_FLAGS or {}

-- 1. Anti-AFK
LocalPlayer.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.zero)
end)

-- 2. Загрузчик модулей с GitHub
local BASE_URL = "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/"
local function loadHubModule(file)
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(BASE_URL .. file .. "?t=" .. os.time()))()
    end)
    return ok and res or nil
end

-- Автозагрузка платформ
task.spawn(function() loadHubModule("Platform.lua") end)

-- 3. Состояние сессии
local Session = {
    Role        = "Main",
    TargetQuest = nil,
    Q3Method    = "Ability",
    Partner     = "",
    Worker      = nil,
}

-- 4. Загрузка интерфейса
local UIModule = loadHubModule("Barrel-mastery-GUI.lua")
assert(UIModule, "Failed to load Barrel-mastery-GUI.lua")

local UI
local function updatePartnerValidation()
    if Session.Partner == "" then
        UI:SetPartnerStatus(false, (Session.Role == "Main") and "ENTER ALT USERNAME" or "ENTER MAIN USERNAME")
        return
    end
    local found = false
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer and (p.Name:lower():find(Session.Partner:lower(), 1, true) or p.DisplayName:lower():find(Session.Partner:lower(), 1, true)) then
            found = true break
        end
    end
    UI:SetPartnerStatus(found, found and nil or "PLAYER NOT FOUND")
end

UI = UIModule.new({
    Maid = { Give = function(_, x) return x end, Clean = function() end },
    OnRoleSelect = function(role)
        Session.Role = role
        GENV.BHUB_ROLE = role
        if role == "Alt" then
            GENV.BHUB_MAIN_NAME = Session.Partner
            loadHubModule("Alt-Engine.lua")
        end
        updatePartnerValidation()
    end,
    OnAccountInput = function(slot, text)
        Session.Partner = text
        if Session.Role == "Alt" then GENV.BHUB_MAIN_NAME = text
        else GENV.BHUB_ALT_NAME = text end
        updatePartnerValidation()
    end,
    OnQuestToggle = function(q) Session.TargetQuest = q end,
    OnQ3MethodSelect = function(m) Session.Q3Method = m; GENV.BHUB_Q3_METHOD = m end,
    OnStartMaster = function(quest, q3Method)
        if Session.Role == "Alt" then return end
        GENV.BHUB_FLAGS.MasterRunning = true
        UI:SetMasterState(true)

        local targetY = (quest == 1 and -10000) or (quest == 2 and -20000) or (quest == 3 and -30000) or -40000
        local targetX = (quest == 3 and q3Method == "Slap") and -9999 or ((quest == 3) and 9999 or 0)
        local targetZ = targetX

        Session.Worker = task.spawn(function()
            loadHubModule("Auto-equip-barrel.lua")
            task.wait(0.3)
            local portal = Workspace:FindFirstChild("Teleport1", true)
            local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp and portal then
                if firetouchinterest then firetouchinterest(hrp, portal, 0); task.wait(0.05); firetouchinterest(hrp, portal, 1) end
            end
            task.wait(0.6)
            hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
            if hrp then hrp.CFrame = CFrame.new(targetX, targetY + 3, targetZ) end

            if quest == 3 then loadHubModule("Barrel-mastery-3-quest.lua")
            elseif quest == 4 then loadHubModule("Barrel-mastery-4-quest.lua") end
        end)
    end,
    OnStopMaster = function()
        GENV.BHUB_FLAGS.MasterRunning = false
        if Session.Worker then pcall(task.cancel, Session.Worker) end
        local hum = LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid")
        if hum then hum.Health = 0 end
        UI:SetMasterState(false)
    end,
    OnShutdown = function()
        GENV.BHUB_FLAGS.MasterRunning = false
        if Session.Worker then pcall(task.cancel, Session.Worker) end
    end
})

UI:BuildMain()
UI:SetStatus("Hub loaded · Ready")
