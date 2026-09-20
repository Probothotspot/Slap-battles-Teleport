repeat task.wait(0.2) until game:IsLoaded()

print("[BABFT] Инициализация логического ядра...")

-- Система антидублирования
if _G.BabftActiveScript and type(_G.BabftActiveScript.Destroy) == "function" then
    pcall(_G.BabftActiveScript.Destroy)
end

-- Единая таблица API ядра
_G.BABFT = {}
local API = _G.BABFT
API.UI = {}

-- Сервисы
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-- Конфигурация и ссылки GitHub
API.RAW_GITHUB_URL = "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Auto-farm-BABFT-Main.lua"
API.GUI_URL = "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Auto-Farm-BABFT-GUI.lua"
API.CART_URL = "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Auto-Farm-BABFT-Cart.lua"
API.CHILLZ_GROUP_ID = 2919213
API.CONFIG_FILE = "babft_farm_config.json"

-- Состояние
API.farming = false
API.isRejoining = false
API.isBlackScreen = false
API.isMinimized = false
API.isClosing = false
API.spaceBgActive = true
API.soundEffectsActive = true

API.smoothnessMode = 1
API.smoothnessNames = {
    "120+ FPS (Ultra)",
    "60 FPS (Баланс)",
    "30 FPS (Эко)"
}

API.farmMode = "Chest"
API.chestDelay = 2
API.autoBuyActive = false
API.buyAmount = 1
API.targetItemRealName = ""
API.targetItemPrice = 0
API.autoRejoinActive = true
API.autoStartOnJoin = false
API.antiDarknessActive = true
API.antiHazardActive = true
API.antiLagActive = false
API.staffDetectorActive = true

API.tgToken = ""
API.tgChatId = ""
API.lastUpdateId = 0

-- Статистика и замеры
API.startGold = 0
API.previousGold = 0
API.totalEarned = 0
API.startTime = 0
API.goldValObject = nil

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

-- Потоки
API.farmThread = nil
API.timerThread = nil
API.tgPollingThread = nil
API.cometThread = nil
API.cartAutoBuyThread = nil
API.masterRenderConn = nil
API.rotConn = nil
API.hazardConnection = nil
API.idledConn = nil
API.playerAddedConn = nil

API.httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
API.queue_on_teleport = (syn and syn.queue_on_teleport) or queue_on_teleport or (fluxus and fluxus.queue_on_teleport)

-- База цен
API.KNOWN_ITEMS = {
    ["common"] = {name = "Common Chest", price = 5},
    ["common chest"] = {name = "Common Chest", price = 5},
    ["uncommon"] = {name = "Uncommon Chest", price = 15},
    ["uncommon chest"] = {name = "Uncommon Chest", price = 15},
    ["rare"] = {name = "Rare Chest", price = 45},
    ["rare chest"] = {name = "Rare Chest", price = 45},
    ["epic"] = {name = "Epic Chest", price = 135},
    ["epic chest"] = {name = "Epic Chest", price = 135},
    ["legendary"] = {name = "Legendary Chest", price = 405},
    ["legendary chest"] = {name = "Legendary Chest", price = 405},
    ["trowel"] = {name = "TrowelTool", price = 1500},
    ["мастерок"] = {name = "TrowelTool", price = 1500},
    ["paint"] = {name = "PaintTool", price = 1500},
    ["кисть"] = {name = "PaintTool", price = 1500},
    ["binding"] = {name = "BindingTool", price = 2000},
    ["ключ"] = {name = "BindingTool", price = 2000},
    ["property"] = {name = "PropertyTool", price = 2500},
    ["отвертка"] = {name = "PropertyTool", price = 2500},
    ["scaling"] = {name = "ScalingTool", price = 5000},
    ["рулетка"] = {name = "ScalingTool", price = 5000},
    ["лего"] = {name = "ToyBlock", price = 250},
    ["lego"] = {name = "ToyBlock", price = 250},
    ["toy"] = {name = "ToyBlock", price = 250},
    ["toyblock"] = {name = "ToyBlock", price = 250},
    ["toy building block"] = {name = "ToyBlock", price = 250},
    ["дерево"] = {name = "WoodBlock", price = 250},
    ["wood"] = {name = "WoodBlock", price = 250},
    ["стекло"] = {name = "GlassBlock", price = 200},
    ["glass"] = {name = "GlassBlock", price = 200},
    ["ткань"] = {name = "FabricBlock", price = 300},
    ["fabric"] = {name = "FabricBlock", price = 300},
    ["пластик"] = {name = "PlasticBlock", price = 300},
    ["plastic"] = {name = "PlasticBlock", price = 300},
    ["ржавый металл"] = {name = "RustedMetalBlock", price = 300},
    ["bouncy"] = {name = "BouncyBlock", price = 300},
    ["прыгучий"] = {name = "BouncyBlock", price = 300},
    ["металл"] = {name = "MetalBlock", price = 325},
    ["metal"] = {name = "MetalBlock", price = 325},
    ["уголь"] = {name = "CoalBlock", price = 375},
    ["кирпич"] = {name = "BrickBlock", price = 375},
    ["мрамор"] = {name = "MarbleBlock", price = 375},
    ["обсидиан"] = {name = "ObsidianBlock", price = 400},
    ["титан"] = {name = "TitaniumBlock", price = 425},
    ["знак"] = {name = "SignBlock", price = 45},
    ["мотор"] = {name = "BoatMotor", price = 450},
    ["колеса"] = {name = "CarWheels", price = 750},
    ["парашют"] = {name = "Parachute", price = 45},
    ["гарпун"] = {name = "Harpoon", price = 200},
    ["джетпак"] = {name = "Jetpack", price = 350},
    ["турбина"] = {name = "JetTurbine", price = 4000},
    ["турбины"] = {name = "JetTurbine", price = 4000},
    ["переключатель"] = {name = "Switch", price = 50},
    ["лампа"] = {name = "LightBulb", price = 60},
    ["камера"] = {name = "Camera", price = 85},
    ["дверь"] = {name = "LockedDoor", price = 30},
    ["шарнир"] = {name = "Hinge", price = 45},
    ["поршень"] = {name = "Piston", price = 65},
    ["магнит"] = {name = "Magnet", price = 125},
    ["сенсор"] = {name = "Sensor", price = 25},
    ["пульт"] = {name = "RemoteController", price = 150},
    ["руль"] = {name = "SteeringWheel", price = 150},
    ["веревка"] = {name = "Rope", price = 60},
    ["прут"] = {name = "Bar", price = 60},
    ["подвеска"] = {name = "Suspension", price = 60},
    ["шипы"] = {name = "Spikes", price = 25},
    ["миниган"] = {name = "Minigun", price = 150},
    ["пушка"] = {name = "Cannon", price = 200},
    ["мечи"] = {name = "MountedSwords", price = 50},
    ["динамит"] = {name = "Dynamite", price = 20},
    ["салют"] = {name = "Fireworks", price = 25},
    ["люк"] = {name = "WoodenTrapDoor", price = 15},
    ["ступеньки"] = {name = "Step", price = 50}
}

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

