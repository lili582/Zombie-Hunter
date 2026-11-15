--!strict
-- You: the slim health bar (bottom left), the medkit chip, and the BLEEDING OUT screen
-- with the revive bar.
local Players = game:GetService("Players")
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.colors
local player = Players.LocalPlayer

local Vitals = {}

local ui: { [string]: any } = {} -- the HUD's shared widget table (set in build)

function Vitals.build(gui: ScreenGui, widgets: { [string]: any })
	ui = widgets
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
end

-- Every frame: draw from the latest round snapshot.
function Vitals.render(frame: any)
	local view, viewStamp, mine, role, inRound =
		frame.view, frame.viewStamp, frame.mine, frame.role, frame.inRound
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

	-- medkit
	ui.medkit.Text = if inRound
			and role == "Survivor"
			and (view.medkits or 0) > 0
		then `MEDKIT x{view.medkits}  -  click to heal`
		else ""
	ui.medkit.Visible = ui.medkit.Text ~= ""
end

return Vitals
