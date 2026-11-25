# G2: build plan (Opus, 2026-11-25)

Branch `growth/v1057` (live runtime + funnel fix + Hatch another + G1 `ce5376a0`, `c5c1927a`). Spec:
`artifacts/growth-2026-11-26/G2-FIRST-SESSION-LOOK.md` (Fable) in the main checkout. Five switches in
`FeatureFlags` (`PetTrail`, `FirstHelloBonus`, `RoundTwoNudge`, `ToyPillCopy`, `CalmFirstDeck`), all `true`;
off = today's behaviour exactly. No new art, no new remotes.

## Files

| File | Change |
|---|---|
| `src/shared/FeatureFlags.lua` | five switches |
| `src/shared/FirstHello.lua` (new, pure) | `Bonus=2`, `valid` / `sanitize` / `due` / `apply` for the optional save field `firstHello` |
| `src/server/HatchProgress.lua` | `valid()` chain + load-time sanitize; `awardPet` pays +2 inside its transaction, receipt `lastPetAward.hello`; `defaultAdapter().firstHello=true` |
| `src/server/PetContact.lua` | the Saved reply's receipt carries `hello` (number or nil) |
| `src/server/init.server.lua` | Economy: the pet part stays `PetCare`, the +2 is its own source (`Onboarding`, sku `FirstHello`) |
| `src/client/PetAffection.lua` | `showHello(count, secondary, reduced)`: gold plate `First hello! +3 ★` held 1.6 s, sparkle + chime, six bond hearts (none under Reduced Effects) |
| `src/client/PetTrail.lua` (new) | pure: print positions, walk swell, fade order, lifetime rules, ground test, edge-chip placement; view: 12 pooled ground parts (vector paw on a top SurfaceGui), the `StationAttract`-style ring at the pet, one screen-edge chip |
| `src/client/PetLookAt.lua` | `visual.faceOwner` holds the existing look-at on the owner (no new animation) |
| `src/client/GrowthNudge.lua` (new, pure) | round-two pill: which variant (`bonus` / `toy` / `plain`) or none; the toy-pill copy keys per switch |
| `src/client/DeckCalm.lua` (new, pure) | Welcome-round calm plan per HUD layout: hidden cards, grown coach and egg rects, text sizes |
| `src/client/DeckScreen.lua` | `setWelcome` applies / restores the calm plan (saved originals; the board rect and every hit target untouched) |
| `src/client/NotificationRail.lua` | a `round` kind (go-tinted disc, ink icon); `kitIcon` allowed on it |
| `src/client/NoticeCards.lua` | notice `firstToy` (reuses `notice.firstSpend.next`, so 7 new strings not 8) |
| `src/client/CoachCards.lua` | `trailDue`: set when the say-hi line starts (or, with `GardenTourCut` off, when a first-visit tour closes) |
| `src/client/init.client.lua` | trail controller (in a `do` block: no new top-level locals); hello plate on a Saved receipt with `hello`; toy pill text + name refresh; round-two status pill (tap = `playRoundForStars`) |
| `src/shared/UICopy.lua` | `pet.hello`, `coach.roundTwo.{bonus,toy,plain}`, `notice.pill.firstToy`, `notice.firstToy.{title,what}` |
| `scripts/*.spec.lua` | `FirstHello` (pure + HatchProgress fixture), `GrowthG2` (client pure rules) |

## Save field: `firstHello` (FirstHelloBonus)

- Optional on hatching v11, no version bump (as `starterRounds`). Valid: nil or integer `0..255` (the Stars the
  first hello paid; frozen stored bound). Malformed: dropped at load (`acquire`, beside `StarterBonus.sanitize`).
