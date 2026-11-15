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
	l.TextStrokeTransparency = 0.55 -- a soft outline: readable over the dark world, not heavy
	l.TextScaled = true
	for k, v in props do
		(l :: any)[k] = v
	end
	l.Parent = parent
	return l
end

-- Glass look for every HUD box: dark see-through plum, soft corners, a thin lavender edge.
function Theme.glass(g: GuiObject, round: boolean?): GuiObject
	g.BackgroundColor3 = Theme.colors.plum
	g.BackgroundTransparency = 0.3
	g.BorderSizePixel = 0
	local corner = Instance.new("UICorner")
	corner.CornerRadius = if round then UDim.new(1, 0) else UDim.new(0, 10)
	corner.Parent = g
	local stroke = Instance.new("UIStroke")
	stroke.Name = "Edge"
	stroke.Color = Theme.colors.lavender
	stroke.Thickness = 1
	stroke.Transparency = 0.65
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = g
	return g
end

function Theme.panel(parent: Instance, props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	Theme.glass(f)
	for k, v in props do
		(f :: any)[k] = v
	end
	f.Parent = parent
	return f
end

-- A small pill with text (grows with its text). Returns the TextLabel itself.
function Theme.chip(parent: Instance, props: { [string]: any }): TextLabel
	local l = Theme.label(parent, {
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		TextScaled = false,
		TextSize = 14,
	})
	Theme.glass(l, true)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 12)
	pad.PaddingRight = UDim.new(0, 12)
	pad.Parent = l
	for k, v in props do
		(l :: any)[k] = v
	end
	return l
end

-- A pill button in the glass style.
function Theme.button(parent: Instance, props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	Theme.glass(b, true)
	b.Font = Theme.uiFont
	b.TextScaled = false
	b.TextSize = 13
	b.TextColor3 = Theme.colors.lavender
	b.AutoButtonColor = true
	for k, v in props do
		(b :: any)[k] = v
	end
	b.Parent = parent
	return b
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
