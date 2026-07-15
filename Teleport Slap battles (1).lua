--[[
    Escanor HUB 🔥 v2.1 – Mobile compact UI, floating button always accessible.
    By: Akulaui
--]]

if not game:IsLoaded() then game.Loaded:Wait() end
local Players = game:GetService("Players")
local LP = Players.LocalPlayer
local UserInput = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local TeleportService = game:GetService("TeleportService")
local LocalizationService = game:GetService("LocalizationService")

-- ===== ГЛОБАЛЬНЫЕ НАСТРОЙКИ ЛАУНЧЕРА =====
if _G.TeleportHubSettings == nil then
    _G.TeleportHubSettings = {}
end

-- ===== ЛАУНЧЕР С ВЫБОРОМ ВЕРСИИ =====
local function showLauncher()
    local launcherGui = Instance.new("ScreenGui")
    launcherGui.Name = "Launcher"
    launcherGui.ResetOnSpawn = false
    pcall(function() launcherGui.Parent = game:GetService("CoreGui") end)
    if not launcherGui.Parent then
        launcherGui.Parent = LP:WaitForChild("PlayerGui")
    end

    local main = Instance.new("Frame", launcherGui)
    main.Size = UDim2.new(0, 420, 0, 400)
    main.Position = UDim2.new(0.5, -210, 0.5, -200)
    main.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
    main.BorderSizePixel = 0
    Instance.new("UICorner", main).CornerRadius = UDim.new(0, 16)
    local gradient = Instance.new("UIGradient", main)
    gradient.Color = ColorSequence.new{
        ColorSequenceKeypoint.new(0, Color3.fromRGB(30, 30, 50)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(15, 15, 30))
    }
    gradient.Rotation = -45

    local titleLabel = Instance.new("TextLabel", main)
    titleLabel.Size = UDim2.new(1, -20, 0, 40)
    titleLabel.Position = UDim2.new(0, 10, 0, 10)
    titleLabel.BackgroundTransparency = 1
    titleLabel.Text = "🚀 Escanor HUB 🔥 v2.1"
    titleLabel.TextColor3 = Color3.new(1, 1, 1)
    titleLabel.TextSize = 24
    titleLabel.Font = Enum.Font.GothamBold
    titleLabel.TextXAlignment = Enum.TextXAlignment.Left

    -- Язык
    local langLabel = Instance.new("TextLabel", main)
    langLabel.Size = UDim2.new(1, -20, 0, 25)
    langLabel.Position = UDim2.new(0, 10, 0, 65)
    langLabel.BackgroundTransparency = 1
    langLabel.Text = "🌐 Язык / Language:"
    langLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    langLabel.TextSize = 16
    langLabel.Font = Enum.Font.Gotham
    langLabel.TextXAlignment = Enum.TextXAlignment.Left

    local selectedLang = "en"
    local langButtons = {}
    local function updateLangButtons()
        for code, btn in pairs(langButtons) do
            btn.BackgroundColor3 = code == selectedLang and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(60, 60, 120)
        end
    end
    local langs = {"English", "Русский", "Українська"}
    local langCodes = {"en", "ru", "ua"}
    for i, name in ipairs(langs) do
        local btn = Instance.new("TextButton", main)
        btn.Size = UDim2.new(0.3, -5, 0, 36)
        btn.Position = UDim2.new(0, 10 + (i-1)*130, 0, 95)
        btn.Text = name
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamSemibold
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        btn.MouseButton1Click:Connect(function()
            selectedLang = langCodes[i]
            updateLangButtons()
        end)
        langButtons[langCodes[i]] = btn
    end

    -- Устройство
    local devLabel = Instance.new("TextLabel", main)
    devLabel.Size = UDim2.new(1, -20, 0, 25)
    devLabel.Position = UDim2.new(0, 10, 0, 145)
    devLabel.BackgroundTransparency = 1
    devLabel.Text = "📱 Устройство / Device:"
    devLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    devLabel.TextSize = 16
    devLabel.Font = Enum.Font.Gotham
    devLabel.TextXAlignment = Enum.TextXAlignment.Left

    local selectedDevice = "PC"
    local deviceButtons = {}
    local function updateDevButtons()
        for dev, btn in pairs(deviceButtons) do
            btn.BackgroundColor3 = dev == selectedDevice and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(60, 60, 120)
        end
    end
    local devs = {"PC", "Mobile"}
    for i, dev in ipairs(devs) do
        local btn = Instance.new("TextButton", main)
        btn.Size = UDim2.new(0.4, -5, 0, 36)
        btn.Position = UDim2.new(0, 10 + (i-1)*170, 0, 175)
        btn.Text = dev == "PC" and "💻 ПК" or "📱 Телефон"
        btn.TextColor3 = Color3.new(1, 1, 1)
        btn.TextSize = 14
        btn.Font = Enum.Font.GothamSemibold
        btn.BackgroundColor3 = Color3.fromRGB(60, 60, 120)
        btn.BorderSizePixel = 0
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
        btn.MouseButton1Click:Connect(function()
            selectedDevice = dev
            updateDevButtons()
        end)
        deviceButtons[dev] = btn
    end

    -- Версия
    local verLabel = Instance.new("TextLabel", main)
    verLabel.Size = UDim2.new(1, -20, 0, 25)
    verLabel.Position = UDim2.new(0, 10, 0, 225)
    verLabel.BackgroundTransparency = 1
    verLabel.Text = "⚙️ Версия / Version:"
    verLabel.TextColor3 = Color3.new(0.9, 0.9, 0.9)
    verLabel.TextSize = 16
    verLabel.Font = Enum.Font.Gotham
    verLabel.TextXAlignment = Enum.TextXAlignment.Left

    local selectedVersion = "v2.1"
    local versionDescriptions = {
        ["v1.0"] = { ru = "Первая стабильная версия.", en = "First stable version.", ua = "Перша стабільна версія." },
        ["v2.0"] = { ru = "Исправлены плавающая кнопка, сброс при P.", en = "Fixed floating button, P reset.", ua = "Виправлено плаваючу кнопку, скидання при P." },
        ["v2.1"] = { ru = "Все локации Guide в одной вкладке.", en = "All Guide locations in one tab.", ua = "Усі локації Guide в одній вкладці." }
    }

    local openVersionsBtn = Instance.new("TextButton", main)
    openVersionsBtn.Size = UDim2.new(0, 180, 0, 36)
    openVersionsBtn.Position = UDim2.new(0, 10, 0, 255)
    openVersionsBtn.Text = "📂 Открыть версии..."
    openVersionsBtn.TextColor3 = Color3.new(1, 1, 1)
    openVersionsBtn.TextSize = 14
    openVersionsBtn.Font = Enum.Font.GothamSemibold
    openVersionsBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 140)
    openVersionsBtn.BorderSizePixel = 0
    Instance.new("UICorner", openVersionsBtn).CornerRadius = UDim.new(0, 8)

    local versionsFrame = nil
    local function createVersionsWindow()
        if versionsFrame then versionsFrame:Destroy(); versionsFrame = nil; return end
        versionsFrame = Instance.new("Frame", launcherGui)
        versionsFrame.Size = UDim2.new(0, 300, 0, 250)
        versionsFrame.Position = UDim2.new(0.5, -150, 0.5, -125)
        versionsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 40)
        versionsFrame.BorderSizePixel = 2
        versionsFrame.BorderColor3 = Color3.new(0.5, 0.5, 0.6)
        Instance.new("UICorner", versionsFrame).CornerRadius = UDim.new(0, 12)

        local verTitle = Instance.new("TextLabel", versionsFrame)
        verTitle.Size = UDim2.new(1, 0, 0, 30)
        verTitle.Position = UDim2.new(0, 10, 0, 10)
        verTitle.BackgroundTransparency = 1
        verTitle.Text = "Выберите версию:"
        verTitle.TextColor3 = Color3.new(1,1,1)
        verTitle.TextSize = 16
        verTitle.Font = Enum.Font.GothamBold

        local scroll = Instance.new("ScrollingFrame", versionsFrame)
        scroll.Size = UDim2.new(1, -20, 1, -80)
        scroll.Position = UDim2.new(0, 10, 0, 45)
        scroll.BackgroundTransparency = 1
        scroll.BorderSizePixel = 0
        scroll.CanvasSize = UDim2.new(0,0,0,0)

        local layout = Instance.new("UIListLayout", scroll)
        layout.Padding = UDim.new(0, 8)

        local versions = {"v1.0", "v2.0", "v2.1"}
        for _, ver in ipairs(versions) do
            local btn = Instance.new("TextButton", scroll)
            btn.Size = UDim2.new(1, -10, 0, 40)
            btn.Text = (ver == selectedVersion and "✅ " or "") .. ver
            btn.TextColor3 = Color3.new(1,1,1)
            btn.BackgroundColor3 = ver == selectedVersion and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(60, 60, 120)
            btn.BorderSizePixel = 0
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
            btn.MouseButton1Click:Connect(function()
                selectedVersion = ver
                for _, child in ipairs(scroll:GetChildren()) do
                    if child:IsA("TextButton") then
                        local v = child.Text:gsub("✅ ", "")
                        child.Text = (v == selectedVersion and "✅ " or "") .. v
                        child.BackgroundColor3 = v == selectedVersion and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(60, 60, 120)
                    end
                end
            end)
        end
        scroll.CanvasSize = UDim2.new(0, 0, 0, #versions * 48 + 10)

        local closeBtn = Instance.new("TextButton", versionsFrame)
        closeBtn.Size = UDim2.new(0, 80, 0, 30)
        closeBtn.Position = UDim2.new(0.5, -40, 1, -40)
        closeBtn.Text = "Закрыть"
        closeBtn.BackgroundColor3 = Color3.new(0.5, 0.2, 0.2)
        closeBtn.BorderSizePixel = 0
        Instance.new("UICorner", closeBtn).CornerRadius = UDim.new(0, 6)
        closeBtn.MouseButton1Click:Connect(function()
            versionsFrame:Destroy()
            versionsFrame = nil
        end)
    end

    openVersionsBtn.MouseButton1Click:Connect(createVersionsWindow)

    local execBtn = Instance.new("TextButton", main)
    execBtn.Size = UDim2.new(0.8, 0, 0, 45)
    execBtn.Position = UDim2.new(0.1, 0, 1, -55)
    execBtn.Text = "🚀 Execute / Запустить"
    execBtn.TextColor3 = Color3.new(1, 1, 1)
    execBtn.TextSize = 18
    execBtn.Font = Enum.Font.GothamBold
    execBtn.BackgroundColor3 = Color3.fromRGB(50, 200, 80)
    execBtn.BorderSizePixel = 0
    Instance.new("UICorner", execBtn).CornerRadius = UDim.new(0, 12)
    execBtn.MouseButton1Click:Connect(function()
        _G.TeleportHubSettings = {language = selectedLang, device = selectedDevice, version = selectedVersion}
        launcherGui:Destroy()
        if selectedVersion == "v1.0" then StartEscanorHub_v1()
        elseif selectedVersion == "v2.0" then StartEscanorHub_v2()
        else StartEscanorHub_v2_1() end
    end)

    -- Перетаскивание лаунчера за любую область
    local dragging = false
    local dragStart, startPos
    main.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = main.Position
        end
    end)
    main.InputEnded:Connect(function() dragging = false end)
    UserInput.InputChanged:Connect(function(input, gameProcessed)
        if gameProcessed then return end
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Клавиша P в лаунчере
    UserInput.InputBegan:Connect(function(input, gp)
        if gp then return end
        if input.KeyCode == Enum.KeyCode.P then
            _G.TeleportHubSettings = nil
            launcherGui:Destroy()
            LP:Chat("📌 Настройки сброшены. При следующем запуске появится лаунчер.")
        end
    end)

    updateLangButtons()
    updateDevButtons()
end

-- ===== ЗАГЛУШКИ ПРЕДЫДУЩИХ ВЕРСИЙ =====
function StartEscanorHub_v1() StartEscanorHub_Common(true) end
function StartEscanorHub_v2() StartEscanorHub_Common(false) end
function StartEscanorHub_v2_1() StartEscanorHub_Common(false) end

-- ===== ОБЩАЯ РЕАЛИЗАЦИЯ ХАБА =====
function StartEscanorHub_Common(legacyMode)
    local settings = _G.TeleportHubSettings or {language = "en", device = "PC"}
    local isMobile = (settings.device == "Mobile")
    local currentLang = settings.language or "en"

    -- ===== НАСТРОЙКИ =====
    local guiTransparency = 0.1
    local teleportSpeed = 50000
    local starsEnabled = true
    local currentTab = "players"
    local sortByDistance = false
    local searchFilter = ""
    local savedPosition = nil
    local autoTeleportActive = false
    local autoTargetPlayer = nil
    local autoLoopConnection = nil
    local instantBtn = nil
    local settingsWindow = nil
    local playerTPOffset = 2

    local guiDestroyed = false
    local sg = nil
    local mainFrame = nil
    local btns = {}
    local bc = nil
    local lf = nil
    local lay = nil
    local hue = 0
    local connection = nil
    local locations = {}
    local locationListFrame = nil
    local locationBtns = {}
    local coordsLabel = nil
    local sortTimer = nil
    local langElements = {}
    local themeElements = {}

    local floatingGui = nil
    local floatingButton = nil

    -- Темы
    local currentTheme = "default"
    local themes = {
        default = {
            mainBg = Color3.fromRGB(25,28,40), mainGradStart = Color3.fromRGB(25,28,40), mainGradEnd = Color3.fromRGB(15,18,30),
            topBg = Color3.fromRGB(40,45,60), topGradStart = Color3.fromRGB(60,65,80), topGradEnd = Color3.fromRGB(40,45,60),
            tabActive = Color3.fromRGB(120,120,220), tabInactive = Color3.fromRGB(70,70,130),
            borderColor = Color3.new(1,1,1), textColor = Color3.new(1,1,1),
        },
        dark = {
            mainBg = Color3.fromRGB(10,10,15), mainGradStart = Color3.fromRGB(10,10,15), mainGradEnd = Color3.fromRGB(5,5,10),
            topBg = Color3.fromRGB(20,20,30), topGradStart = Color3.fromRGB(30,30,45), topGradEnd = Color3.fromRGB(20,20,30),
            tabActive = Color3.fromRGB(80,80,150), tabInactive = Color3.fromRGB(50,50,90),
            borderColor = Color3.new(0.5,0.5,0.5), textColor = Color3.new(0.9,0.9,0.9),
        },
        pink = {
            mainBg = Color3.fromRGB(40,20,30), mainGradStart = Color3.fromRGB(40,20,30), mainGradEnd = Color3.fromRGB(30,15,25),
            topBg = Color3.fromRGB(60,30,45), topGradStart = Color3.fromRGB(80,40,60), topGradEnd = Color3.fromRGB(60,30,45),
            tabActive = Color3.fromRGB(220,120,180), tabInactive = Color3.fromRGB(150,70,120),
            borderColor = Color3.new(1,0.8,0.9), textColor = Color3.new(1,0.9,0.95),
        },
        green = {
            mainBg = Color3.fromRGB(20,35,25), mainGradStart = Color3.fromRGB(20,35,25), mainGradEnd = Color3.fromRGB(15,28,20),
            topBg = Color3.fromRGB(30,50,35), topGradStart = Color3.fromRGB(40,65,45), topGradEnd = Color3.fromRGB(30,50,35),
            tabActive = Color3.fromRGB(100,200,120), tabInactive = Color3.fromRGB(60,130,80),
            borderColor = Color3.new(0.5,1,0.6), textColor = Color3.new(0.9,1,0.9),
        },
        blue = {
            mainBg = Color3.fromRGB(15,20,40), mainGradStart = Color3.fromRGB(15,20,40), mainGradEnd = Color3.fromRGB(10,15,30),
            topBg = Color3.fromRGB(20,30,60), topGradStart = Color3.fromRGB(30,45,80), topGradEnd = Color3.fromRGB(20,30,60),
            tabActive = Color3.fromRGB(80,120,255), tabInactive = Color3.fromRGB(50,80,180),
            borderColor = Color3.new(0.6,0.7,1), textColor = Color3.new(0.85,0.9,1),
        }
    }

    local locationTranslations = {
        -- ... все переводы ...
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
        ["Спавн"] = { ru = "Спавн", en = "Spawn", ua = "Спавн" },
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
    }

    local lang = {
        en = {
            tab_players = "Players", tab_locations = "Locations", tab_places = "Places", tab_help = "Help",
            search_placeholder = "Search players...", sort_name = "ByName", sort_dist = "ByDist",
            plate_location = "Plate (one-time)", save_loc = "+ Save current location",
            coords_label = "📍 Your coords: ---", coords_input = "Coords:", tp_btn = "TP",
            invalid_coords = "Invalid coordinates. Example: 220, -16, -15",
            pos_saved = "Position saved!", cant_save = "Can't save position", no_saved = "No saved position",
            select_player_first = "Select a player first (click on name)",
            auto_on = "Auto teleport ON", auto_off = "Auto teleport OFF",
            settings_title = "Settings", gui_size = "GUI Size:", small = "Small", medium = "Medium", large = "Large",
            transparency = "Background transparency:", speed = "TP speed:",
            theme = "Theme:", theme_default = "Default", theme_dark = "Dark", theme_pink = "Pink",
            theme_green = "Green", theme_blue = "Blue",
            tp_offset = "TP offset (-100..100):",
            place_id_label = "📍 Place ID: ",
            teleport_btn = "TP →",
            close = "Close",
            help_title = "How to use Escanor HUB",
            help_text = [[
• TAB "Players" – click on any player name to teleport to him.
  Use search field and sorting (ByName/ByDist).
  Button "A" (green checkmark) – enables auto-teleport mode.

• TAB "Locations" – list of saved locations. Click to teleport.
  "Plate" – teleports to the moving platform (one-time).
  "+ Save current location" – saves your current position.
  Your coordinates are shown in real time below.

• TAB "Places" – quick teleport to other games by Place ID.

• TOP BUTTONS:
  X – hide GUI (floating button appears). K – bring GUI back.
  R – refresh player list.
  A – toggle auto-teleport (green when active).
  S – open settings.
  M – save current position.
  L – load saved position.

• HOTKEYS:
  K – toggle GUI / floating button.
  M – save position.
  L – toggle auto-teleport.
  P – permanently delete GUI and reset settings (launcher will appear on restart).

Settings: change GUI size, transparency, speed, theme, and TP offset (-100 to 100).
            ]],
        },
        ru = {
            tab_players = "Игроки", tab_locations = "Локации", tab_places = "Плейсы", tab_help = "Помощь",
            search_placeholder = "Поиск игроков...", sort_name = "По имени", sort_dist = "По дистанции",
            plate_location = "Тарелка (разово)", save_loc = "+ Сохранить текущее место",
            coords_label = "📍 Твои координаты: ---", coords_input = "Коорд:", tp_btn = "ТП",
            invalid_coords = "Некорректные координаты. Пример: 220, -16, -15",
            pos_saved = "Позиция сохранена!", cant_save = "Не удалось сохранить", no_saved = "Нет сохранённой позиции",
            select_player_first = "Сначала выберите игрока (нажмите на кнопку с ником)",
            auto_on = "Авто-телепорт включён", auto_off = "Авто-телепорт выключён",
            settings_title = "Настройки", gui_size = "Размер GUI:", small = "Маленький", medium = "Средний", large = "Большой",
            transparency = "Прозрачность фона:", speed = "Скорость ТП:",
            theme = "Тема:", theme_default = "Стандарт", theme_dark = "Тёмная", theme_pink = "Розовая",
            theme_green = "Зелёная", theme_blue = "Синяя",
            tp_offset = "ТП отступ (-100..100):",
            place_id_label = "📍 Place ID: ",
            teleport_btn = "ТП →",
            close = "Закрыть",
            help_title = "Как пользоваться Escanor HUB",
            help_text = [[
• ВКЛАДКА "Игроки" – кликните по имени игрока для телепортации.
  Используйте поиск и сортировку (По имени/По дистанции).
  Кнопка "A" (зелёная галочка) – включает режим авто-телепорта.

• ВКЛАДКА "Локации" – список сохранённых мест. Кликните для телепортации.
  "Тарелка" – разовая телепортация на платформу.
  "+ Сохранить текущее место" – сохраняет вашу текущую позицию.
  Ваши координаты отображаются ниже в реальном времени.

• ВКЛАДКА "Плейсы" – быстрая телепортация в другие игры по ID.

• ВЕРХНИЕ КНОПКИ:
  X – скрыть GUI (появляется плавающая иконка). K – вернуть GUI.
  R – обновить список игроков.
  A – авто-телепорт.
  S – настройки.
  M – сохранить позицию.
  L – загрузить сохранённую позицию.

• ГОРЯЧИЕ КЛАВИШИ:
  K – переключить GUI / плавающую кнопку.
  M – сохранить позицию.
  L – авто-телепорт.
  P – безвозвратно удалить GUI и сбросить настройки (при следующем запуске появится лаунчер).

В настройках можно изменить размер GUI, прозрачность, скорость, тему и дистанцию до игрока (-100..100).
            ]],
        },
        ua = {
            tab_players = "Гравці", tab_locations = "Локації", tab_places = "Плейси", tab_help = "Допомога",
            search_placeholder = "Пошук гравців...", sort_name = "За ім'ям", sort_dist = "За відстанню",
            plate_location = "Тарілка (разово)", save_loc = "+ Зберегти поточне місце",
            coords_label = "📍 Твої координати: ---", coords_input = "Коорд:", tp_btn = "ТП",
            invalid_coords = "Некоректні координати. Приклад: 220, -16, -15",
            pos_saved = "Позицію збережено!", cant_save = "Не вдалося зберегти", no_saved = "Немає збереженої позиції",
            select_player_first = "Спершу виберіть гравця (натисніть на кнопку з ніком)",
            auto_on = "Авто-телепорт увімкнено", auto_off = "Авто-телепорт вимкнено",
            settings_title = "Налаштування", gui_size = "Розмір GUI:", small = "Маленький", medium = "Середній", large = "Великий",
            transparency = "Прозорість фону:", speed = "Швидкість ТП:",
            theme = "Тема:", theme_default = "Стандарт", theme_dark = "Темна", theme_pink = "Рожева",
            theme_green = "Зелена", theme_blue = "Синя",
            tp_offset = "ТП відступ (-100..100):",
            place_id_label = "📍 Place ID: ",
            teleport_btn = "ТП →",
            close = "Закрити",
            help_title = "Як користуватися Escanor HUB",
            help_text = [[
• ВКЛАДКА "Гравці" – натисніть на ім'я гравця для телепортації.
  Використовуйте пошук і сортування (За ім'ям/За відстанню).
  Кнопка "A" (зелена галочка) – вмикає режим авто-телепорту.

• ВКЛАДКА "Локації" – список збережених місць. Натисніть для телепортації.
  "Тарілка" – разова телепортація на платформу.
  "+ Зберегти поточне місце" – зберігає вашу поточну позицію.
  Ваші координати відображаються нижче в реальному часі.

• ВКЛАДКА "Плейси" – швидка телепортація в інші ігри за ID.

• ВЕРХНІ КНОПКИ:
  X – приховати GUI (з'являється плавуча іконка). K – повернути GUI.
  R – оновити список гравців.
  A – авто-телепорт.
  S – налаштування.
  M – зберегти позицію.
  L – завантажити збережену позицію.

• ГАРЯЧІ КЛАВІШІ:
  K – перемкнути GUI / плавучу кнопку.
  M – зберегти позицію.
  L – авто-телепорт.
  P – безповоротно видалити GUI та скинути налаштування (при наступному запуску з'явиться лаунчер).

У налаштуваннях можна змінити розмір GUI, прозорість, швидкість, тему та дистанцію до гравця (-100..100).
            ]],
        }
    }

    local function getText(key)
        return lang[currentLang] and lang[currentLang][key] or lang["en"][key] or key
    end

    local function getLocalizedLocationName(originalName)
        local entry = locationTranslations[originalName]
        if entry then return entry[currentLang] or originalName end
        return originalName
    end

    -- ===== ОБЩИЕ ЛОКАЦИИ (включая Guide) =====
    local function getLocationsForPlace(placeId)
        if placeId == 6403373529 then
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
        elseif placeId == 7234087065 then
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
        elseif placeId == 115782629143468 then
            return {
                {name="Прохождение", cframe=CFrame.new(0, 200, -2), isDefault=true}
            }
        elseif placeId == 127174121130060 then
            return getLocationsForPlace(6403373529)
        elseif placeId == 18550498098 then
            -- Все локации Guide одним списком
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
        else
            return {}
        end
    end

    -- ========== ПОСЛЕДОВАТЕЛЬНЫЙ ТЕЛЕПОРТ ==========
    local function startSequentialTeleport(waypoints)
        task.spawn(function()
            for i, cf in ipairs(waypoints) do
                local myChar = LP.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myHrp then
                    myHrp.CFrame = cf
                end
                task.wait(1)
            end
        end)
    end

    -- ========== ФУНКЦИИ ТЕЛЕПОРТАЦИИ ==========
    local function SmartTP(targetCF)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not (char and hrp) then return end
        local distance = (targetCF.Position - hrp.Position).Magnitude
        if distance < 5 then return end
        local duration = distance / teleportSpeed
        local tween = TweenService:Create(hrp, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = targetCF})
        tween:Play()
        tween.Completed:Wait()
        for i = 1, math.random(2,4) do
            hrp.CFrame = hrp.CFrame + Vector3.new(math.random(-50,50)/100, math.random(-20,20)/100, math.random(-50,50)/100)
            task.wait(0.01)
        end
        hrp.CFrame = targetCF
    end

    local function teleportToPlate()
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and v.Name == "MovingPlate" then
                SmartTP(v.CFrame * CFrame.new(0,0,2))
                return
            end
        end
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") and (v.Name:lower():find("plate") or v.Name:lower():find("платформа")) then
                if not v:IsDescendantOf(workspace:FindFirstChild("Tools") or Instance.new("Folder")) then
                    SmartTP(v.CFrame * CFrame.new(0,0,2))
                    return
                end
            end
        end
        LP:Chat(getText("plate_location").." not found")
    end

    local function parseNumber(str)
        return tonumber(string.gsub(str, ",", "."))
    end

    local function addCurrentLocation()
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return end
        local name = "Location " .. (#locations + 1)
        table.insert(locations, {name = name, cframe = hrp.CFrame, isDefault = false})
        refreshLocationsList()
    end

    local function teleportToCoordinates(inputText)
        if not inputText or inputText == "" then return end
        local x,y,z = nil,nil,nil
        for num in string.gmatch(inputText, "[-]?%d+[.]?%d*") do
            if x == nil then x = parseNumber(num)
            elseif y == nil then y = parseNumber(num)
            elseif z == nil then z = parseNumber(num)
            else break end
        end
        if x and y and z then SmartTP(CFrame.new(x,y,z) * CFrame.new(0,0,2))
        else LP:Chat(getText("invalid_coords")) end
    end

    local function updateCoordsLabel()
        if not coordsLabel then return end
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp then
            local pos = hrp.Position
            coordsLabel.Text = string.format("📍 X: %.1f, Y: %.1f, Z: %.1f", pos.X, pos.Y, pos.Z)
        else
            coordsLabel.Text = "📍 Ожидание персонажа..."
        end
    end

    local function getDistanceToPlayer(p)
        local char = LP.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then return 1e9 end
        local tChar = p.Character
        local tHrp = tChar and tChar:FindFirstChild("HumanoidRootPart")
        if not tHrp then return 1e9 end
        return (hrp.Position - tHrp.Position).Magnitude
    end

    local function refreshButtons()
        if not bc then return end
        for _, v in ipairs(btns) do v:Destroy() end
        btns = {}
        local playersList = {}
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LP and (searchFilter == "" or string.find(string.lower(p.Name), string.lower(searchFilter))) then
                table.insert(playersList, p)
            end
        end
        if sortByDistance then
            table.sort(playersList, function(a,b) return getDistanceToPlayer(a) < getDistanceToPlayer(b) end)
        else
            table.sort(playersList, function(a,b) return a.Name < b.Name end)
        end
        for _, p in ipairs(playersList) do
            local dist = getDistanceToPlayer(p)
            local distText = (dist < 1000) and string.format(" (%.1f m)", dist) or string.format(" (%.2f km)", dist/1000)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -10, 0, isMobile and 35 or 42)
            btn.Position = UDim2.new(0, 5, 0, 0)
            btn.Text = p.Name .. distText
            btn.TextColor3 = Color3.new(1,1,1)
            btn.TextSize = isMobile and 12 or 14
            btn.Font = Enum.Font.GothamSemibold
            btn.BackgroundColor3 = Color3.new(1,0,0)
            btn.BackgroundTransparency = 0.2
            btn.BorderSizePixel = 0
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0,6)
            corner.Parent = btn
            btn.Parent = bc
            btn.MouseButton1Click:Connect(function()
                if autoTeleportActive then
                    if autoTargetPlayer == p then stopAutoTeleport() else startAutoTeleport(p) end
                else
                    local tChar = p.Character
                    if tChar and tChar:FindFirstChild("HumanoidRootPart") then
                        SmartTP(tChar.HumanoidRootPart.CFrame * CFrame.new(0,0,playerTPOffset))
                    end
                    autoTargetPlayer = p
                    local oc = btn.BackgroundColor3
                    btn.BackgroundColor3 = Color3.new(0.3,0.3,0.3)
                    task.wait(0.1)
                    btn.BackgroundColor3 = oc
                end
            end)
            table.insert(btns, btn)
        end
        local th = #btns * ((isMobile and 35 or 42) + (lay and lay.Padding.Offset or 6)) + 10
        if lf then lf.CanvasSize = UDim2.new(0,0,0,th) end
    end

    local function stopAutoTeleport()
        if autoLoopConnection then autoLoopConnection:Disconnect() end
        autoLoopConnection = nil
        autoTeleportActive = false
        autoTargetPlayer = nil
        if instantBtn then
            instantBtn.BackgroundColor3 = Color3.new(0.3,0.3,0.3)
            instantBtn.Text = "A"
        end
        LP:Chat(getText("auto_off"))
    end

    local function startAutoTeleport(targetPlayer)
        if not targetPlayer then return end
        autoTargetPlayer = targetPlayer
        autoTeleportActive = true
        if autoLoopConnection then autoLoopConnection:Disconnect() end
        autoLoopConnection = RunService.Heartbeat:Connect(function()
            if autoTeleportActive and autoTargetPlayer and autoTargetPlayer.Character and autoTargetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                local targetCF = autoTargetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,playerTPOffset)
                local myChar = LP.Character
                local myHrp = myChar and myChar:FindFirstChild("HumanoidRootPart")
                if myHrp then myHrp.CFrame = targetCF end
            end
        end)
        if instantBtn then
            instantBtn.BackgroundColor3 = Color3.new(0,0.7,0)
            instantBtn.Text = "V"
        end
        LP:Chat(getText("auto_on"))
    end

    -- ========== ПРИМЕНЕНИЕ ТЕМЫ ==========
    local function applyTheme(themeName)
        local t = themes[themeName]
        if not t then return end
        currentTheme = themeName
        if mainFrame then
            mainFrame.BackgroundColor3 = t.mainBg
            mainFrame.BorderColor3 = t.borderColor
        end
        if themeElements.mainGradient then
            themeElements.mainGradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, t.mainGradStart),
                ColorSequenceKeypoint.new(1, t.mainGradEnd)
            }
        end
        if themeElements.topBar then themeElements.topBar.BackgroundColor3 = t.topBg end
        if themeElements.topGradient then
            themeElements.topGradient.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, t.topGradStart),
                ColorSequenceKeypoint.new(1, t.topGradEnd)
            }
        end
        if themeElements.tabPlayers then themeElements.tabPlayers.BackgroundColor3 = (currentTab=="players") and t.tabActive or t.tabInactive end
        if themeElements.tabLocations then themeElements.tabLocations.BackgroundColor3 = (currentTab=="locations") and t.tabActive or t.tabInactive end
        if themeElements.tabPlaces then themeElements.tabPlaces.BackgroundColor3 = (currentTab=="places") and t.tabActive or t.tabInactive end
        if themeElements.tabHelp then themeElements.tabHelp.BackgroundColor3 = (currentTab=="help") and t.tabActive or t.tabInactive end
        if themeElements.titleLabel then themeElements.titleLabel.TextColor3 = t.textColor end
    end

    -- ========== ПЛАВАЮЩАЯ КНОПКА ==========
    local function createFloatingButton()
        if floatingGui then return end
        floatingGui = Instance.new("ScreenGui")
        floatingGui.Name = "FloatingButton"
        floatingGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        floatingGui.ResetOnSpawn = false
        pcall(function() floatingGui.Parent = LP:WaitForChild("PlayerGui") end)
        if not floatingGui.Parent then return end

        local btnSize = isMobile and 60 or 50
        floatingButton = Instance.new("TextButton")
        floatingButton.Size = UDim2.new(0, btnSize, 0, btnSize)
        floatingButton.Position = UDim2.new(0.95, -btnSize/2, 0.05, btnSize/2)
        floatingButton.Text = "🛸"
        floatingButton.TextColor3 = Color3.new(1, 1, 1)
        floatingButton.TextSize = isMobile and 36 or 30
        floatingButton.Font = Enum.Font.GothamBold
        floatingButton.BackgroundColor3 = Color3.fromRGB(80, 50, 180)
        floatingButton.BackgroundTransparency = 0.15
        floatingButton.BorderSizePixel = 2
        floatingButton.BorderColor3 = Color3.new(1, 1, 1)
        local corner = Instance.new("UICorner", floatingButton)
        corner.CornerRadius = UDim.new(1, 0)
        floatingButton.Parent = floatingGui

        local dragging = false
        local dragStart, startPos
        floatingButton.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = floatingButton.Position
            end
        end)
        floatingButton.InputEnded:Connect(function() dragging = false end)
        UserInput.InputChanged:Connect(function(input)
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                floatingButton.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)
        floatingButton.MouseButton1Click:Connect(function()
            if not dragging then showMainGUI() end
        end)
    end

    local function showMainGUI()
        if mainFrame then mainFrame.Visible = true end
        if floatingGui then floatingGui:Destroy(); floatingGui = nil; floatingButton = nil end
    end

    local function hideMainGUI()
        if mainFrame then mainFrame.Visible = false end
        if not floatingGui then createFloatingButton() end
    end

    local function destroyGUI()
        if guiDestroyed then return end
        guiDestroyed = true
        if sg then sg:Destroy() end
        sg = nil; mainFrame = nil; btns = {}; locationBtns = {}
        if settingsWindow then settingsWindow:Destroy() end
        settingsWindow = nil
        if connection then connection:Disconnect() end
        connection = nil
        if sortTimer then sortTimer:Disconnect() end
        sortTimer = nil
        if floatingGui then floatingGui:Destroy(); floatingGui = nil; floatingButton = nil end
        _G.TeleportHubSettings = nil
        LP:Chat("📌 Escanor HUB GUI удалён. Настройки сброшены.")
    end

    -- ========== СОЗДАНИЕ ГРАФИЧЕСКОГО ИНТЕРФЕЙСА ЛОКАЦИЙ ==========
    local function refreshLocationsList()
        if not locationListFrame then return end
        for _, v in ipairs(locationBtns) do v:Destroy() end
        locationBtns = {}

        for i, loc in ipairs(locations) do
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(1, -10, 0, isMobile and 35 or 42)
            btn.Position = UDim2.new(0, 5, 0, 0)
            local displayName = getLocalizedLocationName(loc.name)
            if loc.waypoints then displayName = displayName .. " (sequence)" end
            btn.Text = displayName .. (loc.cframe and (" [" .. math.floor(loc.cframe.X) .. ", " .. math.floor(loc.cframe.Y) .. ", " .. math.floor(loc.cframe.Z) .. "]") or "")
            btn.TextColor3 = Color3.new(1,1,1)
            btn.TextSize = isMobile and 12 or 14
            btn.Font = Enum.Font.GothamSemibold
            btn.BackgroundColor3 = Color3.new(0.2,0.5,0.8)
            btn.BackgroundTransparency = 0.2
            btn.BorderSizePixel = 0
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0,6)
            corner.Parent = btn
            btn.Parent = locationListFrame

            if not loc.isDefault then
                local delBtn = Instance.new("TextButton")
                delBtn.Size = UDim2.new(0,28,0,28)
                delBtn.Position = UDim2.new(1,-33,0.5,-14)
                delBtn.Text = "X"
                delBtn.TextColor3 = Color3.new(1,1,1)
                delBtn.TextSize = 14
                delBtn.BackgroundColor3 = Color3.new(0.5,0.1,0.1)
                delBtn.BorderSizePixel = 0
                local delCorner = Instance.new("UICorner")
                delCorner.CornerRadius = UDim.new(0,5)
                delCorner.Parent = delBtn
                delBtn.Parent = btn
                delBtn.MouseButton1Click:Connect(function()
                    table.remove(locations, i)
                    refreshLocationsList()
                end)
            end

            btn.MouseButton1Click:Connect(function()
                if loc.waypoints then
                    startSequentialTeleport(loc.waypoints)
                elseif loc.cframe then
                    if loc.name == "Plate" then
                        teleportToPlate()
                    else
                        SmartTP(loc.cframe * CFrame.new(0,0,2))
                    end
                end
            end)
            table.insert(locationBtns, btn)
        end
        local th = #locationBtns * ((isMobile and 35 or 42) + 6) + 10
        local scroll = locationListFrame.Parent
        if scroll and scroll:IsA("ScrollingFrame") then scroll.CanvasSize = UDim2.new(0,0,0,th) end
    end

    -- ========== СБОРКА GUI ==========
    local function createGUI()
        if guiDestroyed then return end
        if sg and sg.Parent then sg:Destroy() end

        sg = Instance.new("ScreenGui")
        sg.Name = "EscanorHUB"
        sg.ResetOnSpawn = false
        pcall(function() sg.Parent = LP:WaitForChild("PlayerGui") end)

        local guiWidth = isMobile and 380 or 450
        local guiHeight = isMobile and 420 or 580   -- значительно ниже для мобильных

        mainFrame = Instance.new("Frame")
        mainFrame.Size = UDim2.new(0, guiWidth, 0, guiHeight)
        mainFrame.Position = UDim2.new(0.5, -guiWidth/2, 0.5, -guiHeight/2)
        mainFrame.BackgroundColor3 = Color3.fromRGB(25,28,40)
        mainFrame.BackgroundTransparency = guiTransparency
        mainFrame.BorderSizePixel = 2
        mainFrame.BorderColor3 = themes[currentTheme].borderColor
        mainFrame.ClipsDescendants = false
        local frameCorner = Instance.new("UICorner")
        frameCorner.CornerRadius = UDim.new(0,12)
        frameCorner.Parent = mainFrame

        local mainGradient = Instance.new("UIGradient")
        mainGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(25,28,40)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(15,18,30))
        }
        mainGradient.Rotation = 45
        mainGradient.Parent = mainFrame
        themeElements.mainGradient = mainGradient

        mainFrame.Parent = sg

        local topBar = Instance.new("Frame")
        topBar.Size = UDim2.new(1,0,0, isMobile and 44 or 48)
        topBar.BackgroundColor3 = Color3.fromRGB(40,45,60)
        topBar.BorderSizePixel = 0
        local topCorner = Instance.new("UICorner")
        topCorner.CornerRadius = UDim.new(0,10)
        topCorner.Parent = topBar
        topBar.Parent = mainFrame
        themeElements.topBar = topBar

        local topGradient = Instance.new("UIGradient")
        topGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, Color3.fromRGB(60,65,80)),
            ColorSequenceKeypoint.new(1, Color3.fromRGB(40,45,60))
        }
        topGradient.Parent = topBar
        themeElements.topGradient = topGradient

        local titleLabel = Instance.new("TextLabel")
        titleLabel.Size = UDim2.new(1, -210, 0, 20)
        titleLabel.Position = UDim2.new(0, 10, 0, 0)
        titleLabel.BackgroundTransparency = 1
        titleLabel.Text = "Escanor HUB 🔥"
        titleLabel.TextColor3 = Color3.new(1,1,1)
        titleLabel.TextSize = isMobile and 16 or 22
        titleLabel.Font = Enum.Font.GothamBold
        titleLabel.TextXAlignment = Enum.TextXAlignment.Left
        titleLabel.Parent = topBar
        themeElements.titleLabel = titleLabel

        local subTitle = Instance.new("TextLabel")
        subTitle.Size = UDim2.new(1, -210, 0, 14)
        subTitle.Position = UDim2.new(0, 10, 0, isMobile and 20 or 22)
        subTitle.BackgroundTransparency = 1
        subTitle.Text = "🌀 teleport"
        subTitle.TextColor3 = Color3.new(0.8, 0.8, 1)
        subTitle.TextSize = isMobile and 10 or 12
        subTitle.Font = Enum.Font.Gotham
        subTitle.TextXAlignment = Enum.TextXAlignment.Left
        subTitle.Parent = topBar

        local placeIdLabel = Instance.new("TextLabel")
        placeIdLabel.Size = UDim2.new(1, -210, 0, 16)
        placeIdLabel.Position = UDim2.new(0, 10, 0, isMobile and 34 or 38)
        placeIdLabel.BackgroundTransparency = 1
        placeIdLabel.Text = getText("place_id_label") .. tostring(game.PlaceId)
        placeIdLabel.TextColor3 = Color3.new(0.8, 0.8, 1)
        placeIdLabel.TextSize = isMobile and 10 or 12
        placeIdLabel.Font = Enum.Font.Gotham
        placeIdLabel.TextXAlignment = Enum.TextXAlignment.Left
        placeIdLabel.Parent = topBar
        _G.PlaceIdLabel = placeIdLabel

        local btnSize = isMobile and 28 or 32
        local function makeTopBtn(xOffset, text, color)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, btnSize, 0, btnSize)
            btn.Position = UDim2.new(1, xOffset, 0, (topBar.Size.Y.Offset - btnSize)/2)
            btn.Text = text
            btn.TextColor3 = Color3.new(1,1,1)
            btn.TextSize = isMobile and 14 or 16
            btn.BackgroundColor3 = color
            btn.BackgroundTransparency = 0.15
            btn.BorderSizePixel = 0
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0,6)
            corner.Parent = btn
            btn.Parent = topBar
            return btn
        end

        local closeBtn = makeTopBtn(-38-5, "X", Color3.new(0.6,0.15,0.15))
        local refreshBtn = makeTopBtn(-76-10, "R", Color3.new(0.15,0.5,0.15))
        instantBtn = makeTopBtn(-114-15, "A", Color3.new(0.3,0.3,0.3))
        local settingsBtn = makeTopBtn(-152-20, "S", Color3.new(0.2,0.2,0.4))
        local savePosBtn = makeTopBtn(-190-25, "M", Color3.new(0.25,0.25,0.25))
        local loadPosBtn = makeTopBtn(-228-30, "L", Color3.new(0.25,0.25,0.25))

        -- Вкладки
        local tabBar = Instance.new("Frame")
        tabBar.Size = UDim2.new(1, -20, 0, isMobile and 30 or 34)
        tabBar.Position = UDim2.new(0, 10, 0, isMobile and 50 or 60)
        tabBar.BackgroundTransparency = 1
        tabBar.Parent = mainFrame

        local function makeTab(x, width, text)
            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, width, 1, 0)
            btn.Position = UDim2.new(0, x, 0, 0)
            btn.Text = text
            btn.TextColor3 = Color3.new(1,1,1)
            btn.TextSize = isMobile and 11 or 13
            btn.Font = Enum.Font.GothamBold
            btn.BackgroundColor3 = Color3.fromRGB(70, 70, 130)
            btn.BackgroundTransparency = 0.25
            btn.BorderSizePixel = 0
            local corner = Instance.new("UICorner")
            corner.CornerRadius = UDim.new(0, 6)
            corner.Parent = btn
            local tabGrad = Instance.new("UIGradient")
            tabGrad.Color = ColorSequence.new{
                ColorSequenceKeypoint.new(0, Color3.fromRGB(100,100,180)),
                ColorSequenceKeypoint.new(1, Color3.fromRGB(70,70,140))
            }
            tabGrad.Parent = btn
            btn.Parent = tabBar
            return btn
        end

        local tabPlayers = makeTab(0, isMobile and 60 or 80, getText("tab_players"))
        local tabLocations = makeTab(isMobile and 65 or 85, isMobile and 60 or 80, getText("tab_locations"))
        local tabPlaces = makeTab(isMobile and 130 or 170, isMobile and 55 or 70, getText("tab_places"))
        local tabHelp = makeTab(isMobile and 190 or 245, isMobile and 55 or 70, getText("tab_help"))

        themeElements.tabPlayers = tabPlayers
        themeElements.tabLocations = tabLocations
        themeElements.tabPlaces = tabPlaces
        themeElements.tabHelp = tabHelp

        -- Контентные области
        local contentY = isMobile and 85 or 100
        local playersContent = Instance.new("Frame")
        playersContent.Size = UDim2.new(1, -20, 1, -contentY-10)
        playersContent.Position = UDim2.new(0, 10, 0, contentY)
        playersContent.BackgroundTransparency = 1
        playersContent.Parent = mainFrame

        local locationsContent = Instance.new("Frame")
        locationsContent.Size = UDim2.new(1, -20, 1, -contentY-10)
        locationsContent.Position = UDim2.new(0, 10, 0, contentY)
        locationsContent.BackgroundTransparency = 1
        locationsContent.Visible = false
        locationsContent.Parent = mainFrame

        local placesContent = Instance.new("Frame")
        placesContent.Size = UDim2.new(1, -20, 1, -contentY-10)
        placesContent.Position = UDim2.new(0, 10, 0, contentY)
        placesContent.BackgroundTransparency = 1
        placesContent.Visible = false
        placesContent.Parent = mainFrame

        local helpContent = Instance.new("Frame")
        helpContent.Size = UDim2.new(1, -20, 1, -contentY-10)
        helpContent.Position = UDim2.new(0, 10, 0, contentY)
        helpContent.BackgroundTransparency = 1
        helpContent.Visible = false
        helpContent.Parent = mainFrame

        -- Players tab
        local searchFrame = Instance.new("Frame")
        searchFrame.Size = UDim2.new(1, -10, 0, isMobile and 50 or 30)
        searchFrame.Position = UDim2.new(0, 5, 0, 5)
        searchFrame.BackgroundTransparency = 1
        searchFrame.Parent = playersContent

        local searchBox = Instance.new("TextBox")
        if isMobile then
            searchBox.Size = UDim2.new(1, 0, 0, 26)
            searchBox.Position = UDim2.new(0, 0, 0, 0)
        else
            searchBox.Size = UDim2.new(0.7, 0, 1, 0)
            searchBox.Position = UDim2.new(0, 0, 0, 0)
        end
        searchBox.BackgroundColor3 = Color3.new(0.1,0.1,0.12)
        searchBox.Text = ""
        searchBox.TextColor3 = Color3.new(1,1,1)
        searchBox.TextSize = isMobile and 12 or 14
        searchBox.Font = Enum.Font.Gotham
        searchBox.PlaceholderText = getText("search_placeholder")
        searchBox.Parent = searchFrame

        local sortBtn = Instance.new("TextButton")
        if isMobile then
            sortBtn.Size = UDim2.new(1, 0, 0, 24)
            sortBtn.Position = UDim2.new(0, 0, 0, 28)
        else
            sortBtn.Size = UDim2.new(0.25, 0, 1, 0)
            sortBtn.Position = UDim2.new(0.73, 0, 0, 0)
        end
        sortBtn.Text = getText("sort_name")
        sortBtn.TextColor3 = Color3.new(1,1,1)
        sortBtn.TextSize = isMobile and 12 or 14
        sortBtn.BackgroundColor3 = Color3.new(0.2,0.2,0.2)
        sortBtn.BorderSizePixel = 0
        sortBtn.Parent = searchFrame

        local starsContainer = Instance.new("Frame")
        starsContainer.Size = UDim2.new(1, 0, 1, isMobile and -60 or -45)
        starsContainer.Position = UDim2.new(0, 0, 0, isMobile and 55 or 40)
        starsContainer.BackgroundTransparency = 1
        starsContainer.ClipsDescendants = true
        starsContainer.Parent = playersContent
        if starsEnabled then
            for i=1,20 do
                local s = Instance.new("ImageLabel")
                s.Size = UDim2.new(0,math.random(2,4),0,math.random(2,4))
                s.Image = "rbxasset://textures/ui/common/white-circle.png"
                s.ImageColor3 = Color3.new(1,1,1)
                s.ImageTransparency = 0.6
                s.BackgroundTransparency = 1
                s.Position = UDim2.new(math.random(),0,math.random(),0)
                s.Parent = starsContainer
                local function anim()
                    local d = math.random(4,12)
                    local np = UDim2.new(math.random(),0,math.random(),0)
                    local tw = TweenService:Create(s, TweenInfo.new(d, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false, 0), {Position = np})
                    tw:Play()
                    tw.Completed:Connect(anim)
                end
                anim()
            end
        end

        lf = Instance.new("ScrollingFrame")
        lf.Size = UDim2.new(1, -10, 1, -10)
        lf.Position = UDim2.new(0, 5, 0, 5)
        lf.BackgroundTransparency = 1
        lf.BorderSizePixel = 0
        lf.CanvasSize = UDim2.new(0,0,0,0)
        lf.ScrollBarThickness = 3
        lf.ClipsDescendants = false
        lf.Parent = starsContainer

        bc = Instance.new("Frame")
        bc.Size = UDim2.new(1,0,1,0)
        bc.BackgroundTransparency = 1
        bc.Parent = lf

        lay = Instance.new("UIListLayout")
        lay.Padding = UDim.new(0, isMobile and 5 or 8)
        lay.SortOrder = Enum.SortOrder.Name
        lay.Parent = bc

        -- Locations tab
        coordsLabel = Instance.new("TextLabel")
        coordsLabel.Size = UDim2.new(1, -20, 0, 28)
        coordsLabel.Position = UDim2.new(0, 10, 0, 5)
        coordsLabel.BackgroundTransparency = 1
        coordsLabel.Text = getText("coords_label")
        coordsLabel.TextColor3 = Color3.new(1,1,1)
        coordsLabel.TextSize = isMobile and 12 or 14
        coordsLabel.Font = Enum.Font.GothamBold
        coordsLabel.TextXAlignment = Enum.TextXAlignment.Left
        coordsLabel.Parent = locationsContent

        local inputPanel = Instance.new("Frame")
        inputPanel.Size = UDim2.new(1, -20, 0, isMobile and 70 or 50)
        inputPanel.Position = UDim2.new(0, 10, 0, 38)
        inputPanel.BackgroundColor3 = Color3.new(0.15,0.15,0.2)
        inputPanel.BackgroundTransparency = 0.4
        inputPanel.BorderSizePixel = 1
        inputPanel.BorderColor3 = Color3.new(0.5,0.5,0.6)
        inputPanel.Parent = locationsContent

        local coordLabel = Instance.new("TextLabel")
        coordLabel.Size = UDim2.new(0, 50, 0, 26)
        coordLabel.Position = UDim2.new(0, 5, 0, 5)
        coordLabel.BackgroundTransparency = 1
        coordLabel.Text = getText("coords_input")
        coordLabel.TextColor3 = Color3.new(1,1,1)
        coordLabel.TextSize = isMobile and 11 or 12
        coordLabel.Font = Enum.Font.GothamBold
        coordLabel.TextXAlignment = Enum.TextXAlignment.Left
        coordLabel.Parent = inputPanel

        local coordInput = Instance.new("TextBox")
        coordInput.Size = UDim2.new(1, -70, 0, 26)
        coordInput.Position = UDim2.new(0, 5, 0, 32)
        coordInput.BackgroundColor3 = Color3.new(0.05,0.05,0.07)
        coordInput.Text = ""
        coordInput.TextColor3 = Color3.new(1,1,1)
        coordInput.TextSize = isMobile and 11 or 12
        coordInput.Font = Enum.Font.Gotham
        coordInput.PlaceholderText = "X, Y, Z"
        coordInput.Parent = inputPanel

        local tpCoordBtn = Instance.new("TextButton")
        tpCoordBtn.Size = UDim2.new(0, 60, 0, 26)
        tpCoordBtn.Position = UDim2.new(1, -65, 0, 32)
        tpCoordBtn.Text = getText("tp_btn")
        tpCoordBtn.TextSize = isMobile and 11 or 12
        tpCoordBtn.BackgroundColor3 = Color3.new(0.2,0.5,0.2)
        tpCoordBtn.Parent = inputPanel
        tpCoordBtn.MouseButton1Click:Connect(function()
            teleportToCoordinates(coordInput.Text)
        end)

        local locScroll = Instance.new("ScrollingFrame")
        locScroll.Size = UDim2.new(1, -10, 1, isMobile and -175 or -155)
        locScroll.Position = UDim2.new(0, 5, 0, isMobile and 115 or 100)
        locScroll.BackgroundTransparency = 1
        locScroll.BorderSizePixel = 0
        locScroll.CanvasSize = UDim2.new(0,0,0,0)
        locScroll.ScrollBarThickness = 3
        locScroll.Parent = locationsContent

        locationListFrame = Instance.new("Frame")
        locationListFrame.Size = UDim2.new(1,0,1,0)
        locationListFrame.BackgroundTransparency = 1
        locationListFrame.Parent = locScroll

        local locLayout = Instance.new("UIListLayout")
        locLayout.Padding = UDim.new(0, isMobile and 5 or 8)
        locLayout.Parent = locationListFrame

        local addLocBtn = Instance.new("TextButton")
        addLocBtn.Size = UDim2.new(0.9, 0, 0, isMobile and 35 or 40)
        addLocBtn.Position = UDim2.new(0.05, 0, 1, -48)
        addLocBtn.Text = getText("save_loc")
        addLocBtn.TextSize = isMobile and 12 or 14
        addLocBtn.BackgroundColor3 = Color3.new(0.1,0.5,0.1)
        addLocBtn.Parent = locationsContent
        addLocBtn.MouseButton1Click:Connect(addCurrentLocation)

        -- Places tab
        local placesScroll = Instance.new("ScrollingFrame")
        placesScroll.Size = UDim2.new(1, -10, 1, -10)
        placesScroll.Position = UDim2.new(0, 5, 0, 5)
        placesScroll.BackgroundTransparency = 1
        placesScroll.BorderSizePixel = 0
        placesScroll.CanvasSize = UDim2.new(0,0,0,0)
        placesScroll.Parent = placesContent
        local placesLayout = Instance.new("UIListLayout")
        placesLayout.Padding = UDim.new(0, 10)
        placesLayout.Parent = placesScroll

        local placeEntries = {
            {name = "Slap Battles", id = 6403373529},
            {name = "Barzil", id = 7234087065},
            {name = "Untitled Tag", id = 115782629143468},
            {name = "Glove Game", id = 127174121130060},
            {name = "Guide", id = 18550498098},
        }
        for _, place in ipairs(placeEntries) do
            local frame = Instance.new("Frame")
            frame.Size = UDim2.new(1, -10, 0, 40)
            frame.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
            frame.BackgroundTransparency = 0.2
            frame.BorderSizePixel = 0
            Instance.new("UICorner", frame).CornerRadius = UDim.new(0,8)
            frame.Parent = placesScroll

            local label = Instance.new("TextLabel")
            label.Size = UDim2.new(1, -80, 1, 0)
            label.Position = UDim2.new(0, 8, 0, 0)
            label.BackgroundTransparency = 1
            label.Text = place.name .. " (ID: " .. tostring(place.id) .. ")"
            label.TextColor3 = Color3.new(1,1,1)
            label.TextSize = isMobile and 12 or 14
            label.Font = Enum.Font.GothamBold
            label.TextXAlignment = Enum.TextXAlignment.Left
            label.Parent = frame

            local btn = Instance.new("TextButton")
            btn.Size = UDim2.new(0, 65, 1, 0)
            btn.Position = UDim2.new(1, -70, 0, 0)
            btn.Text = getText("teleport_btn")
            btn.TextColor3 = Color3.new(1,1,1)
            btn.BackgroundColor3 = Color3.fromRGB(60, 180, 80)
            btn.BorderSizePixel = 0
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0,6)
            btn.Parent = frame
            btn.MouseButton1Click:Connect(function()
                local ok, err = pcall(function()
                    TeleportService:Teleport(place.id)
                end)
                if not ok then
                    LP:Chat("❌ Ошибка телепортации: " .. tostring(err))
                end
            end)
        end
        placesScroll.CanvasSize = UDim2.new(0, 0, 0, #placeEntries * 50)

        -- Help tab
        local helpScroll = Instance.new("ScrollingFrame")
        helpScroll.Size = UDim2.new(1, -10, 1, -10)
        helpScroll.Position = UDim2.new(0, 5, 0, 5)
        helpScroll.BackgroundTransparency = 1
        helpScroll.BorderSizePixel = 0
        helpScroll.CanvasSize = UDim2.new(0,0,0,0)
        helpScroll.Parent = helpContent
        local helpLayout = Instance.new("UIListLayout")
        helpLayout.Padding = UDim.new(0, 10)
        helpLayout.Parent = helpScroll
        local helpTitle = Instance.new("TextLabel")
        helpTitle.Size = UDim2.new(1, -10, 0, 26)
        helpTitle.BackgroundTransparency = 1
        helpTitle.Text = getText("help_title")
        helpTitle.TextColor3 = Color3.new(1,1,1)
        helpTitle.TextSize = isMobile and 15 or 18
        helpTitle.Font = Enum.Font.GothamBold
        helpTitle.Parent = helpScroll
        local helpText = Instance.new("TextLabel")
        helpText.Size = UDim2.new(1, -10, 0, 360)
        helpText.BackgroundTransparency = 1
        helpText.Text = getText("help_text")
        helpText.TextColor3 = Color3.new(0.9,0.9,0.9)
        helpText.TextSize = isMobile and 11 or 13
        helpText.Font = Enum.Font.Gotham
        helpText.TextWrapped = true
        helpText.Parent = helpScroll

        -- Подпись "By: Akulaui"
        local creditLabel = Instance.new("TextLabel")
        creditLabel.Size = UDim2.new(1, -20, 0, 18)
        creditLabel.Position = UDim2.new(0, 10, 1, -22)
        creditLabel.BackgroundTransparency = 1
        creditLabel.Text = "By: Akulaui"
        creditLabel.TextColor3 = Color3.new(0.5, 0.5, 0.6)
        creditLabel.TextSize = 10
        creditLabel.Font = Enum.Font.Gotham
        creditLabel.TextXAlignment = Enum.TextXAlignment.Center
        creditLabel.Parent = mainFrame

        langElements = {
            {obj = tabPlayers, langKey = "tab_players"},
            {obj = tabLocations, langKey = "tab_locations"},
            {obj = tabPlaces, langKey = "tab_places"},
            {obj = tabHelp, langKey = "tab_help"},
            {obj = searchBox, langKey = "search_placeholder", prop = "PlaceholderText"},
            {obj = sortBtn, langKey = "sort_name"},
            {obj = coordLabel, langKey = "coords_input"},
            {obj = tpCoordBtn, langKey = "tp_btn"},
            {obj = addLocBtn, langKey = "save_loc"},
            {obj = helpTitle, langKey = "help_title"},
            {obj = helpText, langKey = "help_text"},
        }

        locations = getLocationsForPlace(game.PlaceId)
        if not locations or #locations == 0 then
            locations = {}
        end

        local function switchTab(tab)
            currentTab = tab
            playersContent.Visible = (tab == "players")
            locationsContent.Visible = (tab == "locations")
            placesContent.Visible = (tab == "places")
            helpContent.Visible = (tab == "help")
            local t = themes[currentTheme]
            if t then
                tabPlayers.BackgroundColor3 = (tab=="players") and t.tabActive or t.tabInactive
                tabLocations.BackgroundColor3 = (tab=="locations") and t.tabActive or t.tabInactive
                tabPlaces.BackgroundColor3 = (tab=="places") and t.tabActive or t.tabInactive
                tabHelp.BackgroundColor3 = (tab=="help") and t.tabActive or t.tabInactive
            end
            if tab == "players" then refreshButtons()
            elseif tab == "locations" then refreshLocationsList()
            end
        end

        tabPlayers.MouseButton1Click:Connect(function() switchTab("players") end)
        tabLocations.MouseButton1Click:Connect(function() switchTab("locations") end)
        tabPlaces.MouseButton1Click:Connect(function() switchTab("places") end)
        tabHelp.MouseButton1Click:Connect(function() switchTab("help") end)
        switchTab("players")

        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
            searchFilter = searchBox.Text
            refreshButtons()
        end)

        local sortModeText = {getText("sort_name"), getText("sort_dist")}
        local sortModeIdx = 1
        sortBtn.MouseButton1Click:Connect(function()
            sortModeIdx = sortModeIdx % 2 + 1
            sortBtn.Text = sortModeText[sortModeIdx]
            sortByDistance = (sortModeIdx == 2)
            refreshButtons()
            if sortByDistance then
                if sortTimer then sortTimer:Disconnect() end
                sortTimer = RunService.Stepped:Connect(refreshButtons)
            else
                if sortTimer then sortTimer:Disconnect(); sortTimer=nil end
            end
        end)

        savePosBtn.MouseButton1Click:Connect(function()
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then savedPosition = hrp.CFrame; LP:Chat(getText("pos_saved")) else LP:Chat(getText("cant_save")) end
        end)

        loadPosBtn.MouseButton1Click:Connect(function()
            if savedPosition then SmartTP(savedPosition * CFrame.new(0,0,2)) else LP:Chat(getText("no_saved")) end
        end)

        Players.PlayerAdded:Connect(refreshButtons)
        Players.PlayerRemoving:Connect(refreshButtons)
        refreshButtons()
        refreshLocationsList()

        connection = RunService.RenderStepped:Connect(function(dt)
            if not sg or not sg.Parent then if connection then connection:Disconnect() end return end
            hue = (hue + dt * 0.4) % 1
            local col = Color3.fromHSV(hue, 0.9, 0.9)
            for _, b in ipairs(btns) do
                if b and b.Parent then
                    if autoTeleportActive and autoTargetPlayer and b.Text:find(autoTargetPlayer.Name) then
                        b.BackgroundColor3 = Color3.new(0,0.9,0)
                        b.BackgroundTransparency = 0.1
                    else
                        b.BackgroundColor3 = col
                        b.BackgroundTransparency = 0.2
                    end
                end
            end
            updateCoordsLabel()
        end)

        -- Перетаскивание главного окна за любую область
        local dragging = false
        local dragStart, startPos
        mainFrame.InputBegan:Connect(function(input)
            if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
                dragging = true
                dragStart = input.Position
                startPos = mainFrame.Position
            end
        end)
        mainFrame.InputEnded:Connect(function() dragging = false end)
        UserInput.InputChanged:Connect(function(input, gameProcessed)
            if gameProcessed then return end
            if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
                local delta = input.Position - dragStart
                mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
            end
        end)

        closeBtn.MouseButton1Click:Connect(function() hideMainGUI() end)
        refreshBtn.MouseButton1Click:Connect(function()
            refreshButtons()
            if currentTab == "locations" then refreshLocationsList() end
        end)
        instantBtn.MouseButton1Click:Connect(function()
            if autoTeleportActive then stopAutoTeleport()
            else
                if autoTargetPlayer then startAutoTeleport(autoTargetPlayer)
                else LP:Chat(getText("select_player_first")) end
            end
        end)

        -- Настройки (компактнее для мобильных)
        local function createSettingsWindow()
            if settingsWindow and settingsWindow.Parent then settingsWindow:Destroy(); settingsWindow = nil; return end
            settingsWindow = Instance.new("Frame")
            settingsWindow.Size = UDim2.new(0, 300, 0, isMobile and 360 or 400)
            settingsWindow.Position = UDim2.new(0.5, -150, 0.5, -180)
            settingsWindow.BackgroundColor3 = Color3.new(0.1,0.1,0.12)
            settingsWindow.BackgroundTransparency = 0.1
            settingsWindow.BorderSizePixel = 2
            settingsWindow.BorderColor3 = Color3.new(0.5,0.5,0.5)
            settingsWindow.Parent = sg

            local winTitle = Instance.new("TextLabel")
            winTitle.Size = UDim2.new(1, 0, 0, 26)
            winTitle.BackgroundTransparency = 1
            winTitle.Text = getText("settings_title")
            winTitle.TextColor3 = Color3.new(1,1,1)
            winTitle.TextSize = isMobile and 15 or 16
            winTitle.Parent = settingsWindow

            local scroll = Instance.new("ScrollingFrame")
            scroll.Size = UDim2.new(1, -10, 1, -36)
            scroll.Position = UDim2.new(0, 5, 0, 30)
            scroll.BackgroundTransparency = 1
            scroll.BorderSizePixel = 0
            scroll.Parent = settingsWindow

            local layout = Instance.new("UIListLayout")
            layout.Padding = UDim.new(0, 10)
            layout.Parent = scroll

            local function makeRow(text, btnText, onClick, height)
                local fr = Instance.new("Frame")
                fr.Size = UDim2.new(1, 0, 0, height or 36)
                fr.BackgroundTransparency = 1
                fr.Parent = scroll
                local lbl = Instance.new("TextLabel")
                lbl.Size = UDim2.new(0.55, 0, 1, 0)
                lbl.BackgroundTransparency = 1
                lbl.Text = text
                lbl.TextColor3 = Color3.new(1,1,1)
                lbl.TextSize = isMobile and 11 or 12
                lbl.Font = Enum.Font.Gotham
                lbl.Parent = fr
                local btn = Instance.new("TextButton")
                btn.Size = UDim2.new(0.35, 0, 1, 0)
                btn.Position = UDim2.new(0.6, 0, 0, 0)
                btn.Text = btnText
                btn.TextColor3 = Color3.new(0,0,0)
                btn.BackgroundColor3 = Color3.new(1,1,1)
                btn.BorderSizePixel = 0
                local btnCorner = Instance.new("UICorner")
                btnCorner.CornerRadius = UDim.new(0, 5)
                btnCorner.Parent = btn
                btn.Parent = fr
                onClick(btn)
                return btn
            end

            local sizeText = {getText("small"), getText("medium"), getText("large")}
            local sizeIdx = 2
            makeRow(getText("gui_size"), sizeText[sizeIdx], function(btn)
                btn.MouseButton1Click:Connect(function()
                    sizeIdx = sizeIdx % 3 + 1
                    btn.Text = sizeText[sizeIdx]
                    local w,h = 450,580
                    if sizeIdx == 1 then w,h=380,480 elseif sizeIdx == 2 then w,h=450,580 else w,h=550,680 end
                    if isMobile then h = 420 end
                    mainFrame.Size = UDim2.new(0,w,0,h)
                    mainFrame.Position = UDim2.new(0.5,-w/2,0.5,-h/2)
                    refreshButtons(); refreshLocationsList()
                end)
            end, 36)

            local transVal = guiTransparency
            makeRow(getText("transparency"), math.floor(transVal*100).."%", function(btn)
                btn.MouseButton1Click:Connect(function()
                    transVal = (transVal+0.1)%1.1
                    if transVal>1 then transVal=0 end
                    btn.Text = math.floor(transVal*100).."%"
                    mainFrame.BackgroundTransparency = transVal
                    guiTransparency = transVal
                end)
            end, 36)

            local speeds = {10000,25000,50000,100000,200000}
            local spIdx = 3
            makeRow(getText("speed"), tostring(teleportSpeed).." stud/s", function(btn)
                btn.MouseButton1Click:Connect(function()
                    spIdx = spIdx%5+1
                    teleportSpeed = speeds[spIdx]
                    btn.Text = tostring(teleportSpeed).." stud/s"
                end)
            end, 36)

            local themesList = {"default", "dark", "pink", "green", "blue"}
            local themeIdx = 1
            for i, name in ipairs(themesList) do if name == currentTheme then themeIdx = i break end end
            local themeNames = {getText("theme_default"), getText("theme_dark"), getText("theme_pink"), getText("theme_green"), getText("theme_blue")}
            makeRow(getText("theme"), themeNames[themeIdx], function(btn)
                btn.MouseButton1Click:Connect(function()
                    themeIdx = themeIdx % #themesList + 1
                    btn.Text = themeNames[themeIdx]
                    applyTheme(themesList[themeIdx])
                end)
            end, 36)

            -- TP offset (компактный)
            local tpOffsetFrame = Instance.new("Frame")
            tpOffsetFrame.Size = UDim2.new(1,0,0,44)
            tpOffsetFrame.BackgroundTransparency = 1
            tpOffsetFrame.Parent = scroll

            local tpOffsetLabel = Instance.new("TextLabel")
            tpOffsetLabel.Size = UDim2.new(0.55,0,1,0)
            tpOffsetLabel.BackgroundTransparency = 1
            tpOffsetLabel.Text = getText("tp_offset")
            tpOffsetLabel.TextColor3 = Color3.new(1,1,1)
            tpOffsetLabel.TextSize = isMobile and 11 or 12
            tpOffsetLabel.Font = Enum.Font.Gotham
            tpOffsetLabel.Parent = tpOffsetFrame

            local tpOffsetContainer = Instance.new("Frame")
            tpOffsetContainer.Size = UDim2.new(0.4,0,1,0)
            tpOffsetContainer.Position = UDim2.new(0.6,0,0,0)
            tpOffsetContainer.BackgroundTransparency = 1
            tpOffsetContainer.Parent = tpOffsetFrame

            local tpOffsetBox = Instance.new("TextBox")
            tpOffsetBox.Size = UDim2.new(0,50,1,-4)
            tpOffsetBox.Position = UDim2.new(0,0,0,2)
            tpOffsetBox.BackgroundColor3 = Color3.new(0.2,0.2,0.25)
            tpOffsetBox.Text = tostring(playerTPOffset)
            tpOffsetBox.TextColor3 = Color3.new(1,1,1)
            tpOffsetBox.TextSize = 13
            tpOffsetBox.Font = Enum.Font.Gotham
            tpOffsetBox.Parent = tpOffsetContainer
            Instance.new("UICorner", tpOffsetBox).CornerRadius = UDim.new(0,4)

            local minusBtn = Instance.new("TextButton")
            minusBtn.Size = UDim2.new(0,20,0,20)
            minusBtn.Position = UDim2.new(0,55,0.5,-10)
            minusBtn.Text = "-"
            minusBtn.TextColor3 = Color3.new(1,1,1)
            minusBtn.BackgroundColor3 = Color3.new(0.4,0.4,0.5)
            minusBtn.Font = Enum.Font.GothamBold
            minusBtn.TextSize = 14
            minusBtn.Parent = tpOffsetContainer
            Instance.new("UICorner", minusBtn).CornerRadius = UDim.new(0,4)
            minusBtn.MouseButton1Click:Connect(function()
                playerTPOffset = math.max(-100, playerTPOffset - 1)
                tpOffsetBox.Text = tostring(playerTPOffset)
            end)

            local plusBtn = Instance.new("TextButton")
            plusBtn.Size = UDim2.new(0,20,0,20)
            plusBtn.Position = UDim2.new(0,78,0.5,-10)
            plusBtn.Text = "+"
            plusBtn.TextColor3 = Color3.new(1,1,1)
            plusBtn.BackgroundColor3 = Color3.new(0.4,0.4,0.5)
            plusBtn.Font = Enum.Font.GothamBold
            plusBtn.TextSize = 14
            plusBtn.Parent = tpOffsetContainer
            Instance.new("UICorner", plusBtn).CornerRadius = UDim.new(0,4)
            plusBtn.MouseButton1Click:Connect(function()
                playerTPOffset = math.min(100, playerTPOffset + 1)
                tpOffsetBox.Text = tostring(playerTPOffset)
            end)

            tpOffsetBox.FocusLost:Connect(function()
                local val = tonumber(tpOffsetBox.Text)
                if val then
                    playerTPOffset = math.clamp(math.floor(val), -100, 100)
                    tpOffsetBox.Text = tostring(playerTPOffset)
                else
                    tpOffsetBox.Text = tostring(playerTPOffset)
                end
            end)

            local closeSet = Instance.new("TextButton")
            closeSet.Size = UDim2.new(0,70,0,26)
            closeSet.Position = UDim2.new(0.5,-35,1,-45)
            closeSet.Text = getText("close")
            closeSet.BackgroundColor3 = Color3.new(0.5,0.2,0.2)
            closeSet.Parent = settingsWindow
            closeSet.MouseButton1Click:Connect(function()
                settingsWindow:Destroy()
                settingsWindow = nil
            end)

            layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
                scroll.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+20)
            end)
            task.wait()
            scroll.CanvasSize = UDim2.new(0,0,0,layout.AbsoluteContentSize.Y+20)
        end

        settingsBtn.MouseButton1Click:Connect(function()
            if settingsWindow and settingsWindow.Parent then settingsWindow:Destroy(); settingsWindow=nil else createSettingsWindow() end
        end)

        -- Горячие клавиши
        UserInput.InputBegan:Connect(function(input, gp)
            if gp then return end
            if input.KeyCode == Enum.KeyCode.K then
                if mainFrame and mainFrame.Visible then hideMainGUI() else showMainGUI() end
            end
            if input.KeyCode == Enum.KeyCode.M then
                local char = LP.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                if hrp then savedPosition = hrp.CFrame; LP:Chat(getText("pos_saved").." (M)") else LP:Chat(getText("cant_save")) end
            end
            if input.KeyCode == Enum.KeyCode.L then
                if autoTeleportActive then stopAutoTeleport()
                else
                    if autoTargetPlayer then startAutoTeleport(autoTargetPlayer)
                    else LP:Chat(getText("select_player_first")) end
                end
            end
            if input.KeyCode == Enum.KeyCode.P then
                if not guiDestroyed then destroyGUI() end
            end
        end)

        applyTheme(currentTheme)
    end

    local function onCharacterAdded()
        task.wait(0.5)
        if guiDestroyed then return end
        if sg and sg.Parent then
            showMainGUI()
            refreshButtons()
            refreshLocationsList()
        else
            createGUI()
        end
    end

    createGUI()
    LP.CharacterAdded:Connect(onCharacterAdded)

    LP:Chat("🔥 Escanor HUB v2.1 загружен! By: Akulaui")
end

-- ===== ТОЧКА ВХОДА =====
if not _G.TeleportHubSettings or not _G.TeleportHubSettings.language then
    showLauncher()
else
    local ver = _G.TeleportHubSettings.version or "v2.1"
    if ver == "v1.0" then StartEscanorHub_v1()
    elseif ver == "v2.0" then StartEscanorHub_v2()
    else StartEscanorHub_v2_1() end
end