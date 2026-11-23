# Waterfall review, round 1 (Fable, 2026-11-23)

Judged from two stills (`waterfall-r1-wide.jpg`, `waterfall-r1-close.jpg`) against `waterfall.jpg`. Motion not seen.

**Verdict: GO for the private beta.** Clearly better than before: white side ribbons break the ruler edge, the foot and
ledge have foam, rings and rainbow are quiet. Apply the "now" numbers first if a republish is cheap; none of them block.

## What I see

- **Strands:** still read as even vertical stripes in a still. Strand B is the cause (pale, regular, too opaque).
- **Lips:** both are hard white bars; the ledge roll looks like a plank and overhangs the sheet. Too white, too thick.
- **Foam:** reads as a few separate cloud puffs, not a froth line. Too big, too few.
- **Rings:** good. Subtle, flat, correct place. A little wide for the pool.
- **Rainbow:** good. Barely there in the wide shot, soft in the close one. Keep.
- **Mist:** not visible in either shot. The close camera may be inside the 16-stud keep-out; the wide one is not.
- **Palette:** the sheet reads cobalt, not aqua. Strand A should lift it toward #7FE0FF.

## Now (values in `WorldAero.Waterfall`)

| Layer | Property | From | To |
|---|---|---|---|
| StrandB | Transparency mid (8% to 85%) | .45 | .62 |
| StrandB | length | 13 | 9 |
| StrandA | Color | #3CC8F0 | #7FE0FF |
| StrandA | Transparency mid | .35 | .28 |
| Lips.Lower | thickness, length | 1.1, 11.8 | .6, 10.6 |
| Lips.Upper | thickness, length | .9, 8.8 | .5, 8.0 |
| LipLook | Color, Reflectance | #FFFFFF, .2 | #F4FCFF, .1 |
| Foam (pool) | Size peak, rate, Life | 1.9, 16, .7 to 1.1 | 1.4, 22, .6 to .8 (still 18 alive) |
| LedgeFoam | Size peak, rate | 1.5, 8 | 1.1, 11 (Life as above, 9 alive) |
| MistLook | Transparency at 25% | .8 | .62 |

## Emitter boxes and the walk grid: decision

The pool bed is walkable, so "3 studs from any walk tile" cannot be met. The rule becomes: **pool boxes stay within
1.5 studs of the sheet along n, and mist starts above pet height.**

| Layer | Property | From | To |
|---|---|---|---|
| Foam (pool) | box depth, out | 2.5, 1 | 1.5, .75 |
| Mist (pool) | box depth, out, up | 3, 1.5, 2 | 1.5, 1, 3 |
| Mist (pool) | Size end | 6.5 | 5 |
| Rings | out, Size end | 2.5, 9 | 2, 7 |

## Later

- Capture mist from 20+ studs after the change; if still unseen, rate 3 to 4. Do not go below transparency .55.
- Still owed: pool edge at pet height with a pet standing in the pool, phone, Reduced Motion, level 1, a short clip.
- If stripes survive the Strand B change, redraw `water-strand.png` with uneven gaps (map fix, not numbers).
- The grey segmented strip under the pool foam is the old mesh: goes with the export (layer 7).
