# Overnight 2026-11-22 to 23 (Opus coordinating)

Spencer, 2026-11-22: "Add first session tracking, should we disable the ad campaign for now? And carry on with the world pass, and look and build out really effective onboarding by researching exemplary examples from Roblox on line? And making it fit our game? Work agenticslly overnight using timers to restart work if you run out of 5hr window etc and keep track of what is done for the large testing thing"

**Read this first after any restart.** A cron job re-prompts the session every hour or so; each wake reads this file, `git log --oneline -15`, the "Linked/agent" state, and continues the first unfinished step. Tick steps here as they land. Keep `V3-TEST-PASS.md` and `TODO.md` current.

## Rules tonight

- Beta publishes are fine (Pocket Pals Beta, Publish As). **Not mine:** live publishes, live server restarts, **ad campaign changes (asked Spencer: recommend pausing)**, spending, downloads, deletions, public text or images, saves changes that can't be undone, moving Spencer's parked grove-path edits.
- Each slice: plan, architect (for code), build (worktree builder), offline specs, code review, Studio check (I own Studio), Fable on captures for anything visual, beta publish, PLAY-BUILD + TODO + V3-TEST-PASS.
- Before each beta publish: Rojo stopped, ZZSpecs stripped, hash match, output log read.

## Steps

1. [ ] **Island edges** (builder running) + **lime leaf map** (committed 83f25ae): merge, review, Studio check (try to climb/fall; crowns not olive), beta (9).
2. [ ] **First-session tracking:** Roblox onboarding funnel (`AnalyticsService:LogOnboardingFunnelStepEvent`) at each first-session step; plan, architect, build, review. Only useful on live: prepare a **live-ready hotfix** (from the live runtime commit, tracking only) and a beta copy; publishing live waits for Spencer's go.
3. [ ] **Onboarding research:** exemplary Roblox first sessions (top pet/garden/tycoon/sim games), what works in the first 60 s / 5 min, sources; Fable turns it into `ONBOARDING-V3-PLAN` fit to our game; architect; build in slices on the beta.
4. [ ] **World pass 3: waterfall client layers** (WORLD-PASS item 4 + architect check): Fable look, build, Studio, Fable capture review, beta.
5. [ ] **Fruit (looks only)**, then **garden hour** (own gate; pets stay awake), as time allows.
6. [ ] Morning report: what landed, beta number, test-pass rows, what's waiting on Spencer (ads pause, live tracking hotfix, grove-path parking before the re-export).
