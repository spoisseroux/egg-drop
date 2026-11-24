# Beta 16 candidate: Studio check R10 (Opus, 2026-11-24)

`feat/egg-drop-arcade-polish` from **7777fd3**, Rojo on 34872, Studio 53800d7d (place file; Studio counts as beta).
Before Play, Edit held the repo's LF byte lengths: NestLandmark 7,844, NestLandmarkData 1,964, EggCorner 9,355, Onboard
5,844, server init 150,820, EggCornerWorld 21,173, client init 318,168, NestClient 75,848, StationAttract 25,851,
EggMachineClient 22,772, ThingsTrail 14,737. `ServerStorage.NestLandmark` is the real template (Body, Awning, Moon,
three blankets as MeshParts with ids, Collider, `LandmarkVersion` 1). Two Plays (fresh save each: Bear by the welcome
remotes, ack). Nothing saved or published. Captures in `studio/r10/`.

## Fix committed (offline runner 66/66)

| Commit | What |
|---|---|
| **467f8a0** | `EggCornerWorld.landmarkTemplate`: the clone's `WorldPivot` is set to the origin. Rojo drops the rbxmx `PrimaryPart` ref (it was nil in Studio), so the pivot was the bounding box (Body centre, turned 180). Play 1 had the Body centre on the root: **bowl bottom 0.77, 3.3 under the marble**, the moon at root-local x **-2.84** (should be +2.08), the Collider centre at y **2.15**. Same bug class as 97f196b. After: every part at its NestLandmarkData position to 0.01. |

## Results (Play 2, after the fix)

