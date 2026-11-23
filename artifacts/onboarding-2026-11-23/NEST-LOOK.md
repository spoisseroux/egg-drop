# Sleepy Nest and "See you tomorrow": the look (Fable, 2026-11-23)

For Onboarding v3 slices D and E. Textures are script-drawn (`python scripts/draw_onboarding_textures.py [--preview DIR]`, deterministic, numpy + Pillow) and were checked as mocks at 7 to 44 px a stud on grass and 16 to 64 px on HUD ink and cream. **Nothing here has been seen in Studio**: every `[check]` is a one-look test, and I review captures before publish.

Common (as LOOK-R2): `Anchored`, no collide/query/touch/shadow, SmoothPlastic, owner's client only, one local folder. Degrees. A "decal plate" is a Block with `Transparency 1` carrying Decals on **Front and Back** only.

## 1. Where: (86, ground, 66)

- Root = `Vector3.new(86, groundY, 66)`; the walk map says y 4.33 (raycast it). Root frame `CFrame.lookAt(root, Vector3.new(96, y, 66))`: **-Z points at the arrival dais**, +X is south.
- 10 studs from spawn (96, 66), 26 degrees left of the spawn's facing, so it is in the first frame. Level grass (0.2 over 4 studs). Clear by: path and dais 3.6 (nest radius 1.8), nearest find spot (85, 73) 7.1, flower patch (84.1, 68.4) 3.1, lamp 21, Dash course 97, stations 60+, IslandBounds walls 40+.
- **The Bear curls up at root-local (1.9, 0, -1.3)** = world (87.3, 67.9), facing the egg. Tuck in prompt and prints end at root-local (0, 0, -2.6).
- [check] in the arrival capture: nest fully in frame on a phone. If the path's edge crowds it, the fallback is (85, 65).

## 2. The nest: 10 parts

Offsets are root-local, y from the ground.

| # | Part | Shape | Size | Offset / turn | Colour, decals |
|---|---|---|---|---|---|
| 1 | Base | Cylinder, axis up | 0.35 thick, 3.0 across | 0, 0.175, 0 | #6E4524 |
| 2-7 | Rim rolls x6 | Cylinder, axis along the ring | 1.62 long, 0.72 across | angle a = 30 + 60k: (sin a x 1.45, 0.46, cos a x 1.45), axis tangent; ends tipped +8 / -8 alternately | #B07A45 and #8A5A30 alternating. `Texture` `nest-weave.png` on the four curved faces, StudsPerTileU 0.8, V 0.4 |
| 8 | Cushion | Cylinder, axis up | 0.34 thick, 2.3 across | 0, 0.50, 0 (top at 0.67, rim top 0.82) | #FFF4DA |
| 9 | Moon flag | decal plate | 0.96, 1.6, 0.04 | 1.1, 1.55, 0.95 (back, south side) | `nest-flag.png` both faces |
| 10 | Leaves | decal plate | 1.0, 0.6, 0.04 | -1.15, 1.08, -0.9, yaw 25 toward the egg, tipped back 15 | `nest-leaves.png` both faces |

- [check] the weave on a Cylinder's curved faces: if it smears or shows a seam, delete the Texture; two browns alone still read as a woven ring.
- The flag's stick is at the image's left on both faces, so it shifts 0.6 studs between front and back views. Fine: it stays over the rim.

## 3. The Sleepy egg

The existing egg mesh (`EggModels.Egg` TopShell + BottomShell), a `SurfaceAppearance` with ColorMap `sleepy-egg-color.png` and the existing `egg-roughness.png`. Same UV layout as the six eggs. Pale lilac #C9B4FF, a cream belly band with the face on it (two closed eyes, a small mouth, blush), a crescent moon and stars on the top shell. **The face is at the mesh's +Z front: turn the egg 180 so it faces root -Z.** The egg's base sits at (0, 0.61, 0), 0.06 into the cushion. The eyes stay closed at every stage; the body tells the stage.

