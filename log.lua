-- MM2 Trade Logger — Delta (robust, boot-first, in-GUI diagnostics)

local UIS = game:GetService("UserInputService")
local TS = game:GetService("TweenService")
local Players = game:GetService("Players")
local LP = Players.LocalPlayer

local function has(v) return type(v) == "function" end
local unpackFn = table.unpack or unpack

-- ===== capability detection =====
local CAP = {
    hook = has(hookmetamethod) and has(getnamecallmethod),
    getgc = has(getgc),
    files = has(writefile) and has(appendfile) and has(isfolder) and has(makefolder),
    gethui = has(gethui),
    clipboard = has(setclipboard),
}

-- ===== state =====
local logging = false
local hooksInstalled = false
local LOG = {}
local PREFIX = "[MM2-TRADE] "

-- ===== files (lazy) =====
local FILE_OK = false
local LOG_DIR = "MM2_Logs"
local LOG_FILE = LOG_DIR .. "/trade_log_" .. tostring(os.time()) .. ".txt"

local function initFiles()
    if not CAP.files then return false end
    local ok = pcall(function()
        if not isfolder(LOG_DIR) then makefolder(LOG_DIR) end
        writefile(LOG_FILE, "MM2 TRADE LOGGER\nStarted: " .. os.date("%Y-%m-%d %H:%M:%S") .. "\n========================================\n")
    end)
    FILE_OK = ok
    return ok
end

local function fappend(line)
    if FILE_OK then pcall(appendfile, LOG_FILE, line .. "\n") end
end

-- ===== serialization =====
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
    local count = a.n or #a
    for i = 1, count do p[i] = "[" .. i .. "]=" .. ser(a[i]) end
    return #p > 0 and table.concat(p, " | ") or "(none)"
end

-- ===== palette =====
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

-- ===== safe gui parent =====
local function getGuiParent()
    local p
    if CAP.gethui then pcall(function() p = gethui() end) end
    if p then return p end
    pcall(function() p = game:GetService("CoreGui") end)
    if p then return p end
    pcall(function() p = game.CoreGui end)
    if p then return p end
    return LP:WaitForChild("PlayerGui")
end

-- ===== GUI =====
local gui = Instance.new("ScreenGui")
gui.Name = "MM2TradeLogger"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = getGuiParent()

local main = Instance.new("Frame")
main.Size = UDim2.new(0, 340, 0, 440)
main.Position = UDim2.new(0.5, -170, 0.5, -220)
main.BackgroundColor3 = C.bg
main.BorderSizePixel = 0
main.ClipsDescendants = true
main.Active = true
main.Parent = gui
Instance.new("UICorner", main).CornerRadius = UDim.new(0, 10)
local stroke = Instance.new("UIStroke", main)
stroke.Color = C.edge; stroke.Thickness = 1.5

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
minBtn.Text = "-"
minBtn.TextColor3 = C.txt
minBtn.TextSize = 14
minBtn.Font = Enum.Font.GothamBold
minBtn.AutoButtonColor = false
minBtn.ZIndex = 5
minBtn.Parent = header
Instance.new("UICorner", minBtn).CornerRadius = UDim.new(0, 6)

local capLine = Instance.new("TextLabel")
capLine.Size = UDim2.new(1, -24, 0, 16)
capLine.Position = UDim2.new(0, 12, 0, 50)
capLine.BackgroundTransparency = 1
capLine.Text = ""
capLine.TextColor3 = C.dim
capLine.TextSize = 10
capLine.Font = Enum.Font.Code
capLine.TextXAlignment = Enum.TextXAlignment.Left
capLine.Parent = main

local function yn(b) return b and "Y" or "n" end
capLine.Text = string.format("hook:%s getgc:%s files:%s clip:%s",
    yn(CAP.hook), yn(CAP.getgc), yn(CAP.files), yn(CAP.clipboard))

local statusRow = Instance.new("Frame")
statusRow.Size = UDim2.new(1, -24, 0, 24)
statusRow.Position = UDim2.new(0, 12, 0, 68)
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
statusTxt.Text = "IDLE"
statusTxt.TextColor3 = C.dim
statusTxt.TextSize = 12
statusTxt.Font = Enum.Font.GothamMedium
statusTxt.TextXAlignment = Enum.TextXAlignment.Left
statusTxt.Parent = statusRow

local counter = Instance.new("TextLabel")
counter.Size = UDim2.new(0, 80, 1, 0)
counter.Position = UDim2.new(1, -80, 0, 0)
counter.BackgroundTransparency = 1
counter.Text = "0 entries"
counter.TextColor3 = C.amber
counter.TextSize = 12
counter.Font = Enum.Font.GothamBold
counter.TextXAlignment = Enum.TextXAlignment.Right
counter.Parent = statusRow

