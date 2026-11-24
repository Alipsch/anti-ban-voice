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
	LOGO_IMAGE     = "rbxassetid://71119773742781",   -- FILL: "rbxassetid://ID_KAMU"
	LOGO_SIZE      = 48,
	PANEL_W        = 215,
	PANEL_H        = 225,
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
local function enableVF()
	if hookFunc and not origMute then
		pcall(function()
			origMute = hookFunc(VoiceChatSvc.SetMuted,
				function(self, muted, ...)
					if muted == true then return end
					return origMute(self, muted, ...)
				end)
		end)
	end
	if not Conns.vf then
		Conns.vf = RunService.Heartbeat:Connect(function()
			if State.VoiceFilter then
				pcall(function() VoiceChatSvc:SetMuted(false) end)
			end
		end)
	end
end
local function disableVF()
	if Conns.vf then Conns.vf:Disconnect(); Conns.vf = nil end
	if origMute and hookFunc then
		pcall(function() hookFunc(VoiceChatSvc.SetMuted, origMute) end)
		origMute = nil
	end
end

local function enableMS()
	if not Conns.ms then
		Conns.ms = RunService.Heartbeat:Connect(function()
			if State.MicSpoof then
				pcall(function()
					if VoiceChatSvc.IsEnabled then VoiceChatSvc:SetMuted(false) end
				end)
			end
		end)
	end
end
local function disableMS()
	if Conns.ms then Conns.ms:Disconnect(); Conns.ms = nil end
end

local function enableAK()
	if not Conns.ak then
		Conns.ak = RunService.Heartbeat:Connect(function()
			if not State.AntiKick then return end
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
											or low:find("mute") then return end
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
-- TUTUP PANEL KLIK LUAR
------------------------------------------------------------------------
UIS.InputBegan:Connect(function(inp)
	local t = inp.UserInputType
	if t ~= Enum.UserInputType.MouseButton1
		and t ~= Enum.UserInputType.Touch then return end
	if not State.PanelOpen then return end
	if Drag.holding then return end
	local mp = (t == Enum.UserInputType.Touch)
		and Vector2.new(inp.Position.X, inp.Position.Y)
		or  UIS:GetMouseLocation()
	local function inBox(f)
		local ap, as = f.AbsolutePosition, f.AbsoluteSize
		return mp.X >= ap.X and mp.X <= ap.X + as.X
			and mp.Y >= ap.Y and mp.Y <= ap.Y + as.Y
	end
	-- cek Panel DAN ScrollingFrame (SF bisa extend beyond Panel.AbsoluteSize
	-- karena AutomaticCanvasSize, row #3 bisa keitung di luar Panel bounds)
	local function inPanel()
		if inBox(Panel) then return true end
		-- fallback: cek SF absolute bounds langsung
		local ap, as = SF.AbsolutePosition, SF.AbsoluteSize
		return mp.X >= ap.X and mp.X <= ap.X + as.X
			and mp.Y >= ap.Y and mp.Y <= ap.Y + as.Y
	end
	task.defer(function()
		if not inPanel() and not inBox(LogoFrame) then
			State.PanelOpen = false
			Panel.Visible   = false
		end
	end)
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
