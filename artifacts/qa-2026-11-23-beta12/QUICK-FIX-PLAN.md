# Beta (12) quick-fix batch: plan (Opus, 2026-11-23)

Source: `FEEDBACK.md` in this folder. Items S1, G1, T1, O1, G2/G3 and U1. Branch `worktree-agent-a8953522b60d4b3f1`, fast-forwarded to `feat/egg-drop-arcade-polish` (8569c6e). Offline baseline: `python scripts/run_dash_server_specs.py <luau>` exits 0 on this tree.

Every new switch follows the v3 pattern (IslandBounds / Finds): a FeatureFlags build ceiling, the beta place or Studio, a ConfigService key read by an AliveConfig-publisher module, and an owner chat command on the beta and in Studio. Nothing here reaches live 96451847774961.

Order of work: S1, U1, O1 (wiring) first (small, independent), then G2/G3 fixes, then G1, then T1 (save-touching, most review).

---

## S1. Remove the wind rustle ("toilet flush")

**Diagnosis.** The rustle is a 14 s loop (`Ambient.RustleId` 131058187750745) that `stepRustle` starts from `TimePosition 0` every time a gust arrives, rises to .10 over about .25 s, and stops 1.5 s after the gust ends. Gusts come every 9 to 16 s (`Wind.Slot` 12.5 s, 3 in 10 skipped), last 3.5 s, and grow and fade. So the same loop opening swells in and fades out every 12 s or so, which matches "intermittent, new, toilet flush".

**Change.**
- `src/client/AmbientAudio.lua`: `Ambient.RustleId = nil`, with the id kept in the comment (`-- 131058187750745, egg_drop_wind_rustle.wav: off since beta (12) QA S1`). `stepRustle` already returns early on a nil id and makes no voice, so the code path stays and nothing else changes. No new switch: a future replacement sound is one id.
- `scripts/WindClient.spec.lua` (the issue names `src/client/ZZSpecs/WindClient.lua`, but the spec lives in `scripts/`): the two rustle tests that need a voice set a fixture id (`Ambient.RustleId = 1`) in a pcall and put the shipped value back, as the "no id" test already does. Add one case: "the shipped build makes no rustle voice" (shipped id is nil; a minute of full gust leaves `rustleVoice == nil`).
- `V3-TEST-PASS.md` row 1: drop "a soft rustle", add "(rustle removed after beta 12)".

**Other looping or intermittent sounds since live `54dca26`** (`git diff 54dca26..HEAD -- src`), in case it is not the rustle:

| Sound | Where | When it plays | Likely flush? |
|---|---|---|---|
| `wind_rustle` loop | AmbientAudio.stepRustle | Every gust (about every 12 s), garden only | **Yes**: a swelling whoosh on a cycle |
| `machine_attract` at pitch 1.19 | StationAttract `Dash` entry (new extra station) | When you come within beckon range of the Dash gate, once per approach | Unlikely: short ping |
| `machine_attract` at 1.0 | NestClient:ping | Once per ready egg when you come within `Nest.ReadyPing` | No |
| Pet cue at 1.1 | BearNeeds idle hint (init `chirp`) | Every 20 s standing still with an open need, new saves only, capped by `IdleHints` | No (new saves only) |
| `snack_sniff` + `snack_boost_sparkle` | FindsClient | On a find claim | No |
| `hatch_rise`, `snack_boost_sparkle`, `hatch`, `land`, `pet_coo_1` | NestClient | Tuck in and hatch only | No |
| `streak_whoosh`, `drop`, `count_blip`, `retry`, `quest_complete` | DashClient | During a race only | No (a whoosh, but race only) |
| Medal sting | MedalView | On a medal | No |

Existing loops (brook bed, the two waterfall loops) are unchanged since `54dca26` apart from earlier volume cuts. If Spencer still hears it with the rustle gone, the next suspect is the Tumble Falls loop at the edge of its 44-stud range.

