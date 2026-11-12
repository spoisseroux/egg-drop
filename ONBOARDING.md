# Egg Drop: onboarding

Start here if you're new to the repo. This page covers what the game is, where it stands, how the code fits together, how to run it, and the rules we work by. Written 2026-11-11; if something here disagrees with [TODO.md](TODO.md), TODO wins.

## 1. What the game is

Egg Drop is a Roblox game about a shared garden of strange little baby pets, plus a handheld game console you play inside it.

- **The garden (3D, social).** Everyone spawns in one open garden. Your equipped baby follows you around, plays with its toy, rests, and reacts when you pet it. You can see other players' babies nearby. The stations are there too: the care cradle (customise and switch pets), the workbench (style your handheld), the journal, and the bench where you sit to play.
- **The handheld board (2D, solo).** A pocket console with a Suika-style merge game. You drop eggs onto a field and same-tier eggs merge upward. A round is 24 drops with a goal, such as making tier III+ merges in a marked patch. Winning earns **Stars**.
- **Stars, the one currency.** You earn them from rounds, daily contracts, a daily gift and petting your baby. You spend them on eggs in the egg shop.
- **One pet for v1: Zivvi.** Every player meets Zivvi through the first rounds on the handheld. The Companion Egg is retired (decided 2026-11-12) so more pets can be designed deliberately later. The eggs left are item eggs that unlock cosmetics:

  | Egg | Price | What it gives |
  |---|---:|---|
  | Toy | 8 | Ball, Bone or Sparkler |
  | Material | 16 | Gloss or Matte finish |
  | Feature | 32 | Horn buds, Claws or Folded wings, each growing in 5 stages |
  | Hue fruits | 8 | Colour doses for a pet |

  Everything is cosmetic: no pet is stronger than another.

**The babies.** Only Zivvi is active in v1 (`PetCatalog.active`); the other three stay in the code for later. The internal ids are leftovers from an older roster, so learn this mapping:

| Name | Internal id | Personality |
|---|---|---|
| Zivvi | `pip` | Lemon and magenta, huge toothy grin, prankster |
| Ovelle | `puddle` | Sky blue, floating ribbon cuffs, gentle |
| Tikket | `wick` | Coral and cyan, tall and clumsy, hip sails |
| Nuum | `orbit` | Indigo cushion, sleepy, a little spooky |

Old pets still exist in the code as retired data (Vezzi `bloom_pip`, Kiprik `foxfire_wick`, Nolli `eclipse_orbit`). They're out of the hatch pool and shop.

The creative direction is in [CHAO-GARDEN-DIRECTION.md](CHAO-GARDEN-DIRECTION.md). It's inspired by the *idea* of Sonic Adventure's Chao Garden. Everything we make is original: no Sega meshes, textures, names or music.

## 2. Where it stands

- **Published: privately only.** Place **96451847774961** (universe 10774758591). Private builds are logged in [PLAY-BUILD.md](PLAY-BUILD.md); the top entry is the latest. The repo is ahead of the published build.
- **Goal: v1 quiet soft public launch.** Decisions, prices and the checklist are in [TODO.md → v1 public launch](TODO.md). Short version:
  - **Systems: largely done.** That covers save hardening, the four-baby roster, refunds on duplicate pets, the Robux store and analytics.
  - **Garden: in progress.** A new layout is greyboxed and approved, and the pet-walking rebuild is next.
  - **3D: Spencer is remodelling.** Horns, claws, wings, toys, stations and the garden kit.
  - **Still to do:** live verification, then the launch tasks (icon, thumbnails, maturity questionnaire).
- **Saves will be wiped at launch.** Launch uses a fresh DataStore (`EggDropLaunchV1`), and private-test progress doesn't carry over.
- **Monetization.**
  - Robux buys Stars packs (39–499 R$).
  - Two passes: **2× Stars** and **Supporter** (+1 Star per round).
  - Rounds are unlimited, with no energy or timers.
  - Because Stars can be bought, every egg counts as a Roblox *paid random item*. Odds are always shown and sum to 100%, a duplicate refunds half its price, and players Roblox restricts (for example UK under-18s) can't buy packs.

