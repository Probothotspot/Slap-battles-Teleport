local API = _G.BABFT
if not API or not API.screenGui then
    warn("[BABFT-Cart] Ошибка: Ядро или ScreenGui не найдены! Сначала запустите Main и GUI.")
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

-- Единая таблица модуля
local cart = {
    items = {},
    autoBuyActive = false,
    etaThread = nil,
    selectedItem = nil,
    dropdownOpen = false
}

-- Выборка предметов
cart.getAvailableItems = function()
    local unique = {}
    local seen = {}
    if API.KNOWN_ITEMS then
        for key, data in pairs(API.KNOWN_ITEMS) do
            if not seen[data.name] then
                seen[data.name] = true
                table.insert(unique, {
                    name = data.name,
                    display = key:sub(1,1):upper() .. key:sub(2),
                    price = data.price
                })
            end
        end
    end
    table.sort(unique, function(a, b) return a.display < b.display end)
    return unique
end

-- Модальное окно (ZIndex = 70)
local cartWindow = Instance.new("Frame")
cartWindow.Size = UDim2.new(0, 280, 0, 410)
cartWindow.Position = UDim2.new(0.5, -140, 0.5, -205)
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
cartTitle.Text = "🛒 ПЛАНЕР ЗАКУПОК"
cartTitle.TextColor3 = Color3.fromRGB(230, 210, 255)
cartTitle.Font = Enum.Font.GothamBold
cartTitle.TextSize = 12
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

-- Строка добавления
local addSection = Instance.new("Frame")
addSection.Size = UDim2.new(1, -20, 0, 28)
addSection.Position = UDim2.new(0, 10, 0, 36)
addSection.BackgroundTransparency = 1
addSection.ZIndex = 72
addSection.Parent = cartWindow

local available = cart.getAvailableItems()
cart.selectedItem = available[1] or {name = "ToyBlock", display = "ToyBlock", price = 250}

local dropBtn = Instance.new("TextButton")
dropBtn.Size = UDim2.new(0.55, -4, 1, 0)
dropBtn.BackgroundColor3 = Color3.fromRGB(30, 24, 40)
dropBtn.Text = (cart.selectedItem and cart.selectedItem.display or "Выбрать") .. " ▾"
dropBtn.TextColor3 = Color3.fromRGB(240, 230, 255)
dropBtn.Font = Enum.Font.Gotham
dropBtn.TextSize = 9
dropBtn.BorderSizePixel = 0
dropBtn.ZIndex = 73
dropBtn.Parent = addSection
createCorner(dropBtn, 5)

local qtyBox = Instance.new("TextBox")
qtyBox.Size = UDim2.new(0.2, -4, 1, 0)
qtyBox.Position = UDim2.new(0.55, 0, 0, 0)
qtyBox.BackgroundColor3 = Color3.fromRGB(30, 24, 40)
qtyBox.Text = "1"
qtyBox.TextColor3 = Color3.fromRGB(255, 255, 255)
qtyBox.Font = Enum.Font.GothamBold
qtyBox.TextSize = 10
qtyBox.ClearTextOnFocus = false
qtyBox.BorderSizePixel = 0
qtyBox.ZIndex = 73
qtyBox.Parent = addSection
createCorner(qtyBox, 5)

local addBtn = Instance.new("TextButton")
addBtn.Size = UDim2.new(0.25, 0, 1, 0)
addBtn.Position = UDim2.new(0.75, 4, 0, 0)
addBtn.BackgroundColor3 = Color3.fromRGB(138, 43, 226)
addBtn.Text = "➕ Добавить"
addBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
addBtn.Font = Enum.Font.GothamBold
addBtn.TextSize = 9
addBtn.BorderSizePixel = 0
addBtn.ZIndex = 73
addBtn.Parent = addSection
createCorner(addBtn, 5)

-- Dropdown
local dropList = Instance.new("ScrollingFrame")
dropList.Size = UDim2.new(0.65, 0, 0, 130)
dropList.Position = UDim2.new(0, 10, 0, 66)
dropList.BackgroundColor3 = Color3.fromRGB(20, 16, 28)
dropList.BorderSizePixel = 0
dropList.ScrollBarThickness = 3
dropList.ScrollBarImageColor3 = Color3.fromRGB(138, 43, 226)
dropList.Visible = false
dropList.ZIndex = 95
dropList.CanvasSize = UDim2.new(0, 0, 0, #available * 20)
dropList.Parent = cartWindow
createCorner(dropList, 6)
createStroke(dropList, Color3.fromRGB(138, 43, 226), 1)

for idx, itemData in ipairs(available) do
    local itemBtn = Instance.new("TextButton")
    itemBtn.Size = UDim2.new(1, -6, 0, 18)
    itemBtn.Position = UDim2.new(0, 3, 0, (idx - 1) * 20 + 2)
    itemBtn.BackgroundColor3 = Color3.fromRGB(28, 22, 38)
    itemBtn.Text = itemData.display .. " (" .. itemData.price .. " G)"
    itemBtn.TextColor3 = Color3.fromRGB(230, 220, 250)
    itemBtn.Font = Enum.Font.Gotham
    itemBtn.TextSize = 9
    itemBtn.BorderSizePixel = 0
    itemBtn.ZIndex = 96
    itemBtn.Parent = dropList
    createCorner(itemBtn, 4)

    itemBtn.MouseButton1Click:Connect(function()
        API.playSfx(API.clickSfx)
        cart.selectedItem = itemData
        dropBtn.Text = itemData.display .. " ▾"
        dropList.Visible = false
        cart.dropdownOpen = false
    end)
end

dropBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    cart.dropdownOpen = not cart.dropdownOpen
    dropList.Visible = cart.dropdownOpen
end)

