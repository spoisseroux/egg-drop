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


## 05:04 slice plan — make the field journal a useful lounge destination

Astra architecture GO: reuse the existing journal station/book. Add one explicit Family goals route from journal to Menu/Mastery, with zero automatic equip/family writes; Back returns to roaming. Owned cards show inherited family rank, including sparse rare-only inventory. Preserve centered Close for older callers. Journal compact layout must retain a full50px card plus44px footers in160px safe height. Replace unsupported family glyphs with a static vector crest shared by Menu and existing earned pet badges: family motif, rankIseal/IIframe/IIIbloom silhouette. Build only when family/rank changes, preserve unranked/no-badge and legacy/reduced-effects behavior. Improve the existing book/sign without adding stations or rewards.

Verify card names/statuses/scroll end/footers on160/198px landscape and portrait; allfamily/rank silhouettes at24px and grayscale; repeated HUD updates retain crest instances; local/remote pet recreation removes badges. Walk to the actual station with a companion nearby, activate E/X, open goals, choose a family through existing server action, close, greet away from station and resume the same board. Distinguish actual controls, UI/visual fixtures and unavailable live multiplayer/physical devices. Economy/storage/physics/nursery unchanged.


## 05:04 wake — field journal destination and family crests completed

The existing lounge journal now offers Family goals, opening Menu directly on Mastery. Opening that route sends no equip/family selection: actual HatchState bytes, selected family and companion stayed unchanged. Journal cards show owned variants' inherited family rank; locked cards still direct players to eggs. Compact160px safe content preserves a complete50px card in52px scroll viewport and separate44px footers. The existing book has a raised cover/pages, colored seals/ribbon and a small wayfinder; no station, room, currency or reward was added.

A static asset-free FamilyCrest replaces unsupported Menu glyphs and supplies existing earned companion badges: leaf, droplet/ripple, flame and orbit motifs, round rankIseal, double-frameII and a six-petalIIIbloom. Artwork stays the same instance through repeated unchanged HUD updates. Rank0 pets still receive no earned badge; rankII outlines and rankIII/legacy reduced-effects behavior retain their prior gates. A native32px color/24px grayscale sheet exposed overly smallIIIpetals, which were enlarged and visually rechecked.

Actual keyboard approach from spawn(-11,4) to about(7.23,-6.73) initially exposed E choosing the nearby following pet rather than Journal. The fix gives an enabled reachable station priority for E/X while leaving explicit pet clicks available. Station cache updates on added/removed/reparented descendants. Retest: E opened journal; Family goals opened Mastery; Back then Waway/E greeted Pip with hidden pill; a two-drop field returned from lounge/journal/goals with the same runsequence2, same drops2 and A enabled. Only Pip was owned in this walk, so another owned family's server switch was not claimed.

Astra reviewed plan and implementation, catching the new callback's local-helper scope and button padding/crest overlap before final verification. Native results:4 crest lifecycle,4 journal layout/ownership,5 prompt/cache,10 reward presentation,21 transaction and2 close-drain cases pass. All50 production sources compile, eight changed sources match checkout, Rojo builds, no Edit fixtures remain. Raw evidence: `scripts/JournalCrests-results.json`. Expected backend lost-write fixture warnings are separate from ordinary play; existing EditableImage/asset203785492 warnings persist. Physical phone/controller, live persistence/multiplayer and human enjoyment remain unverified.

Next coherent slice: lounge arrival/greeting camera framing and companion reveal polish, then final complete-loop/save recovery verification. Keep the nursery deferred and rewards/physics fixed.

Journal/crest checkpoint: implementation850beb9 pushed; private place96451847774961 shows **version28 Published**, verified in native Version History. Studio is Edit, egg-drop/localhost34873 remains connected and Edit fixtures are absent.


## 06:07 slice plan — greeting shots without camera cross-through

Astra architecture GO: validate a complete bounded greeting shot before changing pet/camera/audio/UI. Use actual model bounds plus greeting motion padding and both vertical/horizontal43-degree frustum constraints. Prefer avatar forward, choose an inward clear alternative near floor edges; reject missing floor, excessive table/tree-top ground height or blocked candidates. Stage pet and camera atomically, retain pet greeting animation and only a small FOV settle in normal effects. Keep one per-greeting roam snapshot separate from the existing room-entry camera snapshot. Movement/timeout restores its landmark direction, translated for avatar motion; stale camera/root/character/epoch never restores. Camera/reduced-effects changes cancel pending work.

Native fixtures will cover seven models/aspects, edge/corner/blocked positions, restore translation and stale lifetimes; actual Meet/E frames and movement/replay remain required. No new UI, profile/economy/physics, shader or nursery feature. Decorative nonquery foliage is not guaranteed clear by collision raycasts; inspect tree/journal views and report limits.

## 06:07 wake — clear companion greetings and reliable roam return completed

