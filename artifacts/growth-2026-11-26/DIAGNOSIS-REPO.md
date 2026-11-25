# Why Pocket Pals isn't taking off: the repo side (2026-11-25)

Opus, read-only pass over the repo, the git history, the store-listing artifacts and the Obsidian `pocketpals` folder. Live numbers come from the coordinator's `CREATOR-HUB-2026-11-25.md` (same folder) and from earlier snapshots in the repo. Nothing was edited, published or committed. **[guess]** marks inference that the code or data does not prove.

**Live build:** place v1054, runtime `54dca26` (PLAY-BUILD.md, "PUBLIC v1054 2026-11-22"). Everything since then (onboarding v3, the Sleepy Nest, Garden Dash, levels, world alive) is **beta only**.

---

## The short answer

All four rows of the framing are failing, and they feed each other:

1. **Impressions:** 100% paid. Home Recommendations and Search gave **0** plays in 56 days. The ad campaign is **paused** (TODO.md line 86: $7.18 spent in total), so impressions are now close to zero.
2. **Play rate:** about **0.2%** of ad impressions became plays. Recorded ad tests: 0.8% CTR, then about 1 in 10 clickers pressed Play (`store-listing/v2/BRIEF.md`). Ads could only target 18+ accounts because of the known 16+ gate. That is a cute-pet game shown to adults, which caps CTR **[guess]**.
3. **Session and D1:** D1 is **1.36%** and D7 is **0%**. Only 24% are still playing at 5 minutes. The tutorial itself mostly works: 57% "start a second round". Sessions end **at the first plain results screen after the tutorial**. At that moment the player has about 5 Stars, nothing they can buy, and nothing in the world promising tomorrow.
4. **Sharing:** the live build has no invite prompt, no notifications, and no visible co-play in session one.

The other agent's hypothesis holds: row 3 plus clarity. One correction to it: the clarity problem is less "the tutorial is confusing" and more "the game is a Suika-style merge board wearing a pet-garden title". The board is fun for 2 rounds. The pet loop it is meant to feed takes too many systems to reach (Stars, machines, eggs, stats, wardrobe), so nothing pays off before minute 5.

---

## 1. What the game records

### Live today (runtime 54dca26)

**Onboarding funnel.** `src/server/FirstSession.lua` (live version: `git show 54dca26:src/server/FirstSession.lua`), from slice A (`fd6435c3`). It is server-side and uses `LogOnboardingFunnelStepEvent`. It runs on live servers only, for saves at rank 0 when they join. In Creator Hub it is under **Analytics > Funnels > Onboarding**. These are the exact step names:

| # | Step name (as shown) | When it fires in live code (`src/server/init.server.lua` @54dca26) |
|---|---|---|
| 1 | Board ready | The server builds the player's board after the save loads (line ~920 and ~2217). This is server-side, so it fires before the client finishes loading. |
| 2 | First drop | First egg dropped in the Welcome round (lines ~1067, ~1974) |
| 3 | First merge | First merge (lines ~1987, ~2078) |
| 4 | Bear met | The Welcome-round Bear is granted and its reveal is acknowledged (lines ~1872, ~1892) |
| 5 | Garden walkthrough done | The client sends coach mark `gardenIntro`, which happens when the "Your garden" tour cards close (line ~1609) |
| 6 | First machine opened | First-visit coach mark for hatch, style, companions, quests or book (line ~1610) |
| 7 | First quest claimed | `questClaim` succeeds (line ~1675) |
| 8 | First Stars spend | Any Stars sink (line ~977, via `EconomyAnalytics.onSink`) |
| 9 | Second round started | First drop of any round after Bear met (`FirstSession:roundStarted`) |

