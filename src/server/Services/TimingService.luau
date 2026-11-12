--!strict
-- One timing bar at a time per player: "dodge" (escape a zombie attack) or "skill" (tower
-- skill check). The client shows a needle; the server judges the click (Rules/Dodge.judge).
-- A dodge always wins over a skill check: an open skill check is cancelled for it.
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local Dodge = require(Shared.Rules.Dodge)
local Rng = require(Shared.Rng)
local Remotes = require(Shared.Net.Remotes)

local TimingService = {}

export type Kind = "dodge" | "skill"

type Pending = {
	id: number,
	kind: Kind,
	challenge: Dodge.Challenge,
	sentAt: number,
	onDone: (boolean) -> (),
}

local pending: { [Player]: Pending } = {}
local rng = Rng.new(os.time() + 17)
local nextId = 0

local function finish(player: Player, id: number, ok: boolean, notify: boolean)
	local p = pending[player]
	if not p or p.id ~= id then
		return
	end
	pending[player] = nil
	Remotes.get("TimingResult"):FireClient(player, id, ok)
	if notify then
		p.onDone(ok)
	end
end

function TimingService.isBusy(player: Player): boolean
	return pending[player] ~= nil
end

-- Cancels an open bar without calling its callback.
function TimingService.cancel(player: Player)
	local p = pending[player]
	if p then
		finish(player, p.id, false, false)
	end
end

-- Starts a bar. Returns false if the player already has a bar that this one can't replace.
function TimingService.start(player: Player, kind: Kind, onDone: (boolean) -> ()): boolean
	local open = pending[player]
	if open then
		if kind == "dodge" and open.kind == "skill" then
			TimingService.cancel(player)
		else
			return false
		end
	end
	nextId += 1
	local id = nextId
	local zone = if kind == "skill" then Weapons.Dodge.skillZoneSize else nil
	local challenge = Dodge.newChallenge(rng, zone)
	pending[player] = { id = id, kind = kind, challenge = challenge, sentAt = os.clock(), onDone = onDone }
	Remotes.get("TimingChallenge")
		:FireClient(player, id, kind, challenge.window, challenge.zoneStart, challenge.zoneSize)
	-- no click in time = fail
	task.delay(challenge.window * (1 + Weapons.Dodge.tolerance) + 0.6, function()
		finish(player, id, false, true)
	end)
	return true
end

function TimingService.init()
	Remotes.get("TimingAttempt").OnServerEvent:Connect(function(player: Player, id: any, claimed: any)
		local p = pending[player]
		if not p or p.id ~= id then
			return
		end
		local elapsed = os.clock() - p.sentAt
		local rtt = math.clamp(player:GetNetworkPing() * 2, 0, 0.6)
		local ok = Dodge.judge(p.challenge, claimed, elapsed, rtt)
		finish(player, id, ok, true)
	end)
	Players.PlayerRemoving:Connect(function(player)
		pending[player] = nil
	end)
end

return TimingService
