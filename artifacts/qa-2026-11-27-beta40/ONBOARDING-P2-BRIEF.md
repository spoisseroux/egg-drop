# Onboarding part 2: gifts through the real machine, then five small lessons (Fable, 2026-11-27)

Answers beta (40) notes 3, 5 and 8. For an Opus build. Switch: `gifts` (part 1) and a new Onboard switch `teach` (part 2). Off is beta (40).

**The rule:** teach the real button. Every lesson is the normal screen with one thing lit, and ends in something happening to the Bear.

## 1. Free eggs come out of the normal shop

The server does not change: the shop's button sends the same `giftEgg {kind}` ask (Snack: `snacks.buyGift`) that the chip sent.

**Flow (Paint, Toy and Snack alike)**

1. **Invite**, as built: the bubble over the Bear ("A gift for you! / A free Paint Egg"). A tap starts the lead. It never cranks.
2. **Walk.** Glow steps to the machine. The dial keeps its ribbon and "Free egg!" tag (the ribbon is the landmark; keep it).
3. **At the machine** (within `Chain.Near`): the bubble becomes "Tap the machine! / Your free egg is inside". The machine's own prompt reads **"Free egg!"** in place of "Hatch eggs" while a gift is ready (client-side ActionText).
4. **The normal Hatch eggs screen opens** in gift mode (`EggHatchView:setGift(kind)`, read from `public.gifts.ready` on every open, from the Menu too):
   - The gift's tile (`Recipe_look` / `Recipe_toy` / `Recipe_stat`) is selected and scrolled into view. Its "★ 12" becomes a gift-pink **FREE** sticker with the 20 px bow from GiftEggArt.
   - The tile wears the pointer (section 2).
   - Other tiles and Get Stars sit at 60% opacity. They still select and buy.
   - Right pane: price sticker "Free"; promise line "A gift from {pet}!"; odds from `GiftEggs.odds` ("Each colour: 1 in 4"); the button reads **"Hatch free!"**, gift pink, ringed. Another egg shows its normal pane. The paid Paint Egg returns once the gift is taken.
5. **Press.** `chain:crank(kind)`. From here it is a paid buy's path exactly: the screen tucks, crank (the ribbon unties on the first tick; tap-to-turn stays), egg out, the gift card.
6. **Card.** Keep the gift card as built (sash, tag, headshot: it reads as a present). Buttons in section 2A.

**Removed:** the chip over the Bear (`bubble.chip`, `onChip`) and "Turn it!" (`onbGift.turn`, `turnSub`). `Chain:tap` and `Chain:resume` only lead; near the machine they open the shop. **Kept:** bubble, "x", one nudge, ribbon, the "Gift waiting" Things row (Show me leads; at the machine it opens the shop), the card, the paint wipe.

**Unseen gift (rejoin before the card closed):** the prompt reads "Free egg!"; pressing it skips the shop, the egg comes out again, then its card.

## 2. Part 2: five lessons, one at a time

**The pointer (new, one module, `TeachPointer`):** a 3 px gift-pink ring on the real button, pulsing 1.0 to 1.12 every 1.2 s, a 40 px white hand that dips 6 px toward it, and a white pill label (ink, ExtraBold 16). It never blocks input or dims the garden; inside a menu the other tiles go to 60%, still usable. Reduced Motion: a still ring and the label. Gamepad: no hand; focus lands on the target and the label shows the glyph (HintGlyphs).

**Rules:** one pointer at a time, never beside a bubble, card or reveal (`ThingsTips.blocked`). A lesson is **done only by the saved fact**, whoever caused it. Ignored for 12 s or dismissed by walking away: the pointer fades and returns once next session. Nothing is marked done by a timer. Gift steps no longer count toward `PerSession`; invites (pull, menu, dash) count, three a session, 90 s clear of the last reveal.

| # | Lesson | Triggers after | What lights up, exact words | Reward | Done when |
|---|---|---|---|---|---|
| A | **Dress up** | The Paint gift card | Card key **"Paint {pet}!"** now opens the pet screen: the Dress up button is ringed, label **"Dress up!"**. It opens on Colour with the won pot selected and the Paint key ringed: **"Tap Paint!"**. The wipe plays close up, "{pet} is {colour}!" | The Bear painted | A pot was used (`hueUse` saved) |
| B | **Pocket Deck** | Lesson A's wipe, or "Later" (as built: "Let's win Stars! / Stars turn the crank!") | The dock's Deck button (`OpenHandheld`, today's `pulseDeck` ring) gains the hand and **"Play!"** | Round Stars, then "You're all set!" and +5 ★ | `stats.rounds` rose |
| C | **The Menu** | "You're all set!" closes | "What's next?" no longer opens Things itself: it closes the card and the dock's Menu button is ringed, **"Open the Menu!"**. In the hub the Things to do tile is ringed: **"All the games!"** | The page lists what is next (gift row on top when one waits) | Things page opened (`dashSeen`-style coach bit `menuSeen`) |
| D | **Pet Park** | The Toy gift's card (**"Play!"**: the Bear pounces on the toy, 5 s), then as built "Let's go play! / The Pet Park is open" | Inside the park the Throw button is ringed: **"Throw it!"** (replaces the toast) | "{pet} learned Fetch!" | `stats.fetches > 0` |
| E | **Garden Dash** | Fetch learned, garden free. Drop the "later session" condition | Bubble "Race time! / Try the Garden Dash", glow steps to the gate; the gate sheet's Start key is ringed: **"Go!"**. DashHints teach the jump as built | First finish: "A snack for the racer!", the free Snack Egg through the shop (section 1), the Bear eats it | A ribbon saved, then the Snack receipt |

