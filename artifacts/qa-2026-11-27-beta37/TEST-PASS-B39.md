# Test pass: beta (39), 2026-11-27

Build: beta (39), place version v135, runtime b1042eaa, on **Pocket Pals Beta**. Live is not touched.
Design: `ONBOARDING-FUN-PASS.md` (Fable). Beta (38)'s test doc `TEST-PASS-B38.md` still applies for everything else.

`/freshsave`, rejoin, play from the start. Switches: `/onboard gifts|lead|allset2|stork|deck2 off`, `/alive pet2|paint off`.

## A. The first minutes, faster

| # | Do | Expect | OK / problem |
|---|---|---|---|
| A1 | Welcome deck | Words "It moved!", "It's cracking!"; after combo 3 the egg keeps knocking until the deck tucks | |
| A2 | Stork | Shorter (about 4.6 s); Skip shows after half a second | |
| A3 | Meet Bear | The camera comes back from the side: you and the Bear both in view; "Pet me!" over the Bear, and it stays until you do it | |
| A4 | First petting | The heart fills in about 3 s of rubbing; the happy burst closes the screen by itself | |
| A5 | Right after | The Bear hops once and **runs** (faster than you) toward the nest: "This way! / A new egg is waiting"; stand still 6 s: "Come on!" | |
| A6 | Tuck it in | "Tuck it in!", the tuck celebration | |

## B. The free eggs (`/onboard gifts`)

| # | Do | Expect | OK / problem |
|---|---|---|---|
| B1 | After the tuck | A bubble invites you to the egg machine for a **free Paint Egg**; at the machine "Turn it!": the crank, the egg comes out, a paint pot is revealed, "Paint Bear!" paints him there | |
| B2 | Play rounds | "Let's win Stars! / Stars turn the crank!" closes only after a round | |
| B3 | "You're all set!" | Stamps, then **+5 ★ welcome gift** with stars flying into it; your Stars go up 5; "Hatch one!" (if you can afford an egg) lays paw prints to the machine | |
| B4 | Two rounds later (or next day) | A **free Toy Egg** invite; crank it; the Bear plays with the toy | |
| B5 | Pet Park | "Throw it!", then a "Bear learned Fetch!" card | |
| B6 | Finish a Garden Dash | A **free Snack Egg** crank (never uses up your own free Snack Egg) | |
| B7 | Ignore an invite / tap ×, wander off | It parks as a chip over the pet, a ribbon on the machine and a row in Things to do; nothing expires | |
| B8 | Rejoin, `/freshsave restore` then back | Each gift only once; the +5 never twice | |

## C. Paint pots from eggs only

| # | Do | Expect | OK / problem |
|---|---|---|---|
| C1 | Pet screen > Dress up > Colour | Pots you own paint; ones you don't are locked swatches you can preview, "Win it from a Paint Egg", and a "Hatch a Paint Egg" button to the machine. No prices anywhere | |
| C2 | Hatch eggs > Paint Egg | No "Pick a colour" strip | |

## Known

- Art for the gift chip, machine ribbon, gift card and paint wipe is placeholder.
- Not built yet: the nest Peek (a glimpse of who's inside after the tuck), a three-tap crank dial (one tap cranks).
- Played in Studio up to the lead (deck, stork, crack, Bear card, side camera, petting, the Bear running with "This way!"); the gift eggs, all-set, Dress up, Park and Dash were not played by hand. The first-visit auto-close of petting did not trigger in my Studio run (worth a look).
- The egg card on the deck has a grey bar under the egg (the shadow) that looks off.
