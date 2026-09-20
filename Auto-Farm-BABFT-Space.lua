local API = _G.BABFT
if not API or not API.UI or not API.UI.mainFrame then
    warn("[BABFT-Space] Ошибка: mainFrame не найден! Запустите GUI первым.")
    return
end

local TweenService = API.TweenService
local RunService = API.RunService
local mainFrame = API.UI.mainFrame

local function createCorner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius)
    c.Parent = parent
    return c
end

local spaceBg = Instance.new("Frame")
spaceBg.Size = UDim2.new(1, 0, 1, 0)
spaceBg.BackgroundTransparency = 1
spaceBg.ZIndex = 1
spaceBg.Parent = mainFrame
API.UI.spaceBg = spaceBg

local function createNebula(size, pos, color, rot)
    local neb = Instance.new("Frame")
    neb.Size = size
    neb.Position = pos
    neb.BackgroundColor3 = color
    neb.BackgroundTransparency = 0.85
    neb.BorderSizePixel = 0
    neb.ZIndex = 1
    neb.Parent = spaceBg
    createCorner(neb, 100)
    local g = Instance.new("UIGradient")
    g.Color = ColorSequence.new(color, Color3.fromRGB(10, 8, 16))
    g.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 0.4),
        NumberSequenceKeypoint.new(0.6, 0.8),
        NumberSequenceKeypoint.new(1, 1)
    })
    g.Rotation = rot
    g.Parent = neb
end

createNebula(UDim2.new(0, 160, 0, 160), UDim2.new(0.55, -20, 0.05, 0), Color3.fromRGB(150, 40, 220), 45)
createNebula(UDim2.new(0, 120, 0, 120), UDim2.new(0.02, 0, 0.58, 0), Color3.fromRGB(30, 80, 200), -30)

-- Сатурн
local saturnContainer = Instance.new("Frame")
saturnContainer.Size = UDim2.new(0, 84, 0, 60)
saturnContainer.Position = UDim2.new(0.68, -10, 0.15, 0)
saturnContainer.BackgroundTransparency = 1
saturnContainer.ZIndex = 1
saturnContainer.Parent = spaceBg

local backRingClipper = Instance.new("Frame")
backRingClipper.Size = UDim2.new(1, 0, 0.52, 0)
backRingClipper.BackgroundTransparency = 1
backRingClipper.ClipsDescendants = true
backRingClipper.ZIndex = 1
backRingClipper.Parent = saturnContainer

local backRingDisc = Instance.new("Frame")
backRingDisc.Size = UDim2.new(0, 82, 0, 24)
backRingDisc.Position = UDim2.new(0.5, -41, 0.5, -12)
backRingDisc.BackgroundColor3 = Color3.fromRGB(225, 195, 145)
backRingDisc.BackgroundTransparency = 0.2
backRingDisc.BorderSizePixel = 0
backRingDisc.Rotation = -24
backRingDisc.Parent = backRingClipper
createCorner(backRingDisc, 100)

local brGrad = Instance.new("UIGradient")
brGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 115, 75)),
    ColorSequenceKeypoint.new(0.25, Color3.fromRGB(235, 205, 155)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 60, 40)),
    ColorSequenceKeypoint.new(0.75, Color3.fromRGB(215, 185, 135)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 90, 55))
})
brGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.9),
    NumberSequenceKeypoint.new(0.2, 0.1),
    NumberSequenceKeypoint.new(0.48, 0.2),
    NumberSequenceKeypoint.new(0.52, 0.85),
    NumberSequenceKeypoint.new(0.8, 0.15),
    NumberSequenceKeypoint.new(1, 0.95)
})
brGrad.Parent = backRingDisc

local saturnGlobe = Instance.new("Frame")
saturnGlobe.Size = UDim2.new(0, 40, 0, 40)
saturnGlobe.Position = UDim2.new(0.5, -20, 0.5, -20)
saturnGlobe.BackgroundColor3 = Color3.fromRGB(224, 192, 140)
saturnGlobe.BorderSizePixel = 0
saturnGlobe.ClipsDescendants = true
saturnGlobe.ZIndex = 2
saturnGlobe.Parent = saturnContainer
createCorner(saturnGlobe, 100)

local saturnBands = Instance.new("UIGradient")
saturnBands.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0.0, Color3.fromRGB(235, 210, 165)),
    ColorSequenceKeypoint.new(0.2, Color3.fromRGB(195, 150, 100)),
    ColorSequenceKeypoint.new(0.4, Color3.fromRGB(240, 220, 180)),
    ColorSequenceKeypoint.new(0.55, Color3.fromRGB(180, 135, 90)),
    ColorSequenceKeypoint.new(0.75, Color3.fromRGB(220, 185, 135)),
    ColorSequenceKeypoint.new(1.0, Color3.fromRGB(160, 120, 75))
})
saturnBands.Rotation = 66
saturnBands.Parent = saturnGlobe

