--!strict
-- The maps that can be voted for. Each needs a builder in MapService (or a hand-built
-- workspace.Map). Mall, School and Forest Camp come in v1.0. All (tune).
local Maps = {
	order = { "Town" },
	choices = 3, -- maps shown on the vote board
	maxRepeats = 2, -- a map can't be played more than twice in a row
	Town = {
		id = "Town",
		name = "ABANDONED TOWN",
		line = "the lights went out at midnight",
	},
}

function Maps.get(id: string?): any
	local map = (Maps :: any)[id or ""]
	return if type(map) == "table" and map.id then map else nil
end

return Maps
