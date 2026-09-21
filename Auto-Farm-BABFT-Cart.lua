-- =====================================================================
-- МОДУЛЬ: КОРЗИНА ПОКУПОК С ЖИВЫМ КАЛЬКУЛЯТОРОМ БЛОКОВ (Auto-Farm-BABFT-Cart.lua)
-- =====================================================================
local API = _G.BABFT
if not API or not API.screenGui then
    warn("[BABFT-Cart] Ошибка: Ядро или ScreenGui не найдены!")
    return
end

local TweenService = API.TweenService
local UserInputService = API.UserInputService
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

-- Красивое форматирование чисел (например: 20000 -> 20,000)
local function formatNum(n)
    local left, num, right = string.match(tostring(math.floor(n)), "^([^%d]*%d)(%d*)(.-)$")
    return left .. (num:reverse():gsub("(%d%d%d)", "%1,"):reverse()) .. right
end

local cart = {
    items = {},
    autoBuyActive = false,
    etaThread = nil,
    searchedItem = nil
}

-- Модальное окно (ZIndex = 70)
local cartWindow = Instance.new("Frame")
cartWindow.Size = UDim2.new(0, 290, 0, 435)
cartWindow.Position = UDim2.new(0.5, -145, 0.5, -217)
cartWindow.BackgroundColor3 = Color3.fromRGB(10, 8, 16)
cartWindow.BorderSizePixel = 0
cartWindow.Active = true
cartWindow.ClipsDescendants = true
cartWindow.Visible = false
cartWindow.ZIndex = 70
cartWindow.Parent = screenGui
cart.window = cartWindow

createCorner(cartWindow, 12)
local cartStroke = createStroke(cartWindow, Color3.fromRGB(180, 100, 255), 1.8)
cartStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- Шапка
local cartTopBar = Instance.new("Frame")
cartTopBar.Size = UDim2.new(1, 0, 0, 32)
cartTopBar.BackgroundTransparency = 1
cartTopBar.ZIndex = 71
cartTopBar.Parent = cartWindow

local cartTitle = Instance.new("TextLabel")
cartTitle.Size = UDim2.new(1, -40, 1, 0)
cartTitle.Position = UDim2.new(0, 12, 0, 0)
cartTitle.BackgroundTransparency = 1
cartTitle.Text = "🛒 КОРЗИНА (ПЛАНЕР ЗАКУПКИ)"
cartTitle.TextColor3 = Color3.fromRGB(230, 210, 255)
cartTitle.Font = Enum.Font.GothamBold
cartTitle.TextSize = 11
cartTitle.TextXAlignment = Enum.TextXAlignment.Left
cartTitle.ZIndex = 72
cartTitle.Parent = cartTopBar

local cartCloseBtn = Instance.new("TextButton")
cartCloseBtn.Size = UDim2.new(0, 22, 0, 22)
cartCloseBtn.Position = UDim2.new(1, -28, 0, 5)
cartCloseBtn.BackgroundColor3 = Color3.fromRGB(50, 20, 35)
cartCloseBtn.Text = "×"
cartCloseBtn.TextColor3 = Color3.fromRGB(255, 130, 150)
cartCloseBtn.Font = Enum.Font.GothamBold
cartCloseBtn.TextSize = 14
cartCloseBtn.BorderSizePixel = 0
cartCloseBtn.ZIndex = 72
cartCloseBtn.Parent = cartTopBar
createCorner(cartCloseBtn, 6)

-- Перетаскивание
local cartDragging, cartDragStart, cartStartPos
cartTopBar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        cartDragging = true
        cartDragStart = input.Position
        cartStartPos = cartWindow.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then cartDragging = false end
        end)
    end
end)

cartTopBar.InputChanged:Connect(function(input)
    if cartDragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local delta = input.Position - cartDragStart
        cartWindow.Position = UDim2.new(
            cartStartPos.X.Scale,
            cartStartPos.X.Offset + delta.X,
            cartStartPos.Y.Scale,
            cartStartPos.Y.Offset + delta.Y
        )
    end
end)

