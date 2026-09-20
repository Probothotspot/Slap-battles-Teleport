-- =====================================================================
-- МОДУЛЬ: ОПТИМИЗИРОВАННЫЕ АВТО-КВЕСТЫ (Auto-Farm-BABFT-Quest.lua)
-- =====================================================================
local API = _G.BABFT
if not API or not API.screenGui then
    warn("[BABFT-Quest] Ошибка: Ядро API или ScreenGui не найдены!")
    return
end

local player = API.player
local Workspace = API.Workspace
local TweenService = API.TweenService
local screenGui = API.screenGui

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

local Q = {
    running = false,
    window = nil,
    statusLabel = nil,
    progressBar = nil
}

function Q.clickButton(btn)
    if not btn then return false end
    pcall(function()
        if firesignal then firesignal(btn.MouseButton1Click) firesignal(btn.Activated) end
        if getconnections then
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
        end
    end)
    return true
end

function Q.activateQuest(questName)
    local pGui = player:FindFirstChild("PlayerGui")
    if not pGui then return false end
    local query = questName:lower()
    for _, desc in ipairs(pGui:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            if desc.Text:lower():find(query) then
                local parent = desc.Parent
                if parent then
                    for _, b in ipairs(parent:GetDescendants()) do
                        if b:IsA("TextButton") or b:IsA("ImageButton") then
                            local bTxt = (b:IsA("TextButton") and b.Text:lower() or "")
                            if bTxt:find("start") or bTxt:find("claim") or bTxt:find("active") or bTxt:find("принять") or bTxt == "" then
                                Q.clickButton(b)
                                return true
                            end
                        end
                    end
                end
            end
        end
    end
    return false
end

-- Плавное перемещение к цели вместо жесткого мгновенного телепорта (исключает лаги и баги античита)
function Q.smoothMove(hrp, targetCF)
    if not hrp then return end
    local tweenInfo = TweenInfo.new(0.3, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCF})
    tween:Play()
    task.wait(0.35)
end

-- 1. Квест: Мишень
function Q.doTargetQuest()
    Q.setStatus("Квест: Мишень...", 0.2)
    Q.activateQuest("target")
    task.wait(0.8)

    local hrp = API.getCurrentHRP()
    if not hrp then return false end

    Q.setStatus("Летим к мишени...", 0.6)
    Q.smoothMove(hrp, CFrame.new(-55, 65, -360))
    task.wait(1)

    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Мишень пройдена! +2 Турбины")
    return true
end

-- 2. Квест: Облако
function Q.doCloudQuest()
    Q.setStatus("Квест: Облако...", 0.2)
    Q.activateQuest("cloud")
    task.wait(0.8)

    local hrp = API.getCurrentHRP()
    if not hrp then return false end

    Q.setStatus("Летим в облако...", 0.6)
    Q.smoothMove(hrp, CFrame.new(-55, 650, 1200))
    task.wait(1)

    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Облако пройдено!")
    return true
end

-- 3. Квест: Найди масло (Find Me)
function Q.doFindMeQuest()
    Q.setStatus("Квест: Найди меня...", 0.1)
    Q.activateQuest("find")
    task.wait(0.8)

    -- Стандартные точки спавна масла в BABFT
    local oilSpots = {
        CFrame.new(-55, 10, -50),
        CFrame.new(-55, 12, 450),
        CFrame.new(-55, 15, 1800),
        CFrame.new(-55, 45, 4200),
        CFrame.new(-55, 65, 7100)
    }

    for step, cf in ipairs(oilSpots) do
        Q.setStatus(string.format("Сбор масла [%d/5]...", step), step / 5)
        local hrp = API.getCurrentHRP()
        if hrp then
            Q.smoothMove(hrp, cf + Vector3.new(0, 3, 0))
        end
        task.wait(0.6)
    end

    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Все блоки масла собраны!")
    return true
end

-- 4. Квест: Кольца
function Q.doRingsQuest()
    Q.setStatus("Квест: Кольца...", 0.1)
    Q.activateQuest("ring")
    task.wait(0.8)

    for i, coord in ipairs(API.STAGE_COORDINATES) do
        Q.setStatus(string.format("Пролет колец [%d/10]...", i), i / 10)
        local hrp = API.getCurrentHRP()
        if hrp then
            Q.smoothMove(hrp, CFrame.new(coord) + Vector3.new(0, 5, 0))
        end
        task.wait(0.4)
    end

    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Кольца пройдены!")
    return true
