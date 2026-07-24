--[[
    MM2 Trade Logger — Delta Executor (robust)
    GUI: Start/Stop, live counter, preview, file output (optional)
]]

-- ═══════════════════════════════════════════
-- Сервисы
-- ═══════════════════════════════════════════
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local function has(v) return type(v) == "function" end

-- ═══════════════════════════════════════════
-- Файлы (опционально, с фолбэком)
-- ═══════════════════════════════════════════
local FILE_OK = false
local LOG_DIR = "MM2_Logs"
local LOG_FILE = LOG_DIR .. "/trade_log_" .. tostring(os.time()) .. ".txt"

pcall(function()
    if not (has(isfolder) and has(makefolder) and has(writefile) and has(appendfile)) then
        error("file api missing")
    end
    if not isfolder(LOG_DIR) then makefolder(LOG_DIR) end
    writefile(LOG_FILE, "MM2 TRADE LOGGER\nStarted: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n========================================\n")
    FILE_OK = true
end)

local function fappend(line)
    if FILE_OK then pcall(appendfile, LOG_FILE, line .. "\n") end
end

-- ═══════════════════════════════════════════
-- Состояние
-- ═══════════════════════════════════════════
local logging = false
local LOG = {}
local PREFIX = "[MM2-TRADE] "

-- ═══════════════════════════════════════════
-- Сериализация
-- ═══════════════════════════════════════════
local DEPTH = 4
local function ser(val, d)
    d = d or 0
    if d > DEPTH then return "..." end
    local t = typeof(val)
    if t == "Instance" then return val:GetFullName() .. " <" .. val.ClassName .. ">"
    elseif t == "string" then return '"' .. val:gsub('"', '\\"') .. '"'
    elseif t == "number" or t == "boolean" then return tostring(val)
    elseif t == "Vector3" then return string.format("V3(%.1f,%.1f,%.1f)", val.X, val.Y, val.Z)
    elseif t == "CFrame" then local p = val.Position return string.format("CF(%.1f,%.1f,%.1f)", p.X, p.Y, p.Z)
    elseif t == "table" then
        local parts, n = {}, 0
        for k, v in pairs(val) do
            n = n + 1
            if n > 15 then parts[#parts+1] = "..." break end
            local key = type(k) == "string" and k or "[" .. tostring(k) .. "]"
            parts[#parts+1] = key .. "=" .. ser(v, d + 1)
        end
        return "{" .. table.concat(parts, ",") .. "}"
    else return tostring(val) end
end
local function serArgs(a)
    local p = {}
    for i = 1, #a do p[i] = "[" .. i .. "]=" .. ser(a[i]) end
    return #p > 0 and table.concat(p, " | ") or "(none)"
end

-- ═══════════════════════════════════════════
-- GUI
-- ═══════════════════════════════════════════
local C = {
    bg = Color3.fromRGB(18, 20, 26),
    panel = Color3.fromRGB(26, 29, 38),
    edge = Color3.fromRGB(48, 54, 70),
    txt = Color3.fromRGB(228, 232, 240),
    dim = Color3.fromRGB(120, 128, 148),
    rec = Color3.fromRGB(255, 84, 64),
    idle = Color3.fromRGB(64, 200, 160),
    amber = Color3.fromRGB(255, 176, 46),
}

-- безопасный парент
local function getGuiParent()
    local p
    pcall(function() if has(gethui) then p = gethui() end end)
    if p then return p end
    pcall(function() p = game:GetService("CoreGui") end)
    if p then return p end
    return LP:WaitForChild("PlayerGui")
end

local gui = Instance.new("ScreenGui")
gui.Name = "MM2TradeLogger"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = getGuiParent()

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 340, 0, 420)
main.Position = UDim2.new(0.5, -170, 0.5, -210)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = C.edge; stroke.Thickness = 1.5

-- Хедер
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = C.panel
header.BorderSizePixel = 0
header.ZIndex = 3
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)
local headerFix = Instance.new("Frame", header)
headerFix.Size = UDim2.new(1, 0, 0.5, 0)
headerFix.Position = UDim2.new(0, 0, 0.5, 0)
headerFix.BackgroundColor3 = C.panel
headerFix.BorderSizePixel = 0

