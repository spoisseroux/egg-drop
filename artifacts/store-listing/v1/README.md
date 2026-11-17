# Pocket Pals: Pet Garden, v1 store icon and thumbnails

Captured 17 November 2026 in Studio Play (solo, place 96451847774961), using the game's own UI and the Studio-only `EggDropStoreTestGrant` for Stars. Nothing is uploaded; Spencer picks first. Studio saves are memory-only (`ProgressStore` has no DataStore in Studio), so the launch save namespace was not touched.

Studio's `screen_capture` returns frames 1649×734 or 1920×777. Each file is a crop of one capture, scaled up with Lanczos and a light unsharp mask. The only additions are the caption pills (Fredoka One, the game's panel and mint colours) and the variant B wordmark (Builder Extended Bold, cream with an ink outline). No AI imagery. The Material Egg, old names, Blip and charms do not appear.

## Icon (`icon/`, 1024 and 512 square)

The Bear holds its **Ball** toy (Spencer's pick). The Pocket Deck was tried first and dropped: in the v1 two-paw hold, its screen faces the Bear, so from the front it shows only the cream back of the shell. Captured in pet focus with UI, avatar and nameplates hidden. Scripted camera at FOV 30, about 4.4 studs away, lens at chest height pitched up 5°, Bear turned 27° off camera.

| File | Shows |
|---|---|
| `icon-A-notext-*` | **A (lead).** Unhued white Bear with the yellow ball against the warm peach dusk sky and lawn. No text. |
| `icon-B-title-*` | **B.** The A frame with "POCKET PALS" along the bottom 20%. It covers the feet, not the ball. |
| `icon-C-rose-*` | **C.** Same pose with one Rose jar (Main, step 1 of 5), shot against the garden's tree and fence. Step 1 is a pale tint, so the pink is subtle at 150 px. |

Phone check at 150 px: the ball and face read in A and B. C reads, but its background is busier and the pink is faint.

## Thumbnails (`thumbnails/`, 1920×1080)

Per Spencer, slots 01, 02, 03 and 04 were cut. 01 would show "Win pays" boosted by the creator's passes, and 03 and 04 need a two-player Local Server. The numbers below follow the shot list.

| File | Shows |
|---|---|
| `05-odds-before-hatch.png` | Hatch eggs with only the Toy Egg (20) and Customization Egg (12), the Customization Egg selected. Its odds table is as built (hues 17%, Gloss and Matte 10%, Jelly 6%, Charms 6%, "Charm within 15 eggs"). Fresh save, 300 test Stars. |
| `06-hatch-toys.png` | A live Toy Egg reveal: Wobble Top on the warm cream card, with **Store** and **Give to Bear**. 37 px of the reveal's own dark edge rows were added top and bottom to fit 16:9. |
| `07-colours-materials.png` | Customize › Hue › Main: the Citrus jar selected (3 of 5, "Use 1 jar"), the jar cards, and the Bear preview in Citrus with Gloss applied. |
| `08-dress-up.png` | Wardrobe › Hat: Tiny Sun Hat previewed on the Citrus Bear, "Buy 100", with 40, 100 and 250 prices in the grid. Scrolled so the discounted weekly Pom Beanie is out of frame. |
| `09-style-deck.png` | Deck style › Balls: Deep Sea (RARE) previewed, "Buy 100". |
| `10-collection-book.png` | Book › Wardrobe page at 2/23 with its four milestone pills (25/50/75/100%). |

## Critique and known issues

- **06** is the strongest. **05**, **07** and **09** read well at phone size.
- **08:** the Tiny Sun Hat is small on the preview Bear.
- **09:** the bottom row of ball tiles is clipped by the panel edge at this viewport height.
- **10 is weak.** The page is mostly empty silhouettes. The Toys page (8/9) would be stronger, but it shows the Pocket Deck as a "P" placeholder because `BookView.Art.slots` has no `toy:pocket_deck` entry, and it shows the Jelly jar.
- **Stars balances** in the headers (300, 232, 52) come from test grants.
- **07–10 show desktop keyboard hints** (WASD, ENTER, BKSP) because the touch-device emulator was not used. 07–10 come from the first session (smaller viewport, about 1.47× upscale). 05, 06 and the icons come from the larger second session (about 1.39×).
