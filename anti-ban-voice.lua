--[[
    ╔══════════════════════════════════════════╗
    ║   XXIV Voice Guard — Executor Edition    ║
    ║   Universal · No server required         ║
    ║   Works on: Synapse X/Z, KRNL, Solara,  ║
    ║             Fluxus, Wave, Delta          ║
    ╚══════════════════════════════════════════╝

    CARA PAKAI:
    1. Buka game Roblox yang ada voice chat-nya
    2. Inject executor lo
    3. Execute script ini
    4. Klik tombol VG di kiri layar → toggle fitur

    FITUR:
    ┌─────────────────────────────────────────────────────┐
    │ 🔇 Voice Filter  — blok auto-mute dari Roblox       │
    │ 🎤 Mic Spoof     — force mic tetap ON               │
    │ 🛡️ Anti-Kick     — filter RemoteEvent kick/mute     │
    │ 👻 Ghost Mic     — mic keliatan OFF, suara jalan    │
    └─────────────────────────────────────────────────────┘

    CATATAN GHOST MIC:
    - Pakai AudioDeviceInput → AudioEmitter pipeline
    - Executor dengan getgenv/hookfunction = lebih stabil
    - Tanpa hookfunction: fallback heartbeat monitor
    - Player lain denger via AudioListener di karakter mereka
    - Roblox voice moderation nggak detect pipeline ini
]]

------------------------------------------------------------------------
-- GUARD: jangan inject dua kali
------------------------------------------------------------------------
if getgenv and getgenv().XXIV_VG_LOADED then
    -- Sudah inject sebelumnya, skip
    return
end
if getgenv then getgenv().XXIV_VG_LOADED = true end

------------------------------------------------------------------------
-- SERVICES
------------------------------------------------------------------------
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local GuiService   = game:GetService("GuiService")
local RS           = game:GetService("ReplicatedStorage")

local ok_vcs, VoiceChatSvc = pcall(function()
    return game:GetService("VoiceChatService")
end)
if not ok_vcs then VoiceChatSvc = nil end

local lp         = Players.LocalPlayer
local PlayerGui  = lp:WaitForChild("PlayerGui", 15)

------------------------------------------------------------------------
-- EXECUTOR API DETECT
------------------------------------------------------------------------
local hookFunc   = (typeof(hookfunction) == "function")  and hookfunction  or nil
local newcclos   = (typeof(newcclosure)  == "function")  and newcclosure   or nil
local isfunc     = (typeof(isfunction)   == "function")  and isfunction    or nil

-- Cek apakah executor support hookmetamethod (Synapse/Solara level)
local hasHookMeta = (typeof(hookmetamethod) == "function")

------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------
local CFG = {
    PANEL_W        = 220,
    PANEL_H        = 288,
    LOGO_SIZE      = 48,
    DRAG_THRESHOLD = 12,
}

------------------------------------------------------------------------
-- STATE
------------------------------------------------------------------------
local State = {
    PanelOpen   = false,
    VoiceFilter = false,
    MicSpoof    = false,
    AntiKick    = false,
    GhostMic    = false,
}
local Conns    = {}
local hooked   = {}
local origMute = nil

-- Ghost Mic instances
local gmInput   = nil
local gmEmitter = nil
local gmWire    = nil

------------------------------------------------------------------------
-- GUI ROOT
-- Executor: pakai syn.protect_gui kalau ada, fallback ke PlayerGui
------------------------------------------------------------------------
local SG = Instance.new("ScreenGui")
SG.Name           = "XXIVVoiceGuard"
SG.ResetOnSpawn   = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true

-- Protect GUI dari detection (Synapse/KRNL)
if syn and syn.protect_gui then
    syn.protect_gui(SG)
    SG.Parent = game:GetService("CoreGui")
elseif gethui then
    SG.Parent = gethui()
else
    pcall(function()
        SG.Parent = game:GetService("CoreGui")
    end)
    if not SG.Parent then
        SG.Parent = PlayerGui
    end
end

------------------------------------------------------------------------
-- LOGO FRAME
------------------------------------------------------------------------
local LogoFrame = Instance.new("Frame")
LogoFrame.Size             = UDim2.new(0, CFG.LOGO_SIZE, 0, CFG.LOGO_SIZE)
LogoFrame.Position         = UDim2.new(0, 20, 0.5, -CFG.LOGO_SIZE/2)
LogoFrame.BackgroundColor3 = Color3.fromRGB(22, 14, 50)
LogoFrame.BorderSizePixel  = 0
LogoFrame.ZIndex           = 20
LogoFrame.Parent           = SG
Instance.new("UICorner", LogoFrame).CornerRadius = UDim.new(1, 0)

