--!strict
-- Repair "emote": every character with the "Repairing" attribute (set by the server while they
-- fix a radio tower) holds a wrench in the right hand and hammers at the box, left hand steadying
-- it, with a few sparks on every hit. Drawn on each client for every player, so everyone sees it.
-- No animation asset needed: it bends the shoulder joints. Works on R6 and R15.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)

local RepairAnimController = {}

type Rig = {
	right: Motor6D,
	left: Motor6D,
	rightC0: CFrame,
	leftC0: CFrame,
	r15: boolean,
	hand: BasePart,
	wrench: BasePart,
	sparks: ParticleEmitter,
	started: number,
	lastHit: number,
}

local rigs: { [Model]: Rig } = {}

local SWINGS_PER_SECOND = 2.2

local function findMotor(char: Model, names: { string }): Motor6D?
	for _, name in names do
		local m = char:FindFirstChild(name, true)
		if m and m:IsA("Motor6D") then
			return m
		end
	end
	return nil
end

local function start(char: Model)
	if rigs[char] then
		return
	end
	local right = findMotor(char, { "Right Shoulder", "RightShoulder" })
	local left = findMotor(char, { "Left Shoulder", "LeftShoulder" })
	local hand = (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm")) :: BasePart?
	if not right or not left or not hand then
		return
	end
	-- a small wrench in the right hand (local only: every client makes its own)
	local wrench = Instance.new("Part")
	wrench.Name = "RepairWrench"
	wrench.Size = Vector3.new(0.25, 0.25, 1.6)
	wrench.Color = Color3.fromRGB(150, 150, 160)
	wrench.Material = Enum.Material.Metal
	wrench.CanCollide = false
	wrench.CanQuery = false
	wrench.CanTouch = false
	wrench.Massless = true
	local tip = Instance.new("Part")
	tip.Name = "Head"
	tip.Size = Vector3.new(0.6, 0.3, 0.35)
	tip.Color = wrench.Color
	tip.Material = Enum.Material.Metal
	tip.CanCollide = false
	tip.CanQuery = false
	tip.CanTouch = false
	tip.Massless = true
	local handBottom = hand.CFrame * CFrame.new(0, -hand.Size.Y / 2, 0)
	wrench.CFrame = handBottom * CFrame.new(0, 0, -0.7)
	tip.CFrame = wrench.CFrame * CFrame.new(0, 0, -0.8)
	for _, p in { wrench, tip } do
		local w = Instance.new("WeldConstraint")
		w.Part0 = hand
		w.Part1 = p
		w.Parent = p
		p.Parent = char
	end
	tip.Parent = wrench
	local sparks = Instance.new("ParticleEmitter")
	sparks.Rate = 0
	sparks.Lifetime = NumberRange.new(0.15, 0.35)
	sparks.Speed = NumberRange.new(6, 12)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.Size = NumberSequence.new(0.12, 0)
	sparks.Color = ColorSequence.new(Theme.colors.butter)
	sparks.LightEmission = 1
	sparks.Acceleration = Vector3.new(0, -30, 0)
	sparks.Parent = tip
	rigs[char] = {
		right = right,
		left = left,
		rightC0 = right.C0,
		leftC0 = left.C0,
		r15 = right.Name == "RightShoulder",
		hand = hand,
		wrench = wrench,
		sparks = sparks,
		started = os.clock(),
		lastHit = 0,
	}
end

local function stop(char: Model)
	local rig = rigs[char]
	if not rig then
		return
	end
	rigs[char] = nil
	if rig.right.Parent then
		rig.right.C0 = rig.rightC0
	end
	if rig.left.Parent then
		rig.left.C0 = rig.leftC0
	end
	rig.wrench:Destroy()
end

-- Arm angles: "raise" lifts the arm forward (radians). R6 shoulders turn around their Z axis
-- (mirrored on the left), R15 shoulders around X.
local function bend(rig: Rig, motor: Motor6D, c0: CFrame, raise: number, isLeft: boolean)
	if rig.r15 then
		motor.C0 = c0 * CFrame.Angles(raise, 0, 0)
	else
		motor.C0 = c0 * CFrame.Angles(0, 0, if isLeft then -raise else raise)
	end
end

local function step()
	local now = os.clock()
	for char, rig in rigs do
		if not char.Parent or not rig.right.Parent then
			rigs[char] = nil
			continue
		end
		local t = (now - rig.started) * SWINGS_PER_SECOND
		local phase = t % 1
		-- quick strike down, slower lift back up
		local swing = if phase < 0.3 then 1 - phase / 0.3 else (phase - 0.3) / 0.7
		bend(rig, rig.right, rig.rightC0, 1.1 + swing * 0.9, false)
		bend(rig, rig.left, rig.leftC0, 1.2 + math.sin(now * 3) * 0.05, true)
		-- sparks right when the wrench comes down
		local hit = math.floor(t)
		if phase >= 0.28 and phase < 0.45 and hit ~= rig.lastHit then
			rig.lastHit = hit
			rig.sparks:Emit(5)
		end
	end
end

local function watchCharacter(char: Model)
	local function update()
		if char:GetAttribute("Repairing") == true then
			start(char)
		else
			stop(char)
		end
	end
	char:GetAttributeChangedSignal("Repairing"):Connect(update)
	char.AncestryChanged:Connect(function()
		if not char.Parent then
			stop(char)
		end
	end)
	update()
end

local function watchPlayer(p: Player)
	if p.Character then
		watchCharacter(p.Character)
	end
	p.CharacterAdded:Connect(watchCharacter)
end

function RepairAnimController.start()
	for _, p in Players:GetPlayers() do
		watchPlayer(p)
	end
	Players.PlayerAdded:Connect(watchPlayer)
	RunService.RenderStepped:Connect(step)
end

return RepairAnimController
