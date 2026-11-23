# Dewdrop fruit, the look (Fable, 2026-11-23)

World pass item 3, after the Architect check and Spencer's answer: **looks only**. No Stars, XP, finds, food, prompt, remote or sound. Lives in Garden life (`GardenLife` owns the instances, `LifeSim` the maths, Alive feature `life`). The texture was drawn and checked as a mock sprite at 160 to 8 px on lime, dark foliage, lawn and sky; **nothing here has been seen in Studio**, so I review captures before publish. This replaces scope section 3's "plain yellow Ball".

## 1. The Dewdrop: one billboard

| Thing | Value |
|---|---|
| Instances | 1 anchor Part (`Transparency 1`, 0.2 cube, anchored, no collide/query/touch/shadow) + `BillboardGui` + `ImageLabel`. No mesh, no Ball. |
| Texture | `assets/world/dewdrop.png`, 192x224, full colour on clear (`python scripts/draw_world_textures.py`; needs an upload) |
| BillboardGui | `Size = UDim2.fromScale(1.1, 1.28)` (studs; the body reads 0.75 wide), `LightInfluence 0.6`, `Brightness 1`, `AlwaysOnTop false`, `MaxDistance 110`, `ClipsDescendants false` |
| ImageLabel | fills the gui, `BackgroundTransparency 1`, `ImageColor3` white, `ScaleType Stretch` |
| Drawn look | plump drop with a blunt point: honey #FFE08C at the upper left to coral #FF6A48 at the belly, outline #B83A1C, one white gloss bean and a dot, a short stem and two lime leaves (#8FD63F, rim #2F8A2A) |

Why a billboard: it is round from every side for one draw, and a roll is just `ImageLabel.Rotation`. The stem tip is at the image top; the belly centre is 10% below the image centre, so a roll has a small lopsided wobble (wanted). [check] if it reads as a flat sticker close up, fall back to two crossed decal plates 1.1 x 1.28 x 0.02 with the same file on Front and Back.