-- Поле ввода блока
local searchBox = Instance.new("TextBox")
searchBox.Size = UDim2.new(1, -20, 0, 22)
searchBox.Position = UDim2.new(0, 10, 0, 34)
searchBox.BackgroundColor3 = Color3.fromRGB(28, 22, 38)
searchBox.PlaceholderText = "Введите блок (напр. Лего, Дерево, Пластик)..."
searchBox.PlaceholderColor3 = Color3.fromRGB(130, 115, 155)
searchBox.Text = ""
searchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
searchBox.Font = Enum.Font.Gotham
searchBox.TextSize = 9.5
searchBox.ClearTextOnFocus = false
searchBox.BorderSizePixel = 0
searchBox.ZIndex = 72
searchBox.Parent = cartWindow
createCorner(searchBox, 5)
createStroke(searchBox, Color3.fromRGB(60, 45, 80), 1)

-- Строка ввода пачек + кнопка добавления
local addRow = Instance.new("Frame")
addRow.Size = UDim2.new(1, -20, 0, 22)
addRow.Position = UDim2.new(0, 10, 0, 60)
addRow.BackgroundTransparency = 1
addRow.ZIndex = 72
addRow.Parent = cartWindow

local qtyBox = Instance.new("TextBox")
qtyBox.Size = UDim2.new(0.38, -4, 1, 0)
qtyBox.BackgroundColor3 = Color3.fromRGB(28, 22, 38)
qtyBox.PlaceholderText = "Пачек: 1"
qtyBox.Text = "1"
qtyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
qtyBox.Font = Enum.Font.GothamBold
qtyBox.TextSize = 10
qtyBox.ClearTextOnFocus = false
qtyBox.BorderSizePixel = 0
qtyBox.ZIndex = 73
qtyBox.Parent = addRow
createCorner(qtyBox, 5)

local addBtn = Instance.new("TextButton")
addBtn.Size = UDim2.new(0.62, 0, 1, 0)
addBtn.Position = UDim2.new(0.38, 0, 0, 0)
addBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
addBtn.Text = "➕ Добавить в корзину"
addBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
addBtn.Font = Enum.Font.GothamBold
addBtn.TextSize = 9.5
addBtn.BorderSizePixel = 0
addBtn.ZIndex = 73
addBtn.Parent = addRow
createCorner(addBtn, 5)

-- Плашка живого расчета блоков (Калькулятор)
local calcPreviewFrame = Instance.new("Frame")
calcPreviewFrame.Size = UDim2.new(1, -20, 0, 26)
calcPreviewFrame.Position = UDim2.new(0, 10, 0, 86)
calcPreviewFrame.BackgroundColor3 = Color3.fromRGB(18, 14, 26)
calcPreviewFrame.BorderSizePixel = 0
calcPreviewFrame.ZIndex = 72
calcPreviewFrame.Parent = cartWindow
createCorner(calcPreviewFrame, 5)
createStroke(calcPreviewFrame, Color3.fromRGB(50, 40, 70), 1)

local calcPreviewLabel = Instance.new("TextLabel")
calcPreviewLabel.Size = UDim2.new(1, -10, 1, 0)
calcPreviewLabel.Position = UDim2.new(0, 5, 0, 0)
calcPreviewLabel.BackgroundTransparency = 1
calcPreviewLabel.Text = "Введите название блока и число пачек"
calcPreviewLabel.TextColor3 = Color3.fromRGB(150, 140, 175)
calcPreviewLabel.Font = Enum.Font.GothamBold
calcPreviewLabel.TextSize = 8.5
calcPreviewLabel.TextXAlignment = Enum.TextXAlignment.Left
calcPreviewLabel.ZIndex = 73
calcPreviewLabel.Parent = calcPreviewFrame

-- Функция мгновенного пересчета умножения: пачки * блоки
local function updateCalculationPreview()
    local query = searchBox.Text
    if query == "" then
        cart.searchedItem = nil
        calcPreviewLabel.Text = "Введите название блока и число пачек"
        calcPreviewLabel.TextColor3 = Color3.fromRGB(150, 140, 175)
        return
    end

    local realName, price, packYield = API.searchItemInGame(query)
    if realName and price > 0 then
        local packs = tonumber(qtyBox.Text) or 1
        if packs <= 0 then packs = 1 end
        packs = math.floor(packs)

        packYield = packYield or 1
        local totalBlocks = packs * packYield
        local totalCost = packs * price

        cart.searchedItem = {
            name = realName,
            display = realName,
            price = price,
            yield = packYield
        }

        if packYield > 1 then
            calcPreviewLabel.Text = string.format("✔ Итого: %s блоков (%s пач. × %d) | %s G", formatNum(totalBlocks), formatNum(packs), packYield, formatNum(totalCost))
        else
            calcPreviewLabel.Text = string.format("✔ Итого: %s шт. (%s G)", formatNum(packs), formatNum(totalCost))
        end
        calcPreviewLabel.TextColor3 = Color3.fromRGB(80, 240, 140)
    else
        cart.searchedItem = nil
        calcPreviewLabel.Text = "✖ Блок не найден в магазине"
        calcPreviewLabel.TextColor3 = Color3.fromRGB(255, 85, 95)
    end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(updateCalculationPreview)
