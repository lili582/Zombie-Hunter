--!strict
-- Night lighting per map: the sky, the fog (an Atmosphere, so it looks like real mist and hides
-- the distance), colour grading, a soft bloom on lights and a touch of depth of field. Uses the
-- Future lighting technology (set in default.project.json) for real shadows from every light.
local Lighting = game:GetService("Lighting")

local MapLighting = {}

export type Preset = {
	clock: number,
	brightness: number,
	ambient: Color3,
	outdoor: Color3,
	exposure: number,
	fog: { density: number, offset: number, color: Color3, decay: Color3, haze: number, glare: number },
	grade: { brightness: number, contrast: number, saturation: number, tint: Color3 },
	bloom: { intensity: number, size: number, threshold: number },
}

MapLighting.PRESETS = {
	-- sodium-orange street haze, cold blue shadows
	Town = {
		clock = 0.2,
		brightness = 1.2,
		ambient = Color3.fromRGB(22, 20, 30),
		outdoor = Color3.fromRGB(40, 40, 58),
		exposure = -0.2,
		fog = {
			density = 0.42,
			offset = 0.1,
			color = Color3.fromRGB(70, 66, 82),
			decay = Color3.fromRGB(40, 32, 48),
			haze = 2.2,
			glare = 0,
		},
		grade = { brightness = 0, contrast = 0.12, saturation = -0.25, tint = Color3.fromRGB(235, 228, 255) },
		bloom = { intensity = 0.7, size = 30, threshold = 1.6 },
	} :: Preset,
	-- cold moonlight through the pines, thick low mist over the lake
	ForestCamp = {
		clock = 23.6,
		brightness = 1.5,
		ambient = Color3.fromRGB(16, 22, 24),
		outdoor = Color3.fromRGB(34, 46, 54),
		exposure = -0.1,
		fog = {
			density = 0.47,
			offset = 0.05,
			color = Color3.fromRGB(64, 78, 84),
			decay = Color3.fromRGB(28, 40, 42),
			haze = 2.6,
			glare = 0,
		},
		grade = { brightness = 0, contrast = 0.15, saturation = -0.3, tint = Color3.fromRGB(222, 240, 245) },
		bloom = { intensity = 0.8, size = 34, threshold = 1.5 },
	} :: Preset,
}

local function effect(className: string, name: string): any
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	if existing then
		existing:Destroy()
	end
	local e = Instance.new(className)
	e.Name = name
	e.Parent = Lighting
	return e
end

-- Puts a map's night on. Unknown maps get the Town night.
function MapLighting.apply(mapId: string)
	local p: Preset = (MapLighting.PRESETS :: any)[mapId] or MapLighting.PRESETS.Town
	Lighting.ClockTime = p.clock
	Lighting.Brightness = p.brightness
	Lighting.Ambient = p.ambient
	Lighting.OutdoorAmbient = p.outdoor
	Lighting.ExposureCompensation = p.exposure
	Lighting.GlobalShadows = true
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.6
	Lighting.FogEnd = 100000 -- the Atmosphere does the fog now

	local atmosphere = effect("Atmosphere", "ZH_Fog")
	atmosphere.Density = p.fog.density
	atmosphere.Offset = p.fog.offset
	atmosphere.Color = p.fog.color
	atmosphere.Decay = p.fog.decay
	atmosphere.Haze = p.fog.haze
	atmosphere.Glare = p.fog.glare

	local grade = effect("ColorCorrectionEffect", "ZH_Grade")
	grade.Brightness = p.grade.brightness
	grade.Contrast = p.grade.contrast
	grade.Saturation = p.grade.saturation
	grade.TintColor = p.grade.tint

	local bloom = effect("BloomEffect", "ZH_Bloom")
	bloom.Intensity = p.bloom.intensity
	bloom.Size = p.bloom.size
	bloom.Threshold = p.bloom.threshold

	local depth = effect("DepthOfFieldEffect", "ZH_Depth")
	depth.FarIntensity = 0.12
	depth.FocusDistance = 40
	depth.InFocusRadius = 40
	depth.NearIntensity = 0
end

return MapLighting
