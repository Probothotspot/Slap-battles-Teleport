--[[
    Escanor HUB 🔥 – Players Module
    File: Escanor-Hub-players.lua
    By: Brobothotspot
--]]

local PlayersModule = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local LP = Players.LocalPlayer

-- Внутреннее состояние вкладки
local btns = {}
local btnPlayerMap = {}
local searchFilter = ""
local sortByDistance = true
local autoTeleportActive = false
local autoTargetPlayer = nil
local autoLoopConnection = nil
local updateConn = nil

-- Расчет дистанции до выбранного игрока
function PlayersModule.getDistanceToPlayer(p)
    local char = LP.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return 1e9 end

    local tChar = p.Character
    local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
    if not tHrp then return 1e9 end

    return (hrp.Position - tHrp.Position).Magnitude
end

-- Остановка авто-телепорта
function PlayersModule.stopAutoTeleport(context)
    if autoLoopConnection then
        autoLoopConnection:Disconnect()
        autoLoopConnection = nil
    end
    autoTeleportActive = false
    autoTargetPlayer = nil

    if context and context.InstantBtn then
        context.InstantBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        context.InstantBtn.Text = "🎯"
    end
    if context and context.ShowNotification and context.GetText then
        context.ShowNotification(context.GetText("auto_off"), 1.5)
    end
end

-- Включение авто-телепорта за игроком
function PlayersModule.startAutoTeleport(targetPlayer, context)
    if not targetPlayer then return end
    context = context or {}

    autoTargetPlayer = targetPlayer
    autoTeleportActive = true

    if autoLoopConnection then autoLoopConnection:Disconnect() end

    local offset = context.Offset or (_G.TeleportHubSettings and _G.TeleportHubSettings.playerTPOffset) or 2

    autoLoopConnection = RunService.Heartbeat:Connect(function()
        if not autoTeleportActive or not autoTargetPlayer or not autoTargetPlayer.Parent then
            PlayersModule.stopAutoTeleport(context)
            return
        end

        local tChar = autoTargetPlayer.Character
        local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
        local myChar = LP.Character
        local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

        if tHrp and myHrp then
            myHrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, offset)
        end
    end)

    if context.InstantBtn then
        context.InstantBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
        context.InstantBtn.Text = "✅"
    end
    if context.ShowNotification and context.GetText then
        context.ShowNotification("🎯 " .. context.GetText("auto_on") .. ": " .. targetPlayer.Name, 2)
    end
end

