--!strict
-- Spawns characters and applies each role's look, health, speed, tools and lights.
-- Keeps the player's own outfit; zombies only get their skin recolored.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local Classic = require(Shared.Config.Classic)

local CharacterService = {}

local ROLE_COLORS = {
	Alpha = Color3.fromRGB(255, 143, 184), -- candy pink
	Zombie = Color3.fromRGB(163, 234, 200), -- zombie mint
	Hunter = Color3.fromRGB(255, 199, 154), -- peach
	Survivor = Color3.fromRGB(156, 200, 255), -- baby blue
}
local ZOMBIE_SKIN = Color3.fromRGB(118, 156, 96)
local ALPHA_SKIN = Color3.fromRGB(96, 112, 86)

local diedCallback: ((Player, Model) -> ())? = nil

function CharacterService.onDied(callback: (Player, Model) -> ())
	diedCallback = callback
end

local function humanoidOf(player: Player): Humanoid?
	local char = player.Character
	return if char then char:FindFirstChildOfClass("Humanoid") else nil
end

local function weld(part: BasePart, to: BasePart, offset: CFrame)
	part.Anchored = false
	part.CanCollide = false
	part.Massless = true
	part.CFrame = to.CFrame * offset
	local w = Instance.new("WeldConstraint")
	w.Part0 = to
	w.Part1 = part
	w.Parent = part
end

local function makeTool(name: string, handleSize: Vector3?, color: Color3?): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.CanBeDropped = false
	if handleSize then
		local handle = Instance.new("Part")
		handle.Name = "Handle"
		handle.Size = handleSize
		handle.Color = color or Color3.new(0.2, 0.2, 0.2)
		handle.CanCollide = false
		handle.Parent = tool
		tool.RequiresHandle = true
	else
		tool.RequiresHandle = false
	end
	return tool
end

