-- Zombie Hunter client entry. Clients only send intents and draw what the server tells them.
local Controllers = script:WaitForChild("Controllers")

require(Controllers:WaitForChild("HudController")).start()
require(Controllers:WaitForChild("AnnouncementController")).start()
require(Controllers:WaitForChild("WeaponController")).start()
