--!strict
-- THE seam: apply(state, event) -> (newState, effects). Phases, timers, roles, win checks, points.
-- Pure: never touches Roblox and never changes the state it is given.
local Types = require("../Types")
local Util = require("./Util")
local RolePicker = require("./RolePicker")
local Infection = require("./Infection")
local WinCheck = require("./WinCheck")
local Scoring = require("./Scoring")

type State = Types.RoundState
type Effect = Types.Effect

local RoundRules = {}

local EPS = 1e-9

function RoundRules.new(config: any, rng: Types.Rng): State
	return {
		phase = "Waiting",
		timeLeft = 0,
		clock = 0,
		config = config,
		rng = rng,
		players = {},
		sinceSpecial = {},
		lastHits = {},
		pendingAssists = {},
		gunDropped = false,
		alphaRevealed = false,
		winner = nil,
	}
end

local function setPhase(s: State, phase: Types.Phase, timeLeft: number, fx: { Effect })
	s.phase = phase
	s.timeLeft = timeLeft
	table.insert(fx, { type = "PhaseChanged", phase = phase })
end

local function announceWaiting(s: State, fx: { Effect })
	table.insert(fx, {
		type = "Announce",
		card = "WaitingForPlayers",
		data = { count = Util.count(s.players), needed = s.config.minPlayers },
	})
end

local function enterWaitingOrIntermission(s: State, fx: { Effect })
	if Util.count(s.players) >= s.config.minPlayers then
		setPhase(s, "Intermission", s.config.intermission, fx)
	else
		if s.phase ~= "Waiting" then
			setPhase(s, "Waiting", 0, fx)
		end
		announceWaiting(s, fx)
	end
end

local function enterHeadStart(s: State, fx: { Effect })
	local ids = Util.sortedIds(s.players)
	local roles = RolePicker.pick(ids, s.sinceSpecial, s.rng, s.config.specialCount)
	for _, id in ids do
		local fresh = Util.newPlayer(id)
		fresh.role = roles[id]
		s.players[id] = fresh
		if fresh.role == "Survivor" then
			s.sinceSpecial[id] = (s.sinceSpecial[id] or 0) + 1
		else
			s.sinceSpecial[id] = 0
		end
	end
	s.gunDropped = false
	s.alphaRevealed = false
	s.winner = nil
	s.clock = 0
	s.lastHits = {}
	s.pendingAssists = {}

	setPhase(s, "HeadStart", s.config.headStart, fx)
	table.insert(fx, { type = "RolesAssigned" })
	table.insert(
		fx,
		{ type = "Announce", card = "Map", data = { name = s.config.mapName, line = s.config.mapLine } }
	)
	table.insert(fx, { type = "Announce", card = "SomeoneInfected" })
	for _, id in ids do
		local role = s.players[id].role
		table.insert(fx, { type = "Announce", card = "YourRole", toPlayerId = id, data = { role = role } })
		table.insert(fx, { type = "Announce", card = "YourRules", toPlayerId = id, data = { role = role } })
	end
	-- Secret roles: public cards never name the Alpha or the Hunter.
	table.insert(fx, { type = "Announce", card = "HunterChosen" })
end

local function enterActive(s: State, fx: { Effect })
	s.alphaRevealed = true
	setPhase(s, "Active", s.config.roundLength, fx)
	table.insert(fx, { type = "Announce", card = "AlphaAwakened" }) -- secret: no name
end

local function endRound(s: State, winner: Types.Winner, fx: { Effect })
	s.winner = winner
	setPhase(s, "Results", s.config.results, fx)
	table.insert(fx, { type = "RoundOver", winner = winner })
	table.insert(fx, { type = "Announce", card = "Result", data = { winner = winner } })
end

local function checkWin(s: State, fx: { Effect })
	if s.phase ~= "Active" then
		return
	end
	local winner = WinCheck.check(s)
	if winner then
		endRound(s, winner, fx)
	end
end

local function timerRanOut(s: State, fx: { Effect })
	if s.phase == "Intermission" then
		if Util.count(s.players) >= s.config.minPlayers then
			enterHeadStart(s, fx)
		else
			enterWaitingOrIntermission(s, fx)
		end
	elseif s.phase == "HeadStart" then
		enterActive(s, fx)
	elseif s.phase == "Active" then
		checkWin(s, fx)
	elseif s.phase == "Results" then
		-- Back to the lobby: everyone (incl. mid-round joiners) is a plain lobby player again.
		for _, id in Util.sortedIds(s.players) do
			local points = s.players[id].points
			s.players[id] = Util.newPlayer(id)
			s.players[id].points = points
		end
		s.gunDropped = false
		s.alphaRevealed = false
		enterWaitingOrIntermission(s, fx)
	end
