local API = _G.BABFT
if not API then
    warn("[BABFT-GUI] Ошибка: Ядро API не найдено!")
    return
end

local player = API.player
local TweenService = API.TweenService
local UserInputService = API.UserInputService
local UI = API.UI

local function createCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local function createStroke(parent, color, thickness)
    local s = Instance.new("UIStroke")
    s.Thickness = thickness or 1.5
    s.Color = color
    s.Parent = parent
    return s
end

local function formatNum(n)
    local left, num, right = string.match(tostring(math.floor(n)), "^([^%d]*%d)(%d*)(.-)$")
    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

local function getSafeGuiParent()
    if typeof(gethui) == "function" then
        local ok, res = pcall(gethui)
        if ok and res then return res end
    end
    local coreOk, coreGui = pcall(function() return game:GetService("CoreGui") end)
    if coreOk and coreGui then
        local canAccess = pcall(function()
            local testObj = Instance.new("Folder")
            testObj.Name = "TestAccessFolder"
            testObj.Parent = coreGui
            testObj:Destroy()
        end)
        if canAccess then return coreGui end
    end
    local pGui = player:FindFirstChild("PlayerGui")
    if not pGui then pGui = player:WaitForChild("PlayerGui", 10) end
    return pGui
end

local guiParent = getSafeGuiParent()

pcall(function()
    if guiParent then
        local old = guiParent:FindFirstChild("BabftPurpleUI")
        if old then old:Destroy() end
    end
    local pGui = player:FindFirstChild("PlayerGui")
    if pGui and pGui ~= guiParent then
        local oldP = pGui:FindFirstChild("BabftPurpleUI")
        if oldP then oldP:Destroy() end
    end
end)

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "BabftPurpleUI"
screenGui.ResetOnSpawn = false
screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local parentSetOk = pcall(function() screenGui.Parent = guiParent end)
if not parentSetOk or not screenGui.Parent then
    local fallbackGui = player:WaitForChild("PlayerGui", 5)
    screenGui.Parent = fallbackGui
    guiParent = fallbackGui
end

API.screenGui = screenGui

function API.showAchievementToast(title, text)
    API.playSfx(API.achievementSfx)
    local toast = Instance.new("Frame")
    toast.Size = UDim2.new(0, 260, 0, 50)
    toast.Position = UDim2.new(0.5, -130, -0.15, 0)
    toast.BackgroundColor3 = Color3.fromRGB(24, 18, 36)
    toast.BorderSizePixel = 0
    toast.ZIndex = 100
    toast.Parent = screenGui

    createCorner(toast, 10)
    createStroke(toast, Color3.fromRGB(255, 215, 0), 1.8)

    local icon = Instance.new("TextLabel")
    icon.Size = UDim2.new(0, 36, 1, 0)
    icon.BackgroundTransparency = 1
    icon.Text = "🏆"
    icon.TextSize = 22
    icon.ZIndex = 101
    icon.Parent = toast

    local tTitle = Instance.new("TextLabel")
    tTitle.Size = UDim2.new(1, -44, 0, 18)
    tTitle.Position = UDim2.new(0, 38, 0, 7)
    tTitle.BackgroundTransparency = 1
    tTitle.Text = title
    tTitle.TextColor3 = Color3.fromRGB(255, 215, 0)
    tTitle.Font = Enum.Font.GothamBold
    tTitle.TextSize = 11
    tTitle.TextXAlignment = Enum.TextXAlignment.Left
    tTitle.ZIndex = 101
    tTitle.Parent = toast

    local tDesc = Instance.new("TextLabel")
    tDesc.Size = UDim2.new(1, -44, 0, 16)
    tDesc.Position = UDim2.new(0, 38, 0, 25)
    tDesc.BackgroundTransparency = 1
    tDesc.Text = text
    tDesc.TextColor3 = Color3.fromRGB(230, 220, 255)
    tDesc.Font = Enum.Font.Gotham
    tDesc.TextSize = 10
    tDesc.TextXAlignment = Enum.TextXAlignment.Left
    tDesc.ZIndex = 101
    tDesc.Parent = toast

    toast:TweenPosition(UDim2.new(0.5, -130, 0.04, 0), Enum.EasingDirection.Out, Enum.EasingStyle.Back, 0.4, true)
    task.delay(3.5, function()
        if toast and toast.Parent then
            toast:TweenPosition(UDim2.new(0.5, -130, -0.15, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quad, 0.35, true, function()
                toast:Destroy()
            end)
        end
    end)
end

local blackScreenFrame = Instance.new("Frame")
blackScreenFrame.Size = UDim2.new(1, 0, 1, 0)
blackScreenFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
blackScreenFrame.BorderSizePixel = 0
blackScreenFrame.Visible = false
blackScreenFrame.ZIndex = 500
blackScreenFrame.Parent = screenGui
UI.blackScreenFrame = blackScreenFrame

local bsTitle = Instance.new("TextLabel")
bsTitle.Size = UDim2.new(1, 0, 0, 30)
bsTitle.Position = UDim2.new(0, 0, 0.33, 0)
bsTitle.BackgroundTransparency = 1
bsTitle.Text = "🔋 РЕЖИМ ЭНЕРГОСБЕРЕЖЕНИЯ"
bsTitle.TextColor3 = Color3.fromRGB(138, 43, 226)
bsTitle.Font = Enum.Font.GothamBold
bsTitle.TextSize = 14
bsTitle.ZIndex = 501
bsTitle.Parent = blackScreenFrame

local bsStats = Instance.new("TextLabel")
bsStats.Size = UDim2.new(1, 0, 0, 85)
bsStats.Position = UDim2.new(0, 0, 0.39, 0)
bsStats.BackgroundTransparency = 1
bsStats.Text = "Заработано: +0 Gold\nСкорость: сбор данных...\nВремя: 00:00:00"
bsStats.TextColor3 = Color3.fromRGB(200, 190, 225)
bsStats.Font = Enum.Font.Gotham
bsStats.TextSize = 12
bsStats.ZIndex = 501
bsStats.Parent = blackScreenFrame
UI.bsStats = bsStats

local bsUnlockBtn = Instance.new("TextButton")
bsUnlockBtn.Size = UDim2.new(0, 180, 0, 34)
bsUnlockBtn.Position = UDim2.new(0.5, -90, 0.55, 0)
bsUnlockBtn.BackgroundColor3 = Color3.fromRGB(30, 22, 45)
bsUnlockBtn.Text = "ВКЛЮЧИТЬ ЭКРАН"
bsUnlockBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
bsUnlockBtn.Font = Enum.Font.GothamBold
bsUnlockBtn.TextSize = 11
bsUnlockBtn.BorderSizePixel = 0
bsUnlockBtn.ZIndex = 501
bsUnlockBtn.Parent = blackScreenFrame
createCorner(bsUnlockBtn, 8)
createStroke(bsUnlockBtn, Color3.fromRGB(138, 43, 226), 1.5)

function API.toggleBlackScreen(state)
    API.isBlackScreen = state
    blackScreenFrame.Visible = API.isBlackScreen
    pcall(function() API.RunService:Set3dRenderingEnabled(not API.isBlackScreen) end)
end

bsUnlockBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.toggleBlackScreen(false)
end)