local ssGrad = Instance.new("UIGradient")
ssGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 1),
    NumberSequenceKeypoint.new(0.45, 0.7),
    NumberSequenceKeypoint.new(0.85, 0.05),
    NumberSequenceKeypoint.new(1, 0)
})
ssGrad.Rotation = 45

local saturnShadow = Instance.new("Frame")
saturnShadow.Size = UDim2.new(1.2, 0, 1.2, 0)
saturnShadow.Position = UDim2.new(-0.25, 0, -0.1, 0)
saturnShadow.BackgroundColor3 = Color3.fromRGB(8, 6, 14)
saturnShadow.BorderSizePixel = 0
saturnShadow.ZIndex = 2
saturnShadow.Parent = saturnGlobe
createCorner(saturnShadow, 100)
local ssGradClone = ssGrad:Clone()
ssGradClone.Parent = saturnShadow

local frontRingContainer = Instance.new("Frame")
frontRingContainer.Size = UDim2.new(1, 0, 0.52, 0)
frontRingContainer.Position = UDim2.new(0, 0, 0.48, 0)
frontRingContainer.BackgroundTransparency = 1
frontRingContainer.ClipsDescendants = true
frontRingContainer.ZIndex = 3
frontRingContainer.Parent = saturnContainer

local frontRingDisc = Instance.new("Frame")
frontRingDisc.Size = UDim2.new(0, 82, 0, 24)
frontRingDisc.Position = UDim2.new(0.5, -41, 0, -12)
frontRingDisc.BackgroundColor3 = Color3.fromRGB(225, 195, 145)
frontRingDisc.BackgroundTransparency = 0.2
frontRingDisc.BorderSizePixel = 0
frontRingDisc.Rotation = -24
frontRingDisc.Parent = frontRingContainer
createCorner(frontRingDisc, 100)
local frGrad = brGrad:Clone()
frGrad.Parent = frontRingDisc

-- Земля
local earthContainer = Instance.new("Frame")
earthContainer.Size = UDim2.new(0, 34, 0, 34)
earthContainer.Position = UDim2.new(0.1, 0, 0.62, 0)
earthContainer.BackgroundTransparency = 1
earthContainer.ZIndex = 1
earthContainer.Parent = spaceBg

local earthHalo = Instance.new("Frame")
earthHalo.Size = UDim2.new(1, 8, 1, 8)
earthHalo.Position = UDim2.new(0, -4, 0, -4)
earthHalo.BackgroundColor3 = Color3.fromRGB(80, 190, 255)
earthHalo.BackgroundTransparency = 0.75
earthHalo.BorderSizePixel = 0
earthHalo.ZIndex = 1
earthHalo.Parent = earthContainer
createCorner(earthHalo, 100)

local earthGlobe = Instance.new("Frame")
earthGlobe.Size = UDim2.new(1, 0, 1, 0)
earthGlobe.BackgroundColor3 = Color3.fromRGB(15, 65, 140)
earthGlobe.BorderSizePixel = 0
earthGlobe.ClipsDescendants = true
earthGlobe.ZIndex = 2
earthGlobe.Parent = earthContainer
createCorner(earthGlobe, 100)

local function createContinent(size, pos, color, rot)
    local cont = Instance.new("Frame")
    cont.Size = size
    cont.Position = pos
    cont.BackgroundColor3 = color
    cont.BorderSizePixel = 0
    cont.Rotation = rot
    cont.ZIndex = 2
    cont.Parent = earthGlobe
    createCorner(cont, 60)
end
createContinent(UDim2.new(0, 14, 0, 18), UDim2.new(0.18, 0, 0.15, 0), Color3.fromRGB(45, 125, 55), 15)
createContinent(UDim2.new(0, 10, 0, 12), UDim2.new(0.55, 0, 0.45, 0), Color3.fromRGB(130, 115, 60), -20)
createContinent(UDim2.new(0, 8, 0, 7), UDim2.new(0.3, 0, 0.65, 0), Color3.fromRGB(35, 110, 45), 40)

local earthShadow = Instance.new("Frame")
earthShadow.Size = UDim2.new(1.2, 0, 1.2, 0)
earthShadow.Position = UDim2.new(-0.25, 0, -0.1, 0)
earthShadow.BackgroundColor3 = Color3.fromRGB(5, 10, 25)
earthShadow.BorderSizePixel = 0
earthShadow.ZIndex = 2
earthShadow.Parent = earthGlobe
createCorner(earthShadow, 100)
local esGrad = ssGrad:Clone()
esGrad.Parent = earthShadow