local recBtn = Instance.new("TextButton")
recBtn.Size = UDim2.new(1, -24, 0, 50)
recBtn.Position = UDim2.new(0, 12, 0, 98)
recBtn.BackgroundColor3 = C.idle
recBtn.Text = "START"
recBtn.TextColor3 = Color3.fromRGB(10, 12, 16)
recBtn.TextSize = 17
recBtn.Font = Enum.Font.GothamBlack
recBtn.AutoButtonColor = false
recBtn.Parent = main
Instance.new("UICorner", recBtn).CornerRadius = UDim.new(0, 8)

local btnRow = Instance.new("Frame")
btnRow.Size = UDim2.new(1, -24, 0, 32)
btnRow.Position = UDim2.new(0, 12, 0, 156)
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

local prevLabel = Instance.new("TextLabel")
prevLabel.Size = UDim2.new(1, -24, 0, 16)
prevLabel.Position = UDim2.new(0, 12, 0, 196)
prevLabel.BackgroundTransparency = 1
prevLabel.Text = "LIVE LOG"
prevLabel.TextColor3 = C.dim
prevLabel.TextSize = 10
prevLabel.Font = Enum.Font.GothamBold
prevLabel.TextXAlignment = Enum.TextXAlignment.Left
prevLabel.Parent = main

local preview = Instance.new("ScrollingFrame")
preview.Size = UDim2.new(1, -24, 1, -224)
preview.Position = UDim2.new(0, 12, 0, 214)
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
    preview.CanvasPosition = Vector2.new(0, 999999)
end

-- ===== animations =====
local function tween(obj, props, t)
    TS:Create(obj, TweenInfo.new(t or 0.2, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), props):Play()
end

local function pressFX(btn, baseTrans)
    baseTrans = baseTrans or 0
    btn.MouseButton1Down:Connect(function() tween(btn, {BackgroundTransparency = math.max(baseTrans - 0.25, 0)}, 0.07) end)
    btn.MouseButton1Up:Connect(function() tween(btn, {BackgroundTransparency = baseTrans}, 0.12) end)
end
pressFX(recBtn, 0)
pressFX(dumpBtn, 0.78)
pressFX(clearBtn, 0.78)
pressFX(gcBtn, 0.78)
pressFX(pathBtn, 0.78)
pressFX(minBtn, 0.5)

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

local minimized = false
minBtn.MouseButton1Click:Connect(function()
    minimized = not minimized
    if minimized then
        tween(main, {Size = UDim2.new(0, 340, 0, 44)}, 0.25); minBtn.Text = "+"
    else
        tween(main, {Size = UDim2.new(0, 340, 0, 440)}, 0.25); minBtn.Text = "-"
    end
end)

