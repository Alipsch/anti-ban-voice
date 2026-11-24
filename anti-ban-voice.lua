-- Language: Luau (Roblox Client)
-- File: LocalScript → StarterPlayerScripts / executor inject
-- Runtime: Synapse X / KRNL / Fluxus
-- v4: hapus overlay system, pakai TextButton langsung di row

--[[
    XXIV Voice Guard v3.5 — GuiInset Fix
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    ROOT CAUSE FIX: overlay geser 58px karena IgnoreGuiInset=true
    bikin SG mulai Y=0, tapi AbsolutePosition row dihitung dari Y=58.
    Fix: kurangi GuiService:GetGuiInset().Y dari overlay Y position.
    Semua toggle dijamin klik tepat sasaran.
]]

------------------------------------------------------------------------
-- CONFIG
------------------------------------------------------------------------
local CFG = {
	LOGO_IMAGE     = "",
	LOGO_SIZE      = 48,
	PANEL_W        = 215,
	PANEL_H        = 272,  -- tambah 47px untuk row ke-4
	DRAG_THRESHOLD = 14,
}

------------------------------------------------------------------------
-- SERVICES
------------------------------------------------------------------------
local Players      = game:GetService("Players")
local RunService   = game:GetService("RunService")
local UIS          = game:GetService("UserInputService")
local GuiService   = game:GetService("GuiService")
local VoiceChatSvc = game:GetService("VoiceChatService")
local lp           = Players.LocalPlayer
local PlayerGui    = lp:WaitForChild("PlayerGui")

------------------------------------------------------------------------
-- STATE
------------------------------------------------------------------------
local State = {
	PanelOpen   = false,
	VoiceFilter = false,
	MicSpoof    = false,
	AntiKick    = false,
	GhostMic    = false,  -- mic keliatan off, player lain denger via AudioEmitter
}
local Conns    = {}
local hooked   = {}
local hookFunc = (typeof(hookfunction) == "function") and hookfunction or nil
local origMute = nil
local Drag     = { holding=false, isDrag=false, startMouse=Vector2.new(), startPos=UDim2.new() }

------------------------------------------------------------------------
-- GUI ROOT
------------------------------------------------------------------------
local SG = Instance.new("ScreenGui")
SG.Name           = "XXIVVoiceGuard"
SG.ResetOnSpawn   = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.IgnoreGuiInset = true
SG.Parent         = PlayerGui

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
logoStroke.Color = Color3.fromRGB(100, 65, 210); logoStroke.Thickness = 1.8
logoStroke.Parent = LogoFrame

local LogoDisplay
if CFG.LOGO_IMAGE ~= "" then
	LogoDisplay = Instance.new("ImageLabel")
	LogoDisplay.Image = CFG.LOGO_IMAGE
	LogoDisplay.ScaleType = Enum.ScaleType.Fit
	LogoDisplay.BackgroundTransparency = 1
else
	LogoDisplay = Instance.new("TextLabel")
	LogoDisplay.Text = "VG"
	LogoDisplay.TextColor3 = Color3.fromRGB(200, 175, 255)
	LogoDisplay.TextSize = 14; LogoDisplay.Font = Enum.Font.GothamBold
	LogoDisplay.TextXAlignment = Enum.TextXAlignment.Center
	LogoDisplay.TextYAlignment = Enum.TextYAlignment.Center
	LogoDisplay.BackgroundTransparency = 1
end
LogoDisplay.Size = UDim2.new(1,-8,1,-8); LogoDisplay.Position = UDim2.new(0,4,0,4)
LogoDisplay.ZIndex = 21; LogoDisplay.Parent = LogoFrame

local LogoDot = Instance.new("Frame")
LogoDot.Size = UDim2.new(0,10,0,10); LogoDot.Position = UDim2.new(1,-11,0,1)
LogoDot.BackgroundColor3 = Color3.fromRGB(80,80,80)
LogoDot.BorderSizePixel = 0; LogoDot.ZIndex = 22; LogoDot.Parent = LogoFrame
Instance.new("UICorner", LogoDot).CornerRadius = UDim.new(1, 0)
local ldS = Instance.new("UIStroke")
ldS.Color = Color3.fromRGB(13,9,26); ldS.Thickness = 1.5; ldS.Parent = LogoDot

local LogoBtn = Instance.new("TextButton")
LogoBtn.Size = UDim2.new(1,0,1,0); LogoBtn.BackgroundTransparency = 1
LogoBtn.Text = ""; LogoBtn.ZIndex = 23; LogoBtn.AutoButtonColor = false
LogoBtn.Parent = LogoFrame

