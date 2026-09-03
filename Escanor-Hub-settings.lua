--[[
    Escanor HUB 🔥 — Модуль настроек (Settings Module)
    Файл: settings.lua
--]]

return function(mainFrame, ctx)
    local TweenService = game:GetService("TweenService")
    local UserInput = game:GetService("UserInputService")

    -- Извлечение контекста
    local isMobile = ctx.isMobile or false
    local currentLang = ctx.currentLang or "ru"
    local currentTheme = ctx.currentTheme or "dark"
    local themes = ctx.themes or {}
    local guiTransparency = ctx.guiTransparency or 0.1
    local teleportSpeed = ctx.teleportSpeed or 50000
    local playerTPOffset = ctx.playerTPOffset or 2
    local applyTheme = ctx.applyTheme or function() end
    local showNotification = ctx.showNotification or function() end
    local onSettingsChanged = ctx.onSettingsChanged or function() end

    -- Словари локализации
    local langTexts = {
        en = {
            settings_title = "Settings",
            gui_size = "GUI Size:",
            small = "Small",
            medium = "Medium",
            large = "Large",
            transparency = "Background transparency:",
            speed = "TP speed:",
            theme = "Theme:",
            theme_dark = "Dark",
            theme_light = "Light",
            theme_pink = "Pink",
            theme_green = "Green",
            theme_blue = "Blue",
            tp_offset = "TP offset (-100..100):"
        },
        ru = {
            settings_title = "Настройки",
            gui_size = "Размер GUI:",
            small = "Маленький",
            medium = "Средний",
            large = "Большой",
            transparency = "Прозрачность фона:",
            speed = "Скорость ТП:",
            theme = "Тема:",
            theme_dark = "Тёмная",
            theme_light = "Светлая",
            theme_pink = "Розовая",
            theme_green = "Зелёная",
            theme_blue = "Синяя",
            tp_offset = "ТП отступ (-100..100):"
        },
        ua = {
            settings_title = "Налаштування",
            gui_size = "Розмір GUI:",
            small = "Маленький",
            medium = "Середній",
            large = "Великий",
            transparency = "Прозорість фону:",
            speed = "Швидкість ТП:",
            theme = "Тема:",
            theme_dark = "Темна",
            theme_light = "Світла",
            theme_pink = "Рожева",
            theme_green = "Зелена",
            theme_blue = "Синя",
            tp_offset = "ТП відступ (-100..100):"
        }
    }

    local function getText(key)
        return (langTexts[currentLang] and langTexts[currentLang][key]) or langTexts["en"][key] or key
    end

    local settingsWindow = nil
    local settingsOpen = false

    local function saveGlobals()
        _G.TeleportHubSettings = _G.TeleportHubSettings or {}
        _G.TeleportHubSettings.transparency = guiTransparency
        _G.TeleportHubSettings.teleportSpeed = teleportSpeed
        _G.TeleportHubSettings.playerTPOffset = playerTPOffset
        _G.TeleportHubSettings.theme = currentTheme
        _G.TeleportHubSettings.language = currentLang
        _G.TeleportHubSettings.device = isMobile and "Mobile" or "PC"
        
        onSettingsChanged({
            transparency = guiTransparency,
            teleportSpeed = teleportSpeed,
            playerTPOffset = playerTPOffset,
            theme = currentTheme
        })
    end

    local function closeSettings()
        if not settingsOpen or not settingsWindow or not settingsWindow.Parent then return end
        saveGlobals()
        local tw = TweenService:Create(settingsWindow, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
            Position = UDim2.new(1, 0, 0, 0)
        })
        tw:Play()
        task.delay(0.28, function()
            if settingsWindow and settingsWindow.Parent then
                settingsWindow:Destroy()
            end
            settingsWindow = nil
            settingsOpen = false
        end)
    end

    local function openSettings()
        if settingsOpen then
            closeSettings()
            return
        end
        if not mainFrame or not mainFrame.Parent then return end

        settingsOpen = true

        -- Главная рамка настроек (плавный оверлей на весь mainFrame)
        settingsWindow = Instance.new("Frame")
        settingsWindow.Name = "SettingsOverlay"
        settingsWindow.Size = UDim2.new(1, 0, 1, 0)
        settingsWindow.Position = UDim2.new(1, 0, 0, 0)
        settingsWindow.BackgroundColor3 = Color3.fromRGB(18, 18, 30)
        settingsWindow.BackgroundTransparency = 0.02
        settingsWindow.BorderSizePixel = 0
        settingsWindow.ZIndex = 25
        settingsWindow.ClipsDescendants = true
        Instance.new("UICorner", settingsWindow).CornerRadius = UDim.new(0, 12)
        settingsWindow.Parent = mainFrame

        TweenService:Create(settingsWindow, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Position = UDim2.new(0, 0, 0, 0)
        }):Play()

        -- Кнопка «Назад»
        local backBtn = Instance.new("TextButton")
        backBtn.Size = UDim2.new(1, 0, 0, isMobile and 28 or 36)
        backBtn.Position = UDim2.new(0, 0, 0, 0)
        backBtn.BackgroundColor3 = Color3.fromRGB(40, 40, 60)
        backBtn.BorderSizePixel = 0
        backBtn.Text = "< " .. getText("settings_title")
        backBtn.TextColor3 = Color3.new(1, 1, 1)
        backBtn.TextSize = isMobile and 12 or 15
        backBtn.Font = Enum.Font.GothamBold
        backBtn.TextXAlignment = Enum.TextXAlignment.Left
        backBtn.ZIndex = 26
        backBtn.Active = true
        Instance.new("UICorner", backBtn).CornerRadius = UDim.new(0, 8)
        
        local backPad = Instance.new("UIPadding")
        backPad.PaddingLeft = UDim.new(0, 10)
        backPad.Parent = backBtn
        backBtn.Parent = settingsWindow

        backBtn.MouseButton1Click:Connect(closeSettings)

        -- Прокручиваемый список
        local scroll = Instance.new("ScrollingFrame")
        scroll.Size = UDim2.new(1, -10, 1, -(isMobile and 34 or 42))
        scroll.Position = UDim2.new(0, 5, 0, isMobile and 32 or 40)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.ZIndex = 26
        scroll.ScrollBarThickness = 3
        scroll.Parent = settingsWindow

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 10)
        layout.Parent = scroll

        local function makeRow(text, btnText, onClick, height)
            local fr = Instance.new("Frame")
            fr.Size = UDim2.new(1, 0, 0, height or 36)
            fr.BackgroundTransparency = 1
            fr.ZIndex = 27
            fr.Parent = scroll

            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0.55, 0, 1, 0)
            lbl.BackgroundTransparency = 1
            lbl.Text = text
            lbl.TextColor3 = Color3.new(1, 1, 1)
            lbl.TextSize = isMobile and 11 or 12
            lbl.Font = Enum.Font.Gotham
            lbl.ZIndex = 27
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = fr

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0.38, 0, 0.85, 0)
            btn.Position = UDim2.new(0.58, 0, 0.075, 0)
            btn.Text = btnText
            btn.TextColor3 = Color3.new(0, 0, 0)
            btn.BackgroundColor3 = Color3.new(1, 1, 1)
            btn.BorderSizePixel = 0
            btn.ZIndex = 28
            btn.Font = Enum.Font.GothamBold
            btn.TextSize = isMobile and 10 or 11
            btn.Active = true
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            btn.Parent = fr

            onClick(btn)
            return btn
        end

        -- 1. Размер GUI
        local sizeText = {getText("small"), getText("medium"), getText("large")}
        local sizeIdx = 2
        makeRow(getText("gui_size"), sizeText[sizeIdx], function(btn)
            btn.MouseButton1Click:Connect(function()
                sizeIdx = sizeIdx % 3 + 1
                btn.Text = sizeText[sizeIdx]
                local w, h = 350, 400
                if sizeIdx == 1 then w, h = 250, 300
                elseif sizeIdx == 2 then w, h = 350, 400
                else w, h = 450, 480 end
                if isMobile then h = 250 end
                
                TweenService:Create(mainFrame, TweenInfo.new(0.25, Enum.EasingStyle.Quad), {
                    Size = UDim2.new(0, w, 0, h),
                    Position = UDim2.new(0.5, -w/2, 0.5, -h/2)
                }):Play()
            end)
        end, 36)

        -- 2. Прозрачность
        local transVal = guiTransparency
        makeRow(getText("transparency"), math.floor(transVal * 100) .. "%", function(btn)
            btn.MouseButton1Click:Connect(function()
                transVal = (transVal + 0.1) % 1.1
                if transVal > 1 then transVal = 0 end
                btn.Text = math.floor(transVal * 100) .. "%"
                mainFrame.BackgroundTransparency = transVal
                guiTransparency = transVal
            end)
        end, 36)

        -- 3. Скорость телепорта
        local speeds = {10000, 25000, 50000, 100000, 200000}
        local spIdx = 3
        makeRow(getText("speed"), tostring(teleportSpeed) .. " stud/s", function(btn)
            btn.MouseButton1Click:Connect(function()
                spIdx = spIdx % 5 + 1
                teleportSpeed = speeds[spIdx]
                btn.Text = tostring(teleportSpeed) .. " stud/s"
            end)
        end, 36)

        -- 4. Темы
        local themesList = {"dark", "light", "pink", "green", "blue"}
        local themeIdx = 1
        for i, name in ipairs(themesList) do
            if name == currentTheme then themeIdx = i break end
        end
        local themeNames = {
            dark = getText("theme_dark"),
            light = getText("theme_light"),
            pink = getText("theme_pink"),
            green = getText("theme_green"),
            blue = getText("theme_blue")
        }
        makeRow(getText("theme"), themeNames[themesList[themeIdx]] or themesList[themeIdx], function(btn)
            btn.MouseButton1Click:Connect(function()
                themeIdx = themeIdx % #themesList + 1
                local newTheme = themesList[themeIdx]
                currentTheme = newTheme
                btn.Text = themeNames[newTheme]
                applyTheme(newTheme)
            end)
        end, 36)

        -- 5. ТП отступ (TP Offset)
        local tpOffsetFrame = Instance.new("Frame")
        tpOffsetFrame.Size = UDim2.new(1, 0, 0, 44)
        tpOffsetFrame.BackgroundTransparency = 1
        tpOffsetFrame.ZIndex = 27
        tpOffsetFrame.Parent = scroll

        local tpOffsetLabel = Instance.new("TextLabel")
        tpOffsetLabel.Size = UDim2.new(0.55, 0, 1, 0)
        tpOffsetLabel.BackgroundTransparency = 1
        tpOffsetLabel.Text = getText("tp_offset")
        tpOffsetLabel.TextColor3 = Color3.new(1, 1, 1)
        tpOffsetLabel.TextSize = isMobile and 11 or 12
        tpOffsetLabel.Font = Enum.Font.Gotham
        tpOffsetLabel.ZIndex = 27
        tpOffsetLabel.TextXAlignment = Enum.TextXAlignment.Left
        tpOffsetLabel.Parent = tpOffsetFrame

        local tpOffsetContainer = Instance.new("Frame")
        tpOffsetContainer.Size = UDim2.new(0.4, 0, 1, 0)
        tpOffsetContainer.Position = UDim2.new(0.58, 0, 0, 0)
        tpOffsetContainer.BackgroundTransparency = 1
        tpOffsetContainer.ZIndex = 27
        tpOffsetContainer.Parent = tpOffsetFrame

        local tpOffsetBox = Instance.new("TextBox")
        tpOffsetBox.Size = UDim2.new(0, 45, 0, 24)
        tpOffsetBox.Position = UDim2.new(0, 0, 0.5, -12)
        tpOffsetBox.BackgroundColor3 = Color3.new(0.2, 0.2, 0.25)
        tpOffsetBox.Text = tostring(playerTPOffset)
        tpOffsetBox.TextColor3 = Color3.new(1, 1, 1)
        tpOffsetBox.TextSize = 12
        tpOffsetBox.Font = Enum.Font.GothamBold
        tpOffsetBox.ZIndex = 28
        tpOffsetBox.BorderSizePixel = 0
        Instance.new("UICorner", tpOffsetBox).CornerRadius = UDim.new(0, 4)
        tpOffsetBox.Parent = tpOffsetContainer

        local minusBtn = Instance.new("TextButton")
        minusBtn.Size = UDim2.new(0, 22, 0, 22)
        minusBtn.Position = UDim2.new(0, 50, 0.5, -11)
        minusBtn.Text = "-"
        minusBtn.TextColor3 = Color3.new(1, 1, 1)
        minusBtn.BackgroundColor3 = Color3.new(0.4, 0.4, 0.5)
        minusBtn.Font = Enum.Font.GothamBold
        minusBtn.TextSize = 14
        minusBtn.ZIndex = 28
        minusBtn.BorderSizePixel = 0
        Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0, 4)
        minusBtn.Parent = tpOffsetContainer
        minusBtn.MouseButton1Click:Connect(function()
            playerTPOffset = math.max(-100, playerTPOffset - 1)
            tpOffsetBox.Text = tostring(playerTPOffset)
            saveGlobals()
        end)

        local plusBtn = Instance.new("TextButton")
        plusBtn.Size = UDim2.new(0, 22, 0, 22)
        plusBtn.Position = UDim2.new(0, 76, 0.5, -11)
        plusBtn.Text = "+"
        plusBtn.TextColor3 = Color3.new(1, 1, 1)
        plusBtn.BackgroundColor3 = Color3.new(0.4, 0.4, 0.5)
        plusBtn.Font = Enum.Font.GothamBold
        plusBtn.TextSize = 14
        plusBtn.ZIndex = 28
        plusBtn.BorderSizePixel = 0
        Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0, 4)
        plusBtn.Parent = tpOffsetContainer
        plusBtn.MouseButton1Click:Connect(function()
            playerTPOffset = math.min(100, playerTPOffset + 1)
            tpOffsetBox.Text = tostring(playerTPOffset)
            saveGlobals()
        end)

        tpOffsetBox.FocusLost:Connect(function()
            local val = tonumber(tpOffsetBox.Text)
            if val then
                playerTPOffset = math.clamp(math.floor(val), -100, 100)
                tpOffsetBox.Text = tostring(playerTPOffset)
            else
                tpOffsetBox.Text = tostring(playerTPOffset)
            end
            saveGlobals()
        end)

        layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
            scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
        end)
        task.wait()
        scroll.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 20)
    end

    -- Возврат методов управления
    return {
        open = openSettings,
        close = closeSettings,
        toggle = openSettings,
        isOpen = function() return settingsOpen end,
        getOffset = function() return playerTPOffset end,
        getSpeed = function() return teleportSpeed end,
        destroy = function()
            if settingsWindow and settingsWindow.Parent then
                settingsWindow:Destroy()
            end
        end
    }
end
