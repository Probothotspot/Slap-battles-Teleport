--[[
═══════════════════════════════════════════════════════════════════════════════
    BARREL HUB · Alt Engine (Zero-Latency & Nexer Physics Stabilizer)
═══════════════════════════════════════════════════════════════════════════════
]]

local Players           = game:GetService("Players")
local Workspace         = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local GENV = (typeof(getgenv) == "function" and getgenv()) or _G

if GENV.BHUB_ALT_THREAD then
    pcall(task.cancel, GENV.BHUB_ALT_THREAD)
    GENV.BHUB_ALT_THREAD = nil
end

local SPAWNS = {
    [1]            = Vector3.new(0, -9997, 0),
    [2]            = Vector3.new(0, -19997, 0),
    ["Q3_Slap"]    = Vector3.new(-9999, -29997, -9999),
    ["Q3_Ability"] = Vector3.new(9999, -29997, 9999),
    [4]            = Vector3.new(0, -39997, 0),
}

local function touchBluePortal()
    local lobby = Workspace:FindFirstChild("Lobby")
    local portal = (lobby and lobby:FindFirstChild("Teleport2", true)) or Workspace:FindFirstChild("Teleport2", true)
    local hrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if hrp and portal and portal:IsA("BasePart") then
        if firetouchinterest then
            firetouchinterest(hrp, portal, 0)
            task.wait(0.05)
            firetouchinterest(hrp, portal, 1)
        else
            portal.CFrame = hrp.CFrame
        end
    end
end

local function detectFloor(y, x)
    if math.abs(y - (-10000)) < 2000 then return 1, SPAWNS[1]
    elseif math.abs(y - (-20000)) < 2000 then return 2, SPAWNS[2]
    elseif math.abs(y - (-30000)) < 2000 then
        return (x < 0) and "Q3_Slap" or "Q3_Ability", (x < 0) and SPAWNS["Q3_Slap"] or SPAWNS["Q3_Ability"]
    elseif math.abs(y - (-40000)) < 2000 then return 4, SPAWNS[4] end
    return nil, nil
end

GENV.BHUB_ALT_THREAD = task.spawn(function()
    local isRunning = true
    local activeBarrel = nil
    local lastHitTime = 0
    local curKey, curSpawn = nil, nil

    -- 1. Слушатель GeneralHit
    local genHit = ReplicatedStorage:FindFirstChild("GeneralHit")
    if genHit and genHit:IsA("RemoteEvent") then
        genHit.OnClientEvent:Connect(function() lastHitTime = tick() end)
    end

    -- 2. Nexer Физический стабилизатор и NoClip
    RunService.Stepped:Connect(function()
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if hrp and hrp.Position.Y < -5000 then
            hrp.AssemblyLinearVelocity = Vector3.zero
            hrp.AssemblyAngularVelocity = Vector3.zero
            for _, p in ipairs(char:GetChildren()) do
                if p:IsA("BasePart") and p.CanCollide then p.CanCollide = false end
            end
        end
    end)

    -- 3. Event-Driven детектор бочки (0ms)
    local function snapToBarrel(root, model)
        if activeBarrel == model then return end
        activeBarrel = model
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        local hum = char and char:FindFirstChildOfClass("Humanoid")
        if not (hrp and hum and hum.Health > 0) then return end

        if curKey == 4 then
            hrp.CFrame = root.CFrame * CFrame.new(0, 0.5, 0)
            if firetouchinterest then
                firetouchinterest(hrp, root, 0)
                task.wait(0.01)
                firetouchinterest(hrp, root, 1)
            end
        elseif curKey == "Q3_Ability" then
            task.spawn(function()
                task.wait(1.0)
                if hum.Health > 0 and root.Parent then
                    hrp.CFrame = root.CFrame * CFrame.new(0, 0.5, 0)
                    if firetouchinterest then
                        firetouchinterest(hrp, root, 0)
                        task.wait(0.01)
                        firetouchinterest(hrp, root, 1)
                    end
                    task.wait(0.5)
                    if hum.Health > 0 then hum.Health = 0 end
                end
            end)
        end

        model.AncestryChanged:Connect(function(_, parent)
            if not parent and activeBarrel == model then activeBarrel = nil end
        end)
    end

    local function checkCandidate(inst)
        local mainName = tostring(GENV.BHUB_MAIN_NAME or ""):lower()
        if mainName == "" or not inst then return end
        local n = inst.Name:lower()
        if n == (mainName .. "barrel") or (n:find(mainName, 1, true) and n:find("barrel", 1, true)) then
            local r = inst:FindFirstChild("Root") or inst:FindFirstChildWhichIsA("BasePart")
            if r then snapToBarrel(r, inst)
            else
                inst.ChildAdded:Connect(function(sub)
                    if sub.Name == "Root" or sub:IsA("BasePart") then snapToBarrel(sub, inst) end
                end)
            end
        end
    end

    Workspace.ChildAdded:Connect(checkCandidate)

    -- 4. Главный рабочий цикл Альта
    while isRunning and GENV.BHUB_ROLE == "Alt" do
        task.wait(0.03)
        local mainPlr = nil
        local mQuery = tostring(GENV.BHUB_MAIN_NAME or ""):lower()
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and (p.Name:lower() == mQuery or p.DisplayName:lower() == mQuery) then
                mainPlr = p break
            end
        end

        local mChar = mainPlr and mainPlr.Character
        local mHrp  = mChar and mChar:FindFirstChild("HumanoidRootPart")

        if mHrp then
            local detectedKey, targetSpawn = detectFloor(mHrp.Position.Y, mHrp.Position.X)
            if detectedKey then
                curKey, curSpawn = detectedKey, targetSpawn
                local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
                local hrp = char:WaitForChild("HumanoidRootPart", 4)
                local hum = char:WaitForChild("Humanoid", 4)

                if hrp and hum and hum.Health > 0 then
                    if hrp.Position.Y >= 200 and hrp.Position.Y <= 500 then
                        touchBluePortal()
                        task.wait(0.6)
                        if hrp then hrp.CFrame = CFrame.new(curSpawn) end
                    else
                        if curKey == "Q3_Slap" then
                            hrp.CFrame = mHrp.CFrame * CFrame.new(0, 0, -3) * CFrame.Angles(0, math.rad(180), 0)
                            if tick() - lastHitTime < 0.5 or hum.Health < 100 then
                                task.wait(0.05)
                                if hum.Health > 0 then hum.Health = 0 end
                            end
                        elseif not activeBarrel then
                            hrp.CFrame = mHrp.CFrame * CFrame.new(0, 0, -2.2) * CFrame.Angles(0, math.rad(180), 0)
                        end
                    end
                end
            end
        else
            task.wait(0.5)
        end
    end
end)
