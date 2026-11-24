# Egg machine, Blender render R1 (Fable, 2026-11-24)

**Verdict: GO WITH CHANGES.** The idea survives: pot, glass egg, sprout, flower dial, woven cup. It looks like nothing
real and nothing from another game. Make the "Now" changes, re-render the same three views, then go into Studio; I
review next on the Studio noon and dusk captures. Seen: the three renders and `build_egg_machine.py`. Not seen: the
texture file on its own, anything in Studio.

## What I see
- **Silhouette:** reads from the path mouth as a cream pot under a glass dome of coloured eggs with a sprout. Good.
  The globe's top pinches to a point under a wider cap, so it reads teardrop-with-a-hat, not egg.
- **Collar:** the weakest part. It is about 4.5 across at the tips (spec 3.9), wider than the base, and the scallops
  are so shallow it reads as a flat octagonal tray, not leaves.
- **Egg pile:** a narrow cone in the middle with empty glass all round. Spencer asked for "full of eggs"; this is
  a third full. My 0.55 egg was too small for a 3.5 globe: that is my spec's fault, corrected below.
- **Eggs:** pointed at both ends (lemons). The zigzag band is invisible at every distance. Material and Feature are
  the same aqua at any range (spec colours; see Later).
- **Dial:** the petals read as a flower from 26 studs. Up close the cream knob and the cream embossed egg touch and
  merge into a white "8". The knob is a long peg (0.4 across, 0.55 proud), not a round knob.
- **Feet:** sit outside the belly's underside like loose pebbles; the right front foot is inside the cup.
- **Chute and cup:** the cup is right and rhymes with the nest. The chute reads as a flat ribbon with a stripe across.
- **Colour:** everything is washed out (collar mint, dial mustard, base near white, band barely there). Probably the
  render's view transform and bright sky, so I cannot judge the hex values from these.

## Now (before Studio)
| Part | Property | From | To |
|---|---|---|---|
| Collar | radius at scallop tips | about 2.26 | **1.95** (3.9 across) |
| Collar | scallop shape | smooth cosine, 0.24 deep | 8 leaf lobes with a sharp notch between: valley radius 1.62, tip 1.95, tip rim dipping 0.08 |
| Globe | profile `roundness` | 0.85 | **0.65** (fuller shoulder, blunt top; still widest at 40%) |
| Cap | height and shape | flat disc at 7.0 to 7.2 | domed, sunk to 6.9 to 7.12 so it hugs the glass; sprout follows (overall height up to 7.6 is fine) |
| Eggs (all) | size | 0.55 x 0.72 | **0.66 x 0.86**; dropped egg 0.72 x 0.94 |
| Eggs (all) | ends | pointed both ends | blunt: rings spaced by angle, `roundness` 0.45, fat end down; still 96 triangles |
| Baked pile | layout radii | rings at 0.95 / 0.62 / 0.32 | 9 at **1.15**, 6 at **0.80**, 3 at 0.40 (touching the glass at the front; top of the heap near 5.6) |
| Loose eggs | ring radius | 0.55 | 0.65, same front weighting |
| Egg band | contrast | body x0.86, band x1.0 | baked: band vertices 50% toward cream `#FFF3C4`; loose: body x0.78, band x1.0. If it still cannot be seen in render-front, drop the band |
| Dial knob | shape | 0.4 across, 0.55 proud cylinder | **0.55 across, 0.3 proud, domed top** |
| Dial emboss egg | colour | cream (knob region) | darker sunflower `#E0A422`, so it does not join the knob |
| Feet | positions (x, z) | (-1.25, 1.0), (1.25, 1.0), (0, -1.3) | (-0.95, 0.85), (0.95, 0.85), (0, -1.05): half tucked under the belly, clear of the cup |
| Chute | leaf shape and UV | even ribbon, vein across | tapers to a point with the tip curled up 0.1; midrib along its length |
| Render | view transform | default | Standard, sky strength 0.4, so the hexes can be judged; check the base band `#E2D2B0` shows |

## Later (Studio pass or R2)
- Globe highlight streak and the thin green rim: judge in Studio with the real transparency.
- Material `#8FF0E4` against Feature `#9CFFDD`: if they still read as one in Studio, I will shift Feature greener.
- Brush grain and rim chips on the base: judge at noon with an avatar beside it.
- Dusk light and the settle motion: after placement.
