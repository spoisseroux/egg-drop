# Garden play brief 2 (Fable, 2026-11-26) for Opus

Beta (35) notes 2, 3, 4, 5, 8, 13, 17, 18. Beta only, behind the existing Alive switches (`balls`, `crunch`, `air`, `snack`). No new text. Every number is `[PLACEHOLDER]`; every spot goes through `GardenClearance` and a Studio raycast. Avatar about 4 studs. Parts only. No Fabric (it renders as dark knit). Reduced Motion: all still, sounds stay. Buzz through `Haptics` only, local player only. Cull 90 / 150 as before.

## 1. Kick balls (2 more; wicker, felt and cork stay)

**Look:** our own panels: round patches, never pentagons or hexagons.

| Ball | Parts (diameter 2.4) | Colours | Material |
|---|---|---|---|
| Patch | Ball + 6 discs (Cylinder .06 x 1.15) on the six axes, .02 proud | body `#F4E8CF`, discs `#E8785A` x2, `#7FB8A4` x2, `#F2C14E` x2 | Rubber body, SmoothPlastic discs |
| Stripe | Ball + 2 crossed bands (Cylinder .5 x 2.44) + 2 end caps (.06 x .7) | body `#6FB6E8`, bands `#F4E8CF`, caps `#3F86C4` | Rubber |

**Motion:** livelier than the three: kick 30 flat + 11 up (jump 36 + 15), restitution .70, .55, .40, rest in about 3.2 s, squash 18%. Same `BallMotion` record, leash 22, server checks unchanged.
**Homes (spec-check, then raycast):** Patch about (20, -22), Stripe about (-60, 6).
**Sound:** kick `land` (114394270790206) at pitch 1.25 + `asmr_pop_a` at .3. New: `ball_rubber` kick and bounce, 3 takes each. Buzz `settle`.
**Budget:** 7 + 5 parts, 2 blob shadows.

## 2. ASMR toys: bigger movement

All: anticipate .05 s, overshoot, settle in two wobbles. No camera shake.

| Toy | Now | Change to |
|---|---|---|
| Leaf heap | flat 30%, 14 cards, re-heap 20 s | flat 12% in .08 s, then springs to 45% and sags; 24 cards from one pool, up 3.5 studs, out 4, spinning 2 turns, 2.2 s; the mounds shudder 8 degrees twice; re-heap 12 s ending in a 10% puff past full |
| Pop pods | flat .22, spread 1.18 | flat .12, spread 1.45; the nub pings 2.5 studs up, tumbles, lands as it re-inflates; neighbours lean away 12 degrees for .4 s; re-inflate overshoots 25% with two wobbles |
| Rattle gourds | swing 25, settle 2 s, neighbour .35 | swing 55, settle 3.5 s, neighbour .6 (they knock in a chain), each twists 20 degrees, the bar dips .15 and flexes 6 degrees |

Sounds and buzz unchanged, plus `asmr_flake` on the heap's rebound and `asmr_pop` at .4 when the nub lands.

## 3. Crackle slab (replaces the pebble tray's gravel)

Same spot (42, 12), same timber frame `#6B4A2E`.

**Look:** a dark Slate bed `#4A4640` (.1 thick) under **10 tiles** (5 x 2, each about 1.05 x 1.6 x .14, 3 to 8 degree skewed joints so it is not a grid). Glass, amber sugar `#E8B45A`, transparency .25, reflectance 0. Each tile is built as 3 shards that sit flush when whole, plus 2 crack lines (.03 wide, `#FFF3D6`, hidden).

**States per tile:** 0 whole; 1 hairline (lines show, tile dips .03); 2 shattered (shards tilt 8 to 15 degrees, drop .08, gap .06; 3 chips from a pool of 8 hop .7 up and skitter).
**Cracking:** a footstep adds 1 to the tile under it, and .08 s later a line runs into 1 or 2 neighbours (+1 only if they are whole). A jump landing sets its tile to 2 and all neighbours to 1. Walking on shattered tiles: chips only.
**Healing:** untouched 8 s, each tile drops one state every 4 s: shards ease flat over 1.2 s, lines fade, a faint warm gloss sweep.
**Sound:** hairline `asmr_crack1_a` to `_c`; shatter `asmr_crack2_a` to `_c` + `asmr_flake`; heal `asmr_creak` at .3. New: `glass_crackle` x4 (thin snap, tinkle tail), `glass_tinkle` x3. Pitch varied 8%, never the same take twice.
**Buzz:** `crack1` hairline, `crack2` shatter.
**Pets:** crack at half volume; the first shatter startles, then a sniff.
**Budget:** 4 frame + 1 bed + 50 tile parts + 8 chips = 63. Raise `Toys.Budget` to 175.

## 4. Pets never clip through props