## 3. Which docs to trust

There are a lot of markdown files at the root. Most are build logs from past passes and are useful history, not current truth.

| Read | Why |
|---|---|
| **This file**, then [TODO.md](TODO.md) | Current state, what's being worked on, the launch checklist |
| [CHAO-GARDEN-DIRECTION.md](CHAO-GARDEN-DIRECTION.md) | Creative direction for the babies, garden and economy |
| [PET-STYLE-GUIDE.md](PET-STYLE-GUIDE.md) | How pets look (the plush Bear is the reference), the two-colour rule, what comes from eggs, rig conventions, and the **Character creation** section: every attachment anchor and slot, how to author wearables, horn stages, night glow, and the steps to build a new pet |
| [ART-HANDOFF.md](ART-HANDOFF.md) | How 3D assets are made for this game: Blender setup, pivots, scale, Roblox materials |
| [AGENTS.md](AGENTS.md) | Rules for AI agents working in the repo |
| [PLAY-BUILD.md](PLAY-BUILD.md) (top entry only) | What is actually published |
| [UI-DESIGN-SYSTEM.md](UI-DESIGN-SYSTEM.md), [UI-EDITING.md](UI-EDITING.md) | UI rules for the handheld and menus |
| [PET-CARE-ARCHITECTURE.md](PET-CARE-ARCHITECTURE.md) | How petting and care work |

**Outdated.**
- [GAME-DESIGN.md](GAME-DESIGN.md) is the original pitch: coins, rebirth, 12 egg tiers, leaderboards. Most of that was replaced. Its "Roblox-specific systems" section is still good reading.
- [README.md](README.md) is partly stale: it says "nectar" (now Stars) and describes family mastery and the old flow.

**Historical:** the rest of the uppercase docs (`OVERNIGHT-*`, `*-PASS.md`, `MORNING-RUNDOWN`, `V2*` and so on).

## 4. Setup