qtyBox:GetPropertyChangedSignal("Text"):Connect(updateCalculationPreview)

-- Список добавленных позиций (ScrollingFrame)
local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -20, 0, 120)
listFrame.Position = UDim2.new(0, 10, 0, 116)
listFrame.BackgroundColor3 = Color3.fromRGB(16, 12, 22)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 3
listFrame.ScrollBarImageColor3 = Color3.fromRGB(138, 43, 226)
listFrame.ZIndex = 72
listFrame.Parent = cartWindow
createCorner(listFrame, 6)
createStroke(listFrame, Color3.fromRGB(45, 35, 60), 1)

-- Прогресс-бар
local progressBg = Instance.new("Frame")
progressBg.Size = UDim2.new(1, -20, 0, 16)
progressBg.Position = UDim2.new(0, 10, 0, 240)
progressBg.BackgroundColor3 = Color3.fromRGB(25, 20, 35)
progressBg.BorderSizePixel = 0
progressBg.ZIndex = 72
progressBg.Parent = cartWindow
createCorner(progressBg, 5)

local progressFill = Instance.new("Frame")
progressFill.Size = UDim2.new(0, 0, 1, 0)
progressFill.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
progressFill.BorderSizePixel = 0
progressFill.ZIndex = 73
progressFill.Parent = progressBg
createCorner(progressFill, 5)

local pGrad = Instance.new("UIGradient")
pGrad.Color = ColorSequence.new(Color3.fromRGB(138, 43, 226), Color3.fromRGB(46, 204, 113))
pGrad.Parent = progressFill

local progressLabel = Instance.new("TextLabel")
progressLabel.Size = UDim2.new(1, 0, 1, 0)
progressLabel.BackgroundTransparency = 1
progressLabel.Text = "Накоплено: 0%"
progressLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
progressLabel.Font = Enum.Font.GothamBold
progressLabel.TextSize = 9
progressLabel.ZIndex = 74
progressLabel.Parent = progressBg

-- Итоговая сводка
local summaryFrame = Instance.new("Frame")
summaryFrame.Size = UDim2.new(1, -20, 0, 72)
summaryFrame.Position = UDim2.new(0, 10, 0, 260)
summaryFrame.BackgroundColor3 = Color3.fromRGB(16, 12, 22)
summaryFrame.BorderSizePixel = 0
summaryFrame.ZIndex = 72
summaryFrame.Parent = cartWindow
createCorner(summaryFrame, 6)

local sPosLabel = Instance.new("TextLabel")
sPosLabel.Size = UDim2.new(0.62, -8, 0, 14)
sPosLabel.Position = UDim2.new(0, 8, 0, 3)
sPosLabel.BackgroundTransparency = 1
sPosLabel.Text = "Позиций: 0 (Всего: 0 блоков)"
sPosLabel.TextColor3 = Color3.fromRGB(180, 170, 200)
sPosLabel.Font = Enum.Font.GothamBold
sPosLabel.TextSize = 8.5
sPosLabel.TextXAlignment = Enum.TextXAlignment.Left
sPosLabel.ZIndex = 73
sPosLabel.Parent = summaryFrame

local sCostLabel = Instance.new("TextLabel")
sCostLabel.Size = UDim2.new(0.38, -8, 0, 14)
sCostLabel.Position = UDim2.new(0.62, 0, 0, 3)
sCostLabel.BackgroundTransparency = 1
sCostLabel.Text = "Осталось: 0 G"
sCostLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
sCostLabel.Font = Enum.Font.GothamBold
sCostLabel.TextSize = 8.5
sCostLabel.TextXAlignment = Enum.TextXAlignment.Right
sCostLabel.ZIndex = 73
sCostLabel.Parent = summaryFrame