local savedWindowSize = UDim2.new(0, API.windowSizeX or 260, 0, API.windowSizeY or 320)
local mainFrame = Instance.new("Frame")
mainFrame.Size = savedWindowSize
mainFrame.Position = UDim2.new(API.windowScaleX or 0.5, API.windowPosX or -130, API.windowScaleY or 0.28, API.windowPosY or 0)
mainFrame.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
mainFrame.BorderSizePixel = 0
mainFrame.Active = true
mainFrame.ClipsDescendants = true
mainFrame.ZIndex = 1
mainFrame.Parent = screenGui
UI.mainFrame = mainFrame

createCorner(mainFrame, 12)
local frameStroke = createStroke(mainFrame, Color3.fromRGB(180, 100, 255), 1.8)
frameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local strokeGradient = Instance.new("UIGradient")
strokeGradient.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(138, 43, 226)),
    ColorSequenceKeypoint.new(0.35, Color3.fromRGB(218, 112, 214)),
    ColorSequenceKeypoint.new(0.7, Color3.fromRGB(147, 0, 211)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(75, 0, 130))
})
strokeGradient.Parent = frameStroke
UI.strokeGradient = strokeGradient

local topBar = Instance.new("Frame")
topBar.Size = UDim2.new(1, 0, 0, 34)
topBar.BackgroundTransparency = 1
topBar.ZIndex = 50
topBar.Parent = mainFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Size = UDim2.new(1, -70, 1, 0)
titleLabel.Position = UDim2.new(0, 12, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "BABFT AUTO FARM"
titleLabel.TextColor3 = Color3.fromRGB(230, 210, 255)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 13
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 51
titleLabel.Parent = topBar

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 22, 0, 22)
minBtn.Position = UDim2.new(1, -52, 0, 6)
minBtn.BackgroundColor3 = Color3.fromRGB(35, 25, 50)
minBtn.Text = "-"
minBtn.TextColor3 = Color3.fromRGB(220, 200, 255)
minBtn.Font = Enum.Font.GothamBold
minBtn.TextSize = 14
minBtn.BorderSizePixel = 0
minBtn.ZIndex = 51
minBtn.Parent = topBar
createCorner(minBtn, 6)

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.new(0, 22, 0, 22)
closeBtn.Position = UDim2.new(1, -26, 0, 6)
closeBtn.BackgroundColor3 = Color3.fromRGB(50, 20, 35)
closeBtn.Text = "×"
closeBtn.TextColor3 = Color3.fromRGB(255, 130, 150)
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 14
closeBtn.BorderSizePixel = 0
closeBtn.ZIndex = 51
closeBtn.Parent = topBar
createCorner(closeBtn, 6)

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, 0, 1, -34)
scrollFrame.Position = UDim2.new(0, 0, 0, 34)
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarThickness = 3
scrollFrame.ScrollBarImageColor3 = Color3.fromRGB(138, 43, 226)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 640)
scrollFrame.ZIndex = 20
scrollFrame.Parent = mainFrame
UI.scrollFrame = scrollFrame

local modeContainer = Instance.new("Frame")
modeContainer.Size = UDim2.new(1, -24, 0, 24)
modeContainer.Position = UDim2.new(0, 12, 0, 4)
modeContainer.BackgroundTransparency = 1
modeContainer.ZIndex = 21
modeContainer.Parent = scrollFrame

local chestModeBtn = Instance.new("TextButton")
chestModeBtn.Size = UDim2.new(0.5, -4, 1, 0)
chestModeBtn.Position = UDim2.new(0, 0, 0, 0)
chestModeBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
chestModeBtn.Text = "Сундук"
chestModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
chestModeBtn.Font = Enum.Font.GothamBold
chestModeBtn.TextSize = 11
chestModeBtn.BorderSizePixel = 0
chestModeBtn.ZIndex = 22
chestModeBtn.Parent = modeContainer
createCorner(chestModeBtn, 6)
UI.chestModeBtn = chestModeBtn

local goldModeBtn = Instance.new("TextButton")
goldModeBtn.Size = UDim2.new(0.5, -4, 1, 0)
goldModeBtn.Position = UDim2.new(0.5, 4, 0, 0)
goldModeBtn.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
goldModeBtn.Text = "Золото"
goldModeBtn.TextColor3 = Color3.fromRGB(160, 145, 185)
goldModeBtn.Font = Enum.Font.GothamBold
goldModeBtn.TextSize = 11
goldModeBtn.BorderSizePixel = 0
goldModeBtn.ZIndex = 22
goldModeBtn.Parent = modeContainer
createCorner(goldModeBtn, 6)
UI.goldModeBtn = goldModeBtn

local delayContainer = Instance.new("Frame")
delayContainer.Size = UDim2.new(1, -24, 0, 18)
delayContainer.Position = UDim2.new(0, 12, 0, 32)
delayContainer.BackgroundTransparency = 1
delayContainer.ZIndex = 21
delayContainer.Parent = scrollFrame

