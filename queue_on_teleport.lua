-- Защита от повторной инициализации модуля
if getgenv()._TP_MODULE_LOADED then
    return getgenv()._TP_MODULE_INSTANCE
end

local Players = game:GetService("Players")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local FILE = "return_point.json"

-- Универсальный алиас для функции передачи кода при телепортации
local queueTeleport = queue_on_teleport 
    or (syn and syn.queue_on_teleport) 
    or (fluxus and fluxus.queue_on_teleport)

local Module = {}
local lastCFrame = nil

-- Фоновое отслеживание последней валидной позиции персонажа
RunService.Heartbeat:Connect(function()
    local char = player.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if hrp then
        lastCFrame = hrp.CFrame
    end
end)

-- Функция сохранения данных на диск
local function saveData()
    if not lastCFrame or not writefile then return end
    
    local payload = {
        placeId = game.PlaceId,
        jobId = game.JobId,
        cframe = {lastCFrame:GetComponents()}
    }
    
    pcall(function()
        writefile(FILE, HttpService:JSONEncode(payload))
    end)
end

-- Перехват перед телепортом
player.OnTeleport:Connect(function()
    saveData()
end)

function Module.Save()
    saveData()
end

function Module.Return()
    if not readfile or not isfile or not isfile(FILE) then
        warn("[TP Module] Файл точки возврата отсутствует на устройстве.")
        return
    end

    local success, data = pcall(function()
        return HttpService:JSONDecode(readfile(FILE))
    end)

    if not success or not data or not data.cframe then
        warn("[TP Module] Не удалось прочитать данные локации.")
        return
    end

    -- Заряжаем код восстановления, если среда поддерживает queue_on_teleport
    if queueTeleport then
        local restoreCode = string.format([[
            local p = game:GetService("Players").LocalPlayer
            local char = p.Character or p.CharacterAdded:Wait()
            local hrp = char:WaitForChild("HumanoidRootPart", 10)
            if hrp then
                task.wait(1)
                hrp.CFrame = CFrame.new(%s)
            end
        ]], table.concat(data.cframe, ", "))
        
        queueTeleport(restoreCode)
    end

    -- Попытка входа на старый сервер с fallback-ом на обычный вход
    local tpSuccess = pcall(function()
        if data.jobId and data.jobId ~= "" and data.jobId ~= game.JobId then
            TeleportService:TeleportToPlaceInstance(data.placeId, data.jobId, player)
        else
            TeleportService:Teleport(data.placeId, player)
        end
    end)

    if not tpSuccess then
        -- Если по JobId подключиться не удалось (сервер полон/закрыт), заходим на любой сервер плейса
        TeleportService:Teleport(data.placeId, player)
    end
end

getgenv()._TP_MODULE_LOADED = true
getgenv()._TP_MODULE_INSTANCE = Module

return Module
