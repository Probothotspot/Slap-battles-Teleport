--[[
    Escanor HUB 🔥 — Модуль детекта инжектора (Executor Detection Module)
    Файл: detector.lua
--]]

local Detector = {}

function Detector.run()
    local ExecutorInfo = {
        detected = false,
        name = "Unknown",
        version = nil,
        features = {}
    }

    local execName = "Unknown Executor"
    local execVersion = nil
    local isExploiting = false
    local detectedFeatures = {}

    -- Метод 1: identifyexecutor()
    if identifyexecutor then
        local success, name, ver = pcall(identifyexecutor)
        if success and name then
            execName = tostring(name)
            execVersion = ver and tostring(ver) or nil
            isExploiting = true
            table.insert(detectedFeatures, "identifyexecutor")
        end
    end

    -- Метод 2: getexecutorname()
    if not isExploiting and getexecutorname then
        local success, name = pcall(getexecutorname)
        if success and name then
            execName = tostring(name)
            isExploiting = true
            table.insert(detectedFeatures, "getexecutorname")
        end
    end

    -- Метод 3: Проверка глобальных функций инжекторов
    local exploitFunctions = {
        {check = "getgenv", name = "getgenv"},
        {check = "getrenv", name = "getrenv"},
        {check = "getsenv", name = "getsenv"},
        {check = "getrawmetatable", name = "getrawmetatable"},
        {check = "hookfunction", name = "hookfunction"},
        {check = "hookmetamethod", name = "hookmetamethod"},
        {check = "newcclosure", name = "newcclosure"},
        {check = "setclipboard", name = "setclipboard"},
        {check = "setfflag", name = "setfflag"},
        {check = "gethui", name = "gethui"},
        {check = "gethiddenproperty", name = "gethiddenproperty"},
        {check = "sethiddenproperty", name = "sethiddenproperty"},
        {check = "getconnections", name = "getconnections"},
        {check = "firesignal", name = "firesignal"},
        {check = "fireproximityprompt", name = "fireproximityprompt"},
        {check = "request", name = "request/http"},
        {check = "http_request", name = "http_request"},
        {check = "writefile", name = "filesystem"},
        {check = "readfile", name = "filesystem"},
        {check = "isfile", name = "filesystem"},
        {check = "isfolder", name = "filesystem"},
        {check = "listfiles", name = "filesystem"},
        {check = "makefolder", name = "filesystem"},
        {check = "Drawing", name = "Drawing"},
        {check = "debug", name = "debug library"},
        
        {check = "syn", name = "Synapse X", executor = true},
        {check = "fluxus", name = "Fluxus", executor = true},
        {check = "KRNL_LOADED", name = "KRNL", executor = true},
        {check = "Sentinel", name = "Sentinel", executor = true},
        {check = "OXYGEN_LOADED", name = "Oxygen U", executor = true},
        {check = "pebc_execute", name = "ProtoSmasher", executor = true},
        {check = "elysian", name = "Elysian", executor = true},
    }

    for _, func in ipairs(exploitFunctions) do
        local exists = false
        pcall(function()
            exists = getfenv()[func.check] ~= nil or _G[func.check] ~= nil
            if not exists and getgenv then
                exists = getgenv()[func.check] ~= nil
            end
        end)
        
        if exists then
            isExploiting = true
            table.insert(detectedFeatures, func.name)
            if func.executor and execName == "Unknown Executor" then
                execName = func.name
            end
        end
    end

    if queue_on_teleport then
        isExploiting = true
        table.insert(detectedFeatures, "queue_on_teleport")
    end

    pcall(function()
        if syn and syn.queue_on_teleport then
            isExploiting = true
            if execName == "Unknown Executor" then execName = "Synapse X" end
            table.insert(detectedFeatures, "syn.queue_on_teleport")
        end
    end)

    pcall(function()
        if fluxus and fluxus.queue_on_teleport then
            isExploiting = true
            if execName == "Unknown Executor" then execName = "Fluxus" end
            table.insert(detectedFeatures, "fluxus.queue_on_teleport")
        end
    end)

    local uniqueFeatures = {}
    local seen = {}
    for _, v in ipairs(detectedFeatures) do
        if not seen[v] then
            seen[v] = true
            table.insert(uniqueFeatures, v)
        end
    end

    ExecutorInfo.detected = isExploiting
    ExecutorInfo.name = execName
    ExecutorInfo.version = execVersion
    ExecutorInfo.features = uniqueFeatures

    return ExecutorInfo
end

function Detector.printBanner(ExecutorInfo)
    local separator = string.rep("═", 50)
    local featureCount = #ExecutorInfo.features
    
    if ExecutorInfo.detected then
        print("")
        print("╔" .. separator .. "╗")
        print("║" .. string.rep(" ", 14) .. "🔥 ESCANOR HUB v1.3 🔥" .. string.rep(" ", 14) .. "║")
        print("╠" .. separator .. "╣")
        print("║  📍 Executor Detected: " .. string.rep(" ", 25 - #ExecutorInfo.name) .. ExecutorInfo.name .. "  ║")
        if ExecutorInfo.version then
            print("║  📋 Version: " .. string.rep(" ", 35 - #ExecutorInfo.version) .. ExecutorInfo.version .. "  ║")
        end
        print("║  🛠️  Features Available: " .. string.rep(" ", 22 - #tostring(featureCount)) .. tostring(featureCount) .. "  ║")
        print("╠" .. separator .. "╣")
        print("║  ✅ Environment: SUPPORTED" .. string.rep(" ", 21) .. "║")
        print("║  🚀 Status: LAUNCHING..." .. string.rep(" ", 23) .. "║")
        print("╚" .. separator .. "╝")
        print("")
    else
        warn("")
        warn("╔" .. separator .. "╗")
        warn("║" .. string.rep(" ", 14) .. "⚠️ ESCANOR HUB v1.3 ⚠️" .. string.rep(" ", 13) .. "║")
        warn("╠" .. separator .. "╣")
        warn("║  ❌ Executor: NOT DETECTED" .. string.rep(" ", 21) .. "║")
        warn("║  ⚠️  Environment: UNSUPPORTED" .. string.rep(" ", 18) .. "║")
        warn("╠" .. separator .. "╣")
        warn("║  📌 Этот скрипт требует эксплойт для работы!" .. string.rep(" ", 3) .. "║")
        warn("╚" .. separator .. "╝")
        warn("")
    end
end

return Detector
