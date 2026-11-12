--!strict
-- Picks the mode for the next round. Pure.
--   * weighted random over `pool`
--   * a mode needs its minimum players (unless `ignoreMinimums`, used in Studio)
--   * the same special mode never comes twice in a row
--   * `force` (Studio / VIP servers) always wins if it is a real mode
local Types = require("../Types")
local Modes = require("../Config/Modes")

local ModePicker = {}

export type Options = { ignoreMinimums: boolean?, force: string? }

function ModePicker.pick(
	pool: { string },
	playerCount: number,
	lastMode: string?,
	rng: Types.Rng,
	options: Options?
): string
	local opts: Options = options or {}
	if opts.force and Modes.get(opts.force).id == opts.force then
		return opts.force
	end
	local candidates = {}
	local total = 0
	for _, id in pool do
		local mode = Modes.get(id)
		if mode.id ~= id then
			continue -- unknown mode name
		end
		if not opts.ignoreMinimums and playerCount < mode.minPlayers then
			continue
		end
		if mode.special and id == lastMode then
			continue
		end
		table.insert(candidates, mode)
		total += mode.weight
	end
	if #candidates == 0 then
		return "Classic"
	elseif #candidates == 1 then
		return candidates[1].id
	end
	local r = rng:float() * total
	for _, mode in candidates do
		r -= mode.weight
		if r < 0 then
			return mode.id
		end
	end
	return candidates[#candidates].id
end

return ModePicker