local delayLabel = Instance.new("TextLabel")
delayLabel.Size = UDim2.new(1, -50, 1, 0)
delayLabel.Position = UDim2.new(0, 0, 0, 0)
delayLabel.BackgroundTransparency = 1
delayLabel.Text = "Задержка сундука (сек):"
delayLabel.TextColor3 = Color3.fromRGB(200, 190, 225)
delayLabel.Font = Enum.Font.Gotham
delayLabel.TextSize = 11
delayLabel.TextXAlignment = Enum.TextXAlignment.Left
delayLabel.ZIndex = 22
delayLabel.Parent = delayContainer

local delayBox = Instance.new("TextBox")
delayBox.Size = UDim2.new(0, 45, 1, 0)
delayBox.Position = UDim2.new(1, -45, 0, 0)
delayBox.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
delayBox.Text = tostring(API.chestDelay)
delayBox.TextColor3 = Color3.fromRGB(255, 255, 255)
delayBox.Font = Enum.Font.GothamBold
delayBox.TextSize = 11
delayBox.BorderSizePixel = 0
delayBox.ClearTextOnFocus = false
delayBox.ZIndex = 22
delayBox.Parent = delayContainer
createCorner(delayBox, 5)
UI.delayBox = delayBox

local stageDelayContainer = Instance.new("Frame")
stageDelayContainer.Size = UDim2.new(1, -24, 0, 18)
stageDelayContainer.Position = UDim2.new(0, 12, 0, 52)
stageDelayContainer.BackgroundTransparency = 1
stageDelayContainer.ZIndex = 21
stageDelayContainer.Parent = scrollFrame

local stageDelayLabel = Instance.new("TextLabel")
stageDelayLabel.Size = UDim2.new(1, -50, 1, 0)
stageDelayLabel.Position = UDim2.new(0, 0, 0, 0)
stageDelayLabel.BackgroundTransparency = 1
stageDelayLabel.Text = "Задержка ТП (сек):"
stageDelayLabel.TextColor3 = Color3.fromRGB(200, 190, 225)
stageDelayLabel.Font = Enum.Font.Gotham
stageDelayLabel.TextSize = 11
stageDelayLabel.TextXAlignment = Enum.TextXAlignment.Left
stageDelayLabel.ZIndex = 22
stageDelayLabel.Parent = stageDelayContainer

local stageDelayBox = Instance.new("TextBox")
stageDelayBox.Size = UDim2.new(0, 45, 1, 0)
stageDelayBox.Position = UDim2.new(1, -45, 0, 0)
stageDelayBox.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
stageDelayBox.Text = tostring(API.stageDelay)
stageDelayBox.TextColor3 = Color3.fromRGB(255, 255, 255)
stageDelayBox.Font = Enum.Font.GothamBold
stageDelayBox.TextSize = 11
stageDelayBox.BorderSizePixel = 0
stageDelayBox.ClearTextOnFocus = false
stageDelayBox.ZIndex = 22
stageDelayBox.Parent = stageDelayContainer
createCorner(stageDelayBox, 5)
UI.stageDelayBox = stageDelayBox

local chestStageContainer = Instance.new("Frame")
chestStageContainer.Size = UDim2.new(1, -24, 0, 18)
chestStageContainer.Position = UDim2.new(0, 12, 0, 72)
chestStageContainer.BackgroundTransparency = 1
chestStageContainer.ZIndex = 21
chestStageContainer.Parent = scrollFrame

local chestStageLabel = Instance.new("TextLabel")
chestStageLabel.Size = UDim2.new(1, -50, 1, 0)
chestStageLabel.Position = UDim2.new(0, 0, 0, 0)
chestStageLabel.BackgroundTransparency = 1
chestStageLabel.Text = "Этап сундука (1-10):"
chestStageLabel.TextColor3 = Color3.fromRGB(200, 190, 225)
chestStageLabel.Font = Enum.Font.Gotham
chestStageLabel.TextSize = 11
chestStageLabel.TextXAlignment = Enum.TextXAlignment.Left
chestStageLabel.ZIndex = 22
chestStageLabel.Parent = chestStageContainer

local chestStageBox = Instance.new("TextBox")
chestStageBox.Size = UDim2.new(0, 45, 1, 0)
chestStageBox.Position = UDim2.new(1, -45, 0, 0)
chestStageBox.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
chestStageBox.Text = tostring(API.chestStage or 2)
chestStageBox.TextColor3 = Color3.fromRGB(255, 255, 255)
chestStageBox.Font = Enum.Font.GothamBold
chestStageBox.TextSize = 11
chestStageBox.BorderSizePixel = 0
chestStageBox.ClearTextOnFocus = false
chestStageBox.ZIndex = 22
chestStageBox.Parent = chestStageContainer
createCorner(chestStageBox, 5)
UI.chestStageBox = chestStageBox

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -24, 0, 14)
statusLabel.Position = UDim2.new(0, 12, 0, 94)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Статус: Оффлайн"
statusLabel.TextColor3 = Color3.fromRGB(180, 165, 205)
statusLabel.Font = Enum.Font.Gotham
statusLabel.TextSize = 10
statusLabel.ZIndex = 22
statusLabel.Parent = scrollFrame
UI.statusLabel = statusLabel

local startAndCurrentGoldLabel = Instance.new("TextLabel")
startAndCurrentGoldLabel.Size = UDim2.new(1, -24, 0, 14)
startAndCurrentGoldLabel.Position = UDim2.new(0, 12, 0, 109)
startAndCurrentGoldLabel.BackgroundTransparency = 1
startAndCurrentGoldLabel.Text = "Старт: 0  |  Сейчас: " .. tostring(API.getCurrentGold())
startAndCurrentGoldLabel.TextColor3 = Color3.fromRGB(200, 190, 225)
startAndCurrentGoldLabel.Font = Enum.Font.Gotham
startAndCurrentGoldLabel.TextSize = 10
startAndCurrentGoldLabel.ZIndex = 22
startAndCurrentGoldLabel.Parent = scrollFrame
UI.startAndCurrentGoldLabel = startAndCurrentGoldLabel

local goldTrackerLabel = Instance.new("TextLabel")
goldTrackerLabel.Size = UDim2.new(1, -24, 0, 14)
goldTrackerLabel.Position = UDim2.new(0, 12, 0, 124)
goldTrackerLabel.BackgroundTransparency = 1
goldTrackerLabel.Text = "Заработано: +0 Gold"
goldTrackerLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
goldTrackerLabel.Font = Enum.Font.GothamBold
goldTrackerLabel.TextSize = 10
goldTrackerLabel.ZIndex = 22
goldTrackerLabel.Parent = scrollFrame
UI.goldTrackerLabel = goldTrackerLabel

