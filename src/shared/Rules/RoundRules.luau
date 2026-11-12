--!strict
-- THE seam: apply(state, event) -> (newState, effects). Phases, timers, roles, win checks, points.
-- Pure: never touches Roblox and never changes the state it is given.
local Types = require("../Types")
local Util = require("./Util")
local RolePicker = require("./RolePicker")
local Infection = require("./Infection")
local WinCheck = require("./WinCheck")
local Scoring = require("./Scoring")
local Objectives = require("./Objectives")
local Survival = require("./Survival")
local Abilities = require("./Abilities")
local ModePicker = require("./ModePicker")
local Modes = require("../Config/Modes")
local Maps = require("../Config/Maps")
local MapVote = require("./MapVote")

type State = Types.RoundState
type Effect = Types.Effect

local RoundRules = {}

local EPS = 1e-9

function RoundRules.new(config: any, rng: Types.Rng, mapMeta: Types.MapMeta?): State
	return {
		mapMeta = mapMeta,
		towers = {},
		towersDone = 0,
		heli = { phase = "None", timeLeft = 0, zone = nil },
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
		alphaPrefs = {},
		baseConfig = config,
		nextMode = nil,
		lastMode = nil,
		mapChoices = {},
		votes = {},
		mapHistory = {},
		mapId = nil,
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

-- Mode for the next round. `baseConfig.modePool` lists the modes in play (default: Classic only).
local function pickMode(s: State): string
	local base = s.baseConfig
	return ModePicker.pick(base.modePool or { "Classic" }, Util.count(s.players), s.lastMode, s.rng, {
		ignoreMinimums = base.ignoreModeMinimums,
		force = base.forceMode,
	})
end

local function modeStillFits(s: State): boolean
	local mode = Modes.get(s.nextMode)
	return s.nextMode ~= nil
		and (
			s.baseConfig.ignoreModeMinimums
			or s.baseConfig.forceMode
			or Util.count(s.players) >= mode.minPlayers
		)
end

local function enterWaitingOrIntermission(s: State, fx: { Effect })
	if Util.count(s.players) >= s.config.minPlayers then
		s.nextMode = pickMode(s)
		s.mapChoices = MapVote.choices(
			s.baseConfig.mapPool or Maps.order,
			s.mapHistory,
			Maps.choices,
			Maps.maxRepeats,
			s.rng
		)
		s.votes = {}
		setPhase(s, "Intermission", s.config.intermission, fx)
	else
		if s.phase ~= "Waiting" then
			setPhase(s, "Waiting", 0, fx)
		end
		announceWaiting(s, fx)
	end
end

local function enterHeadStart(s: State, fx: { Effect })
	if not modeStillFits(s) then
		s.nextMode = pickMode(s) -- players left during the intermission
	end
	s.config = Modes.configFor(s.baseConfig, s.nextMode)
	s.lastMode = s.config.modeId
	-- the most-voted map
	local mapId = MapVote.winner(s.mapChoices, s.votes, s.rng)
	local map = Maps.get(mapId)
	if mapId and map then
		s.mapId = mapId
		table.insert(s.mapHistory, mapId)
		if #s.mapHistory > 5 then
			table.remove(s.mapHistory, 1)
		end
		s.config.mapName = map.name
		s.config.mapLine = map.line
		table.insert(fx, { type = "MapChosen", mapId = mapId })
	end
	s.votes = {}
	local ids = Util.sortedIds(s.players)
	local roles = RolePicker.pick(ids, s.sinceSpecial, s.rng, s.config.alphaCount, s.config.hunterCount)
	for _, id in ids do
		local fresh = Util.newPlayer(id)
		fresh.role = roles[id]
		if fresh.role == "Survivor" then
			fresh.medkits = s.config.medkitsPerSurvivor or 0
		elseif fresh.role == "Alpha" then
			Abilities.makeAlpha(s, fresh)
		end
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
	Objectives.setup(s)

	setPhase(s, "HeadStart", s.config.headStart, fx)
	table.insert(fx, { type = "RolesAssigned" })
	table.insert(
		fx,
		{ type = "Announce", card = "Map", data = { name = s.config.mapName, line = s.config.mapLine } }
	)
	table.insert(
		fx,
		{ type = "Announce", card = "Mode", data = { name = s.config.modeName, line = s.config.modeLine } }
	)
	table.insert(fx, { type = "Announce", card = "SomeoneInfected" })
	for _, id in ids do
		local role = s.players[id].role
		table.insert(fx, { type = "Announce", card = "YourRole", toPlayerId = id, data = { role = role } })
		table.insert(fx, {
			type = "Announce",
			card = "YourRules",
			toPlayerId = id,
			data = { role = role, alphaClass = s.players[id].alphaClass, mode = s.config.modeId },
		})
	end
	-- Secret roles: public cards never name the Alpha or the Hunter.
	if s.config.hunterCount(#ids) > 0 then
		table.insert(fx, { type = "Announce", card = "HunterChosen" })
	else
		table.insert(fx, { type = "Announce", card = "EveryoneArmed" }) -- e.g. Outbreak: no Hunter
	end
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
		s.config = s.baseConfig
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
			Objectives.step(s, { type = "Tick", dt = step }, fx)
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

local function onVoteMap(s: State, playerId: number, mapId: string, fx: { Effect })
	if s.phase ~= "Intermission" or not s.players[playerId] or not table.find(s.mapChoices, mapId) then
		return
	end
	s.votes[playerId] = mapId
	table.insert(fx, { type = "MapVoted", playerId = playerId, mapId = mapId })
	table.insert(fx, { type = "Announce", card = "Voted", toPlayerId = playerId, data = { mapId = mapId } })
end

local function onLeft(s: State, playerId: number, fx: { Effect })
	local leaver = s.players[playerId]
	if not leaver then
		return
	end
	s.votes[playerId] = nil
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
	elseif event.type == "VoteMap" then
		onVoteMap(s, event.playerId, event.mapId, fx)
	else
		local before = #fx
		Infection.step(s, event, fx)
		Objectives.step(s, event, fx)
		Survival.step(s, event, fx)
		Abilities.step(s, event, fx)
		for i = before + 1, #fx do
			local f = fx[i]
			if f.type == "HitLanded" then
				Objectives.onHitLanded(s, f.attackerId, f.victimId, fx)
			end
		end
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
		-- Secret roles: you only see your own role and state. Everyone else is "?" for the whole
		-- round (even infected zombies), and nobody learns who is downed, hurt or escaped.
		-- Only "Out" (waiting in the lobby for the next round) is shown for others.
		local isMe = id == viewerId
		local role: string = if isMe then p.role else "?"
		if s.phase ~= "HeadStart" and s.phase ~= "Active" and s.phase ~= "Results" then
			role = "-"
		end
		players[tostring(id)] = {
			id = id,
			role = role,
			life = if isMe or p.life == "Out" then p.life else "?",
			points = p.points,
			hitsTaken = if isMe then p.hitsTaken else 0,
			bleedLeft = if isMe then p.bleedLeft else nil,
			reviverId = if isMe then p.reviverId else nil,
			reviveProgress = if isMe then p.reviveProgress else 0,
		}
	end
	local humansLeft = 0
	for _, p in s.players do
		if (p.life == "Alive" or p.life == "Downed") and Util.isHumanRole(p.role) then
			humansLeft += 1
		end
	end
	local towers = {}
	for id, t in s.towers do
		towers[tostring(id)] = { progress = t.progress, done = t.done }
	end
	local me = s.players[viewerId]
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
		-- objectives
		towers = towers,
		towersDone = s.towersDone,
		towersNeeded = s.config.towersNeeded,
		heli = { phase = s.heli.phase, timeLeft = s.heli.timeLeft, zone = s.heli.zone },
		-- only about you (hiding is secret)
		hidden = me ~= nil and me.hiddenIn ~= nil,
		repairing = if me then me.repairing else nil,
		medkits = if me then me.medkits else 0,
		-- game mode: this round's, and the next one (lobby)
		mode = s.config.modeId or "Classic",
		modeName = s.config.modeName,
		nextMode = s.nextMode,
		humanWeapon = s.config.humanWeapon,
		-- map vote (lobby): the board and your vote; the map being played
		mapChoices = s.mapChoices,
		mapVotes = MapVote.tally(s.mapChoices, s.votes),
		myVote = s.votes[viewerId],
		mapId = s.mapId,
		-- Alpha class: your pick in the safehouse, and your ability while you are the Alpha
		alphaPref = s.alphaPrefs[viewerId],
		alphaClass = if me and me.role == "Alpha" then me.alphaClass else nil,
		abilityIn = if me and me.role == "Alpha" then Abilities.readyIn(s, me) else nil,
	}
end

return RoundRules