**This live funnel has a known flaw.** Roblox treats logging step N as completing every step before it. **Steps 5 to 8 are inflated by step 9.** A player who skipped the tour, never claimed a quest and never spent anything, then dropped one egg in round two, is counted as passing all of them. Evidence: "First quest claimed" shows 97% of the people who opened a machine. The daily quests on live are "Finish 3 rounds", "Chain 3 merges", "Score 600" and the like (`src/shared/QuestCatalog.lua`), and very few new players can claim one in their first minutes. **Treat steps 6 to 8 as meaningless, and step 5 as an upper bound.** Steps 1 to 4 and 9 are trustworthy.

**Live custom events** (Creator Hub **Analytics > Custom events**), all through `src/server/EconomyAnalytics.lua`:
- First session (logged through `FirstSession:record`): `OnbSkipWelcome`, `FirstSessionLoungeVisit`, `FirstSessionRoundRetry`, `OnbIdleDemo`
- Rounds: `RoundWon`, `RoundLost`, `SessionRounds` (count at leave), `SessionEndWallet`
- Pets: `PetEarned`, `PetAdopted`, `PettingCapReached`, `PlayDateDone`, `SnackFed`
- Eggs: `EggOpened_toy|feature|material|hue|look|name|stat` (result in CustomField01)
- Store: `StoreOpened`, `RobuxPurchase`, `PassPurchased_<key>`
- Other: `WardrobeEquip`, `BookMilestone`, `StampAdded`

**Live economy events** (**Analytics > Economy**, currency "Stars"):
- Sources: `WelcomeRound`, `RoundReward:<heat>`, `PetCare`, `Quest`, `BookMilestone`, `PlayDate`, `DailyGift`, `StarsPack_<key>`, `DuplicateRefund`
- Sinks: `CompanionEgg_*` and shop actions

**Retention, session length and acquisition** come from Roblox automatically. No code is needed.

### Built but not live

| What | Where | Status |
|---|---|---|
| **Funnel order fix**. Step N logs only after N-1; an early step goes as `FunnelOutOfOrder_<StepKey>`. Brand-new saves only (`profile.newSave`). Adds the custom events `FirstPet`, `FirstHatch` and `FiveMinutes`. Off switch `FeatureFlags.FirstSessionFunnel`. | `hotfix/first-session-funnel` @ `cf9e7ee8` (branched from live 54dca26) and `fix/first-session-funnel-arcade` @ `e9f58bf6`, merged into `feat/egg-drop-arcade-polish` | **Not in `main`, not live.** Spec green (FirstSession 10/10), code review GO. **On hold** (Spencer, 2026-11-23: "Hold for now"; TODO.md lines 86 and 89). Plan: `FIRST-SESSION-FUNNEL-PLAN-2026-11-23.md`. |
| **v3 11-step funnel**: Board ready, First merge, Bear met, In the garden, First pet, Followed the Bear to the machine, Toy given, Nest tucked, Second round done, Five minutes, Ten minutes | `src/server/FirstSession.lua` on the feature branch (`V3Steps`) | Beta only, and only when onboarding v3 (follow, needs, nest) is on. |

**Question about the funnel population [guess].** On the live code, step 1 fires for any session whose save is at rank 0. That includes returning players still at rank 0, and Spencer's own fresh-save test sessions. The research doc flagged 157 funnel users against roughly 70 new players a week. The coordinator's numbers show the same pattern: 107 funnel users in 7 days, against 176 plays in 56 days. The hotfix's `newSave` gate fixes this.

---

## 2. Every recorded number found