local goldSpeedLabel = Instance.new("TextLabel")
goldSpeedLabel.Size = UDim2.new(1, -24, 0, 14)
goldSpeedLabel.Position = UDim2.new(0, 12, 0, 139)
goldSpeedLabel.BackgroundTransparency = 1
goldSpeedLabel.Text = "Скорость: ~0 G/ч (0.0 G/мин)"
goldSpeedLabel.TextColor3 = Color3.fromRGB(130, 240, 175)
goldSpeedLabel.Font = Enum.Font.GothamBold
goldSpeedLabel.TextSize = 10
goldSpeedLabel.ZIndex = 22
goldSpeedLabel.Parent = scrollFrame
UI.goldSpeedLabel = goldSpeedLabel

local minuteStatsLabel = Instance.new("TextLabel")
minuteStatsLabel.Size = UDim2.new(1, -24, 0, 14)
minuteStatsLabel.Position = UDim2.new(0, 12, 0, 154)
minuteStatsLabel.BackgroundTransparency = 1
minuteStatsLabel.Text = "Мин. статистика: нет данных"
minuteStatsLabel.TextColor3 = Color3.fromRGB(215, 185, 255)
minuteStatsLabel.Font = Enum.Font.Gotham
minuteStatsLabel.TextSize = 9
minuteStatsLabel.ZIndex = 22
minuteStatsLabel.Parent = scrollFrame
UI.minuteStatsLabel = minuteStatsLabel

local etaLabel = Instance.new("TextLabel")
etaLabel.Size = UDim2.new(1, -24, 0, 14)
etaLabel.Position = UDim2.new(0, 12, 0, 169)
etaLabel.BackgroundTransparency = 1
etaLabel.Text = "До покупки: Выкл"
etaLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
etaLabel.Font = Enum.Font.GothamBold
etaLabel.TextSize = 10
etaLabel.ZIndex = 22
etaLabel.Parent = scrollFrame
UI.etaLabel = etaLabel

local timeTrackerLabel = Instance.new("TextLabel")
timeTrackerLabel.Size = UDim2.new(1, -24, 0, 14)
timeTrackerLabel.Position = UDim2.new(0, 12, 0, 184)
timeTrackerLabel.BackgroundTransparency = 1
timeTrackerLabel.Text = "Время фарма: 00:00:00"
timeTrackerLabel.TextColor3 = Color3.fromRGB(165, 195, 255)
timeTrackerLabel.Font = Enum.Font.GothamBold
timeTrackerLabel.TextSize = 10
timeTrackerLabel.ZIndex = 22
timeTrackerLabel.Parent = scrollFrame
UI.timeTrackerLabel = timeTrackerLabel

-- Авто-закупка (одиночная)
local autoBuyRow = Instance.new("Frame")
autoBuyRow.Size = UDim2.new(1, -24, 0, 22)
autoBuyRow.Position = UDim2.new(0, 12, 0, 202)
autoBuyRow.BackgroundTransparency = 1
autoBuyRow.ZIndex = 21
autoBuyRow.Parent = scrollFrame

local autoBuyToggleBtn = Instance.new("TextButton")
autoBuyToggleBtn.Size = UDim2.new(0.6, -4, 1, 0)
autoBuyToggleBtn.Position = UDim2.new(0, 0, 0, 0)
autoBuyToggleBtn.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
autoBuyToggleBtn.Text = "Авто-закупка: ВЫКЛ"
autoBuyToggleBtn.TextColor3 = Color3.fromRGB(175, 160, 205)
autoBuyToggleBtn.Font = Enum.Font.GothamBold
autoBuyToggleBtn.TextSize = 10
autoBuyToggleBtn.BorderSizePixel = 0
autoBuyToggleBtn.ZIndex = 22
autoBuyToggleBtn.Parent = autoBuyRow
createCorner(autoBuyToggleBtn, 5)
UI.autoBuyToggleBtn = autoBuyToggleBtn

local amountLabel = Instance.new("TextLabel")
amountLabel.Size = UDim2.new(0.2, 0, 1, 0)
amountLabel.Position = UDim2.new(0.6, 0, 0, 0)
amountLabel.BackgroundTransparency = 1
amountLabel.Text = "Пачек:"
amountLabel.TextColor3 = Color3.fromRGB(200, 190, 225)
amountLabel.Font = Enum.Font.Gotham
amountLabel.TextSize = 10
amountLabel.ZIndex = 22
amountLabel.Parent = autoBuyRow

local amountBox = Instance.new("TextBox")
amountBox.Size = UDim2.new(0.2, -4, 1, 0)
amountBox.Position = UDim2.new(0.8, 4, 0, 0)
amountBox.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
amountBox.Text = tostring(API.buyAmount)
amountBox.TextColor3 = Color3.fromRGB(255, 255, 255)
amountBox.Font = Enum.Font.GothamBold
amountBox.TextSize = 10
amountBox.BorderSizePixel = 0
amountBox.ClearTextOnFocus = false
amountBox.ZIndex = 22
amountBox.Parent = autoBuyRow
createCorner(amountBox, 5)
UI.amountBox = amountBox

local itemInputBox = Instance.new("TextBox")
itemInputBox.Size = UDim2.new(1, -24, 0, 20)
itemInputBox.Position = UDim2.new(0, 12, 0, 228)
itemInputBox.BackgroundColor3 = Color3.fromRGB(30, 24, 40)
itemInputBox.PlaceholderText = "Введите блок (напр. Лего, Дерево)..."
itemInputBox.PlaceholderColor3 = Color3.fromRGB(120, 105, 145)
itemInputBox.Text = ""
itemInputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
itemInputBox.Font = Enum.Font.Gotham
itemInputBox.TextSize = 10
itemInputBox.BorderSizePixel = 0
itemInputBox.ClearTextOnFocus = false
itemInputBox.ZIndex = 22
itemInputBox.Parent = scrollFrame
createCorner(itemInputBox, 5)
UI.itemInputBox = itemInputBox

