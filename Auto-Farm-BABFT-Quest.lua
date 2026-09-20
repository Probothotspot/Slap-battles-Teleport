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
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

-- Прямой вызов RemoteEvent сервера для активации квеста
function Q.fireQuestRemote(questId)
    pcall(function()
        local qEvent = ReplicatedStorage:FindFirstChild("QuestMakerEvent")
        if qEvent and qEvent:IsA("RemoteEvent") then
            qEvent:FireServer(questId)
        end
    end)
end

-- Резервный клик по кнопке в GUI игры
function Q.clickButton(btn)
    if not btn then return false end
    pcall(function()
        if firesignal then
            firesignal(btn.MouseButton1Click)
            firesignal(btn.Activated)
        end
        if getconnections then
            for _, c in ipairs(getconnections(btn.MouseButton1Click)) do c:Fire() end
            for _, c in ipairs(getconnections(btn.Activated)) do c:Fire() end
        end
    end)
    return true
end

function Q.activateQuestInGui(questName)
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
                                task.wait(0.5)
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
-- 1. КВЕСТ: МАСЛО (FIND ME) - ID 4
-- =====================================================================
local function isButterPart(v)
    if not v:IsA("MeshPart") then return false end
    if v.Name ~= "PPart" then return false end
    if not v.Parent or v.Parent.Name ~= "Butter" then return false end
    local sz = v.Size
    if math.abs(sz.X - 2) > 0.6 or math.abs(sz.Y - 2) > 0.6 or math.abs(sz.Z - 2) > 0.6 then
        return false
    end
    return true
end

local function findUniqueButter(visitedList)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isButterPart(obj) then
            local alreadyClicked = false
            for _, pos in ipairs(visitedList) do
                if (obj.Position - pos).Magnitude < 5 then
                    alreadyClicked = true
                    break
                end
            end
            if not alreadyClicked then return obj end
        end
    end
    return nil
end

local function clickButter(part)
    if not part then return end
    local cd = part:FindFirstChildOfClass("ClickDetector") or (part.Parent and part.Parent:FindFirstChildOfClass("ClickDetector"))
    if not cd then
        for _, ch in ipairs(part:GetChildren()) do
            if ch:IsA("ClickDetector") then cd = ch break end
        end
    end
    if cd and fireclickdetector then pcall(function() fireclickdetector(cd) end) end

    local hrp = API.getCurrentHRP()
    if hrp and firetouchinterest then
        pcall(function()
            firetouchinterest(hrp, part, 0)
            task.wait()
            firetouchinterest(hrp, part, 1)
        end)
    end
end

function Q.doButterQuest(skipReturn)
    local startHrp = API.getCurrentHRP()
    local originalCF = startHrp and startHrp.CFrame

    Q.setStatus("Запуск квеста: Масло (ID 4)...", 0.1)
    Q.fireQuestRemote(4)
    Q.activateQuestInGui("find")
    task.wait(1)

    local visited = {}
    local count = 0

    while count < 5 do
        Q.setStatus(string.format("Поиск масла [%d/5]...", count + 1), count / 5)
        local target = nil
        local timeout = 0
        while not target and timeout < 20 do
            target = findUniqueButter(visited)
            if not target then
                task.wait(0.35)
                timeout = timeout + 0.35
            end
        end

        if not target then break end

        local hrp = API.getCurrentHRP()
        if not hrp then task.wait(0.5) hrp = API.getCurrentHRP() end

        if hrp and target and target.Parent then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(target.Position + Vector3.new(0, 1.2, 0), target.Position)
            task.wait(0.25)
            clickButter(target)
            table.insert(visited, target.Position)
            count = count + 1
            API.playSfx(API.coinSfx)
            task.wait(1.2)
        end
    end

    Q.completed.Butter = true
    Q.setStatus("Квест с маслом выполнен! ✓", 1.0)
    API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Масло собрано (5/5)!")
    if API.sendTelegramMessage then API.sendTelegramMessage("🧈 <b>Квест с маслом завершен!</b>") end

    if Q.buttons.Butter then
        Q.buttons.Butter.Text = "✓ 🧈 Квест: Найди масло (Выполнено)"
        Q.buttons.Butter.BackgroundColor3 = Color3.fromRGB(35, 90, 50)
    end

    if not skipReturn and originalCF then
        local finalHrp = API.getCurrentHRP()
        if finalHrp then
            finalHrp.AssemblyLinearVelocity = Vector3.zero
            finalHrp.CFrame = originalCF
        end
    end

    return true
end