**Edge cases**

| Case | Result |
|---|---|
| Wind on, full gust, Ambience on | No rustle voice is made; flags and chimes still move |
| `/alive wind off` | As before (moves stop); still no rustle |
| An old client (pre-fix) on the same server | Plays its own rustle; client-only, no network |
| Live | AmbientAudio never builds the wind (Alive ceiling); unchanged |

**Tests.** WindClient.spec (3 rustle cases adjusted, 1 added). `AmbientAudio` is already in the offline runner; add `WindClient` to `CLIENT` in `run_dash_server_specs.py` if it runs with the mocks (check; otherwise Studio ZZSpecs only).

**Risks.** None on save or network. Spencer may miss the leaves; a softer, non-looping one-shot can come later (Astra's call).

---

## G1. Pets catch up: teleport to the owner when too far or stuck

**Where it lives.** Pets are server-authored in `src/server/GardenState.lua:decide` (0.5 s cadence). The v859 leash (`Layout.LeashRadius` 19) already makes a far pet walk back at up to 18 studs/s, which a running owner (16 studs/s) outpaces, and a pet whose planned path stops short (`safetyStop`, or `resolveTarget` returning `from`) stands still. The client (`PetFollow.lua`) already treats a jump of more than 8 studs as a rest, not a run (`traveled>8`), and `PetPoseSampler` drops the old foot stance on a discontinuity, so a server teleport draws cleanly.

**New files**
- `src/shared/PetCatchup.lua`: the IslandBounds/Finds pattern. `PlaceId` 107705084891479, `Attribute "Catchup_on"`, `Key "pet_catchup"`, `ceiling(env)`, `resolve`, `setSwitch`, `on`, `inject`. Plus the pure rules (below) and `landing(...)`.
- `src/server/CatchupConfig.lua`: IslandBoundsConfig clone on one key: `/catchup on|off|clear`, off until the config has loaded once, then missing or malformed = on.
- `src/client/PetPoof.lua`: the poof (placeholder look; Fable sets the numbers).
- `FeatureFlags.PetCatchup = true` with its comment line.

**Numbers (proposed)**

| Name | Value | Meaning |
|---|---|---|
| `Far` | 40 studs | flat distance from the pet's sampled position to the owner's ground anchor (`input.anchor`) |
| `FarHold` | 1.5 s | Far must hold this long (a respawn or bounds return counts, a single bad sample does not) |
| `StuckNear` | 8 studs | below this gap the pet is never "stuck" |
| `StuckSeconds` | 4 s | following, gap over StuckNear, and the best gap has not shrunk by `StuckGain` 1 stud in this long |
| `Cooldown` | 8 s | per pet between catch-ups |
| `Retry` | 2 s | after a search found no landing |
| `Burst` | 4 a minute | over this the pet stops catching up for 60 s and the server warns once (a loop guard) |
| `Rings` | 0, 2.5, 4 studs, 8 bearings | landing candidates round `input.anchor`, the side away from the owner's facing first |
| `WallKeep` | 3 studs | from every `IslandBounds.Walls` centre line |
| `CourseKeep` | 4 studs | from the Dash course line (DashCourse Main + Branch), only while any race is live |
| `PadKeep` | 2 studs | past the Dash waiting pad's edge, only while any race is live |

Distances are measured to `input.anchor`, not the character: when the owner is on a terrace or bench, `groundAnchor` keeps the anchor on the last ground spot, which is where the pet should be.

**Server change (`GardenState`)**
- New optional deps: `options.catchup()` (true when `PetCatchup.on()`), `options.landing(input, from, racing)` (a Vector3 or nil). init supplies both; specs inject them. With `options.catchup` nil or false the decide loop and the snapshot are byte-for-byte as today (off parity).
- In `decide`, after the existing `Focus`, `care`/`dash`, `park` and `Board` skips and before the v859 leash: `if self:catchUp(actor,input,position,now) then continue end`.
- `Garden:catchUp`: tracks per actor `farSince`, `stuckBest`, `stuckAt`, `catchAt`, `catchCount`/window. When due, asks `options.landing`; on a hit: `self:release(actor)`, `old = position`, `self:transition(actor,"rest",landing,.6,"catchup")`, then `actor.from = actor.to = pack(landing)`, `actor.path = nil` (as `focus` does), `actor.poof = pack(old)`, `actor.idleSince = now`. When the rest ends, decide's last branch returns it to follow.
- Snapshot: `poof = if actor.action=="catchup" then actor.poof else nil` (absent otherwise, so the snapshot is unchanged when off).
- Stuck tracking runs only while `behavior=="follow"`; any other behaviour clears it.

**`options.landing` in init** (server, beside `resolveTarget`): for each candidate in ring order: `resolveTarget(candidate, candidate)` must return a point within .5 studs of the candidate; `IslandBounds.safeCell(x, z)`; `PetCatchup.clear(point, racing)` (walls, course, pad: pure, in the shared module, the course line built once from DashCourse as `LifeSim.courseLine` does); within `LeashRadius - LeashMargin` of the owner. First that passes wins; none: nil.

**Client**
- `PetFollow.lua`: when `sample.action=="catchup"` and `sample.actionId` differs from `state.catchupId`, call `PetPoof.play(visual, old, sample.position, reduced)`; `old` is `visual.origin` before this frame's move (already in hand there). Works for every player's pet, since all pets go through PetFollow.
- `PetPoof.lua`: two short puff bursts (old spot and new spot), placeholder 8 white puffs over .35 s, LightInfluence 0, local folder, cleaned up after 1 s. Reduced Motion: no puffs; the pet just appears. Optional soft "pop" via the existing `aim` cue at low gain, only for my own pet (Astra to decide; off by default).

**Wiring.** `init.server.lua`: start `CatchupConfig` next to the other configs (line ~121); add the `/catchup` chat line in the owner block (~line 857); pass `catchup` and `landing` into `GardenState.new`.

**Edge cases**

| Case | Result |
|---|---|
| Owner runs away for 3 s (pet 45 studs behind) | After 1.5 s over Far: poof, pet lands 2.5 studs behind the owner |
| Owner respawns or FallCatch / bounds return moves them | Same, 1.5 s later |
| Pet on the far side of an IslandBounds wall, path stops short | Stuck after 4 s without progress: lands on the owner's side |
| Owner in a Pocket Deck round (`mode=="Board"`) | Skipped (pet rests at the station as today) |
| Owner racing (`actor.dash`) | Skipped; the race draws the pet |
| Someone else racing | Allowed, but never lands within 4 studs of the course or on the pad |
| Pet in a park, focus, care, carried or docked | Skipped (existing branches continue first) |
| Pet in a greeting pair or a nook | `release` ends it, as the leash does; the partner resumes |
| Owner on a bench or terrace | Measured to the ground anchor; no teleport while the pet sits at it |
| Owner standing in the creek or on unwalkable ground | `resolveTarget` clamps every candidate: no landing, retry in 2 s, no poof |
| Owner just standing still, pet resting 10 studs away | Not following or under Far: nothing |
| Wander or sit near the owner | Within StuckNear or not following: nothing |
| Teleport loop (landing that the planner cannot leave) | Burst cap: 4 a minute, then 60 s quiet and one warn |
| Switch off mid-tracking | Counters cleared; next decide is today's code |
| Live place | Ceiling false: `options.catchup` returns false, snapshot unchanged |
| Old client sees `action="catchup"` | Unknown action: it draws a rest at the new spot (pet jumps, no poof) |

**Tests**
- `scripts/PetCatchup.spec.lua` (pure, offline): ceiling and resolve (live place false, beta true, Studio true, flag off false); `clear` (wall, course only while racing, pad); ring order.
- `scripts/CatchupConfig.spec.lua`: the FindsConfig.spec cases (parse, off before load, override, clear, ceiling off starts nothing).
- `scripts/GardenState.spec.lua` additions: far for 1.4 s does nothing, 1.6 s teleports; stuck 4 s teleports, slow progress does not; cooldown; burst cap; Board, dash, park, focus skipped; no landing means no change; snapshot has `poof` only on a catch-up; `catchup` nil gives the same snapshot as today (off parity, JSON compare).
- Add `PetCatchup`, `CatchupConfig`, `GardenState` (if it runs on the mocks) to `run_dash_server_specs.py`.
- Studio: walk off fast, respawn, try the north spur wall, race with a second test client watching.

**Risks.** A teleport that lands somewhere the planner then cannot leave (loop: burst cap covers it). Measuring "stuck" too eagerly near a nook or the park kerb (StuckNear 8 and follow-only keep it narrow). Other players see a pet pop: intended.

---

## T1. `/freshsave`: a fresh save for the owner on the beta

**What exists.** One DataStore, `ProgressStore.Name = "EggDropLaunchV3"`, key `player_<userId>`, shared by `PlayerProgress` (profile fields) and `HatchProgress` (`record.hatching`, with a lease `{token, expiresAt}`, 90 s, released on close by `CloseProgress.drain`). `Progress.load` sets `profile.newSave = record == nil`, which FirstSession and the v3 onboarding key on. In Studio `DataStoreService` is nil and the store is an in-memory table. DataStores are per universe, so the beta (universe 10777916361) can never reach live's saves; the code still refuses anything off the beta.

**Design: intent now, swap on the next join.** Doing the swap at kick time races the closing server (and the server itself may shut down when its only player leaves). Writing an intent and applying it at the next join runs on a server that is staying up, after the old session's lease is released.

**New file `src/server/FreshSave.lua`** (server only; ServerScriptService):
- `FreshSave.ceiling(env)`: `(game.PlaceId == 107705084891479 and game.GameId == 10777916361) or RunService:IsStudio()`. Specs pass `{place, game, studio}`.
- One side key per owner, `freshsave_<userId>`, in the same store: `{version=1, intent="fresh"|"restore"|nil, intentAt, backup=<record>|nil, backupAt, restoredAt, testing=bool}`. One key, so the intent and the backup change together.
- `FreshSave.command(player, message)`: owner (`SimCheck.isOwner`) and ceiling only. `/freshsave` sets intent `fresh`; `/freshsave restore` sets intent `restore` (refused, with a chat line, when there is no unrestored backup); `/freshsave cancel` clears the intent. On success: `player:Kick("Fresh save on your next join. Rejoin the beta.")` (or "Your old save comes back on your next join."). One command per 10 s.
- `FreshSave.apply(userId)`: called in `addPlayer` before `Progress.load`, owner and ceiling only, at most 20 s:
  1. Read `freshsave_<userId>`. No intent: return.
  2. Fence the player key: `UpdateAsync(player_<id>)`: if `hatching.lease.expiresAt > now` and the token is not ours, abort this try ("Locked": the old server is still draining) and retry every 2 s; otherwise take the lease with our own token for 90 s and keep the `previous` value the callback saw as the snapshot.
  3. **fresh**: update `freshsave_<id>`: if a backup exists and has no `restoredAt`, keep it (the current save is an earlier test save and is thrown away); else store the snapshot (lease cleared) as `backup`, `backupAt = now`, `restoredAt = nil`. Set `intent = nil`, `testing = true`. Only after that write succeeds: `RemoveAsync(player_<id>)`.
     **restore**: `UpdateAsync(player_<id>)`: only while the lease token is ours, write `backup` back with the lease freed (`token ""`, `expiresAt 0`). Then `freshsave_<id>`: `restoredAt = now`, `intent = nil`, `testing = false`. The backup stays in the key until the next `/freshsave`.
  4. Any failure: give our lease back (`expiresAt 0` if the token is ours), keep the intent, warn, and the join goes on with whatever save is there. Nothing is removed unless the backup write succeeded first.
- `ProgressStore`: add `Store:RemoveAsync(key)` (memory: `memory[key] = nil`; DataStore: budget wait, then `RemoveAsync`).
- The beta's one-time 1,000 Star owner top-up (`beta:stars:2026-11-20`) would land again on a fresh save; skip it while `testing == true` (FreshSave.testing(userId), read once at join).
- After a fresh join the owner gets one system line: "Fresh save. Your old one is backed up: /freshsave restore." (TextChatService system message, or the notice rail if simpler.)

**Edge cases**

| Case | Result |
|---|---|
| `/freshsave` on live | Ceiling false: not connected at all (the owner chat block is beta or Studio only; FreshSave also checks place and universe) |
| Non-owner types it | Ignored (owner check) |
| `/freshsave` twice before restoring | The first backup (the real save) is kept; the second test save is discarded |
| Restore, play, then `/freshsave` again | The restored save becomes the new backup |
| `/freshsave restore` with no backup | Refused with a line; nothing written |
| Old server still draining at rejoin | Lease held: retries for 20 s; then the join goes on with the old save and the intent stays ("rejoin in a minute") |
| Close timed out (lease left for 90 s) | Same as above |
| Backup write fails | Lease given back, player key untouched, intent kept |
| `RemoveAsync` fails after the backup is written | Lease given back; the old save loads; intent kept; the next join tries again (the backup is not overwritten: it has no `restoredAt`) |
| Owner joins two servers at once | The second hits our lease: Locked, the existing retry path in HatchProgress |
| Studio | Memory store: works within the play session only |
| A late profile write from the old server | Cannot happen after release: `CloseProgress.drain` flushes the profile before it releases the lease, and we wait for the release |

**Tests.** `scripts/FreshSave.spec.lua` (offline, with an in-memory store fake): ceiling (live place false, live universe false, beta true, Studio true); command parse and owner gate; fresh with no backup, with an unrestored backup (kept), with a restored backup (replaced); restore with and without backup; lease held by another token (abort, intent kept); backup write fails (nothing removed); remove fails; `newSave` true after a fresh apply (with `Progress.load` against the fake store). Add to the offline runner. Studio: `/freshsave`, rejoin, row 11 new-save checks, `/freshsave restore`, rejoin, old Stars and pets back.

**Risks.** It deletes a save key; the guards above (backup first, own lease, beta universe only) are the whole safety story and want a careful review. A backup record larger than the DataStore limit is not a real risk (records are small) but the write would fail safe.

**Rejoin note.** Both directions need a rejoin; the command kicks with the reason, and `V3-TEST-PASS.md` gets a "Test tools" line: `/freshsave`, `/freshsave restore`, `/freshsave cancel`, each followed by a rejoin.

---

## O1. Nest copy in plain words (wiring only; Fable writes the words)

**Today.** The nest board (`NestClient:draw`) has a clock pill ("Ready in 7 h.") and, within `Client.Near` 8 studs, an "Inside: Ball and 5 Stars." pill. Tuck in says "Sleep tight. It will wait for you." for 4 s. The prompt's ObjectText is "Sleepy egg". Nothing says what the egg is.

**Plan, so swapping strings is one edit in `UICopy.lua`:**
- New keys under `onb3.nest` (placeholder text until `GARDEN-LIFE-NEST-LOOK.md` lands): `explain` (near, before the first tuck in: "{pet}'s egg naps for {hours} hours. Come back to hatch a gift."), `explainTucked` (near, after tuck in, while it grows), `firstTuck` (the say() line after the very first tuck in, held longer), `explainReady` (near, ready). Placeholders `{pet}` and `{hours}` from `view.pet` and `Nest.Seconds / 3600`.
- `NestClient`: one table `Client.Copy = {explain="onb3.nest.explain", ...}` naming the keys by role, and one pure `Client.explain(view, now, firstEgg)` that picks the role. The explain line takes the second pill's place when near (the "Inside:" line moves to it after the explain has shown once per egg, or a third pill if Fable wants both: decided by her look doc; the pure function returns both texts so either layout is a paint change only). `Client.FirstTuckLabel` seconds for the longer hold.
- `scripts/NestClient.spec.lua`: replace literal English (`"Ready in 7 h."`, `"Sleep tight..."`, `"Inside: ..."`) with `UICopy.get(key, args)` so copy edits never break specs; add explain-role cases (first egg near, tucked, ready, far shows nothing).
- Before publish: `export_localization_csv.py`, then `sync_localization.py` (AGENTS.md).

**Edge cases:** pet name missing (use `onb3.notifyPlain` style fallback key `explainPlain`); long names (pill width already clamps to 236 px; check with PseudoLocale); compact phones (13 px).

**Tests.** NestClient.spec in the offline runner; LocalizationFit/UICopy specs pick the new keys up.

---

## G2. Garden finds not seen (row 6): diagnosis

**Gates are fine on the beta.** `FeatureFlags.GardenFinds` true; `Finds.ceiling` true on 107705084891479; `FindsConfig` is off only until the config loads once, then a missing `garden_finds` is on (the same load that makes `garden_hour` work). Client mount gates the same way. So finds were most likely on.

**Likely cause: they spawn where he is not, and nothing tells him.**
1. Timer: the first find needs `Finds.FirstAfter` 60 s of *active* time: Room mode, alive, no `conflict` (`careHeld`, `dashHeld`, an unacknowledged `lastHatch`, saving), and the character moved 2 studs within the last 60 s. Deck rounds, races, petting/care and standing still all pause it; a rejoin starts it again (server memory). After that, one every 240 active s. A QA pass that hops between deck, Dash and menus can easily bank less than 60 s of garden walking per session.
2. Place: `Finds.pick` is uniform over the 24 spots on four lawns (south, east, west, grove), with no relation to where the player is. It can appear 100+ studs away or behind the mountains.
3. Look: a 1.8-stud billboard star 1.4 studs over the grass, `MaxDistance` 140, not `AlwaysOnTop`, no beam, no sound, no tip when it appears. The only pointer is the Things to do row "N finds waiting" with Show me, which he may not have opened.

**Fix (proposed, Spencer/Astra to agree):**
- Spawn near the player: pick among spots within `NearSpot` 45 studs of the character that are not within 10 studs of it (fall back to the nearest open spot), so the sparkle lands somewhere he can see. Pure change in `Finds.pick(random, live, recent, near)`; the server passes the root position.
- Announce it: when a find is placed, a soft tip in the notification rail, "Something sparkly on the lawn!" with Show me (uses the existing trail); once per session plus the existing `Notice` twinkle.
- Easier to spot: a thin light shaft or a taller glint visible from 140 studs (Astra's look; numbers from her).
- Test tool: owner `/finds now` places one at once (beta/Studio only), so QA does not wait a minute.
- Optional: `FirstAfter` 60 to 30 s on the beta.

**Tests.** `FindsState`/`FindsHost` specs: pick prefers near spots, falls back when none; `/finds now` parse and ceiling; tip fires once per session.

---

## G3. Dewdrop fruit not seen (row 15): diagnosis

**Gates are fine.** `AliveLife` flag, Alive ceiling on the beta, `life` key missing = on, Aero on with lime trees (row 4 passed). Butterflies and birds showed, so GardenLife is enabled and the budget is under level 2.

**Likely cause: very few, small, and half hidden.**
1. Only the 12 `LifeSpots.Crowns` carry fruit, and 4 of those are on the islets: 8 trees on the island (Landmark BlossomPoint, Tree_05/07/10/14/17/19/21 blossom). The round and tall lime trees have none.
2. Each crown fills a slot with chance .8 of 3: about 2.4 drops a tree, about 19 on the island, at most 16 drawn (8 at budget level 1, which also stops the sway).
3. Each is a 1.1 by 1.28 stud billboard. The stem tip is `.8 * size.Y` under the crown's top (inside the lower skirt), and the image centre hangs `.64` studs under that: for a 5.7-stud crown at radius `.36 * size.X`, the drop's top half sits inside the crown's silhouette, and from a standing camera under a tree it reads as a small coral dot in lime leaves.
4. Falls need a gust peak of at least .8 (about half the gusts) and the .35 per-crown chance; the fallen drop rests 18 s then fades. Easy to miss.
5. FEEDBACK W2 notes he may have seen them without knowing what they were.

**Fix (proposed, look numbers are Fable's):** hang them clear of the crown (`down` .80 to about .95 and `hang` .64 to about 1.0), bigger (`FruitSize` 1.1 by 1.28 to about 1.5 by 1.75), fill every slot on the island trees (`fill` 1), and add the round lime crowns to the grove (regenerate `LifeSpots` with `scripts/build_life_spots.py` including the round and tall crowns, a separate `FruitCrowns` list so petals stay on the blossoms). All are `Sim.Fruit` and `GardenLife` constants plus the generated data; specs in `LifeSim.spec`/`GardenLife.spec` read the constants, and the "never on a find, course or kerb" cases must still pass.

---

## U1. Notification text a smidge lower

**Card.** `src/client/PetFocusUI.lua`: the `PettingHint` TextLabel (`self.helper`, built near line 101), text "Tap or rub · hold E to pet" (line 595) and the save notice detail. `layoutSaveHelper` (line 549) sizes it: height `Art.textHeight(helper, width, 26) + 8`, text centred.

**Why it sits high.** `Art.type` (DeckArt 301) zeroes any `UIPadding` top and bottom each time it runs, and the label is re-typed on every layout, so the card has no vertical inset of its own; the Supporting face's line box puts the glyphs above centre.

**Fix.** In `layoutSaveHelper`, after `Art.type`: ensure one `UIPadding`, set `PaddingTop = Focus.HelperNudge` (Fable's number from `DASH-DECK-UI-LOOK.md`; placeholder 2 px) and `PaddingBottom = 0`, and add the nudge to the height (`textHeight + 8 + nudge`) so the bottom inset does not shrink. Apply the same to the `RoamPetHint` clone only if Fable says so. `PetFocusUI.spec` and `SaveNoticeLayout.spec`: the helper keeps its padding after a relayout and its height grows by the nudge.

---

## Questions for the architect

1. **G1 distance basis.** Measure "too far" to `input.anchor` (the ground anchor, so a pet waiting below an owner on a terrace never teleports) rather than to the character. Agree, and is 40 studs / 1.5 s the right trigger given the leash walks back at 18 studs/s?
2. **G1 snapshot shape.** A new `action="catchup"` plus a `poof` field (absent otherwise) versus a separate `teleports` list in the snapshot. The action route reuses PetFollow's per-actionId hook and keeps off parity; is an unknown action safe enough for an old client still on the server after a beta publish?
3. **T1 deletion.** `RemoveAsync` on `player_<id>` after the backup write, fenced by taking the hatching lease ourselves. Is the fence enough, or should the fresh state be written as an explicit empty record through `HatchProgress` (losing `newSave`, which FirstSession and the onboarding key on, unless `newSave` also learns a "fresh" marker)?
4. **T1 gate.** Place id plus `game.GameId` plus owner plus the existing beta-only chat block. Do you also want a `FeatureFlags.FreshSaveCommand` ceiling, and should the 1,000 Star beta top-up skip while a fresh test save is active (my proposal) or stay?
5. **G2/G3 scope.** The diagnosis says both features work but are hard to notice. Is "spawn near the player + rail tip + `/finds now`" and "bigger, lower, more crowns" in this quick batch, or does it go to Fable first for the look and come back as its own slice?