local itemStatusLabel = Instance.new("TextLabel")
itemStatusLabel.Size = UDim2.new(1, -24, 0, 15)
itemStatusLabel.Position = UDim2.new(0, 12, 0, 251)
itemStatusLabel.BackgroundTransparency = 1
itemStatusLabel.Text = "Введите название для поиска"
itemStatusLabel.TextColor3 = Color3.fromRGB(140, 130, 160)
itemStatusLabel.Font = Enum.Font.GothamBold
itemStatusLabel.TextSize = 9
itemStatusLabel.ZIndex = 22
itemStatusLabel.Parent = scrollFrame
UI.itemStatusLabel = itemStatusLabel

-- Подсчет в реальном времени для главного GUI: пачки * блоки
local function updateGuiItemCalculation()
    local text = itemInputBox.Text
    if text == "" then
        API.targetItemRealName = ""
        API.targetItemPrice = 0
        API.targetItemYield = 1
        itemStatusLabel.Text = "Введите название для поиска"
        itemStatusLabel.TextColor3 = Color3.fromRGB(140, 130, 160)
        return
    end

    if API.searchItemInGame then
        local realName, price, packYield = API.searchItemInGame(text)
        if realName and price > 0 then
            local packs = tonumber(amountBox.Text) or 1
            if packs <= 0 then packs = 1 end
            packs = math.floor(packs)

            packYield = packYield or 1
            local totalBlocks = packs * packYield
            local totalGold = packs * price

            API.targetItemRealName = realName
            API.targetItemPrice = price
            API.targetItemYield = packYield

            if packYield > 1 then
                itemStatusLabel.Text = string.format("✔ %s: %s пач. × %d = %s блоков (%s G)", realName, formatNum(packs), packYield, formatNum(totalBlocks), formatNum(totalGold))
            else
                itemStatusLabel.Text = string.format("✔ %s: %s шт. (%s G)", realName, formatNum(packs), formatNum(totalGold))
            end
            itemStatusLabel.TextColor3 = Color3.fromRGB(80, 240, 130)
            if API.checkAndAutoBuy then API.checkAndAutoBuy() end
        else
            API.targetItemRealName = ""
            API.targetItemPrice = 0
            itemStatusLabel.Text = "✖ Блок не найден в магазине"
            itemStatusLabel.TextColor3 = Color3.fromRGB(255, 80, 90)
        end
    end
end

itemInputBox:GetPropertyChangedSignal("Text"):Connect(updateGuiItemCalculation)
amountBox:GetPropertyChangedSignal("Text"):Connect(updateGuiItemCalculation)

local antiDarkBtn = Instance.new("TextButton")
antiDarkBtn.Size = UDim2.new(1, -24, 0, 20)
antiDarkBtn.Position = UDim2.new(0, 12, 0, 269)
antiDarkBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
antiDarkBtn.Text = "Анти-темнота: ВКЛ"
antiDarkBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
antiDarkBtn.Font = Enum.Font.GothamBold
antiDarkBtn.TextSize = 10
antiDarkBtn.BorderSizePixel = 0
antiDarkBtn.ZIndex = 22
antiDarkBtn.Parent = scrollFrame
createCorner(antiDarkBtn, 5)
UI.antiDarkBtn = antiDarkBtn

local antiHazardBtn = Instance.new("TextButton")
antiHazardBtn.Size = UDim2.new(1, -24, 0, 20)
antiHazardBtn.Position = UDim2.new(0, 12, 0, 292)
antiHazardBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
antiHazardBtn.Text = "🛡 Анти-урон / Вода: ВКЛ"
antiHazardBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
antiHazardBtn.Font = Enum.Font.GothamBold
antiHazardBtn.TextSize = 10
antiHazardBtn.BorderSizePixel = 0
antiHazardBtn.ZIndex = 22
antiHazardBtn.Parent = scrollFrame
createCorner(antiHazardBtn, 5)
UI.antiHazardBtn = antiHazardBtn

local batterySaverBtn = Instance.new("TextButton")
batterySaverBtn.Size = UDim2.new(1, -24, 0, 20)
batterySaverBtn.Position = UDim2.new(0, 12, 0, 315)
batterySaverBtn.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
batterySaverBtn.Text = "🔋 Ночной режим (Экран): ВЫКЛ"
batterySaverBtn.TextColor3 = Color3.fromRGB(175, 160, 205)
batterySaverBtn.Font = Enum.Font.GothamBold
batterySaverBtn.TextSize = 10
batterySaverBtn.BorderSizePixel = 0
batterySaverBtn.ZIndex = 22
batterySaverBtn.Parent = scrollFrame
createCorner(batterySaverBtn, 5)
UI.batterySaverBtn = batterySaverBtn

local antiLagBtn = Instance.new("TextButton")
antiLagBtn.Size = UDim2.new(1, -24, 0, 20)
antiLagBtn.Position = UDim2.new(0, 12, 0, 338)
antiLagBtn.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
antiLagBtn.Text = "⚡ Анти-лаг очистка: ВЫКЛ"
antiLagBtn.TextColor3 = Color3.fromRGB(175, 160, 205)
antiLagBtn.Font = Enum.Font.GothamBold
antiLagBtn.TextSize = 10
antiLagBtn.BorderSizePixel = 0
antiLagBtn.ZIndex = 22
antiLagBtn.Parent = scrollFrame
createCorner(antiLagBtn, 5)
UI.antiLagBtn = antiLagBtn

local smoothnessBtn = Instance.new("TextButton")
smoothnessBtn.Size = UDim2.new(1, -24, 0, 20)
smoothnessBtn.Position = UDim2.new(0, 12, 0, 361)
smoothnessBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 65)
smoothnessBtn.Text = "🚀 Плавность: " .. API.smoothnessNames[API.smoothnessMode]
smoothnessBtn.TextColor3 = Color3.fromRGB(225, 210, 255)
smoothnessBtn.Font = Enum.Font.GothamBold
smoothnessBtn.TextSize = 10
smoothnessBtn.BorderSizePixel = 0
smoothnessBtn.ZIndex = 22
smoothnessBtn.Parent = scrollFrame
createCorner(smoothnessBtn, 5)
UI.smoothnessBtn = smoothnessBtn

