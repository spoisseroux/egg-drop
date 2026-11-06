# Egg Drop — nectar and egg loop

The active prototype now uses field runs and random egg hatches. The 2026-11-06 arcade pass adds family ranks, daily contracts, fair overflow pressure, and the unified menu described below. The physical
nursery and staged care proposal is deferred in `assets/concepts/nursery/` and
`OVERNIGHT-NURSERY-LOOP.md`; it is not included in the runtime Rojo tree.

## What to play

1. A new player starts on the welcome board and earns guaranteed Pip. Existing
   owned pets remain owned. Pip's reveal opens Sprout Hollow.
2. Open the deck for a 24-drop field run. Make a tier-III-or-higher merge in the
   illuminated left bank region, then the right region. Keep the pile low.
3. The next drop becomes ready after the falling jelly first contacts the floor,
   a bank or another jelly, or merges. A 1.8-second simulation-time fallback
   prevents a stuck ready state. The minimum 0.35-second request cadence remains.
4. After the final accepted drop, a four-second settlement window lets cascades
   finish. Completing the route without overflow earns six nectar, plus two for
   finishing below Y=7.5. Failed runs keep prior progress and can retry quickly. Their base payout is zero, but completed-budget failures can still finish daily skill contracts.
5. Choose **Hatch eggs** on the recap, or **Menu → Hatch eggs** from the handheld or lounge. Spend nectar on one of two egg recipes.
6. Watch the shell swell, crack, split and release its 3D pet with original synth
   cues. The server commits the outcome before the reveal. Closing/reopening or
   reconnecting cannot reroll or charge twice. **Try another run** acknowledges
   the result and returns to play.

Returning players start in the lounge. Leaving for the lounge pauses a current
board; returning resumes it. An unfinished field run restarts on reconnect.

## Rewards and odds

One welcome credit gives six nectar. Remaining legacy hatch charge converts
once at one nectar per charge. Thereafter, ordinary merges do not automatically
grant post-Pip pets or nectar. Completed Pocket Trials remain achievements and
cosmetic progression; they no longer bypass egg ownership.

| Recipe | Cost | Outcomes |
|---|---:|---|
| Mixed Meadow | 18 nectar | Pip 35%, Puddle 25%, Wick 20%, Orbit 10%, Bloom Pip 5%, Foxfire Wick 3%, Eclipse Orbit 2% |
| Sprout Focused | 24 nectar | Pip 80%, Bloom Pip 20% |

After seven consecutive non-rare hatches, the next guarantees a rare. Mixed
Meadow then shows Bloom Pip 50%, Foxfire Wick 30%, Eclipse Orbit 20%; focused
shows Bloom Pip 100%. A rare resets the counter. This does not guarantee a
missing common or a full collection. The UI displays the actual applicable pool.

Duplicate hatches add one permanent family mastery mark. Successful runs train the family selected before that run: one mark, or two total for a clean win. Ranks I/II/III require 3/10/25 marks; III also requires a clean win, chain 3, and score 500 in successful runs. Rank I displays an original family crest; II adds an accent outline; III adds bounded bursts. Rare variants count toward their base family. Existing three-duplicate sparkle entitlements are preserved separately. Reduced effects keeps the static badge and disables bursts.

An optional daily claim gives six nectar once per Hollow day (UTC−5). The
migration day already receives the welcome credit, so it cannot also claim that
day's daily bonus. There is **no daily play/drop limit** and no paid currency,
paid egg, or luck product in this prototype.

## Data and authority

`HatchProgress` uses a version-3 `hatching` subrecord inside the existing
`EggDropProgressV1` profile. It preserves legacy fields and snapshots ownership
into an explicit seven-bit inventory. Sparse ownership such as Pip + Orbit does
not grant Puddle or Wick. Equip, journal, counts and Wick's sticker use actual
inventory rather than treating inventory as a contiguous rank.

Nectar debits, random results, inventory/mastery updates and the rare counter are
atomic. The result persists until its specific ID is acknowledged. Session
leases use tokens and epochs; stale writers cannot renew or spend. Operations
have monotonic sequences, and run awards are protected against replay. Both
before-commit failures and ambiguous committed failures retry the same operation
and RNG candidate. Background retry runs every two seconds; lease maintenance
runs every twenty seconds. Failed loads cannot spend or overwrite a profile.

## Verification performed

- Rojo build and Studio Luau compilation of all runtime scripts.
- Thirteen transaction regression cases, including all advertised outcomes,
  rare protection, seven-pet migration, credits, sparse inventory, stale writers,
  daily boundaries, callback retries, pre-commit errors and ambiguous commits.
- Actual-solver held-out comparisons stored in
  `scripts/FieldRunBenchmark-results.json`, including rejected tuning candidates.
  The final setup uses empty field trays, seeded four-I/two-II bags, kick six,
  first-contact readiness, and bank boundaries at X=−3.8/+3.8.
- Thirty fresh seeds: deliberate heuristic 30/30 completions, uniform random
  8/30, minimum-cooldown random 3/30, center-only zero. Nectar rates were
  14.43, 3.85 and 1.38 per active minute respectively.
- Another thirty seeds modeling 2.5-second deliberate decisions yielded a
  1.885× nectar-rate advantage over fast random. These are automated models,
  not evidence that human players find the loop fun or comfortable.
- Real Studio drag-and-release runs earned nectar. At 22 nectar, an actual
  Meadow purchase deducted eighteen and hatched Orbit, leaving four and an
  inventory of Pip + Orbit. Reopening retained its result ID and balance.
  Journal and equip checks kept Puddle locked and correctly selected Orbit.
- All seven 3D hero models rendered; reduced-effects and cleanup checks passed.
  Safe-content fixtures 844×300, 667×285, 568×198 and 390×740 retained 44px
  footer controls and readable names. Seven-row odds lists scroll without
  dropping the footer. A silent rare-reveal visual preview was recorded.

## What still needs validation

Fresh physical-phone comfort, player understanding, voluntary replay, live
DataStore networking, and shared live multiplayer remain separate checks. The
benchmarks are provisional tuning evidence, not retention or revenue claims.
The seven-species pool and capped mastery finishes are finite prototype content.

Five-minute playtest: explain the two bank goals; finish or retry a field run;
read an egg's odds and cost; hatch; select the companion; leave/rejoin; verify
balance, ownership and any pending reveal; decide whether to play another run.

## Proposed family prestige — scope only, 2026-11-06

Spencer wants family mastery with the recognizable evolving emblems and social
status of prestige badges, expressed in Sprout Hollow's own plant/creature art.
This section is a proposal, not shipped behavior. Current mastery remains
three duplicate marks unlocking sparkles.

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

### Current evidence

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
