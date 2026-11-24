# Fable review R4: four leftovers from R3 (2026-11-23)

Reviewed: `STUDIO-CHECK-R4.md`, captures 05 to 15 in `studio/r4/`, `Sim.BirdShape` and `Sim.birdParts` in
`src/client/LifeSim.lua`, `Life.PetalColours` in `src/client/GardenLife.lua`. Look only. Everything else in R4 is GO.
Numbers below are worked out from the shape table, not rendered: recapture 09a and 09c to confirm.

## 1. Bird: folded wings, FIX

What 09a shows is not the tips. It is the **shoulder end** of each wing: `foldYaw` 15 swings the front of a .68 long
plate about .07 outward, to x = +-.29 at head height (y up to .39), where the body is only about .10 wide. From the
front you see the wings' grey inner faces as a collar beside the neck.

Root frame as R3 (body centre, -Z forward, studs). In `Sim.BirdShape`:

| Key | Now | Change to |
|---|---|---|
| `wing` | (.03, .68, .32) | **(.03, .48, .22)** |
| `foldAt` | (.22, .06, .06) | **(.205, 0, .17)**: lower and further back, shoulder end stops below the head |
| `foldYaw` | 15 | **8** |
| `fold` | -55 | unchanged |
| `foldRoll` (new) | none | **22 deg** about the wing's long axis, top edge leaning in toward the spine, so the plate lies on the curve of the flank |

`foldRoll` goes last in the fold chain: left `... * fold * CFrame.Angles(0, rad(22), 0)`, right with `-22`.
**[check]** the sign: the upper (back) edge must move toward the spine, not away.

Result by the numbers: wing runs from just behind the shoulder (.10 forward of body centre along the back) to the tail
root; top front corner at x = .19, y = .22, inside the head and body outline; widest point .29 at breast height (was
.29 at head height).

Pass, front at 8 studs: nothing wing-coloured outside the head and body outline above the body's centre; a sliver of
no more than **.05 studs** at mid height is allowed (it reads as a wing, not an arm). If more shows, `foldAt.X` to
**.19**, nothing else. Three-quarter (09c): the wing file must still cover the flank from shoulder to tail root. Flight
pose untouched (`shoulder` stays); only the tuck lerp target moves.

## 2. Leaves: FIX A and B, petal stays

The line is the drawn **long side at most .25 studs, envelope included**, at the worst measured factor (1.65 x Size).
So peak + envelope must be at most .15.

| Emitter | R3 keys {start, peak, envelope, end} | **R4 keys** | Drawn long side |
|---|---|---|---|
| Leaf A | {.11, .165, .03, .15} | **{.09, .135, .015, .12}** | .21 typical, .25 max |
| Leaf B | {.10, .145, .02, .13} | **{.08, .125, .015, .11}** | .20 typical, .23 max |
| Petal | {.075, .12, .02, .105} | unchanged | .20 typical, .23 max |

If the air then looks empty: rate to **3.0 / 1.5**, nothing else. 12 and 13 already read right beside the Bear; this
only takes the top off the biggest leaf.

## 3. Petal colour: FIX

Flat colour, no sequence, `LightEmission` 0. In `Life.PetalColours`:

- lime: #FFF6C2 -> **#F1E6C8**
- pink: #FFB8D6 -> **#F0B4CE** (the same drop in value, so the pink crowns follow the same matte rule)

Full-value cream is the brightest thing in the air (the blob by the lamp in 13). Ambient stays matte under the pets.

## 4. "Coming up" strip order: one rule

**The order never changes: egg, stamp, quests.** Ready never sorts. Ready shows only as the **#FFC14D 2 px** outline
and gold text (plus the boing for the egg). Two or three ready at once: each one outlined, same order. Nothing ready:
no outline, same order.

Reason: the strip updates live while results are open (16, 17). With sort-first, the quest chip would jump from slot 1
to slot 3 the moment it is claimed. Chips keep their place; gold does the pointing. Change the model so ready chips are
not put ahead, and update the spec that expects them first.