local function skin(char: Model, color: Color3)
	local bc = char:FindFirstChildOfClass("BodyColors")
	if bc then
		bc.HeadColor3 = color
		bc.TorsoColor3 = color
		bc.LeftArmColor3 = color
		bc.RightArmColor3 = color
		bc.LeftLegColor3 = color
		bc.RightLegColor3 = color
	end
	for _, name in { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" } do
		local p = char:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			p.Color = color
		end
	end
end

local function eyes(char: Model, color: Color3, size: number)
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	for _, x in { -0.25, 0.25 } do
		local e = Instance.new("Part")
		e.Name = "Eye"
		e.Shape = Enum.PartType.Ball
		e.Size = Vector3.new(size, size, size)
		e.Material = Enum.Material.Neon
		e.Color = color
		weld(e, head, CFrame.new(x, 0.15, -0.55))
		e.Parent = char
	end
	local glow = Instance.new("PointLight")
	glow.Name = "EyeGlow"
	glow.Color = color
	glow.Range = 6
	glow.Brightness = 2
	glow.Parent = head
end

local function flashlight(char: Model)
	local head = char:FindFirstChild("Head")
	if head and not head:FindFirstChild("Flashlight") then
		local light = Instance.new("SpotLight")
		light.Name = "Flashlight"
		light.Face = Enum.NormalId.Front
		light.Range = 30
		light.Angle = 50
		light.Brightness = 3
		light.Color = Color3.fromRGB(255, 240, 200)
		light.Shadows = true
		light.Parent = head
	end
end

-- No floating names or health bars over heads: you can't spot or identify players from far away.
local function hideNameTag(hum: Humanoid)
	local distance = Classic.nameTagDistance
	if distance <= 0 then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	else
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Subject
		hum.NameDisplayDistance = distance
		hum.HealthDisplayDistance = distance
	end
	hum.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
end

local function setStats(hum: Humanoid, health: number, speed: number)
	hum.MaxHealth = health
	hum.Health = health
	hum.WalkSpeed = speed
	hum.UseJumpPower = true
	hum.JumpPower = 50
end

function CharacterService.giveTools(player: Player, role: string)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return
	end
	backpack:ClearAllChildren()
	if player.Character then
		for _, t in player.Character:GetChildren() do
			if t:IsA("Tool") then
				t:Destroy()
			end
		end
	end
	-- Survivors get no weapons: they hide, repair, revive and escape attacks with timing.
	-- Their only item is a medkit (heals one hit).
	if role == "Survivor" then
		local kit = makeTool("Medkit", Vector3.new(1, 0.8, 0.5), Color3.fromRGB(240, 240, 240))
		local handle = kit:FindFirstChild("Handle") :: BasePart
		for _, size in { Vector3.new(0.6, 0.18, 0.55), Vector3.new(0.18, 0.6, 0.55) } do -- red cross
			local bar = Instance.new("Part")
			bar.Name = "Cross"
			bar.Size = size
			bar.Color = Color3.fromRGB(255, 80, 100)
			bar.CanCollide = false
			bar.Massless = true
			bar.CFrame = handle.CFrame
			local w = Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = bar
			w.Parent = bar
			bar.Parent = kit
		end
		kit.Parent = backpack
	elseif role == "Hunter" then
		makeTool("Revolver", Vector3.new(0.4, 0.9, 1.8), Color3.fromRGB(40, 40, 44)).Parent = backpack
		makeTool("Bat", Vector3.new(0.4, 4, 0.4), Color3.fromRGB(120, 85, 50)).Parent = backpack
	elseif role == "Alpha" or role == "Zombie" then
		local claws = makeTool("Claws", nil)
		claws.Parent = backpack
		local hum = humanoidOf(player)
		if hum then
			hum:EquipTool(claws) -- tapping/clicking anywhere attacks
		end
	end
end

-- Look + stats for a role on the current character (no respawn).
function CharacterService.applyRole(player: Player, role: string)
	local char = player.Character
	local hum = humanoidOf(player)
	if not char or not hum then
		return
	end
	if role == "Alpha" then
		-- Disguised: looks, moves and lights up exactly like a survivor (own skin, flashlight,
		-- human speed). Only an attack shows the zombie face, for a moment (revealAlpha).
		setStats(hum, Weapons.health.alpha, Weapons.speed.human)
		flashlight(char)
	elseif role == "Zombie" then
		skin(char, ZOMBIE_SKIN)
		eyes(char, ROLE_COLORS.Zombie, 0.25)
		setStats(hum, Weapons.health.basic, Weapons.speed.basic)
	else
		setStats(hum, Weapons.health.human, Weapons.speed.human)
		flashlight(char)
		-- secret roles: the Hunter looks like everyone else (no hat, no name tag)
	end
	CharacterService.giveTools(player, role)
end

-- The Alpha's true face, shown for `seconds` when he attacks, then hidden again.
-- Attacking again while revealed keeps the face on longer.
local revealToken: { [Model]: number } = {}
local savedLook: { [Model]: { [Instance]: { [string]: any } } } = {}
local LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local BODY_COLOR_PROPS =
	{ "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

function CharacterService.revealAlpha(player: Player, seconds: number)
	local char = player.Character
	local hum = humanoidOf(player)
	if not char or not hum then
		return
	end
	revealToken[char] = (revealToken[char] or 0) + 1
	local my = revealToken[char]
	if not savedLook[char] then
		local saved = {}
		local bc = char:FindFirstChildOfClass("BodyColors")
		if bc then
			saved[bc] = {}
			for _, prop in BODY_COLOR_PROPS do
				saved[bc][prop] = (bc :: any)[prop]
			end
		end
		for _, name in LIMBS do
			local p = char:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				saved[p] = { Color = p.Color }
			end
		end
		savedLook[char] = saved
		skin(char, ALPHA_SKIN)
		eyes(char, Color3.fromRGB(255, 40, 60), 0.35)
		local head = char:FindFirstChild("Head")
		local light = head and head:FindFirstChild("Flashlight") :: SpotLight?
		if light then
			light.Enabled = false
		end
		hum.WalkSpeed = Weapons.speed.alpha -- faster while the mask is off
	end
	task.delay(seconds, function()
		if revealToken[char] ~= my or not char.Parent then
			return
		end
		local saved = savedLook[char]
		savedLook[char] = nil
		revealToken[char] = nil
		if saved then
			for inst, props in saved do
				for prop, value in props do
					(inst :: any)[prop] = value
				end
			end
		end
		for _, d in char:GetChildren() do
			if d.Name == "Eye" then
				d:Destroy()
			end
		end
		local head = char:FindFirstChild("Head")
		if head then
			local glow = head:FindFirstChild("EyeGlow")
			if glow then
				glow:Destroy()
			end
			local light = head:FindFirstChild("Flashlight") :: SpotLight?
			if light then
				light.Enabled = true
			end
		end
		if hum.Parent and hum.WalkSpeed == Weapons.speed.alpha then
			hum.WalkSpeed = Weapons.speed.human
		end
	end)
end

-- Loads a fresh character, applies the role and moves it to `at`. Yields.
function CharacterService.spawn(player: Player, role: string?, at: CFrame?)
	if player.Parent == nil then
		return
	end
	player:LoadCharacter()
	local char = player.Character
	if not char then
		return
	end
	local hum = char:WaitForChild("Humanoid", 5) :: Humanoid?
	char:WaitForChild("HumanoidRootPart", 5)
	if not hum then
		return
	end
	-- wait for the avatar's clothes/colors so our zombie skin is not overwritten
	local waited = 0
	while not player:HasAppearanceLoaded() and waited < 3 do
		waited += task.wait(0.1)
	end
	hideNameTag(hum)
	hum.Died:Connect(function()
		if diedCallback then
			diedCallback(player, char)
		end
	end)
	if at then
		char:PivotTo(at + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)))
	end
	if role then
		CharacterService.applyRole(player, role)
	else
		CharacterService.giveTools(player, "None")
	end