- **Due** only when: the field is missing, `lastPetAward == nil` (no pet ever paid: `petCount` never returns to 0
  once a pet is paid, so the receipt is a lifetime marker), `stats.rounds == 0` and `lastAwardSeq == 0` (no field
  round ever saved, G1's B2 rule). Any present value = done.
- **Deviation from the spec, on purpose:** "gardenIntro already set" is not used. G1's say-hi line saves
  `gardenIntro` the moment it shows, before the player can reach the pet, so that rule would refuse every new
  player. "Never petted and never finished a field round" already excludes every existing player who has played.
- Paid inside `awardPet`'s transaction (`transact`, fence, `pet:<id>` signature, `lastPetAward` receipt proof):
  a retried or ambiguous write resumes the same pending op and can never pay twice. +2 flat on top of the +1
  (no pass, no Supporter: `awardPet` has neither). Counts as one of the day's pets (same award).
- Gate captured in the frozen candidate at call time: `FeatureFlags.FirstHelloBonus == true` and
  `handle.adapter.firstHello == true` (only `defaultAdapter`), so every existing pet spec keeps +1.
- `BalanceLimit`: refuses when `nectar + 1 + hello > 1e9`, as today's `>= 1e9` for +1.
- Old servers (v1056) ignore and keep `firstHello` and the extra receipt key (`validVersion` reads named keys only).
- Client: shows only what the receipt says (`receipt.hello`); count = 1 + hello.

## Client

- **Trail** (`PetTrail`): starts when CoachCards sets `trailDue` (new player, not a replay, free settled garden),
  once per session (the say-hi line itself is once per save via `gardenIntro`). Ends on the first Saved pet
  receipt, 30 s, a menu or machine open (`open` map or any overlay), or the deck (Mode ~= Room). Hidden (not
  ended) while focusing or busy. Prints: start 3 studs ahead of the player, stop 2.5 short of the pet, 2.2 apart,
  ±0.35 alternate, at most 12 (nearest the player); none under 6 studs. Each print: ray down from 6 studs up;
  skipped without a hit, on a steep face (normal Y < 0.8), more than 1.5 studs off the player-pet line, or inside
  a `GardenWetRegion` / `GardenBlockedRegion` footprint. Redrawn after 3 studs (player) / 2 studs (pet). Swell
  every 1.6 s, 0.12 s apart (none under Reduced Motion). Fade 0.4 s nearest first. Ring at the pet (radius 2.2,
  companions tint, ripple 2.4 s) and `faceOwner` on the pet. Edge chip (36 px round, `tray` disc, paw in the
  companions tint, small pointer) only while the pet is off screen.
- **Second draw** (to "where a round starts"): skipped. The garden has no Pocket Deck spot (stations are
  Customize, Eggs, Journal, Park; the deck is the handheld). As the spec says.
- **Hello** (`FirstHelloBonus`): the Saved receipt with `hello` shows `showHello` instead of `showSaved`.
- **Toy pill** (`ToyPillCopy`): `notice.pill.firstToy` with `{pet}` (companion name), refreshed if the name
  changes; detail `firstToy` with the same vars. Off: today's keys and vars exactly.
- **Round-two pill** (`RoundTwoNudge`): `GrowthNudge.variant(stage, state, flags)`; shown under the toy pill's
  free-garden rule, 2.5 s after it becomes due, never with the toy pill (different stages), not a veteran,
  `stats.rounds == 0`. Hidden for the rest of the session once a field round starts (`FieldPhase` leaves
  `Welcome` with a pet owned). `done` stage without a toy (another egg first) reads as `bonus` / `plain`.
  Icon: there is no `deck` Kit icon; it uses the vector `ball`. Tap: `clientUI.playRoundForStars()`.
- **Calm deck** (`CalmFirstDeck`, gate exactly `phase=="Welcome"` and `owned==0`): `DeckCalm.plan(layout, rects)`
  hides Score, Chain, Daily quests / quest handle, Difficulty, Win pays, Controls and the THEN balls (label and
  `next[2..]`); grows the coach card (Goals) to the column foot and the egg (Eggs left) over the Difficulty and
  Win pays slots (Controls slot stays empty); phone `one` column: coach and egg share the column under the top
  row, egg under the words. Prompt text 20 px (PC) / 16 px (phone). Every change is saved and restored when the
  gate closes; the HUD's own sizing (`h.cardH`) is reset so the next `setHud` re-applies it. The board, its
  geometry and every hit area are untouched.
- **Step B: skipped.** At the spec sizes the board is already full glass height (not squeezed), so its condition
  never holds: 750x402 `narrow`, board 163x273 of 456x289 glass (33.8%); 568x320 `narrow`, 116x194 of 342x210
  (31.3%); 402x750 is portrait and takes the non-phone deck path. (Offline arithmetic of `resolveCompact` with
  the default 58 px top bar.)

## Studio fresh-save path

`ProgressStore` never touches DataStoreService in Studio (`if RunService:IsStudio() then nil`): Play Solo (and a
local Start Server) read and write an in-memory table that starts empty on every run. Every Studio session is therefore a
brand-new save and the real (veteran) save is never read or written. No new hook is needed; G2 adds none.
(Play Solo and Start Server / local players only; Team Test runs on a Roblox server and is not covered.)
A veteran check in Studio = finish a field round in the same session (or the offline specs' legacy-save cases).

## Architect review (2026-11-25): APPROVE WITH CHANGES, applied

- B1: the switch is captured inside `awardPet` after its five-key check (clone, add `hello`, freeze), and the due
  test reads the transaction's snapshot before `lastPetAward` is written.
- B2: the calm state lives on the HUD table (`h.calm`), applied and restored only on a change; a rebuilt HUD starts
  clean and is re-applied; nothing old is restored onto a new HUD.
- S1: the THEN label's tab hides with it; a chain counter in the Goals header hides too. S2: `setCompactHud` leaves the
  coach card's height alone while calm; the plan is applied before setWelcome reads the card's size. S3: rects come
  from the live cards. S4: the hidden quest card's Open Quests button rests with it during the Welcome round (it was
  never reachable then); Skip moves with the bigger card, as intended. S5: trail parts anchored, no collide / touch /
  query / shadow; the ground ray includes only the garden and Terrain and accepts only WorldMesh, Terrain or a
  walkable span; cleaned up on gui teardown. S6: `faceOwner` ignores the 12 stud range (still a 35 degree head turn)
  and clears on every end. S7: `trailDue` is raised in the say-hi line's `onShown`. S8: Economy logs PetCare with
  the balance before the hello, then FirstHello at the final balance. S9: the client shows the hello only for an
  integer 1..255. S10: the card's one line (the step prompt under the GOALS tab) takes the title size (20 / 16); the
  tab keeps its size. S11: Team Test is dropped from the fresh-save claim (not verified). S12: the pill's name is at
  the end of its line, so the rail's end truncation shortens the name, never the verb; the garden pills wait out the
  hello's 2.5 s (G1's first-Stars toast already showed with the say-hi line, before the hello).
