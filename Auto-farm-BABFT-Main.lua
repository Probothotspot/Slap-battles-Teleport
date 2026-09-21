repeat task.wait(0.2) until game:IsLoaded()

print("[BABFT-Main] Инициализация ядра...")

if _G.BabftActiveScript and type(_G.BabftActiveScript.Destroy) == "function" then
    pcall(_G.BabftActiveScript.Destroy)
end

_G.BABFT = _G.BABFT or {}
local API = _G.BABFT
API.UI = API.UI or {}

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local GuiService = game:GetService("GuiService")
local HttpService = game:GetService("HttpService")
local VirtualUser = game:GetService("VirtualUser")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
while not player do
    task.wait(0.2)
    player = Players.LocalPlayer
end

API.Players = Players
API.player = player
API.Workspace = Workspace
API.RunService = RunService
API.TeleportService = TeleportService
API.GuiService = GuiService
API.HttpService = HttpService
API.Lighting = Lighting
API.TweenService = TweenService
API.UserInputService = UserInputService
API.SoundService = SoundService

API.RAW_GITHUB_URL = "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Auto-farm-BABFT-Main.lua"
API.CHILLZ_GROUP_ID = 2919213
API.CONFIG_FILE = "babft_farm_config.json"

API.farming = false
API.isRejoining = false
API.isBlackScreen = false
API.isMinimized = false
API.isClosing = false
API.spaceBgActive = true
API.soundEffectsActive = true
API.customSoundsActive = true

API.smoothnessMode = 1
API.smoothnessNames = {"120+ FPS (Ultra)", "60 FPS (Баланс)", "30 FPS (Эко)"}

API.farmMode = "Chest"
API.chestDelay = 2
API.stageDelay = 1.5
API.chestStage = 2
API.autoBuyActive = false
API.buyAmount = 1
API.targetItemRealName = ""
API.targetItemPrice = 0
API.targetItemYield = 1
API.autoRejoinActive = true
API.autoStartOnJoin = false
API.antiDarknessActive = true
API.antiHazardActive = true
API.antiLagActive = false
API.staffDetectorActive = true

API.windowPosX = nil
API.windowPosY = nil
API.windowScaleX = 0.5
API.windowScaleY = 0.28
API.windowSizeX = 260
API.windowSizeY = 320

API.tgToken = ""
API.tgChatId = ""
API.lastUpdateId = 0

API.startGold = 0
API.previousGold = 0
API.totalEarned = 0
API.startTime = 0
API.goldValObject = nil

-- Метрики замера
API.statsStartTime = 0
API.lastFinalizedMinute = 0
API.currentMinuteGold = 0
API.minuteBuckets = {}
API.minuteSamples = {}
API.minuteSampleSum = 0
API.averageGoldPerMinute = 0
API.estimatedGoldPerHour = 0
API.currentETA = "Выкл"

API.MILESTONES = {10000, 25000, 50000, 100000, 250000, 500000, 1000000}
API.reachedMilestones = {}

API.STAGE_COORDINATES = {
    Vector3.new(-52, 70, 1369),
    Vector3.new(-52, 70, 2139),
    Vector3.new(-52, 70, 2909),
    Vector3.new(-52, 70, 3679),
    Vector3.new(-52, 70, 4449),
    Vector3.new(-52, 70, 5219),
    Vector3.new(-52, 70, 5989),
    Vector3.new(-52, 70, 6759),
    Vector3.new(-52, 70, 7529),
    Vector3.new(-52, 70, 8299)
}
API.CHEST_POSITION = Vector3.new(-55, -356, 9489)
API.SPAWN_Z_MAX = 1200

API.httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
API.queue_on_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)

