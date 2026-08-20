--[[
    Navigation Module v1.7 (Final)
    Advanced Pathfinding & Obstacle Avoidance for Roblox (Luau)
    Environment: Delta Executor
    Load: local Nav = loadstring(game:HttpGet(url))()

    v1.7 Fix:
      FIX — moveTo() now clears dead thread references from _threads
            after the active wait loop, preventing memory leak from
            6 dead entries accumulating on every moveTo() call.

    All fixes and optimizations from v1.1–v1.6 retained unchanged.
]]

local Navigation = {}

-- ═══════════════════════════════════════════════════════════════
--  Services (obtained once, cached)
-- ═══════════════════════════════════════════════════════════════
local PathfindingService = game:GetService("PathfindingService")
local Players            = game:GetService("Players")
local Workspace          = game:GetService("Workspace")

-- ═══════════════════════════════════════════════════════════════
--  Internal state
-- ═══════════════════════════════════════════════════════════════
local _humanoid   = nil
local _rootPart   = nil
local _moving     = false
local _status     = "idle"
local _stopFlag   = false
local _connections = {}
local _threads     = {}

local _originalWalkSpeed = nil
local _debug = false
local _lastLoggedStatus = ""

-- Cached RaycastParams (reused every frame to avoid GC pressure)
local _rayParams = RaycastParams.new()
_rayParams.FilterType = Enum.RaycastFilterType.Exclude
_rayParams.FilterDescendantsInstances = {}

local _lastFilterChar = nil

-- Constants
local GROUND_CHECK_INTERVAL = 0.1
local STUCK_DISTANCE        = 1
local STUCK_DISTANCE_SQ     = STUCK_DISTANCE * STUCK_DISTANCE
local STUCK_TIME            = 2
local JUMP_HEIGHT           = 7.2
local GAP_DETECT_RANGE      = 15
local EDGE_RAY_RANGE        = 12
local BRIDGE_NARROW_THRESHOLD = 4
local WALL_DETECT_RANGE     = 5
local AGENT_RADII           = {1, 2, 3, 1.5, 2.5}

-- Throttling timers and intervals
local _timers = { bridge = 0, gap = 0, wall = 0, edges = 0 }
local BRIDGE_CHECK_INTERVAL = 0.2
local GAP_CHECK_INTERVAL    = 0.15
local WALL_CHECK_INTERVAL   = 0.15
local EDGE_CHECK_INTERVAL   = 0.2

-- Cached detection results (indices must match on write and read)
local _cachedBridge = {false, 100, 100, 200}
local _cachedGap    = {false, 0}
local _cachedWall   = {false, 0, 0}
local _cachedEdge   = {true, Vector3.zero}

-- Path recompute cooldown
local _lastPathTime = 0
local PATH_COOLDOWN = 0.5

-- ═══════════════════════════════════════════════════════════════
--  Utility helpers
-- ═══════════════════════════════════════════════════════════════

local function debugLog(...)
    if _debug then
        print("[NAV]", ...)
    end
end

-- Only log status when it actually changes
local function setStatus(newStatus)
    _status = newStatus
    if _debug and newStatus ~= _lastLoggedStatus then
        _lastLoggedStatus = newStatus
        debugLog("Status:", newStatus)
    end
end

-- Disconnect all stored connections and cancel all threads
local function cleanupAll()
    for _, conn in ipairs(_connections) do
        if typeof(conn) == "RBXScriptConnection" and conn.Connected then
            conn:Disconnect()
        end
    end
    for _, thread in ipairs(_threads) do
        pcall(function()
            if coroutine.status(thread) ~= "dead" then
                task.cancel(thread)
            end
        end)
    end
    table.clear(_connections)
    table.clear(_threads)
end

