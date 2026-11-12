# Changelog

All notable changes to Zombie Hunter. Versions follow [SemVer](https://semver.org/).

## [Unreleased]

### Changed
- **Disguised Alpha:** the Alpha looks, moves and lights up like any survivor (own skin, flashlight, human speed) and starts with them. Every claw swing shows his zombie face (skin, red eyes, Alpha speed) for 3s (`Weapons.AlphaReveal`), then he blends in again. Claws only work after release.
- Survivors carry no weapons (the bat is Hunter-only).
- The Alpha is the same height as all other players (no longer 1.3x bigger).

### Added
- **Game modes** (v0.3): the mode is picked at random every round (`Config/Modes`, `Rules/ModePicker`): Classic 40 / Outbreak 20, a mode needs its minimum players (Outbreak 6+), and a special mode never comes twice in a row. The lobby shows **NEXT ROUND: OUTBREAK** during the countdown. In Studio every mode can come up with 2+ players; set a Workspace attribute `ForceMode = "Outbreak"` to always get it.
- **Outbreak mode:** 2 Alphas (3 at 12+), no Hunter, every Survivor carries a **pistol** (20 dmg, 8 / 24, ammo boxes work for them), no towers or helicopter, survive **4:00**, downed players turn after **10s**. The intro ends with **EVERYONE IS ARMED** instead of the Hunter card. Survivors earn zombie-kill points in Outbreak. 12 new tests.
- **Alpha classes** (v0.3): pick **Runner**, **Tank** or **Screamer** at the pedestals in the lobby; it's used whenever you're the Alpha (default Runner, private). Runner 300 HP + **DASH** (speed burst), Tank 600 HP + **SLAM** (knocks nearby humans back and slows them), Screamer 350 HP + **SCREAM** (nearby humans glow through walls for every zombie, 5s). Press **Q** or tap the ability button; each ability has a cooldown and shows the Alpha's face like an attack. Numbers in `Config/AlphaClasses`. 7 new tests.
- **Phase 2 objectives:**
  - Radio towers: each round picks 5 of the map's 8 tower spots (spread out). Hold E to repair (60s alone, +60% per extra repairer). Random skill checks while repairing (same timing bar): good = +2%, failed = -8% and a noise ping for zombies. Walk away, get hit, get downed or hide and the repair stops. Blinking red beacons are visible through the fog and turn mint when repaired.
  - Rescue helicopter: 3 repaired towers call it (one of 3 zones); it lands after 45s and waits 20s. Humans who reach the glowing zone escape (+40) and wait safe in the lobby. If it leaves with anyone on board, or every remaining human has escaped or turned: SURVIVORS ESCAPED.
  - Lockers (14 on the greybox): hide (claws can't reach you, repairs stop), leave with E / LEAVE; zombies can search a locker and pull you out (+5).
  - Medkit: each Survivor gets one; click to heal one hit off the nearest hurt teammate (+5) or yourself.
  - Points: 1 per 10% repaired, +25 tower, +40 escape, +5 zombie for stopping a repair / finding a hider, +5 heal.
  - HUD: towers x/3, helicopter countdown, repair bar, hiding screen, medkit count, zombie noise pings. Banners for towers and helicopter, YOU ESCAPED card.
  - 25 new Lune tests (93 total): SpotPicker, Objectives, Survival.
- Creepier round intro: VHS scanlines, flickering lights, glitching titles, typed text; a MODE card; every player shown as a faceless shadow while "someone is infected" (a red light jumps between them and stops on nobody); your own character revealed in the dark with a heartbeat for your role card (red flash + shake for the Alpha); the infected card shows your zombie. Everyone is frozen during the 16s intro, then humans get 10s before the Alpha is released (`Classic.introLength`, `headStart` = 26).
- Survivor escape: when a zombie attacks a Survivor, a timing bar appears; clicking/tapping/Space while the needle is in the green zone escapes the hit (+5 points, short speed burst, 1.2s safe). The server checks the timing (`Rules/Dodge`, 8 tests).
- Compact player list (smaller rows, narrower, see-through), toggled with Tab or the small PLAYERS button; closed by default on phones. Roblox's default player list is hidden.
- No floating player names or health bars over heads (`Classic.nameTagDistance = 0`), so players can't be spotted or identified from far away.
- Secret roles: nobody is told who the Alpha or the Hunter is. Cards and banners never name them, the player list shows `?` for every other non-zombie player all round, and the Hunter has no hat or name tag. Basic (infected) zombies are still shown.
- Studio playtests start a round with 2+ players automatically (`Classic.studioMinPlayers`); live servers still need 5.
- Phase 1 playable Classic round (target v0.1.0):
  - Pure rules core (`src/shared/Rules`): role picker with anti-repeat, round phases and timers,
    hidden Alpha until release, hits → downed → revive or turn into a basic zombie, Hunter gun
    hand-off, special roles leaving mid-round, win checks, round points and coins.
  - 56 headless Lune tests (`lune run tests/run`).
  - Server: RoundManager, CharacterService (role looks, flashlight, downed crawl), CombatService
    (server-raycast revolver, bat, claws, ammo boxes), MapService (auto-built greybox Town + lobby),
    AnnouncementService.
  - Client: HUD (timer, player list, health/wounds, ammo, crosshair, downed screen, +points,
    edge tint, phone reload), round cards and banners, weapon input.
  - Tooling: Rojo project, Rokit pins, Selene, StyLua, GitHub Actions CI.