-- акцентная полоска
local accentBar = Instance.new("Frame", header)
accentBar.Size = UDim2.new(0, 40, 0, 3)
accentBar.Position = UDim2.new(0, 14, 1, -6)
accentBar.BackgroundColor3 = C.amber
accentBar.BorderSizePixel = 0
Instance.new("UICorner", accentBar).CornerRadius = UDim.new(1, 0)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, -6)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "MM2 TRADE LOGGER"
title.TextColor3 = C.txt
title.TextSize = 15
title.Font = Enum.Font.GothamBlack
title.TextXAlignment = Enum.TextXAlignment.Left
title.ZIndex = 4
title.Parent = header

local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -36, 0.5, -14)
minBtn.BackgroundColor3 = C.edge
minBtn.BackgroundTransparency = 0.5
minBtn.Text = "—"
minBtn.TextColor3 = C.txt
minBtn.TextSize = 14
minBtn.Font = Enum.Font.GothamBold
minBtn.AutoButtonColor = false
minBtn.ZIndex = 5
minBtn.Parent = header
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- Статус
local statusRow = Instance.new("Frame")
statusRow.Size = UDim2.new(1, -24, 0, 26)
statusRow.Position = UDim2.new(0, 12, 0, 52)
statusRow.BackgroundTransparency = 1
statusRow.Parent = main

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 10, 0, 10)
dot.Position = UDim2.new(0, 0, 0.5, -5)
dot.BackgroundColor3 = C.idle
dot.Parent = statusRow
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local statusTxt = Instance.new("TextLabel")
statusTxt.Size = UDim2.new(1, -100, 1, 0)
statusTxt.Position = UDim2.new(0, 18, 0, 0)
statusTxt.BackgroundTransparency = 1
statusTxt.Text = "IDLE — ожидание"
statusTxt.TextColor3 = C.dim
statusTxt.TextSize = 12
statusTxt.Font = Enum.Font.GothamMedium
statusTxt.TextXAlignment = Enum.TextXAlignment.Left
statusTxt.Parent = statusRow

local counter = Instance.new("TextLabel")
counter.Size = UDim2.new(0, 80, 1, 0)
counter.Position = UDim2.new(1, -80, 0, 0)
counter.BackgroundTransparency = 1
counter.Text = "0 записей"
counter.TextColor3 = C.amber
counter.TextSize = 12
counter.Font = Enum.Font.GothamBold
counter.TextXAlignment = Enum.TextXAlignment.Right
counter.Parent = statusRow

-- START/STOP
local recBtn = Instance.new("TextButton")
recBtn.Size = UDim2.new(1, -24, 0, 50)
recBtn.Position = UDim2.new(0, 12, 0, 86)
recBtn.BackgroundColor3 = C.idle
recBtn.Text = "▶  START"
recBtn.TextColor3 = Color3.fromRGB(10, 12, 16)
recBtn.TextSize = 17
recBtn.Font = Enum.Font.GothamBlack
recBtn.AutoButtonColor = false
recBtn.Parent = main
Instance.new("UICorner", recBtn).CornerRadius = UDim.new(0, 8)

-- Ряд кнопок
local btnRow = Instance.new("Frame")
btnRow.Size = UDim2.new(1, -24, 0, 32)
btnRow.Position = UDim2.new(0, 12, 0, 144)
btnRow.BackgroundTransparency = 1
btnRow.Parent = main
local rowLayout = Instance.new("UIListLayout", btnRow)
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.Padding = UDim.new(0, 7)

local function mkSmallBtn(text, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 74, 1, 0)
    b.BackgroundColor3 = color
    b.BackgroundTransparency = 0.78
    b.Text = text
    b.TextColor3 = color
    b.TextSize = 11
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.Parent = btnRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local dumpBtn = mkSmallBtn("DUMP", C.amber)
local clearBtn = mkSmallBtn("CLEAR", C.rec)
local gcBtn = mkSmallBtn("GC", C.idle)
local pathBtn = mkSmallBtn("PATH", C.txt)

