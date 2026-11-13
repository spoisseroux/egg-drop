# Egg preview effects recipe

For the Hatch eggs preview (UI-SPEC-REDESIGN-MENUS section 3) and the hatch moment. Art: `eggs.fbx`
(`Egg__TopShell`, `Egg__BottomShell`, `Egg__Core`), one ColorMap per type, colours in
`eggs-manifest.json` (`types[id].core`, `.bloom`, `.crackLight`, `.particles`). Target look:
`artifacts/eggs-2026-11-13/eggs-sheet.png`.

Rule of thumb: the egg is 3D in one `ViewportFrame`; every glow, sparkle and flash is a 2D image
over or under it. No ParticleEmitters, no lights, no per-frame allocation.

## 1. Build

```
EggWell (Frame, clips)
  Bloom        ImageLabel  soft radial dot, behind the ViewportFrame
  Shadow       ImageLabel  dark soft ellipse under the egg
  Viewport     ViewportFrame, transparent background
    WorldModel
      EggRoot (Model, pivot = egg base centre)
        BottomShell, TopShell   MeshPart + SurfaceAppearance
        Core                    MeshPart, Material Neon, no texture
    Camera
  CrackFlash   ImageLabel  soft horizontal glow band, over the ViewportFrame
  Glint        ImageLabel  soft white ellipse, over the ViewportFrame
  Sparkles     6 pooled ImageLabels (four-point star sprite)
```

- **Sizes and positions.** Use `sizeStuds` and `centerFromEggBase` from the manifest (Studio imports
  the FBX at 100x, as for the Bear: Size = MeshSize / 100). The egg is 1.0 x 1.3 studs standing on
  the origin. Spin and tilt about `egg.spinPivotFromEggBase` (0, 0.546, 0).
- **Materials.** Shells: `SurfaceAppearance` with the type's ColorMap and `egg-roughness.png`.
  Swapping the egg type is one ColorMap swap on both shells plus `Core.Color`. If SurfaceAppearance
  looks flat or costs too much inside a ViewportFrame, use the ColorMap as `MeshPart.TextureID` with
  SmoothPlastic and Reflectance 0.08: the top light and bottom shade are already painted in.
  Core: Neon, `Color = types[id].core`, CastShadow off.
- **Camera.** FOV 20, 6.4 studs in front, 1.05 studs above the egg's middle, aimed at (0, 0.70, 0).
  The egg then fills about 55% of the well's height, which leaves room for the hop and sparkles.
- **ViewportFrame light.** `Ambient` (150, 160, 165), `LightColor` white, `LightDirection`
  (0.5, -0.8, -0.6) so the upper left is lit, matching the Glint.
- **2D sprites** (three small white images, tinted with ImageColor3; reuse the existing sparkle and
  soft-dot sprites if the deck already has them): soft radial dot, four-point star, soft ellipse.

## 2. Idle loop (one Heartbeat connection for the whole well)

| Effect | Recipe |
|---|---|
| Spin | 20 degrees per second about +Y, constant. |
| "Something inside" beat | Every 2.4 to 3.6 s (random each time), 0.35 s long: tilt 6 to 9 degrees to a random side (0.10 s, Quad out), counter-tilt to -4 degrees (0.08 s), settle (0.17 s, Back out). In the same beat: squash to (1.04, 0.96, 1.04) for 0.08 s, then hop 0.06 studs up and land (0.20 s). Soft tick sound on the first tilt. One beat in four is a double: repeat at 60% size 0.12 s later. |
| Core pulse | `Core.Size` = base x (1 + 0.05 sin(2 pi t / 1.6)). The core is hidden while the egg is shut, so the visible pulse is the Bloom: transparency 0.64 +/- 0.08 on the same 1.6 s sine, colour `bloom`, diameter 2.6 x the egg's width on screen. |
| Crack-light flash | On every beat's landing, and on its own every 5 to 7 s: lift `TopShell` 0.05 studs for 0.12 s, then drop it back over 0.10 s. The Neon core shows through the zig-zag as a line of light. At the same time fade `CrackFlash` (colour `crackLight`, width 1.3 x the egg, height 0.25 x, centred on the seam at 58% of the egg's height) from transparency 1 to 0.35 and back in 0.25 s, and bump the Bloom to transparency 0.45 for that long. |
| Rim highlight | `Glint`: white, transparency 0.4, 10% x 26% of the egg's width, rotated -32 degrees, on the upper left at 26% down from the top. It does not spin. It follows the hop, and stretches 10% on the squash. |
| Sparkles | 6 pooled star sprites around the egg, within 0.6 to 1.0 egg widths of its centre, colours cycling through `particles`. Each one: scale 0 to 1 to 0 and transparency 1 to 0 to 1 over 0.7 s with a 30 degree turn, then waits 0.4 to 1.6 s and respawns somewhere else. Sizes 8 to 20 px on desktop, 6 to 12 px on the phone. Each beat fires 3 of them at once near the seam. |
| Shadow | Black ellipse, transparency 0.55, width 1.05 x the egg. During the hop it shrinks to 85% and fades to 0.7. |

