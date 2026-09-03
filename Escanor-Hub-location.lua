--[[
    Escanor HUB 🔥 – Location Module
    File: Escanor-Hub-location.lua
    By: Brobothotspot
--]]

local LocationModule = {}

local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- =========================================================================
-- 1. СПИСОК ПОДДЕРЖИВАЕМЫХ ПЛЕЙСОВ
-- =========================================================================
LocationModule.SupportedPlaces = {
    [6403373529] = "Slap Battles",
    [7234087065] = "Barzil",
    [115782629143468] = "Untitled Tag",
    [127174121130060] = "Glove Game",
    [18550498098] = "Guide",
    [125845699717230] = "DoorKeeper",
    [106620300132058] = "Plate",
    [103505724406848] = "Poltergeist",
    [77283826005207] = "G-X",
}

-- =========================================================================
-- 2. СПЕЦИАЛЬНЫЕ ФУНКЦИИ ТЕЛЕПОРТАЦИИ
-- =========================================================================

-- Телепорт на движущуюся тарелку в Slap Battles
function LocationModule.teleportToPlate()
    local arena = workspace:FindFirstChild("Arena")
    if arena then
        local plate = arena:FindFirstChild("Plate")
        if plate then
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = plate.CFrame * CFrame.new(0, 5, 0)
                return true
            end
        end
    end
    return false
end

-- Последовательный телепорт по чекпоинтам (например, Relude/Hunter в Guide)
function LocationModule.startSequentialTeleport(waypoints)
    if not waypoints or #waypoints == 0 then return end
    task.spawn(function()
        for _, cf in ipairs(waypoints) do
            local char = LP.Character
            local hrp = char and char:FindFirstChild("HumanoidRootPart")
            if hrp then
                hrp.CFrame = cf
            end
            task.wait(1)
        end
    end)
end

