# Stars counter: "Star Bank" capsule (Astra, 2026-11-20)

Spencer: "the star counter in the ui looks dull and outdated". Cause: gold mono digits on dark glass is the last piece of the old dark dashboard; it sits flat beside the cream round keys. Fix: make it a Toy Shell piece, a cream token with a gold coin edge and a Star medallion that pops out of its left end. Mock: `stars-counter-mock.png` (Pillow, `render_mock.py`; the 2D star stands in for the 3D one).

Replaces the body of `Kit.wallet` (src/client/DeckKit.lua). Same API (`root, amount, star, star3D, set`), same footprint height, no new uploaded images.

## Parts (back to front)

| Part | Instance | Spec |
|---|---|---|
| Root `Wallet` | Frame, transparent | `W x H`, no clipping (the medallion overhangs) |
| `Edge` (coin lip) | Frame, radius 999 | Full `W x H`, fill `#D9A31C` (`selectedLip`), UIStroke 2 px `ink`, Border mode |
| `Face` | Frame, radius 999 | `W x (H - lip)` at y 0, fill white with UIGradient rotation 90: `#FFF4DC` (cream) at 0 and .45, `#FFE7B0` at 1. UIStroke 2 px `ink` |
| Glint | `Kit.glint(face,999)` | Left inset moved to `disc - 2` so it starts right of the medallion. Heights 32 and up only |
| `Medal` | Frame, circle | Diameter `disc`, fill deck `well` (`#10133A` on Classic), UIStroke 2 px `ink`. AnchorPoint (0,.5), Position `(-4, faceHeight/2)`: it overhangs the capsule 4 px left and about 2 to 4 px top and bottom |
| `MedalDrop` | Frame, circle, under Medal | Same size, `ink`, offset y +2 (the medallion's own lip) |
| `MedalRing` | Frame in Medal, transparent | Inset 3 px, UIStroke 1.5 px `#FFC14D` (`stars`). Skip at 28 if it crowds the Star |
| Star | `Kit.icon("star")` + StarFace/eyes + `WalletStar.attach` | Unchanged build, parented to Medal, centred, y +1. Size `star` from the table |
| `Amount` | TextLabel | FontFace `Kit.DisplayFace` (FredokaOne, `Enum.Font.FredokaOne`), TextColor3 `ink` (`#15143A` Classic), no TextStroke, right-aligned, AnchorPoint (1,.5), Position `(1,-pad, 0, faceHeight/2 - 1)` |

`ink` and `well` come from the deck palette as now (`Kit.color`); cream, the gold lip and Stars gold are fixed on every deck. Ink on cream is 16:1, so the digits are far easier to read than gold on glass. Gold now appears as the Star, its ring and the coin edge only.

## Per-height table (px)

| H | lip | face | disc | star | digits | right pad | eyes | glint |
|---|---|---|---|---|---|---|---|---|
| 44 | 4 | 40 | 48 | 28 | 22 | 14 | yes | yes |
| 40 | 4 | 36 | 44 | 26 | 20 | 13 | yes | yes |
| 36 | 3 | 33 | 40 | 22 | 18 | 12 | yes | yes |
| 32 | 3 | 29 | 34 | 20 | 16 | 10 | yes | yes |
| 28 | 2 | 26 | 30 | 16 | 15 | 9 | no | no |

Width: `W = (disc - 4) + 6 + textWidth + pad`. Measure with `Enum.Font.FredokaOne` (the current code measures RobotoMono). Replace `Kit.WalletSpec` with this table, so 40 and 32 stop using the fallback proportions.

## Notes for the build

- Layout slot stays `W x H`. Leave 4 px clear left of the slot and 4 px above and below; check no ancestor header clips (`ClipsDescendants`), most of all the 28 px results chip. If one must clip, drop `disc` to `H` there.
- Not pressable: no hover lift and no press drop, so it does not pass for a key. If a screen makes it open the Stars shop, then give it the normal key states.
- FredokaOne digits are not tabular. Size the capsule once for the final value before a count-up, so it does not jitter.
- Keep `Kit.setSurface(face,"light")`, `AccessibleLabel` and the `StarFace` attribute as they are. The old "gold" LCD chip kind (`Kit.chip`) is out of scope.
- Specs to update: any test that reads the wallet's `well` fill, the `stars` text colour or the RobotoMono measure.

## Earn juice (number goes up only)

1. **Count:** digits roll from old to new over 0.35 s (0.6 s when the gain is 100 or more), at most 8 steps, Quad Out. Each step plays the existing `tick`, pitch rising from 1.0 to 1.3.
2. **Pop:** a UIScale on `Amount` goes 1 to 1.25 in 80 ms (Back Out) on the first step, then settles to 1 in 160 ms (Quad Out) after the last.
3. **Coin flash:** `Face` gradient swaps to flat lemon `#FFE14D` for 120 ms, back to cream over 200 ms.
4. **Medal hop:** Medal rises 3 px in 70 ms and lands in 110 ms with a 1 px overshoot; the 3D Star does one 360 degree turn in 0.4 s (WalletStar), or the 2D Star wobbles +-12 degrees.
5. Spending: no pop, no flash; digits roll down in 0.25 s. Reduced motion: steps 1 and 3 only.

## Acceptance

Screenshots at 844x390 and a phone results screen: wallet beside the back key in Companions, Hatch and one shop, on Classic, Honey and one green deck; the 28 chip readable; nothing clipped; an earn recorded as a short video.