-- База цен и размеров паков
API.KNOWN_ITEMS = {
    ["common"] = {name = "Common Chest", price = 5, yield = 1},
    ["common chest"] = {name = "Common Chest", price = 5, yield = 1},
    ["uncommon"] = {name = "Uncommon Chest", price = 15, yield = 1},
    ["uncommon chest"] = {name = "Uncommon Chest", price = 15, yield = 1},
    ["rare"] = {name = "Rare Chest", price = 45, yield = 1},
    ["rare chest"] = {name = "Rare Chest", price = 45, yield = 1},
    ["epic"] = {name = "Epic Chest", price = 135, yield = 1},
    ["epic chest"] = {name = "Epic Chest", price = 135, yield = 1},
    ["legendary"] = {name = "Legendary Chest", price = 405, yield = 1},
    ["legendary chest"] = {name = "Legendary Chest", price = 405, yield = 1},

    ["дерево"] = {name = "WoodBlock", price = 250, yield = 50},
    ["wood"] = {name = "WoodBlock", price = 250, yield = 50},
    ["лего"] = {name = "ToyBlock", price = 250, yield = 50},
    ["lego"] = {name = "ToyBlock", price = 250, yield = 50},
    ["toy"] = {name = "ToyBlock", price = 250, yield = 50},
    ["toyblock"] = {name = "ToyBlock", price = 250, yield = 50},
    ["стекло"] = {name = "GlassBlock", price = 250, yield = 25},
    ["glass"] = {name = "GlassBlock", price = 250, yield = 25},
    ["камень"] = {name = "StoneBlock", price = 275, yield = 50},
    ["stone"] = {name = "StoneBlock", price = 275, yield = 50},
    ["ткань"] = {name = "FabricBlock", price = 300, yield = 50},
    ["fabric"] = {name = "FabricBlock", price = 300, yield = 50},
    ["пластик"] = {name = "PlasticBlock", price = 300, yield = 50},
    ["plastic"] = {name = "PlasticBlock", price = 300, yield = 50},
    ["песок"] = {name = "SandBlock", price = 300, yield = 50},
    ["sand"] = {name = "SandBlock", price = 300, yield = 50},
    ["bouncy"] = {name = "BouncyBlock", price = 300, yield = 50},
    ["прыгучий"] = {name = "BouncyBlock", price = 300, yield = 50},
    ["металл"] = {name = "MetalBlock", price = 325, yield = 50},
    ["metal"] = {name = "MetalBlock", price = 325, yield = 50},
    ["лед"] = {name = "IceBlock", price = 350, yield = 50},
    ["ice"] = {name = "IceBlock", price = 350, yield = 50},
    ["уголь"] = {name = "CoalBlock", price = 375, yield = 50},
    ["кирпич"] = {name = "BrickBlock", price = 375, yield = 50},
    ["brick"] = {name = "BrickBlock", price = 375, yield = 50},
    ["мрамор"] = {name = "MarbleBlock", price = 375, yield = 50},
    ["marble"] = {name = "MarbleBlock", price = 375, yield = 50},
    ["обсидиан"] = {name = "ObsidianBlock", price = 425, yield = 50},
    ["obsidian"] = {name = "ObsidianBlock", price = 425, yield = 50},
    ["титан"] = {name = "TitaniumBlock", price = 425, yield = 50},
    ["titanium"] = {name = "TitaniumBlock", price = 425, yield = 50},
    ["ржавый металл"] = {name = "RustedMetalBlock", price = 300, yield = 50},

    ["колеса"] = {name = "CarWheels", price = 750, yield = 4},
    ["старые колеса"] = {name = "LegacyCarWheels", price = 750, yield = 4},
    ["шарики"] = {name = "Balloon", price = 45, yield = 3},
    ["balloon"] = {name = "Balloon", price = 45, yield = 3},
    ["гарпун"] = {name = "Harpoon", price = 200, yield = 1},
    ["джетпак"] = {name = "Jetpack", price = 350, yield = 1},
    ["турбина"] = {name = "JetTurbine", price = 4000, yield = 3},
    ["турбины"] = {name = "JetTurbine", price = 4000, yield = 3},
    ["кнопка"] = {name = "Button", price = 50, yield = 1},
    ["переключатель"] = {name = "Switch", price = 50, yield = 1},
    ["лампа"] = {name = "LightBulb", price = 60, yield = 3},
    ["камера"] = {name = "Camera", price = 85, yield = 1},
    ["задержка"] = {name = "DelayBlock", price = 50, yield = 2},
    ["нота"] = {name = "NoteBlock", price = 40, yield = 2},
    ["поршень"] = {name = "Piston", price = 65, yield = 1},
    ["магнит"] = {name = "Magnet", price = 125, yield = 1},
    ["сенсор"] = {name = "Sensor", price = 25, yield = 1},
    ["пульт"] = {name = "RemoteController", price = 150, yield = 1},
    ["стержень"] = {name = "Bar", price = 60, yield = 3},
    ["прут"] = {name = "Bar", price = 60, yield = 3},
    ["подвеска"] = {name = "Suspension", price = 60, yield = 3},
    ["динамит"] = {name = "Dynamite", price = 20, yield = 1},
    ["миниган"] = {name = "Minigun", price = 150, yield = 1},
    ["пушка"] = {name = "Cannon", price = 250, yield = 1},
    ["мечи"] = {name = "MountedSwords", price = 50, yield = 1},
    ["рулетка"] = {name = "ScalingTool", price = 5000, yield = 1},
    ["мастерок"] = {name = "TrowelTool", price = 1500, yield = 1},
    ["кисть"] = {name = "PaintTool", price = 1500, yield = 1},
    ["ключ"] = {name = "BindingTool", price = 2000, yield = 1},
    ["отвертка"] = {name = "PropertyTool", price = 2500, yield = 1}
}

