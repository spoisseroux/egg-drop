# Onboarding and bug reporting for v1: scope

**Status: scope only, 2026-11-13. Nothing here is built.** No code, save format, Studio place or published build was changed. It answers Spencer's ask: "scope out bug reporting and onboarding/tutorials for v1. It has to be a fun loop to win the Bear. Find the best first tutorial/onboarding to win over players."

No mockups were made for this pass. Section 7 lists the ones worth drawing before the build.

Sources read: `ONBOARDING.md`, `CHAO-GARDEN-DIRECTION.md`, `HATCH-LOOP.md`, `PRODUCT-SCOPE.md`, `PLAY-BUILD.md` (top entry), `TODO.md`, both 2026-11-12 redesign specs, and the first-session code listed in section 2.

## 0. What the code does today (checked 2026-11-13)

| Fact | Where |
|---|---|
| A fresh save opens on the deck in the `Welcome` field phase: no goals, no drop limit that matters, free dropping. | `init.server.lua` (`FieldPhase` is `"Welcome"` while `board.field` is nil) |
| Each merge adds its tier to the hatch charge. The Bear needs 6, so about three merges (roughly five drops) earn it. | `PlayerProgress.chargeHatch`, `PetCatalog` (`pip`, name "Bear", `charge = 6`) |
| The Bear is granted by `Nursery.grantStarter` and then shown through the normal hatch reveal. | `init.server.lua` `grantWelcome`, `HatchProgress.grantStarter` |
| Coaching is three text lines in the status label ("1/3 AIM & DROP", "2/3 MATCH MARKS", "3/3 HATCH BEAR") plus cyan outlines on the tray, rocker, drop key and meter. | `src/client/FirstHatchGuide.lua` |
| A Welcome round can still end: the overflow rule and the egg cap apply. Charge is kept, and the player retries. | `BoardRound.lua`, `RunReturn.lua` |
| After the Bear, the first three rounds are forced to Easy until the first saved win. They are normal rounds: 24 drops, two goals (LEFT then RIGHT), overflow on. They can be lost. | `HeatRequest.guided`, `FieldRun.lua`, `FieldQuestText.lua` |
| A fresh save starts with 6 Stars. | `HatchProgress.lua` (`nectar = charge + 6`) |
| Easy win pays 5, tidy win 6. A missed round pays 0. | `HeatPayout.lua`, `FieldRun.lua` line 121 |
| Petting pays +1 Star, five times a day. Daily gift is 6 Stars, and a new save cannot claim it until the next day (05:00 UTC roll). | `HatchProgress.lua` (`petCount`, `dailyClaimDay`), `EggCatalog.DailyBonus` |
| Daily quests: three a day at 4 Stars. Weekly: three at 10 Stars plus 5 for all three. | `QuestCatalog.lua` |
| Prices: Toy Egg 8, Hue Egg 8, Material Egg 16, Feature Egg 32; wearables 15 / 30 / 60; faceplates 20 / 40 / 80. | `ToyCatalog`, `HueCatalog`, `MaterialCatalog`, `FeatureCatalog`, `WearableCatalog`, `DeckThemes` |
| Four funnel steps are logged: Board ready, First drop, First merge, "Pip hatched". Nothing after the Bear. Disabled in Studio. | `src/server/FirstSession.lua` |
| Pocket Menu on a fresh save: Restart, Quit, Hatch eggs and Customize are locked and say "Win a round to unlock". | `src/client/PocketMenu.lua` |
| There is no bug reporting, no `LogService` capture and no build stamp in `src/`. | grep |

**About "+1 Star on Easy".** No Easy outcome pays exactly 1 in the code. A miss pays 0 and the Supporter pass adds a flat +1 to every finished round, so "+1" most likely means **missed rounds on an account with Supporter**. If that is right, the problem is the miss rate on the first rounds (goals not understood, 24 drops required, overflow), not the ×0.8 multiplier. This is an inference from the code, not something observed in a session. It should be confirmed on Spencer's account before any payout retune.

## 1. The first 10 minutes

### Rules