## 3. Per type

| Type | Core / bloom | Sparkle colours | Extra |
|---|---|---|---|
| companion | `#FFE58A` / `#FFD86B` | white, butter, soft blue | none |
| toy | `#FFB340` / `#FF9F2E` | white, gold, coral, sky | bigger hop (0.08 studs): it rattles |
| material | `#8FF0E4` / `#6FDCD2` | white, pale mint, lilac | slower, heavier: beats every 3.2 to 4.4 s, no double beat; a white sheen band sweeps across the shell every 4 s (a 2D gradient strip moved across the well, clipped to the egg's box) |
| hue | `#FF7AB8` / `#FF5FA8` | white, pink, yellow, sky, violet | Bloom colour drifts through the five sparkle colours over 6 s |
| feature | `#9CFFDD` / `#74E8C4` | white, mint, lilac | 8 sparkles instead of 6, twinkling at 1.2 Hz |

## 4. Hatch (the button press)

Total 0.9 s before the reveal screen takes over (celebrations spec section 1.5 starts at "the egg
splits").

| Time | What happens |
|---|---|
| 0.00 s | Spin stops easing to the three-quarter angle. Three fast beats, 0.12 s apart, each bigger (tilt 8, 11, 14 degrees). Bloom ramps to transparency 0.3. |
| 0.40 s | Anticipation: squash to (1.08, 0.90, 1.08) for 0.10 s. `TopShell` lifts 0.05 studs, `CrackFlash` on full. |
| 0.50 s | Pop: `TopShell` goes up 0.55 studs and tips 16 degrees back and to the right over 0.22 s (Back out), then keeps drifting up and fades (transparency to 1 over 0.25 s). `BottomShell` stretches to (0.96, 1.06, 0.96) and settles. |
| 0.50 s | `Core` scales from 1 to 1.35 and a white full-well flash goes from transparency 0.2 to 1 in 0.3 s. Burst: 12 pooled sparkles fly outwards 0.8 to 1.4 egg widths in 0.45 s, colours from `particles`. |
| 0.70 s | The prize rises out of the cup through the core (the existing reveal), and the core fades. |

## 5. Reduced Motion

No spin, no beats, no flash, no sparkle motion. The egg sits at a three-quarter angle (yaw -28
degrees) with a steady Bloom at transparency 0.6 and two static sparkles. Hatch: cross-fade to the
open pose (top shell 0.5 studs up) over 0.2 s.

## 6. Phone budget

- 1,424 triangles and one 1024 ColorMap in view at a time; downscale the ColorMaps to 512 on upload
  if memory matters, they are painted to survive it (checked at 120 px: `eggs-120px.png`).
- One ViewportFrame, never two: build the egg once and swap ColorMap and colours on selection.
- At most 12 sparkle ImageLabels alive (6 idle, 12 only during the Hatch burst, from the same pool).
- Drive everything from one Heartbeat with plain math; tween only the Hatch. Pause the loop when the
  menu is hidden.
- When the well is 150 px or smaller (phone), halve the sparkle count and skip the sheen sweep.

## 7. Star token (results screen)

`star.fbx` / `StarToken`, 640 triangles, about 1.01 x 0.97 x 0.45 studs, with `star-color.png` (512)
and `star-roughness.png`. Facets and the bevel are painted in, so it reads under flat ViewportFrame
light. It faces the camera in the FBX; spin about +Y. Rays, mini Stars and confetti stay 2D as in the
celebrations spec section 2.4. Missed round: same mesh at Transparency 0.6 with Color `#DDE7EE`, no rays.
Target look: `artifacts/eggs-2026-11-13/star-sheet.png`.
