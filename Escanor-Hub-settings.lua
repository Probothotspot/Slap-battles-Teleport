--[[
    Escanor HUB 🔥 – Settings Module
    File: Escanor-Hub-settings.lua
    By: Brobothotspot
--]]

local SettingsModule = {}

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer

local function getGuiParent()
    if gethui then return gethui() end
    local ok, res = pcall(function() return CoreGui end)
    if ok and res then return res end
    return LP:WaitForChild("PlayerGui")
end

function SettingsModule.Open(context)
    context = context or {}
    
    -- Получаем или создаем глобальную таблицу настроек
    if _G.TeleportHubSettings == nil then _G.TeleportHubSettings = {} end
    local settings = _G.TeleportHubSettings
    
    local isMobile = (settings.device == "Mobile") or (context.IsMobile == true)
    local parentGui = getGuiParent()

    -- Удаляем старое окно настроек, если уже открыто
    if parentGui:FindFirstChild("EscanorSettingsGUI") then
        parentGui:FindFirstChild("EscanorSettingsGUI"):Destroy()
    end

    local sg = Instance.new("ScreenGui")
    sg.Name = "EscanorSettingsGUI"
    sg.ResetOnSpawn = false
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.DisplayOrder = 1000
    sg.Parent = parentGui

    local winW = isMobile and 240 or 300
    local winH = isMobile and 310 or 350

    local main = Instance.new("Frame", sg)
    main.Name = "SettingsWindow"
    main.Size = UDim2.new(0, winW, 0, winH)
    main.Position = UDim2.new(0.5, -winW/2, 0.5, -winH/2)
    main.BackgroundColor3 = Color3.fromRGB(22, 24, 34)
    main.BorderSizePixel = 0
    main.ClipsDescendants = true
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)

    local stroke = Instance.new("UIStroke", main)
    stroke.Thickness = 1.8
    stroke.Color = Color3.fromRGB(120, 100, 240)

    -- Шапка окна
    local topBar = Instance.new("Frame", main)
    topBar.Size = UDim2.new(1, 0, 0, 32)
    topBar.BackgroundColor3 = Color3.fromRGB(32, 35, 48)
    topBar.BorderSizePixel = 0
    Instance.new("UICorner", topBar).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel", topBar)
    title.Size = UDim2.new(1, -40, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "⚙ Настройки / Settings"
    title.TextColor3 = Color3.new(1, 1, 1)
    title.Font = Enum.Font.GothamBold
    title.TextSize = isMobile and 11 or 13
    title.TextXAlignment = Enum.TextXAlignment.Left

    local closeBtn = Instance.new("TextButton", topBar)
    closeBtn.Size = UDim2.new(0, 22, 0, 22)
    closeBtn.Position = UDim2.new(1, -27, 0.5, -11)
    closeBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    closeBtn.Text = "✕"
    closeBtn.TextColor3 = Color3.new(1, 1, 1)
    closeBtn.Font = Enum.Font.GothamBold
    closeBtn.TextSize = 12
    Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 5)
    closeBtn.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)

    -- Перетаскивание (Мышь и Touch)
    local dragging, dragStart, startPos
    topBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Контейнер с настройками
    local scroll = Instance.new("ScrollingFrame", main)
    scroll.Size = UDim2.new(1, -12, 1, -42)
    scroll.Position = UDim2.new(0, 6, 0, 36)
    scroll.BackgroundTransparency = 1
    scroll.BorderSizePixel = 0
    scroll.ScrollBarThickness = 2
    scroll.CanvasSize = UDim2.new(0, 0, 0, 330)

    local layout = Instance.new("UIListLayout", scroll)
    layout.Padding = UDim.new(0, 8)

    local function makeSection(name)
        local lbl = Instance.new("TextLabel", scroll)
        lbl.Size = UDim2.new(1, 0, 0, 16)
        lbl.BackgroundTransparency = 1
        lbl.Text = name
        lbl.TextColor3 = Color3.fromRGB(180, 180, 200)
        lbl.Font = Enum.Font.GothamBold
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        return lbl
    end

    -- 1. ТЕМА
    makeSection("🎨 Тема / Theme:")
    local themeFrame = Instance.new("Frame", scroll)
    themeFrame.Size = UDim2.new(1, 0, 0, 24)
    themeFrame.BackgroundTransparency = 1
    local thLayout = Instance.new("UIListLayout", themeFrame)
    thLayout.FillDirection = Enum.FillDirection.Horizontal
    thLayout.Padding = UDim.new(0, 4)

    local themes = {"dark", "light", "pink", "green", "blue"}
    local themeBtns = {}
    for _, th in ipairs(themes) do
        local b = Instance.new("TextButton", themeFrame)
        b.Size = UDim2.new(0, isMobile and 38 or 48, 1, 0)
        b.Text = th:sub(1,1):upper()..th:sub(2)
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 10
        b.BackgroundColor3 = (settings.theme == th) and Color3.fromRGB(100, 90, 220) or Color3.fromRGB(40, 45, 60)
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        themeBtns[th] = b

        b.MouseButton1Click:Connect(function()
            settings.theme = th
            for k, btn in pairs(themeBtns) do
                btn.BackgroundColor3 = (k == th) and Color3.fromRGB(100, 90, 220) or Color3.fromRGB(40, 45, 60)
            end
            if context.ApplyTheme then context.ApplyTheme(th) end
        end)
    end

    -- 2. ПРОЗРАЧНОСТЬ
    makeSection("👁 Прозрачность / Transparency:")
    local transFrame = Instance.new("Frame", scroll)
    transFrame.Size = UDim2.new(1, 0, 0, 24)
    transFrame.BackgroundTransparency = 1
    local trLayout = Instance.new("UIListLayout", transFrame)
    trLayout.FillDirection = Enum.FillDirection.Horizontal
    trLayout.Padding = UDim.new(0, 5)

    local transValues = {0, 0.1, 0.25, 0.4}
    local transBtns = {}
    for _, val in ipairs(transValues) do
        local b = Instance.new("TextButton", transFrame)
        b.Size = UDim2.new(0, isMobile and 45 or 55, 1, 0)
        b.Text = math.floor(val * 100) .. "%"
        b.TextColor3 = Color3.new(1,1,1)
        b.Font = Enum.Font.GothamSemibold
        b.TextSize = 10
        b.BackgroundColor3 = (settings.transparency == val) and Color3.fromRGB(100, 90, 220) or Color3.fromRGB(40, 45, 60)
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 4)
        transBtns[val] = b

        b.MouseButton1Click:Connect(function()
            settings.transparency = val
            for k, btn in pairs(transBtns) do
                btn.BackgroundColor3 = (k == val) and Color3.fromRGB(100, 90, 220) or Color3.fromRGB(40, 45, 60)
            end
            if context.SetTransparency then context.SetTransparency(val) end
        end)
    end

    -- 3. ДИСТАНЦИЯ ТП (OFFSET)
    makeSection("📏 Отступ до игрока / TP Offset (-100..100):")
    local offsetFrame = Instance.new("Frame", scroll)
    offsetFrame.Size = UDim2.new(1, 0, 0, 26)
    offsetFrame.BackgroundTransparency = 1

    local minusBtn = Instance.new("TextButton", offsetFrame)
    minusBtn.Size = UDim2.new(0, 30, 1, 0)
    minusBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    minusBtn.Text = "-"
    minusBtn.TextColor3 = Color3.new(1,1,1)
    minusBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0, 4)

    local offsetInput = Instance.new("TextBox", offsetFrame)
    offsetInput.Size = UDim2.new(0, 60, 1, 0)
    offsetInput.Position = UDim2.new(0, 36, 0, 0)
    offsetInput.BackgroundColor3 = Color3.fromRGB(28, 30, 40)
    offsetInput.Text = tostring(settings.playerTPOffset or 2)
    offsetInput.TextColor3 = Color3.new(1,1,1)
    offsetInput.Font = Enum.Font.GothamSemibold
    offsetInput.TextSize = 12
    Instance.new("UICorner", offsetInput).CornerRadius = UDim.new(0, 4)

    local plusBtn = Instance.new("TextButton", offsetFrame)
    plusBtn.Size = UDim2.new(0, 30, 1, 0)
    plusBtn.Position = UDim2.new(0, 102, 0, 0)
    plusBtn.BackgroundColor3 = Color3.fromRGB(40, 45, 60)
    plusBtn.Text = "+"
    plusBtn.TextColor3 = Color3.new(1,1,1)
    plusBtn.Font = Enum.Font.GothamBold
    Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0, 4)

    local function updateOffset(newVal)
        newVal = math.clamp(newVal, -100, 100)
        settings.playerTPOffset = newVal
        offsetInput.Text = tostring(newVal)
    end

    minusBtn.MouseButton1Click:Connect(function()
        updateOffset((tonumber(offsetInput.Text) or 2) - 1)
    end)
    plusBtn.MouseButton1Click:Connect(function()
        updateOffset((tonumber(offsetInput.Text) or 2) + 1)
    end)
    offsetInput.FocusLost:Connect(function()
        updateOffset(tonumber(offsetInput.Text) or 2)
    end)

    -- 4. ЭФФЕКТ ЗВЁЗД (STARS)
    makeSection("✨ Эффект звёзд / Stars:")
    local starsBtn = Instance.new("TextButton", scroll)
    starsBtn.Size = UDim2.new(1, 0, 0, 24)
    local isStars = (settings.starsEnabled ~= false)
    starsBtn.BackgroundColor3 = isStars and Color3.fromRGB(50, 180, 80) or Color3.fromRGB(60, 60, 70)
    starsBtn.Text = isStars and "ВКЛ / ON" or "ВЫКЛ / OFF"
    starsBtn.TextColor3 = Color3.new(1,1,1)
    starsBtn.Font = Enum.Font.GothamBold
    starsBtn.TextSize = 11
    Instance.new("UICorner", starsBtn).CornerRadius = UDim.new(0, 4)

    starsBtn.MouseButton1Click:Connect(function()
        settings.starsEnabled = not (settings.starsEnabled ~= false)
        local active = settings.starsEnabled
        starsBtn.BackgroundColor3 = active and Color3.fromRGB(50, 180, 80) or Color3.fromRGB(60, 60, 70)
        starsBtn.Text = active and "ВКЛ / ON" or "ВЫКЛ / OFF"
    end)

    -- Сохранить и закрыть
    local saveBtn = Instance.new("TextButton", scroll)
    saveBtn.Size = UDim2.new(1, 0, 0, 28)
    saveBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 90)
    saveBtn.Text = "💾 Готово / Save"
    saveBtn.TextColor3 = Color3.new(1,1,1)
    saveBtn.Font = Enum.Font.GothamBold
    saveBtn.TextSize = 12
    Instance.new("UICorner", saveBtn).CornerRadius = UDim.new(0, 5)
    saveBtn.MouseButton1Click:Connect(function()
        sg:Destroy()
    end)
end

-- Поддержка прямого вызова SettingsModule() без точки
setmetatable(SettingsModule, {
    __call = function(_, ctx)
        return SettingsModule.Open(ctx)
    end
})

-- ОБЯЗАТЕЛЬНЫЙ ЭКСПОРТ ДЛЯ LOADSTRING
return SettingsModule