- **One verb per beat.** Drop, match, meet, pet, play, spend, dress.
- **Teach by doing.** A ghost thumb or a pulsing target shows the action. Text is three words or fewer and never in a modal. The only modal in the whole flow is the hatch reveal.
- **Nothing fails before the first spend.** The Bear round and the first Stars round cannot be lost.
- **Phone first.** Every beat is designed for a thumb on a landscape phone, then mapped to keys and gamepad. Text entry is never needed.
- **Skippable.** Anyone who owns the Bear never sees it. A new save can skip with one tap (see 1.3).
- **No new currency, timer or energy.** Everything below pays or spends Stars through existing transactions.

### 1.1 Beats

Times are targets for a first-time phone player. "Guaranteed" means the server cannot produce a failing outcome.

| # | Time | Beat | What the player does | What they see and hear | New verb |
|---|---|---|---|---|---|
| 0 | 0:00–0:05 | **Boot** | Nothing | Short deck boot (1.2 s cap on a fresh save), then the board with three eggs already resting in it and one large speckled **mystery egg** sitting where the hatch meter is. Headline: "Hatch your first friend". | none |
| 1 | 0:05–0:15 | **Drop** | Drags on the tray and lets go (Space / A) | A ghost thumb slides along the tray and lifts, looping until the first drop. The first egg is seeded to match the egg directly under the default aim, so **the first drop always merges**. Merge pop, and the mystery egg wobbles and gets its first crack. | Drop |
| 2 | 0:15–0:35 | **Match** | Two or three more drops | The matching egg on the board pulses in time with the egg in the dispenser. Each merge adds a crack and a rising note (three notes, one scale). The status line reads "Match" then "One more!". No "1/3" step counter. | Match |
| 3 | 0:35–0:40 | **Crack** | Nothing | Third merge: board freezes, the mystery egg shakes, existing egg-crack cinematic plays. | none |
| 4 | 0:40–1:00 | **The Bear** | Spins the Bear with a thumb, taps **Meet Bear** | The new full-screen reveal stage (being built). First-hatch headline tag "YOUR FIRST FRIEND". One button only; no "Play again" on this one. | none |
| 5 | 1:00–1:30 | **Meet** | Nothing for 2 s, then walks | Deck lowers. Greeting shot: the Bear looks up, hops, runs a small circle. Camera returns to the player. A soft marker sits on the Bear. | Walk |
| 6 | 1:30–2:00 | **Pet** | Taps the Pet prompt (E) and rubs | Hearts, the Bear's happy face, and **+1 Star flies into the wallet** (existing petting pay). Wallet shows 7. A second pet makes 8 and the hearts chip reads "2/5 today". | Pet |
| 7 | 2:00–2:20 | **Back to the deck** | Taps the deck button (or walks to the bench) | The Bear looks at the deck and the deck button pulses once. Chip: "Play for Stars". | Open deck |
| 8 | 2:20–3:50 | **First Stars round** (guaranteed) | Plays a **starter round**: one goal, "Make 3 merges", fill line off | Bear portrait in the corner of the LCD reacts to merges. The round ends the moment the goal is met and the board settles. There is no drop limit, so it cannot be missed. | Goals |
| 9 | 3:50–4:20 | **Results** | Watches the count, taps the gold **Hatch** button | New results screen: ROUND CLEAR!, the Star counts to 6 (fixed first-win pay), the egg meter fills past 8 and reads "Ready to hatch!". Hatch is the focused button this one time. | none |
| 10 | 4:20–5:10 | **First spend** | Buys a Toy Egg for 8 Stars | Hatch eggs opens with the Toy Egg selected and odds shown ("1 in 3"). Egg cracks: Ball, Bone or Sparkler. Receipt button "Give to Bear". | Spend |
| 11 | 5:10–6:00 | **Play with the Bear** | Taps "Give to Bear", lands in the garden | The Bear plays with the toy. Other players can see it. This is the first moment the garden reads as "mine". | none |
| 12 | 6:00–8:30 | **Second round, real rules** | Opens the deck, plays a normal Easy round | The LEFT / RIGHT matching diagram (exists) and the fill-line coach card the first time the line is crossed. Quest card shows a daily quest already at 1/3. A win pays 5 or 6. | Fill line, two goals |
| 13 | 8:30–9:30 | **A goal to leave with** | Taps the come-back strip, or Companions > Wardrobe | Wardrobe opens on a common item at 15 Stars with the Bear wearing the preview. Wallet is around 11 to 13: "2 more Stars". One more round or tomorrow's gift buys it. | Dress (preview) |
| 14 | 9:30–10:00 | **Tomorrow** | Leaves or keeps playing | On results and on the garden HUD: "Tomorrow: gift +6, 3 new quests, 5 pets". The Bear waves on Leave. | none |