-- Превью
local prevLabel = Instance.new("TextLabel")
prevLabel.Size = UDim2.new(1, -24, 0, 16)
prevLabel.Position = UDim2.new(0, 12, 0, 184)
prevLabel.BackgroundTransparency = 1
prevLabel.Text = "LIVE LOG"
prevLabel.TextColor3 = C.dim
prevLabel.TextSize = 10
prevLabel.Font = Enum.Font.GothamBold
prevLabel.TextXAlignment = Enum.TextXAlignment.Left
prevLabel.Parent = main

local preview = Instance.new("ScrollingFrame")
preview.Size = UDim2.new(1, -24, 1, -214)
preview.Position = UDim2.new(0, 12, 0, 204)
preview.BackgroundColor3 = C.panel
preview.BorderSizePixel = 0
preview.ScrollBarThickness = 3
preview.ScrollBarImageColor3 = C.amber
preview.CanvasSize = UDim2.new(0, 0, 0, 0)
preview.AutomaticCanvasSize = Enum.AutomaticSize.Y
preview.Parent = main
Instance.new("UICorner", preview).CornerRadius = UDim.new(0, 8)

local prevLayout = Instance.new("UIListLayout", preview)
prevLayout.Padding = UDim.new(0, 3)
prevLayout.SortOrder = Enum.SortOrder.LayoutOrder
local prevPad = Instance.new("UIPadding", preview)
prevPad.PaddingTop = UDim.new(0, 6)
prevPad.PaddingLeft = UDim.new(0, 8)
prevPad.PaddingRight = UDim.new(0, 8)
prevPad.PaddingBottom = UDim.new(0, 6)

local prevOrder = 0
local MAX_PREVIEW = 60

local function addPreview(line, color)
    prevOrder = prevOrder + 1
    local l = Instance.new("TextLabel")
    l.Size = UDim2.new(1, 0, 0, 14)
    l.BackgroundTransparency = 1
    l.Text = line
    l.TextColor3 = color or C.txt
    l.TextSize = 10
    l.Font = Enum.Font.Code
    l.TextXAlignment = Enum.TextXAlignment.Left
    l.TextTruncate = Enum.TextTruncate.AtEnd
    l.LayoutOrder = prevOrder
    l.Parent = preview

    local count = 0
    for _, k in ipairs(preview:GetChildren()) do if k:IsA("TextLabel") then count = count + 1 end end
    if count > MAX_PREVIEW then
        for _, k in ipairs(preview:GetChildren()) do
            if k:IsA("TextLabel") and k.LayoutOrder <= prevOrder - MAX_PREVIEW then k:Destroy() end
        end
    end
    preview.CanvasPosition = Vector2.new(0, math.huge)
end

