# Egg Drop overnight playtest and delivery plan

**Start from the reviewed arcade pass on `feat/egg-drop-arcade-polish`.** The six-hour target is one complete experience a new player can discover unaided: meet Pip, understand a field quest, earn nectar toward a specific egg, greet a hatchling and choose a reason to return. Start with an actual playthrough. Spend remaining time on the first point where that sequence breaks.

## Baseline for the next worker

Use `git status --short --branch` and record HEAD and the version served by the private place. Check the running version again after publishing. Preserve other workers' changes. Read the current implementations before using older proposals in `HATCH-LOOP.md`.

- Pip is guaranteed. The starter credit is six nectar. Meadow costs 18 and Sprout costs 24. A standard field run allows 24 drops. Make a tier III or higher on the highlighted left side, then the right. A completed quest earns six nectar, plus two for a clean finish. Full-length runs can also complete daily contracts.
- The selected family earns one mark for a win, two total for a clean win, and one from a duplicate in that family. Ranks I/II/III require 3/10/25 marks. Rank III also requires a clean win, a peak chain of three and a 500-point run, recorded on wins for that family. The three current daily contracts pay 4/3/3 nectar. The separate daily gift gives six.
- The approved standard tray is 11 studs wide with bank boundaries at ±2.6. Sustained overflow at 8.6 for 2.4 seconds can end a run after drop 12. Clean height is 7.5. The 30-seed native solver completed 29 deliberate runs and 16 fast-random runs. These figures describe the solver. Record human comprehension and completion separately.

## Six hours in priority order

### 0:00–0:40 · P0 · Establish the playable baseline

Build the checkout with `rojo build default.project.json -o <temporary-path>.rbxlx`. Sync Studio through the repo's Rojo port 34873. Run the actual `HatchProgress.spec.lua` and `CloseProgress.spec.lua` fixtures against the included modules. Record counts, version and first failure. Open play mode, enter the lounge, return to the field, open/close the menu, press A twice with a landing between presses. Check mouse and controller or touch where available.

**Pass:** both accepted presses advance Drops by exactly one. Only the display labeled FALLING/SETTLE may withhold a physical drop during normal play. A save problem shows the save message. A private-server check uses a designated test account by playing normally. Never reset someone's inventory to create a fixture. Start the rejoin test now so it can be completed in the last hour.

### 0:40–1:55 · P0 · Make the first five minutes understandable

The welcome guide teaches matching, then vanishes once Pip is owned. A new player must infer why their next run has different rules. At Pip's reveal explain the immediate goal using the actual balance and selected recipe, e.g. “6/18 nectar for Meadow. Complete field quests to hatch it.” At the first field target show two marked II jellies forming III in the lit left bank. Mirror it on the right after success. Reuse `FirstHatchGuide`, field attributes and HUD slots. Keep the tray and A button clear. Skip extra screens and a persistent tutorial flag. Use the first recap to connect the earned amount to the remaining cost, including the exact missed bank or overflow reason on failure.

**Pass:** on a fresh fixture, play without debug input. By five minutes the player has a tangible goal and can identify where to aim, how matching works, what a win earns and how much their egg still costs. Record times to Pip, first bank, first recap and first affordable egg, including misses. If the tester wrote the feature, label this a scripted walk-through. Repeat the steps in 568×198 landscape safe content and 390×740 portrait. Native device results and emulated results get separate labels.

### 1:55–2:45 · P1 · Let a hatch lead directly to the pet

Today the committed reveal primarily routes the player back to a run. Offer “Meet [name]” and “Play again” after a new hatch. Meet acknowledges the exact result ID, waits for server confirmation, equips the owned pet through the existing server action and opens its lounge greeting. After a duplicate, show the earned family mark and next rank requirement. Keep pending results recoverable if either button is interrupted. Check `EggHatchView`, `HatchCinematic`, and the mode/equip callbacks. Give common, rare and duplicate outcomes distinct short visual beats using existing models and cues.

