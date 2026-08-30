--[[
    BARREL HUB · Multi-Floor Platform Generator
    4 этажа под квесты 1-4
]]

local Workspace = game:GetService("Workspace")

local FLOORS = {
    { Name = "PBH_Platform_Q1", Y = -12385 },
    { Name = "PBH_Platform_Q2", Y = -20000 },
    { Name = "PBH_Platform_Q3", Y = -30000 },
    { Name = "PBH_Platform_Q4", Y = -40000 },
}

for _, f in ipairs(FLOORS) do
    local old = Workspace:FindFirstChild(f.Name)
    if old then old:Destroy() end

    local platform = Instance.new("Part")
    platform.Name = f.Name
    platform.Size = Vector3.new(50000, 50, 50000)
    platform.Position = Vector3.new(0, f.Y - 25, 0) -- Верхняя плоскость ровно на координате Y
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 0.5
    platform.BrickColor = BrickColor.new("Really black")
    platform.Material = Enum.Material.SmoothPlastic
    platform.Parent = Workspace
end
