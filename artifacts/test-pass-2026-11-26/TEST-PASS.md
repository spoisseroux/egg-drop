# Test pass: beta (34), 2026-11-26

Build: beta (34), place version v100, runtime 4ae3791f.

Place: **Pocket Pals Beta** (the private beta). Live is not touched.
Do the whole pass twice: once on a **phone**, once on **PC**.
Mark each row **OK** or write what went wrong (a screenshot helps).

## Before you start

- Type `/freshsave` in chat and rejoin. A fresh save is the only way to see the first minute.
  Your own save shows none of the new-player parts.
- Sound on, if you can. The egg cracks are meant to be heard and felt.
- Each new part has an off switch (section G), for comparing with the old way.

## A. Joining

| # | Do | Expect | OK / problem |
|---|---|---|---|
| A1 | Join | Loading screen: "Hatch a Handheld Pal", moving checker, five pals waving. It leaves on its own, or you can skip it after 10 s | |
| A2 | First screen | The Pocket Deck is the blue **Cloud Glass** skin, not the green one | |

## B. The Welcome round (three combos hatch the Bear)

| # | Do | Expect | OK / problem |
|---|---|---|---|
| B1 | Look before dropping | Six balls sit still at the bottom, a big green one resting on top. The goal says "Hatch a friend". A big cream egg with blue spots and a green band fills the right card, with three empty dots under it | |
| B2 | Drop your first ball anywhere | It sets off a chain of three merges (the notes rise, the deck kicks, "x3") | |
| B3 | Watch the merges | Every merge sends a coloured spark with a little trail flying into the egg. The egg bumps, its card flashes, and one dot fills | |
| B4 | Keep dropping | Drops that merge fill the second and third dots. A drop with no merge fills nothing. The goal stays "Hatch a friend" | |
| B5 | Third combo | The Bear's egg hatches right away | |
| B6 | Try B2 again on a new `/freshsave` with a different aim | The first drop still chains | |
| B7 | **Phone:** is the egg in the right card big enough to see clearly? | | |

## C. Crack the egg yourself

| # | Do | Expect | OK / problem |
|---|---|---|---|
| C1 | Wait on the reveal | The egg stops. A gold pill under the card says "Tap the egg!" (phone), "Click the egg!" (PC) or "Press A!" (controller). It pulses gently | |
| C2 | Keep waiting about 1 s | A little hand appears on the egg and taps, to show you how | |
| C3 | Tap the egg | Crack sound and buzz at once, a ring and flakes where you tapped, and a dark crack line across the egg. The egg stops again | |
| C4 | Tap again | The crack forks, with a light line along it | |
| C5 | Tap a third time | It creaks, then pops: the Bear. Under his name there is no "NEXT · Toy Egg ready" line any more (his first ask is the nest) | |
| C6 | New `/freshsave`; at the reveal, don't touch anything | It cracks by itself about once a second and opens in ~4 s | |
| C7 | New `/freshsave`; at the reveal, tap very fast many times | It never skips the Bear's pop | |
| C8 | Turn **Reduced Motion** on and hatch again | No stops, no flying flakes; the hatch plays as before | |

## D. Garden: tomorrow's egg comes first

| # | Do | Expect | OK / problem |
|---|---|---|---|
| D1 | After "Meet Bear", wait | A hand bubble over the Bear. Tap it to say hi | |
| D2 | After hi | The **next** bubble is the moon with a small egg (the nest), before the toy ball | |
| D3 | Top-left rail before you tuck the egg in | No nest ticket yet | |
| D4 | Follow the prints, tuck the egg in | The tuck card shows, the egg sits in the nest under a blanket, and a little egg flies from the nest up to the rail, where the new ticket pulses | |
| D5 | Read the ticket | "Hatches tomorrow" if the egg is ready on a later day, else a countdown ("Egg 7 h"). Late in the day it should say tomorrow | |
| D6 | Then | The toy ball bubble, the deck bubble, and the rest as before | |

## E. The cliff, the den and the path

