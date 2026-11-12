--!strict
-- Picks Alpha(s) and Hunter(s) with anti-repeat weighting. Pure.
local Types = require("../Types")
local Classic = require("../Config/Classic")

type Role = Types.Role
type Rng = Types.Rng

local RolePicker = {}

local MAX_WEIGHT_ROUNDS = 5

-- Removes and returns one id from `pool`, weighted by `weights`.
local function weightedTake(pool: { number }, weights: { [number]: number }, rng: Rng): number
	local total = 0
	for _, id in pool do
		total += weights[id]
	end
	local r = rng:float() * total
	for i, id in pool do
		r -= weights[id]
		if r < 0 then
			table.remove(pool, i)
			return id
		end
	end
	return table.remove(pool) :: number
end

function RolePicker.pick(
	playerIds: { number },
	roundsSinceSpecial: { [number]: number },
	rng: Rng,
	specialCount: ((number) -> number)?
): { [number]: Role }
	local pool = table.clone(playerIds)
	table.sort(pool) -- deterministic order for a given seed
	local weights = {}
	for _, id in pool do
		weights[id] = 1 + math.min(roundsSinceSpecial[id] or MAX_WEIGHT_ROUNDS, MAX_WEIGHT_ROUNDS)
	end

	local roles: { [number]: Role } = {}
	for _, id in pool do
		roles[id] = "Survivor"
	end

	local n = (specialCount or Classic.specialCount)(#pool)
	for _ = 1, n do
		if #pool > 1 then
			roles[weightedTake(pool, weights, rng)] = "Alpha"
		end
	end
	for _ = 1, n do
		if #pool > 1 then
			roles[weightedTake(pool, weights, rng)] = "Hunter"
		end
	end
	return roles
end

function RolePicker.pickReplacementAlpha(candidateIds: { number }, rng: Rng): number?
	if #candidateIds == 0 then
		return nil
	end
	local sorted = table.clone(candidateIds)
	table.sort(sorted)
	return sorted[rng:int(1, #sorted)]
end

return RolePicker