| `Nest.look` | Scale (1 = 1.0 x 1.3 studs) | Motion | Glow | Zzz |
|---|---|---|---|---|
| small | 1.25 | still | none | one `sleepy-z` every 4 s |
| glow | 1.6 | slow breath: scale 1.00 to 1.03, 3.2 s | halo 0.25 to 0.50 alpha, 3.2 s; PointLight range 6, brightness 0.4 | every 3 s |
| rocking | 2.0 | rock 7 degrees each way about the base, two rocks at 0.9 Hz then 1.2 s still | halo 0.45 to 0.70 | every 3 s |
| ready | 2.0 | hop 0.35 every 1.6 s (land squash Y 0.92 for 0.08 s), rock 10 | halo 0.85 steady, tint #FFE08A; sparks as the find burst (`sparkles_main`, Rate 6) | none |

- Halo: `sleepy-halo.png` in a BillboardGui at the egg's middle, 2.6 x the egg's width, `ImageColor3` #FFF3C4 (ready #FFE08A), not AlwaysOnTop, LightInfluence 0.
- Zzz: one ParticleEmitter at the egg's top, `sleepy-z.png`, Size 0.35 to 0.6, Lifetime 2.2, Speed 0.6 up, drift toward +X, Rotation -12 to 12, fade in 0.2 / out 0.6, `Emit(1)` by the table's clock. Never more than 2 alive.
- Stage change while watching: scale tween 0.6 s, Back Out. On join: set, no tween.
- Ready ping: `machine_attract` once, inside `Nest.ReadyPing` (14 studs), per egg.
- **Label** (BillboardGui over the egg top + 0.9, the "Garden find" cream pill, MaxDistance 60): gift icon (`ItemIcons`, or the Star) + `nest.hours` / `nest.minutes` / `nest.ready` (gold pill, ink text). Within 14 studs a second line: `nest.inside` or `nest.insideStars`, and `nest.count` while egg <= 7. Text 14 px, 13 on a phone, never smaller.

## 4. Tuck in (2.6 s, nothing locks, camera untouched)

| t | What |
|---|---|
| 0.0 | Egg sinks 0.12 into the cushion and back (0.25 s). `pet_coo_1` at speed 0.85. Halo to 0.9, back over 0.6 s. `Emit(3)` Zzz. |
| 0.2 | Gift peek over the egg: a cream `Kit.tile` 96 px with the item on the existing ghost preview (Stars eggs: the big Star), and a gold "+{stars}" chip. In 0.2 s, hold 2.0 s, out 0.3 s. |
| 0.4 | The Bear plays its `yawn` beat (2.4 s), walks to its curl spot and takes the sit pose. |
| 2.6 | Label reads `nest.tucked` for 4 s, then the clock again. |

Tucked, for as long as that egg lasts: the egg leans 6 degrees toward the Bear's spot and the Zzz come twice as often. Send `tuck`; play the beats at once and undo nothing on `refused` (`Tucked` is not an error). No new sound: the tuck-in chime waits for Spencer's pick.

## 5. Hatch

**Press Hatch, send `claim`, and show no reward until `claimed` arrives.** While waiting the egg does the fast rock below on a loop; on `refused` it settles back to the ready hop and says nothing (`Busy`: the prompt returns in 2 s).

| t after `claimed` | What |
|---|---|
| 0.0 | Three fast rocks, 14 degrees, 6 Hz. `hatch_rise`. Halo swells to 1.3 x. |
| 0.5 | TopShell pops up 1.2 studs, tumbles back and fades by 0.9. The Core mesh, Neon #FFF3C4, scales 1 to 2.4 and fades in 0.35 s. `Emit(18)` sparks. `hatch`. |
| 0.6 | **The reward.** Item gifts (hat, neck piece, toy, Nest Charm): the existing item receipt stage (`HatchItemStage` + `ItemReceiptLayout`), title `nest.title`, the Stars as its gold chip; the item is worn when the stage closes. Stars-only eggs stay in the garden: "+{stars}" floats up from the nest in the find's "+N Smarts" billboard, gold with the wallet Star, `snack_boost_sparkle`, and the wallet counts up. |
| 1.6 | BottomShell fades (0.4 s). |
| next `state` | The new egg drops 1.5 studs onto the cushion with one bounce (0.35 s), `land`, at the small look. Label `nest.next` for 3 s. |

Egg 7: after the receipt, the welcome-week card (slice G). All sound is existing: `hatch_rise`, `hatch`, `land`, `machine_attract`, `pet_coo_1`, `snack_boost_sparkle`.