local sBalLabel = Instance.new("TextLabel")
sBalLabel.Size = UDim2.new(0.5, -8, 0, 14)
sBalLabel.Position = UDim2.new(0, 8, 0, 19)
sBalLabel.BackgroundTransparency = 1
sBalLabel.Text = "Баланс: 0 G"
sBalLabel.TextColor3 = Color3.fromRGB(190, 185, 210)
sBalLabel.Font = Enum.Font.Gotham
sBalLabel.TextSize = 8.5
sBalLabel.TextXAlignment = Enum.TextXAlignment.Left
sBalLabel.ZIndex = 73
sBalLabel.Parent = summaryFrame

local sNeedLabel = Instance.new("TextLabel")
sNeedLabel.Size = UDim2.new(0.5, -8, 0, 14)
sNeedLabel.Position = UDim2.new(0.5, 0, 0, 19)
sNeedLabel.BackgroundTransparency = 1
sNeedLabel.Text = "Золота хватает!"
sNeedLabel.TextColor3 = Color3.fromRGB(80, 240, 130)
sNeedLabel.Font = Enum.Font.GothamBold
sNeedLabel.TextSize = 8.5
sNeedLabel.TextXAlignment = Enum.TextXAlignment.Right
sNeedLabel.ZIndex = 73
sNeedLabel.Parent = summaryFrame

local sEtaLabel = Instance.new("TextLabel")
sEtaLabel.Size = UDim2.new(1, -16, 0, 14)
sEtaLabel.Position = UDim2.new(0, 8, 0, 36)
sEtaLabel.BackgroundTransparency = 1
sEtaLabel.Text = "ETA: Цель достигнута"
sEtaLabel.TextColor3 = Color3.fromRGB(120, 210, 255)
sEtaLabel.Font = Enum.Font.GothamBold
sEtaLabel.TextSize = 8.5
sEtaLabel.TextXAlignment = Enum.TextXAlignment.Left
sEtaLabel.ZIndex = 73
sEtaLabel.Parent = summaryFrame

local sStatusLabel = Instance.new("TextLabel")
sStatusLabel.Size = UDim2.new(1, -16, 0, 14)
sStatusLabel.Position = UDim2.new(0, 8, 0, 52)
sStatusLabel.BackgroundTransparency = 1
sStatusLabel.Text = "Статус: Пауза"
sStatusLabel.TextColor3 = Color3.fromRGB(160, 145, 185)
sStatusLabel.Font = Enum.Font.Gotham
sStatusLabel.TextSize = 8.5
sStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
sStatusLabel.ZIndex = 73
sStatusLabel.Parent = summaryFrame

-- Кнопки действий
local btnRow1 = Instance.new("Frame")
btnRow1.Size = UDim2.new(1, -20, 0, 20)
btnRow1.Position = UDim2.new(0, 10, 0, 338)
btnRow1.BackgroundTransparency = 1
btnRow1.ZIndex = 72
btnRow1.Parent = cartWindow

local saveCartBtn = Instance.new("TextButton")
saveCartBtn.Size = UDim2.new(0.32, -2, 1, 0)
saveCartBtn.BackgroundColor3 = Color3.fromRGB(35, 28, 48)
saveCartBtn.Text = "💾 Сохранить"
saveCartBtn.TextColor3 = Color3.fromRGB(220, 210, 240)
saveCartBtn.Font = Enum.Font.Gotham
saveCartBtn.TextSize = 8
saveCartBtn.BorderSizePixel = 0
saveCartBtn.ZIndex = 73
saveCartBtn.Parent = btnRow1
createCorner(saveCartBtn, 4)

local loadCartBtn = Instance.new("TextButton")
loadCartBtn.Size = UDim2.new(0.32, -2, 1, 0)
loadCartBtn.Position = UDim2.new(0.34, 0, 0, 0)
loadCartBtn.BackgroundColor3 = Color3.fromRGB(35, 28, 48)
loadCartBtn.Text = "📂 Загрузить"
loadCartBtn.TextColor3 = Color3.fromRGB(220, 210, 240)
loadCartBtn.Font = Enum.Font.Gotham
loadCartBtn.TextSize = 8
loadCartBtn.BorderSizePixel = 0
loadCartBtn.ZIndex = 73
loadCartBtn.Parent = btnRow1
createCorner(loadCartBtn, 4)

