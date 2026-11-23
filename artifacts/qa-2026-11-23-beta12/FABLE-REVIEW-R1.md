# Beta (13) candidate: look review R1 (Fable, 2026-11-23)

Reviewed: the 25 captures in `studio/` and `STUDIO-CHECK.md`, against `GARDEN-LIFE-NEST-LOOK.md`, `DASH-DECK-UI-LOOK.md` and Spencer's QA notes. Stills only: no motion was seen, and no AlwaysOnTop billboard (names, glows, egg pill) is in any capture. Sizes are pt (Roblox offset px) and studs.

The six problems the checker already listed stand as written. Where I add numbers to one of them it is marked **(adds to checker)**.

## Verdicts

| Item | Verdict | Why |
|---|---|---|
| Butterflies | **FIX** | Wings and colours are right (02, 19). The body is a floating dark plank, longer than the wing (19). Section 1. |
| Leaves | **GO** | Sparse, green, everywhere, no bursts (01, 02, 09, 18). Texture reads as a leaf. One note under Later. |
| Birds | **FIX** | Still a ball with stickers: blue eye, cube beak, plastic body, small wing (20). Section 2. |
| Nest | **FIX (small)** | Twigs, straw and sign are good and the egg is the smoothest thing in frame (04, 05). Three flat brown slats stand on the rim (04). Section 3. |
| Dash picker | **FIX** | Layout matches the mockup. The spotlight is a dark staircase behind the pet and the glow is a grey slab (07, 08). Section 4. |
| Dash HUD | **GO after the key cap fix** | Icons, pads, place pill and strip match (11, 12). Two adds in section 5. |
| Dash line-up | **FIX** | Lanes no longer overlap. Four racers fill 32% of the width while the two gate posts fill 36% (10, 15). Section 6. |
| Dash results | **FIX** | Headline, field chips, strip and buttons match. The pet is tiny and cropped, on the same staircase (13, 14, 16). Section 7. |
| Deck results | **FIX** | Strip v2 and the compact buttons are right (24, 25). The phone overlaps need the numbers in section 8. |
| Pet tag (U2) | **Not seen** | No capture. Needs one before the publish (section 9). |
| Hint card (U1) | **Not seen** | No capture. Same. |

## 1. Butterfly body

What is wrong in 19: the body is a square-ended box, it sits on top of the wings, and on screen it is as long as the wing is deep. The spec said 0.40 long against a 0.67 wing.

Keep 3 parts a butterfly. Change the body part only:

| | Now | New |
|---|---|---|
| Part | Block 0.08, 0.08, 0.40 | Block **0.09, 0.08, 0.42** with a `SpecialMesh`, `MeshType` Sphere, `Scale` 1, 1, 1 (a child, not a part): a tapered spindle, no flat ends |
| Colour | #2A2018 | **#33271C**, Material SmoothPlastic, `Reflectance` 0 |
| Wing root height | `CFrame.new(±0.04, 0.03, 0)` | **`CFrame.new(±0.03, 0, 0)`**: wings leave from the body's mid-line, not its top |
| Body offset | at the root | **0.03 forward** (-Z), so a little head shows past the fore wing |

- Measure in Studio first: if the body part is not 0.40 long today, that is a bug on top of the shape.
- The hand-off fade writes `Transparency` on the body as before. The mesh follows it.
- Pass test, from 3 studs and from above: no flat face or square corner, the body is shorter than two thirds of the wing's depth, and no gap shows between wing root and body.
- Antennae and thorax fuzz would have to be drawn into the wing textures. Later, only if it still reads bare.

## 2. Birds

Still 8 parts.

| Part | Now (20) | New |
|---|---|---|
| Eyes | `Reflectance` 0.2: they mirror the sky and read as blue beads | **`Reflectance` 0**, #14110F, SmoothPlastic |
| Moss head | #3F4438: near black, a helmet, and dark eyes vanish on it | **#6E7A4A** |
| Beak | a 0.17 cube, corner first: reads as a block | Block **0.10, 0.09, 0.24** with a `SpecialMesh` Sphere, at `H * CFrame.new(0, -0.03, -0.38)`, no turns. Colours unchanged |
| Body and head | smooth plastic with a highlight | **Material Sand** on both (matte, fine grain). `[check]` if it reads as gravel from 6 studs, use Fabric |
| Wings | plate 0.04, 0.75, 0.55: a sticker on a third of the flank | plate **0.04, 0.95, 0.66**, perched offset x **±0.54**, z **0.20**; the tips should cross the tail root |

Wanted before I pass it: each of the three, dead front and side-on, from 4 studs. The breast decal and both eyes have not been seen yet.

## 3. Nest

