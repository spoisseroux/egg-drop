# Egg Drop — Stars, companion eggs and Hue Eggs

The current branch has one earned **Stars** wallet, three rotating field variations, companion hatches and deterministic Hue Eggs for Zivvi and Ovelle. Stars are the existing stored `nectar` balance presented one-for-one; this pass creates no second currency and changes no historical reward amount. [Accepted design and transaction contract](PET-SOFTENING-AND-HUE.md) · [Hue verification evidence](artifacts/hue-eggs-2026-11-08/BUILD-EVIDENCE.md).

The last verified private publication is **v232**, runtime `355fad7`. The Stars/Hue slice described here passed final integration and is awaiting private publication; this document does not claim a newer private publication. [PLAY-BUILD.md](PLAY-BUILD.md) remains the publication handoff.

The physical nursery, training eggs, supplies, additional base pets and broader progression proposals remain deferred. Their concepts are not enabled offers in this runtime.

## What to play

1. A new player earns guaranteed **Zivvi** on the welcome board and receives its saved companion reveal. Zivvi opens Sprout Hollow. Returning ownership stays intact. Zivvi retains stored ID `pip`; Ovelle retains `puddle`.
2. Open the deck for a **24-drop round**, with unlimited rounds. Completed rounds rotate **Bank pair**, **Creek crossing** and **Lantern chain**. Bank asks for a tier III-or-higher merge on each side; Creek asks for a tier II center merge and a tier III-or-higher merge at the indicated bank; Lantern asks for two merges and a chain of two. Read the actual goal and highlighted region before dropping.
3. Mouse, touch, controller A and drag-release submit the same server-validated drop. The next drop becomes ready after the falling jelly first contacts the floor, bank or another jelly, or merges. A 1.8-second simulation fallback prevents a stuck ready state; the minimum request cadence remains 0.35 seconds.
4. After the final accepted drop, a four-second settlement window lets cascades finish. Both goals without overflow earn **6 Stars**, or **8** when the pile stays below the clean-bonus height of 7.5. A failed completed-budget round has zero base reward but can still earn its chain/score daily contracts.
5. **Menu → Hatch eggs** or the hatch tree opens the companion recipes and their actual odds. Selecting a recipe previews it; its explicit Hatch action spends Stars. A saved result remains the same across Close/reopen and reconnect. **Meet [pet]** acknowledges that result and equips the companion; **Play again** acknowledges and returns to play.
6. **Menu → Hatch eggs → Hue Eggs** opens the color offers; the pet journal's **Body & accents** opens learned choices. Choose an owned Zivvi or Ovelle, compare its current and resulting colors, rank and wallet, then explicitly **Feed** one named Hue Egg for 8 Stars. Color changes become confirmed only after saving. Free learned-body and accent choices stay available afterward.

Returning players start in the lounge. A lounge visit preserves an unfinished round; returning after a completed saved round starts a fresh field. An unfinished physical board restarts on reconnect. A pending companion reveal must be resolved before a new Hue purchase or color equip; Colors never acknowledges or replaces that reveal.

Zivvi uses a warm porcelain body and dusty-rose accents. Ovelle uses pale cool stone and sage, with short attached mittens. Both have seeded blinks, gentle breathing and an optional floating Dot. The Dot has its own saved per-pet visibility and follows the selected secondary color. Reduced motion keeps a settled expression and still Dot. These neutral base colors do not replace the separate palettes or earned identities of the rare companions.

## One wallet, rewards and companion odds

The welcome credit remains **6 Stars**. Remaining legacy hatch charge converts once at one Star per stored charge. Ordinary merges do not directly award Stars or later companions. Pocket Trials retain their achievements and cosmetic unlocks; they do not bypass inventory ownership.

| Companion recipe | Cost | Outcomes |
|---|---:|---|
| Mixed Meadow | 18 Stars | Zivvi 35%, Ovelle 25%, Wick 20%, Orbit 10%, Bloom Pip 5%, Foxfire Wick 3%, Eclipse Orbit 2% |
| Sprout Focused | 24 Stars | Zivvi 80%, Bloom Pip 20% |

