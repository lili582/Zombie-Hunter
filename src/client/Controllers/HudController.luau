--!strict
-- In-round HUD. Draws only what the server sends (RoundStateChanged); sends nothing itself.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local Theme = require(script.Parent.Theme)

local C = Theme.colors
local player = Players.LocalPlayer

local HudController = {}

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

	-- top center: timer + subline
	local top = Instance.new("Frame")
	top.BackgroundTransparency = 1
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 44)
	top.Size = UDim2.fromOffset(320, 90)
	top.Parent = gui
	ui.top = top
	ui.timer = Theme.label(top, { Size = UDim2.new(1, 0, 0, 56), Text = "", Font = Theme.titleFont })
	ui.sub =
		Theme.label(top, { Position = UDim2.fromOffset(0, 56), Size = UDim2.new(1, 0, 0, 26), Text = "" })

	-- top right: player list
	local list = Theme.panel(gui, {
		Name = "PlayerList",
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -12, 0, 50),
		Size = UDim2.fromOffset(250, 40),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	local layout = Instance.new("UIListLayout")
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 2)
	layout.Parent = list
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 6)
	pad.PaddingBottom = UDim.new(0, 6)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = list
	ui.list = list

	-- bottom left: health / wounds
	local healthBack, healthFill = Theme.bar(gui, {
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -70),
		Size = UDim2.fromOffset(220, 22),
	}, C.mint)
	ui.healthBack, ui.healthFill = healthBack, healthFill
	ui.healthText = Theme.label(healthBack, { Size = UDim2.fromScale(1, 1), Text = "", ZIndex = 3 })

	-- hunter: ammo + crosshair
	ui.ammo = Theme.label(gui, {
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -20, 1, -130),
		Size = UDim2.fromOffset(160, 40),
		Text = "",
		TextColor3 = C.peach,
	})
	ui.crosshair = Theme.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(30, 30),
		Text = "+",
		TextColor3 = C.peach,
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
	popups.Position = UDim2.new(1, -20, 1, -180)
	popups.Size = UDim2.fromOffset(260, 200)
	popups.Parent = gui
	ui.popups = popups

	-- phone: reload button for the Hunter (attack = tap, interact = prompt buttons)
	local reload = Instance.new("TextButton")
	reload.AnchorPoint = Vector2.new(1, 1)
	reload.Position = UDim2.new(1, -30, 1, -230)
	reload.Size = UDim2.fromOffset(80, 80)
	reload.BackgroundColor3 = C.peach
	reload.Font = Theme.uiFont
	reload.Text = "RELOAD"
	reload.TextColor3 = C.ink
	reload.TextScaled = true
	reload.Visible = false
	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(1, 0)
	rc.Parent = reload
	reload.Parent = gui
	reload.Activated:Connect(function()
		Remotes.get("Reload"):FireServer()
	end)
	ui.reload = reload
end

local function rebuildList()
	for _, child in ui.list:GetChildren() do
		if child:IsA("TextLabel") then
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
		local roleText = Theme.roleText[p.role] or p.role
		if p.life == "Downed" then
			roleText = "DOWN"
		elseif p.life == "Out" then
			roleText = "WAITING"
		end
		Theme.label(ui.list, {
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			RichText = true,
			Text = string.format(
				'%s  <font color="#%s">%s</font>  <font color="#%s">%d</font>',
				name,
				(Theme.roleColor[p.role] or C.lavender):ToHex(),
				roleText,
				C.butter:ToHex(),
				p.points
			),
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
	for _, prompt in CollectionService:GetTagged("AmmoPrompt") do
		local box = prompt.Parent
		prompt.Enabled = role == "Hunter" and box ~= nil and not box:GetAttribute("Empty")
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
		Size = UDim2.fromOffset(260, 30),
		TextXAlignment = Enum.TextXAlignment.Right,
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
	local inRound = (phase == "HeadStart" or phase == "Active") and mine and mine.life ~= "Out"

	-- top center
	local shake = UDim2.fromOffset(0, 0)
	if phase == "Waiting" then
		ui.timer.Text = "ZOMBIE HUNTER"
		ui.timer.TextColor3 = C.mint
		ui.sub.Text = `WAITING FOR PLAYERS {view.count}/{view.needed}`
	elseif phase == "Intermission" then
		ui.timer.Text = Theme.timeText(left)
		ui.timer.TextColor3 = C.bone
		ui.sub.Text = "NEXT ROUND STARTING"
	elseif phase == "HeadStart" then
		ui.timer.Text = Theme.timeText(left)
		ui.timer.TextColor3 = C.blood
		ui.sub.Text = if role == "Alpha"
			then `YOU WILL BE RELEASED IN {Theme.timeText(left)}`
			else "SOMEONE IS INFECTED... RUN"
	elseif phase == "Active" then
		ui.timer.Text = Theme.timeText(left)
		ui.timer.TextColor3 = if left < 60 then C.blood else C.bone
		if left < 60 then
			shake = UDim2.fromOffset(math.random(-2, 2), math.random(-2, 2))
		end
		ui.sub.Text = `HUMANS LEFT: {view.humansLeft}`
	elseif phase == "Results" then
		ui.timer.Text = "ROUND OVER"
		ui.timer.TextColor3 = C.lavender
		ui.sub.Text = `BACK TO THE SAFEHOUSE IN {math.ceil(left)}`
	end
	ui.top.Position = UDim2.new(0.5, 0, 0, 44) + shake

	-- health / wounds
	ui.healthBack.Visible = inRound == true
	if inRound and mine then
		if role == "Alpha" or role == "Zombie" then
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			local frac = if hum and hum.MaxHealth > 0 then hum.Health / hum.MaxHealth else 0
			ui.healthFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
			ui.healthFill.BackgroundColor3 = Theme.roleColor[role]
			ui.healthText.Text = if hum then `{math.ceil(hum.Health)} HP` else ""
		else
			local frac = 1 - mine.hitsTaken / 3
			ui.healthFill.Size = UDim2.fromScale(math.clamp(frac, 0, 1), 1)
			ui.healthFill.BackgroundColor3 = Theme.roleColor[role] or C.baby
			ui.healthText.Text = if mine.hitsTaken == 0 then "HEALTHY" else `WOUNDED x{mine.hitsTaken}`
		end
	end

	-- hunter bits
	local isHunter = inRound and role == "Hunter"
	local holdingGun = isHunter
		and player.Character ~= nil
		and player.Character:FindFirstChild("Revolver") ~= nil
	ui.ammo.Visible = isHunter == true
	ui.ammo.Text = `{ammo.mag} / {ammo.reserve}`
	ui.crosshair.Visible = holdingGun == true
	ui.reload.Visible = isHunter == true and UserInputService.TouchEnabled

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
	for _, tag in { "RevivePrompt", "GunPrompt", "AmmoPrompt" } do
		CollectionService:GetInstanceAddedSignal(tag):Connect(updatePrompts)
	end
	RunService.RenderStepped:Connect(render)
end

return HudController
