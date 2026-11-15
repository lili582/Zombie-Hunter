--!strict
-- Round start: players are split into small groups (2-3), and each group starts at its own
-- spawn spot, spread out over the map. Players are shuffled first, so the Alpha (disguised)
-- lands in a random group and the spot tells nobody anything. Pure.
local Types = require("../Types")
local SpotPicker = require("./SpotPicker")

local SpawnGroups = {}

SpawnGroups.GROUP_SIZE = 2 -- groups of 2, the last one may get 3 (tune)
SpawnGroups.MIN_DISTANCE = 80 -- studs between the picked spots, relaxed if the map is small (tune)

-- How many groups for `n` players: groups of 2-3, but never everyone in one place - 2 or 3
-- players start alone or in a pair at 2 different spots. Never more than there are spots.
function SpawnGroups.count(n: number, spotCount: number): number
	if n <= 0 or spotCount <= 0 then
		return 0
	end
	local groups = math.max(math.floor(n / SpawnGroups.GROUP_SIZE), math.min(n, 2))
	return math.clamp(groups, 1, spotCount)
end

-- playerIds -> spot index (1-based into `spots`).
function SpawnGroups.assign(
	playerIds: { number },
	spots: { { x: number, z: number } },
	rng: Types.Rng
): { [number]: number }
	local out: { [number]: number } = {}
	local groups = SpawnGroups.count(#playerIds, #spots)
	if groups == 0 then
		return out
	end
	local picked = SpotPicker.pick(spots, groups, SpawnGroups.MIN_DISTANCE, rng)
	-- shuffle a sorted copy so a given seed always gives the same result
	local order = table.clone(playerIds)
	table.sort(order)
	for i = #order, 2, -1 do
		local j = rng:int(1, i)
		order[i], order[j] = order[j], order[i]
	end
	-- deal the players out like cards: group sizes differ by at most one
	for i, id in order do
		out[id] = picked[(i - 1) % #picked + 1]
	end
	return out
end

return SpawnGroups