local clearCartBtn = Instance.new("TextButton")
clearCartBtn.Size = UDim2.new(0.32, 0, 1, 0)
clearCartBtn.Position = UDim2.new(0.68, 0, 0, 0)
clearCartBtn.BackgroundColor3 = Color3.fromRGB(50, 20, 30)
clearCartBtn.Text = "🗑 Очистить"
clearCartBtn.TextColor3 = Color3.fromRGB(255, 150, 150)
clearCartBtn.Font = Enum.Font.Gotham
clearCartBtn.TextSize = 8
clearCartBtn.BorderSizePixel = 0
clearCartBtn.ZIndex = 73
clearCartBtn.Parent = btnRow1
createCorner(clearCartBtn, 4)

local autoBuyCartToggle = Instance.new("TextButton")
autoBuyCartToggle.Size = UDim2.new(1, -20, 0, 26)
autoBuyCartToggle.Position = UDim2.new(0, 10, 0, 362)
autoBuyCartToggle.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
autoBuyCartToggle.Text = "▶ НАЧАТЬ АВТО-ЗАКУПКУ"
autoBuyCartToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
autoBuyCartToggle.Font = Enum.Font.GothamBold
autoBuyCartToggle.TextSize = 10
autoBuyCartToggle.BorderSizePixel = 0
autoBuyCartToggle.ZIndex = 73
autoBuyCartToggle.Parent = cartWindow
createCorner(autoBuyCartToggle, 6)

local closeCartBottom = Instance.new("TextButton")
closeCartBottom.Size = UDim2.new(1, -20, 0, 22)
closeCartBottom.Position = UDim2.new(0, 10, 0, 392)
closeCartBottom.BackgroundColor3 = Color3.fromRGB(28, 22, 38)
closeCartBottom.Text = "❌ Закрыть окно"
closeCartBottom.TextColor3 = Color3.fromRGB(200, 190, 220)
closeCartBottom.Font = Enum.Font.Gotham
closeCartBottom.TextSize = 9
closeCartBottom.BorderSizePixel = 0
closeCartBottom.ZIndex = 73
closeCartBottom.Parent = cartWindow
createCorner(closeCartBottom, 5)

-- Пересчет сводки
cart.updateSummary = function()
    local currentGold = API.getCurrentGold()
    local totalItems = #cart.items
    local totalCost = 0
    local unboughtCost = 0
    local totalBlocksCount = 0

    for _, itm in ipairs(cart.items) do
        local lineCost = itm.price * itm.qty
        local lineBlocks = (itm.yield or 1) * itm.qty
        totalCost = totalCost + lineCost
        totalBlocksCount = totalBlocksCount + lineBlocks
        if not itm.bought then
            unboughtCost = unboughtCost + lineCost
        end
    end

    local remainingNeeded = unboughtCost - currentGold
    if remainingNeeded < 0 then remainingNeeded = 0 end

    sPosLabel.Text = string.format("Позиций: %d (Итого: %s блоков)", totalItems, formatNum(totalBlocksCount))
    sCostLabel.Text = "Осталось: " .. formatNum(unboughtCost) .. " G"
    sBalLabel.Text = "Баланс: " .. formatNum(currentGold) .. " G"

    if remainingNeeded > 0 then
        sNeedLabel.Text = "Не хватает: " .. formatNum(remainingNeeded) .. " G"
        sNeedLabel.TextColor3 = Color3.fromRGB(255, 90, 90)
    else
        sNeedLabel.Text = "Золота хватает!"
        sNeedLabel.TextColor3 = Color3.fromRGB(80, 240, 130)
    end

    local progressPercent = 0
    if totalCost > 0 then
        local alreadyPaidOrHave = (totalCost - unboughtCost) + currentGold
        progressPercent = math.clamp(alreadyPaidOrHave / totalCost, 0, 1)
    else
        progressPercent = 1
    end

    progressFill.Size = UDim2.new(progressPercent, 0, 1, 0)
    progressLabel.Text = string.format("Прогресс цели: %d%%", math.floor(progressPercent * 100))

    local avgGpm = API.getAvgGoldPerMin and API.getAvgGoldPerMin() or (API.averageGoldPerMinute or 0)
    if unboughtCost == 0 and totalItems > 0 then
        sEtaLabel.Text = "ETA: Все куплено! ✓"
        sEtaLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
    elseif remainingNeeded == 0 then
        sEtaLabel.Text = "ETA: Готово к покупке"
        sEtaLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
    elseif avgGpm <= 0 then
        sEtaLabel.Text = "ETA: Ожидаю замер скорости..."
        sEtaLabel.TextColor3 = Color3.fromRGB(255, 200, 100)
    else
        local sec = math.floor((remainingNeeded / avgGpm) * 60)
        sEtaLabel.Text = "ETA: ~" .. API.formatTime(sec)
        sEtaLabel.TextColor3 = Color3.fromRGB(120, 210, 255)
    end

    if cart.autoBuyActive then
        sStatusLabel.Text = "Статус: Закупка активна..."
        sStatusLabel.TextColor3 = Color3.fromRGB(80, 240, 130)
    else
        sStatusLabel.Text = "Статус: Пауза"
        sStatusLabel.TextColor3 = Color3.fromRGB(160, 145, 185)
    end