-- ===== logging =====
local function addLog(dir, path, method, args)
    LOG[#LOG + 1] = { time = os.clock(), dir = dir, remote = path, method = method, args = args }
    local line = string.format("[%.2f] %s | %s | %s | %s", os.clock(), dir, path, method, args)
    pcall(print, PREFIX .. line)
    fappend(line)
    counter.Text = #LOG .. " entries"
    local color = dir == "C->S" and C.amber or C.idle
    local short = path:match("%.([^%.]+)$") or path
    addPreview(dir .. " " .. short .. " " .. args, color)
end

-- ===== hooks (installed lazily on START) =====
local function installHooks()
    if hooksInstalled then return true end
    if not CAP.hook then return false end
    local ok = pcall(function()
        local old
        old = hookmetamethod(game, "__namecall", function(self, ...)
            if logging then
                local m = getnamecallmethod()
                if m == "FireServer" or m == "InvokeServer" then
                    local args = { ... }
                    args.n = select("#", ...)
                    local selfRef = self
                    pcall(function()
                        addLog("C->S", selfRef:GetFullName(), selfRef.ClassName .. ":" .. m, serArgs(args))
                    end)
                end
            end
            return old(self, ...)
        end)
    end)
    if not ok then return false end

    local hooked = {}
    local function hookRemote(r)
        if hooked[r] then return end
        hooked[r] = true
        pcall(function()
            if r:IsA("RemoteEvent") then
                r.OnClientEvent:Connect(function(...)
                    if logging then
                        local args = { ... }
                        args.n = select("#", ...)
                        local rRef = r
                        pcall(function() addLog("S->C", rRef:GetFullName(), "OnClientEvent", serArgs(args)) end)
                    end
                end)
            elseif r:IsA("RemoteFunction") then
                pcall(function()
                    local oldInvoke = r.OnClientInvoke
                    if oldInvoke then
                        r.OnClientInvoke = function(...)
                            local args = { ... }
                            args.n = select("#", ...)
                            if logging then
                                local rRef = r
                                pcall(function() addLog("S->C", rRef:GetFullName(), "OnClientInvoke", serArgs(args)) end)
                            end
                            return oldInvoke(unpackFn(args, 1, args.n))
                        end
                    end
                end)
            end
        end)
    end

    pcall(function()
        for _, o in ipairs(game:GetDescendants()) do
            if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then hookRemote(o) end
        end
    end)
    game.DescendantAdded:Connect(function(o)
        if o:IsA("RemoteEvent") or o:IsA("RemoteFunction") then
            if logging then addPreview("NEW REMOTE: " .. o:GetFullName(), C.amber) end
            hookRemote(o)
        end
    end)

    hooksInstalled = true
    return true
end

-- ===== START / STOP =====
recBtn.MouseButton1Click:Connect(function()
    if not logging then
        initFiles()
        local ok = installHooks()
        if not ok then
            addPreview(">>> hook FAIL: no hookmetamethod", C.rec)
            statusTxt.Text = "HOOK UNAVAILABLE"; statusTxt.TextColor3 = C.rec
            return
        end
        logging = true
        recBtn.BackgroundColor3 = C.rec; recBtn.Text = "STOP"
        statusTxt.Text = "RECORDING"; statusTxt.TextColor3 = C.rec
        dot.BackgroundColor3 = C.rec; pulseOn = true
        fappend("\n--- RECORDING STARTED ---")
        addPreview(">>> recording ON", C.rec)
        addPreview(">>> files: " .. (FILE_OK and "OK" or "OFF"), FILE_OK and C.idle or C.amber)
    else
        logging = false
        recBtn.BackgroundColor3 = C.idle; recBtn.Text = "START"
        statusTxt.Text = "IDLE"; statusTxt.TextColor3 = C.dim
        dot.BackgroundColor3 = C.idle; pulseOn = false
        fappend("--- RECORDING STOPPED ---\n")
        addPreview(">>> recording OFF", C.idle)
    end
end)

-- ===== buttons =====
dumpBtn.MouseButton1Click:Connect(function()
    local lines = {}
    for i, e in ipairs(LOG) do
        lines[i] = string.format("[%03d] %.2f | %s | %s | %s | %s", i, e.time, e.dir, e.remote, e.method, e.args)
    end
    local full = table.concat(lines, "\n")
    pcall(print, PREFIX .. "=== DUMP (" .. #LOG .. ") ===")
    for _, l in ipairs(lines) do pcall(print, l) end
    local clipped = false
    if CAP.clipboard then pcall(function() setclipboard(full) clipped = true end) end
    if FILE_OK then pcall(writefile, LOG_DIR .. "/dump.txt", full) end
    if clipped then
        addPreview(">>> " .. #LOG .. " entries -> CLIPBOARD (paste it)", C.amber)
    elseif FILE_OK then
        addPreview(">>> " .. #LOG .. " entries -> MM2_Logs/dump.txt", C.amber)
    else
        addPreview(">>> " .. #LOG .. " entries (no clip/files: see preview)", C.rec)
    end
end)

clearBtn.MouseButton1Click:Connect(function()
    LOG = {}; counter.Text = "0 entries"
    for _, k in ipairs(preview:GetChildren()) do if k:IsA("TextLabel") then k:Destroy() end end
    if FILE_OK then pcall(writefile, LOG_FILE, "") end
    addPreview(">>> cleared", C.rec)
end)

gcBtn.MouseButton1Click:Connect(function()
    if not CAP.getgc then addPreview(">>> getgc unavailable", C.rec) return end
    addPreview(">>> scanning GC...", C.dim)
    task.spawn(function()
        local hits = 0
        pcall(function()
            for _, v in ipairs(getgc(true)) do
                if type(v) == "table" then
                    for key, val in pairs(v) do
                        if type(key) == "string" and key:lower():match("trade") then
                            hits = hits + 1
                            local line = "GC TABLE: " .. key .. " (" .. type(val) .. ")"
                            pcall(print, PREFIX .. line); fappend(line); addPreview(line, C.idle)
                        end
                    end
                elseif type(v) == "function" then
                    pcall(function()
                        local info = debug.getinfo(v)
                        if info and info.name and tostring(info.name):lower():match("trade") then
                            hits = hits + 1
                            local line = "GC FUNC: " .. tostring(info.name)
                            pcall(print, PREFIX .. line); fappend(line); addPreview(line, C.idle)
                        end
                    end)
                end
            end
        end)
        addPreview(">>> GC done: " .. hits .. " hits", C.amber)
    end)
end)

pathBtn.MouseButton1Click:Connect(function()
    if not FILE_OK then addPreview(">>> files OFF - log in console only", C.rec) return end
    if CAP.clipboard then pcall(setclipboard, LOG_FILE) end
    addPreview(">>> " .. LOG_FILE, C.idle)
    pcall(print, PREFIX .. "Log file: " .. LOG_FILE)
end)

-- ===== boot done =====
addPreview("BOOT OK", C.idle)
addPreview("press START, then do the trade", C.dim)
pcall(print, PREFIX .. "BOOT OK")