| Number | Value | Source |
|---|---|---|
| D1 retention (7-day average) | 1.04% (to Nov 22); **1.36%** (Nov 25) | `research/FUNNEL-SNAPSHOT-2026-11-23.md`; `CREATOR-HUB-2026-11-25.md` |
| D7 | 0% | CREATOR-HUB |
| New users | ~10/day, then ~15/day | both |
| Average playtime | 3.9 min (5.1 over 28 days); new users 3.6 min, returning 5.2 | CREATOR-HUB |
| First-session retention | 24% at 5:00 (about 55% at 1:00, 40% at 2:00, 30% at 3:20, 15% at 6:00, 5% at 13:00) | CREATOR-HUB |
| Funnel, Nov 15 to 22 (157 users) | 100 / 91 / 91 / 89 / **68** / 61 / 57 / 57 / 50% | FUNNEL-SNAPSHOT |
| Funnel, last 7 days (107 users) | 100 / 93.5 / 93.5 / 92 / **72** / 64 / 62 / 62 / **57%** | CREATOR-HUB |
| Acquisition | Sponsored Ads 169, Other 5, Friends 2, Home 0, Search 0 | CREATOR-HUB |
| Ad test 1 (ad-v1) | 0.8% CTR, about 1 in 10 clickers pressed Play | `artifacts/store-listing/v2/BRIEF.md` line 3; `v3-launch-v2/SCOPE.md` line 9 |
| Campaign "Pocket Pals v2 store set (A/B/C)" | 688 impressions and 12 clicks (Nov 22, 00:58); 1,867 impressions and 24 clicks, about 1.3% CTR (Nov 22, 01:52); $5/day, audience 18+ only; **paused** at $7.18 total | PLAY-BUILD.md lines 43 and 77; TODO.md lines 86 and 107 |
| Impressions to plays | about 0.2% (read off a chart, roughly 100K impressions) | CREATOR-HUB (marked as a guess there) |
| Public page | 148 visits, 13 favourites, 3 up / 1 down (Nov 23); 166 visits, 75% likes (Nov 25) | both |
| Revenue | 0 (one real Robux purchase, by Spencer, to verify) | FUNNEL-SNAPSHOT; PLAY-BUILD line 41 |
| Store listing audits | v1051 and v1054: description, icon and 7 thumbnails match; Home Page set has 1 active (T1) | PLAY-BUILD lines 43 and 77 |

The Obsidian folder (`C:\Users\skunk\Documents\obsidian-spencer\pocketpals`) holds only Spencer's QA-pass notes and screenshots, with **no metrics**. One line from it is worth keeping: "its ok to assume the player knows how to use suica game" (`roblox qa pass nov 13.md`). The core verb is Suika, and the team already knows it.

---

## 3. The live first session, minute by minute

The timings are **estimates** from the code, the onboarding v1 scope (`ONBOARDING-V1-SCOPE-2026-11-13.md` section 1.1, target times) and a measured round length of 30 to 60 s (`artifacts/qa-2026-11-16-v751/GAME-FEEL-PLAN.md`; "A Medium round takes about 33 s", PLAY-BUILD line 193). Nobody has timed a real new player on a phone.