| # | Check | Result |
|---|---|---|
| 1 | Ring arc on marble | **Marginal FAIL.** 25 segments, ArcAngle -96..+96, r 3.0 at (-41, 4.21, 2), max reach 3.08. 675 samples (9 along x 3 across each segment): **673 on marble/trim, 2 on `W7C_Ground_16`**, both on Arc25. Fine sweep: r 2.925 and r 3.0 clear over the full +-100; r 3.075 (the outer edge) is off from **+98.5 to +100** (world 117-118 deg). In 09 / 11 the west tip just meets the grass line. Smallest fix: `Corner.RingArc` 196 (spec pins 200). |
| 2 | Real model, height | **PASS.** Model, `LandmarkGreybox` false, Persistent, one copy in `EggDropLounge`. Root (-31, **4.07**, -11) facing (0.14, 0, 0.99). **Note:** the marble there is **4.127**, so the feet sit 0.057 low: `nestFloor` fell back to `NestSpot.Y` at boot (today the same ray finds the marble; likely the EggsSign part was still queryable at build). Fix: an Include filter on `room.World`. |
| 2 | Old station gone | **PASS.** All six `W7_EggsStation__*` T 1, no collide, no query; client nest folder has no twig parts (23: sign, moon lamp, shadow, 15 scatter, egg, prompt). |
| 2 | Tree clearance | **PASS.** Trunk surface 5.86 from the root at the ground (rule 3.5). Lowest foliage over the bowl (r 3) **12.47** above the root, r 5 **12.07** (rule above 8; convex-hull clones, so conservative). Crook apex to nearest branch 5.30, to foliage 6.02 (rule 1.0). **But** from the path mouth (01, 03) the trunk stands straight behind the crook and the crook reads against it: Fable's mirror rule is her call. |
| 2 | Star inlay | **PASS (0.07 proud).** No `Plaza_InlayStar` part: the star is `W7_Architecture__palette` at **4.200** on marble **4.130** in every one of 65 samples. The prompt's foot point is on marble, not a star tip. |
| 3 | States | Driven by: a real **Tuck in** (prompt fired), and server `NestEvent:FireClient` with a forged `state` packet for **ready** (`ready=true, tucked=true`) and **empty** (`public=nil`); the nest code has no owner command for states. Untucked: folded quilt T 0, others T 1 (04a, 05). Tucked: folded hides, draped **unrolls Y 0.38 to 0.904 in about 0.5 s, lower edge held at 2.19 to 2.21**, ripples to 0.922 (1.02); prompt Tuck in -> Peek (06b, 04b). Ready: slipped T 0, prompt **Hatch**, moon `#FFE08A` range 10, brightness **0.64 to 0.80** (80-100%), halo 2.0, awning **4 to 8 deg** off rest (6 +- 2) (06c, 07). Empty: dent and folded quilt on rim (06a). |
| 3 | Motion | **PASS.** 10 s at 15 Hz: egg height +2.50%, peaks 2.47 / 6.93 s (**4.46 s**), rise 0.057; moon 0 to **3.00 deg**, awning 0 to **2.00 deg**. |
| 3 | **Egg size** | **FAIL vs spec.** Ready egg shells span local **2.25 to 5.61** (3.4 tall, about 2.5 wide); spec 1.6 x 2.1, top 4.25. The 1.3 was applied to `Client.Scale` ready = 2 (the mesh at scale 1 is not 1.25 x 1.63). The ready egg's top passes the pill (5.2) and covers it (06c). Napping top about 4.35. Smallest fix: `Land.EggScale` 0.8 gives 1.6 x 2.1; Fable to choose (that is smaller than today's twig-nest egg). |
| 3 | Empty is static | **Finding.** With no egg the client nest closes: the moon has **no light at night** (06a), nothing sways, and the code `NestSign` goes, so the two rope loops hang empty. LOOK 4 says the moon follows the dusk rule and sways in Empty. |
| 4 | Moon at dusk | **PASS.** `/hour on`, `/hour at 2900`: at 2900 daylight is .33, so it stays off until it crosses .30 (rule `NightBelow`). Then brightness 0.27 to 0.60 at **0.21/s (about 2.9 s)**, `#FFE9A6`, range 9, halo 1.6, Moon tint and SA `#FFE9A6`, emissive 0.6. Day (`/hour off`, 10.5): light off, halo off. Lights within 7 studs: MoonLight on, **EggNestLight off**, egg Glow off: one. |
| 5 | Collider | **PASS.** Dropped from y 12: stands on `Collider` at **6.82** (local 2.75). Walking a 13-point circle at r 3.6: 13/13 reached, closest root 3.26 from the centre, no snag. Pet box `SleepyNest` **5.6 x 1 x 5.6**. Pet sampler (1,504 samples): closest pet body **3.54** from the root, 0 inside 2.8. **Look:** standing in the nest the egg comes through the avatar's legs (10); LOOK's option is a 4.4 collision box. |
| 5 | Bear on the mat | **FAIL.** The Bear never goes to the mat: `BearSpot` (-2.9, 0, -2.0) only drives the egg's lean and the scatter gap; no pet code uses it. It rested at local (-6.0, 0.5, -2.9) and at the prompt point (closest 3.54), never curled. Needs a pet rest target (Sol). |
| 6 | Prompt, "?", pin | **PASS.** Prompt anchor local (0, 1.0, -3.5), reach 4.5, UIOffset (0, 72). Pill billboard on the egg anchor + 3.05 = **5.2**; "?" `HelpDisc` 44 px hit, `Mark` 24 px. Show me from the nest chip (ready): `EggDropShowMe.Marker.Pin` "Hatch!" at local **(0, 8.20, 0)**. **Finding:** the pill is depth-tested, and from play height the awning's front leaf cuts across it ("Hatc[leaf]8 h", 04a, 04b, 05); at ready the egg covers it too. |
| 7 | `/onboard landmark off` / `on` | **PASS.** Off: landmark parked, the twig nest (42 parts) at mound (-31, 4.34, -11), prompt Peek, pet box 4.2, EggNestLight on (range 8) (08). On: landmark back, draped quilt, EggNestLight off, MoonLight on. |
| 8 | Output log | **PASS.** Known lines only (ConfigService keys incl. `onboard_landmark`, BoardSnapshot dropped, EditableImage, `Player:Move`, 203785492, Assistant notices) plus one error from my own probe. Nothing from EggCornerWorld, NestClient or NestLandmark. |

Unconfirmed: the nest chip's `AccessibleLabel` still read "naps for 8 hours" while the chip showed "Hatch egg!" (with
the forged ready state).

## Captures (`studio/r10/`, Fable)

01 / 03 plaza from the path mouth, noon / dusk (machine + nest). 02 the player camera, noon. 04a / 04b nest at noon,
untucked wide / tucked with avatar. 05 untucked, dusk. 06a empty, night (moon dark). 06b tucked, dusk. 06c ready,
dusk. 07 ready with the Show me trail. 08 landmark off: twig nest. 09 ring from above, 11 ring at eye height (forced
on locally). 10 avatar standing in the bowl. Not captured: the "Hatch!" pin (AlwaysOnTop does not draw in
`screen_capture`), the hub and (2.5, 21) angles, a phone.

At the end: Studio in Edit; Rojo disconnected in the plugin and only my serve (34872) stopped; the 2 `ZZSpecs`
folders (329 instances) removed from Edit, 0 left; the foliage probe clones removed.
