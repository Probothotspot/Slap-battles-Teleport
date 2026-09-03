--[[
    Escanor HUB 🔥 – Themes & Shimmer Module
    File: Escanor-Hub-themes.lua
    By: Brobothotspot
--]]

local Themes = {}

-- =========================================================================
-- 1. БАЗА ДАННЫХ ТЕМ
-- =========================================================================
Themes.data = {
    dark = {
        mainBg = Color3.fromRGB(25, 28, 40),
        mainGradStart = Color3.fromRGB(25, 28, 40),
        mainGradEnd = Color3.fromRGB(15, 18, 30),
        topBg = Color3.fromRGB(40, 45, 60),
        topGradStart = Color3.fromRGB(60, 65, 80),
        topGradEnd = Color3.fromRGB(40, 45, 60),
        tabActive = Color3.fromRGB(120, 120, 220),
        tabInactive = Color3.fromRGB(70, 70, 130),
        borderColor = Color3.new(1, 1, 1),
        textColor = Color3.new(1, 1, 1),
        btnColor = Color3.fromRGB(70, 70, 130),
        inputBg = Color3.fromRGB(15, 15, 20),
        shimmerHue = 0.75,
        shimmerRange = 0.12,
        shimmerSat = 0.7,
        shimmerVal = 0.85
    },
    light = {
        mainBg = Color3.fromRGB(240, 240, 245),
        mainGradStart = Color3.fromRGB(240, 240, 245),
        mainGradEnd = Color3.fromRGB(220, 220, 225),
        topBg = Color3.fromRGB(200, 200, 220),
        topGradStart = Color3.fromRGB(210, 210, 230),
        topGradEnd = Color3.fromRGB(190, 190, 210),
        tabActive = Color3.fromRGB(80, 120, 220),
        tabInactive = Color3.fromRGB(180, 180, 200),
        borderColor = Color3.new(0.3, 0.3, 0.4),
        textColor = Color3.new(0.1, 0.1, 0.15),
        btnColor = Color3.fromRGB(180, 180, 200),
        inputBg = Color3.fromRGB(255, 255, 255),
        shimmerHue = 0.72,
        shimmerRange = 0.10,
        shimmerSat = 0.45,
        shimmerVal = 0.70
    },
    pink = {
        mainBg = Color3.fromRGB(40, 20, 30),
        mainGradStart = Color3.fromRGB(40, 20, 30),
        mainGradEnd = Color3.fromRGB(30, 15, 25),
        topBg = Color3.fromRGB(60, 30, 45),
        topGradStart = Color3.fromRGB(80, 40, 60),
        topGradEnd = Color3.fromRGB(60, 30, 45),
        tabActive = Color3.fromRGB(220, 120, 180),
        tabInactive = Color3.fromRGB(150, 70, 120),
        borderColor = Color3.new(1, 0.8, 0.9),
        textColor = Color3.new(1, 0.9, 0.95),
        btnColor = Color3.fromRGB(150, 70, 120),
        inputBg = Color3.fromRGB(30, 15, 25),
        shimmerHue = 0.91,
        shimmerRange = 0.08,
        shimmerSat = 0.65,
        shimmerVal = 0.90
    },
    green = {
        mainBg = Color3.fromRGB(20, 35, 25),
        mainGradStart = Color3.fromRGB(20, 35, 25),
        mainGradEnd = Color3.fromRGB(15, 28, 20),
        topBg = Color3.fromRGB(30, 50, 35),
        topGradStart = Color3.fromRGB(40, 65, 45),
        topGradEnd = Color3.fromRGB(30, 50, 35),
        tabActive = Color3.fromRGB(100, 200, 120),
        tabInactive = Color3.fromRGB(60, 130, 80),
        borderColor = Color3.new(0.5, 1, 0.6),
        textColor = Color3.new(0.9, 1, 0.9),
        btnColor = Color3.fromRGB(60, 130, 80),
        inputBg = Color3.fromRGB(20, 35, 25),
        shimmerHue = 0.38,
        shimmerRange = 0.10,
        shimmerSat = 0.70,
        shimmerVal = 0.80
    },
    blue = {
        mainBg = Color3.fromRGB(15, 20, 40),
        mainGradStart = Color3.fromRGB(15, 20, 40),
        mainGradEnd = Color3.fromRGB(10, 15, 30),
        topBg = Color3.fromRGB(20, 30, 60),
        topGradStart = Color3.fromRGB(30, 45, 80),
        topGradEnd = Color3.fromRGB(20, 30, 60),
        tabActive = Color3.fromRGB(80, 120, 255),
        tabInactive = Color3.fromRGB(50, 80, 180),
        borderColor = Color3.new(0.6, 0.7, 1),
        textColor = Color3.new(0.85, 0.9, 1),
        btnColor = Color3.fromRGB(50, 80, 180),
        inputBg = Color3.fromRGB(15, 20, 40),
        shimmerHue = 0.60,
        shimmerRange = 0.10,
        shimmerSat = 0.75,
        shimmerVal = 0.90
    }
}
Themes.data["default"] = Themes.data.dark