-- Звуки
pcall(function()
    local function createSound(id, vol)
        local s = Instance.new("Sound")
        s.SoundId = "rbxassetid://" .. tostring(id)
        s.Volume = vol or 0.5
        pcall(function() s.Parent = SoundService end)
        return s
    end
    API.clickSfx = createSound(6895079853, 0.4)
    API.coinSfx = createSound(5153734608, 0.5)
    API.achievementSfx = createSound(5153724623, 0.7)
end)

function API.playSfx(sfx)
    if API.soundEffectsActive and sfx then
        pcall(function() sfx:Play() end)
    end
end

-- Платформа
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
        if hrp and hum and hum.Health > 0 then
            return hrp, char, hum
        end
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
        if part:IsA("BasePart") and part ~= API.platform then
            part.CanCollide = false
        end
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

function API.sendTelegramMessage(text)
    if not API.httpRequest or API.tgToken == "" or API.tgChatId == "" then return end
    task.spawn(function()
        pcall(function()
            API.httpRequest({
                Url = "https://api.telegram.org/bot" .. API.tgToken .. "/sendMessage",
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({
                    chat_id = API.tgChatId,
                    text = text,
                    parse_mode = "HTML"
                })
            })
        end)
    end)
end

function API.showAchievementToast(title, text)
    API.playSfx(API.achievementSfx)
    print("[BABFT Достижение] " .. tostring(title) .. ": " .. tostring(text))
end

-- Анти-АФК
API.idledConn = player.Idled:Connect(function()
    VirtualUser:CaptureController()
    VirtualUser:ClickButton2(Vector2.new(0, 0))
end)

-- Детектор Администрации
local function checkStaffMember(p)
    if not API.staffDetectorActive or p == player then return end
    pcall(function()
        local rank = p:GetRankInGroup(API.CHILLZ_GROUP_ID)
        if rank and rank > 1 then
            local role = p:GetRoleInGroup(API.CHILLZ_GROUP_ID)
            API.sendTelegramMessage(string.format(
                "🚨 <b>ВНИМАНИЕ! НА СЕРВЕР ЗАШЕЛ АДМИН!</b>\n\n• Игрок: <b>%s</b> (@%s)\n• Должность: <b>%s</b> (Ранг %d)\n⚠️ Фарм остановлен, произвожу экстренный перезаход!",
                p.DisplayName, p.Name, role, rank
            ))
            API.stopFarming()
            task.wait(0.5)
            API.executeRejoin()
        end
    end)
end

API.playerAddedConn = Players.PlayerAdded:Connect(checkStaffMember)
task.spawn(function()
    for _, p in ipairs(Players:GetPlayers()) do
        checkStaffMember(p)
    end
end)

-- Анти-Лаг
local lastAntiLagRun = 0
function API.applyAntiLag(force)
    if not API.antiLagActive then return end
    if not force and (os.clock() - lastAntiLagRun < 20) then return end
    lastAntiLagRun = os.clock()

    task.spawn(function()
        pcall(function()
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("BasePart") and not v:IsDescendantOf(player.Character) and v ~= API.platform then
                    v.Material = Enum.Material.SmoothPlastic
                    v.CastShadow = false
                elseif v:IsA("Decal") or v:IsA("Texture") or v:IsA("ParticleEmitter") or v:IsA("Trail") or v:IsA("Smoke") or v:IsA("Fire") then
                    if not v:IsDescendantOf(player.Character) then
                        v:Destroy()
                    end
                end
            end
        end)
    end)
end