**Pass:** exercise new, duplicate and guaranteed-rare fixtures. Close or reconnect mid-crack, reopen, finish once. The pet, debit, pity and mark counts match the first committed result. “Meet” leads to the displayed pet. “Play again” returns to a usable board. Reduced motion and muted audio preserve every result and both actions.

### 2:45–3:45 · P1 · Show what a run unlocked

The mastery menu can give a total without showing which condition is missing. Display only the next rank and its remaining marks or named challenges. At recap, show the specific daily contract completed and its nectar alongside quest earnings. Prioritize one next achievable goal. Use the existing authoritative mastery and contract records. Draw rank silhouettes once for use on the menu, recap and companion: seed/leaf, droplet/ripple, lantern/flame and moon/ring. Rank II adds a border. Rank III changes the outer silhouette. Use a short family burst for promotions and a static badge in reduced effects.

**Pass:** verify all four families at I/II/III at the smallest displayed size, including grayscale. Show a 25-mark family missing only the chain condition, then a fixture that earns it. A daily award appears once per eligible completion. Switching family mid-run affects the next run. Returning players can continue indefinitely after all daily contracts finish.

### 3:45–4:30 · P2 · Give the lounge a destination

Use two existing interactions. Direct greeting lets the player see their companion's name and crest. The field journal station lets them inspect discovered families, equip a pet, and choose the next family goal. Make the existing journal station identifiable from the spawn path with one sign and a recognizable prop. Keep the roaming HUD collapsed. Prefer improving the current stations over adding a new room, currency or reward request.

**Pass:** walk from spawn to the journal, equip a different pet, greet by tap/E/controller, then resume the same board. Test near an outer wall and scenery. The camera frames the whole pet and releases on movement. Verify prompt cleanup, a second player's companion, and quiet behavior during menus and reveals. If two-player testing is unavailable, record the gap.

### 4:30–6:00 · P0 · Verify the complete loop and hand it off

Rebuild, rerun the fixtures, and play through a full quest and a failure on the final checkout. Use menu Play/Daily/Mastery in the compact 160px and 198px safe heights. Check scrolling, 44px controls, controller selection and contrast over the lit bank. Retest first field A after greeting and after closing each overlay. If field physics changed, rerun the native benchmark on the previous seeds plus fresh held-out seeds and compare strategy-specific wins, overflows and nectar/minute.

On an authorized private test account, note the displayed starting balance, inventory, recipe and timestamp. Finish a quest, note the exact receipt, buy one affordable egg, leave during the reveal, rejoin and acknowledge it. Confirm one charge, the same hatch, owned/equipped pet, family marks and daily claim after a second rejoin. Use synthetic adapter fixtures for stale-writer, ambiguous-write, before-commit and shutdown failures. If the private client or account is unavailable, finish Studio checks and explicitly leave live persistence unverified.

Hand off the tested commit and place version, the verified sequence, fixture results, known gaps and next single improvement. Use the last 30 minutes for defects or verification. Defer lower-priority art before cutting this check. Publish only within existing authorization.

## Scope after these checks

Leave the nursery archived. A harder route needs its own review, a clearly selectable entry after a first win, independent balance evidence and an obvious way back to Standard. Put additional egg recipes, inventory expansion and earned rate items into a later design pass. Future monetization can explore directly chosen cosmetics. Keep paid random outcomes and paid luck outside the economy.

## Scheduled continuation

Hourly heartbeat `egg-drop-overnight-build-through-9-am` continues this chat until a final wake after 09:00 America/New_York on 2026-11-06 (schedule expires 09:15). At or after 09:00, start no new changes, checkpoint, write the morning rundown, and pause this automation. The desktop app and machine must remain running and awake.

Baseline checkpoint: arcade implementation commit `6b7e987` is pushed. Private place `96451847774961` published version **15** at 01:10 Eastern on November 6, verified in native Version History. Egg Drop Studio is in Edit mode and its Rojo panel is now explicitly connected to **egg-drop / localhost:34873**; the unrelated suica 34872 connection was disconnected. All runtime fixtures were removed before publishing.