local spaceBgBtn = Instance.new("TextButton")
spaceBgBtn.Size = UDim2.new(1, -24, 0, 20)
spaceBgBtn.Position = UDim2.new(0, 12, 0, 384)
spaceBgBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
spaceBgBtn.Text = "🌌 Космо-фон: ВКЛ"
spaceBgBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
spaceBgBtn.Font = Enum.Font.GothamBold
spaceBgBtn.TextSize = 10
spaceBgBtn.BorderSizePixel = 0
spaceBgBtn.ZIndex = 22
spaceBgBtn.Parent = scrollFrame
createCorner(spaceBgBtn, 5)
UI.spaceBgBtn = spaceBgBtn

local soundToggleBtn = Instance.new("TextButton")
soundToggleBtn.Size = UDim2.new(1, -24, 0, 20)
soundToggleBtn.Position = UDim2.new(0, 12, 0, 407)
soundToggleBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
soundToggleBtn.Text = "🔊 Звуковые эффекты: ВКЛ"
soundToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
soundToggleBtn.Font = Enum.Font.GothamBold
soundToggleBtn.TextSize = 10
soundToggleBtn.BorderSizePixel = 0
soundToggleBtn.ZIndex = 22
soundToggleBtn.Parent = scrollFrame
createCorner(soundToggleBtn, 5)
UI.soundToggleBtn = soundToggleBtn

local customSoundsBtn = Instance.new("TextButton")
customSoundsBtn.Size = UDim2.new(1, -24, 0, 20)
customSoundsBtn.Position = UDim2.new(0, 12, 0, 430)
customSoundsBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
customSoundsBtn.Text = "🐾 Кастомные звуки (Шаги): ВКЛ"
customSoundsBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
customSoundsBtn.Font = Enum.Font.GothamBold
customSoundsBtn.TextSize = 10
customSoundsBtn.BorderSizePixel = 0
customSoundsBtn.ZIndex = 22
customSoundsBtn.Parent = scrollFrame
createCorner(customSoundsBtn, 5)
UI.customSoundsBtn = customSoundsBtn

local cartOpenBtn = Instance.new("TextButton")
cartOpenBtn.Size = UDim2.new(0.5, -16, 0, 22)
cartOpenBtn.Position = UDim2.new(0, 12, 0, 453)
cartOpenBtn.BackgroundColor3 = Color3.fromRGB(110, 30, 180)
cartOpenBtn.Text = "🛒 КОРЗИНА"
cartOpenBtn.TextColor3 = Color3.fromRGB(255, 230, 130)
cartOpenBtn.Font = Enum.Font.GothamBold
cartOpenBtn.TextSize = 10
cartOpenBtn.BorderSizePixel = 0
cartOpenBtn.ZIndex = 22
cartOpenBtn.Parent = scrollFrame
createCorner(cartOpenBtn, 5)
createStroke(cartOpenBtn, Color3.fromRGB(218, 112, 214), 1)

local questOpenBtn = Instance.new("TextButton")
questOpenBtn.Size = UDim2.new(0.5, -16, 0, 22)
questOpenBtn.Position = UDim2.new(0.5, 4, 0, 453)
questOpenBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
questOpenBtn.Text = "⚡ КВЕСТЫ"
questOpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
questOpenBtn.Font = Enum.Font.GothamBold
questOpenBtn.TextSize = 10
questOpenBtn.BorderSizePixel = 0
questOpenBtn.ZIndex = 22
questOpenBtn.Parent = scrollFrame
createCorner(questOpenBtn, 5)
createStroke(questOpenBtn, Color3.fromRGB(180, 100, 255), 1)

local tgTokenInputBox = Instance.new("TextBox")
tgTokenInputBox.Size = UDim2.new(1, -24, 0, 20)
tgTokenInputBox.Position = UDim2.new(0, 12, 0, 479)
tgTokenInputBox.BackgroundColor3 = Color3.fromRGB(30, 24, 40)
tgTokenInputBox.PlaceholderText = "Telegram Bot Token..."
tgTokenInputBox.PlaceholderColor3 = Color3.fromRGB(120, 105, 145)
tgTokenInputBox.Text = API.tgToken
tgTokenInputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
tgTokenInputBox.Font = Enum.Font.Gotham
tgTokenInputBox.TextSize = 9
tgTokenInputBox.BorderSizePixel = 0
tgTokenInputBox.ClearTextOnFocus = false
tgTokenInputBox.ZIndex = 22
tgTokenInputBox.Parent = scrollFrame
createCorner(tgTokenInputBox, 5)
UI.tgTokenInputBox = tgTokenInputBox

local tgChatIdInputBox = Instance.new("TextBox")
tgChatIdInputBox.Size = UDim2.new(1, -24, 0, 20)
tgChatIdInputBox.Position = UDim2.new(0, 12, 0, 502)
tgChatIdInputBox.BackgroundColor3 = Color3.fromRGB(30, 24, 40)
tgChatIdInputBox.PlaceholderText = "Telegram Chat ID (число)..."
tgChatIdInputBox.PlaceholderColor3 = Color3.fromRGB(120, 105, 145)
tgChatIdInputBox.Text = API.tgChatId
tgChatIdInputBox.TextColor3 = Color3.fromRGB(255, 255, 255)
tgChatIdInputBox.Font = Enum.Font.Gotham
tgChatIdInputBox.TextSize = 9
tgChatIdInputBox.BorderSizePixel = 0
tgChatIdInputBox.ClearTextOnFocus = false
tgChatIdInputBox.ZIndex = 22
tgChatIdInputBox.Parent = scrollFrame
createCorner(tgChatIdInputBox, 5)
UI.tgChatIdInputBox = tgChatIdInputBox

local saveBtn = Instance.new("TextButton")
saveBtn.Size = UDim2.new(1, -24, 0, 24)
saveBtn.Position = UDim2.new(0, 12, 0, 526)
saveBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 65)
saveBtn.Text = "💾 СОХРАНИТЬ НАСТРОЙКИ"
saveBtn.TextColor3 = Color3.fromRGB(215, 195, 255)
saveBtn.Font = Enum.Font.GothamBold
saveBtn.TextSize = 10
saveBtn.BorderSizePixel = 0
saveBtn.ZIndex = 22
saveBtn.Parent = scrollFrame
createCorner(saveBtn, 6)
createStroke(saveBtn, Color3.fromRGB(138, 43, 226), 1)
UI.saveBtn = saveBtn