local logoStroke = Instance.new("UIStroke")
logoStroke.Color     = Color3.fromRGB(100, 65, 210)
logoStroke.Thickness = 1.8
logoStroke.Parent    = LogoFrame

local LogoDisplay = Instance.new("TextLabel")
LogoDisplay.Text              = "VG"
LogoDisplay.TextColor3        = Color3.fromRGB(200, 175, 255)
LogoDisplay.TextSize          = 14
LogoDisplay.Font              = Enum.Font.GothamBold
LogoDisplay.TextXAlignment    = Enum.TextXAlignment.Center
LogoDisplay.TextYAlignment    = Enum.TextYAlignment.Center
LogoDisplay.BackgroundTransparency = 1
LogoDisplay.Size              = UDim2.new(1,-8,1,-8)
LogoDisplay.Position          = UDim2.new(0,4,0,4)
LogoDisplay.ZIndex            = 21
LogoDisplay.Parent            = LogoFrame

local LogoDot = Instance.new("Frame")
LogoDot.Size              = UDim2.new(0,10,0,10)
LogoDot.Position          = UDim2.new(1,-11,0,1)
LogoDot.BackgroundColor3  = Color3.fromRGB(80,80,80)
LogoDot.BorderSizePixel   = 0
LogoDot.ZIndex            = 22
LogoDot.Parent            = LogoFrame
Instance.new("UICorner", LogoDot).CornerRadius = UDim.new(1, 0)

local ldS = Instance.new("UIStroke")
ldS.Color = Color3.fromRGB(13,9,26); ldS.Thickness = 1.5; ldS.Parent = LogoDot

local LogoBtn = Instance.new("TextButton")
LogoBtn.Size               = UDim2.new(1,0,1,0)
LogoBtn.BackgroundTransparency = 1
LogoBtn.Text               = ""
LogoBtn.ZIndex             = 23
LogoBtn.AutoButtonColor    = false
LogoBtn.Parent             = LogoFrame

------------------------------------------------------------------------
-- PANEL
------------------------------------------------------------------------
local Panel = Instance.new("Frame")
Panel.Name              = "Panel"
Panel.Size              = UDim2.new(0, CFG.PANEL_W, 0, CFG.PANEL_H)
Panel.Position          = UDim2.new(0, 76, 0.5, -CFG.PANEL_H/2)
Panel.BackgroundColor3  = Color3.fromRGB(13, 9, 26)
Panel.BorderSizePixel   = 0
Panel.Visible           = false
Panel.ZIndex            = 15
Panel.Parent            = SG
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 14)

local ps = Instance.new("UIStroke")
ps.Color = Color3.fromRGB(85,55,175); ps.Thickness = 1.4; ps.Parent = Panel

local pg = Instance.new("UIGradient")
pg.Color = ColorSequence.new{
    ColorSequenceKeypoint.new(0, Color3.fromRGB(22,14,46)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(11,7,22)),
}
pg.Rotation = 120; pg.Parent = Panel

-- Header
local PHeader = Instance.new("Frame")
PHeader.Size            = UDim2.new(1,0,0,38)
PHeader.BackgroundColor3 = Color3.fromRGB(20,12,44)
PHeader.BorderSizePixel = 0
PHeader.ZIndex          = 16
PHeader.Parent          = Panel
Instance.new("UICorner", PHeader).CornerRadius = UDim.new(0, 14)

local HLabel = Instance.new("TextLabel")
HLabel.Text             = "🎙️  Voice Guard"
HLabel.Size             = UDim2.new(1,-12,1,0)
HLabel.Position         = UDim2.new(0,12,0,0)
HLabel.BackgroundTransparency = 1
HLabel.TextColor3       = Color3.fromRGB(185,160,255)
HLabel.TextSize         = 13
HLabel.Font             = Enum.Font.GothamBold
HLabel.TextXAlignment   = Enum.TextXAlignment.Left
HLabel.ZIndex           = 17
HLabel.Parent           = PHeader

-- Status bar
local SBar = Instance.new("Frame")
SBar.Size            = UDim2.new(1,-16,0,24)
SBar.Position        = UDim2.new(0,8,0,42)
SBar.BackgroundColor3 = Color3.fromRGB(19,12,38)
SBar.BorderSizePixel = 0; SBar.ZIndex = 16; SBar.Parent = Panel
Instance.new("UICorner", SBar).CornerRadius = UDim.new(0, 7)

