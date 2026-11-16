--!strict
-- Brings the Relay Station 9 safehouse to life on your own screen (design-safehouse.md §3.5, §5).
-- Everything here is local: other players never see your scares, and nothing collides or hurts.
--   * The room breathes: the drum fire's light wavers, the jars glow and fade, the CRT shimmers,
--     the hanging bulb dips now and then, the shop's green tube stutters.
--   * The scare director (Rules/LobbyScares): every 35-70s one small scare (a bang on the boards and
--     a hand between the planks, the bulb dimming, dust sifting down as footsteps cross the ceiling,
--     the door wheel turning by itself, eyes in the boards, the Tall One in the moonbeam), each with
--     a caption. Never while a panel is open, never in your first 20s, never in the final countdown.
--   * The countdown: at 10s the door bulb pulses; at 5s the bulb settles dim, candles gutter and
--     breath fogs at the door; at 3s the door handle rattles; at the end the door swings open into fog.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Remotes = require(Shared.Net.Remotes)
local LobbyScares = require(Shared.Rules.LobbyScares)

local Room = require(script.Parent.Room)

local SafehouseController = {}

local player = Players.LocalPlayer
local SAFEHOUSE_HEIGHT = 200 -- the safehouse floats at y 300, the maps are below

local view = { phase = "Waiting", timeLeft = 0 }
local viewStamp = os.clock()
local joinedAt = os.clock()

local function timeLeft(): number
	return math.max(0, (view.timeLeft or 0) - (os.clock() - viewStamp))
end

local function inSafehouse(): boolean
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return root ~= nil and root.Position.Y > SAFEHOUSE_HEIGHT
end

--------------------------------------------------------------------------- captions

local caption: TextLabel

local function makeCaptions()
	local gui = Instance.new("ScreenGui")
	gui.Name = "SafehouseCaptions"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")
	caption = Instance.new("TextLabel")
	caption.AnchorPoint = Vector2.new(0.5, 1)
	caption.Position = UDim2.fromScale(0.5, 0.86)
	caption.Size = UDim2.fromOffset(520, 28)
	caption.BackgroundTransparency = 1
	caption.Font = Enum.Font.GothamMedium
	caption.TextSize = 18
	caption.TextColor3 = Color3.fromRGB(214, 206, 230)
	caption.TextStrokeTransparency = 0.6
	caption.TextTransparency = 1
	caption.TextStrokeTransparency = 1
	caption.Text = ""
	caption.Parent = gui
end

local function showCaption(text: string)
	caption.Text = text
	local fadeIn = TweenInfo.new(0.3)
	TweenService:Create(caption, fadeIn, { TextTransparency = 0, TextStrokeTransparency = 0.6 }):Play()
	task.delay(2.8, function()
		if caption.Text == text then
			TweenService
				:Create(caption, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 })
				:Play()
		end
	end)
end

--------------------------------------------------------------------------- the room's parts

type Parts = {
	lobby: Instance,
	bulb: BasePart,
	bulbLight: Light,
	fireLight: Light,
	doorBulbLight: Light,
	doorParts: { BasePart },
	wheelParts: { [BasePart]: boolean },
	hub: Vector3,
	hinge: Vector3,
	fog: BasePart,
	fogLight: Light,
	vapor: ParticleEmitter,
	candles: { Light },
	jars: { Light },
	crt: Light?,
	tube: BasePart,
	tubeLight: Light,
	windows: { Model },
	tallOne: { BasePart },
}

local P: Parts
local original: { [Instance]: { [string]: any } } = {}

-- Remembers a property's starting value so every effect can put it back.
local function remember(inst: Instance, prop: string)
	original[inst] = original[inst] or {}
	if original[inst][prop] == nil then
		original[inst][prop] = (inst :: any)[prop]
	end
end

local function restore(inst: Instance, prop: string)
	local saved = original[inst]
	if saved and saved[prop] ~= nil then
		(inst :: any)[prop] = saved[prop]
	end
end

local function findAll(root: Instance, name: string, class: string): { any }
	local out = {}
	for _, d in root:GetDescendants() do
		if d.Name == name and d:IsA(class) then
			table.insert(out, d)
		end
	end
	return out
end