Star budget for the session, without passes: 6 (welcome) + 2 (two pets) + 6 (starter round) = 14, minus 8 (Toy Egg) = 6, plus 5 or 6 (second round) = 11 or 12, plus up to 3 more pets = up to 15. A player who pets five times and wins twice can buy the first wearable in session one; most will leave one round short, which is the intended pull.

### 1.2 Why this order

- **The Bear is on screen within 45 seconds and owned within a minute.** Roblox players decide in 60 to 90 seconds; the pet is the thing they would stay for, so it arrives first and the rules arrive later.
- **The mystery egg makes three merges feel like a win, not a tutorial.** Today the charge meter fills with no anticipation. Cracks plus rising notes turn the same three merges into a countdown.
- **Petting pays before rounds do.** The first Star the player earns comes from touching their pet. That ties the garden to the wallet and makes the 5-a-day pets a habit from minute two.
- **The first real round is short and always won**, so the first results screen is a celebration and the first egg is bought while the player is happy. The hard parts of the game (two goals, 24 drops, the fill line) are introduced in round two, when the player already owns a pet and a toy.
- **The session ends on a visible near-miss** (a wearable a few Stars away) and a dated promise (gift and quests tomorrow).

### 1.3 Skipping and returning players

- A save that owns the Bear never enters the Welcome phase (already true).
- **New save, experienced player:** a small "Skip" pill appears on the Welcome board after 3 s. One tap grants the Bear through the same `grantStarter` path and goes straight to the reveal, which itself closes on one tap. The starter round also carries the pill; skipping it starts a normal Easy round instead. Skips are logged.
- **Garden coaching is state-driven, not scripted.** The Bear marker shows until the first pet; the deck pulse shows until the first round ends. Leaving mid-way and rejoining resumes at the right beat, because each beat is derived from saved state (owns Bear, pets today, total wins, any item receipt).
- **No input is ever blocked.** A player who ignores the marker and wanders the garden is not pulled back. After 20 s without the hinted action, the hint repeats once, louder (a hop and a chirp from the Bear), then goes quiet.
- **Idle on the Welcome board:** after 8 s with no drop, the ghost thumb replays with a sound. After 25 s, one egg drops by itself onto its match so the first crack happens anyway. A player who never touches the screen is not a retained player, but a confused one gets a free demonstration.

### 1.4 Controls per device

| Beat | Touch (landscape) | Keyboard | Gamepad |
|---|---|---|---|
| Drop | Drag the tray, release. Ghost thumb. | ← → then Space. Key glyphs pulse on the deck. | D-pad then A |
| Spin the Bear | Drag | Drag or ← → | Right stick |
| Pet | Tap the prompt, rub | E | X (as built) |
| Open deck | Deck button | As built | As built |
| Hatch / Give to Bear | Tap the gold button | Enter / A key | A |

Touch targets are 48 px or more. Nothing is placed under the Roblox top-left controls (`top = kh + 2`, as built). The ghost thumb and pulses respect Reduced Motion (static arrow and a steady outline).

## 2. What exists and what to build

### 2.1 Per beat

