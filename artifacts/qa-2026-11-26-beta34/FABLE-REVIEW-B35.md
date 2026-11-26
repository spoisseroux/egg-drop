# Fable review, beta 35 renders (2026-11-26)

Judged from `studio-b35/01..06` and `studio-r8/01, 05, 06`. Parts only.

## Ship

- **Wobble Egg (01):** ship. Twig and moss collar is matte, the glossy egg is the only bright thing on the crag. Right hierarchy.
- **Bumble ball, felt (04):** ship. The knit reads touchable and the seam gives the roll something to show.
- **Den mouth (r8 01), stairs foot (r8 05), daises removed (r8 06):** ship. Follow-up only: the path's square notch at the stairs' foot (05, bottom centre) wants one 45 degree corner.

## Fix 1: drift lanterns (02, 03)

They read as dark woven hampers: this place's Fabric renders a brown knit (same as the ball), and four crossed slabs read square. Rebuild, still 8 parts each (`PartsEach` unchanged):

| Part | Shape, size (studs) | Material, colour | Notes |
|---|---|---|---|
| globe | Ball 1.8 | Cardboard (fallback SmoothPlastic), `#F6EBD2` | Transparency .25 |
| core | Ball 1.1, centred | Neon | see below |
| rib x3 | Cylinder .05 tall; 1.84 across at y 0, 1.54 at y +/-.5 | SmoothPlastic, accent | the paper's hoops |
| cap x2 | Cylinder .18 tall, .7 across, y +/-.86 | Wood `#6B4A2E` | |
| tassel | .12 x .8 x .12, under the lower cap | SmoothPlastic, accent | no Fabric anywhere |

Look by daylight (drop the Fabric/Neon material swap on the paper):
- **Day (>= .3):** core `#F2C98A`, Transparency .6; globe `#F6EBD2`, .25. A warm heart, not a lamp.
- **Night (glow 0 to 1):** core to `#FFD98A`, Transparency .6 to 0; globe to `#FFE6B0`, Transparency .25 to .4; PointLight brightness .5 to .8, range 12, parented to the core.
- Start the ramp earlier: `GlowSpan` .15 to .25 so full glow lands at daylight .05.

Positions. Rule: no lantern within 20 studs XZ of the hatch tree crown (-36.1, -18) or 9 studs of any other crown. Offenders and moves (re-run `DriftLanterns.spec`, nudge along the same rule if clearance fails):

- hub_1 (-35, -1) to (-38, 8), over 16
- hub_2 (-25, -2) to (-22, 5), over 15
- hub_3 (-30, -7) to (-29, 12), over 18
- fountain_1 (45, 9) to (47, 13) (crown at 37.7, 7.8)
- bridge_1 (-15, 27.5) to (-19, 27.5); bridge_2 (-9, 31) to (-4, 31) (crown at -11.8, 34.3)

## Fix 2: pop pods (05)

Six identical olive balls; nothing says "stomp me". Per pod, 2 parts become 5 (pods 12 to 30):
- Body: 1.1 across, .9 tall (`reach` 1.0, `spacing` 1.7). Alternate `#9DBF6A` / `#B5CC6E` / `#8DB37A` along the row.
- Dome becomes a puckered nub: .34 across, .2 tall, `#E9DCA6`.
- Three sepals at the base, 120 degrees apart: Part .6 x .05 x .32, Grass (fallback SmoothPlastic), `#4F7F3A`, tilted 20 degrees up at the tip, reaching .25 past the body. They stay put when the pod flattens, so the squash reads against them.
- Each pod gets a fixed yaw and a height scale of .9 to 1.1 from its index (hash), so the row is a litter, not a rank.

## Fix 3: rattle gourds (06)

Reads as a small brown hurdle beside a pillar; the eye skips it. 12 parts become 16 (total 94 of 120):
- `span` 3.4 to 4.6, `gap` 1.05 to 1.35, `post` .2 to .3, `bar` stays 2.35 (still bumped at walking height).
- Gourds bigger and unalike: bodies 1.0 x .92, .88 x .8, 1.08 x 1.0; necks .44 x .6; colours `#D8B56A`, `#C98F4A`, `#E6CC8E`.
- Two foot stones under the posts: 1.0 x .28 x .8, Slate `#9C968A`, yawed 15 and -25 degrees.
- Two cord wraps on the bar ends: Cylinder .25 long, .3 across, `#E8785A` (the lantern accent, ties the set).
- Move it 3 studs further from the pillar plinth, along the arch's normal, away from the path; re-run the clearance spec.

## Order

Lanterns first (most seen, most wrong), then pods, then gourds. New renders at daylight .55 and .1 for the lanterns, please.