| Time (est.) | What the player sees and does | Taps / screens | Funnel step |
|---|---|---|---|
| Join | Roblox loading screen, then the place streams in. This is a heavy place (82k lines of live Luau; menu art preloads at join). **Load time on a phone has never been measured [guess: 10 to 30 s].** | 0 | **1 Board ready** fires on the server here, before the player can see anything |
| 0:00 to 0:05 | The Pocket Deck boots up in their hands, showing the board. Pill: "Match eggs. Hatch a friend." (5 s, or gone at the first drop). A mystery egg sits where the hatch meter is. | screen 1: the deck | |
| 0:05 to 0:15 | Drag the tray, drop an egg. The first merge is seeded. | 1 to 2 drops | **2 First drop**, **3 First merge** |
| 0:15 to 0:45 | About 3 merges (roughly 5 drops) fill the Bear's charge of 6 (`PetCatalog` `pip` charge 6). | ~5 drops | |
| 0:45 to 1:00 | Egg-crack cinematic, then the full-screen reveal stage, then tap Meet. Then a greeting camera shot. **14 Stars** arrive with the Bear, so the wallet goes from 6 to 20 (`CoachMarks.WelcomeStars`). | screens 2 and 3 (cinematic, reveal), 1 tap | **4 Bear met** |
| 1:00 to 1:30 | The player is now in the garden as their avatar. After standing still 1.2 s, the **"Your garden" tour** opens by itself: 4 text cards (Machines, Say hi to your pet, Quests and dailies, Customize; `UICopy` `howItWorks.garden`). A "Your first Stars" toast plays under it. | screen 4: a modal with 4 cards and 4 taps | **5 Garden walkthrough done** when it closes. **This is the biggest measured leak: 21 to 32% drop here.** |
| 1:30 to 2:30 | A "Hatch your first egg" pill points at a menu. Walk to the Hatch eggs machine (or open Menu), pick the Toy Egg (20 Stars), watch the hatch reveal, then "Give to Bear". Or ignore all of it. | 3 to 6 taps, 2 to 3 more screens | 6 to 8 (not reliable, see section 1) |
| ~2:00 to 3:00 | The player opens the deck again and drops one egg into a **real** round: 24 drops, two goals (LEFT then RIGHT), a fill line, and it can be lost. | | **9 Second round started** fires at the first drop |
| ~3:00 to 4:00 | The round ends (30 to 60 s). The results screen shows Total ★, Score · Best · Chain, a "TODAY ★ N earned" strip, and the buttons Replay / Hatch eggs / Back to the garden. An Easy win pays 5 Stars (6 tidy); a loss pays 0 to 2 (`HeatPayout`). | screen N | **No step after this.** Sessions end here. |

**Counting it up:** to reach the pet, about 6 inputs and 3 screens, under a minute. That part works, and it matches the funnel (92 to 98% reach Bear met). **To the end of the tutorial, about 15 to 20 inputs, 6 to 8 screens, 4 text cards and 3 new concepts**: Stars, machines and eggs.

### What the player is shown right after step 9, and why they leave

Step 9 fires at the first drop of round two, so "after step 9" means the rest of that round and then its results screen.

- **The round is harder than the one before.** The Welcome round could not fail. Round two has 24 drops, two goals and an overflow loss, and nothing new teaches it except a fill-line card the first time the line is crossed.
- **The payout buys nothing.** The player spent their 20 Stars on the Toy Egg, so they now hold about 5. The cheapest next things are the Names Egg (8), the Customization Egg (12), the Stat Egg (15) and wearables (40 and up). The results screen says "TODAY ★ 5 earned", which looks back at today rather than forward to a next step.
- **Nothing new unlocks and the pet isn't involved.** The Bear does not react, level up, ask for anything or learn anything on screen. The pet garden the title promised is now a menu of machines.
- **No next goal is on screen.** The quests are "Finish 3 rounds" or "Score 600", and they live in Menu > Quests.

So the session ends at the first moment the game stops handing out novelty. That fits the curve: 30% are left at 3:20 and 24% at 5:00. **[guess, strongly suggested by the curve and the funnel together]** The hotfix's `FiveMinutes` event and the v3 "Second round done" step would confirm it.

**About the numbers that disagree:** 92% reach Bear met but only about 55% are still playing at 1:00, and 57% reach step 9 but about 40% remain at 2:00. These come from different groups: the funnel covers 7 days and includes rank-0 returners and test saves, while the retention curve covers 28 days and includes the large first ad bursts on older builds. **Don't over-read the gap.** Ship the funnel fix and read both again on the same week.

### What brings a player back on day 2 (live)

Every reason to return exists only as a number inside a menu:
- Daily stamp card: one stamp a day, and stamp 7 gives the free Bunny and ★12 (Menu > Quests).
- Daily quests: three a day at ★4 each.
- Stat Eggs: 3 a day.
- Petting: pays Stars 5 times a day.
- Play dates: 3 a day.
- A daily 2x XP bonus.

