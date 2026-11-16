--!strict
-- Night lighting and weather per map: the sky, the fog (an Atmosphere, so it looks like real mist and hides
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
	-- the weather the clients draw around each player (AtmosphereController)
	weather: "None" | "Drizzle" | "Rain",
	groundFog: number, -- 0..1: the low mist hugging the ground
	thunder: boolean, -- lightning, then every light on the map dies for a moment
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
			density = 0.5,
			offset = 0.1,
			color = Color3.fromRGB(62, 62, 76),
			decay = Color3.fromRGB(25, 25, 60),
			haze = 2.4,
			glare = 0,
		},
		grade = {
			brightness = -0.02,
			contrast = 0.16,
			saturation = -0.38,
			tint = Color3.fromRGB(228, 228, 250),
		},
		bloom = { intensity = 0.75, size = 30, threshold = 1.5 },
		weather = "Drizzle",
		groundFog = 0.6,
		thunder = true,
	} :: Preset,
	-- cold moonlight through the pines, thick low mist over the lake
	ForestCamp = {
		clock = 23.6,
		brightness = 1.5,
		ambient = Color3.fromRGB(16, 22, 24),
		outdoor = Color3.fromRGB(34, 46, 54),
		exposure = -0.1,
		fog = {
			density = 0.52,
			offset = 0.05,
			color = Color3.fromRGB(58, 70, 76),
			decay = Color3.fromRGB(24, 34, 40),
			haze = 2.8,
			glare = 0,
		},
		grade = {
			brightness = -0.02,
			contrast = 0.17,
			saturation = -0.4,
			tint = Color3.fromRGB(220, 236, 242),
		},
		bloom = { intensity = 0.8, size = 34, threshold = 1.5 },
		weather = "Drizzle",
		groundFog = 1,
		thunder = false,
	} :: Preset,
	-- buzzing fluorescent green inside, wet sodium haze outside
	School = {
		clock = 0.4,
		brightness = 1.1,
		ambient = Color3.fromRGB(18, 22, 20),
		outdoor = Color3.fromRGB(36, 42, 50),
		exposure = -0.15,
		fog = {
			density = 0.44,
			offset = 0.08,
			color = Color3.fromRGB(58, 64, 62),
			decay = Color3.fromRGB(30, 36, 34),
			haze = 2.2,
			glare = 0,
		},
		grade = {
			brightness = -0.02,
			contrast = 0.16,
			saturation = -0.4,
			tint = Color3.fromRGB(224, 242, 230),
		},
		bloom = { intensity = 0.75, size = 30, threshold = 1.5 },
		weather = "Rain",
		groundFog = 0.4,
		thunder = true,
	} :: Preset,
	-- pale, dead mall light with a pink neon tint
	Mall = {
		clock = 0.1,
		brightness = 1.1,
		ambient = Color3.fromRGB(22, 20, 26),
		outdoor = Color3.fromRGB(42, 38, 52),
		exposure = -0.1,
		fog = {
			density = 0.42,
			offset = 0.1,
			color = Color3.fromRGB(66, 60, 74),
			decay = Color3.fromRGB(36, 28, 44),
			haze = 2,
			glare = 0,
		},
		grade = {
			brightness = -0.02,
			contrast = 0.15,
			saturation = -0.3,
			tint = Color3.fromRGB(242, 230, 242),
		},
		bloom = { intensity = 0.9, size = 32, threshold = 1.4 },
		weather = "Drizzle",
		groundFog = 0.3,
		thunder = true,
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

	-- the clients read these to draw the weather; the server's thunder reads `Thunder`
	workspace:SetAttribute("Weather", p.weather)
	workspace:SetAttribute("GroundFog", p.groundFog)
	workspace:SetAttribute("Thunder", p.thunder)
end

return MapLighting
