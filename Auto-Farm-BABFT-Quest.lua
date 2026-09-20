-- =====================================================================
-- МОДУЛЬ: КВЕСТ С МАСЛОМ (Auto-Farm-BABFT-Quest.lua)
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

-- Единая таблица модуля
local ButterQuest = {
    running = false,
    completed = false,
    window = nil,
    statusLabel = nil,
    countLabel = nil,
    progressBar = nil,
    actionBtn = nil
}

-- Проверка блока масла по твоим характеристикам
local function isTargetButterPart(v)
    if not v:IsA("MeshPart") then return false end
    if v.Name ~= "PPart" then return false end
    if not v.Parent or v.Parent.Name ~= "Butter" then return false end

    -- Проверка размера: 2.00 x 2.00 x 2.00 (с погрешностью)
    local sz = v.Size
    if math.abs(sz.X - 2) > 0.6 or math.abs(sz.Y - 2) > 0.6 or math.abs(sz.Z - 2) > 0.6 then
        return false
    end

    return true
end

-- Поиск блока масла, координаты которого отличаются от уже нажатых
local function findNewButterPart(visitedPositions)
    for _, obj in ipairs(Workspace:GetDescendants()) do
        if isTargetButterPart(obj) then
            local isAlreadyClicked = false
            for _, pos in ipairs(visitedPositions) do
                if (obj.Position - pos).Magnitude < 5 then
                    isAlreadyClicked = true
                    break
                end
            end

            if not isAlreadyClicked then
                return obj
            end
        end
    end
    return nil
end

-- Активация квеста в меню игры (если игрок еще не нажал "Start")
local function tryActivateQuestInGame()
    local pGui = player:FindFirstChild("PlayerGui")
    if not pGui then return end

    for _, desc in ipairs(pGui:GetDescendants()) do
        if desc:IsA("TextLabel") or desc:IsA("TextButton") then
            local txt = desc.Text:lower()
            if txt:find("find") or txt:find("butter") or txt:find("масло") then
                local parent = desc.Parent
                if parent then
                    for _, b in ipairs(parent:GetDescendants()) do
                        if b:IsA("TextButton") or b:IsA("ImageButton") then
                            local bTxt = (b:IsA("TextButton") and b.Text:lower() or "")
                            if bTxt:find("start") or bTxt:find("claim") or bTxt:find("active") or bTxt:find("принять") or bTxt == "" then
                                pcall(function()
                                    if firesignal then firesignal(b.MouseButton1Click) end
                                    if getconnections then
                                        for _, c in ipairs(getconnections(b.MouseButton1Click)) do c:Fire() end
                                    end
                                end)
                            end
                        end
                    end
                end
            end
        end
    end
end

-- Нажатие на ClickDetector
local function clickButterPart(part)
    if not part then return false end

    local cd = part:FindFirstChildOfClass("ClickDetector") or (part.Parent and part.Parent:FindFirstChildOfClass("ClickDetector"))
    
    if not cd then
        -- Поиск ClickDetector в дочерних элементах
        for _, child in ipairs(part:GetChildren()) do
            if child:IsA("ClickDetector") then
                cd = child
                break
            end
        end
    end

    if cd and fireclickdetector then
        pcall(function()
            fireclickdetector(cd)
        end)
    end

    -- Запасной физический триггер касания
    local hrp = API.getCurrentHRP()
    if hrp and firetouchinterest then
        pcall(function()
            firetouchinterest(hrp, part, 0)
            task.wait()
            firetouchinterest(hrp, part, 1)
        end)
    end

    return true
end

-- Обновление UI
function ButterQuest.updateUI(status, count, ratio)
    if ButterQuest.statusLabel then
        ButterQuest.statusLabel.Text = status
    end
    if ButterQuest.countLabel then
        ButterQuest.countLabel.Text = string.format("Собрано: %d / 5", count)
    end
    if ButterQuest.progressBar then
        TweenService:Create(ButterQuest.progressBar, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
            Size = UDim2.new(math.clamp(ratio or 0, 0, 1), 0, 1, 0)
        }):Play()
    end
end

