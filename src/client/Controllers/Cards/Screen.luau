--!strict
-- The full-screen card: its look (black screen, drifting fog, VHS scanlines, flicker, glitching
-- title, typed subtitles) and the tools every card uses: titles, flashes, typing, the 3D stage for
-- characters, the silhouette row and your role emote. One card at a time: `begin` gives each card
-- a token, and anything still running for an old card stops when the token moves on.
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Parent.Theme)
local CharacterCopy = require(script.Parent.Parent.CharacterCopy)
local RoleEmote = require(script.Parent.Parent.RoleEmote)

local C = Theme.colors
local player = Players.LocalPlayer

local Screen = {}

local BLOOD_DARK = Color3.fromRGB(60, 8, 22)

local gui: ScreenGui
local ui: { [string]: any } = {}
local glitching = false
local cardToken = 0 -- bumps every card so old animations stop
Screen.ui = ui

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
end

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
		local model = CharacterCopy.of(list[i])
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

-- Is this card still the one on screen?
function Screen.isCurrent(token: number): boolean
	return token == cardToken
end

-- A new card: blank screen, nothing typed yet. Returns the card's token.
function Screen.begin(): number
	cardToken += 1
	textDoneAt = 0
	clearStage()
	ui.kicker.Text = ""
	ui.subtitle.Text = ""
	ui.card.BackgroundColor3 = Color3.new(0, 0, 0)
	ui.fog.BackgroundTransparency = 0.2
	ui.card.Visible = true
	return cardToken
end

-- All cards done: hide the screen and stop anything still running.
function Screen.finish()
	cardToken += 1
	clearStage()
	ui.card.Visible = false
end

-- Has the text on the current card finished typing, plus a moment to read it?
function Screen.isRead(): boolean
	return os.clock() >= textDoneAt + READ_HOLD
end

function Screen.build(): ScreenGui
	build()
	return gui
end

Screen.animate = animate
Screen.setTitle = setTitle
Screen.slam = slam
Screen.flash = doFlash
Screen.typeText = typeText
Screen.stage = stage
Screen.playEmote = playEmote
Screen.silhouetteRow = silhouetteRow

return Screen
