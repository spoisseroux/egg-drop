# Cliff path, Play Den and terrace: review of the Studio captures (Fable, 2026-11-25)

Reviewed: `studio/world/01` to `05` (Studio, noon, PC framing, Assistant camera), against my spec
`qa-2026-11-24-beta16/CLIFF-PATH-AND-ARCADE-CAVE-LOOK.md` and Opus's `CLIFF-DEN-BUILD.md`. Also read `DenGreybox.lua`,
`TierGreybox.lua`, `DenLayout.Light`, `WorldAero.Surfaces` and the lip code in `cliff_den_sculpt.py` so the fixes name
real rows. Not seen: night, phone (844 x 390), the turn, shelf 2 from the plaza, anything in motion. Hexes below are
targets read off JPEGs; treat each as "set, capture, compare".

## Verdict: ship to beta with the listed fixes

The big call is right. From the lawn (01) the way up is **one worn line rising left from the cave**, nothing stacked,
nothing standing on the lawn. That answers "a ramp up that cuts into the cliff to the left of the cave". The den is a
real walk-in room with objects, and from outside it is a warm lit opening with a readable name. Both are worth
Spencer's walk now.

What would spoil that walk is cheap to fix with rows and colours: blown-out white lamps, a hot orange floor, a white
marble shop-front round the mouth, a hole at the path's foot, and a terrace that still reads as a grey building on the
skyline. Fixes 1 to 7 before the beta publish (all rows, tints or numbers). 8 to 11 can follow. The mesh list at the
end waits for the next sculpt export.

## Per capture

### 01 path from the lawn

- **Reads well.** One diagonal, about 15 degrees, starting beside the den. The den glow and sign pull the eye to the
  foot of the path, so the two features sell each other. The step flight at the top is visible and inviting. Dirt
  against grey-green rock is the garden's own path language.
- **Doesn't.**
  - The path looks **laid on** the rock, not cut in: no back wall shows from here, and the line is ruler straight.
    The spec's "half cut, bows out with the foot" is not visible.
  - The lip is a **dotted line**: identical grey boxes at an even pitch (2.0 long, 1.2 gap). It reads as a kerb or
    crenellation, which is the built look he hated.
  - **Skyline:** the terrace is a white marble stripe 76 studs long over a flat dark wall, with a dark box on top
    (`ClumpOne`). It is the largest, flattest, darkest shape in frame. This is the "grey building" from R8 again.
  - **Tan flat faces** show round the den mouth and in the rock seams right of centre (untextured cut faces of the
    ground mesh). They read as paper.
  - A **dark hole** at the path's foot (about x 1320, y 575 in the frame) where the ground is missing.
  - A white marble column stub stands at the foot. Plaza material in the wrong place, but live mesh: leave tonight.

### 02 den mouth

- **Reads well.** A wide, shallow, lit stage: you see the floor, the table and the back wall from the lawn, as asked.
  "The Play Den" is legible at this distance. The notice board on its post is in the right place.
- **Doesn't.**
  - The **old marble frame**: a thin white rectangle with the teal zigzag trim and a white sill across the floor. It
    turns a cave into a shop front, and the sill is a white trip line on a dirt floor.
  - **Lanterns are white cubes on sticks.** Neon at #FFD9A0 blooms to pure white, so no warmth at all, and they
    silhouette as street lamps.
  - **Glow-caps are lemon neon crystals** with a bloom that turns the lawn yellow-green for 3 studs round each.
    Loudest thing in frame, louder than a pet.
  - The **sign hangs in the middle of the opening** and hides the Deck table, the one lit toy the mouth should show.
  - The board is a blank plank.
  - The apron stops at the sill; the lawn meets it in a hard sawtooth, and the missing-ground hole shows again lower
    left (blue-grey).
  - Large tan faces left and right of the mouth, as 01.

### 03 den inside

- **Reads well.** Room size is right: five bays with air between them, eight paw stones fit, the dome gives headroom.
  Bunting, crate and dust sheet, rope posts are the right vocabulary. The Deck screen is the brightest thing on the
  back wall, which is correct.
