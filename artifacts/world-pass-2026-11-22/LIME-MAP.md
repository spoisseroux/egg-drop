# Lime leaf map (Fable, 2026-11-22) — WORLD-PASS item 1A

**File:** `assets/world/lime-leaf.png`, 512x512 RGB, opaque, tileable. Drawn by `python scripts/draw_world_textures.py`
(Pillow + numpy, seeded, no outside art; `--preview DIR` writes a 2x2 tile sheet, small sizes and a seam report).

**Kind of map: full colour, not a grey map to tint.** The lime is in the pixels: mean exactly #8FD63F, puffy clumps
shaded to #6FBF2E, lit tops and leaf flecks #B4EC58 / #C4F060, a few #E8FFB0 gloss dots. Darkest pixel luma 144, so no
olive anywhere. Reason: every earlier failure was a multiply (SurfaceAppearance.Color on pink, coral tint near black).
Multiplying can only darken, so nothing here relies on it.

**Apply** (in `AeroWorld.paintCrown`, the line that writes `TextureID=""`, per the architect check):
- `TextureID` = the uploaded asset id of `lime-leaf.png`.
- `Color` = **#FFFFFF** on the crown part while the map is on. An opaque TextureID should replace Color, but if the
  engine multiplies, white keeps the map as drawn; lime under it would give lime x lime = olive.
- `Material` = SmoothPlastic, as now. Not Fabric (its grain is what rendered olive). No SurfaceAppearance; the pink
  skins stay parked as today.
- Keep `WorldAero.Crowns.lime.Color` at #8FD63F (the `ZZSpecs/AeroWorld` spec pins it, and it is the flat fallback).
  Add fields instead, e.g. `Texture="rbxassetid://..."`, `TextureColor=#FFFFFF`. Coral stays flat.
- If the upload or the write fails, fall back to today's flat lime, all or nothing as the code already does.

**Check in Studio `[check]`**
1. Colour: crown reads lime beside a flat #8FD63F test part in the same light. Not olive, not yellow, not darker.
2. Try Color #FFFFFF against #8FD63F once; record whether Color changes anything (settles composite or multiply).
3. Tiling on the old pink-map UVs: no seams, no stretched clumps, on the trees and on the islet blossoms.
   Clumps should be about a pet's head across. If they are tiny and noisy at 40 studs, tell me and I redraw at
   half density. If UVs smear, stop and fall back to 1B (vertex colours in the export).
4. Aero day at 6, 20 and 60 studs, phone too, Bear and Bunny in frame: softer than the dark crowns, not busier.
5. Trees switch to coral and back, Aero off and on: the pink crown comes back untouched.
6. Blown lime leaves (B4) still match the crown.

**Restore value:** `TextureID=""`, `Color=#8FD63F`, `Material=SmoothPlastic` (today's flat lime). The original pink
TextureID and SurfaceAppearance are restored by the existing `surfaces` record, unchanged.

## Uploaded (Opus, 2026-11-22)

- `assets/world/lime-leaf.png` -> `rbxassetid://127425168647805`; applied in `WorldAero.Crowns.lime` (Texture, TextureColor white) via `AeroWorld:paintCrown`.