------------------------------------------------------------------------
-- PANEL
------------------------------------------------------------------------
local Panel = Instance.new("Frame")
Panel.Name = "Panel"; Panel.Size = UDim2.new(0,CFG.PANEL_W,0,CFG.PANEL_H)
Panel.Position = UDim2.new(0,76,0.5,-CFG.PANEL_H/2)
Panel.BackgroundColor3 = Color3.fromRGB(13,9,26)
Panel.BorderSizePixel = 0; Panel.Visible = false; Panel.ZIndex = 15; Panel.Parent = SG
Instance.new("UICorner", Panel).CornerRadius = UDim.new(0, 14)
local ps = Instance.new("UIStroke")
ps.Color = Color3.fromRGB(85,55,175); ps.Thickness = 1.4; ps.Parent = Panel
local pg = Instance.new("UIGradient")
pg.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(22,14,46)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(11,7,22)),
}
pg.Rotation = 120; pg.Parent = Panel

local PHeader = Instance.new("Frame")
PHeader.Size = UDim2.new(1,0,0,38); PHeader.BackgroundColor3 = Color3.fromRGB(20,12,44)
PHeader.BorderSizePixel = 0; PHeader.ZIndex = 16; PHeader.Parent = Panel
Instance.new("UICorner", PHeader).CornerRadius = UDim.new(0, 14)
local HLabel = Instance.new("TextLabel")
HLabel.Text = "🎙️  Voice Guard"; HLabel.Size = UDim2.new(1,-12,1,0)
HLabel.Position = UDim2.new(0,12,0,0); HLabel.BackgroundTransparency = 1
HLabel.TextColor3 = Color3.fromRGB(185,160,255); HLabel.TextSize = 13
HLabel.Font = Enum.Font.GothamBold; HLabel.TextXAlignment = Enum.TextXAlignment.Left
HLabel.ZIndex = 17; HLabel.Parent = PHeader

local SBar = Instance.new("Frame")
SBar.Size = UDim2.new(1,-16,0,24); SBar.Position = UDim2.new(0,8,0,42)
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