local SDot = Instance.new("Frame")
SDot.Size = UDim2.new(0,8,0,8); SDot.Position = UDim2.new(0,8,0.5,-4)
SDot.BackgroundColor3 = Color3.fromRGB(80,80,80)
SDot.BorderSizePixel = 0; SDot.ZIndex = 17; SDot.Parent = SBar
Instance.new("UICorner", SDot).CornerRadius = UDim.new(1, 0)

local STxt = Instance.new("TextLabel")
STxt.Text = "Semua mati"; STxt.Size = UDim2.new(1,-26,1,0)
STxt.Position = UDim2.new(0,22,0,0); STxt.BackgroundTransparency = 1
STxt.TextColor3 = Color3.fromRGB(125,115,150); STxt.TextSize = 10
STxt.Font = Enum.Font.Gotham; STxt.TextXAlignment = Enum.TextXAlignment.Left
STxt.ZIndex = 17; STxt.Parent = SBar

-- Toggle container
local SF = Instance.new("Frame")
SF.Name = "ToggleContainer"
SF.Size = UDim2.new(1,0,1,-72); SF.Position = UDim2.new(0,0,0,72)
SF.BackgroundTransparency = 1; SF.BorderSizePixel = 0
SF.ClipsDescendants = false; SF.ZIndex = 16; SF.Parent = Panel
local ll = Instance.new("UIListLayout")
ll.Padding = UDim.new(0,6); ll.SortOrder = Enum.SortOrder.LayoutOrder; ll.Parent = SF
local lpad = Instance.new("UIPadding")
lpad.PaddingLeft = UDim.new(0,8); lpad.PaddingRight = UDim.new(0,8)
lpad.PaddingTop = UDim.new(0,6); lpad.PaddingBottom = UDim.new(0,14); lpad.Parent = SF

------------------------------------------------------------------------
-- STATUS UPDATE
------------------------------------------------------------------------
local function updateStatus()
    local anyOn = State.VoiceFilter or State.MicSpoof or State.AntiKick or State.GhostMic
    local allOn = State.VoiceFilter and State.MicSpoof and State.AntiKick
    local dc, tc, tx
    if allOn then
        dc=Color3.fromRGB(70,215,115); tc=Color3.fromRGB(80,205,125); tx="Full protection aktif 🔒"
    elseif anyOn then
        dc=Color3.fromRGB(220,175,45); tc=Color3.fromRGB(210,170,55); tx="Sebagian aktif ⚠️"
    else
        dc=Color3.fromRGB(80,80,80); tc=Color3.fromRGB(125,115,150); tx="Semua mati"
    end
    SDot.BackgroundColor3 = dc; STxt.TextColor3 = tc; STxt.Text = tx
    LogoDot.BackgroundColor3 = dc
    logoStroke.Color = anyOn and Color3.fromRGB(120,80,230) or Color3.fromRGB(100,65,210)
end

local function positionPanel()
    local lf = LogoFrame.Position
    Panel.Position = UDim2.new(
        lf.X.Scale, lf.X.Offset + CFG.LOGO_SIZE + 10,
        lf.Y.Scale, lf.Y.Offset
    )
end

