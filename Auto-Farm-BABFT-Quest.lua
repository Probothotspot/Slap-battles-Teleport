-- =====================================================================
-- МОДУЛЬ: АВТО-КВЕСТЫ BABFT (Auto-Farm-BABFT-Quest.lua)
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

-- Единая таблица модуля для экономии локальных регистров
local Q = {
    running = false,
    window = nil,
    statusLabel = nil,
    progressBar = nil
}

-- Безопасный клик по кнопкам в PlayerGui
function Q.clickButton(btn)
    if not btn then return false end
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
        end
    end)
    pcall(function()
        if getconnections then
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
        end
    end)
    return true
end

-- Активация квеста в интерфейсе игры
function Q.activateQuest(questName)
    local pGui = player:FindFirstChild("PlayerGui")
    if not pGui then return false end

    local query = questName:lower()
    for _, desc in ipairs(pGui:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local txt = desc.Text:lower()
            if txt:find(query) then
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

-- Касание предмета
function Q.touch(hrp, targetPart)
    if not hrp or not targetPart then return end
    hrp.AssemblyLinearVelocity = Vector3.zero
    hrp.CFrame = targetPart.CFrame + Vector3.new(0, 1.5, 0)
    pcall(function()
        if firetouchinterest then
            firetouchinterest(hrp, targetPart, 0)
            task.wait()
            firetouchinterest(hrp, targetPart, 1)
        end
    end)
end

-- 1. Прохождение квеста "Мишень" (Target)
function Q.doTargetQuest()
    Q.setStatus("Запуск квеста: Мишень...", 0.2)
    Q.activateQuest("target")
    task.wait(1)

    local hrp = API.getCurrentHRP()
    if not hrp then return false end

    local targetModel = Workspace:FindFirstChild("Target", true) or Workspace:FindFirstChild("TargetQuest", true)
    local targetPart = nil

    if targetModel then
        targetPart = targetModel:FindFirstChild("TargetMiddle") or targetModel:FindFirstChild("Middle") or targetModel:FindFirstChild("Center") or targetModel:FindFirstChildOfClass("BasePart")
    end

    if not targetPart then
        -- Координаты мишени на горе
        targetPart = {CFrame = CFrame.new(-55, 65, -360)}
    end

    Q.setStatus("Касание центра мишени...", 0.7)
    for i = 1, 5 do
        hrp = API.getCurrentHRP()
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = targetPart.CFrame
            if typeof(targetPart) ~= "table" then Q.touch(hrp, targetPart) end
        end
        task.wait(0.25)
    end

    task.wait(1)
    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Мишень пройдена! +2 Турбины")
    return true
end

-- 2. Прохождение квеста "Облако" (Cloud)
function Q.doCloudQuest()
    Q.setStatus("Запуск квеста: Облако...", 0.2)
    Q.activateQuest("cloud")
    task.wait(1)

    local hrp = API.getCurrentHRP()
    if not hrp then return false end

    local cloudPart = nil
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and v.Name:lower():find("cloud") and v.Position.Y > 300 then
            cloudPart = v
            break
        end
    end

    Q.setStatus("Полёт сквозь облако...", 0.7)
    local targetCF = cloudPart and cloudPart.CFrame or CFrame.new(-55, 650, 1200)

    for i = 1, 6 do
        hrp = API.getCurrentHRP()
        if hrp then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = targetCF
            if cloudPart then Q.touch(hrp, cloudPart) end
        end
        task.wait(0.25)
    end

    task.wait(1)
    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Облако пройдено! +Золото")
    return true
end

-- 3. Прохождение квеста "Найди меня" (Find Me / Butter)
function Q.doFindMeQuest()
    Q.setStatus("Запуск квеста: Найди меня...", 0.1)
    Q.activateQuest("find")
    task.wait(1)

    for step = 1, 5 do
        Q.setStatus(string.format("Поиск масла [%d/5]...", step), 0.2 + (step * 0.15))
        local foundBlock = nil

        local timeout = 0
        while not foundBlock and timeout < 8 do
            for _, v in ipairs(Workspace:GetDescendants()) do
                if v:IsA("BasePart") then
                    local n = v.Name:lower()
                    if n:find("butter") or n:find("findme") or n:find("block") and v.Parent and v.Parent.Name:lower():find("find") then
                        foundBlock = v
                        break
                    end
                end
            end
            if not foundBlock then
                task.wait(0.3)
                timeout = timeout + 0.3
            end
        end

        local hrp = API.getCurrentHRP()
        if hrp and foundBlock then
            for i = 1, 4 do
                Q.touch(hrp, foundBlock)
                task.wait(0.2)
            end
        end
        task.wait(0.8)
    end

    task.wait(1)
    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Все 5 блоков масла собраны!")
    return true
end

-- 4. Прохождение квеста "Кольца" (Rings)
function Q.doRingsQuest()
    Q.setStatus("Запуск квеста: Кольца...", 0.1)
    Q.activateQuest("ring")
    task.wait(1)

    local rings = {}
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name:lower():find("ring") or (v.Parent and v.Parent.Name:lower():find("ring"))) then
            table.insert(rings, v)
        end
    end

    table.sort(rings, function(a, b) return a.Position.Z < b.Position.Z end)

    local total = #rings
    if total == 0 then
        -- Резервный пролёт по этапам
        for i, coord in ipairs(API.STAGE_COORDINATES) do
            local hrp = API.getCurrentHRP()
            if hrp then
                hrp.AssemblyLinearVelocity = Vector3.zero
                hrp.CFrame = CFrame.new(coord)
            end
            task.wait(0.3)
        end
    else
        for i, ring in ipairs(rings) do
            Q.setStatus(string.format("Пролет кольца [%d/%d]...", i, total), i / total)
            local hrp = API.getCurrentHRP()
            if hrp and ring and ring.Parent then
                Q.touch(hrp, ring)
            end
            task.wait(0.35)
        end
    end

    task.wait(1)
    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Все кольца пройдены!")
    return true