API.stepSoundId = "rbxassetid://9069609204"

pcall(function()
    local function createSound(id, vol)
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://" .. tostring(id)
        s.Volume = vol or 0.5
        pcall(function() s.Parent = SoundService end)
        return s
    end
    API.clickSfx = createSound(6895079853, 0.5)
    API.coinSfx = createSound(5153734608, 0.6)
    API.achievementSfx = createSound(5153724623, 0.8)
end)

function API.playSfx(sfx)
    if API.soundEffectsActive and sfx then pcall(function() sfx:Play() end) end
end

function API.formatNum(n)
    local left, num, right = string.match(tostring(math.floor(n)), "^([^%d]*%d)(%d*)(.-)$")
    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

function API.playStepSound()
    if not API.customSoundsActive or not API.soundEffectsActive then return end
    local char = player.Character
    if char then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hrp then
            task.spawn(function()
                local s = Instance.new("Sound")
                s.Name = "CustomStepSFX"
                s.SoundId = API.stepSoundId
                s.Volume = 1.4
                s.RollOffMaxDistance = 50
                s.Parent = hrp
                s:Play()
                s.Ended:Connect(function() s:Destroy() end)
                task.delay(0.8, function() if s and s.Parent then s:Destroy() end end)
            end)
        end
    end
end

function API.applyFootstepSounds(char)
    if not char then return end
    task.spawn(function()
        local hrp = char:WaitForChild("HumanoidRootPart", 5)
        if hrp then
            local running = hrp:WaitForChild("Running", 5)
            if running and running:IsA("Sound") then
                if API.customSoundsActive and API.soundEffectsActive then
                    running.SoundId = API.stepSoundId
                    running.Volume = 1.2
                else
                    running.SoundId = "rbxasset://sounds/action_footsteps_plastic.mp3"
                    running.Volume = 0.5
                end
            end
        end
    end)
end

player.CharacterAdded:Connect(function(newChar)
    task.wait(0.5)
    API.applyFootstepSounds(newChar)
end)
if player.Character then API.applyFootstepSounds(player.Character) end