| # | Do | Expect | OK / problem |
|---|---|---|---|
| E1 | Stand on the lawn facing the den | A big rock arch (about 18 wide, 11 tall), "The Play Den" sign under it, two lanterns on timber props. No pale plank at the left side, no thin rock slivers hanging above or left of the mouth | |
| E2 | Walk into the den at a run | No invisible walls or head knocks. A big room (36 x 24) | |
| E3 | Garden Dash gate in the den | Teal posts, checker banner, bulbs, "Garden Dash" board, start mat: easy to spot | |
| E4 | Walk the cliff path from the bottom to the terrace, once along each edge | 9 wide, no invisible walls or bumps that stop you, no head knocks | |
| E5 | Look at the path from the lawn | Solid rock wall. No tan/pale flat face beside the lower path, no dark blades across the cliff | |
| E6 | Path edges | Small rocks sit on the outer edge (3 on the first shelf, 5 on the second), none floating | |
| E7 | Arrival at the terrace | Clean rock below the arrival, no grass wall beside the top steps | |
| E8 | At night (`/hour on`, then `/hour at 2800`) | Den and path lanterns lit, glow-caps along the path, fireflies on the terrace | |
| E9 | In a park with pets | "Pets playing N/M" bottom right | |

## E2. Player scale (the world feels bigger)

Your avatar is now drawn at **0.8** of its size, so the island, the cave, the trees and the pets read 1.25x bigger.
Walk speed and jump are unchanged. You can change it live, on this server only, by typing in chat:
`/scale 0.75` (anything from 0.6 to 1.2), `/scale 1` (the old size), `/scale clear` (back to the default).

| # | Do | Expect | OK / problem |
|---|---|---|---|
| S1 | Join and look at yourself in the garden | Smaller than before, hair and clothes in proportion, feet on the ground | |
| S2 | Open the Pocket Deck (board mode) | The deck in your hands fits the smaller body | |
| S3 | Walk to the den, the path, the terrace and the parks | Everything feels bigger; nothing to get stuck in | |
| S4 | Try `/scale 0.7`, `/scale 0.85`, `/scale 1` | Changes at once. **Tell me the number that feels best**, I'll make it the default | |
| S5 | Respawn (reset) | Still at the chosen size | |
| S6 | Carry your Bear (pet focus) | The Bear sits right in the arms | |

## E3. Top Lawn toys at 1.25x (the terrace playground)

| # | Do | Expect | OK / problem |
|---|---|---|---|
| T1 | Stand in the Top Lawn with your pets | The swing set, slide, see-saw, sandbox and ball mat are bigger. They sit well on the lawn and none pokes over the edge | |
| T2 | Watch your pets play for a minute or two | On the swings they sit on the seats; on the slide they climb the ladder, sit at the top and slide all the way down; on the see-saw they sit on the seats; in the sandbox they dig in the sand. Nothing floating, sunk or clipping | |
| T3 | Throw the ball (the throw button) | It works here now (before, it never had a lane on the Top Lawn). The pets chase it and bring it back | |
| T4 | Other parks (the arrival lawn) | Unchanged | |

## F. Your own save

| # | Do | Expect | OK / problem |
|---|---|---|---|
| F1 | `/freshsave restore`, rejoin | None of sections B to D show. Your deck skin is whatever you picked before | |

## G. Switches (only if something in B to D feels wrong)

Each one turns off just that part, so you can compare with beta (27). Type it in chat, then `/freshsave`:

- `/onboard opener off`: the old Welcome round (the egg fills by charge, no sparks or dots).
- `/onboard crack off`: the old reveal (plays by itself).
- `/onboard nestfirst off`: the toy comes before the nest, the ticket counts down, no egg in the moon bubble.
- `/onboard all clear`: back to normal.

## Known, not in this beta

- Two small steps remain on the path (the outer edge of the switchback, the terrace floor corners).
  You can walk over them, but say if they bother you.
- The funnel events "DeckShown" and "EggTapped" only record on live servers.

## Results

| Date | Device | Section | Notes |
|---|---|---|---|
| | | | |
