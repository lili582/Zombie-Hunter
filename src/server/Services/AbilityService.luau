--!strict
-- Alpha class abilities. The rules core decides WHEN an ability may be used (role, phase,
-- cooldown); this service makes it happen in the world. Every ability shows the Alpha's face.
--   Runner   Dash:   burst of speed
--   Tank     Slam:   knocks nearby humans back and slows them for a moment
--   Screamer Scream: nearby humans glow through walls for every zombie, for a few seconds
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Weapons = require(Shared.Config.Weapons)
local Remotes = require(Shared.Net.Remotes)
local CharacterService = require(script.Parent.CharacterService)

local AbilityService = {}

type Round = {
	getState: () -> any,
	send: (event: any) -> (),
}

local round: Round

local function rootOf(player: Player): BasePart?
	local char = player.Character
	return if char then char:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
end

-- Humans (alive, not hiding, not escaped) within `radius` of `from`.
local function humansNear(from: Vector3, radius: number): { Player }
	local players = round.getState().players
	local found = {}
	for _, other in Players:GetPlayers() do
		local p = players[other.UserId]
		local r = rootOf(other)
		if
			p
			and r
			and (p.role == "Survivor" or p.role == "Hunter")
			and p.life == "Alive"
			and p.hiddenIn == nil
			and (r.Position - from).Magnitude <= radius
		then
			table.insert(found, other)
		end
	end
	return found
end

local function dash(player: Player, class: any)
	CharacterService.revealAlpha(
		player,
		math.max(class.dashTime, Weapons.AlphaReveal.seconds),
		class.dashSpeed
	)
end

local function slam(player: Player, class: any)
	CharacterService.revealAlpha(player, Weapons.AlphaReveal.seconds)
	local me = rootOf(player)
	if not me then
		return
	end
	for _, victim in humansNear(me.Position, class.slamRadius) do
		local r = rootOf(victim)
		local hum = victim.Character and victim.Character:FindFirstChildOfClass("Humanoid")
		if r and hum then
			local away = r.Position - me.Position
			local dir = if away.Magnitude > 0.1 then away.Unit else me.CFrame.LookVector
			r.AssemblyLinearVelocity = dir * class.slamPush + Vector3.new(0, 25, 0)
			hum.WalkSpeed = class.slowSpeed
			task.delay(class.slowTime, function()
				if hum.Parent and hum.WalkSpeed == class.slowSpeed then
					hum.WalkSpeed = Weapons.speed.human
				end
			end)
		end
	end
end

local function scream(player: Player, class: any)
	CharacterService.revealAlpha(player, Weapons.AlphaReveal.seconds)
	local me = rootOf(player)
	if not me then
		return
	end
	local chars = {}
	for _, victim in humansNear(me.Position, class.screamRadius) do
		table.insert(chars, victim.Character)
	end
	-- only zombies see the glow
	local players = round.getState().players
	local remote = Remotes.get("RevealHumans")
	for _, other in Players:GetPlayers() do
		local p = players[other.UserId]
		if p and (p.role == "Alpha" or p.role == "Zombie") then
			remote:FireClient(other, chars, class.revealTime)
		end
	end
end

function AbilityService.onUsed(f: any)
	local player = Players:GetPlayerByUserId(f.playerId)
	if not player then
		return
	end
	local class = AlphaClasses.get(f.class)
	if f.ability == "Dash" then
		dash(player, class)
	elseif f.ability == "Slam" then
		slam(player, class)
	elseif f.ability == "Scream" then
		scream(player, class)
	end
end

function AbilityService.start(r: Round)
	round = r
	Remotes.get("UseAbility").OnServerEvent:Connect(function(player)
		round.send({ type = "UseAbility", playerId = player.UserId })
	end)
end

return AbilityService