local lastStepTime = 0
API.stepConn = RunService.Heartbeat:Connect(function()
    if not API.customSoundsActive or not API.soundEffectsActive then return end
    local char = player.Character
    if char then
        local hum = char:FindFirstChildOfClass("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum and hrp and hum.Health > 0 then
            local defRunning = hrp:FindFirstChild("Running")
            if defRunning and defRunning.SoundId ~= API.stepSoundId then defRunning.Volume = 0 end
            if hum.MoveDirection.Magnitude > 0.1 and hum.FloorMaterial ~= Enum.Material.Air then
                local interval = (hum.WalkSpeed > 18 and 0.26 or 0.35)
                if os.clock() - lastStepTime > interval then
                    lastStepTime = os.clock()
                    API.playStepSound()
                end
            end
        end
    end
end)

API.platform = Instance.new("Part")
API.platform.Name = "FarmPlatform"
API.platform.Size = Vector3.new(8, 1, 8)
API.platform.Anchored = true
API.platform.CanCollide = true
API.platform.Material = Enum.Material.SmoothPlastic
API.platform.Transparency = 0.4
API.platform.BrickColor = BrickColor.new("Royal purple")

function API.setSpin(hrp, enabled)
    if not hrp then return end
    local spin = hrp:FindFirstChild("FarmSpin")
    if enabled then
        if not spin then
            spin = Instance.new("BodyAngularVelocity")
            spin.Name = "FarmSpin"
            spin.MaxTorque = Vector3.new(0, 4e5, 0)
            spin.AngularVelocity = Vector3.new(0, 2.5, 0)
            spin.Parent = hrp
        end
    else
        if spin then spin:Destroy() end
    end
end

function API.getCurrentHRP()
    local char = player.Character
    if char and char.Parent then
        local hrp = char:FindFirstChild("HumanoidRootPart")
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hrp and hum and hum.Health > 0 then return hrp, char, hum end
    end
    return nil, nil, nil
end

function API.placeOnPlatform(targetPos, hrp)
    API.platform.Position = targetPos - Vector3.new(0, 3.1, 0)
    API.platform.Parent = Workspace
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = CFrame.new(targetPos)
    API.setSpin(hrp, true)
end

function API.setNoclip(character)
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA("BasePart") and part ~= API.platform then part.CanCollide = false end
    end
end

function API.formatTime(seconds)
    local hrs = math.floor(seconds / 3600)
    local mins = math.floor((seconds % 3600) / 60)
    local secs = seconds % 60
    return string.format("%02d:%02d:%02d", hrs, mins, secs)
end

function API.getGoldObject()
    if API.goldValObject and API.goldValObject.Parent then return API.goldValObject end
    local data = player:FindFirstChild("Data")
    if data and data:FindFirstChild("Gold") then
        API.goldValObject = data.Gold
        return API.goldValObject
    end
    local ls = player:FindFirstChild("leaderstats")
    if ls and ls:FindFirstChild("Gold") then
        API.goldValObject = ls.Gold
        return API.goldValObject
    end
    return nil
end

function API.getCurrentGold()
    local obj = API.getGoldObject()
    return obj and (tonumber(obj.Value) or 0) or 0
end

function API.getAvgGoldPerMin()
    return API.averageGoldPerMinute or 0
end

function API.showAchievementToast(title, text)
    API.playSfx(API.achievementSfx)
    print("[BABFT Достижение] " .. tostring(title) .. ": " .. tostring(text))
end

API.idledConn = player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

-- Анти-темнота (постоянная работа без отключения)
local defaultLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows
}

function API.enableClearVision()
    if not API.antiDarknessActive then return end
    pcall(function()
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e6
        Lighting.GlobalShadows = false

        local pGui = player:FindFirstChild("PlayerGui")
        if pGui then
            for _, v in ipairs(pGui:GetDescendants()) do
                if v:IsA("Frame") and v.Visible and v.BackgroundTransparency < 0.4 then
                    local col = v.BackgroundColor3
                    if (col.R + col.G + col.B) < 0.25 then v.Visible = false end
                end
            end
        end
    end)
end

function API.disableClearVision()
    pcall(function()
        Lighting.Ambient = defaultLighting.Ambient
        Lighting.OutdoorAmbient = defaultLighting.OutdoorAmbient
        Lighting.Brightness = defaultLighting.Brightness
        Lighting.ClockTime = defaultLighting.ClockTime
        Lighting.FogEnd = defaultLighting.FogEnd
        Lighting.GlobalShadows = defaultLighting.GlobalShadows
    end)
end

task.spawn(function()
    while true do
        if API.antiDarknessActive then API.enableClearVision() end
        task.wait(1.5)
    end
end)

-- Поиск предмета в магазине с выдачей размера пака
function API.searchItemInGame(query)
    query = string.lower(string.gsub(query, "%s+", ""))
    if query == "" then return nil, 0, 1 end

    for key, data in pairs(API.KNOWN_ITEMS) do
        local cleanKey = string.lower(string.gsub(key, "%s+", ""))
        if cleanKey == query or string.find(cleanKey, query) or string.find(query, cleanKey) then
            return data.name, data.price, (data.yield or 1)
        end
    end

    local pGui = player:FindFirstChild("PlayerGui")
    if pGui and pGui:FindFirstChild("Shop") then
        for _, frame in ipairs(pGui.Shop:GetDescendants()) do
            if frame:IsA("TextLabel") or frame:IsA("TextButton") then
                if string.find(string.lower(string.gsub(frame.Text, "%s+", "")), query) then
                    local parent = frame.Parent
                    if parent then
                        for _, child in ipairs(parent:GetDescendants()) do
                            if child:IsA("TextLabel") and string.find(string.lower(child.Text), "gold") then
                                local parsed = tonumber(string.match(child.Text, "(%d+)"))
                                if parsed and parsed > 0 then return frame.Text, parsed, 1 end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil, 0, 1
end

