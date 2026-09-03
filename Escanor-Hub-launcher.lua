--[[
    Escanor HUB 🔥 – Launcher Module
    File: Escanor-Hub-launcher.lua
    By: Brobothotspot
--]]

local LauncherModule = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer

local function getGuiParent()
    if gethui then return gethui() end
    local ok, res = pcall(function() return CoreGui end)
    if ok and res then return res end
    return LP:WaitForChild("PlayerGui")
end

function LauncherModule.Show(onLaunchCallback)
    local parentGui = getGuiParent()

    -- Удаляем предыдущий лаунчер, если он уже открыт
    if parentGui:FindFirstChild("EscanorLauncherGUI") then
        parentGui:FindFirstChild("EscanorLauncherGUI"):Destroy()
    end

    local launcherGui = Instance.new("ScreenGui")
    launcherGui.Name = "EscanorLauncherGUI"
    launcherGui.ResetOnSpawn = false
    launcherGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    launcherGui.DisplayOrder = 1000
    launcherGui.Parent = parentGui

    local main = Instance.new("Frame", launcherGui)
    main.Name = "LauncherFrame"
    main.Size = UDim2.new(0, 300, 0, 200)
    main.Position = UDim2.new(0.5, -150, 0.5, -100)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 12)

    local gradient = Instance.new("UIGradient", main)
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 30))
    }
    gradient.Rotation = -45

    local launcherStroke = Instance.new("UIStroke", main)
    launcherStroke.Thickness = 2
    launcherStroke.Color = Color3.fromRGB(140, 100, 255)
    launcherStroke.Transparency = 0.15

    -- Анимация переливания
    local launcherHue = 0
    local launcherShimmerConn
    launcherShimmerConn = RunService.Heartbeat:Connect(function(dt)
        if not main or not main.Parent then
            if launcherShimmerConn then launcherShimmerConn:Disconnect() end
            return
        end
        launcherHue = (launcherHue + dt * 1.2) % (math.pi * 2)
        local h = (0.75 + math.sin(launcherHue) * 0.12) % 1
        launcherStroke.Color = Color3.fromHSV(h, 0.7, 0.9)
        local bgH = (0.75 + math.sin(launcherHue * 0.7) * 0.05) % 1
        gradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromHSV(bgH, 0.3, 0.15)),
            ColorSequenceKeypoint.new(1, Color3.fromHSV((bgH + 0.03) % 1, 0.25, 0.08))
        }
    end)

    -- Верхняя панель (Header)
    local titleBar = Instance.new("Frame", main)
    titleBar.Size = UDim2.new(1, 0, 0, 24)
    titleBar.BackgroundColor3 = Color3.fromRGB(40, 40, 45)
    titleBar.BorderSizePixel = 0
    Instance.new("UICorner", titleBar).CornerRadius = UDim.new(0, 6)

    local titleText = Instance.new("TextLabel", titleBar)
    titleText.Size = UDim2.new(1, -60, 1, 0)
    titleText.Position = UDim2.new(0, 8, 0, 0)
    titleText.BackgroundTransparency = 1
    titleText.Text = "🚀 Escanor HUB 🔥 v1.2"
    titleText.TextColor3 = Color3.new(1, 1, 1)
    titleText.Font = Enum.Font.GothamBold
    titleText.TextSize = 12
    titleText.TextXAlignment = Enum.TextXAlignment.Left

    local minBtn = Instance.new("TextButton", titleBar)
    minBtn.Size = UDim2.new(0, 22, 0, 22)
    minBtn.Position = UDim2.new(1, -46, 0, 1)
    minBtn.BackgroundColor3 = Color3.fromRGB(80, 80, 85)
    minBtn.Text = "–"
    minBtn.TextColor3 = Color3.new(1, 1, 1)
    minBtn.Font = Enum.Font.GothamBold
    minBtn.TextSize = 14
    Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 5)

    local closeBtn = Instance.new("TextButton", titleBar)
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -22, 0, 1)
    closeBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 14
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)

    local contentFrame = Instance.new("Frame", main)
    contentFrame.Size = UDim2.new(1, 0, 1, -24)
    contentFrame.Position = UDim2.new(0, 0, 0, 24)
    contentFrame.BackgroundTransparency = 1

    -- Сворачивание лаунчера
    local launcherMinimized = false
    minBtn.MouseButton1Click:Connect(function()
        launcherMinimized = not launcherMinimized
        if launcherMinimized then
            main:TweenSize(UDim2.new(0, 300, 0, 24), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 0.25, true)
            minBtn.Text = "+"
            contentFrame.Visible = false
        else
            main:TweenSize(UDim2.new(0, 300, 0, 200), Enum.EasingDirection.InOut, Enum.EasingStyle.Quad, 0.25, true)
            minBtn.Text = "–"
            contentFrame.Visible = true
        end
    end)

    closeBtn.MouseButton1Click:Connect(function()
        if launcherShimmerConn then launcherShimmerConn:Disconnect() end
        launcherGui:Destroy()
    end)

    -- Перетаскивание
    local dragging = false
    local dragStart, startPos
    titleBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    titleBar.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input, gp)
        if gp then return end
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- ================= 1. Выбор Языка =================
    local langLabel = Instance.new("TextLabel", contentFrame)
    langLabel.Size = UDim2.new(1, -16, 0, 16)
    langLabel.Position = UDim2.new(0, 8, 0, 8)
    langLabel.BackgroundTransparency = 1
    langLabel.Text = "🌐 Язык / Language:"
    langLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    langLabel.TextSize = 11
    langLabel.Font = Enum.Font.Gotham
    langLabel.TextXAlignment = Enum.TextXAlignment.Left

    local selectedLang = "ru"
    local langButtons = {}
    local langs = {"English", "Русский", "Українська"}
    local langCodes = {"en", "ru", "ua"}

    local function updateLangButtons()
        for code, btn in pairs(langButtons) do
            btn.BackgroundColor3 = (code == selectedLang) and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(60, 60, 120)
        end
    end

    for i, name in ipairs(langs) do
        local btn = Instance.new("TextButton", contentFrame)
        btn.Size = UDim2.new(0.3, -4, 0, 22)
        btn.Position = UDim2.new(0, 8 + (i-1)*92, 0, 28)
        btn.Text = name
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextSize = 11
        btn.Font = Enum.Font.GothamSemibold
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(function()
            selectedLang = langCodes[i]
            updateLangButtons()
        end)
        langButtons[langCodes[i]] = btn
    end

    -- ================= 2. Выбор Устройства =================
    local devLabel = Instance.new("TextLabel", contentFrame)
    devLabel.Size = UDim2.new(1, -16, 0, 16)
    devLabel.Position = UDim2.new(0, 8, 0, 58)
    devLabel.BackgroundTransparency = 1
    devLabel.Text = "📱 Устройство / Device:"
    devLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    devLabel.TextSize = 11
    devLabel.Font = Enum.Font.Gotham
    devLabel.TextXAlignment = Enum.TextXAlignment.Left

    local selectedDevice = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled and "Mobile" or "PC"
    local deviceButtons = {}
    local devs = {"PC", "Mobile"}

    local function updateDevButtons()
        for dev, btn in pairs(deviceButtons) do
            btn.BackgroundColor3 = (dev == selectedDevice) and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(60, 60, 120)
        end
    end

    for i, dev in ipairs(devs) do
        local btn = Instance.new("TextButton", contentFrame)
        btn.Size = UDim2.new(0.4, -4, 0, 22)
        btn.Position = UDim2.new(0, 8 + (i-1)*120, 0, 78)
        btn.Text = (dev == "PC") and "💻 ПК" or "📱 Телефон"
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextSize = 11
        btn.Font = Enum.Font.GothamSemibold
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(function()
            selectedDevice = dev
            updateDevButtons()
        end)
        deviceButtons[dev] = btn
    end

    -- ================= 3. Выбор Темы =================
    local themeLabel = Instance.new("TextLabel", contentFrame)
    themeLabel.Size = UDim2.new(1, -16, 0, 16)
    themeLabel.Position = UDim2.new(0, 8, 0, 108)
    themeLabel.BackgroundTransparency = 1
    themeLabel.Text = "🎨 Тема / Theme:"
    themeLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    themeLabel.TextSize = 11
    themeLabel.Font = Enum.Font.Gotham
    themeLabel.TextXAlignment = Enum.TextXAlignment.Left

    local selectedTheme = "dark"
    local themeButtons = {}
    local themes = {"dark", "light"}
    local themeNames = { dark = "🌙 Тёмная", light = "☀️ Светлая" }

    local function updateThemeButtons()
        for theme, btn in pairs(themeButtons) do
            btn.BackgroundColor3 = (theme == selectedTheme) and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(60, 60, 120)
        end
    end

    for i, theme in ipairs(themes) do
        local btn = Instance.new("TextButton", contentFrame)
        btn.Size = UDim2.new(0.4, -4, 0, 22)
        btn.Position = UDim2.new(0, 8 + (i-1)*120, 0, 128)
        btn.Text = themeNames[theme]
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextSize = 11
        btn.Font = Enum.Font.GothamSemibold
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
        btn.MouseButton1Click:Connect(function()
            selectedTheme = theme
            updateThemeButtons()
            if theme == "dark" then
                main.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
                titleText.TextColor3 = Color3.new(1,1,1)
                langLabel.TextColor3 = Color3.new(0.9,0.9,0.9)
                devLabel.TextColor3 = Color3.new(0.9,0.9,0.9)
                themeLabel.TextColor3 = Color3.new(0.9,0.9,0.9)
            else
                main.BackgroundColor3 = Color3.fromRGB(240, 240, 245)
                titleText.TextColor3 = Color3.new(0.1,0.1,0.15)
                langLabel.TextColor3 = Color3.new(0.2,0.2,0.3)
                devLabel.TextColor3 = Color3.new(0.2,0.2,0.3)
                themeLabel.TextColor3 = Color3.new(0.2,0.2,0.3)
            end
        end)
        themeButtons[theme] = btn
    end

    -- ================= Кнопка Execute =================
    local execBtn = Instance.new("TextButton", contentFrame)
    execBtn.Size = UDim2.new(0.8, 0, 0, 30)
    execBtn.Position = UDim2.new(0.1, 0, 1, -36)
    execBtn.Text = "🚀 Execute / Запустить"
    execBtn.TextColor3 = Color3.new(1, 1, 1)
    execBtn.TextSize = 13
    execBtn.Font = Enum.Font.GothamBold
    execBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    execBtn.BorderSizePixel = 0
    Instance.new("UICorner", execBtn).CornerRadius = UDim.new(0, 8)

    execBtn.MouseButton1Click:Connect(function()
        _G.TeleportHubSettings = _G.TeleportHubSettings or {}
        _G.TeleportHubSettings.language = selectedLang
        _G.TeleportHubSettings.device = selectedDevice
        _G.TeleportHubSettings.theme = selectedTheme

        if launcherShimmerConn then launcherShimmerConn:Disconnect() end
        launcherGui:Destroy()

        if typeof(onLaunchCallback) == "function" then
            onLaunchCallback(_G.TeleportHubSettings)
        end
    end)

    updateLangButtons()
    updateDevButtons()
    updateThemeButtons()
end

-- Поддержка прямого вызова LauncherModule(callback)
setmetatable(LauncherModule, {
    __call = function(_, callback)
        return LauncherModule.Show(callback)
    end
})

-- ОБЯЗАТЕЛЬНЫЙ ЭКСПОРТ ДЛЯ LOADSTRING
return LauncherModule