-- Защита от воды
local cachedHazards = {}
local function refreshHazardCache()
    table.clear(cachedHazards)
    local stages = Workspace:FindFirstChild("BoatStages")
    if stages then
        for _, v in ipairs(stages:GetDescendants()) do
            if v:IsA("BasePart") then
                local name = v.Name:lower()
                if name:find("water") or name:find("lava") or name:find("kill") or name:find("damage") then
                    table.insert(cachedHazards, v)
                end
            end
        end
    end
end

function API.applyAntiHazard(state)
    for i = #cachedHazards, 1, -1 do
        local part = cachedHazards[i]
        if part and part.Parent then
            part.CanTouch = not state
        else
            table.remove(cachedHazards, i)
        end
    end
end

function API.toggleAntiHazard(enabled)
    API.antiHazardActive = enabled
    if API.antiHazardActive then
        refreshHazardCache()
        API.applyAntiHazard(true)
        if not API.hazardConnection then
            API.hazardConnection = Workspace.DescendantAdded:Connect(function(v)
                if API.antiHazardActive and v:IsA("BasePart") then
                    local name = v.Name:lower()
                    if name:find("water") or name:find("lava") or name:find("kill") or name:find("damage") then
                        table.insert(cachedHazards, v)
                        v.CanTouch = false
                    end
                end
            end)
        end
    else
        if API.hazardConnection then
            API.hazardConnection:Disconnect()
            API.hazardConnection = nil
        end
        API.applyAntiHazard(false)
    end
end

-- Освещение
local defaultLighting = {
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogEnd = Lighting.FogEnd,
    GlobalShadows = Lighting.GlobalShadows
}
local disabledEffects = {}
local hiddenFadeFrames = {}

function API.enableClearVision()
    if not API.antiDarknessActive then return end
    pcall(function()
        Lighting.Ambient = Color3.fromRGB(255, 255, 255)
        Lighting.OutdoorAmbient = Color3.fromRGB(255, 255, 255)
        Lighting.Brightness = 2
        Lighting.ClockTime = 14
        Lighting.FogEnd = 1e6
        Lighting.GlobalShadows = false

        for _, fx in ipairs(Lighting:GetChildren()) do
            if fx:IsA("PostEffect") and fx.Enabled then
                table.insert(disabledEffects, fx)
                fx.Enabled = false
            end
        end

        local pGui = player:FindFirstChild("PlayerGui")
        if pGui then
            for _, v in ipairs(pGui:GetDescendants()) do
                if v:IsA("Frame") and v.Visible and v.BackgroundTransparency < 0.5 then
                    local col = v.BackgroundColor3
                    if (col.R + col.G + col.B) < 0.25 then
                        table.insert(hiddenFadeFrames, {frame = v, prevVis = v.Visible, prevTrans = v.BackgroundTransparency})
                        v.Visible = false
                    end
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

        for _, fx in ipairs(disabledEffects) do
            if fx and fx.Parent then fx.Enabled = true end
        end
        table.clear(disabledEffects)

        for _, item in ipairs(hiddenFadeFrames) do
            if item.frame and item.frame.Parent then
                item.frame.Visible = item.prevVis
                item.frame.BackgroundTransparency = item.prevTrans
            end
        end
        table.clear(hiddenFadeFrames)
    end)
end

function API.searchItemInGame(query)
    query = string.lower(string.gsub(query, "%s+", ""))
    if query == "" then return nil, 0 end

    for key, data in pairs(API.KNOWN_ITEMS) do
        local cleanKey = string.lower(string.gsub(key, "%s+", ""))
        if cleanKey == query or string.find(cleanKey, query) or string.find(query, cleanKey) then
            return data.name, data.price
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
                                if parsed and parsed > 0 then return frame.Text, parsed end
                            end
                        end
                    end
                end
            end
        end
    end
    return nil, 0
end

function API.executeBuy(itemName, amount)
    local rName, price = API.searchItemInGame(itemName)
    if not rName or price <= 0 then
        return false, "Предмет '" .. tostring(itemName) .. "' не найден в магазине."
    end
    amount = tonumber(amount) or 1
    local totalCost = price * amount
    if API.getCurrentGold() < totalCost then
        return false, "Недостаточно золота! Нужно: " .. totalCost .. " Gold."
    end
    local buyRemote = Workspace:FindFirstChild("ItemBoughtFromShop")
    if buyRemote then
        local ok = pcall(function()
            buyRemote:InvokeServer(rName, amount)
        end)
        if ok then
            return true, "Успешно куплено: " .. rName .. " (" .. amount .. " шт.)"
        end
    end
    return false, "Ошибка удаленного вызова покупки."
end

function API.checkAndAutoBuy()
    if not API.autoBuyActive or API.targetItemRealName == "" or API.targetItemPrice <= 0 then return end
    local totalCost = API.targetItemPrice * API.buyAmount
    if API.getCurrentGold() >= totalCost then
        local buyRemote = Workspace:FindFirstChild("ItemBoughtFromShop")
        if buyRemote then
            pcall(function()
                buyRemote:InvokeServer(API.targetItemRealName, API.buyAmount)
            end)
        end
    end
end

