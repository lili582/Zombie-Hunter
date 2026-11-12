--!strict
-- Spawns characters and applies each role's look, health, speed, tools and lights.
-- Keeps the player's own outfit; zombies only get their skin recolored.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)

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

local function roleTag(char: Model, text: string, color: Color3)
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	local old = head:FindFirstChild("RoleTag")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "RoleTag"
	gui.Size = UDim2.fromOffset(120, 26)
	gui.StudsOffset = Vector3.new(0, 2.6, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 60
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.TextScaled = true
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeColor3 = Color3.fromRGB(42, 31, 61)
	label.TextStrokeTransparency = 0
	label.Parent = gui
	gui.Parent = head
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

local function hunterHat(char: Model)
	local head = char:FindFirstChild("Head") :: BasePart?
	if not head or char:FindFirstChild("HunterHat") then
		return
	end
	local brim = Instance.new("Part")
	brim.Name = "HunterHat"
	brim.Size = Vector3.new(2.4, 0.2, 2.4)
	brim.Color = Color3.fromRGB(45, 32, 25)
	weld(brim, head, CFrame.new(0, 0.65, 0))
	brim.Parent = char
	local crown = Instance.new("Part")
	crown.Name = "HunterHatTop"
	crown.Size = Vector3.new(1.4, 0.7, 1.4)
	crown.Color = Color3.fromRGB(45, 32, 25)
	weld(crown, head, CFrame.new(0, 1.05, 0))
	crown.Parent = char
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
	if role == "Hunter" then
		makeTool("Revolver", Vector3.new(0.4, 0.9, 1.8), Color3.fromRGB(40, 40, 44)).Parent = backpack
		makeTool("Bat", Vector3.new(0.4, 4, 0.4), Color3.fromRGB(120, 85, 50)).Parent = backpack
	elseif role == "Survivor" then
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
	char:SetAttribute("Role", role)
	if role == "Alpha" then
		skin(char, ALPHA_SKIN)
		eyes(char, Color3.fromRGB(255, 40, 60), 0.35)
		pcall(function()
			char:ScaleTo(1.3)
		end)
		setStats(hum, Weapons.health.alpha, Weapons.speed.alpha)
		roleTag(char, "ALPHA", ROLE_COLORS.Alpha)
	elseif role == "Zombie" then
		skin(char, ZOMBIE_SKIN)
		eyes(char, ROLE_COLORS.Zombie, 0.25)
		setStats(hum, Weapons.health.basic, Weapons.speed.basic)
		local tag = char:FindFirstChild("Head") and (char.Head :: any):FindFirstChild("RoleTag")
		if tag then
			tag:Destroy()
		end
	else
		setStats(hum, Weapons.health.human, Weapons.speed.human)
		flashlight(char)
		if role == "Hunter" then
			hunterHat(char)
			roleTag(char, "HUNTER", ROLE_COLORS.Hunter)
		end
	end
	CharacterService.giveTools(player, role)
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
