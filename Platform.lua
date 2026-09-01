--[[
    BARREL HUB · Multi-Floor & Area Platform Generator
    Q1: 0, -10000, 0
    Q2: 0, -20000, 0
    Q3 Slap: -9999, -30000, -9999
    Q3 Ability: 9999, -30000, 9999
    Q4: 0, -40000, 0
]]

local Workspace = game:GetService("Workspace")

local FLOORS = {
    { Name = "PBH_Platform_Q1",         Pos = Vector3.new(0, -10000, 0) },
    { Name = "PBH_Platform_Q2",         Pos = Vector3.new(0, -20000, 0) },
    { Name = "PBH_Platform_Q3_Slap",    Pos = Vector3.new(-9999, -30000, -9999) },
    { Name = "PBH_Platform_Q3_Ability", Pos = Vector3.new(9999, -30000, 9999) },
    { Name = "PBH_Platform_Q4",         Pos = Vector3.new(0, -40000, 0) },
}

for _, f in ipairs(FLOORS) do
    local old = Workspace:FindFirstChild(f.Name)
    if old then old:Destroy() end

    local platform = Instance.new("Part")
    platform.Name = f.Name
    platform.Size = Vector3.new(10000, 50, 10000)
    platform.Position = Vector3.new(f.Pos.X, f.Pos.Y - 25, f.Pos.Z)
    platform.Anchored = true
    platform.CanCollide = true
    platform.Transparency = 0.5
    platform.BrickColor = BrickColor.new("Really black")
    platform.Material = Enum.Material.SmoothPlastic
    platform.Parent = Workspace
end