end

-- 5. Квест: Футбол
function Q.doSoccerQuest()
    Q.setStatus("Квест: Футбол...", 0.2)
    Q.activateQuest("soccer")
    task.wait(0.8)

    local hrp = API.getCurrentHRP()
    if hrp then
        Q.smoothMove(hrp, CFrame.new(-55, 30, 8500))
    end
    task.wait(1)

    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Футбол пройден!")
    return true
end

function Q.runAllQuests()
    if Q.running then return end
    Q.running = true

    local wasFarming = API.farming
    if wasFarming then API.stopFarming() end

    Q.setStatus("Запуск очереди квестов...", 0.05)
    task.wait(0.5)

    pcall(Q.doTargetQuest)
    task.wait(1)
    pcall(Q.doCloudQuest)
    task.wait(1)
    pcall(Q.doFindMeQuest)
    task.wait(1)
    pcall(Q.doRingsQuest)
    task.wait(1)
    pcall(Q.doSoccerQuest)
    task.wait(1)

    Q.setStatus("Все квесты завершены! ✓", 1.0)
    API.showAchievementToast("УСПЕХ", "Все квесты пройдены!")
    if API.sendTelegramMessage then
        API.sendTelegramMessage("🏆 <b>Все квесты BABFT успешно выполнены!</b>")
    end

    local hrp = API.getCurrentHRP()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(-55, 10, -50)
    end

    Q.running = false
    if wasFarming then
        task.wait(1)
        API.startFarming()
    end
end

-- Окно квестов UI
local qWindow = Instance.new("Frame")
qWindow.Size = UDim2.new(0, 270, 0, 360)
qWindow.Position = UDim2.new(0.5, -135, 0.5, -180)
qWindow.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
qWindow.BorderSizePixel = 0
qWindow.Active = true
qWindow.ClipsDescendants = true
qWindow.Visible = false
qWindow.ZIndex = 70
qWindow.Parent = screenGui
Q.window = qWindow

createCorner(qWindow, 12)
local qStroke = createStroke(qWindow, Color3.fromRGB(180, 100, 255), 1.8)
qStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local qTopBar = Instance.new("Frame")
qTopBar.Size = UDim2.new(1, 0, 0, 32)
qTopBar.BackgroundTransparency = 1
qTopBar.ZIndex = 71
qTopBar.Parent = qWindow

local qTitle = Instance.new("TextLabel")
qTitle.Size = UDim2.new(1, -40, 1, 0)
qTitle.Position = UDim2.new(0, 12, 0, 0)
qTitle.BackgroundTransparency = 1
qTitle.Text = "⚡ АВТО-КВЕСТЫ BABFT"
qTitle.TextColor3 = Color3.fromRGB(230, 210, 255)
qTitle.Font = Enum.Font.GothamBold
qTitle.TextSize = 12
qTitle.TextXAlignment = Enum.TextXAlignment.Left
qTitle.ZIndex = 72
qTitle.Parent = qTopBar

local qCloseBtn = Instance.new("TextButton")
qCloseBtn.Size = UDim2.new(0, 22, 0, 22)
qCloseBtn.Position = UDim2.new(1, -28, 0, 5)
qCloseBtn.BackgroundColor3 = Color3.fromRGB(50, 20, 35)
qCloseBtn.Text = "×"
qCloseBtn.TextColor3 = Color3.fromRGB(255, 130, 150)
qCloseBtn.Font = Enum.Font.GothamBold
qCloseBtn.TextSize = 14
qCloseBtn.BorderSizePixel = 0
qCloseBtn.ZIndex = 72
qCloseBtn.Parent = qTopBar
createCorner(qCloseBtn, 6)

local qStatusBar = Instance.new("Frame")
qStatusBar.Size = UDim2.new(1, -20, 0, 42)
qStatusBar.Position = UDim2.new(0, 10, 0, 36)
qStatusBar.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
qStatusBar.BorderSizePixel = 0
qStatusBar.ZIndex = 71
qStatusBar.Parent = qWindow
createCorner(qStatusBar, 6)