**Nothing in the world changes while you're away.** On live there is no notification (`ExperienceNotificationService` does not appear in the live `src`), no invite prompt (no `PromptGameInvite`), and nothing on the HUD or results screen that says "tomorrow". The research doc (`research/ONBOARDING-RESEARCH-2026-11-23.md` section 4) reached the same conclusion. The fix for it (the Sleepy Nest, welcome week, the "See you tomorrow" strip, follow-the-Bear) **is built on the beta, not live** (`ONBOARDING-V3-PLAN-2026-11-23.md`; beta 10, runtime e5edeb0).

### Likely drop-off points, ranked

1. **The end of round two.** The tutorial runs out of rewards, and the player has nothing to buy and no promise for tomorrow. This one sets D1.
2. **The 4-card garden tour at about 1:00.** It is the biggest measured leak: 21 to 32% of players who just met their pet.
3. **Ad expectation mismatch.** The ads show pets, outfits and a garden. The first 45 seconds are a merge puzzle on a handheld screen. **[guess]**
4. **Loading on phones.** This has never been measured. Ad traffic is mostly mobile **[guess]**.

---

## 4. The store listing today

| Asset | Live | File |
|---|---|---|
| Title | **Pocket Pals: Pet Garden** | `artifacts/store-listing/LISTING.md` section 1 |
| Description (869 characters, live since Nov 21) | Opens with: "Pocket Pals is a cozy merge game with cute pets to raise. Merge balls on your Pocket Deck to earn Stars, then dress up, train and play with your pals." | `artifacts/store-listing/v2-new-look/DESCRIPTION-v2.txt` |
| Icon | **Icon J**: Bear and Bunny, a deck with the Bubbles ball theme, glossy lowercase "pocket pals" wordmark | `artifacts/store-listing/v2-new-look/icons/icon-J.png` (TODO.md line 107) |
| Detail-page thumbnails | T1 to T7 (pocket pals / dress up / merge / hatch / play / decks / level up) | `artifacts/store-listing/v2-new-look/set/T*-*.png`; ids in `set/live-asset-ids.json` |
| Home Page thumbnail | T1 only (personalization off) | TODO.md line 107 |
| Ads | ad-A, ad-B, ad-C (paused) | `v2-new-look/set/ad-*.png` |

**Does the pitch read in 5 words? No.**
- The title says "pets in a garden". It does not say what you *do*.
- T1's tagline is four verbs ("merge · hatch · dress up · train") plus six chips ("clothes / colors / toys / decks / stats / & more"). That is a feature list, not a hook.
- The description needs a sentence and a half, plus an invented noun ("Pocket Deck"), before the core verb lands.
- **The game names its own core object three ways.** The description says "merge balls". The first-screen pill says "Match eggs. Hatch a friend." The Welcome card says "Drop eggs into the deck". A player can't repeat a pitch the game doesn't state consistently.

**The 5-word version the build actually supports:** "Merge balls. Hatch cute pets." It is honest, because the Welcome round literally hatches the Bear from merges. The stronger, more familiar framing is "Suika, but you hatch pets" **[guess; no test]**.

---

## 5. Plan, ranked

### A. Measure first (this week, no build needed except A1)

1. **Ship the funnel hotfix `cf9e7ee8`.** It is instrumentation only, spec green, code-review GO, and has its own off switch. Without it, steps 5 to 8 can't be read and nobody can tell whether sessions end at round two. It is on hold by Spencer's call, and this is the cheapest thing on the list.
2. **Creator Hub pages to read weekly** (labels as Creator Hub shows them):
   - **Analytics > Acquisition**: plays by source (Home / Search / Sponsored / Friends), impressions, and the **Thumbnail Performance** table (qualified play-through per thumbnail).
   - **Analytics > Engagement**: **new-user first-session retention** (% still in at 1, 2, 5 and 10 min), and session length for new vs returning players.
   - **Analytics > Retention**: D1 / D7 by cohort, **split by acquisition source**.
   - **Analytics > Funnels**: Onboarding (the 9 steps above), plus Custom events: `SessionRounds`, `RoundLost`, and after the hotfix `FiveMinutes`, `FirstPet`, `FirstHatch`.
   - **Home Recommendations / discovery**: the first-play bounce bands (under 60 s, 61 to 180 s). Roblox's discovery ranking counts these against the game (research doc section 1).
   - **Ads Manager**, per creative: impressions, CTR, clicks, plays, cost per play.
