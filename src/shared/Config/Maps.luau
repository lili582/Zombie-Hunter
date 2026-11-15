--!strict
-- The maps that can be voted for. Each has a builder in server/Maps (same id). Its spots (starts,
-- towers, helicopter zones...) are data in that builder; the round rules get them through the
-- server. All (tune).
local Maps = {
	order = { "Town", "ForestCamp", "School", "Mall" },
	choices = 3, -- maps shown on the vote board
	maxRepeats = 2, -- a map can't be played more than twice in a row
	Town = {
		id = "Town",
		name = "ABANDONED TOWN",
		line = "the lights went out at midnight",
	},
	ForestCamp = {
		id = "ForestCamp",
		name = "FOREST CAMP",
		line = "the counselors never came back from the lake",
	},
	School = {
		id = "School",
		name = "SCHOOL AT NIGHT",
		line = "detention ran late. very late.",
	},
	Mall = {
		id = "Mall",
		name = "SHOPPING MALL",
		line = "closing time was three weeks ago",
	},
}

function Maps.get(id: string?): any
	local map = (Maps :: any)[id or ""]
	return if type(map) == "table" and map.id then map else nil
end

return Maps
