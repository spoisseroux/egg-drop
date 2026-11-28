# Test pass: beta (45), 2026-11-28

**Build:** Pocket Pals Beta (place 107705084891479), **v154**, repo `c5e5cf8b` + the odds-row fix. Live is untouched.

**Covers:**
- your 25 beta (44) notes;
- the daily item rotation;
- the Aero glass deck;
- the new music.

**Start from a fresh save:** `/freshsave`, then rejoin. Every new piece has an owner chat switch, so `off` tells you which one caused a problem.

**Switches:**
- `/rack rack on|off` turns on the Outfit Egg, today's picks and the Outfit gift. It's on by default.
- `/rack lookdaily on`: the Paint Egg's odds shift each day. **Off by default; turn it on to test it.**
- `/rack looknopity on`: no guaranteed charm. **Off by default.**
- `/alive deckglass on|off` switches the glass deck. It needs `/alive deckfeel` on as well.
- `/alive music2 on|off` switches the new garden and deck songs.
- `/onboard teach|gifts on|off` switches the shorter onboarding and the gift chain.

**I checked in Studio before publishing:**
- The Welcome round runs, and the welcome egg hatches the Bear.
- Clicking the pet opens the pet screen, and rubbing fills the heart.
- Hatch eggs shows the Outfit Egg tile, with today's 9 picks and their rarities.
- Tapping a pick opens the Today's picks sheet, with each pick previewed on the Bear.
- Hatching an Outfit Egg gave a Tangerine Party Hat (Uncommon, 12%), and "Wear it!" put it on.
- The garden plays the new day track (125877989254797).
- The glass deck shows on the Cloud Glass plate.
- No script errors.
- 162 offline specs pass, and all 634 scripts compile.

**I did not check:** the full onboarding chain through the deck tour, other plates, the phone layout, two players in a Dash, or the night crossfade. Those are yours. Shots of what I did see are in this folder: `outfit-egg-odds.jpg`, `todays-picks.jpg` and `deck-aero-welcome.jpg`.

---

## A. Your beta (44) notes

Tick each one, or tell me what's still off.

### Hatch, machine and gifts

| # | Your note | What changed | Try |
|---|---|---|---|
| 1 | Square corners on the hatch preview | The preview's sky and grass are clipped to the frame's rounded corners. | Hatch any egg: the corners are rounded. |
| 2 | No crank sound | The crank clicks are louder (.3) and so is the clunk (.4). Effect sounds come back on any input after you alt-tab. | Hatch an egg after alt-tabbing away and back: you hear the clicks and the clunk. |
| 3 | The "free egg is inside" bubble stays up | The bubble goes the moment the shop opens, and stays gone. | Get a gift, tap the machine: the bubble is gone. |

### Onboarding

| # | Your note | What changed | Try |
|---|---|---|---|
| 4 | The welcome egg went small after combo 3 | The calm deck stays on while the welcome egg is showing. | Welcome round: the egg stays big through the hatch. |
| 5 | "Let's try playing a game!" | The pet says it when the deck is next. | After the first petting. |
| 6 | The ring showed before the boot ended | The tour waits for the deck's boot animation to finish. | Open the deck: no ring until the screen is up. |
| 7 | Goals spacing and checklist | The Goals card is restyled (deckfeel). | Look at Goals with one-line and two-line goals. |
| 8 | Show how to open quests | The tour's last step rings the quests clipboard. | Six steps: Goals, Balls left, Win pays + level, Score, Chain, quests. |
| 9 | "What does score even do?" | The Score step reads "Your high score. Goals win Stars!" (Stars come from goals, not raw score). | Read the Score step. |
| 10 | Don't make me finish a whole game | Drops are held during the tour, and the deck closes itself when the tour ends. | Tap through the six steps: the deck closes and you're back in the garden. |
| 11 | "You can hatch one!" too early | It waits until the deck lesson is done. | You shouldn't see it before the tour. |
| 12 | "You're all set!" too early | It shows only once the tour is over and you're free in the garden. It comes with the +5 gift. | After the deck closes. |
| 13 | Dress-up and materials lesson lost | Alt-tabbing no longer counts against it: the lesson clock pauses while the window is unfocused, and losing focus doesn't skip the lesson. | Alt-tab during the Dress up lesson: it waits for you. |
| 14 | Things to do instead of long lessons | Things to do has learn rows with ticks and Show me: Dress up, Customize, Book, Deck style, Quests. | Open Things to do, then Show me on Customize and Dress up. |

### Pet and garden

