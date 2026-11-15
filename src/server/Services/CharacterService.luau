--!strict
-- Spawns characters and applies each role's look, health, speed, tools and lights.
-- Characters are built from the player's in-game outfit (catalog, saved in their profile;
-- new players get the default character). Zombies only get their skin recoloured on top.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Weapons = require(Shared.Config.Weapons)
local Classic = require(Shared.Config.Classic)
local AlphaClasses = require(Shared.Config.AlphaClasses)
local Items = require(Shared.Config.Items)
local Outfit = require(Shared.Data.Outfit)

local CharacterService = {}

local ROLE_COLORS = {
	Alpha = Color3.fromRGB(255, 143, 184), -- candy pink
	Zombie = Color3.fromRGB(163, 234, 200), -- zombie mint
	Hunter = Color3.fromRGB(255, 199, 154), -- peach
	Survivor = Color3.fromRGB(156, 200, 255), -- baby blue
}
local ZOMBIE_SKIN = Color3.fromRGB(118, 156, 96)

local diedCallback: ((Player, Model) -> ())? = nil

-- Set by RoundManager: the player's saved outfit (nil while their save is loading).
CharacterService.outfitOf = function(_player: Player): any
	return nil
end

-- Set by RoundManager: the gun every Survivor carries this round (Outbreak), or nil.
CharacterService.humanWeapon = function(): string?
	return nil
end

-- Set by RoundManager: the shop item a player has equipped in a slot
-- ("hunterGun" | "hunterMelee" | "zombieSkin").
CharacterService.equippedOf = function(_player: Player, slot: string): string
	return if slot == "hunterGun" then "Revolver" elseif slot == "hunterMelee" then "Bat" else "Rotten"
end

local function rgb(c: { number }?, fallback: Color3): Color3
	return if c then Color3.fromRGB(c[1], c[2], c[3]) else fallback
end

-- The zombie skin a player has equipped: (body color, eye color).
local function zombieLook(player: Player): (Color3, Color3)
	local item = Items.get(CharacterService.equippedOf(player, "zombieSkin"))
	return rgb(item and item.skin, ZOMBIE_SKIN), rgb(item and item.eyes, ROLE_COLORS.Zombie)
end

-- Tool looks per shop item: handle size and color.
-- (size, colour) of a shop weapon's handle, from Config/Items `look`.
local function toolLook(id: string, fallback: string): (Vector3, Color3)
	local item = Items.get(id) or Items.get(fallback)
	local look = item.look
	return Vector3.new(look.size[1], look.size[2], look.size[3]),
		Color3.fromRGB(look.color[1], look.color[2], look.color[3])
end

-- Set by RoundManager: which Alpha class a player has this round (nil = not an Alpha).
CharacterService.alphaClassOf = function(_player: Player): string?
	return nil
end

function CharacterService.onDied(callback: (Player, Model) -> ())
	diedCallback = callback
end

local function humanoidOf(player: Player): Humanoid?
	local char = player.Character
	return if char then char:FindFirstChildOfClass("Humanoid") else nil
end

-- The HumanoidDescription for a player's in-game character.
function CharacterService.descriptionFor(player: Player): HumanoidDescription
	local o = CharacterService.outfitOf(player) or Outfit.default()
	local desc = Instance.new("HumanoidDescription")
	for prop, value in Outfit.descriptionProps(o) do
		if type(value) == "table" then
			(desc :: any)[prop] = Color3.fromRGB(value[1], value[2], value[3])
		else
			(desc :: any)[prop] = value
		end
	end
	return desc
end