- **Doesn't.**
  - **The floor is the brightest, most saturated surface** (reads about #C4683C). The room is orange first, toys
    second. The spec is the reverse.
  - **Walls are flat-lit pale grey-green** with the rock crack pattern stretched to about four times the outdoor
    scale: giant spider-web cracks. No lantern falloff shows at all, so the room is lit by ambient, not by the four
    lamps. It feels like a tent, not a cave.
  - **Glassy vertical panes** along the walls with bright top edges (centre and right of frame). Looks like collision
    boxes or wall panels that are not fully transparent. Check before anything else in the room.
  - Wall lanterns: white cubes again.
  - The Deck table is a brown cube with a glowing slab lying flat on top; reads as a pedestal light, not a Deck
    propped up. No mat.

### 04 terrace arrival

- **Reads well.** Dirt steps climbing through a notch between rocks, grass at the top: the right gesture. The island
  and sky beyond are a good reward.
- **Doesn't.**
  - You arrive **facing a dark 10-stud wall** (`ClumpOne`, 18 x 22 x 10, #5A6256). The spec's arrival is "the whole
    terrace ahead".
  - The balustrade's end (`BalustradeSouth`, a 4-stud marble stub 3 high) stands beside the notch like a headstone,
    and the long run is a solid white wall, not a low lip.
  - The notch rocks are square posts with stretched texture (mesh; next export).
  - Tan faces in the rocks lower right.

### 05 avatar on the path

- **Reads well.** The avatar is clearly on a ledge crossing a rock face, and the drop is readable without feeling
  dangerous. Scale against the big rock facets is good: the mountain feels big.
- **Doesn't.**
  - The walking width reads as **about 4 studs**, not 6: the avatar nearly fills it. `[check]` the built width; two
    avatars must pass.
  - The lip stones are **uniform boxes like teeth**, square to the path, same height. No back wall on the uphill side
    here either: the path is a ribbon on a convex face.
  - Dirt is one flat colour edge to edge; no grass creeping in from the lip.

## Fixes, ranked (rows, tints and numbers only; no new meshes)

1. **Lanterns stop blowing out** (`DenGreybox`, all four). `Look.lamp` #FFD9A0 to **#D98A3A**, keep Neon. Add to each
   lantern a cap and a base, 0.95 x 0.15 x 0.95, `Look.dark` #5C4330 Wood, at +0.62 and -0.62 from the lantern's
   centre, so it is a lantern and not a cube. `DenLayout.Light`: colour #FFC98A to **#FFB870**, brightness 1.2 to
   **0.9**, range 14 unchanged.
2. **A timber frame over the marble at the mouth** (new `W7D_` rows, Wood, `Look.dark` #5C4330; these also replace the
   two lantern posts). Lintel beam **17.5 x 1.3 x 1.2** centred on the trim (x -7, y 10.5, 0.2 lawnward of the
   marble's face so it covers it). Two jamb posts **1.5 x 6.3 x 1.5** over the marble posts at x -15 and x 1, floor to
   the beam. Threshold: **16 x 0.5 x 1.8**, Ground material, #815C3F, top at 4.5, over the white sill, sunk so its top
   is level with the room floor. Then hang the two mouth lanterns from the beam's ends on 0.8 cords (lantern centres
   about y 9, x -14 and x 0) and delete `LanternPost1/2`.
3. **Sign onto the beam** (`layout.sign`): centre it on the new lintel's lawn face (y 10.5), tilted forward 8 degrees,
   cords removed. The opening is then clear and the Deck table is the thing you see through it.
4. **Den floor down** (tint on `W7_CD_PlayDen__dirt_path` only, `SurfaceAppearance.Color`, a new entry beside
   `WorldAero.Surfaces`; the garden's `dirt_path` stays untouched): multiply **#B8A898**. Target on screen about
   #8A5E44, clearly darker than the Deck screen and the bunting. Add the **mat**: a cylinder 8 across x 0.08, Fabric,
   #B8AE98 (`Look.cloth`), with a 6.4 inner disc #D9725E at +0.01, centred mid-room about (-8, floor, -108).
5. **Den walls back and warm** (tint on `W7_CD_PlayDen__cliff_rock` only): multiply **#A8957E**. Target: walls a
   warm grey-brown about two stops under the lamps, so the four lights finally show as pools. If the panes in 03 are
   the `W7C_CD_` boxes, set them fully transparent (Transparency 1); if they are wall faces, tell me what they are.
6. **Glow-caps down** (whatever builds the yellow crystals at the mouth): colour to **#E8C468**, any light on them
   to brightness 0.4, range 5, or no light at all (spec: unlit emissive). They are markers at the foot of the wall,
   not lamps.
7. **Apron slab, which also plugs the hole at the path's foot.** One `W7D_` row, Ground material, **#815C3F**, no
   collision change needed if the lawn carries feet: x -25..3, z -100..-90, 0.4 thick, top at lawn height +0.05
   (about 4.65). It joins mouth and path foot on one worn patch as specified, hides the sawtooth and covers the
   missing ground at about (-22, -90). Break its lawn edge with two existing boulder or bush dressing templates,
   one at each front corner.
8. **Terrace skyline** (`TierGreybox`):
   - `BalustradeNorth` / `BalustradeSouth`: height Y+3 to **Y+1.4**, colour MARBLE to **CLIFF #6B7465**, Slate. The
     `...Stop` walls start at Y+1.4. A low stone lip, same idea as the path's.
   - `ClumpOne`: from s 6..24, t -8..14, 10 high to **s 8..20, t -8..6, 5 high**, colour #5A6256 to #6B7465; add a
     second block s 12..18, t -4..4 up to Y+8 so it steps. Nothing over Y+5 within 14 studs of the gap (s 26..34).
   - `ClumpTwo`: 8 high to 6, same colour change.
   - `FaceGarden`: top from Y-2 to **Y** (so the floor slab's dark grass side never shows as a band), and lighten to
     **#869080** if it still reads darker than the rock beside it from the 01 viewpoint.
9. **Hide the tan faces at the mouth** with existing dressing only: two bush templates each side of the mouth against
   the jamb rocks (about x -18 and x 4, z -97), and one boulder template on the big tan face left of the mouth.
   Proper fix is in the mesh list.
10. **Deck table reads as a Deck:** `Stump` 3 x 2.4 x 3 to **cylinder 5 across x 2.2**; the `Deck` slab tilt from
    -18 to **-55 degrees** and size up to 3.5 x 0.25 x 2.4 (screen 2.8 x 0.05 x 1.7), propped at the back of the
    stump facing the mouth. Stools to cylinders 1.1 across.
11. **Notice board:** three thin rows on its face (3.4 x 0.5 x 0.05, #B8AE98 Fabric, at 0.75 spacing) so it reads as
    a list even before the live text is on it.

## Next sculpt export (mesh; not tonight)

- **Lip stones:** vary length 1.2 to 3.4, height 0.8 to 1.8, yaw +/- 15 degrees, gaps 0.6 to 4, drop about one in
  four, sink each 0.3. No two neighbours alike. Round the tops.
- **Show the cut:** a back wall of 3+ studs along the middle third so the path reads as a shelf from the plaza; let
  the line bow 2 to 3 studs with the contour.
- **Width 6** if the check in 05 says it is 4.
- **Rock UV density** in the den walls and dome matched to the outdoor cliff (about a quarter of the current size).
- **Cut faces** take the rock (or dirt) material, never the bare ground colour: the tan faces everywhere.
- **Notch rocks and the fin** as irregular boulders, not posts.
- Grass creeping onto the path's outer third; the foot's two flanking boulders.
- Carve the marble frame, sill and the column stub out of the mouth and foot (needs the marble re-bake solved).

## Captures I want next

All after fixes 1 to 8, same Studio, a real player camera where possible:

1. The mouth from the Hub and from 30 studs, **noon and night**. Night is the landmark test: a warm glow at the back
   of the garden, no white, no lemon.
2. Inside from the mouth and from the back wall looking out, PC and **844 x 390**, with an avatar and a pet for
   scale and colour rank (pet and toys must be the brightest things).
3. The path from the Hub (does it read as one ledge at plaza distance?), from its foot looking up, on shelf 2
   looking down at the garden, and **at the turn** (never captured: the fin, the pocket, the first view west).
4. Arrival: the first frame as the camera clears the notch, looking north-east along the terrace.
5. The 01 viewpoint again for the skyline, and one from the far side of the plaza.
6. A phone clip walking up and down, including two avatars passing on a shelf.
7. One close frame of the wall panes in 03, with their instance names.