-- ═══════════════════════════════════════════
-- Анимации
-- ═══════════════════════════════════════════
local function tween(obj, props, t)
    TS:Create(obj, TweenInfo.new(t or 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

local function pressFX(btn, baseTrans)
    baseTrans = baseTrans or 0
    btn.MouseButton1Down:Connect(function() tween(btn, {BackgroundTransparency = math.max(baseTrans - 0.25, 0)}, 0.07) end)
    btn.MouseButton1Up:Connect(function() tween(btn, {BackgroundTransparency = baseTrans}, 0.12) end)
    btn.MouseButton1Click:Connect(function() tween(btn, {BackgroundTransparency = baseTrans}, 0.12) end)
end
pressFX(recBtn, 0)
pressFX(dumpBtn, 0.78)
pressFX(clearBtn, 0.78)
pressFX(gcBtn, 0.78)
pressFX(pathBtn, 0.78)
pressFX(minBtn, 0.5)

-- Пульс точки
local pulseOn = false
task.spawn(function()
    while gui.Parent do
        if pulseOn then
            tween(dot, {BackgroundTransparency = 0.25}, 0.5); task.wait(0.5)
            tween(dot, {BackgroundTransparency = 0.9}, 0.5); task.wait(0.5)
        else
            dot.BackgroundTransparency = 0; task.wait(0.3)
        end
    end
end)

-- Drag (проверенный паттерн)
local function makeDraggable(handle, target)
    local dragging, offX, offY = false, 0, 0
    handle.InputBegan:Connect(function(i)
        if i.UserInputType ~= Enum.UserInputType.MouseButton1 and i.UserInputType ~= Enum.UserInputType.Touch then return end
        dragging = true
        local mp = UIS:GetMouseLocation()
        offX = mp.X - target.AbsolutePosition.X
        offY = mp.Y - target.AbsolutePosition.Y
    end)
    UIS.InputChanged:Connect(function(i)
        if not dragging then return end
        if i.UserInputType ~= Enum.UserInputType.MouseMovement and i.UserInputType ~= Enum.UserInputType.Touch then return end
        local mp = UIS:GetMouseLocation()
        target.Position = UDim2.fromOffset(mp.X - offX, mp.Y - offY)
    end)
    UIS.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
    end)
end
makeDraggable(header, main)

-- Свернуть
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(main, {Size = UDim2.new(0, 340, 0, 44)}, 0.25); minBtn.Text = "+"
    else
        tween(main, {Size = UDim2.new(0, 340, 0, 420)}, 0.25); minBtn.Text = "—"
    end
end)