local function gather(lobby: Instance): Parts?
	local function one(name: string): any
		return lobby:FindFirstChild(name, true)
	end
	local door = one("DeployDoor")
	local wheel = one("DoorWheel")
	local bulb = one("HearthBulb")
	local fog = one("DoorFog")
	local tube = one("ShopTube")
	if not (door and wheel and bulb and fog and tube) then
		return nil
	end
	local doorParts = {}
	for _, d in door:GetDescendants() do
		if d:IsA("BasePart") then
			table.insert(doorParts, d)
			remember(d, "CFrame")
		end
	end
	local wheelParts = {}
	for _, d in wheel:GetDescendants() do
		if d:IsA("BasePart") then
			wheelParts[d] = true
		end
	end
	local panel = door:FindFirstChild("DoorPanel") :: BasePart
	local hubPart = wheel:FindFirstChild("WheelHub") :: BasePart
	local tallParts = {}
	local tall = one("TallOne")
	if tall then
		for _, d in tall:GetDescendants() do
			if d:IsA("BasePart") then
				table.insert(tallParts, d)
			end
		end
	end
	local windows = {}
	for i = 1, 2 do
		local w = one(`Window{i}`)
		if w then
			table.insert(windows, w)
			for _, board in findAll(w, "Board", "BasePart") do
				remember(board, "CFrame")
			end
		end
	end
	local crtScreen = one("CRTScreen")
	return {
		lobby = lobby,
		bulb = bulb,
		bulbLight = bulb:FindFirstChildWhichIsA("Light"),
		fireLight = (one("DrumFire") :: any):FindFirstChildWhichIsA("Light"),
		doorBulbLight = (one("DoorBulb") :: any):FindFirstChildWhichIsA("Light"),
		doorParts = doorParts,
		wheelParts = wheelParts,
		hub = hubPart.Position,
		hinge = (panel.CFrame * CFrame.new(-panel.Size.X / 2, 0, 0)).Position,
		fog = fog,
		fogLight = fog:FindFirstChild("FogLight") :: Light,
		vapor = (one("DoorVapor") :: any):FindFirstChildWhichIsA("ParticleEmitter"),
		candles = findAll(lobby, "CandleLight", "Light"),
		jars = findAll(lobby, "JarLight", "Light"),
		crt = crtScreen and crtScreen:FindFirstChildWhichIsA("Light"),
		tube = tube,
		tubeLight = tube:FindFirstChildWhichIsA("Light") :: Light,
		windows = windows,
		tallOne = tallParts,
	}
end

--------------------------------------------------------------------------- the door

local doorOpen = 0 -- degrees the door has swung
local wheelTurn = 0 -- degrees the wheel lock has turned
local openedAt = 0

-- Puts every door part where the swing and the wheel say.
local function placeDoor()
	local hinge = CFrame.new(P.hinge)
	local swing = hinge * CFrame.Angles(0, math.rad(-doorOpen), 0) * hinge:Inverse()
	local hub = CFrame.new(P.hub)
	local spin = hub * CFrame.Angles(0, 0, math.rad(wheelTurn)) * hub:Inverse()
	for _, part in P.doorParts do
		local cf = original[part].CFrame :: CFrame
		if P.wheelParts[part] then
			cf = spin * cf
		end
		part.CFrame = swing * cf
	end
end

local function openDoor()
	openedAt = os.clock()
	local value = Instance.new("NumberValue")
	value.Value = 0
	value.Changed:Connect(function(v)
		doorOpen = v
		placeDoor()
	end)
	TweenService
		:Create(value, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = 100 })
		:Play()
	P.fogLight.Enabled = true
	remember(P.fog, "Transparency")
	P.fog.Transparency = 0.3
	task.delay(1.5, function()
		value:Destroy()
	end)
end

local function closeDoor()
	doorOpen = 0
	wheelTurn = 0
	placeDoor()
	P.fogLight.Enabled = false
	restore(P.fog, "Transparency")
end

--------------------------------------------------------------------------- scares

local scareBusy = false