-- =========================================================================
-- 2. ФУНКЦИИ ПЕРЕЛИВАНИЯ (SHIMMER)
-- =========================================================================
function Themes.getTheme(themeName)
    local name = themeName or (_G.TeleportHubSettings and _G.TeleportHubSettings.theme) or "dark"
    return Themes.data[name] or Themes.data.dark
end

function Themes.getShimmerColor(themeOrName, phase)
    local t = (type(themeOrName) == "table") and themeOrName or Themes.getTheme(themeOrName)
    local baseH = t.shimmerHue or 0.75
    local range = t.shimmerRange or 0.12
    local sat = t.shimmerSat or 0.7
    local val = t.shimmerVal or 0.85
    local h = (baseH + math.sin(phase) * range) % 1
    return Color3.fromHSV(h, sat, val)
end

function Themes.getShimmerColorOffset(themeOrName, phase, offset)
    local t = (type(themeOrName) == "table") and themeOrName or Themes.getTheme(themeOrName)
    local baseH = t.shimmerHue or 0.75
    local range = t.shimmerRange or 0.12
    local sat = t.shimmerSat or 0.7
    local val = t.shimmerVal or 0.85
    local h = (baseH + math.sin(phase + (offset or 0)) * range) % 1
    return Color3.fromHSV(h, sat, val)
end

function Themes.getShimmerColorDim(themeOrName, phase, dimFactor)
    local t = (type(themeOrName) == "table") and themeOrName or Themes.getTheme(themeOrName)
    local baseH = t.shimmerHue or 0.75
    local range = t.shimmerRange or 0.12
    local sat = t.shimmerSat or 0.7
    local val = (t.shimmerVal or 0.85) * (dimFactor or 1)
    local h = (baseH + math.sin(phase) * range) % 1
    return Color3.fromHSV(h, sat, val)
end

-- =========================================================================
-- 3. ПРИМЕНЕНИЕ ТЕМЫ К ЭЛЕМЕНТАМ GUI
-- =========================================================================
function Themes.apply(themeName, elements, currentTab)
    local t = Themes.getTheme(themeName)
    elements = elements or {}

    if elements.mainFrame then
        elements.mainFrame.BackgroundColor3 = t.mainBg
    end
    if elements.mainStroke then
        elements.mainStroke.Color = Themes.getShimmerColor(t, 0)
    end
    if elements.topStroke then
        elements.topStroke.Color = Themes.getShimmerColorOffset(t, 0, 1.0)
    end
    if elements.mainGradient then
        elements.mainGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, t.mainGradStart),
            ColorSequenceKeypoint.new(1, t.mainGradEnd)
        }
    end
    if elements.topBar then
        elements.topBar.BackgroundColor3 = t.topBg
    end
    if elements.topGradient then
        elements.topGradient.Color = ColorSequence.new{
            ColorSequenceKeypoint.new(0, t.topGradStart),
            ColorSequenceKeypoint.new(1, t.topGradEnd)
        }
    end

    -- Перекрашивание текста
    for _, elem in ipairs(elements.textElements or {}) do
        if elem and elem.Parent then
            elem.TextColor3 = t.textColor
        end
    end

    -- Вкладки
    local cur = currentTab or "players"
    if elements.tabPlayers then elements.tabPlayers.BackgroundColor3 = (cur == "players") and t.tabActive or t.tabInactive end
    if elements.tabLocations then elements.tabLocations.BackgroundColor3 = (cur == "locations") and t.tabActive or t.tabInactive end
    if elements.tabPlaces then elements.tabPlaces.BackgroundColor3 = (cur == "places") and t.tabActive or t.tabInactive end
    if elements.tabHelp then elements.tabHelp.BackgroundColor3 = (cur == "help") and t.tabActive or t.tabInactive end
    if elements.tabFavorites then elements.tabFavorites.BackgroundColor3 = (cur == "favorites") and t.tabActive or t.tabInactive end
    if elements.tabHistory then elements.tabHistory.BackgroundColor3 = (cur == "history") and t.tabActive or t.tabInactive end
    if elements.tabOther then elements.tabOther.BackgroundColor3 = (cur == "other") and t.tabActive or t.tabInactive end

    -- Поля ввода
    if elements.searchBox then elements.searchBox.TextColor3 = t.textColor end
    if elements.locSearchBox then elements.locSearchBox.TextColor3 = t.textColor end
    if elements.sortBtn then elements.sortBtn.TextColor3 = t.textColor end
end

-- Быстрый доступ: Themes["dark"] возвращает таблицу темы
setmetatable(Themes, {
    __index = function(tbl, key)
        return tbl.data[key]
    end
})

-- ОБЯЗАТЕЛЬНЫЙ ЭКСПОРТ ДЛЯ LOADSTRING
return Themes
