local env = (getgenv and getgenv()) or _G

-- Очистка старого слушателя при перезапуске loadstring
if env.BarrelTP and type(env.BarrelTP.Stop) == "function" then
    env.BarrelTP:Stop()
end

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local BarrelTP = {
    Enabled = true,
    Delay = 1.0,    -- Время ожидания конца полета бочки (в секундах)
    YOffset = 3.5,  -- Смещение по высоте над бочкой
    _Connection = nil,
    _LastTeleported = nil
}

-- Функция телепортации
local function teleportTo(targetPart)
    local char = player.Character
    if not char then return end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    
    if hrp and targetPart and targetPart:IsA("BasePart") and targetPart.Parent then
        local offset = (targetPart.Size.Y / 2) + BarrelTP.YOffset
        hrp.CFrame = targetPart.CFrame + Vector3.new(0, offset, 0)
    end
end

-- Обработка найденной бочки
local function processBarrel(rootPart)
    if not BarrelTP.Enabled or not rootPart or rootPart == BarrelTP._LastTeleported then return end
    BarrelTP._LastTeleported = rootPart

    task.spawn(function()
        task.wait(BarrelTP.Delay)
        if BarrelTP.Enabled and rootPart and rootPart.Parent then
            teleportTo(rootPart)
        end
    end)
end

-- Детект появления в Workspace
local function checkTarget(instance)
    if not BarrelTP.Enabled then return end

    if instance.Name == "Root" and instance:IsA("BasePart") and instance.Parent then
        if string.find(instance.Parent.Name, "Barrel") then
            processBarrel(instance)
        end
    elseif string.find(instance.Name, "Barrel") then
        task.spawn(function()
            local root = instance:WaitForChild("Root", 1.5)
            if root and root:IsA("BasePart") then
                processBarrel(root)
            end
        end)
    end
end

-- Поиск уже существующих бочек
local function scanExisting()
    for _, obj in ipairs(Workspace:GetChildren()) do
        if string.find(obj.Name, "Barrel") then
            local root = obj:FindFirstChild("Root")
            if root and root:IsA("BasePart") and root ~= BarrelTP._LastTeleported then
                processBarrel(root)
                return
            end
        end
    end
end

-- Методы управления
function BarrelTP:Start()
    self.Enabled = true
    self._LastTeleported = nil
    if self._Connection then
        self._Connection:Disconnect()
    end
    scanExisting()
    self._Connection = Workspace.DescendantAdded:Connect(checkTarget)
end

function BarrelTP:Stop()
    self.Enabled = false
    if self._Connection then
        self._Connection:Disconnect()
        self._Connection = nil
    end
    self._LastTeleported = nil
end

-- Автозапуск при инжекте
BarrelTP:Start()

-- Экспорт
env.BarrelTP = BarrelTP
return BarrelTP
