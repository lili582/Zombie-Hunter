--!strict
-- Hunter revolver, human bat, zombie claws, ammo boxes. The server raycasts from the shooter's
-- own head and never trusts a client hit position. Claw hits become rule `Hit` events.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local HitValidation = require(Shared.Rules.HitValidation)
local Remotes = require(Shared.Net.Remotes)
local CharacterService = require(script.Parent.CharacterService)

local CombatService = {}

type Round = {
	getState: () -> any,
	send: (event: any) -> (),
}

type Gun = { mag: number, reserve: number, lastShot: number, reloading: boolean }

local guns: { [Player]: Gun } = {}
local lastSwing: { [Player]: number } = {}
local round: Round

local function roleOf(player: Player): string?
	local p = round.getState().players[player.UserId]
	return if p then p.role else nil
end

local function lifeOf(player: Player): string?
	local p = round.getState().players[player.UserId]
	return if p then p.life else nil
end

local function isActive(): boolean
	return round.getState().phase == "Active"
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

local function sendAmmo(player: Player)
	local g = guns[player]
	if g then
		Remotes.get("AmmoChanged"):FireClient(player, g.mag, g.reserve)
	end
end

function CombatService.resetGun(player: Player)
	guns[player] =
		{ mag = Weapons.Revolver.mag, reserve = Weapons.Revolver.reserve, lastShot = 0, reloading = false }
	sendAmmo(player)
end

local function reload(player: Player)
	local g = guns[player]
	if not g or g.reloading or g.mag >= Weapons.Revolver.mag or g.reserve <= 0 then
		return
	end
	g.reloading = true
	task.delay(Weapons.Revolver.reloadTime, function()
		if guns[player] ~= g then
			return
		end
		local need = math.min(Weapons.Revolver.mag - g.mag, g.reserve)
		g.mag += need
		g.reserve -= need
		g.reloading = false
		sendAmmo(player)
	end)
end

-- Nearest other character in front of `player` within `range` whose player passes `filter`.
local function nearestInFront(player: Player, range: number, filter: (Player) -> boolean): (Player?, number)
	local root = rootOf(player)
	if not root then
		return nil, math.huge
	end
	local best, bestDist = nil, math.huge
	for _, other in Players:GetPlayers() do
		if other == player or not filter(other) then
			continue
		end
		local r = rootOf(other)
		if not r then
			continue
		end
		local offset = r.Position - root.Position
		local dist = offset.Magnitude
		local facing = if dist > 0.01 then root.CFrame.LookVector:Dot(offset.Unit) else 1
		if dist <= range + 1 and facing > 0.2 and dist < bestDist then
			best, bestDist = other, dist
		end
	end
	return best, bestDist
end

local function damageZombie(victim: Player, amount: number, attacker: Player)
	local char = victim.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum and hum.Health > 0 then
		if roleOf(attacker) == "Hunter" then
			char:SetAttribute("LastHunter", attacker.UserId)
		end
		hum:TakeDamage(amount)
	end
end

local function onFire(player: Player, direction: any)
	if typeof(direction) ~= "Vector3" or direction.Magnitude < 0.01 or not isActive() then
		return
	end
	local char = player.Character
	local head = char and char:FindFirstChild("Head") :: BasePart?
	local g = guns[player]
	if not char or not head or not g or not char:FindFirstChild("Revolver") or g.reloading then
		return
	end
	local now = os.clock()
	local ok = HitValidation.shot({
		role = roleOf(player) or "",
		distance = 0, -- the ray below is capped at the weapon range
		sinceLastShot = now - g.lastShot,
		ammoInMag = g.mag,
	}, Weapons.Revolver)
	if not ok then
		return
	end
	g.lastShot = now
	g.mag -= 1

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { char }
	local origin = head.Position
	local result = workspace:Raycast(origin, direction.Unit * Weapons.Revolver.range, params)
	local hitPos = if result then result.Position else origin + direction.Unit * Weapons.Revolver.range
	if result then
		local victim = CharacterService.playerFromPart(result.Instance)
		local role = victim and roleOf(victim)
		if victim and (role == "Alpha" or role == "Zombie") then
			damageZombie(victim, Weapons.Revolver.damage, player)
		end
	end
	Remotes.get("ShotFired"):FireAllClients(origin, hitPos)
	sendAmmo(player)
	if g.mag <= 0 then
		reload(player)
	end
