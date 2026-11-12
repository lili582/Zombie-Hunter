--!strict
-- Game modes are data: each mode changes some Classic numbers for one round. All (tune).
-- Picked at random every round (ModePicker): weights, minimum players, and a special mode never
-- comes twice in a row. Last Stand and Juggernaut Alpha come later (v1.0).
local Modes = {}

Modes.Classic = {
	id = "Classic",
	weight = 40,
	minPlayers = 5,
	special = false,
	overrides = {} :: { [string]: any },
	alphaCount = function(n: number): number
		return if n >= 12 then 2 else 1
	end,
	hunterCount = function(n: number): number
		return if n >= 12 then 2 else 1
	end,
}

Modes.Outbreak = {
	id = "Outbreak",
	weight = 20,
	minPlayers = 6,
	special = true,
	overrides = {
		modeName = "OUTBREAK",
		modeLine = "More of you are infected. Everyone has a pistol. Survive 4:00.",
		roundLength = 240,
		bleedOut = 10,
		towersOnMap = 0, -- no towers, no helicopter: just survive
		humanWeapon = "Pistol", -- every Survivor is armed; there is no Hunter
	} :: { [string]: any },
	alphaCount = function(n: number): number
		return if n >= 12 then 3 else 2
	end,
	hunterCount = function(_n: number): number
		return 0
	end,
}

Modes.all = { "Classic", "Outbreak" }

function Modes.get(id: string?): any
	local mode = (Modes :: any)[id or "Classic"]
	return if type(mode) == "table" and mode.id then mode else Modes.Classic
end

-- The round config for a mode: the base config with the mode's numbers on top.
function Modes.configFor(base: any, id: string?): any
	local mode = Modes.get(id)
	local config = table.clone(base)
	for k, v in mode.overrides do
		config[k] = v
	end
	config.modeId = mode.id
	config.alphaCount = mode.alphaCount
	config.hunterCount = mode.hunterCount
	return config
end

return Modes