------------------------------------------------------------------------
-- TOGGLE BUILDER
------------------------------------------------------------------------
local tOrder = 0
local function buildToggle(icon, labelTxt, stateKey, onCb)
    tOrder += 1
    local row = Instance.new("Frame")
    row.Name = stateKey; row.Size = UDim2.new(1,0,0,44)
    row.BackgroundColor3 = Color3.fromRGB(20,13,40)
    row.BorderSizePixel = 0; row.LayoutOrder = tOrder; row.ZIndex = 17; row.Parent = SF
    Instance.new("UICorner", row).CornerRadius = UDim.new(0, 9)

    local ico = Instance.new("TextLabel")
    ico.Text = icon; ico.Size = UDim2.new(0,32,1,0); ico.Position = UDim2.new(0,6,0,0)
    ico.BackgroundTransparency = 1; ico.TextSize = 18; ico.Font = Enum.Font.GothamBold
    ico.TextXAlignment = Enum.TextXAlignment.Center
    ico.TextYAlignment = Enum.TextYAlignment.Center
    ico.ZIndex = 18; ico.Parent = row

    local lbl = Instance.new("TextLabel")
    lbl.Text = labelTxt; lbl.Size = UDim2.new(1,-88,1,0); lbl.Position = UDim2.new(0,40,0,0)
    lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.fromRGB(195,180,225)
    lbl.TextSize = 11; lbl.Font = Enum.Font.Gotham
    lbl.TextXAlignment = Enum.TextXAlignment.Left
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.TextWrapped = true; lbl.ZIndex = 18; lbl.Parent = row

    local pill = Instance.new("Frame")
    pill.Size = UDim2.new(0,40,0,20); pill.Position = UDim2.new(1,-48,0.5,-10)
    pill.BackgroundColor3 = Color3.fromRGB(40,28,68)
    pill.BorderSizePixel = 0; pill.ZIndex = 18; pill.Parent = row
    Instance.new("UICorner", pill).CornerRadius = UDim.new(1, 0)

    local knob = Instance.new("Frame")
    knob.Size = UDim2.new(0,14,0,14); knob.Position = UDim2.new(0,3,0.5,-7)
    knob.BackgroundColor3 = Color3.fromRGB(95,80,145)
    knob.BorderSizePixel = 0; knob.ZIndex = 19; knob.Parent = pill
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1,0,1,0); btn.BackgroundTransparency = 1
    btn.Text = ""; btn.ZIndex = 25; btn.AutoButtonColor = false; btn.Parent = row

    local function refresh()
        local on = State[stateKey]
        pill.BackgroundColor3  = on and Color3.fromRGB(75,45,165)   or Color3.fromRGB(40,28,68)
        knob.BackgroundColor3  = on and Color3.fromRGB(205,185,255)  or Color3.fromRGB(95,80,145)
        knob.Position          = on and UDim2.new(0,23,0.5,-7)      or UDim2.new(0,3,0.5,-7)
        lbl.TextColor3         = on and Color3.fromRGB(220,205,255)  or Color3.fromRGB(195,180,225)
    end

    local function doToggle()
        State[stateKey] = not State[stateKey]
        refresh(); onCb(State[stateKey]); updateStatus()
    end

    btn.MouseButton1Click:Connect(doToggle)
    btn.TouchTap:Connect(doToggle)
    refresh()
end

------------------------------------------------------------------------
-- FEATURES
------------------------------------------------------------------------

-- ── MUTE HOOK ──────────────────────────────────────────────────────
local function installMuteHook()
    if not VoiceChatSvc then return end
    if hookFunc and not origMute then
        pcall(function()
            origMute = hookFunc(VoiceChatSvc.SetMuted,
                function(self, muted, ...)
                    if muted == true and (State.VoiceFilter or State.MicSpoof or State.GhostMic) then
                        return  -- block mute
                    end
                    return origMute(self, muted, ...)
                end)
        end)
    end
end

local function removeMuteHook()
    if origMute and hookFunc then
        pcall(function() hookFunc(VoiceChatSvc.SetMuted, origMute) end)
        origMute = nil
    end
end

-- ── MAIN HEARTBEAT LOOP ────────────────────────────────────────────
local jitterAcc      = 0
local jitterInterval = 0.3

local function startMainLoop()
    if Conns.main then return end
    Conns.main = RunService.Heartbeat:Connect(function(dt)

        -- Ghost Mic: jaga AudioDeviceInput tetap capturing, pantau wire
        if State.GhostMic then
            if gmInput and gmInput.Parent then
                if gmInput.Muted then
                    pcall(function() gmInput.Muted = false end)
                end
            end
            -- Auto-rebuild wire kalau putus
            local char = lp.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            if root and gmInput and gmInput.Parent and gmEmitter and gmEmitter.Parent then
                local w = root:FindFirstChild("GhostWire")
                if not w then
                    pcall(function()
                        local wire = Instance.new("Wire")
                        wire.Name           = "GhostWire"
                        wire.SourceInstance = gmInput
                        wire.TargetInstance = gmEmitter
                        wire.Parent         = root
                        gmWire = wire
                    end)
                end
            end
            return
        end

        -- Voice Filter / Mic Spoof: force SetMuted(false) dengan jitter
        if State.VoiceFilter or State.MicSpoof then
            if not VoiceChatSvc then return end
            jitterAcc = jitterAcc + dt
            if jitterAcc >= jitterInterval then
                jitterAcc = 0
                jitterInterval = 0.3 + math.random() * 0.6
                pcall(function() VoiceChatSvc:SetMuted(false) end)
            end
        else
            jitterAcc = 0
        end
    end)
end

local function stopMainLoop()
    if Conns.main then Conns.main:Disconnect(); Conns.main = nil end
end

local function refreshMainLoop()
    if State.VoiceFilter or State.MicSpoof or State.GhostMic then
        installMuteHook()
        startMainLoop()
    else
        stopMainLoop()
        removeMuteHook()
    end
end

local function enableVF()  refreshMainLoop() end
local function disableVF() refreshMainLoop() end
local function enableMS()  refreshMainLoop() end
local function disableMS() refreshMainLoop() end

-- ── ANTI-KICK ──────────────────────────────────────────────────────
local akScanAcc      = 0
local AK_SCAN_INTERVAL = 2.0

