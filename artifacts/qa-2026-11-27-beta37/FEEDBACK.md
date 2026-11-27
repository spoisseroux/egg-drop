# Spencer's notes on beta (37), 2026-11-27

Build: beta (37), v119, runtime f5a7408b, Pocket Pals Beta. Played from `/freshsave`.
Shots: `shot-62-deck.png` (the Welcome deck), `shot-63-tuck.webp` ("Tuck the egg in!" by the dais), `shot-64-stars.png`
("Play for Stars!" over the Bear, egg not tucked).

## A. The first minutes after the hatch

| # | Note (his words, trimmed) | Lane | Cause (first look) |
|---|---|---|---|
| 1 | "when the first egg hatches and we start playing the 3d world the bear isnt visible bc it teleports somewhere behind us behind a fence. we need to make it stay in the middle where the egg was ... and then start following us" | Opus bug | to find: the Bear's spawn after FirstHatchStory |
| 2 | "tuck the egg in ui thing doesnt constantly follow the pet, it like waits and then catches up to it?" | Opus bug | the NeedBubble's follow is smoothed or stepped |
| 3 | "The onboarding thing above the pet changed to play for stars even though i didnt tuck in the egg yet. it said youre all set before i even did anything. it just timed out?" | Opus bug + Fable flow | Yes: `V2.Guide.ignore=20` s. A prompt ignored 20 s shrinks and is skipped; all three skipped = "You're all set!" |
| 4 | "why is that the first thing to do after hatching the bear? Should we keep it that way?" | Fable flow | The nest went right after the hello in "nestfirst": tomorrow's egg is the reason to come back. Unexplained to a new player |
| 5 | "when we go to click the pet to tuck in the egg, should it run towards the egg like beckoning us to follow it? with edge case handling like if the player doesnt follow etc so no one gets soft blocked" | Fable flow, Opus build | |
| 6 | "make the footsteps follow it but make them like pulsating and more attention grabbing across the board" | Fable look, Opus build | PetTrail everywhere |
| 7 | "the youre all set should be more fun and exciting too" | Fable | GuideEndCard is "the exhale, no confetti" |
| 8 | "make the petting screen cuter, cuter ui, cuter interactions, look at nintendogs petting for inspiration" | Fable design, Opus build | PetFocusUI / PetAffection. Mechanic inspiration only, original look |
| 9 | "make the ui on the first drop a ball to hatch egg egg drop game more exciting/cuter" | Fable | Shot 62: flat navy panel, "Drop a ball!", plain pips |
| 10 | "i dont think the new onboarding goes over the pet park and mini games too, and customizing?? wardrobe and more?" | Fable scope | Onboarding part 2 |
| 11 | "should we redo the materials and color and hue and stuff system first?" | Question | Fable audits the system; Spencer decides |

## B. Garden

| # | Note | Lane |
|---|---|---|
| 12 | "some of the balls are still boring looking not animal crossing like textures" | Fable look, Opus build |
| 13 | "the hot air balloons are too crowded, and some need to be way higher" | Fable layout, Opus build |
| 14 | "the hot air balloon sounds are too loud" | Opus |
| 15 | "we still cant shake trees to make fruit fall like animal crossing? And the fruit should be like in the trees like animal crossing" | Opus check + build. Today: walk into a trunk faster than 4 studs/s (not discoverable) |
| 16 | "i think all the trees should be bigger also? do we need more vegetation?" | Fable judgement, world |