function API.executeBuy(itemName, amount)
    local rName, price, packYield = API.searchItemInGame(itemName)
    if not rName or price <= 0 then return false, "Предмет не найден" end
    amount = tonumber(amount) or 1
    local totalCost = price * amount
    if API.getCurrentGold() < totalCost then return false, "Недостаточно золота" end
    local buyRemote = Workspace:FindFirstChild("ItemBoughtFromShop")
    if buyRemote then
        local ok = pcall(function() buyRemote:InvokeServer(rName, amount) end)
        if ok then return true, "Куплено: " .. rName .. " (" .. (amount * packYield) .. " шт.)" end
    end
    return false, "Ошибка покупки"
end

function API.checkAndAutoBuy()
    if not API.autoBuyActive or API.targetItemRealName == "" or API.targetItemPrice <= 0 then return end
    local totalCost = API.targetItemPrice * API.buyAmount
    if API.getCurrentGold() >= totalCost then
        local buyRemote = Workspace:FindFirstChild("ItemBoughtFromShop")
        if buyRemote then
            pcall(function() buyRemote:InvokeServer(API.targetItemRealName, API.buyAmount) end)
        end
    end
end

-- ВОССТАНОВЛЕННАЯ ФУНКЦИЯ ЗАМЕРОВ М1, М2, СКОРОСТИ И ETA
function API.updateSpeedAndEtaMetrics()
    local UI = API.UI
    if not API.farming then
        if API.lastFinalizedMinute == 0 then
            if UI.goldSpeedLabel then UI.goldSpeedLabel.Text = "Скорость: ~0 G/ч (0.0 G/мин)" end
            if UI.minuteStatsLabel then UI.minuteStatsLabel.Text = "Мин. статистика: фарм остановлен" end
        end
        if UI.etaLabel then UI.etaLabel.Text = "До покупки: Выкл" end
        return
    end

    local elapsed = time() - API.statsStartTime
    local completedMinutes = math.floor(elapsed / 60)

    if completedMinutes > API.lastFinalizedMinute then
        while API.lastFinalizedMinute < completedMinutes do
            API.lastFinalizedMinute = API.lastFinalizedMinute + 1
            if API.lastFinalizedMinute == completedMinutes then
                API.minuteSamples[API.lastFinalizedMinute] = API.currentMinuteGold
                API.minuteSampleSum = API.minuteSampleSum + API.currentMinuteGold
                API.currentMinuteGold = 0
            else
                API.minuteSamples[API.lastFinalizedMinute] = 0
            end
        end

        if API.lastFinalizedMinute > 0 then
            API.averageGoldPerMinute = API.minuteSampleSum / API.lastFinalizedMinute
            API.estimatedGoldPerHour = math.floor(API.averageGoldPerMinute * 60 + 0.5)
        end
    end

    if API.lastFinalizedMinute == 0 then
        if UI.goldSpeedLabel then UI.goldSpeedLabel.Text = "Скорость: сбор данных до 1-й минуты..." end
        if UI.minuteStatsLabel then
            UI.minuteStatsLabel.Text = string.format("Замер минуты 1: +%d G (%dс/60с)", API.currentMinuteGold, math.floor(elapsed % 60))
        end
    else
        if UI.goldSpeedLabel then
            UI.goldSpeedLabel.Text = string.format("Скорость: ~%s G/ч (%.1f G/мин)", API.formatNum(API.estimatedGoldPerHour), API.averageGoldPerMinute)
        end
        if UI.minuteStatsLabel then
            if API.lastFinalizedMinute == 1 then
                UI.minuteStatsLabel.Text = string.format("М1: +%d | Ср: %.1f/мин", API.minuteSamples[1] or 0, API.averageGoldPerMinute)
            else
                local mPrev = API.lastFinalizedMinute - 1
                local mCurr = API.lastFinalizedMinute
                UI.minuteStatsLabel.Text = string.format("М%d:+%d | М%d:+%d | Ср:%.1f/мин", mPrev, API.minuteSamples[mPrev] or 0, mCurr, API.minuteSamples[mCurr] or 0, API.averageGoldPerMinute)
            end
        end
    end

    -- Расчет ETA с учетом формулы (50 x 400 = 20,000 блоков)
    if API.autoBuyActive and API.targetItemPrice > 0 and API.buyAmount > 0 then
        local currentG = API.getCurrentGold()
        local totalCost = API.targetItemPrice * API.buyAmount
        local remainingGold = totalCost - currentG
        local packYield = API.targetItemYield or 1
        local totalBlocks = API.buyAmount * packYield

        local formulaText = ""
        if packYield > 1 then
            formulaText = string.format(" (%d × %s = %s бл.)", packYield, API.formatNum(API.buyAmount), API.formatNum(totalBlocks))
        else
            formulaText = string.format(" (%s шт.)", API.formatNum(API.buyAmount))
        end

        if remainingGold <= 0 then
            API.currentETA = "Покупка: сейчас"
            if UI.etaLabel then
                UI.etaLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
                UI.etaLabel.Text = "Покупка: сейчас!" .. formulaText
            end
        elseif API.lastFinalizedMinute == 0 or API.averageGoldPerMinute <= 0 then
            API.currentETA = "после 1 мин."
            if UI.etaLabel then
                UI.etaLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                UI.etaLabel.Text = string.format("Нужно %s G%s | ETA после 1 мин.", API.formatNum(remainingGold), formulaText)
            end
        else
            local etaSeconds = math.floor((remainingGold / API.averageGoldPerMinute) * 60)
            API.currentETA = API.formatTime(etaSeconds)
            if UI.etaLabel then
                UI.etaLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                UI.etaLabel.Text = string.format("Нужно %s G%s | ETA: %s", API.formatNum(remainingGold), formulaText, API.currentETA)
            end
        end
    else
        API.currentETA = "Выкл"
        if UI.etaLabel then
            UI.etaLabel.TextColor3 = Color3.fromRGB(160, 150, 180)
            UI.etaLabel.Text = "До покупки: Выкл"
        end
    end

    if API.isBlackScreen and UI.bsStats then
        if API.lastFinalizedMinute == 0 then
            UI.bsStats.Text = string.format("Заработано: +%d Gold\nСкорость: сбор данных...\nВремя: %s", API.totalEarned, UI.timeTrackerLabel and UI.timeTrackerLabel.Text:gsub("Время фарма: ", "") or "00:00:00")
        else
            UI.bsStats.Text = string.format("Заработано: +%d Gold\nСкорость: ~%s G/ч (%.1f/мин)\nВремя: %s", API.totalEarned, API.formatNum(API.estimatedGoldPerHour), API.averageGoldPerMinute, UI.timeTrackerLabel and UI.timeTrackerLabel.Text:gsub("Время фарма: ", "") or "00:00:00")
        end
    end