## 02:07 wake — first-session onboarding completed

Astra reviewed the plan and implementation. FirstHatchGuide now shows a noninteractive II + II → III diagram with LEFT/RIGHT in the existing HUD slot until the first successful quest, then retires it. The starter reveal names the selected egg and actual nectar balance. Round recaps name the missed side or overflow, show SCORE / BEST, separate base and daily nectar, and show the selected egg's committed remaining cost. Pending/retrying rewards do not show a premature receipt. Short layouts hide unreadable stats and prioritize the cost line; the first-field coaching owns an opaque background so menu closure cannot overlap stale text.

Native Studio: 21 transaction and two close-drain cases passed; seven new presentation regressions in `scripts/Onboarding.spec.lua` passed, including daily-only failed quests, transient saves, selected recipe costs, 128/166/198/236px recap heights, coach overlay/first-win behavior, and immutable starter display payloads. A fresh developer-authored scripted keyboard/UI walk earned Pip at 4.38s, completed LEFT at 69.36s and RIGHT at 95.91s, reached a successful recap at 141.01s (base6 + daily6 =12 nectar, balance18, one Pip mark), and bought Meadow to hatch Wick at 178.43s, leaving zero nectar. The next run began at zero drops with A usable and coaching hidden. These times include operator/tool inspection and do not measure human comprehension or retention. Raw evidence is in `scripts/OnboardingWalkthrough-results.json`.

Next slice: implement the exact-ID hatch acknowledgment → Meet [pet] / Play again choice described at 1:55–2:45 above. Keep the economy and physics fixed. Live persistence and shared multiplayer remain unverified.

Onboarding checkpoint: implementation `655d2dd` is pushed; private **version 17** is Published, verified in native Version History. Studio remains Edit with egg-drop Rojo 34873 connected and no runtime fixtures in the publish tree.


## 03:03 wake — hatch to companion completed

A committed reveal now offers **Meet [pet]** and **Play again** with 44px actions. Meet acknowledges the exact result ID, waits for an advanced Ready snapshot, equips through the existing server action, then greets that pet. Play again acknowledges once and returns to a usable board. Close cancels delayed navigation; reopening resumes the same committed result. Duplicates show +1 family mark and next-rank progress; promotions retain their explicit announcement.

Astra reviewed the plan and implementation. Its findings were fixed: Busy/Pending pre-dispatch ack rejections retain a bounded same-ID/source-revision retry until Ready; Close/new results cancel queued retries; an already open purchased reveal cannot schedule a delayed reopen after Close. No purchase rerolls, economy/schema changes or local ownership/equip writes were added.

Native Studio: **21 transaction, 2 close-drain, 7 onboarding presentation, 17 hatch action and 10 post-ack navigation cases passed**. All47 production sources compile; the four changed production sources match the checkout after newline normalization. Rojo builds. Actual mouse checks confirmed Starter Meet Pip (revision2→3, nectar6 unchanged, equipped and greeted), Play again (zero drops, A usable, two presses produce two drops), and Close mid-crack → Menu/Hatch eggs → same result ID → one ack and usable board. Raw details: `scripts/HatchActions-results.json`. An initial fixture attempt used a stale Play snapshot; restarting Studio loaded final sources and all final cases passed.

Limits: 128px safe-height fixtures prove controls fit, not full cinematic readability; hero/caption remain cramped there. Camera can briefly pass close to a pet while entering greeting, then settles on the whole pet. Existing EditableImage fallback and external asset203785492 warnings remain; no final ordinary-play Luau errors were observed. Live DataStore/rejoin, physical phone feel, multiplayer and human enjoyment remain unverified. Fixtures do not grant real profiles.

Implementation `9446370` is pushed. Next coherent slice: show the next specific mastery requirement and itemized daily-contract recap receipts using authoritative progress. Keep physics/prices fixed.