| Beat | Exists | Build or change | Files |
|---|---|---|---|
| 0 Boot | Deck boot sequence | Cap the boot at 1.2 s when the Bear is not owned. | `src/client/DeckBoot.lua` |
| 1–3 Welcome round | Welcome phase, charge by merges, text coaching, outlines | Seeded opening board and bag so the first drop merges. Mystery egg in place of the meter with three crack stages. Ghost thumb. Three rising notes. Overflow and egg cap off in Welcome. Idle demo. Skip pill. New copy. | `src/server/init.server.lua` (Welcome set-up, a skip remote), `src/server/BoardSimulation.lua` (seed), `src/server/BoardRound.lua` (arm flag), `src/client/FirstHatchGuide.lua` (rewrite), `src/client/EggArt.lua` or `DeckArt.lua` (mystery egg), `src/client/BoardAudio.lua` (three notes: audio from Spencer) |
| 4 Reveal | Hatch cinematic; full-screen reveal being built (celebrations spec section 1) | A `starter` variant: headline tag "YOUR FIRST FRIEND", one button "Meet Bear". The receipt already carries `starter = true`. | `src/client/HatchReveal.lua`, `src/client/HatchNavigation.lua` |
| 5 Meet | `PetGreetingShot`, `PetFollow`, Meet routing | Make the starter Meet always play the greeting shot, then hand the camera back within 2.5 s. Marker on the Bear. | `src/client/PetGreetingShot.lua`, `src/client/GardenClient.lua`, new `src/client/GardenCoach.lua` |
| 6 Pet | Petting, hearts, +1 Star, 5 a day | Star fly-in to the wallet on the first pets (the pay exists; the fly-in may not). "n/5 today" chip. Bear rim light in petting mode (already an open QA item). | `src/client/GardenCareClient.lua`, `src/client/PetAffection.lua`, `src/client/PetFocusUI.lua` |
| 7 Back to deck | Deck open button, bench | One pulse and a "Play for Stars" chip driven by `GardenCoach`. | `src/client/GardenCoach.lua`, `src/client/HandheldScreens.lua` |
| 8 Starter round | Guided Easy rounds; `count` goal kind already exists ("Make N merges anywhere") | A `starter` field template: one `count` goal of 3, no drop limit, fill line not armed, ends on success, fixed pay 6 with no heat multiplier. Used once, for the first round after the Bear, while `totalWins == 0`. | `src/shared/FieldObjectives.lua`, `src/server/FieldRun.lua`, `src/server/HeatRequest.lua`, `src/shared/HeatPayout.lua` (fixed starter pay), `src/client/FieldQuestText.lua` |
| 9 Results | Results in the deck; new results with egg meter and Hatch button being built | First-win rule: Hatch is the focused button when it is the player's first affordable egg. | `src/client/DeckResults.lua` |
| 10 First spend | Hatch eggs (list redesign being built), odds, Toy Egg selected first, receipts | Receipt button reads "Give to Bear" for the first toy and equips it in one tap. | `src/client/EggHatchView.lua`, `src/client/ItemReceiptLayout.lua`, `src/client/ToyIntent.lua` |
| 11 Toy play | Toy visuals and garden toy play | Start a toy play beat as soon as the player lands in the garden after the first toy. | `src/server/GardenState.lua`, `src/client/PetPlayVisual.lua` |
| 12 Second round | LEFT/RIGHT diagram (`FirstHatchGuide:fieldStep`), danger state redesign being built | The one-time fill-line coach card (already a TODO follow-up). Needs the saved flag in 2.3. | `src/client/FirstHatchGuide.lua`, `src/client/DeckScreen.lua` |
| 13 Wardrobe goal | Companions hub being built, `WardrobeShop`, results come-back strip being built | Come-back strip picks the cheapest unowned wearable as the next target once a Toy Egg has been bought ("Bell Collar · 2 more Stars"), and deep-links to it. | `src/client/DeckResults.lua`, `src/client/WardrobeShop.lua` |
| 14 Tomorrow | Daily gift, quest rotation, day clock | A "Tomorrow" line on results and a small sign on the garden HUD after the first session's second round. Bear wave on Leave. | `src/client/DeckResults.lua`, `src/client/QuestLog.lua`, `src/client/PetReactions.lua` |
| All | Four funnel steps | Extend the funnel (section 5). | `src/server/FirstSession.lua`, `src/server/init.server.lua` |

### 2.2 What must change in the current Welcome round

1. **It can end badly.** Overflow and the egg cap still apply. Turn both off while `FieldPhase == "Welcome"`.
2. **The first drop is not guaranteed to merge.** Seed the board with three resting eggs and a matching bag so the default aim merges.
3. **Text is doing the teaching.** "1/3 AIM & DROP / Drag tray, release" is a line of instructions in a small label. Replace it with the ghost thumb and a pulsing match; keep at most three words.
4. **No anticipation.** The meter fills quietly. Replace it with the mystery egg, three cracks and three rising notes.
5. **The numbered steps promise a course.** "1/3" tells a new player they are in a tutorial. Drop the counter.
6. **The reveal offers two choices.** On the first hatch, only "Meet Bear".
7. **The Pocket Menu looks broken on a fresh save.** Four of five rows are locked. During Welcome, show only Resume and Settings (which holds Report a bug), and bring the other rows in when they work.
8. **The step name "Pip hatched" is stale.** Rename when the funnel is extended.
9. **The known sticking reveal** ("Something is stirring… / Hatching…", TODO Systems list) sits exactly on the most important second of the session. It must be reproduced by hand and fixed, or given a 6 s timeout that falls through to the reveal, before any of this ships.