-- Store a connection for later cleanup
local function trackConnection(conn)
    _connections[#_connections + 1] = conn
    return conn
end

-- Store a spawned thread for later cleanup
local function trackThread(thread)
    _threads[#_threads + 1] = thread
    return thread
end

-- Only update raycast filter when character reference changes
local function updateRayFilter()
    local player = Players.LocalPlayer
    local char = player and player.Character
    if char and char ~= _lastFilterChar then
        _lastFilterChar = char
        _rayParams.FilterDescendantsInstances = {char}
    end
end

local function castRay(origin, direction)
    return Workspace:Raycast(origin, direction, _rayParams)
end

local function hasGroundBelow(position, maxDist)
    maxDist = maxDist or 10
    local result = castRay(position, Vector3.new(0, -maxDist, 0))
    return result ~= nil, result
end

local function getFloorPart()
    if not _rootPart then return nil end
    local _, result = hasGroundBelow(_rootPart.Position, 10)
    return result and result.Instance or nil
end

-- Squared horizontal distance (avoids sqrt in comparisons)
local function horizontalDistanceSq(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return dx * dx + dz * dz
end

-- ═══════════════════════════════════════════════════════════════
--  Obstacle detection helpers
-- ═══════════════════════════════════════════════════════════════

-- Returns: isNarrow (bool), leftDist, rightDist, totalWidth — always 4 values
local function detectBridge()
    if not _rootPart then return false, 100, 100, 200 end
    local pos = _rootPart.Position
    local cf  = _rootPart.CFrame
    local rightDir = cf.RightVector
    local leftDir  = -rightDir
    local maxCheckDist = BRIDGE_NARROW_THRESHOLD * 2

    local rightEdgeDist = maxCheckDist
    for d = 1, maxCheckDist, 1.0 do
        local checkPos = pos + rightDir * d
        local groundHit = castRay(checkPos, Vector3.new(0, -20, 0))
        if not groundHit then
            rightEdgeDist = d
            break
        end
    end

    local leftEdgeDist = maxCheckDist
    for d = 1, maxCheckDist, 1.0 do
        local checkPos = pos + leftDir * d
        local groundHit = castRay(checkPos, Vector3.new(0, -20, 0))
        if not groundHit then
            leftEdgeDist = d
            break
        end
    end

    local totalWidth = leftEdgeDist + rightEdgeDist
    local isNarrow = totalWidth < (BRIDGE_NARROW_THRESHOLD * 2)

    if isNarrow then
        debugLog("Narrow bridge, width:", totalWidth)
    end

    return isNarrow, leftEdgeDist, rightEdgeDist, totalWidth
end

-- Two-phase gap detection: coarse sweep then fine sweep
-- Returns: gapDetected (bool), gapWidth (number) — always 2 values
local function detectGapAhead()
    if not _rootPart then return false, 0 end
    local pos = _rootPart.Position
    local lookDir = _rootPart.CFrame.LookVector

    -- Phase 1: coarse sweep (step 2)
    local gapSuspected = false
    local suspectStart = nil
    for d = 2, GAP_DETECT_RANGE, 2 do
        local checkPos = pos + lookDir * d
        local groundHit = castRay(checkPos, Vector3.new(0, -10, 0))
        if not groundHit then
            gapSuspected = true
            suspectStart = d
            break
        end
    end

    if not gapSuspected then
        return false, 0
    end

    -- Phase 2: fine sweep (step 0.5) around suspected region
    local gapStart = nil
    local gapEnd = nil
    local searchStart = math.max(2, suspectStart - 2)
    local searchEnd = math.min(GAP_DETECT_RANGE, suspectStart + 10)

    for d = searchStart, searchEnd, 0.5 do
        local checkPos = pos + lookDir * d
        local groundHit = castRay(checkPos, Vector3.new(0, -10, 0))
        if not groundHit then
            if not gapStart then
                gapStart = d
            end
        else
            if gapStart and not gapEnd then
                gapEnd = d
                break
            end
        end
    end

    if not gapStart then
        return false, 0
    end

    if not gapEnd then
        gapEnd = GAP_DETECT_RANGE
    end

    local gapWidth = gapEnd - gapStart
    debugLog("Gap detected, width:", gapWidth)
    return true, gapWidth
end

-- Wall detection with forward rays at increasing heights
-- Returns: wallHit (bool), wallDistance (number), wallHeight (number) — always 3 values
local function detectWall()
    if not _rootPart then return false, 0, 0 end
    local pos = _rootPart.Position
    local lookDir = _rootPart.CFrame.LookVector

    local result = castRay(pos, lookDir * WALL_DETECT_RANGE)
    if not result then
        return false, WALL_DETECT_RANGE, 0
    end

    local wallDist = result.Distance

    local wallHeight = JUMP_HEIGHT + 5
    local allHit = true
    for h = 1, JUMP_HEIGHT + 5, 0.5 do
        local rayOrigin = pos + Vector3.new(0, h, 0)
        local rayResult = castRay(rayOrigin, lookDir * (wallDist + 2))
        if not rayResult then
            wallHeight = h
            allHit = false
            break
        end
    end

    if allHit then
        wallHeight = JUMP_HEIGHT + 5
    end

    debugLog("Wall detected, height:", wallHeight)
    return true, wallDist, wallHeight
end

-- Fan-pattern edge detection
-- Returns: isSafe (bool), dangerDirection (Vector3) — second value is ALWAYS a Vector3
local function detectEdges()
    if not _rootPart then return true, Vector3.zero end
    local pos = _rootPart.Position
    local cf  = _rootPart.CFrame
    local forward = cf.LookVector
    local right   = cf.RightVector

    local directions = {
        forward,
        (forward + right).Unit,
        (forward - right).Unit,
        right,
        -right,
    }

    for _, dir in ipairs(directions) do
        local checkPos = pos + dir * 3
        local hasGround = hasGroundBelow(checkPos, EDGE_RAY_RANGE)
        if not hasGround then
            return false, dir
        end
    end

    local belowOk = hasGroundBelow(pos, EDGE_RAY_RANGE)
    if not belowOk then
        -- Move backward when no ground below (not upward)
        return false, -cf.LookVector
    end

    return true, Vector3.zero
end

-- Returns: isMoving (bool), velocity (Vector3) — always 2 values
local function detectMovingPlatform()
    local floorPart = getFloorPart()
    if not floorPart then return false, Vector3.zero end
    local vel = floorPart.Velocity
    if vel.Magnitude > 0.5 then
        return true, vel
    end
    local assemblyVel = floorPart.AssemblyLinearVelocity
    if assemblyVel and assemblyVel.Magnitude > 0.5 then
        return true, assemblyVel
    end
    return false, Vector3.zero
end

-- ═══════════════════════════════════════════════════════════════
--  Path scoring — cost = distance + jumps*5 + dangerous*10
-- ═══════════════════════════════════════════════════════════════

local function scorePath(waypoints, earlyExitThreshold)
    if not waypoints or #waypoints == 0 then
        return math.huge
    end
    earlyExitThreshold = earlyExitThreshold or math.huge
    local totalDist = 0
    local jumpCount = 0
    local dangerCount = 0
    for i = 2, #waypoints do
        local prev = waypoints[i - 1].Position
        local curr = waypoints[i].Position
        totalDist = totalDist + (curr - prev).Magnitude
        if waypoints[i].Action == Enum.PathWaypointAction.Jump then
            jumpCount = jumpCount + 1
        end
        -- Early exit if already worse than best known
        local currentScore = totalDist + (jumpCount * 5) + (dangerCount * 10)
        if currentScore > earlyExitThreshold then
            return math.huge
        end
        -- Ground check only every 3rd segment (performance)
        if (i % 3 == 0) then
            local midpoint = (prev + curr) / 2
            local groundOk = hasGroundBelow(midpoint, 20)
            if not groundOk then
                dangerCount = dangerCount + 1
            end
        end
    end
    return totalDist + (jumpCount * 5) + (dangerCount * 10)
end

-- Cooldown-guarded multi-candidate pathfinding (used ONLY in moveTo)
local function findBestPath(startPos, targetPos)
    local now = tick()
    if now - _lastPathTime < PATH_COOLDOWN then
        debugLog("Path cooldown active, skipping recompute")
        return nil, nil, math.huge
    end
    _lastPathTime = now

    updateRayFilter()

    local results = {}
    local completed = 0
    local total = #AGENT_RADII

    local offsets = {
        Vector3.new(0, 0, 0),
        Vector3.new(2, 0, 0),
        Vector3.new(-2, 0, 0),
        Vector3.new(0, 0, 2),
        Vector3.new(0, 0, -2),
    }

    -- Parallel ComputeAsync; every spawned thread is tracked for cleanup
    for i, radius in ipairs(AGENT_RADII) do
        trackThread(task.spawn(function()
            local params = {
                AgentRadius  = radius,
                AgentHeight  = 5,
                AgentCanJump = true,
                AgentCanClimb = false,
                WaypointSpacing = 4,
            }
            local offset = offsets[i] or Vector3.zero
            local path = PathfindingService:CreatePath(params)
            local ok = pcall(function()
                path:ComputeAsync(startPos, targetPos + offset)
            end)
            if ok and path.Status == Enum.PathStatus.Success then
                local waypoints = path:GetWaypoints()
                results[i] = { path = path, waypoints = waypoints }
            end
            -- completed always incremented LAST, after any writes
            completed = completed + 1
        end))
    end

    -- Wait for all candidates (max 2s)
    local waitStart = tick()
    while completed < total and tick() - waitStart < 2 do
        task.wait(0)
    end

    local bestWaypoints = nil
    local bestScore = math.huge
    local bestPath = nil

    for i = 1, total do
        local r = results[i]
        if r and r.waypoints then
            local score = scorePath(r.waypoints, bestScore * 2)
            if score < bestScore then
                bestScore = score
                bestWaypoints = r.waypoints
                bestPath = r.path
            end
        end
    end

    if bestWaypoints then
        debugLog("Path found, score:", bestScore, "waypoints:", #bestWaypoints)
    end

    return bestPath, bestWaypoints, bestScore
end

-- Bypasses cooldown — used for ALL internal recalculations inside followPath
local function forceRecalcPath(startPos, targetPos)
    _lastPathTime = 0
    return findBestPath(startPos, targetPos)
end

-- ═══════════════════════════════════════════════════════════════
--  Safety system
-- ═══════════════════════════════════════════════════════════════

local function findNearestSafePlatform()
    if not _rootPart then return nil end
    local pos = _rootPart.Position
    local iteration = 0
    for angle = 0, 360, 30 do
        for dist = 5, 50, 5 do
            iteration = iteration + 1
            -- Yield every 30 rays to prevent frame freeze
            if iteration % 30 == 0 then
                task.wait(0)
            end
            local rad = math.rad(angle)
            local checkPos = pos + Vector3.new(math.cos(rad) * dist, 0, math.sin(rad) * dist)
            local grounded, result = hasGroundBelow(checkPos, 100)
            if grounded and result then
                return result.Position + Vector3.new(0, 3, 0)
            end
        end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════
--  Core navigation loop
--  Pattern: while ... do repeat ... until true (break = continue)
-- ═══════════════════════════════════════════════════════════════

local function followPath(waypoints, options)
    if not waypoints or #waypoints == 0 then
        setStatus("error")
        _moving = false
        return
    end

    local jumpEnabled  = options.jumpEnabled
    local avoidVoid    = options.avoidVoid
    local precision    = options.precision
    local precisionSq  = precision * precision
    local timeout      = options.timeout
    local dynamicRecalc = options.dynamicRecalc
    local targetPos    = options._targetPosition

    local startTime    = tick()
    local lastPos      = _rootPart and _rootPart.Position or Vector3.zero
    local lastMoveTime = tick()
    local waypointIdx  = 2

    setStatus("moving")

    while _moving and not _stopFlag and _rootPart and _humanoid do
    repeat -- repeat-until wrapper: "break" here acts as "continue"
        -- Timeout check
        if tick() - startTime > timeout then
            setStatus("error")
            _moving = false
            return
        end

        -- Death check (Health guarded by _humanoid in while condition)
        if _humanoid.Health <= 0 then
            setStatus("error")
            _moving = false
            return
        end

        local currentPos = _rootPart.Position

        -- Reached target?
        if horizontalDistanceSq(currentPos, targetPos) <= precisionSq then
            setStatus("done")
            _moving = false
            return
        end

        -- Stuck detector (squared distance, no sqrt)
        local sdx = currentPos.X - lastPos.X
        local sdz = currentPos.Z - lastPos.Z
        if (sdx*sdx + sdz*sdz) > STUCK_DISTANCE_SQ then
            lastPos = currentPos
            lastMoveTime = tick()
        elseif tick() - lastMoveTime > STUCK_TIME then
            setStatus("stuck")
            debugLog("STUCK detected, recalculating")
            if jumpEnabled then
                _humanoid.Jump = true
            end
            task.wait(0.3)
            if dynamicRecalc and _rootPart then
                local _, newWaypoints = forceRecalcPath(_rootPart.Position, targetPos)
                if newWaypoints then
                    waypoints = newWaypoints
                    waypointIdx = 2
                end
            end
            lastPos = _rootPart and _rootPart.Position or lastPos
            lastMoveTime = tick()
            setStatus("moving")
        end

        -- Falling recovery
        local grounded = hasGroundBelow(currentPos, 10)
        if not grounded then
            setStatus("falling")
            debugLog("FALLING, searching safe platform")
            local safePlatform = findNearestSafePlatform()
            if safePlatform and _humanoid then
                _humanoid:MoveTo(safePlatform)
            end
            task.wait(0.5)
            if _rootPart then
                local nowGrounded = hasGroundBelow(_rootPart.Position, 10)
                if nowGrounded then
                    setStatus("moving")
                    if dynamicRecalc then
                        local _, newWaypoints = forceRecalcPath(_rootPart.Position, targetPos)
                        if newWaypoints then
                            waypoints = newWaypoints
                            waypointIdx = 2
                        end
                    end
                end
            end
            task.wait(GROUND_CHECK_INTERVAL)
            break -- continue
        end

        local onMoving, platformVel = detectMovingPlatform()

        -- Exhausted waypoints: recalc or finish
        if waypointIdx > #waypoints then
            if dynamicRecalc and horizontalDistanceSq(currentPos, targetPos) > precisionSq then
                local _, newWaypoints = forceRecalcPath(currentPos, targetPos)
                if newWaypoints and #newWaypoints > 1 then
                    waypoints = newWaypoints
                    waypointIdx = 2
                else
                    setStatus("error")
                    _moving = false
                    return
                end
            else
                setStatus("done")
                _moving = false
                return
            end
        end

        local wp = waypoints[waypointIdx]
        local wpPos = wp.Position

        if onMoving then
            wpPos = wpPos + platformVel * 0.1
        end

        updateRayFilter()

        -- Throttled obstacle detection with cached results
        local now = tick()
        local gapDetected, gapWidth
        local wallHit, wallDist, wallHeight
        local isNarrow, leftDist, rightDist
        local edgeSafe, dangerDir

        if now - _timers.gap >= GAP_CHECK_INTERVAL then
            _timers.gap = now
            _cachedGap[1], _cachedGap[2] = detectGapAhead()
        end
        gapDetected, gapWidth = _cachedGap[1], _cachedGap[2]

        if now - _timers.wall >= WALL_CHECK_INTERVAL then
            _timers.wall = now
            _cachedWall[1], _cachedWall[2], _cachedWall[3] = detectWall()
        end
        wallHit, wallDist, wallHeight = _cachedWall[1], _cachedWall[2], _cachedWall[3]

        if now - _timers.bridge >= BRIDGE_CHECK_INTERVAL then
            _timers.bridge = now
            _cachedBridge[1], _cachedBridge[2], _cachedBridge[3], _cachedBridge[4] = detectBridge()
        end
        isNarrow, leftDist, rightDist = _cachedBridge[1], _cachedBridge[2], _cachedBridge[3]

        if now - _timers.edges >= EDGE_CHECK_INTERVAL then
            _timers.edges = now
            _cachedEdge[1], _cachedEdge[2] = detectEdges()
        end
        edgeSafe, dangerDir = _cachedEdge[1], _cachedEdge[2]

        -- 1) Gap handling: jump small gaps (moving forward), reroute large ones
        if avoidVoid and gapDetected then
            local jumpable = gapWidth < 8 and jumpEnabled
            if jumpable then
                _humanoid.Jump = true
                local jumpTarget = currentPos + _rootPart.CFrame.LookVector * 10
                _humanoid:MoveTo(jumpTarget)
                task.wait(0.6)
                if dynamicRecalc and _rootPart then
                    local _, newWaypoints = forceRecalcPath(_rootPart.Position, targetPos)
                    if newWaypoints then
                        waypoints = newWaypoints
                        waypointIdx = 2
                    end
                end
                break -- continue
            else
                if dynamicRecalc then
                    local _, newWaypoints = forceRecalcPath(currentPos, targetPos)
                    if newWaypoints then
                        waypoints = newWaypoints
                        waypointIdx = 2
                        task.wait(0.1)
                        break -- continue
                    end
                end
                setStatus("error")
                _moving = false
                return
            end
        end

        -- 2) Edge handling: walk away from the edge danger direction
        if avoidVoid and not edgeSafe and dangerDir and dangerDir ~= Vector3.zero then
            local awayDir = -dangerDir
            local safeTarget = currentPos + awayDir * 3
            _humanoid:MoveTo(safeTarget)
            task.wait(0.5)
            if dynamicRecalc and _rootPart then
                local _, newWaypoints = forceRecalcPath(_rootPart.Position, targetPos)
                if newWaypoints then
                    waypoints = newWaypoints
                    waypointIdx = 2
                end
            end
            task.wait(0.1)
            break -- continue
        end

        -- 3) Wall handling: jump short walls, reroute tall ones
        if wallHit and wallDist < WALL_DETECT_RANGE then
            if wallHeight < JUMP_HEIGHT and jumpEnabled then
                _humanoid.Jump = true
                local jumpTarget = currentPos + _rootPart.CFrame.LookVector * 8
                _humanoid:MoveTo(jumpTarget)
                task.wait(0.5)
                if dynamicRecalc and _rootPart then
                    local _, newWaypoints = forceRecalcPath(_rootPart.Position, targetPos)
                    if newWaypoints then
                        waypoints = newWaypoints
                        waypointIdx = 2
                    end
                end
                break -- continue
            else
                if dynamicRecalc then
                    local _, newWaypoints = forceRecalcPath(currentPos, targetPos)
                    if newWaypoints then
                        waypoints = newWaypoints
                        waypointIdx = 2
                        task.wait(0.1)
                        break -- continue
                    end
                end
            end
        end

        -- 4) Bridge handling: slow down and center on narrow surfaces
        if isNarrow then
            if _originalWalkSpeed then
                _humanoid.WalkSpeed = math.max(_originalWalkSpeed * 0.5, 4)
            else
                debugLog("WARNING: _originalWalkSpeed nil, skipping slowdown")
            end
            if leftDist ~= rightDist then
                local offset = (rightDist - leftDist) / 2
                local rightVec = _rootPart.CFrame.RightVector
                wpPos = wpPos + rightVec * offset * 0.5
            end
        else
            if _originalWalkSpeed and _humanoid.WalkSpeed < _originalWalkSpeed then
                _humanoid.WalkSpeed = _originalWalkSpeed
            end
        end

        -- 5) Jump-flagged waypoints
        if wp.Action == Enum.PathWaypointAction.Jump and jumpEnabled then
            _humanoid.Jump = true
        end

        _humanoid:MoveTo(wpPos)

        -- Linear waypoint timeout: true distance / 8 (sqrt runs once per waypoint)
        local wdx = wpPos.X - currentPos.X
        local wdz = wpPos.Z - currentPos.Z
        local wpDistSq = wdx*wdx + wdz*wdz
        local wpDist = math.sqrt(wpDistSq)
        local wpTimeout = math.clamp(wpDist / 8, 0.5, 3)

        local wpStart = tick()
        local wpReached = false
        while not _stopFlag and _rootPart and _humanoid
              and _humanoid.Health > 0 and tick() - wpStart < wpTimeout do
            if horizontalDistanceSq(_rootPart.Position, wpPos) < 9 then
                wpReached = true
                break -- breaks the INNER waypoint-wait loop (correct)
            end
            task.wait(GROUND_CHECK_INTERVAL)
        end

        if wpReached then
            waypointIdx = waypointIdx + 1
        else
            if dynamicRecalc and _rootPart then
                local _, newWaypoints = forceRecalcPath(_rootPart.Position, targetPos)
                if newWaypoints then
                    waypoints = newWaypoints
                    waypointIdx = 2
                else
                    waypointIdx = waypointIdx + 1
                end
            else
                waypointIdx = waypointIdx + 1
            end
        end

        -- Adaptive loop interval: faster polling near obstacles
        local loopInterval = GROUND_CHECK_INTERVAL
        if not gapDetected and not wallHit and not isNarrow and edgeSafe then
            loopInterval = 0.2
        else
            loopInterval = GROUND_CHECK_INTERVAL
        end
        task.wait(loopInterval)

    until true
    end

    if _stopFlag then
        setStatus("idle")
    end
    _moving = false