local toggleButton = Instance.new("TextButton")
toggleButton.Size = UDim2.new(1, -24, 0, 32)
toggleButton.Position = UDim2.new(0, 12, 0, 554)
toggleButton.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
toggleButton.Text = "START AUTO FARM"
toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
toggleButton.Font = Enum.Font.GothamBold
toggleButton.TextSize = 12
toggleButton.BorderSizePixel = 0
toggleButton.ZIndex = 22
toggleButton.Parent = scrollFrame
createCorner(toggleButton, 8)
UI.toggleButton = toggleButton

local creditsLabel = Instance.new("TextLabel")
creditsLabel.Size = UDim2.new(1, 0, 0, 16)
creditsLabel.Position = UDim2.new(0, 0, 0, 592)
creditsLabel.BackgroundTransparency = 1
creditsLabel.Text = "By: Probothotspot"
creditsLabel.TextColor3 = Color3.fromRGB(175, 150, 220)
creditsLabel.Font = Enum.Font.GothamBold
creditsLabel.TextSize = 11
creditsLabel.ZIndex = 22
creditsLabel.Parent = scrollFrame

local resizeGrip = Instance.new("TextButton")
resizeGrip.Size = UDim2.new(0, 18, 0, 18)
resizeGrip.Position = UDim2.new(1, -18, 1, -18)
resizeGrip.BackgroundTransparency = 1
resizeGrip.Text = "◢"
resizeGrip.TextColor3 = Color3.fromRGB(175, 130, 240)
resizeGrip.Font = Enum.Font.GothamBold
resizeGrip.TextSize = 13
resizeGrip.ZIndex = 60
resizeGrip.Parent = mainFrame

local resizing = false
local resizeStart = Vector2.zero
local startWindowSize = Vector2.zero

resizeGrip.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        resizing = true
        resizeStart = Vector2.new(input.Position.X, input.Position.Y)
        startWindowSize = Vector2.new(mainFrame.AbsoluteSize.X, mainFrame.AbsoluteSize.Y)
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                resizing = false
                if not API.isMinimized then
                    savedWindowSize = mainFrame.Size
                    if API.saveConfig then API.saveConfig() end
                end
            end
        end)
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if resizing and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = Vector2.new(input.Position.X, input.Position.Y) - resizeStart
        local newWidth = math.clamp(startWindowSize.X + delta.X, 240, 480)
        local newHeight = math.clamp(startWindowSize.Y + delta.Y, 260, 580)
        mainFrame.Size = UDim2.new(0, newWidth, 0, newHeight)
    end
end)

local dragging, dragStart, startPos
topBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
                if API.saveConfig then API.saveConfig() end
            end
        end)
    end
end)

topBar.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - dragStart
        mainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

minBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.isMinimized = not API.isMinimized
    if API.isMinimized then
        savedWindowSize = mainFrame.Size
        resizeGrip.Visible = false
        local tw = TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
            Size = UDim2.new(mainFrame.Size.X.Scale, mainFrame.Size.X.Offset, 0, 34)
        })
        tw:Play()
        tw.Completed:Connect(function() if API.isMinimized then scrollFrame.Visible = false end end)
        minBtn.Text = "+"
    else
        scrollFrame.Visible = true
        resizeGrip.Visible = true
        TweenService:Create(mainFrame, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = savedWindowSize
        }):Play()
        minBtn.Text = "-"
    end
end)

closeBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    if API.isClosing then return end
    API.isClosing = true
    if API.saveConfig then API.saveConfig(false) end
    local closeTween = TweenService:Create(mainFrame, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.In), {
        Size = UDim2.new(0, 0, 0, 0),
        BackgroundTransparency = 1
    })
    closeTween:Play()
    closeTween.Completed:Connect(function()
        API.fullCleanup()
    end)
end)

chestModeBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.farmMode = "Chest"
    chestModeBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    chestModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    goldModeBtn.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
    goldModeBtn.TextColor3 = Color3.fromRGB(160, 145, 185)
    if API.saveConfig then API.saveConfig() end
end)

goldModeBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.farmMode = "Gold"
    goldModeBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    goldModeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    chestModeBtn.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
    chestModeBtn.TextColor3 = Color3.fromRGB(160, 145, 185)
    if API.saveConfig then API.saveConfig() end
end)

delayBox.FocusLost:Connect(function()
    local val = tonumber(delayBox.Text)
    if val and val > 0 then API.chestDelay = val else delayBox.Text = tostring(API.chestDelay) end
    if API.saveConfig then API.saveConfig() end
end)

stageDelayBox.FocusLost:Connect(function()
    local val = tonumber(stageDelayBox.Text)
    if val and val > 0 then API.stageDelay = val else stageDelayBox.Text = tostring(API.stageDelay) end
    if API.saveConfig then API.saveConfig() end
end)

chestStageBox.FocusLost:Connect(function()
    local val = tonumber(chestStageBox.Text)
    if val then
        API.chestStage = math.clamp(math.floor(val), 1, 10)
    else
        API.chestStage = 2
    end
    chestStageBox.Text = tostring(API.chestStage)
    if API.saveConfig then API.saveConfig() end
end)

amountBox.FocusLost:Connect(function()
    local val = tonumber(amountBox.Text)
    if val and val > 0 then API.buyAmount = math.floor(val) else amountBox.Text = tostring(API.buyAmount) end
    if API.saveConfig then API.saveConfig() end
    updateGuiItemCalculation()
end)

autoBuyToggleBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.autoBuyActive = not API.autoBuyActive
    autoBuyToggleBtn.BackgroundColor3 = API.autoBuyActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
    autoBuyToggleBtn.TextColor3 = API.autoBuyActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
    autoBuyToggleBtn.Text = API.autoBuyActive and "Авто-закупка: ВКЛ" or "Авто-закупка: ВЫКЛ"
    if API.autoBuyActive and API.checkAndAutoBuy then API.checkAndAutoBuy() end
    if API.saveConfig then API.saveConfig() end