-- Отрисовка и инициализация интерфейса вкладки игроков
function PlayersModule.render(parentFrame, context)
    context = context or {}
    local isMobile = context.IsMobile or (_G.TeleportHubSettings and _G.TeleportHubSettings.device == "Mobile")
    local getText = context.GetText or function(k) return k end
    local SmartTP = context.SmartTP or function() end
    local addHistory = context.AddHistory or function() end

    -- Очистка старых элементов
    for _, child in ipairs(parentFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("ScrollingFrame") then
            child:Destroy()
        end
    end
    if updateConn then updateConn:Disconnect(); updateConn = nil end

    -- Верхняя плашка (Поиск + Кнопка сортировки)
    local searchFrameHeight = isMobile and 34 or 28
    local searchFrame = Instance.new("Frame", parentFrame)
    searchFrame.Size = UDim2.new(1, 0, 0, searchFrameHeight)
    searchFrame.Position = UDim2.new(0, 0, 0, 2)
    searchFrame.BackgroundTransparency = 1

    local searchBox = Instance.new("TextBox", searchFrame)
    if isMobile then
        searchBox.Size = UDim2.new(1, 0, 0, 18)
        searchBox.Position = UDim2.new(0, 0, 0, 0)
    else
        searchBox.Size = UDim2.new(0.7, 0, 1, 0)
        searchBox.Position = UDim2.new(0, 0, 0, 0)
    end
    searchBox.BackgroundColor3 = Color3.fromRGB(15, 18, 25)
    searchBox.Text = ""
    searchBox.TextColor3 = Color3.new(1, 1, 1)
    searchBox.TextSize = isMobile and 9 or 11
    searchBox.Font = Enum.Font.Gotham
    searchBox.PlaceholderText = getText("search_placeholder")
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 5)

    local sortBtn = Instance.new("TextButton", searchFrame)
    if isMobile then
        sortBtn.Size = UDim2.new(1, 0, 0, 18)
        sortBtn.Position = UDim2.new(0, 0, 0, 20)
    else
        sortBtn.Size = UDim2.new(0.27, 0, 1, 0)
        sortBtn.Position = UDim2.new(0.73, 0, 0, 0)
    end
    sortBtn.Text = sortByDistance and getText("sort_dist") or getText("sort_name")
    sortBtn.TextColor3 = Color3.new(1, 1, 1)
    sortBtn.TextSize = isMobile and 9 or 11
    sortBtn.Font = Enum.Font.GothamBold
    sortBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    sortBtn.BorderSizePixel = 0
    Instance.new("UICorner", sortBtn).CornerRadius = UDim.new(0, 5)

    -- Список игроков (ScrollingFrame)
    local scroll = Instance.new("ScrollingFrame", parentFrame)
    scroll.Size = UDim2.new(1, 0, 1, -(searchFrameHeight + 8))
    scroll.Position = UDim2.new(0, 0, 0, searchFrameHeight + 6)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0, isMobile and 3 or 5)

    -- Функция перерисовки кнопок игроков
    local function refreshButtons()
        for _, b in ipairs(btns) do b:Destroy() end
        btns = {}
        btnPlayerMap = {}

        local list = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP then
                if searchFilter == "" or string.find(string.lower(p.Name), string.lower(searchFilter)) then
                    table.insert(list, p)
                end
            end
        end

        if sortByDistance then
            table.sort(list, function(a, b)
                return PlayersModule.getDistanceToPlayer(a) < PlayersModule.getDistanceToPlayer(b)
            end)
        else
            table.sort(list, function(a, b)
                return string.lower(a.Name) < string.lower(b.Name)
            end)
        end

        local btnHeight = isMobile and 24 or 32
        for _, p in ipairs(list) do
            local dist = PlayersModule.getDistanceToPlayer(p)
            local distText = (dist < 1000) and string.format(" (%.0fm)", dist) or string.format(" (%.1fkm)", dist / 1000)

            local btn = Instance.new("TextButton", scroll)
            btn.Size = UDim2.new(1, -4, 0, btnHeight)
            btn.Text = p.Name .. distText
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.TextSize = isMobile and 10 or 12
            btn.Font = Enum.Font.GothamSemibold
            btn.BackgroundColor3 = Color3.fromRGB(45, 50, 70)
            btn.BorderSizePixel = 0
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

            btnPlayerMap[btn] = p

            btn.MouseButton1Click:Connect(function()
                if autoTeleportActive then
                    if autoTargetPlayer == p then
                        PlayersModule.stopAutoTeleport(context)
                    else
                        PlayersModule.startAutoTeleport(p, context)
                    end
                else
                    local tChar = p.Character
                    local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
                    if tHrp then
                        local offset = context.Offset or (_G.TeleportHubSettings and _G.TeleportHubSettings.playerTPOffset) or 2
                        local targetCF = tHrp.CFrame * CFrame.new(0, 0, offset)
                        SmartTP(targetCF)
                        addHistory(p.Name, tHrp.CFrame)
                    end
                end
            end)

            table.insert(btns, btn)
        end

        scroll.CanvasSize = UDim2.new(0, 0, 0, #btns * (btnHeight + layout.Padding.Offset) + 10)
    end

    -- Обработчики поиска и сортировки
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchFilter = searchBox.Text
        refreshButtons()
    end)

    sortBtn.MouseButton1Click:Connect(function()
        sortByDistance = not sortByDistance
        sortBtn.Text = sortByDistance and getText("sort_dist") or getText("sort_name")
        refreshButtons()
    end)

    -- Постоянное обновление дистанций в тексте кнопок
    updateConn = RunService.Heartbeat:Connect(function()
        for btn, p in pairs(btnPlayerMap) do
            if btn and btn.Parent and p and p.Parent then
                local dist = PlayersModule.getDistanceToPlayer(p)
                local distText = (dist < 1000) and string.format(" (%.0fm)", dist) or string.format(" (%.1fkm)", dist / 1000)
                btn.Text = p.Name .. distText

                if autoTeleportActive and autoTargetPlayer == p then
                    btn.BackgroundColor3 = Color3.fromRGB(40, 180, 80)
                else
                    btn.BackgroundColor3 = Color3.fromRGB(45, 50, 70)
                end
            end
        end
    end)

    Players.PlayerAdded:Connect(refreshButtons)
    Players.PlayerRemoving:Connect(refreshButtons)

    refreshButtons()
end

-- Алиас Init для совместимости
PlayersModule.Init = PlayersModule.render

-- ОБЯЗАТЕЛЬНЫЙ ЭКСПОРТ ДЛЯ LOADSTRING
return PlayersModule