end

-- Обработка баланса
function API.updateGoldStats()
    local UI = API.UI
    local current = API.getCurrentGold()
    if API.farming then
        local delta = current - API.previousGold
        if delta > 0 then
            API.totalEarned = API.totalEarned + delta
            API.currentMinuteGold = API.currentMinuteGold + delta
            API.playSfx(API.coinSfx)
        end
        API.previousGold = current
        if UI.startAndCurrentGoldLabel then UI.startAndCurrentGoldLabel.Text = "Старт: " .. tostring(API.startGold) .. "  |  Сейчас: " .. tostring(current) end
        if UI.goldTrackerLabel then UI.goldTrackerLabel.Text = "Заработано: +" .. tostring(API.totalEarned) .. " Gold" end
    else
        API.previousGold = current
        if UI.startAndCurrentGoldLabel then UI.startAndCurrentGoldLabel.Text = "Старт: 0  |  Сейчас: " .. tostring(current) end
    end
    API.checkAndAutoBuy()
    API.updateSpeedAndEtaMetrics()
end

task.spawn(function()
    local obj = API.getGoldObject()
    while not obj do
        task.wait(1)
        obj = API.getGoldObject()
    end
    API.previousGold = API.getCurrentGold()
    API.updateGoldStats()
    obj.Changed:Connect(API.updateGoldStats)
end)