After seven consecutive non-rare companion hatches, the next companion hatch is rare-only. Meadow then gives Bloom Pip 50%, Foxfire Wick 30%, Eclipse Orbit 20%; Focused gives Bloom Pip 100%. A rare resets the counter. This does not guarantee a missing common or a complete collection. Hue Eggs do not roll rarity, advance/reset this counter, consume its guarantee, or add companion inventory bits.

Duplicate companions add one family mastery mark. A successful round gives the selected family one mark, or two total for a clean win. Ranks I/II/III require 3/10/25 marks; III also requires a clean win, chain 3 and score 500 in successful rounds. Rare editions share their base family track. Existing three-duplicate sparkle entitlements remain separate. Reduced effects retain static earned badges and disable bursts.

The optional daily gift remains **6 Stars**. Three contracts auto-award once per Hollow day: win two rounds **+4**, chain three merges in a completed-budget round **+3**, and score 500 in a completed-budget round **+3**. The Hollow day changes at fixed **05:00 UTC**, independent of local time or daylight saving. The welcome/migration day cannot claim a second daily gift.

Eligible, server-validated petting keeps its existing saved +1-Star opportunities and five-award-per-Hollow-day limit. That limit caps incidental care rewards only. Idle focus, autonomous garden play and an AFK owner do not earn care awards. There is **no daily play/drop cap**, paid currency, paid egg, paid luck or attendance penalty in this prototype.

## Four deterministic Hue Eggs

Hue Eggs are earned color purchases for an exact owned Zivvi or Ovelle. Each costs **8 Stars** and advances one named direction by one rank, capped at three. There are no purchase odds.

| Egg | Direction | Swatch | Body tint at ranks 1 / 2 / 3 |
|---|---|---|---|
| Rose Hue Egg | Rose | `#D988A1` | 12% / 23% / 35% |
| Tide Hue Egg | Tide | `#77AAD3` | 12% / 23% / 35% |
| Citrus Hue Egg | Citrus | `#E7C764` | 12% / 23% / 35% |
| Iris Hue Egg | Iris | `#A994D4` | 12% / 23% / 35% |

A purchase increments only the selected pet's selected rank, chooses that body direction, and unlocks that hue as a secondary on that pet. The prior secondary stays selected. Other directions and other pets retain their ranks. Rank three shows **Max rank** and cannot spend again. Preview and confirmed rendering use the same linear-light blend between the authored body and direction swatch. Eyes, blush, mouth and ivory keep their authored palette.

**Original** restores the authored body for free while retaining all learned ranks. Any learned body direction can be selected again for free. Secondary selection is independent: **Default** restores the species' original secondary; learned accents recolor only feet, mitten details and the optional Dot. Hiding the Dot retains the selected secondary. Neither a new Hue purchase nor a pet switch erases an earlier unlock or independently confirmed Dot preference.

For example, a Zivvi with Tide 2 and Rose 0 can buy one Rose Hue Egg: it spends 8 Stars, reaches Rose 1, selects Rose body and unlocks Rose accents while retaining Tide 2 and its previous accent selection. The player may then choose Tide body and Rose accents, or Original body and Rose accents, without another purchase.

## Data and authority

`HatchProgress` keeps the **version-4** `hatching` subrecord in the existing `EggDropProgressV1` profile. Its optional sparse `hues` namespace is keyed by persistent `pip` / `puddle`, with four integer ranks and independent body/secondary selections. Absent Hue data means zero ranks, Original and Default; it grants no currency or unlock. Present Hue records and typed receipt data are strictly validated. No version bump is required for these additive fields.

The seven-bit companion inventory, all existing pet/result IDs, balances, prices, mastery, pity and pending companion receipts retain their meaning. Sparse ownership such as Zivvi + Orbit does not grant Ovelle or Wick. `nectar` remains the sole authoritative wallet field; Stars is its current presentation.

