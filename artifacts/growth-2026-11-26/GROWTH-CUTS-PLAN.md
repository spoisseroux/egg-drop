# Growth cuts: build plan (Opus, 2026-11-25)

Branch `growth/v1056` (live `54dca26` + funnel fix `cf9e7ee8` + Hatch another `efb72c9b`). Spec:
`artifacts/growth-2026-11-26/GROWTH-CUTS-LOOK.md` (Fable) in the main checkout. Four cuts; three switches in
`FeatureFlags` (`TomorrowStrip`, `GardenTourCut`, `StarterBonus`), all `true`; off = today's behaviour exactly.

## Files

| File | Change |
|---|---|
| `src/shared/FeatureFlags.lua` | three switches |
| `src/shared/StarterBonus.lua` (new, pure) | rewards `{12,4,4}`, cap 20, `valid` / `sanitize` / `paid` / `apply` for the optional save field |
| `src/server/HatchProgress.lua` | `valid()` chain + load-time sanitize; `award` pays the bonus inside its transaction; `lastRunReward.starter`; `defaultAdapter().starterBonus=true` |
| `src/server/init.server.lua` | Economy: round part as `RoundReward:<heat>`, bonus as its own source (`Onboarding`, sku `StarterBonus`) |
| `src/client/TomorrowChips.lua` (new, pure) | strip model (today/tomorrow chips), PC fit (drop Stat Eggs first), garden rail text |
| `src/client/ResultsNudge.lua` (new, pure) | which egg (Toy if no toy owned, else Customization; fallbacks), the nudge line, the starter payout row |
| `src/client/DeckResultsInPlace.lua` | 5 payout rows (gold starter row first); PC bottom strip (panes give up 42 px when the switch is on); phone block in place of `self.today`; nudge in `self.saved`; Hatch eggs primary + default focus while ready in a bonus round |
| `src/client/DeckKit.lua` | `Kit.setVariant(button, variant)` (repaint only) |
| `src/client/NotificationRail.lua` | optional `kitIcon` on an info line (a `Kit.icon` in the disc, for `paw`) |
| `src/client/CoachCards.lua` | `GardenTourCut`: say-hi line instead of the tour; tomorrow rail line once a session (lowest priority) |
| `src/client/NoticeCards.lua` | notice `tomorrow` (go: quests) |
| `src/client/init.client.lua` | results data (`starter` row first, `tomorrow` model, nudge, `eggId`, `hatchPrimary`); `recap:on("quests")`; egg preselect on the next Hatch eggs open; coach ctx gets `focusing`; tell coach a results screen was seen |
| `src/shared/UICopy.lua` | section `tomorrow`, `notice.tomorrow`, `coach.sayHi.*`, `results.starter.row`, `results.next.*`; 4 ball-name edits |
| `scripts/*.spec.lua` | `StarterBonus`, `TomorrowChips`, `ResultsNudge`, `GrowthCoach` (pure + HatchProgress fixture) |

## Save field: `starterRounds`

- Optional on hatching v11, no version bump (like `coachMask`). Valid: `nil` or integer `0..255` (frozen stored
  bound; the game reads `min(v, 3)`). Malformed: dropped at load (`acquire`, beside `Coach.sanitize`), never a failed load.
- Meaning: Welcome-bonus rounds already paid. **Missing** reads 0 only when `stats.rounds == 0` (nothing finished yet),
  else 3 (existing players get nothing). Read **before** `Lifetime.recordRun` in the same transaction.
- Written only inside `Hatching.award`'s transaction (`transact`, fenced lease, `lastAwardSeq`, signature
  `award:<seq>:...`): a retried or ambiguous write resumes the same pending op; a committed one is proven by
  `lastOperation`; `runSequence <= lastAwardSeq` returns `AlreadyAwarded`. Two servers: the lease fence (`fenced`)
  allows one writer; the counter lives in the save, so a rejoin or another server reads 1..3 and pays the next
  step or nothing. Total per save can never exceed 20 (`apply` clamps against the cap).
- Old servers (v1055) ignore and preserve the field (top-level unknown keys are kept; `validBase` does not reject them).
- `BalanceLimit` check includes the bonus. `total` includes it; `bonus` keeps its old meaning
  (`total - roundStars - starter`), so the client's 2x / Supporter rows are unchanged. Flat: not multiplied, no +1.
- **Enable gate**: `FeatureFlags.StarterBonus == true` and `handle.adapter.starterBonus == true`, captured in the
  candidate at call time. Only the live adapter (`defaultAdapter`) sets it, so the ~20 existing specs that build
  their own adapters on fresh saves keep their exact payouts; `StarterBonus.spec` opts in.
- `todayEarned` (session memory) includes the bonus (it reads `total`).
- Funnel: unaffected. `profile.newSave` (funnel gate) is a different store and is not used for eligibility.
- DataStore failure: the award loop retries (`RewardRetry`); the bonus rides the same pending candidate, so it is paid
  exactly when the round is. `Temporary` (load-failed) handles never award.

