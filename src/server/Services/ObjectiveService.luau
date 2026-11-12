--!strict
-- Phase 2 in the world: radio towers (repair prompts, skill checks, range checks), the rescue
-- helicopter (zone marker, landing, escape detection) and lockers (hide / search / leave).
-- All decisions are made by the rules (Objectives / Survival); this only turns Roblox input
-- into rule events and rule effects into things you can see.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Classic = require(Shared.Config.Classic)
local Weapons = require(Shared.Config.Weapons)
local Remotes = require(Shared.Net.Remotes)
local Services = script.Parent
local TimingService = require(Services.TimingService)
local CharacterService = require(Services.CharacterService)

local ObjectiveService = {}

type Round = { getState: () -> any, send: (event: any) -> () }
type MapInfo = {
	towerSpots: { CFrame },
	heliZones: { CFrame },
	lockers: { BasePart },
	lobbySpawn: CFrame,
}

local round: Round
local map: MapInfo
local roundFolder: Folder? = nil -- towers + heli of the current round
local towerModels: { [number]: Model } = {}
local heliModel: Model? = nil
local heliMarker: BasePart? = nil
local nextSkillCheck: { [Player]: number } = {}
local hiddenLooks: { [Player]: { [Instance]: number } } = {}

local BEACON = Color3.fromRGB(255, 60, 80)
local DONE = Color3.fromRGB(163, 234, 200) -- mint

