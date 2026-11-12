--!strict
-- UI palette + small builders (cute-creepy pastel interface, spec "Look & Feel").
local Theme = {}

Theme.colors = {
	plum = Color3.fromRGB(27, 20, 40),
	dusk = Color3.fromRGB(58, 40, 86),
	ink = Color3.fromRGB(42, 31, 61),
	lavender = Color3.fromRGB(191, 169, 242),
	blood = Color3.fromRGB(255, 143, 184),
	mint = Color3.fromRGB(163, 234, 200),
	peach = Color3.fromRGB(255, 199, 154),
	baby = Color3.fromRGB(156, 200, 255),
	butter = Color3.fromRGB(255, 224, 138),
	bone = Color3.fromRGB(255, 246, 238),
}

Theme.roleColor = {
	Alpha = Theme.colors.blood,
	Zombie = Theme.colors.mint,
	Hunter = Theme.colors.peach,
	Survivor = Theme.colors.baby,
	["?"] = Theme.colors.lavender,
	["-"] = Theme.colors.lavender,
}

Theme.roleText =
	{ Alpha = "ALPHA", Zombie = "ZOMBIE", Hunter = "HUNTER", Survivor = "SURVIVOR", ["?"] = "?", ["-"] = "" }

Theme.titleFont = Enum.Font.Creepster
Theme.uiFont = Enum.Font.FredokaOne

function Theme.label(parent: Instance, props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Theme.uiFont
	l.TextColor3 = Theme.colors.bone
	l.TextStrokeColor3 = Theme.colors.ink
	l.TextStrokeTransparency = 0
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

function Theme.panel(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.colors.plum
	f.BackgroundTransparency = 0.15
	f.BorderSizePixel = 0
	for k, v in props do
		(f :: any)[k] = v
	end
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = f
	local stroke = Instance.new("UIStroke")
	stroke.Color = Theme.colors.ink
	stroke.Thickness = 3
	stroke.Parent = f
	f.Parent = parent
	return f
end

function Theme.bar(parent: Instance, props: { [string]: any }, fillColor: Color3): (Frame, Frame)
	local back = Theme.panel(parent, props)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BorderSizePixel = 0
	fill.BackgroundColor3 = fillColor
	fill.Size = UDim2.fromScale(1, 1)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = fill
	fill.Parent = back
	return back, fill
end

function Theme.timeText(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

return Theme
