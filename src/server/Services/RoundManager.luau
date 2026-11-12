--!strict
-- Owns the RoundState. Turns Roblox happenings into rule events, and rule effects into
-- Roblox actions. All game decisions are made by RoundRules (pure, tested).
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CollectionService = game:GetService("CollectionService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local RoundRules = require(Shared.Rules.RoundRules)
local Classic = require(Shared.Config.Classic)
local Rng = require(Shared.Rng)
local Remotes = require(Shared.Net.Remotes)

local Services = script.Parent
local CharacterService = require(Services.CharacterService)
local CombatService = require(Services.CombatService)
local AnnouncementService = require(Services.AnnouncementService)
local MapService = require(Services.MapService)
local TimingService = require(Services.TimingService)
local ObjectiveService = require(Services.ObjectiveService)
local AbilityService = require(Services.AbilityService)
local LobbyService = require(Services.LobbyService)

local RoundManager = {}

local TICK = 0.1
local BROADCAST_EVERY = 0.5

-- In Studio playtests a round starts with fewer players, so you can test alone or with 2-3.
local config = table.clone(Classic)
if RunService:IsStudio() then
	config.minPlayers = Classic.studioMinPlayers
end
local state = RoundRules.new(config, Rng.new(os.time())) -- replaced in start() once the map is loaded
local map: MapService.MapInfo
local lastPositions: { [number]: CFrame } = {}
local droppedGun: Model? = nil
local dirty = true

local function playerById(id: number): Player?
	return Players:GetPlayerByUserId(id)
end

local function inRound(): boolean
	return state.phase == "HeadStart" or state.phase == "Active"
end

local function randomZombieSpawn(): CFrame
	return map.zombieSpawns[math.random(1, #map.zombieSpawns)]
end

function RoundManager.getState()
	return state
end

-- Forward declaration (effects can send new events, e.g. prompts)
local runEffect: (any) -> ()

function RoundManager.send(event: any)
	local fx
	state, fx = RoundRules.apply(state, event)
	for _, f in fx do
		local ok, err = pcall(runEffect, f)
		if not ok then
			warn("RoundManager effect failed:", f.type, err)
		end
	end
	if #fx > 0 then
		dirty = true
	end
end

local function hookRevivePrompt(prompt: ProximityPrompt)
	local targetId = prompt:GetAttribute("TargetId")
	prompt.PromptButtonHoldBegan:Connect(function(reviver)
		RoundManager.send({ type = "ReviveStart", reviverId = reviver.UserId, targetId = targetId })
	end)
	prompt.PromptButtonHoldEnded:Connect(function(reviver)
		RoundManager.send({ type = "ReviveStop", reviverId = reviver.UserId })
	end)
end

local function removeDroppedGun()
	if droppedGun then
		droppedGun:Destroy()
		droppedGun = nil
	end
end

local function spawnDroppedGun(at: CFrame)
	removeDroppedGun()
	local model = Instance.new("Model")
	model.Name = "DroppedGun"
	local gun = Instance.new("Part")
	gun.Name = "Gun"
	gun.Size = Vector3.new(0.6, 1, 2)
	gun.Anchored = true
	gun.CanCollide = false
	gun.Color = Color3.fromRGB(255, 199, 154) -- peach (Hunter)
	gun.Material = Enum.Material.Neon
	gun.CFrame = CFrame.new(at.Position.X, at.Position.Y - 2, at.Position.Z)
	gun.Parent = model
	local light = Instance.new("PointLight")
	light.Color = gun.Color
	light.Range = 14
	light.Brightness = 3
	light.Parent = gun
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up the gun"
	prompt.ObjectText = "Hunter's revolver"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	CollectionService:AddTag(prompt, "GunPrompt")
	prompt.Parent = gun
	prompt.Triggered:Connect(function(player)
		RoundManager.send({ type = "PickUpGun", playerId = player.UserId })
	end)
	model.Parent = workspace
	droppedGun = model
	-- a slow spin so it catches the eye
	task.spawn(function()
		while model.Parent do
			gun.CFrame *= CFrame.Angles(0, math.rad(4), 0)
			task.wait(0.03)
		end
	end)
end

local function sendEveryoneToLobby()
	removeDroppedGun()
	MapService.setAlphaDoor(map, false)
	for _, player in Players:GetPlayers() do
		CombatService.clearGun(player)
		task.spawn(CharacterService.spawn, player, nil, map.lobbySpawn)
	end
end

local function spawnRoundCharacters()
	-- everyone stands frozen in the dark while the intro cards play
	local introEnds = os.clock() + Classic.introLength
	for id, p in state.players do
		local player = playerById(id)
		if not player or p.life == "Out" then
			continue
		end
		-- the Alpha starts among the survivors, disguised (claws only work after release)
		local at = map.humanStart
		task.spawn(function()
			CharacterService.spawn(player, p.role, at)
			if p.role == "Hunter" then
				CombatService.resetGun(player)
			end
			CharacterService.freeze(player, introEnds - os.clock())
		end)
	end
end

local previousPhase = state.phase

runEffect = function(f: any)
	if f.type == "PhaseChanged" then
		local from = previousPhase
		previousPhase = f.phase
		if f.phase == "HeadStart" then
			MapService.setAlphaDoor(map, false)
			removeDroppedGun()
		elseif f.phase == "Active" then
			MapService.setAlphaDoor(map, true)
		elseif (f.phase == "Intermission" or f.phase == "Waiting") and from == "Results" then
			ObjectiveService.cleanup()
			sendEveryoneToLobby()
		end
	elseif f.type == "RolesAssigned" then
		ObjectiveService.setupRound(state)
		spawnRoundCharacters()
	elseif f.type == "Healed" then
		local user = playerById(f.playerId)
		local p = state.players[f.playerId]
		if user and p and p.medkits <= 0 then
			for _, container in { user:FindFirstChildOfClass("Backpack"), user.Character } do
				local kit = container and container:FindFirstChild("Medkit")
				if kit then
					kit:Destroy()
				end
			end
		end
	elseif
		f.type == "RepairStarted"
		or f.type == "RepairStopped"
		or f.type == "TowerRepaired"
		or f.type == "NoiseAlert"
		or f.type == "HeliCalled"
		or f.type == "HeliLeft"
		or f.type == "EnteredLocker"
		or f.type == "LeftLocker"
		or f.type == "Escaped"
	then
		ObjectiveService.onEffect(f)
	elseif f.type == "Downed" then
		local player = playerById(f.playerId)
		if player then
			CharacterService.setDowned(player, true, hookRevivePrompt)
		end
	elseif f.type == "Revived" then
		local player = playerById(f.playerId)
		if player then
			CharacterService.setDowned(player, false)
		end
	elseif f.type == "BecameZombie" or f.type == "BecameAlpha" then
		local player = playerById(f.playerId)
		if player then
			local role = if f.type == "BecameAlpha" then "Alpha" else "Zombie"
			local at = if state.phase == "HeadStart"
				then map.humanStart
				else (CharacterService.position(player) or randomZombieSpawn())
			CombatService.clearGun(player)
			task.spawn(CharacterService.spawn, player, role, at)
		end
	elseif f.type == "GunDropped" then
		local at = lastPositions[f.fromId] or map.humanStart
		spawnDroppedGun(at)
	elseif f.type == "NewHunter" then
		removeDroppedGun()
		local player = playerById(f.playerId)
		if player then
			CharacterService.applyRole(player, "Hunter")
			CombatService.resetGun(player)
		end
	elseif f.type == "AbilityUsed" then
		AbilityService.onUsed(f)
	elseif f.type == "PointsAwarded" then
		local player = playerById(f.playerId)
		if player then
			Remotes.get("PointsPopup"):FireClient(player, f.amount, f.reason)
		end
	elseif f.type == "Announce" then
		AnnouncementService.send(f.card, f.toPlayerId, f.data)
	end
end

local function broadcast()
	local remote = Remotes.get("RoundStateChanged")
	for _, player in Players:GetPlayers() do
		remote:FireClient(player, RoundRules.viewFor(state, player.UserId))
	end
	dirty = false
end

-- A character died (fell off the map, or a zombie was killed by the Hunter).
local function onDied(player: Player, char: Model)
	local p = state.players[player.UserId]
	if not p or not inRound() or p.life == "Out" or p.life == "Escaped" then
		task.delay(2, function()
			if player.Character == char then
				CharacterService.spawn(player, nil, map.lobbySpawn)
			end
		end)
		return
	end
	if p.role == "Alpha" or p.role == "Zombie" then
		local killer = CombatService.takeLastHunter(player)
		if type(killer) == "number" then
			RoundManager.send({ type = "ZombieKilled", killerId = killer, victimId = player.UserId })
		end
		local delay = if p.role == "Alpha" then Classic.alphaRespawn else Classic.zombieRespawn
		task.delay(delay, function()
			local now = state.players[player.UserId]
			if now and inRound() and player.Character == char then
				CharacterService.spawn(player, now.role, randomZombieSpawn())
			end
		end)
	else
		-- humans only die from falling out of the world: put them back
		task.delay(2, function()
			local now = state.players[player.UserId]
			if now and inRound() and player.Character == char then
				CharacterService.spawn(player, now.role, map.humanStart)
				if now.role == "Hunter" then
					CombatService.resetGun(player)
				end
				if now.life == "Downed" then
					CharacterService.setDowned(player, true, hookRevivePrompt)
				end
			end
		end)
	end
end

function RoundManager.start()
	Players.CharacterAutoLoads = false
	map = MapService.load()
	MapService.startFlicker()
	-- the rules get the map's tower spots and helicopter zones (positions only, no Roblox objects)
	local towerSpots = {}
	for _, cf in map.towerSpots do
		table.insert(towerSpots, { x = cf.Position.X, z = cf.Position.Z })
	end
	state = RoundRules.new(config, Rng.new(os.time()), {
		towerSpots = towerSpots,
		heliZoneCount = #map.heliZones,
	})
	TimingService.init()
	CharacterService.alphaClassOf = function(player: Player): string?
		local p = state.players[player.UserId]
		return if p and p.role == "Alpha" then p.alphaClass else nil
	end
	AbilityService.start(RoundManager)
	LobbyService.start(RoundManager)
	ObjectiveService.start(RoundManager, map)
	CharacterService.onDied(onDied)
	CombatService.start(RoundManager, map.ammoSpawns)

	local function onJoin(player: Player)
		task.spawn(CharacterService.spawn, player, nil, map.lobbySpawn)
		RoundManager.send({ type = "PlayerJoined", playerId = player.UserId })
	end
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerAdded:Connect(onJoin)
	Players.PlayerRemoving:Connect(function(player)
		lastPositions[player.UserId] = CharacterService.position(player) or lastPositions[player.UserId]
		RoundManager.send({ type = "PlayerLeft", playerId = player.UserId })
		lastPositions[player.UserId] = nil
	end)

	local acc, sinceBroadcast = 0, 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		sinceBroadcast += dt
		if acc >= TICK then
			for _, player in Players:GetPlayers() do
				local cf = CharacterService.position(player)
				if cf then
					lastPositions[player.UserId] = cf
				end
			end
			RoundManager.send({ type = "Tick", dt = acc })
			ObjectiveService.tick()
			acc = 0
		end
		if dirty or sinceBroadcast >= BROADCAST_EVERY then
			broadcast()
			sinceBroadcast = 0
		end
	end)
end

return RoundManager