-- Поминутная статистика и ETA
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
                currentMinuteGold = 0
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
            UI.goldSpeedLabel.Text = string.format("Скорость: ~%d G/ч (%.1f G/мин)", API.estimatedGoldPerHour, API.averageGoldPerMinute)
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

    -- Расчет ETA
    if API.autoBuyActive and API.targetItemPrice > 0 and API.buyAmount > 0 then
        local currentG = API.getCurrentGold()
        local totalCost = API.targetItemPrice * API.buyAmount
        local remainingGold = totalCost - currentG

        if remainingGold <= 0 then
            API.currentETA = "Покупка: сейчас"
            if UI.etaLabel then
                UI.etaLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
                UI.etaLabel.Text = "Покупка: сейчас"
            end
        elseif API.lastFinalizedMinute == 0 or API.averageGoldPerMinute <= 0 then
            API.currentETA = "после 1 мин."
            if UI.etaLabel then
                UI.etaLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                UI.etaLabel.Text = string.format("Нужно %d G | ETA после 1 мин.", remainingGold)
            end
        else
            local etaSeconds = math.floor((remainingGold / API.averageGoldPerMinute) * 60)
            API.currentETA = API.formatTime(etaSeconds)
            if UI.etaLabel then
                UI.etaLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
                UI.etaLabel.Text = string.format("Нужно %d G | ETA: %s", remainingGold, API.currentETA)
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
            UI.bsStats.Text = string.format("Заработано: +%d Gold\nСкорость: ~%d G/ч (%.1f/мин)\nВремя: %s", API.totalEarned, API.estimatedGoldPerHour, API.averageGoldPerMinute, UI.timeTrackerLabel and UI.timeTrackerLabel.Text:gsub("Время фарма: ", "") or "00:00:00")
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

            for _, m in ipairs(API.MILESTONES) do
                if API.totalEarned >= m and not API.reachedMilestones[m] then
                    API.reachedMilestones[m] = true
                    API.showAchievementToast("НОВОЕ ДОСТИЖЕНИЕ!", "Заработано +" .. tostring(m) .. " Gold!")
                    API.sendTelegramMessage(string.format("🏆 <b>ДОСТИЖЕНИЕ РАЗБЛОКИРОВАНО!</b>\nСессия принесла уже более <b>+%d Gold</b>!", m))
                end
            end
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

-- Фарм цикл
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
                for index = 1, 2 do
                    if not API.farming then break end
                    hrp, char, hum = API.getCurrentHRP()
                    if not hrp then resetToFirstStage = true break end

                    if UI.statusLabel then UI.statusLabel.Text = "Зона " .. index .. "/10" end
                    API.setNoclip(char)
                    API.placeOnPlatform(API.STAGE_COORDINATES[index], hrp)

                    local stageStart = tick()
                    while tick() - stageStart < 1.5 do
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
                    API.disableClearVision()
                    task.wait(0.5)
                    continue
                end

                hrp, char, hum = API.getCurrentHRP()
                if hrp then
                    if UI.statusLabel then UI.statusLabel.Text = "Сундук (" .. tostring(API.chestDelay) .. " сек)..." end
                    API.enableClearVision()
                    API.setNoclip(char)
                    API.placeOnPlatform(API.CHEST_POSITION, hrp)

                    local chestStart = tick()
                    while tick() - chestStart < API.chestDelay do
                        task.wait(0.1)
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
                    API.disableClearVision()
                    task.wait(0.5)
                    continue
                end

                hrp, char, hum = API.getCurrentHRP()
                if hrp then
                    if UI.statusLabel then UI.statusLabel.Text = "Возврат на зону 2..." end
                    API.disableClearVision()
                    API.setNoclip(char)
                    API.placeOnPlatform(API.STAGE_COORDINATES[2], hrp)
                    task.wait(1.5)
                end

                for index = 3, 10 do
                    if not API.farming then break end
                    hrp, char, hum = API.getCurrentHRP()
                    if not hrp then resetToFirstStage = true break end

                    if UI.statusLabel then UI.statusLabel.Text = "Зона " .. index .. "/10" end
                    API.setNoclip(char)
                    API.placeOnPlatform(API.STAGE_COORDINATES[index], hrp)

                    local stageStart = tick()
                    while tick() - stageStart < 1.5 do
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
                    API.disableClearVision()
                    task.wait(0.5)
                    continue
                end

                if UI.statusLabel then UI.statusLabel.Text = "10 этап: ожидание спавна..." end
                while API.farming do
                    task.wait(0.1)
                    local curHrp = API.getCurrentHRP()
                    if curHrp and curHrp.Position.Z < API.SPAWN_Z_MAX then break end
                end

                API.disableClearVision()
                API.checkAndAutoBuy()
                API.platform.Parent = nil
                task.wait(0.8)

            elseif API.farmMode == "Gold" then
                API.disableClearVision()
                for index, coord in ipairs(API.STAGE_COORDINATES) do
                    if not API.farming then break end
                    hrp, char, hum = API.getCurrentHRP()
                    if not hrp then resetToFirstStage = true break end

                    if UI.statusLabel then UI.statusLabel.Text = "Зона " .. index .. "/10" end
                    API.setNoclip(char)
                    API.placeOnPlatform(coord, hrp)

                    local stageStart = tick()
                    while tick() - stageStart < 1.5 do
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

                    if UI.statusLabel then UI.statusLabel.Text = "Возрождение на спавне..." end
                    while API.farming do
                        task.wait(0.1)
                        local curHrp = getCurrentHRP()
                        if curHrp and curHrp.Position.Z < API.SPAWN_Z_MAX then break end
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
    API.saveConfig(true)

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
    if API.antiHazardActive then API.applyAntiHazard(true) end

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
    if UI.statusLabel then
        UI.statusLabel.Text = "Запуск: " .. (API.farmMode == "Chest" and "Сундук" or "Золото")
    end
    print("[BABFT] Автофарм успешно запущен!")
    API.startFarmingLoop()
