# Onboarding research: first 60 s, first 5 min, first session (2026-11-23)

Research for Pocket Pals: Pet Garden. Live, 7 days: about 10 new players a day, nearly all from Sponsored Ads; 3.9 min average playtime; **D1 retention 1.04%**. The live funnel is in `research/FUNNEL-SNAPSHOT-2026-11-23.md`. This doc covers patterns from other games only. No other game's IP is copied.

Source quality is marked. **[R]** means Roblox's own docs or a staff post. **[A]** means an analyst or developer write-up. **[F]** means a fan guide: those details depend on the game version, so treat them as approximate.

## 1. Benchmarks

| Metric | Number | Source |
|---|---|---|
| D1, similar-game benchmark band (example) | 50th to 90th percentile: 12.4% to 24.1%, and 12.11% to 18.73% in a second example | [R] [Analytics get started](https://create.roblox.com/docs/en-us/production/analytics/get-started), [Analytics dashboard](https://create.roblox.com/docs/en-us/production/analytics/analytics-dashboard). Your own band appears at 100+ DAU |
| D1 / D7 / D30, median game with 1M+ MAU | 10.3% / 1.6% / 0.5% | [A] GameAnalytics 2025 report, via [GameDev Reports](https://gamedevreports.substack.com/p/gameanalytics-key-roblox-and-roblox) |
| D1 / D7 / D30, top 1% of games | 22.2% / 9.1% / 4.7% | same |
| The common "20% D1 is good" rule | Called inflated, because it comes from samples of games that already succeeded | same. [RoWatcher](https://rowatcher.com/news/retention-benchmarks-by-roblox-genre-what-good-actually-looks-like) also says it is genre-blind |
| D1 for short-session games (0 to 6 min) | Below 10% | [A] [GameAnalytics 2025 Roblox report](https://www.gameanalytics.com/reports/2025-roblox-report) |
| Effect of ad traffic | One developer's A/B by weeks, same build: D1 about 3% with ads against 5% to 8% without, and session length roughly halved. Others report 2.7% D1 from ads against 7% to 9% organic | [A] DevForum: [ads degrade metrics](https://devforum.roblox.com/t/sponsored-ads-traffic-degrades-the-engagement-metrics-used-for-discovery-causing-paid-acquisition-to-harm-organic-ranking/4838351), [thread cluster](https://devforum.roblox.com/t/sponsors-gaining-100-players-then-losing-all-shortly/3000999). Anecdotal |
| What discovery rewards (since 15 Jun 2026) | "Most important": play-through rate, **first-play bounce rate** (<60 s and 61 to 180 s, a negative signal), play days per user (D1, D2-7, D8-28) and playtime. "Important": **intentional co-play days**, qualified sessions and spend days | [R] [Discovery docs](https://create.roblox.com/docs/discovery), [announcement](https://devforum.roblox.com/t/recommended-for-you-algorithm-improvements-that-better-value-long-term-retention/4684575) |
| Plant (Roblox's reference game) funnel | Spawn to first seed planted: 100% to 29.5%. The fix was an icon over the pots | [R] [Improving onboarding through funnel events](https://devforum.roblox.com/t/improving-onboarding-through-funnel-events/3064458) |

**What "good" means for us.** Ad traffic is the hardest audience Roblox has. A realistic first milestone is **4 to 5% D1**, next **8 to 10%** (near the median of established games), and the stretch is **12% or more**, the bottom of the similar-game band. At 1% we are roughly 10 times below median. That is a design gap, not noise.

**Roblox's own FTUE guidance** [R] ([Onboarding](https://create.roblox.com/docs/en-us/production/game-design/onboarding), [Techniques](https://create.roblox.com/docs/en-us/production/game-design/onboarding-techniques)):

1. Teach only the essentials.
2. Get to the fun quickly with starter items, early progression and social motivators.
3. Leave players wanting more: show short, mid and long-term goals in visible places and end onboarding on a "moment of joy".
4. Prefer visual elements, such as arrows, trails, in-world signs and highlights, over text. Players "don't like to read instructions", and visuals work for young readers and on phones.
5. Use **contextual** (just-in-time) tutorials and **timed hints** for players who are struggling, rather than a fixed sequence.

The retention doc adds **performance** as one of the three D1 levers.

## 2. Per-game first-session teardown (short)

| Game | First minute | Tutorial delivery | First reward | Reason to come back tomorrow | Social | Mobile |
|---|---|---|---|---|---|---|
| **Grow a Garden** | Spawn by your own plot with a few coins. Buy a cheap seed from the shop NPC and plant it. Starter crops grow fast [F] | Almost none. The dev's line is that Roblox has "no time for tutorials" [A] | First harvest and sale within a couple of minutes [F] | **Crops grow while you're offline.** Called "a mechanic never seen before" that brings players back to see what grew [A]. The shop restocks every 5 min and weather events add check-in moments [F] | Plots sit side by side, so everyone sees your farm. Veterans gift fruit to newcomers [A] | One-tap plant and harvest; the interface is "easy enough for a wide age range" [A] |
| **Adopt Me!** | Pick Baby or Parent, then a short guided flow to dress up and get a first pet [F] | Short, forced and linear, then free roam [F] | A pet within the tutorial [F] | Pets **age up** through care tasks, so "your pet does not reset" [A]. A Task Board gives one task a day, stores up to 7, and three done earns a free egg [F] ([Uplift FAQ](https://upliftgames.helpshift.com/hc/en/3-adopt-me/faq/83-what-is-the-task-board-for)). Daily login reward with a streak [F] | Roleplay families, trading, houses you can visit | Need bubbles over the pet act as the to-do list, readable with no text |
| **Pet Simulator 99** | Break coins around spawn with a starter pet. Spend at once to open the next gate [F] | Arrows, gates and numbers; nearly no text | Seconds: coins burst on the first tap [F] | A playtime gift timer (a present icon with gifts every few minutes [A], [BIG Games](https://biggames.io/post/pet-simulator-99-update-9)), daily rewards, Saturday updates, time-limited free event eggs [F] | Trading plaza, flex of rare pets | Auto-target taps, huge buttons |
| **Dress to Impress** | Lobby, then a round with a theme, a timer and a dressing room (fan guides say about 6 min to style) [F] | None: the theme banner *is* the instruction; a hint card sits beside the timer [F] | Runway, everyone rates 1 to 5 stars, podium. Everyone earns currency by placement [F] | Rotating themes, so every round differs; currency for the wardrobe; events | Peer voting is the core loop: you play *for* an audience | Large item tiles; the round's pace hides slow controls |
| **Brookhaven RP** | Claim a free house, spawn a car, pick a role [F] | None. "No quest order" [F] | Instant: house and car are free [F] | **Friends.** Players come back to see people, not progress [A] | The whole game | Side menu of big icons |
| **Fisch** | Spawn with a rod; an NPC asks you to catch 3 fish [F] | One NPC quest, then free | First catch inside a minute: cast, click, reel minigame [F] | Bestiary to complete, the next rod to save for, rare-fish chances [F] | Shared docks, show-off catches | One-button cast and reel |
| **Blox Fruits** | Pick a faction; the nearest NPC gives "defeat 5 bandits" [F] | Quest-giver NPCs with tight, numeric goals | Level-ups within minutes [F] | Layered goals: level, then fruits, then trades [A] | Crews and trading | Combat on a tap |
| **Squishmallows** (Roblox doc example) | Collect plushies | **Contextual tutorial**: the combine tutorial fires only when you hold duplicates [R] | Collect on contact | Collection | Marketplace, taught only when found [R] | n/a |

## 3. Patterns that matter, ranked by expected D1 impact

1. **Something of yours changes while you're away, and you can see it coming** (GaG crops, Adopt Me aging, PS99 gifts). This is the single strongest return reason in the genre, and it is the one we lack.
2. **A concrete, visible promise for tomorrow, shown before the player leaves.** That means a timer on a thing in the world, not a line in a menu. Roblox calls this short and mid-term goals in "highly visible places".
3. **The player is in the core loop within seconds, with no text** (Brookhaven, PS99, Fisch, DTI). The first action pays out at once.
4. **The tutorial is the world, not cards.** Use in-world signs, trails, NPC asks and need bubbles. Teach each extra system only when the player meets it (contextual, timed hints).
5. **Persistent attachment** to an owned thing that grows: your pet, your plot, your house.
6. **Other people are visible and matter** (DTI voting, Brookhaven friends, GaG neighbours). Intentional co-play days is now a discovery signal.
7. **A short-term goal ladder on screen at all times** (Blox Fruits' "5 bandits", Fisch's "3 fish", PS99's next gate).
8. **One-tap mobile controls and readable visuals.** Performance counts as a D1 lever in its own right.

## 4. What our current first session gets wrong (blunt)

The live funnel (157 users, 7 days) goes Board ready 100%, First drop 91%, Bear met 89%, **Garden walkthrough done 68%**, First machine 61%, Quest claimed 57%, First spend 57%, Second round 50%. Steps 6 to 9 are slightly inflated, because a later step auto-completes earlier ones.

- **The first 60 seconds work. Stop spending effort there.** 89% meet the Bear. Instant deck, seeded merges and a mystery egg are a strong opening, at Brookhaven/PS99 level.
- **The session holds, the day doesn't.** Half of all new players start a second round, yet 1% return. The game gives nobody a reason to come back. Our tomorrow hooks (the stamp card with ★ 12 at stamp 7, three daily quests, the daily gift) are all **numbers inside Menu > Quests**. Nothing in the world is unfinished when you leave, and no pet-shaped promise is waiting. Pattern 1 is missing entirely and pattern 2 is buried.
- **The garden walkthrough is the biggest in-session leak.** It loses 24% of players who just met their pet. It is a five-slide text tour (Machines, Say hi, Quests, Customize, Things to do), shown at the exact moment the player wants to touch the Bear. Every top game above teaches by doing. Roblox's own guidance says text gets skipped.
- **"Hatch your first egg" is a pill pointing at a menu.** It is a shopping errand, not something the Bear wants, so the pet isn't driving the session.
- **No mid-term goal shows on the HUD.** Players don't see "Bear learns a trick at level 2" or "your hat is 2 Stars away" while playing.
- **Social is invisible in session one.** Pet Park, the Bear's toy that others can see and the Dash are never shown with other people.
- **Session length of 3.9 min sits inside the "short-session games, D1 under 10%" band,** and discovery penalises 61 to 180 s bounces. The second round is where sessions end: we have no step after "Second round started".
- **Ad mismatch risk.** If the ad shows pets in a garden and the first screen is a puzzle board, some bounce is expectation mismatch. Ad cohorts also retain about half as well as organic ones (section 1), so judge changes on funnel steps, not only on D1.
- **Data check.** The funnel counts 157 users in 7 days, but about 10 new users a day is roughly 70 a week. Confirm that step 1 fires only for truly new players, for example not for old accounts that get a fresh save after a wipe.

## 5. Recommendations, ranked by impact/effort

Constraints: one Stars wallet; no paid randomness; no Robux skips on timers; kid-safe (no streak loss, no guilt, no fake urgency). S/M/L is build effort.

**1. Bear's Sleepy Nest: the "come back tomorrow" hook. Impact: highest. Effort: M.**
- **At about 3:00**, on the first results screen after the starter round: the Bear yawns, waddles to a nest beside its bed spot in the garden and tucks in a **Sleepy egg**.
- **What's inside is shown, not random.** For example: "Bear's first hat + ★ 10". The hat appears as a silhouette on the egg, and the Bear wears a ghost preview for 2 s.
- **The nest is a world object with a clock:** "Ready in 8 h". It sprouts in three visible stages, the way GaG crops grow offline. Other players walking past see it.
- **Ready means 8 h after it was tucked in or more,** so "tomorrow after school" always works. There is no expiry and no Robux skip, ever.
- **Day 2 claim** is a hatch at the nest with the existing reveal stage. The Bear puts the hat on at once, a moment of joy. A new Sleepy egg is then tucked in for day 3, with a different known item.
- **Seven nests make a "welcome week"** of fixed, previewed items: a hat, a toy, a colour jar, a charm, ★ and so on. This fits one wallet, because every Star is fixed, and it fits no paid randomness.

**2. A "See you tomorrow" strip on every results screen and on the garden HUD. Impact: high. Effort: S.**
- From the first round on, show three items with icons: **nest timer**, "Stamp 2: ★ X", and "3 new quests".
- Re-show the strip when the player idles for 60 s or opens the Pocket menu after the 5:00 mark.
- Roblox can't show UI as a player quits, so the promise has to already be on screen before they leave.

**3. Replace the five-card garden tour with "follow the Bear". Impact: high, because this is the 24% leak. Effort: S to M.**
- **At 0:00 in the garden:** zero cards. The Bear hops and looks back, and paw prints lead to the Hatch machine (the existing **Show me** trail).
- **On arrival:** one 8-word contextual line ("Bear found an egg machine!").
- **The other machines get one-line contextual tips** the first time the player walks within 14 studs, using the existing `StationAttract` and `coachMask` once-bits.
- **Timed hint:** after 20 s idle, the Bear chirps and the prints replay.
- **The "Say hi" line becomes a hand icon over the Bear** that loops until the first pet.
- Keep "Show tips again" in the Menu for anyone who wants the full tour.

**4. Make the Bear the quest-giver. Impact: medium-high. Effort: S.**
- Replace the "Hatch your first egg" pill with a need bubble over the Bear, the way Adopt Me's bubbles work: a ball icon means "Bear wants a toy".
- Tapping the bubble lays the trail to Hatch eggs. Buying the Toy egg and pressing "Give to Bear" closes the bubble with play hearts.
- Next bubbles: "play again" (deck icon), then "sleepy" (nest), which leads into rec 1.

**5. Opt-in experience notification for the nest. Impact: medium (13+ only). Effort: S.**
- Right after the nest is placed, show one Roblox opt-in prompt ([ExperienceNotificationService](https://create.roblox.com/docs/en-us/production/promotion/experience-notifications)). The text is personal and actionable, which is what Roblox's guidelines require: "{pet}'s Sleepy egg is ready to hatch!"
- Send it only when the nest is actually ready. No time pressure and no bait.
- Eligibility starts at 100 visits, which we already have.

**6. A goal ladder on the HUD. Impact: medium. Effort: S.**
- One line under the wallet, always the next nearest goal: "Hat: 2 more Stars", then "Bear Lv 2: learns a trick", then "Nest ready in 6 h".
- The mid-term goal is a pet growth stage on day 2 or 3. That is Adopt Me's "your pet does not reset" pull, using the levels track.

**7. Fix the end of round two. Impact: medium. Effort: S.**
- The session stops near the second round. Keep round 2 short, with one goal and the fill line taught by a timed hint.
- End round 2 on the near-miss wardrobe item plus the tomorrow strip, not on a plain results screen.
- Log "Second round done" so we can see it (section 6).

**8. Show other people in session one. Impact: medium. Effort: S.**
- At about 4:00 to 5:00, with the toy given: "{pet} wants to meet friends" opens the Pet Park bubble.
- If another player is in the server, their pet waves at yours with a two-pet heart pop.
- After the first play date, offer one game invite (`SocialService:PromptGameInvite`) with the line "Bring a friend's pet tomorrow". Co-play days count toward discovery.

**9. Phone pass on the first 5 minutes. Impact: medium (most ad traffic is mobile). Effort: S.**
- On a low-end phone: frame rate in the garden with Alive, life and Aero on; tap targets on the nest, bubble and trail; no text under 14 pt.
- Roblox lists performance as a D1 lever.

**10. Match the ads to the first screen, and judge by cohort. Impact: medium on D1, high on cost. Effort: S.**
- The ad creative should show the deck-to-pet moment that really happens in the first 40 s.
- Watch D1 per source on the Acquisition page.
- Hold spend flat until a build shows 4% or more. At 1%, each ad cohort mostly teaches discovery that the game bounces.

**11. A free daily check-in moment in the world, not the menu. Impact: low-medium. Effort: S.**
- The stamp card becomes a mailbox by the arch with a flag up when today's stamp is waiting.
- Keep "Miss a day, lose nothing" visible. Its only job is to make the stamp visible.

**Build order:** 3 and 4 (the in-session leak, small), then 1, 2 and 5 together (one "tomorrow" slice), then 6 and 7, then 8, 9, 10 and 11.

## 6. What to measure (Roblox onboarding funnel)

**Fix first.** `LogOnboardingFunnelStepEvent` auto-completes earlier steps, so the onboarding funnel must be **strictly linear**. Things that can happen in any order (machine, quest, spend) belong in a separate `LogFunnelStepEvent` funnel or in custom events ([Funnel events](https://create.roblox.com/docs/en-us/production/analytics/funnel-events)). Events are server-only and only count in published places.

**Onboarding funnel (linear, first session):**
1. BoardReady
2. FirstMerge
3. BearMet
4. InGarden (character spawned)
5. FirstPet (first petting)
6. FollowedBearToMachine (reached the Hatch machine via the trail or on their own)
7. ToyGiven (first spend done and the toy handed to the Bear)
8. NestTucked (Sleepy egg placed and the timer seen)
9. SecondRoundDone
10. FiveMinutes
11. TenMinutes

**Day-2 funnel** (`LogFunnelStepEvent "Return"`):
1. JoinedLaterDay
2. NestHatched
3. RoundPlayedDay2
4. NewNestTucked

**Custom events** (`LogCustomEvent`):
- Tour or tip dismissed, and which one.
- Skip pressed.
- Notification prompt shown, then accepted.
- Bubble tapped.
- Show-me trail used.
- Idle hint fired.
- Session-end beat: the last step reached before leaving.

**Dashboards to watch:**
- Engagement: **new-user first-session retention**, the % still playing at N minutes ([staff post](https://devforum.roblox.com/t/analytics-new-user-first-session-retention-new-and-returning-users/2890832)).
- Retention: daily cohorts and D1 by acquisition source.
- Home Recommendations: first-play bounce in the <60 s and 61 to 180 s bands.

**Sample size.** At about 70 new players a week, Roblox Experiments can only detect very large effects. Ship changes one at a time and compare weekly cohorts. Use per-step funnel deltas of 10 points or more as the in-session signal, and D1 as the slow confirmation.
