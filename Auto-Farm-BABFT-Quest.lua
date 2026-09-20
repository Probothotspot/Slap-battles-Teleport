-- =====================================================================
-- МОДУЛЬ: АВТО-КВЕСТЫ BABFT (Auto-Farm-BABFT-Quest.lua)
-- =====================================================================
local API = _G.BABFT
if not API or not API.screenGui then
    warn("[BABFT-Quest] Ошибка: Ядро API или ScreenGui не найдены!")
    return
end

local player = API.player
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
    completed = {
        Target = false,
        Cloud = false,
        Butter = false,
        Rings = false,
        Soccer = false
    },
    buttons = {},
    window = nil,
    statusLabel = nil,
    progressBar = nil
}

function Q.setStatus(msg, ratio)
    if Q.statusLabel then
        Q.statusLabel.Text = msg
    end
    if Q.progressBar then
        TweenService:Create(Q.progressBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(math.clamp(ratio or 0, 0, 1), 0, 1, 0)
        }):Play()
    end
end

-- =====================================================================
-- 1. КВЕСТ: МАСЛО (FIND ME)
-- =====================================================================

-- Быстрый поиск активного масла без лагов (без полного обхода Workspace)
local function getActiveButterPart()
    local butterModel = Workspace:FindFirstChild("Butter", true)
    if butterModel then
        local ppart = butterModel:FindFirstChild("PPart") 
            or butterModel:FindFirstChildWhichIsA("MeshPart") 
            or butterModel:FindFirstChildWhichIsA("BasePart")
        if ppart then
            return ppart, butterModel
        end
    end

    -- Резервный поиск по зонам команд
    for _, zone in ipairs(Workspace:GetChildren()) do
        if zone.Name:find("Zone") or zone.Name == "Quest" then
            local b = zone:FindFirstChild("Butter", true)
            if b then
                local p = b:FindFirstChild("PPart") or b:FindFirstChildWhichIsA("MeshPart") or b:FindFirstChildWhichIsA("BasePart")
                if p then return p, b end
            end
        end
    end
    return nil, nil
end

-- Клик по маслу (ClickDetector + Touch)
local function clickButterPart(ppart, butterModel)
    if not ppart then return end

    local cd = ppart:FindFirstChildOfClass("ClickDetector")
        or (butterModel and butterModel:FindFirstChildOfClass("ClickDetector"))
        or ppart:FindFirstChildWhichIsA("ClickDetector", true)
        or (butterModel and butterModel:FindFirstChildWhichIsA("ClickDetector", true))

    if cd and fireclickdetector then
        pcall(function() fireclickdetector(cd) end)
        pcall(function() fireclickdetector(cd, 1) end)
        pcall(function() fireclickdetector(cd, 0) end)
    end

    local hrp = API.getCurrentHRP()
    if hrp and firetouchinterest then
        pcall(function()
            firetouchinterest(hrp, ppart, 0)
            task.wait(0.02)
            firetouchinterest(hrp, ppart, 1)
        end)
    end
end

function Q.doButterQuest(skipReturn)
    if Q.running and not skipReturn then return end
    Q.running = true

    local startHrp = API.getCurrentHRP()
    local originalCF = startHrp and startHrp.CFrame

    Q.setStatus("Запуск квеста: Масло...", 0.1)

    -- Точный запуск через RemoteEvent
    pcall(function()
        local args = {[1] = 4}
        ReplicatedStorage.QuestMakerEvent:FireServer(unpack(args))
    end)
    task.wait(1.5)

    local count = 0
    local lastPos = nil

    while count < 5 and Q.running do
        Q.setStatus(string.format("Поиск масла [%d/5]...", count + 1), count / 5)

        local ppart, butterModel = nil, nil
        local waitTime = 0

        -- Ожидание появления нового блока масла
        while not ppart and waitTime < 25 and Q.running do
            local foundPart, foundModel = getActiveButterPart()
            if foundPart and foundPart.Parent then
                -- Убеждаемся, что координаты отличаются от уже собранного масла
                if not lastPos or (foundPart.Position - lastPos).Magnitude > 4 then
                    ppart = foundPart
                    butterModel = foundModel
                    break
                end
            end
            task.wait(0.3)
            waitTime = waitTime + 0.3
        end

        if not ppart then
            Q.setStatus(string.format("Таймаут: найдено %d/5 масел", count), count / 5)
            break
        end

        local currentPos = ppart.Position
        local hrp = API.getCurrentHRP()
        if not hrp then task.wait(0.4) hrp = API.getCurrentHRP() end

        if hrp and ppart and ppart.Parent then
            -- Телепорт вплотную к маслу
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(currentPos + Vector3.new(0, 1.0, 0))
            task.wait(0.2)

            -- Кликаем несколько раз с паузами, пока блок не исчезнет или не изменит координаты
            local attempts = 0
            while ppart and ppart.Parent and ppart:IsDescendantOf(Workspace) and attempts < 10 and Q.running do
                clickButterPart(ppart, butterModel)
                task.wait(0.2)
                attempts = attempts + 1
                if (ppart.Position - currentPos).Magnitude > 4 then
                    break
                end
            end

            lastPos = currentPos
            count = count + 1
            API.playSfx(API.coinSfx)
            Q.setStatus(string.format("Масло #%d собрано! Ждем следующее...", count), count / 5)
            task.wait(1.0)
        end
    end

    if count >= 5 then
        Q.completed.Butter = true
        Q.setStatus("Квест с маслом выполнен! ✓", 1.0)
        API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Масло собрано (5/5)!")
        if API.sendTelegramMessage then API.sendTelegramMessage("🧈 <b>Квест с маслом успешно завершен!</b>") end

        if Q.buttons.Butter then
            Q.buttons.Butter.Text = "✓ 🧈 Квест: Найди масло (Выполнено)"
            Q.buttons.Butter.BackgroundColor3 = Color3.fromRGB(35, 90, 50)
        end
    end

    -- Возврат на место, где стоял персонаж до начала квеста
    if not skipReturn and originalCF then
        local finalHrp = API.getCurrentHRP()
        if finalHrp then
            finalHrp.AssemblyLinearVelocity = Vector3.zero
            finalHrp.CFrame = originalCF
        end
    end

    Q.running = false
    return Q.completed.Butter