end

local function onBat(player: Player)
	if not isActive() or lifeOf(player) ~= "Alive" then
		return
	end
	local now = os.clock()
	local target, dist = nearestInFront(player, Weapons.Melee.range, function(other)
		local r = roleOf(other)
		return r == "Alpha" or r == "Zombie"
	end)
	local ok = HitValidation.melee({
		role = roleOf(player) or "",
		distance = if target then dist else 0,
		sinceLast = now - (lastSwing[player] or 0),
	})
	if not ok then
		return
	end
	lastSwing[player] = now
	if target then
		damageZombie(target, Weapons.Melee.damage, player)
		-- short push back (stun-lite)
		local r, me = rootOf(target), rootOf(player)
		if r and me then
			r.AssemblyLinearVelocity = (r.Position - me.Position).Unit * 40 + Vector3.new(0, 15, 0)
		end
	end
end

local function onClaw(player: Player)
	if not isActive() then
		return
	end
	local now = os.clock()
	local target, dist = nearestInFront(player, Weapons.Claw.range, function(other)
		local r = roleOf(other)
		return (r == "Survivor" or r == "Hunter") and lifeOf(other) == "Alive"
	end)
	local ok = HitValidation.claw({
		role = roleOf(player) or "",
		distance = if target then dist else 0,
		sinceLast = now - (lastSwing[player] or 0),
	})
	if not ok then
		return
	end
	lastSwing[player] = now
	if target then
		round.send({ type = "Hit", attackerId = player.UserId, victimId = target.UserId })
	end
end

local function hookTool(player: Player, tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	if tool.Name == "Bat" then
		tool.Activated:Connect(function()
			onBat(player)
		end)
	elseif tool.Name == "Claws" then
		tool.Activated:Connect(function()
			onClaw(player)
		end)
	end
end

local function watchPlayer(player: Player)
	local function watchContainer(container: Instance)
		for _, t in container:GetChildren() do
			hookTool(player, t)
		end
		container.ChildAdded:Connect(function(t)
			hookTool(player, t)
		end)
	end
	player.CharacterAdded:Connect(function(char)
		watchContainer(char)
		local backpack = player:WaitForChild("Backpack")
		watchContainer(backpack)
	end)
end

local function setupAmmoBoxes(spots: { CFrame })
	for _, cf in spots do
		local box = Instance.new("Part")
		box.Name = "AmmoBox"
		box.Size = Vector3.new(2, 1.2, 1.4)
		box.CFrame = cf
		box.Anchored = true
		box.Color = Color3.fromRGB(255, 224, 138) -- butter
		box.Material = Enum.Material.Neon
		box.Parent = workspace
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Pick up ammo"
		prompt.ObjectText = "Ammo"
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0.3
		prompt.RequiresLineOfSight = false
		CollectionService:AddTag(prompt, "AmmoPrompt")
		prompt.Parent = box
		prompt.Triggered:Connect(function(player)
			local g = guns[player]
			if not g or roleOf(player) ~= "Hunter" or box:GetAttribute("Empty") then
				return
			end
			g.reserve += Weapons.AmmoBox.amount
			sendAmmo(player)
			box:SetAttribute("Empty", true)
			box.Transparency = 0.85
			prompt.Enabled = false
			task.delay(Weapons.AmmoBox.respawn, function()
				box:SetAttribute("Empty", nil)
				box.Transparency = 0
				prompt.Enabled = true
			end)
		end)
	end
end

function CombatService.start(r: Round, ammoSpots: { CFrame })
	round = r
	Remotes.get("FireWeapon").OnServerEvent:Connect(onFire)
	Remotes.get("Reload").OnServerEvent:Connect(function(player)
		if roleOf(player) == "Hunter" then
			reload(player)
		end
	end)
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	Players.PlayerRemoving:Connect(function(p)
		guns[p] = nil
		lastSwing[p] = nil
	end)
	setupAmmoBoxes(ammoSpots)
end

function CombatService.clearGun(player: Player)
	guns[player] = nil
end

return CombatService