local function windowBang()
	local win = P.windows[math.random(1, #P.windows)]
	if not win then
		return
	end
	local boards = findAll(win, "Board", "BasePart")
	local dust = win:FindFirstChild("BangDust", true) :: ParticleEmitter?
	for _ = 1, 3 do
		for _, b in boards do
			b.CFrame = (original[b].CFrame :: CFrame)
				* CFrame.new(0, 0, -0.25)
				* CFrame.Angles(0, 0, (math.random() - 0.5) * 0.06)
		end
		if dust then
			dust:Emit(10)
		end
		task.wait(0.1)
		for _, b in boards do
			restore(b, "CFrame")
		end
		task.wait(0.35)
	end
	-- a hand slides in between the planks, then withdraws
	local hand = win:FindFirstChild("ScareHand") :: BasePart?
	if hand then
		remember(hand, "CFrame")
		local start = original[hand].CFrame :: CFrame
		hand.Transparency = 0
		local reach =
			TweenService:Create(hand, TweenInfo.new(0.6), { CFrame = start * CFrame.new(0, 0, -0.9) })
		reach:Play()
		reach.Completed:Wait()
		task.wait(0.5)
		local back = TweenService:Create(hand, TweenInfo.new(0.4), { CFrame = start })
		back:Play()
		back.Completed:Wait()
		hand.Transparency = 1
	end
end

local function bulbDip()
	remember(P.bulbLight, "Brightness")
	remember(P.bulb, "Color")
	local full = original[P.bulbLight].Brightness :: number
	for _ = 1, 2 do
		P.bulbLight.Brightness = 0
		task.wait(0.07)
		P.bulbLight.Brightness = full
		task.wait(0.12)
	end
	P.bulbLight.Brightness = full * 0.2
	P.bulb.Color = Color3.fromRGB(120, 100, 60)
	task.wait(1.2)
	restore(P.bulbLight, "Brightness")
	restore(P.bulb, "Color")
end

-- Footsteps across the ceiling: dust sifts down, step by step, ending right above you.
local function footsteps()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local ceilingY = root.Position.Y + 12
	local target = Vector3.new(root.Position.X, ceilingY, root.Position.Z)
	local start = target + Vector3.new(-18, 0, -10)
	for step = 0, 5 do
		local spot = Instance.new("Part")
		spot.Anchored = true
		spot.CanCollide = false
		spot.CanQuery = false
		spot.Transparency = 1
		spot.Size = Vector3.new(1.5, 0.2, 1.5)
		spot.Position = start:Lerp(target, step / 5)
		local dust = Instance.new("ParticleEmitter")
		dust.Rate = 0
		dust.Lifetime = NumberRange.new(1.5, 2.5)
		dust.Speed = NumberRange.new(0.5, 1.5)
		dust.EmissionDirection = Enum.NormalId.Bottom
		dust.Acceleration = Vector3.new(0, -3, 0)
		dust.Size = NumberSequence.new(0.12)
		dust.Color = ColorSequence.new(Color3.fromRGB(130, 124, 116))
		dust.Parent = spot
		spot.Parent = workspace
		dust:Emit(8)
		task.delay(3, function()
			spot:Destroy()
		end)
		task.wait(0.6)
	end
end

local function doorTest()
	for _ = 1, 10 do
		wheelTurn += 1
		placeDoor()
		task.wait(0.03)
	end
	for _ = 1, 3 do
		for _, part in P.doorParts do
			part.CFrame = part.CFrame * CFrame.new((math.random() - 0.5) * 0.12, 0, 0)
		end
		task.wait(0.06)
		placeDoor()
	end
	task.wait(0.6)
	for _ = 1, 10 do
		wheelTurn -= 1
		placeDoor()
		task.wait(0.08)
	end
end

local function eyes()
	local win = P.windows[math.random(1, #P.windows)]
	if not win then
		return
	end
	local found = findAll(win, "ScareEye", "BasePart")
	for _, e in found do
		e.Transparency = 0
	end
	task.wait(2)
	for _, e in found do
		e.Transparency = 1
	end
end

local function tallOne()
	for _, p in P.tallOne do
		p.Transparency = 0
	end
	task.wait(2)
	for _, p in P.tallOne do
		p.Transparency = 1
	end
end

local SCARES: { [string]: () -> () } = {
	windowBang = windowBang,
	bulbDip = bulbDip,
	footsteps = footsteps,
	doorTest = doorTest,
	eyes = eyes,
	tallOne = tallOne,
}

local function startDirector()
	task.spawn(function()
		while true do
			task.wait(LobbyScares.gap(math.random()))
			local ok = LobbyScares.allowed({
				inSafehouse = inSafehouse(),
				panelOpen = Room.anyOpen(),
				sinceJoin = os.clock() - joinedAt,
				stage = LobbyScares.stage(view.phase, timeLeft()),
			})
			if ok and not scareBusy and doorOpen == 0 then
				local event = LobbyScares.pick(math.random())
				scareBusy = true
				showCaption(event.caption)
				local done, err = pcall(SCARES[event.id])
				if not done then
					warn("[Safehouse] scare failed:", err)
				end
				scareBusy = false
			end
		end
	end)
end

--------------------------------------------------------------------------- the room breathing + the countdown

-- The shop's tube light stutters now and then (under 3 flickers a second).
local function startTubeStutter()
	task.spawn(function()
		while true do
			task.wait(math.random(20, 60))
			for _ = 1, 2 do
				P.tubeLight.Enabled = false
				P.tube.Transparency = 0.6
				task.wait(0.08)
				P.tubeLight.Enabled = true
				P.tube.Transparency = 0
				task.wait(0.3)
			end
		end
	end)
end

local function startBreathing()
	for _, l in { P.fireLight, P.doorBulbLight, P.bulbLight } do
		remember(l, "Brightness")
	end
	for _, l in P.candles do
		remember(l, "Brightness")
	end
	for _, l in P.jars do
		remember(l, "Brightness")
	end
	if P.crt then
		remember(P.crt, "Brightness")
	end
	local lastStage = "calm"
	RunService.Heartbeat:Connect(function()
		local t = os.clock()
		-- the fire wavers (smooth noise, not a flicker)
		P.fireLight.Brightness = (original[P.fireLight].Brightness :: number) + math.noise(t * 3, 0.5) * 0.5
		for i, l in P.jars do
			l.Brightness = (original[l].Brightness :: number) * (0.6 + 0.4 * math.sin(t * 0.8 + i * 2))
		end
		if P.crt then
			P.crt.Brightness = (original[P.crt].Brightness :: number) * (0.7 + 0.3 * math.noise(t * 8, 1.5))
		end
		-- the countdown
		local stage = LobbyScares.stage(view.phase, timeLeft())
		if stage ~= "calm" then
			local full = original[P.doorBulbLight].Brightness :: number
			P.doorBulbLight.Brightness = full * (0.4 + 0.6 * math.abs(math.sin(t * math.pi)))
		end
		if stage ~= lastStage then
			if stage == "five" or stage == "three" then
				P.bulbLight.Brightness = (original[P.bulbLight].Brightness :: number) * 0.6
				for _, l in P.candles do
					l.Brightness = (original[l].Brightness :: number) * 0.4
				end
				P.vapor.Enabled = true
			elseif stage == "calm" then
				restore(P.doorBulbLight, "Brightness")
				restore(P.bulbLight, "Brightness")
				for _, l in P.candles do
					restore(l, "Brightness")
				end
				P.vapor.Enabled = false
			end
			lastStage = stage
		end
		if stage == "three" and doorOpen == 0 then
			-- the handle rattles: something on the other side wants in
			wheelTurn = -25 * math.abs(math.sin(t * 9))
			placeDoor()
		end
		if view.phase == "Intermission" and timeLeft() <= LobbyScares.DOOR_OPENS_AT and doorOpen == 0 then
			openDoor()
		end
		-- once the round is under way, the door closes behind the fog
		if doorOpen > 0 and view.phase ~= "Intermission" and t - openedAt > 4 then
			closeDoor()
		end
	end)
end

function SafehouseController.start()
	makeCaptions()
	Remotes.get("RoundStateChanged").OnClientEvent:Connect(function(newView: any)
		view = newView
		viewStamp = os.clock()
	end)
	local lobby = workspace:WaitForChild("Lobby", 60)
	if not lobby then
		return
	end
	local parts = gather(lobby)
	if not parts then
		warn("[Safehouse] this lobby has none of the Relay Station props; no scares")
		return
	end
	P = parts
	startBreathing()
	startTubeStutter()
	startDirector()
end

return SafehouseController