local function part(
	parent: Instance,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.Metal
	p.TopSurface = Enum.SurfaceType.Studs
	p.Parent = parent
	return p
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function stateOf(player: Player): any
	return round.getState().players[player.UserId]
end

----------------------------------------------------------------------------- towers

local function buildTower(towerId: number, at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "RadioTower" .. towerId
	local base = at.Position
	part(model, Vector3.new(7, 1, 7), CFrame.new(base + Vector3.new(0, 0.5, 0)), Color3.fromRGB(50, 48, 52))
	for _, o in { Vector3.new(-2, 0, -2), Vector3.new(2, 0, -2), Vector3.new(-2, 0, 2), Vector3.new(2, 0, 2) } do
		local leg = part(
			model,
			Vector3.new(0.5, 26, 0.5),
			CFrame.new(base + o * 0.6 + Vector3.new(0, 13.5, 0)),
			Color3.fromRGB(80, 76, 84)
		)
		leg.TopSurface = Enum.SurfaceType.Smooth
	end
	for y = 5, 25, 5 do
		part(
			model,
			Vector3.new(3, 0.3, 0.3),
			CFrame.new(base + Vector3.new(0, y, 0)),
			Color3.fromRGB(80, 76, 84)
		)
		part(
			model,
			Vector3.new(0.3, 0.3, 3),
			CFrame.new(base + Vector3.new(0, y, 0)),
			Color3.fromRGB(80, 76, 84)
		)
	end
	local box = part(
		model,
		Vector3.new(3, 3, 2),
		CFrame.new(base + Vector3.new(0, 2.5, 0)),
		Color3.fromRGB(60, 70, 64)
	)
	box.Name = "RadioBox"
	-- the beacon: blinks red, seen through the fog (the compass of the map)
	local beacon = part(
		model,
		Vector3.new(1.4, 1.4, 1.4),
		CFrame.new(base + Vector3.new(0, 27.5, 0)),
		BEACON,
		Enum.Material.Neon
	)
	beacon.Name = "Beacon"
	beacon.Shape = Enum.PartType.Ball
	local light = Instance.new("PointLight")
	light.Color = BEACON
	light.Range = 10
	light.Brightness = 3
	light.Parent = beacon
	local far = Instance.new("BillboardGui")
	far.Name = "FarBeacon"
	far.AlwaysOnTop = true
	far.Size = UDim2.fromOffset(10, 10)
	far.MaxDistance = 170
	local dot = Instance.new("Frame")
	dot.Size = UDim2.fromScale(1, 1)
	dot.BackgroundColor3 = BEACON
	dot.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = dot
	dot.Parent = far
	far.Parent = beacon
	task.spawn(function() -- blinks red until repaired, then glows mint
		while beacon.Parent do
			light.Enabled = true
			dot.BackgroundTransparency = 0
			beacon.Transparency = 0
			task.wait(0.6)
			if beacon.Color ~= DONE then
				light.Enabled = false
				dot.BackgroundTransparency = 0.7
				beacon.Transparency = 0.6
				task.wait(0.6)
			end
		end
	end)

	-- progress bar above the radio box (only up close)
	local bar = Instance.new("BillboardGui")
	bar.Name = "Progress"
	bar.Size = UDim2.fromOffset(90, 12)
	bar.StudsOffset = Vector3.new(0, 3, 0)
	bar.MaxDistance = 35
	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = Color3.fromRGB(27, 20, 40)
	back.BorderSizePixel = 0
	back.Parent = bar
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = DONE
	fill.BorderSizePixel = 0
	fill.Parent = back
	bar.Parent = box

	-- hold to repair (the hold never "completes": progress comes from the rules)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "RepairPrompt"
	prompt.ActionText = "Repair (hold)"
	prompt.ObjectText = "Radio tower"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 100000
	prompt.MaxActivationDistance = 8
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("TowerId", towerId)
	CollectionService:AddTag(prompt, "RepairPrompt")
	prompt.Parent = box
	prompt.PromptButtonHoldBegan:Connect(function(player)
		round.send({ type = "RepairStart", playerId = player.UserId, towerId = towerId })
	end)
	prompt.PromptButtonHoldEnded:Connect(function(player)
		round.send({ type = "RepairStop", playerId = player.UserId })
	end)
	return model
end

local function towerPosition(towerId: number): Vector3?
	local model = towerModels[towerId]
	local box = model and model:FindFirstChild("RadioBox") :: BasePart?
	return if box then box.Position else nil
end

----------------------------------------------------------------------------- helicopter

local function buildHeli(at: Vector3): Model
	local model = Instance.new("Model")
	model.Name = "Helicopter"
	local body = part(model, Vector3.new(8, 6, 14), CFrame.new(at), Color3.fromRGB(40, 50, 44))
	body.Name = "Body"
	part(model, Vector3.new(2, 2, 12), CFrame.new(at + Vector3.new(0, 1, 12)), Color3.fromRGB(40, 50, 44))
	part(
		model,
		Vector3.new(7.6, 3, 0.2),
		CFrame.new(at + Vector3.new(0, 1, -7)),
		Color3.fromRGB(160, 190, 210),
		Enum.Material.Glass
	)
	local rotor = part(
		model,
		Vector3.new(28, 0.3, 1.2),
		CFrame.new(at + Vector3.new(0, 3.8, 0)),
		Color3.fromRGB(25, 25, 25)
	)
	rotor.Name = "Rotor"
	for _, x in { -5, 5 } do
		part(
			model,
			Vector3.new(0.4, 0.4, 12),
			CFrame.new(at + Vector3.new(x * 0.6, -3.4, 0)),
			Color3.fromRGB(25, 25, 25)
		)
	end
	local search = Instance.new("SpotLight")
	search.Face = Enum.NormalId.Bottom
	search.Range = 60
	search.Angle = 40
	search.Brightness = 6
	search.Color = Color3.fromRGB(255, 240, 200)
	search.Parent = body
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide = false
		end
	end
	model.PrimaryPart = body
	task.spawn(function()
		while rotor.Parent do
			rotor.CFrame *= CFrame.Angles(0, math.rad(35), 0)
			task.wait(0.03)
		end
	end)
	return model
end

local function placeZoneMarker(at: Vector3, parent: Instance)
	local ring = part(
		parent,
		Vector3.new(0.4, Classic.heliZoneRadius * 2, Classic.heliZoneRadius * 2),
		CFrame.new(at + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(255, 224, 138),
		Enum.Material.Neon
	)
	ring.Name = "HeliZone"
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.6
	ring.CanCollide = false
	ring.CanQuery = false
	local light = Instance.new("PointLight")
	light.Range = 30
	light.Brightness = 2
	light.Color = ring.Color
	light.Parent = ring
	local tag = Instance.new("BillboardGui")
	tag.AlwaysOnTop = true
	tag.Size = UDim2.fromOffset(140, 30)
	tag.StudsOffset = Vector3.new(0, 8, 0)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = "HELICOPTER"
	label.TextColor3 = ring.Color
	label.TextStrokeTransparency = 0
	label.Parent = tag
	tag.Parent = ring
	heliMarker = ring
end

local function heliCalled(zone: number)
	local cf = map.heliZones[zone]
	if not cf or not roundFolder then
		return
	end
	local ground = cf.Position
	placeZoneMarker(ground, roundFolder)
	-- the helicopter appears far up in the sky and slowly comes down
	local model = buildHeli(ground + Vector3.new(0, 160, 0))
	model.Parent = roundFolder
	heliModel = model
	local body = model.PrimaryPart :: BasePart
	local target = CFrame.new(ground + Vector3.new(0, 4, 0))
	local start = body.CFrame
	local duration = Classic.heliInbound
	task.spawn(function()
		local t0 = os.clock()
		while model.Parent and os.clock() - t0 < duration do
			local a = (os.clock() - t0) / duration
			model:PivotTo(start:Lerp(target, a * a * (3 - 2 * a))) -- ease in/out
			task.wait(0.05)
		end
		if model.Parent then
			model:PivotTo(target)
		end
	end)
end

local function heliLeft()
	local model = heliModel
	if heliMarker then
		heliMarker:Destroy()
		heliMarker = nil
	end
	if model then
		local from = model:GetPivot()
		task.spawn(function()
			for i = 1, 60 do
				if not model.Parent then
					return
				end
				model:PivotTo(from + Vector3.new(0, i * i * 0.08, 0))
				task.wait(0.05)
			end
			model:Destroy()
		end)
	end
	heliModel = nil
end

----------------------------------------------------------------------------- lockers

local function setHidden(player: Player, hidden: boolean, locker: BasePart?)
	local char = player.Character
	local root = rootOf(player)
	if not char or not root then
		return
	end
	if hidden and locker then
		local hum = char:FindFirstChildOfClass("Humanoid")
		if hum then
			hum:UnequipTools()
		end
		local saved = {}
		for _, d in char:GetDescendants() do
			if d:IsA("BasePart") or d:IsA("Decal") then
				saved[d] = (d :: any).Transparency;
				(d :: any).Transparency = 1
			elseif d:IsA("Light") then
				saved[d] = if d.Enabled then 1 else 0
				d.Enabled = false
			end
		end
		hiddenLooks[player] = saved
		root.Anchored = true
		root.CFrame = locker.CFrame
	else
		local saved = hiddenLooks[player]
		hiddenLooks[player] = nil
		if saved then
			for inst, value in saved do
				if inst.Parent then
					if inst:IsA("Light") then
						inst.Enabled = value == 1
					else
						(inst :: any).Transparency = value
					end
				end
			end
		end
		if locker then
			root.CFrame = locker.CFrame * CFrame.new(0, 0, -3.5) -- step out in front
		end
		root.Anchored = false
	end
end

local function setupLockers()
	for id, locker in map.lockers do
		locker:SetAttribute("LockerId", id)
		local hide = Instance.new("ProximityPrompt")
		hide.Name = "HidePrompt"
		hide.ActionText = "Hide"
		hide.ObjectText = "Locker"
		hide.KeyboardKeyCode = Enum.KeyCode.E
		hide.HoldDuration = 0.3
		hide.MaxActivationDistance = 6
		hide.RequiresLineOfSight = false
		CollectionService:AddTag(hide, "LockerHidePrompt")
		hide.Parent = locker
		hide.Triggered:Connect(function(player)
			round.send({ type = "LockerEnter", playerId = player.UserId, lockerId = id })
		end)

		local search = Instance.new("ProximityPrompt")
		search.Name = "SearchPrompt"
		search.ActionText = "Search"
		search.ObjectText = "Locker"
		search.KeyboardKeyCode = Enum.KeyCode.E
		search.HoldDuration = 1.5
		search.MaxActivationDistance = 6
		search.RequiresLineOfSight = false
		CollectionService:AddTag(search, "LockerSearchPrompt")
		search.Parent = locker
		search.Triggered:Connect(function(player)
			round.send({ type = "LockerSearch", attackerId = player.UserId, lockerId = id })
		end)
	end
	Remotes.get("LockerLeave").OnServerEvent:Connect(function(player)
		round.send({ type = "LockerExit", playerId = player.UserId })
	end)
end

----------------------------------------------------------------------------- round life

function ObjectiveService.cleanup()
	if roundFolder then
		roundFolder:Destroy()
		roundFolder = nil
	end
	towerModels = {}
	heliModel = nil
	heliMarker = nil
	table.clear(nextSkillCheck)
	for player in hiddenLooks do
		setHidden(player, false, nil)
	end
end

-- Builds this round's towers (the rules already picked which spots).
function ObjectiveService.setupRound(state: any)
	ObjectiveService.cleanup()
	local folder = Instance.new("Folder")
	folder.Name = "RoundObjectives"
	folder.Parent = workspace
	roundFolder = folder
	for towerId in state.towers do
		local cf = map.towerSpots[towerId]
		if cf then
			local model = buildTower(towerId, cf)
			model.Parent = folder
			towerModels[towerId] = model
		end
	end
end

function ObjectiveService.onEffect(f: any)
	if f.type == "RepairStarted" then
		local player = Players:GetPlayerByUserId(f.playerId)
		if player then
			local every = Weapons.Dodge.skillEvery
			nextSkillCheck[player] = os.clock() + math.random(every[1] * 10, every[2] * 10) / 10
		end
	elseif f.type == "RepairStopped" then
		local player = Players:GetPlayerByUserId(f.playerId)
		if player then
			nextSkillCheck[player] = nil
		end
	elseif f.type == "TowerRepaired" then
		local model = towerModels[f.towerId]
		if model then
			local beacon = model:FindFirstChild("Beacon") :: BasePart?
			if beacon then
				beacon.Color = DONE
				local light = beacon:FindFirstChildOfClass("PointLight")
				if light then
					light.Color = DONE
				end
				local far = beacon:FindFirstChild("FarBeacon")
				local dot = far and far:FindFirstChildOfClass("Frame")
				if dot then
					dot.BackgroundColor3 = DONE
				end
			end
			local box = model:FindFirstChild("RadioBox")
			local prompt = box and box:FindFirstChild("RepairPrompt") :: ProximityPrompt?
			if prompt then
				prompt:Destroy()
			end
		end
		for _, id in f.repairerIds do
			local player = Players:GetPlayerByUserId(id)
			if player then
				nextSkillCheck[player] = nil
			end
		end
	elseif f.type == "NoiseAlert" then
		local pos = towerPosition(f.towerId)
		if pos then
			for _, player in Players:GetPlayers() do
				local p = stateOf(player)
				if p and (p.role == "Alpha" or p.role == "Zombie") then
					Remotes.get("NoiseAlert"):FireClient(player, pos)
				end
			end
		end
	elseif f.type == "HeliCalled" then
		heliCalled(f.zone)
	elseif f.type == "HeliLeft" then
		heliLeft()
	elseif f.type == "EnteredLocker" then
		local player = Players:GetPlayerByUserId(f.playerId)
		if player then
			TimingService.cancel(player)
			setHidden(player, true, map.lockers[f.lockerId])
		end
	elseif f.type == "LeftLocker" then
		local player = Players:GetPlayerByUserId(f.playerId)
		if player then
			setHidden(player, false, map.lockers[f.lockerId])
		end
	elseif f.type == "Escaped" then
		local player = Players:GetPlayerByUserId(f.playerId)
		if player then
			nextSkillCheck[player] = nil
			TimingService.cancel(player)
			task.spawn(CharacterService.spawn, player, nil, map.lobbySpawn) -- safe in the safehouse
		end
	end
end

-- Called ~10 times a second by RoundManager during a round.
function ObjectiveService.tick()
	local state = round.getState()
	if state.phase ~= "Active" then
		return
	end
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local p = state.players[player.UserId]
		local root = rootOf(player)
		if not p or not root then
			continue
		end
		-- walked away from the tower: stop repairing
		if p.repairing ~= nil then
			local pos = towerPosition(p.repairing)
			if not pos or (root.Position - pos).Magnitude > Classic.repairRange then
				round.send({ type = "RepairStop", playerId = player.UserId })
			elseif (nextSkillCheck[player] or math.huge) <= now and not TimingService.isBusy(player) then
				local every = Weapons.Dodge.skillEvery
				nextSkillCheck[player] = now + math.random(every[1] * 10, every[2] * 10) / 10
				TimingService.start(player, "skill", function(ok)
					round.send({ type = "SkillCheck", playerId = player.UserId, success = ok })
				end)
			end
		end
		-- standing in the landed helicopter's zone: escape
		if state.heli.phase == "Landed" and heliMarker and p.life == "Alive" then
			local flat = Vector3.new(
				root.Position.X - heliMarker.Position.X,
				0,
				root.Position.Z - heliMarker.Position.Z
			)
			if flat.Magnitude <= Classic.heliZoneRadius then
				round.send({ type = "EnterHeliZone", playerId = player.UserId })
			end
		end
	end
	-- tower progress bars
	for towerId, t in state.towers do
		local model = towerModels[towerId]
		local box = model and model:FindFirstChild("RadioBox")
		local bar = box and box:FindFirstChild("Progress")
		local fill = bar and bar:FindFirstChild("Frame") and (bar :: any).Frame:FindFirstChild("Fill")
		if fill then
			fill.Size = UDim2.fromScale(t.progress, 1)
		end
	end
end

function ObjectiveService.start(r: Round, m: MapInfo)
	round = r
	map = m
	setupLockers()
	Players.PlayerRemoving:Connect(function(player)
		nextSkillCheck[player] = nil
		hiddenLooks[player] = nil
	end)
end

return ObjectiveService