-- Основной цикл квеста
function ButterQuest.start()
    if ButterQuest.running then return end
    ButterQuest.running = true
    ButterQuest.completed = false

    -- Ставим фарм на паузу, если он был включен
    local wasFarming = API.farming
    if wasFarming then API.stopFarming() end

    if ButterQuest.actionBtn then
        ButterQuest.actionBtn.Text = "⏸ ОСТАНОВИТЬ КВЕСТ"
        ButterQuest.actionBtn.BackgroundColor3 = Color3.fromRGB(220, 50, 70)
    end

    tryActivateQuestInGame()
    task.wait(0.5)

    local visitedPositions = {}
    local successCount = 0

    ButterQuest.updateUI("Поиск первого масла...", 0, 0)

    while ButterQuest.running and successCount < 5 do
        local currentTarget = nil
        local waitTimeout = 0

        -- Оптимизированное ожидание появления блока без лагов
        while ButterQuest.running and not currentTarget and waitTimeout < 25 do
            currentTarget = findNewButterPart(visitedPositions)
            if not currentTarget then
                task.wait(0.35)
                waitTimeout = waitTimeout + 0.35
            end
        end

        if not currentTarget then
            ButterQuest.updateUI("Таймаут: блок масла не появился!", successCount, successCount / 5)
            break
        end

        local hrp = API.getCurrentHRP()
        if not hrp then
            task.wait(0.5)
            hrp = API.getCurrentHRP()
        end

        if hrp and currentTarget and currentTarget.Parent then
            -- 1. Телепорт прямо к маслу
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.CFrame = CFrame.new(currentTarget.Position + Vector3.new(0, 1.2, 0), currentTarget.Position)
            task.wait(0.25)

            -- 2. Нажатие через ClickDetector
            clickButterPart(currentTarget)
            table.insert(visitedPositions, currentTarget.Position)
            successCount = successCount + 1

            API.playSfx(API.coinSfx)
            ButterQuest.updateUI(string.format("Клик по маслу #%d! Ждем следующее...", successCount), successCount, successCount / 5)

            -- Задержка перед поиском следующей точки
            task.wait(1.2)
        end
    end

    -- Завершение квеста
    if successCount >= 5 then
        ButterQuest.completed = true
        ButterQuest.updateUI("Квест с маслом успешно выполнен! ✓", 5, 1.0)
        API.showAchievementToast("КВЕСТ ВЫПОЛНЕН", "Масло собрано (5/5)! Награда получена.")
        
        if API.sendTelegramMessage then
            API.sendTelegramMessage("🧈 <b>Квест с маслом успешно завершен (5/5)!</b>")
        end

        if ButterQuest.actionBtn then
            ButterQuest.actionBtn.Text = "✓ ВЫПОЛНЕНО (ПОВТОРИТЬ)"
            ButterQuest.actionBtn.BackgroundColor3 = Color3.fromRGB(46, 204, 113)
        end

        -- Возвращаем персонажа на спавн
        local finalHrp = API.getCurrentHRP()
        if finalHrp then
            finalHrp.AssemblyLinearVelocity = Vector3.zero
            finalHrp.CFrame = CFrame.new(-55, 10, -50)
        end
    else
        if ButterQuest.actionBtn then
            ButterQuest.actionBtn.Text = "🧈 НАЧАТЬ КВЕСТ: МАСЛО"
            ButterQuest.actionBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
        end
    end

    ButterQuest.running = false

    -- Возвращаем автофарм, если он работал до квеста
    if wasFarming then
        task.wait(1)
        API.startFarming()
    end
end

function ButterQuest.stop()
    ButterQuest.running = false
    ButterQuest.updateUI("Квест остановлен", 0, 0)
    if ButterQuest.actionBtn then
        ButterQuest.actionBtn.Text = ButterQuest.completed and "✓ ВЫПОЛНЕНО (ПОВТОРИТЬ)" or "🧈 НАЧАТЬ КВЕСТ: МАСЛО"
        ButterQuest.actionBtn.BackgroundColor3 = ButterQuest.completed and Color3.fromRGB(46, 204, 113) or Color3.fromRGB(138, 43, 226)
    end
end

