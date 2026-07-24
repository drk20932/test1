--[[
    MM2 Trade Logger — Delta Executor
    GUI: Start/Stop, live counter, log preview, file output
    Путь лога: MM2_Logs/trade_log_<ts>.txt
]]

-- ═══════════════════════════════════════════
-- Сервисы
-- ═══════════════════════════════════════════
local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

-- ═══════════════════════════════════════════
-- Файлы
-- ═══════════════════════════════════════════
local LOG_DIR = "MM2_Logs"
local LOG_FILE = LOG_DIR .. "/trade_log_" .. os.time() .. ".txt"
if not isfolder(LOG_DIR) then makefolder(LOG_DIR) end
writefile(LOG_FILE, "MM2 TRADE LOGGER\nStarted: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n========================================\n")

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

local gui = Instance.new("ScreenGui")
gui.Name = "MM2TradeLogger"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = gethui()

-- Главный фрейм
local main = Instance.new("Frame")
main.Size = UDim2.new(0, 340, 0, 420)
main.Position = UDim2.new(0.5, -170, 0.5, -210)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Parent = gui

local corner = Instance.new("UICorner", main)
corner.CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = C.edge
stroke.Thickness = 1.5

-- Тень
local shadow = Instance.new("ImageLabel", main)
shadow.Size = UDim2.new(1, 40, 1, 40)
shadow.Position = UDim2.new(0, -20, 0, -20)
shadow.BackgroundTransparency = 1
shadow.ImageTransparency = 0.4
shadow.Image = "rbxassetid://1316045217"
shadow.ScaleType = Enum.ScaleType.Slice
shadow.SliceCenter = Rect.new(24, 24, 276, 276)
shadow.ZIndex = -1

-- Хедер
local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 44)
header.BackgroundColor3 = C.panel
header.BorderSizePixel = 0
header.Parent = main
Instance.new("UICorner", header).CornerRadius = UDim.new(0, 10)

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.Position = UDim2.new(0, 14, 0, 0)
title.BackgroundTransparency = 1
title.Text = "MM2 TRADE LOGGER"
title.TextColor3 = C.txt
title.TextSize = 15
title.Font = Enum.Font.GothamBlack
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local verTag = Instance.new("TextLabel")
verTag.Size = UDim2.new(0, 34, 0, 16)
verTag.Position = UDim2.new(1, -76, 0.5, -8)
verTag.BackgroundColor3 = C.amber
verTag.BackgroundTransparency = 0.85
verTag.Text = "v1.0"
verTag.TextColor3 = C.amber
verTag.TextSize = 10
verTag.Font = Enum.Font.GothamBold
verTag.Parent = header
Instance.new("UICorner", verTag).CornerRadius = UDim.new(0, 4)

-- Кнопка свернуть
local minBtn = Instance.new("TextButton")
minBtn.Size = UDim2.new(0, 28, 0, 28)
minBtn.Position = UDim2.new(1, -36, 0.5, -14)
minBtn.BackgroundColor3 = C.edge
minBtn.BackgroundTransparency = 0.5
minBtn.Text = "—"
minBtn.TextColor3 = C.txt
minBtn.TextSize = 14
minBtn.Font = Enum.Font.GothamBold
minBtn.Parent = header
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

-- Статус-бар
local statusRow = Instance.new("Frame")
statusRow.Size = UDim2.new(1, -24, 0, 30)
statusRow.Position = UDim2.new(0, 12, 0, 54)
statusRow.BackgroundTransparency = 1
statusRow.Parent = main

local dot = Instance.new("Frame")
dot.Size = UDim2.new(0, 10, 0, 10)
dot.Position = UDim2.new(0, 0, 0.5, -5)
dot.BackgroundColor3 = C.idle
dot.Parent = statusRow
Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

local statusTxt = Instance.new("TextLabel")
statusTxt.Size = UDim2.new(1, -20, 1, 0)
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

-- Кнопка START/STOP
local recBtn = Instance.new("TextButton")
recBtn.Size = UDim2.new(1, -24, 0, 52)
recBtn.Position = UDim2.new(0, 12, 0, 92)
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
btnRow.Size = UDim2.new(1, -24, 0, 34)
btnRow.Position = UDim2.new(0, 12, 0, 152)
btnRow.BackgroundTransparency = 1
btnRow.Parent = main
local rowLayout = Instance.new("UIListLayout", btnRow)
rowLayout.FillDirection = Enum.FillDirection.Horizontal
rowLayout.Padding = UDim.new(0, 8)

local function mkSmallBtn(text, color)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 100, 1, 0)
    b.BackgroundColor3 = color
    b.BackgroundTransparency = 0.75
    b.Text = text
    b.TextColor3 = color
    b.TextSize = 12
    b.Font = Enum.Font.GothamBold
    b.AutoButtonColor = false
    b.Parent = btnRow
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
    return b
end

local dumpBtn = mkSmallBtn("DUMP", C.amber)
local clearBtn = mkSmallBtn("CLEAR", C.rec)
local pathBtn = mkSmallBtn("PATH", C.idle)