3. **What "good" looks like for a small new game.** These are rough targets. The D1 targets come from the research doc's sources; the rest are rules of thumb **[guess]**.

| Metric | Now | First target | Good |
|---|---|---|---|
| Sponsored CTR | 0.8 to 1.3% | 1.5% | 2%+ |
| Play-through (plays ÷ clicks) | ~10% | 20% | 30%+ (`v3-launch-v2/SCOPE.md` rule: stop if nothing beats 15%) |
| Still playing at 5 min (new users) | 24% | 40% | 50%+ |
| Average session, new users | 3.6 min | 8 min | 12+ min |
| D1 | 1.4% | 4 to 5% | 8 to 10% (median game); 12%+ |
| D7 | 0% | 1% | 3%+ |

4. **Keep ad spend off until a build shows D1 of 4% or more** (research doc recommendation 10). At 1% D1, every ad cohort tells the recommender that the game bounces. Paid installs that bounce probably hurt organic ranking **[anecdotal, DevForum]**.

### B. Cheap tests on play rate

- **Ad creatives are the only test with real traffic.** Home and Search impressions are 0, so thumbnail personalization and icon swaps have nothing to measure against yet. When ads resume, run one campaign with 2 to 3 thumbnails, decided on **plays ÷ impressions**, then on D1 of the cohort.
  - Creative 1: the literal first minute. A Suika board mid-merge with a Bear bursting out of the egg, headed "Merge balls. Hatch a pet."
  - Creative 2: the Bear's face, huge.
  - Creative 3: the current ad-A as the control.
- **Keep the promise matched.** Whichever creative wins becomes thumbnail 1 and the description's first line. Use the same nouns everywhere: pick "balls" or "eggs" and change the other two strings.
- **Personalization:** once Home impressions are non-zero, activate 2 to 5 Home Page thumbnails (T1, plus the winning ad art) and read qualified play-through per image.
- **Icon:** a 7-day A/B by swapping. It only means something once Search or Home traffic exists.
- **The 18+ ad audience is a known constraint, not a bug** (the 16+ label until 100 HEP). It still matters for planning. All benchmarks are from adults seeing a kids-styled game, so reaching 100 HEP is itself a growth milestone that opens the real audience **[guess at size of effect]**.

### C. First-session cuts that could ship as a live hotfix (ranked by expected effect on D1, then play rate)

Each one is small, and each can be built on a branch from `54dca26` like the funnel hotfix. Effects are **guesses**.

| # | Cut | Why | Expected effect | Size |
|---|---|---|---|---|
| 1 | **Give tomorrow a visible promise.** Before the player leaves, show it on every results screen and the garden HUD: "Tomorrow: Stamp 2 ★X · 3 new quests · 3 Stat Eggs". This is the "See you tomorrow" strip from onboarding v3, ported alone, using live data only (stamp card, quests). | Live has zero day-2 signals outside menus. The results screen is where sessions end. | D1: highest of the hotfix-sized items | S |
| 2 | **Delete the 4-card garden tour for new players.** Mark `gardenIntro` when the player arrives in the garden; keep "Show tips again". Optionally keep one line: "Tap {pet} to say hi". | The biggest measured leak, 21 to 32%. Text cards at the moment of meeting the pet. | 5-min retention up; D1 indirectly | S (client; `CoachCards.openTour` / `options.tour`) |
| 3 | **Make round two pay off.** Example: the first 3 wins after the Bear pay enough to buy the next egg (≥12 Stars), and the results screen names it ("Customization Egg: 0 more Stars → Hatch"). Or make round two the v1 scope's guaranteed "starter round" (one goal, can't be lost). | After round two the player can afford nothing. | 5-min retention, rounds per session | S (payout config, results nudge) |
| 4 | **Promote onboarding v3 from the beta** (follow-the-Bear, need bubbles, Sleepy Nest with fixed welcome-week gifts). | This is the real fix for D1: something you own grows while you're away. It is built and beta-tested, but it rides on the v3 feature branch with Things to do, so it is **not** a hotfix. | D1: highest overall | M to L (release, not hotfix) |
| 5 | **One name for the core object** across the pill, the Welcome card, the description and the ads. | Clarity, and the ad promise matching what the player sees. | Play rate and first-minute bounce, small | XS (copy plus a translation sync) |
| 6 | **Measure load time on a low-end phone.** | Never measured. A bounce here is invisible in the funnel, because step 1 fires on the server. | Unknown | XS |

