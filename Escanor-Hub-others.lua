--[[
    Escanor HUB 🔥 – Others & Utilities Module
    File: Escanor-Hub-others.lua
    By: Brobothotspot
--]]

local OthersModule = {}

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Stats = game:GetService("Stats")
local Lighting = game:GetService("Lighting")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer

local function getGuiParent()
    if gethui then return gethui() end
    local ok, res = pcall(function() return CoreGui end)
    if ok and res then return res end
    return LP:WaitForChild("PlayerGui")
end

-- =========================================================================
-- 1. УПРАВЛЕНИЕ СОСТОЯНИЕМ
-- =========================================================================
if _G.AntiAFKEnabled == nil then _G.AntiAFKEnabled = false end
if _G.ShowFPS == nil then _G.ShowFPS = false end
if _G.FPSPosition == nil then _G.FPSPosition = UDim2.new(0, 5, 0, 5) end
if _G.FullbrightEnabled == nil then _G.FullbrightEnabled = false end
if _G.CoordsDisplayEnabled == nil then _G.CoordsDisplayEnabled = false end
if _G.TimerEnabled == nil then _G.TimerEnabled = false end

local antiAFKConnection = nil
local fpsConnection = nil
local fpsData = { gui = nil, label = nil, fpsCount = 0, fpsTime = 0 }
local fullbrightBackup = {}

-- =========================================================================
-- 2. ЛОГИКА УТИЛИТ
-- =========================================================================

-- Anti-AFK
function OthersModule.startAntiAFK()
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

function OthersModule.stopAntiAFK()
    if type(antiAFKConnection) == "function" then
        pcall(antiAFKConnection)
    end
    antiAFKConnection = nil
    _G.AntiAFKEnabled = false
end

function OthersModule.toggleAntiAFK(state)
    if state == nil then state = not _G.AntiAFKEnabled end
    if state then OthersModule.startAntiAFK() else OthersModule.stopAntiAFK() end
    return _G.AntiAFKEnabled
end

-- FPS & Ping Widget
local function updateFPSWidget(dt)
    if not fpsData.label then return end
    fpsData.fpsCount = fpsData.fpsCount + 1
    fpsData.fpsTime = fpsData.fpsTime + dt
    if fpsData.fpsTime >= 0.5 then
        local avgFPS = fpsData.fpsCount / fpsData.fpsTime
        local pingNum = "?"
        pcall(function()
            local pingStr = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
            pingNum = pingStr:match("^(%d+)") or "?"
        end)
        fpsData.label.Text = string.format("FPS: %d | Ping: %s", math.floor(avgFPS), pingNum)
        fpsData.fpsCount = 0
        fpsData.fpsTime = 0
    end
end

local function createFPSWidget()
    if fpsData.gui then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "FPSWidget"
    gui.ResetOnSpawn = false
    gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    gui.Parent = getGuiParent()

    local frame = Instance.new("Frame")
    frame.Size = UDim2.new(0, 160, 0, 24)
    frame.Position = _G.FPSPosition
    frame.BackgroundColor3 = Color3.fromRGB(25, 28, 40)
    frame.BackgroundTransparency = 0.25
    frame.BorderSizePixel = 0
    local corner = Instance.new("UICorner", frame)
    corner.CornerRadius = UDim.new(0, 6)
    frame.Parent = gui

    local label = Instance.new("TextLabel")
    label.Size = UDim2.new(1, 0, 1, 0)
    label.BackgroundTransparency = 1
    label.Text = "FPS: -- | Ping: --"
    label.TextColor3 = Color3.new(1, 1, 1)
    label.Font = Enum.Font.GothamBold
    label.TextSize = 13
    label.Parent = frame

    fpsData.gui = gui
    fpsData.label = label

    -- Перетаскивание виджета
    local dragging = false
    local dragStart, startPos
    frame.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
        end
    end)
    frame.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = false
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            _G.FPSPosition = frame.Position
        end
    end)
