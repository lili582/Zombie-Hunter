--!strict
-- The saved player profile: coins, owned items, what is equipped, stats. Pure.
-- Everything read from the DataStore goes through `migrate`, so old or broken saves still load.
local Outfit = require("./Outfit")

local Profile = {}

Profile.VERSION = 1

export type Stats = {
	rounds: number,
	wins: number,
	escapes: number,
	survivals: number,
	zombieKills: number,
	infections: number,
	revives: number,
	towersRepaired: number,
	roundsAsHunter: number,
	roundsAsAlpha: number,
}

export type Equipped = {
	hunterGun: string,
	hunterMelee: string,
	zombieSkin: string,
	preferredAlpha: string,
}

export type Profile = {
	version: number,
	coins: number,
	owned: { [string]: boolean }, -- item id -> true (starter items are always owned)
	equipped: Equipped,
	stats: Stats,
	outfit: Outfit.Outfit, -- your in-game character (catalog); new players get the default
}

-- A reward for one round (or one event): coins and stat counters to add.
export type Reward = { coins: number?, stats: { [string]: number }? }

local STAT_NAMES = {
	"rounds",
	"wins",
	"escapes",
	"survivals",
	"zombieKills",
	"infections",
	"revives",
	"towersRepaired",
	"roundsAsHunter",
	"roundsAsAlpha",
}
Profile.STAT_NAMES = STAT_NAMES

local DEFAULT_EQUIPPED: Equipped = {
	hunterGun = "Revolver",
	hunterMelee = "Bat",
	zombieSkin = "Rotten",
	preferredAlpha = "Runner",
}
Profile.DEFAULT_EQUIPPED = DEFAULT_EQUIPPED

local function count(v: any): number
	return if type(v) == "number" and v == v and v >= 0 then math.floor(v) else 0
end

function Profile.new(): Profile
	local stats = {}
	for _, name in STAT_NAMES do
		stats[name] = 0
	end
	return {
		version = Profile.VERSION,
		coins = 0,
		owned = {},
		equipped = table.clone(DEFAULT_EQUIPPED),
		stats = stats :: any,
		outfit = Outfit.default(),
	}
end

-- Any saved value (nil, an old version, a broken table) -> a valid profile.
function Profile.migrate(raw: any): Profile
	local p = Profile.new()
	if type(raw) ~= "table" then
		return p
	end
	p.coins = count(raw.coins)
	if type(raw.owned) == "table" then
		for id, owned in raw.owned do
			if type(id) == "string" and owned == true then
				p.owned[id] = true
			end
		end
	end
	if type(raw.equipped) == "table" then
		for slot in DEFAULT_EQUIPPED do
			local id = raw.equipped[slot]
			if type(id) == "string" and id ~= "" then
				(p.equipped :: any)[slot] = id
			end
		end
	end
	p.outfit = Outfit.migrate(raw.outfit)
	if type(raw.stats) == "table" then
		for _, name in STAT_NAMES do
			(p.stats :: any)[name] = count(raw.stats[name])
		end
	end
	return p
end

-- Adds coins and stats. Unknown stat names are ignored. Returns the same profile.
function Profile.addReward(p: Profile, reward: Reward): Profile
	p.coins += count(reward.coins)
	for name, n in reward.stats or {} do
		if table.find(STAT_NAMES, name) then
			(p.stats :: any)[name] += count(n)
		end
	end
	return p
end

-- What the owner's client may see (a copy).
function Profile.snapshot(p: Profile): { [string]: any }
	return {
		coins = p.coins,
		owned = table.clone(p.owned),
		equipped = table.clone(p.equipped),
		stats = table.clone(p.stats),
		outfit = Outfit.migrate(p.outfit), -- a copy
	}
end

return Profile