"Hatch one!" on the all-set card stays (their own Stars); C then follows that reveal. The Toy gift still waits for three rounds.

**A in detail.** "Later" on the card keeps the pot and skips to B. The Dress up button then wears a small pink dot (no pulse) until a pot is used; it never expires. If the pet screen cannot open (pet not out, a race seat), fall back to today's one-tap paint. Enter through the pet screen's own focus path so one owner holds the camera (note 4's fix: coordinate).

**New and changed words** (UICopy, then export and sync):
`onbGift.atMachine="Tap the machine!"`, `atMachineSub="Your free egg is inside"`, `freeEgg="Free egg!"` (now the prompt too), `shop.free="FREE"`, `shop.price="Free"`, `shop.hatch="Hatch free!"`, `shop.from="A gift from {pet}!"`, `teach.dress="Dress up!"`, `teach.paint="Tap Paint!"`, `teach.deck="Play!"`, `teach.menu="Open the Menu!"`, `teach.things="All the games!"`, `teach.throw="Throw it!"`, `teach.go="Go!"`. Remove `turn`, `turnSub`.

## 3. Edge cases

| Case | Behaviour |
|---|---|
| Ignores the bubble | One nudge, then parked: ribbon, "Free egg!" prompt, Things row. Waits forever |
| Opens the shop and buys something else, or closes it | Fine. The gift tile stays FREE and lit every time the shop opens |
| Leaves mid-crank or before the card | The receipt is saved; the unseen replay (section 1) |
| Rejoins mid-lesson | Derived from the save; the next undone lesson's pointer shows once that session |
| Did it already (painted, played, opened the Menu, fetched, raced) | Counted done; no pointer. A gift still waits |
| Veteran or old save | No bubbles or pointers. A ready gift shows as ribbon, prompt and FREE tile only |
| Owns every toy | Toy gift skipped (AllOwned); D offers itself |
| Pouch full, pet not out, grant refused | The existing toasts; the tile stays lit |
| Phone | Hand and ring on the tap target; labels clear of the thumbstick and dock; targets 44 px |
| Keyboard | Labels add the key: prompt E, Menu M, Throw F |
| Gamepad | Focus goes to the lit target; A acts, B backs out; glyphs Y (Menu), R1 (Dress up), R2 (Throw) |
| A switch off mid-chain | Nothing lit or offered; receipts and items kept |

## 4. Priority

**Must, beta (41):**

1. Free eggs through the shop, chip removed: `EggHatchView.lua` (gift mode, FREE sticker, "Hatch free!"), `GiftChain.lua` (tap and resume lead only; `near` text; PerSession exemption), `GiftBubble.lua` (chip out), `init.client.lua` (wiring: shop reads `public.gifts`, prompt text, ribbon tap), `EggMachineClient.lua` (prompt ActionText, unseen replay on prompt), `SnackHost.lua` (gift buy from the shop button), `ThingsPage.lua` / `things.act`, `UICopy.lua`, specs `GiftChain.spec`, `EggHatchView` spec.
2. `TeachPointer.lua` (new) and lesson A: `GiftReveal.lua` (primary key routes to Dress up), `DressUpButton.lua`, `PetFocusUI.lua`, `PaintPanel.lua` (preselect pot, ring Paint), `GiftPaintWipe.lua` (plays in the pet screen).
3. Lesson C: `AllSetCard.lua` (`next()`), `RoomView.lua` (Menu button ring), `MachineHub.lua` (Things tile ring), `CoachMarks.lua` (`menuSeen`), `Onboard.lua` (`teach` switch, events `TeachShown`, `TeachDone`).
4. Lesson B's hand and label on the existing `pulseDeck`.

**Later (beta 42):** lesson D's Throw ring (`ParkThrowControl.lua`), lesson E same session (`GiftChain.next`, `DashGateSheet.lua`), the Dress up dot, gamepad label polish.

Each slice adds its `V3-TEST-PASS.md` row. Captures for my review at 600 x 360: the shop in gift mode, lesson A's three taps, the Menu ring.

**Spencer decides:** "Paint {pet}!" becoming three lit taps through Dress up (it teaches the door; the one-tap version is the fallback).