A Hue purchase validates ownership, supported pet, exact quoted rank, wallet revision, cap and balance. Debit, rank increment, derived unlock, selected body and receipt commit together through the existing leased command lane. A stale preview refreshes without charging. Free color equips validate learned choices on that exact pet and use the same compare-and-save revision fence. Client-supplied RGB values cannot grant colors.

Each client correlator binds its quoted revision (`revision:GUID`). The server creates a separate internal operation ID and retains full typed quote proof. Successful paid Hue receipts have a lifetime bound of **24** across two pets × four hues × three ranks; old exact paid retries return their original receipt even after later awards or equips, without spending or restoring an old selection. Conflicting action/pet/hue/rank/revision reuse rejects. Free equip retries retain the same captured quote; stale older equips cannot switch a newer selection back.

Only confirmed Hue choices and the latest saved Hue result are exposed to the client. The private paid receipt ledger is not replicated. Visitor appearance contains a compact confirmed body/rank/secondary token plus the independently saved Dot visibility. Pending, rejected or delayed operations retain the previous confirmed model palette. A Saved event and a later snapshot can arrive in either order; an older paid replay does not rewind the current wallet or latest result.

Companion result acknowledgment and pity remain separate from Hue results. Existing random companion debits, outcomes, inventory/mastery and rare-counter updates stay atomic. Session leases retain token/epoch fencing, monotonic operation sequences and replay-protected run/care awards. Failed or ambiguous writes retry the same captured operation, not a new price, rank or random candidate. Background retries run every two seconds and lease maintenance every twenty seconds. Failed loads cannot spend or overwrite a profile. Independent profile/Dot flushes preserve the leased Hue state and receipts.

## Current verification and limits

[Hue build evidence](artifacts/hue-eggs-2026-11-08/BUILD-EVIDENCE.md) records native server/client suites, actual UI actions, desktop and phone-emulator captures, and Medium/Largest checks. Coverage includes atomic rank/Stars changes, caps, malformed data, exact replay after later operations, ambiguous writes, host retry overlap, lost Saved events, independent accents/Original and confirmed palette projection. Actual field controls earned Stars before the color purchase flow; preview and repeated selection were also checked without spending.

The preceding soft-baby checkpoint is documented in [PLAY-BUILD.md](PLAY-BUILD.md) and the [pet-softening evidence](artifacts/pet-softening-2026-11-08/BUILD-EVIDENCE.md). The current Hue work has not acquired a new publication claim in this document. Native fixture counts and evidence labels belong to the current build evidence; historical counts below are not summed into new coverage.

Physical-phone comfort, a real-account save/rejoin over live DataStore networking, and longer human play remain separate checks. Two-client Hue propagation remains a release check until its controls and results are recorded in the current evidence. Automated solvers and controlled UI traces do not establish enjoyment, difficulty for new players, retention or revenue. Training, nursery progression, new companion pools and additional base forms remain future scope.

## Historical decisions and verification — 2026-11-06

The dated sections below preserve the earlier design and test record. Their old **nectar** label, Pip/Puddle visuals, two-bank-only route, 112×96 lounge and earlier schema descriptions are historical. The active Stars/Hue and rotating-field sections above take precedence. Proposed rates, rewards and unfinished features in this archive are not enabled merely by appearing here.

## Proposed family prestige — scope only, 2026-11-06

Spencer wants family mastery with the recognizable evolving emblems and social
status of prestige badges, expressed in Sprout Hollow's own plant/creature art.
This historical proposal is superseded by the shipped ranks I–III described
above and in the arcade section below. Legacy duplicate sparkles remain a
separate entitlement; this proposal is retained as design history.

### Progress and identity

Use one permanent track per family: Pip (seed/leaf crest), Puddle (droplet and
ripple crest), Wick (lantern/flame crest), Orbit (moon/ring crest). Base and rare
variants share the family track. Players select a family contract before a run;
contract wins earn a mark and a clean win earns one extra (maximum two per run).
Duplicate hatches also earn one mark. Ordinary play must advance prestige
without requiring lucky duplicates. Contract conditions must preserve the
left/right aiming decisions, validate on the server, and stay readable in one
sentence. Family contract rules and balance need a separate implementation pass.

