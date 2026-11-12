# Zombie Hunter — Phase 1 in Roblox Studio

There are three ways in. Pick one — they all end with the same game.

| Way | Best for | Time |
|---|---|---|
| **A. Open the ready place file** | Playing it right now | 2 min |
| **B. Copy-paste scripts by hand** | Learning where every piece lives | 20 min |
| **C. Rojo + git** | Real development (branches, PRs, tests, CI) | 15 min setup |

The map, lobby and lighting are **built by code** the first time the server starts, so you do not have to build anything to play. Later you can replace `Workspace.Map` with a hand-built map (see "Your own map" below).

---

## A. Open the ready place file

1. Open `ZombieHunter.rbxl` in Roblox Studio (double-click it, or Studio → File → Open from File).
2. Nothing to change for testing: inside Studio a round starts with **2+ players** automatically (`studioMinPlayers` in `Classic`); live servers still need 5.
3. Go to **Test → Clients and Servers**, choose **3 players**, press **Start**. Studio opens 1 server window + 3 player windows.
4. Recommended: **File → Publish to Roblox** (private), then **Home → Game Settings → Avatar → Avatar Type: R6** for the classic 2014 look. (The game also works on R15.)

## B. Copy-paste by hand

In the Explorer, create these objects (right-click the parent → **Insert Object**), rename them exactly, and paste the matching file's contents.

**ReplicatedStorage**

| Create | Name | Paste file |
|---|---|---|
| Folder | `Shared` | — |
| ModuleScript in `Shared` | `Types` | `src/shared/Types.luau` |
| ModuleScript in `Shared` | `Rng` | `src/shared/Rng.luau` |
| Folder in `Shared` | `Config` | — |
| ModuleScript in `Config` | `Classic` | `src/shared/Config/Classic.luau` |
| ModuleScript in `Config` | `Points` | `src/shared/Config/Points.luau` |
| ModuleScript in `Config` | `Weapons` | `src/shared/Config/Weapons.luau` |
| Folder in `Shared` | `Rules` | — |
| ModuleScript in `Rules` | `Util` | `src/shared/Rules/Util.luau` |
| ModuleScript in `Rules` | `RolePicker` | `src/shared/Rules/RolePicker.luau` |
| ModuleScript in `Rules` | `Infection` | `src/shared/Rules/Infection.luau` |
| ModuleScript in `Rules` | `WinCheck` | `src/shared/Rules/WinCheck.luau` |
| ModuleScript in `Rules` | `Scoring` | `src/shared/Rules/Scoring.luau` |
| ModuleScript in `Rules` | `RoundRules` | `src/shared/Rules/RoundRules.luau` |
| ModuleScript in `Rules` | `HitValidation` | `src/shared/Rules/HitValidation.luau` |
| Folder in `Shared` | `Net` | — |
| ModuleScript in `Net` | `Remotes` | `src/shared/Net/Remotes.luau` |

**ServerScriptService**

| Create | Name | Paste file |
|---|---|---|
| Script | `Server` | `src/server/init.server.luau` |
| Folder in `Server` | `Services` | — |
| ModuleScript in `Services` | `RoundManager` | `src/server/Services/RoundManager.luau` |
| ModuleScript in `Services` | `CharacterService` | `src/server/Services/CharacterService.luau` |
| ModuleScript in `Services` | `CombatService` | `src/server/Services/CombatService.luau` |
| ModuleScript in `Services` | `MapService` | `src/server/Services/MapService.luau` |
| ModuleScript in `Services` | `AnnouncementService` | `src/server/Services/AnnouncementService.luau` |

**StarterPlayer → StarterPlayerScripts**

| Create | Name | Paste file |
|---|---|---|
| LocalScript | `Client` | `src/client/init.client.luau` |
| Folder in `Client` | `Controllers` | — |
| ModuleScript in `Controllers` | `Theme` | `src/client/Controllers/Theme.luau` |
| ModuleScript in `Controllers` | `HudController` | `src/client/Controllers/HudController.luau` |
| ModuleScript in `Controllers` | `AnnouncementController` | `src/client/Controllers/AnnouncementController.luau` |
| ModuleScript in `Controllers` | `WeaponController` | `src/client/Controllers/WeaponController.luau` |