end

function API.stopFarming()
    local UI = API.UI
    if not API.farming then return end
    API.farming = false
    API.autoStartOnJoin = false
    API.saveConfig(false)
    API.disableClearVision()

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
    API.toggleAntiHazard(false)
    if API.toggleBlackScreen then API.toggleBlackScreen(false) end

    if API.idledConn then API.idledConn:Disconnect() end
    if API.playerAddedConn then API.playerAddedConn:Disconnect() end
    if API.masterRenderConn then API.masterRenderConn:Disconnect() end
    if API.rotConn then API.rotConn:Disconnect() end
    if API.hazardConnection then API.hazardConnection:Disconnect() end
    if API.farmThread then task.cancel(API.farmThread) end
    if API.timerThread then task.cancel(API.timerThread) end
    if API.tgPollingThread then task.cancel(API.tgPollingThread) end
    if API.cometThread then task.cancel(API.cometThread) end
    if API.cartAutoBuyThread then task.cancel(API.cartAutoBuyThread) end

    local hrp = API.getCurrentHRP()
    if hrp then API.setSpin(hrp, false) end
    if API.platform then API.platform:Destroy() end
    if API.screenGui and API.screenGui.Parent then API.screenGui:Destroy() end
    _G.BABFT = nil
end

_G.BabftActiveScript = { Destroy = API.fullCleanup }

function API.saveConfig(customAutoStart)
    local UI = API.UI
    if UI.tgTokenInputBox then API.tgToken = UI.tgTokenInputBox.Text end
    if UI.tgChatIdInputBox then API.tgChatId = UI.tgChatIdInputBox.Text end
    if UI.delayBox then
        local valDelay = tonumber(UI.delayBox.Text)
        if valDelay and valDelay > 0 then API.chestDelay = valDelay end
    end
    if UI.amountBox then
        local valAmt = tonumber(UI.amountBox.Text)
        if valAmt and valAmt > 0 then API.buyAmount = math.floor(valAmt) end
    end

    local shouldAutoStart = API.autoStartOnJoin
    if customAutoStart ~= nil then shouldAutoStart = customAutoStart end

    local data = {
        farmMode = API.farmMode,
        chestDelay = API.chestDelay,
        autoBuyActive = API.autoBuyActive,
        buyAmount = API.buyAmount,
        targetItem = UI.itemInputBox and UI.itemInputBox.Text or "",
        tgToken = API.tgToken,
        tgChatId = API.tgChatId,
        autoStart = shouldAutoStart,
        antiDarknessActive = API.antiDarknessActive,
        antiHazardActive = API.antiHazardActive,
        antiLagActive = API.antiLagActive,
        staffDetectorActive = API.staffDetectorActive,
        spaceBgActive = API.spaceBgActive,
        smoothnessMode = API.smoothnessMode,
        soundEffectsActive = API.soundEffectsActive
    }

    if writefile then
        pcall(function() writefile(API.CONFIG_FILE, HttpService:JSONEncode(data)) end)
    end
end