-- Превью лога
local prevLabel = Instance.new("TextLabel")
prevLabel.Size = UDim2.new(1, -24, 0, 16)
prevLabel.Position = UDim2.new(0, 12, 0, 194)
prevLabel.BackgroundTransparency = 1
prevLabel.Text = "LIVE LOG"
prevLabel.TextColor3 = C.dim
prevLabel.TextSize = 10
prevLabel.Font = Enum.Font.GothamBold
prevLabel.TextXAlignment = Enum.TextXAlignment.Left
prevLabel.Parent = main

local preview = Instance.new("ScrollingFrame")
preview.Size = UDim2.new(1, -24, 1, -222)
preview.Position = UDim2.new(0, 12, 0, 212)
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

    -- чистим старые
    local kids = preview:GetChildren()
    local count = 0
    for _, k in ipairs(kids) do if k:IsA("TextLabel") then count = count + 1 end end
    if count > MAX_PREVIEW then
        for _, k in ipairs(kids) do
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

local function pressFX(btn)
    btn.MouseButton1Down:Connect(function() tween(btn, {Size = btn.Size - UDim2.new(0, 0, 0, 3)}, 0.08) end)
    btn.MouseButton1Up:Connect(function() tween(btn, {Size = btn.Size + UDim2.new(0, 0, 0, 3)}, 0.12) end)
end
pressFX(recBtn); pressFX(dumpBtn); pressFX(clearBtn); pressFX(pathBtn); pressFX(minBtn)

-- Пульсация точки при записи
local pulseOn = false
task.spawn(function()
    while true do
        if pulseOn then
            tween(dot, {BackgroundTransparency = 0.2}, 0.5)
            task.wait(0.5)
            tween(dot, {BackgroundTransparency = 0.9}, 0.5)
            task.wait(0.5)
        else
            dot.BackgroundTransparency = 0
            task.wait(0.3)
        end
    end
end)

-- Drag
local dragging, dragStart, startPos
header.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = main.Position
    end
end)
UIS.InputChanged:Connect(function(input)
    if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        local d = input.Position - dragStart
        main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
    end
end)
UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        dragging = false
    end
end)

-- Свернуть
local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(main, {Size = UDim2.new(0, 340, 0, 44)}, 0.25)
        minBtn.Text = "+"
    else
        tween(main, {Size = UDim2.new(0, 340, 0, 420)}, 0.25)
        minBtn.Text = "—"
    end
end)

-- ═══════════════════════════════════════════
-- Логирование (файл + превью + консоль)
-- ═══════════════════════════════════════════
local function addLog(dir, path, method, args)
    local entry = { time = os.clock(), dir = dir, remote = path, method = method, args = args }
    LOG[#LOG + 1] = entry

    local line = string.format("[%.2f] %s | %s | %s | %s", entry.time, dir, path, method, args)
    print(PREFIX .. line)
    appendfile(LOG_FILE, line .. "\n")

    counter.Text = #LOG .. " записей"
    local color = dir == "C→S" and C.amber or C.idle
    addPreview(dir .. " " .. path:match("%.([^%.]+)$") .. " " .. args, color)
end

-- ═══════════════════════════════════════════
-- Хуки
-- ═══════════════════════════════════════════
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", function(self, ...)
    if logging then
        local m = getnamecallmethod()
        if m == "FireServer" or m == "InvokeServer" then
            pcall(function()
                addLog("C→S", self:GetFullName(), self.ClassName .. ":" .. m, serArgs({ ... }))
            end)
        end
    end
    return oldNamecall(self, ...)
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
    logging = not logging
    if logging then
        recBtn.BackgroundColor3 = C.rec
        recBtn.Text = "■  STOP"
        statusTxt.Text = "RECORDING — трейд ловится"
        statusTxt.TextColor3 = C.rec
        dot.BackgroundColor3 = C.rec
        pulseOn = true
        appendfile(LOG_FILE, "\n--- RECORDING STARTED ---\n")
        addPreview(">>> запись включена", C.rec)
    else
        recBtn.BackgroundColor3 = C.idle
        recBtn.Text = "▶  START"
        statusTxt.Text = "IDLE — остановлено"
        statusTxt.TextColor3 = C.dim
        dot.BackgroundColor3 = C.idle
        pulseOn = false
        appendfile(LOG_FILE, "--- RECORDING STOPPED ---\n\n")
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
    LOG = {}
    counter.Text = "0 записей"
    for _, k in ipairs(preview:GetChildren()) do if k:IsA("TextLabel") then k:Destroy() end end
    writefile(LOG_FILE, "")
    addPreview(">>> лог очищен", C.rec)
end)

pathBtn.MouseButton1Click:Connect(function()
    if setclipboard then setclipboard(LOG_FILE) end
    addPreview(">>> путь: " .. LOG_FILE, C.idle)
    print(PREFIX .. "Log file: " .. LOG_FILE)
end)

-- ═══════════════════════════════════════════
-- Старт
-- ═══════════════════════════════════════════
local rc = 0
for _, o in ipairs(game:GetDescendants()) do
    if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then rc = rc + 1 end
end
addPreview("logger готов, remotes: " .. rc, C.dim)
addPreview("файл: " .. LOG_FILE, C.dim)
print(PREFIX .. "GUI ready. Remotes: " .. rc .. " | File: " .. LOG_FILE)