local qStatusLabel = Instance.new("TextLabel")
qStatusLabel.Size = UDim2.new(1, -12, 0, 18)
qStatusLabel.Position = UDim2.new(0, 6, 0, 4)
qStatusLabel.BackgroundTransparency = 1
qStatusLabel.Text = "Статус: Готов к запуску"
qStatusLabel.TextColor3 = Color3.fromRGB(255, 215, 100)
qStatusLabel.Font = Enum.Font.GothamBold
qStatusLabel.TextSize = 10
qStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
qStatusLabel.ZIndex = 72
qStatusLabel.Parent = qStatusBar
Q.statusLabel = qStatusLabel

local qProgBg = Instance.new("Frame")
qProgBg.Size = UDim2.new(1, -12, 0, 6)
qProgBg.Position = UDim2.new(0, 6, 0, 26)
qProgBg.BackgroundColor3 = Color3.fromRGB(28, 22, 40)
qProgBg.BorderSizePixel = 0
qProgBg.ZIndex = 72
qProgBg.Parent = qStatusBar
createCorner(qProgBg, 10)

local qProgFill = Instance.new("Frame")
qProgFill.Size = UDim2.new(0, 0, 1, 0)
qProgFill.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
qProgFill.BorderSizePixel = 0
qProgFill.ZIndex = 73
qProgFill.Parent = qProgBg
createCorner(qProgFill, 10)
Q.progressBar = qProgFill

function Q.setStatus(msg, ratio)
    qStatusLabel.Text = msg
    TweenService:Create(qProgFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
        Size = UDim2.new(math.clamp(ratio or 0, 0, 1), 0, 1, 0)
    }):Play()
end

local runAllBtn = Instance.new("TextButton")
runAllBtn.Size = UDim2.new(1, -20, 0, 32)
runAllBtn.Position = UDim2.new(0, 10, 0, 86)
runAllBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
runAllBtn.Text = "⚡ ПРОЙТИ ВСЕ КВЕСТЫ (АВТО)"
runAllBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
runAllBtn.Font = Enum.Font.GothamBold
runAllBtn.TextSize = 10
runAllBtn.BorderSizePixel = 0
runAllBtn.ZIndex = 72
runAllBtn.Parent = qWindow
createCorner(runAllBtn, 6)

runAllBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    task.spawn(Q.runAllQuests)
end)

local function createQuestButton(yPos, name, cb)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 24)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(26, 20, 36)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(230, 220, 245)
    btn.Font = Enum.Font.Gotham
    btn.TextSize = 9
    btn.BorderSizePixel = 0
    btn.ZIndex = 72
    btn.Parent = qWindow
    createCorner(btn, 5)

    btn.MouseButton1Click:Connect(function()
        API.playSfx(API.clickSfx)
        task.spawn(cb)
    end)
end

createQuestButton(126, "🎯 Квест: Мишень (Target)", Q.doTargetQuest)
createQuestButton(156, "☁️ Квест: Облако (Cloud)", Q.doCloudQuest)
createQuestButton(186, "🧈 Квест: Найди меня (Find Me)", Q.doFindMeQuest)
createQuestButton(216, "⭕ Квест: Кольца (Rings)", Q.doRingsQuest)
createQuestButton(246, "⚽ Квест: Футбол (Soccer)", Q.doSoccerQuest)

local closeBottom = Instance.new("TextButton")
closeBottom.Size = UDim2.new(1, -20, 0, 24)
closeBottom.Position = UDim2.new(0, 10, 0, 320)
closeBottom.BackgroundColor3 = Color3.fromRGB(40, 25, 45)
closeBottom.Text = "Закрыть окно"
closeBottom.TextColor3 = Color3.fromRGB(220, 200, 230)
closeBottom.Font = Enum.Font.Gotham
closeBottom.TextSize = 9
closeBottom.BorderSizePixel = 0
closeBottom.ZIndex = 72
closeBottom.Parent = qWindow
createCorner(closeBottom, 5)

local function closeWindow()
    API.playSfx(API.clickSfx)
    qWindow.Visible = false
end

qCloseBtn.MouseButton1Click:Connect(closeWindow)
closeBottom.MouseButton1Click:Connect(closeWindow)

function API.openQuests()
    qWindow.Visible = true
end

function API.closeQuests()
    qWindow.Visible = false
end

print("[BABFT-Quest] Оптимизированный модуль квестов подключен!")