## 6. The HUD chip

The `StampChip` pill (well fill, `Kit.stroke`): pill 30 px tall, 26 compact; hit rect 36 / 44. Left to right: `nest-chip.png` 22 px (18 compact), the gift icon 16 px, the time in Strong 14 (13 compact).

- **Needs two short strings, not in `onb3` yet:** `nest.chipHours` = "{hours} h", `nest.chipMinutes` = "{minutes} min" (through `Nest.countdown`; in the localization export). "Ready in 7 h." is too wide for a chip.
- Ready: pill fill `Kit.Color.stars`, ink text `nest.ready`, gold rim; one 120 ms overshoot when it turns; the nest icon bobs 2 px at 1.2 Hz.
- Widths: about 92 px ("7 h"), 118 ("40 min"), 104 ("Ready!"). Phone: drop the gift icon (about 70 px). It hides before the title is squeezed, like the stamp chip.
- `AccessibleLabel` = `nest.title`. A tap lays the Show me trail to the nest.

## 7. The "See you tomorrow" strip

One well-filled row, radius 12, not focusable, never a button. It comes in after the screen's own count-up ends.

| | Desktop | Phone |
|---|---|---|
| Height | 44 | 36 |
| Title `strip.title` | Label 12, soft, at the left, 132 px | Label 11 on a small tab centred on the strip's top edge, overlapping 7 px |
| Chips | three, flowing right, gap 8 | three equal columns, gap 6 |
| Chip | icon 20 + text Strong 14 | icon 16 + text Strong 12 |
| Under it | `strip.wait`, Label 11, soft, centred | left out below 400 px of screen height |

1. **Nest:** `nest-chip.png` + gift icon + `nest.hours` / `nest.minutes`; ready: gold chip, `nest.ready`.
2. **Stamp:** the stamp card's own stamp art + `strip.stamp`, the Stars number in gold. Card complete or today's stamp taken: tomorrow's.
3. **Quests:** atlas `quests` icon + `strip.quests`.

- Text never truncates: shrink to 11, then switch that chip to its short value (the two chip strings above; "{stars}" with the Star; "3").
- **Deck results** (`DeckResults`, phone and desktop): under the last content row, above the buttons, full content width. **In place** (`DeckResultsInPlace`): docked under the panel; under the near-miss item when there is one, and with no room the `strip.wait` line goes first, then the title. Nothing ever overlaps the near-miss item.
- **Dash results** (`DashCard`): between line 3 and the buttons; `g.h` grows by 44 + 8 (36 + 6 compact). A card narrower than 420 px uses short values at once.
- In: 12 px up and a fade, 0.25 s; chips pop 60 ms apart. No loop, no pulse, no sound.

## 8. Reduced Motion

No rock, hop, breath, bob or overshoot. Halo steady at 0.3 / 0.5 / 0.8 by stage; ready is the steady gold halo and one still spark, as the still find. One still Z over the egg (none when ready). Stage scale snaps. Tuck in: the gift tile fades only, the Bear walks and sits as usual. Hatch: shells fade in 0.3 s, no pop or tumble, the Core flash at half brightness with no scale. Strip and chip: fades only.

## 9. Uploads (all in `assets/onboarding/`)

`sleepy-egg-color.png` 1024; `nest-weave.png` 128x64; `nest-flag.png` 96x160; `nest-leaves.png` 160x96; `sleepy-halo.png` 256; `sleepy-z.png` 64; `nest-chip.png` 128.

**Captures wanted:** the arrival frame on desktop and a phone (nest in view?); the egg at all four looks, close and from the dais; the Bear curled beside it; the gift tile; one item hatch and one Stars hatch; the chip in both states at phone size; the strip on first, second and day-2 deck results, in place, and on the Dash card.

## Uploaded (Opus, 2026-11-23)

- nest-chip.png -> rbxassetid://114080030018596
- nest-flag.png -> rbxassetid://96303130180036
- nest-leaves.png -> rbxassetid://130921787854357
- nest-weave.png -> rbxassetid://118690234276511
- sleepy-egg-color.png -> rbxassetid://116613877519776
- sleepy-halo.png -> rbxassetid://93444884817210
- sleepy-z.png -> rbxassetid://127381504371398
