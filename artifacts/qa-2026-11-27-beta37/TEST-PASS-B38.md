# Test pass: beta (38), 2026-11-27

Build: beta (38), place version v133, runtime eb3f94fd, on **Pocket Pals Beta**. Live is not touched.
Your notes: `FEEDBACK.md`. What was done: `BRIEF-B38.md`.

`/freshsave` then rejoin for a new player (`/freshsave restore` brings your save back).
Switches: `/onboard deck2|trail2|lead|allset2 off`, `/alive pet2|paint|air|balls|fruit|scene off` (and `on`, `clear`).

## A. The first minutes (fresh save)

| # | Do | Expect | OK / problem |
|---|---|---|---|
| A1 | The Welcome deck | Glass sky card on the left with a little looping picture of the step; a big gold number ("2", "1") and "2 more!" / "1 more!"; the egg on a grass card knocking from inside; egg-shaped pips, the next one breathing | |
| A2 | Each combo | A spark flies to its pip, the pip pops, the egg card flashes, "Nice!" / "So close!" / "It's hatching!" | |
| A3 | Stork, three taps, Meet Bear | As beta (37); then the camera comes back from the side and **the Bear is right there where the egg was** (not behind you or a fence) | |
| A4 | Wait without touching anything | "Pet Bear!" stays over the Bear (it no longer vanishes); every ~15 s it hops and chirps | |
| A5 | Pet the Bear | The new petting screen (B below). Close it | |
| A6 | After petting | The Bear chirps, hops and **runs to the nest**, stopping to look back and beckon; "Follow Bear! / A new egg is waiting". Glowing paw prints pop in under its feet | |
| A7 | Follow it | At the nest: "Tuck the egg in! / It hatches tomorrow"; tuck: the Bear spins, hearts, "Sweet dreams! Come back tomorrow to hatch it." | |
| A8 | Try to lose it | Stand still or walk away: the Bear runs back, "This way!"; after 3 ignored nudges it follows you again with a little moon chip over it (tap it to lead again). Nothing ever says done unless you did it | |
| A9 | "Play for Stars! / Stars buy eggs and toys" | Closes only after you play a round | |
| A10 | Back in the garden | "You're all set!": the Bear jump-spins, bubbles and confetti, a card with three stamps (Pet, Nest, Stars), "What's next?" opens Things to do | |

## B. Petting (`/alive pet2`)

| # | Do | Expect | OK / problem |
|---|---|---|---|
| B1 | Pet any pet | Closer camera, a white mitten hand instead of the cursor (above your finger on a phone), a name pill, a glass Happy heart on the right, "Rub Bear!" | |
| B2 | Rub head, cheeks, chin, belly, back, ears | The pet leans into the hand and its eyes follow it; each spot reacts differently (eyes close, head tilts, giggle wiggle, stretch, ear twitch) | |
| B3 | Keep rubbing | Hearts at a third, bigger hearts and blush at two thirds, a happy burst when full; one favourite spot sparkles and fills it faster ("Bear loves this!") | |
| B4 | Leave (Back, B, Esc or walk) | The pet waves; the cursor comes back | |

## C. Paint, Shine, Dress (`/alive paint`)

| # | Do | Expect | OK / problem |
|---|---|---|---|
| C1 | Pet screen > **Dress up** | One screen, tabs Colour, Shine, Outfit, Charm; Back returns to the pet screen | |
| C2 | Colour | Paint pots (Pink, Blue, Yellow, Purple), body and tummy/ears targets; pick a pot you don't own: buy and paint in one tap (15 Stars), "Painting…" then done; "Back to white" asks first if it has paid pots | |
| C3 | Shine | A Soft-Normal-Shiny slider and a See-through row | |
| C4 | Eggs | The Customization Egg reads "Paint Egg", the Stat Egg "Snack Egg" | |

## D. Garden

| # | Do | Expect | OK / problem |
|---|---|---|---|
| D1 | Look up | Seven balloons at three heights, two far ones up over the skyline, none over the hub; burners only heard close | |
| D2 | Trees | Shade trees about a third bigger, three tall ones at the island's edge; fruit trees a little bigger; trunks meet their crowns | |
| D3 | Fruit tree | Fruit sitting in the leaves; stand by the trunk: **Shake** (R on keyboard, X on a pad, tap on a phone): the tree rocks, leaves fall, fruit drops (sometimes none) | |
| D4 | Balls | Felt is a patchwork, plus a polka-dot ball and a ringed ball | |
| D5 | Plants | Round bushes at corners and path forks, flowering bushes by the hub and fountain, reeds along the streams and pools | |

## Known

- Petting, the lead, all-set, Dress up, pot buys and Shake were not played by hand in Studio (the test tools can't press those inputs); the logic is spec-checked.
- Stand-in sounds: the deck egg's knock, the trail's pat, the petting brush and squeak.
- A second fruit from one shake can almost never earn Heart XP (the one-a-minute cap).
- The 15 Stars pot price is a placeholder until you OK it.
- Not seen on a phone.

## Results

| Date | Device | Section | Notes |
|---|---|---|---|
| | | | |
