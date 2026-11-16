-- A small Roblox-like world for headless tests of server code that builds things (the lobby
-- and the maps). Uses Lune's Roblox library for real Instances (so a wrong property type
-- fails like it does in Studio), loads src/shared and src/server as ModuleScripts the way Rojo
-- does, and stubs the few engine services the builders call (terrain, tags).
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local roblox = require("@lune/roblox")

local World = {}

local tags: { [string]: { any } } = {}

-- Tags live here (Lune's own Instance:AddTag would shadow a CollectionService method).
local CollectionService = {}
function CollectionService.AddTag(_, inst: any, tag: string)
	tags[tag] = tags[tag] or {}
	table.insert(tags[tag], inst)
end
function CollectionService.GetTagged(_, tag: string): { any }
	local alive = {}
	for _, inst in tags[tag] or {} do
		if inst.Parent ~= nil then
			table.insert(alive, inst)
		end
	end
	return alive
end
function CollectionService.HasTag(_, inst: any, tag: string): boolean
	return table.find(tags[tag] or {}, inst) ~= nil
end

for _, method in { "FillBlock", "FillBall", "FillCylinder", "FillWedge", "Clear" } do
	roblox.implementMethod("Terrain", method, function(_, ...)
		if method == "FillBlock" then
			local cf, size, material = ...
			assert(typeof(cf) == "CFrame", "FillBlock: CFrame expected")
			assert(typeof(size) == "Vector3", "FillBlock: Vector3 expected")
			assert(typeof(material) == "EnumItem", "FillBlock: material expected")
		end
	end)
end
for _, class in { "ReplicatedStorage", "Folder", "ModuleScript", "Script" } do
	roblox.implementMethod(class, "WaitForChild", function(self, name)
		return assert(self:FindFirstChild(name), "WaitForChild: no " .. name .. " in " .. self.Name)
	end)
end

-- Random is an engine type Lune does not have: a seeded stand-in.
local Random = {}
function Random.new(seed: number?)
	local s = (seed or 1) % 2147483647
	if s <= 0 then
		s += 2147483646
	end
	local function nextFloat(): number
		s = (s * 16807) % 2147483647
		return s / 2147483647
	end
	return {
		NextNumber = function(_, a: number?, b: number?)
			local f = nextFloat()
			if a == nil then
				return f
			end
			return a + ((b :: number) - a) * f
		end,
		NextInteger = function(_, a: number, b: number)
			return math.min(b, a + math.floor((b - a + 1) * nextFloat()))
		end,
	}
end

-- Builds a fresh game with the source tree in it. Returns `game` and a `require` for modules.
function World.new()
	tags = {}
	local game = roblox.Instance.new("DataModel")
	local workspace = game:GetService("Workspace")
	local terrain = roblox.Instance.new("Terrain")
	terrain.Name = "Terrain"
	terrain.Parent = workspace
	game:GetService("Lighting")
	-- what modules see as `game`: the real one, except for the tag service
	local gameForModules = {
		GetService = function(_, name: string)
			if name == "CollectionService" then
				return CollectionService
			end
			return game:GetService(name)
		end,
	}

	local sources: { [any]: string } = {}
	local function mirror(dir: string, parent: any, name: string)
		local initPath = dir .. "/init.luau"
		local folder
		if fs.isFile(initPath) then
			folder = roblox.Instance.new("ModuleScript")
			sources[folder] = fs.readFile(initPath)
		elseif fs.isFile(dir .. "/init.server.luau") then
			folder = roblox.Instance.new("Script")
		else
			folder = roblox.Instance.new("Folder")
		end
		folder.Name = name
		folder.Parent = parent
		for _, entry in fs.readDir(dir) do
			local path = dir .. "/" .. entry
			if fs.isDir(path) then
				mirror(path, folder, entry)
			elseif string.match(entry, "%.luau$") and not string.match(entry, "^init") then
				local moduleName = string.match(entry, "^(.-)%.luau$") :: string
				if not string.match(moduleName, "%.") then
					local m = roblox.Instance.new("ModuleScript")
					m.Name = moduleName
					m.Parent = folder
					sources[m] = fs.readFile(path)
				end
			end
		end
	end
	mirror("src/shared", game:GetService("ReplicatedStorage"), "Shared")
	mirror("src/server", game:GetService("ServerScriptService"), "Server")

	local loaded: { [any]: any } = {}
	local function requireModule(module: any): any
		if loaded[module] ~= nil then
			return loaded[module]
		end
		local source = assert(sources[module], "not a module: " .. tostring(module))
		local env = setmetatable({
			script = module,
			game = gameForModules,
			workspace = workspace,
			require = requireModule,
			Random = Random,
			Instance = roblox.Instance,
			Vector3 = roblox.Vector3,
			Vector2 = roblox.Vector2,
			CFrame = roblox.CFrame,
			Color3 = roblox.Color3,
			ColorSequence = roblox.ColorSequence,
			NumberSequence = roblox.NumberSequence,
			NumberSequenceKeypoint = roblox.NumberSequenceKeypoint,
			ColorSequenceKeypoint = roblox.ColorSequenceKeypoint,
			NumberRange = roblox.NumberRange,
			UDim = roblox.UDim,
			UDim2 = roblox.UDim2,
			Enum = roblox.Enum,
			Font = roblox.Font,
		}, { __index = _G })
		local fn = luau.load(source, { debugName = module:GetFullName(), environment = env })
		loaded[module] = fn()
		return loaded[module]
	end

	return game, requireModule
end

function World.tagged(tag: string): number
	local n = 0
	for _, inst in tags[tag] or {} do
		if inst.Parent ~= nil then
			n += 1
		end
	end
	return n
end

return World