-- Puts the player's current outfit on their character right away (catalog try-on, lobby only).
function CharacterService.applyOutfit(player: Player): boolean
	local hum = humanoidOf(player)
	if not hum then
		return false
	end
	local ok, err = pcall(function()
		hum:ApplyDescription(CharacterService.descriptionFor(player))
	end)
	if not ok then
		warn(`CharacterService: couldn't apply outfit for {player.Name}: {err}`)
	end
	return ok
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
		if CharacterService.humanWeapon() == "Pistol" then
			local pistol = makeTool("Pistol", Vector3.new(0.35, 0.8, 1.4), Color3.fromRGB(60, 60, 70))
			pistol:SetAttribute("Gun", true)
			pistol.Parent = backpack
		end
	elseif role == "Hunter" then
		-- the gun and melee the player equipped in the shop (tool name = item id)
		for _, slot in { "hunterGun", "hunterMelee" } do
			local id = CharacterService.equippedOf(player, slot)
			local size, color = toolLook(id, if slot == "hunterGun" then "Revolver" else "Bat")
			local tool = makeTool(id, size, color)
			tool:SetAttribute(if slot == "hunterGun" then "Gun" else "Melee", true)
			tool.Parent = backpack
		end
	elseif role == "Alpha" or role == "Zombie" then
		-- Claws start in the backpack: take them out (1 / tap) to attack. While they are out you
		-- look like a zombie; put them away and you look human again.
		local claws = makeTool("Claws", nil)
		claws.Equipped:Connect(function()
			if not CharacterService.clawsAllowed(player) then
				-- the Alpha's claws are still asleep (head start): no showing your face yet
				task.defer(function()
					local hum = humanoidOf(player)
					if hum then
						hum:UnequipTools()
					end
				end)
				return
			end
			CharacterService.setClawsOut(player, true)
		end)
		claws.Unequipped:Connect(function()
			CharacterService.setClawsOut(player, false)
		end)
		claws.Parent = backpack
	end
end

-- Look + stats for a role on the current character (no respawn).
-- `noTools`: the look and stats only, empty hands (the intro: tools would show your role).
function CharacterService.applyRole(player: Player, role: string, noTools: boolean?)
	local char = player.Character
	local hum = humanoidOf(player)
	if not char or not hum then
		return
	end
	-- Every zombie is disguised: own skin and clothes, a flashlight like everyone else. The zombie
	-- face shows while the claws are out (setClawsOut) or for a moment after an Alpha ability.
	if role == "Alpha" then
		local class = AlphaClasses.get(CharacterService.alphaClassOf(player))
		setStats(hum, class.health, Weapons.speed.human)
		flashlight(char)
	elseif role == "Zombie" then
		setStats(hum, Weapons.health.basic, Weapons.speed.basic)
		flashlight(char)
	else
		setStats(hum, Weapons.health.human, Weapons.speed.human)
		flashlight(char)
		-- secret roles: the Hunter looks like everyone else (no hat, no name tag)
	end
	CharacterService.giveTools(player, if noTools then "None" else role)
end