end

-- Can't move or jump for `seconds` (used while the intro cards play). Yields nothing.
function CharacterService.freeze(player: Player, seconds: number)
	local char = player.Character
	local hum = humanoidOf(player)
	if not char or not hum or seconds <= 0 then
		return
	end
	local speed, jump = hum.WalkSpeed, hum.JumpPower
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	task.delay(seconds, function()
		if player.Character == char and hum.Parent and hum.WalkSpeed == 0 then
			hum.WalkSpeed = speed
			hum.JumpPower = jump
		end
	end)
end

-- Downed: crawl slowly, no jump, revive prompt on the body.
function CharacterService.setDowned(player: Player, downed: boolean, onPrompt: ((ProximityPrompt) -> ())?)
	local char = player.Character
	local hum = humanoidOf(player)
	if not char or not hum then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local old = root and root:FindFirstChild("RevivePrompt")
	if old then
		old:Destroy()
	end
	if downed then
		hum.WalkSpeed = Weapons.speed.downed
		hum.JumpPower = 0
		hum:UnequipTools()
		if root then
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "RevivePrompt"
			prompt.ActionText = "Revive"
			prompt.ObjectText = player.DisplayName
			prompt.HoldDuration = 4
			prompt.MaxActivationDistance = 8
			prompt.RequiresLineOfSight = false
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt:SetAttribute("TargetId", player.UserId)
			CollectionService:AddTag(prompt, "RevivePrompt")
			prompt.Parent = root
			if onPrompt then
				onPrompt(prompt)
			end
		end
	else
		hum.WalkSpeed = Weapons.speed.human
		hum.JumpPower = 50
	end
end

function CharacterService.position(player: Player): CFrame?
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	return if root then root.CFrame else nil
end

function CharacterService.playerFromPart(part: Instance): Player?
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local p = Players:GetPlayerFromCharacter(model)
		if p then
			return p
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil
end

return CharacterService