### D. The 1 to 2 week spinoff option (sketch)

**"Merge Pets": the balls *are* the baby pets.** One Suika board. You drop baby pets, two of the same merge into the next bigger one, and the biggest tier hatches a new pet into your collection. One verb, one screen, and the 5-word pitch is the gameplay: **"Drop and merge cute pets."**

- **Reuse:**
  - The board sim (`BoardRound`, `BoardRoundSim`, `FieldRun`, the deck UI).
  - The Bear and Bunny rigs, recoloured with the dyes, as the higher tiers.
  - The hatch reveal stage and the Pop-Out stage for a new top tier.
  - `EggModels`, the collection book layout, `HeatPayout` and the Stars wallet, and `EconomyAnalytics` plus the funnel pattern.
- **Cut:** the garden, the machines, stats, the wardrobe, the Pet Park and the 3D avatar walking. The Roblox avatar just stands beside a big board, or the board is a full-screen 2D layer.
- **Day-2 hook:** a "nursery" shelf of the pets you've hatched. One egg on it grows offline (the Sleepy Nest idea, reused), and a daily board seed changes which pets drop.
- **Social:** a per-server shared high-score board with your best merge chain, plus a "Bring a friend: co-op board" invite.
- **Week 1:**
  - Fork the board into a new place.
  - Swap the ball themes for pet-face balls, using the existing themes as the base: `BallThemes` already has Kittens.
  - Add the top-tier hatch, the collection shelf and the funnel.
- **Week 2:** the offline egg, a share/invite prompt, icon and thumbnails, then $5/day on 2 creatives to compare play-through against Pocket Pals.
- **Why it might work [guess]:** it keeps the one part with proven first-minute retention (92%+ reach the Bear) and drops the systems players leave at.
- **Why it might not:** Suika-likes are crowded on Roblox, and a merge game alone may have the same 4-minute session ceiling. The offline egg is the part to test.

---

**Files referenced:**
- Live code: `git show 54dca26:src/server/FirstSession.lua`, `src/server/EconomyAnalytics.lua`, `src/server/init.server.lua`, `src/client/CoachCards.lua`, `src/shared/UICopy.lua`, `src/shared/CoachMarks.lua`, `src/shared/QuestCatalog.lua`, `src/shared/HeatPayout.lua`
- Plans and research: `FIRST-SESSION-FUNNEL-PLAN-2026-11-23.md`, `ONBOARDING-V3-PLAN-2026-11-23.md`, `ONBOARDING-V1-SCOPE-2026-11-13.md`, `research/ONBOARDING-RESEARCH-2026-11-23.md`, `research/FUNNEL-SNAPSHOT-2026-11-23.md`
- Build history and tasks: `PLAY-BUILD.md`, `TODO.md`
- Store listing: `artifacts/store-listing/` (`LISTING.md`, `v2/BRIEF.md`, `v3-launch-v2/SCOPE.md`, `v2-new-look/`)
- Live numbers: `artifacts/growth-2026-11-26/CREATOR-HUB-2026-11-25.md`
