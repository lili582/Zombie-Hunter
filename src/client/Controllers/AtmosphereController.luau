--!strict
-- The weather and the little scares, drawn on each player's own screen:
--   * rain or drizzle falling around you (it stops when there is a roof over your head),
--   * a low mist hugging the ground at ankle height,
--   * the camera shaking when thunder strikes (the server flashes the sky and kills the lights),
--   * now and then a shadow figure standing on a roof edge or at the end of a corridor, off to
--     the side of where you're looking. Look straight at it and it's gone.
-- The map's lighting preset says which weather (workspace attributes Weather / GroundFog), and
-- each map tags the spots a figure may stand on (ScareSpot). Nothing here up in the safehouse.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Scares = require(Shared.Rules.Scares)

local AtmosphereController = {}

local player = Players.LocalPlayer
local LOBBY_HEIGHT = 200 -- the safehouse floats at y 300: no weather or figures up there
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local RAIN_RATE = { None = 0, Drizzle = 260, Rain = 720 }
local FIGURE_LIFETIME = 14

local localParts: { Instance } = {}

local function root(): BasePart?
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function onMap(): BasePart?
	local r = root()
	if r and r.Position.Y < LOBBY_HEIGHT then
		return r
	end
	return nil
end

local function emitterPart(name: string, size: Vector3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = size
	p.Parent = workspace
	table.insert(localParts, p)
	return p
end

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore = table.clone(localParts)
	if player.Character then
		table.insert(ignore, player.Character)
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = true
	return params
end

--------------------------------------------------------------------------- weather

local function makeRain(): ParticleEmitter
	local rain = Instance.new("ParticleEmitter")
	rain.Texture = SMOKE
	rain.EmissionDirection = Enum.NormalId.Bottom
	rain.Orientation = Enum.ParticleOrientation.VelocityParallel
	rain.Speed = NumberRange.new(80, 95)
	rain.Lifetime = NumberRange.new(0.6, 0.8)
	rain.Size = NumberSequence.new(0.12)
	rain.Squash = NumberSequence.new(-3) -- long thin streaks
	rain.SpreadAngle = Vector2.new(4, 4)
	rain.Acceleration = Vector3.new(3, 0, 1.5) -- a little wind
	rain.Transparency = NumberSequence.new(0.5)
	rain.Color = ColorSequence.new(Color3.fromRGB(176, 188, 204))
	rain.LightInfluence = 1
	rain.LightEmission = 0.1
	rain.Rate = 0
	rain.Parent = emitterPart("ZH_Rain", Vector3.new(110, 1, 110))
	return rain
end

local function makeGroundFog(): ParticleEmitter
	local fog = Instance.new("ParticleEmitter")
	fog.Texture = SMOKE
	fog.EmissionDirection = Enum.NormalId.Top
	fog.Speed = NumberRange.new(0.2, 0.8)
	fog.SpreadAngle = Vector2.new(80, 80)
	fog.Lifetime = NumberRange.new(7, 11)
	fog.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 5),
		NumberSequenceKeypoint.new(1, 9),
	})
	fog.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.86),
		NumberSequenceKeypoint.new(0.7, 0.88),
		NumberSequenceKeypoint.new(1, 1),
	})
	fog.Rotation = NumberRange.new(0, 360)
	fog.RotSpeed = NumberRange.new(-8, 8)
	fog.Acceleration = Vector3.new(0.4, -0.06, 0.2)
	fog.Color = ColorSequence.new(Color3.fromRGB(150, 160, 170))
	fog.LightInfluence = 0.8
	fog.Rate = 0
	fog.Parent = emitterPart("ZH_GroundFog", Vector3.new(120, 1, 120))
	return fog
end

-- Keeps the rain above the camera and the mist on the ground under you. Checks for a roof
-- a few times a second.
local function startWeather()
	local rain = makeRain()
	local fog = makeGroundFog()
	local rainPart = rain.Parent :: BasePart
	local fogPart = fog.Parent :: BasePart
	local covered = false
	local groundY = 0
	local nextCheck = 0
	RunService.RenderStepped:Connect(function()
		local r = onMap()
		local camera = workspace.CurrentCamera
		if not r or not camera then
			rain.Rate = 0
			fog.Rate = 0
			return
		end
		local now = os.clock()
		if now >= nextCheck then
			nextCheck = now + 0.3
			local params = rayParams()
			covered = workspace:Raycast(camera.CFrame.Position, Vector3.new(0, 120, 0), params) ~= nil
			local down = workspace:Raycast(r.Position, Vector3.new(0, -30, 0), params)
			groundY = if down then down.Position.Y else r.Position.Y - 3
		end
		local weather = workspace:GetAttribute("Weather")
		local rate = RAIN_RATE[if type(weather) == "string" then weather else "None"] or 0
		rain.Rate = if covered then 0 else rate
		local look = camera.CFrame.LookVector
		rainPart.CFrame = CFrame.new(camera.CFrame.Position + Vector3.new(look.X * 20, 45, look.Z * 20))
		local density = workspace:GetAttribute("GroundFog")
		fog.Rate = if type(density) == "number" then 70 * density else 0
		fogPart.CFrame = CFrame.new(r.Position.X, groundY + 0.3, r.Position.Z)
	end)
