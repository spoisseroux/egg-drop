# Growth cuts: look and copy (Fable, 2026-11-25)

Direction for Opus, for `hotfix/v1055` (live runtime `54dca26` plus the two fixes). It covers cuts 1, 2, 3 and 5 of
`DIAGNOSIS-REPO.md` section 5C. Nothing here needs new art: every icon, colour and font is already in `DeckKit`.
No machine, card or layout is borrowed from another game.

`[check]` marks something Opus confirms in the code or Studio before building on it.

**Why these four.** Sessions end on the first plain results screen (24% left at 5:00, D1 1.36%). At that moment the
player holds about 0 to 8 Stars, can buy nothing, and nothing on screen mentions tomorrow. Before that, the 4-card
tour loses 21% of players who just met their pet.

**Switches.** One `FeatureFlags` entry per cut, all `true` in the hotfix: `TomorrowStrip`, `GardenTourCut`,
`StarterBonus`. Off = today's behaviour exactly. The naming cut (section 4) is copy only and has no switch.

---

## 1. The Tomorrow strip

### What it says

Up to three chips, icon first, read left to right. Live data only: the stamp card, daily quests, Stat Eggs.

| Chip | Icon (`Kit.icon`) | Normal text | Data |
|---|---|---|---|
| Stamp | `check`, tint `accent` | `Stamp {count}  ★ {reward}` | `StampCard.position` / `.reward` of the **next** stamp |
| Quests | `quests`, tint `text` | `{count} new quests` | `{count}` = 3 (`#QuestCatalog.Pools`) |
| Stat Eggs | `egg`, tint `text` | `{count} Stat Eggs` | `{count}` = `StatEggCatalog.DailyBuys` (3) |

