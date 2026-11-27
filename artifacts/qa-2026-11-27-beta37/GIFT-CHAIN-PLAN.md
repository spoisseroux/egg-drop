# Gift chain: build plan (Opus, 2026-11-27, plan only)

Brief: `ONBOARDING-FUN-PASS.md` section 2 (switch `gifts`, replaces ONBOARDING-V3-BRIEF section 6 `invites`), approved by Spencer ("Yes, all three"). Base `f197c396`. Note: the brief is untracked in the main checkout and is not in this commit's tree.

## Goal

After the Bear, every step ends in a hatch. There are three free cranks (Paint, Toy, Snack), each once per save and each only when its trigger is true in the save on the server. They come one at a time, can be skipped, park as a chip, a ribbon and a Things row, and never expire. Every gift egg is cranked and comes out of the machine before its reveal (`Machine:deliver`).

## Server design

**Why not the existing buys.** Old builds reject a cost-0 `lookBuy` or `toyBuy` receipt: the cost must match the price (`Prices{12}`, `charged(20|8)`), and the pending results need such a receipt. A cost-0 receipt, a new pool or a new action would fail HueState or ToyState `valid()` on beta (38) and live, and the save would not load. So a gift writes only fields every build accepts and keeps its receipt in a new top-level field that old builds ignore and keep (the `welcomeGift` and `paintPots` precedent).

**Save field `gifts`** (hatching v11, no version bump). It is never part of `HatchProgress.valid`, and every read is tolerant (the NestState and DashState pattern). A malformed field reads as "not owed", so it fails closed and pays nothing.

```
gifts = { v=1,                                   -- owed marker
          paint = {op, item, day, rev, seq, seen?},
          toy   = {op, item, day, rev, seq, seen?},
          snack = {op, day},                     -- the Stat Egg receipt op that spent it
          fetch = true }                         -- the "learned Fetch" card was shown
```

- **Owed.** `gifts.v` is written inside `Hatching.grantStarter`, in the Bear's own transaction, on a brand-new save while `gifts` is on. That is how `WelcomeGift.mark` works today. Older and veteran saves are not owed (open question 1).
- **Derived, never banked** (the MedalEggs pattern). A gift is *ready* when it is owed, its trigger holds, its receipt is missing and the player is not a veteran. The ready state is published as `public.gifts = {ready=kind?, result=unseen receipt?}`, and the chip, ribbon and row read it. Nothing is written until the crank.
- **Triggers**, checked again inside UpdateAsync on the authoritative snapshot (`GiftEggs.due(state, kind, today, ctx)`):
  - **paint**: `nest.tucked` or `nest.n > 0`. With the nest off, the `needHi` fact is used instead.
  - **toy**: the paint receipt exists, and either `stats.rounds >= 3` (the Welcome round plus two) or `today > paint.day`. There is no saved session counter, so "session 2" is read as a later server day (open question 3). At least one toy must be left (`ToyCatalog.remaining`).
  - **snack**: the paint receipt exists and a Dash race has finished (`dash.ribbons` sum > 0).
  - **all**: no other reveal open (`Guard.other(state, nil)`), otherwise `RevealPending`, which the host waits on.