Then: select **Players** in the Explorer → Properties → untick **CharacterAutoLoads**. Delete the default `SpawnLocation` in Workspace (the lobby makes its own). Test as in A, step 2–3.

> The shared modules load each other with `require("./Util")` / `require("../Config/Classic")` (Roblox "require by string"). That only works if the names and folders match the table exactly.

## C. Rojo + git (the long-term way)

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then in this folder run `rokit install` (installs rojo, lune, selene, stylua).
2. In Studio install the **Rojo** plugin (Plugins → Manage Plugins, or `rojo plugin install`).
3. Run `rojo serve`, then in Studio: Plugins → Rojo → **Connect**. Your files now sync into Studio live.
4. Tests: `lune run tests/run` (56 tests, no Studio needed). Lint: `selene src`. Format: `stylua src tests`.
5. Git: create an empty GitHub repo, then
   ```
   git remote add origin <your repo url>
   git push -u origin main
   git push -u origin feat/phase1-playable-round
   ```
   Open a PR from `feat/phase1-playable-round` → `main`. CI (`.github/workflows/ci.yml`) runs format check, lint, tests and a place build on every PR. After you merge, delete the branch; when the playtest checklist passes, tag `v0.1.0`.

---

## Playtest checklist (3 players in Studio)

- [ ] Lobby (pink spawn, purple room in the sky) shows **WAITING FOR PLAYERS x/2** until enough join.
- [ ] 20s countdown → cards: map name → SOMEONE IS INFECTED (names flicker, stop on "?") → your private role → your rules → A HUNTER WALKS AMONG YOU (no name).
- [ ] **Secret roles:** every other player's role shows **?** in the list for the whole round (only infected zombies show ZOMBIE). No floating player names, health bars, name tags or Hunter hat over heads.
- [ ] Alpha starts in the locked room up north; after 10s the door opens + banner **THE ALPHA HAS AWAKENED — it could be anyone** (no name).
- [ ] Alpha: 2 claw hits downs a human (grey BLEEDING OUT screen, crawl speed). Basic zombie needs 3.
- [ ] Another human holds **E** for 4s on the downed body → revived ("Name is coming!" + bar).
- [ ] Not revived in 20s → **YOU'VE BEEN INFECTED!** → green zombie with mint eyes, claws equipped.
- [ ] Hunter: click shoots (yellow tracer), ammo `6 / 36`, R reloads; 3 shots kill a basic zombie → respawns in 5s at a corner; +10 for the Hunter.
- [ ] Survivors' click does nothing to shoot (they only have the bat; bat knocks zombies back).
- [ ] Hunter turned → banner **THE HUNTER HAS FALLEN — GRAB THE GUN!**, glowing peach gun; first Survivor to press E becomes Hunter (banner: SOMEONE PICKED UP THE GUN, no name); nobody else can.
- [ ] Last human turns → ZOMBIES WIN! → +coins card → back to the lobby → next round.
- [ ] Timer to 0:00 with a human alive (even downed) → SURVIVORS SURVIVED!; timer turns pink and shakes under 1:00.
- [ ] Phone emulator (Test → Device): Hunter sees a RELOAD button; tapping attacks with claws/bat; prompts show a tap button.

## Your own map

Build anything under a Model named **`Map`** in Workspace and add these **tags** (Home → Tag Editor) to small invisible parts:
`HumanStart` (1), `AlphaStart` (1, inside a room), `ZombieSpawn` (3+), `AmmoSpawn` (any). Name the Alpha room's door part **`AlphaDoor`** — it is closed during the head start and opens at release. Tag lamp parts with a light inside as `FlickerLight` to make them flicker. If `Workspace.Map` exists, the greybox is not built.

## Where to change numbers

Everything marked *(tune)* in the spec is in `Shared/Config`: round timers, hits to down, bleed-out and revive time in `Classic`; points and coins in `Points`; damage, ammo, health and speed in `Weapons`.

## Known Phase 1 limits (next phases)

Points/coins are not saved yet (DataService, v0.4). No towers/helicopter/lockers/gadgets (v0.2). No Alpha classes or 3D safehouse/map vote (v0.3). Round-start cards cover the screen for ~11s, which is longer than the 10s head start — tune `headStart` or card times after the first playtest.
