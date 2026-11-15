--!strict
-- What each role is for and how to play it. One place for the words, used by:
--   * the role card in the intro (`quick`: one short line under YOU ARE THE ...)
--   * the role help icon on the HUD (`goal` + `tips`, opened with the icon or [H])
-- A mode can change a role's text (`modes.Outbreak.Survivor`, ...).
local RoleGuide = {}

export type Guide = {
	title: string,
	quick: string,
	goal: string,
	tips: { string },
}

RoleGuide.roles = {
	Survivor = {
		title = "SURVIVOR",
		quick = "Stay alive. Fix the towers. Escape.",
		goal = "Survive the night, or escape on the rescue helicopter.",
		tips = {
			"Hold [E] at a radio tower to repair it. Click in the green on SKILL CHECKS.",
			"3 towers call the helicopter. Get into the glowing ring before it leaves.",
			"Zombie attack? CLICK / TAP / SPACE in the green to escape the hit.",
			"Hide in a locker [E]. Hold [E] on a downed friend to revive them.",
			"Your medkit (click) heals one hit, on a friend or yourself.",
			"Trust no one: anyone could be the Alpha.",
		},
	},
	Hunter = {
		title = "HUNTER",
		quick = "Only you have a gun. Protect them.",
		goal = "Keep the survivors alive. Your role is secret.",
		tips = {
			"Click to shoot where the + crosshair is. [R] reloads.",
			"Grab ammo boxes [E] around the map.",
			"Your melee knocks zombies back.",
			"Zombies look human until their claws come out. Watch who swings.",
			"If you fall, your gun drops. The first survivor to grab it is the new Hunter.",
		},
	},
	Alpha = {
		title = "ALPHA ZOMBIE",
		quick = "Blend in. Then infect them all.",
		goal = "Turn every human into a zombie before the timer runs out.",
		tips = {
			"You look like them. Your claws wake up after the head start.",
			"[1] takes your claws out: your face shows until you put them away.",
			"Click to claw. 2 hits downs a human. If nobody revives them, they turn.",
			"[Q] uses your class ability. Pick your class at the pedestals in the safehouse.",
			"Search a locker [E] to pull out whoever is hiding inside.",
		},
	},
	Zombie = {
		title = "ZOMBIE",
		quick = "You still look human. Spread it.",
		goal = "Infect everyone left. You keep scoring points as a zombie.",
		tips = {
			"You look human until your claws come out: [1] takes them out / puts them away.",
			"Click to claw. 3 hits downs a human.",
			"Search lockers [E]. Stop survivors repairing towers.",
			"If the Hunter kills you, you come back after a few seconds.",
		},
	},
}

RoleGuide.modes = {
	Outbreak = {
		Survivor = {
			title = "SURVIVOR",
			quick = "Everyone's armed. Survive 4:00.",
			goal = "Stay alive until the timer runs out. No towers tonight.",
			tips = {
				"You have a PISTOL: click to shoot at the + crosshair, [R] reloads.",
				"Ammo boxes [E] refill it.",
				"Zombie attack? CLICK / TAP / SPACE in the green to escape the hit.",
				"Downed players turn after only 10s: revive fast [E].",
				"There are more Alphas tonight. Trust no one.",
			},
		},
	},
}

function RoleGuide.get(role: string?, mode: string?): Guide?
	if role == nil then
		return nil
	end
	local modeGuides = (RoleGuide.modes :: any)[mode or ""]
	return (modeGuides and modeGuides[role]) or (RoleGuide.roles :: any)[role]
end

return RoleGuide