end

-- ═══════════════════════════════════════════════════════════════
--  PUBLIC API
-- ═══════════════════════════════════════════════════════════════

function Navigation.init(humanoid, rootPart)
    assert(humanoid, "Navigation.init: humanoid is nil")
    assert(rootPart, "Navigation.init: rootPart is nil")
    Navigation.stop()
    _humanoid = humanoid
    _rootPart = rootPart
    _originalWalkSpeed = humanoid.WalkSpeed
    setStatus("idle")
    _moving   = false
    _stopFlag = false
    updateRayFilter()

    trackConnection(_humanoid.Died:Connect(function()
        Navigation.stop()
    end))

    -- Auto re-initialize when the character respawns
    local player = Players.LocalPlayer
    trackConnection(player.CharacterAdded:Connect(function(newChar)
        local newHum = newChar:WaitForChild("Humanoid")
        local newRoot = newChar:WaitForChild("HumanoidRootPart")
        _humanoid = newHum
        _rootPart = newRoot
        _originalWalkSpeed = newHum.WalkSpeed
        setStatus("idle")
        _moving = false
        _stopFlag = false
        updateRayFilter()
        debugLog("Character respawned, re-initialized")
        trackConnection(newHum.Died:Connect(function()
            Navigation.stop()
        end))
    end))

    debugLog("Initialized, WalkSpeed:", _originalWalkSpeed)