You need:
- **Windows or macOS** with **Roblox Studio**.
- **Access to the experience.** Spencer has to add you as a collaborator on universe 10774758591 before you can open the place in Studio.
- **GitHub access** to `spoisseroux/egg-drop`.
- **[Aftman](https://github.com/LPGhatguy/aftman).** It installs the pinned tools from [aftman.toml](aftman.toml): Rojo 7.7.1, selene, StyLua and wally. Run `aftman install` in the repo.
- **The Rojo Studio plugin**, version 7.7.x, installed from inside Studio.

Then:

```bash
git clone https://github.com/spoisseroux/egg-drop.git
```

```bash
cd egg-drop && git checkout feat/egg-drop-arcade-polish
```

```bash
rojo serve --port 34873
```

Open the place in Studio. In the Rojo plugin, connect to `localhost:34873`.

Rojo now syncs `src/` into Studio live:
- `src/shared` → `ReplicatedStorage.Shared`
- `src/server` → `ServerScriptService.Server`
- `src/client` → `StarterPlayerScripts.Client`

The pet asset files under `assets/` sync too. See [default.project.json](default.project.json).

**Rojo gotchas:**
- **Edit files in the repo, never in Studio.** Studio edits are overwritten on the next sync.
- **Restart Play after code changes.** Edits sync into Edit mode, but a running Play session keeps the old code until you stop and start it.
- **Don't delete a synced folder while `rojo serve` is running.** Rojo 7.7.1 crashes. If it does, restart the serve and reconnect the plugin.

**Branching.** All current work is on `feat/egg-drop-arcade-polish`, about 140 commits ahead of `main`. Branch off it for your own work and talk to Spencer before merging anything into it.

## 5. Playing it in Studio

Press Play. A fresh save starts on the handheld board.

| Device | Aim | Drop |
|---|---|---|
| Keyboard | Arrows or A/D | Space |
| Gamepad | D-pad | A |
| Touch | Drag across the screen bar | Release |

- In the garden, walk up to your pet and press **E** (or its prompt) to pet it.
- **Menu** opens Hatch eggs, Pocket Trials and Settings. **Get Stars** in the egg shop header opens the Robux store.
- **Studio saves don't persist.** Studio uses an in-memory profile per Play session, so every Play starts fresh.
- **Analytics and real purchases only work in a published game.** Purchase prompts show in Studio but don't charge.

## 6. How the code is organised

Three folders, the standard Roblox split. The server owns everything that matters; the client only renders and sends requests.

### `src/server` — authority and saves
| Module | What it does |
|---|---|
| `init.server.lua` | The main script. Player join/leave, remotes, the per-player `board` state, reward settlement. It's big; search it rather than reading it top to bottom. |
| `BoardRound.lua`, `BoardSimulation.lua`, `FieldRun.lua` | The merge board: physics, merges, round goals, scoring |
| `HatchProgress.lua` | **The economy core.** Wallet, hatches, rewards and purchases go through fenced transactions here. |
| `ProgressStore.lua`, `SessionProfile.lua`, `PlayerProgress.lua`, `CloseProgress.lua` | Saving and loading, budget waits, the save on shutdown |
| `StoreService.lua`, `PurchaseState.lua` | Robux store: prompts, `ProcessReceipt`, pass ownership, the purchase ledger |
| `EconomyAnalytics.lua` | Stars source/sink analytics (live servers only) |
| `GardenState.lua`, `GardenCare*.lua`, `GardenToyReturn.lua`, `PetContact.lua` | Shared garden state: pet behaviour, care, toys |
| `Lounge*.lua` | Builds the 3D world (garden, stations, spring) from code, and spawns players |
| `HueState`, `MaterialState`, `FeatureState`, `ToyState`, `AppearanceIntent`, `PetAppearance` | Per-pet cosmetics |

### `src/client` — everything you see
- `init.client.lua` wires it all together.
- **Handheld:** `Deck*`, `Jelly*` (the LCD renderer), `HandheldScreens`, `DropDispenser`.
- **Pets:** `Pet*` (`PetFactory` builds a pet from rig data, `PetFollow` moves it, `PetFace`/`PetExpression` animate it). `RoomCompanions` renders other players' pets.
- **Hatching:** `EggHatchView` (egg shop), `HatchCinematic`, `HatchReveal`.
- **UI:** `StoreView`, `RoundRecap`, `PetJournal`, `*Panel` and the rest.

### `src/shared` — data both sides read
| Module | What it holds |
|---|---|
| `PetCatalog` | Pet list |
| `EggCatalog` | Egg recipes, odds, refund rate, pity |
| `StoreCatalog` | Robux product and pass ids and prices |
| `ToyCatalog`, `FeatureCatalog`, `MaterialCatalog`, `HueCatalog`, `PetCharmCatalog` | Cosmetics |
| `BoardConfig`, `FieldObjectives`, `DailyContracts`, `PocketTrials` | Board tuning, round goals, contracts, trials |
| `HollowWorldLayout`, `GardenLayout`, `GardenWalkability`, `GardenPathPlanner`, `GardenActivity` | Garden coordinates and pet movement |
| `NewBabyRigDefinitions`, `PetRigDefinitions` | How each baby is assembled from mesh parts |

### Rules the code depends on
- **The server is the authority.** It calculates Stars, pets, merges and rewards. Never trust a number from the client; a remote only asks the server to do something.
- **Every wallet change is a fenced transaction.** It goes through `HatchProgress`'s `transact` and carries an operation id, so a retry or a second server can't apply it twice. Purchases are keyed by Roblox's `PurchaseId` in the `PurchaseState` ledger. If you add anything that grants or spends Stars, follow the same pattern.
- **Saves are session-locked.** A lease, renewed every 20 s, makes one server own a player's economy at a time. Don't write to the DataStore directly.
- **Displayed odds are the real odds.** Shown as whole percentages, summing to 100.

## 7. Tests

Specs live in `scripts/*.spec.lua`. Each returns a function you run inside Studio, because they need the Roblox engine. There's no command-line runner.

1. Copy the spec into a git-ignored folder that Rojo syncs: `src/server/ZZSpecs/` for server specs, `src/client/ZZSpecs/` for client specs. Add both folders to your own `.git/info/exclude`; they're not in `.gitignore`.
2. Restart Play.
3. In the command bar (Server or Client view), require it and call it, for example:
   ```lua
   require(game.ServerScriptService.Server.ZZSpecs.StorePurchase)(game.ServerScriptService.Server)
   ```
   A spec errors on failure and returns `{ passed = n, cases = {...} }` on success.
4. Delete the copies when you're done. Stop `rojo serve` first, or restart it afterwards.

**Status (2026-11-12):** the garden, store and v1 one-pet specs pass in Studio, including PetAward, HatchProgress, SessionRecovery, StorePurchase and GardenGreyboxWorld. A full sweep of every spec hasn't been run.

## 8. How we work

- **Keep [TODO.md](TODO.md) current while you work.** Put your task under **Now working on** when you start, check it off with the commit hash when it lands, and add anything you find. Two people means this matters more, not less.
- **Commits are small and descriptive**, for example `feat(garden): ...` or `fix(store): ...`, and get pushed.
- **Evidence goes in `artifacts/<topic>-<date>/`.** That's screenshots and short write-ups of what was tested and what wasn't. Be explicit about which is which; "untested on a phone" is a fine thing to write.
- **AI agents.** Spencer uses Claude Code and Codex in this repo; [AGENTS.md](AGENTS.md) has the split. Agents follow the same TODO and evidence rules.
- **Never touch the other Roblox project/place** (`roblox_suica_collector`). Only place 96451847774961.
- **Don't publish without Spencer.** Publishing is a release checkpoint with its own checks (see PLAY-BUILD.md).

## 9. Art and assets

- **3D: Blender → FBX → Studio.** [ART-HANDOFF.md](ART-HANDOFF.md) covers it: 1 Blender unit = 1 stud, the export preset, pivots, left/right meshes, triangle budgets, and what Roblox can and can't render. There are no custom shaders; looks come from materials, SurfaceAppearance, colour and lighting.
- **Source files** go in `assets/art-source/` (`features/`, `toys/`, `stations/`, `environment/`, `pets/`). The approved garden greybox is in `assets/art-source/environment/` as a Blender underlay.
- **Audio:** the original sound bank is in `assets/audio`, generated by `scripts/synth_egg_drop.py`. Asset ids are mapped in `src/client/BoardAudio.lua`.

## 10. Gotchas

- **Pet ids don't match pet names** (`pip` is Zivvi). See section 1.
- **Space is Drop on the board.** While the handheld is up, your avatar won't jump.
- **Line endings.** Many files are CRLF, so a tool that writes LF makes noisy diffs. Match the file you're editing.
- **`Workspace.GardenGreybox` lives only in the Studio place.** It's built by `scripts/GardenGreybox.lua` at X = 1000 and isn't in the Rojo tree. It must be deleted before any publish.
- **Pass and product ids live in `StoreCatalog.lua`.** Each `price` must match the Creator Dashboard. Changing a price on the dashboard means changing it there too.
- **Expected warnings.** EditableImage and legacy asset-type warnings appear in the Studio output. They're known; the fallbacks work.

## 11. Open questions and what's next

These are tracked in [TODO.md](TODO.md). The headline items:
- Garden swap: replace the old flat lawn with the approved layout and rebuild pet walking.
- Spencer's Blender pass on horns, claws, wings, toys, stations and the garden kit.
- Decisions pending:
  - Roblox Managed Pricing
  - Art for the Supporter cosmetics
  - Icons for the passes
- Live verification:
  - a real purchase
  - save and rejoin
  - two players together
  - a physical phone
- Launch tasks:
  - balance pass
  - game icon and thumbnails
  - maturity questionnaire
  - soft launch

Questions: ask Spencer.
