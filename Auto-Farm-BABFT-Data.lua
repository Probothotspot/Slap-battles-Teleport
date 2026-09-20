local API = _G.BABFT
if not API then
    warn("[BABFT-Data] Ошибка: Ядро API не найдено!")
    return
end

local HttpService = API.HttpService
local Workspace = API.Workspace
local TeleportService = API.TeleportService
local GuiService = API.GuiService
local player = API.player

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

function API.saveConfig(customAutoStart)
    local UI = API.UI
    if UI.tgTokenInputBox then API.tgToken = UI.tgTokenInputBox.Text end
    if UI.tgChatIdInputBox then API.tgChatId = UI.tgChatIdInputBox.Text end
    if UI.delayBox then
        local valDelay = tonumber(UI.delayBox.Text)
        if valDelay and valDelay > 0 then API.chestDelay = valDelay end
    end
    if UI.stageDelayBox then
        local valStage = tonumber(UI.stageDelayBox.Text)
        if valStage and valStage > 0 then API.stageDelay = valStage end
    end
    if UI.chestStageBox then
        local valChestStage = tonumber(UI.chestStageBox.Text)
        if valChestStage then API.chestStage = math.clamp(math.floor(valChestStage), 1, 10) end
    end
    if UI.amountBox then
        local valAmt = tonumber(UI.amountBox.Text)
        if valAmt and valAmt > 0 then API.buyAmount = math.floor(valAmt) end
    end

    if UI.mainFrame then
        API.windowPosX = UI.mainFrame.Position.X.Offset
        API.windowPosY = UI.mainFrame.Position.Y.Offset
        API.windowScaleX = UI.mainFrame.Position.X.Scale
        API.windowScaleY = UI.mainFrame.Position.Y.Scale
        API.windowSizeX = UI.mainFrame.Size.X.Offset
        API.windowSizeY = UI.mainFrame.Size.Y.Offset
    end

    local shouldAutoStart = API.autoStartOnJoin
    if customAutoStart ~= nil then shouldAutoStart = customAutoStart end

    local data = {
        farmMode = API.farmMode,
        chestDelay = API.chestDelay,
        stageDelay = API.stageDelay,
        chestStage = API.chestStage,
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
        soundEffectsActive = API.soundEffectsActive,
        customSoundsActive = API.customSoundsActive,
        windowPosX = API.windowPosX,
        windowPosY = API.windowPosY,
        windowScaleX = API.windowScaleX,
        windowScaleY = API.windowScaleY,
        windowSizeX = API.windowSizeX,
        windowSizeY = API.windowSizeY
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
                if data.stageDelay then
                    API.stageDelay = tonumber(data.stageDelay) or 1.5
                    if UI.stageDelayBox then UI.stageDelayBox.Text = tostring(API.stageDelay) end
                end
                if data.chestStage then
                    API.chestStage = math.clamp(math.floor(tonumber(data.chestStage) or 2), 1, 10)
                    if UI.chestStageBox then UI.chestStageBox.Text = tostring(API.chestStage) end
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
                    API.toggleAntiHazard(true)
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
                    soundEffectsActive = data.soundEffectsActive
                    if UI.soundToggleBtn then
                        UI.soundToggleBtn.BackgroundColor3 = API.soundEffectsActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                        UI.soundToggleBtn.TextColor3 = API.soundEffectsActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                        UI.soundToggleBtn.Text = API.soundEffectsActive and "🔊 Звуковые эффекты: ВКЛ" or "🔊 Звуковые эффекты: ВЫКЛ"
                    end
                end
                if data.customSoundsActive ~= nil then
                    API.customSoundsActive = data.customSoundsActive
                    if UI.customSoundsBtn then
                        UI.customSoundsBtn.BackgroundColor3 = API.customSoundsActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
                        UI.customSoundsBtn.TextColor3 = API.customSoundsActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
                        UI.customSoundsBtn.Text = API.customSoundsActive and "🐾 Кастомные звуки (Шаги): ВКЛ" or "🐾 Кастомные звуки (Шаги): ВЫКЛ"
                    end
                end

                if data.windowPosX and data.windowPosY and UI.mainFrame then
                    API.windowPosX = data.windowPosX
                    API.windowPosY = data.windowPosY
                    API.windowScaleX = data.windowScaleX or 0.5
                    API.windowScaleY = data.windowScaleY or 0.28
                    UI.mainFrame.Position = UDim2.new(API.windowScaleX, API.windowPosX, API.windowScaleY, API.windowPosY)
                end
                if data.windowSizeX and data.windowSizeY and UI.mainFrame then
                    API.windowSizeX = data.windowSizeX
                    API.windowSizeY = data.windowSizeY
                    UI.mainFrame.Size = UDim2.new(0, API.windowSizeX, 0, API.windowSizeY)
                end

                print("[BABFT-Data] Конфиг успешно загружен!")

                if data.autoStart then
                    API.autoStartOnJoin = true
                    if API.sendTelegramMessage then
                        API.sendTelegramMessage("🔔 <b>Скрипт запущен! Ожидаю загрузку мира...</b>")
                    end
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
                            if API.sendTelegramMessage then
                                API.sendTelegramMessage("✅ <b>Успешный перезаход! Фарм запущен.</b>")
                            end
                        end
                    end)
                end
            end
        end)
    else
        API.toggleAntiHazard(true)
        print("[BABFT-Data] Конфиг не найден, применены настройки по умолчанию.")
    end
end

function API.executeRejoin()
    if API.isRejoining then return end
    API.isRejoining = true

    if API.sendTelegramMessage then
        API.sendTelegramMessage("🔄 <b>Перезахожу на сервер... Фарм продолжится автоматически!</b>")
    end
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
                                    if API.autoBuyActive and API.targetItemPrice > 0 and buyAmount > 0 then
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
                                        API.farmMode == "Chest" and ("Сундук (Этап " .. tostring(API.chestStage) .. ")") or "Золото",
                                        API.averageGoldPerMinute,
                                        API.estimatedGoldPerHour,
                                        etaReportLine,
                                        API.antiDarknessActive and "ВКЛ" or "ВЫКЛ",
                                        API.antiHazardActive and "ВКЛ" or "ВЫКЛ",
                                        API.antiLagActive and "ВКЛ" or "ВЫКЛ",
                                        isBlackScreen and "ВКЛ" or "ВЫКЛ",
                                        formatTime(elapsed),
                                        currentG,
                                        totalEarned
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

print("[BABFT-Data] Модуль базы данных и сети готов!")