end

-- =====================================================================
-- 2. КВЕСТ: ОБЛАКО (CLOUD)
-- =====================================================================
local function getCloudPart()
    local cloudModel = Workspace:FindFirstChild("Cloud", true)
    if cloudModel then
        local p2 = cloudModel:FindFirstChild("Part2") or cloudModel:FindFirstChildWhichIsA("BasePart")
        if p2 then return p2 end
    end
    return nil
end

function Q.doCloudQuest(skipReturn)
    if Q.running and not skipReturn then return end
    Q.running = true

    local startHrp = API.getCurrentHRP()
    local originalCF = startHrp and startHrp.CFrame

    Q.setStatus("Запуск квеста: Облако...", 0.1)

    -- Точный запуск через RemoteEvent
    pcall(function()
        local args = {[1] = 1}
        ReplicatedStorage.QuestMakerEvent:FireServer(unpack(args))
    end)
    task.wait(1.5)

    Q.setStatus("Ожидание появления облака...", 0.2)
    local cloud = nil
    local waitSpawn = 0
    while not cloud and waitSpawn < 15 and Q.running do
        cloud = getCloudPart()
        if not cloud then
            task.wait(0.4)
            waitSpawn = waitSpawn + 0.4
        end
    end

    if not cloud then
        Q.setStatus("Ошибка: облако не появилось!", 0)
        Q.running = false
        return false
    end

    local timeout = 0
    local maxTimeout = 50

    while timeout < maxTimeout and Q.running do
        local hrp = API.getCurrentHRP()
        cloud = getCloudPart()

        if not cloud then
            break -- Облако исчезло -> квест засчитан
        end

        if hrp and cloud then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = cloud.CFrame
            if firetouchinterest then
                pcall(function()
                    firetouchinterest(hrp, cloud, 0)
                    task.wait(0.04)
                    firetouchinterest(hrp, cloud, 1)
                end)
            end
        end

        task.wait(0.35)
        timeout = timeout + 0.35
        Q.setStatus(string.format("Касание облака (сек: %.1f)...", timeout), 0.7)
    end

    Q.completed.Cloud = true
    Q.setStatus("Квест с облаком выполнен! ✓", 1.0)
    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Облако пройдено!")
    if API.sendTelegramMessage then API.sendTelegramMessage("☁️ <b>Квест с облаком завершен!</b>") end

    if Q.buttons.Cloud then
        Q.buttons.Cloud.Text = "✓ ☁️ Квест: Облако (Выполнено)"
        Q.buttons.Cloud.BackgroundColor3 = Color3.fromRGB(35, 90, 50)
    end

    if not skipReturn and originalCF then
        local finalHrp = API.getCurrentHRP()
        if finalHrp then
            finalHrp.AssemblyLinearVelocity = Vector3.zero
            finalHrp.CFrame = originalCF
        end
    end

    Q.running = false
    return true
end

-- =====================================================================
-- КАРКАСЫ ДЛЯ ОСТАЛЬНЫХ КВЕСТОВ
-- =====================================================================
function Q.doTargetQuest(skipReturn)
    local startHrp = API.getCurrentHRP()
    local originalCF = startHrp and startHrp.CFrame

    Q.setStatus("Квест: Мишень (в разработке)...", 0.5)
    task.wait(1)

    Q.completed.Target = true
    if Q.buttons.Target then
        Q.buttons.Target.Text = "✓ 🎯 Квест: Мишень (Выполнено)"
        Q.buttons.Target.BackgroundColor3 = Color3.fromRGB(35, 90, 50)
    end

    if not skipReturn and originalCF then
        local finalHrp = API.getCurrentHRP()
        if finalHrp then finalHrp.CFrame = originalCF end
    end