local function enableAK()
    if Conns.ak then return end
    Conns.ak = RunService.Heartbeat:Connect(function(dt)
        if not State.AntiKick then return end
        akScanAcc = akScanAcc + dt
        if akScanAcc < AK_SCAN_INTERVAL then return end
        akScanAcc = 0
        for _, obj in ipairs(game:GetDescendants()) do
            if obj:IsA("RemoteEvent") and not hooked[obj] then
                local n = obj.Name:lower()
                if n:find("kick") or n:find("mute") or n:find("voice") or n:find("ban") then
                    hooked[obj] = true
                    if hookFunc then
                        pcall(function()
                            local orig
                            orig = hookFunc(obj.OnClientEvent, function(...)
                                local a = {...}
                                if type(a[1]) == "string" then
                                    local low = a[1]:lower()
                                    if low:find("kick") or low:find("ban")
                                        or low:find("mute") or low:find("warn") then
                                        return
                                    end
                                end
                                return orig(...)
                            end)
                        end)
                    end
                end
            end
        end
    end)
end

local function disableAK()
    if Conns.ak then Conns.ak:Disconnect(); Conns.ak = nil end
end

-- ── GHOST MIC ──────────────────────────────────────────────────────
--[[
    Executor approach (no server):
    1. Mute voice chat resmi (Roblox AI nggak detect)
    2. Buat AudioDeviceInput(Player=lp) dari client
    3. Scan game untuk AudioEmitter yang udah ada di karakter player lain
       — kalau ada, wire ke sana (game udah punya voice setup)
    4. Kalau game nggak punya AudioEmitter sama sekali:
       buat AudioEmitter di root lo sendiri + Wire
       lalu scan tiap player dan inject AudioListener ke karakter mereka
       (executor bisa modify instance orang lain dari client)
    5. Heartbeat monitor: jaga semua instance tetap hidup
]]

local function gmCleanup()
    if gmInput   then pcall(function() gmInput:Destroy()   end); gmInput   = nil end
    if gmEmitter then pcall(function() gmEmitter:Destroy() end); gmEmitter = nil end
    if gmWire    then pcall(function() gmWire:Destroy()    end); gmWire    = nil end
end

local function gmInjectListenerToAll()
    -- Inject AudioListener ke semua player yang belum punya
    -- Executor bisa parent instance ke karakter player lain
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= lp and p.Character then
            local root = p.Character:FindFirstChild("HumanoidRootPart")
            if root and not root:FindFirstChildOfClass("AudioListener") then
                pcall(function()
                    local l = Instance.new("AudioListener")
                    l.Name   = "GhostListener"
                    l.Parent = root
                end)
            end
        end
    end
end

local function enableGM()
    local char = lp.Character or lp.CharacterAdded:Wait()
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return end

    -- Mute voice chat resmi
    if VoiceChatSvc then
        installMuteHook()
        pcall(function() VoiceChatSvc:SetMuted(true) end)
    end

    gmCleanup()

    -- Buat AudioDeviceInput (harus dari client)
    gmInput = Instance.new("AudioDeviceInput")
    gmInput.Name   = "GhostInput"
    gmInput.Player = lp
    gmInput.Muted  = false
    gmInput.Parent = root

    -- Cek apakah game sudah punya AudioEmitter di karakter ini
    local existingEmitter = root:FindFirstChildOfClass("AudioEmitter")
    if existingEmitter then
        -- Game udah punya pipeline, wire ke sana
        gmEmitter = existingEmitter
    else
        -- Buat sendiri
        gmEmitter = Instance.new("AudioEmitter")
        gmEmitter.Name   = "GhostEmitter"
        gmEmitter.Parent = root
    end

    -- Wire: ADI → Emitter
    local oldWire = root:FindFirstChild("GhostWire")
    if oldWire then oldWire:Destroy() end
    gmWire = Instance.new("Wire")
    gmWire.Name           = "GhostWire"
    gmWire.SourceInstance = gmInput
    gmWire.TargetInstance = gmEmitter
    gmWire.Parent         = root

    -- AudioListener di karakter lo sendiri (biar denger feedback)
    if not root:FindFirstChildOfClass("AudioListener") then
        local selfL = Instance.new("AudioListener")
        selfL.Name   = "GhostListenerSelf"
        selfL.Parent = root
    end

    -- Inject AudioListener ke semua player lain
    gmInjectListenerToAll()

    -- Monitor player baru masuk
    if Conns.gmPlayerAdded then Conns.gmPlayerAdded:Disconnect() end
    Conns.gmPlayerAdded = Players.PlayerAdded:Connect(function(p)
        task.wait(2)  -- tunggu karakter spawn
        if State.GhostMic and p.Character then
            local r = p.Character:FindFirstChild("HumanoidRootPart")
            if r and not r:FindFirstChildOfClass("AudioListener") then
                pcall(function()
                    local l = Instance.new("AudioListener")
                    l.Name = "GhostListener"; l.Parent = r
                end)
            end
        end
    end)

    -- Monitor karakter respawn
    if Conns.gmRespawn then Conns.gmRespawn:Disconnect() end
    Conns.gmRespawn = lp.CharacterAdded:Connect(function()
        if State.GhostMic then task.wait(0.5); enableGM() end
    end)

    refreshMainLoop()