- **One list.** Every client-built prop gives a keep-out to the pet planner: `{x, z, r, kind}`. `CrunchToys.footprints()` already exists; balls, the slab and tree trunks add theirs.
- **Solid** (gourd arch posts, slab frame, trunks, stations, a resting ball at r 1.2): routes bend round with .6 clearance. A blocked straight trot (fruit, bunt) picks the nearest free point on the circle or is refused.
- **Soft** (leaf heap, pods, slab tiles): allowed through, but the pet's feet ride the prop's top (`groundY` + the prop's current height), and it triggers the toy.
- **A ball in flight:** a pet in its path hops aside .8 studs; it never passes through.
- **Proof:** a spec walks 200 random pet routes against the list (zero crossings of a solid circle) and one capture per prop.

## 5. Fruit

**Look (3D, brighter):** body Ball .9 `#FF8A4C`, blush Ball .5 `#FFD166` sunk in one shoulder, stem Cylinder .08 x .3 `#6B4A2E`, leaf .4 x .04 x .22 `#7FBF4D`. SmoothPlastic, no gloss. Replaces the grey-tinted billboard in the crowns and on the ground; same slots and pool of 16.

**Shake a tree:** walk into a trunk (root within 2.2, over 4 studs/s). The crown rocks 6 degrees three times in .6 s, 8 leaf cards fall, one fruit drops with the existing fall and bounces. That crown then has nothing to drop until its fruit grows back (scale 0 to 1 over 20 s, about 60 s after). Client-local, like the gust drops, which stay.
**Eating:** 5 bites over 3.2 s (was 3 nibbles). Fruit scale 100, 78, 58, 40, 22, 0%, turning 25 degrees a bite; 3 crumbs per bite in the fruit's colour; cheeks puff. The stem and leaf drop and fade in 1 s.
**Sound:** rustle `asmr_flake` x2 on the shake; landing `land` at .4; bites `snack_nom_a/b/c`; `snack_gulp`; `snack_happy_squeak`. New: `tree_shake` x3.
**Buzz:** `settle` on the shake.

**Stats: yes, Heart.** +2 Heart XP per fruit your own pet eats (the same as one petting), server-granted on a claim: at most 1 a minute and **12 a day (24 XP)**, under the existing Heart per-minute cap. It does not use the daily Bonus XP, gives no Stars and shows the normal Heart pip. (A care is 6, a daily quest 30.) No counter is shown; after the cap the pet still eats happily.

## 6. Lanterns become drift balloons

Same 9 spots, drift and switch. Each balloon:

| Piece | Part | Colour |
|---|---|---|
| Envelope | Ball 3.0 | `#F6EBD2` |
| Gores | 4 thin rings (Cylinder .06 x 3.04) turned 45 degrees apart, upright | accent `#E8785A`, `#7FB8A4` or `#F2C14E` |
| Skirt | Cylinder .5 x 1.2 at y -1.6 | accent |
| Ropes | 4 Cylinders .04 x 1.0 | `#8A6A3C` |
| Basket | Wood block .9 x .7 x .9 + rim .95 x .1 x .95 | `#8A6A3C`, rim `#6B4A2E` |
| Flame | Neon Ball .28 under the skirt | `#FFB347` |

SmoothPlastic, matte. 13 parts each, 117 in all.

**Mascots:** 3 of the 9 carry one, chosen per session; those three hang at 14 over. A mascot is a `PetFactory` baby at .45 scale with a random roster pet and palette, never a player's: an **imp** (the `horns` feature, warm palette) or a **cherub** (`wings`, plus a new halo: Neon disc .5 x .04 `#FFE9A8`, .25 over the head, bobbing .05). It stands in the basket, head and paws over the rim.
**Behaviour:** idle look-about every 4 to 7 s. When the local player is within 35 studs it turns, waves 1.2 s and hops, at most every 10 s. `snack_happy_squeak` at .3 within 25 studs.
**Burn:** every 6 to 10 s the flame grows 1.6x for .8 s and the balloon lifts .4. Sound: `asmr_exhale_a/b` pitched .7 within 30 studs; new `burner_whoosh` x2.
**Night (daylight under .3):** flame flickers (two sines, 7.3 and 11.1 Hz, 15%); the envelope's lower half warms to `#FFD98A`; lights on the 4 nearest (range 12, .5 to .8, flickering with the flame).
**Budget:** 117 parts, 3 mascots, 4 lights.

## 7. The Dash start balloon

A bigger sister of section 6: envelope 5.0 in `#D9776B` with `#EFE6D2` gores, basket 1.5, both ropes kept.

- **Bunting:** 6 pennants a rope (.5 x .4 x .04, the three accents), fluttering 10 degrees.
- **Starter mascot:** one baby in the basket with a small flag (.6 x .4, `#F2C14E`).
- **Countdown:** each beat the flame burns and the envelope puffs 8%. On Go it jumps 1.5 studs, drops 20 leaf cards in the accents, and the mascot swings the flag. At the finish the mascot hops twice.
- **Sound:** `asmr_pop` on each puff, `spin_whoosh` on Go, over the Dash's own cues.
- **Budget:** about 40 parts. Nothing collides; nothing in a lane.

## 8. Weekly specials (scope)

**Rules:** no countdowns, no "last chance". A special is first in line this week and joins the normal catalogue after, at the same price. Nothing is lost by missing a week. No new Stars in.

**First slice: "This week in the garden" (world only, no shop change).** One pure table keyed by `WeeklyShelf.week`, four rows that loop:

| Week | Balls | Fruit | Balloons |
|---|---|---|---|
| 1 | Patch + Stripe out | apricot | imps |
| 2 | bell colours on cork | plum `#B58CFF` | cherubs |
| 3 | Patch + Stripe out | lime `#B9EE5A` | both, bunting on all nine |
| 4 | all five out | berry `#FF86A8` | one golden balloon `#F2C14E` |

It costs no art beyond this brief.

**Second slice: a fourth shelf slot, "New this week".** One new item a week at full price (no discount, so nobody waits): three weeks at 60 Stars, the fourth at 150. 330 Stars a month against about 800 banked by a casual player and 3,600 by an engaged one. Art: one recolour or charm a week.

**Not yet:** streaks, exclusive items, Robux specials, a weekly Stars prize, any timer.

## Not yet (all sections)

Goals or scores; ownable mascots; rideable balloons; fruit as an item or for sale; XP in other stats; replicating shakes or cracks.