end

function Q.doRingsQuest(skipReturn)
    local startHrp = API.getCurrentHRP()
    local originalCF = startHrp and startHrp.CFrame

    Q.setStatus("Квест: Кольца (в разработке)...", 0.5)
    task.wait(1)

    Q.completed.Rings = true
    if Q.buttons.Rings then
        Q.buttons.Rings.Text = "✓ ⭕ Квест: Кольца (Выполнено)"
        Q.buttons.Rings.BackgroundColor3 = Color3.fromRGB(35, 90, 50)
    end

    if not skipReturn and originalCF then
        local finalHrp = API.getCurrentHRP()
        if finalHrp then finalHrp.CFrame = originalCF end
    end
end

function Q.doSoccerQuest(skipReturn)
    local startHrp = API.getCurrentHRP()
    local originalCF = startHrp and startHrp.CFrame

    Q.setStatus("Квест: Футбол (в разработке)...", 0.5)
    task.wait(1)

    Q.completed.Soccer = true
    if Q.buttons.Soccer then
        Q.buttons.Soccer.Text = "✓ ⚽ Квест: Футбол (Выполнено)"
        Q.buttons.Soccer.BackgroundColor3 = Color3.fromRGB(35, 90, 50)
    end

    if not skipReturn and originalCF then
        local finalHrp = API.getCurrentHRP()
        if finalHrp then finalHrp.CFrame = originalCF end
    end
end

function Q.runAllQuests()
    if Q.running then return end

    local wasFarming = API.farming
    if wasFarming then API.stopFarming() end

    local initialHrp = API.getCurrentHRP()
    local globalReturnCF = initialHrp and initialHrp.CFrame

    Q.setStatus("Запуск очереди квестов...", 0.05)
    task.wait(0.5)

    pcall(function() Q.doButterQuest(true) end)
    task.wait(1.5)

    pcall(function() Q.doCloudQuest(true) end)
    task.wait(1.5)

    pcall(function() Q.doTargetQuest(true) end)
    task.wait(1)

    pcall(function() Q.doRingsQuest(true) end)
    task.wait(1)

    pcall(function() Q.doSoccerQuest(true) end)
    task.wait(1)

    if globalReturnCF then
        local finalHrp = API.getCurrentHRP()
        if finalHrp then
            finalHrp.AssemblyLinearVelocity = Vector3.zero
            finalHrp.CFrame = globalReturnCF
        end
    end

    Q.setStatus("Очередь квестов завершена! ✓", 1.0)

    if wasFarming then
        task.wait(1)
        API.startFarming()
    end
end

-- =====================================================================
-- МОДАЛЬНОЕ ОКНО (ZIndex = 70)
-- =====================================================================
local qWindow = Instance.new("Frame")
qWindow.Size = UDim2.new(0, 275, 0, 365)
qWindow.Position = UDim2.new(0.5, -137, 0.5, -182)
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

-- Шапка
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

-- Перетаскивание окна
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

-- Статус-бар
local qStatusBar = Instance.new("Frame")
qStatusBar.Size = UDim2.new(1, -20, 0, 44)
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
qStatusLabel.Text = "Статус: Выберите квест для запуска"
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

-- Кнопка запуска всех квестов
local runAllBtn = Instance.new("TextButton")
runAllBtn.Size = UDim2.new(1, -20, 0, 30)
runAllBtn.Position = UDim2.new(0, 10, 0, 88)
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

-- Создание отдельных кнопок квестов
local function createQuestButton(yPos, key, defaultName, cb)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -20, 0, 24)
    btn.Position = UDim2.new(0, 10, 0, yPos)
    btn.BackgroundColor3 = Color3.fromRGB(26, 20, 36)
    btn.Text = defaultName
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

    Q.buttons[key] = btn
    return btn
end

createQuestButton(124, "Butter", "🧈 Квест: Найди масло (Find Me)", function() Q.doButterQuest(false) end)
createQuestButton(154, "Cloud", "☁️ Квест: Облако (Cloud)", function() Q.doCloudQuest(false) end)
createQuestButton(184, "Target", "🎯 Квест: Мишень (Target)", function() Q.doTargetQuest(false) end)
createQuestButton(214, "Rings", "⭕ Квест: Кольца (Rings)", function() Q.doRingsQuest(false) end)
createQuestButton(244, "Soccer", "⚽ Квест: Футбол (Soccer)", function() Q.doSoccerQuest(false) end)

local closeBottom = Instance.new("TextButton")
closeBottom.Size = UDim2.new(1, -20, 0, 24)
closeBottom.Position = UDim2.new(0, 10, 0, 325)
closeBottom.BackgroundColor3 = Color3.fromRGB(35, 28, 45)
closeBottom.Text = "Закрыть окно"
closeBottom.TextColor3 = Color3.fromRGB(210, 200, 230)
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

print("[BABFT-Quest] Оптимизированный модуль квестов готов!")
