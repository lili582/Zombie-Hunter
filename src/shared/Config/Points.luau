--!strict
-- Round points and coin conversion. All (tune).
return {
	hit = 3,
	down = 10,
	infection = 25,
	infectionAssist = 10,
	assistWindow = 10, -- seconds before the down
	revive = 20,
	survive = 30,
	zombieKill = 10,
	alphaKill = 30,
	pickUpGun = 15,
	dodge = 5, -- survivor escaped an attack with good timing
	repairPer10 = 1, -- per 10% of a tower you repaired
	towerDone = 25, -- to everyone repairing when a tower completes
	escape = 40,
	interruptRepair = 5, -- zombie hit someone who was repairing
	pullOut = 5, -- zombie pulled a human out of a locker
	heal = 5, -- medkit used on a teammate
	teamWin = 30,
	firstInfectionBonus = 10,
	coinsPerPoint = 0.5,
	minCoins = 10, -- plan decision: minimum participation reward
}