- Portrait windows keep today's stacked deck (not the DeckScreen HUD), so the calm screen covers PC, tablet and
  landscape phones (including the one-column landscape layout).

## Verification

Offline, Luau CLI, scratch harness (G1's, untracked, plus `game.HttpService` in the mock):
`FirstHello` (pure + HatchProgress fixture: pays once, retry after a lost response, existing saves, malformed
field, flag/adapter off), `GrowthG2` (trail maths and rules, nudge variants, copy keys, calm plans),
regressions `PetAward`, `StatState`, `StarterBonus`, `GrowthCoach`, `TomorrowChips`, `ResultsNudge`.
Then `export_localization_csv.py`, `rojo build`. Studio pass by the coordinator.

Stale PlayerScripts copies (StatsPanel, StatsHost, CompanionsHub, PetFocusUI, DeckResultsInPlace, DeckResults,
RoomView): grep shows every `require` of them goes through `script` / `script.Parent` inside `Client`; nothing
requires them from StarterPlayerScripts' root. Deletion is the coordinator's, in Studio.

## Code review (2026-11-25): APPROVE WITH CHANGES (no blockers), notes applied

- The round-two pill needs `lastRunReward == nil` too (the public snapshot has no `lastAwardSeq`; an old save whose
  round counter started at 0 would be promised a bonus StarterBonus never pays).
- One-column calm plan: too short for the coach card's own height plus a 44 px egg = hide the panels, move nothing.
- `roundTwoStarted` latches on a ball dropped in a field round (`Drops > 0`), not on the deck being open.
- The THEN label is kept at build (`h.thenLabel`), not found by its text. Prints lie on the ground's normal
  (`PetTrail.frame`). The trail's RenderStepped link disconnects once the trail has drawn and gone.
- Near the balance cap the hello drops to 0 instead of refusing the pet.
- New Studio-only spec `scripts/CalmDeck.spec.lua` (real DeckScreen fixture at five sizes: panels hidden, board,
  Skip and egg hold, every HUD card's Position / Size / Visible restored on the first field round). Not run offline.
- Left as before (outside G2): an award committed through another retry path logs no Economy source.

Localization export: 7 new keys; `ui.onboarding.spend.ready` ("A toy for {pet}") is now keyed
`ui.notice.firstToy.title` (same text, the export keeps one row per text), so a sync is 7 adds and 1 delete.