-- A zombie's true face. Shown while the claws are out (setClawsOut), and for `seconds` after an
-- Alpha ability (revealZombie); hidden again only when both are over.
--   Alpha: zombie skin + RED eyes, faster (class speed) while unmasked; `speed` (a dash) overrides.
--   Basic zombie: zombie skin + its skin's eye colour, same speed.
local savedLook: { [Model]: { [Instance]: { [string]: any } } } = {}
local clawsOut: { [Model]: boolean } = {}
local timedUntil: { [Model]: number } = {}
local LIMBS = { "Head", "Torso", "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local BODY_COLOR_PROPS =
	{ "HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3" }

-- Set by RoundManager: may this player take their claws out now? (false during the head start)
CharacterService.clawsAllowed = function(_player: Player): boolean
	return true
end

local function isAlpha(player: Player): boolean
	return CharacterService.alphaClassOf(player) ~= nil
end

local function unmask(player: Player, char: Model, hum: Humanoid)
	if savedLook[char] then
		return -- already showing
	end
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
	local body, eyeColor = zombieLook(player)
	skin(char, body)
	if isAlpha(player) then
		eyes(char, Color3.fromRGB(255, 40, 60), 0.35) -- the Alpha's eyes are red: that's how you know
	else
		eyes(char, eyeColor, 0.25)
	end
	local head = char:FindFirstChild("Head")
	local light = head and head:FindFirstChild("Flashlight") :: SpotLight?
	if light then
		light.Enabled = false
	end
	if isAlpha(player) and hum.WalkSpeed > 0 then
		hum.WalkSpeed = AlphaClasses.get(CharacterService.alphaClassOf(player)).speed -- faster unmasked
	end
end

local function remask(player: Player, char: Model, hum: Humanoid)
	local saved = savedLook[char]
	if not saved then
		return -- already hidden
	end
	savedLook[char] = nil
	for inst, props in saved do
		for prop, value in props do
			(inst :: any)[prop] = value
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
	if hum.Parent and hum.WalkSpeed > 0 then
		hum.WalkSpeed = if isAlpha(player) then Weapons.speed.human else Weapons.speed.basic
	end
end

-- Shows or hides the face to match: claws out, or an ability timer still running.
local function refresh(player: Player)
	local char = player.Character
	local hum = humanoidOf(player)
	if not char or not hum or not char.Parent then
		return
	end
	local timed = (timedUntil[char] or 0) > os.clock()
	if clawsOut[char] or timed then
		unmask(player, char, hum)
		if not timed and isAlpha(player) and hum.WalkSpeed > 0 then
			-- an ability (dash) just ended but the claws are still out: back to class speed
			hum.WalkSpeed = AlphaClasses.get(CharacterService.alphaClassOf(player)).speed
		end
	else
		timedUntil[char] = nil
		remask(player, char, hum)
	end
end

-- Claws taken out / put away.
function CharacterService.setClawsOut(player: Player, out: boolean)
	local char = player.Character
	if not char then
		return
	end
	clawsOut[char] = if out then true else nil
	refresh(player)
end

-- Shows the face for `seconds` (Alpha abilities). `speed` (a dash) overrides the speed meanwhile.
function CharacterService.revealZombie(player: Player, seconds: number, speed: number?)
	local char = player.Character
	local hum = humanoidOf(player)
	if not char or not hum then
		return
	end
	timedUntil[char] = math.max(timedUntil[char] or 0, os.clock() + seconds)
	unmask(player, char, hum)
	if speed then
		hum.WalkSpeed = speed
	end
	task.delay(seconds + 0.05, function()
		if player.Character == char then
			refresh(player)
		end
	end)
end

-- Forget a character's reveal state when it goes away.
local function forget(char: Model)
	savedLook[char] = nil
	clawsOut[char] = nil
	timedUntil[char] = nil
end

-- Loads a fresh character, applies the role and moves it to `at`. Yields.
-- `noTools`: spawn empty-handed (round intro); call giveTools later.
function CharacterService.spawn(player: Player, role: string?, at: CFrame?, noTools: boolean?)
	if player.Parent == nil then
		return
	end
	-- the in-game character (catalog outfit), not the Roblox avatar
	local ok = pcall(function()
		player:LoadCharacterWithHumanoidDescription(CharacterService.descriptionFor(player))
	end)
	if not ok then
		warn(`CharacterService: outfit failed to load for {player.Name}, using the default character`)
		local fallback = pcall(function()
			local desc = Instance.new("HumanoidDescription")
			for prop, value in Outfit.descriptionProps(Outfit.default()) do
				if type(value) == "table" then
					(desc :: any)[prop] = Color3.fromRGB(value[1], value[2], value[3])
				end
			end
			player:LoadCharacterWithHumanoidDescription(desc)
		end)
		if not fallback then
			player:LoadCharacter()
		end
	end
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
	char.AncestryChanged:Connect(function()
		if not char.Parent then
			forget(char)
		end
	end)
	hum.Died:Connect(function()
		if diedCallback then
			diedCallback(player, char)
		end
	end)
	if at then
		char:PivotTo(at + Vector3.new(math.random(-4, 4), 0, math.random(-4, 4)))
	end
	if role then
		CharacterService.applyRole(player, role, noTools)
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
