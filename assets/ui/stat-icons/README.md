# Stat icons: Pocket Buddies (UI icons)

Production art for the six stat icons that replace the rune stones, with the level-up burst and the snack decals. All of it is drawn by `build_icons.py` (PIL and numpy, from coordinates). Original art; no AI art. **Nothing here has been uploaded to Roblox.**

Rebuild from the repo root: `python assets/ui/stat-icons/build_icons.py` (needs Pillow and numpy; no fonts).

Design: `V2-CUTE-ICONS-AND-NAMES-2026-11-20.md` section 1. Colours mirror `src/shared/StatCatalog.lua`; change them there first, then in `STATS` in the script.

| Stat | Buddy | Colour |
|---|---|---|
| heart | a heart | `#FF86A8` |
| power | a paw | `#FF9D4D` |
| energy | a lightning bolt | `#6CCBFF` |
| jump | an up arrow on a spring | `#B9EE5A` |
| speed | a sneaker with speed lines | `#8FA8FF` |
| smarts | a light bulb with a sparkle | `#E58CFF` |

## Files

| File | What it is |
|---|---|
| `icon-<stat>-128.png` | 128x128, transparent. Stat-colour body, ink outline (`#15143A`), darker lip, soft top light, face with two catchlights, smile and blush. |
| `icon-<stat>-64.png` | The same at 64x64, drawn at that size (not a downscale). One catchlight. |
| `icon-<stat>-small-24.png` | Chip, 24x24. Simpler shape, two bigger eyes, no smile, blush, sparkle or catchlight. Use at 24 px or below, at 1:1. |
| `icon-atlas-512x128.png` | Atlas, **same size and rects as `rune-atlas-512x128.png`**. Top row: six 64 px sprites, 8 px gutters, from (8, 8). Second row: six 24 px chips at y = 80. |
| `icon-atlas-512x128.json` | Atlas rects, same format as the rune JSON (`sprites`, `small`, `order`, `stats`). `stats.<id>.icon` replaces `stats.<id>.rune`. |
| `levelup-burst-8x128.png` | Level-up burst, 8 frames of 128 px in one 1024x128 row, one buddy of each stat. Same frames, timing and ring as the rune burst; the buddies rock gently and stay upright so the faces read. |
| `levelup-burst-<stat>-8x128.png` | The same burst with six buddies of one stat. |
| `levelup-burst-8x128.json` | Frame rects. Play once at about 16 fps; do not loop. |
| `../../art-source/snacks/export/icon-decal-<stat>-256.png` | Snack icing decals: dark cocoa (`#4A2B22`) on clear, eyes and smile cut out, corners clear. Same size and UV use as `rune-decal-<stat>-256.png`. |
| `_preview.png`, `_preview-burst.png` | Check sheets. Not for upload. |

The "2x BONUS" tags are unchanged and stay in `assets/ui/stat-runes/`.

## Swapping them in (for the implementer)

1. Upload `icon-atlas-512x128.png` and `levelup-burst-8x128.png` (and the per-stat bursts if used). Record the ids in a new `asset-ids.json` here.
2. Change `Panel.Atlas` in `src/client/StatsPanel.lua` and `Model.Atlas` in `src/client/SnackModel.lua` to the new atlas id. **No rect changes**: `Panel.Rune` and `Panel.RuneSmall` offsets are the same.
3. Change the burst image id where the rune burst is used. Frame rects are the same.
4. Snacks: upload the six `icon-decal-*` images and point the icing Decal at them. The mesh, UVs and tint are unchanged.
5. Remove the 2 px ink outline box or stone backing if any code draws one behind the sprite: the buddies carry their own outline and have no square.

## Rules

- Every sprite has 1 px of clear padding; clear pixels carry the neighbouring colour (no fringe under bilinear filtering).
- Never tint the icons. Never show a stat colour without its buddy.
- Below 30 px use the chip. Do not scale the 64 px sprite under 30 px: the smile and blush turn to noise.
- On a disabled tile the icon keeps its colour; only the text greys.