end)

smoothnessBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.smoothnessMode = (API.smoothnessMode % 3) + 1
    smoothnessBtn.Text = "🚀 Плавность: " .. API.smoothnessNames[API.smoothnessMode]
    if API.saveConfig then API.saveConfig() end
end)

soundToggleBtn.MouseButton1Click:Connect(function()
    API.soundEffectsActive = not API.soundEffectsActive
    soundToggleBtn.BackgroundColor3 = API.soundEffectsActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
    soundToggleBtn.TextColor3 = API.soundEffectsActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
    soundToggleBtn.Text = API.soundEffectsActive and "🔊 Звуковые эффекты: ВКЛ" or "🔊 Звуковые эффекты: ВЫКЛ"
    API.playSfx(API.clickSfx)
    if API.saveConfig then API.saveConfig() end
end)

customSoundsBtn.MouseButton1Click:Connect(function()
    API.customSoundsActive = not API.customSoundsActive
    customSoundsBtn.BackgroundColor3 = API.customSoundsActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
    customSoundsBtn.TextColor3 = API.customSoundsActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
    customSoundsBtn.Text = API.customSoundsActive and "🐾 Кастомные звуки (Шаги): ВКЛ" or "🐾 Кастомные звуки (Шаги): ВЫКЛ"
    if API.customSoundsActive then API.playStepSound() end
    if player.Character then API.applyFootstepSounds(player.Character) end
    if API.saveConfig then API.saveConfig() end
end)

spaceBgBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.spaceBgActive = not API.spaceBgActive
    if API.UI.spaceBg then API.UI.spaceBg.Visible = API.spaceBgActive end
    spaceBgBtn.BackgroundColor3 = API.spaceBgActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
    spaceBgBtn.TextColor3 = API.spaceBgActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
    spaceBgBtn.Text = API.spaceBgActive and "🌌 Космо-фон: ВКЛ" or "🌌 Космо-фон: ВЫКЛ"
    if API.saveConfig then API.saveConfig() end
end)

batterySaverBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.toggleBlackScreen(not API.isBlackScreen)
    batterySaverBtn.BackgroundColor3 = API.isBlackScreen and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
    batterySaverBtn.TextColor3 = API.isBlackScreen and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
    batterySaverBtn.Text = API.isBlackScreen and "🔋 Ночной режим (Экран): ВКЛ" or "🔋 Ночной режим (Экран): ВЫКЛ"
end)

antiLagBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.antiLagActive = not API.antiLagActive
    antiLagBtn.BackgroundColor3 = API.antiLagActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
    antiLagBtn.TextColor3 = API.antiLagActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
    antiLagBtn.Text = API.antiLagActive and "⚡ Анти-лаг очистка: ВКЛ" or "⚡ Анти-лаг очистка: ВЫКЛ"
    if API.antiLagActive then API.applyAntiLag(true) end
    if API.saveConfig then API.saveConfig() end
end)

antiHazardBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.toggleAntiHazard(not API.antiHazardActive)
    antiHazardBtn.BackgroundColor3 = API.antiHazardActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
    antiHazardBtn.TextColor3 = API.antiHazardActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
    antiHazardBtn.Text = API.antiHazardActive and "🛡 Анти-урон / Вода: ВКЛ" or "🛡 Анти-урон / Вода: ВЫКЛ"
    if API.saveConfig then API.saveConfig() end
end)

antiDarkBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.antiDarknessActive = not API.antiDarknessActive
    antiDarkBtn.BackgroundColor3 = API.antiDarknessActive and Color3.fromRGB(138, 43, 226) or Color3.fromRGB(35, 28, 45)
    antiDarkBtn.TextColor3 = API.antiDarknessActive and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(175, 160, 205)
    antiDarkBtn.Text = API.antiDarknessActive and "Анти-темнота: ВКЛ" or "Анти-темнота: ВЫКЛ"
    if not API.antiDarknessActive then API.disableClearVision() else API.enableClearVision() end
    if API.saveConfig then API.saveConfig() end
end)

saveBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    if API.saveConfig then API.saveConfig() end
    saveBtn.Text = "✔ НАСТРОЙКИ СОХРАНЕНЫ!"
    saveBtn.BackgroundColor3 = Color3.fromRGB(35, 90, 50)
    saveBtn.TextColor3 = Color3.fromRGB(120, 255, 150)
    task.delay(1.5, function()
        if saveBtn and saveBtn.Parent then
            saveBtn.Text = "💾 СОХРАНИТЬ НАСТРОЙКИ"
            saveBtn.BackgroundColor3 = Color3.fromRGB(45, 35, 65)
            saveBtn.TextColor3 = Color3.fromRGB(215, 195, 255)
        end
    end)
end)

toggleButton.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    if not API.farming then API.startFarming() else API.stopFarming() end
end)

tgTokenInputBox.FocusLost:Connect(function()
    API.tgToken = tgTokenInputBox.Text
    if API.saveConfig then API.saveConfig() end
end)

tgChatIdInputBox.FocusLost:Connect(function()
    API.tgChatId = tgChatIdInputBox.Text
    if API.saveConfig then API.saveConfig() end
end)

cartOpenBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    if API.openCart then
        API.openCart()
    else
        task.spawn(function()
            local url = API.CART_URL or "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Auto-Farm-BABFT-Cart.lua"
            local ok, err = pcall(function()
                loadstring(game:HttpGet(url .. "?t=" .. tostring(os.time())))()
            end)
            if ok and API.openCart then API.openCart() end
        end)
    end
end)

questOpenBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    if API.openQuests then
        API.openQuests()
    else
        task.spawn(function()
            local url = API.QUEST_URL or "https://raw.githubusercontent.com/Probothotspot/Slap-battles-Teleport/main/Auto-Farm-BABFT-Quest.lua"
            local ok, err = pcall(function()
                loadstring(game:HttpGet(url .. "?t=" .. tostring(os.time())))()
            end)
            if ok and API.openQuests then API.openQuests() end
        end)
    end
end)

print("[BABFT-GUI] Интерфейс готов!")

if API.loadConfig then API.loadConfig() end
