--!strict
-- Saves each player's profile (coins, owned items, equipped items, stats) in a DataStore.
-- Session-locked (ProfileStore), autosaves, saves on leave and on shutdown.
-- If DataStores can't be used (Studio without "Enable Studio Access to API Services"), players
-- still get a profile for this session, it just isn't saved. A warning says so.
local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Profile = require(Shared.Data.Profile)
local ProfileStore = require(Shared.Data.ProfileStore)
local Remotes = require(Shared.Net.Remotes)

local DataService = {}

local STORE_NAME = "PlayerProfiles_v1"
local AUTOSAVE_EVERY = 120
local LOCK_RETRIES = 5
local LOCK_RETRY_WAIT = 4

local profiles: { [Player]: Profile.Profile } = {}
local saving: { [Player]: boolean } = {} -- false = session only (no DataStore, or lost the lock)
local loadedCallbacks: { (Player, Profile.Profile) -> () } = {}
local store: any = nil
local warned = false

local function warnOnce(msg: string)
	if not warned then
		warned = true
		warn(`DataService: {msg} Progress is NOT saved this session.`)
	end
end

local function openStore()
	local ok, ds = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if not ok then
		warnOnce(`can't open the DataStore ({ds}).`)
		return
	end
	local session = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
	store = ProfileStore.new({
		update = function(_, key, fn)
			return ds:UpdateAsync(key, fn)
		end,
	}, session, os.time)
end

local function sendProfile(player: Player)
	local p = profiles[player]
	if p then
		Remotes.get("ProfileChanged"):FireClient(player, Profile.snapshot(p))
	end
end

local function load(player: Player)
	local profile: Profile.Profile? = nil
	local persistent = false
	if store then
		for attempt = 1, LOCK_RETRIES + 1 do
			local ok, result, err = pcall(store.load, store, player.UserId, attempt > LOCK_RETRIES)
			if not ok then
				warnOnce(`load failed ({result}).`)
				break
			elseif result then
				profile, persistent = result, true
				break
			elseif err == "locked" then
				task.wait(LOCK_RETRY_WAIT) -- the last server is still saving this player
			end
			if player.Parent == nil then
				return
			end
		end
	end
	if player.Parent == nil then
		if persistent and profile then
			pcall(store.save, store, player.UserId, profile, true) -- left while loading: free the lock
		end
		return
	end
	profiles[player] = profile or Profile.new()
	saving[player] = persistent
	sendProfile(player)
	for _, callback in loadedCallbacks do
		task.spawn(callback, player, profiles[player])
	end
end

local function save(player: Player, release: boolean)
	local p = profiles[player]
	if not p or not saving[player] or not store then
		return
	end
	local ok, stillOurs = pcall(store.save, store, player.UserId, p, release)
	if not ok then
		warn(`DataService: save failed for {player.UserId}: {stillOurs}`)
	elseif stillOurs == false then
		saving[player] = false -- another server took over; stop writing
	end
end

-- The player's profile, or nil while it is still loading.
function DataService.get(player: Player): Profile.Profile?
	return profiles[player]
end

-- Runs when a player's profile is ready (it is safe to read and change it then).
function DataService.onLoaded(callback: (Player, Profile.Profile) -> ())
	table.insert(loadedCallbacks, callback)
	for player, p in profiles do
		task.spawn(callback, player, p)
	end
end

-- Change a profile, then tell its owner. Saving happens on autosave / leave.
function DataService.update(player: Player, change: (Profile.Profile) -> ())
	local p = profiles[player]
	if p then
		change(p)
		sendProfile(player)
	end
end

function DataService.start()
	openStore()
	Remotes.get("RequestProfile").OnServerEvent:Connect(sendProfile)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerAdded:Connect(load)
	Players.PlayerRemoving:Connect(function(player)
		save(player, true)
		profiles[player] = nil
		saving[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_EVERY)
			for player in profiles do
				task.spawn(save, player, false)
			end
		end
	end)
	game:BindToClose(function()
		local pending = 0
		for player in profiles do
			pending += 1
			task.spawn(function()
				save(player, true)
				pending -= 1
			end)
		end
		local waited = 0
		while pending > 0 and waited < 25 do
			waited += task.wait(0.2)
		end
	end)
end

return DataService
