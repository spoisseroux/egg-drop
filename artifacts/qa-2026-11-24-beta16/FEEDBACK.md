# Beta (16) QA, Spencer, 2026-11-24: triage (Opus)

Spencer's words: "wtf is that horrible ada compliant ramp up to the new area? i like the new area but needs to be integrated more naturally into the landscape. Maybe theres a ramp up that cuts into the cliff to the left of the cave? i think we should use the cave to enter the minigames? and mini game selection? itll be like the central repo for minigame. and the hatch eggs thing just says turn on interact. sometimes the hatching egg is off center in its square too? [Turn / Buy crank items] i didnt see any of these happening, pressing turn just opened the hatch eggs screen, and they hatched normally like before now. everything else looks good?"

## Passed
- Everything else on the beta (16) checklist. He likes the new area.

## Bugs
- **B1 The crank never plays on the beta.** Turn opens Hatch eggs at once; buying hatches as before (no full turn, no clunk, no egg in the cup). Worked in Studio (R8/R9). Suspects: the client can't find the shared machine parts on the real server (streaming, PrimaryPart/pivot, the template copy), the switch path, or Reduced Motion.
- **B2 The prompt says only "Turn".** It should say what it does.
- **B3 The hatching egg is sometimes off centre in its square** (Hatch eggs screen tile / preview).
- **B4 The Bunny's eyes still clip into its head** (the eye on the viewer's right, outer edge). The 2026-11-21 conform fixed the Bear's eyes and the shared eye items, not the Bunny's own eyes.

## Changes
- **C1 The tier's way up:** the zigzag reads as an ugly accessibility ramp. Integrate it into the landscape: a path cut into the cliff to the left of the cave.
- **C2 The cave becomes the minigame entrance:** the central place to pick a minigame (a hub for Garden Dash, the Pocket Deck rounds and future ones).

## Routing
- Opus (egg corner builder): B1, B2, B3. Opus (pet art): B4.
- Fable: C1 (a natural cliff path) and C2 (the cave as the minigame hub), then build plans.
