--!strict
-- Seedable xorshift32 random generator. Pure: works in Roblox and Lune.
local Rng = {}
Rng.__index = Rng

function Rng.new(seed: number)
	local s = bit32.band(math.floor(math.abs(seed)), 0xFFFFFFFF)
	if s == 0 then
		s = 0x9E3779B9
	end
	return setmetatable({ state = s }, Rng)
end

function Rng.next(self: any): number
	local x = self.state
	x = bit32.bxor(x, bit32.lshift(x, 13))
	x = bit32.bxor(x, bit32.rshift(x, 17))
	x = bit32.bxor(x, bit32.lshift(x, 5))
	self.state = x
	return x
end

-- Float in [0, 1)
function Rng.float(self: any): number
	return Rng.next(self) / 4294967296
end

-- Integer in [min, max], inclusive
function Rng.int(self: any, min: number, max: number): number
	return min + math.floor(Rng.float(self) * (max - min + 1))
end

return Rng