Greetings now validate a complete supported shot before changing camera, pet, UI or audio. Seven models fit landscape, portrait and very wide views with greeting-motion padding. The pet and lens stage together, avoiding a camera flight through its body/avatar; normal effects settle only FOV, reduced effects change it immediately. Movement or timeout restores the pre-greeting roam direction/FOV translated with the avatar. Camera, character, root and epoch guards prevent old callbacks restoring into a replacement lifetime. Room-entry and greeting snapshots remain separate.

Actual world screenshots exposed two blockers missed by a center ray: the nonquery JournalSign and the GardenBench hiding Pip's feet. Astra reviewed the targeted fix: seven center/top/side/low-foot probes test nearby visible oriented boxes independently of physics flags, plus physical rays. The final spawn and journal views show the whole pet; blocked directions select a clear alternative, and all-blocked fixtures safely leave roam usable. Planner samples after prefilter were1.529ms/116boxes/2candidates at spawn,0.881ms/162boxes/2 at the journal pose,2.861ms/165boxes/3 away from the station. These are individual desktop samples, not worst-case or phone timings.

Native verification:35 geometry/lifetime cases,72 projection checks across7 actual models,3 interaction-lifecycle cases,21 transaction and2 close-drain regressions passed. Actual Meet, direct pet click, E, movement cancellation and Deck/Lounge/Deck preserved runsequence2/drops2; the next A produced drop3 with nectar6 unchanged. Earlier same-slice checks observed169 Scriptable frames with0 clipped corners, automatic/movement view restoration, reduced-effects behavior, overlapping-greeting epoch protection, Studio respawn and async camera replacement. Some world positions were fixtures; those do not count as walking or live multiplayer/rejoin evidence.

All53 source containers compile (51 production plus2 legacy inert containers); both changed production sources match checkout, Rojo builds and Edit has no test fixtures. Evidence: `scripts/GreetingCamera-results.json`. Existing external asset/EditableImage warnings remain; deliberate backend lost-write fixture warnings are expected. No ordinary-play Luau error was observed in the final run. Some fallback directions expose bright existing sun bloom; lighting/art tuning remains. Seven probes are conservative authored-scene protection, not proof for all future scenery. Physical phone/controller, live DataStore/rejoin, shared live multiplayer and human replay appeal remain unverified.

Next slice: final integrated first-session/save-recovery audit, fix only concrete blockers, keep economy/physics/nursery scope fixed.

Greeting checkpoint: implementation6faf5a6 pushed. Private place96451847774961 shows **version33 Published**, verified in native Version History after tests. Studio is Edit, egg-drop/localhost34873 connected; fixture-free publish tree. No account/security/privacy/public-release setting changed.

## 07:03 slice plan — recover the authoritative companion and settings

Astra found a concrete reconnect race: hatch lease release could precede the outgoing profile write, and a Locked→Ready recovery retained provisional companion/sticker defaults. Share one Studio backing row between both writers, hydrate only from the successful acquire's outer snapshot, and gate progression/appearance mutations while the profile is provisional. Drain pending hatch/payout plus dirty profile before releasing the lease; back off failed writes and retain the lease on timeout. Retry failed initial profile reads without writing defaults, clear the temporary banner after recovery, and fail closed if hydration fails. Preserve schema/prices/physics/nursery scope.

Verify real profile/hatch functions against one isolated two-session store: delayed/in-flight outgoing write, stale pre-acquire read, Locked→Ready, exact rare/settings/reveal identity, once-only rewards/ack/reload, failed close/timeouts, initial read recovery and Studio shared backing. Run transaction/close regressions and actual first-Pip/field controls, console, compilation/source matching and Rojo before review/commit/private publish. Simulated rejoin remains distinct from live DataStore/private-client evidence.

## 07:03 wake — authoritative save recovery completed

Astra's audit found and reviewed fixes for a concrete rejoin race: dirty companion/settings could outlive lease release, and the recovered board retained a provisional Pip/sticker. Close now drains hatch operations and earned payout, then the outgoing dirty profile, then releases its lease. Busy saves are polled; failed profile writes back off0.5/1/2seconds, and a close timeout retains the lease. Studio now shares the same root between both writers, matching production's record topology. No schema or live DataStore/security setting changed.

Initial and recovered sessions hydrate from the successful acquire's outer snapshot. Locked/Unavailable/Temporary profiles cannot accumulate progression or persistent appearance changes. Failed initial reads retry before attempting acquisition; success restores the exact companion, family, theme, sticker, sound, motion and room mode and clears the banner. An unexpectedly unhydrated Ready candidate fails closed. Shutdown/removal cannot release twice. The loading banner now explains safe retries rather than suggesting unsaved practice.

Native results:8 shared-store recovery,2 actual-entry recovery,1 actual-default-Studio-store,21 transaction,2 close,7 onboarding,17 hatch-action,10 hatch-navigation,8 goal/receipt and10 reward-presentation cases passed (**86 total**). Shared-store fixtures cover stale reads, outgoing/in-flight settings changes, failed writes, exact pending reveal identity, ack/reload, reward replay and retained leases. Entry fixtures verify both Temporary/Locked gating, all recovered attributes and a usable first field drop. These fixtures use isolated stores/services or a synthetic Studio memory key; they are not live private-server rejoin evidence.