end

function OthersModule.startFPS()
    if fpsConnection then return end
    createFPSWidget()
    fpsConnection = RunService.Heartbeat:Connect(updateFPSWidget)
    _G.ShowFPS = true
end

function OthersModule.stopFPS()
    if fpsConnection then
        fpsConnection:Disconnect()
        fpsConnection = nil
    end
    if fpsData.gui then
        fpsData.gui:Destroy()
        fpsData.gui = nil
        fpsData.label = nil
    end
    _G.ShowFPS = false
end

function OthersModule.toggleFPS(state)
    if state == nil then state = not _G.ShowFPS end
    if state then OthersModule.startFPS() else OthersModule.stopFPS() end
    return _G.ShowFPS
end

-- Fullbright
function OthersModule.startFullbright()
    if _G.FullbrightEnabled then return end
    fullbrightBackup = {
        ClockTime = Lighting.ClockTime,
        Brightness = Lighting.Brightness,
        GlobalShadows = Lighting.GlobalShadows,
        FogEnd = Lighting.FogEnd,
        FogColor = Lighting.FogColor,
        Ambient = Lighting.Ambient,
        OutdoorAmbient = Lighting.OutdoorAmbient,
        ShadowSoftness = Lighting.ShadowSoftness
    }
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://pastebin.com/raw/rCTuDHKi"))()
    end)
    if not success then
        warn("[Escanor HUB] Fullbright error: " .. tostring(err))
        return
    end
    _G.FullbrightEnabled = true
end

function OthersModule.stopFullbright()
    if not _G.FullbrightEnabled then return end
    if fullbrightBackup.ClockTime then
        Lighting.ClockTime = fullbrightBackup.ClockTime
        Lighting.Brightness = fullbrightBackup.Brightness
        Lighting.GlobalShadows = fullbrightBackup.GlobalShadows
        Lighting.FogEnd = fullbrightBackup.FogEnd
        Lighting.FogColor = fullbrightBackup.FogColor
        Lighting.Ambient = fullbrightBackup.Ambient
        Lighting.OutdoorAmbient = fullbrightBackup.OutdoorAmbient
        Lighting.ShadowSoftness = fullbrightBackup.ShadowSoftness
    end
    local gui = LP.PlayerGui:FindFirstChild("Fullbright")
    if not gui then
        pcall(function() gui = game:GetService("CoreGui"):FindFirstChild("Fullbright") end)
    end
    if gui then gui:Destroy() end
    _G.FullbrightEnabled = false
end

function OthersModule.toggleFullbright(state)
    if state == nil then state = not _G.FullbrightEnabled end
    if state then OthersModule.startFullbright() else OthersModule.stopFullbright() end
    return _G.FullbrightEnabled
end

-- Coords Display
function OthersModule.startCoordsDisplay()
    if _G.CoordsDisplayEnabled then return end
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://pastebin.com/raw/SWf2qLAf"))()
    end)
    if not success then
        warn("[Escanor HUB] Coords error: " .. tostring(err))
        return
    end
    _G.CoordsDisplayEnabled = true
end

function OthersModule.stopCoordsDisplay()
    if not _G.CoordsDisplayEnabled then return end
    local gui = LP.PlayerGui:FindFirstChild("CoordsDisplay")
    if not gui then
        pcall(function() gui = game:GetService("CoreGui"):FindFirstChild("CoordsDisplay") end)
    end
    if gui then gui:Destroy() end
    _G.CoordsDisplayEnabled = false
end

function OthersModule.toggleCoordsDisplay(state)
    if state == nil then state = not _G.CoordsDisplayEnabled end
    if state then OthersModule.startCoordsDisplay() else OthersModule.stopCoordsDisplay() end
    return _G.CoordsDisplayEnabled
end