function API.loadConfig()
    local UI = API.UI
    if isfile and readfile and isfile(API.CONFIG_FILE) then
        pcall(function()
            local content = readfile(API.CONFIG_FILE)
            local data = HttpService:JSONDecode(content)
            if data and type(data) == "table" then
                if data.farmMode then
                    API.farmMode = data.farmMode
                    if UI.chestModeBtn then
                        UI.chestModeBtn.BackgroundColor3 = (API.farmMode == "Chest") and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                        UI.chestModeBtn.TextColor3 = (API.farmMode == "Chest") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 145, 185)
                    end
                    if UI.goldModeBtn then
                        UI.goldModeBtn.BackgroundColor3 = (API.farmMode == "Gold") and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                        UI.goldModeBtn.TextColor3 = (API.farmMode == "Gold") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 145, 185)
                    end
                end
                if data.chestDelay then
                    API.chestDelay = tonumber(data.chestDelay) or 2
                    if UI.delayBox then UI.delayBox.Text = tostring(API.chestDelay) end
                end
                if data.buyAmount then
                    API.buyAmount = tonumber(data.buyAmount) or 1
                    if UI.amountBox then UI.amountBox.Text = tostring(API.buyAmount) end
                end
                if data.targetItem and UI.itemInputBox then
                    UI.itemInputBox.Text = data.targetItem
                    local rName, price = API.searchItemInGame(data.targetItem)
                    if rName and price > 0 then
                        API.targetItemRealName = rName
                        API.targetItemPrice = price
                        if UI.itemStatusLabel then
                            UI.itemStatusLabel.Text = "Блок найден: " .. rName .. " (" .. tostring(price) .. " Gold)"
                            UI.itemStatusLabel.TextColor3 = Color3.fromRGB(80, 240, 130)
                        end
                    end
                end
                if data.tgToken then
                    API.tgToken = data.tgToken
                    if UI.tgTokenInputBox then UI.tgTokenInputBox.Text = API.tgToken end
                end
                if data.tgChatId then
                    API.tgChatId = data.tgChatId
                    if UI.tgChatIdInputBox then UI.tgChatIdInputBox.Text = API.tgChatId end
                end
                if data.autoBuyActive then
                    API.autoBuyActive = data.autoBuyActive
                    if UI.autoBuyToggleBtn then
                        UI.autoBuyToggleBtn.BackgroundColor3 = API.autoBuyActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                        UI.autoBuyToggleBtn.TextColor3 = API.autoBuyActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                        UI.autoBuyToggleBtn.Text = API.autoBuyActive and "Авто-закупка: ВКЛ" or "Авто-закупка: ВЫКЛ"
                    end
                end
                if data.antiDarknessActive ~= nil then
                    API.antiDarknessActive = data.antiDarknessActive
                    if UI.antiDarkBtn then
                        UI.antiDarkBtn.BackgroundColor3 = API.antiDarknessActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                        UI.antiDarkBtn.TextColor3 = API.antiDarknessActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                        UI.antiDarkBtn.Text = API.antiDarknessActive and "Анти-темнота: ВКЛ" or "Анти-темнота: ВЫКЛ"
                    end
                end
                if data.antiHazardActive ~= nil then
                    API.antiHazardActive = data.antiHazardActive
                    if UI.antiHazardBtn then
                        UI.antiHazardBtn.BackgroundColor3 = API.antiHazardActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                        UI.antiHazardBtn.TextColor3 = API.antiHazardActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                        UI.antiHazardBtn.Text = API.antiHazardActive and "🛡 Анти-урон / Вода: ВКЛ" or "🛡 Анти-урон / Вода: ВЫКЛ"
                    end
                    API.toggleAntiHazard(API.antiHazardActive)
                else
                    toggleAntiHazard(true)
                end
                if data.antiLagActive ~= nil then
                    API.antiLagActive = data.antiLagActive
                    if UI.antiLagBtn then
                        UI.antiLagBtn.BackgroundColor3 = API.antiLagActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                        UI.antiLagBtn.TextColor3 = API.antiLagActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                        UI.antiLagBtn.Text = API.antiLagActive and "⚡ Анти-лаг очистка: ВКЛ" or "⚡ Анти-лаг очистка: ВЫКЛ"
                    end
                    if API.antiLagActive then API.applyAntiLag(true) end
                end
                if data.spaceBgActive ~= nil then
                    spaceBgActive = data.spaceBgActive
                    if UI.spaceBg then UI.spaceBg.Visible = API.spaceBgActive end
                    if UI.spaceBgBtn then
                        UI.spaceBgBtn.BackgroundColor3 = API.spaceBgActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                        UI.spaceBgBtn.TextColor3 = API.spaceBgActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                        UI.spaceBgBtn.Text = API.spaceBgActive and "🌌 Космо-фон: ВКЛ" or "🌌 Космо-фон: ВЫКЛ"
                    end
                end
                if data.smoothnessMode then
                    API.smoothnessMode = math.clamp(tonumber(data.smoothnessMode) or 1, 1, 3)
                    if UI.smoothnessBtn then UI.smoothnessBtn.Text = "🚀 Плавность: " .. API.smoothnessNames[API.smoothnessMode] end
                end
                if data.soundEffectsActive ~= nil then
                    API.soundEffectsActive = data.soundEffectsActive
                    if UI.soundToggleBtn then
                        UI.soundToggleBtn.BackgroundColor3 = API.soundEffectsActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                        UI.soundToggleBtn.TextColor3 = API.soundEffectsActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                        UI.soundToggleBtn.Text = API.soundEffectsActive and "🔊 Звуковые эффекты: ВКЛ" or "🔊 Звуковые эффекты: ВЫКЛ"
                    end
                end

                print("[BABFT] Конфигурация успешно загружена!")

                if data.autoStart then
                    API.autoStartOnJoin = true
                    API.sendTelegramMessage("🔔 <b>Скрипт запущен! Ожидаю загрузку мира...</b>")
                    task.spawn(function()
                        local char = player.Character or player.CharacterAdded:Wait()
                        local hrp = char:WaitForChild("HumanoidRootPart", 15)
                        while not hrp do
                            task.wait(0.5)
                            char = player.Character
                            if char then hrp = char:FindFirstChild("HumanoidRootPart") end
                        end
                        
                        local gObj = API.getGoldObject()
                        local t = 0
                        while not gObj and t < 15 do
                            task.wait(0.5)
                            t = t + 0.5
                            gObj = API.getGoldObject()
                        end

                        task.wait(2)
                        if not API.farming then
                            API.startFarming()
                            API.sendTelegramMessage("✅ <b>Успешный перезаход! Фарм запущен.</b>")
                        end
                    end)
                end
            end
        end)
    else
        API.toggleAntiHazard(true)
        print("[BABFT] Конфиг не найден, применены стандартные настройки.")
    end
end

function API.executeRejoin()
    if API.isRejoining then return end
    API.isRejoining = true

    API.sendTelegramMessage("🔄 <b>Перезахожу на сервер... Фарм продолжится автоматически!</b>")
    API.saveConfig(true)

    if API.queue_on_teleport then
        pcall(function()
            API.queue_on_teleport(string.format([[
                repeat task.wait() until game:IsLoaded()
                task.wait(1)
                pcall(function() loadstring(game:HttpGet("%s"))() end)
            ]], API.RAW_GITHUB_URL))
        end)
    end

    task.wait(1)
    pcall(function() TeleportService:Teleport(game.PlaceId, player) end)
