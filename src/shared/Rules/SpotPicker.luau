--!strict
-- Picks `count` spots that are spread out (at least `minDistance` apart when possible). Pure.
local Types = require("../Types")

local SpotPicker = {}

local function dist(a: { x: number, z: number }, b: { x: number, z: number }): number
	return math.sqrt((a.x - b.x) ^ 2 + (a.z - b.z) ^ 2)
end

-- Returns spot indices (1-based), sorted ascending.
function SpotPicker.pick(
	spots: { { x: number, z: number } },
	count: number,
	minDistance: number,
	rng: Types.Rng
): { number }
	local n = math.min(count, #spots)
	local required = minDistance
	for _ = 1, 6 do -- relax the distance if the map can't fit them
		for _ = 1, 40 do
			local order = {}
			for i = 1, #spots do
				order[i] = i
			end
			for i = #order, 2, -1 do -- shuffle
				local j = rng:int(1, i)
				order[i], order[j] = order[j], order[i]
			end
			local chosen = {}
			for _, idx in order do
				local ok = true
				for _, c in chosen do
					if dist(spots[idx], spots[c]) < required then
						ok = false
						break
					end
				end
				if ok then
					table.insert(chosen, idx)
					if #chosen == n then
						table.sort(chosen)
						return chosen
					end
				end
			end
		end
		required *= 0.7
	end
	local all = {}
	for i = 1, n do
		all[i] = i
	end
	return all
end

return SpotPicker
