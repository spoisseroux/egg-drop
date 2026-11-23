# Overnight 2026-11-22 to 23 (Opus coordinating)

Spencer, 2026-11-22: "Add first session tracking, should we disable the ad campaign for now? And carry on with the world pass, and look and build out really effective onboarding by researching exemplary examples from Roblox on line? And making it fit our game? Work agenticslly overnight using timers to restart work if you run out of 5hr window etc and keep track of what is done for the large testing thing"

**Read this first after any restart.** A cron job re-prompts the session every hour or so; each wake reads this file, `git log --oneline -15`, the "Linked/agent" state, and continues the first unfinished step. Tick steps here as they land. Keep `V3-TEST-PASS.md` and `TODO.md` current.

## Rules tonight

- Beta publishes are fine (Pocket Pals Beta, Publish As). **Not mine:** live publishes, live server restarts, **ad campaign changes (asked Spencer: recommend pausing)**, spending, downloads, deletions, public text or images, saves changes that can't be undone, moving Spencer's parked grove-path edits.
- Each slice: plan, architect (for code), build (worktree builder), offline specs, code review, Studio check (I own Studio), Fable on captures for anything visual, beta publish, PLAY-BUILD + TODO + V3-TEST-PASS.
- Before each beta publish: Rojo stopped, ZZSpecs stripped, hash match, output log read.

## Steps

1. [x] **DONE beta (9) 6119afa.** **Island edges** (builder running) + **lime leaf map** (committed 83f25ae): merge, review, Studio check (try to climb/fall; crowns not olive), beta (9).
2. [x] **DONE: feature branch fab30bf (on beta 9); live hotfix cf9e7ee reviewed GO, waits for Spencer.** **First-session tracking:** FOUND ALREADY LIVE (9-step funnel, `research/FUNNEL-SNAPSHOT-2026-11-23.md`: 50% reach a second round, biggest drop at the garden walkthrough, D1 1%). Builder fixing step order + 3 custom events on `hotfix/first-session-funnel` (from 54dca26) and the feature branch. Was: Roblox onboarding funnel (`AnalyticsService:LogOnboardingFunnelStepEvent`) at each first-session step; plan, architect, build, review. Only useful on live: prepare a **live-ready hotfix** (from the live runtime commit, tracking only) and a beta copy; publishing live waits for Spencer's go.
3. [x] **DONE beta (10) e5edeb0.** **Onboarding:** A+B merged c995af7 (follow the Bear, need bubbles; review running), C+F merged 7193705 (Sleepy Nest server + v3 funnel; review running), Fable designing D (nest in the garden) + E (strip). Contract merged d85f0ae (Onboard gate, coach bits 15-26, onb3 strings, Nest constants); building in parallel: C+F nest server + v3 funnel (server builder), A+B follow-the-Bear + need bubbles (client builder); then D nest view, E strip, G. Research DONE (`research/ONBOARDING-RESEARCH-2026-11-23.md`: median D1 ~10%; top recs: Bear's Sleepy Nest that grows while you're away + welcome week, "See you tomorrow" strip, follow-the-Bear instead of the 5-card tour, Bear need bubbles, opt-in notification). Fable writing `ONBOARDING-V3-PLAN-2026-11-23.md`. Was: exemplary Roblox first sessions (top pet/garden/tycoon/sim games), what works in the first 60 s / 5 min, sources; Fable turns it into `ONBOARDING-V3-PLAN` fit to our game; architect; build in slices on the beta.
4. [x] **Waterfall: merged (layers 2f6d9d5, fixes d8cf7c9); code review GO, Fable GO with fixes applied; ships in beta (10) with onboarding.** Fable look + 5 textures uploaded (f508345); builder adding the client layers. Was: **World pass 3: waterfall client layers** (WORLD-PASS item 4 + architect check): Fable look, build, Studio, Fable capture review, beta.
5. [x] **Fruit DONE beta (11) 9272c61; garden hour DONE beta (12) 416ff26.** **Fruit (looks only)**, then **garden hour** (own gate; pets stay awake), as time allows.
6. [x] Morning report: what landed, beta number, test-pass rows, what's waiting on Spencer (ads pause, live tracking hotfix, grove-path parking before the re-export).

## Resume note (usage limit, 2026-11-23 ~00:45)

- Merged and specs green: A+B with review fixes (9576cb1), C+F with review fixes (e99e1d2), waterfall + fixes (db162be). Nest look + 7 textures uploaded (deb281e). **Builder running: D nest client + E strip** (branch worktree-agent-a4bc909a5b75c3631): merge it, code review, then Studio check.
- **Studio check of A+B was in progress:** a hand bubble showed over the Bear with no tour card (good). Tapping a moving billboard was hard; after a tap the bubble switched off and no ball bubble or paw prints had appeared 10 s later. Bear at (97,4,70), no errors in the log, PetFocus/screens visible in PlayerGui. Re-check that flow first: does tapping start the greeting, does the ball bubble and trail follow?
- Rojo is running and connected (stop it and strip ZZSpecs before any publish). Next beta (10) = waterfall + onboarding A-F once checked.

- **2026-11-23 ~02:05 (after the reset):** A+B flow checked in Studio: hand bubble, no tour card → greeting (by clicking the Bear) → ball bubble + "Hatch eggs" label (`artifacts/onboarding-2026-11-23/studio/`). Finding: the bubble jumps as the Bear shuttles between idle spots, hard to tap; sent to the A+B builder (bigger hit area, smoothed, tap the Bear counts, a key bind). Nest client builder resumed.

- **Beta (10) published** e5edeb0: onboarding A-F + waterfall. Next: fruit (looks only), then garden hour; morning report.

## Morning report (2026-11-23)

All steps done. Live untouched (v1054); everything below is on **Pocket Pals Beta**, reviewed (architect + code review + Fable on captures) and checked in Studio, listed in `V3-TEST-PASS.md` rows 8-16:
- **(9) 6119afa:** island edges (18 walls from an offline sweep; back to your last safe spot after a fall), textured lime crowns, funnel order fix.
- **(10) e5edeb0:** new first session (follow the Bear instead of the tour cards; need bubbles; the Bear's Sleepy Nest with a 7-egg welcome week ~200 Stars; See you tomorrow strip; v3 funnel) and the waterfall layers.
- **(11) 9272c61:** Dewdrop fruit (looks only, same drops for every player).
- **(12) 416ff26:** garden hour, off until `/hour on`.
- **Research:** `research/ONBOARDING-RESEARCH-2026-11-23.md`, `research/FUNNEL-SNAPSHOT-2026-11-23.md` (half of new players reach a second round; D1 1%; the gap is a reason to come back).

**Waiting on Spencer:** (1) publish the reviewed live tracking hotfix `hotfix/first-session-funnel` cf9e7ee? (2) welcome week ~200 Stars OK? (3) pause the ad campaign? (4) OK to park the grove-path edits on a wip branch before the island re-export? (5) the big test pass on the beta (V3-TEST-PASS.md).
**Not seen in Studio:** hatching the nest egg (8 h), the strip on a real results screen, phone layouts and frame times, blends in motion.
