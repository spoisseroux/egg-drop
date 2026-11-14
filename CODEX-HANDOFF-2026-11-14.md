# Codex handoff, 2026-11-14 (from Claude Code)

Claude Code is out of weekly usage until **Sunday 2026-11-15 16:00 local**. Codex picks up from here.

**Read this whole file before acting.** Then read, in this order:
1. `AGENTS.md`
2. `TODO.md`, the "Now working on" and "Next session" blocks
3. `PLAY-BUILD.md`, the newest entry
4. `artifacts/overnight-2026-11-14/`: BUILD-PLAN, PROGRESS, SYSTEMS-SCOPE, VISUAL-BRIEF, the LANE-* files, FOLLOWUP-*, FLICKER-FIX
5. `artifacts/content-v1-2026-11-13/CONTENT-SCOPE.md`

## 0. First instruction: WAIT for Spencer's QA pass

Spencer is playtesting **private v634** now. His checklist is `obsidian-spencer/roblox qa pass nov 15 checklist.md`, at `C:\Users\skunk\Documents\obsidian-spencer\`.

**Do not build anything until he posts his QA notes.** Then:
1. Copy his note and screenshots into `artifacts/qa-2026-11-15/`.
2. Write `QA-TRIAGE.md` the same way as `artifacts/qa-2026-11-13-v2/QA-TRIAGE.md`: numbered items grouped into tracks, each with its screenshot timestamp.
3. Fix all of it, following the review-driven-build workflow (§4).
4. Publish a private build.

Answer questions in chat. Fix bugs in code.

## 1. Who does what (model mapping)

| Role | In Codex | In Claude Code |
|---|---|---|
| Creative direction, art, 3D models, UI/UX look, audio, critique of actual renders | **Astra** (`gpt-6-astra`) | **Fable** |
| Implementation code: runtime, UI construction, asset tooling, specs | **Sol 6.1 High** (`gpt-6.1-sol`, high reasoning) | **Opus** |
| Coordinator: integration, Studio control, running specs, evidence, commits, publishes | the primary agent | the primary agent |
| Plan review (architect) and code review | Sol | Opus (the Software Architect and Code Reviewer agents) |

Everything Fable wrote (VISUAL-BRIEF, LANE-A, FOLLOWUP-ART, FLICKER-FIX, blip-v2 NOTES) is Astra's lane now. Everything Opus wrote (SYSTEMS-SCOPE, LANE-S/K/U, FOLLOWUP-CODE) is Sol's.

## 2. Where things stand

- **Branch:** `feat/egg-drop-arcade-polish`. Everything is committed and pushed.
- **Runtime:** f75cf12. Docs follow it up to 4ef617d and later.
- **Private place:** 96451847774961, universe 10774758591, Studio studio_id `382a9271-f8bd-4f5d-b4c4-54405899367e`.
- **Never touch** the `roblox_suica_collector` place.

**Newest build: private v634.**
- slice A: Happy, Lash and Round Eyes, Kitty W, the analytics funnel and events
- overnight slices E/B/C/D/F:
  - E: Blip behind `FeatureFlags.SecondPet=false`
  - B: 10 recolours, 6 new wearables, Eyewear/Cheek/Wrist tabs
  - C: the weekly shelf at 20% off
  - D: toy pool 2, Heart/Star/Leaf charms, 6 Discoveries
  - F: bond levels 1–10 with tricks
- Stargazer and Grape Soda/Rose Chrome faceplates, the Bubbles ball theme
- the phone layout fixes and the round camera park
- the world flicker fix: 38 coplanar pairs, 6 meshes

**Studio results at v634:** server specs 44/44. Client specs are all green except the long-standing failures: SemanticUI, Onboarding, SaveNoticeLayout, PreferredTextLayout, VividHandheld, StyleJournalActions/Layout, EmulatorSafeArea, PetAssetsReadyFixture, and the Board-only specs (JellyRenderOwner, CompactDeck, JellyOverflow, FieldFeedbackOwner, HardwareDeck), which need the deck open.

**`FeatureFlags.TestFreshSaves=true`.** Every private publish wipes saves. It MUST be false at the public launch.

## 3. What's left, after the QA fixes (TODO.md "Next session")

1. **Blip redesign.** Spencer rejected v1 (too Bear-like) and the v2 concepts A Bean, B Saucer and C Sprout in `artifacts/blip-v2-2026-11-14/` as "not cute enough".
   - Astra makes a new concept round: baby proportions, a head about 60% of height, huge glossy low-set eyes with two shines, a tiny mouth, blush, chubby short limbs, rounded everywhere, mint with a cream belly. Review at phone size next to the Bear.
   - Spencer picks a concept. Only then: build, export, import, refit wearables, add `PetRigDefinitions.blip`, then flip `SecondPet`.
2. **Second Pet Park.** Spencer asked for it on 2026-11-14. One park has 9 slots, and the server is 12 players. Scope a site and reuse ParkDirector.
3. **Pet Park v1 scope accepted:** shared fetch (idle pets join), the Play date reward, 12 players per server. Needs a second test account.
4. **UI personality pass accepted** (`UI-PERSONALITY-SCOPE-2026-11-13.md`): Fredoka One, lips and seams, copy voice, the desktop pet peek, house palette plus a per-screen tint, a Star face in the wallet and results hero.
5. **196 more same-facing face pairs** in the stairs, rotunda, arch, bridge, balustrades and stations. Use `scripts/scan_world_v7_coplanar.py` and FLICKER-FIX.md.
6. **Post-launch:** the Weekly Board, the monthly Colour Egg, a fixed-price Robux bundle, private servers, a Premium perk.
7. **Launch checklist:**
   - TestFreshSaves=false
   - shard the bug-report day keys
   - confirm FeatureFlags.Park
   - the Creator Hub listing (`artifacts/store-listing/`): public, 12 players
   - check Creator Analytics Funnels/Custom events

## 4. How to work (proven workflows)

**Review-driven build.** For every non-trivial change:
1. Plan.
2. Architect review.
3. Implement.
4. Code review.
5. Fix.
6. Verify in Studio.
7. Commit and push.

Commits end with a co-author line. Keep `TODO.md` current as you go, not at the end.

**Lanes.** Parallel agents must own disjoint files. `init.server.lua`, `init.client.lua` and `UICopy.lua` each get one owner per batch. UICopy is append-only, one block per slice. Agents never commit, never delete files (Rojo 7.7.1 crashes when a watched file is deleted) and never start Play. The coordinator runs Studio, commits and publishes.

**The Luau limit.** `init.client.lua` is at **219 column-0 locals**, which is the budget, and `scripts/ClientLocalBudget.spec.lua` enforces it. New wiring goes in `do ... end` blocks or on `clientUI`.

**Saves.** Hatching is v11 with additive optional fields only. Never renumber bits. Pools stay sorted and keep their old entries. `inventoryMask` is bounded at 255; Blip is bit 0x80.

**Rojo.** `rojo serve --port 34873 default.project.json`, run unsandboxed. The Studio plugin connects to host **127.0.0.1**, not localhost.

**Running specs.**
1. Copy `scripts/X.spec.lua` to `src/server/ZZSpecs/X.lua` or `src/client/ZZSpecs/X.lua`. Both are git-excluded.
2. Restart Play, because `require` caches.
3. Use `execute_luau` in the Server or Client datamodel. The first Server call after starting Play sometimes fails with "Target is not reachable"; retry once.

Argument signatures:
- server specs: `f(server)`
- `SessionRecovery`: `(server, server.PlayerProgress.Source, server.SessionProfile.Source)`
- `BugReports`: `(server, shared)`
- `HatchProgress`: `(require(server.HatchProgress), require(shared.EggCatalog))`
- `ToyFeatureProgress`: `(server, Z.FixtureFrozenV370.Value, Z.FixtureFrozenDaily.Value)`
- `PetContactHost`: `(server, server.Source)`
- `NeutralPetRoster` / `HuePalette`: `(shared)`
- client specs: `(client, gui)`, where gui is a fresh ScreenGui

**Publish.** Use computer-use on Roblox Studio:
1. Click File at (10,19), then Publish at about (25,200).
2. Confirm "Published new changes" and read the version from Quick Links ("Add publish notes to vNNN").
3. If the Studio start window covers the Egg Drop window, minimise it first.
4. Record the build in `PLAY-BUILD.md`, newest at the top, with what's new, what passed and what to test.

**Translations, every build.**
1. `python scripts/export_localization_csv.py`
2. `python scripts/sync_localization.py`. It needs `ROBLOX_LOCALIZATION_KEY` in `~/.claude/.env`; run it unsandboxed.
3. Record "translations synced (N/M)" in the build's PLAY-BUILD entry.

**Uploads.**
- Studio MCP `open_cloud_invoke` POST `/assets/v1/assets` with `files:[{name:"fileContent",path}]`, scopes asset:read/write, creator userId 10716920546. Then poll `/assets/v1/operations/<id>`.
- **Image** uploads return the image id directly.
- **Model (FBX)** uploads: read the MeshIds with `InsertService:LoadAsset(id)` in Edit.

**Bear wearables pipeline.**
1. Add items to `ITEMS` in `scripts/build_bear_wearables.py`.
2. Run Blender in background: `".../Blender 5.2 LTS/blender.exe" -b assets/art-source/pets/pet-bear-attachments.blend --python scripts/export_bear_attachments.py`
3. Upload the changed FBX group.
4. Write the parts into `bear-attachments-studio-import.json` with `rel = (-cx*100, cz*100, cy*100) - (-0.002, 93.439, 1.038)`.
5. Run `python scripts/build_bear_attachments.py`, then `python scripts/build_bear_assets.py`.

**Book atlas.** `render_book_icons.py`, then `build_book_atlas.py`, which pages at 32 cells per page. Upload the pages and set `BookView.Art` (atlas, atlas2).

**World meshes.**
1. Fix in `scripts/build_world_v7_chunks.py`.
2. Export, upload, and write the ids into `world-v7-studio-import.json`, which is one JSON line.
3. Run `build_world_v7_assets.py`.
4. In Studio Edit, rebuild collision for each changed solid mesh: `AssetService:CreateMeshPartAsync(meshId,{CollisionFidelity=PreciseConvexDecomposition})`, then `ApplyMesh`, then restore Size, CFrame and TextureID. The parts are in `ServerStorage.WorldAssets.WorldV7`.
5. `save_place`.

**Studio-only helpers** (see memory notes in `.claude` and AGENTS):
- `workspace:SetAttribute("StudioPetWearables","Eyes=round;Mouth=w")` previews wearables.
- `PetFactory.new(root,pos,Pets.byId.pip,scale,appearance,{})` builds a test Bear.
- For clean captures, bind a RenderStep camera at `RenderPriority.Last+100` and disable the PlayerGui ScreenGuis.

## 5. Spencer's taste and rules

Treat this as the tastebook.

- **No AI-generated art, ever**, and that includes marketing. Only hand-built or procedural art (Blender, PIL) and real in-game captures.
- **Original designs only.** Inspiration is fine, for example cozy life-sim conventions in the eye shapes. Never recreate an existing game's characters or items.
- **Cute and readable at phone size**, never creepy. Things he has rejected:
  - beady wide-set eyes ("creepy")
  - dog, cat and bunny plush ("too creepy")
  - his own Chao-like base ("reads as a Chao")
  - flat-shaded, very low-poly bodies
  - Blip v1 and all three v2 concepts ("we need cuter")
- **Pet look:**
  - a low-poly Dreamcast/GameCube silhouette with smooth shading and moderate gloss
  - a two-tone body
  - a face in dark ink
  - the charm floats centred above the head
  - the Bear uses his yellow-to-pink gradient material
- **Things he liked:**
  - the side-offset flower charm and three-feather wings
  - his eye and mouth textures
  - Happy Eyes and Lash Eyes
  - the confetti reveal
  - quiet, fading pills instead of intrusive cards
- **UI:**
  - PlayStation-style dark glass menus tinted by the Pocket Deck colour
  - the PICO-8 palette for the game
  - the menu shell consistent on PC and phone, with a full-screen dim per menu
  - the 3D Star in every wallet
  - phone looks like PC (the full handheld)
- **Monetization:**
  - Stars only as the soft currency
  - fixed prices
  - odds shown on eggs
  - no paid luck, no random Robux items, no pay-to-win
- **Scale goal:** a solo developer (plus maybe one more) at $5–10k/month. Prefer rotation built from existing art over new heavy content.
- **Communication:**
  - Be direct and lead with the answer.
  - No openers or sign-offs.
  - Show captures with real images.
  - Never ask "should I save this?"; just record it.
  - Ask before anything outward-facing or irreversible: a **public** publish, deleting his files, accounts, money.
  - Private publishes are fine when the work is verified.
- Keep `TODO.md` and `PLAY-BUILD.md` current. Save notable decisions to memory (`~/.claude/memory`, shared with Codex).

## 6. Accepted decisions (for reference)

- **CONTENT-SCOPE §6 (2026-11-14), all five:**
  - Blip is free on the 7th stamp.
  - Wardrobe is per pet, with 10 Bear refits.
  - Bond levels 1–5 in v1 (6–10 are now built too).
  - One fixed-price Robux bundle plus private servers.
  - No random Robux items.
- **Pet Park v1 and the UI personality scope:** all recommendations accepted (2026-11-14).
- **Overnight defaults** (SYSTEMS-SCOPE §8):
  - Variants don't count on the Book.
  - Stargazer is earned at Discoveries 100%.
  - The shelf only spotlights and discounts; it never gates (no FOMO).
  - Blip isn't switched to automatically on arrival.
  - `pet_night` uses the real clock while DayNight is off.
- **The owner-still sit** is at bond level 1. Level 2 makes it sooner (`Room.BondSitHead`).
