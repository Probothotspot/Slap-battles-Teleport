--[[
    Escanor HUB 🔥 — Модуль переводов и локализации
    Файл: localization.lua
--]]

local Localization = {}

-- 1. Переводы интерфейса (EN, RU, UA)
Localization.lang = {
    en = {
        tab_players = "Players", tab_locations = "Locations", tab_places = "Places", tab_help = "Help",
        tab_favorites = "⭐ Favorites", tab_history = "📜 History", tab_other = "Other",
        search_placeholder = "Search players...", search_loc_placeholder = "🔍 Search locations...",
        sort_name = "ByName", sort_dist = "ByDist",
        plate_location = "Plate (one-time)", save_loc = "+ Save current location",
        coords_label = "📍 Your coords: ---", coords_input = "Coords:", tp_btn = "TP",
        invalid_coords = "Invalid coordinates. Example: 220, -16, -15",
        pos_saved = "Position saved!", cant_save = "Can't save position", no_saved = "No saved position",
        select_player_first = "Select a player first (click on name)",
        auto_on = "Auto teleport ON", auto_off = "Auto teleport OFF",
        settings_title = "Settings", gui_size = "GUI Size:", small = "Small", medium = "Medium", large = "Large",
        transparency = "Background transparency:", speed = "TP speed:",
        theme = "Theme:", theme_default = "Default", theme_dark = "Dark", theme_light = "Light",
        theme_pink = "Pink", theme_green = "Green", theme_blue = "Blue",
        tp_offset = "TP offset (-100..100):",
        place_id_label = "📍 Place ID: ",
        teleport_btn = "TP →",
        close = "Close",
        clear_history = "Clear History",
        history_empty = "No history yet",
        favorites_empty = "No favorites yet",
        anti_afk = "🛡️ Anti-AFK",
        fps_ping = "📊 FPS / Ping",
        fullbright = "☀️ Fullbright",
        coords_display = "📍 Coordinates",
        timer = "⏱️ Timer/Stopwatch",
        help_title = "How to use Escanor HUB",
        help_text = [[
• TAB "Players" – click on any player name to teleport.
• TAB "Locations" – list of saved locations.
• TAB "Favorites" – your favorite locations.
• TAB "History" – recent teleports.
• TAB "Other" – utilities (Anti-AFK, FPS, Fullbright, Timer).
• TAB "Places" – quick teleport to other games.
        ]],
    },
    ru = {
        tab_players = "Игроки", tab_locations = "Локации", tab_places = "Плейсы", tab_help = "Помощь",
        tab_favorites = "⭐ Избранное", tab_history = "📜 История", tab_other = "Другое",
        search_placeholder = "Поиск игроков...", search_loc_placeholder = "🔍 Поиск локаций...",
        sort_name = "По имени", sort_dist = "По дистанции",
        plate_location = "Тарелка (разово)", save_loc = "+ Сохранить текущее место",
        coords_label = "📍 Твои координаты: ---", coords_input = "Коорд:", tp_btn = "ТП",
        invalid_coords = "Некорректные координаты. Пример: 220, -16, -15",
        pos_saved = "Позиция сохранена!", cant_save = "Не удалось сохранить", no_saved = "Нет сохранённой позиции",
        select_player_first = "Сначала выберите игрока (нажмите на кнопку с ником)",
        auto_on = "Авто-телепорт включён", auto_off = "Авто-телепорт выключён",
        settings_title = "Настройки", gui_size = "Размер GUI:", small = "Маленький", medium = "Средний", large = "Большой",
        transparency = "Прозрачность фона:", speed = "Скорость ТП:",
        theme = "Тема:", theme_default = "Стандарт", theme_dark = "Тёмная", theme_light = "Светлая",
        theme_pink = "Розовая", theme_green = "Зелёная", theme_blue = "Синяя",
        tp_offset = "ТП отступ (-100..100):",
        place_id_label = "📍 Place ID: ",
        teleport_btn = "ТП →",
        close = "Закрыть",
        clear_history = "Очистить историю",
        history_empty = "История пуста",
        favorites_empty = "Избранное пусто",
        anti_afk = "🛡️ Анти-АФК",
        fps_ping = "📊 FPS / Пинг",
        fullbright = "☀️ Fullbright",
        coords_display = "📍 Координаты",
        timer = "⏱️ Таймер/Секундомер",
        help_title = "Как пользоваться Escanor HUB",
        help_text = [[
• ВКЛАДКА "Игроки" – кликните по имени игрока для телепортации.
• ВКЛАДКА "Локации" – список сохранённых мест.
• ВКЛАДКА "Избранное" – ваши избранные локации.
• ВКЛАДКА "История" – последние телепорты.
• ВКЛАДКА "Другое" – утилиты (Анти-АФК, FPS, Fullbright, Таймер).
• ВКЛАДКА "Плейсы" – быстрая телепортация по Place ID.
        ]],
    },
    ua = {
        tab_players = "Гравці", tab_locations = "Локації", tab_places = "Плейси", tab_help = "Допомога",
        tab_favorites = "⭐ Обране", tab_history = "📜 Історія", tab_other = "Інше",
        search_placeholder = "Пошук гравців...", search_loc_placeholder = "🔍 Пошук локацій...",
        sort_name = "За ім'ям", sort_dist = "За відстанню",
        plate_location = "Тарілка (разово)", save_loc = "+ Зберегти поточне місце",
        coords_label = "📍 Твої координати: ---", coords_input = "Коорд:", tp_btn = "ТП",
        invalid_coords = "Некоректні координати. Приклад: 220, -16, -15",
        pos_saved = "Позицію збережено!", cant_save = "Не вдалося зберегти", no_saved = "Немає збереженої позиції",
        select_player_first = "Спершу виберіть гравця (натисніть на кнопку з ніком)",
        auto_on = "Авто-телепорт увімкнено", auto_off = "Авто-телепорт вимкнено",
        settings_title = "Налаштування", gui_size = "Розмір GUI:", small = "Маленький", medium = "Середній", large = "Великий",
        transparency = "Прозорість фону:", speed = "Швидкість ТП:",
        theme = "Тема:", theme_default = "Стандарт", theme_dark = "Темна", theme_light = "Світла",
        theme_pink = "Рожева", theme_green = "Зелена", theme_blue = "Синя",
        tp_offset = "ТП відступ (-100..100):",
        place_id_label = "📍 Place ID: ",
        teleport_btn = "ТП →",
        close = "Закрити",
        clear_history = "Очистити історію",
        history_empty = "Історія порожня",
        favorites_empty = "Обране порожнє",
        anti_afk = "🛡️ Анти-АФК",
        fps_ping = "📊 FPS / Пінг",
        fullbright = "☀️ Fullbright",
        coords_display = "📍 Координати",
        timer = "⏱️ Таймер/Секундомір",
        help_title = "Як користуватися Escanor HUB",
        help_text = [[
• ВКЛАДКА "Гравці" – телепортація до гравця.
• ВКЛАДКА "Локації" – список збережених локацій.
• ВКЛАДКА "Обране" – обрані точки.
• ВКЛАДКА "Історія" – історія переміщень.
• ВКЛАДКА "Інше" – утиліти.
• ВКЛАДКА "Плейси" – ТП до других ігор.
        ]],
    }
}

-- 2. Переводы названий локаций
Localization.locationTranslations = {
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
    ["Синий портал"] = { ru = "Синий портал", en = "Blue Portal", ua = "Синій портал" },
    ["Зеленый портал"] = { ru = "Зеленый портал", en = "Green Portal", ua = "Зелений портал" },
    ["Оранжевый портал"] = { ru = "Оранжевый портал", en = "Orange Portal", ua = "Помаранчевий портал" },
    ["Конец"] = { ru = "Конец", en = "End", ua = "Кінець" },
}

-- 3. Вспомогательные функции получения текста
function Localization.getText(currentLang, key)
    local l = Localization.lang
    return (l[currentLang] and l[currentLang][key]) or (l["en"] and l["en"][key]) or key
end

function Localization.getLocalizedLocationName(currentLang, originalName)
    local entry = Localization.locationTranslations[originalName]
    if entry then return entry[currentLang] or originalName end
    return originalName
end

return Localization