## Client

- **Strip** (`TomorrowStrip`): `TomorrowChips.model(nurseryState, {phone})` -> `nil` (no snapshot) or
  `{before={today chips}, after={tomorrow chips}}`. Hidden while `data.pending`. PC: a 36 px row at the LCD bottom
  across the three panes, built at `View.new` (panes give up 42 px whenever the switch is on; nothing is drawn in it
  while pending or with no snapshot); fades up 8 px over 0.25 s, 1 s after the count-up ends; Reduced Motion: fade
  only. Today chips get a 44 px transparent hit button on the root (not in the CanvasGroup) that opens Quests.
  Phone: eyebrow + one line each (today lines first, each with a full-width 44 px hit), no Stat Egg chip, stats move
  under the block.
- **Rail** (`TomorrowStrip`): CoachCards, last branch, once a session: free settled garden (as the arrival rule),
  onboarding stage not `garden`, after a results screen was seen or 4 min after the coach started; 7 s; tap opens notice
  `tomorrow` (button: Open Quests).
- **Tour cut** (`GardenTourCut`): when the old tour would start (minus the stand-still wait) and not a replay: one rail
  line `coach.sayHi.<input>`, `paw`, 12 s; `gardenIntro` saved in its `onShown`; ends on focus (say hi), a menu/deck,
  12 s or a tap. "Show tips again" (`replayGarden`) still opens the four cards. First-Stars toast unchanged.
- **Nudge** (`StarterBonus`): `ResultsNudge.egg(state)`, then `ResultsNudge.line(egg, balance)` in `self.saved` once
  saved (flag off: "Tucked into your wallet" as today). `hatchPrimary` when ready **and** this round paid a bonus:
  Hatch eggs gold, Replay secondary, first non-pending paint focuses Hatch. Hatch eggs then preselects that egg
  (`nurseryView:selectRecipe`) on the next open within 60 s.
- **Copy** (no switch): the four `UICopy` edits. Store description untouched.

## Edge cases

- Pending results: no strip, nudge reads `Saving…`, no hatch-primary until saved.
- Restricted (paid-random) players: the Customization Egg is still buyable (fixed next item), so the rule holds;
  `lookAvailable == false` or `LookEggCatalog.EnablePurchases ~= true` falls back to the Toy Egg (if any toy left),
  else no line.
- Portrait / non-1.2:1 windows use the legacy compact card (Total only, no come-back strip): the bonus is in the
  Total; no strip there.
- Localization: 20 new keys (Fable's 19 + `notice.tomorrow.next`, which reuses the stamp promise text because
  `NoticeCards` reads `notice.<id>.*`), 4 changed. Longest checked with `PseudoLocale` in Studio by the coordinator.

## Verification

Specs run in the Luau CLI through the feature branch's offline harness (copied to scratch, untracked):
`StarterBonus` (incl. HatchProgress fixture: 12/4/4, cap, retry after a lost response, rejoin, existing player,
malformed field, flag off), `TomorrowChips`, `ResultsNudge`, `GrowthCoach` (CoachCards pure rules). Then
`export_localization_csv.py`, `rojo build`. Studio pass by the coordinator.

## Architect review (2026-11-25): APPROVE WITH CHANGES, applied

- B1: the client's `doubled = total - roundStars - bonus` would turn the bonus into a fake "2x Stars" row: it now also
  subtracts `reward.starter`.
- B2: a pre-v11 save reads `stats.rounds == 0` after its upgrade. A missing field is eligible only when
  `stats.rounds == 0` **and** `lastAwardSeq == 0` (only `award` raises it, so it covers every round ever saved).
- S2: `starterRounds` is written only when a bonus is paid. S3: the bonus Economy source is logged only for this
  round's saved receipt. S4/S5: the egg preselect is one-shot and re-checks the egg is on sale; the Hatch eggs default
  focus is taken once, only while focus is still the default. S6: the strip's hit buttons are inactive while empty;
  only the in-place (lateral) view reserves the row. S1: the coordinator checks a real Studio join pays +12.
- S7 (live today, outside this change): `lastRunReward.bonus = total - roundStars` folds the 2x share into
  "Supporter" and hides the 2x row. Logged in TODO, not fixed here.

## Code review (2026-11-25): APPROVE, notes applied

- A say-hi line cancelled before the rail showed it no longer ends the garden step for the session; saying hi
  before it shows saves `gardenIntro` (so the Tomorrow line is not blocked).
- The egg preselect expires after 5 s (the deck-to-garden walk opens Hatch eggs within 4 s or not at all).
- A phone TOMORROW block is cleared if the snapshot goes away; the two-line nudge sits 3 px lower.
- Left for the Studio pass: gold `stars` text on the raised panes (same role as the existing Total line), the
  bonus-round default focus on Hatch eggs (as specified), the ball copy is the one change with every switch off (as planned).