- **Exactly once.** The kind's receipt is the proof, written in the same UpdateAsync as the item. The candidate `{kind, op, unit|fixed, day}` is frozen, so a retry rolls the same pot. A replay, a rejoin or a second server (lease fence) meets the receipt and answers `AlreadyGranted` with the stored item, so an unseen reveal can still show. An ambiguous write is proved by `lastOperation` or the receipt's op.
- **Paint (pots only).** `GiftEggs.Pools.paint = HueCatalog.RollOrder`, 25% each, shown as its own odds. `Hue.roll(unit)`, or `Hue.fixedNext(hueInventory)` for restricted accounts. The apply sets `hueInventory[pot] += 1`, sets the `lookFound` bit and writes `gifts.paint`. It leaves `lookCharmMisses` alone (not a paid pull).
- **Toy.** Picked from `ToyCatalog.remaining` (`roll`, or `fixedNext` for restricted accounts). It sets `toyUnlocks[id] = true` and writes `gifts.toy`. The Bear playing with it is the existing `toyEquip` (`resultId` nil, cost 0).
- **Snack.** It rides the existing free Stat Egg. The gift becomes the first free source in `StatEggs.buy` (before the bank and medals), frozen as `c.gift` like `c.medals`. The receipt gets `source="gift"` and `gifts.snack` is written in the same write. Old builds never see the derived credit and accept the receipt (only op, kind and digest are checked).
- **Seen.** `giftSeen {kind}` is OR-only, so an unseen reveal replays after a rejoin. "Paint {pet}!" is the existing `hueUse` (main channel, `pendingResultId` nil), then `giftSeen`.
- **Host** `src/server/GiftEggHost.lua` copies the WelcomeGiftHost order: a saved receipt replays first, then the switch (NotReady), one loop per board, and N tries while the board is free. RevealPending, Busy, Pending, Retrying and RevisionChanged wait; NotDue, AllOwned and Veteran answer at once. It is rate-limited, with two new remotes, `GiftEgg` and `GiftResult`.

## Component changes

