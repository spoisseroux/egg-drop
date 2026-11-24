# World feel, the egg corner, the race line, leaves and Dewdrops: the look (Fable, 2026-11-23)

For beta (14) QA items **W3, W4, D1, Q1, Q2, F2 (look and copy), Q5, D2 / B5** (`FEEDBACK.md`). Direction only; Opus builds.
Not here: the waterfall, lime crowns and water sound (the island re-export session), F3 / F4 / Q6 (my sound note).

**The rule, unchanged:** the world and ambient life are realistic, textured and matte, in lower-saturation natural
colour, so the pets are the brightest, smoothest things on screen. Ambient motion is eased: nothing snaps or bursts.

**What I looked at:** Spencer's five phone shots, `Nest.lua`, `NestClient.lua`, `NeedBubble.lua`, `ThingsTrail.lua`,
`StationAttract*.lua`, `GardenLife.lua`, `LifeSim.lua`, `DashClient.lua`, `build_dash_course.py`, `HollowWorldLayout.lua`.
**Nothing here has been seen in Studio.** Every `[check]` is a one-look or one-probe test. The W3 references are
techniques named from memory of those games; I did not run a web search and no art is to be copied.

Common, as before: new world parts `Anchored`, no collide / query / touch, `CastShadow` off unless said. Budget levels
are `AliveBudget` 0 / 1 / 2; level 2 and Reduced Motion show none of the new motion unless said. New textures are
script-drawn (extend `scripts/draw_garden_life_r3_textures.py`), no outside or generated art.

---

## 1. W3: alive yet calm

**What good chill-out hubs do** (Animal Crossing villages, the Chao Garden, A Short Hike, Delfino Plaza):

1. **One wind, seen on many things.** Trees, grass, cloth, chimes and leaves all answer the same gust a beat apart.
   The player reads "weather", not "effects".
2. **Slow loops at three distances.** Something moves near (2 to 10 studs), mid (10 to 60) and far (100+), each slower
   than the last. Stillness at any one distance reads as a painted backdrop.
3. **Light that changes.** Dapple under trees, lamps coming on one by one, a long dusk.
4. **Rare shared moments.** Calm is the base; excitement is a small event every few minutes that everyone sees at once
   and that asks nothing of the player.
5. **Residents with their own business.** Things that are doing something when you arrive and carry on when you leave.
6. **Quiet has room in it.** Few sounds, gaps between them. (Sound is in my other note.)

The garden already has 1 in part (leaves, Dewdrops, gusts), 5 in part (birds, butterflies, pets) and 3 in part (the
garden hour). It has nothing at the far distance, nothing in the water, no dapple, and no shared moment.

**Eight additions, ranked by impact for cost.** Build in this order; each stands alone.