An actual adaptive mouse drag/release field walk completed24 drops and both goals, score630/chain4, base8+daily6 nectar (bank6→20), two Pip marks/all challenge flags. Actual Meadow purchase spent18 once, hatched Wick (inventoryPip+Wick, bank2), and Meet equipped Wick with the reveal acknowledged. A final source restart repeated welcome/Meet/Deck/A: Ready, Pip equipped, fieldbudget24/drop1 and save banner hidden. Client-only loading-banner fixture was visible and TextFits. All55 source containers compile (53 production plus2 legacy), seven changed sources match checkout, Rojo builds, Edit is fixture-free. Evidence: `scripts/SessionRecovery-results.json`.

Final ordinary-play console showed existing EditableImage/external asset203785492 warnings only; failure-injection fixture save/load warnings are separately expected. Physical phone/controller, live DataStore/rejoin, shared live multiplayer and human comprehension/replay remain unverified. Next pass should focus on bounded final compatibility/playtest handoff rather than new systems.

Recovery checkpoint: implementation4e51d6a pushed. Private place96451847774961 shows **version36 Published**, verified in native Version History after tests. Studio remains Edit with egg-drop/localhost34873 connected and no fixtures in the publish tree. Next wake: final compatibility/input audit and morning playtest handoff; at09:00 Eastern stop new changes and pause the existing automation after the rundown.

## 08:08 slice — compact controls and recipe selection

Astra identified two concrete compact blockers: at568×160 the tray was16×27 with a negative-width count, and the shop gave83px recipe buttons an18px viewport. The bounded plan preserved the existing game loop while using nearly all short-landscape height for the tray, moving existing readouts to the grips and preserving44px controls. The shop reserves44px header/footer actions and a complete44px recipe row. Actual mouse wheel then exposed that a100px step skipped the second stacked recipe; both recipes now share the first row. At350×279 the decorative egg hides to make room for full recipe names/costs.

The final tray is76×128 at568×160. Menu/Lounge sit above the44px arrows; A remains54px. A transparent full-tray input surface supports drag/release, and resize cancels a held gesture. Compact count/quest/drop-strip dimensions stay positive, and side-goal layouts hide the overlapping decorative egg summary. Fixed a separate real bug where every HUD refresh multiplied the drop-strip cells' previous scales: all24 cells now compute fresh geometry and retain their numeric-counter gap. Normal layouts restore their properties across the280px breakpoint. The pinned shop action names the exact selected recipe and cost/shortfall after scrolling/reopening; compact errors remain visible. Menu→Pets uses the existing navigation generation/actual handoff rather than an unguarded0.9s delay. Pocket Trial copy no longer says score achievements directly grant Bloom Pip.

Astra final GO. Native10 actual-deck layout cases and8 shop cases pass, plus17 hatch actions,7 onboarding,10 navigation,10 reward presentation,21 transaction and2 close-drain cases (**85 total**). Sizes include568×160/198,350×279,568×279/280,667×285,844×300/330/390 and390×740. The deck cases also passed with Pip owned and repeated HUD refreshes. Actual component-resized mouse checks: left/right releases each accepted one drop; side-count clicks and resize-during-drag did not spend a drop. Actual Menu→Eggs→Sprout showed two247×44 recipes and the exact18-nectar shortfall at bank6. Close/reopen retained Sprout; Earn resumed sequence2/drops2, next A produced3 without changing the bank. These are layout fixtures with native pointer input, not physical-phone or device-emulator evidence.

All55 source containers compile (53 production plus2 legacy), three changed sources match checkout, Rojo builds, Edit is fixture-free. Final evidence: `scripts/CompactControls-results.json`. Expected backend fault-injection warnings remain separate from existing image/asset warnings. Minimum44px scroll browsing, touch comfort, hardware controller, live rejoin/multiplayer and human replay remain unverified. Start no further systems; prepare the morning rundown and at09:00 stop new changes/pause the automation.

Compact checkpoint: implementationf021041 pushed; private place96451847774961 shows **version41 Published**, verified in native Version History. Studio is Edit, Rojo egg-drop/localhost34873 remains connected, and the publish tree is fixture-free. The self-contained `MORNING-RUNDOWN.md` records the shipped loop, all pets/rewards, evidence, private link and exact next playtest. No new implementation slice remains before the09:00 cutoff; the final wake should confirm the checkpoint and pause the existing automation.


## Post-playtest UI pass, 2026-11-06

The new user request after the overnight checkpoint adds persistent petting, original handheld boot, non-overlapping grips, clearer bank/queue/drops UI, receipt animation, illustrated eggs, compact daily cards and themed backgrounds. See `UI-EXPERIENCE-PASS.md` for Astra review fixes and exact Studio evidence; `UI-EDITING.md` explains durable position tweaks. Overnight automation remains paused. Economy and nursery scope are unchanged.