| File | Change |
|---|---|
| `src/shared/GiftEggs.lua` (new) | Pure: bounds, `owed/mark/facts/due/apply/sanitizeRead/public`, pools and odds |
| `src/server/GiftEggHost.lua` (new) | Request order (above), pure over deps |
| `src/server/HatchProgress.lua` | `grantStarter` marks `gifts.v`; `Hatching.giftEgg(handle, kind, ctx)`; `Hatching.giftSeen`; snapshot `public.gifts` |
| `src/server/StatEggState.lua` | Gift as the first free source (`c.gift`, `source="gift"`) |
| `src/server/init.server.lua` | Remotes, host wiring, `statEggBuy` passes `gift` |
| `src/shared/Onboard.lua` | Append `gifts` (Features, Attributes, Keys); events `GiftShown/GiftParked/GiftCranked/GiftDone/PeekShown` |
| `src/shared/EggCorner.lua` | `giftPaint` on the `hue` row, `giftToy` on the `toy` row (the one path) |
| `src/client/GiftChain.lua` (new) | Invite controller (below) |
| `src/client/GiftReveal.lua` (new) | Builds the gift's reveal and hands it to `machine:deliver`; card buttons "Paint {pet}!", "Play!", "Later" |
| `src/client/EggMachineClient.lua` | Ribbon on the dial while a gift is ready; tap-to-turn for gift cranks (section 3) |
| `src/client/ThingsTips.lua` | `blocked`: `if g.gift then return "gift" end` (holds BearNeeds' next bubble) |
| `src/client/ThingsPage.lua` | `ctx.gift`: a top "Gift waiting" row, Show me to the machine |
| `src/client/NestClient.lua` | The Peek on the tuck reply (wobble, crack light in the shell colour, "?" silhouette, 0.9 s) |
| `src/client/init.client.lua` | Wiring only |
| `src/shared/UICopy.lua` | Bubbles, card, row and odds copy, then the export and sync of localization |

**Kept minimal (another engineer is working there):** no edits to PetLead, NestLead, PetCuddle, OnboardV2, FirstHatchStory, AllSetCard or WelcomeDeck2. The lead to the machine calls the existing `GardenState:lead` / PetLead API with target `Eggs`. BearNeeds is held only through `ThingsTips.blocked`.

## Invite controller (`GiftChain`)

The pure rules are spec-checked and the controller follows the BearNeeds shape. Steps 1 to 6 come from the saved facts plus `public.gifts`. Step 2 is done on any paid egg receipt, step 4 on `stats.fetches > 0`, and step 6 on a ready nest egg.

- **States per step:** `locked → ready → invited (bubble) → nudged (one hop, "For you!") → parked (chip, ribbon, row) → cranking → reveal → done`.
- **Session memory:** the steps closed with "x" (parked, not asked again this session), invites shown this session (at most 2 after step 1), and the time of the last reveal (3 minutes clear).
- **Gates:** `ThingsTips.blocked` free, and no Needs bubble, menu or deck up. Step 1 comes 1.5 s after the tuck toast, and the gift controller blocks the Needs bubble until step 1 parks or finishes. When a player returns with a ready nest egg, step 6 goes first.
- **Veterans:** no leads. A ready gift shows only as the ribbon and the row.
- **Unprompted:** a step done unprompted closes its invite, and its gift stays parked.

## Edge cases

| Case | Behaviour |
|---|---|
| Ignored or "x" | Ignored: one nudge, then it parks. "x": parks at once, not asked again this session. Either way it waits forever (derived) |
| Returning mid-chain | Resumes from the saved receipts and facts. An unseen reveal replays first |
| Veteran or old save | Not owed (`gifts.v` missing): no chip, no lead (open question 1) |
| Switch off mid-chain | No new opens (NotReady). Invites, chip and ribbon hidden. Receipts and items kept; turning it on resumes |
| Already owns pots | Duplicates stack, shown as "Deeper {pot}!" |
| Owns every toy | Toy not ready (AllOwned). Step 3 is skipped and step 4 offers itself (open question 4) |
| Grant fails | The host retries on wait reasons. A final refusal calls `Machine:refuse()` (hello nudge) and a toast, and the chip stays |
| Two servers or replay | Lease fence plus the receipt: AlreadyGranted, same item |
| Restricted account | Fixed next pot or toy, same crank, same reveal |
| Old build loads | Ignores and keeps `gifts`. Sees a pot, a toy unlock and a statEgg receipt, all valid there |

## Not in this slice

The veteran "normal pool" Paint gift, the Sleepy Egg from the machine, the tier step-up tell and escalation (section 3, apart from tap-to-turn), "New!" and the found count, the 0.6 s colour-wipe art (v1 uses the existing paint update plus sparkles, with Fable's art to follow), the Outfit Egg, and the timing and words of section 1 (`fun1`).

## Spec plan

New: `GiftEggs.spec` (rules per kind, owed, veteran, triggers, fixed or roll), `GiftEggHost.spec` (order, wait reasons), `GiftEggSave.spec` (fake adapter: once, ambiguous retry, rejoin, second handle, RevealPending, AllOwned, seen), `GiftEggCrossVersion.spec` (beta 38 validators load and keep a gifted save), `GiftChain.spec` (one at a time, park, "x", gap, two a session, step 6 first, veterans, switch off). Updated: StatEggState (gift first, source), `EggDelivery.spec`, the ThingsPage row, AllSetGift and WelcomeGift unchanged. Run through the ZZSpecs copies.

## Studio checks

Fresh beta save, all switches on, run the whole chain: Peek, gift bubble, lead, tap-turn, pot out of the machine, reveal, "Paint Bear!", Toy after two rounds, Fetch card, Dash finish to the Snack crank. Then: rejoin mid-reveal, "x" then the Things row, and `gifts` off and on mid-chain. Captures for Fable at 600 x 360.

## Risks

- **Reveal adapter.** HueEggView and HatchFlow are built around `pendingHueResult` and `pendingToyResult`. GiftReveal must feed the reveal stages directly; this is the biggest client unknown, so I will prove it in Studio first.
- **No reveal guard.** A gift has no Guard field, so a paid buy could start during its reveal. The client keeps the machine busy, and the data cannot be harmed.
- **Step 1 ordering** depends on the `blocked` hook holding against the concurrent BearNeeds and NestLead work.
- **"Session 2" proxy.** It is read as a later server day.
- **Step 6 mismatch.** The brief says a second pet, but welcome-week nest eggs pay items or Stars.
