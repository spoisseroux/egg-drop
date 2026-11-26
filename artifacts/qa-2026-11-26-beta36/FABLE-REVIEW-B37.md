# Fable review: beta 37 Studio captures (2026-11-26)

Reviewed from the jpgs in `studio-b37/` against `onboarding-now/`. I did not open the code, so property names are suggestions; the numbers are the direction.

| # | Capture | Verdict |
|---|---|---|
| 1 | Deck, Aero balls, egg | **Ship** |
| 1b | Grey egg flash | **Fix** |
| 2 | Stork in open sky | **Ship** |
| 3 | Egg on blanket | **Fix** (blanket only) |
| 4-5 | 3D cracks | **Fix** (the main one) |
| 6 | Pop | **Fix** (chips only) |
| 7 | Bear card, Sky | **Fix** (backdrop, Bear light) |

**1. Ship.** Aqua, sun-gold, leaf and lotus read calmer and clearly apart; glow disc and UI cracks are gone. Nit: lotus still shows a dark ring; the brief said no outline.

**1b. Grey flash** (OnboardV2). Set the deck egg's base `Color` to `#FBF6D2` so an untextured frame is cream. `ContentProvider:PreloadAsync` the texture before the panel shows; keep the egg at Transparency 1 until it returns (0.6 s cap), then fade in 150 ms.

**2. Ship.** Clear of the arch, readable on sky. Optional: stork 1.25x.

**3. Blanket** (FirstHatchStory). No seam, no zigzag: good. The blanket hangs over the dais edge and its grey tufts read as pebbles.
- Diameter to 78% of now, thickness to 50%, moved 0.6 studs toward the dais centre; no part past the chamfer.
- Remove the tufts, or recolour them `#DCEBFA`.

**4-5. Cracks** (EggCrackPaths, FirstHatchStory). Not convincing yet: uniform pure-black sticks, an even sawtooth, and in 5 two straight ticks stand off the shell.
- **Colour**: core `#4A3524`, never black.
- **Width**: 0.035 studs at the tap point tapering to 0.008 at tips; branches start at 60% of the parent's width.
- **Lighter edge**: a twin strip 0.012 studs below-right, `#FFFDF0`, transparency 0.45, 0.6x core width. This gives the depth.
- **Path**: segment length 0.06 to 0.15 studs (max 0.15 so chords hug the curve), turn jitter ±35 degrees, no regular zigzag. Each vertex on the shell surface, oriented to its normal, offset 0.004 out.
- **Ticks**: delete the perpendicular spurs; branches leave at 35 to 60 degrees, 40% of parent length.
- **Junction chips**: at each fork a dark triangle (0.05 studs, `#3A2A1C`) and one cream shard lifted 0.01 and tilted 8 degrees.
- **Growth**: from the tap point outward over 90 ms. Tap 2 adds the cream leak (`#FFF3C4`, 25% alpha). Only tap 3 completes the ring.

**6. Pop.** Bear facing camera: ship. Chips are flat rectangles, one bigger than the Bear's foot, with saturated blue slabs.
- Wedge shards, not blocks: 0.12 to 0.35 studs, 0.03 thick, random yaw.
- Outer `#FBF8DC`, inner `#FFFFFF`; spot blue `#2F6BFF` on 1 in 4 at most.
- Shrink to 0 over 300 ms from 1.2 s after landing; none resting between camera and Bear.
- Keep the bottom half-shell under the Bear for 600 ms.

**7. Card** (HatchAero/RevealStage). Sky look reads sunny, not sad-teal; plates and grass arc: ship.
- Backdrop outside the card is still the navy checker: replace with a vertical gradient `#58B8F2` to `#0E5FB8`, no checker, 6 bubbles at 12% alpha.
- Inside, the old polka-dot grid remains: drop to 6% alpha or remove; the bubbles are the pattern.
- The Bear renders warm grey here but white in capture 6: key light `#FFFFFF`, cool fill `#CFEFFF` at 0.5, until the belly reads `#F4F8FF`.
- Rays to 14% alpha; they barely show.

**Not judged from stills:** the "cathartic asmr-y" sound, haptics and timing. That needs a video with audio.

**Order:** cracks, chips, card backdrop, blanket, grey flash.