Hatch destination checkpoint: private place96451847774961 now shows **version20 Published** in native Version History after the tested publish. Studio is Edit, Rojo egg-drop/localhost34873 remains connected, and no temporary test modules are present in the Edit publish tree. Implementation9446370 and evidence5038952 are pushed.


## 04:05 slice plan — explain rewards and the next family goal

Astra architecture GO: expose current RunSequence and gate every recap receipt/promotion on Saved + matching lastRunReward.sequence + completed field. Derive named contract awards from canonical definitions (including previous-day receipts), and use the run's locked family for next mastery progress. If Saved arrives before its display snapshot, show Loading receipt while keeping replay available. Extend FamilyMastery.describe with the actual next missing marks/challenges and completed-rank text. Keep existing describe keys for hatches. Daily skill contracts can reward full-length losses; mastery challenges explicitly require wins. Preserve prices, payouts, storage, pity, simulation and nursery deferral.

Verify all rank/flag combinations, rankII25marks missing only chain, stale equal-value receipt, late Saved snapshot, daily-only failure, allthree contracts, another family selected, completedrankIII, compact128–236px recaps and scroll reachability. Test native transactions/close regression, actual UI controls and console. Finish review/build/tests before commit/push/private publish.


## 04:05 wake — named round rewards and specific mastery goals completed

Recaps now use the matching Saved run receipt for every total, named daily-contract component, family mark and promotion. RunSequence fences equal-value receipts from previous rounds. Saved arriving before its display snapshot shows Loading receipt without blocking replay. The total and committed egg bank stay pinned; quest/daily components appear first, with a scrollable breakdown and the played family's next goal. Early ranks name remaining marks; rankII lists only missing WIN conditions. RankIII says mastered rather than an overfull25-mark progress fraction. The Menu preserves next-run versus current-family selection.

Astra plan/final implementation review passed after fixing compact title overlap, receipt draw order, guidance after overflow with both banks completed, and explicit D-pad footer navigation. Native results:21 transaction,2 close-drain,7 onboarding,17 hatch-action,8 goals/receipt-fence and10 reward-presentation cases passed. All48 production sources compile and six changed production sources match the checkout; Rojo builds. No temporary fixtures remain in Edit.

Two actual mouse/keyboard Studio rounds used24 drops and completed both sides. First: score670/chain5, base8 + contracts6 =14 nectar, balance6→20, two Pip marks. Actual Meadow purchase spent18 once, hatched rare Foxfire Wick, left2 nectar and Meet equipped that exact pet. Second on the final UI: score640/chain3, base6 + contracts6 =12, balance6→18, one Pip mark. Daily showed chain/score earned and the two-win goal1/2; Mastery showed Pip's exact next mark and the newly discovered Wick family. Replay advanced sequence2→3 while retaining receipt2, hid recap and accepted two A drops without changing nectar.

Actual receipt mouse wheel and Studio-injected D-pad keys reached top/bottom and selected both44px footer actions. MCP's injected D-pad reports Keyboard input, so this is emulated navigation, not hardware-controller evidence. A runtime layout fixture resized the actual component to568×160 safe content: dialog128, complete14px row/viewport, title ends exactly before receipt, both44px footers, every row TextFits, final row reaches viewport bottom. Physical phone/touch/controller comfort remains unverified. Raw details: `scripts/RunRewards-results.json`. Previous solver data was not rerun because physics/rewards are unchanged. Existing EditableImage/asset203785492 warnings persist without final-play Luau errors; Pip's symbol still renders as a square and is a future vector-crest polish item.

Next coherent slice: useful lounge destination/journal interaction and recognizable family crests, with no new room or currency. Keep nursery deferred; live save/rejoin and live multiplayer remain unverified.

Reward explanation checkpoint: implementation66630c5 is pushed. Private place96451847774961 shows **version25 Published** in native Version History. Studio is Edit with egg-drop/localhost34873 connected; Edit tree is fixture-free.
