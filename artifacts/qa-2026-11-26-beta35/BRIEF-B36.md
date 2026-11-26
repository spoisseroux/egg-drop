# What changed for your beta (35) notes

Beta (36), place version v114, runtime 0f2cc42d, on Pocket Pals Beta. **Live has not been touched.**
Test doc: `TEST-PASS-B36.md`. Your notes: `FEEDBACK.md`.

| # | Your note | What was done |
|---|---|---|
| 1 | Deck laggy on a bad connection | Audit (`DECK-NET-AUDIT.md`): play was already local except two waits. Taps at a round's start were eaten for one round trip (up to ~630 ms); the board froze at round end for a round trip (up to 1.4 s with loss). Both fixed: early taps play at once, the results open the frame the board ends, Stars show "Saving…" until the server confirms. Rewards stay server-checked. `/netsim` lets you feel it. |
| 2 | Animal-Crossing-like soccer balls | Patch (cream, round panels) and Stripe (blue, crossed bands): original looks, rubber, bouncier. The three you like stay. |
| 3 | Bigger ASMR toy motion | Leaf heaps burst bigger (24 cards), pods squash and pop with overshoot, gourds knock in a chain. |
| 4 | Pets clip through meshes | One keep-out list of solid props (trunks, lamps, fountain, crag egg, gourds, slab); pets route round them, soft toys (leaves, pods) they walk through. |
| 5 | Gravel should crack (ASMR trend) | Replaced by a crackle slab: 10 amber sugar-glass tiles that hairline, then shatter under steps and jumps, then heal after 8 s. |
| 6, 7 | Fountain farther, from the player, less "fried chicken"; waterfall barely audible | You now hear the garden from your character's head (back to the camera in deck/egg/race shots). New original water loops made by our own script (no crackle highs), uploaded; fountain carries ~45 studs, falls are loud near the pool. |
| 8 | Fruit: stats, brighter, eaten slowly, shrinking, sounds, shaken from trees | Bright 3D fruit in the lime trees; walk into a trunk to shake one down; pets eat in 5 bites over ~3 s with sounds. +2 Heart XP per fruit, at most 1 a minute and 12 a day (24 XP), no Stars, checked by the server. |
| 9, 10 | Stat Egg showed its hatch screen during the crank; all eggs must crank | The Stat reveal had its own screen layer the shot never covered. Now every egg goes through one delivery path: crank, the egg out of the machine in its own egg's look, lands, then the reveal. A spec checks every egg type and every buy. Saved as a standing rule. |
| 11 | Make the leaf a hole | The leaf is gone and the machine has a real mouth in its belly (dark inside, tan lip) the egg pops out of into the cup. |
| 12 | Egg in its type's texture | The dropped egg is the real egg shell with its type's texture. |
| 13 | Weekly specials | Scoped (Fable): first a world rotation (balls, fruit colour, balloon mascots on a 4-week loop), then optionally a "New this week" shop slot at full price. Not built yet: the shop slot waits on your call. |
| 14-16 | Missing faces at the stairs; loose faces above the ramp; left of the den by the first steps | World round 9 + 9b: the terrace's lip was crossing the upper steps and the island's underside showed; the face's bottom hung loose over the path; the cut wall's open end stood bare by the den. All re-cut and uploaded; the steps at the turn now meet edge to edge. |
| 17 | Hot-air balloons with a pet mascot | Nine little balloons replace the lanterns; three carry an imp (horn buds) or cherub (wings, halo) pet that looks about and waves when you come close; burners flicker softly at night. |
| 18 | Dash balloon more fun | Bigger, bunting, and a flag mascot that reacts to the countdown. |
| 19 | How to test onboarding | `/freshsave`, rejoin. |
| 20-25 | Onboarding: confusing, wonky Bear in the deck, flat egg, your stork flow, the reveal not fitting, nothing after | Fable redesigned it around your flow (`ONBOARDING-V2.md`): one big instruction at a time and a spinning 3D egg on the deck; after combo 3 the deck tucks, a stork sets the egg down in front of you, you tap it 3 times, the Bear pops (the old second hatch in the deck is gone), the card fits inside the screen's safe area (every pet card now), then "Pet Bear!", "Tuck the egg in!", "Play for Stars!", "You're all set!". Each step has a switch. |

## How it was checked

- Offline specs: 112 pass, 0 fail.
- Code review: two passes, GO WITH CHANGES; every should-fix applied before publishing (onboarding: the dock shut during the story, the card always closable, no double hatch; planner capped; fruit claim history).
- Studio Play: no script errors (one real bug found and fixed there: the pets' keep-out check read a property off a Part every server tick). Played the new onboarding end to end: 3D egg, combos, the stork, three taps, the Bear card inside the safe area, "Pet Bear!".
- Hash 563 scripts 1141361281 = repo; ZZSpecs stripped; lock removed; Rojo stopped. Translations exported (beta: no sync).

## Not checked

- Buying eggs (the Studio save has no Stars): the machine mouth and the per-type egg in game. Pets walking, fruit eating, two players kicking.
- A real phone.
- Stork/burner/crackle sound takes are stand-ins.

## Waiting on you

1. Your test pass (`TEST-PASS-B36.md`).
2. Weekly specials: build the "New this week" shop slot (60 Stars x3, then 150), or the world rotation only?
3. Deck netcode left two small options for your OK: reveal 2 more upcoming balls to the client (removes a rare preview change on very bad connections), and let your deck keep drawing its own settle after a 3 s stall.
