# Changelog

All notable changes to Zombie Hunter. Versions follow [SemVer](https://semver.org/).

## [Unreleased]

### Changed
- **Round recap:** after the result, a slow card lines up every player's character in the dark; one by one a light comes on over each with their name, the role they really had (the Alpha and Hunter are revealed now that the round is over), what happened to them (**SURVIVED** / **ESCAPED** / **INFECTED** / **THE ALPHA**) and **WINNER** for the winning side. Infected players and the Alpha are shown as zombies. Winners come first and stay lit; the rest fade. The whole end sequence is slower (result 4s, recap about 8-12s, coins 3s; results phase 20s). `RoundRules.recap`, 4 tests.
- **Cleaner HUD design:** one glass style everywhere (dark see-through plum, soft rounded corners, a thin lavender edge, softer text outlines). The clock sits in a pill at the top centre in a clean font with one quiet line under it; coins and the role help icon top left; PLAYERS and SHOP pills top right with the list under them; health + medkit bottom left; repair bar bottom centre (slim, like health); ammo, ability and reload bottom right; smaller point popups. Chips only appear when they have something to say.
- **Role help icon:** during a round a round **?** icon in your role colour (top left, with your role name) opens a panel with your goal and how to play, keys included (**H** on a keyboard). It follows your role (infected → zombie tips) and the mode (Outbreak survivors). Words live in `Config/RoleGuide`.
- **Slower, creepier role pick:** the intro is now 22s (`introLength`, head start 32s). SOMEONE IS INFECTED types in slowly with whispers while the red light drifts between the shadows and sometimes lingers; YOUR ROLE has a 5-beat heartbeat in the dark before the light stutters on, then a quick one-line explanation of your role under the title.
- **Straight to the safehouse:** the moment a round ends everyone is brought back to the safehouse, and the result and coin cards play there. Players rest at least 35s before the next round (15s results + 20s countdown); a test checks the countdown never drops under 20s.
- **Last-minute clock:** under 1:00 the timer turns a deep blood red with a dark edge, and no longer shakes.
- **Spread-out group starts:** at round start players are split into groups of 2 (the last group may have 3), and each group starts at its own spot, far apart on the map (`Rules/SpawnGroups`, 6 tests). Groups are reshuffled every round and the disguised Alpha lands in a random group. The greybox Town now has 7 `HumanStart` spots; a map with one spot still starts everyone together.
- **Role reveal emotes:** on the intro's role card your character acts out what it got, as the light comes on: **Survivor** crouches, shields its face and shakes, head snapping around; **Hunter** raises a revolver, scans and fires (recoil + muzzle flash); **Alpha** hangs limp, then its head snaps up crooked, red eyes open, claws rise and it glitches; **Zombie** (the infected card) shambles with arms reaching, head lolling and mint eyes. It carries on into the rules card. Made in code (`RoleEmote`), R6 and R15.
- **Repair emote:** while repairing a radio tower your character turns to face the box, holds a wrench and hammers at it (left hand steadying), with sparks on every hit. Everyone sees it. Made in code (no animation asset), works on R6 and R15.
- **Slimmer health bar:** a small, thin rounded bar in the bottom-left corner with a caption above it (HEALTHY / WOUNDED x1 / HP for zombies). It slides smoothly on a hit, humans' bar is split into 3 hit marks, and it turns pink when you're one hit from going down. The medkit line sits just above it.
- **Every zombie is disguised:** infected (basic) zombies now look like any other player too (own skin and clothes, a flashlight). Claws start in the backpack: take them out (**1**, or tap them in the toolbar) to attack, and your zombie face (zombie skin + glowing eyes) shows **for as long as the claws are out**; put them away and you look human again. The Alpha's revealed eyes are red, and its claws can't be taken out during the head start. Alpha abilities still show the face for 3s. Basic zombies keep their slower speed.
- **The next mode is a surprise:** the lobby no longer says which mode is next (HUD shows NEXT ROUND STARTING, the sign shows NEXT ROUND STARTING SOON / ROUND IN PROGRESS). You find out on the intro's MODE card.

### Fixed
- No green bar when you join: the health bar stays hidden until a round, and Roblox's own health bar is turned off.
- Repair emote: your own repair now also starts it straight from your round state (it no longer depends only on the server's signal), and the Output warns if the character has no arm joints to animate.
- **Gun aiming:** the crosshair now follows your mouse cursor (centre of the screen on phones and in shift-lock), the mouse pointer hides while you hold a gun, and the shot goes exactly to the point under the crosshair. Bullets no longer stop on invisible parts.

- **No roles in the player list:** other players are always blank in the list, even infected zombies, downed or escaped players (only WAITING for people sitting out the round). Your own row still shows your role. The server no longer sends anyone else's role, wounds or downed state to your client.
- **Disguised Alpha:** the Alpha looks, moves and lights up like any survivor (own skin, flashlight, human speed) and starts with them. Every claw swing shows his zombie face (skin, red eyes, Alpha speed) for 3s (`Weapons.AlphaReveal`), then he blends in again. Claws only work after release.
- Survivors carry no weapons (the bat is Hunter-only).
- The Alpha is the same height as all other players (no longer 1.3x bigger).

### Added
- **Z-Shop** (v0.4): press **E** at the shop counter in the safehouse (or the **SHOP** button in the lobby). Tabs **WEAPONS** and **ZOMBIE SKINS**; each card shows the price and **BUY** / **EQUIP** / **EQUIPPED**. Not enough coins shows how many more you need. Shopping works between rounds or while you sit out a round. Items (`Config/Items`), all side-grades or looks:
  - Hunter guns: Revolver (starter), **Lever Rifle** 400 (50 dmg, far, slow, 5 shots), **Rusty SMG** 600 (fast, weak, short range).
  - Hunter melee: Bat (starter), **Shovel** 250 (harder, slower), **Crowbar** 250 (quick, shorter).
  - Zombie skins: Rotten (starter), **Pale Ghoul** 150, **Bog Mint** 150, **Bruised Plum** 200, **Candy Corpse** 300: body color + eye glow for your basic zombie and the Alpha's revealed face (the Alpha's eyes stay red).
  - When you're the Hunter you carry your equipped gun and melee. The server checks every purchase (`Shared/Data/Shop`). 7 new tests (136 total).
- **Saved progress** (v0.4): every player has a saved profile (`Shared/Data/Profile`): **Z-Coins**, owned and equipped items, your Alpha class, and stats (rounds, wins, escapes, survivals, zombie kills, infections, revives, towers repaired, rounds as Hunter / Alpha). Round-end coins are added and saved. `DataService` uses a session lock so two servers never write the same player (`Shared/Data/ProfileStore`), autosaves every 2 min, saves on leave and on shutdown. Your coins show at the top left. If DataStores aren't available (Studio without API access) you still play, with a warning that nothing is saved. 10 new tests (129 total).
- **Safehouse lobby** (v0.3): a bigger, cozy room in the sky: wood floor, rug, couch and an old TV, warm light and pastel string lights, two windows with a zombie peeking in, a shop counter and a dressing mirror (both "soon", v0.4), the Alpha pedestals, and a **NEXT ROUND / NOW PLAYING** sign.
- **Map vote** (`Rules/MapVote`, `Config/Maps`): a board with 3 posters and a pad in front of each; press **E** on a pad during the countdown to vote (private **YOU VOTED** banner, the posters show the vote counts). Most votes wins, ties are random, and a map can't be played more than twice in a row. The winning map's name is on the intro card. Only the Town greybox exists so far, so the board shows one map until Mall / School / Forest Camp are built (v1.0). 7 new tests (119 total).
- **Game modes** (v0.3): the mode is picked at random every round (`Config/Modes`, `Rules/ModePicker`): Classic 40 / Outbreak 20, a mode needs its minimum players (Outbreak 6+), and a special mode never comes twice in a row. The mode is revealed on the intro's MODE card. In Studio every mode can come up with 2+ players; set a Workspace attribute `ForceMode = "Outbreak"` to always get it.
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
