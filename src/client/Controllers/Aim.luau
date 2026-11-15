--!strict
-- Where the gun points. One answer for the crosshair and the shot, so you hit what you see:
--   * mouse: the crosshair follows the mouse cursor (or the screen centre in shift-lock /
--     first person, where the cursor is locked there anyway)
--   * touch: the crosshair stays in the centre of the screen; a tap anywhere shoots at it
-- The world point is found with a ray from the camera through the crosshair that ignores
-- your own character and invisible parts.
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer

local Aim = {}

local MAX_DISTANCE = 1000

function Aim.usesMouse(): boolean
	return UserInputService.MouseEnabled and UserInputService:GetLastInputType() ~= Enum.UserInputType.Touch
end

-- Crosshair position in screen pixels (matches a ScreenGui with IgnoreGuiInset = true).
function Aim.screenPoint(): Vector2
	local camera = workspace.CurrentCamera
	if Aim.usesMouse() then
		return UserInputService:GetMouseLocation()
	end
	return camera.ViewportSize / 2
end

-- Raycast that skips parts you can't see (unless they belong to a character).
local function seenHit(origin: Vector3, direction: Vector3, ignore: { Instance }): RaycastResult?
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = table.clone(ignore)
	for _ = 1, 8 do
		params.FilterDescendantsInstances = list
		local result = workspace:Raycast(origin, direction, params)
		if not result then
			return nil
		end
		local part = result.Instance
		local inCharacter = part:FindFirstAncestorOfClass("Model") ~= nil
			and part:FindFirstAncestorOfClass("Model"):FindFirstChildOfClass("Humanoid") ~= nil
		if part.Transparency < 0.95 or inCharacter then
			return result
		end
		table.insert(list, part)
	end
	return nil
end

-- The world point under the crosshair.
function Aim.worldPoint(): Vector3
	local camera = workspace.CurrentCamera
	local screen = Aim.screenPoint()
	-- GetMouseLocation and ViewportSize are both in viewport pixels (top bar included).
	local ray = camera:ViewportPointToRay(screen.X, screen.Y)
	local ignore: { Instance } = {}
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local hit = seenHit(ray.Origin, ray.Direction * MAX_DISTANCE, ignore)
	return if hit then hit.Position else ray.Origin + ray.Direction * MAX_DISTANCE
end

return Aim
