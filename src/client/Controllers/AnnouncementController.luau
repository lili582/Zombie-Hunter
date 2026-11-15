--!strict
-- Full-screen cards (round start / end) and top banners (mid-round). Horror style:
-- VHS scanlines, flicker, glitching text, typed subtitles, and the players' own characters
-- shown as black silhouettes in the dark while roles are "chosen". No emoji, no names leaked.
-- Card times for the intro must add up to Classic.introLength (32s).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Maps = require(Shared.Config.Maps)
local Theme = require(script.Parent.Theme)
local RoleEmote = require(script.Parent.RoleEmote)
local RoleGuide = require(Shared.Config.RoleGuide)

local C = Theme.colors
local player = Players.LocalPlayer

local AnnouncementController = {}

local CARD_TIME = {
	-- intro (32s total): slow on purpose, the role pick is the scary part and needs time to read
	Map = 2.5,
	Mode = 3,
	SomeoneInfected = 8.5,
	YourRole = 8.5,
	YourRules = 7,
	HunterChosen = 2.5,
	EveryoneArmed = 2.5, -- replaces HunterChosen in modes without a Hunter
	-- round end / other
	Result = 4,
	Recap = 8, -- the real length is set per round (recapDuration)
	YourCoins = 3,
	Infected = 2.5,
	Escaped = 3,
	ShotInnocent = 3.5, -- private: you (the Hunter) shot a human
	ShotByHunter = 3.5, -- private: the Hunter shot you
}
local BANNERS = {
	AlphaAwakened = true,
	HunterFallen = true,
	NewHunter = true,
	TowerRepaired = true,
	HeliIncoming = true,
	HeliHere = true,
	AlphaPicked = true,
	Voted = true,
}

local ROLE_TITLE = {
	Survivor = "YOU ARE A SURVIVOR",
	Hunter = "YOU ARE THE HUNTER",
	Alpha = "YOU ARE THE ALPHA ZOMBIE",
	Zombie = "YOU ARE A ZOMBIE",
}
local ROLE_RULES = {
	Survivor = "No weapons  -  Repair 3 radio towers  -  Hide in lockers  -  Revive friends\nZombie attack? CLICK IN TIME to escape!",
	Hunter = "Your role is SECRET  -  Only you have a gun\nShoot a HUMAN and you both die  -  Ammo boxes  -  [R] reload",
	Alpha = "You look like them. Blend in.\nClaws wake up at release  -  [1] takes them out: your face shows until you put them away",
	Zombie = "You still look human. Blend in.\n[1] takes your claws out: your face shows until you put them away  -  3 hits downs a human",
}
-- Rules that change in a mode (role -> text)
local MODE_RULES = {
	Outbreak = {
		Survivor = "You have a PISTOL  -  [R] reload  -  Survive 4:00\nZombie attack? CLICK IN TIME to escape!",
		Alpha = "There are more of you. Blend in.\nClaws wake up at release  -  claws out = your face shows",
	},
}
local RESULT_TEXT = {
	SurvivorsSurvived = { "SURVIVORS SURVIVED!", C.baby },
	SurvivorsEscaped = { "SURVIVORS ESCAPED!", C.baby },
	ZombiesWin = { "ZOMBIES WIN!", C.mint },
	NoWinner = { "NOBODY WINS", C.lavender },
}

-- YourRole: heartbeat gaps (seconds), slow then faster; the reveal comes right after.
local HEARTBEAT = { 0.85, 0.8, 0.72, 0.65, 0.6 }
local ROLE_REVEAL = 0.85 + 0.8 + 0.72 + 0.65 + 0.6 -- when the light comes on (emote starts)

local BLOOD_DARK = Color3.fromRGB(60, 8, 22)

local gui: ScreenGui
local ui: { [string]: any } = {}
local queue: { { card: string, data: any } } = {}
local playing = false
local glitching = false
local cardToken = 0 -- bumps every card so old animations stop

----------------------------------------------------------------------------- building