### 2.3 Saved state

Most beats derive from state that is already saved (Bear owned, pets today, `totalWins`, item receipts). Three things do not:

- fill-line coach card seen,
- starter round done or skipped (so a rejoin does not repeat it; `totalWins >= 1` covers the done case, not the skip),
- garden intro done (a player who quits before petting and returns the next day).

Recommendation: add **one** integer `coachMask` to the profile in a single save-format bump and put every one-time flag in it, now and later. One bump before launch costs nothing because launch saves are fresh.

## 3. Day 1 to day 7

Existing income for a casual day with no passes: about three wins on Easy or Medium (15 to 20), three daily quests (12), the gift (6) and five pets (5). That is roughly **40 Stars a day**, plus 35 a week from weekly quests.

| Day | The pull to come back | What they do | Spend it points at |
|---|---|---|---|
| 1 | The Bear, the first toy, a wearable a few Stars away | Section 1 | Toy Egg 8 |
| 2 | Gift +6 waiting, three new quests, the wearable they left behind | Claim, pet, one or two rounds | First wearable 15 |
| 3 | Difficulty picker unlocked; "Play two difficulties" style quests | First Medium win (6 to 8) | Hue Egg 8: dye the Bear, which also recolours its reveal plate |
| 4 | Second toy or a missing one ("2 of 3 toys") | Rounds, quests | Toy Egg 8, Material Egg 16 (Gloss or Matte) |
| 5 | The deck itself: other players see it while you play | Deck style | First faceplate 20 |
| 6 | Hard rounds, "SPICY WIN!" and 9 to 12 Stars | Skill quests | Rare wearable 30 |
| 7 | Weekly quests close: 30 Stars plus the +5 bonus | Finish the set | Showcase wearable 60 or a rare faceplate 40 comes into range |

Supporting pieces, all presentation over existing data:

- **Come-back strip target** (results screen, being built): always names the cheapest thing the player does not own and how many Stars short they are. Order: Toy Egg, common wearable, Hue Egg, faceplate, then by price.
- **"Tomorrow" line**: gift amount, "3 new quests", pets reset. Uses the 05:00 UTC clock and shows the time left.
- **Gift on arrival**: on days 2 and later the gift is the first thing on screen, claimed with one tap, with the Bear running up. Today it is easy to miss.
- **Hearts chip** "n/5 today" in petting mode, so the daily cap reads as a small goal instead of a silent stop.
- **Weekly progress on results** when a weekly quest moved (`weeklyLine` already reaches the screen).
- **Night**: the Bear's night glow and the night garden are a reason to log in at a different time. A quest pool entry could point at it later; no v1 work.

Not proposed for v1: login streaks, a streak currency, limited-time eggs, push-style notifications. Each needs new saved state or new policy review, and the existing gift, quests and pets already give three daily reasons.

## 4. Bug reporting

### 4.1 Where it lives

- **Settings > Report a bug.** Settings is reachable from the garden menu (`DeckMenu`) and should be reachable from the Pocket Menu in every state, including a fresh save.
- **Offered at the moment something breaks.** A toast with a "Report" action when: a save or payout is refused or retries more than 10 s (`SaveNotice`, `RewardStatus = "Refused"`), a hatch reveal waits more than 10 s, or the client logs an error. One tap opens the form with the category pre-selected.
- No Stars for reporting. A reward would turn the form into a farm.

### 4.2 The form (phone first)

A deck sheet using `DeckKit`:

1. **What happened?** Five chips, one required: Stuck or frozen · Looks wrong · Stars or items missing · Controls · Something else.
2. **Tell us more (optional).** One text box, 200 characters. On a landscape phone the keyboard covers the screen, so the chips must be enough by themselves.
3. **Send.** Then "Sent. Thank you!" with the Bear waving, and the sheet closes after 1.5 s.

Under the text box, in small type: "Don't include names or personal details."

### 4.3 Captured automatically