Provisional cumulative thresholds: I=3, II=10, III=25, IV=50, V=100 marks.
These are tuning candidates, not approved time-to-completion targets. Rank III
also needs three distinct family challenges; rank V needs a final mastery trial.
Show each requirement and current progress before the player starts a run.
Keep pets and progress permanently; no reset or extra hatch luck on promotion.

| Rank | Emblem evolution | Cosmetic reward |
|---|---|---|
| I: Sprout | Small family crest | Deck sticker and journal seal |
| II: Grove | Crest with leaf border | Family accent finish and greeting pose |
| III: Bloom | Distinct blooming silhouette | Short family movement effect |
| IV: Guardian | Larger framed crest | Animated deck emblem and special idle |
| V: Hollow Legend | Unique sculpted family crest | Equipped title and brief arrival flourish |

Each promotion gets a short badge-forging animation and original synth motif.
Family effect vocabulary: drifting leaves; small landing ripples; warm motes;
a short orbiting arc. Effects are bounded bursts, player-toggleable, and reduce
to static finishes in reduced-effects mode. Display the equipped crest on the
handheld, next to the companion's name, and in an inspectable lounge profile.
Earned high-rank badges stay identifiable by silhouette at small mobile sizes;
color and particle quantity alone must not carry rank. Avoid continuous loud
loops, screen-obscuring auras, and copying Call of Duty artwork.

### Data migration and implementation order

Preserve existing duplicate marks as initial points, keep all existing cosmetics
unlocked, and retain a versioned progression record with challenge flags and
idempotent per-run grants. Replace the three-mark-only network mask with rank
information while supporting old data. Rank and cosmetic equip remain server
validated. Build I–III first, including journal progress, recap next-unlock,
profile display, and reduced-effects behavior; add IV–V when challenge variety
and completion times justify their longer goals. No nursery dependency.

### Nectar difficulty and playtest gate

Current pricing means 18 nectar takes three basic wins or three clean wins
(with six nectar left over); 24 takes four basic wins or three clean wins.
With the one-time six-nectar credit, a Meadow hatch needs two wins. Failed runs
currently pay zero, so human failure rate matters more than the solver's rate.
Measure completion rate, time to first paid hatch, repeated-failure exits, and
whether bank goals are understood. Proposed target: roughly 2–4 minutes to the
first paid hatch for a new player who understands the controls. Do not present
that as a measured rate. If failures feel wasted, evaluate a small one-bank
reward with replay protection before raising general payouts or adding caps.
Daily nectar stays a six-nectar bonus, not a play limit or missed-day penalty.

## Arcade pass decision, 2026-11-06

**GO for implementation with the following limits.** These proposed rules take precedence over the earlier prestige sketch for this pass.

### Play a run

- Give the A button one unobstructed hit target. Mouse, touch, controller A and drag-release each submit one drop. While falling or settling, show why A is waiting. Verify center and edge taps on the smallest landscape layout.
- Show “Make a 3 or higher on the LEFT” with two matching 2s pointing to a 3. Outline and label the actual target region. On success switch to RIGHT, then “Both done · keep the pile low.” Place a horizontal 24-light strip with “8/24” at its right. Advance only on server-accepted drops.
- Draw the overflow line before danger. Show a filling warning while the server counts sustained overflow and clear it immediately on recovery. Exempt newly falling pieces during entry. Test an isolated high bounce, a rescued pile and a sustained jam. Tune height/grace against seeded runs before changing rewards.
- Keep standard wins at six nectar, clean wins at eight and failures at zero. Show balance and next recipe together, e.g. “6/18 nectar · Meadow egg.” Recap shows amount earned, remaining cost, score versus personal best and peak chain. Start with Meadow selected. Recipe selection previews a purchase. The reveal identifies the new companion or duplicate family mark, then offers equip/visit or replay.

### Roam and collect