-- Фарм цикл с таймаутом 10 секунд на 10 этапе
function API.startFarmingLoop()
    local UI = API.UI
    API.farmThread = task.spawn(function()
        while API.farming do
            local hrp, char, hum = API.getCurrentHRP()
            while API.farming and not hrp do
                task.wait(0.2)
                hrp, char, hum = API.getCurrentHRP()
            end
            if not API.farming then break end

            local resetToFirstStage = false

            if API.farmMode == "Chest" then
                local targetStage = math.clamp(math.floor(tonumber(API.chestStage) or 2), 1, 10)

                for index = 1, targetStage do
                    if not API.farming then break end
                    hrp, char, hum = API.getCurrentHRP()
                    if not hrp then resetToFirstStage = true break end

                    if UI.statusLabel then UI.statusLabel.Text = "Зона " .. index .. "/10" end
                    API.setNoclip(char)
                    API.placeOnPlatform(API.STAGE_COORDINATES[index], hrp)

                    local stageStart = tick()
                    while tick() - stageStart < API.stageDelay do
                        task.wait(0.05)
                        if not API.farming then break end
                        local curHrp = API.getCurrentHRP()
                        if not curHrp or (index > 1 and curHrp.Position.Z < API.SPAWN_Z_MAX) then
                            resetToFirstStage = true
                            break
                        end
                    end
                    if resetToFirstStage then break end
                end

                if resetToFirstStage or not API.farming then
                    API.platform.Parent = nil
                    task.wait(0.5)
                    continue
                end

                hrp, char, hum = API.getCurrentHRP()
                if hrp then
                    if UI.statusLabel then UI.statusLabel.Text = "Сундук (" .. tostring(API.chestDelay) .. " сек)..." end
                    API.setNoclip(char)
                    API.placeOnPlatform(API.CHEST_POSITION, hrp)

                    local chestStart = tick()
                    while tick() - chestStart < API.chestDelay do
                        task.wait(0.05)
                        if not API.farming then break end
                        local curHrp = API.getCurrentHRP()
                        if not curHrp or curHrp.Position.Z < API.SPAWN_Z_MAX then
                            resetToFirstStage = true
                            break
                        end
                    end
                end

                if resetToFirstStage or not API.farming then
                    API.platform.Parent = nil
                    task.wait(0.5)
                    continue
                end

                hrp, char, hum = API.getCurrentHRP()
                if hrp then
                    if UI.statusLabel then UI.statusLabel.Text = "Возврат на зону " .. targetStage .. "..." end
                    API.setNoclip(char)
                    API.placeOnPlatform(API.STAGE_COORDINATES[targetStage], hrp)
                    task.wait(API.stageDelay)
                end

                if targetStage < 10 then
                    for index = (targetStage + 1), 10 do
                        if not API.farming then break end
                        hrp, char, hum = API.getCurrentHRP()
                        if not hrp then resetToFirstStage = true break end

                        if UI.statusLabel then UI.statusLabel.Text = "Зона " .. index .. "/10" end
                        API.setNoclip(char)
                        API.placeOnPlatform(API.STAGE_COORDINATES[index], hrp)

                        local stageStart = tick()
                        while tick() - stageStart < API.stageDelay do
                            task.wait(0.05)
                            if not API.farming then break end
                            local curHrp = API.getCurrentHRP()
                            if not curHrp or curHrp.Position.Z < API.SPAWN_Z_MAX then
                                resetToFirstStage = true
                                break
                            end
                        end
                        if resetToFirstStage then break end
                    end
                end

                if resetToFirstStage or not API.farming then
                    API.platform.Parent = nil
                    task.wait(0.5)
                    continue
                end

                if UI.statusLabel then UI.statusLabel.Text = "10 этап: ожидание спавна..." end
                local stage10Timer = tick()

                while API.farming do
                    task.wait(0.1)
                    local curHrp, curChar, curHum = API.getCurrentHRP()
                    if curHrp and curHrp.Position.Z < API.SPAWN_Z_MAX then break end

                    -- Таймаут 10 секунд -> принудительный сброс
                    if tick() - stage10Timer > 10 then
                        if UI.statusLabel then UI.statusLabel.Text = "10с зависание! Экстренный ресет..." end
                        if curHum then curHum.Health = 0 end
                        while API.farming do
                            task.wait(0.1)
                            local rHrp = API.getCurrentHRP()
                            if rHrp and rHrp.Position.Z < API.SPAWN_Z_MAX then break end
                        end
                        break
                    end
                end

                API.checkAndAutoBuy()
                API.platform.Parent = nil
                task.wait(0.8)

            elseif API.farmMode == "Gold" then
                for index, coord in ipairs(API.STAGE_COORDINATES) do
                    if not API.farming then break end
                    hrp, char, hum = API.getCurrentHRP()
                    if not hrp then resetToFirstStage = true break end

                    if UI.statusLabel then UI.statusLabel.Text = "Зона " .. index .. "/10" end
                    API.setNoclip(char)
                    API.placeOnPlatform(coord, hrp)

                    local stageStart = tick()
                    while tick() - stageStart < API.stageDelay do
                        task.wait(0.05)
                        if not API.farming then break end
                        local curHrp = API.getCurrentHRP()
                        if not curHrp or curHrp.Position.Z < API.SPAWN_Z_MAX then
                            resetToFirstStage = true
                            break
                        end
                    end
                    if resetToFirstStage then break end
                end

                if resetToFirstStage or not API.farming then
                    API.platform.Parent = nil
                    task.wait(0.5)
                    continue
                end

                hrp, char, hum = API.getCurrentHRP()
                if hum then
                    if UI.statusLabel then UI.statusLabel.Text = "10 этап: сброс..." end
                    API.platform.Parent = nil
                    hum.Health = 0

                    local gTimer = tick()
                    while API.farming do
                        task.wait(0.1)
                        local curHrp = API.getCurrentHRP()
                        if curHrp and curHrp.Position.Z < API.SPAWN_Z_MAX then break end
                        if tick() - gTimer > 10 then break end
                    end
                    API.checkAndAutoBuy()
                    task.wait(0.8)
                end
            end
        end
    end)