local moon = Instance.new("Frame")
moon.Size = UDim2.new(0, 8, 0, 8)
moon.Position = UDim2.new(1, 6, 0.15, 0)
moon.BackgroundColor3 = Color3.fromRGB(195, 200, 210)
moon.BorderSizePixel = 0
moon.ZIndex = 1
moon.Parent = earthContainer
createCorner(moon, 100)

-- Марс
local mars = Instance.new("Frame")
mars.Size = UDim2.new(0, 20, 0, 20)
mars.Position = UDim2.new(0.68, 0, 0.78, 0)
mars.BackgroundColor3 = Color3.fromRGB(195, 65, 35)
mars.BorderSizePixel = 0
mars.ClipsDescendants = true
mars.ZIndex = 1
mars.Parent = spaceBg
createCorner(mars, 100)

local marsGrad = Instance.new("UIGradient")
marsGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(245, 120, 75)),
    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(180, 55, 25)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(75, 15, 10))
})
marsGrad.Rotation = 45
marsGrad.Parent = mars

for i = 1, 14 do
    local isCross = (i % 6 == 0)
    local star = Instance.new("Frame")
    star.Size = isCross and UDim2.new(0, 3, 0, 3) or UDim2.new(0, 2, 0, 2)
    star.Position = UDim2.new(math.random(4, 96) / 100, 0, math.random(8, 94) / 100, 0)
    star.BackgroundColor3 = isCross and Color3.fromRGB(255, 250, 225) or Color3.fromRGB(215, 230, 255)
    star.BackgroundTransparency = 0.4
    star.BorderSizePixel = 0
    star.ZIndex = 1
    star.Parent = spaceBg
    createCorner(star, 100)
end

local comet = Instance.new("Frame")
comet.Size = UDim2.new(0, 45, 0, 2)
comet.Position = UDim2.new(-0.2, 0, 0.1, 0)
comet.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
comet.BorderSizePixel = 0
comet.Rotation = -35
comet.ZIndex = 1
comet.Parent = spaceBg

local cometGrad = Instance.new("UIGradient")
cometGrad.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 80, 255))
cometGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0),
    NumberSequenceKeypoint.new(0.5, 0.3),
    NumberSequenceKeypoint.new(1, 1)
})
cometGrad.Parent = comet

API.cometThread = task.spawn(function()
    while true do
        task.wait(math.random(8, 14))
        if API.spaceBgActive and spaceBg.Visible and not API.isMinimized and not API.isBlackScreen then
            local startY = math.random(5, 45) / 100
            comet.Position = UDim2.new(-0.25, 0, startY, 0)
            comet.BackgroundTransparency = 0
            local tw = TweenService:Create(comet, TweenInfo.new(1.0, Enum.EasingStyle.Linear), {
                Position = UDim2.new(1.2, 0, startY + 0.45, 0),
                BackgroundTransparency = 1
            })
            tw:Play()
        end
    end
end)

local simTime = 0
local frameAccumulator = 0

API.masterRenderConn = RunService.RenderStepped:Connect(function(dt)
    if API.isMinimized or API.isBlackScreen then return end

    if API.UI.strokeGradient and API.UI.strokeGradient.Parent then
        API.UI.strokeGradient.Rotation = (API.UI.strokeGradient.Rotation + dt * 45) % 360
    end

    if not API.spaceBgActive or not spaceBg.Visible then return end

    local interval = 0
    if API.smoothnessMode == 2 then interval = 1 / 60
    elseif API.smoothnessMode == 3 then interval = 1 / 30 end

    frameAccumulator = frameAccumulator + dt
    if frameAccumulator >= interval then
        simTime = simTime + frameAccumulator
        frameAccumulator = 0

        local saturnX = -10 + math.sin(simTime * 0.45) * 12
        local saturnY = math.cos(simTime * 0.45) * 7
        saturnContainer.Position = UDim2.new(0.68, saturnX, 0.15, saturnY)

        local earthX = math.sin(simTime * 0.55) * 8
        local earthY = -math.cos(simTime * 0.55) * 6
        earthContainer.Position = UDim2.new(0.1, earthX, 0.62, earthY)

        local marsX = math.cos(simTime * 0.5) * 6
        local marsY = math.sin(simTime * 0.5) * 5
        mars.Position = UDim2.new(0.68, marsX, 0.78, marsY)
    end
end)

print("[BABFT-Space] Космо-фон успешно активирован!")
