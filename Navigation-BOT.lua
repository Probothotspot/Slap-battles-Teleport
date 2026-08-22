--[[
    Navigation Module v2.1 (Rail-Locked, Polished Release)
    Advanced Pathfinding & Obstacle Avoidance for Roblox (Luau)
    Environment: Delta Executor
    Load: local Nav = loadstring(game:HttpGet(url))()
          -- init() вызывается автоматически при загрузке,
          -- moveTo() доступен сразу после loadstring(...)()

    v2.1 — Micro-Optimization & Guard Update (поверх v2.0):

      1. STRING-PULLING RUN-UP GUARD — сглаживание теперь проверяет
         не только следующую, но и ТЕКУЩУЮ точку: если
         waypoints[waypointIdx].Action == Jump, цикл сглаживания
         немедленно прерывается (break). Бот больше не срезает
         дистанцию разбега прямо перед прыжком через пропасть,
         траектория прыжка не ломается.
      2. PATHFINDER LATENCY — ожидание кандидатов в findBestPath и
         радиальный скан платформ переведены на нативный task.wait()
         вместо task.wait(0). Добавлен моментальный ранний выход из
         цикла ожидания: как только готов хотя бы один "идеальный"
         путь (без Jump-вейпоинтов, без опасных сегментов, не
         длиннее ~1.8x прямой линии), флаг idealFound мгновенно
         снимает блокировку, и тяжёлые оставшиеся кандидаты не
         тянут лишний фрейм.
      3. FALL-RECOVERY SAFETY — applyFallRecovery защищена от
         смерти/деспавна персонажа ровно в кадр импульса: строгая
         проверка _rootPart.Parent в условии цикла + pcall вокруг
         присваивания AssemblyLinearVelocity. Редкий краш скрипта
         на невалидном root part исключён.

    Фундамент v2.0 (все 5 фиксов + 3 улучшения) сохранён:
      • SPEED-AWARE WP TIMEOUT — таймаут вейпоинта от текущей
        скорости: clamp((courseLen / max(WalkSpeed, 4)) * 2.5, 1.2, 8)
      • NO FALSE-POSITIVE BLOCKS — courseBlocked только при явном
        неперепрыгиваемом разрыве, микро-стыки не пугают роутер
      • EXACT TARGET — все пути строго до targetPos, оффсеты цели
        удалены; финиш при precision < 2 работает
      • NO WALKSPEED LEAK — restoreWalkSpeed() на КАЖДОМ выходе
        из followPath и в stop()
      • PHYSICAL FALL RECOVERY — импульс к _lastSafePos с Y ≈ 18
      • STRING PULLING — срез лишних вейпоинтов на чистых прямых
      • ACTIVE MICRO-UNSTUCK — два стрейфа до траты пересчётов
      • AUTO-INIT — bootstrap после loadstring + lazy ensure-init

    Rail-Locked ядро v1.8 сохранено по семантике:
      Path Commitment (recalc только при stuck / blocked),
      Sensor Priority (вейпоинт > боковые сенсоры),
      Course-Locked Sensors (лучи строго вдоль курса),
      No Danger Inversion (детерминированный возврат на _lastSafePos),
      Anti Corner-Cut (segmentHasGround перед каждым MoveTo),
      Memory Hygiene (_threads чистится каждым moveTo,
      CharacterAdded в _systemConnections переживает stop/респавн),
      os.clock() вместо tick(), AssemblyLinearVelocity для платформ.
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

-- Runtime registry: cleared on every stop()/moveTo()
local _connections = {}
local _threads     = {}

-- System registry: persistent listeners, NEVER cleared by stop()
local _systemConnections = {}
local _diedConn          = nil
local _systemHooked      = false

local _originalWalkSpeed = nil
local _debug = false
local _lastLoggedStatus = ""

-- Last memorized grounded position (deterministic fall recovery)
local _lastSafePos = nil

-- Rail-lock: recalculations are exceptional events, not routine.
-- Hard budget per moveTo() call.
local MAX_RECALCS = 5

-- Cached RaycastParams (reused every frame to avoid GC pressure)
local _rayParams = RaycastParams.new()
_rayParams.FilterType = Enum.RaycastFilterType.Exclude
_rayParams.FilterDescendantsInstances = {}

local _lastFilterChar = nil

-- Constants
local GROUND_CHECK_INTERVAL   = 0.1
local CALM_LOOP_INTERVAL      = 0.15
local STUCK_DISTANCE          = 1
local STUCK_DISTANCE_SQ       = STUCK_DISTANCE * STUCK_DISTANCE
local STUCK_TIME              = 2
local JUMP_HEIGHT             = 7.2
local GAP_DETECT_RANGE        = 15
local JUMPABLE_GAP            = 8
local FALL_AIR_TIME           = 1.2
local BRIDGE_NARROW_THRESHOLD = 4
local WALL_DETECT_RANGE       = 5
local WALL_BLOCK_DIST         = 3
local WP_REACH_RADIUS_SQ      = 9 -- 3 studs, squared
local AGENT_RADII             = {1, 2, 3, 1.5, 2.5}

-- [v2.0] Physical fall recovery tuning
local RECOVER_Y_VELOCITY      = 18   -- damp freefall, arc back up
local RECOVER_MAX_TIME        = 2.5  -- hard cap for one recovery
local RECOVER_STEP            = 0.12 -- re-steer period while airborne

-- [v2.0] Active micro-unstuck tuning
local UNSTUCK_SIDEWAYS        = 3    -- strafe vector length (studs)
local UNSTUCK_BACKPEDAL       = 2    -- backward vector length (studs)
local UNSTUCK_MAX_ATTEMPTS    = 2    -- strafes BEFORE spending a recalc

-- Throttled sensor caches (bridge slowdown + wall scan only;
-- edge/gap sensors no longer steer the character)
local _timers = { bridge = 0, wall = 0, smooth = 0 }
local BRIDGE_CHECK_INTERVAL = 0.25
local WALL_CHECK_INTERVAL   = 0.15
local SMOOTH_CHECK_INTERVAL = 0.2 -- [v2.0] string pulling cadence
local _cachedBridge = {false, 100, 100, 200}
local _cachedWall   = {false, 0, 0}

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

-- [v2.0 FIX 4] Guaranteed WalkSpeed restore.
-- Called on EVERY exit path of followPath() and inside stop(), so a
-- bridge slowdown can never leak past the end of a route.
local function restoreWalkSpeed()
    if _humanoid and _originalWalkSpeed then
        pcall(function()
            _humanoid.WalkSpeed = _originalWalkSpeed
        end)
    end
end

-- Disconnect RUNTIME connections and cancel threads.
-- System listeners (_systemConnections / _diedConn) stay alive:
-- CharacterAdded must survive stop() and respawn cycles.
local function cleanupRuntime()
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

-- Store a runtime connection for later cleanup
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

-- Locked course: horizontal unit vector from→to plus true distance.
-- Returns (Vector3.zero, 0) for degenerate segments.
local function courseDirection(fromPos, toPos)
    local dx = toPos.X - fromPos.X
    local dz = toPos.Z - fromPos.Z
    local lenSq = dx * dx + dz * dz
    if lenSq < 0.000001 then
        return Vector3.zero, 0
    end
    local len = math.sqrt(lenSq)
    return Vector3.new(dx / len, 0, dz / len), len
end

-- ═══════════════════════════════════════════════════════════════
--  Obstacle detection helpers (course-locked versions)
-- ═══════════════════════════════════════════════════════════════

-- Bridge width measurement. Measurement ONLY — never steers.
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
        debugLog("Narrow bridge, width:", totalWidth, "(slowdown only, no lateral shift)")
    end

    return isNarrow, leftEdgeDist, rightEdgeDist, totalWidth
end

-- Anti corner-cut: sample the straight segment from→to every 2 studs.
-- Returns false as soon as ANY sample point has no ground under it.
local function segmentHasGround(fromPos, toPos)
    local dir, dist = courseDirection(fromPos, toPos)
    if dist <= 2 then
        return true
    end
    local sampleY = math.max(fromPos.Y, toPos.Y) + 1
    local d = 2
    while d < dist do
        local samplePos = Vector3.new(fromPos.X + dir.X * d, sampleY, fromPos.Z + dir.Z * d)
        local ok = hasGroundBelow(samplePos, 25)
        if not ok then
            return false
        end
        d = d + 2
    end
    return true
end

-- Two-phase gap detection along the LOCKED course direction (not LookVector).
-- Returns: gapDetected (bool), gapWidth (number) — always 2 values
local function detectGapAlong(direction)
    if not _rootPart then return false, 0 end
    if direction == Vector3.zero then return false, 0 end
    local pos = _rootPart.Position

    -- Phase 1: coarse sweep (step 2)
    local gapSuspected = false
    local suspectStart = nil
    for d = 2, GAP_DETECT_RANGE, 2 do
        local checkPos = pos + direction * d
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
        local checkPos = pos + direction * d
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
    debugLog("Gap on course, width:", gapWidth)
    return true, gapWidth
end

-- Wall detection along the LOCKED course direction.
-- Returns: wallHit (bool), wallDistance (number), wallHeight (number)
local function detectWallAlong(direction)
    if not _rootPart then return false, 0, 0 end
    if direction == Vector3.zero then return false, 0, 0 end
    local pos = _rootPart.Position

    local result = castRay(pos, direction * WALL_DETECT_RANGE)
    if not result then
        return false, WALL_DETECT_RANGE, 0
    end

    local wallDist = result.Distance

    -- Height sweep: find the first height that clears the wall
    local maxH = JUMP_HEIGHT + 2
    local wallHeight = maxH
    for h = 1, maxH, 1 do
        local rayOrigin = pos + Vector3.new(0, h, 0)
        local rayResult = castRay(rayOrigin, direction * (wallDist + 1.5))
        if not rayResult then
            wallHeight = h
            break
        end
    end

    debugLog("Wall on course, dist:", wallDist, "height:", wallHeight)
    return true, wallDist, wallHeight
end

-- Moving platform via AssemblyLinearVelocity (Velocity is deprecated).
-- Returns: isMoving (bool), velocity (Vector3) — always 2 values
local function detectMovingPlatform()
    local floorPart = getFloorPart()
    if not floorPart then return false, Vector3.zero end
    local vel = floorPart.AssemblyLinearVelocity
    if vel and vel.Magnitude > 0.5 then
        return true, vel
    end
    return false, Vector3.zero
end

-- [v2.0] STRING PULLING sight test.
-- True only when BOTH conditions hold:
--   1. Direct line of sight: no wall between fromPos and toPos
--      (horizontal ray at safe height along the locked course line).
--   2. Ground under the ENTIRE straight segment (anti corner-cut).
-- Skipping is refused for big upward climbs (jump-routed chains stay).
local function canSkipTo(fromPos, toPos)
    local dy = toPos.Y - fromPos.Y
    if dy > JUMP_HEIGHT * 0.7 then
        return false
    end
    local dir, dist = courseDirection(fromPos, toPos)
    if dist < 0.001 then
        return false
    end
    local rayHeight = math.max(fromPos.Y, toPos.Y) + 1.5
    local origin = Vector3.new(fromPos.X, rayHeight, fromPos.Z)
    if castRay(origin, Vector3.new(dir.X * dist, 0, dir.Z * dist)) then
        return false -- wall in the way
    end
    return segmentHasGround(fromPos, toPos)
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

-- [v2.1] Fast "ideal path" classifier for the early-exit wait loop.
-- Ideal = no Jump waypoints, ground under every sampled segment
-- (same every-3rd-segment sampling policy as scorePath) and the
-- route stays SHORT (≤ ~1.8x the straight line, +5 studs of slack).
-- This is only a latency hint: full scoring still decides the winner.
local function isIdealPath(waypoints)
    if not waypoints or #waypoints < 2 then
        return false
    end
    local totalDist = 0
    for i = 2, #waypoints do
        local prev = waypoints[i - 1].Position
        local curr = waypoints[i].Position
        totalDist = totalDist + (curr - prev).Magnitude
        if waypoints[i].Action == Enum.PathWaypointAction.Jump then
            return false
        end
        if i % 3 == 0 then
            local midpoint = (prev + curr) / 2
            if not hasGroundBelow(midpoint, 20) then
                return false
            end
        end
    end
    local first = waypoints[1].Position
    local last  = waypoints[#waypoints].Position
    local direct = (last - first).Magnitude
    return totalDist <= direct * 1.8 + 5
end

-- Cooldown-guarded multi-candidate pathfinding
local function findBestPath(startPos, targetPos)
    local now = os.clock()
    if now - _lastPathTime < PATH_COOLDOWN then
        debugLog("Path cooldown active, skipping recompute")
        return nil, nil, math.huge
    end
    _lastPathTime = now

    updateRayFilter()

    local results = {}
    local completed = 0
    local total = #AGENT_RADII
    local idealFound = false -- [v2.1] instant early-exit flag

    -- [v2.0 FIX 3] Every candidate computes to the EXACT targetPos.
    -- The old ±2 stud target offsets shifted the final waypoint and
    -- made precision < 2 finishes impossible; they are removed for
    -- good. Route variety now comes only from AgentRadius.
    for i, radius in ipairs(AGENT_RADII) do
        trackThread(task.spawn(function()
            local params = {
                AgentRadius  = radius,
                AgentHeight  = 5,
                AgentCanJump = true,
                AgentCanClimb = false,
                WaypointSpacing = 4,
            }
            local path = PathfindingService:CreatePath(params)
            local ok = pcall(function()
                path:ComputeAsync(startPos, targetPos)
            end)
            if ok and path.Status == Enum.PathStatus.Success then
                local waypoints = path:GetWaypoints()
                results[i] = { path = path, waypoints = waypoints }
                -- [v2.1] Flag an ideal short no-jump/no-danger route
                -- the moment it lands → wait loop exits immediately,
                -- heavy straggler candidates are no longer awaited.
                if not idealFound and isIdealPath(waypoints) then
                    idealFound = true
                end
            end
            -- completed always incremented LAST, after any writes
            completed = completed + 1
        end))
    end

    -- Wait for all candidates (max 2s), with an instant early exit
    -- as soon as an ideal path is ready. [v2.1] Native task.wait()
    -- replaces task.wait(0).
    local waitStart = os.clock()
    while completed < total and not idealFound and os.clock() - waitStart < 2 do
        task.wait()
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

-- Bypasses cooldown — used for the RARE exceptional recalculations:
-- genuine stuck (after failed micro-unstuck) or physically blocked course
local function forceRecalcPath(startPos, targetPos)
    _lastPathTime = 0
    return findBestPath(startPos, targetPos)
end

-- ═══════════════════════════════════════════════════════════════
--  Safety system
-- ═══════════════════════════════════════════════════════════════

-- Radial sweep for the nearest safe platform.
-- Used ONLY as a last resort when _lastSafePos has not been memorized yet.
local function findNearestSafePlatform()
    if not _rootPart then return nil end
    local pos = _rootPart.Position
    local iteration = 0
    for angle = 0, 360, 30 do
        for dist = 5, 50, 5 do
            iteration = iteration + 1
            -- Yield every 30 rays to prevent frame freeze
            -- [v2.1] native task.wait() instead of task.wait(0)
            if iteration % 30 == 0 then
                task.wait()
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

-- [v2.0 FIX 5] PHYSICAL fall recovery.
-- Humanoid:MoveTo cannot steer a body in Freefall, so we drive the
-- root part directly: horizontal AssemblyLinearVelocity points at the
-- recovery platform while Y ~= 18 cancels the freefall and arcs the
-- character back up. Re-steered every RECOVER_STEP until grounded
-- (or RECOVER_MAX_TIME hard cap), so the arc tracks the target even
-- if the platform is moving.
-- [v2.1] Crash-proofed: a character dying/despawning in the exact
-- impulse frame would invalidate the root part mid-assignment.
-- Guarded twice: strict _rootPart.Parent check in the loop
-- condition + pcall around the velocity write.
local function applyFallRecovery(recovery)
    if not _rootPart or not _rootPart.Parent or not _humanoid then return end
    _humanoid:MoveTo(recovery) -- keeps steering intent AFTER landing
    local recoverStart = os.clock()
    while not _stopFlag
          and _rootPart and _rootPart.Parent -- [v2.1] despawn guard
          and _humanoid and _humanoid.Health > 0
          and os.clock() - recoverStart < RECOVER_MAX_TIME do
        local pos = _rootPart.Position
        if hasGroundBelow(pos, 6) then
            break -- back on solid ground
        end
        local dir, len = courseDirection(pos, recovery)
        local horizSpeed = math.clamp(len * 2.5, 10, 30)
        -- [v2.1] pcall turns a mid-flight invalidation race into a
        -- silent abort instead of a hard script error.
        local okImpulse = pcall(function()
            _rootPart.AssemblyLinearVelocity = Vector3.new(
                dir.X * horizSpeed,
                RECOVER_Y_VELOCITY,
                dir.Z * horizSpeed
            )
        end)
        if not okImpulse then
            debugLog("Fall recovery aborted: root part invalidated")
            break
        end
        task.wait(RECOVER_STEP)
    end
end

-- ═══════════════════════════════════════════════════════════════
--  Core navigation loop — RAIL-LOCKED
--  Rules:
--   • MoveTo() is issued ONLY toward the current committed waypoint
--     (plus deterministic fall recovery to _lastSafePos).
--   • Side sensors never steer. Waypoint wins whenever its segment
--     from the current position has ground under it.
--   • Path recalculation happens ONLY on: genuine stuck (A, after the
--     micro-unstuck strafes fail) or a physically blocked course
--     (B: tall wall / EXPLICIT unjumpable gap / unreachable waypoint).
--   • [v2.0] Clean straight runs are shortened by string pulling;
--     WalkSpeed is restored on every single exit.
--  Pattern: while ... do repeat ... until true (break = continue)
-- ═══════════════════════════════════════════════════════════════

local function followPath(waypoints, options)
    if not waypoints or #waypoints == 0 then
        setStatus("error")
        _moving = false
        restoreWalkSpeed()
        return
    end

    local jumpEnabled  = options.jumpEnabled
    local avoidVoid    = options.avoidVoid
    local precision    = options.precision
    local precisionSq  = precision * precision
    local timeout      = options.timeout
    local targetPos    = options._targetPosition

    local startTime      = os.clock()
    local lastPos        = _rootPart and _rootPart.Position or Vector3.zero
    local lastMoveTime   = os.clock()
    local lastGrounded   = os.clock()
    local waypointIdx    = 2
    local lastWpIdx      = 1
    local recalcCount    = 0
    local stuckAttempts  = 0 -- [v2.0] micro-unstuck strafes used

    setStatus("moving")

    while _moving and not _stopFlag and _rootPart and _humanoid do
    repeat -- repeat-until wrapper: "break" here acts as "continue"
        -- Timeout check
        if os.clock() - startTime > timeout then
            setStatus("error")
            _moving = false
            restoreWalkSpeed() -- [v2.0 FIX 4]
            return
        end

        -- Death check (Health guarded by _humanoid in while condition)
        if _humanoid.Health <= 0 then
            setStatus("error")
            _moving = false
            restoreWalkSpeed() -- [v2.0 FIX 4]
            return
        end

        local currentPos = _rootPart.Position

        -- Reached target?
        if horizontalDistanceSq(currentPos, targetPos) <= precisionSq then
            setStatus("done")
            _moving = false
            restoreWalkSpeed() -- [v2.0 FIX 4]
            return
        end

        -- ─────────────────────────────────────────────────────
        -- (A) Stuck detector with ACTIVE MICRO-UNSTUCK [v2.0]
        --   Attempts 1..2: strafe sideways + backpedal + jump.
        --   Recalc budget is spent ONLY if strafes do not help.
        -- ─────────────────────────────────────────────────────
        local sdx = currentPos.X - lastPos.X
        local sdz = currentPos.Z - lastPos.Z
        if (sdx * sdx + sdz * sdz) > STUCK_DISTANCE_SQ then
            lastPos = currentPos
            lastMoveTime = os.clock()
            stuckAttempts = 0 -- real motion resets the strafe counter
        elseif os.clock() - lastMoveTime > STUCK_TIME then
            stuckAttempts = stuckAttempts + 1

            if stuckAttempts <= UNSTUCK_MAX_ATTEMPTS then
                -- Active evasion maneuver (recalc NOT spent)
                setStatus("unstuck")
                debugLog("STUCK: micro-unstuck #", stuckAttempts, "(no recalc spent)")
                if _rootPart then
                    local cf = _rootPart.CFrame
                    local strafeDir = (stuckAttempts % 2 == 1) and cf.RightVector or -cf.RightVector
                    local unstickPos = currentPos
                        + strafeDir * UNSTUCK_SIDEWAYS
                        - cf.LookVector * UNSTUCK_BACKPEDAL
                    if jumpEnabled then
                        _humanoid.Jump = true
                    end
                    -- Strafe only onto solid ground: never into the void
                    if hasGroundBelow(unstickPos + Vector3.new(0, 1.5, 0), 25) then
                        _humanoid:MoveTo(unstickPos)
                        task.wait(0.45)
                    else
                        debugLog("Strafe target is void, hopping in place")
                        task.wait(0.3)
                    end
                end
                lastPos = _rootPart and _rootPart.Position or lastPos
                lastMoveTime = os.clock()
                setStatus("moving")
                break -- continue (re-evaluate from a clean state)
            end

            -- Strafes failed → spend ONE exceptional recalc
            setStatus("stuck")
            debugLog("STUCK: micro-unstuck failed, spending ONE recalc")
            if jumpEnabled then
                _humanoid.Jump = true
            end
            task.wait(0.2)
            if recalcCount < MAX_RECALCS and _rootPart then
                recalcCount = recalcCount + 1
                local _, newWaypoints = forceRecalcPath(_rootPart.Position, targetPos)
                if newWaypoints and #newWaypoints > 1 then
                    waypoints = newWaypoints
                    waypointIdx = 2
                    lastWpIdx = 1 -- force wall-cache refresh on next iteration
                    debugLog("STUCK recalc OK, new waypoints:", #newWaypoints)
                else
                    debugLog("STUCK recalc failed, keeping committed path")
                end
                stuckAttempts = 0
                lastPos = _rootPart and _rootPart.Position or lastPos
                lastMoveTime = os.clock()
                setStatus("moving")
                break -- continue
            end

            debugLog("STUCK: recalc budget exhausted")
            setStatus("error")
            _moving = false
            restoreWalkSpeed() -- [v2.0 FIX 4]
            return
        end

        -- ─────────────────────────────────────────────────────
        -- Ground / fall handling (NO inverted danger vectors)
        -- A fall is declared only after FALL_AIR_TIME seconds
        -- without ground, so normal gap jumps never trigger it.
        -- Recovery is PHYSICAL: velocity impulse back onto the
        -- platform, re-steered until grounded. [v2.0 FIX 5]
        -- ─────────────────────────────────────────────────────
        local grounded = hasGroundBelow(currentPos, 10)
        if grounded then
            lastGrounded = os.clock()
            _lastSafePos = currentPos
        elseif os.clock() - lastGrounded > FALL_AIR_TIME then
            setStatus("falling")
            debugLog("FALLING: physics impulse toward _lastSafePos")
            local recovery = _lastSafePos or findNearestSafePlatform()
            if recovery then
                applyFallRecovery(recovery)
            else
                task.wait(0.5)
            end
            lastGrounded = os.clock()
            lastPos = _rootPart and _rootPart.Position or lastPos
            lastMoveTime = os.clock()
            if _rootPart and hasGroundBelow(_rootPart.Position, 10) then
                _lastSafePos = _rootPart.Position
                setStatus("moving")
            end
            break -- continue
        end

        -- Exhausted waypoints: target in reach → done, else ONE recalc
        if waypointIdx > #waypoints then
            if horizontalDistanceSq(currentPos, targetPos) <= precisionSq then
                setStatus("done")
                _moving = false
                restoreWalkSpeed() -- [v2.0 FIX 4]
                return
            end
            if recalcCount < MAX_RECALCS then
                recalcCount = recalcCount + 1
                local _, newWaypoints = forceRecalcPath(currentPos, targetPos)
                if newWaypoints and #newWaypoints > 1 then
                    waypoints = newWaypoints
                    waypointIdx = 2
                    lastWpIdx = 1
                    break -- continue
                end
            end
            setStatus("error")
            _moving = false
            restoreWalkSpeed() -- [v2.0 FIX 4]
            return
        end

        -- ─────────────────────────────────────────────────────
        -- [v2.0 + v2.1] STRING PULLING / PATH SMOOTHING (throttled)
        -- Skip redundant intermediate waypoints on clean straight
        -- runs: needs clear sight (no wall) + ground under the whole
        -- segment. Never pulls across Jump waypoints, narrow bridges
        -- or freshly detected walls — rail-lock stays intact.
        -- [v2.1] RUN-UP GUARD: the CURRENT waypoint is checked too —
        -- if it is a Jump waypoint the loop breaks instantly, so the
        -- run-up distance right before a gap jump is never shortened
        -- and the jump trajectory stays intact.
        -- ─────────────────────────────────────────────────────
        local nowSmooth = os.clock()
        if nowSmooth - _timers.smooth >= SMOOTH_CHECK_INTERVAL then
            _timers.smooth = nowSmooth
            while waypointIdx < #waypoints do
                local curWp = waypoints[waypointIdx]
                if curWp and curWp.Action == Enum.PathWaypointAction.Jump then
                    break -- [v2.1] protect the jump run-up distance
                end
                local nxt = waypoints[waypointIdx + 1]
                if not nxt then break end
                if nxt.Action == Enum.PathWaypointAction.Jump then break end
                if _cachedBridge[1] or _cachedWall[1] then break end
                if canSkipTo(currentPos, nxt.Position) then
                    waypointIdx = waypointIdx + 1
                else
                    break
                end
            end
        end

        local wp    = waypoints[waypointIdx]
        local wpPos = wp.Position

        -- Waypoint switched: the locked course changed, so the cached
        -- wall scan (which is direction-dependent) must be refreshed
        if waypointIdx ~= lastWpIdx then
            lastWpIdx = waypointIdx
            _timers.wall = 0
        end

        -- Moving platform compensation (AssemblyLinearVelocity)
        local onMoving, platformVel = detectMovingPlatform()
        if onMoving then
            wpPos = wpPos + platformVel * 0.1
        end

        -- Locked course direction toward the committed waypoint
        local courseDir, courseLen = courseDirection(currentPos, wpPos)
        if courseLen < 0.001 then
            courseDir = _rootPart.CFrame.LookVector
        end

        local nearObstacle = false
        local courseBlocked = false

        -- ─────────────────────────────────────────────────────
        -- Wall scan along the locked course (throttled)
        -- Low wall → jump, course unchanged. Tall wall right in
        -- front → physical blockage → exceptional recalc.
        -- ─────────────────────────────────────────────────────
        local nowWall = os.clock()
        if nowWall - _timers.wall >= WALL_CHECK_INTERVAL then
            _timers.wall = nowWall
            _cachedWall[1], _cachedWall[2], _cachedWall[3] = detectWallAlong(courseDir)
        end
        local wallHit, wallDist, wallHeight = _cachedWall[1], _cachedWall[2], _cachedWall[3]

        if wallHit and wallDist < WALL_DETECT_RANGE then
            nearObstacle = true
            if wallHeight < JUMP_HEIGHT and jumpEnabled then
                _humanoid.Jump = true -- hop over, course vector NOT modified
            elseif wallHeight >= JUMP_HEIGHT and wallDist < WALL_BLOCK_DIST then
                courseBlocked = true
            end
        end

        -- ─────────────────────────────────────────────────────
        -- Anti corner-cut + gap handling along the locked course.
        -- [v2.0 FIX 2] courseBlocked fires ONLY when a gap is
        -- EXPLICITLY detected AND unjumpable. A bare micro-seam
        -- miss (segmentHasGround false, gapFound false) no longer
        -- panics the router into a phantom recalc.
        -- Skipped for Jump-flagged waypoints (a gap there is
        -- the intended route).
        -- ─────────────────────────────────────────────────────
        if avoidVoid
           and wp.Action ~= Enum.PathWaypointAction.Jump
           and not segmentHasGround(currentPos, wpPos) then
            nearObstacle = true
            local gapFound, gapWidth = detectGapAlong(courseDir)
            if gapFound and gapWidth > 0 then
                if gapWidth < JUMPABLE_GAP and jumpEnabled then
                    _humanoid.Jump = true -- jump across, course vector NOT modified
                    debugLog("Jumpable gap on course:", gapWidth, "studs — committing jump")
                else
                    courseBlocked = true -- EXPLICIT unjumpable void on the route
                end
            else
                debugLog("Micro-seam on course, no real gap — keeping course")
            end
        end

        -- ─────────────────────────────────────────────────────
        -- (B) Physical blockage — the ONLY "hard" recalc trigger
        -- ─────────────────────────────────────────────────────
        if courseBlocked then
            setStatus("blocked")
            debugLog("COURSE BLOCKED: single exceptional recalc")
            if recalcCount < MAX_RECALCS then
                recalcCount = recalcCount + 1
                local _, newWaypoints = forceRecalcPath(currentPos, targetPos)
                if newWaypoints and #newWaypoints > 1 then
                    waypoints = newWaypoints
                    waypointIdx = 2
                    lastWpIdx = 1
                    setStatus("moving")
                    task.wait(0.1)
                    break -- continue
                end
            end
            setStatus("error")
            _moving = false
            restoreWalkSpeed() -- [v2.0 FIX 4]
            return
        end

        -- ─────────────────────────────────────────────────────
        -- Narrow bridge: SLOWDOWN ONLY. The speed is guaranteed to
        -- come back on exit via restoreWalkSpeed(). [v2.0 FIX 4]
        -- ─────────────────────────────────────────────────────
        local nowBridge = os.clock()
        if nowBridge - _timers.bridge >= BRIDGE_CHECK_INTERVAL then
            _timers.bridge = nowBridge
            _cachedBridge[1], _cachedBridge[2], _cachedBridge[3], _cachedBridge[4] = detectBridge()
        end
        local isNarrow = _cachedBridge[1]
        if isNarrow then
            nearObstacle = true
            if _originalWalkSpeed then
                _humanoid.WalkSpeed = math.max(_originalWalkSpeed * 0.5, 4)
            else
                debugLog("WARNING: _originalWalkSpeed nil, skipping slowdown")
            end
        else
            if _originalWalkSpeed and _humanoid.WalkSpeed < _originalWalkSpeed then
                _humanoid.WalkSpeed = _originalWalkSpeed
            end
        end

        -- Jump-flagged waypoints
        if wp.Action == Enum.PathWaypointAction.Jump and jumpEnabled then
            _humanoid.Jump = true
            nearObstacle = true
        end

        -- SINGLE command channel: only ever toward the committed waypoint
        _humanoid:MoveTo(wpPos)

        -- ─────────────────────────────────────────────────────
        -- [v2.0 FIX 1] SPEED-AWARE waypoint timeout.
        -- Old fixed formula clamp(courseLen / 8, 0.5, 3) fired false
        -- timeouts on bridges where WalkSpeed is halved (8 studs/s).
        -- Now the budget derives from the CURRENT speed with head-room
        -- for acceleration and turning:
        -- ─────────────────────────────────────────────────────
        local currentSpeed = math.max(_humanoid.WalkSpeed, 4)
        local wpTimeout = math.clamp((courseLen / currentSpeed) * 2.5, 1.2, 8.0)

        local wpStart = os.clock()
        local wpReached = false
        while not _stopFlag and _rootPart and _humanoid
              and _humanoid.Health > 0 and os.clock() - wpStart < wpTimeout do
            if horizontalDistanceSq(_rootPart.Position, wpPos) < WP_REACH_RADIUS_SQ then
                wpReached = true
                break -- breaks the INNER waypoint-wait loop (correct)
            end
            task.wait(GROUND_CHECK_INTERVAL)
        end

        if wpReached then
            waypointIdx = waypointIdx + 1
        else
            -- Waypoint unreachable in time = physically blocked route
            if recalcCount < MAX_RECALCS and _rootPart then
                recalcCount = recalcCount + 1
                local _, newWaypoints = forceRecalcPath(_rootPart.Position, targetPos)
                if newWaypoints and #newWaypoints > 1 then
                    waypoints = newWaypoints
                    waypointIdx = 2
                    lastWpIdx = 1
                else
                    waypointIdx = waypointIdx + 1
                end
            else
                waypointIdx = waypointIdx + 1
            end
        end

        -- Adaptive loop interval: faster polling near obstacles
        task.wait(nearObstacle and GROUND_CHECK_INTERVAL or CALM_LOOP_INTERVAL)

    until true
    end

    if _stopFlag then
        setStatus("idle")
    end
    _moving = false
    restoreWalkSpeed() -- [v2.0 FIX 4] final safety net on ANY exit
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
    _lastSafePos = rootPart.Position
    setStatus("idle")
    _moving   = false
    _stopFlag = false
    updateRayFilter()

    -- Per-character Died listener (system-owned, survives stop();
    -- the previous one is disconnected to avoid accumulation)
    if _diedConn and _diedConn.Connected then
        _diedConn:Disconnect()
    end
    _diedConn = _humanoid.Died:Connect(function()
        Navigation.stop()
    end)

    -- System listener: connected ONCE for the module lifetime and
    -- NEVER disconnected by stop()/cleanupRuntime(). Auto re-init
    -- on respawn keeps working forever.
    if not _systemHooked then
        _systemHooked = true
        local player = Players.LocalPlayer
        _systemConnections[#_systemConnections + 1] = player.CharacterAdded:Connect(function(newChar)
            local newHum  = newChar:WaitForChild("Humanoid")
            local newRoot = newChar:WaitForChild("HumanoidRootPart")
            if _diedConn and _diedConn.Connected then
                _diedConn:Disconnect()
            end
            _humanoid = newHum
            _rootPart = newRoot
            _originalWalkSpeed = newHum.WalkSpeed
            _lastSafePos = newRoot.Position
            setStatus("idle")
            _moving = false
            _stopFlag = false
            updateRayFilter()
            _diedConn = newHum.Died:Connect(function()
                Navigation.stop()
            end)
            debugLog("Character respawned, re-initialized")
        end)
    end

    debugLog("Initialized, WalkSpeed:", _originalWalkSpeed)
end

-- [v2.0] AUTO-INIT helper: bind to the current character if init()
-- was never called (or the session lost its reference). Safe no-op
-- when a valid character is already bound.
local function tryAutoInit()
    if _humanoid and _rootPart and _rootPart.Parent then
        return true
    end
    local player = Players.LocalPlayer
    local char = player and player.Character
    if not char then return false end
    local hum  = char:FindFirstChildOfClass("Humanoid")
    local root = char:FindFirstChild("HumanoidRootPart")
    if hum and root then
        Navigation.init(hum, root)
        debugLog("Auto-init: bound to current character")
        return true
    end
    return false
end

function Navigation.moveTo(targetPosition, options)
    -- [v2.0 AUTO-INIT] lazy ensure: module keeps working even if the
    -- caller forgot Navigation.init() after loadstring or respawn.
    if not (_humanoid and _rootPart and _rootPart.Parent) then
        tryAutoInit()
    end
    assert(_humanoid, "Navigation.moveTo: call Navigation.init() first")
    assert(_rootPart, "Navigation.moveTo: rootPart is nil, call init()")
    assert(typeof(targetPosition) == "Vector3", "Navigation.moveTo: targetPosition must be Vector3")

    -- Active wait: guarantee the old follower thread fully exited
    if _moving then
        _stopFlag = true
        local waitStart = os.clock()
        while _moving and os.clock() - waitStart < 1 do
            task.wait(0.05)
        end
        _moving = false
    end

    -- [MEMORY FIX] _threads is purged on EVERY moveTo() call:
    -- cancel any stragglers, then drop all references.
    for _, thread in ipairs(_threads) do
        pcall(function()
            if coroutine.status(thread) ~= "dead" then
                task.cancel(thread)
            end
        end)
    end
    table.clear(_threads)

    options = options or {}
    local opts = {
        jumpEnabled  = options.jumpEnabled ~= false,
        avoidVoid    = options.avoidVoid ~= false,
        precision    = options.precision or 3,
        timeout      = options.timeout or 30,
        -- dynamicRecalc is DEPRECATED since v1.8 and intentionally ignored:
        -- recalculation fires ONLY on stuck / blocked events.
        _targetPosition = targetPosition,
    }

    _moving   = true
    _stopFlag = false
    _timers = { bridge = 0, wall = 0, smooth = 0 }
    _lastPathTime = 0
    _lastSafePos = _rootPart.Position
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
            local fbStart = os.clock()
            local precisionSq = opts.precision * opts.precision
            while _moving and not _stopFlag and _rootPart
                  and _humanoid and _humanoid.Health > 0 do
                if horizontalDistanceSq(_rootPart.Position, targetPosition) <= precisionSq then
                    setStatus("done")
                    _moving = false
                    restoreWalkSpeed() -- [v2.0 FIX 4]
                    return
                end
                if os.clock() - fbStart > opts.timeout then
                    setStatus("error")
                    _moving = false
                    restoreWalkSpeed() -- [v2.0 FIX 4]
                    return
                end
                _humanoid:MoveTo(targetPosition)
                task.wait(0.5)
            end
            restoreWalkSpeed() -- [v2.0 FIX 4]
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
    restoreWalkSpeed() -- [v2.0 FIX 4] guaranteed restore on stop()
    _lastPathTime = 0
    -- Runtime resources only: CharacterAdded / Died stay alive
    cleanupRuntime()
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

-- ═══════════════════════════════════════════════════════════════
--  [v2.0] AUTO-INIT BOOTSTRAP (loadstring self-setup)
--  Runs in the background right after loadstring(...)(): locates the
--  current LocalPlayer character, extracts Humanoid / HumanoidRootPart
--  and calls Navigation.init(). Navigation.moveTo() is ready to use
--  immediately, even if the user never calls init() manually.
-- ═══════════════════════════════════════════════════════════════
task.spawn(function()
    local ok, err = pcall(function()
        local player = Players.LocalPlayer
        if not player then return end
        local char = player.Character or player.CharacterAdded:Wait()
        if not char then return end
        local hum  = char:WaitForChild("Humanoid", 10)
        local root = char:WaitForChild("HumanoidRootPart", 10)
        if hum and root and not (_humanoid and _rootPart) then
            Navigation.init(hum, root)
            debugLog("Auto-init complete (loadstring bootstrap)")
        end
    end)
    if not ok then
        warn("[NAV] auto-init failed:", err)
    end
end)

return Navigation