end

-- Thunder: a short, heavy shake of the camera.
local function startThunderShake()
	workspace:GetAttributeChangedSignal("LastThunder"):Connect(function()
		local r = onMap()
		local humanoid = r and player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if not humanoid then
			return
		end
		local started = os.clock()
		local conn
		conn = RunService.RenderStepped:Connect(function()
			local t = os.clock() - started
			if t > 0.8 or humanoid.Parent == nil then
				humanoid.CameraOffset = Vector3.zero
				conn:Disconnect()
				return
			end
			local amp = 0.35 * (1 - t / 0.8)
			humanoid.CameraOffset = Vector3.new(
				(math.random() - 0.5) * amp,
				(math.random() - 0.5) * amp,
				(math.random() - 0.5) * amp
			)
		end)
	end)
end

--------------------------------------------------------------------------- the figure

local SHADOW = Color3.fromRGB(10, 10, 12)

-- A tall, thin shadow of a person, arms hanging too long, head a little tilted, facing you.
local function buildFigure(feet: Vector3, faceTowards: Vector3): Model
	local figure = Instance.new("Model")
	figure.Name = "ZH_Figure"
	local base = CFrame.lookAt(feet, Vector3.new(faceTowards.X, feet.Y, faceTowards.Z))
	local function limb(size: Vector3, offset: CFrame, color: Color3?, neon: boolean?)
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Size = size
		p.CFrame = base * offset
		p.Color = color or SHADOW
		p.Material = if neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
		p.Parent = figure
		return p
	end
	limb(Vector3.new(0.8, 2.8, 0.8), CFrame.new(-0.5, 1.4, 0))
	limb(Vector3.new(0.8, 2.8, 0.8), CFrame.new(0.5, 1.4, 0))
	limb(Vector3.new(1.9, 2.6, 0.9), CFrame.new(0, 4.1, 0))
	limb(Vector3.new(0.6, 3.6, 0.6), CFrame.new(-1.3, 3.5, 0) * CFrame.Angles(0, 0, math.rad(-6)))
	limb(Vector3.new(0.6, 3.6, 0.6), CFrame.new(1.3, 3.5, 0) * CFrame.Angles(0, 0, math.rad(6)))
	local head = limb(Vector3.new(1.1, 1.3, 1.1), CFrame.new(0.1, 6.1, 0) * CFrame.Angles(0, 0, math.rad(14)))
	for _, x in { -0.25, 0.25 } do
		local eye = Instance.new("Part")
		eye.Anchored = true
		eye.CanCollide = false
		eye.CanQuery = false
		eye.Size = Vector3.new(0.14, 0.1, 0.05)
		eye.CFrame = head.CFrame * CFrame.new(x, 0.1, -0.56)
		eye.Color = Color3.fromRGB(210, 214, 200)
		eye.Material = Enum.Material.Neon
		eye.Parent = figure
	end
	figure.Parent = workspace
	return figure
end

local function spotPositions(): { Vector3 }
	local spots = {}
	local map = workspace:FindFirstChild("Map")
	for _, inst in CollectionService:GetTagged("ScareSpot") do
		if inst:IsA("BasePart") and map and inst:IsDescendantOf(map) then
			table.insert(spots, inst.Position)
		end
	end
	return spots
end

local function showFigure(spot: Vector3)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	-- stand it on whatever is under the spot (a roof, the floor, a hill)
	local down = workspace:Raycast(spot + Vector3.new(0, 6, 0), Vector3.new(0, -40, 0), rayParams())
	local feet = if down then down.Position else spot
	local figure = buildFigure(feet, camera.CFrame.Position)
	local head = feet + Vector3.new(0, Scares.FIGURE_HEAD, 0)
	local born = os.clock()
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local r = onMap()
		local cam = workspace.CurrentCamera
		local gone = not r or not cam or os.clock() - born > FIGURE_LIFETIME
		if not gone and r and cam then
			local eye = cam.CFrame.Position
			if (r.Position - feet).Magnitude < 20 then
				gone = true -- walked right up to it: it isn't there
			elseif Scares.isSeen(eye, cam.CFrame.LookVector, feet) then
				local params = rayParams()
				local ignore = params.FilterDescendantsInstances
				table.insert(ignore, figure)
				params.FilterDescendantsInstances = ignore
				gone = workspace:Raycast(eye, head - eye, params) == nil -- nothing in between: you saw it
			end
		end
		if gone then
			conn:Disconnect()
			figure:Destroy()
		end
	end)
end

local function startFigures()
	task.spawn(function()
		while true do
			task.wait(Scares.figureDelay(math.random()))
			local camera = workspace.CurrentCamera
			if onMap() and camera then
				local spot = Scares.pickSpot(
					spotPositions(),
					camera.CFrame.Position,
					camera.CFrame.LookVector,
					math.random()
				)
				if spot then
					showFigure(spot :: any)
				end
			end
		end
	end)
end

function AtmosphereController.start()
	startWeather()
	startThunderShake()
	startFigures()
end

return AtmosphereController