The eyebrow `TOMORROW` sits in front of the chips (same style as today's `TODAY` label: 12 px, `soft`).

New `UICopy` keys, section `tomorrow`:

| Key | String |
|---|---|
| `tomorrow.label` | `TOMORROW` |
| `tomorrow.stamp` | `Stamp {count}  ★ {reward}` |
| `tomorrow.stampPet` | `Stamp 7  {pet} + ★ {reward}` |
| `tomorrow.stampToday` | `Today's stamp  ★ {reward}` |
| `tomorrow.quests` | `{count} new quests` |
| `tomorrow.claim` | `{count} to claim` |
| `tomorrow.claimOne` | `1 to claim` |
| `tomorrow.statEggs` | `{count} Stat Eggs` |
| `tomorrow.rail` | `Tomorrow: Stamp {count} ★ {reward} · {quests} new quests` |
| `tomorrow.railToday` | `Today's stamp is waiting  ★ {reward}` |
| `tomorrow.notice.title` | `See you tomorrow` |
| `tomorrow.notice.what` | `A new stamp, three new quests and three Stat Eggs arrive every day.` |
| `tomorrow.notice.next` | reuse `stamp.promise`: `No streaks. Miss a day, lose nothing.` |

### When a piece has nothing, or something better to say

| Case | What shows |
|---|---|
| Today's stamp **not taken** (`dailyAvailable == true`) | Stamp chip reads `tomorrow.stampToday` with today's reward, in `stars` gold. It sits **before** the `TOMORROW` eyebrow, because it is a today thing. A tap opens Quests. |
| Today's stamp taken | `tomorrow.stamp` with the next position and reward. |
| Next stamp is number 7 and the Bunny is not owned (`EarnedPets` enabled) | `tomorrow.stampPet`, `{pet}` = the earned pet's name. This is the best line the live game has; give it the `paw` icon instead of `check`. |
| Card just filled (stamp 7 taken today) | `tomorrow.stamp` with `{count}` = 1 and its reward. No "card full" wording here. |
| A daily quest is **ready to claim** | Quests chip reads `tomorrow.claim` / `claimOne` in `accent`, before the eyebrow like the stamp. A tap opens Quests. |
| All three dailies claimed, or none ready | `tomorrow.quests`. |
| Stat Eggs off (`StatEggCatalog.Enabled == false`) or no pet | No Stat Egg chip. The other two centre. |
| Results still saving (`data.pending`) | Strip hidden until the save lands. |
| Snapshot missing (`nurseryState` nil) | No strip. Never a chip with a made-up number. |

Chips are never a step the player must press. Only the two "today" variants take a tap (44 px tall hit area on
touch); the tomorrow chips are plain labels.

### Where: the results screen (`DeckResultsInPlace`, the live one)

Today the LCD holds three panes: Payout (left), Star (middle), Goals and the four buttons (right).

**PC, tablet, console (`g.phone` false).** One row across the bottom of the LCD, from the Payout pane's left edge to
the Goals pane's right edge.
- Height **36 px**, 6 px gap above it. The three panes each give up 42 px of height. The wallet chip and the action
  grid keep their place at the foot of their (now shorter) panes.
- Look: the same tray as the panes (`raised`, corner 10, 1 px stroke at .75). Eyebrow at the left, 12 px `soft`.
  Chips 14 px `BodyMedium`, icon 18 px, 6 px between icon and text, 20 px between chips. One line, no wrap.
- If the three chips do not fit the width, drop the Stat Egg chip first, then shorten nothing else.
- In: fades up 8 px over 0.25 s, **1 s after the count-up ends**, so it is the last thing to arrive and the eye
  lands on it. Reduced Motion: no slide, fade only.
- The pane's old `★ {count} earned` today line stays.

**Phone (`g.phone` true), landscape and portrait.** The panes are already tight (the goals pane was fixed once for a
263 px height), so nothing gets shorter.
- The strip becomes a **block in the Payout pane**, in place of the `★ {count} earned` line (that line looks back;
  this one looks forward). Position: where `self.today` sits, 8 px under the Total.
- Eyebrow `TOMORROW` 11 px `soft`, then one chip per line, 12 px, icon 14 px: stamp, then quests. **No Stat Egg
  chip on phones.** The stat gains move down under the block. The pane already scrolls.
- A "today" variant (unclaimed stamp, quest to claim) goes on the first line, gold or accent, with a full-width
  44 px hit area.

**Legacy `DeckResults` card** (only reached when the deck gives no in-place view) `[check: can live still reach
it?]`. If yes: the come-back strip's left cell swaps `TODAY / ★ N earned` for `TOMORROW / <stamp chip text>`.
Nothing else moves. If no: skip.

It shows on **every** field-round results screen, win or lose, for every player, not only new ones.

### Where: the garden

Not a permanent HUD element. One **rail line, once per session**, through the existing `NotificationRail` (so it
obeys the calm-rail rules: one line at a time, never over a card, a menu, a reveal or a round).
- **When:** the first time the player is free in the garden after seeing a results screen, or 4 minutes into the
  session, whichever comes first. (The beta waits for 5 min + 60 s idle; on live most players have left by then.)
- **Text:** `tomorrow.railToday` if today's stamp is not taken, else `tomorrow.rail`. Icon `check`.
- **Tap:** opens a notice card (`tomorrow.notice.*`) with one button, `notice.go.quests`.
- **Time on screen:** `Cards.Duration` (7 s). Lowest priority: any onboarding line goes first.

---

## 2. The garden tour, cut

**New players see no cards in the garden.** With `GardenTourCut` on, `CoachCards` never calls `options.tour` by
itself and never runs the three beat lines (machines, hub, quest).

**What replaces it: one rail line.**

| Key | String | Input |
|---|---|---|
| `coach.sayHi.touch` | `Tap {pet} to say hi` | Touch |
| `coach.sayHi.key` | `Press E near {pet} to say hi` | Keyboard |
| `coach.sayHi.pad` | `Press X near {pet} to say hi` | Gamepad |

- `{pet}` = the companion's name (`Bear` by default), as `Cards.copy` fills it today.
- Icon `paw`, tint `companions`. No `?`, no notice card behind it; a tap on the line just closes it.
- **Appears** when the old tour would have opened, minus the stand-still wait: free in the garden, no menu, reveal
  and greeting shot over, `Coach.GardenSettle` (2.5 s) passed. It does not wait for the player to stop walking,
  because it blocks nothing.
- **Disappears** on the first of: the player says hi (first pet accepted), 12 s on screen, a menu or the deck opens.
  It is not shown again, this session or later.
- **`gardenIntro` is saved the moment the line appears.** Everything that waits for "the tour is over" keeps
  working. Funnel step 5 ("Garden walkthrough done") will now read close to 100%: note the date in the funnel log so
  nobody reads it as a win by itself. The number to watch is step 4 to step 6.
- **After it:** the "Your first Stars" toast, then the existing `Hatch your first egg` pill, in the rail's normal
  order and gap. Unchanged.

**Kept, untouched:** "Show tips again" (`r3.tips`) in the Pocket menu and Settings still opens the four "Your
garden" cards. The Welcome pill on the deck, the fill-line card, the machine first-visit lines, "A friend arrived".

**Who gets what:** a save with `gardenIntro` already set sees no change. A save that owns the Bear but never
finished the tour gets the one line, not the cards. Veterans (`Coach.VeteranWins`) get nothing, as today.

---

## 3. Round two pays off

### Live numbers today (read from the worktree)

| Thing | Stars |
|---|---|
| Fresh save | 6 |
| The Bear arrives (`CoachMarks.WelcomeStars`) | +14, wallet 20 |
| Toy Egg (`ToyCatalog.Cost`), the first-egg guide's egg | 20, wallet **0** |
| Round win, Medium (the default heat): plain / tidy | 6 / 8 (Easy 5 / 6, Hard 9 / 12) |
| Missed round: a goal met / good effort / neither | 2 / 1 / 0 |
| Stamp 1, one daily quest | 4, 4 (both inside Menu > Quests) |
| Customization Egg (`LookEggCatalog.Price`) | **12**, the cheapest egg on the Hatch eggs list |
| Stat Egg (`StatEggCatalog.Price`), 3 a day | 15 |

So after round two a typical new player holds 6 to 8 Stars, and a player who lost holds 0 to 2. Nothing costs
less than 12.

### The change: a Welcome bonus on the first three rounds

A flat extra row on the results payout, for the **first three finished field rounds of a save** (the Welcome round
is not a field round and does not count):

| Field round on the save | Bonus | Worst case wallet after it (Toy Egg bought, round lost, nothing claimed) |
|---|---|---|
| 1st (the player's "round two") | **+12** | 12: exactly the Customization Egg |
| 2nd | **+4** | 4 (after buying that egg), 6 to 12 with a win |
| 3rd | **+4** | enough for the next egg with two ordinary wins |

Typical path: round two won on Medium pays 6 + 12 = **18**. Buy the Customization Egg (12), 6 left. The next win
pays 6 + 4 = 16 in the wallet, enough for a Stat Egg (15). That is three things hatched in the first three rounds.

**Rules that keep it safe.**
- **20 Stars per save, once, ever.** That is one Toy Egg. A casual week earns about 200.
- **Brand-new saves only.** Counted in a new optional save field (`starterRounds`, 0 to 3, tolerant like
  `coachMask`). A save that has it missing **and** already has any finished round in its lifetime stats is treated
  as 3: existing players get nothing. `[check: the lifetime rounds counter; BookCatalog reads stats.rounds]`
- **Paid win or lose,** on any round that reaches the results screen. The players we are losing are the ones who
  lost round two.
- **Flat.** Not multiplied by difficulty, not doubled by the 2x Stars pass, no Supporter +1 on top of it.
- **Paid inside the round's award transaction** (where `MissPay` is paid), so a retried save can never pay twice.
- No change to any price, to `HeatPayout.Win` / `TidyWin` / `MissPay`, or to `WelcomeStars`.
- Logged to `EconomyAnalytics` as its own source (`StarterBonus`) so the Stars are not read as round income.

**On the payout pane.** Its own row, **first** in the list, gold (`stars`) text:

| Key | String |
|---|---|
| `results.starter.row` | `Welcome bonus` |

Amount in the right column like the others (`+12`). The pane builds four rows today; make it five, the list
already scrolls. A lost round with the bonus is not a zero payout: the Star stays gold, not glass.

### The nudge line

One line in the **Star pane, where "Tucked into your wallet" sits** (`self.saved`). While saving it still reads
`Saving…`. Once saved it becomes the nudge. 12 px, centred, up to two lines on a narrow phone column.

| Key | String | When |
|---|---|---|
| `results.next.ready` | `{egg}: you have enough!` | wallet >= the egg's price. Text in `stars` gold. |
| `results.next.short` | `{egg}: {count} more Stars` | wallet below the price |
| `results.next.shortOne` | `{egg}: 1 more Star` | exactly one short |

- **Which egg:** the Toy Egg (20) if the player owns no toy yet, otherwise the Customization Egg (12). The current
  `eggName` / `eggCost` code says "cheapest egg" but always picks the Toy Egg; change it to this rule.
  `[check: when the Customization Egg is not ready or restricted, fall back to the Toy Egg, then to no line]`
- `{count}` = price minus the wallet after this round's payout.
- **When ready, during the Welcome bonus rounds only:** the `Hatch eggs` button becomes the primary (gold) button
  and holds the default focus instead of `Replay`. After the third round `Replay` is primary again; the line stays.
- The `Hatch eggs` button should open the list with that egg selected `[check]`.
- Shown to every player on every field-round results screen. "Tucked into your wallet" is dropped; the wallet chip
  counting up already says it.

---

## 4. One name: balls

**The things you drop are balls. Eggs are what you hatch.** The live description, Deck style ("Faceplates,
backgrounds and balls"), the Collection book and `BallThemes` already say balls. "Egg" already means two real
things the player meets later (the mystery egg that cracks, and the eggs sold at Hatch eggs). Only the first minute
calls the balls eggs. The verb is **merge** everywhere (the description's word), not "match".

| Key (`UICopy`) | Old | New |
|---|---|---|
| `qa.coach.welcome` (the first-screen pill) | `Match eggs. Hatch a friend.` | `Merge balls. Hatch a friend.` |
| `notice.welcome.what` (the Welcome card) | `Drop eggs into the deck. Two of the same kind merge into a bigger one.` | `Drop balls into the deck. Two of the same kind merge into a bigger one.` |
| `notice.fillLine.next` | `Merge to make room, and drop each egg next to its match.` | `Merge to make room, and drop each ball next to its match.` |
| `onboarding.welcome.match` (the Welcome board prompt) | `Match` | `Merge` |

**Left as they are, on purpose** (the egg in them is a real egg): `onboarding.welcome.egg` "Mystery egg",
`coach.welcome.line` "Merge to crack the egg. Stars come with it.", `notice.welcome.next`, `r1.welcomePill.*`,
`notice.pill.firstSpend` "Hatch your first egg", and every Hatch eggs string.

`[check]` Search the client for hard-coded first-round text outside `UICopy` (`init.client.lua` status lines,
`DeckScreen`), and look at the default ball theme on a new save: if the default balls are drawn egg-shaped, tell
me before shipping the copy, because then the art and the word disagree and the fix is the theme, not the string.

**Store description: DRAFT, needs Spencer's OK before it is posted.** Only the first line changes. The rest of
`artifacts/store-listing/v2-new-look/DESCRIPTION-v2.txt` already says balls.

- Old: `Pocket Pals is a cozy merge game with cute pets to raise. Merge balls on your Pocket Deck to earn Stars, then dress up, train and play with your pals.`
- **Draft:** `Merge balls. Hatch cute pets. Your first friend hatches in your very first round. Earn Stars, then dress up, train and play with your pals.` (139 characters; the total stays under 950.)

Ads and thumbnails: when campaigns resume, the headline on any new creative is the same five words, `Merge balls.
Hatch cute pets.` That is a separate job with its own OK and is not part of this hotfix.

---

## 5. Before it ships

- **Translations:** 19 new strings and 4 changed ones. Run the export and sync steps and record the counts in the
  PLAY-BUILD entry.
- **Text fit:** check every new line with `PseudoLocale` on in Studio, on a 750 x 402 phone and at 1280 x 720. The
  longest are `tomorrow.stampPet`, `tomorrow.rail` and `results.next.short` with "Customization Egg".
- **Screens to capture for my review** (actual renders, phone and PC):
  1. Round-two results, won, new save: the Welcome bonus row, "Customization Egg: you have enough!", gold
     Hatch eggs button, the Tomorrow strip.
  2. Round-two results, lost with no goal met: bonus row +12, the Star gold.
  3. Results with today's stamp not taken, and with a quest to claim.
  4. Results the day stamp 7 is next (Bunny line).
  5. The garden with the say-hi line, and the garden with the Tomorrow rail line.
  6. A veteran save: no bonus row, no say-hi line, the strip present.
- **What should move:** step 4 to step 6 of the funnel (was 78.6% x 88.3%), still playing at 5 minutes (24%),
  rounds per session, and D1 (1.36%). Read them a week after the hotfix, same week for both the funnel and the
  retention curve.
