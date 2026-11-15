--!strict
-- Loads and saves profiles with a session lock, so two servers never write the same player at
-- once (the "ProfileStore pattern"). Pure: the DataStore is passed in, so tests use a stub.
--
-- `store:update(key, fn)` must behave like DataStore:UpdateAsync: `fn(old)` returns the new
-- record, or nil to leave the saved value unchanged. A saved record is { data, lock? } where
-- lock = { session, time }.
local Profile = require("./Profile")

local ProfileStore = {}
ProfileStore.__index = ProfileStore

export type Store = {
	update: (self: any, key: string, fn: (old: any) -> any) -> any,
}

-- A lock older than this (seconds) belongs to a server that crashed: it may be taken over.
ProfileStore.LOCK_TIMEOUT = 30 * 60

function ProfileStore.new(store: Store, session: string, now: () -> number)
	return setmetatable({ store = store, session = session, now = now }, ProfileStore)
end

function ProfileStore.key(userId: number): string
	return `player_{userId}`
end

local function lockedByOther(self: any, record: any): boolean
	local lock = type(record) == "table" and record.lock
	return type(lock) == "table"
		and lock.session ~= self.session
		and type(lock.time) == "number"
		and self.now() - lock.time < ProfileStore.LOCK_TIMEOUT
end

-- Loads and locks a profile. Returns (profile, nil), or (nil, "locked") when another live
-- server holds it. `force` takes the lock anyway (after waiting long enough).
function ProfileStore.load(self: any, userId: number, force: boolean?): (Profile.Profile?, string?)
	local locked = false
	local loaded: Profile.Profile? = nil
	self.store:update(ProfileStore.key(userId), function(old)
		if not force and lockedByOther(self, old) then
			locked = true
			return nil
		end
		local data = Profile.migrate(if type(old) == "table" then old.data else nil)
		loaded = data
		return { data = data, lock = { session = self.session, time = self.now() } }
	end)
	if locked then
		return nil, "locked"
	end
	return loaded, nil
end

-- Saves a profile this session holds. `release` lets the next server load it right away.
-- Returns false if another server took the lock (this server must stop saving that player).
function ProfileStore.save(self: any, userId: number, profile: Profile.Profile, release: boolean?): boolean
	local ok = true
	self.store:update(ProfileStore.key(userId), function(old)
		local lock = type(old) == "table" and old.lock
		if type(lock) == "table" and lock.session ~= self.session then
			ok = false -- someone else owns it now; never overwrite their newer data
			return nil
		end
		return {
			data = profile,
			lock = if release then nil else { session = self.session, time = self.now() },
		}
	end)
	return ok
end

return ProfileStore
