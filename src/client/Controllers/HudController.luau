--!strict
-- In-round HUD. Draws only what the server sends (RoundStateChanged); sends nothing itself.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local AlphaClasses = require(Shared.Config.AlphaClasses)
local RoleGuide = require(Shared.Config.RoleGuide)
local Theme = require(script.Parent.Theme)
local Aim = require(script.Parent.Aim)

local C = Theme.colors
local player = Players.LocalPlayer

local HudController = {}

local LIST_WIDTH = 165 -- compact player list (was 250)
local ROW_HEIGHT = 15

local view: any = nil
local viewStamp = 0
local ammo = { mag = 0, reserve = 0 }

local gui: ScreenGui
local ui: { [string]: any } = {}

local function me(): any
	return view and view.players[tostring(player.UserId)]
end

HudController.myRole = function(): string?
	local p = me()
	return p and p.role
end

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "HUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")

	-- role tint at the screen edges
	local vignette = Instance.new("Frame")
	vignette.Name = "Vignette"
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundTransparency = 1
	vignette.Parent = gui
	local edge = Instance.new("UIStroke")
	edge.Thickness = 60
	edge.Transparency = 1
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = vignette
	ui.edge = edge

	-- top centre: the clock in a glass pill, and one quiet line under it
	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 12)
	top.Size = UDim2.fromOffset(520, 80)
	top.Parent = gui
	ui.top = top
	ui.timer = Theme.chip(top, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0),
		Size = UDim2.fromOffset(0, 44),
		TextSize = 28,
		TextStrokeTransparency = 0.7,
		Text = "",
	})
	ui.sub = Theme.label(top, {
		Position = UDim2.fromOffset(0, 50),
		Size = UDim2.new(1, 0, 0, 18),
		TextScaled = false,
		TextSize = 13,
		TextColor3 = C.lavender,
		Text = "",
	})

	-- top right: player list
	local list = Theme.panel(gui, {
		Name = "PlayerList",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 46),
		Size = UDim2.fromOffset(LIST_WIDTH, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = not UserInputService.TouchEnabled, -- phones start with it closed
	})
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 1)
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 3)
	pad.PaddingBottom = UDim.new(0, 3)
	pad.PaddingLeft = UDim.new(0, 6)
	pad.PaddingRight = UDim.new(0, 6)
	pad.Parent = list
	ui.list = list

	-- small toggle button (and Tab on a keyboard) to show / hide the list
	local toggle = Theme.button(gui, {
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -16, 0, 12),
		Size = UDim2.fromOffset(78, 26),
		Text = "PLAYERS",
	})
	toggle.Activated:Connect(function()
		list.Visible = not list.Visible
	end)

	-- bottom left: a small, slim health bar with a caption above it
	local health = Instance.new("Frame")
	health.Name = "Health"
	health.AnchorPoint = Vector2.new(0, 1)
	health.Position = UDim2.new(0, 16, 1, -16)
	health.Size = UDim2.fromOffset(150, 26)
	health.BackgroundTransparency = 1
	health.Visible = false -- shown only in a round
	health.Parent = gui
	ui.healthBack = health
	ui.healthText = Theme.label(health, {
		Size = UDim2.new(1, 0, 0, 14),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 12,
		TextStrokeTransparency = 0.5,
		Text = "",
	})
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0, 1)
	track.Position = UDim2.fromScale(0, 1)
	track.Size = UDim2.new(1, 0, 0, 7)
	track.BackgroundColor3 = C.plum
	track.BackgroundTransparency = 0.35
	track.BorderSizePixel = 0
	track.ClipsDescendants = true
	track.Parent = health
	local trackCorner = Instance.new("UICorner")
	trackCorner.CornerRadius = UDim.new(1, 0)
	trackCorner.Parent = track
	local trackStroke = Instance.new("UIStroke")
	trackStroke.Color = C.ink
	trackStroke.Thickness = 1
	trackStroke.Transparency = 0.2
	trackStroke.Parent = track
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = C.mint
	fill.BorderSizePixel = 0
	fill.Parent = track
	local fillCorner = Instance.new("UICorner")
	fillCorner.CornerRadius = UDim.new(1, 0)
	fillCorner.Parent = fill
	local sheen = Instance.new("UIGradient") -- a soft glossy top edge
	sheen.Rotation = 90
	sheen.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200))
	sheen.Parent = fill
	ui.healthFill = fill
	-- humans go down in hits: thin marks split the bar into 3
	ui.healthMarks = {}
	for i = 1, 2 do
		local mark = Instance.new("Frame")
		mark.AnchorPoint = Vector2.new(0.5, 0)
		mark.Position = UDim2.fromScale(i / 3, 0)
		mark.Size = UDim2.new(0, 2, 1, 0)
		mark.BackgroundColor3 = C.plum
		mark.BorderSizePixel = 0
		mark.ZIndex = 2
		mark.Parent = track
		table.insert(ui.healthMarks, mark)
	end
	ui.healthShown = 1 -- eased fill amount

	-- hunter: ammo + crosshair
	ui.ammo = Theme.chip(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -16),
		Size = UDim2.fromOffset(0, 34),
		TextSize = 20,
		Text = "",
		TextColor3 = C.peach,
		Visible = false,
	})
	ui.crosshair = Theme.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(26, 26),
		Text = "+",
		TextColor3 = C.peach,
		TextStrokeTransparency = 0.3,
		Visible = false,
	})

	-- downed overlay
	local downed = Instance.new("Frame")
	downed.Size = UDim2.fromScale(1, 1)
	downed.BackgroundColor3 = Color3.fromRGB(40, 40, 46)
	downed.BackgroundTransparency = 0.55
	downed.Visible = false
	downed.Parent = gui
	ui.downed = downed
	Theme.label(downed, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.3),
		Size = UDim2.fromOffset(500, 60),
		Text = "BLEEDING OUT",
		Font = Theme.titleFont,
		TextColor3 = C.blood,
	})
	local _, bleedFill = Theme.bar(downed, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.3) + UDim2.fromOffset(0, 70),
		Size = UDim2.fromOffset(360, 20),
	}, C.blood)
	ui.bleedFill = bleedFill
	ui.coming = Theme.label(downed, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.3) + UDim2.fromOffset(0, 100),
		Size = UDim2.fromOffset(420, 30),
		Text = "",
		TextColor3 = C.baby,
	})
	local reviveBack, reviveFill = Theme.bar(downed, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.3) + UDim2.fromOffset(0, 136),
		Size = UDim2.fromOffset(260, 14),
	}, C.baby)
	ui.reviveBack, ui.reviveFill = reviveBack, reviveFill

	-- "+points" popups
	local popups = Instance.new("Frame")
	popups.BackgroundTransparency = 1
	popups.AnchorPoint = Vector2.new(1, 1)
	popups.Position = UDim2.new(1, -16, 1, -150)
	popups.Size = UDim2.fromOffset(260, 160)
	popups.Parent = gui
	ui.popups = popups

	-- phone: reload button for the Hunter (attack = tap, interact = prompt buttons)
	local reload = Theme.button(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -108),
		Size = UDim2.fromOffset(64, 64),
		Text = "RELOAD",
		TextColor3 = C.peach,
		Visible = false,
	})
	reload.Activated:Connect(function()
		Remotes.get("Reload"):FireServer()
	end)
	ui.reload = reload

	-- Alpha: class ability button ([Q] on a keyboard), shows the cooldown
	local ability = Theme.button(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -60),
		Size = UDim2.fromOffset(150, 40),
		TextSize = 16,
		Text = "",
		Visible = false,
	})
	ability.Activated:Connect(function()
		Remotes.get("UseAbility"):FireServer()
	end)
	ui.ability = ability

	-- role help: a round icon (top left) that opens "how to play your role" ([H])
	local help = Instance.new("TextButton")
	help.Name = "RoleHelp"
	help.Position = UDim2.fromOffset(16, 46)
	help.Size = UDim2.fromOffset(32, 32)
	help.BackgroundColor3 = C.baby
	help.Font = Theme.titleFont
	help.TextScaled = true
	help.TextColor3 = C.ink
	help.Text = "?"
	help.Visible = false
	local hc = Instance.new("UICorner")
	hc.CornerRadius = UDim.new(1, 0)
	hc.Parent = help
	local hs = Instance.new("UIStroke")
	hs.Color = C.plum
	hs.Thickness = 2
	hs.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	hs.Parent = help
	help.Parent = gui
	ui.help = help
	ui.helpStroke = hs
	ui.helpLabel = Theme.label(gui, {
		Position = UDim2.fromOffset(56, 46),
		Size = UDim2.fromOffset(200, 16),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 14,
		Text = "",
		Visible = false,
	})
	Theme.label(ui.helpLabel, {
		Position = UDim2.fromOffset(0, 17),
		Size = UDim2.fromOffset(200, 13),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextScaled = false,
		TextSize = 11,
		TextColor3 = C.lavender,
		Text = if UserInputService.TouchEnabled then "tap ? for how to play" else "[H] how to play",
	})

	local panel = Theme.panel(gui, {
		Name = "RoleHelpPanel",
		Position = UDim2.fromOffset(16, 86),
		Size = UDim2.fromOffset(340, 10),
		AutomaticSize = Enum.AutomaticSize.Y,
		Visible = false,
	})
	local panelPad = Instance.new("UIPadding")
	panelPad.PaddingTop = UDim.new(0, 10)
	panelPad.PaddingBottom = UDim.new(0, 12)
	panelPad.PaddingLeft = UDim.new(0, 12)
	panelPad.PaddingRight = UDim.new(0, 12)
	panelPad.Parent = panel
	local panelLayout = Instance.new("UIListLayout")
	panelLayout.SortOrder = Enum.SortOrder.LayoutOrder
	panelLayout.Padding = UDim.new(0, 6)
	panelLayout.Parent = panel
	ui.helpPanel = panel
	help.Activated:Connect(function()
		panel.Visible = not panel.Visible
	end)

	-- your saved Z-Coins (top left)
	ui.coins = Theme.chip(gui, {
		Position = UDim2.fromOffset(16, 12),
		Text = "",
		TextColor3 = C.butter,
		Visible = false, -- until your save has loaded
	})

	-- lobby: which Alpha class you will play if you are picked
	ui.alphaPref = Theme.chip(gui, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -16),
		TextSize = 13,
		Text = "",
		TextColor3 = C.blood,
		Visible = false,
	})

	-- repairing: progress of the tower you're working on
	local repair = Instance.new("Frame")
	repair.Name = "Repair"
	repair.AnchorPoint = Vector2.new(0.5, 1)
	repair.Position = UDim2.new(0.5, 0, 1, -110)
	repair.Size = UDim2.fromOffset(240, 26)
	repair.BackgroundTransparency = 1
	repair.Visible = false
	repair.Parent = gui
	ui.repairText = Theme.label(repair, {
		Size = UDim2.new(1, 0, 0, 14),
		TextScaled = false,
		TextSize = 12,
		TextColor3 = C.mint,
		Text = "",
	})
	local repairTrack = Instance.new("Frame")
	repairTrack.AnchorPoint = Vector2.new(0, 1)
	repairTrack.Position = UDim2.fromScale(0, 1)
	repairTrack.Size = UDim2.new(1, 0, 0, 7)
	repairTrack.ClipsDescendants = true
	repairTrack.Parent = repair
	Theme.glass(repairTrack, true)
	local repairFill = Instance.new("Frame")
	repairFill.Size = UDim2.fromScale(0, 1)
	repairFill.BackgroundColor3 = C.mint
	repairFill.BorderSizePixel = 0
	repairFill.Parent = repairTrack
	local rfc = Instance.new("UICorner")
	rfc.CornerRadius = UDim.new(1, 0)
	rfc.Parent = repairFill
	ui.repairBack, ui.repairFill = repair, repairFill

	-- medkit count (Survivors)
	ui.medkit = Theme.chip(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -50),
		Size = UDim2.fromOffset(0, 22),
		TextSize = 12,
		Text = "",
		TextColor3 = C.blood,
		Visible = false,
	})

	-- hiding in a locker: dark screen with slats and a way out
	local hiding = Instance.new("Frame")
	hiding.Size = UDim2.fromScale(1, 1)
	hiding.BackgroundColor3 = Color3.new(0, 0, 0)
	hiding.BackgroundTransparency = 0.25
	hiding.Visible = false
	hiding.Parent = gui
	for i = 0, 6 do -- light through the locker slats
		local slat = Instance.new("Frame")
		slat.BorderSizePixel = 0
		slat.BackgroundColor3 = C.lavender
		slat.BackgroundTransparency = 0.85
		slat.Position = UDim2.fromScale(0.35, 0.38 + i * 0.025)
		slat.Size = UDim2.fromScale(0.3, 0.006)
		slat.Parent = hiding
	end
	Theme.label(hiding, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.6),
		Size = UDim2.fromOffset(500, 32),
		Text = "HIDING... stay quiet",
		Font = Theme.titleFont,
		TextColor3 = C.lavender,
	})
	local leave = Instance.new("TextButton")
	leave.AnchorPoint = Vector2.new(0.5, 0)
	leave.Position = UDim2.fromScale(0.5, 0.67)
	leave.Size = UDim2.fromOffset(170, 40)
	leave.BackgroundColor3 = C.dusk
	leave.Font = Theme.uiFont
	leave.TextScaled = true
	leave.TextColor3 = C.bone
	leave.Text = "[E] LEAVE"
	local lc = Instance.new("UICorner")
	lc.CornerRadius = UDim.new(0, 10)
	lc.Parent = leave
	leave.Parent = hiding
	leave.Activated:Connect(function()
		Remotes.get("LockerLeave"):FireServer()
	end)
	ui.hiding = hiding
