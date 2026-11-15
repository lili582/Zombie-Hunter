local lib = require("./lib")
local test, expect = lib.test, lib.expect
local Profile = require("../src/shared/Data/Profile")
local ProfileStore = require("../src/shared/Data/ProfileStore")
local Rewards = require("../src/shared/Rules/Rewards")
local Classic = require("../src/shared/Config/Classic")
local Rng = require("../src/shared/Rng")
local RoundRules = require("../src/shared/Rules/RoundRules")
local H = require("./helpers")

-- In-memory DataStore with UpdateAsync behaviour (fn returns nil = no change).
local function memoryStore()
	local store = { data = {} }
	function store.update(self, key, fn)
		local new = fn(self.data[key])
		if new ~= nil then
			self.data[key] = new
		end
		return self.data[key]
	end
	return store
end

local function clock(start)
	local t = { now = start }
	return t, function()
		return t.now
	end
end

test("a new player gets a fresh profile and the lock", function()
	local _, now = clock(1000)
	local ps = ProfileStore.new(memoryStore(), "server-a", now)
	local p, err = ps:load(42)
	expect(err).toBeNil()
	expect(p.coins).toBe(0)
	expect(p.equipped.hunterGun).toBe("Revolver")
	expect(p.stats.rounds).toBe(0)
end)

test("saved coins and stats come back on the next join", function()
	local store = memoryStore()
	local _, now = clock(1000)
	local ps = ProfileStore.new(store, "server-a", now)
	local p = ps:load(42)
	Profile.addReward(p, { coins = 35, stats = { rounds = 1, wins = 1 } })
	expect(ps:save(42, p, true)).toBe(true)
	local again = ProfileStore.new(store, "server-b", now):load(42)
	expect(again.coins).toBe(35)
	expect(again.stats.wins).toBe(1)
end)

test("another live server holding the lock blocks the load; a stale lock can be taken", function()
	local store = memoryStore()
	local t, now = clock(1000)
	ProfileStore.new(store, "server-a", now):load(7)
	local b = ProfileStore.new(store, "server-b", now)
	local p, err = b:load(7)
	expect(p).toBeNil()
	expect(err).toBe("locked")
	expect(b:load(7, true) ~= nil).toBeTruthy() -- forced after waiting
	-- a crashed server's lock times out
	local c = ProfileStore.new(store, "server-c", now)
	t.now += ProfileStore.LOCK_TIMEOUT + 1
	expect(c:load(7) ~= nil).toBeTruthy()
end)

test("a server that lost the lock never overwrites the new owner's data", function()
	local store = memoryStore()
	local _, now = clock(1000)
	local a = ProfileStore.new(store, "server-a", now)
	local old = a:load(9)
	local b = ProfileStore.new(store, "server-b", now)
	local fresh = b:load(9, true)
	fresh.coins = 500
	b:save(9, fresh)
	old.coins = 1
	expect(a:save(9, old)).toBe(false)
	expect(store.data[ProfileStore.key(9)].data.coins).toBe(500)
end)

test("broken or old saves still load", function()
	local p = Profile.migrate({
		coins = -5,
		owned = { Shovel = true, [3] = true, Bad = "yes" },
		stats = { wins = 2.7 },
	})
	expect(p.coins).toBe(0)
	expect(p.owned.Shovel).toBe(true)
	expect(p.owned.Bad).toBeNil()
	expect(p.stats.wins).toBe(2)
	expect(p.stats.revives).toBe(0)
	expect(Profile.migrate("garbage").coins).toBe(0)
	expect(Profile.migrate(nil).equipped.zombieSkin).toBe("Rotten")
end)

test("round end: everyone who played gets coins and a round; the winning side gets a win", function()
	local s = H.activeRound(5) -- 1 Alpha, 2 Hunter, 3-5 Survivors
	local fx
	s, fx = H.run(s, { H.tick(Classic.roundLength) })
	local r = Rewards.collect(s, fx)
	expect(r[3].stats.rounds).toBe(1)
	expect(r[3].stats.wins).toBe(1)
	expect(r[3].stats.survivals).toBe(1)
	expect(r[1].stats.wins).toBeNil() -- the Alpha lost
	expect(r[1].coins >= 10).toBeTruthy() -- the minimum
	expect(r[3].coins).toBe(math.max(10, math.floor(s.players[3].points / 2)))
end)

test("revives, infections, kills and roles are counted for the right player", function()
	local s = H.activeRound(6)
	local fx
	s, fx = H.run(s, { H.hit(1, 3), H.hit(1, 3), H.reviveStart(4, 3), H.tick(Classic.reviveTime) })
	expect(Rewards.collect(s, fx)[4].stats.revives).toBe(1)
	s, fx = H.run(s, { H.hit(1, 5), H.hit(1, 5), H.tick(Classic.bleedOut) })
	expect(Rewards.collect(s, fx)[1].stats.infections).toBe(1)
	_, fx = H.run(s, { H.killed(2, 5) })
	expect(Rewards.collect(s, fx)[2].stats.zombieKills).toBe(1)

	local fresh = H.run(RoundRules.new(Classic, Rng.new(1)), H.join(5))
	local after
	after, fx = H.run(fresh, { H.tick(Classic.intermission) })
	local r = Rewards.collect(after, fx)
	local hunters, alphas = 0, 0
	for _, reward in r do
		hunters += reward.stats.roundsAsHunter or 0
		alphas += reward.stats.roundsAsAlpha or 0
	end
	expect(hunters).toBe(1)
	expect(alphas).toBe(1)
end)

test("players sitting out the round get nothing", function()
	local s = H.activeRound(5)
	s = H.run(s, H.join(1, 9)) -- joined mid-round
	local fx
	s, fx = H.run(s, { H.tick(Classic.roundLength) })
	expect(Rewards.collect(s, fx)[9]).toBeNil()
end)

test("profile snapshot is a copy", function()
	local p = Profile.new()
	local snap = Profile.snapshot(p)
	snap.equipped.hunterGun = "Hacked"
	expect(p.equipped.hunterGun).toBe("Revolver")
end)
