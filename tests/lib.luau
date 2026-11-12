-- Tiny test library: `test(name, fn)` registers a test, `expect(v)` asserts.
local lib = {}

lib.registered = {} :: { { name: string, fn: () -> () } }

function lib.test(name: string, fn: () -> ())
	table.insert(lib.registered, { name = name, fn = fn })
end

local function deepEqual(a: any, b: any): boolean
	if a == b then
		return true
	end
	if type(a) ~= "table" or type(b) ~= "table" then
		return false
	end
	for k, v in a do
		if not deepEqual(v, b[k]) then
			return false
		end
	end
	for k in b do
		if a[k] == nil then
			return false
		end
	end
	return true
end

local function show(v: any): string
	if type(v) ~= "table" then
		return tostring(v)
	end
	local parts = {}
	for k, x in v do
		table.insert(parts, tostring(k) .. "=" .. show(x))
	end
	table.sort(parts)
	return "{" .. table.concat(parts, ", ") .. "}"
end

function lib.expect(actual: any)
	return {
		toBe = function(expected: any)
			if actual ~= expected then
				error(`expected {show(expected)}, got {show(actual)}`, 2)
			end
		end,
		toEqual = function(expected: any)
			if not deepEqual(actual, expected) then
				error(`expected {show(expected)}, got {show(actual)}`, 2)
			end
		end,
		toBeNil = function()
			if actual ~= nil then
				error(`expected nil, got {show(actual)}`, 2)
			end
		end,
		toBeTruthy = function()
			if not actual then
				error(`expected truthy, got {show(actual)}`, 2)
			end
		end,
	}
end

return lib
