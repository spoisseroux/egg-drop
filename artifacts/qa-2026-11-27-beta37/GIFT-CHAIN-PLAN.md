# Gift chain: build plan (Opus, 2026-11-27, plan only)

Brief: `ONBOARDING-FUN-PASS.md` section 2 (switch `gifts`, replaces ONBOARDING-V3-BRIEF section 6 `invites`), approved by Spencer ("Yes, all three"). Base `f197c396`. Note: the brief is untracked in the main checkout and is not in this commit's tree.

## Goal

After the Bear, every step ends in a hatch. There are three free cranks (Paint, Toy, Snack), each once per save and each only when its trigger is true in the save on the server. They come one at a time, can be skipped, park as a chip, a ribbon and a Things row, and never expire. Every gift egg is cranked and comes out of the machine before its reveal (`Machine:deliver`).

## Server design

**Why not the existing buys.** A `lookBuy` receipt must have `cost == price` and a price in `Prices{12}`. A `toyBuy` receipt must pass `charged(20|8)`. `pendingHueResult` and `pendingToyResult` need such a receipt. A cost-0 receipt, a new pool version or a new action in those rings would make HueState and ToyState `valid()` fail on beta (38) and on live, so those builds could not load the save. A gift therefore writes only fields every build already accepts, and keeps its own receipt in a new top-level field that old builds ignore and keep. That is the `welcomeGift` and `paintPots` precedent, proved by a cross-version spec.

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
- **Exactly once.** The kind's receipt is the proof. It is read and written in the same UpdateAsync as the item. The pending candidate `{kind, op, unit|fixed, day}` is frozen, so a retry rolls the same pot. A replayed request, a rejoin or a second server (lease fence, `fenced`) meets the existing receipt and answers `AlreadyGranted` with the stored item, so the client can still show an unseen reveal. An ambiguous write is proved by `lastOperation` or by the receipt's own op.
- **Paint (pots-only pool).** `GiftEggs.Pools.paint = HueCatalog.RollOrder`, 25% each, with its own odds line. A random account uses `Hue.roll(unit)`. A restricted account (`isRestricted`) uses `Hue.fixedNext(hueInventory)`. The apply sets `hueInventory[pot] += 1` and the `lookFound` bit and writes `gifts.paint`. It does not touch `lookCharmMisses`, because a gift is not a paid pull.
- **Toy.** The apply picks from `ToyCatalog.remaining`: `roll` for random accounts, `fixedNext` for restricted ones. It sets `toyUnlocks[id] = true` and writes `gifts.toy`. "The Bear plays with it" is the existing `toyEquip` with `resultId` nil, a cost-0 receipt every build accepts.
- **Snack.** This one rides the existing free Stat Egg. `StatEggs.buy`'s free path gets a third source, the gift. While it is ready it is spent first, before the bank and the medal eggs. It is frozen into the candidate as `c.gift` (as `c.medals` is), the receipt gets `source="gift"`, and `gifts.snack` is written in the same write. Old builds never see the credit, because it is derived. They also accept the receipt, because StatEggState checks only op, kind and digest.
- **Seen.** `giftSeen {kind}` sets `seen = true`, OR-only and idempotent, so an unseen reveal replays after a rejoin. "Paint {pet}!" is the existing `hueUse` on the main channel (`pendingResultId` nil) followed by `giftSeen`.
- **Host** `src/server/GiftEggHost.lua` copies the WelcomeGiftHost order:
  1. A saved receipt replays (Saved AlreadyGranted plus the item).
  2. The switch: NotReady.
  3. One loop per board.
  4. Up to N tries while the board is free. `RevealPending`, Busy, Pending, Retrying and RevisionChanged wait. NotDue, AllOwned and Veteran answer at once.
  It is rate-limited like PaintPotCatalog.allow. There are two new remotes, `GiftEgg` and `GiftResult`.

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
| Invite ignored | One nudge, then it parks. The gift waits forever, because it is derived |
| "x" | Parks at once, not asked again this session |
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

- **New specs:**
  - `GiftEggs.spec`: rules per kind, owed, veteran, triggers, fixed versus roll, tolerant reads.
  - `GiftEggHost.spec`: order and wait reasons.
  - `GiftEggSave.spec`: fake adapter; once only, ambiguous-write retry, rejoin, second handle, RevealPending, AllOwned, `giftSeen`.
  - `GiftEggCrossVersion.spec`: beta (38) validators load and keep a gifted save.
  - `GiftChain.spec`: one at a time, nudge then park, "x", the 3-minute gap, two per session, step 6 first, veteran ribbon only, switch off.
- **Updated specs:** `StatEggState` (gift spent first, digest, source), `EggDelivery.spec` (new actions routed), ThingsPage row, `AllSetGift` and `WelcomeGift` (unchanged behaviour).
- **How to run:** through the ZZSpecs copies (`scripts/run_dash_server_specs.py` list).

## Studio checks

1. Fresh beta save, all switches on: tuck, Peek, gift bubble, lead, three-tap crank, pot out of the machine, reveal, "Paint Bear!".
2. Rejoin during the reveal: it replays.
3. "x" then the Things row starts the gift.
4. Turn `gifts` off mid-chain, then on again.
5. Toy after two rounds, then the Bear plays with it.
6. The park "Throw it!" ends in the Fetch card.
7. A Dash finish, then the free Snack crank.
8. Captures for Fable at 600 x 360: the Peek, the gift crank and the paint.

## Risks

- **Reveal adapter.** HueEggView and HatchFlow are built around `pendingHueResult` and `pendingToyResult`, so GiftReveal must feed the reveal stages directly. That is the biggest client unknown, and I will prove it in Studio first.
- **No server-side reveal guard.** A gift has no Guard field, so a paid buy could start during a gift reveal. The client keeps the machine busy. The data cannot be harmed.
- **Step 1 ordering** against the concurrent BearNeeds and NestLead work depends on the `blocked` hook holding.
- **"Session 2"** read as a later day is a proxy.
- **Step 6 mismatch.** The brief says the nest egg gives a second pet, but the code's welcome-week nest eggs pay items or Stars.