end

-- Отрисовка списка строк в корзине
cart.refreshList = function()
    for _, child in ipairs(listFrame:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    listFrame.CanvasSize = UDim2.new(0, 0, 0, #cart.items * 28 + 4)

    for i, itm in ipairs(cart.items) do
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -8, 0, 24)
        row.Position = UDim2.new(0, 4, 0, (i - 1) * 28 + 2)
        row.BackgroundColor3 = itm.bought and Color3.fromRGB(20, 35, 25) or Color3.fromRGB(26, 20, 34)
        row.BorderSizePixel = 0
        row.ZIndex = 73
        row.Parent = listFrame
        createCorner(row, 4)

        local statusMark = itm.bought and "✓ " or "• "
        local packYield = itm.yield or 1
        local totalPieces = itm.qty * packYield

        local displayText = ""
        if packYield > 1 then
            displayText = string.format("%s × %s пач. ➔ %s блоков", itm.display, formatNum(itm.qty), formatNum(totalPieces))
        else
            displayText = string.format("%s × %s шт.", itm.display, formatNum(itm.qty))
        end

        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0.66, 0, 1, 0)
        nameLbl.Position = UDim2.new(0, 6, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = statusMark .. displayText
        nameLbl.TextColor3 = itm.bought and Color3.fromRGB(140, 255, 170) or Color3.fromRGB(235, 225, 250)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 8.5
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.ZIndex = 74
        nameLbl.Parent = row

        local priceLbl = Instance.new("TextLabel")
        priceLbl.Size = UDim2.new(0.20, 0, 1, 0)
        priceLbl.Position = UDim2.new(0.66, 0, 0, 0)
        priceLbl.BackgroundTransparency = 1
        priceLbl.Text = formatNum(itm.price * itm.qty) .. " G"
        priceLbl.TextColor3 = Color3.fromRGB(255, 215, 0)
        priceLbl.Font = Enum.Font.Gotham
        priceLbl.TextSize = 8
        priceLbl.TextXAlignment = Enum.TextXAlignment.Right
        priceLbl.ZIndex = 74
        priceLbl.Parent = row

        local delBtn = Instance.new("TextButton")
        delBtn.Size = UDim2.new(0, 18, 0, 18)
        delBtn.Position = UDim2.new(1, -21, 0, 3)
        delBtn.BackgroundColor3 = Color3.fromRGB(55, 20, 30)
        delBtn.Text = "✕"
        delBtn.TextColor3 = Color3.fromRGB(255, 120, 140)
        delBtn.Font = Enum.Font.GothamBold
        delBtn.TextSize = 9
        delBtn.BorderSizePixel = 0
        delBtn.ZIndex = 74
        delBtn.Parent = row
        createCorner(delBtn, 3)

        delBtn.MouseButton1Click:Connect(function()
            API.playSfx(API.clickSfx)
            table.remove(cart.items, i)
            cart.refreshList()
            cart.updateSummary()
        end)
    end
end

-- Добавление найденного блока
addBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    if not cart.searchedItem then
        calcPreviewLabel.Text = "Сначала введите правильный блок выше!"
        calcPreviewLabel.TextColor3 = Color3.fromRGB(255, 180, 80)
        return
    end

    local q = tonumber(qtyBox.Text)
    if not q or q <= 0 then q = 1 end
    q = math.floor(q)

    table.insert(cart.items, {
        name = cart.searchedItem.name,
        display = cart.searchedItem.display,
        qty = q,
        price = cart.searchedItem.price,
        yield = cart.searchedItem.yield or 1,
        bought = false
    })

    searchBox.Text = ""
    qtyBox.Text = "1"
    cart.searchedItem = nil
    calcPreviewLabel.Text = "✔ Добавлено! Введите следующий блок..."
    calcPreviewLabel.TextColor3 = Color3.fromRGB(120, 220, 255)

    cart.refreshList()
    cart.updateSummary()
end)