| # | Your note | What changed | Try |
|---|---|---|---|
| 15 | The head jitters while petting | The head eases between spots, and a spot changes only after you've been over its edge for a moment. | Rub slowly across the head and cheeks: no snapping. |
| 16 | Unnatural run to the egg | The lead turns in arcs around obstacles, doesn't re-plan when it switches pace, and keeps its old path instead of walking straight. | Watch the tuck-in run. |
| 17 | Footprints face the wrong way | The prints follow a smoothed path and go round keep-outs. | Things to do, Show me: the prints point along the path. |
| 18 | **Can't click the pet** | Any input brings the window back into focus, and the gift bubble's clickable area is only its pill. | Click the pet from every angle, especially right after alt-tabbing. |
| 19 | Shaken fruit vanishes | The fruit from a shake is always drawn; the oldest other fruit goes instead. | Shake a tree with 3 fruit already down: the new one falls and stays. |
| 20 | Garden Dash start line | The start line has colliders, and the sign and its icon are removed. | Walk into the start line. |

### Deck and Dash

| # | Your note | What changed | Try |
|---|---|---|---|
| 21 | Replay too close to Difficulty | 8 px gaps past every button lip. | Results pane, desktop and phone. |
| 22 | Server messages for the Dash | A chat line when a race opens, and one for the winner: "*Name*'s *pet* won the Garden Dash!" No line for bot winners or trials. | Needs two players: one joins the race, the other watches the chat. |
| 23 | No footsteps for the Dash Show me | The Show me aims at the pad's edge, with a straight path if no route is found. | Things to do, Garden Dash, Show me. |
| 24 | Remove the Play Den row | Removed. | Things to do. |
| 25 | Deck song for Dash racers | Racers hear the deck song. Nobody else does. | Race: the deck song plays. Watch from outside: the garden music keeps playing. |

---

## B. The daily item rotation (new)

| What | Try |
|---|---|
| The Outfit Egg | Hatch eggs → Looks → **Outfit Egg (★ 25)**. The odds list is today's 9 picks: the name, a colour dot, a rarity pill and the percent. The last pick is a 1% Sparkle with an animated finish. |
| Today's picks | Tap any odds row: a sheet shows every pick on your pet with its rarity and odds. "Missed one? They come back." There are no countdowns anywhere. |
| Hatching | One unowned pick from today's list, with a rarity sticker. "Wear it!" puts it on. Once you own all of today's picks: "You have today's picks! New picks tomorrow." |
| The Wardrobe in closet mode | Wardrobe cards show one card per item. Owned colours appear as round swatches; tap one to wear it. Items you don't own say "From the Outfit Egg" and have a button that opens the Outfit Egg tile. Level-gated items and the This week pick still sell for Stars. |
| Copy | The Companions hub and the Wardrobe help card say the clothes come "from the Outfit Egg", not "bought with Stars". This week no longer shows clothing deals. |
| Onboarding | The first free gift is now an Outfit Egg holding a Pom Beanie (fixed, not random). A pointer goes from the tile to the odds ("Tap to see today's picks!") and then to Hatch free!. Paint follows two rounds later, then Toy and Snack as before. |
| Paint Egg daily odds | `/rack lookdaily on`: one colour "splashes" extra each day (23% vs 15%). Today's colours are tappable too. |
| No guaranteed charm | `/rack looknopity on`: "Every egg has a chance at a charm." The "charm in N" countdown is gone. |
| Switch off | `/rack rack off`: the Outfit Egg tile goes and the Wardrobe sells as before. What you got from the egg stays yours and stays on. |

---

## C. The Pocket Deck in glass (new)

Play a round on Cloud Glass. Then equip two or three other plates (Ember, Night Orb, Bookworm) and play again.

- Every HUD card should be glass in that plate's colours, with round gel tags and a soft gloss.
- Check the Welcome deck too: the sky card, the egg card and NEXT.
- Tell me if any plate's text gets hard to read.

## D. Music (new)

- Garden day and night use the new tracks, and they crossfade on the garden hour.
- The deck uses the new deck song; Deck Lite uses its lite version.
- Racers hear the deck song during a Dash.

---

## Known gaps (not bugs to report)

- Toy colours, deck skins and Angel Wings are not built yet; they're the next rotation slice.
- The Today's picks previews are small on tiny items like studs and eyes. Fable can zoom the camera per slot next.
- Long pick names still cut off in the odds list. The full names are in the sheet.

## Before any of this goes live (decisions for you, not tests)

- **Charm pity:** players partway to a guaranteed charm were promised one. Do we keep that promise if `looknopity` goes live (e.g. finish the count they started)?
- **Odds text:** review the odds wording.
- **Restricted players:** they keep the fixed charm every 12th egg.
- **Server cost:** cache today's picks per pet before live (from the code review).
- **Translations:** sync for live (beta export only tonight).