-- =========================================================================
-- 3. БАЗА КООРДИНАТ ДЛЯ КАЖДОГО PLACE ID
-- =========================================================================
function LocationModule.getLocationsForPlace(placeId)
    placeId = placeId or game.PlaceId

    if placeId == 6403373529 then
        -- Slap Battles
        return {
            {name = "Debug room", cframe = CFrame.new(-17922, 59, 3561), isDefault = true},
            {name = "Main island", cframe = CFrame.new(5, -6, 2), isDefault = true},
            {name = "Left island", cframe = CFrame.new(1, -6, 164), isDefault = true},
            {name = "Right island", cframe = CFrame.new(-3, -6, -165), isDefault = true},
            {name = "Moai", cframe = CFrame.new(220, -16, -15), isDefault = true},
            {name = "Castle", cframe = CFrame.new(273, 33, 205), isDefault = true},
            {name = "Kill cube", cframe = CFrame.new(-242, -6, 3), isDefault = true},
            {name = "Slapple island", cframe = CFrame.new(-378, 51, -16), isDefault = true},
            {name = "Lobby", cframe = CFrame.new(-1197, 327, -2), isDefault = true},
            {name = "Basement", cframe = CFrame.new(17895, -130, -3545), isDefault = true},
            {name = "Blue portal", cframe = CFrame.new(116, 360, -3), isDefault = true},
            {name = "Cloud", cframe = CFrame.new(-124.3, -4.6, 121.2), isDefault = true},
            {name = "Brazil", cframe = CFrame.new(-1124, 310, 0), isDefault = true},
            {name = "Plate", cframe = CFrame.new(0, 0, 0), isDefault = true, isPlate = true}
        }
    elseif placeId == 7234087065 then
        -- Barzil
        return {
            {name = "Spawn", cframe = CFrame.new(-1.4, 8.8, -8.5), isDefault = true},
            {name = "Clown (Fan)", cframe = CFrame.new(200, 3, 221), isDefault = true},
            {name = "Angry Brazil", cframe = CFrame.new(-65, 3, -164), isDefault = true},
            {name = "OOG", cframe = CFrame.new(-233, 3, 210), isDefault = true},
            {name = "RiftShot", cframe = CFrame.new(-261, 13, 460), isDefault = true},
            {name = "Библиотека", cframe = CFrame.new(318, 52, -43), isDefault = true},
            {name = "ФастФуд/Море", cframe = CFrame.new(303, 63, 200), isDefault = true},
            {name = "Часы на водопаде", cframe = CFrame.new(156, 231, 455), isDefault = true},
            {name = "Водопад - Наверху", cframe = CFrame.new(83, 287, 564), isDefault = true},
            {name = "Пикник", cframe = CFrame.new(35, 133, 423), isDefault = true},
            {name = "Кирки/Топоры", cframe = CFrame.new(42, 52, 330), isDefault = true},
            {name = "Карусель", cframe = CFrame.new(80, 3, 202), isDefault = true},
            {name = "Metaverse", cframe = CFrame.new(250, 94, -442), isDefault = true},
            {name = "Clock", cframe = CFrame.new(250, 150, -458.6), isDefault = true},
            {name = "Машина", cframe = CFrame.new(93.4, 60, -97.5), isDefault = true},
            {name = "Мортис", cframe = CFrame.new(251, -60, -361), isDefault = true},
            {name = "Ключ (Fan)", cframe = CFrame.new(247, -265, -366), isDefault = true},
            {name = "Untitled Tag", cframe = CFrame.new(-243, 300, -493), isDefault = true}
        }
    elseif placeId == 115782629143468 then
        -- Untitled Tag
        return {
            {name = "Прохождение", cframe = CFrame.new(0, 200, -2), isDefault = true}
        }
    elseif placeId == 127174121130060 then
        -- Glove Game (использует локации Slap Battles)
        return LocationModule.getLocationsForPlace(6403373529)
    elseif placeId == 18550498098 then
        -- Guide
        return {
            {name = "Спавн", cframe = CFrame.new(570, 11, 112), isDefault = true},
            {name = "Рычаг", cframe = CFrame.new(613, 11, 146), isDefault = true},
            {name = "2 комната", cframe = CFrame.new(557, 6, 353), isDefault = true},
            {name = "Начальный Туннель (Паркур)", cframe = CFrame.new(602, 6, 360), isDefault = true},
            {name = "1 локация", cframe = CFrame.new(723, 28, 403), isDefault = true},
            {name = "Конец 1 локации", cframe = CFrame.new(831, 5, 404), isDefault = true},
            {name = "Начальный Туннель (Голем)", cframe = CFrame.new(535, 6, 364), isDefault = true},
            {name = "Голем начало", cframe = CFrame.new(487, 24, 510), isDefault = true},
            {name = "Конец голема", cframe = CFrame.new(486, 55, 641), isDefault = true},
            {name = "Паркур Sbeve", cframe = CFrame.new(690, -1, 720), isDefault = true},
            {name = "Лазеры начало", cframe = CFrame.new(1071, -30, 571), isDefault = true},
            {name = "Лазеры конец", cframe = CFrame.new(1218, -30, 572), isDefault = true},
            {name = "1 и 2 воссоединение", cframe = CFrame.new(1435, -63, 645), isDefault = true},
            {name = "Огонь начало", cframe = CFrame.new(1052, -36, 715), isDefault = true},
            {name = "Конец огня", cframe = CFrame.new(1200, -36, 715), isDefault = true},
            {name = "Начало поездов", cframe = CFrame.new(925, -4, 850), isDefault = true},
            {name = "Конец поездов", cframe = CFrame.new(1192, -4, 860), isDefault = true},
            {name = "Пвп картошка", cframe = CFrame.new(1917, -31, 893), isDefault = true},
            {name = "Сжимание пола и потолка, перчатка", cframe = CFrame.new(1821, -31, 400), isDefault = true},
            {name = "Конец сжимания пола и потолка, перчатка", cframe = CFrame.new(2066, -31, 397), isDefault = true},
            {name = "Машина в лабиринте", cframe = CFrame.new(2126, -31, 954), isDefault = true},
            {name = "Конец лабиринта", cframe = CFrame.new(2750, -31, 823), isDefault = true},
            {name = "Комната начала", cframe = CFrame.new(3231, -75, 822), isDefault = true},
            {name = "Регенерация", cframe = CFrame.new(3286, -75, 822), isDefault = true},
            {name = "Доп хп", cframe = CFrame.new(3271, -227, 822), isDefault = true},
            {name = "Аватар", cframe = CFrame.new(3270, -75, 821), isDefault = true},
            {name = "Relude, Hunter", waypoints = {
                CFrame.new(3286, -75, 822),
                CFrame.new(3271, -227, 822),
                CFrame.new(3270, -75, 821),
            }, isDefault = true}
        }
    elseif placeId == 77283826005207 then
        -- G-X
        return {
            {name = "Синий портал", cframe = CFrame.new(847, 82, 381), isDefault = true},
            {name = "Зеленый портал", cframe = CFrame.new(-384, 82, 386), isDefault = true},
            {name = "Оранжевый портал", cframe = CFrame.new(142, 82, 923), isDefault = true},
            {name = "Конец", cframe = CFrame.new(142, 84, 287), isDefault = true}
        }
    else
        return {}
    end
end

-- Быстрый вызов LocationModule(placeId)
setmetatable(LocationModule, {
    __call = function(_, placeId)
        return LocationModule.getLocationsForPlace(placeId)
    end
})

-- ОБЯЗАТЕЛЬНЫЙ ЭКСПОРТ ДЛЯ LOADSTRING
return LocationModule
