--[[
    Escanor HUB 🔥 — Модуль вкладки «Другое» (Other Tab Module)
    Файл: other.lua
--]]

return function(otherContent, ctx)
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer
    local RunService = game:GetService("RunService")
    local Stats = game:GetService("Stats")
    local Lighting = game:GetService("Lighting")

    local currentLang = ctx.currentLang or "ru"
    local currentTheme = ctx.currentTheme or "dark"
    local themes = ctx.themes or {}
    local t = themes[currentTheme] or { textColor = Color3.new(1, 1, 1) }

    -- Состояния утилит (берутся из глобальных переменных или контекста)
    local antiAFKEnabled = _G.AntiAFKEnabled or false
    local showFPS = _G.ShowFPS or false
    local fullbrightEnabled = _G.FullbrightEnabled or false
    local coordsDisplayEnabled = _G.CoordsDisplayEnabled or false
    local timerEnabled = _G.TimerEnabled or false

    local antiAFKConnection = nil
    local fpsConnection = nil
    local fpsData = { gui = nil, label = nil, fpsCount = 0, fpsTime = 0 }
    local fullbrightBackup = {}

    -- Переводы
    local langTexts = {
        en = {
            anti_afk = "🛡️ Anti-AFK",
            fps_ping = "📊 FPS / Ping",
            fullbright = "☀️ Fullbright",
            coords_display = "📍 Coordinates",
            timer = "⏱️ Timer/Stopwatch"
        },
        ru = {
            anti_afk = "🛡️ Анти-АФК",
            fps_ping = "📊 FPS / Пинг",
            fullbright = "☀️ Fullbright",
            coords_display = "📍 Координаты",
            timer = "⏱️ Таймер/Секундомер"
        },
        ua = {
            anti_afk = "🛡️ Анти-АФК",
            fps_ping = "📊 FPS / Пінг",
            fullbright = "☀️ Fullbright",
            coords_display = "📍 Координати",
            timer = "⏱️ Таймер/Секундомір"
        }
    }

    local function getText(key)
        return (langTexts[currentLang] and langTexts[currentLang][key]) or langTexts["en"][key] or key
    end

    -- Утилита: Анти-АФК
    local function startAntiAFK()
        if antiAFKConnection then return end
        local success, result = pcall(function()
            return loadstring(game:HttpGet("https://pastebin.com/raw/mgEReA6Q"))()
        end)
        if success and type(result) == "function" then
            antiAFKConnection = result
        else
            antiAFKConnection = true
        end
        _G.AntiAFKEnabled = true
    end

    local function stopAntiAFK()
        if type(antiAFKConnection) == "function" then pcall(antiAFKConnection) end
        antiAFKConnection = nil
        _G.AntiAFKEnabled = false
    end

    -- Утилита: FPS / Пинг виджет
    local function createFPSWidget()
        if fpsData.gui then return end
        local gui = Instance.new("ScreenGui")
        gui.Name = "FPSWidget"
        gui.ResetOnSpawn = false
        pcall(function() gui.Parent = game:GetService("CoreGui") end)
        if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
        if not gui.Parent then return end

        local frame = Instance.new("Frame", gui)
        frame.Size = UDim2.new(0, 160, 0, 24)
        frame.Position = _G.FPSPosition or UDim2.new(0, 5, 0, 5)
        frame.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
        frame.BackgroundTransparency = 0.25
        frame.BorderSizePixel = 0
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 6)

        local label = Instance.new("TextLabel", frame)
        label.Size = UDim2.new(1, 0, 1, 0)
        label.BackgroundTransparency = 1
        label.Text = "FPS: -- | Ping: --"
        label.TextColor3 = Color3.new(1, 1, 1)
        label.Font = Enum.Font.GothamBold
        label.TextSize = 13

        fpsData.gui = gui
        fpsData.label = label
    end

    local function updateFPSWidget(dt)
        if not fpsData.label then return end
        fpsData.fpsCount = fpsData.fpsCount + 1
        fpsData.fpsTime = fpsData.fpsTime + dt
        if fpsData.fpsTime >= 0.5 then
            local avgFPS = fpsData.fpsCount / fpsData.fpsTime
            local pingStr = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
            local pingNum = pingStr:match("^(%d+)") or "?"
            fpsData.label.Text = string.format("FPS: %d | Ping: %s", math.floor(avgFPS), pingNum)
            fpsData.fpsCount = 0
            fpsData.fpsTime = 0
        end
    end

    local function startFPS()
        if fpsConnection then return end
        createFPSWidget()
        fpsConnection = RunService.Heartbeat:Connect(updateFPSWidget)
        _G.ShowFPS = true
    end

    local function stopFPS()
        if fpsConnection then fpsConnection:Disconnect(); fpsConnection = nil end
        if fpsData.gui then fpsData.gui:Destroy(); fpsData.gui = nil; fpsData.label = nil end
        _G.ShowFPS = false
    end

    -- Утилита: Fullbright
    local function startFullbright()
        if fullbrightEnabled then return end
        fullbrightBackup = {
            ClockTime = Lighting.ClockTime, Brightness = Lighting.Brightness, GlobalShadows = Lighting.GlobalShadows,
            FogEnd = Lighting.FogEnd, FogColor = Lighting.FogColor, Ambient = Lighting.Ambient,
            OutdoorAmbient = Lighting.OutdoorAmbient, ShadowSoftness = Lighting.ShadowSoftness
        }
        pcall(function() loadstring(game:HttpGet("https://pastebin.com/raw/rCTuDHKi"))() end)
        fullbrightEnabled = true
        _G.FullbrightEnabled = true
    end

    local function stopFullbright()
        if not fullbrightEnabled then return end
        if fullbrightBackup.ClockTime then
            for k, v in pairs(fullbrightBackup) do Lighting[k] = v end
        end
        local gui = LP.PlayerGui:FindFirstChild("Fullbright") or (game:GetService("CoreGui"):FindFirstChild("Fullbright"))
        if gui then gui:Destroy() end
        fullbrightEnabled = false
        _G.FullbrightEnabled = false
    end

    -- Утилита: Координаты
    local function startCoordsDisplay()
        if coordsDisplayEnabled then return end
        pcall(function() loadstring(game:HttpGet("https://pastebin.com/raw/SWf2qLAf"))() end)
        coordsDisplayEnabled = true
        _G.CoordsDisplayEnabled = true
    end

    local function stopCoordsDisplay()
        if not coordsDisplayEnabled then return end
        local gui = LP.PlayerGui:FindFirstChild("CoordsDisplay") or (game:GetService("CoreGui"):FindFirstChild("CoordsDisplay"))
        if gui then gui:Destroy() end
        coordsDisplayEnabled = false
        _G.CoordsDisplayEnabled = false
    end

    -- Утилита: Таймер
    local function startTimer()
        if timerEnabled then return end
        pcall(function() loadstring(game:HttpGet("https://pastebin.com/raw/cRxzSZwL"))() end)
        timerEnabled = true
        _G.TimerEnabled = true
    end

    local function stopTimer()
        if not timerEnabled then return end
        local gui = LP.PlayerGui:FindFirstChild("TimerGUI") or (game:GetService("CoreGui"):FindFirstChild("TimerGUI"))
        if gui then gui:Destroy() end
        timerEnabled = false
        _G.TimerEnabled = false
    end

    -- Очистка контейнера вкладки
    otherContent:ClearAllChildren()

    -- Отрисовка элементов вкладки
    local function createOtherUtility(yPos, labelText, state, onToggle)
        local frame = Instance.new("Frame", otherContent)
        frame.Size = UDim2.new(1, -4, 0, 24)
        frame.Position = UDim2.new(0, 2, 0, yPos)
        frame.BackgroundTransparency = 1

        local lbl = Instance.new("TextLabel", frame)
        lbl.Size = UDim2.new(0.6, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = t.textColor or Color3.new(1,1,1)
        lbl.TextSize = 10
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local btn = Instance.new("TextButton", frame)
        btn.Size = UDim2.new(0, 45, 0, 20)
        btn.Position = UDim2.new(0.7, 0, 0.5, -10)
        btn.Text = state and "ON" or "OFF"
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.BackgroundColor3 = state and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(80, 80, 80)
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = state and "ON" or "OFF"
            btn.BackgroundColor3 = state and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(80, 80, 80)
            onToggle(state)
        end)
    end

    createOtherUtility(2, getText("anti_afk"), antiAFKEnabled, function(e)
        if e then startAntiAFK() else stopAntiAFK() end
    end)
    createOtherUtility(28, getText("fps_ping"), showFPS, function(e)
        if e then startFPS() else stopFPS() end
    end)
    createOtherUtility(54, getText("fullbright"), fullbrightEnabled, function(e)
        if e then startFullbright() else stopFullbright() end
    end)
    createOtherUtility(80, getText("coords_display"), coordsDisplayEnabled, function(e)
        if e then startCoordsDisplay() else stopCoordsDisplay() end
    end)
    createOtherUtility(106, getText("timer"), timerEnabled, function(e)
        if e then startTimer() else stopTimer() end
    end)

    -- Возврат методов управления наружу
    return {
        destroy = function()
            stopAntiAFK()
            stopFPS()
            stopFullbright()
            stopCoordsDisplay()
            stopTimer()
        end
    }
end
