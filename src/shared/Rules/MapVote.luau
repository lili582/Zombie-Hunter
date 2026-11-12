--!strict
-- Map vote: which maps are on the board, and which one wins. Pure.
local Types = require("../Types")

local MapVote = {}

-- The map that may not be picked: the last `maxRepeats` rounds were all on it.
function MapVote.banned(history: { string }, maxRepeats: number): string?
	if maxRepeats <= 0 or #history < maxRepeats then
		return nil
	end
	local last = history[#history]
	for i = #history - maxRepeats + 1, #history do
		if history[i] ~= last then
			return nil
		end
	end
	return last
end

-- Up to `count` maps from `pool` (in pool order). Never the banned map, unless it's the only one.
function MapVote.choices(
	pool: { string },
	history: { string },
	count: number,
	maxRepeats: number,
	rng: Types.Rng
): { string }
	local banned = MapVote.banned(history, maxRepeats)
	local candidates = {}
	for _, id in pool do
		if id ~= banned then
			table.insert(candidates, id)
		end
	end
	if #candidates == 0 then
		candidates = table.clone(pool)
	end
	if #candidates > count then
		for i = #candidates, 2, -1 do -- shuffle, keep the first `count`
			local j = rng:int(1, i)
			candidates[i], candidates[j] = candidates[j], candidates[i]
		end
		local picked = {}
		for i = 1, count do
			picked[candidates[i]] = true
		end
		candidates = {}
		for _, id in pool do
			if picked[id] then
				table.insert(candidates, id)
			end
		end
	end
	return candidates
end

-- Votes per map on the board (maps with no votes count 0).
function MapVote.tally(choices: { string }, votes: { [number]: string }): { [string]: number }
	local counts = {}
	for _, id in choices do
		counts[id] = 0
	end
	for _, id in votes do
		if counts[id] ~= nil then
			counts[id] += 1
		end
	end
	return counts
end

-- The most-voted map; a tie (or no votes) is broken at random among the tied maps.
function MapVote.winner(choices: { string }, votes: { [number]: string }, rng: Types.Rng): string?
	if #choices == 0 then
		return nil
	end
	local counts = MapVote.tally(choices, votes)
	local best, tied = -1, {}
	for _, id in choices do
		if counts[id] > best then
			best, tied = counts[id], { id }
		elseif counts[id] == best then
			table.insert(tied, id)
		end
	end
	if #tied == 1 then
		return tied[1]
	end
	return tied[rng:int(1, #tied)]
end

return MapVote