**Not the Hue Egg fruit.** That item (`HueCatalog`: Rose #FF327A, Tide #008DFF, Citrus #FFCC00, Iris #9350FF; drawn by `PetFruitEating` as `ConfirmedHueFruit`) is a tiny plain single-colour SmoothPlastic Ball at the pet's mouth, and flat jar art in menus. The Dewdrop is a two-tone drop with an outline, gloss and a leaf cap, in none of the four hue colours, never near a mouth and never eaten. The scope's yellow Ball was a Citrus berry at a glance; that is why it changed.

## 2. On the tree

- **Which trees:** `LifeSpots.Crowns` (12) while `crowns()` is `"lime"`. Pink crowns: no fruit at all.
- **How many:** 3 slots a crown. Slot k of crown i is filled when `Wind.hash(i*8+k, 11) < 0.8`, so 2 or 3 hang on most crowns. Only crowns within 90 studs of the camera (`Life.PetalReach`) build theirs.
- **Where** (top = `position + (0, size.Y/2, 0)`; sx, sy = `size.X`, `size.Y`): the stem tip sits at `top + (0.36*sx*cos a, -0.80*sy, 0.36*sx*sin a)`, with a = 40, 160, 285 degrees plus `Wind.hash(i, 12) * 360`. That is just inside the crown's lower skirt, so the fruit hangs below the leaves against trunk and sky. The image centre is 0.64 below the stem tip.
- **Hanging sway:** a pendulum about the stem tip: angle = `(3 + 12 * Wind.at(spot, now)) * sin(now * 2.2 + k)` degrees, toward `Wind.Direction`; set `Rotation` to the angle and move the anchor so the stem tip stays put. Budget level 1: still.
- [check] one capture per crown size (17 wide landmark, 9 to 11 others): if a fruit is buried in leaves or floats clear, change the one `-0.80` factor, not per-tree offsets.

## 3. The drop

| Step | Numbers |
|---|---|
| Trigger | `Wind.at(crown.position, now)` rises past **0.8** (re-arms under 0.5). Gust number n = `floor(Wind.localTime(crown.position, now) / Wind.Slot + 0.5)` |
| Chance | the crown drops one when `Wind.hash(n*16+i, 13) < 0.35`; which filled slot: `Wind.hash(n*16+i, 14)`. Same on every client, no remote |
| Let go | 0.15 s: stem tugs 20 degrees downwind, then free |
| Fall | 0.55 s to `groundY` (quadratic, speeding up), 1.2 studs downwind, half a turn of `Rotation` |
| Bounce | two: 0.9 studs high over 0.34 s, then 0.3 over 0.2 s, 0.5 and 0.2 studs further downwind. On each landing a squash for 0.06 s: gui size x1.15 wide, x0.85 tall |
| Roll | 1.6 to 2.4 studs (roll `hash(.., 15)`), heading `Wind.Direction` turned by -25 to 25 degrees (`hash(.., 16)`), 0.9 s ease-out; `Rotation` turns 150 degrees a stud, in the travel direction as seen on screen |
| Rest | 18 s, centre 0.5 above the ground, leaning 12 degrees; a gust over 0.6 rocks it 6 degrees |
| Fade | 1.2 s: `ImageTransparency` to 1 and size to x0.7, then hidden |
| Regrow | the slot is empty for 45 s after the drop, then grows x0 to x1 over 1.5 s with a x1.12 overshoot |

## 4. Caps (by `AliveBudget` level 0 / 1 / 2)

| Thing | 0 | 1 | 2 |
|---|---|---|---|
| Hanging fruit shown (`Caps.fruit`), nearest crowns first | 16 | 8 | 0 |
| Loose fruit at once (`Caps.loose`); over the cap, the drop is skipped | 3 | 2 | 0 |
| Step rate | 30 Hz | 15 Hz, no hanging sway | nothing exists |

A pool of 16 billboards, made once and parked at `Life.Hidden`; never created or destroyed in play.

## 5. The pet bat

When a Dewdrop comes to rest, and at each 2 s poll while it rests, if a garden pet the client draws is within **3 studs** (flat), the fruit is batted **once in its life**: a hop 0.7 studs up and 1.0 stud straight away from the pet over 0.4 s, one 0.2 stud bounce (0.15 s), a full turn of `Rotation`, the landing squash, then it rests out its remaining time. The landing spot passes section 7 or the hop is straight up. No new pet animation and no server call: the pet does nothing new. If the pet view already has a head look-at, point it at the fruit for 0.6 s; otherwise skip it, the hop alone reads as a bat. Avatars do not nudge fruit (cut from the scope: it would read as a tap reward).

## 6. Reduced Motion

Fruit hangs, upright and still; none let go, none lie on the ground, no regrow pop (a slot is just filled). Turning it on mid-flight hides loose fruit at once and refills their slots.

## 7. Never in the way

- A drop is **skipped** (the fruit stays on the tree) unless its final resting point: has a `groundY` no more than 14 below the crown's centre (not water, not off the island); passes `Sim.clear` (camera 6, station 8, pad 2); is 4 or more studs from the Dash course line **whether or not a race is live** (pass the course every time, unlike petals); is 3 or more from every `FindSpots` spot; and is outside the park kerb ellipse grown by 2 studs (`ParkLayout`). Check the roll's end and the bat's end, not only the first landing.
- While a race is live: no drops anywhere, and loose fruit fades in 0.3 s.
- Loose fruit closer than 6 studs to the camera fades in 0.3 s; farther than `Sim.Drop` (120) it is dropped. During a hatch (`hatching`) everything is hidden, as the rest of Garden life.
- No collision, no query, no touch, no shadow, no prompt, no highlight, no sparkle, no sound. Nothing can be clicked or collected.
- Never pink, white or a hue colour; never larger than 1.3 studs; never more than 3 on the ground.

## 8. Needed, and captures for round 2

Upload `assets/world/dewdrop.png` and put the id in `Life.DewdropTexture`. Captures: a lime crown with fruit from 15 and 40 studs, side-on and from under it; one frame mid-fall; one at rest on the lawn beside a pet (scale check against a paw); the same crown at budget level 1.

## Uploaded (Opus, 2026-11-23)

- dewdrop.png -> rbxassetid://82054526707528