end

local function disableGM()
    -- Cleanup instance yang kita buat
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    if root then
        local w = root:FindFirstChild("GhostWire")
        if w then w:Destroy() end
        local inp = root:FindFirstChild("GhostInput")
        if inp then inp:Destroy() end
        -- Jangan destroy GhostEmitter kalau bukan punya kita (existingEmitter)
        local em = root:FindFirstChild("GhostEmitter")
        if em then em:Destroy() end
        local sl = root:FindFirstChild("GhostListenerSelf")
        if sl then sl:Destroy() end
    end
    gmInput = nil; gmEmitter = nil; gmWire = nil

    if Conns.gmRespawn     then Conns.gmRespawn:Disconnect();     Conns.gmRespawn     = nil end
    if Conns.gmPlayerAdded then Conns.gmPlayerAdded:Disconnect(); Conns.gmPlayerAdded = nil end

    if VoiceChatSvc then
        pcall(function() VoiceChatSvc:SetMuted(false) end)
    end
    refreshMainLoop()
end

------------------------------------------------------------------------
-- BUILD TOGGLES
------------------------------------------------------------------------
buildToggle("🔇", "Voice Filter\nBlok auto-mute", "VoiceFilter", function(on)
    if on then enableVF() else disableVF() end
end)
buildToggle("🎤", "Mic Spoof\nForce mic ON", "MicSpoof", function(on)
    if on then enableMS() else disableMS() end
end)
buildToggle("🛡️", "Anti-Kick Voice\nFilter kick remote", "AntiKick", function(on)
    if on then enableAK() else disableAK() end
end)
buildToggle("👻", "Ghost Mic\nMic off, player denger", "GhostMic", function(on)
    if on then enableGM() else disableGM() end
end)

------------------------------------------------------------------------
-- WARNING / MODAL SUPPRESSOR
------------------------------------------------------------------------
local MODAL_PATTERNS = {
    "kehilangan akses", "ditangguhkan", "melanggar", "peraturan komunitas",
    "voice access", "suspended", "community guidelines", "you may lose",
    "violation", "inappropriate",
}

local function isModalText(s)
    if type(s) ~= "string" or #s < 5 then return false end
    local low = s:lower()
    for _, pat in ipairs(MODAL_PATTERNS) do
        if low:find(pat, 1, true) then return true end
    end
    return false
end

