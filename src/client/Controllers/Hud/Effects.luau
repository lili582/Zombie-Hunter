--!strict
-- Short-lived effects: "+points" popups, gun tracers, the zombies' noise pings and scream
-- glow, and the role tint at the screen edges.
local Theme = require(script.Parent.Parent.Theme)

local C = Theme.colors

local Effects = {}

local ui: { [string]: any } = {} -- the HUD's shared widget table (set in build)

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

function Effects.build(gui: ScreenGui, widgets: { [string]: any })
	ui = widgets
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

	-- "+points" popups
	local popups = Instance.new("Frame")
	popups.BackgroundTransparency = 1
	popups.AnchorPoint = Vector2.new(1, 1)
	popups.Position = UDim2.new(1, -16, 1, -150)
	popups.Size = UDim2.fromOffset(260, 160)
	popups.Parent = gui
	ui.popups = popups
end

-- Every frame: draw from the latest round snapshot.
function Effects.render(frame: any)
	local role, inRound = frame.role, frame.inRound
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

Effects.noisePing = noisePing
Effects.revealHumans = revealHumans
Effects.popup = popup
Effects.tracer = tracer

return Effects