- **Slats (04):** three flat brown bars, about 0.12 wide and 0.6 tall, stand on the front rim. Find which part draws them (a fringe or tuft plate that is not `Transparency` 1, or a decal on a side face) and remove it. Pass test: walking round the nest, no straight vertical bar and no card edge.
- **Rim rolls (05):** they shine like varnished logs. Set the 8 rolls and the mound to **Material Wood** (the Texture stays on top).
- **Sign (05):** a dot follows "egg". If it is a full stop in `nest.sign`, remove it. If it is a knot in the texture, leave it.
- Sign yaw: with the checker. The words must face a player standing at the prompt point and one crossing from the star.

## 4. Dash picker

| Thing | Now (07, 08) | New |
|---|---|---|
| Spotlight | about 12 stacked bars: a dark ziggurat | **Delete the bars.** One ImageLabel, `spot-wedge.png`: 256 x 256, white, a trapezoid whose top edge is 18% of the width and bottom edge 80%, 4 px feathered sides. `ImageTransparency` **0.90**, from the stage's top to the pedestal's middle. Until it is uploaded, show nothing: a flat well is better than stairs |
| Glow | an olive-grey pill, hard edged, wider than the pedestal | ImageLabel `firefly-dot.png` (id 132656608030953), **190 x 40**, `ImageColor3` #FFE14D, `ImageTransparency` **0.55**, centred under the pedestal, behind it |
| Stage fill | navy on a teal card | the deck's `well` role, as the spec. If `well` is navy on this deck, leave it |
| Pet | standing, leaning | confirm it runs in place (the capture cannot show it) |

Both the picker and the results stage use the same two changes.

## 5. Dash HUD

- **Key caps (adds to checker):** besides being cut off, they are 16 px tall with 7 px text on a 1080p screen. Cap **20 tall x the HUD's UIScale, text 11 minimum**, wholly on screen: its right edge at least **8** from the screen edge. If it cannot overlap the pad's top right and stay on screen, put it at the pad's top **left**.
- **Blank pads (10):** the icons were missing for the first seconds of the first countdown. Preload the three icon ids when the client starts.
- **Question:** 11 shows a blue rounded square with an up arrow above the Jump pad. It is not in the spec. If it is the avatar's own jump button, hide it during a race.

## 6. Dash line-up

- **Camera fits the racers present, not eight.** Scale the line-up camera's back distance and height by `max(0.5, (span + 3) / 13.5)`, where span = (n - 1) x 1.5 studs. Target for four racers: the row is **55 to 65%** of the screen width and each gate post covers **under 6%** of it or is off screen. Eight racers: as now.
- Countdown digit: good where it is.
- Names: verified by state only. I need one real screenshot (not `screen_capture`) of the countdown with four names.

## 7. Dash results

With prizes off the Earned row drops out and the stage shrinks to about 132 tall, so the hop leaves the frame.

| Stage height | Pet standing height | Podium | Hop height on the card | Head clearance at the top of a hop |
|---|---|---|---|---|
| 172 (with Earned row) | **84** | 132 x 22, 14 above the bottom | **24** | 8 or more |
| 132 (without) | **62** | 110 x 18, 10 above the bottom | **16** | 8 or more |

- The pet stands on the podium's top, centred 10 right of the stage's middle so it clears the medal.
- The hop on the card is these pt values, not the 1.2 studs of the race pose.
- Spotlight and glow: section 4.
- Wanted: a 1st to 3rd result with prizes on (medal colour, confetti, Earned row). Not seen yet.

## 8. Deck results, phone (adds to checker)

- **Wallet chip:** the scrolling rows end **42** above the pane's bottom (8 + chip 28 + 6). Nothing draws under the chip.
- **Stat rows, pane 150 or wider:** the gain's right edge sits **6** left of the "Lv n" pill; the pill is right aligned at the pane's padding.
- **Stat rows, pane under 150** (Spencer's phone is 125): the pill becomes a **14 pt disc with the number only** (FredokaOne 10, ink on the stat colour, the same disc as the pet tag). Row: `10 | dot 10 | 4 | name | 4 | gain | 4 | disc 14 | 10`, about 116 wide.
- Desktop (24) is the unchanged grid layout: its text is small on a big screen. Later.

## 9. Before the publish

1. Captures of the pet tag (long and short name) and the hint card, phone size.
2. **Firefly glow:** the checker could not capture it because AlwaysOnTop billboards are not drawn. The spec says the glow is **not** AlwaysOnTop. Confirm it is false, or fireflies will shine through trees and walls.
3. A 6 s clip of butterfly flight for Spencer: soft motion was his first note and only he can pass it.

## Later (not blocking)

- A leaf that spawns within about 2.5 studs of the camera is 110 px tall for a moment (18). If Spencer notices: skip emits inside 4 studs of the camera.
- Start pad slabs are flat white and yellow sheets, and the gate posts are plain striped boxes (10). World pass.
- Butterfly antennae; an egg-shaped bird body.
