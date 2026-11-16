-- Zombie Hunter client entry. Clients only send intents and draw what the server tells them.
-- Every controller starts on its own: if one fails (or waits), the others still run, and the
-- error is printed in the Output with the controller's name.
local Controllers = script:WaitForChild("Controllers")

local ORDER = {
	"HudController",
	"AnnouncementController",
	"WeaponController",
	"TimingController",
	"RepairAnimController",
	"ShopController",
	"CatalogController",
	"AtmosphereController",
	"SafehouseController",
}

for _, name in ORDER do
	task.spawn(function()
		local ok, err = pcall(function()
			require(Controllers:WaitForChild(name)).start()
		end)
		if not ok then
			warn(`[Zombie Hunter] {name} failed to start: {err}`)
		end
	end)
end