- Put Menu and Lounge on the left grip. Eggs, pets and style live inside Menu. Every lounge entry and greeting collapses it. Tap the companion or use its nearby controller/keyboard prompt to greet. Movement releases camera focus. Enlarge the walkable floor and move boundaries, scenery and collision together.
- Recompute planar follow targets every rendered frame. Throttle ground probes separately. Smooth position and shortest-angle heading using elapsed time. Face travel while moving and the player when greeting. Check a turn, stop and greeting at 20 and 60 FPS.

### Give repeat runs a purpose

- Snapshot the equipped family at run start. A win earns one mark, a clean win two total, and a duplicate hatch one. Ranks I/II/III at 3/10/25 marks earn a family seal, framed crest and blooming silhouette. Use original seed, ripple, flame and orbit motifs. Keep existing three-mark sparkles. Use a brief promotion burst and static reduced-effects art.
- Rotate one optional daily contract on the existing Hollow day, e.g. win with a two-merge chain, win with 150 points, or finish clean. Show today's exact goal before play. Its first completion adds one family mark. Keep the daily six-nectar claim independent. After the first standard win offer the harder left/right 3 then left/right 4 route for mastery practice. Keep standard runs selectable.
- Extend the existing fenced run award with server-observed results. Freeze route, family and contract day for retries. Commit all rewards and completion flags together. Migrate v2 marks, pending reveals and existing entitlements before enforcing new rank limits. Test duplicate retries, rollover and legacy profiles.
- Keep two recipes and their published odds. Scope future family eggs as catalog additions after inventory expansion; evaluate earned, capped, pre-hatch rate items only after defining exact odds, pity interaction and atomic consumption. Paid luck, ranks IV/V and the archived nursery stay outside this pass.

## Shipped arcade pass, 2026-11-06

This section supersedes scope-only proposals above. The nursery remains deferred.

- Unified Menu has pinned Play / Daily / Mastery tabs and a Back control. Handheld controls are Menu and Lounge. Lounge enters free roaming with only a small Menu/Deck pill; pet greetings hide it. A and drag input recover after transitions and overlays. Save-related input locks show SAVE WAIT plus a specific notice instead of FALLING.
- QUEST says II + II on LEFT, then RIGHT. Matching larger pairs also count. The target regions glow. The horizontal 24-light strip shows **remaining** drops, e.g. 23/24. Nectar is the main header value; a visible egg and selected recipe cost connect the currency to hatching. Choosing an egg only previews it; purchasing spends nectar. Another hatch always requires another purchase.
- Tray width is 11, target boundaries are ±2.6. Standard runs remain 24 drops. Field pressure arms after drop 12, uses a line at Y=8.6, and requires a continuous 2.4 seconds over it. Fresh airborne drops are exempt during entry; recovery below the line clears the timer. An early sustained spawn jam can end a run before drop 12. The welcome board retains its original grace/line. Clean bonus height is 7.5.
- Three daily contracts auto-credit once per Hollow day: finish two quests (+4 nectar), chain three merges in a completed-budget round (+3), score 500 in a completed-budget round (+3). A failed quest can earn those last two skill contracts after using all 24 drops. Base round reward remains 6/8/0. The daily gift remains six. The server locks family and day at run start, commits compound rewards atomically, and drains retained writes/earned payouts before releasing a session on leave/shutdown.
- Rank I is a family badge, II a restrained outline finish, III a bounded five-particle flourish. Bodies stay shaded SmoothPlastic; these are Roblox effects rather than custom shader programs. Promotion recaps identify the new family rank. Marks and family challenges persist; no reset or paid luck.
- The playable lounge floor is now 112×96 (previously 44×35), with paths, orchard, clearings, picnic spots, extended creek, and a second bridge. Pet follow position/heading updates every rendered frame; ground probes run at 10Hz. Click a pet or use E/ButtonX/touch prompt to greet. The greeting stages the pet and camera clear of the avatar.

### Historical evidence