end

GuiService.ErrorMessageChanged:Connect(function()
    if API.autoRejoinActive then API.executeRejoin() end
end)

-- Telegram Polling
local function syncTelegramOffset()
    if API.httpRequest and API.tgToken ~= "" then
        pcall(function()
            local res = API.httpRequest({
                Url = "https://api.telegram.org/bot" .. API.tgToken .. "/getUpdates?offset=-1",
                Method = "GET"
            })
            if res and res.Body then
                local data = HttpService:JSONDecode(res.Body)
                if data and data.ok and data.result and #data.result > 0 then
                    API.lastUpdateId = data.result[#data.result].update_id
                    API.httpRequest({
                        Url = "https://api.telegram.org/bot" .. API.tgToken .. "/getUpdates?offset=" .. tostring(API.lastUpdateId + 1) .. "&limit=1",
                        Method = "GET"
                    })
                end
            end
        end)
    end
end

API.tgPollingThread = task.spawn(function()
    task.wait(2)
    syncTelegramOffset()

    while true do
        task.wait(3)
        if API.httpRequest and API.tgToken ~= "" and API.tgChatId ~= "" and not API.isRejoining then
            pcall(function()
                local pollUrl = "https://api.telegram.org/bot" .. API.tgToken .. "/getUpdates?offset=" .. tostring(API.lastUpdateId + 1) .. "&limit=5"
                local res = API.httpRequest({ Url = pollUrl, Method = "GET" })

                if res and res.Body then
                    local data = HttpService:JSONDecode(res.Body)
                    if data and data.ok and data.result then
                        for _, update in ipairs(data.result) do
                            API.lastUpdateId = update.update_id
                            local msg = update.message
                            if msg and tostring(msg.chat.id) == tostring(API.tgChatId) and msg.text then
                                local fullText = msg.text
                                local parts = string.split(fullText, " ")
                                local cmd = string.lower(parts[1] or "")

                                if cmd == "/stop" then
                                    if API.farming then
                                        API.stopFarming()
                                        API.sendTelegramMessage("🛑 <b>Фарм остановлен дистанционно!</b>")
                                    else
                                        API.sendTelegramMessage("⚠️ Фарм уже выключен.")
                                    end
                                elseif cmd == "/start" then
                                    if not API.farming then
                                        API.startFarming()
                                        API.sendTelegramMessage("🚀 <b>Фарм запущен дистанционно!</b>")
                                    else
                                        API.sendTelegramMessage("⚠️ Фарм уже работает.")
                                    end
                                elseif cmd == "/mode" then
                                    API.farmMode = (API.farmMode == "Chest" and "Gold" or "Chest")
                                    local UI = API.UI
                                    if UI.chestModeBtn then
                                        UI.chestModeBtn.BackgroundColor3 = (API.farmMode == "Chest") and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                                        UI.chestModeBtn.TextColor3 = (API.farmMode == "Chest") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 145, 185)
                                    end
                                    if UI.goldModeBtn then
                                        UI.goldModeBtn.BackgroundColor3 = (API.farmMode == "Gold") and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                                        UI.goldModeBtn.TextColor3 = (API.farmMode == "Gold") and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(160, 145, 185)
                                    end
                                    API.saveConfig()
                                    API.sendTelegramMessage("🔄 <b>Режим фарма переключен на:</b> " .. (API.farmMode == "Chest" and "Сундук" or "Золото"))
                                elseif cmd == "/afk" or cmd == "/screen" then
                                    if API.toggleBlackScreen then
                                        API.toggleBlackScreen(not API.isBlackScreen)
                                        local UI = API.UI
                                        if UI.batterySaverBtn then
                                            UI.batterySaverBtn.BackgroundColor3 = API.isBlackScreen and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                                            UI.batterySaverBtn.TextColor3 = API.isBlackScreen and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                                            UI.batterySaverBtn.Text = API.isBlackScreen and "🔋 Ночной режим (Экран): ВКЛ" or "🔋 Ночной режим (Экран): ВЫКЛ"
                                        end
                                        API.sendTelegramMessage("🔋 <b>Ночной режим энергосбережения:</b> " .. (API.isBlackScreen and "ВКЛЮЧЕН" or "ВЫКЛЮЧЕН"))
                                    end
                                elseif cmd == "/lag" then
                                    API.antiLagActive = not API.antiLagActive
                                    local UI = API.UI
                                    if UI.antiLagBtn then
                                        UI.antiLagBtn.BackgroundColor3 = API.antiLagActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                                        UI.antiLagBtn.TextColor3 = API.antiLagActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                                        UI.antiLagBtn.Text = API.antiLagActive and "⚡ Анти-лаг очистка: ВКЛ" or "⚡ Анти-лаг очистка: ВЫКЛ"
                                    end
                                    if API.antiLagActive then API.applyAntiLag(true) end
                                    API.saveConfig()
                                    API.sendTelegramMessage("⚡ <b>Анти-лаг очистка:</b> " .. (API.antiLagActive and "ВКЛЮЧЕНА" or "ВЫКЛЮЧЕНА"))
                                elseif cmd == "/buy" then
                                    local itemArg = parts[2]
                                    local amountArg = tonumber(parts[3]) or 1
                                    if not itemArg then
                                        API.sendTelegramMessage("⚠️ Формат команды: <code>/buy [блок] [кол-во]</code>\nПример: <code>/buy лего 5</code>")
                                    else
                                        local success, resultMsg = API.executeBuy(itemArg, amountArg)
                                        if success then
                                            API.sendTelegramMessage("🛍 <b>" .. resultMsg .. "</b>")
                                            API.showAchievementToast("ПОКУПКА ИЗ TELEGRAM", resultMsg)
                                        else
                                            API.sendTelegramMessage("❌ <b>Ошибка:</b> " .. resultMsg)
                                        end
                                    end
                                elseif cmd == "/god" or cmd == "/water" then
                                    API.toggleAntiHazard(not API.antiHazardActive)
                                    local UI = API.UI
                                    if UI.antiHazardBtn then
                                        UI.antiHazardBtn.BackgroundColor3 = API.antiHazardActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                                        UI.antiHazardBtn.TextColor3 = API.antiHazardActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                                        UI.antiHazardBtn.Text = API.antiHazardActive and "🛡 Анти-урон / Вода: ВКЛ" or "🛡 Анти-урон / Вода: ВЫКЛ"
                                    end
                                    API.saveConfig()
                                    API.sendTelegramMessage("🛡 <b>Защита от воды/урона:</b> " .. (API.antiHazardActive and "ВКЛ" or "ВЫКЛ"))
                                elseif cmd == "/kill" or cmd == "/shutdown" then
                                    API.saveConfig(false)
                                    API.sendTelegramMessage("💀 <b>Скрипт полностью остановлен и деактивирован!</b>\nАвто-старт и авто-перезаход отключены.")
                                    API.fullCleanup()
                                elseif cmd == "/status" then
                                    local currentG = API.getCurrentGold()
                                    local elapsed = API.farming and math.max(os.time() - API.startTime, 1) or 0
                                    local etaReportLine = ""
                                    if API.autoBuyActive and API.targetItemPrice > 0 and API.buyAmount > 0 then
                                        local targetTotal = API.targetItemPrice * API.buyAmount
                                        local needed = targetTotal - currentG
                                        if needed <= 0 then
                                            etaReportLine = string.format("\n• Автопокупка: <b>%s</b>\n• Стоимость: <b>%d Gold</b>\n• Не хватает: <b>0 Gold</b>\n• ETA: <b>сейчас</b>", API.targetItemRealName ~= "" and API.targetItemRealName or "Предмет", targetTotal)
                                        elseif API.lastFinalizedMinute == 0 or API.averageGoldPerMinute <= 0 then
                                            etaReportLine = string.format("\n• Автопокупка: <b>%s</b>\n• Стоимость: <b>%d Gold</b>\n• Не хватает: <b>%d Gold</b>\n• ETA: <b>ожидаю первый минутный замер</b>", API.targetItemRealName ~= "" and API.targetItemRealName or "Предмет", targetTotal, needed)
                                        else
                                            local secondsNeeded = math.floor((needed / API.averageGoldPerMinute) * 60)
                                            etaReportLine = string.format("\n• Автопокупка: <b>%s</b>\n• Стоимость: <b>%d Gold</b>\n• Не хватает: <b>%d Gold</b>\n• ETA: <b>%s</b>", API.targetItemRealName ~= "" and API.targetItemRealName or "Предмет", targetTotal, needed, API.formatTime(secondsNeeded))
                                        end
                                    end

                                    local report = string.format(
                                        "📊 <b>Статистика BABFT:</b>\n\n• Состояние: <b>%s</b>\n• Режим: <b>%s</b>\n• Среднее: <b>%.1f Gold/мин</b>\n• Прогноз: <b>~%d Gold/час</b>%s\n• Анти-темнота: <b>%s</b>\n• Анти-вода/урон: <b>%s</b>\n• Анти-лаг: <b>%s</b>\n• Ночной экран: <b>%s</b>\n• Время сессии: <b>%s</b>\n• Баланс: <b>%d Gold</b>\n• Заработано: <b>+%d Gold</b>",
                                        API.farming and "🟢 Работает" or "🔴 Остановлен",
                                        API.farmMode == "Chest" and "Сундук" or "Золото",
                                        API.averageGoldPerMinute,
                                        API.estimatedGoldPerHour,
                                        etaReportLine,
                                        API.antiDarknessActive and "ВКЛ" or "ВЫКЛ",
                                        API.antiHazardActive and "ВКЛ" or "ВЫКЛ",
                                        API.antiLagActive and "ВКЛ" or "ВЫКЛ",
                                        API.isBlackScreen and "ВКЛ" or "ВЫКЛ",
                                        API.formatTime(elapsed),
                                        currentG,
                                        API.totalEarned
                                    )
                                    API.sendTelegramMessage(report)
                                elseif cmd == "/rejoin" then
                                    API.executeRejoin()
                                end
                            end
                        end
                    end
                end
            end)
        end
    end
end)

-- Авто-загрузка GUI
print("[BABFT] Загрузка GUI файла...")
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet(API.GUI_URL .. "?t=" .. tostring(os.time())))()
    end)
    if not ok then
        warn("[BABFT] Ошибка загрузки GUI: " .. tostring(err))
    end
end)