end

local function onTick(s: State, dt: number, fx: { Effect })
	local remaining = dt
	local guard = 0
	while remaining > EPS and s.phase ~= "Waiting" and guard < 20 do
		guard += 1
		local step = math.min(remaining, math.max(s.timeLeft, 0))
		remaining -= step
		s.timeLeft -= step
		if s.phase == "Active" then
			s.clock += step
			Infection.step(s, { type = "Tick", dt = step }, fx)
			checkWin(s, fx)
			if s.phase ~= "Active" then
				continue
			end
		end
		if s.timeLeft <= EPS then
			timerRanOut(s, fx)
		end
	end
end

local function onJoined(s: State, playerId: number, fx: { Effect })
	if s.players[playerId] then
		return
	end
	local p = Util.newPlayer(playerId)
	if s.phase == "HeadStart" or s.phase == "Active" or s.phase == "Results" then
		p.life = "Out" -- waits in the lobby until the next round
	end
	s.players[playerId] = p
	if s.phase == "Waiting" then
		enterWaitingOrIntermission(s, fx)
	end
end

local function onLeft(s: State, playerId: number, fx: { Effect })
	local leaver = s.players[playerId]
	if not leaver then
		return
	end
	s.players[playerId] = nil
	s.sinceSpecial[playerId] = nil
	s.lastHits[playerId] = nil
	s.pendingAssists[playerId] = nil

	if s.phase == "Waiting" then
		announceWaiting(s, fx)
	elseif s.phase == "Intermission" then
		if Util.count(s.players) < s.config.minPlayers then
			setPhase(s, "Waiting", 0, fx)
			announceWaiting(s, fx)
		end
	elseif s.phase == "HeadStart" or s.phase == "Active" then
		if Util.count(s.players) < 2 then
			endRound(s, "NoWinner", fx) -- checked before normal win checks
			return
		end
		Infection.onPlayerLeft(s, leaver, fx)
		checkWin(s, fx)
	end
end

function RoundRules.apply(state: State, event: Types.Event): (State, { Effect })
	local s = Util.cloneState(state)
	local fx: { Effect } = {}

	if event.type == "Tick" then
		onTick(s, event.dt, fx)
	elseif event.type == "PlayerJoined" then
		onJoined(s, event.playerId, fx)
	elseif event.type == "PlayerLeft" then
		onLeft(s, event.playerId, fx)
	else
		Infection.step(s, event, fx)
		checkWin(s, fx)
	end

	-- Points for everything that just happened, then private coin cards at round end.
	local pointFx = Scoring.award(s, fx)
	for _, f in pointFx do
		table.insert(fx, f)
	end
	for _, f in table.clone(fx) do
		if f.type == "RoundOver" then
			for _, id in Util.sortedIds(s.players) do
				local p = s.players[id]
				if p.life ~= "Out" then
					table.insert(fx, {
						type = "Announce",
						card = "YourCoins",
						toPlayerId = id,
						data = { points = p.points, coins = Scoring.coins(p.points) },
					})
				end
			end
		end
	end
	return s, fx
end

-- What one client is allowed to see.
function RoundRules.viewFor(s: State, viewerId: number): { [string]: any }
	local players = {}
	for id, p in s.players do
		local role: string = p.role
		-- Secret roles: you only see your own role. Infected (basic) zombies are shown,
		-- everyone else (Alpha, Hunter, Survivors) is "?" for the whole round.
		if id ~= viewerId and p.role ~= "Zombie" then
			role = "?"
		end
		if s.phase ~= "HeadStart" and s.phase ~= "Active" and s.phase ~= "Results" then
			role = "-"
		end
		players[tostring(id)] = {
			id = id,
			role = role,
			life = p.life,
			points = p.points,
			hitsTaken = p.hitsTaken,
			bleedLeft = p.bleedLeft,
			reviverId = p.reviverId,
			reviveProgress = p.reviveProgress,
		}
	end
	local humansLeft = 0
	for _, p in s.players do
		if p.life ~= "Out" and Util.isHumanRole(p.role) then
			humansLeft += 1
		end
	end
	return {
		phase = s.phase,
		timeLeft = s.timeLeft,
		gunDropped = s.gunDropped,
		alphaRevealed = s.alphaRevealed,
		humansLeft = humansLeft,
		needed = s.config.minPlayers,
		count = Util.count(s.players),
		hitsToDown = s.config.hitsToDown,
		bleedOut = s.config.bleedOut,
		reviveTime = s.config.reviveTime,
		players = players,
		you = viewerId,
	}
end

return RoundRules
