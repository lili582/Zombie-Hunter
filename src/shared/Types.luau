--!strict
-- Shared types for the rules core. Pure: no Roblox APIs.

export type Role = "Alpha" | "Hunter" | "Survivor" | "Zombie"
export type Life = "Alive" | "Downed" | "Out"
export type Phase = "Waiting" | "Intermission" | "HeadStart" | "Active" | "Results"
export type Winner = "SurvivorsSurvived" | "SurvivorsEscaped" | "ZombiesWin" | "NoWinner"

export type PlayerState = {
	id: number,
	role: Role,
	life: Life,
	hitsTaken: number,
	bleedLeft: number?,
	downedBy: number?,
	reviverId: number?,
	reviveProgress: number,
	points: number,
	wasInfected: boolean,
	infections: number,
}

export type Rng = {
	int: (self: Rng, min: number, max: number) -> number,
	float: (self: Rng) -> number,
}

export type RoundState = {
	phase: Phase,
	timeLeft: number,
	clock: number, -- seconds of Active time elapsed (for assist windows)
	config: any,
	rng: Rng,
	players: { [number]: PlayerState },
	sinceSpecial: { [number]: number }, -- rounds since each player was Alpha/Hunter
	lastHits: { [number]: { [number]: number } }, -- victim -> attacker -> clock time
	pendingAssists: { [number]: { number } }, -- victim -> attacker ids, set when downed
	gunDropped: boolean,
	alphaRevealed: boolean,
	winner: Winner?,
}

export type Event =
	{ type: "Tick", dt: number }
	| { type: "PlayerJoined", playerId: number }
	| { type: "PlayerLeft", playerId: number }
	| { type: "Hit", attackerId: number, victimId: number }
	| { type: "ReviveStart", reviverId: number, targetId: number }
	| { type: "ReviveStop", reviverId: number }
	| { type: "PickUpGun", playerId: number }
	| { type: "ZombieKilled", killerId: number, victimId: number }
	| { type: "Dodged", playerId: number, attackerId: number }

export type Effect = { type: string, [string]: any }
-- Effect types:
--   PhaseChanged {phase}            RolesAssigned {}
--   HitLanded {attackerId, victimId}
--   Downed {playerId, byId}         Revived {playerId, byId}
--   ReviveStarted {reviverId, targetId}   ReviveStopped {targetId}
--   BecameZombie {playerId, byId?}  BecameAlpha {playerId}
--   GunDropped {fromId}             NewHunter {playerId}
--   ZombieKilled {killerId, victimId}  Dodged {playerId, attackerId}
--   PointsAwarded {playerId, amount, reason}
--   Announce {card, toPlayerId?, data?}
--   RoundOver {winner}

return {}