end

-- 5. Прохождение квеста "Футбол" (Soccer)
function Q.doSoccerQuest()
    Q.setStatus("Запуск квеста: Футбол...", 0.2)
    Q.activateQuest("soccer")
    task.wait(1)

    local ball = nil
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name:lower():find("soccer") or v.Name:lower():find("ball") or v.Name:lower():find("football")) then
            if v.Size.Magnitude > 3 then
                ball = v
                break
            end
        end
    end

    local goalPart = nil
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("BasePart") and (v.Name:lower():find("goal") or v.Name:lower():find("net")) then
            goalPart = v
            break
        end
    end

    Q.setStatus("Доставка мяча в ворота...", 0.7)
    local goalPos = goalPart and goalPart.Position or Vector3.new(-55, 30, 8500)

    if ball then
        for i = 1, 15 do
            ball.AssemblyLinearVelocity = Vector3.zero
            ball.CFrame = CFrame.new(goalPos)
            task.wait(0.1)
        end
    end

    task.wait(1)
    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Гол забит! Футбол пройден")
    return true
end

-- Выполнение цепочки всех квестов
function Q.runAllQuests()
    if Q.running then return end
    Q.running = true

    local wasFarming = API.farming
    if wasFarming then API.stopFarming() end

    Q.setStatus("Подготовка квестов...", 0.05)
    task.wait(0.5)

    pcall(Q.doTargetQuest)
    task.wait(1.5)

    pcall(Q.doCloudQuest)
    task.wait(1.5)

    pcall(Q.doFindMeQuest)
    task.wait(1.5)

    pcall(Q.doRingsQuest)
    task.wait(1.5)

    pcall(Q.doSoccerQuest)
    task.wait(1)

    Q.setStatus("Все квесты успешно завершены! ✓", 1.0)
    API.showAchievementToast("УСПЕХ", "Все квесты BABFT пройдены!")
    if API.sendTelegramMessage then
        API.sendTelegramMessage("🏆 <b>Все доступные квесты BABFT успешно выполнены!</b> Награды получены.")
    end

    -- Возврат персонажа на спавн
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

-- =====================================================================
-- ГРАФИЧЕСКИЙ ИНТЕРФЕЙС КВЕСТОВ (Модальное окно ZIndex = 70)
-- =====================================================================
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

-- Шапка окна
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

-- Перетаскивание
local qDragging, qDragStart, qStartPos
qTopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        qDragging = true
        qDragStart = input.Position
        qStartPos = qWindow.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then qDragging = false end
        end)
    end
end)

qTopBar.InputChanged:Connect(function(input)
    if qDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - qDragStart
        qWindow.Position = UDim2.new(
            qStartPos.X.Scale,
            qStartPos.X.Offset + delta.X,
            qStartPos.Y.Scale,
            qStartPos.Y.Offset + delta.Y
        )
    end
end)

-- Статус бар
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

-- Главная кнопка "Пройти ВСЕ квесты"
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

-- Индивидуальные кнопки квестов
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

-- Экспорт методов в глобальную таблицу API
function API.openQuests()
    qWindow.Visible = true
end

function API.closeQuests()
    qWindow.Visible = false
end

print("[BABFT-Quest] Модуль авто-квестов успешно подключен!")
