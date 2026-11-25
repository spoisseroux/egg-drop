# G2: the first session, look and copy (Fable, 2026-11-25)

Direction for Opus, for the live line (`growth/v1056`), built **after G1 lands**. Scope: rows 1 to 3 of the G2 table
in `RETENTION-TODAY.md`. Row 4 (stale module copies) is place hygiene with no look and no switch.
It sits on top of `GROWTH-CUTS-LOOK.md`: G1's say-hi line, Tomorrow strip, Welcome bonus and nudge stay as written.
No new art: the paw is `Kit`'s vector paw, the ring and hop are `StationAttract`'s, the hearts are `PetAffection`'s.
No trail, arrow or layout is borrowed from another game.

`[check]` = Opus confirms in the code or Studio before building on it.

**The gap this closes.** After the Bear, the player lands in the garden with the pet off to one side and nothing
pointing at it; the pill then asks for a "first egg" seconds after an egg hatched; and before all of that the first
Deck screen shows about 15 panels around a 3-drop round.

**What I found in the code (it shapes the spec).**
- There is no path, trail or "Show me" in the game today. The only pointing language is `StationAttract`
  (marker, light shaft, ground ring, hop). The pet gets the same language, plus one new thing: paw prints.
- Petting already pays `+1 ★` (5 a day) with a gold sparkle and a chime (`PetAffection`, `UICopy pet.star`).
- The Bear arrives with a wallet of exactly 20 = one Toy Egg. So the pill is already affordable in the garden;
  the "back to the deck" nudge belongs **after** the toy, not instead of it.
- The first Deck screen is the `Welcome` phase (`snapshot.phase=="Welcome"` and `owned==0`, the test
  `Screen:setWelcome` already uses). That is the gate for section 3.

---

## 1. The way to the pet

### 1a. Paw prints (switch `PetTrail`)

A short line of paw prints on the grass, from the player's feet to the pet. It shows **with** G1's say-hi line and
under the same conditions (free in the garden, reveal over, `Coach.GardenSettle` passed, new player, not a replay).

| Thing | Look |
|---|---|
| Prints | `Kit`'s paw, flat on the ground, 1.1 studs, 2.2 studs apart, stepping left and right of the line by 0.35 like real tracks. Warm cream (`#FFF4DC`), 35% see-through, matte: no neon, no glow, no light. `[check: the vector paw can draw on a ground SurfaceGui; else bake one 128 px paw image]` |
| Length | Starts 3 studs ahead of the player, ends 2.5 studs short of the pet. At most 12 prints (the 12 nearest the player). Under 6 studs from the pet: no prints, ring only. |
| Motion | A soft "walk": every 1.6 s each print in turn swells to 1.15 and back (0.12 s apart), running toward the pet. Reduced Motion: still prints, no swell. |
| Ground | Each print sits on the ground under it (ray down). A print with no lawn under it (water, a machine, a wall) is skipped. Straight line; it is a hint, not a route. |
| Follows | Redrawn when the player has moved 3 studs or the pet 2. Pooled parts, client only, no remotes. |
| At the pet | `StationAttract`'s ground ring at 2.2 studs radius in the `companions` tint, one ripple every 2.4 s, and the pet turns to face the player. `[check: an existing look-at or coo pose; no new animation]` No light shaft: the pet is the bright thing. |
| Pet off screen | One round chip (36 px, `raised`, paw icon, `companions` tint, small pointer) pinned to the screen edge on the pet's side. It goes the moment the pet is on screen. No text. The camera is never taken. |

**When it goes** (first of): the first hello lands; 30 s; a menu, the deck or a machine opens. Prints fade over 0.4 s,
nearest the player first. It is shown once per save (it rides `gardenIntro`, which G1 saves when the line appears).
The say-hi line still leaves at 12 s; the prints outlast it on purpose.

### 1b. The first hello (switch `FirstHelloBonus`)

The first paid pet on a new save is a bigger moment than every pet after it.