| Group | Fields |
|---|---|
| Build | `game.PlaceVersion`, a build tag (git short hash) from a new `src/shared/BuildInfo.lua` stamped at publish, server uptime |
| Device | Input class (touch, keyboard, gamepad), viewport size, safe-area insets, preferred text size, Reduced Motion, graphics quality level, average frame time over the last 10 s, network ping |
| Where | Mode (Board or Room), open screen id (deck screen, menu or sheet name), `FieldPhase`, heat, goal template id, drops, run sequence, round over or not, garden position rounded to whole studs, clock hour |
| Save | Profile load status, hatching handle status (Ready, Retrying, Busy), last `RewardStatus`, save revision, wallet balance, owns Bear, `totalWins` |
| Errors | Last 20 client warnings and errors from a `LogService.MessageOut` ring buffer (started at boot), and the last 20 server warnings and errors that mention this player's board |
| Report | Category, filtered text, UTC time, a random report id |

Size cap: 6 KB per report; error lines are cut to 200 characters each.

### 4.4 Privacy and Roblox policy

- **No username, display name, chat, friends, locale or avatar data.** Log lines are scrubbed before sending: the player's name and display name are replaced with `<player>`.
- **UserId** is the one identifier worth keeping: it is what lets us look at the save and delete a player's reports on an erasure request. It is still personal data. See open question 4.
- **Free text is filtered** on the server with `TextService:FilterStringAsync` and `GetNonChatStringForBroadcastAsync` before it is stored. If filtering fails, the text is dropped and the rest of the report is kept. The text is never shown to another player.
- **Never ask for contact details**, and never link out to Discord, email or a form from inside the game. All-ages experiences cannot solicit personal information or send under-13 players off platform.
- **Retention: 30 days**, then deleted by the pull script.
- The points above reflect Roblox policy as understood at the time of writing; re-check the current Community Standards and the HttpService and DataStore terms before building.

### 4.5 Rate limits

| Limit | Value |
|---|---|
| Per player | 1 report per 60 s, 3 per server session, 5 per day (a counter in the report store, not in the economy save) |
| Per server | 30 per hour |
| Client | Send button disabled for 60 s after a send |
| Duplicate | Same category and same top error line within 10 minutes from one player is counted, not stored again |
| Remote | Payload type- and size-checked on the server; anything malformed is dropped silently |

### 4.6 Where reports go

| Option | For | Against |
|---|---|---|
| **A. DataStore queue** (`EggDropBugReportsV1`, one key per report, key prefix by day), read with Open Cloud | No external service, no HTTP from the game, no secret in the place. Persistent. The repo already uses Open Cloud for uploads. Deleting by UserId or by age is a script. | Not pushed to you: you run a script (or a scheduled agent does). Uses DataStore write budget (small at these limits). |
| **B. HttpService to a private endpoint you own** (for example a Cloudflare Worker that stores to D1/KV and can ping you) | Real-time. Rich triage later. | Turns on HTTP requests for the experience, adds a service to keep alive and a token to guard (Roblox Secrets Store). Player-entered text leaves Roblox, which raises the privacy bar. |
| **C. HttpService straight to a Discord webhook** | Quick | Discord has throttled and blocked Roblox server traffic in the past and does not want webhooks used as a log sink. The webhook URL is a secret living in the game. Not recommended. |
| **D. MessagingService** | Live | Not storage. Only running servers hear it, and you would have to be in one. Rejected. |
| **E. AnalyticsService custom events** | Free counts on the dashboard | No text, no payload. Use it alongside, for volume by category and version. |
| **F. Creator Dashboard error report** | Already on. Groups script errors by place version with counts. | Only errors, no player context. Use it alongside. |

**Recommendation: A for v1**, with E and F alongside. A soft launch will produce a handful of reports a day; a queue you pull is enough, adds no attack surface and keeps player text inside Roblox. Write the reporter behind one function (`BugReports.submit`) so B can be added later without touching the form.

### 4.7 Owner triage flow

1. **Pull.** `scripts/pull_bug_reports.py` (new; Open Cloud key from the local `.env`) lists and fetches new reports.
2. **Group.** By signature: category + top error line + place version. Output `artifacts/bug-reports/<date>/REPORT.md` with counts, device split, first and latest time, and three sample reports per group. Raw JSON stays out of git because it holds UserIds.
3. **Rank.** P0, same day: Stars or items missing, save refused, stuck in Welcome or on the reveal. P1: stuck elsewhere, controls on a device class. P2: looks wrong.
4. **Act.** New groups go into `TODO.md` under a "Player-reported bugs" heading with the signature and the count. An agent can do steps 1 to 4 on a schedule and leave the ranking for Spencer.
5. **Close.** When a fix is published, the group is marked with the fixing place version; the next pull flags any report of that signature from a newer version as a regression.
6. **Purge.** The same script deletes reports older than 30 days, or all reports for one UserId on request.