end

-- Zombies: a red ripple where a skill check just failed (it fades; no exact position kept).
local function noisePing(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = position + Vector3.new(0, 6, 0)
	anchor.Parent = workspace
	local tag = Instance.new("BillboardGui")
	tag.AlwaysOnTop = true
	tag.Size = UDim2.fromOffset(60, 60)
	tag.Parent = anchor
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromScale(0.3, 0.3)
	ring.BackgroundTransparency = 1
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = C.blood
	stroke.Thickness = 3
	stroke.Parent = ring
	ring.Parent = tag
	task.spawn(function()
		for i = 1, 45 do
			local a = i / 45
			ring.Size = UDim2.fromScale(0.3 + a * 0.7, 0.3 + a * 0.7)
			stroke.Transparency = a
			task.wait(0.05)
		end
		anchor:Destroy()
	end)
end

-- Zombies: a Screamer screamed. These humans glow through walls for a few seconds.
local function revealHumans(chars: { Model }, seconds: number)
	for _, char in chars do
		if typeof(char) ~= "Instance" or not char:IsA("Model") or not char.Parent then
			continue
		end
		local glow = Instance.new("Highlight")
		glow.Name = "ScreamReveal"
		glow.FillColor = C.blood
		glow.FillTransparency = 0.6
		glow.OutlineColor = C.blood
		glow.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		glow.Adornee = char
		glow.Parent = char
		task.delay(seconds, function()
			glow:Destroy()
		end)
	end
end

-- Fills the role help panel: role title, the goal, then one line per tip.
local helpFor = ""
local function fillHelp(role: string, mode: string)
	local key = role .. "/" .. mode
	if key == helpFor then
		return
	end
	helpFor = key
	local guide = RoleGuide.get(role, mode)
	for _, child in ui.helpPanel:GetChildren() do
		if child:IsA("TextLabel") then
			child:Destroy()
		end
	end
	if not guide then
		return
	end
	local color = Theme.roleColor[role] or C.bone
	local order = 0
	local function line(text: string, size: number, textColor: Color3, font: Enum.Font?)
		order += 1
		Theme.label(ui.helpPanel, {
			LayoutOrder = order,
			Size = UDim2.fromScale(1, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextWrapped = true,
			TextScaled = false,
			TextSize = size,
			TextStrokeTransparency = 0.5,
			TextColor3 = textColor,
			Font = font or Theme.uiFont,
			Text = text,
		})
	end
	line(`YOU ARE THE {guide.title}`, 22, color, Theme.titleFont)
	line(guide.goal, 15, C.bone)
	for _, tip in guide.tips do
		line("-  " .. tip, 13, C.lavender)
	end
end

local function rebuildList()
	for _, child in ui.list:GetChildren() do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	local rows = {}
	for _, p in view.players do
		table.insert(rows, p)
	end
	table.sort(rows, function(a, b)
		return a.points > b.points
	end)
	for i, p in rows do
		local other = Players:GetPlayerByUserId(p.id)
		local name = if other then other.DisplayName else "?"
		-- No roles in the list: only your own row says what you are.
		local isMe = p.id == player.UserId
		local roleText = if isMe then (Theme.roleText[p.role] or "") else ""
		if p.life == "Out" then
			roleText = "WAITING"
		elseif isMe and p.life == "Downed" then
			roleText = "DOWN"
		end
		-- one compact row: name (cut if long) | role | points
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.LayoutOrder = i
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
		row.Parent = ui.list
		local small = { TextScaled = false, TextSize = 12, TextStrokeTransparency = 0.4 }
		local function cell(props)
			for k, v in small do
				props[k] = props[k] or v
			end
			return Theme.label(row, props)
		end
		cell({
			Size = UDim2.new(0.5, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Text = name,
		})
		cell({
			Position = UDim2.fromScale(0.5, 0),
			Size = UDim2.new(0.34, 0, 1, 0),
			TextTruncate = Enum.TextTruncate.AtEnd,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextColor3 = Theme.roleColor[p.role] or C.lavender,
			Text = roleText,
		})
		cell({
			Position = UDim2.fromScale(0.84, 0),
			Size = UDim2.new(0.16, 0, 1, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			TextColor3 = C.butter,
			Text = tostring(p.points),
		})
	end
end

local function updatePrompts()
	local mine = me()
	local role = mine and mine.role
	local alive = mine and mine.life == "Alive"
	local human = role == "Survivor" or role == "Hunter"
	for _, prompt in CollectionService:GetTagged("RevivePrompt") do
		local ownBody = player.Character ~= nil and prompt:IsDescendantOf(player.Character)
		prompt.Enabled = human and alive and not ownBody
	end
	for _, prompt in CollectionService:GetTagged("GunPrompt") do
		prompt.Enabled = role == "Survivor" and alive
	end
	local armed = role == "Hunter" or (role == "Survivor" and view ~= nil and view.humanWeapon ~= nil)
	for _, prompt in CollectionService:GetTagged("AmmoPrompt") do
		local box = prompt.Parent
		prompt.Enabled = armed and box ~= nil and not box:GetAttribute("Empty")
	end
	local hidden = view ~= nil and view.hidden == true
	local canAct = human and alive and not hidden
	local zombie = (role == "Alpha" or role == "Zombie") and alive
	for _, prompt in CollectionService:GetTagged("RepairPrompt") do
		prompt.Enabled = canAct == true
	end
	for _, prompt in CollectionService:GetTagged("LockerHidePrompt") do
		prompt.Enabled = canAct == true
	end
	for _, prompt in CollectionService:GetTagged("LockerSearchPrompt") do
		prompt.Enabled = zombie == true
	end
	if hidden then
		for _, prompt in CollectionService:GetTagged("RevivePrompt") do
			prompt.Enabled = false
		end
		for _, prompt in CollectionService:GetTagged("GunPrompt") do
			prompt.Enabled = false
		end
	end
end

local function onState(newView: any)
	view = newView
	viewStamp = os.clock()
	rebuildList()
	updatePrompts()
end

local function popup(amount: number, reason: string)
	local l = Theme.label(ui.popups, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.fromScale(1, 1),
		Size = UDim2.fromOffset(260, 22),
		TextXAlignment = Enum.TextXAlignment.Right,
		TextScaled = false,
		TextSize = 17,
		Text = `+{amount} {reason}`,
		TextColor3 = C.butter,
	})
	task.spawn(function()
		for i = 1, 40 do
			l.Position = UDim2.new(1, 0, 1, -i * 3)
			l.TextTransparency = math.max(0, (i - 25) / 15)
			l.TextStrokeTransparency = l.TextTransparency
			task.wait(0.03)
		end
		l:Destroy()
	end)
end

local function tracer(origin: Vector3, hitPos: Vector3)
	local dist = (hitPos - origin).Magnitude
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Material = Enum.Material.Neon
	p.Color = C.butter
	p.Size = Vector3.new(0.08, 0.08, dist)
	p.CFrame = CFrame.lookAt(origin, hitPos) * CFrame.new(0, 0, -dist / 2)
	p.Parent = workspace
	task.delay(0.06, function()
		p:Destroy()
	end)
end

local function render()
	if not view then
		return
	end
	local phase = view.phase
	local left = math.max(0, view.timeLeft - (os.clock() - viewStamp))
	local mine = me()
	local role = mine and mine.role or "-"
	local inRound = (phase == "HeadStart" or phase == "Active")
		and mine ~= nil
		and mine.life ~= "Out"
		and mine.life ~= "Escaped"

	-- top center
	local lastMinute = phase == "Active" and left < 60
	-- last minute: the clock turns a deep blood red with a dark edge (no shaking)
	ui.timer.TextStrokeColor3 = if lastMinute then Color3.fromRGB(40, 0, 6) else C.ink
	if phase == "Waiting" then
		ui.timer.Text = "ZOMBIE HUNTER"
		ui.timer.TextColor3 = C.mint
		ui.sub.Text = `WAITING FOR PLAYERS {view.count}/{view.needed}`
	elseif phase == "Intermission" then
		ui.timer.Text = Theme.timeText(left)
		ui.timer.TextColor3 = C.bone
		ui.sub.Text = "NEXT ROUND STARTING  -  VOTE FOR A MAP AT THE BOARD"
	elseif phase == "HeadStart" then
		ui.timer.Text = Theme.timeText(left)
		ui.timer.TextColor3 = C.blood
		ui.sub.Text = if role == "Alpha"
			then `BLEND IN... YOUR CLAWS WAKE UP IN {Theme.timeText(left)}`
			else "SOMEONE IS INFECTED... RUN"
	elseif phase == "Active" then
		ui.timer.Text = Theme.timeText(left)
		ui.timer.TextColor3 = if lastMinute then Color3.fromRGB(200, 10, 28) else C.bone
		local line = `HUMANS LEFT: {view.humansLeft}`
		if next(view.towers) ~= nil then
			line ..= `   TOWERS {view.towersDone}/{view.towersNeeded}`
		end
		local heli = view.heli
		local heliLeft = math.max(0, heli.timeLeft - (os.clock() - viewStamp))
		if heli.phase == "Inbound" then
			line = `HELICOPTER IN {Theme.timeText(heliLeft)}   ` .. line
		elseif heli.phase == "Landed" then
			line = `GET TO THE HELICOPTER! {math.ceil(heliLeft)}s   ` .. line
		end
		ui.sub.Text = line
	elseif phase == "Results" then
		ui.timer.Text = "ROUND OVER"
		ui.timer.TextColor3 = C.lavender
		ui.sub.Text = "SAFE IN THE SAFEHOUSE  -  REST UP"
	end

	-- health / wounds
	ui.healthBack.Visible = inRound == true
	if inRound and mine then
		local zombie = role == "Alpha" or role == "Zombie"
		local target
		if zombie then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			target = if hum and hum.MaxHealth > 0 then hum.Health / hum.MaxHealth else 0
			ui.healthText.Text = if hum then `{math.ceil(hum.Health)} HP` else ""
		else
			target = 1 - mine.hitsTaken / 3
			ui.healthText.Text = if mine.hitsTaken == 0 then "HEALTHY" else `WOUNDED  x{mine.hitsTaken}`
		end
		-- ease toward the new value so hits slide instead of jumping
		ui.healthShown += (math.clamp(target, 0, 1) - ui.healthShown) * 0.2
		ui.healthFill.Size = UDim2.fromScale(ui.healthShown, 1)
		local color = Theme.roleColor[role] or C.baby
		ui.healthFill.BackgroundColor3 = if not zombie and mine.hitsTaken >= 2 then C.blood else color
		ui.healthText.TextColor3 = if not zombie and mine.hitsTaken > 0 then C.blood else C.bone
		for _, mark in ui.healthMarks do
			mark.Visible = not zombie
		end
	end

	-- gun bits: the Hunter, or every Survivor in an armed mode (Outbreak)
	local hasGun = inRound and (role == "Hunter" or (role == "Survivor" and view.humanWeapon ~= nil))
	local char = player.Character
	local holdingGun = hasGun
		and char ~= nil
		and char:FindFirstChildWhichIsA("Tool") ~= nil
		and (char:FindFirstChildWhichIsA("Tool") :: Tool):GetAttribute("Gun") == true
	ui.ammo.Visible = hasGun == true
	ui.ammo.Text = `{ammo.mag} / {ammo.reserve}`
	-- the crosshair sits exactly where the shot goes (mouse cursor, or screen centre on touch)
	ui.crosshair.Visible = holdingGun == true
	if holdingGun then
		local at = Aim.screenPoint()
		ui.crosshair.Position = UDim2.fromOffset(at.X, at.Y)
	end
	UserInputService.MouseIconEnabled = not (holdingGun and Aim.usesMouse())
	ui.reload.Visible = hasGun == true and UserInputService.TouchEnabled

	-- downed
	local isDowned = inRound and mine and mine.life == "Downed"
	ui.downed.Visible = isDowned == true
	if isDowned then
		local bleed = math.max(0, (mine.bleedLeft or 0) - (os.clock() - viewStamp))
		ui.bleedFill.Size = UDim2.fromScale(math.clamp(bleed / view.bleedOut, 0, 1), 1)
		local reviver = mine.reviverId and Players:GetPlayerByUserId(mine.reviverId)
		ui.coming.Text = if reviver then `{reviver.DisplayName} is coming!` else "Crawl to your team..."
		ui.reviveBack.Visible = reviver ~= nil
		if reviver then
			local prog = mine.reviveProgress + (os.clock() - viewStamp)
			ui.reviveFill.Size = UDim2.fromScale(math.clamp(prog / view.reviveTime, 0, 1), 1)
		end
	end

	-- repairing a tower
	local towerId = inRound and view.repairing
	local tower = towerId and view.towers[tostring(towerId)]
	ui.repairBack.Visible = tower ~= nil
	if tower then
		ui.repairFill.Size = UDim2.fromScale(math.clamp(tower.progress, 0, 1), 1)
		ui.repairText.Text = `REPAIRING  {math.floor(tower.progress * 100)}%`
	end

	-- medkit
	ui.medkit.Text = if inRound
			and role == "Survivor"
			and (view.medkits or 0) > 0
		then `MEDKIT x{view.medkits}  -  click to heal`
		else ""
	ui.medkit.Visible = ui.medkit.Text ~= ""

	-- Alpha ability
	local showAbility = inRound and phase == "Active" and role == "Alpha" and view.alphaClass ~= nil
	ui.ability.Visible = showAbility == true
	if showAbility then
		local class = AlphaClasses.get(view.alphaClass)
		local wait = math.max(0, (view.abilityIn or 0) - (os.clock() - viewStamp))
		local key = if UserInputService.TouchEnabled then "" else " [Q]"
		ui.ability.Text = if wait > 0
			then `{string.upper(class.ability)} {math.ceil(wait)}s`
			else string.upper(class.ability) .. key
		-- ready: glowing red pill; cooling down: quiet glass
		ui.ability.BackgroundColor3 = if wait > 0 then C.plum else Color3.fromRGB(150, 20, 40)
		ui.ability.BackgroundTransparency = if wait > 0 then 0.3 else 0.1
		ui.ability.TextColor3 = if wait > 0 then C.lavender else C.bone
	end

	-- lobby: your Alpha class
	local lobby = not inRound
		and (phase == "Waiting" or phase == "Intermission" or (mine and mine.life == "Out"))
	ui.alphaPref.Text = if lobby
		then `IF YOU ARE THE ALPHA: {AlphaClasses.get(view.alphaPref).name}  -  change it at the pedestals`
		else ""
	ui.alphaPref.Visible = ui.alphaPref.Text ~= ""

	-- role help icon: in a round, for your own role (pulses for the first seconds)
	local knowsRole = inRound
		and (role == "Survivor" or role == "Hunter" or role == "Alpha" or role == "Zombie")
	ui.help.Visible = knowsRole == true
	ui.helpLabel.Visible = knowsRole == true
	if knowsRole then
		local color = Theme.roleColor[role] or C.baby
		ui.help.BackgroundColor3 = color
		local guide = RoleGuide.get(role, view.mode)
		ui.helpLabel.Text = if guide then guide.title else ""
		ui.helpLabel.TextColor3 = color
		fillHelp(role, view.mode or "Classic")
		local pulse = phase == "HeadStart" or (phase == "Active" and left > view.roundLength - 8)
		ui.helpStroke.Thickness = if pulse then 3 + 2 * math.abs(math.sin(os.clock() * 4)) else 3
	else
		ui.helpPanel.Visible = false
	end

	-- hiding
	ui.hiding.Visible = inRound and view.hidden == true or false

	-- edge tint: zombies green-black, Alpha pulsing pink-red, nothing for humans
	if inRound and role == "Zombie" then
		ui.edge.Color = Color3.fromRGB(20, 60, 40)
		ui.edge.Transparency = 0.45
	elseif inRound and role == "Alpha" then
		ui.edge.Color = C.blood
		ui.edge.Transparency = 0.55 + 0.2 * math.sin(os.clock() * 3)
	else
		ui.edge.Transparency = 1
	end
end

function HudController.start()
	build()
	Remotes.get("RoundStateChanged").OnClientEvent:Connect(onState)
	Remotes.get("PointsPopup").OnClientEvent:Connect(popup)
	Remotes.get("AmmoChanged").OnClientEvent:Connect(function(mag, reserve)
		ammo.mag, ammo.reserve = mag, reserve
	end)
	Remotes.get("ShotFired").OnClientEvent:Connect(tracer)
	Remotes.get("NoiseAlert").OnClientEvent:Connect(noisePing)
	Remotes.get("RevealHumans").OnClientEvent:Connect(revealHumans)
	Remotes.get("ProfileChanged").OnClientEvent:Connect(function(profile)
		ui.coins.Text = `Z-COINS  {profile.coins}`
		ui.coins.Visible = true
	end)
	Remotes.get("RequestProfile"):FireServer()
	for _, tag in
		{
			"RevivePrompt",
			"GunPrompt",
			"AmmoPrompt",
			"RepairPrompt",
			"LockerHidePrompt",
			"LockerSearchPrompt",
		}
	do
		CollectionService:GetInstanceAddedSignal(tag):Connect(updatePrompts)
	end
	RunService.RenderStepped:Connect(render)
	-- Tab shows / hides our player list. Roblox's own big player list is turned off.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Health, false) -- our own bar replaces Roblox's green one
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.Tab then
			ui.list.Visible = not ui.list.Visible
		elseif input.KeyCode == Enum.KeyCode.E and view and view.hidden then
			Remotes.get("LockerLeave"):FireServer()
		elseif not processed and input.KeyCode == Enum.KeyCode.Q and ui.ability.Visible then
			Remotes.get("UseAbility"):FireServer()
		elseif not processed and input.KeyCode == Enum.KeyCode.H and ui.help.Visible then
			ui.helpPanel.Visible = not ui.helpPanel.Visible
		end
	end)
end

return HudController