-- Сохранение и загрузка
cart.save = function()
    if not writefile then return end
    pcall(function()
        local payload = {
            items = cart.items,
            autoBuyActive = cart.autoBuyActive
        }
        writefile("babft_cart.json", API.HttpService:JSONEncode(payload))
    end)
end

cart.load = function()
    if not (isfile and readfile and isfile("babft_cart.json")) then return end
    pcall(function()
        local raw = readfile("babft_cart.json")
        local data = API.HttpService:JSONDecode(raw)
        if data and type(data.items) == "table" then
            cart.items = data.items
            cart.refreshList()
            cart.updateSummary()
        end
    end)
end

saveCartBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    cart.save()
    saveCartBtn.Text = "✔ Сохранено!"
    task.delay(1.2, function()
        if saveCartBtn and saveCartBtn.Parent then saveCartBtn.Text = "💾 Сохранить" end
    end)
end)

loadCartBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    cart.load()
    loadCartBtn.Text = "✔ Загружено!"
    task.delay(1.2, function()
        if loadCartBtn and loadCartBtn.Parent then loadCartBtn.Text = "📂 Загрузить" end
    end)
end)

clearCartBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    cart.items = {}
    cart.refreshList()
    cart.updateSummary()
end)

-- Авто-закупка
cart.startAutoBuy = function()
    if cart.autoBuyActive then return end
    cart.autoBuyActive = true
    autoBuyCartToggle.Text = "⏸ ОСТАНОВИТЬ АВТО-ЗАКУПКУ"
    autoBuyCartToggle.BackgroundColor3 = Color3.fromRGB(220, 50, 70)
    cart.updateSummary()

    API.cartAutoBuyThread = task.spawn(function()
        while cart.autoBuyActive do
            local allCompleted = true
            for _, item in ipairs(cart.items) do
                if not item.bought then
                    allCompleted = false
                    local cost = item.price * item.qty
                    if API.getCurrentGold() >= cost then
                        local success, resultMsg = API.executeBuy(item.name, item.qty)
                        if success then
                            item.bought = true
                            cart.save()
                            cart.refreshList()
                            cart.updateSummary()
                            local totalP = item.qty * (item.yield or 1)
                            API.showAchievementToast("КУПЛЕНО", item.display .. " (" .. formatNum(totalP) .. " шт.)")
                            if API.sendTelegramMessage then
                                API.sendTelegramMessage("🛒 <b>Куплено:</b> " .. item.display .. " × " .. formatNum(item.qty) .. " пач. (" .. formatNum(totalP) .. " шт.)")
                            end
                        end
                    end
                    break
                end
            end

            if allCompleted and #cart.items > 0 then
                API.showAchievementToast("КОРЗИНА ГОТОВА", "Все позиции закуплены!")
                if API.sendTelegramMessage then
                    API.sendTelegramMessage("🎉 <b>Корзина BABFT:</b> Все запланированные блоки закуплены!")
                end
                cart.stopAutoBuy()
                break
            end

            task.wait(3)
        end
    end)
end

cart.stopAutoBuy = function()
    cart.autoBuyActive = false
    autoBuyCartToggle.Text = "▶ НАЧАТЬ АВТО-ЗАКУПКУ"
    autoBuyCartToggle.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
    if API.cartAutoBuyThread then
        task.cancel(API.cartAutoBuyThread)
        API.cartAutoBuyThread = nil
    end
    cart.updateSummary()
end

autoBuyCartToggle.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    if cart.autoBuyActive then
        cart.stopAutoBuy()
    else
        cart.startAutoBuy()
    end
end)

function API.openCart()
    cartWindow.Visible = true
    cart.refreshList()
    cart.updateSummary()
    updateCalculationPreview()

    if not cart.etaThread then
        cart.etaThread = task.spawn(function()
            while cartWindow.Visible do
                cart.updateSummary()
                task.wait(5)
            end
            cart.etaThread = nil
        end)
    end
end

function API.closeCart()
    cartWindow.Visible = false
end

cartCloseBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.closeCart()
end)

closeCartBottom.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    API.closeCart()
end)

cart.load()
print("[BABFT-Cart] Корзина с живым калькулятором блоков готова!")