-- =====================================================================
-- МОДАЛЬНОЕ ОКНО (ZIndex = 70)
-- =====================================================================
local qWindow = Instance.new("Frame")
qWindow.Size = UDim2.new(0, 270, 0, 230)
qWindow.Position = UDim2.new(0.5, -135, 0.5, -115)
qWindow.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
qWindow.BorderSizePixel = 0
qWindow.Active = true
qWindow.ClipsDescendants = true
qWindow.Visible = false
qWindow.ZIndex = 70
qWindow.Parent = screenGui
ButterQuest.window = qWindow

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
qTitle.Text = "🧈 КВЕСТ: МАСЛО (FIND ME)"
qTitle.TextColor3 = Color3.fromRGB(255, 235, 150)
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

topBarInput = qTopBar.InputChanged:Connect(function(input)
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

-- Панель статуса
local statusPanel = Instance.new("Frame")
statusPanel.Size = UDim2.new(1, -20, 0, 55)
statusPanel.Position = UDim2.new(0, 10, 0, 38)
statusPanel.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
statusPanel.BorderSizePixel = 0
statusPanel.ZIndex = 71
statusPanel.Parent = qWindow
createCorner(statusPanel, 8)

local statusLbl = Instance.new("TextLabel")
statusLbl.Size = UDim2.new(1, -16, 0, 16)
statusLbl.Position = UDim2.new(0, 8, 0, 6)
statusLbl.BackgroundTransparency = 1
statusLbl.Text = "Статус: Нажмите «Начать»"
statusLbl.TextColor3 = Color3.fromRGB(240, 230, 255)
statusLbl.Font = Enum.Font.Gotham
statusLbl.TextSize = 10
statusLbl.TextXAlignment = Enum.TextXAlignment.Left
statusLbl.ZIndex = 72
statusLbl.Parent = statusPanel
ButterQuest.statusLabel = statusLbl

local countLbl = Instance.new("TextLabel")
countLbl.Size = UDim2.new(1, -16, 0, 16)
countLbl.Position = UDim2.new(0, 8, 0, 22)
countLbl.BackgroundTransparency = 1
countLbl.Text = "Собрано: 0 / 5"
countLbl.TextColor3 = Color3.fromRGB(255, 215, 100)
countLbl.Font = Enum.Font.GothamBold
countLbl.TextSize = 10
countLbl.TextXAlignment = Enum.TextXAlignment.Left
countLbl.ZIndex = 72
countLbl.Parent = statusPanel
ButterQuest.countLabel = countLbl

local barBg = Instance.new("Frame")
barBg.Size = UDim2.new(1, -16, 0, 6)
barBg.Position = UDim2.new(0, 8, 0, 42)
barBg.BackgroundColor3 = Color3.fromRGB(30, 24, 42)
barBg.BorderSizePixel = 0
barBg.ZIndex = 72
barBg.Parent = statusPanel
createCorner(barBg, 10)

local barFill = Instance.new("Frame")
barFill.Size = UDim2.new(0, 0, 1, 0)
barFill.BackgroundColor3 = Color3.fromRGB(255, 215, 0)
barFill.BorderSizePixel = 0
barFill.ZIndex = 73
barFill.Parent = barBg
createCorner(barFill, 10)
ButterQuest.progressBar = barFill

-- Кнопка действия
local actionBtn = Instance.new("TextButton")
actionBtn.Size = UDim2.new(1, -20, 0, 34)
actionBtn.Position = UDim2.new(0, 10, 0, 102)
actionBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
actionBtn.Text = "🧈 НАЧАТЬ КВЕСТ: МАСЛО"
actionBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
actionBtn.Font = Enum.Font.GothamBold
actionBtn.TextSize = 11
actionBtn.BorderSizePixel = 0
actionBtn.ZIndex = 72
actionBtn.Parent = qWindow
createCorner(actionBtn, 6)
ButterQuest.actionBtn = actionBtn

actionBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    if ButterQuest.running then
        ButterQuest.stop()
    else
        task.spawn(ButterQuest.start)
    end
end)

local closeBottom = Instance.new("TextButton")
closeBottom.Size = UDim2.new(1, -20, 0, 24)
closeBottom.Position = UDim2.new(0, 10, 0, 144)
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

-- Экспорт в глобальное API
function API.openQuests()
    qWindow.Visible = true
end

function API.closeQuests()
    qWindow.Visible = false
end

print("[BABFT-Quest] Квест с маслом готов к тестированию!")