-- Timer / Stopwatch
function OthersModule.startTimer()
    if _G.TimerEnabled then return end
    local success, err = pcall(function()
        loadstring(game:HttpGet("https://pastebin.com/raw/cRxzSZwL"))()
    end)
    if not success then
        warn("[Escanor HUB] Timer error: " .. tostring(err))
        return
    end
    _G.TimerEnabled = true
end

function OthersModule.stopTimer()
    if not _G.TimerEnabled then return end
    local gui = LP.PlayerGui:FindFirstChild("TimerGUI")
    if not gui then
        pcall(function() gui = game:GetService("CoreGui"):FindFirstChild("TimerGUI") end)
    end
    if gui then gui:Destroy() end
    _G.TimerEnabled = false
end

function OthersModule.toggleTimer(state)
    if state == nil then state = not _G.TimerEnabled end
    if state then OthersModule.startTimer() else OthersModule.stopTimer() end
    return _G.TimerEnabled
end

-- =========================================================================
-- 3. ОТРИСОВКА ВКЛАДКИ «ДРУГОЕ»
-- =========================================================================
function OthersModule.render(parentFrame, context)
    context = context or {}
    local getText = context.GetText or function(k) return k end
    local textColor = context.TextColor or Color3.new(1, 1, 1)

    -- Очищаем контейнер перед отрисовкой
    for _, child in ipairs(parentFrame:GetChildren()) do
        if child:IsA("Frame") or child:IsA("TextLabel") or child:IsA("TextButton") then
            child:Destroy()
        end
    end

    local function createRow(yPos, labelText, currentState, onToggle)
        local frame = Instance.new("Frame", parentFrame)
        frame.Size = UDim2.new(1, -4, 0, 24)
        frame.Position = UDim2.new(0, 2, 0, yPos)
        frame.BackgroundTransparency = 1

        local lbl = Instance.new("TextLabel", frame)
        lbl.Size = UDim2.new(0.65, 0, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.Text = labelText
        lbl.TextColor3 = textColor
        lbl.TextSize = 10
        lbl.Font = Enum.Font.GothamSemibold
        lbl.TextXAlignment = Enum.TextXAlignment.Left

        local btn = Instance.new("TextButton", frame)
        btn.Size = UDim2.new(0, 45, 0, 20)
        btn.Position = UDim2.new(0.72, 0, 0.5, -10)
        btn.Text = currentState and "ON" or "OFF"
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.BackgroundColor3 = currentState and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(80, 80, 80)
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

        btn.MouseButton1Click:Connect(function()
            local newState = onToggle()
            btn.Text = newState and "ON" or "OFF"
            btn.BackgroundColor3 = newState and Color3.fromRGB(0, 200, 0) or Color3.fromRGB(80, 80, 80)
        end)
    end

    createRow(2,   getText("anti_afk"),        _G.AntiAFKEnabled,        OthersModule.toggleAntiAFK)
    createRow(28,  getText("fps_ping"),        _G.ShowFPS,               OthersModule.toggleFPS)
    createRow(54,  getText("fullbright"),      _G.FullbrightEnabled,      OthersModule.toggleFullbright)
    createRow(80,  getText("coords_display"),  _G.CoordsDisplayEnabled,  OthersModule.toggleCoordsDisplay)
    createRow(106, getText("timer"),           _G.TimerEnabled,          OthersModule.toggleTimer)
end

-- Автозапуск активных утилит при перезагрузке
if _G.AntiAFKEnabled then OthersModule.startAntiAFK() end
if _G.ShowFPS then OthersModule.startFPS() end
if _G.FullbrightEnabled then OthersModule.startFullbright() end
if _G.CoordsDisplayEnabled then OthersModule.startCoordsDisplay() end
if _G.TimerEnabled then OthersModule.startTimer() end

-- ОБЯЗАТЕЛЬНЫЙ ЭКСПОРТ ДЛЯ LOADSTRING
return OthersModule