After every publish, also read the Creator Dashboard error report for the new place version once, 24 hours in.

### 4.8 Files

New: `src/client/BugReportSheet.lua`, `src/client/ClientLog.lua` (ring buffer), `src/server/BugReports.lua` (validate, limit, filter, store), `src/shared/BuildInfo.lua`, `scripts/pull_bug_reports.py`, `scripts/BugReports.spec.lua`. Changed: `src/client/DeckMenu.lua` and `src/client/PocketMenu.lua` (entry points), `src/client/SaveNotice.lua` (offer on failure), `src/server/init.server.lua` (remote, server log buffer).

## 5. Metrics

### 5.1 Onboarding funnel

`AnalyticsService:LogOnboardingFunnelStepEvent`, extending `FirstSession.lua`. Set the step list before launch and do not renumber it afterwards. `FirstSession` must stay alive past step 4 for the rest of the first session.

| Step | Name | Fires when | Target (share of joins) | Time target (median) |
|---:|---|---|---:|---|
| 1 | Board ready | Welcome board is interactive | 97% | 5 s |
| 2 | First drop | First accepted drop | 92% | 12 s |
| 3 | First merge | First merge | 90% | 15 s |
| 4 | Bear hatched | Starter grant saved | 85% | 45 s (p90 90 s) |
| 5 | Met Bear | "Meet Bear" pressed | 82% | 60 s |
| 6 | First pet | First saved pet award | 65% | 2:00 |
| 7 | First round started | First drop of the starter round | 60% | 2:30 |
| 8 | First round won | Starter payout saved | 57% | 4:00 |
| 9 | First spend | First egg purchase saved | 48% | 5:00 |
| 10 | First item used | Toy equipped | 44% | 5:30 |
| 11 | Second round finished | Any outcome | 38% | 8:30 |
| 12 | Wardrobe seen | Wardrobe opened in session one | 25% | 9:30 |

### 5.2 Custom events (`LogCustomEvent`)

`OnbSkipWelcome`, `OnbSkipStarter`, `OnbIdleDemo` (the auto-drop fired), `OnbWelcomeStuck` (reveal timeout hit), `FirstSessionSeconds` (value on leave), `SecondRoundResult` (1 win, 0 miss), `GiftClaimed`, `QuestClaimed`, `PetsToday` (value on leave), `BugReportSent` (one event per category), `BugReportOffered`. Existing events stay: `FirstSessionLoungeVisit`, `FirstSessionRoundRetry`, economy sources and sinks.

### 5.3 Outcome targets for the soft launch

| Metric | Target | Source |
|---|---:|---|
| Median time to the Bear | 45 s or less | Step 4 timing |
| First session, median length | 8 minutes or more | `FirstSessionSeconds`, dashboard |
| Second-round win rate | 60 to 75% | `SecondRoundResult` (below 60% means round two is too hard; above 75% means Easy is trivial) |
| Day 1 retention | 25% or more | Creator Dashboard |
| Day 7 retention | 8% or more | Creator Dashboard |
| Reports about Welcome or the reveal | 0 | Bug report groups |

These numbers are starting hypotheses, not benchmarks from data. Replace them with the dashboard's similar-experience benchmarks once the place has a week of traffic. Read the funnel for the largest single drop between two steps and fix that step first.

## 6. Risks

