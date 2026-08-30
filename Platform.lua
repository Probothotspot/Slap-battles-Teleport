local Workspace = game:GetService("Workspace")

-- Удаляем старую платформу при повторном запуске
local existingPlatform = Workspace:FindFirstChild("PBH_Platform")
if existingPlatform then
    existingPlatform:Destroy()
end

-- Создание платформы
local platform = Instance.new("Part")
platform.Name = "PBH_Platform"
platform.Size = Vector3.new(50000, 100, 50000)
platform.Position = Vector3.new(0, -12438, 0)
platform.Anchored = true
platform.CanCollide = true
platform.Transparency = 0.5
platform.BrickColor = BrickColor.new("Really black")
platform.Material = Enum.Material.SmoothPlastic
platform.Parent = Workspace
