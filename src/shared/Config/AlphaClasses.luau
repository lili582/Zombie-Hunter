--!strict
-- Alpha classes: each player picks one in the safehouse; it is used whenever they are the Alpha.
-- `speed` is the speed while the mask is off (a disguised Alpha moves at human speed).
-- Using an ability always shows the Alpha's face, like an attack. All (tune).
local AlphaClasses = {
	order = { "Runner", "Tank", "Screamer" },
	default = "Runner",
	Runner = {
		name = "RUNNER",
		ability = "Dash",
		line = "Fast. [Q] DASH: a burst of speed",
		health = 300,
		speed = 20,
		cooldown = 15,
		dashSpeed = 34,
		dashTime = 2.5,
	},
	Tank = {
		name = "TANK",
		ability = "Slam",
		line = "Very tough. [Q] SLAM: knocks nearby humans back",
		health = 600,
		speed = 17,
		cooldown = 20,
		slamRadius = 14,
		slamPush = 70,
		slowSpeed = 8,
		slowTime = 1.5,
	},
	Screamer = {
		name = "SCREAMER",
		ability = "Scream",
		line = "Hunts by sound. [Q] SCREAM: shows nearby humans to all zombies",
		health = 350,
		speed = 18,
		cooldown = 25,
		screamRadius = 70,
		revealTime = 5,
	},
}

function AlphaClasses.isValid(name: any): boolean
	return type(name) == "string" and table.find(AlphaClasses.order, name) ~= nil
end

function AlphaClasses.get(name: string?): any
	return (AlphaClasses :: any)[if name and AlphaClasses.isValid(name) then name else AlphaClasses.default]
end

return AlphaClasses