-- Список позиций
local listFrame = Instance.new("ScrollingFrame")
listFrame.Size = UDim2.new(1, -20, 0, 140)
listFrame.Position = UDim2.new(0, 10, 0, 70)
listFrame.BackgroundColor3 = Color3.fromRGB(16, 12, 22)
listFrame.BorderSizePixel = 0
listFrame.ScrollBarThickness = 3
listFrame.ScrollBarImageColor3 = Color3.fromRGB(138, 43, 226)
listFrame.ZIndex = 72
listFrame.Parent = cartWindow
createCorner(listFrame, 6)
createStroke(listFrame, Color3.fromRGB(45, 35, 60), 1)
cart.listFrame = listFrame

-- Прогресс-бар
local progressBg = Instance.new("Frame")
progressBg.Size = UDim2.new(1, -20, 0, 16)
progressBg.Position = UDim2.new(0, 10, 0, 216)
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

-- Сводка
local summaryFrame = Instance.new("Frame")
summaryFrame.Size = UDim2.new(1, -20, 0, 75)
summaryFrame.Position = UDim2.new(0, 10, 0, 238)
summaryFrame.BackgroundColor3 = Color3.fromRGB(16, 12, 22)
summaryFrame.BorderSizePixel = 0
summaryFrame.ZIndex = 72
summaryFrame.Parent = cartWindow
createCorner(summaryFrame, 6)

local sPosLabel = Instance.new("TextLabel")
sPosLabel.Size = UDim2.new(0.5, -8, 0, 14)
sPosLabel.Position = UDim2.new(0, 8, 0, 4)
sPosLabel.BackgroundTransparency = 1
sPosLabel.Text = "Позиций: 0"
sPosLabel.TextColor3 = Color3.fromRGB(180, 170, 200)
sPosLabel.Font = Enum.Font.Gotham
sPosLabel.TextSize = 9
sPosLabel.TextXAlignment = Enum.TextXAlignment.Left
sPosLabel.ZIndex = 73
sPosLabel.Parent = summaryFrame

local sCostLabel = Instance.new("TextLabel")
sCostLabel.Size = UDim2.new(0.5, -8, 0, 14)
sCostLabel.Position = UDim2.new(0.5, 0, 0, 4)
sCostLabel.BackgroundTransparency = 1
sCostLabel.Text = "Стоимость: 0 G"
sCostLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
sCostLabel.Font = Enum.Font.GothamBold
sCostLabel.TextSize = 9
sCostLabel.TextXAlignment = Enum.TextXAlignment.Right
sCostLabel.ZIndex = 73
sCostLabel.Parent = summaryFrame

local sBalLabel = Instance.new("TextLabel")
sBalLabel.Size = UDim2.new(0.5, -8, 0, 14)
sBalLabel.Position = UDim2.new(0, 8, 0, 20)
sBalLabel.BackgroundTransparency = 1
sBalLabel.Text = "Баланс: 0 G"
sBalLabel.TextColor3 = Color3.fromRGB(190, 185, 210)
sBalLabel.Font = Enum.Font.Gotham
sBalLabel.TextSize = 9
sBalLabel.TextXAlignment = Enum.TextXAlignment.Left
sBalLabel.ZIndex = 73
sBalLabel.Parent = summaryFrame

local sNeedLabel = Instance.new("TextLabel")
sNeedLabel.Size = UDim2.new(0.5, -8, 0, 14)
sNeedLabel.Position = UDim2.new(0.5, 0, 0, 20)
sNeedLabel.BackgroundTransparency = 1
sNeedLabel.Text = "Осталось: 0 G"
sNeedLabel.TextColor3 = Color3.fromRGB(80, 240, 130)
sNeedLabel.Font = Enum.Font.GothamBold
sNeedLabel.TextSize = 9
sNeedLabel.TextXAlignment = Enum.TextXAlignment.Right
sNeedLabel.ZIndex = 73
sNeedLabel.Parent = summaryFrame

local sEtaLabel = Instance.new("TextLabel")
sEtaLabel.Size = UDim2.new(1, -16, 0, 14)
sEtaLabel.Position = UDim2.new(0, 8, 0, 38)
sEtaLabel.BackgroundTransparency = 1
sEtaLabel.Text = "ETA: Цель достигнута"
sEtaLabel.TextColor3 = Color3.fromRGB(120, 210, 255)
sEtaLabel.Font = Enum.Font.GothamBold
sEtaLabel.TextSize = 9
sEtaLabel.TextXAlignment = Enum.TextXAlignment.Left
sEtaLabel.ZIndex = 73
sEtaLabel.Parent = summaryFrame

