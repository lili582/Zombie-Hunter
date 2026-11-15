--!strict
-- One list of RemoteEvent names. The server creates them; clients wait for them.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Remotes = {}

Remotes.names = {
	-- client -> server intents
	"FireWeapon", -- (direction: Vector3) Hunter only
	"Reload",
	"TimingAttempt", -- (id, needlePos) clicked during an escape / skill-check bar
	"LockerLeave", -- leave the locker you are hiding in
	"UseAbility", -- Alpha only: use your class ability
	"RequestProfile", -- send me my saved profile (coins, items, stats)
	"ShopBuy", -- (itemId) buy with Z-Coins (and equip it)
	"ShopEquip", -- (itemId) equip an owned item
	"CatalogWear", -- (assetId) try on a Roblox catalog item (lobby only)
	"CatalogRemove", -- (assetId) take an item off
	"CatalogColor", -- (part, paletteIndex) body colour
	"CatalogReset", -- back to the default character
	"CatalogUseAvatar", -- copy my real Roblox avatar
	-- (melee and claws use Tool.Activated, which already reaches the server)
	-- server -> client
	"RoundStateChanged", -- filtered round snapshot
	"Announce", -- (card: string, data: table?)
	"PointsPopup", -- (amount, reason)
	"AmmoChanged", -- (mag, reserve)
	"ShotFired", -- (origin, hitPos) for tracers
	"TimingChallenge", -- (id, kind "dodge"|"skill", window, zoneStart, zoneSize): click in time!
	"TimingResult", -- (id, ok: boolean)
	"NoiseAlert", -- (position) zombies only: a skill check failed at this tower
	"ShopResult", -- (ok, reason?, itemId)
	"CatalogResult", -- (ok, reason?, assetId?)
	"ProfileChanged", -- (snapshot) your saved profile: coins, owned, equipped, stats
	"RevealHumans", -- (characters, seconds) zombies only: a Screamer's scream shows these humans
}

local folder: Folder? = nil

local function getFolder(): Folder
	if folder then
		return folder
	end
	if RunService:IsServer() then
		local f = ReplicatedStorage:FindFirstChild("Remotes") :: Folder?
		if not f then
			local newFolder = Instance.new("Folder")
			newFolder.Name = "Remotes"
			newFolder.Parent = ReplicatedStorage
			f = newFolder
		end
		for _, name in Remotes.names do
			if not (f :: Folder):FindFirstChild(name) then
				local r = Instance.new("RemoteEvent")
				r.Name = name
				r.Parent = f
			end
		end
		folder = f
	else
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	return folder :: Folder
end

function Remotes.get(name: string): RemoteEvent
	local f = getFolder()
	if RunService:IsServer() then
		return f:FindFirstChild(name) :: RemoteEvent
	end
	return f:WaitForChild(name) :: RemoteEvent
end

return Remotes