- All runtime sources compile in Studio; Rojo builds. Native Studio passes 21 transaction regression cases, two closing-save cases, and field readiness/grace/rescue/spawn-jam checks.
- Native production-solver benchmark, seeds 64001–64030: deliberate 29/30 successful rounds, fast random 16/30, random 15/30, center 0/30. Deliberate base nectar rate is 1.86× fast random. Every strategy encountered warning pressure; deliberate had zero overflows, random and fast random one each, center 28/30. Raw data: `scripts/FieldPressureBenchmark-native.json`. Portable calibration/rejected candidates are separately labeled in `FieldPressureBenchmark-results.json`.
- Actual native clicks on simulated iPhone 17 Pro accepted welcome and field A drops; field counter changed 24/24 to 23/24. The native pet E greeting hid the UI and framed the whole pet without the avatar arm.
- Menu fixtures at 844×300, 667×285, 568×198, 568×160, and 390×740 retain a 44px Back control and enough scroll viewport to display a complete 44px action. Pinned tabs expose contracts/mastery without scrolling past the play page.
- An actual drag/release run finished its 24 drops without its quest, earned chain/score daily contracts, and atomically credited six nectar with zero mastery. This verifies failure/skill-contract integration rather than claiming a quest win.

Fresh physical-phone feel, live DataStore rejoin, shared live multiplayer, and human replay/retention remain unproven. The optional harder route, rank IV/V, additional egg pools, rate-changing items, and nursery are future scope. Current score and chains support contracts, mastery challenges, and personal bests; nectar alone buys eggs.

- Additional client-request integration run (separate from the UI input checks) completed both quest regions in 24 drops, credited eight base nectar and two Pip marks, recorded all three family challenge flags, and advanced the two-win daily contract to 1/2. Balance rose from 12 to 20.
- The same Studio session purchased Meadow through the actual hatch UI at 20 nectar: balance became two, inventory became Pip + Puddle, and a persistent Puddle reveal appeared. Rank I/II/III visual fixtures verified badge/outline/burst layering and reduced-effects cleanup without granting profile progress.


## First-session coaching, 2026-11-06 overnight

After Pip, the first field run uses a compact matching diagram labeled LEFT, then RIGHT. It disappears after the first successful quest and does not block controls. Starter Pip's reveal shows the selected egg recipe and real balance. The recap identifies the missed side or overflow, separates quest/daily nectar, shows score against best, and calculates the next egg's cost from the committed balance. A save delay remains a pending reward until a Saved receipt arrives. Compact recaps prioritize readable progress over score tiles.

Seven native Studio presentation regression cases passed. A developer-authored keyboard/UI walkthrough reached its first paid Meadow hatch (Wick) in 178.43 seconds, including operator inspection time; this is not a human usability study. It completed both goals, earned base6 + daily6 and one Pip mark, paid18 once, and returned to a usable board with the first-field coaching retired. See `scripts/OnboardingWalkthrough-results.json` for details.


## Hatch destination, 2026-11-06 overnight

After the committed cinematic, choose Meet [pet] or Play again. Both acknowledge that exact result once; Meet waits for server-confirmed equip before greeting, while Play returns to the board. Close preserves the result for later and cancels delayed routing. Duplicates show +1 family mark and next-rank progress, preserving promotion announcements. Pre-dispatch save/throttle locks retry only the captured acknowledgment, at most three automatic retries; purchases are never resent by this UI.

Native Studio passed17 new hatch-action and10 navigation race cases, plus existing21 transaction/2 close/7 onboarding cases. Actual mouse checks covered Meet Pip, replay with A0→2 accepted drops, and mid-crack Close/reopen with the same hatch ID and unchanged6 nectar. Evidence/limits: `scripts/HatchActions-results.json`. Live persistence/phone/multiplayer remain unverified.


## Understand the earned reward, 2026-11-06 overnight

The recap now pins nectar earned and egg-bank progress, then itemizes quest nectar, each completed daily contract, family marks and the played family's next mastery goal. Only a Saved receipt matching the current run sequence can announce a reward or promotion. A delayed display snapshot cannot lock replay. Menu mastery names the actual missing win condition at rankII and marks rankIII mastered. D-pad up/down or PageUp/PageDown scroll the receipt; D-pad left/right selects Try again/Hatch eggs. Mouse wheel scrolls normally.