local function build()
	gui = Instance.new("ScreenGui")
	gui.Name = "Announcements"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 10
	gui.Parent = player:WaitForChild("PlayerGui")

	local card = Instance.new("Frame")
	card.Size = UDim2.fromScale(1, 1)
	card.BackgroundColor3 = Color3.new(0, 0, 0)
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = gui
	ui.card = card

	-- drifting fog behind everything
	local fog = Instance.new("Frame")
	fog.Size = UDim2.fromScale(1, 1)
	fog.BackgroundColor3 = Color3.new(1, 1, 1)
	fog.BorderSizePixel = 0
	fog.Parent = card
	local grad = Instance.new("UIGradient")
	grad.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(0, 0, 0)),
		ColorSequenceKeypoint.new(0.5, C.plum),
		ColorSequenceKeypoint.new(1, Color3.new(0, 0, 0)),
	})
	grad.Parent = fog
	ui.fog, ui.fogGrad = fog, grad

	-- the stage: one big character, or a row of small silhouettes
	local big = Instance.new("ViewportFrame")
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.fromScale(0.5, 0.36)
	big.Size = UDim2.fromScale(0.26, 0.5)
	big.BackgroundTransparency = 1
	big.Visible = false
	big.Parent = card
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 0.7
	ratio.Parent = big
	ui.big = big

	local row = Instance.new("Frame")
	row.AnchorPoint = Vector2.new(0.5, 0.5)
	row.Position = UDim2.fromScale(0.5, 0.36)
	row.Size = UDim2.fromScale(0.9, 0.32)
	row.BackgroundTransparency = 1
	row.Visible = false
	row.Parent = card
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Center
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row
	ui.row = row

	-- small text above the title ("MODE")
	ui.kicker = Theme.label(card, {
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 0.635),
		Size = UDim2.fromScale(0.5, 0.04),
		TextColor3 = C.lavender,
		Text = "",
	})

	-- title + two coloured ghosts for the glitch (chromatic split)
	local function titleLabel(color: Color3, transparency: number): TextLabel
		return Theme.label(card, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.7),
			Size = UDim2.fromScale(0.85, 0.12),
			Font = Theme.titleFont,
			Text = "",
			TextColor3 = color,
			TextTransparency = transparency,
			TextStrokeTransparency = if transparency > 0 then 1 else 0,
		})
	end
	ui.ghostA = titleLabel(Color3.fromRGB(255, 40, 70), 0.45)
	ui.ghostB = titleLabel(C.mint, 0.55)
	ui.title = titleLabel(C.bone, 0)

	ui.subtitle = Theme.label(card, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromScale(0.5, 0.77),
		Size = UDim2.fromScale(0.75, 0.08),
		Text = "",
		TextColor3 = C.lavender,
	})

	-- VHS scanlines
	ui.lines = {}
	for i = 1, 18 do
		local line = Instance.new("Frame")
		line.BorderSizePixel = 0
		line.BackgroundColor3 = if i % 3 == 0 then C.blood else C.lavender
		line.Size = UDim2.new(1, 0, 0, math.random(1, 3))
		line.Parent = card
		table.insert(ui.lines, line)
	end

	-- dark edges + full-screen flash/blackout layers
	local vignette = Instance.new("Frame")
	vignette.Size = UDim2.fromScale(1, 1)
	vignette.BackgroundTransparency = 1
	vignette.Parent = card
	local edge = Instance.new("UIStroke")
	edge.Thickness = 90
	edge.Color = Color3.new(0, 0, 0)
	edge.Transparency = 0.15
	edge.Parent = vignette
	ui.edge = edge

	local flash = Instance.new("Frame")
	flash.Size = UDim2.fromScale(1, 1)
	flash.BorderSizePixel = 0
	flash.BackgroundTransparency = 1
	flash.Parent = card
	ui.flash = flash

	ui.banner = Theme.label(gui, {
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 140),
		Size = UDim2.fromOffset(700, 44),
		Font = Theme.titleFont,
		Text = "",
		Visible = false,
	})
end

----------------------------------------------------------------------------- helpers

local function setTitle(text: string, color: Color3)
	ui.title.Text = text
	ui.ghostA.Text = text
	ui.ghostB.Text = text
	ui.title.TextColor3 = color
end

local function slam()
	ui.title.Size = UDim2.fromScale(1, 0.18)
	TweenService
		:Create(ui.title, TweenInfo.new(0.2, Enum.EasingStyle.Back), { Size = UDim2.fromScale(0.85, 0.12) })
		:Play()
	glitching = true
	task.delay(0.35, function()
		glitching = false
	end)
end

local function doFlash(color: Color3, strength: number)
	ui.flash.BackgroundColor3 = color
	ui.flash.BackgroundTransparency = 1 - strength
	TweenService:Create(ui.flash, TweenInfo.new(0.35), { BackgroundTransparency = 1 }):Play()