-- =====================================================================
-- 2. КВЕСТ: ОБЛАКО (CLOUD) - ID 1
-- =====================================================================
local function findCloudPart()
    for _, v in ipairs(Workspace:GetDescendants()) do
        if v:IsA("Part") and v.Name == "Part2" and v.Parent and v.Parent.Name == "Cloud" then
            return v
        end
    end
    return nil
end

function Q.doCloudQuest(skipReturn)
    local startHrp = API.getCurrentHRP()
    local originalCF = startHrp and startHrp.CFrame

    Q.setStatus("Запуск квеста: Облако (ID 1)...", 0.1)
    Q.fireQuestRemote(1)
    Q.activateQuestInGui("cloud")
    task.wait(1)

    local timeout = 0
    local maxTimeout = 50

    while timeout < maxTimeout do
        local hrp = API.getCurrentHRP()
        local cloud = findCloudPart()

        if not cloud then
            break -- Облако пропало/собрано -> квест засчитан
        end

        if hrp and cloud then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = cloud.CFrame
            if firetouchinterest then
                pcall(function()
                    firetouchinterest(hrp, cloud, 0)
                    task.wait()
                    firetouchinterest(hrp, cloud, 1)
                end)
            end
        end

        task.wait(0.4)
        timeout = timeout + 0.4
        Q.setStatus(string.format("Поиск облака (сек: %.1f)...", timeout), 0.5)
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

    return true
end

-- =====================================================================
-- КАРКАСЫ ОСТАЛЬНЫХ КВЕСТОВ
-- =====================================================================
function Q.doTargetQuest(skipReturn)
    local startHrp = API.getCurrentHRP()
    local originalCF = startHrp and startHrp.CFrame

    Q.setStatus("Запуск квеста: Мишень...", 0.2)
    Q.activateQuestInGui("target")
    task.wait(1)
    local hrp = API.getCurrentHRP()
    if hrp then
        hrp.AssemblyLinearVelocity = Vector3.zero
        hrp.CFrame = CFrame.new(-55, 65, -360)
        task.wait(1)
    end
    Q.completed.Target = true
    Q.setStatus("Мишень: ожидает доработки", 1.0)
    if Q.buttons.Target then
        Q.buttons.Target.Text = "✓ 🎯 Квест: Мишень (Выполнено)"
        Q.buttons.Target.BackgroundColor3 = Color3.fromRGB(35, 90, 50)
    end

    if not skipReturn and originalCF then
        local finalHrp = API.getCurrentHRP()
        if finalHrp then
            finalHrp.AssemblyLinearVelocity = Vector3.zero
            finalHrp.CFrame = originalCF
        end
    end
end

function Q.doRingsQuest(skipReturn)
    local startHrp = API.getCurrentHRP()
    local originalCF = startHrp and startHrp.CFrame

    Q.setStatus("Запуск квеста: Кольца...", 0.2)
    Q.activateQuestInGui("ring")
    task.wait(1)
    Q.completed.Rings = true
    Q.setStatus("Кольца: ожидает доработки", 1.0)
    if Q.buttons.Rings then
        Q.buttons.Rings.Text = "✓ ⭕ Квест: Кольца (Выполнено)"
        Q.buttons.Rings.BackgroundColor3 = Color3.fromRGB(35, 90, 50)
    end

    if not skipReturn and originalCF then
        local finalHrp = API.getCurrentHRP()
        if finalHrp then
            finalHrp.AssemblyLinearVelocity = Vector3.zero
            finalHrp.CFrame = originalCF
        end
    end
end

function Q.doSoccerQuest(skipReturn)
    local startHrp = API.getCurrentHRP()
    local originalCF = startHrp and startHrp.CFrame

    Q.setStatus("Запуск квеста: Футбол...", 0.2)
    Q.activateQuestInGui("soccer")
    task.wait(1)
    Q.completed.Soccer = true
    Q.setStatus("Футбол: ожидает доработки", 1.0)
    if Q.buttons.Soccer then
        Q.buttons.Soccer.Text = "✓ ⚽ Квест: Футбол (Выполнено)"
        Q.buttons.Soccer.BackgroundColor3 = Color3.fromRGB(35, 90, 50)
    end

    if not skipReturn and originalCF then
        local finalHrp = API.getCurrentHRP()
        if finalHrp then
            finalHrp.AssemblyLinearVelocity = Vector3.zero
            finalHrp.CFrame = originalCF
        end
    end
end

-- Запуск ВСЕХ квестов по очереди
function Q.runAllQuests()
    if Q.running then return end
    Q.running = true

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
    Q.running = false

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

-- Кнопка "Пройти ВСЕ квесты"
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

-- Создание кнопок отдельных квестов
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

print("[BABFT-Quest] Квесты обновлены: облако активируется через ID 1!")