| # | What | Numbers | Cost |
|---|---|---|---|
| 1 | **The big breath** (the shared moment). A long, strong gust on a schedule, on top of the normal gusts, the same on every client (server time, like the Grove). | Every **240 to 360 s** (hash of the breath number). Wind `g` eases 0 to 1 over **2.5 s**, holds **3 s**, eases out over **5 s**. During it: leaf emits x3 (section 6), the skitter emitter runs, every Dewdrop sways at `swayGust`, the arch chimes swing (row 2), birds on crowns do one hop pair and a wing flick, and the player's own pet looks up for 1.2 s `[check]` (only if a pet look-at hook exists; else skip). No UI, no reward. Reduced Motion: none. | Small: one schedule function beside the gust, and the existing systems read `g`. |
| 2 | **The arch chimes swing.** The five coloured bars under the arrival arch (shot 1) hang dead still. | Each bar pivots at its top: `angle = (3 + 11 * g) * sin(2π * 0.45 * t + k * 1.3)` degrees along `Wind.Direction`, k = bar index. Written at 15 Hz, only within 70 studs of the camera. Level 1: 8 Hz. `[check]` the bars are separate parts; if they are merged into the arch mesh, re-export them as five parts (ask the island session) or skip. Also take their saturation down one step so they sit under the pets: multiply each colour's saturation by **0.75**. | Small, if the parts are separate. |
| 3 | **Dapple under the trees.** Soft moving leaf shadow on the ground. | One decal plate per crown, for the **6 crowns nearest the camera** (level 1: 3). Plate 9 x 9 studs, 0.05 over the ground, texture `dapple.png` (256 x 256, script-drawn: soft dark blobs with light gaps, alpha), colour **#1E2A16**, `Transparency` **0.72** by day, 1 at night (follow daylight: fully gone under 0.30). Drift: the plate's centre moves `0.35 * sin(2π * t / 9)` studs along the wind and turns ±4 degrees over 13 s; add `0.5 * g` studs in a gust. Written at 10 Hz. `[check]` on the lawn it reads as shade, not a dark sticker; if it does, 0.80. | Medium: one texture, a 6-plate pool. |
| 4 | **Koi in the pool.** Something alive in the water (the pool at the foot of the falls, shot 4 right). | **3 koi** (level 1: 2). Each is one decal plate 1.3 x 0.5 studs, 0.25 **under** the water surface, texture `koi-a/b/c.png` (128 x 48, seen from above: muted orange-and-white, pale gold, slate; no outline). They swim a slow figure of eight inside an ellipse 60% of the pool, **0.5 studs/s**, with a tail-sway yaw of ±8 degrees at 1.1 Hz. Every **9 to 15 s** one rises: a ripple ring decal on the surface grows 0.4 to 1.6 studs and fades 0.3 to 1 over 1.4 s. Player within 3 studs of the bank: they glide to the far side at 1.2 studs/s. Coordinate with the island session for the pool's centre, size and surface height `[check]`; the water must be see-through enough to show them, else put the plates 0.02 over the surface at `Transparency` 0.35 (a shape under the water). | Medium. |
| 5 | **A far flock.** The far distance moves. | Every **90 to 150 s** by day, **5 birds** cross the sky in a loose V, **130 to 170 studs** from the island's middle, 45 to 60 studs up, at 9 studs/s, on a shallow arc; about 25 s in view. Each bird is 2 wing plates (0.9 x 0.35), flat colour **#3B3A40**, no texture, flapping `φ = 25 * sin(2π * 2.6 * t + k)`. 10 parts, written at 15 Hz, removed when done. Level 1: 3 birds. None at night (daylight under 0.7). | Small. |
| 6 | **Lamps come on one by one; a shooting star.** Dusk is an event. | As daylight falls through **0.45**, the garden lamps light in order of distance from the plaza, **0.35 s apart**, each easing its light and glow from 0 to full over 0.8 s (off the same way at dawn, 0.15 s apart). `[check]` what the lamps are today (one switch for all, or per lamp). Once a night, at a hashed time in the middle third: **3 streaks, 6 to 9 s apart**; each a Beam 14 studs long, 0.25 wide, **#FFF4D6**, across the sky 200 studs out, 0.7 s, fading tail. (B2, no fireflies at night, is the first fix here: the night has nothing in it without them.) | Small to medium. |
| 7 | **Texture on the ground.** The lawn is one flat green. | (a) **Leaf litter** under trees: 8 decal plates, 3 x 3 studs, `litter.png` (256 x 256, alpha: scattered leaf A / B / C / D shapes, section 6), `Transparency` 0.15, one under each of the 8 largest crowns, offset 1 to 2 studs downwind. (b) **Mown and clover patches**: 10 decal plates 7 to 11 studs across, `lawn-patch-a/b.png` (soft-edged, alpha), tinting the grass ±6% in value (#2E7A34 darker, #4C9A45 lighter), `Transparency` 0.55. (c) **Worn path edges**: where the dirt path meets the grass, 12 plates 4 x 1.5 studs of `path-fray.png` (dirt breaking into grass). All static; they show at every budget level. Hand-placed list in a layout module, with the same clear rules as the Dewdrop rest spots (off the course, the pad, find spots). | Medium: three textures, about 30 static plates. |
| 8 | **Dragonflies over the water** (after 4). | 2 by day (level 1: 1) over the pool and stream: body 0.35 long, two wing plates 0.5 x 0.14 at `Transparency` 0.55, body **#3F6F78**. Motion: hover 0.8 to 2 s (wings a blur: swap two wing angles ±12 degrees at 15 Hz), then a straight dart of 3 to 5 studs in 0.35 s (ease out), repeat; 1 to 1.6 studs over the water. | Small. |

Phone budget for all eight: about **55 parts** at level 0 (10 flock + 6 dapple + 3 koi + 3 ripple pool + 6 dragonfly +
about 30 static plates), **no new emitters** (the emitter cap stays 3, section 6), 2 Beams for a few seconds a night,
and 6 new small textures. The written-per-frame count rises by about 20 CFrames at 10 to 15 Hz. All of it is client-only.

**Do not add:** more particles, more glow, more saturated colour, or anything that loops faster than about 1 Hz at mid
distance. Those read as busy, not alive.

---

## 2. W4: is the world too small?

**Recommendation: do not rescale.** The island is about 185 x 175 studs. A literal rescale moves every station, the
walk map, the safe-ground sweep, `IslandBounds` walls, find spots, the Dash course and pad, park kerbs, leaf cover
circles, the nest spot and every spec that pins a coordinate, and it also makes the lawn emptier, which is the
opposite of W3. It feels small for four reasons that are cheaper to fix:

| Why it feels small | Evidence | Fix | Numbers |
|---|---|---|---|
| **You see all of it at once.** | Shot 1: from the arrival lawn the playground, the arch, the plaza, the far trees and the far rail are all in one frame, with nothing in front of anything. | **Three sightline breaks**: a clump of 3 trees or a hedge-and-rock group at each of three points, so each area is revealed as you walk. Places a walk "between rooms". | (1) Between the arrival lawn and the playground. (2) On the arrival path about 15 studs before the plaza, so the plaza opens round a bend. (3) Between the plaza and the pool. Each clump 8 to 12 studs wide, tallest thing 12+ studs, with a gap of 6+ studs for the path. Existing tree and rock meshes only. `[check]` each against the walk map, find spots and the course (a clump is solid). |
| **The camera looks down on it like a diorama.** | Shots 1 and 3: the horizon is at the top edge; most of the screen is lawn seen from above. `RoomView` places the arrival camera at (5, 6, 12) from the avatar: about 25 degrees down. | **Lower the default look** so the horizon sits about a third of the way down and things overlap in depth. Cap the zoom so the island cannot be seen as a toy. | Arrival offset **(4, 3.5, 11)**: about 17 degrees down. `CameraMaxZoomDistance` **22** `[check]` today's value; `CameraMinZoomDistance` unchanged. FOV stays **65** (billboard and prompt sizes are tuned to it). `[check]` on a phone that the thumbstick and the jump button do not cover the pet at this pitch. |
| **Nothing beyond the edge.** | Shot 3: past the rail there is only pink cloud. The world visibly ends 20 studs away. | **Layered distance.** Far islets and haze, so the island sits in a bigger place. | **4 far islets**: low-detail rock-and-grass shapes (300 triangles each at most, reuse the floating-rock mesh scaled up), at **260, 340, 450 and 600 studs** from the middle, on four different bearings, 20 to 60 studs below to 30 above the island's height, the nearest with 2 or 3 tree shapes on it. Flat matte colours stepped toward the sky: mix the rock and grass colours with the sky colour by **25%, 40%, 55%, 70%** by distance. No collision, no shadows. Haze: `Atmosphere.Density` up until the far rail of the island (about 150 studs) is about **20%** toward the sky colour and the nearest islet about 40% `[check]` today's Atmosphere values; start at Density +0.05 and judge by capture. |
| **Everything is the same grain.** | Big chunky props (the arch is about 14 studs high, the path about 6 wide) and a flat lawn give the eye no small things to count. "Ground flowers: way better" is the same finding. | **Small-scale detail near the player.** Section 1 row 7, plus more of the ground flowers Spencer liked. | Aim: from any standing point, at least 6 things under 1 stud across within 10 studs (flowers, tufts, pebbles, litter). |

One more to **test, not ship blind:** the garden walk speed. At 16 studs/s the island is crossed in under 12 s.
Try **14** on the beta `[check]` today's value; if it feels sluggish to Spencer, revert at once. Do not go under 13.

Order to try, cheapest first: camera pitch and zoom cap (an hour), haze (an hour), far islets (half a day),
sightline breaks (half a day, needs the walk map re-swept), walk speed (a switch). Capture shot 1's view before and
after each. If it still feels small after all five, the next step is **adding a place** (a second small islet reached
by a bridge), not scaling this one.

---

## 3. D1: one place for eggs

**Recommendation: yes, one place, two verbs.** Shot 4 shows the problem: an egg on a pedestal with an egg marker, and
8 or so studs away a second egg in a nest with its own words. Two egg things with two vocabularies in one frame.
Make the nest part of the egg station, visibly, and keep the two actions distinct: **Hatch eggs** (spend Stars, now)
and the **napping egg** (free, later). Do not merge the two into one screen flow: the nest must stay a thing in the
world you walk to and see change, or the daily return loses its object.

### Layout: the nest at the station's foot

The station cannot move cheaply (it is in the world mesh and `HollowWorldLayout.Stations.Eggs` =
(-31, 4.1, -11)); the nest can (`Nest.Spot`, `Nest.Facing`, one blocked region).

- Let `S` = (-31, -11), `C` = (-30, -4) (the plaza's middle), `f` = unit(C - S) = (0.14, 0.99), `e` = (0.99, -0.14)
  (the station's east side, the side arriving players come from).
- **Nest root E1 (recommended): `S + 5.5 e + 2.0 f` = about `Vector3.new(-25.3, y, -9.8)`**, y by raycast.
  `Nest.Facing` stays (-30, y, -4). That is 5.9 studs from the station's centre, 9.8 from the Journal, 7.5 from the
  plaza's middle (inside the patterned ring, off the star).
- The sign moves to the nest's **outer** side (away from the station), so station, egg and sign read left to right
  as one group from the plaza's middle. The Bear's curl spot stays root-local (2.2, 0, -1.4) unless that puts it
  inside the station's footprint `[check]`; then mirror it to (-2.2, 0, -1.4) and put the sign on +X.
- **`[check]` before building:** rerun `scripts/probe_nest_spot.luau` at E1. Needed: 2.6 studs clear all round, the
  prompt point (root-local 0, 0, -2.6, world about (-26.9, -7.8)) on open marble, and the main walking line from the
  arrival path to the station not through the nest. If E1 fails, **E2**: the mirror on the west side,
  `S - 5.5 e + 2.0 f` = about (-36.7, y, -8.2) (9.3 from the Wardrobe station). If both fail, keep spot A and do only
  the "one marker" and "one screen row" parts below.
- `[check]` which thing the pedestal egg in shot 4 is. If it is the Eggs station's own display, E1 puts the nest
  beside it. If it is something else 8 studs from spot A, tell me before moving anything.

### What the player sees

- **One marker.** The Eggs station marker (the gold egg pin) stands for the whole corner. The nest gets no marker of
  its own, and the Show me trail for the nest ends at the nest's prompt point with the pin text of section 4.
- **The station's first-visit line** (the `StationAttract` intro, name + one line) becomes:
  **`Eggs`** / **`Hatch new friends. Your napping egg waits here too.`** (`UICopy`; check at 320 px width).
- **The Hatch eggs screen** gets one quiet row at the top of its list, above the egg types: the nest icon,
  **`Napping egg`**, and the clock (`Hatches in 7 h`, or `Hatch me!` in gold). Tapping it closes the screen and lays
  the Show me trail to the nest (4.6 studs away). No gift details, no button to hatch from the menu. This is also
  where F1's "egg" chip can point if the nest trail is not wanted.
- From the plaza's middle: the machine, then the low dark nest with the pale egg in it, then the small sign. The egg
  is the only bright thing in the nest; the station stays the taller landmark.

### Prompts that remain

| Prompt | Where | When | Reach |
|---|---|---|---|
| **Hatch eggs** (the station's) | the station, as today | as today | as today (9) |
| **Tuck in** (`nest.tuck`) | the nest's front point | only while this egg is untucked | **4.5** (was `Client.Prompt` `[check]` today's value) |
| **Hatch** (`nest.hatch`) | the nest's front point | only while the egg is ready | **4.5** |

- So for most of the day the corner has **one** prompt. The nest prompt's object text stays `Napping egg`.
- Both use the same key; Roblox shows one prompt per key, the nearer. `[check]` standing between the two (about 3
  studs from each), the shown prompt is the one you are facing or nearer to, and it does not flicker as you turn. If it
  flickers, drop the nest reach to 3.5.
- Cost to name for the builder: `Nest.Spot`, the blocked region (it follows `Nest.Spot`), the walk map re-check, the
  trail end, `clientUI.nestPlace`, `tip.nest`, the Life `Keep.station` ring (leaves and bubbles already keep 8 off
  stations; the nest now sits inside it, which is fine), any spec that pins (-17.5, -2.5), and `V3-TEST-PASS.md`.

---

## 4. Q2 and Q1: one calm line at the nest

**What shot 4 shows:** the same sentence three times and a fourth thing on top. The rail toast ("Tucked in! Come back
in 8..."), the label's first pill ("Tucked in! Come back in 8 hours to hatch a gift."), the label's second pill
("Bear's egg naps for 8 hours. Come back to..."), and the Bear's ball bubble drawn over both.

**The rule: the nest has one pill, with one message, and it never shares the screen with a need bubble.**

### What the pill says

First row that is true wins. `n` = eggs hatched so far.

| # | When | Text | For |
|---|---|---|---|
| 1 | a beat: just tucked in, first time ever | `nest.tuckedFirst` | 6 s |
| 2 | a beat: just tucked in, later times | `nest.tucked` | 4 s |
| 3 | a beat: a new egg just landed after a hatch | `nest.next` | 5 s |
| 4 | the egg is ready | `nest.ready` ("Hatch me!"), gold pill | while near |
| 5 | untucked and `n == 0` | `nest.how` ("{pet}'s egg naps for {hours} hours. Come back to hatch a gift.") | while near |
| 6 | player within **8** studs and `n >= 1` | the "Inside: ..." line | while near |
| 7 | otherwise | the clock (`nest.hours` / `nest.minutes`) | while near |

- The explainer (row 5) shows **before** the tuck-in, where it answers "what is this and why press it". After the
  tuck-in the beat (row 1) says the same thing once, then the clock takes over. It is never shown under another line.
- **The second pill is deleted** (`InsidePill`). Its two uses are rows 5 and 6 above.
- **The tuck-in rail toast is dropped** (previous spec, section 5 item 2). The player has just pressed a prompt 2.6
  studs from the egg; the pill is in front of them. The HUD chip ("Egg 8 h") is the lasting record.

### Size

- One cream pill (ink 2 px stroke, as today), **at most 220 px wide**, padding 12 px each side, text **14 px** (the
  clock and "Hatch me!") or **13 px** (sentences), **two lines at most**. Height 28 px for one line, 46 px for two.
  Rows 1, 3 and 5 wrap to two lines at 196 px with a 12 character pet name `[check]`; if any needs three, drop to
  12 px before allowing a third line.
- Fixed pixel size, as today. The billboard is 220 x 46, the pill bottom-anchored in it, so a one-line pill does not
  jump when the text changes.

### When it shows (Q2 and the nest's own part of Q1)

Distance is from the **player's root to the nest root**, not from the camera (`MaxDistance` is from the camera, which
sits 12+ studs behind; `StationAttract` already gates by `Enabled` this way).

| State | Shows within | Fades |
|---|---|---|
| Rows 5, 6, 7 (clock, explainer, inside) | **12 studs** | from 12 to 10 in, by distance: transparency = clamp((d - 10) / 2, 0, 1) on the pill, stroke and text |
| Row 4 (ready) | **18 studs** | from 18 to 15 |
| Rows 1 to 3 (beats) | 18 studs (the player is at the nest anyway) | 0.25 s in, 0.4 s out |

- `AlwaysOnTop` **false** for rows 4 to 7 (so the pill never shows through the arch, a tree or the station), **true**
  only for the beats. Keep `MaxDistance` at 60 as a backstop.
- Beyond those distances the nest speaks through its look only: the egg's four looks, the halo when ready, the sign.
- **With a need bubble:** while the pet's need bubble is enabled and the pet is within **6 studs** of the nest root,
  the pill is hidden, except rows 1 to 4. During a beat (rows 1 to 3) the need bubble is held back until the beat ends
  (it appears 0.3 s after). When the egg is ready (row 4) both may show; the pill lifts by 34 px
  (`StudsOffset` stays, add a pixel offset) so they stack with a gap, bubble below. That is the only time two things
  are up, and one of them is an icon.
- Halo `MaxDistance` 120 to **80**, Zzz billboard 80 to **40**.

### Q1: the "Napping egg" tag over the arch

That tag is not the nest's label. It is the **Show me trail's pin** (`ThingsTrail` "Pin": 190 x 64 px, `AlwaysOnTop`,
no distance limit, named with `onb3.nest.title`). At 90 studs a fixed-pixel billboard is bigger than the arch.

- **The pin shows only when the player's root is within 28 studs of the trail's end**, fading in from 28 to 22 (same
  formula as above). Farther than that the paw prints lead and the HUD chip already names the goal.
- Inside 28 studs keep `AlwaysOnTop` true (it is a "here" marker) but shrink it: **150 x 48 px**, text 15 px.
- For the nest trail the pin reads `nest.hatch` + "!" when the egg is ready ("Hatch!") and `Napping egg` otherwise.
- This is a change to the trail for every destination (park, finds, nest): the same far-away tag would show for each.
  `[check]` that no first-visit step relies on seeing the pin from far (the paw prints should carry it).

---

## 5. F2: the race line

Once queued at the Garden Dash waiting pad (`Course.Pad`, (66, -21), radius 2.5), the player stays inside a visible
boundary and leaves by tapping the line's notification and confirming.

### The boundary: a rope ring

A low rope on short wooden stakes round the pad, like the edge of a village fete. Matte, wood and jute, nothing glows.

| Part | Count | Size | Look |
|---|---|---|---|
| Stake | **10**, evenly round a circle of radius **R = 4.0** | 0.16 x 1.0 x 0.16, sunk 0.1, each leaning out 4 degrees, turned by a hash so no two match | Material Wood, **#6B4A2B** (the nest sign post). Top 0.12 painted **#E9E2C8** (chalk), flat. |
| Rope | 10 spans, stake top to stake top | a Beam 0.11 wide, `CurveSize0 / 1` set for a sag of **0.22** at mid-span, `Segments` 8, **`FaceCamera` true** (a beam's width lies on its secondary axis; without this a span seen from above is edge-on, as the falls strands were) | texture `rope.png` (128 x 32, script-drawn twisted jute, tiles along the span), colour **#B79A66**, `LightEmission` 0, `LightInfluence` 1, `Transparency` 0 |
| Ground ring | 1 decal plate, 9 x 9 studs, 0.04 over the lawn | a soft ring 0.4 wide at radius 4.0, plus scuffed lawn inside | `queue-ring.png` (256 x 256, alpha): trampled, paler grass **#9DB37A** at 45% for the inside, a chalk line **#E9E2C8** at 55% for the ring |

- `[check]` R = 4.0 against `build_dash_course.py`'s pad checks (level lawn, 1 stud off every lane, 0.5 off every
  obstacle, 4 from the cliff): it was validated at 2.5. If 4.0 fails, **3.2**; do not go under 3 (two avatars and
  two pets must fit).
- **Who sees it:** everyone, whenever at least one player is queued or the race is gathering. It rises when the first
  player queues: stakes come up out of the lawn over **0.45 s** (ease out, 0.05 s apart round the ring), the rope
  fades in over 0.3 s after. It sinks the same way 2 s after the line empties. Reduced Motion: it fades in and out
  over 0.3 s, no rise.
- **Who it stops:** only queued players. 10 invisible wall boxes (one per span, 6 studs high, 0.4 thick) on the
  queued player's own client, switched on once their root is inside R - 0.6 (so a player who joins from the prompt
  just outside can walk in). The server keeps the last word: a queued player whose root is more than **R + 2.5**
  from the pad for over 1 s is taken out of the line, with the toast below. Others walk through the rope freely.
- The queued player's pet waits inside the ring `[check]` (if the pet's roam is server-planned, give it the pad as a
  stay spot; if that is a big change, leave the pet free and say so).
- **Touching the rope:** when the queued player pushes on a wall, the two nearest spans sway (sag 0.22 to 0.34 and
  back, 0.5 s, eased) and the line's notification pulses once (scale 1 to 1.06 to 1 over 0.3 s). At most once every
  4 s. That is how the player learns where the way out is. Reduced Motion: the pulse only.

### Leaving: the notification, then a confirm

- The rail status that reads "You're next in line" today becomes tappable, with the rail's chevron, and reads:

| Key | Now | New |
|---|---|---|
| `dash.queue` (rail status while queued) | You're next in line | `You're in line. Tap to leave.` |
| `dash.reason.Queued` (the toast on joining) | You're next in line | `You're in line for the next race!` |
| `dash.line.title` (new, confirm) | | `Leave the line?` |
| `dash.line.line` (new) | | `You'll lose your spot for the next race.` |
| `dash.line.yes` / `dash.line.no` (new) | | `Leave` / `Stay in line` |
| `dash.line.left` (new, toast after leaving, and when the server takes a strayed player out) | | `You left the line.` |

- The confirm is the existing `ConfirmDialog` (as `dash.ask`). **Stay in line** is the default, larger, on the right;
  **Leave** is the quiet button. Back / B closes it as Stay.
- On Leave: walls off at once, toast `dash.line.left`; the ring sinks if the line is now empty.
- Opening the Pocket Deck while queued asks the same question (today it leaves silently).
- Run the localization export and sync with the build.

---

## 6. Q5: more leaves blowing, with texture

Two things are wrong: there are too few, and they **fall** rather than **blow**. And at a drawn 0.25 studs, "texture"
can only be read as silhouette and two-tone, not as veins. So: more of them, a stronger lean, leaves that scud along
the ground in a gust, four leaf shapes instead of two, and leaves lying on the lawn.

### Counts and wind (`Sim.Leaf`, `Sim.Caps.leaves`)

| | Now | New |
|---|---|---|
| Emits a second, level 0 / 1 (`rate`) | 2.4 / 1.2 | **4.0 / 2.0** |
| Gust boost (`boost`): rate x (1 + boost x g) | 0.5 | **1.5** (a full gust: 10 a second for its 3.5 s) |
| In the big breath (section 1) | | rate x 3 for its whole 10.5 s, still under the cap |
| Alive cap, level 0 / 1 | 28 / 14 | **44 / 22** |
| Calm lean (`lean`) | 0.25 | **0.45** (they slant even in calm) |
| Gust push (`gust`) | 0.9 | **1.3** |
| Cross sway (`sway`) | 0.3 | 0.35 |
| RotSpeed | -45 to 45 | **-70 to 70** |
| Lifetime, fall, drag, speed, spawn square, height | | unchanged |

- **`reach` and `side` must be re-derived** (`LifeSim.spec`'s drift run) with the new lean and gust before the build:
  they keep leaves from drifting under roofs. Expect reach about 22 `[check]`.
- Size keys stay as R4 (drawn long side at most 0.25 studs). If 44 leaves still read as thin: raise the cap to 56 / 28
  before touching size.

### Four leaves in one emitter (no extra emitters)

The emitter cap stays **3**. Put the leaf shapes on one **2 x 2 flipbook sheet** so one emitter draws all four:

- `leaf-sheet.png`, 192 x 192, four 96 x 96 cells, script-drawn. `FlipbookLayout` Grid2x2, `FlipbookMode` Random or
  `FlipbookStartRandom` true with `FlipbookFramerate` 0, so each leaf picks one cell and keeps it `[check]` that a
  leaf does not flip between shapes in flight; if it does, fall back to two leaf emitters (A + C, B + D as two
  1 x 2 sheets) and no skitter emitter.

| Cell | Leaf | Shape (silhouette is what reads) | Colour |
|---|---|---|---|
| A | broad leaf (today's `leaf-a`, redrawn) | a plain oval with a point, short stalk | fresh green **#5E8F3A**, one half 12% darker along the midrib (a lit side and a shade side) |
| B | narrow leaf (today's `leaf-b`, redrawn) | a long willow shape, slightly bent | olive **#7C7A3A** going to brown **#7A5A30** at the tip |
| C | **lime leaf (new)** | heart-shaped with a lopsided base and a saw-tooth edge: the leaf of the trees it falls from | yellow-green **#8FA83E**, pale midrib **#C9D08A**, darker half as A |
| D | **dry curled leaf (new)** | a "C" curl seen side-on, a notch missing from one edge | ochre **#A8762E** outside, shadow **#5C3D1C** inside the curl |

- All four: no outline, no gloss, a 2 px darker rim only where the shade side is, alpha edge anti-aliased. Contrast
  between the lit and shade halves is the "texture" that survives at 12 px on a phone.
- Emitters: **1** leaves (the sheet), **2** petal (unchanged, share **10%**, was 15%), **3** ground skitter (below).
  The leaf emitter's cells are equally likely; that gives A 22.5%, B 22.5%, C 22.5%, D 22.5% of all emits. `[check]`
  if the dry leaf D reads as litter in the air at that share; if so, draw a second lime leaf in its cell and keep D
  for the ground only.

### Leaves along the ground (the third emitter)

- Runs only while `g` is over **0.5** (a gust's top, and the big breath). Uses the leaf sheet.
- Spawns in the same square round the player, on the ground (0.12 over `groundY`), never under cover (the same test).
- Speed **3 to 5** studs/s along `Wind.Direction`, `SpreadAngle` 12 flat, `Acceleration` (0, 0, 0), `Drag` 1.2 (they
  scud and slow), lifetime **2 to 3 s**, RotSpeed -220 to 220, the same size keys, `Squash` flicking 0 to -0.5 twice
  (tumbling), transparency 1 to 0.1 in the first 10%, back to 1 over the last 25%.
- Emits **6 a second** while it runs (level 1: 3). Alive cap **14 / 7**, on top of the falling cap.
- `[check]` they do not slide through kerbs, the nest or the pool in a way that shows; they live 3 s and are 0.25
  studs, so I expect not. If they do, shorten the life to 1.8 s.

### Leaves on the lawn

Section 1 row 7a (the litter plates) uses the same four shapes at rest. That is the texture that stays on screen.

Level 2 and Reduced Motion: no falling or scudding leaves (unchanged); the litter plates stay.

---

## 7. D2 / B5: the Dewdrops

**Recommendation: keep them, hang them properly, and make the fallen one a snack for the pet.** A fruit that ripens,
falls and gets eaten is exactly the "residents with their own business" of section 1, and it is the Chao Garden's
best idea in one beat. Removing them loses the only tree-to-ground-to-pet link in the garden. They must not become a
collectible or a chore: no counter, no prompt, no currency.

### B5a: floating under the crowns

Today the stem tip is at `down` 0.80 of the crown's height and `out` 0.36 of its width, and the image centre hangs
`hang` 0.64 below that: by design it hung *under* the skirt, and on the crown shapes now in the build that is clear
air. With the crowns being redone, fix it against the **new** crowns:

- The fruit's top third must be **inside** the foliage: from below and from the side you see it emerge from leaves.
  Start from `down` **0.62**, `out` **0.30**, `hang` **0.50** `[check]` on the re-exported crowns; tune `down` until
  the top third is hidden on the three most-seen lime trees.
- Add a short stem to the texture: a 2 px **#5A4A2A** line from the fruit's top to the image's top edge (the image
  grows from 1.1 x 1.28 to 1.1 x 1.5, the fruit itself the same size), so even where the foliage is thin it visibly
  hangs from something.
- Take the fruit's own brightness down so it sits with the ambient: `ImageColor3` **#E6E6DC** (a 10% drop) and no
  highlight brighter than the pets' `[check]` against the Bear in one frame.
- If the new crowns are see-through cards with no solid lower mass and nothing looks right: hang **2** a crown from
  the lowest solid branch points instead (ask the island session for them).

### B5b / D2: the snack moment

Today a pet within **3** studs of a resting Dewdrop bats it once. Spencer's pet "did nothing": the pet has to happen
to be standing on it. Change the moment, for the **owner's own pet on the owner's client** (as the bat is today):

| Step | What | Numbers |
|---|---|---|
| Notice | A Dewdrop comes to rest within **12 studs** of the pet (was: 3, and only a bat), the pet is free (roaming, not in a need, greeting, park, race or menu). | Checked at `poll` 2 s, as today. One snack per pet every **90 s** at most. |
| Go | The pet turns to it (0.3 s), pauses (ears up, 0.4 s), then trots over. | Arrives within 0.9 studs. `[check]` **the pet's roam target must be settable from the client view for this** (the bat is in place). If the roam is server-planned and cannot take a short client detour, fallback: reach **6** studs and the fruit rolls **to the pet** on its last roll (bias the roll direction toward the pet by up to 40 degrees), then the eat plays in place. |
| Eat | Three nibbles. | Each nibble 0.35 s: the pet dips its head, the fruit loses a third (scale 1, 0.72, 0.45, then 0 with the last), squashing 0.9 x 1.1 on each bite. One soft bite sound per nibble (my sound note will name it). |
| Glad | A small happy hop and the pet's content face. | Hop 0.35 studs, 0.3 s; face held 1.5 s. **One** small heart mote rising 1 stud over 0.8 s, pet-palette pink, the only bright thing in the beat because it belongs to the pet. No UI, no number. |
| After | The slot regrows as today. | `regrow` 45 s, unchanged. |

- A resting fruit waits longer so there is time: `rest` 18 to **30 s**.
- Fruit nobody eats fades as today.
- The player can play too, lightly: walking into a resting Dewdrop (root within **1.6** studs) nudges it **2 studs**
  away along the player's heading, one small bounce (0.25 high, 0.25 s). So you can roll one toward your pet. Client
  view only.
- Other players' pets: unchanged in v1 (they keep today's bat on each viewer's client). `[check]` if showing other
  pets eating is wanted later, it needs the shared Grove to mark a fruit eaten.
- **Not in v1, and Spencer's call:** a real reward. If wanted later, the smallest honest one is +1 Heart for the
  first snack of the day, server-checked. I recommend shipping the moment without it first: the reason to like it is
  watching the pet.
- More of them fall, so the moment is seen: `chance` 0.35 to **0.5**, and the big breath (section 1) always counts as
  a strong gust. Loose cap stays 3 / 2.
- Reduced Motion: fruit hangs, nothing falls (unchanged), so no snack.

---

## 8. Captures wanted for my review

Phone-sized, day hold unless said.

- **W3:** a 20 s clip through one big breath from the plaza (chimes, leaves, Dewdrops, birds); the dapple under two
  trees, still and a 6 s clip; the pool with koi from the bank and from 20 studs, plus one ripple; the far flock
  crossing; dusk through the lamps coming on (clip), and one shooting star; the lawn with litter, patches and path
  fray from player height.
- **W4:** shot 1's view before and after each of: camera pitch, haze, far islets, sightline breaks. The view over the
  east rail (shot 3's) with the islets.
- **D1:** the egg corner from the plaza's middle, from the arrival path's mouth, and close; standing between the
  station and the nest with each prompt showing; the Hatch eggs screen's napping-egg row in both states.
- **Q2 / Q1:** the nest at 20, 12, 10 and 4 studs (pill absent, fading, full); each of rows 1, 4, 5, 6, 7; the first
  tuck-in with the Bear beside the nest and a need pending (one thing on screen); the trail pin from 60 and from 20
  studs.
- **F2:** the rope ring rising (clip), from the start arch and from above; pushing on the rope; the rail status, the
  confirm, the toast, on a 320 px wide phone.
- **Q5:** 10 s clips in calm and through a gust from player height, with the Bear in frame; a still against the sky,
  one across the plaza marble; the four leaf shapes close; live counts at levels 0 and 1.
- **D2:** three lime trees with fruit hanging, from below and side-on; one clip of fall, rest, the pet's notice, trot,
  three nibbles and the hop; the player nudging one.
