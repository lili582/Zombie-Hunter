--!strict
-- When the scares happen and where the shadow figure stands (pure: plain numbers in, no engine).
-- A figure appears where you are not quite looking: in front of you but off to the side, not too
-- close and not too far into the fog. It vanishes the moment you look straight at it.
-- Positions are anything with X, Y, Z (Vector3 in the game, tables in tests).
local Scares = {}

Scares.FIGURE_MIN = 35 -- studs: closer than this and it's a jump scare, not a glimpse
Scares.FIGURE_MAX = 130 -- further than this the fog hides it anyway
Scares.SIDE_MIN = 0.3 -- cosine to your look direction: in front of you (about 72 degrees)...
Scares.SIDE_MAX = 0.9 -- ...but not where you are looking (about 26 degrees)
Scares.SEEN = 0.975 -- look within about 13 degrees of its head and it's gone
Scares.FIGURE_HEAD = 5.5 -- studs above its feet (where you look to see it)

export type Point = { X: number, Y: number, Z: number }

-- Seconds until the next figure, from a roll in [0, 1).
function Scares.figureDelay(roll: number): number
	return 40 + roll * 50
end

-- Seconds until the next thunder strike, from a roll in [0, 1).
function Scares.thunderDelay(roll: number): number
	return 110 + roll * 80
end

local function flatCos(dx: number, dz: number, look: Point): number?
	local a = math.sqrt(dx * dx + dz * dz)
	local b = math.sqrt(look.X * look.X + look.Z * look.Z)
	if a < 1e-6 or b < 1e-6 then
		return nil
	end
	return (dx * look.X + dz * look.Z) / (a * b)
end

-- A spot for the figure seen from `eye` looking along `look`, or nil if none fits right now.
-- `roll` in [0, 1) picks among the spots that fit.
function Scares.pickSpot(spots: { Point }, eye: Point, look: Point, roll: number): Point?
	local fits = {}
	for _, spot in spots do
		local dx, dz = spot.X - eye.X, spot.Z - eye.Z
		local distance = math.sqrt(dx * dx + dz * dz)
		local cos = flatCos(dx, dz, look)
		if
			cos
			and distance >= Scares.FIGURE_MIN
			and distance <= Scares.FIGURE_MAX
			and cos >= Scares.SIDE_MIN
			and cos <= Scares.SIDE_MAX
		then
			table.insert(fits, spot)
		end
	end
	if #fits == 0 then
		return nil
	end
	return fits[math.min(#fits, math.floor(roll * #fits) + 1)]
end

-- True when someone at `eye` looking along `look` is looking right at the figure standing at `feet`.
function Scares.isSeen(eye: Point, look: Point, feet: Point): boolean
	local dx, dy, dz = feet.X - eye.X, feet.Y + Scares.FIGURE_HEAD - eye.Y, feet.Z - eye.Z
	local a = math.sqrt(dx * dx + dy * dy + dz * dz)
	local b = math.sqrt(look.X * look.X + look.Y * look.Y + look.Z * look.Z)
	if a < 1e-6 or b < 1e-6 then
		return true
	end
	return (dx * look.X + dy * look.Y + dz * look.Z) / (a * b) >= Scares.SEEN
end

return Scares