end

-- When the last text on the current card finishes typing. A card never switches before that
-- plus READ_HOLD, so there is always time to read it.
local READ_HOLD = 1.2
local textDoneAt = 0
local typingOn: { [TextLabel]: number } = {} -- newest typing job per label (older ones stop)

local function typeText(label: TextLabel, text: string, perChar: number, token: number)
	typingOn[label] = (typingOn[label] or 0) + 1
	local job = typingOn[label]
	textDoneAt = math.max(textDoneAt, os.clock() + #text * perChar)
	task.spawn(function()
		label.Text = ""
		for i = 1, #text do
			if cardToken ~= token or typingOn[label] ~= job then
				return
			end
			label.Text = string.sub(text, 1, i)
			task.wait(perChar)
		end
	end)
end

-- Copy of a player's character that can sit in a ViewportFrame.
local function cloneCharacter(plr: Player): Model?
	local char = plr.Character
	if not char then
		return nil
	end
	local wasArchivable = char.Archivable
	char.Archivable = true
	local ok, copy = pcall(function()
		return char:Clone()
	end)
	char.Archivable = wasArchivable
	if not ok or not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if
			d:IsA("BaseScript")
			or d:IsA("Sound")
			or d:IsA("Light")
			or d:IsA("BillboardGui")
			or d:IsA("ProximityPrompt")
			or d:IsA("Tool")
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return copy
end

-- Turns a character copy into a faceless shadow: same shape, no face, no clothes, no glowing
-- eyes, no skin colour. Used for the "everyone" rows, so nothing hints at anyone's role.
local function shadowify(model: Model)
	for _, d in model:GetDescendants() do
		if
			d:IsA("Decal")
			or d:IsA("Texture")
			or d:IsA("Clothing")
			or d:IsA("ShirtGraphic")
			or d:IsA("BodyColors")
			or d.Name == "Eye"
		then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Color = Color3.fromRGB(28, 26, 32)
			d.Material = Enum.Material.SmoothPlastic
			if d:IsA("MeshPart") then
				d.TextureID = ""
			end
		elseif d:IsA("SpecialMesh") then
			d.TextureId = ""
		end
	end
end

-- Puts `model` in `vp` facing the camera. Starts as a black silhouette.
local function stage(vp: ViewportFrame, model: Model)
	vp:ClearAllChildren()
	local ratio = Instance.new("UIAspectRatioConstraint")
	ratio.AspectRatio = 0.7
	ratio.Parent = vp
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	cam.Parent = vp
	vp.CurrentCamera = cam
	model:PivotTo(CFrame.new())
	model.Parent = vp
	local _, size = model:GetBoundingBox()
	local h = math.max(size.Y, 4)
	cam.CFrame = CFrame.lookAt(Vector3.new(0, h * 0.05, -h * 2.1), Vector3.new(0, 0, 0))
	vp.Ambient = Color3.new(0, 0, 0)
	vp.LightColor = Color3.new(0, 0, 0)
	vp.LightDirection = Vector3.new(0.6, -0.4, 1)
end

-- The role emote playing in the big viewport (your character acting out its role).
local emote: any = nil
local emoteRole: string? = nil
local emoteStart = 0

-- Starts (or, for the next card of the same role, continues) the emote on a staged model.
local emoteReveal = 0
local function playEmote(model: Model, role: string, continueIt: boolean, revealAt: number?)
	if not (continueIt and emoteRole == role and os.clock() - emoteStart < 12) then
		emoteStart = os.clock()
		emoteReveal = revealAt or 0
	end
	emoteRole = role
	emote = RoleEmote.new(model, role, emoteReveal)
end

local function clearStage()
	emote = nil
	ui.big.Visible = false
	ui.big:ClearAllChildren()
	ui.row.Visible = false
	ui.row.Size = UDim2.fromScale(0.9, 0.32)
	ui.row.Position = UDim2.fromScale(0.5, 0.36)
	for _, child in ui.row:GetChildren() do
		if child:IsA("ViewportFrame") or child:IsA("Frame") then
			child:Destroy()
		end
	end
end

-- One small silhouette per player in the server (max 10), all in the dark.
local function silhouetteRow(): { ViewportFrame }
	local frames = {}
	local list = Players:GetPlayers()
	for i = 1, math.min(#list, 10) do
		local model = cloneCharacter(list[i])
		if model then
			shadowify(model)
			local vp = Instance.new("ViewportFrame")
			vp.Size = UDim2.new(0.085, 0, 1, 0)
			vp.BackgroundColor3 = BLOOD_DARK
			vp.BackgroundTransparency = 0.6
			vp.LayoutOrder = math.random(1, 1000) -- shuffled: the order means nothing
			vp.Parent = ui.row
			stage(vp, model)
			local corner = Instance.new("UICorner")
			corner.CornerRadius = UDim.new(0, 8)
			corner.Parent = vp
			table.insert(frames, vp)
		end
	end
	ui.row.Visible = #frames > 0
	return frames
end

-- Round recap: everyone who played, lined up in the dark. One by one a light comes on over each
-- character with their name, the role they really had, and what happened to them.
local OUTCOME_LOOK = {
	SURVIVED = { "SURVIVED", Theme.colors.baby },
	ESCAPED = { "ESCAPED", Theme.colors.butter },
	INFECTED = { "INFECTED", Theme.colors.mint },
	ZOMBIE = { "ZOMBIE", Theme.colors.mint },
	ALPHA = { "THE ALPHA", Theme.colors.blood },
	KILLED = { "KILLED", Theme.colors.lavender },
}
local RECAP_STEP = 0.55 -- seconds between two reveals (slow on purpose)
local RECAP_MAX = 12

-- Turns a character copy into its zombie self: rotten skin, glowing eyes.
local function zombify(model: Model, eyeColor: Color3)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Parent == model and d.Name ~= "HumanoidRootPart" then
			d.Color = Color3.fromRGB(118, 156, 96)
		elseif d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if head then
		for _, x in { -0.22, 0.22 } do
			local eye = Instance.new("Part")
			eye.Name = "Eye"
			eye.Shape = Enum.PartType.Ball
			eye.Size = Vector3.new(0.26, 0.26, 0.26)
			eye.Material = Enum.Material.Neon
			eye.Color = eyeColor
			eye.Anchored = true
			eye.CanCollide = false
			eye.CFrame = head.CFrame * CFrame.new(x, 0.15, -head.Size.Z / 2 - 0.02)
			eye.Parent = model
		end
	end
end

local function recapDuration(count: number): number
	return 2.2 + math.min(count, RECAP_MAX) * RECAP_STEP + 3.5
end

local function playRecap(data: any, token: number)
	local entries = data.players or {}
	local zombiesWon = data.winner == "ZombiesWin"
	setTitle("", C.bone)
	typeText(
		ui.title,
		if zombiesWon then "THE NIGHT BELONGS TO THEM" else "WHO MADE IT THROUGH THE NIGHT",
		0.06,
		token
	)
	ui.kicker.Text = "THE ROUND"
	ui.row.Size = UDim2.fromScale(0.94, 0.46)
	ui.row.Position = UDim2.fromScale(0.5, 0.42)
	local slots = {}
	for i = 1, math.min(#entries, RECAP_MAX) do
		local e = entries[i]
		local who = Players:GetPlayerByUserId(e.id)
		local look = OUTCOME_LOOK[e.outcome] or OUTCOME_LOOK.SURVIVED
		local slot = Instance.new("Frame")
		slot.Name = "RecapSlot"
		slot.LayoutOrder = i
		slot.Size = UDim2.fromScale(math.min(0.15, 0.9 / math.max(#entries, 1)), 1)
		slot.BackgroundTransparency = 1
		slot.Parent = ui.row
		local vp = Instance.new("ViewportFrame")
		vp.Size = UDim2.fromScale(1, 0.72)
		vp.BackgroundColor3 = Color3.fromRGB(12, 8, 18)
		vp.BackgroundTransparency = 0.4
		vp.Parent = slot
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = vp
		local model = if who then cloneCharacter(who) else nil
		if model then
			if e.outcome == "INFECTED" or e.outcome == "ZOMBIE" then
				zombify(model, Theme.colors.mint)
			elseif e.outcome == "ALPHA" then
				zombify(model, Color3.fromRGB(255, 40, 60))
			end
			stage(vp, model)
		end
		local function caption(y: number, height: number, text: string, color: Color3, size: number)
			return Theme.label(slot, {
				Position = UDim2.new(0, 0, 0.72, y),
				Size = UDim2.new(1, 0, 0, height),
				TextScaled = false,
				TextSize = size,
				TextTruncate = Enum.TextTruncate.AtEnd,
				TextColor3 = color,
				TextTransparency = 1,
				TextStrokeTransparency = 1,
				Text = text,
			})
		end
		local name = caption(4, 16, if who then who.DisplayName else "?", C.bone, 14)
		local role =
			caption(20, 13, Theme.roleText[e.role] or e.role, Theme.roleColor[e.role] or C.lavender, 11)
		local outcome = caption(34, 16, look[1], look[2], 14)
		local winner = caption(52, 14, if e.won then "WINNER" else "", C.butter, 12)
		table.insert(
			slots,
			{ vp = vp, labels = { name, role, outcome, winner }, color = look[2], won = e.won }
		)
	end
	ui.row.Visible = #slots > 0
	task.spawn(function()
		task.wait(1.6)
		for _, slot in slots do
			if cardToken ~= token then
				return
			end
			-- the light comes on over this one
			slot.vp.LightColor = slot.color
			slot.vp.Ambient = Color3.fromRGB(45, 38, 60)
			slot.vp.BackgroundColor3 = if slot.won
				then Color3.fromRGB(40, 32, 12)
				else Color3.fromRGB(18, 12, 26)
			slot.vp.BackgroundTransparency = 0.15
			for _, label in slot.labels do
				TweenService
					:Create(
						label,
						TweenInfo.new(0.35),
						{ TextTransparency = 0, TextStrokeTransparency = 0.55 }
					)
					:Play()
			end
			task.wait(RECAP_STEP)
		end
		if cardToken ~= token then
			return
		end
		-- the losers fade back into the dark; the winners stay lit
		for _, slot in slots do
			if not slot.won then
				TweenService:Create(slot.vp, TweenInfo.new(0.8), { BackgroundTransparency = 0.6 }):Play()
				slot.vp.LightColor = Color3.fromRGB(60, 60, 70)
			end
		end
		local r = RESULT_TEXT[data.winner] or RESULT_TEXT.NoWinner
		ui.subtitle.Text = ""
		typeText(ui.subtitle, r[1], 0.05, token)
	end)
end

----------------------------------------------------------------------------- the cards

local function play(name: string, data: any, token: number)
	clearStage()
	ui.kicker.Text = ""
	ui.subtitle.Text = ""
	ui.card.BackgroundColor3 = Color3.new(0, 0, 0)
	ui.fog.BackgroundTransparency = 0.2

	if name == "Map" then
		setTitle("", C.bone)
		local mapName = data.name or "???"
		typeText(ui.title, mapName, 0.8 / math.max(#mapName, 1), token)
		typeText(ui.subtitle, data.line or "", 0.035, token)
		task.delay(0.9, function()
			if cardToken == token then
				setTitle(mapName, C.bone)
				slam()
			end
		end)
	elseif name == "Mode" then
		ui.kicker.Text = "MODE"
		setTitle(data.name or "", C.blood)
		slam()
		doFlash(C.blood, 0.35)
		typeText(ui.subtitle, data.line or "", 0.03, token)
	elseif name == "SomeoneInfected" then
		local cardStart = os.clock()
		-- slow and quiet: the title creeps in, whispers, and a red light searches the crowd
		setTitle("", C.blood)
		typeText(ui.title, "SOMEONE IS INFECTED...", 0.09, token)
		local frames = silhouetteRow()
		task.spawn(function()
			-- two slow whispers, each left up long enough to read
			local whispers = { { 1.0, "who is it..." }, { 3.2, "they're standing right next to you" } }
			for _, w in whispers do
				task.wait(math.max(0, w[1] - (os.clock() - cardStart)))
				if cardToken ~= token then
					return
				end
				typeText(ui.subtitle, w[2], 0.06, token)
			end
		end)
		-- the red light drifts from shadow to shadow, slower and slower. Sometimes it lingers on
		-- someone... then moves on. It never stops on anyone: the Alpha stays secret.
		task.spawn(function()
			if #frames == 0 then
				return
			end
			task.wait(0.8)
			local last = 0
			local steps = 14
			for i = 1, steps do
				if cardToken ~= token then
					return
				end
				local pick = math.random(1, #frames)
				if pick == last and #frames > 1 then
					pick = pick % #frames + 1
				end
				last = pick
				for j, vp in frames do
					vp.LightColor = if j == pick then C.blood else Color3.new(0, 0, 0)
					vp.Ambient = if j == pick then Color3.fromRGB(40, 0, 10) else Color3.new(0, 0, 0)
					vp.BackgroundTransparency = if j == pick then 0.2 else 0.7
				end
				local linger = math.random() < 0.2 and i > 4
				task.wait((0.1 + (i / steps) * 0.3) * (if linger then 2.6 else 1))
			end
			if cardToken ~= token then
				return
			end
			for _, vp in frames do
				vp.LightColor = Color3.new(0, 0, 0)
				vp.Ambient = Color3.new(0, 0, 0)
				vp.BackgroundTransparency = 0.9
			end
			-- the last line only after the second whisper has had time to be read
			task.wait(math.max(0, 6 - (os.clock() - cardStart)))
			if cardToken ~= token then
				return
			end
			doFlash(Color3.new(0, 0, 0), 1)
			typeText(ui.subtitle, "...and it could be you.", 0.08, token)
		end)
	elseif name == "YourRole" then
		local role = data.role
		local color = Theme.roleColor[role] or C.bone
		local guide = RoleGuide.get(role, data.mode)
		setTitle("", color)
		local model = cloneCharacter(player)
		if model then
			stage(ui.big, model)
			playEmote(model, role, false, ROLE_REVEAL)
			ui.big.Visible = true
		end
		ui.subtitle.Text = ""
		typeText(ui.subtitle, "who are you...?", 0.08, token)
		-- a slow heartbeat in the dark, getting faster; the light stutters... then the reveal
		task.spawn(function()
			for beat, gap in HEARTBEAT do
				if cardToken ~= token then
					return
				end
				ui.big.Size = UDim2.fromScale(0.28, 0.54)
				TweenService:Create(ui.big, TweenInfo.new(0.3), { Size = UDim2.fromScale(0.26, 0.5) }):Play()
				if beat >= #HEARTBEAT - 1 then
					for _ = 1, 3 do -- the light tries to come on
						ui.big.LightColor = color
						ui.big.Ambient = Color3.fromRGB(50, 40, 60)
						task.wait(0.05)
						ui.big.LightColor = Color3.new(0, 0, 0)
						ui.big.Ambient = Color3.new(0, 0, 0)
						task.wait(0.07)
					end
					task.wait(math.max(0, gap - 0.36))
				else
					task.wait(gap)
				end
			end
			if cardToken ~= token then
				return
			end
			ui.big.LightColor = color
			ui.big.Ambient = Color3.fromRGB(55, 45, 70)
			setTitle(ROLE_TITLE[role] or "", color)
			slam()
			-- the quick explanation of the role, typed under the title
			ui.subtitle.Text = ""
			if guide then
				typeText(ui.subtitle, guide.quick, 0.08, token) -- slow enough to read
			end
			if role == "Alpha" then
				doFlash(Color3.fromRGB(255, 30, 50), 0.8) -- red flash + shake
				for _ = 1, 10 do
					ui.card.Position = UDim2.fromOffset(math.random(-8, 8), math.random(-6, 6))
					task.wait(0.03)
				end
				ui.card.Position = UDim2.fromOffset(0, 0)
			else
				doFlash(color, 0.45)
			end
		end)
	elseif name == "YourRules" then
		local role = data.role
		local model = cloneCharacter(player)
		if model then
			stage(ui.big, model)
			playEmote(model, role, true) -- keeps going from the role card
			ui.big.LightColor = Theme.roleColor[role] or C.bone
			ui.big.Ambient = Color3.fromRGB(55, 45, 70)
			ui.big.Visible = true
		end
		local modeRules = MODE_RULES[data.mode or ""]
		local rules = (modeRules and modeRules[role]) or ROLE_RULES[role] or ""
		if role == "Alpha" then
			local class = AlphaClasses.get(data.alphaClass)
			setTitle(`ALPHA - {class.name}`, Theme.roleColor[role])
			rules ..= "\n" .. class.line
		else
			setTitle(Theme.roleText[role] or "", Theme.roleColor[role] or C.bone)
		end
		typeText(ui.subtitle, rules, 0.035, token)
	elseif name == "HunterChosen" then
		setTitle("A HUNTER WALKS AMONG YOU", C.peach)
		slam()
		local frames = silhouetteRow()
		-- a warm light sweeps over everyone at once: no one is singled out
		for _, vp in frames do
			vp.Ambient = Color3.fromRGB(30, 20, 15)
			vp.LightColor = C.peach
			vp.BackgroundColor3 = Color3.fromRGB(40, 25, 15)
		end
		ui.subtitle.Text = "Nobody knows who. Trust no one."
	elseif name == "EveryoneArmed" then
		setTitle("EVERYONE IS ARMED", C.baby)
		slam()
		silhouetteRow()
		ui.subtitle.Text = "No Hunter tonight. Shoot anything that bites."
	elseif name == "Recap" then
		playRecap(data, token)
	elseif name == "Result" then
		local r = RESULT_TEXT[data.winner] or RESULT_TEXT.NoWinner
		setTitle(r[1], r[2])
		slam()
		doFlash(r[2], 0.4)
	elseif name == "YourCoins" then
		setTitle(`+{data.coins} Z-COINS`, C.butter)
		slam()
		typeText(ui.subtitle, `{data.points} points this round`, 0.03, token)
	elseif name == "ShotInnocent" then
		ui.card.BackgroundColor3 = Color3.fromRGB(30, 4, 8)
		setTitle("YOU SHOT AN INNOCENT", C.blood)
		slam()
		doFlash(Color3.fromRGB(255, 30, 50), 0.8)
		typeText(
			ui.subtitle,
			"They were human. The guilt takes you too... your gun lies in the dirt.",
			0.03,
			token
		)
	elseif name == "ShotByHunter" then
		ui.card.BackgroundColor3 = Color3.fromRGB(14, 10, 20)
		setTitle("THE HUNTER SHOT YOU", C.peach)
		slam()
		doFlash(Color3.new(1, 1, 1), 0.6)
		typeText(
			ui.subtitle,
			"You were human. They didn't believe it. Watch from the safehouse.",
			0.03,
			token
		)
	elseif name == "Escaped" then
		ui.card.BackgroundColor3 = Color3.fromRGB(10, 14, 30)
		setTitle("YOU ESCAPED", C.baby)
		slam()
		doFlash(C.butter, 0.5)
		typeText(ui.subtitle, "You're safe... for now. The others are still out there.", 0.03, token)
	elseif name == "Infected" then
		ui.card.BackgroundColor3 = Color3.fromRGB(8, 30, 18)
		ui.fog.BackgroundTransparency = 0.6
		setTitle("YOU'VE BEEN INFECTED!", C.blood)
		slam()
		doFlash(C.mint, 0.7)
		local model = cloneCharacter(player)
		if model then
			stage(ui.big, model)
			playEmote(model, "Zombie", false, 0) -- no build-up: you're already one of them
			ui.big.LightColor = C.mint
			ui.big.Ambient = Color3.fromRGB(20, 60, 35)
			ui.big.Visible = true
		end
		typeText(
			ui.subtitle,
			"You're one of them now. You look human... until your claws come out.",
			0.03,
			token
		)
	end
end

-- Runs every frame while a card is up: static, flicker, glitch, slow sway of the character.
local function animate(dt: number)
	if not ui.card.Visible then
		return
	end
	local t = os.clock()
	for _, line in ui.lines do
		line.Position = UDim2.fromScale(0, math.random())
		line.BackgroundTransparency = 0.82 + math.random() * 0.18
	end
	ui.fogGrad.Offset = Vector2.new(math.sin(t * 0.4) * 0.3, 0)
	ui.fogGrad.Rotation = (ui.fogGrad.Rotation + dt * 6) % 360
	ui.edge.Transparency = 0.1 + 0.1 * math.sin(t * 5) -- breathing dark edges

	-- the lights die for a frame now and then
	if math.random() < 0.025 then
		ui.flash.BackgroundColor3 = Color3.new(0, 0, 0)
		ui.flash.BackgroundTransparency = 0.15
		TweenService:Create(ui.flash, TweenInfo.new(0.12), { BackgroundTransparency = 1 }):Play()
	end

	-- chromatic glitch on the title (always a little, a lot right after a slam)
	local amount = if glitching then 10 elseif math.random() < 0.06 then 4 else 0
	local base = UDim2.fromScale(0.5, 0.7)
	ui.ghostA.Position = base
		+ UDim2.fromOffset(math.random(-amount, amount), math.random(-amount, amount) / 2)
	ui.ghostB.Position = base
		+ UDim2.fromOffset(math.random(-amount, amount), math.random(-amount, amount) / 2)
	ui.ghostA.Visible = amount > 0
	ui.ghostB.Visible = amount > 0
	ui.ghostA.Size = ui.title.Size
	ui.ghostB.Size = ui.title.Size

	-- the character sways slowly, as if breathing, and acts out its role (RoleEmote)
	local model = ui.big:FindFirstChildOfClass("Model")
	if ui.big.Visible and model then
		if emote and emote.model == model then
			emote:step(os.clock() - emoteStart, CFrame.Angles(0, math.sin(t * 0.7) * 0.25, 0))
		else
			model:PivotTo(CFrame.Angles(0, math.sin(t * 0.7) * 0.5, 0))
		end
	end
end

local function playQueue()
	if playing then
		return
	end
	playing = true
	task.spawn(function()
		while #queue > 0 do
			local item = table.remove(queue, 1) :: any
			cardToken += 1
			textDoneAt = 0
			ui.card.Visible = true
			play(item.card, item.data or {}, cardToken)
			local seconds = CARD_TIME[item.card] or 2
			if item.card == "Recap" then
				seconds = recapDuration(#((item.data or {}).players or {}))
			end
			task.wait(seconds)
			-- still typing? let it finish, then leave it up a moment to be read (max 4s more)
			local extra = 0
			while os.clock() < textDoneAt + READ_HOLD and extra < 4 do
				extra += task.wait(0.1)
			end
		end
		cardToken += 1
		clearStage()
		ui.card.Visible = false
		playing = false
	end)
end

----------------------------------------------------------------------------- banners

local bannerToken = 0
local function showBanner(name: string, data: any)
	local text, color = "", C.blood
	if name == "AlphaAwakened" then
		text = "THE ALPHA HAS AWAKENED - it could be anyone"
	elseif name == "HunterFallen" then
		text = if data.reason == "innocent"
			then "THE HUNTER SHOT AN INNOCENT - BOTH ARE DEAD. GRAB THE GUN!"
			else "THE HUNTER HAS FALLEN - GRAB THE GUN!"
		color = C.peach
	elseif name == "NewHunter" then
		text = "SOMEONE PICKED UP THE GUN"
		color = C.peach
	elseif name == "TowerRepaired" then
		text = `A RADIO TOWER IS ONLINE  {data.done or "?"}/{data.needed or "?"}`
		color = C.mint
	elseif name == "HeliIncoming" then
		text = `HELICOPTER INCOMING - {data.seconds or 45}s`
		color = C.butter
	elseif name == "HeliHere" then
		text = "THE HELICOPTER IS HERE - GET TO THE ZONE!"
		color = C.butter
	elseif name == "Voted" then
		local map = Maps.get(data.mapId)
		text = `YOU VOTED: {if map then map.name else "?"}`
		color = C.lavender
	elseif name == "AlphaPicked" then
		local class = AlphaClasses.get(data.class)
		text = `IF YOU ARE THE ALPHA: {class.name}`
	end
	bannerToken += 1
	local my = bannerToken
	local banner = ui.banner
	banner.Text = text
	banner.TextColor3 = color
	banner.Visible = true
	task.spawn(function()
		for _ = 1, 10 do -- shake + flicker
			banner.Position = UDim2.new(0.5, math.random(-5, 5), 0, 140 + math.random(-3, 3))
			banner.TextTransparency = if math.random() < 0.3 then 0.6 else 0
			task.wait(0.03)
		end
		banner.Position = UDim2.new(0.5, 0, 0, 140)
		banner.TextTransparency = 0
	end)
	task.delay(3, function()
		if bannerToken == my then
			banner.Visible = false
		end
	end)
end

local function onAnnounce(name: string, data: any)
	if BANNERS[name] then
		showBanner(name, data or {})
	elseif CARD_TIME[name] then
		table.insert(queue, { card = name, data = data })
		playQueue()
	end
end

-- The "infected moment": my role flips from human to zombie during a round.
local lastRole: string? = nil
local function onState(view: any)
	local mine = view.players[tostring(player.UserId)]
	local role = mine and mine.role
	if view.phase == "Active" and role == "Zombie" and (lastRole == "Survivor" or lastRole == "Hunter") then
		task.delay(0.8, function() -- let the zombie body load so the card shows it
			onAnnounce("Infected", {})
		end)
	end
	lastRole = role
end

function AnnouncementController.start()
	build()
	Remotes.get("Announce").OnClientEvent:Connect(onAnnounce)
	Remotes.get("RoundStateChanged").OnClientEvent:Connect(onState)
	RunService.RenderStepped:Connect(animate)
end

return AnnouncementController