local function hideAncestorGui(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("ScreenGui") or cur:IsA("Frame") then
            pcall(function() cur.Enabled = false end)
            pcall(function() cur.Visible = false end)
            return
        end
        cur = cur.Parent
    end
end

local function scanAndSuppress(root)
    for _, obj in ipairs(root:GetDescendants()) do
        if (obj:IsA("TextLabel") or obj:IsA("TextButton")) and isModalText(obj.Text) then
            hideAncestorGui(obj)
        end
    end
end

pcall(function()
    local CG = game:GetService("CoreGui")
    CG.DescendantAdded:Connect(function(obj)
        if obj:IsA("TextLabel") or obj:IsA("TextButton") then
            task.delay(0.05, function()
                if obj and obj.Parent and isModalText(obj.Text) then
                    hideAncestorGui(obj)
                end
            end)
        end
    end)
end)

local warnAcc = 0
Conns.warnScan = RunService.Heartbeat:Connect(function(dt)
    warnAcc = warnAcc + dt
    if warnAcc < 0.5 then return end
    warnAcc = 0
    pcall(function() scanAndSuppress(game:GetService("CoreGui")) end)
    pcall(function() scanAndSuppress(PlayerGui) end)
end)

------------------------------------------------------------------------
-- GHOST MIC DEBUG PANEL
------------------------------------------------------------------------
local DBG_W, DBG_H = CFG.PANEL_W, 92
local DebugPanel = Instance.new("Frame")
DebugPanel.Name             = "GhostDebug"
DebugPanel.Size             = UDim2.new(0, DBG_W, 0, DBG_H)
DebugPanel.BackgroundColor3 = Color3.fromRGB(10, 7, 22)
DebugPanel.BorderSizePixel  = 0
DebugPanel.Visible          = false
DebugPanel.ZIndex           = 15
DebugPanel.Parent           = SG
Instance.new("UICorner", DebugPanel).CornerRadius = UDim.new(0, 10)
local dbs = Instance.new("UIStroke")
dbs.Color = Color3.fromRGB(80,50,160); dbs.Thickness = 1.2; dbs.Parent = DebugPanel

local DBG_HEADER = Instance.new("TextLabel")
DBG_HEADER.Size = UDim2.new(1,-12,0,20); DBG_HEADER.Position = UDim2.new(0,10,0,6)
DBG_HEADER.BackgroundTransparency = 1; DBG_HEADER.Text = "👻 Ghost Mic Debug"
DBG_HEADER.TextColor3 = Color3.fromRGB(160,130,230)
DBG_HEADER.TextSize = 10; DBG_HEADER.Font = Enum.Font.GothamBold
DBG_HEADER.TextXAlignment = Enum.TextXAlignment.Left
DBG_HEADER.ZIndex = 16; DBG_HEADER.Parent = DebugPanel

local dbgRows = {}
local DBG_LABELS = {"Roblox Mic", "AudioDeviceInput", "AudioEmitter", "Hook/Fallback"}
for i, labelTxt in ipairs(DBG_LABELS) do
    local row = Instance.new("Frame")
    row.Size = UDim2.new(1,-12,0,14); row.Position = UDim2.new(0,10,0,22+(i-1)*16)
    row.BackgroundTransparency = 1; row.ZIndex = 16; row.Parent = DebugPanel
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0,8,0,8); dot.Position = UDim2.new(0,0,0.5,-4)
    dot.BackgroundColor3 = Color3.fromRGB(80,80,80)
    dot.BorderSizePixel = 0; dot.ZIndex = 17; dot.Parent = row
    Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)
    local lbl2 = Instance.new("TextLabel")
    lbl2.Size = UDim2.new(0.55,-12,1,0); lbl2.Position = UDim2.new(0,14,0,0)
    lbl2.BackgroundTransparency = 1; lbl2.Text = labelTxt
    lbl2.TextColor3 = Color3.fromRGB(140,130,165); lbl2.TextSize = 10
    lbl2.Font = Enum.Font.Gotham; lbl2.TextXAlignment = Enum.TextXAlignment.Left
    lbl2.ZIndex = 17; lbl2.Parent = row
    local val = Instance.new("TextLabel")
    val.Size = UDim2.new(0.45,0,1,0); val.Position = UDim2.new(0.55,0,0,0)
    val.BackgroundTransparency = 1; val.Text = "—"
    val.TextColor3 = Color3.fromRGB(180,170,210); val.TextSize = 10
    val.Font = Enum.Font.GothamBold; val.TextXAlignment = Enum.TextXAlignment.Right
    val.ZIndex = 17; val.Parent = row
    dbgRows[i] = {dot=dot, val=val}
end

local function setDbgRow(i, ok, text)
    dbgRows[i].dot.BackgroundColor3 = ok and Color3.fromRGB(60,210,100) or Color3.fromRGB(210,70,70)
    dbgRows[i].val.Text = text
end

local function positionDebugPanel()
    if Panel.Visible then
        DebugPanel.Position = UDim2.new(
            Panel.Position.X.Scale, Panel.Position.X.Offset,
            Panel.Position.Y.Scale, Panel.Position.Y.Offset + CFG.PANEL_H + 6
        )
    else
        local lf = LogoFrame.Position
        DebugPanel.Position = UDim2.new(
            lf.X.Scale, lf.X.Offset + CFG.LOGO_SIZE + 10,
            lf.Y.Scale, lf.Y.Offset
        )
    end
end