| Risk | Why it matters | Mitigation |
|---|---|---|
| The reveal sticks on "Hatching…" | It would lose the player at second 40 | Reproduce by hand, fix or add the 6 s fall-through, add `OnbWelcomeStuck` (2.2 item 9) |
| Three build agents are changing results, reveal, hub and danger state now | Beats 4, 9, 10, 12 and 13 sit on those screens | Build onboarding after slices B and D land; beats 0 to 3 and 5 to 8 do not touch them and can start first |
| Garden load on a phone at beat 5 | The first 3D moment could hitch right after the best moment | Preload already runs 3 s after join; hold the reveal's button until the garden and Bear assets report ready (the reveal is a pleasant place to wait) |
| A no-fail starter round could be farmed | Fixed 6 Stars for three merges | It exists only while `totalWins == 0`; paying it sets `totalWins = 1` in the same transaction |
| Seeded Welcome physics is not deterministic enough | "First drop always merges" must hold on every device | The server owns the simulation; spec the seeded board across aim positions, and widen the first match by seeding two matching eggs side by side |
| "+1 on Easy" is misdiagnosed | A payout retune that does not fix the miss rate | Confirm on Spencer's account, then read `SecondRoundResult` after launch |
| Bug report spam or abusive text | Storage and reading cost | Limits in 4.5, filtering, chips-first form, 200 characters |
| UserIds in stored reports | Personal data obligations | 30-day purge, delete-by-UserId script, or drop the id (open question 4) |
| Save-format bump for `coachMask` | Another migration | Do it once, before the launch DataStore goes live |
| Audio for cracks, rising notes and the Bear's chirp | Spencer owns audio and it is not started | Ship with existing merge and hatch cues pitched up; swap when the audio lands |

## 7. Build order

| # | Slice | Size | Depends on |
|---:|---|:--:|---|
| 1 | Reproduce and fix the sticking starter reveal; add the timeout | S | none |
| 2 | Funnel steps 5 to 12 and the custom events; rename step 4 | S | none |
| 3 | Welcome round rework: no-fail, seeded board, mystery egg, ghost thumb, idle demo, skip pill, new copy | M | none |
| 4 | Starter field template: one goal, no drop limit, fixed pay, used once | M | none |
| 5 | Starter reveal variant ("YOUR FIRST FRIEND", one button) | S | redesign slice B |
| 6 | `GardenCoach`: greeting hand-off, Bear marker, first-pet Star fly-in, hearts chip, deck pulse | M | none |
| 7 | First-spend path: Hatch focused on first affordable egg, "Give to Bear", toy play on arrival | S | redesign slices B and D |
| 8 | `coachMask` save bump; fill-line coach card | S | redesign slice C |
| 9 | Come-back target, "Tomorrow" line, gift on arrival | M | redesign slice B |
| 10 | Bug reports: `ClientLog`, sheet, server module, store, entry points, spec | M | none |
| 11 | `pull_bug_reports.py`, report template, purge | S | 10 |
| 12 | Fresh-save Pocket Menu (Resume and Settings only during Welcome) | S | 10 |
| 13 | Physical-phone run of the whole first 10 minutes with a stopwatch; adjust timings | S | 1 to 9 |

Slices 1 to 4, 6 and 10 can start now without touching the screens being rebuilt. Total: about six M and seven S.

Mockups worth drawing before slices 3 and 6 (none made in this pass): the Welcome board with the mystery egg at each crack stage on 812×354, the ghost thumb, the garden marker and hearts chip, and the bug report sheet on a phone. Output folder `artifacts/onboarding-2026-11-13/`, generator `scripts/deck_art/build_onboarding_mockups.py`.

## 8. Open questions for Spencer

1. **Should the first Stars round be impossible to miss?** Recommendation: yes. One starter round (one goal, no drop limit, fill line off, fixed 6 Stars), used once. The real rules arrive in round two, after the player owns the Bear and a toy.
2. **Is "+1 on Easy" a missed round plus the Supporter bonus?** The code pays 5 or 6 for an Easy win and 0 for a miss. Recommendation: confirm on your account before retuning. If confirmed, leave the multiplier alone and add a small finish pay for missed rounds on every difficulty (2 Stars when at least one goal was met), so a loss still moves the egg meter.
3. **One `coachMask` save field, added now?** Recommendation: yes, one bump before the launch store goes live, holding every one-time flag (fill-line card, starter skipped, garden intro done).
4. **Store the player's UserId with a bug report?** Recommendation: yes, UserId only, purged at 30 days, with a delete-by-UserId script. Without it a "my Stars are gone" report cannot be matched to a save. The alternative is fully anonymous reports that are only good for counting.
5. **Reports through a DataStore queue you pull, or pushed to an endpoint you run?** Recommendation: the DataStore queue for the soft launch (no HTTP, no secret, text stays on Roblox), with an agent pulling daily. Add a pushed endpoint only if volume or urgency calls for it.
