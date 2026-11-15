--!strict
-- Role reveal emotes: your character, in the intro's role card, acts out the role it got.
-- The model sits in a ViewportFrame (no physics, no joints), so every body part is placed by
-- hand each frame: rest pose + a rotation around its joint. Works on R6 and R15.
--
--   Survivor  TERRIFIED  crouches, arms up to shield the face, shaking, head snapping around
--   Hunter    LOADED     raises the revolver, aims, scans, kicks back with a muzzle flash
--   Alpha     AWAKENING  hangs limp... then the head snaps up crooked, red eyes open, claws rise,
--                        and it glitches
--   Zombie    HUNGRY     shambles in place, arms reaching, head lolling, twitching
--
-- The pose fades in at `revealAt` seconds (default REVEAL), when the role card's light comes on.
local RoleEmote = {}
RoleEmote.__index = RoleEmote

local REVEAL = 1.7

type Group = { parts: { BasePart }, pivot: CFrame }

local GROUP_PARTS = {
	head = { "Head" },
	rightArm = { "Right Arm", "RightUpperArm", "RightLowerArm", "RightHand" },
	leftArm = { "Left Arm", "LeftUpperArm", "LeftLowerArm", "LeftHand" },
	rightLeg = { "Right Leg", "RightUpperLeg", "RightLowerLeg", "RightFoot" },
	leftLeg = { "Left Leg", "LeftUpperLeg", "LeftLowerLeg", "LeftFoot" },
}

local function smooth(x: number): number
	local c = math.clamp(x, 0, 1)
	return c * c * (3 - 2 * c)
end

local function rot(x: number, y: number, z: number): CFrame
	return CFrame.Angles(x, y, z)
end

-- `model` must already be staged (pivoted to the origin, facing -Z).
function RoleEmote.new(model: Model, role: string, revealAt: number?)
	local pivot = model:GetPivot()
	local rest: { [BasePart]: CFrame } = {}
	local groupOf: { [BasePart]: string } = {}
	local byName: { [string]: BasePart } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			rest[d] = pivot:ToObjectSpace(d.CFrame)
			byName[d.Name] = byName[d.Name] or d
		end
	end
	for group, names in GROUP_PARTS do
		for _, name in names do
			local p = model:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				groupOf[p] = group
			end
		end
	end
	-- hats and hair follow the part they're attached to; glowing eyes follow the head
	for _, d in model:GetDescendants() do
		if d:IsA("Accessory") then
			local handle = d:FindFirstChild("Handle")
			local weld = handle and handle:FindFirstChildWhichIsA("JointInstance")
			local attached = weld
				and ((weld :: any).Part1 ~= handle and (weld :: any).Part1 or (weld :: any).Part0)
			if handle and handle:IsA("BasePart") and attached and groupOf[attached] then
				groupOf[handle] = groupOf[attached]
			end
		elseif d:IsA("BasePart") and d.Name == "Eye" then
			groupOf[d] = "head"
		end
	end

	local function top(name: string, inset: number): CFrame?
		local p = byName[name]
		return if p then rest[p] * CFrame.new(0, p.Size.Y / 2 - inset, 0) else nil
	end
	local head = byName.Head
	local pivots: { [string]: CFrame } = {
		head = if head then rest[head] * CFrame.new(0, -head.Size.Y / 2, 0) else CFrame.new(0, 1, 0),
		rightArm = top("Right Arm", 0.5) or top("RightUpperArm", 0.15) or CFrame.new(1.5, 0.5, 0),
		leftArm = top("Left Arm", 0.5) or top("LeftUpperArm", 0.15) or CFrame.new(-1.5, 0.5, 0),
		rightLeg = top("Right Leg", 0) or top("RightUpperLeg", 0) or CFrame.new(0.5, -1, 0),
		leftLeg = top("Left Leg", 0) or top("LeftUpperLeg", 0) or CFrame.new(-0.5, -1, 0),
	}
	-- pivots keep only their position: rotations are in model axes (front = -Z, right = +X)
	for k, cf in pivots do
		pivots[k] = CFrame.new(cf.Position)
	end

	local self = setmetatable({
		model = model,
		role = role,
		rest = rest,
		groupOf = groupOf,
		pivots = pivots,
		props = {} :: { [string]: BasePart },
		reveal = revealAt or REVEAL,
		glitchUntil = 0,
		nextGlitch = (revealAt or REVEAL) + 1.2,
	}, RoleEmote)
	self:addProps(byName)
	return self
end

-- A part that moves with a group (gun, eyes). `at` is in model space.
function RoleEmote.prop(self: any, name: string, group: string, size: Vector3, at: CFrame, color: Color3)
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.Color = color
	p.Material = Enum.Material.Neon
	p.CFrame = self.model:GetPivot() * at
	p.Parent = self.model
	self.rest[p] = at
	self.groupOf[p] = group
	self.props[name] = p
	return p
end