local sStatusLabel = Instance.new("TextLabel")
sStatusLabel.Size = UDim2.new(1, -16, 0, 14)
sStatusLabel.Position = UDim2.new(0, 8, 0, 54)
sStatusLabel.BackgroundTransparency = 1
sStatusLabel.Text = "Статус: Ожидание запуска"
sStatusLabel.TextColor3 = Color3.fromRGB(160, 145, 185)
sStatusLabel.Font = Enum.Font.Gotham
sStatusLabel.TextSize = 9
sStatusLabel.TextXAlignment = Enum.TextXAlignment.Left
sStatusLabel.ZIndex = 73
sStatusLabel.Parent = summaryFrame

-- Кнопки
local btnRow1 = Instance.new("Frame")
btnRow1.Size = UDim2.new(1, -20, 0, 20)
btnRow1.Position = UDim2.new(0, 10, 0, 320)
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
autoBuyCartToggle.Position = UDim2.new(0, 10, 0, 346)
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
closeCartBottom.Position = UDim2.new(0, 10, 0, 378)
closeCartBottom.BackgroundColor3 = Color3.fromRGB(28, 22, 38)
closeCartBottom.Text = "❌ Закрыть окно"
closeCartBottom.TextColor3 = Color3.fromRGB(200, 190, 220)
closeCartBottom.Font = Enum.Font.Gotham
closeCartBottom.TextSize = 9
closeCartBottom.BorderSizePixel = 0
closeCartBottom.ZIndex = 73
closeCartBottom.Parent = cartWindow
createCorner(closeCartBottom, 5)

-- Обновление сводки
cart.updateSummary = function()
    local currentGold = API.getCurrentGold()
    local totalItems = #cart.items
    local totalCost = 0
    local unboughtCost = 0

    for _, itm in ipairs(cart.items) do
        local lineTotal = itm.price * itm.qty
        totalCost = totalCost + lineTotal
        if not itm.bought then
            unboughtCost = unboughtCost + lineTotal
        end
    end

    local remainingNeeded = unboughtCost - currentGold
    if remainingNeeded < 0 then remainingNeeded = 0 end

    sPosLabel.Text = "Позиций: " .. totalItems
    sCostLabel.Text = "Осталось: " .. unboughtCost .. " G"
    sBalLabel.Text = "Баланс: " .. currentGold .. " G"

    if remainingNeeded > 0 then
        sNeedLabel.Text = "Не хватает: " .. remainingNeeded .. " G"
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

-- Перерисовка списка
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
        local nameLbl = Instance.new("TextLabel")
        nameLbl.Size = UDim2.new(0.62, 0, 1, 0)
        nameLbl.Position = UDim2.new(0, 6, 0, 0)
        nameLbl.BackgroundTransparency = 1
        nameLbl.Text = statusMark .. itm.display .. " × " .. itm.qty
        nameLbl.TextColor3 = itm.bought and Color3.fromRGB(140, 255, 170) or Color3.fromRGB(235, 225, 250)
        nameLbl.Font = Enum.Font.GothamBold
        nameLbl.TextSize = 9
        nameLbl.TextXAlignment = Enum.TextXAlignment.Left
        nameLbl.ZIndex = 74
        nameLbl.Parent = row

        local priceLbl = Instance.new("TextLabel")
        priceLbl.Size = UDim2.new(0.24, 0, 1, 0)
        priceLbl.Position = UDim2.new(0.62, 0, 0, 0)
        priceLbl.BackgroundTransparency = 1
        priceLbl.Text = (itm.price * itm.qty) .. " G"
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

-- Добавление
addBtn.MouseButton1Click:Connect(function()
    API.playSfx(API.clickSfx)
    if not cart.selectedItem then return end
    local q = tonumber(qtyBox.Text)
    if not q or q <= 0 then q = 1 end
    q = math.floor(q)

    table.insert(cart.items, {
        name = cart.selectedItem.name,
        display = cart.selectedItem.display,
        qty = q,
        price = cart.selectedItem.price,
        bought = false
    })

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
                            API.showAchievementToast("КУПЛЕНО", item.display .. " × " .. item.qty)
                            API.sendTelegramMessage("🛒 <b>Куплено из корзины:</b> " .. item.display .. " × " .. item.qty)
                        end
                    end
                    break
                end
            end

            if allCompleted and #cart.items > 0 then
                API.showAchievementToast("КОРЗИНА ГОТОВА", "Все позиции закуплены!")
                API.sendTelegramMessage("🎉 <b>Корзина BABFT:</b> Все запланированные позиции закуплены!")
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

-- Публичные методы для GUI
function API.openCart()
    cartWindow.Visible = true
    cart.refreshList()
    cart.updateSummary()

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
    dropList.Visible = false
    cart.dropdownOpen = false
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
print("[BABFT-Cart] Модуль Корзины успешно подключен!")
