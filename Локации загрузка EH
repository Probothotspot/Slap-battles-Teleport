--[[
    Escanor HUB — Modular Locations System
    Поддерживает мультиязычность, темы, поиск, кастомные точки и последовательные ТП.
--]]

return function(locationsContent, ctx)
    local Players = game:GetService("Players")
    local LP = Players.LocalPlayer
    local TweenService = game:GetService("TweenService")
    local UserInput = game:GetService("UserInputService")
    local RunService = game:GetService("RunService")

    -- Извлечение контекста из главного скрипта
    local isMobile = ctx.isMobile or false
    local currentLang = ctx.currentLang or "en"
    local currentTheme = ctx.currentTheme or "dark"
    local themes = ctx.themes or {}
    local t = themes[currentTheme] or {
        textColor = Color3.new(1, 1, 1),
        inputBg = Color3.fromRGB(15, 15, 20)
    }
    local favorites = ctx.favorites or {}
    local SmartTP = ctx.SmartTP or function(cf)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then hrp.CFrame = cf end
    end
    local showNotification = ctx.showNotification or function(msg) print(msg) end
    local addHistoryEntry = ctx.addHistoryEntry or function() end

    -- Словари переводов
    local locTexts = {
        en = {
            coords_label = "📍 Your coords: ---",
            coords_input = "Coords:",
            tp_btn = "TP",
            search_loc_placeholder = "🔍 Search locations...",
            save_loc = "+ Save current location",
            invalid_coords = "Invalid coordinates. Example: 220, -16, -15",
            pos_saved = "Position saved!"
        },
        ru = {
            coords_label = "📍 Твои координаты: ---",
            coords_input = "Коорд:",
            tp_btn = "ТП",
            search_loc_placeholder = "🔍 Поиск локаций...",
            save_loc = "+ Сохранить текущее место",
            invalid_coords = "Некорректные координаты. Пример: 220, -16, -15",
            pos_saved = "Позиция сохранена!"
        },
        ua = {
            coords_label = "📍 Твої координати: ---",
            coords_input = "Коорд:",
            tp_btn = "ТП",
            search_loc_placeholder = "🔍 Пошук локацій...",
            save_loc = "+ Зберегти поточне місце",
            invalid_coords = "Некоректні координати. Приклад: 220, -16, -15",
            pos_saved = "Позицію збережено!"
        }
    }

    local function getT(key)
        return (locTexts[currentLang] and locTexts[currentLang][key]) or locTexts["en"][key] or key
    end

    local locationTranslations = {
        ["Debug room"] = { ru = "Дебаг комната", en = "Debug Room", ua = "Дебаг кімната" },
        ["Main island"] = { ru = "Главный остров", en = "Main Island", ua = "Головний острів" },
        ["Left island"] = { ru = "Левый остров", en = "Left Island", ua = "Лівий острів" },
        ["Right island"] = { ru = "Правый остров", en = "Right Island", ua = "Правий острів" },
        ["Moai"] = { ru = "Моаи", en = "Moai", ua = "Моаі" },
        ["Castle"] = { ru = "Замок", en = "Castle", ua = "Замок" },
        ["Kill cube"] = { ru = "Куб смерти", en = "Kill Cube", ua = "Куб смерті" },
        ["Slapple island"] = { ru = "Остров Slapple", en = "Slapple Island", ua = "Острів Slapple" },
        ["Lobby"] = { ru = "Лобби", en = "Lobby", ua = "Лобі" },
        ["Basement"] = { ru = "Подвал", en = "Basement", ua = "Підвал" },
        ["Blue portal"] = { ru = "Синий портал", en = "Blue Portal", ua = "Синій портал" },
        ["Cloud"] = { ru = "Облако", en = "Cloud", ua = "Хмара" },
        ["Brazil"] = { ru = "Бразил", en = "Brazil", ua = "Бразил" },
        ["Plate"] = { ru = "Тарелка", en = "Plate", ua = "Тарілка" },
        ["Spawn"] = { ru = "Спавн", en = "Spawn", ua = "Спавн" },
        ["Clown (Fan)"] = { ru = "Клоун (Фан)", en = "Clown (Fan)", ua = "Клоун (Фан)" },
        ["Angry Brazil"] = { ru = "Злой Бразил", en = "Angry Brazil", ua = "Злий Бразил" },
        ["OOG"] = { ru = "OOG", en = "OOG", ua = "OOG" },
        ["RiftShot"] = { ru = "RiftShot", en = "RiftShot", ua = "RiftShot" },
        ["Библиотека"] = { ru = "Библиотека", en = "Library", ua = "Бібліотека" },
        ["ФастФуд/Море"] = { ru = "ФастФуд/Море", en = "FastFood/Sea", ua = "ФастФуд/Море" },
        ["Часы на водопаде"] = { ru = "Часы на водопаде", en = "Clock at waterfall", ua = "Годинник на водоспаді" },
        ["Водопад - Наверху"] = { ru = "Водопад - Наверху", en = "Waterfall - Top", ua = "Водоспад - Вгорі" },
        ["Пикник"] = { ru = "Пикник", en = "Picnic", ua = "Пікнік" },
        ["Кирки/Топоры"] = { ru = "Кирки/Топоры", en = "Pickaxes/Axes", ua = "Кирки/Сокири" },
        ["Карусель"] = { ru = "Карусель", en = "Carousel", ua = "Карусель" },
        ["Metaverse"] = { ru = "Metaverse", en = "Metaverse", ua = "Metaverse" },
        ["Clock"] = { ru = "Часы", en = "Clock", ua = "Годинник" },
        ["Машина"] = { ru = "Машина", en = "Car", ua = "Машина" },
        ["Мортис"] = { ru = "Мортис", en = "Mortis", ua = "Мортис" },
        ["Ключ (Fan)"] = { ru = "Ключ (Фан)", en = "Key (Fan)", ua = "Ключ (Фан)" },
        ["Untitled Tag"] = { ru = "Untitled Tag", en = "Untitled Tag", ua = "Untitled Tag" },
        ["Прохождение"] = { ru = "Прохождение", en = "Walkthrough", ua = "Проходження" },
        ["Рычаг"] = { ru = "Рычаг", en = "Lever", ua = "Важіль" },
        ["2 комната"] = { ru = "2 комната", en = "Room 2", ua = "Кімната 2" },
        ["Начальный Туннель (Паркур)"] = { ru = "Начальный Туннель (Паркур)", en = "Initial Tunnel (Parkour)", ua = "Початковий тунель (Паркур)" },
        ["1 локация"] = { ru = "1 локация", en = "Location 1", ua = "Локація 1" },
        ["Конец 1 локации"] = { ru = "Конец 1 локации", en = "End of Location 1", ua = "Кінець локації 1" },
        ["Начальный Туннель (Голем)"] = { ru = "Начальный Туннель (Голем)", en = "Initial Tunnel (Golem)", ua = "Початковий тунель (Голем)" },
        ["Голем начало"] = { ru = "Голем начало", en = "Golem Start", ua = "Початок голема" },
        ["Конец голема"] = { ru = "Конец голема", en = "Golem End", ua = "Кінець голема" },
        ["Паркур Sbeve"] = { ru = "Паркур Sbeve", en = "Sbeve Parkour", ua = "Паркур Sbeve" },
        ["Лазеры начало"] = { ru = "Лазеры начало", en = "Lasers Start", ua = "Лазери початок" },
        ["Лазеры конец"] = { ru = "Лазеры конец", en = "Lasers End", ua = "Лазери кінець" },
        ["1 и 2 воссоединение"] = { ru = "1 и 2 воссоединение", en = "1&2 Reunion", ua = "1 і 2 возз'єднання" },
        ["Огонь начало"] = { ru = "Огонь начало", en = "Fire Start", ua = "Вогонь початок" },
        ["Конец огня"] = { ru = "Конец огня", en = "Fire End", ua = "Кінець вогню" },
        ["Начало поездов"] = { ru = "Начало поездов", en = "Trains Start", ua = "Початок поїздів" },
        ["Конец поездов"] = { ru = "Конец поездов", en = "Trains End", ua = "Кінець поїздів" },
        ["Пвп картошка"] = { ru = "Пвп картошка", en = "PVP Potato", ua = "PVP картопля" },
        ["Сжимание пола и потолка, перчатка"] = { ru = "Сжимание пола и потолка, перчатка", en = "Floor & Ceiling Crush", ua = "Стискання підлоги та стелі" },
        ["Конец сжимания пола и потолка, перчатка"] = { ru = "Конец сжимания пола и потолка, перчатка", en = "End of Crush", ua = "Кінець стискання" },
        ["Машина в лабиринте"] = { ru = "Машина в лабиринте", en = "Car in Maze", ua = "Машина в лабіринті" },
        ["Конец лабиринта"] = { ru = "Конец лабиринта", en = "Maze End", ua = "Кінець лабіринту" },
        ["Комната начала"] = { ru = "Комната начала", en = "Starting Room", ua = "Кімната початку" },
        ["Регенерация"] = { ru = "Регенерация", en = "Regeneration", ua = "Регенерація" },
        ["Доп хп"] = { ru = "Доп хп", en = "Extra HP", ua = "Додаткове HP" },
        ["Аватар"] = { ru = "Аватар", en = "Avatar", ua = "Аватар" },
        ["Relude, Hunter"] = { ru = "Relude, Hunter", en = "Relude, Hunter", ua = "Relude, Hunter" },
        ["Зеленый портал"] = { ru = "Зеленый портал", en = "Green Portal", ua = "Зелений портал" },
        ["Оранжевый портал"] = { ru = "Оранжевый портал", en = "Orange Portal", ua = "Помаранчевий портал" },
        ["Конец"] = { ru = "Конец", en = "End", ua = "Кінець" },
    }

    local function getLocalizedLocationName(orig)
        local item = locationTranslations[orig]
        return item and (item[currentLang] or orig) or orig
    end

    -- База локаций по плейсам
    local function getLocationsForPlace(placeId)
        if placeId == 6403373529 or placeId == 127174121130060 then -- Slap Battles / Glove Game
            return {
                {name="Debug room", cframe=CFrame.new(-17922,59,3561), isDefault=true},
                {name="Main island", cframe=CFrame.new(5,-6,2), isDefault=true},
                {name="Left island", cframe=CFrame.new(1,-6,164), isDefault=true},
                {name="Right island", cframe=CFrame.new(-3,-6,-165), isDefault=true},
                {name="Moai", cframe=CFrame.new(220,-16,-15), isDefault=true},
                {name="Castle", cframe=CFrame.new(273,33,205), isDefault=true},
                {name="Kill cube", cframe=CFrame.new(-242,-6,3), isDefault=true},
                {name="Slapple island", cframe=CFrame.new(-378,51,-16), isDefault=true},
                {name="Lobby", cframe=CFrame.new(-1197,327,-2), isDefault=true},
                {name="Basement", cframe=CFrame.new(17895,-130,-3545), isDefault=true},
                {name="Blue portal", cframe=CFrame.new(116,360,-3), isDefault=true},
                {name="Cloud", cframe=CFrame.new(-124.3,-4.6,121.2), isDefault=true},
                {name="Brazil", cframe=CFrame.new(-1124,310,0), isDefault=true},
                {name="Plate", cframe=CFrame.new(0,0,0), isDefault=true}
            }
        elseif placeId == 7234087065 then -- Barzil
            return {
                {name="Spawn", cframe=CFrame.new(-1.4, 8.8, -8.5), isDefault=true},
                {name="Clown (Fan)", cframe=CFrame.new(200, 3, 221), isDefault=true},
                {name="Angry Brazil", cframe=CFrame.new(-65, 3, -164), isDefault=true},
                {name="OOG", cframe=CFrame.new(-233, 3, 210), isDefault=true},
                {name="RiftShot", cframe=CFrame.new(-261, 13, 460), isDefault=true},
                {name="Библиотека", cframe=CFrame.new(318, 52, -43), isDefault=true},
                {name="ФастФуд/Море", cframe=CFrame.new(303, 63, 200), isDefault=true},
                {name="Часы на водопаде", cframe=CFrame.new(156, 231, 455), isDefault=true},
                {name="Водопад - Наверху", cframe=CFrame.new(83, 287, 564), isDefault=true},
                {name="Пикник", cframe=CFrame.new(35, 133, 423), isDefault=true},
                {name="Кирки/Топоры", cframe=CFrame.new(42, 52, 330), isDefault=true},
                {name="Карусель", cframe=CFrame.new(80, 3, 202), isDefault=true},
                {name="Metaverse", cframe=CFrame.new(250, 94, -442), isDefault=true},
                {name="Clock", cframe=CFrame.new(250, 150, -458.6), isDefault=true},
                {name="Машина", cframe=CFrame.new(93.4, 60, -97.5), isDefault=true},
                {name="Мортис", cframe=CFrame.new(251, -60, -361), isDefault=true},
                {name="Ключ (Fan)", cframe=CFrame.new(247, -265, -366), isDefault=true},
                {name="Untitled Tag", cframe=CFrame.new(-243, 300, -493), isDefault=true}
            }
        elseif placeId == 115782629143468 then -- Untitled Tag
            return {
                {name="Прохождение", cframe=CFrame.new(0, 200, -2), isDefault=true}
            }
        elseif placeId == 18550498098 then -- Guide
            return {
                {name="Спавн", cframe=CFrame.new(570, 11, 112), isDefault=true},
                {name="Рычаг", cframe=CFrame.new(613, 11, 146), isDefault=true},
                {name="2 комната", cframe=CFrame.new(557, 6, 353), isDefault=true},
                {name="Начальный Туннель (Паркур)", cframe=CFrame.new(602, 6, 360), isDefault=true},
                {name="1 локация", cframe=CFrame.new(723, 28, 403), isDefault=true},
                {name="Конец 1 локации", cframe=CFrame.new(831, 5, 404), isDefault=true},
                {name="Начальный Туннель (Голем)", cframe=CFrame.new(535, 6, 364), isDefault=true},
                {name="Голем начало", cframe=CFrame.new(487, 24, 510), isDefault=true},
                {name="Конец голема", cframe=CFrame.new(486, 55, 641), isDefault=true},
                {name="Паркур Sbeve", cframe=CFrame.new(690, -1, 720), isDefault=true},
                {name="Лазеры начало", cframe=CFrame.new(1071, -30, 571), isDefault=true},
                {name="Лазеры конец", cframe=CFrame.new(1218, -30, 572), isDefault=true},
                {name="1 и 2 воссоединение", cframe=CFrame.new(1435, -63, 645), isDefault=true},
                {name="Огонь начало", cframe=CFrame.new(1052, -36, 715), isDefault=true},
                {name="Конец огня", cframe=CFrame.new(1200, -36, 715), isDefault=true},
                {name="Начало поездов", cframe=CFrame.new(925, -4, 850), isDefault=true},
                {name="Конец поездов", cframe=CFrame.new(1192, -4, 860), isDefault=true},
                {name="Пвп картошка", cframe=CFrame.new(1917, -31, 893), isDefault=true},
                {name="Сжимание пола и потолка, перчатка", cframe=CFrame.new(1821, -31, 400), isDefault=true},
                {name="Конец сжимания пола и потолка, перчатка", cframe=CFrame.new(2066, -31, 397), isDefault=true},
                {name="Машина в лабиринте", cframe=CFrame.new(2126, -31, 954), isDefault=true},
                {name="Конец лабиринта", cframe=CFrame.new(2750, -31, 823), isDefault=true},
                {name="Комната начала", cframe=CFrame.new(3231, -75, 822), isDefault=true},
                {name="Регенерация", cframe=CFrame.new(3286, -75, 822), isDefault=true},
                {name="Доп хп", cframe=CFrame.new(3271, -227, 822), isDefault=true},
                {name="Аватар", cframe=CFrame.new(3270, -75, 821), isDefault=true},
                {name="Relude, Hunter", waypoints = {
                    CFrame.new(3286, -75, 822),
                    CFrame.new(3271, -227, 822),
                    CFrame.new(3270, -75, 821),
                }, isDefault=true}
            }
        elseif placeId == 77283826005207 then -- G-X
            return {
                {name="Синий портал", cframe=CFrame.new(847, 82, 381), isDefault=true},
                {name="Зеленый портал", cframe=CFrame.new(-384, 82, 386), isDefault=true},
                {name="Оранжевый портал", cframe=CFrame.new(142, 82, 923), isDefault=true},
                {name="Конец", cframe=CFrame.new(142, 84, 287), isDefault=true}
            }
        end
        return {}
    end

    local locations = getLocationsForPlace(game.PlaceId)
    local locationBtns = {}
    local locationSearchFilter = ""

    -- Специальные методы ТП
    local function teleportToPlate()
        local arena = workspace:FindFirstChild("Arena")
        if arena then
            local plate = arena:FindFirstChild("Plate")
            if plate then
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = plate.CFrame * CFrame.new(0, 5, 0) end
            end
        end
    end

    local function startSequentialTeleport(waypoints)
        task.spawn(function()
            for _, cf in ipairs(waypoints) do
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then hrp.CFrame = cf end
                task.wait(1)
            end
        end)
    end

    local function parseNumber(str)
        return tonumber(string.gsub(str, ",", "."))
    end

    local function teleportToCoordinates(inputText)
        if not inputText or inputText == "" then return end
        local coords = {}
        for num in string.gmatch(inputText, "[-]?%d+[.]?%d*") do
            table.insert(coords, parseNumber(num))
            if #coords == 3 then break end
        end
        if #coords == 3 then
            SmartTP(CFrame.new(coords[1], coords[2], coords[3]) * CFrame.new(0, 0, 2))
        else
            showNotification(getT("invalid_coords"), 2)
        end
    end

    -- Очистка контейнера перед сборкой
    locationsContent:ClearAllChildren()

    -- 1. Координаты игрока
    local coordsLabel = Instance.new("TextLabel")
    coordsLabel.Size = UDim2.new(1, 0, 0, isMobile and 0 or 18)
    coordsLabel.Position = UDim2.new(0, 4, 0, 2)
    coordsLabel.BackgroundTransparency = 1
    coordsLabel.Text = getT("coords_label")
    coordsLabel.TextColor3 = t.textColor
    coordsLabel.TextSize = isMobile and 8 or 11
    coordsLabel.Font = Enum.Font.GothamBold
    coordsLabel.TextXAlignment = Enum.TextXAlignment.Left
    coordsLabel.Visible = not isMobile
    coordsLabel.Parent = locationsContent

    -- 2. Поисковая строка
    local locSearchBox = Instance.new("TextBox")
    locSearchBox.Size = UDim2.new(1, -8, 0, 18)
    locSearchBox.Position = UDim2.new(0, 4, 0, isMobile and 2 or 22)
    locSearchBox.BackgroundColor3 = t.inputBg
    locSearchBox.Text = ""
    locSearchBox.PlaceholderText = getT("search_loc_placeholder")
    locSearchBox.TextColor3 = t.textColor
    locSearchBox.TextSize = 9
    locSearchBox.Font = Enum.Font.Gotham
    locSearchBox.BorderSizePixel = 0
    Instance.new("UICorner", locSearchBox).CornerRadius = UDim.new(0, 4)
    locSearchBox.Parent = locationsContent

    -- 3. Панель ввода координат
    local inputPanel = Instance.new("Frame")
    inputPanel.Size = UDim2.new(1, -8, 0, isMobile and 32 or 40)
    inputPanel.Position = UDim2.new(0, 4, 0, isMobile and 24 or 44)
    inputPanel.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    inputPanel.BackgroundTransparency = 0.4
    inputPanel.BorderSizePixel = 0
    Instance.new("UICorner", inputPanel).CornerRadius = UDim.new(0, 6)
    inputPanel.Parent = locationsContent

    local coordLabel = Instance.new("TextLabel")
    coordLabel.Size = UDim2.new(0, 45, 0, 14)
    coordLabel.Position = UDim2.new(0, 4, 0, 2)
    coordLabel.BackgroundTransparency = 1
    coordLabel.Text = getT("coords_input")
    coordLabel.TextColor3 = Color3.new(1, 1, 1)
    coordLabel.TextSize = isMobile and 8 or 10
    coordLabel.Font = Enum.Font.GothamBold
    coordLabel.Parent = inputPanel

    local coordInput = Instance.new("TextBox")
    coordInput.Size = UDim2.new(1, -65, 0, 16)
    coordInput.Position = UDim2.new(0, 4, 0, 18)
    coordInput.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    coordInput.Text = ""
    coordInput.TextColor3 = Color3.new(1, 1, 1)
    coordInput.TextSize = 9
    coordInput.Font = Enum.Font.Gotham
    coordInput.PlaceholderText = "X, Y, Z"
    coordInput.BorderSizePixel = 0
    Instance.new("UICorner", coordInput).CornerRadius = UDim.new(0, 4)
    coordInput.Parent = inputPanel

    local tpCoordBtn = Instance.new("TextButton")
    tpCoordBtn.Size = UDim2.new(0, 50, 0, 16)
    tpCoordBtn.Position = UDim2.new(1, -54, 0, 18)
    tpCoordBtn.Text = getT("tp_btn")
    tpCoordBtn.TextColor3 = Color3.new(1, 1, 1)
    tpCoordBtn.TextSize = 9
    tpCoordBtn.Font = Enum.Font.GothamBold
    tpCoordBtn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
    tpCoordBtn.BorderSizePixel = 0
    Instance.new("UICorner", tpCoordBtn).CornerRadius = UDim.new(0, 4)
    tpCoordBtn.Parent = inputPanel
    tpCoordBtn.MouseButton1Click:Connect(function()
        teleportToCoordinates(coordInput.Text)
    end)

    -- 4. Скролл-список кнопок локаций
    local locScroll = Instance.new("ScrollingFrame")
    locScroll.Size = UDim2.new(1, -4, 1, isMobile and -60 or -95)
    locScroll.Position = UDim2.new(0, 2, 0, isMobile and 60 or 90)
    locScroll.BackgroundTransparency = 1
    locScroll.BorderSizePixel = 0
    locScroll.ScrollBarThickness = 2
    locScroll.ClipsDescendants = true
    locScroll.Parent = locationsContent

    local locationListFrame = Instance.new("Frame")
    locationListFrame.Size = UDim2.new(1, 0, 1, 0)
    locationListFrame.BackgroundTransparency = 1
    locationListFrame.Parent = locScroll

    local locLayout = Instance.new("UIListLayout")
    locLayout.Padding = UDim.new(0, isMobile and 3 or 6)
    locLayout.Parent = locationListFrame

    -- Функция обновления списка локаций
    local function refreshLocationsList()
        for _, v in ipairs(locationBtns) do v:Destroy() end
        locationBtns = {}

        local filteredLocs = {}
        for _, loc in ipairs(locations) do
            if locationSearchFilter == "" or string.find(string.lower(getLocalizedLocationName(loc.name)), string.lower(locationSearchFilter)) then
                table.insert(filteredLocs, loc)
            end
        end

        for i, loc in ipairs(filteredLocs) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -10, 0, isMobile and 30 or 36)
            local displayName = getLocalizedLocationName(loc.name)
            if loc.waypoints then displayName = displayName .. " (sequence)" end
            if not isMobile and loc.cframe then
                displayName = displayName .. string.format(" [%d, %d, %d]", loc.cframe.X, loc.cframe.Y, loc.cframe.Z)
            end
            btn.Text = displayName
            btn.TextColor3 = Color3.new(1, 1, 1)
            btn.TextSize = isMobile and 10 or 13
            btn.Font = Enum.Font.GothamSemibold
            btn.BackgroundColor3 = Color3.fromRGB(50, 120, 200)
            btn.BackgroundTransparency = 0.2
            btn.BorderSizePixel = 0
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
            btn.Parent = locationListFrame

            -- Кнопка Избранного (★ / ☆)
            local isFav = table.find(favorites, loc.name) ~= nil
            local favBtn = Instance.new("TextButton")
            favBtn.Size = UDim2.new(0, 22, 0, 22)
            favBtn.Position = UDim2.new(1, -28, 0.5, -11)
            favBtn.Text = isFav and "★" or "☆"
            favBtn.TextColor3 = Color3.fromRGB(255, 220, 0)
            favBtn.TextSize = 16
            favBtn.Font = Enum.Font.GothamBold
            favBtn.BackgroundTransparency = 1
            favBtn.Parent = btn

            favBtn.MouseButton1Click:Connect(function()
                local idx = table.find(favorites, loc.name)
                if idx then
                    table.remove(favorites, idx)
                else
                    table.insert(favorites, loc.name)
                end
                _G.FavoriteLocations = favorites
                refreshLocationsList()
            end)

            -- Кнопка удаления для пользовательских сохраненных точек
            if not loc.isDefault then
                favBtn.Position = UDim2.new(1, -54, 0.5, -11)
                local delBtn = Instance.new("TextButton")
                delBtn.Size = UDim2.new(0, 22, 0, 22)
                delBtn.Position = UDim2.new(1, -26, 0.5, -11)
                delBtn.Text = "✕"
                delBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
                delBtn.TextSize = 12
                delBtn.Font = Enum.Font.GothamBold
                delBtn.BackgroundTransparency = 1
                delBtn.Parent = btn
                delBtn.MouseButton1Click:Connect(function()
                    local idx = table.find(locations, loc)
                    if idx then table.remove(locations, idx) end
                    refreshLocationsList()
                end)
            end

            -- Телепортация по клику
            btn.MouseButton1Click:Connect(function()
                if loc.waypoints then
                    startSequentialTeleport(loc.waypoints)
                elseif loc.cframe then
                    if loc.name == "Plate" then
                        teleportToPlate()
                    else
                        SmartTP(loc.cframe * CFrame.new(0, 0, 2))
                    end
                end
                addHistoryEntry(loc.name, loc.cframe)
            end)

            table.insert(locationBtns, btn)
        end

        -- Кнопка "+ Сохранить текущее место"
        local addLocBtn = Instance.new("TextButton")
        addLocBtn.Size = UDim2.new(1, -10, 0, isMobile and 30 or 36)
        addLocBtn.Text = getT("save_loc")
        addLocBtn.TextColor3 = Color3.new(1, 1, 1)
        addLocBtn.TextSize = isMobile and 10 or 13
        addLocBtn.Font = Enum.Font.GothamSemibold
        addLocBtn.BackgroundColor3 = Color3.fromRGB(40, 160, 60)
        addLocBtn.BackgroundTransparency = 0.2
        addLocBtn.BorderSizePixel = 0
        Instance.new("UICorner", addLocBtn).CornerRadius = UDim.new(0, 6)
        addLocBtn.Parent = locationListFrame

        addLocBtn.MouseButton1Click:Connect(function()
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                local pos = hrp.Position
                local name = string.format("Saved #%d [%d, %d, %d]", #locations + 1, math.floor(pos.X), math.floor(pos.Y), math.floor(pos.Z))
                table.insert(locations, {name = name, cframe = hrp.CFrame, isDefault = false})
                refreshLocationsList()
                showNotification(getT("pos_saved"), 1.5)
            end
        end)
        table.insert(locationBtns, addLocBtn)

        task.defer(function()
            if locScroll and locLayout then
                locScroll.CanvasSize = UDim2.new(0, 0, 0, locLayout.AbsoluteContentSize.Y + 20)
            end
        end)
    end

    -- Подключение поиска
    locSearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        locationSearchFilter = locSearchBox.Text
        refreshLocationsList()
    end)

    -- Первичная отрисовка
    refreshLocationsList()

    -- Возвращаем интерфейс для управления из основного скрипта
    return {
        refresh = refreshLocationsList,
        getLocations = function() return locations end,
        updateCoords = function()
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp and coordsLabel then
                local pos = hrp.Position
                coordsLabel.Text = string.format("📍 X: %.1f, Y: %.1f, Z: %.1f", pos.X, pos.Y, pos.Z)
            end
        end
    }
end
