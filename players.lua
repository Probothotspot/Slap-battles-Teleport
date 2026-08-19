--[[
    Escanor HUB 🔥 — Модуль вкладки «Игроки» (Players Module)
    Файл: players.lua
--]]

return function(playersContent, ctx)
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer
    local RunService = game:GetService("RunService")
    local TweenService = game:GetService("TweenService")

    -- 1. Извлечение контекста от основного скрипта
    local isMobile = ctx.isMobile or false
    local currentLang = ctx.currentLang or "ru"
    local currentTheme = ctx.currentTheme or "dark"
    local themes = ctx.themes or {}
    local t = themes[currentTheme] or {
        textColor = Color3.new(1, 1, 1),
        inputBg = Color3.fromRGB(15, 15, 20)
    }

    local playerTPOffset = ctx.playerTPOffset or 2
    local starsEnabled = (ctx.starsEnabled ~= false)
    local SmartTP = ctx.SmartTP or function(cf)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = cf
        end
    end
    local showNotification = ctx.showNotification or function() end
    local addHistoryEntry = ctx.addHistoryEntry or function() end
    local instantBtn = ctx.instantBtn -- Кнопка 🎯 на панели действий (если передана)

    -- 2. Словари переводов
    local langTexts = {
        en = {
            search_placeholder = "Search players...",
            sort_name = "ByName",
            sort_dist = "ByDist",
            auto_on = "Auto teleport ON",
            auto_off = "Auto teleport OFF",
            select_player_first = "Select a player first (click on name)"
        },
        ru = {
            search_placeholder = "Поиск игроков...",
            sort_name = "По имени",
            sort_dist = "По дистанции",
            auto_on = "Авто-телепорт включён",
            auto_off = "Авто-телепорт выключён",
            select_player_first = "Сначала выберите игрока (нажмите на кнопку с ником)"
        },
        ua = {
            search_placeholder = "Пошук гравців...",
            sort_name = "За ім'ям",
            sort_dist = "За відстанню",
            auto_on = "Авто-телепорт увімкнено",
            auto_off = "Авто-телепорт вимкнено",
            select_player_first = "Спершу виберіть гравця (натисніть на кнопку з ніком)"
        }
    }

    local function getText(key)
        return (langTexts[currentLang] and langTexts[currentLang][key]) or langTexts["en"][key] or key
    end

    -- 3. Внутренние переменные состояния
    local sortByDistance = false
    local searchFilter = ""
    local autoTeleportActive = false
    local autoTargetPlayer = nil
    local autoLoopConnection = nil
    local btns = {}
    local btnPlayerMap = {}

    -- Очистка контейнера перед сборкой
    playersContent:ClearAllChildren()

    -- 4. Расчет дистанции до игрока
    local function getDistanceToPlayer(p)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return 1e9 end
        local tChar = p.Character
        local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tHrp then return 1e9 end
        return (hrp.Position - tHrp.Position).Magnitude
    end

    -- 5. Функции авто-телепорта (Auto-TP)
    local function stopAutoTeleport()
        if autoLoopConnection then
            autoLoopConnection:Disconnect()
            autoLoopConnection = nil
        end
        autoTeleportActive = false
        autoTargetPlayer = nil
        if instantBtn then
            instantBtn.BackgroundColor3 = Color3.fromRGB(70, 70, 80)
            instantBtn.Text = "🎯"
        end
        showNotification(getText("auto_off"), 1.5)
    end

    local function startAutoTeleport(targetPlayer)
        if not targetPlayer then return end
        if autoTeleportActive then stopAutoTeleport() end

        autoTargetPlayer = targetPlayer
        autoTeleportActive = true

        if autoLoopConnection then autoLoopConnection:Disconnect() end
        autoLoopConnection = RunService.Heartbeat:Connect(function()
            if not autoTeleportActive or not autoTargetPlayer or not autoTargetPlayer.Parent then
                stopAutoTeleport()
                return
            end
            local tChar = autoTargetPlayer.Character
            local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
            local myChar = LP.Character
            local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")

            if myHrp and tHrp then
                myHrp.AssemblyLinearVelocity = Vector3.zero
                myHrp.CFrame = tHrp.CFrame * CFrame.new(0, 0, playerTPOffset)
            end
        end)

        if instantBtn then
            instantBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
            instantBtn.Text = "✅"
        end
        showNotification("🎯 " .. getText("auto_on") .. ": " .. targetPlayer.Name, 2)
    end

    -- 6. Создание элементов UI
    local searchFrameHeight = isMobile and 34 or 28
    local searchFrame = Instance.new("Frame")
    searchFrame.Size = UDim2.new(1, 0, 0, searchFrameHeight)
    searchFrame.Position = UDim2.new(0, 0, 0, 2)
    searchFrame.BackgroundTransparency = 1
    searchFrame.Parent = playersContent

    local searchBox = Instance.new("TextBox")
    if isMobile then
        searchBox.Size = UDim2.new(1, 0, 0, 18)
        searchBox.Position = UDim2.new(0, 0, 0, 0)
    else
        searchBox.Size = UDim2.new(0.7, 0, 1, 0)
        searchBox.Position = UDim2.new(0, 0, 0, 0)
    end
    searchBox.BackgroundColor3 = t.inputBg
    searchBox.Text = ""
    searchBox.TextColor3 = t.textColor
    searchBox.TextSize = isMobile and 9 or 12
    searchBox.Font = Enum.Font.Gotham
    searchBox.PlaceholderText = getText("search_placeholder")
    searchBox.BorderSizePixel = 0
    Instance.new("UICorner", searchBox).CornerRadius = UDim.new(0, 5)
    searchBox.Parent = searchFrame

    local sortBtn = Instance.new("TextButton")
    if isMobile then
        sortBtn.Size = UDim2.new(1, 0, 0, 18)
        sortBtn.Position = UDim2.new(0, 0, 0, 20)
    else
        sortBtn.Size = UDim2.new(0.25, 0, 1, 0)
        sortBtn.Position = UDim2.new(0.73, 0, 0, 0)
    end
    sortBtn.Text = getText("sort_name")
    sortBtn.TextColor3 = Color3.new(1, 1, 1)
    sortBtn.TextSize = isMobile and 9 or 12
    sortBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    sortBtn.BorderSizePixel = 0
    Instance.new("UICorner", sortBtn).CornerRadius = UDim.new(0, 5)
    sortBtn.Parent = searchFrame

    -- Анимация звезд на фоне
    if starsEnabled then
        local starsContainer = Instance.new("Frame")
        starsContainer.Size = UDim2.new(1, 0, 1, 0)
        starsContainer.Position = UDim2.new(0, 0, 0, 0)
        starsContainer.BackgroundTransparency = 1
        starsContainer.Parent = playersContent
        for i = 1, 10 do
            local s = Instance.new("ImageLabel")
            s.Size = UDim2.new(0, math.random(2, 3), 0, math.random(2, 3))
            s.Image = "rbxasset://textures/ui/common/white-circle.png"
            s.ImageColor3 = Color3.new(1, 1, 1)
            s.ImageTransparency = 0.6
            s.BackgroundTransparency = 1
            s.Position = UDim2.new(math.random(), 0, math.random(), 0)
            s.Parent = starsContainer
            local function anim()
                local d = math.random(4, 12)
                local np = UDim2.new(math.random(), 0, math.random(), 0)
                local tw = TweenService:Create(s, TweenInfo.new(d, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0), {Position = np})
                tw:Play()
                tw.Completed:Connect(anim)
            end
            anim()
        end
    end

    local playerScroll = Instance.new("ScrollingFrame")
    playerScroll.Size = UDim2.new(1, 0, 1, -(searchFrameHeight + 10))
    playerScroll.Position = UDim2.new(0, 0, 0, searchFrameHeight + 6)
    playerScroll.BackgroundTransparency = 1
    playerScroll.BorderSizePixel = 0
    playerScroll.ScrollBarThickness = 2
    playerScroll.ClipsDescendants = true
    playerScroll.Parent = playersContent

    local bc = Instance.new("Frame")
    bc.Size = UDim2.new(1, 0, 1, 0)
    bc.BackgroundTransparency = 1
    bc.Parent = playerScroll

    local lay = Instance.new("UIListLayout")
    lay.Padding = UDim.new(0, isMobile and 3 or 6)
    lay.SortOrder = Enum.SortOrder.Name
    lay.Parent = bc

    -- 7. Отрисовка списка кнопок игроков
    local function refreshButtons()
        for _, v in ipairs(btns) do v:Destroy() end
        btns = {}
        btnPlayerMap = {}

        local playersList = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and (searchFilter == "" or string.find(string.lower(p.Name), string.lower(searchFilter))) then
                table.insert(playersList, p)
            end
        end

        if sortByDistance then
            table.sort(playersList, function(a, b) return getDistanceToPlayer(a) < getDistanceToPlayer(b) end)
        else
            table.sort(playersList, function(a, b) return a.Name:lower() < b.Name:lower() end)
        end

        for _, p in ipairs(playersList) do
            local dist = getDistanceToPlayer(p)
            local distText = (dist < 1000) and string.format(" (%.0fm)", dist) or string.format(" (%.1fkm)", dist / 1000)

            local btn = Instance.new("TextButton")
            btn.Name = "PlayerBtn_" .. p.Name
            btn.Size = UDim2.new(1, -10, 0, isMobile and 24 or 36)
            btn.Position = UDim2.new(0, 5, 0, 0)
            btn.Text = p.Name .. distText
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.TextSize = isMobile and 10 or 14
            btn.Font = Enum.Font.GothamSemibold
            btn.BackgroundColor3 = (autoTeleportActive and autoTargetPlayer == p) and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(70, 70, 130)
            btn.BackgroundTransparency = 0.2
            btn.BorderSizePixel = 0
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            btn.Parent = bc
            btnPlayerMap[btn] = p

            btn.MouseButton1Click:Connect(function()
                if autoTeleportActive then
                    if autoTargetPlayer == p then
                        stopAutoTeleport()
                    else
                        startAutoTeleport(p)
                    end
                else
                    local tChar = p.Character
                    local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
                    if tHrp then
                        SmartTP(tHrp.CFrame * CFrame.new(0, 0, playerTPOffset))
                        addHistoryEntry(p.Name, tHrp.CFrame)
                    end
                    autoTargetPlayer = p
                end
            end)
            table.insert(btns, btn)
        end

        task.defer(function()
            if playerScroll and lay then
                playerScroll.CanvasSize = UDim2.new(0, 0, 0, lay.AbsoluteContentSize.Y + 20)
            end
        end)
    end

    -- 8. Быстрое обновление дистанций без лагов
    local function updatePlayerDistances()
        for btn, p in pairs(btnPlayerMap) do
            if btn and btn.Parent and p and p.Parent then
                local dist = getDistanceToPlayer(p)
                local distText = (dist < 1000) and string.format(" (%.0fm)", dist) or string.format(" (%.1fkm)", dist / 1000)
                btn.Text = p.Name .. distText
            end
        end
    end

    -- Слушатели ввода
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchFilter = searchBox.Text
        refreshButtons()
    end)

    sortBtn.MouseButton1Click:Connect(function()
        sortByDistance = not sortByDistance
        sortBtn.Text = sortByDistance and getText("sort_dist") or getText("sort_name")
        refreshButtons()
    end)

    -- Авто-обновление при входе/выходе игроков
    local playerAddedConn = Players.PlayerAdded:Connect(refreshButtons)
    local playerRemovingConn = Players.PlayerRemoving:Connect(function(p)
        if autoTargetPlayer == p then stopAutoTeleport() end
        refreshButtons()
    end)

    -- Первичная сборка
    refreshButtons()

    -- 9. Возврат методов управления наружу в загрузчик
    return {
        refresh = refreshButtons,
        updateDistances = updatePlayerDistances,
        getBtns = function() return btns end,
        getAutoTarget = function() return autoTargetPlayer end,
        isAutoTeleport = function() return autoTeleportActive end,
        startAutoTeleport = startAutoTeleport,
        stopAutoTeleport = stopAutoTeleport,
        toggleAutoTeleport = function()
            if autoTeleportActive then
                stopAutoTeleport()
            else
                if autoTargetPlayer then
                    startAutoTeleport(autoTargetPlayer)
                else
                    showNotification(getText("select_player_first"), 2)
                end
            end
        end,
        destroy = function()
            if playerAddedConn then playerAddedConn:Disconnect() end
            if playerRemovingConn then playerRemovingConn:Disconnect() end
            if autoLoopConnection then autoLoopConnection:Disconnect() end
        end
    }
end
