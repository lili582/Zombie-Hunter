--!strict
-- Full-screen cards (round start / end) and top banners (mid-round). Horror style:
-- VHS scanlines, flicker, glitching text, typed subtitles, and the players' own characters
-- shown as black silhouettes in the dark while roles are "chosen". No emoji, no names leaked.
-- Card times for the intro must add up to Classic.introLength (16s).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Theme = require(script.Parent.Theme)

local C = Theme.colors
local player = Players.LocalPlayer

local AnnouncementController = {}

local CARD_TIME = {
	-- intro (16s total)
	Map = 2.5,
	Mode = 2.5,
	SomeoneInfected = 4,
	YourRole = 3.5,
	YourRules = 2,
	HunterChosen = 1.5,
	EveryoneArmed = 1.5, -- replaces HunterChosen in modes without a Hunter
	-- round end / other
	Result = 3,
	YourCoins = 2,
	Infected = 2.5,
	Escaped = 3,
}
local BANNERS = {
	AlphaAwakened = true,
	HunterFallen = true,
	NewHunter = true,
	TowerRepaired = true,
	HeliIncoming = true,
	HeliHere = true,
	AlphaPicked = true,
}

local ROLE_TITLE = {
	Survivor = "YOU ARE A SURVIVOR",
	Hunter = "YOU ARE THE HUNTER",
	Alpha = "YOU ARE THE ALPHA ZOMBIE",
	Zombie = "YOU ARE A ZOMBIE",
}
local ROLE_RULES = {
	Survivor = "No weapons  -  Repair 3 radio towers  -  Hide in lockers  -  Revive friends\nZombie attack? CLICK IN TIME to escape!",
	Hunter = "Your role is SECRET  -  Only you have a gun\nProtect the survivors  -  Ammo boxes  -  [R] reload",
	Alpha = "You look like them. Blend in.\nClaws wake up at release  -  every attack shows your face for 3s",
	Zombie = "Infect everyone  -  3 hits downs a human",
}
-- Rules that change in a mode (role -> text)
local MODE_RULES = {
	Outbreak = {
		Survivor = "You have a PISTOL  -  [R] reload  -  Survive 4:00\nZombie attack? CLICK IN TIME to escape!",
		Alpha = "There are more of you. Blend in.\nClaws wake up at release  -  every attack shows your face",
	},
}
local RESULT_TEXT = {
	SurvivorsSurvived = { "SURVIVORS SURVIVED!", C.baby },
	SurvivorsEscaped = { "SURVIVORS ESCAPED!", C.baby },
	ZombiesWin = { "ZOMBIES WIN!", C.mint },
	NoWinner = { "NOBODY WINS", C.lavender },
}

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

local function typeText(label: TextLabel, text: string, perChar: number, token: number)
	task.spawn(function()
		label.Text = ""
		for i = 1, #text do
			if cardToken ~= token then
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

local function clearStage()
	ui.big.Visible = false
	ui.big:ClearAllChildren()
	ui.row.Visible = false
	for _, child in ui.row:GetChildren() do
		if child:IsA("ViewportFrame") then
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
		setTitle("SOMEONE IS INFECTED...", C.blood)
		slam()
		local frames = silhouetteRow()
		-- a red light jumps between the silhouettes, slower and slower... then goes out.
		-- It never stops on anyone: the Alpha stays secret.
		task.spawn(function()
			if #frames == 0 then
				return
			end
			local last = 0
			for i = 1, 16 do
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
					vp.BackgroundTransparency = if j == pick then 0.2 else 0.6
				end
				task.wait(0.06 + i * 0.012)
			end
			for _, vp in frames do
				vp.LightColor = Color3.new(0, 0, 0)
				vp.Ambient = Color3.new(0, 0, 0)
				vp.BackgroundTransparency = 0.85
			end
			doFlash(Color3.new(0, 0, 0), 1)
			typeText(ui.subtitle, "...and it could be you.", 0.05, token)
		end)
	elseif name == "YourRole" then
		local role = data.role
		local color = Theme.roleColor[role] or C.bone
		setTitle("", color)
		local model = cloneCharacter(player)
		if model then
			stage(ui.big, model)
			ui.big.Visible = true
		end
		ui.subtitle.Text = "who are you?"
		-- heartbeat in the dark, the light stutters on, then the reveal
		task.spawn(function()
			for beat = 1, 3 do
				if cardToken ~= token then
					return
				end
				ui.big.Size = UDim2.fromScale(0.28, 0.54)
				TweenService:Create(ui.big, TweenInfo.new(0.25), { Size = UDim2.fromScale(0.26, 0.5) }):Play()
				if beat == 3 then
					for _ = 1, 3 do -- flicker
						ui.big.LightColor = color
						ui.big.Ambient = Color3.fromRGB(50, 40, 60)
						task.wait(0.05)
						ui.big.LightColor = Color3.new(0, 0, 0)
						ui.big.Ambient = Color3.new(0, 0, 0)
						task.wait(0.07)
					end
				end
				task.wait(0.4)
			end
			if cardToken ~= token then
				return
			end
			ui.big.LightColor = color
			ui.big.Ambient = Color3.fromRGB(55, 45, 70)
			ui.subtitle.Text = ""
			setTitle(ROLE_TITLE[role] or "", color)
			slam()
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
		typeText(ui.subtitle, rules, 0.015, token)
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
	elseif name == "Result" then
		local r = RESULT_TEXT[data.winner] or RESULT_TEXT.NoWinner
		setTitle(r[1], r[2])
		slam()
		doFlash(r[2], 0.4)
	elseif name == "YourCoins" then
		setTitle(`+{data.coins} Z-COINS`, C.butter)
		slam()
		typeText(ui.subtitle, `{data.points} points this round`, 0.03, token)
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
			ui.big.LightColor = C.mint
			ui.big.Ambient = Color3.fromRGB(20, 60, 35)
			ui.big.Visible = true
		end
		typeText(ui.subtitle, "You're one of them now. Keep scoring points.", 0.03, token)
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

	-- the character sways slowly, as if breathing
	local model = ui.big:FindFirstChildOfClass("Model")
	if ui.big.Visible and model then
		model:PivotTo(CFrame.Angles(0, math.sin(t * 0.7) * 0.5, 0))
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
			ui.card.Visible = true
			play(item.card, item.data or {}, cardToken)
			task.wait(CARD_TIME[item.card] or 2)
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
		text = "THE HUNTER HAS FALLEN - GRAB THE GUN!"
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