-- Frame biasa, bukan ScrollingFrame
-- 3 toggle = 3*44 + 2*6 gap + 6 top + 14 bot = 144px — nggak perlu scroll
-- ScrollingFrame intercept klik di row edge sebagai scroll gesture
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
	local anyOn = State.VoiceFilter or State.MicSpoof or State.AntiKick
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

	-- TextButton langsung di row, full size — no proxy, no offset issue
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1,0,1,0)
	btn.BackgroundTransparency = 1
	btn.Text = ""; btn.ZIndex = 25; btn.AutoButtonColor = false
	btn.Parent = row

	local function refresh()
		local on = State[stateKey]
		pill.BackgroundColor3 = on and Color3.fromRGB(75,45,165) or Color3.fromRGB(40,28,68)
		knob.BackgroundColor3 = on and Color3.fromRGB(205,185,255) or Color3.fromRGB(95,80,145)
		knob.Position = on and UDim2.new(0,23,0.5,-7) or UDim2.new(0,3,0.5,-7)
		lbl.TextColor3 = on and Color3.fromRGB(220,205,255) or Color3.fromRGB(195,180,225)
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
-- Hook SetMuted sekali aja — shared antara VF dan MS
local function installMuteHook()
	if hookFunc and not origMute then
		pcall(function()
			origMute = hookFunc(VoiceChatSvc.SetMuted,
				function(self, muted, ...)
					if muted == true and (State.VoiceFilter or State.MicSpoof or State.GhostMic) then
						return
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

-- Single heartbeat — gabungan VF + MS, jitter evasion biar pola aktivasi nggak detectable
local jitterAcc = 0
local jitterInterval = 0.3

local function startMainLoop()
	if Conns.main then return end
	Conns.main = RunService.Heartbeat:Connect(function(dt)
		-- Ghost Mic ON: voice chat resmi harus stay muted, jangan di-force unmute
		-- kalau hookfunction nil (executor nggak support), spam SetMuted tiap frame sebagai fallback
		if State.GhostMic then
			pcall(function() VoiceChatSvc:SetMuted(true) end)
			-- fallback tanpa hook: juga coba via LocalPlayer MicEnabled property
			pcall(function()
				if lp.GameSettings then
					lp.GameSettings.MicrophoneEnabled = false
				end
			end)
			return
		end
		if State.VoiceFilter or State.MicSpoof then
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
	-- Ghost Mic butuh loop juga untuk keep voice chat stay muted
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

-- AntiKick: scan tiap 2s bukan tiap frame — hemat CPU, tambah filter "warn"
local akScanAcc = 0
local AK_SCAN_INTERVAL = 2.0

local function enableAK()
	if not Conns.ak then
		Conns.ak = RunService.Heartbeat:Connect(function(dt)
			if not State.AntiKick then return end
			akScanAcc = akScanAcc + dt
			if akScanAcc < AK_SCAN_INTERVAL then return end
			akScanAcc = 0
			for _, obj in ipairs(game:GetDescendants()) do
				if obj:IsA("RemoteEvent") and not hooked[obj] then
					local n = obj.Name:lower()
					if n:find("kick") or n:find("mute")
						or n:find("voice") or n:find("ban") then
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
end
local function disableAK()
	if Conns.ak then Conns.ak:Disconnect(); Conns.ak = nil end
end

------------------------------------------------------------------------
-- GHOST MIC
-- Cara kerja:
--   1. Roblox voice chat di-mute (SetMuted true) — AI detection nggak proses
--   2. AudioDeviceInput → AudioEmitter di karakter lo
--   3. Tiap player lain punya AudioListener di karakter mereka (via server script)
--   4. Roblox 3D audio system forward suara lo ke player sekitar secara natural
-- Roblox voice moderation nggak menyentuh AudioEmitter/AudioListener pipeline.
------------------------------------------------------------------------
local gmInput    = nil  -- AudioDeviceInput
local gmEmitter  = nil  -- AudioEmitter di karakter lo
local gmAnalyser = nil  -- AudioAnalyser untuk cek mic aktif (opsional)
local SoundSvc   = game:GetService("SoundService")
local RS         = game:GetService("ReplicatedStorage")

-- RemoteEvent untuk minta server setup AudioListener di tiap player
local gmRemote
local function getOrCreateRemote()
	if gmRemote then return gmRemote end
	local existing = RS:FindFirstChild("GhostMicSetup")
	if existing then gmRemote = existing; return gmRemote end
	-- executor bisa create di ReplicatedStorage dari client
	local re = Instance.new("RemoteEvent")
	re.Name = "GhostMicSetup"
	re.Parent = RS
	gmRemote = re
	return gmRemote
end

local function enableGM()
	local char = lp.Character or lp.CharacterAdded:Wait()
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	-- mute Roblox voice chat resmi — AI nggak denger
	-- install hook dulu biar Roblox internal nggak bisa unmute balik
	installMuteHook()
	pcall(function() VoiceChatSvc:SetMuted(true) end)

	-- bersihkan kalau udah ada
	if gmInput then pcall(function() gmInput:Destroy() end); gmInput = nil end
	if gmEmitter then pcall(function() gmEmitter:Destroy() end); gmEmitter = nil end

	-- AudioDeviceInput: tangkap mic hardware lo
	gmInput = Instance.new("AudioDeviceInput")
	gmInput.Player = lp
	gmInput.Muted  = false
	gmInput.Parent = root

	-- AudioEmitter: broadcast ke dunia 3D Roblox
	gmEmitter = Instance.new("AudioEmitter")
	gmEmitter.Parent = root

	-- Wire: AudioDeviceInput → AudioEmitter
	local wire = Instance.new("Wire")
	wire.SourceInstance = gmInput
	wire.TargetInstance = gmEmitter
	wire.Parent         = root

	-- Pasang AudioListener di karakter lo sendiri juga
	-- (biar lo bisa denger feedback dan emitter propagate ke diri sendiri)
	if not root:FindFirstChildOfClass("AudioListener") then
		local selfListener = Instance.new("AudioListener")
		selfListener.Parent = root
	end

	-- Minta server pasang AudioListener di semua player
	pcall(function() getOrCreateRemote():FireServer("setup") end)

	-- Reconnect kalau karakter respawn
	if Conns.gmRespawn then Conns.gmRespawn:Disconnect() end
	Conns.gmRespawn = lp.CharacterAdded:Connect(function(newChar)
		if State.GhostMic then
			task.wait(0.5)
			enableGM()
		end
	end)
end

local function disableGM()
	if gmInput   then pcall(function() gmInput:Destroy()   end); gmInput   = nil end
	if gmEmitter then pcall(function() gmEmitter:Destroy() end); gmEmitter = nil end
	if Conns.gmRespawn then Conns.gmRespawn:Disconnect(); Conns.gmRespawn = nil end
	-- unmute Roblox voice chat balik
	pcall(function() VoiceChatSvc:SetMuted(false) end)
end
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
-- WARNING UI SUPPRESSOR
-- Roblox voice warning muncul sebagai TextLabel/Frame di CoreGui atau
-- PlayerGui dengan nama/text yang mengandung kata warning/violation/moderation.
-- Kita scan tiap 2s dan hide semua yang match.
------------------------------------------------------------------------
------------------------------------------------------------------------
-- WARNING / MODAL SUPPRESSOR v2
-- Target: popup modal CoreGui Roblox voice warning
-- "Kamu dapat kehilangan akses ke suara" dst.
-- Strategy: scan TEKS KONTEN di semua TextLabel/TextButton,
-- bukan nama instance — karena Roblox pakai nama internal kayak
-- "VoiceChatPrompt", "SafetyBubble", bukan nama yang ngandung "warn".
------------------------------------------------------------------------
local MODAL_TEXT_PATTERNS = {
	-- Bahasa Indonesia (Roblox lokalisasi)
	"kehilangan akses", "ditangguhkan", "melanggar", "peraturan komunitas",
	"fitur suara", "suara",
	-- English fallback
	"voice access", "suspended", "community guidelines", "voice feature",
	"you may lose", "violation", "inappropriate", "safety",
}

local function isModalText(s)
	if type(s) ~= "string" or #s < 5 then return false end
	local low = s:lower()
	for _, pat in ipairs(MODAL_TEXT_PATTERNS) do
		if low:find(pat, 1, true) then return true end
	end
	return false
end

-- Sembunyikan seluruh ScreenGui/Frame ancestor kalau ada descendant yang match
local function hideAncestorGui(obj)
	local cur = obj
	while cur and cur ~= game:GetService("CoreGui") do
		if cur:IsA("ScreenGui") or (cur:IsA("Frame") and cur.Parent == game:GetService("CoreGui")) then
			cur.Enabled = false
			pcall(function() cur.Visible = false end)
			return
		end
		cur = cur.Parent
	end
	-- fallback: hide obj sendiri
	pcall(function() obj.Visible = false end)
end

local function scanAndSuppress(root)
	for _, obj in ipairs(root:GetDescendants()) do
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			if isModalText(obj.Text) then
				hideAncestorGui(obj)
			end
		end
	end
end

-- Hook DescendantAdded di CoreGui — intercept modal saat muncul
pcall(function()
	local CoreGui = game:GetService("CoreGui")
	CoreGui.DescendantAdded:Connect(function(obj)
		if obj:IsA("TextLabel") or obj:IsA("TextButton") then
			-- cek langsung
			if isModalText(obj.Text) then
				hideAncestorGui(obj)
				return
			end
			-- teks bisa belum di-set saat DescendantAdded, tunggu sebentar
			task.delay(0.05, function()
				if obj and obj.Parent and isModalText(obj.Text) then
					hideAncestorGui(obj)
				end
			end)
		end
	end)
end)

-- Scan berkala tiap 0.5s sebagai safety net
local warnScanAcc = 0
local WARN_SCAN_INTERVAL = 0.5
Conns.warnScan = RunService.Heartbeat:Connect(function(dt)
	warnScanAcc = warnScanAcc + dt
	if warnScanAcc < WARN_SCAN_INTERVAL then return end
	warnScanAcc = 0
	pcall(function() scanAndSuppress(game:GetService("CoreGui")) end)
	pcall(function() scanAndSuppress(PlayerGui) end)
end)

------------------------------------------------------------------------
-- TAP HANDLER
------------------------------------------------------------------------
local function togglePanel()
	if Drag.isDrag then Drag.isDrag = false; return end
	State.PanelOpen = not State.PanelOpen
	if State.PanelOpen then
		positionPanel()
		Panel.Visible = true
	else
		Panel.Visible = false
	end
end

LogoBtn.MouseButton1Click:Connect(togglePanel)
LogoBtn.TouchTap:Connect(togglePanel)

------------------------------------------------------------------------
-- DRAG HANDLER
------------------------------------------------------------------------
LogoBtn.InputBegan:Connect(function(inp)
	local t = inp.UserInputType
	if t ~= Enum.UserInputType.MouseButton1
		and t ~= Enum.UserInputType.Touch then return end
	Drag.holding = true; Drag.isDrag = false
	Drag.startMouse = Vector2.new(inp.Position.X, inp.Position.Y)
	Drag.startPos   = LogoFrame.Position
end)

UIS.InputChanged:Connect(function(inp)
	if not Drag.holding then return end
	local t = inp.UserInputType
	local cur
	if t == Enum.UserInputType.MouseMovement then
		cur = UIS:GetMouseLocation()
	elseif t == Enum.UserInputType.Touch then
		cur = Vector2.new(inp.Position.X, inp.Position.Y)
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
	if t == Enum.UserInputType.MouseButton1
		or t == Enum.UserInputType.Touch then
		Drag.holding = false
	end
end)

------------------------------------------------------------------------
-- TUTUP PANEL KLIK LUAR — v5: cek per-row bounds bukan container
------------------------------------------------------------------------
-- Kumpulkan semua row frame dari SF supaya inPanel() bisa cek tiap row
-- langsung. Fix root cause: row ke-3 overflow keluar Panel.AbsoluteSize.
local rowFrames = {}
for _, child in ipairs(SF:GetChildren()) do
	if child:IsA("Frame") then
		table.insert(rowFrames, child)
	end
end
SF.ChildAdded:Connect(function(child)
	if child:IsA("Frame") then
		table.insert(rowFrames, child)
	end
end)

UIS.InputBegan:Connect(function(inp)
	local t = inp.UserInputType
	if t ~= Enum.UserInputType.MouseButton1
		and t ~= Enum.UserInputType.Touch then return end
	if not State.PanelOpen then return end
	if Drag.holding then return end
	-- v6 fix: kalau GUI udah proses input ini (tombol toggle diklik),
	-- jangan close panel. inp.Processed = true berarti ada GuiButton
	-- yang udah consume event ini — itu pasti toggle row, bukan click luar.
	if inp.Processed then return end
	local mp = (t == Enum.UserInputType.Touch)
		and Vector2.new(inp.Position.X, inp.Position.Y)
		or  UIS:GetMouseLocation()
	local function inBox(f)
		local ap, as = f.AbsolutePosition, f.AbsoluteSize
		return mp.X >= ap.X and mp.X <= ap.X + as.X
			and mp.Y >= ap.Y and mp.Y <= ap.Y + as.Y
	end
	if inBox(Panel) or inBox(LogoFrame) then return end
	-- fallback: cek tiap row (cover kasus row overflow bounds Panel)
	for _, row in ipairs(rowFrames) do
		if inBox(row) then return end
	end
	State.PanelOpen = false
	Panel.Visible   = false
end)

------------------------------------------------------------------------
-- GHOST MIC DEBUG PANEL
-- Tampil di bawah panel utama, hanya kalau GhostMic ON
-- Baris: [👻 Ghost Mic] [🔇 Roblox Mic] [🎤 AudioInput] [📡 Emitter]
------------------------------------------------------------------------
local DBG_W, DBG_H = CFG.PANEL_W, 92
local DebugPanel = Instance.new("Frame")
DebugPanel.Name        = "GhostDebug"
DebugPanel.Size        = UDim2.new(0, DBG_W, 0, DBG_H)
DebugPanel.BackgroundColor3 = Color3.fromRGB(10, 7, 22)
DebugPanel.BorderSizePixel  = 0
DebugPanel.Visible     = false
DebugPanel.ZIndex      = 15
DebugPanel.Parent      = SG
Instance.new("UICorner", DebugPanel).CornerRadius = UDim.new(0, 10)
local dbs = Instance.new("UIStroke")
dbs.Color = Color3.fromRGB(80, 50, 160); dbs.Thickness = 1.2; dbs.Parent = DebugPanel

local DBG_HEADER = Instance.new("TextLabel")
DBG_HEADER.Size = UDim2.new(1, -12, 0, 20)
DBG_HEADER.Position = UDim2.new(0, 10, 0, 6)
DBG_HEADER.BackgroundTransparency = 1
DBG_HEADER.Text = "👻 Ghost Mic Debug"
DBG_HEADER.TextColor3 = Color3.fromRGB(160, 130, 230)
DBG_HEADER.TextSize = 10; DBG_HEADER.Font = Enum.Font.GothamBold
DBG_HEADER.TextXAlignment = Enum.TextXAlignment.Left
DBG_HEADER.ZIndex = 16; DBG_HEADER.Parent = DebugPanel

-- 4 baris status
local dbgRows = {}
local DBG_LABELS = {
	"Roblox Mic",
	"AudioDeviceInput",
	"AudioEmitter",
	"Hook aktif",
}
for i, labelTxt in ipairs(DBG_LABELS) do
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -12, 0, 14)
	row.Position = UDim2.new(0, 10, 0, 22 + (i-1)*16)
	row.BackgroundTransparency = 1; row.ZIndex = 16; row.Parent = DebugPanel

	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 8, 0, 8); dot.Position = UDim2.new(0, 0, 0.5, -4)
	dot.BackgroundColor3 = Color3.fromRGB(80, 80, 80)
	dot.BorderSizePixel = 0; dot.ZIndex = 17; dot.Parent = row
	Instance.new("UICorner", dot).CornerRadius = UDim.new(1, 0)

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.55, -12, 1, 0); lbl.Position = UDim2.new(0, 14, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelTxt
	lbl.TextColor3 = Color3.fromRGB(140, 130, 165); lbl.TextSize = 10
	lbl.Font = Enum.Font.Gotham
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 17; lbl.Parent = row

	local val = Instance.new("TextLabel")
	val.Size = UDim2.new(0.45, 0, 1, 0); val.Position = UDim2.new(0.55, 0, 0, 0)
	val.BackgroundTransparency = 1
	val.Text = "—"
	val.TextColor3 = Color3.fromRGB(180, 170, 210); val.TextSize = 10
	val.Font = Enum.Font.GothamBold
	val.TextXAlignment = Enum.TextXAlignment.Right
	val.ZIndex = 17; val.Parent = row

	dbgRows[i] = { dot = dot, val = val }
end

local function setDbgRow(i, ok, text)
	dbgRows[i].dot.BackgroundColor3 = ok
		and Color3.fromRGB(60, 210, 100)
		or  Color3.fromRGB(210, 70, 70)
	dbgRows[i].val.Text = text
end

local function positionDebugPanel()
	local pp = DebugPanel
	if not Panel.Visible then
		-- kalau panel utama tutup, letakkan langsung di bawah logo
		local lf = LogoFrame.Position
		pp.Position = UDim2.new(
			lf.X.Scale, lf.X.Offset + CFG.LOGO_SIZE + 10,
			lf.Y.Scale, lf.Y.Offset
		)
	else
		-- di bawah panel utama, +6px gap
		pp.Position = UDim2.new(
			Panel.Position.X.Scale, Panel.Position.X.Offset,
			Panel.Position.Y.Scale, Panel.Position.Y.Offset + CFG.PANEL_H + 6
		)
	end
end

local dbgAcc = 0
Conns.dbg = RunService.Heartbeat:Connect(function(dt)
	if not State.GhostMic then
		if DebugPanel.Visible then DebugPanel.Visible = false end
		return
	end
	if not DebugPanel.Visible then
		DebugPanel.Visible = true
	end
	positionDebugPanel()

	dbgAcc = dbgAcc + dt
	if dbgAcc < 0.4 then return end
	dbgAcc = 0

	-- Row 1: Roblox Mic muted?
	local robloxMuted = false
	pcall(function() robloxMuted = VoiceChatSvc:IsLocalMuted() end)
	-- IsLocalMuted belum ada di semua executor — fallback: cek property
	if not robloxMuted then
		pcall(function()
			local lpm = VoiceChatSvc:GetMuteState(Players.LocalPlayer)
			robloxMuted = (lpm == Enum.VoiceChatState.Muted
				or lpm == Enum.VoiceChatState.Hidden)
		end)
	end
	setDbgRow(1, robloxMuted, robloxMuted and "MUTED ✓" or "AKTIF ⚠")

	-- Row 2: AudioDeviceInput ada + not muted
	local inputOk = false
	local inputTxt = "nggak ada"
	if gmInput and gmInput.Parent then
		inputOk = not gmInput.Muted
		inputTxt = inputOk and "capturing ✓" or "Muted ✗"
	end
	setDbgRow(2, inputOk, inputTxt)

	-- Row 3: AudioEmitter ada
	local emitterOk = gmEmitter ~= nil and gmEmitter.Parent ~= nil
	setDbgRow(3, emitterOk, emitterOk and "ada ✓" or "nggak ada ✗")

	-- Row 4: hook SetMuted terpasang
	local hookOk = origMute ~= nil
	setDbgRow(4, hookOk, hookOk and "terpasang ✓" or "nggak ada ✗")
end)

------------------------------------------------------------------------
-- TEARDOWN
------------------------------------------------------------------------
SG.AncestryChanged:Connect(function()
	for _, c in pairs(Conns) do
		if typeof(c) == "RBXScriptConnection" then c:Disconnect() end
	end
end)

updateStatus()
