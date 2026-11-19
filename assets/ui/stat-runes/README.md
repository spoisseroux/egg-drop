# Stat rune stones (UI icons)

Production art for the six stat runes, the level-up burst and the "2x BONUS" tag. All of it is drawn by `build_runes.py` (PIL, from stave coordinates). Original art; no AI art. Nothing here has been uploaded to Roblox yet.

Rebuild from the repo root: `python assets/ui/stat-runes/build_runes.py` (needs Pillow, numpy and Nunito Black in `C:/Windows/Fonts`).

Design: `V2-FEEDING-RUNES-ONBOARDING-2026-11-19.md` section 1 and `UI-RETRO-RESTYLE-2026-11-19.md` 3.2 and 3.8. Colours mirror `src/shared/StatCatalog.lua`; change them there first, then in `STATS` in the script.

| Stat | Rune | Colour |
|---|---|---|
| heart | Wunjo | `#FF86A8` |
| power | Uruz | `#FF9D4D` |
| energy | Dagaz | `#6CCBFF` |
| jump | Ehwaz | `#B9EE5A` |
| speed | Raidho | `#8FA8FF` |
| smarts | Ansuz | `#E58CFF` |

## Files

| File | What it is |
|---|---|
| `rune-<stat>-128.png` | Stone icon, 128x128, transparent. Stat-colour face, ink rune with a chisel light, ink outline (`#15143A`), darker lip, soft top highlight and glint. |
| `rune-<stat>-64.png` | The same at 64x64, drawn at that size (not a downscale of the 128). |
| `rune-<stat>-small-24.png` | Chip variant, 24x24. Thicker carve, staves redrawn with wider counters, no glint or chisel line. Use at 24 px or below, at 1:1. |
| `rune-atlas-512x128.png` | Atlas. Top row: the six 64 px stones, 8 px gutters, starting at (8, 8). Second row: the six 24 px chips at y = 80. |
| `rune-atlas-512x128.json` | Atlas rects (`sprites` = 64 px, `small` = 24 px) as x, y, w, h for `ImageRectOffset` / `ImageRectSize`, plus order, names, colours and rune ids. |
| `levelup-burst-8x128.png` | Level-up burst, 8 frames of 128 px in one 1024x128 row, one stone of each stat. |
| `levelup-burst-<stat>-8x128.png` | The same burst with six stones of one stat, for a single-stat level-up. |
| `levelup-burst-8x128.json` | Frame rects for the burst sheets. Play once at about 16 fps; do not loop. |
| `tag-2x-bonus.png` | "2x BONUS" sticker, 256x96 (show at 128x48). Lemon face, cream edge, ink outline, lip, 4 degree tilt, sparkle. |
| `tag-2x.png` | The same sticker with "2x" only, 128x96 (show at 64x48). Use it where the word is translated in text beside it: the word in `tag-2x-bonus.png` is baked in and will not auto-translate. |
| `_preview.png`, `_preview-burst.png` | Check sheets on the Toy Shell backgrounds, with the 24 px chips at 6x in colour and grey. Not for upload. |
| `build_runes.py` | The script that writes everything above. |

## Notes for whoever wires them in

- Every icon has 1 clear pixel on all four sides, and clear pixels carry their neighbours' colour, so bilinear filtering does not pull in a dark or white fringe.
- The outline is the Toy Shell ink edge for UI. The white sticker edge for the 3D world is `stone_hi(..., edge="#FFFFFF")` in the script; it is not exported.
- Rules from the design doc still apply: a stone never appears without its colour, the stat name sits beside it wherever there is room, and 16 px is the floor (particles only).
- Reduced Motion: skip the burst.