end

function API.startFarming()
    local UI = API.UI
    if API.farming then return end
    API.farming = true
    API.autoStartOnJoin = true
    if API.saveConfig then API.saveConfig(true) end

    API.startGold = API.getCurrentGold()
    API.previousGold = API.startGold
    API.totalEarned = 0
    table.clear(API.reachedMilestones)

    API.statsStartTime = time()
    API.lastFinalizedMinute = 0
    API.currentMinuteGold = 0
    API.minuteBuckets = {}
    API.minuteSamples = {}
    API.minuteSampleSum = 0
    API.averageGoldPerMinute = 0
    API.estimatedGoldPerHour = 0
    API.currentETA = "Выкл"

    API.updateGoldStats()
    if API.antiHazardActive and API.applyAntiHazard then API.applyAntiHazard(true) end
    if API.antiDarknessActive then API.enableClearVision() end

    API.startTime = os.time()
    if UI.timeTrackerLabel then UI.timeTrackerLabel.Text = "Время фарма: 00:00:00" end

    API.timerThread = task.spawn(function()
        while API.farming do
            local elapsed = math.floor(time() - API.statsStartTime)
            if UI.timeTrackerLabel then UI.timeTrackerLabel.Text = "Время фарма: " .. API.formatTime(elapsed) end
            API.updateSpeedAndEtaMetrics()
            task.wait(1)
        end
    end)

    if UI.toggleButton then
        UI.toggleButton.Text = "STOP AUTO FARM"
        UI.toggleButton.BackgroundColor3 = Color3.fromRGB(220, 50, 70)
    end
    if UI.statusLabel then UI.statusLabel.Text = "Запуск: " .. (API.farmMode == "Chest" and "Сундук" or "Золото") end
    print("[BABFT] Автофарм успешно запущен!")
    API.startFarmingLoop()
end

function API.stopFarming()
    local UI = API.UI
    if not API.farming then return end
    API.farming = false
    API.autoStartOnJoin = false
    if API.saveConfig then API.saveConfig(false) end

    if UI.toggleButton then
        UI.toggleButton.Text = "START AUTO FARM"
        UI.toggleButton.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    end
    if UI.statusLabel then UI.statusLabel.Text = "Статус: Остановлен" end

    if API.timerThread then task.cancel(API.timerThread) API.timerThread = nil end
    local hrp = API.getCurrentHRP()
    if hrp then API.setSpin(hrp, false) end
    API.platform.Parent = nil
    if API.farmThread then task.cancel(API.farmThread) API.farmThread = nil end

    API.updateSpeedAndEtaMetrics()
    print("[BABFT] Автофарм остановлен.")
end

function API.fullCleanup()
    API.farming = false
    API.autoBuyActive = false
    API.autoStartOnJoin = false
    API.disableClearVision()
    if API.toggleAntiHazard then API.toggleAntiHazard(false) end
    if API.toggleBlackScreen then API.toggleBlackScreen(false) end

    if API.idledConn then API.idledConn:Disconnect() end
    if API.stepConn then API.stepConn:Disconnect() end
    if API.farmThread then task.cancel(API.farmThread) end
    if API.timerThread then task.cancel(API.timerThread) end

    local hrp = API.getCurrentHRP()
    if hrp then API.setSpin(hrp, false) end
    if API.platform then API.platform:Destroy() end
    if API.screenGui and API.screenGui.Parent then API.screenGui:Destroy() end
    _G.BABFT = nil
end

_G.BabftActiveScript = { Destroy = API.fullCleanup }
print("[BABFT-Main] Логическое ядро с М1/М2 и ETA готово!")
