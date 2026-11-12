--!strict
-- Is a shot / swing / claw allowed? Pure. The server measures distance itself.
local Weapons = require("../Config/Weapons")

local HitValidation = {}

export type ShotInput = { role: string, distance: number, sinceLastShot: number, ammoInMag: number }
export type SwingInput = { role: string, distance: number, sinceLast: number }

function HitValidation.shot(input: ShotInput, weapon: typeof(Weapons.Revolver)?): (boolean, string?)
	local w = weapon or Weapons.Revolver
	if input.role ~= "Hunter" then
		return false, "not_hunter"
	end
	if input.ammoInMag <= 0 then
		return false, "no_ammo"
	end
	if input.sinceLastShot < w.fireInterval - 1e-6 then
		return false, "too_fast"
	end
	if input.distance > w.range then
		return false, "out_of_range"
	end
	return true, nil
end

function HitValidation.melee(input: SwingInput): (boolean, string?)
	if input.role ~= "Hunter" then
		return false, "not_hunter" -- survivors carry no weapons
	end
	if input.sinceLast < Weapons.Melee.interval - 1e-6 then
		return false, "too_fast"
	end
	if input.distance > Weapons.Melee.range then
		return false, "out_of_range"
	end
	return true, nil
end

function HitValidation.claw(input: SwingInput): (boolean, string?)
	if input.role ~= "Alpha" and input.role ~= "Zombie" then
		return false, "not_zombie"
	end
	if input.sinceLast < Weapons.Claw.interval - 1e-6 then
		return false, "too_fast"
	end
	if input.distance > Weapons.Claw.range then
		return false, "out_of_range"
	end
	return true, nil
end

return HitValidation
