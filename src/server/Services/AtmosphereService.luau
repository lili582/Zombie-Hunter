--!strict
-- Thunder on stormy maps (the map's lighting preset sets workspace "Thunder"): every couple of
-- minutes the sky flashes twice, then every light on the map dies for a moment and comes back.
-- Clients shake the camera when "LastThunder" changes (AtmosphereController). The flicker loop
-- leaves the lights alone while "Blackout" is on.
local Lighting = game:GetService("Lighting")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Scares = require(Shared.Rules.Scares)

local AtmosphereService = {}

local BLACKOUT_SECONDS = 1.5
local strikes = 0

local function flash(seconds: number)
	local brightness, outdoor, exposure =
		Lighting.Brightness, Lighting.OutdoorAmbient, Lighting.ExposureCompensation
	Lighting.Brightness = 6
	Lighting.OutdoorAmbient = Color3.fromRGB(190, 200, 235)
	Lighting.ExposureCompensation = exposure + 1.2
	task.wait(seconds)
	Lighting.Brightness = brightness
	Lighting.OutdoorAmbient = outdoor
	Lighting.ExposureCompensation = exposure
end

-- Every light on the map off for a moment (the safehouse keeps its fire going).
local function blackout()
	local map = workspace:FindFirstChild("Map")
	if not map then
		return
	end
	workspace:SetAttribute("Blackout", true)
	local wasOn = {}
	for _, inst in map:GetDescendants() do
		if inst:IsA("Light") and inst.Enabled then
			inst.Enabled = false
			table.insert(wasOn, inst)
		end
	end
	task.wait(BLACKOUT_SECONDS)
	for _, light in wasOn do
		if light.Parent then
			light.Enabled = true
		end
	end
	workspace:SetAttribute("Blackout", false)
end

function AtmosphereService.strike()
	strikes += 1
	flash(0.08)
	task.wait(0.12)
	flash(0.06)
	workspace:SetAttribute("LastThunder", strikes)
	task.wait(0.4)
	blackout()
end

function AtmosphereService.start()
	task.spawn(function()
		while true do
			task.wait(Scares.thunderDelay(math.random()))
			if workspace:GetAttribute("Thunder") == true then
				AtmosphereService.strike()
			end
		end
	end)
end

return AtmosphereService