local dbgAcc = 0
Conns.dbg = RunService.Heartbeat:Connect(function(dt)
    if not State.GhostMic then
        if DebugPanel.Visible then DebugPanel.Visible = false end
        return
    end
    DebugPanel.Visible = true
    positionDebugPanel()
    dbgAcc = dbgAcc + dt
    if dbgAcc < 0.4 then return end
    dbgAcc = 0

    -- Row 1: Roblox voice muted?
    local robloxMuted = false
    if VoiceChatSvc then
        pcall(function() robloxMuted = VoiceChatSvc:IsLocalMuted() end)
    end
    setDbgRow(1, robloxMuted, robloxMuted and "MUTED ✓" or "AKTIF ⚠")

    -- Row 2: ADI status
    local char = lp.Character
    local root = char and char:FindFirstChild("HumanoidRootPart")
    local inp = root and root:FindFirstChild("GhostInput")
    local wire = root and root:FindFirstChild("GhostWire")
    local inputOk = inp and not inp.Muted or false
    local wireOk  = wire and wire.SourceInstance and wire.TargetInstance
    local inputTxt = inp and (inputOk and (wireOk and "capturing+wire ✓" or "capturing,no wire ⚠") or "Muted ✗") or "nggak ada"
    setDbgRow(2, inputOk and wireOk, inputTxt)

    -- Row 3: Emitter
    local em = root and (root:FindFirstChild("GhostEmitter") or root:FindFirstChildOfClass("AudioEmitter"))
    setDbgRow(3, em ~= nil, em and "ada ✓" or "nggak ada ✗")

    -- Row 4: Hook mode
    local hookOk = origMute ~= nil
    local hookTxt = hookOk and "hook ✓" or (hookFunc and "hook fail ✗" or "fallback ✓")
    setDbgRow(4, hookOk or not hookFunc, hookTxt)
end)

------------------------------------------------------------------------
-- TAP / DRAG HANDLER
------------------------------------------------------------------------
local Drag = {holding=false, isDrag=false, startMouse=Vector2.new(), startPos=UDim2.new()}

local function togglePanel()
    if Drag.isDrag then Drag.isDrag = false; return end
    State.PanelOpen = not State.PanelOpen
    if State.PanelOpen then positionPanel(); Panel.Visible = true
    else Panel.Visible = false end
end

LogoBtn.MouseButton1Click:Connect(togglePanel)
LogoBtn.TouchTap:Connect(togglePanel)

LogoBtn.InputBegan:Connect(function(inp)
    local t = inp.UserInputType
    if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
    Drag.holding = true; Drag.isDrag = false
    Drag.startMouse = Vector2.new(inp.Position.X, inp.Position.Y)
    Drag.startPos   = LogoFrame.Position
end)

UIS.InputChanged:Connect(function(inp)
    if not Drag.holding then return end
    local t = inp.UserInputType
    local cur
    if t == Enum.UserInputType.MouseMovement then cur = UIS:GetMouseLocation()
    elseif t == Enum.UserInputType.Touch then cur = Vector2.new(inp.Position.X, inp.Position.Y)
    else return end
    local delta = cur - Drag.startMouse
    if delta.Magnitude < CFG.DRAG_THRESHOLD then return end
    Drag.isDrag = true
    LogoFrame.Position = UDim2.new(
        Drag.startPos.X.Scale, Drag.startPos.X.Offset + delta.X,
        Drag.startPos.Y.Scale, Drag.startPos.Y.Offset + delta.Y
    )
    if State.PanelOpen then positionPanel() end
end)

UIS.InputEnded:Connect(function(inp)
    local t = inp.UserInputType
    if t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch then
        Drag.holding = false
    end
end)

-- Close panel klik luar
local rowFrames = {}
for _, c in ipairs(SF:GetChildren()) do if c:IsA("Frame") then table.insert(rowFrames, c) end end
SF.ChildAdded:Connect(function(c) if c:IsA("Frame") then table.insert(rowFrames, c) end end)

UIS.InputBegan:Connect(function(inp)
    local t = inp.UserInputType
    if t ~= Enum.UserInputType.MouseButton1 and t ~= Enum.UserInputType.Touch then return end
    if not State.PanelOpen or Drag.holding or inp.Processed then return end
    local mp = (t == Enum.UserInputType.Touch)
        and Vector2.new(inp.Position.X, inp.Position.Y)
        or  UIS:GetMouseLocation()
    local function inBox(f)
        local ap, as = f.AbsolutePosition, f.AbsoluteSize
        return mp.X>=ap.X and mp.X<=ap.X+as.X and mp.Y>=ap.Y and mp.Y<=ap.Y+as.Y
    end
    if inBox(Panel) or inBox(LogoFrame) then return end
    for _, row in ipairs(rowFrames) do if inBox(row) then return end end
    State.PanelOpen = false; Panel.Visible = false
end)

------------------------------------------------------------------------
-- TEARDOWN (kalau script di-unload / GUI dihapus)
------------------------------------------------------------------------
SG.AncestryChanged:Connect(function()
    for _, c in pairs(Conns) do
        if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
    end
    if getgenv then getgenv().XXIV_VG_LOADED = nil end
end)

------------------------------------------------------------------------
-- INIT
------------------------------------------------------------------------
updateStatus()
-- print("[XXIV VoiceGuard] Loaded — hookFunc=" .. tostring(hookFunc ~= nil))