-- ═══════════════════════════════════════════
-- Логирование
-- ═══════════════════════════════════════════
local function addLog(dir, path, method, args)
    LOG[#LOG + 1] = { time = os.clock(), dir = dir, remote = path, method = method, args = args }
    local line = string.format("[%.2f] %s | %s | %s | %s", os.clock(), dir, path, method, args)
    print(PREFIX .. line)
    fappend(line)
    counter.Text = #LOG .. " записей"
    local color = dir == "C→S" and C.amber or C.idle
    local short = path:match("%.([^%.]+)$") or path
    addPreview(dir .. " " .. short .. " " .. args, color)
end

-- ═══════════════════════════════════════════
-- Хуки (с защитой)
-- ═══════════════════════════════════════════
local HOOK_OK = false
pcall(function()
    if not (has(hookmetamethod) and has(getnamecallmethod)) then error("hook api missing") end
    local old
    old = hookmetamethod(game, "__namecall", function(self, ...)
        if logging then
            local m = getnamecallmethod()
            if m == "FireServer" or m == "InvokeServer" then
                pcall(function()
                    addLog("C→S", self:GetFullName(), self.ClassName .. ":" .. m, serArgs({ ... }))
                end)
            end
        end
        return old(self, ...)
    end)
    HOOK_OK = true
end)

local hooked = {}
local function hookRemote(r)
    if hooked[r] then return end
    hooked[r] = true
    pcall(function()
        if r:IsA("RemoteEvent") then
            r.OnClientEvent:Connect(function(...)
                if logging then
                    pcall(function() addLog("S→C", r:GetFullName(), "OnClientEvent", serArgs({ ... })) end)
                end
            end)
        elseif r:IsA("RemoteFunction") then
            pcall(function()
                local old = r.OnClientInvoke
                if old then
                    r.OnClientInvoke = function(...)
                        if logging then
                            pcall(function() addLog("S→C", r:GetFullName(), "OnClientInvoke", serArgs({ ... })) end)
                        end
                        return old(...)
                    end
                end
            end)
        end
    end)
end

for _, o in ipairs(game:GetDescendants()) do
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then hookRemote(o) end
end
game.DescendantAdded:Connect(function(o)
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
        if logging then addPreview("NEW REMOTE: " .. o:GetFullName(), C.amber) end
        hookRemote(o)
    end
end)

-- ═══════════════════════════════════════════
-- START / STOP
-- ═══════════════════════════════════════════
recBtn.MouseButton1Click:Connect(function()
    if not HOOK_OK then
        addPreview(">>> hook недоступен, лог не пойдёт", C.rec)
        return
    end
    logging = not logging
    if logging then
        recBtn.BackgroundColor3 = C.rec; recBtn.Text = "■  STOP"
        statusTxt.Text = "RECORDING"; statusTxt.TextColor3 = C.rec
        dot.BackgroundColor3 = C.rec; pulseOn = true
        fappend("\n--- RECORDING STARTED ---")
        addPreview(">>> запись включена", C.rec)
    else
        recBtn.BackgroundColor3 = C.idle; recBtn.Text = "▶  START"
        statusTxt.Text = "IDLE — остановлено"; statusTxt.TextColor3 = C.dim
        dot.BackgroundColor3 = C.idle; pulseOn = false
        fappend("--- RECORDING STOPPED ---\n")
        addPreview(">>> запись выключена", C.idle)
    end
end)

-- ═══════════════════════════════════════════
-- Кнопки
-- ═══════════════════════════════════════════
dumpBtn.MouseButton1Click:Connect(function()
    print(PREFIX .. "=== DUMP (" .. #LOG .. ") ===")
    for i, e in ipairs(LOG) do
        print(string.format("[%03d] %.2f | %s | %s | %s | %s", i, e.time, e.dir, e.remote, e.method, e.args))
    end
    addPreview(">>> дамп в консоль (" .. #LOG .. ")", C.amber)
end)

clearBtn.MouseButton1Click:Connect(function()
    LOG = {}; counter.Text = "0 записей"
    for _, k in ipairs(preview:GetChildren()) do if k:IsA("TextLabel") then k:Destroy() end end
    if FILE_OK then pcall(writefile, LOG_FILE, "") end
    addPreview(">>> лог очищен", C.rec)
end)

-- GC скан (по кнопке, в отдельном потоке, с защитой)
gcBtn.MouseButton1Click:Connect(function()
    if not has(getgc) then addPreview(">>> getgc недоступен", C.rec) return end
    addPreview(">>> скан GC...", C.dim)
    task.spawn(function()
        local hits = 0
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" then
                    for key, val in pairs(v) do
                        if type(key) == "string" and key:lower():match("trade") then
                            hits = hits + 1
                            local line = "GC TABLE: " .. key .. " (" .. type(val) .. ")"
                            print(PREFIX .. line); fappend(line); addPreview(line, C.idle)
                        end
                    end
                elseif type(v) == "function" then
                    pcall(function()
                        local info = debug.getinfo(v)
                        if info and info.name and tostring(info.name):lower():match("trade") then
                            hits = hits + 1
                            local line = "GC FUNC: " .. info.name .. " @ " .. tostring(info.source) .. ":" .. tostring(info.linedefined)
                            print(PREFIX .. line); fappend(line); addPreview(line, C.idle)
                        end
                    end)
                end
            end
        end)
        addPreview(">>> GC: " .. hits .. " совпадений", C.amber)
    end)
end)

pathBtn.MouseButton1Click:Connect(function()
    if not FILE_OK then addPreview(">>> файлы недоступны — лог в консоли", C.rec) return end
    if has(setclipboard) then pcall(setclipboard, LOG_FILE) end
    addPreview(">>> " .. LOG_FILE, C.idle)
    print(PREFIX .. "Log file: " .. LOG_FILE)
end)

-- ═══════════════════════════════════════════
-- Старт / диагностика
-- ═══════════════════════════════════════════
local rc = 0
for _, o in ipairs(game:GetDescendants()) do
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then rc = rc + 1 end
end

addPreview("logger готов | remotes: " .. rc, C.dim)
addPreview("hook: " .. (HOOK_OK and "OK" or "FAIL"), HOOK_OK and C.idle or C.rec)
addPreview("files: " .. (FILE_OK and "OK" or "OFF (консоль)"), FILE_OK and C.idle or C.amber)
if FILE_OK then addPreview("файл: " .. LOG_FILE, C.dim) end
print(PREFIX .. "Ready | remotes=" .. rc .. " | hook=" .. tostring(HOOK_OK) .. " | files=" .. tostring(FILE_OK))