Native fixtures passed8 goal/receipt and10 presentation cases plus transaction/close/onboarding/hatch regressions. Actual UI completed clean8+daily6 and ordinary6+daily6 rounds; the former bought Meadow, hatched Foxfire Wick and equipped it through Meet. Emulated D-pad/wheel and actual compact-component layout passed; physical phone/controller/touch, live persistence, multiplayer and human retention remain unproven. Evidence: `scripts/RunRewards-results.json`.


## Journal destination and family identity, 2026-11-06 overnight

Walk to the raised Field journal, press E/X or its prompt, equip an owned companion or open Family goals to choose mastery through the existing menu. The goals route itself changes no selection, inventory or currency. Station shortcuts take priority over a nearby companion; walk away or click the pet directly to greet. Returning to the deck preserves the active run.

Menu and earned companion badges share static family motifs and distinct rankI/II/IIIseal/frame/bloom shapes. Rank0pets have no earned badge. Compact journal layouts and sparse rare-family inheritance passed native fixtures, as did an actual walk/journal/goals/greet/resume sequence. Evidence and remaining device/live-test limits: `scripts/JournalCrests-results.json`.

## Companion greeting shots, 2026-11-06 overnight

Meet or interact stages a framed companion shot after checking supported ground and visibility. The whole pet fits landscape/portrait; low foot probes avoid the lounge bench and visual box checks include nonquery signs. Movement or timeout restores the player's previous roam view and FOV. Missing/blocked scenery leaves roaming available. Reduced effects skip the FOV settle. Stale character/camera/greeting callbacks cannot restore an old view.

Native35 geometry/lifetime and3 interaction cases passed alongside transaction/close regressions. Actual Meet, journal-area pet click, E/movement and same-run board return passed; some position/lifetime setups were Studio fixtures. Evidence: `scripts/GreetingCamera-results.json`. Live persistence, shared multiplayer, physical phone and enjoyment remain unproven.

## Save and rejoin recovery, 2026-11-06 overnight

Outgoing profile settings/companion writes finish before the hatch lease is released. A reconnect waiting on that lease restores its companion and settings from the successful acquire snapshot. Temporary load failures pause progression and retry without saving defaults; recovery clears the loading banner and restores room mode. Studio's two writers now share one memory row, matching the live storage topology. A close timeout keeps its lease fenced until expiry.

Native11 new recovery/default-store fixtures and existing transaction/close/UI regressions passed (86 total in this slice); actual field→nectar→Meadow→Wick→Meet passed. These establish simulated recovery and Studio controls, not a live Roblox account reconnect. Evidence: `scripts/SessionRecovery-results.json`.

## Compact-screen controls, 2026-11-06 overnight

Short landscape allocates the full central height to the board and puts nectar/quest/drop count on the grips. Both egg recipes fit in one44px row, with the selected recipe and exact price/shortfall pinned in the action. Resize cancels an unfinished drag; repeated HUD updates retain all24 drop-strip cells. Compact errors remain visible, and rotating/reopening preserves the selected egg.

Native10 deck/8 shop cases and related UI/transaction/close regressions passed (85 total), including350px-wide and160px-high safe content. Actual resized-component mouse checks verified both aim directions, A, no stale release, Sprout selection/reopen and same-run return. Physical phone/touch/controller comfort remains a separate playtest. Evidence: `scripts/CompactControls-results.json`.


## Post-playtest UI pass, 2026-11-06

The new user request after the overnight checkpoint adds persistent petting, original handheld boot, non-overlapping grips, clearer bank/queue/drops UI, receipt animation, illustrated eggs, compact daily cards and themed backgrounds. See `UI-EXPERIENCE-PASS.md` for Astra review fixes and exact Studio evidence; `UI-EDITING.md` explains durable position tweaks. Overnight automation remains paused. Economy and nursery scope are unchanged.