- **Hearts:** the six-heart bond burst (`PetAffection` bond hearts, the pet's secondary colour) plays with the usual
  gold sparkle and chime. Reduced Effects: no hearts, the text carries it.
- **Text over the pet** (where `+1 ★` floats today), gold, held 1.6 s:

| Key | String |
|---|---|
| `pet.hello` | `First hello! +{count} ★` |

- **Yes, a number: 3 Stars** (the usual 1, plus 2). The wallet chip counts 20 to 23 in front of the player, which
  teaches "{pet} pays Stars" in one tap. After the Toy Egg the player holds 3, so a **lost** round two (G1's +12)
  leaves 15: a Stat Egg or a Customization Egg either way.

**Rules that keep it safe.**
- **Once per save, ever, decided on the server.** A new optional save field (`firstHello`, tolerant like G1's
  `starterRounds`); never a coach bit the client can mark. A save where it is missing **and** that has any petting,
  any finished round, or `gardenIntro` already set is treated as done: existing players get nothing.
  `[check: a lifetime petting or bond counter to read]`
- **Paid inside the petting award** (`HatchProgress.awardPet`), so a retried save cannot pay twice, and only an
  accepted, server-timed pet earns it. It counts as one of the day's five pets.
- **Flat +2.** Not doubled by the 2x Stars pass, no Supporter bonus. The client only shows what the receipt says.
- Logged to `EconomyAnalytics` as its own source (`FirstHello`). Total gift per save with G1: 22 Stars.
- No price, payout or `WelcomeStars` changes.

### 1c. Then what (the order after the hello)

1. Hearts and `First hello! +3 ★` (about 2.5 s). Nothing else speaks.
2. G1's order continues: the "Your first Stars" toast, then the pill, now reading **`Hatch a toy for {pet}`**
   (section 2). The player has 23 Stars; the pill's card opens Hatch eggs on the Toy Egg, as today.
3. The existing toy handoff plays (the pet gets the toy in the garden). Unchanged.
4. **The round-two nudge** (switch `RoundTwoNudge`): a status pill on the rail, same place and style as the
   toy pill, icon `deck` `[check: the Kit icon name]`, tint `accent`.

| Key | String | When |
|---|---|---|
| `coach.roundTwo.bonus` | `Round two: ★ {count} Welcome bonus` | A toy is owned, `StarterBonus` on, no field round finished. `{count}` = the first bonus (12), read from `StarterBonus`, never typed in. |
| `coach.roundTwo.toy` | `Round two: hatch a toy for {pet}` | No toy and not enough Stars for the Toy Egg (stage `earn`). |
| `coach.roundTwo.plain` | `Play round two on your Pocket Deck` | A toy is owned and `StarterBonus` is off or already used. |

- **Appears** when `FirstSpendGuide` reaches `done` (after the toy handoff), or is at `earn`, on a save with **no
  finished field round** that is not a veteran, free in the garden, 2.5 s after the last toast. Never at the same
  time as the toy pill: that pill goes first.
- **Tap:** straight into a round (`clientUI.playRoundForStars()`), no card in between.
  `[check: a rail status can carry a direct action; if it must open a card, reuse notice.go wording "Open the Pocket Deck"]`
- **Stays** until the first field round starts, then never again. It comes back next session if the player left
  before round two.
- **If the player stands still for 20 s with it up:** the paw prints draw once more, this time to where a round
  starts in the garden `[check: the Pocket Deck spot; if there is none, skip this]`, for 20 s. Same look, same rules.

---

## 2. The pill rename (switch `ToyPillCopy`)

| Key | Old | New |
|---|---|---|
| `notice.pill.firstSpend` | `Hatch your first egg` | **`Hatch a toy for {pet}`** |
| `notice.firstSpend.title` | `Your first egg` | **`A toy for {pet}`** |
| `notice.firstSpend.what` | `You have enough Stars for an egg. A Toy Egg hatches a toy for {pet} to carry and play with.` | **`You have enough Stars for a Toy Egg. It hatches a toy for {pet} to carry and play with.`** |

- `notice.firstSpend.next` stays (`Open Hatch eggs and choose the Toy Egg. The odds are on every label.`).
- `{pet}` = the companion's name, filled the way `Cards.copy` fills it (`Bear` by default). The pill is built once
  today with no variables (`init.client.lua`, `Copy.get("notice.pill.firstSpend")`): pass the name, and refresh the
  text if the name changes while it is up.
- So the switch is real: keep the old strings under the old keys and add the new ones as `notice.pill.firstToy`,
  `notice.firstToy.title`, `notice.firstToy.what`; the flag picks the set. Off = today's words exactly.
- Logic unchanged: same stage (`purchase`), same star icon, same card, same button.
- G1's "left as they are" list named this pill. This supersedes that one line.

---

## 3. A calmer first Deck screen (switch `CalmFirstDeck`)

**Gate:** exactly the Welcome round, `snapshot.phase=="Welcome"` and `owned==0`. A player who skips the tutorial
gets the Bear too, so the gate closes the same way.

### What hides, what stays

| Panel | Welcome round | Why |
|---|---|---|
| Daily quests card (wide) / quest handle (narrow, one column) | **Hidden** | "Win on Hard" means nothing yet. |
| Difficulty | **Hidden** | There is no choice in this round. |
| Win pays | **Hidden** | The round pays a pet, not a range. |
| Controls list | **Hidden** | The board's own cue (`↓`, `D-pad · A`, `← → · SPACE`) already says it, where the eyes are. |
| Chain | **Hidden** | Three drops make no chain. |
| Score and Best | **Hidden** | Nobody is scoring this round. |
| "Then" (the second preview) `[check: if Next shows two]` | **Hidden** | One ball ahead is enough. |
| **Board**, with the Welcome gesture cue | Stays | The whole point. |
| **Next** | Stays | It is the one thing to read before a drop. |
| **Mystery egg** meter | Stays, bigger | The goal. |
| **Coach card**: `Hatch a friend`, the one-line prompt, `Skip tutorial` | Stays, bigger | The only words on screen. |
| Shell: MENU, d-pad, A / B, back arrow, wordmark | Stays | It is the handheld, not a panel. No change. |

Hidden means not drawn: no card back, no empty tray. Plain glass is the calm.

### What the screen gains

**Step A (every layout, must ship).** The board rectangle does not move: its geometry and hit areas stay with the
unchanged layout, as `setWelcome` promises today.
- **Left column:** the coach card grows down over the quests slot, from the goals top to the column foot. Title
  20 px, prompt 16 px on PC and tablet; 16 and 14 on a phone. `Skip tutorial` stays at the foot as the quiet
  button it is now, never the brightest thing.
- **Right column:** Next at the top as today. The Mystery egg well takes the three rows under it (the egg, Difficulty
  and Win pays slots) so the egg draws about twice as tall. The Controls slot stays empty.
- **Top row:** the Score and Chain slots stay empty.
- **One column (portrait phone):** Next stays at the top right of the column; the coach card and the egg share
  the rest, egg under the words.

**Step B (phones only, and only where the board is squeezed).** On most landscape phones the board is already as
tall as the glass and cannot grow; Step A is the whole gain there. Where the layout has **shrunk the board to keep
two columns** (`g.phone`, board width under its full width):
- Use **one** side column, 120 px, on the left: Next, the coach card, the egg, top to bottom.
- The board takes all the width that frees, up to its full size, centred in the space that is left.
- The normal layout returns the next time the deck opens, which is after the hatch. It never changes mid-round.
- `[check]` everything that reads the board rectangle (drops, ghost, lockstep render, the gesture well) follows the
  new one. If that is not clean on the live line, ship Step A alone and tell me the board's share of the glass at
  750 x 402, 568 x 320 and 402 x 750.

**PC and tablet:** Step A only. The board is already full height; the win is that nothing competes with it.

### When it all comes back

At the **first field round** (the player's "round two"), in full and at once: the deck opens fresh, so nothing
slides in. Not staged over later rounds: G1's Welcome bonus and nudge already carry round two, and a second
special layout would be one more thing to test. Returning players and veterans never see the calm screen.

---

## 4. Switches

One `FeatureFlags` entry each, all `true` in the build. Off = today's behaviour exactly.

| Switch | Covers | Off means |
|---|---|---|
| `PetTrail` | Paw prints, the ring at the pet, the screen-edge chip (1a) and the second draw to the deck (1c) | Nothing points at the pet. |
| `FirstHelloBonus` | The six hearts, `First hello! +3 ★`, the +2 Stars (1b). Read on the server for the Stars. | The first pet is a plain `+1 ★`. |
| `RoundTwoNudge` | The round-two pill (1c) | No pill after the toy. |
| `ToyPillCopy` | The three renamed strings (2) | `Hatch your first egg`. |
| `CalmFirstDeck` | The Welcome-round screen (3), Steps A and B | All panels, as today. |

`PetTrail` and `RoundTwoNudge` do nothing useful with `GardenTourCut` off (the four cards own that moment):
with the cards on, the trail waits until they close.

---

## 5. Before it ships

- **Translations:** 7 new strings (`pet.hello`, three `coach.roundTwo.*`, three `notice.*firstToy*`). Run the export
  and sync steps; record the counts in the PLAY-BUILD entry.
- **Text fit** with `PseudoLocale` at 750 x 402 and 1280 x 720: `coach.roundTwo.bonus`, `coach.roundTwo.toy` and the
  new pill with a long pet name are the tight ones. If the pill clips, the name shortens with an ellipsis, not the verb.
- **Screens for my review** (actual renders, phone and PC):
  1. Garden just opened, new save: say-hi line, paw prints, ring, pet facing the player.
  2. The same with the pet off screen: the edge chip.
  3. The first hello: hearts, `First hello! +3 ★`, wallet at 23.
  4. The pill reading `Hatch a toy for Bear`, and its card.
  5. After the toy: `Round two: ★ 12 Welcome bonus`. And the `earn` case: `Round two: hatch a toy for Bear`.
  6. The Welcome deck, calm: PC wide, phone landscape (750 x 402 and 568 x 320), phone portrait. Step B before and after.
  7. Round two's deck: every panel back.
  8. A veteran save: no prints, no bonus, no nudge, normal deck.
  9. Night in the garden: the prints must still read on dark grass. If they vanish, lift them to 20% see-through.
- **What should move:** time from "Bear met" to `FirstPet`; funnel step 4 to step 6; "Second round started";
  the share still in at 1:00 (45% gone today) for the calm deck. Read with G1, same week.