end

function Navigation.moveTo(targetPosition, options)
    assert(_humanoid, "Navigation.moveTo: call Navigation.init() first")
    assert(_rootPart, "Navigation.moveTo: rootPart is nil, call init()")
    assert(typeof(targetPosition) == "Vector3", "Navigation.moveTo: targetPosition must be Vector3")

    -- Active wait: guarantee old thread fully exited before starting new one
    if _moving then
        _stopFlag = true
        local waitStart = tick()
        while _moving and tick() - waitStart < 1 do
            task.wait(0.05)
        end
        -- [FIX] Clear dead thread references so _threads never grows unbounded (memory leak fix)
        table.clear(_threads)
    end

    options = options or {}
    local opts = {
        jumpEnabled  = options.jumpEnabled ~= false,
        avoidVoid    = options.avoidVoid ~= false,
        precision    = options.precision or 3,
        timeout      = options.timeout or 30,
        dynamicRecalc = options.dynamicRecalc ~= false,
        _targetPosition = targetPosition,
    }

    _moving   = true
    _stopFlag = false
    _timers = { bridge = 0, gap = 0, wall = 0, edges = 0 }
    _lastPathTime = 0
    setStatus("moving")
    updateRayFilter()

    -- Initial path: cooldown already reset above, findBestPath runs fresh
    local _, waypoints = findBestPath(_rootPart.Position, targetPosition)

    if not waypoints or #waypoints < 2 then
        -- Fallback: direct movement if pathfinding fails entirely
        debugLog("No path found, falling back to direct movement")
        setStatus("moving")
        _humanoid:MoveTo(targetPosition)
        trackThread(task.spawn(function()
            local startTime = tick()
            local precisionSq = opts.precision * opts.precision
            while _moving and not _stopFlag and _rootPart
                  and _humanoid and _humanoid.Health > 0 do
                if horizontalDistanceSq(_rootPart.Position, targetPosition) <= precisionSq then
                    setStatus("done")
                    _moving = false
                    return
                end
                if tick() - startTime > opts.timeout then
                    setStatus("error")
                    _moving = false
                    return
                end
                _humanoid:MoveTo(targetPosition)
                task.wait(0.5)
            end
        end))
        return
    end

    trackThread(task.spawn(function()
        followPath(waypoints, opts)
    end))
end

function Navigation.stop()
    _stopFlag = true
    _moving   = false
    if _humanoid then
        pcall(function()
            _humanoid:MoveTo(_rootPart and _rootPart.Position or Vector3.zero)
        end)
    end
    if _humanoid and _originalWalkSpeed then
        pcall(function()
            _humanoid.WalkSpeed = _originalWalkSpeed
        end)
    end
    _lastPathTime = 0
    cleanupAll()
    setStatus("idle")
end

function Navigation.isMoving()
    return _moving
end

function Navigation.getStatus()
    return _status
end

function Navigation.setDebug(enabled)
    _debug = enabled
    _lastLoggedStatus = ""
    debugLog("Debug mode:", enabled and "ON" or "OFF")
end

return Navigation