function RoleEmote.addProps(self: any, byName: { [string]: BasePart })
	local hand = byName.RightHand or byName["Right Arm"]
	local head = byName.Head
	if self.role == "Hunter" and hand then
		-- a revolver held along the arm, so raising the arm aims it
		local below = self.rest[hand] * CFrame.new(0, -hand.Size.Y / 2, -0.1)
		local gun = self:prop(
			"Gun",
			"rightArm",
			Vector3.new(0.3, 1.4, 0.45),
			below * CFrame.new(0, -0.6, 0),
			Color3.fromRGB(40, 40, 46)
		)
		gun.Material = Enum.Material.Metal
		local flash = self:prop(
			"Flash",
			"rightArm",
			Vector3.new(0.6, 0.6, 0.6),
			below * CFrame.new(0, -1.45, 0),
			Color3.fromRGB(255, 224, 138)
		)
		flash.Shape = Enum.PartType.Ball
		flash.Transparency = 1
	end
	if head and (self.role == "Alpha" or self.role == "Zombie") then
		local color = if self.role == "Alpha"
			then Color3.fromRGB(255, 40, 60)
			else Color3.fromRGB(163, 234, 200)
		for i, x in { -0.22, 0.22 } do
			local eye = self:prop(
				`GlowEye{i}`,
				"head",
				Vector3.new(0.24, 0.24, 0.1),
				self.rest[head] * CFrame.new(x, 0.15, -head.Size.Z / 2 - 0.03),
				color
			)
			eye.Shape = Enum.PartType.Ball
			eye.Transparency = 1
		end
	end
end

-- The pose at time `t` (seconds since the card started): body offset + rotation per group.
function RoleEmote.pose(self: any, t: number): (CFrame, { [string]: CFrame })
	local k = smooth((t - self.reveal) / 0.5) -- 0 before the reveal, 1 after
	local after = math.max(0, t - self.reveal)
	local role = self.role
	if role == "Survivor" then
		local shake = math.sin(t * 55) * 0.025 * k
		local look = if math.floor(after / 0.9) % 2 == 0 then 0.55 else -0.5
		return CFrame.new(shake, -0.35 * k, 0) * rot(0.18 * k, 0, shake),
			{
				head = rot(-0.15 * k, look * k, 0),
				rightArm = rot(2.3 * k, 0, -0.55 * k),
				leftArm = rot(2.2 * k, 0, 0.6 * k),
				rightLeg = rot(0.25 * k, 0, 0),
				leftLeg = rot(-0.1 * k, 0, 0),
			}
	elseif role == "Hunter" then
		local cycle = after % 1.4
		local kick = if cycle < 0.08
			then cycle / 0.08
			elseif cycle < 0.35 then 1 - (cycle - 0.08) / 0.27
			else 0
		kick *= k
		local scan = math.sin(after * 1.3) * 0.35 * k
		local flash = self.props.Flash
		if flash then
			flash.Transparency = if k > 0.9 and cycle < 0.07 then 0.1 else 1
		end
		return CFrame.new(0, 0, 0.12 * kick) * rot(0, scan, 0),
			{
				head = rot(-0.05 * k, 0.1 * k, 0),
				rightArm = rot((1.55 + 0.35 * kick) * k, 0, -0.12 * k),
				leftArm = rot((1.35 + 0.3 * kick) * k, 0, 0.75 * k),
				rightLeg = rot(-0.15 * k, 0, 0),
				leftLeg = rot(0.25 * k, 0, 0),
			}
	elseif role == "Alpha" then
		-- limp, head hanging... then it wakes up wrong
		local limp = 1 - k
		local glitch = t < self.glitchUntil
		if t > self.nextGlitch then
			self.glitchUntil = t + 0.12
			self.nextGlitch = t + 0.9 + math.random() * 1.2
		end
		local g = if glitch then 1 else 0
		local twitch = g * (math.random() - 0.5)
		local rise = smooth((t - self.reveal) / 1.6)
		for i = 1, 2 do
			local eye = self.props[`GlowEye{i}`]
			if eye then
				eye.Transparency = 1 - smooth((t - self.reveal) / 0.4)
			end
		end
		return CFrame.new(twitch * 0.4, -0.15 * limp + math.sin(after * 1.2) * 0.04, 0) * rot(
			0.25 * limp,
			twitch * 0.5,
			0
		),
			{
				head = rot(-1.0 * limp + 0.15 * k, twitch * 1.2, 0.55 * k + twitch * 0.8),
				rightArm = rot(rise * 1.7 + math.sin(after * 4) * 0.06 * k, 0, 0.15 * limp - 0.1 * k),
				leftArm = rot(rise * 1.45 + math.sin(after * 4 + 1) * 0.06 * k, 0, -0.15 * limp + 0.1 * k),
				rightLeg = rot(0, 0, 0.05 * limp),
				leftLeg = rot(0, 0, -0.05 * limp),
			}
	else -- Zombie
		local step = math.sin(after * 2.2)
		local twitch = if math.random() < 0.02 then (math.random() - 0.5) * 0.6 else 0
		for i = 1, 2 do
			local eye = self.props[`GlowEye{i}`]
			if eye then
				eye.Transparency = 1 - k
			end
		end
		return CFrame.new(step * 0.08 * k, math.abs(step) * -0.06 * k, 0) * rot(0.12 * k, 0, step * 0.08 * k),
			{
				head = rot(-0.25 * k, twitch, (0.35 + math.sin(after * 1.1) * 0.25) * k),
				rightArm = rot((1.5 + step * 0.12) * k, 0, 0),
				leftArm = rot((1.4 - step * 0.12) * k, 0, 0),
				rightLeg = rot(step * 0.35 * k, 0, 0),
				leftLeg = rot(-step * 0.35 * k, 0, 0),
			}
	end
end

-- Places every part for time `t`, with the whole model at `base` (the card's slow sway).
function RoleEmote.step(self: any, t: number, base: CFrame)
	if not self.model.Parent then
		return
	end
	local body, groups = self:pose(t)
	local root = base * body
	local xform: { [string]: CFrame } = {}
	for group, r in groups do
		local pivot = self.pivots[group]
		xform[group] = pivot * r * pivot:Inverse()
	end
	for part, restCf in self.rest do
		local group = self.groupOf[part]
		local g = group and xform[group]
		part.CFrame = if g then root * g * restCf else root * restCf
	end
end

return RoleEmote
