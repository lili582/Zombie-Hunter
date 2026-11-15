--!strict
-- Copies of characters for the 2D screens (role cards, the recap, the dressing room and shop
-- previews), and the zombie look on such a copy. One place for both, so every screen shows
-- characters the same way.
local CharacterCopy = {}

local ZOMBIE_SKIN = Color3.fromRGB(118, 156, 96)

-- Things a copy in a ViewportFrame must not carry (they run, make noise, or light things up).
local function isBaggage(d: Instance): boolean
	return d:IsA("BaseScript")
		or d:IsA("Sound")
		or d:IsA("Light")
		or d:IsA("BillboardGui")
		or d:IsA("ProximityPrompt")
		or d:IsA("Tool")
		or d:IsA("ParticleEmitter")
end

-- A still copy of a player's character (anchored, no scripts, tools or lights), or nil.
function CharacterCopy.of(player: Player): Model?
	local char = player.Character
	if not char then
		return nil
	end
	local wasArchivable = char.Archivable
	char.Archivable = true
	local ok, copy = pcall(function()
		return char:Clone()
	end)
	char.Archivable = wasArchivable
	if not ok or not copy then
		return nil
	end
	for _, d in copy:GetDescendants() do
		if isBaggage(d) then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
	local hum = copy:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	return copy
end

-- Turns a copy into its zombie self: rotten skin (or `skin`) and two glowing eyes.
function CharacterCopy.zombify(model: Model, eyeColor: Color3, skin: Color3?)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Parent == model and d.Name ~= "HumanoidRootPart" then
			d.Color = skin or ZOMBIE_SKIN
		elseif d:IsA("BodyColors") then
			d:Destroy()
		end
	end
	local head = model:FindFirstChild("Head") :: BasePart?
	if not head then
		return
	end
	for _, x in { -0.22, 0.22 } do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Shape = Enum.PartType.Ball
		eye.Size = Vector3.new(0.26, 0.26, 0.26)
		eye.Material = Enum.Material.Neon
		eye.Color = eyeColor
		eye.Anchored = true
		eye.CanCollide = false
		eye.CFrame = head.CFrame * CFrame.new(x, 0.15, -head.Size.Z / 2 - 0.02)
		eye.Parent = model
	end
end

return CharacterCopy
