--[[
    MM2 Trade Logger — Delta Executor (file output)
    Лог: консоль + файл в папке Delta
    Путь: MM2_Logs/trade_log_<timestamp>.txt
]]

-- ═══════════════════════════════════════════
-- Файловая система
-- ═══════════════════════════════════════════
local LOG_DIR = "MM2_Logs"
local LOG_FILE = LOG_DIR .. "/trade_log_" .. os.time() .. ".txt"

if not isfolder(LOG_DIR) then
    makefolder(LOG_DIR)
end

-- Заголовок файла
writefile(LOG_FILE, table.concat({
    "MM2 TRADE LOGGER",
    "Started: " .. os.date("%Y-%m-%d %H:%M:%S"),
    "Executor: Delta",
    "========================================",
    ""
}, "\n"))

local function fileLog(line)
    appendfile(LOG_FILE, line .. "\n")
end

-- ═══════════════════════════════════════════
-- Сериализация
-- ═══════════════════════════════════════════
local DEPTH_LIMIT = 4

local function serialize(val, depth)
    depth = depth or 0
    if depth > DEPTH_LIMIT then return "..." end

    local t = typeof(val)

    if t == "Instance" then
        return val:GetFullName() .. " <" .. val.ClassName .. ">"
    elseif t == "string" then
        return '"' .. val:gsub('"', '\\"') .. '"'
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "Vector3" then
        return string.format("Vector3(%.2f, %.2f, %.2f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then
        local p = val.Position
        return string.format("CFrame(%.2f, %.2f, %.2f)", p.X, p.Y, p.Z)
    elseif t == "Color3" then
        return string.format("Color3(%.2f, %.2f, %.2f)", val.R, val.G, val.B)
    elseif t == "EnumItem" then
        return tostring(val)
    elseif t == "table" then
        local parts = {}
        local count = 0
        for k, v in pairs(val) do
            count = count + 1
            if count > 20 then
                parts[#parts + 1] = "... (" .. (count - 20) .. " more)"
                break
            end
            local key = type(k) == "string" and k or "[" .. tostring(k) .. "]"
            parts[#parts + 1] = key .. " = " .. serialize(v, depth + 1)
        end
        return "{" .. table.concat(parts, ", ") .. "}"
    elseif t == "function" then
        return "function: " .. tostring(val):match("0x%x+")
    else
        return tostring(val) .. " <" .. t .. ">"
    end
end

local function serializeArgs(args)
    local parts = {}
    for i = 1, #args do
        parts[i] = "[" .. i .. "] " .. serialize(args[i], 0)
    end
    return #parts > 0 and table.concat(parts, " | ") or "(none)"
end

-- ═══════════════════════════════════════════
-- Логирование (консоль + файл)
-- ═══════════════════════════════════════════
local LOG = {}
local PREFIX = "[MM2-TRADE] "

local function addLog(direction, remotePath, method, args, extra)
    local entry = {
        time = os.clock(),
        dir = direction,
        remote = remotePath,
        method = method,
        args = args,
        extra = extra or ""
    }
    LOG[#LOG + 1] = entry

    local line = string.format(
        "[%.3f] %s | %s | %s | Args: %s%s",
        entry.time, direction, remotePath, method, args,
        extra ~= "" and (" | " .. extra) or ""
    )

    print(PREFIX .. line)
    fileLog(line)
end

-- ═══════════════════════════════════════════
-- 1. Перехват __namecall
-- ═══════════════════════════════════════════
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    local method = getnamecallmethod()
    local args = { ... }

    if method == "FireServer" or method == "InvokeServer" then
        pcall(function()
            addLog(
                "C→S",
                self:GetFullName(),
                self.ClassName .. ":" .. method,
                serializeArgs(args)
            )
        end)
    end

    return oldNamecall(self, ...)
end)

-- ═══════════════════════════════════════════
-- 2. Перехват входящих (сервер → клиент)
-- ═══════════════════════════════════════════
local hookedRemotes = {}

local function hookRemote(remote)
    if hookedRemotes[remote] then return end
    hookedRemotes[remote] = true

    pcall(function()
        if remote:IsA("RemoteEvent") then
            remote.OnClientEvent:Connect(function(...)
                pcall(function()
                    addLog(
                        "S→C",
                        remote:GetFullName(),
                        "RemoteEvent:OnClientEvent",
                        serializeArgs({ ... })
                    )
                end)
            end)
        elseif remote:IsA("RemoteFunction") then
            pcall(function()
                local old = remote.OnClientInvoke
                if old then
                    remote.OnClientInvoke = function(...)
                        pcall(function()
                            addLog(
                                "S→C",
                                remote:GetFullName(),
                                "RemoteFunction:OnClientInvoke",
                                serializeArgs({ ... })
                            )
                        end)
                        return old(...)
                    end
                end
            end)
        end
    end)
end

for _, obj in ipairs(game:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        hookRemote(obj)
    end
end

game.DescendantAdded:Connect(function(obj)
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        local line = "NEW REMOTE: " .. obj:GetFullName() .. " <" .. obj.ClassName .. ">"
        print(PREFIX .. line)
        fileLog(line)
        hookRemote(obj)
    end
end)

-- ═══════════════════════════════════════════
-- 3. Скан GC
-- ═══════════════════════════════════════════
fileLog("=== GC SCAN ===")
local gcHits = 0
for _, v in ipairs(getgc(true)) do
    if type(v) == "table" then
        for key, val in pairs(v) do
            if type(key) == "string" and key:lower():match("trade") then
                gcHits = gcHits + 1
                local line = "GC TABLE: key=" .. key .. " type=" .. type(val) .. " table=" .. tostring(v)
                print(PREFIX .. line)
                fileLog(line)
            end
        end
    elseif type(v) == "function" then
        local info = debug.getinfo(v)
        if info and info.name and info.name:lower():match("trade") then
            gcHits = gcHits + 1
            local line = "GC FUNC: " .. info.name .. " @ " .. (info.source or "?") .. ":" .. (info.linedefined or "?")
            print(PREFIX .. line)
            fileLog(line)
        end
    end
end
fileLog("GC scan done. " .. gcHits .. " hits.")
fileLog("========================================")

-- ═══════════════════════════════════════════
-- 4. UI мониторинг
-- ═══════════════════════════════════════════
pcall(function()
    local gui = game:GetService("Players").LocalPlayer:FindFirstChild("PlayerGui")
    if gui then
        gui.DescendantAdded:Connect(function(obj)
            if obj.Name:lower():match("trade") then
                local line = "UI ELEMENT: " .. obj:GetFullName() .. " <" .. obj.ClassName .. ">"
                print(PREFIX .. line)
                fileLog(line)
            end
        end)
    end
end)

-- ═══════════════════════════════════════════
-- 5. Экспорт / управление
-- ═══════════════════════════════════════════
_G.MM2Log = LOG
_G.MM2LogFile = LOG_FILE

function _G.DumpLog()
    print(PREFIX .. "=== DUMP (" .. #LOG .. " entries) ===")
    for i, e in ipairs(LOG) do
        print(string.format(
            "[%03d] %.3f | %s | %s | %s | %s",
            i, e.time, e.dir, e.remote, e.method, e.args
        ))
    end
end

function _G.ClearLog()
    LOG = {}
    _G.MM2Log = LOG
    writefile(LOG_FILE, "")
    print(PREFIX .. "Log cleared.")
end

function _G.FilterLog(keyword)
    for i, e in ipairs(LOG) do
        local line = e.remote .. " " .. e.method .. " " .. e.args
        if line:lower():match(keyword:lower()) then
            print(string.format("[%03d] %.3f | %s | %s | %s", i, e.time, e.dir, e.remote, e.args))
        end
    end
end

-- ═══════════════════════════════════════════
-- Старт
-- ═══════════════════════════════════════════
local remoteCount = 0
for _, obj in ipairs(game:GetDescendants()) do
    if obj:IsA("RemoteEvent") or obj:IsA("RemoteFunction") then
        remoteCount = remoteCount + 1
    end
end

local startMsg = table.concat({
    "Logger active.",
    "Remotes hooked: " .. remoteCount,
    "Log file: " .. LOG_FILE,
    "Commands: _G.DumpLog() | _G.ClearLog() | _G.FilterLog('trade')"
}, "\n")

print(PREFIX .. startMsg)
fileLog(startMsg)
