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
| `icon-D-notext-*`, `icon-D-title-*` | **D (13 Nov layout).** A close-up of the Bear's face and chest in three-quarter view, with the red Pom Beanie, the Bell Collar and the Ball, in front of the soft-focus pink garden. The title version puts POCKET PALS across the top (Builder Extended Bold, cream with an ink outline and a gold underline, tilted 4°). The Sparkler was tried first, but its sparks are a 0.1-stud dot and don't read in a still frame. The pink castle from the old icon is no longer near the garden in v1, so it's absent. |

Phone check at 150 px: the ball and face read in A and B. C reads, but its background is busier and the pink is faint.

## Thumbnails (`thumbnails/`, 1920×1080)

05–07 are from 17 Nov (place before v875). 01–04 and 08–10 are from the v875 launch candidate (Rojo off, nothing saved), with a fresh Studio save funded by 3 test grants.

| File | Shows |
|---|---|
| `01-merge-pocket-deck.png` | An Easy round on the v875 deck just after a merge: chain ×3, score 260, a fresh pink ball, 12/24 eggs left, Smileys balls and the Scout faceplate. **Problem:** "WIN PAYS 11–13" includes Studio's grant of Spencer's 2× and Supporter passes. A player without passes sees 5–6. Goals are 0/2. |
| `02-bear-pocket-pal.png` | The Bear holding its Ball toy in pet focus, close and low, as the hero. The avatar is cropped to its legs on the right. Garden dusk behind. |
| `03-garden.png` | A wide, high establishing shot of the garden: the path through the arch, trees, cliffs and the Pet Park on the left. The avatar is on the path with five Bears around it: the player's own and four extra pet models built with the game's own `PetFactory` and real appearances (Rose with Pom Beanie, Tide with Bell Collar, Citrus with Gloss and Sun Hat, Iris with Jelly and Flower Crown). The extras exist only on the client and nothing was saved. |
| `04-pet-park.png` | The Bear mid-slide in the Pet Park (live park activity, not staged), with the swings and seesaw behind. Same one-pet limit as 03. |
| `05-odds-before-hatch.png` | Hatch eggs with only the Toy Egg (20) and Customization Egg (12), the Customization Egg selected. Its odds table is as built (hues 17%, Gloss and Matte 10%, Jelly 6%, Charms 6%, "Charm within 15 eggs"). |
| `06-hatch-toys.png` | A live Toy Egg reveal: the Ball on the warm cream card, NEW TOY title, **Store** and **Give to Bear**. Shot at the full 1920-wide viewport so nothing is cut; 62 px of the reveal's own dark edge rows were added top and bottom to fit 16:9. |
| `07-colours-materials.png` | Customize › Hue › Main: Citrus jar selected (3 of 5), the jar cards, and the Bear preview in Citrus with Gloss applied. |
| `08-dress-up.png` | Wardrobe › Hat: Grape Pom Beanie previewed large on the Bear ("Buy 40"), with 40 and 100 prices in the grid. The Pom Beanie tile shows the weekly 32/~~40~~ price. |
| `09-style-deck.png` | Deck style › Faceplates: Night Orb (SHOWCASE) previewed, "Buy 250", with all 16 faceplate tiles drawn. Studio's warmup gives each image only 1.2 s, so the tiles were made visible after their images had loaded. |
| `10-collection-book.png` | Book › Toys & materials at 6/9: six toys drawn in 3D (the Pocket Deck included), two milestones to claim. The controller focus ring and mouse cursor were hidden. |
| `11-make-it-yours.png` | Four Bears side by side in the garden, made with `PetFactory` and the game's own appearance data: Rose (5 doses), Tide (5), Citrus with Gloss (sheen 3) and Iris with Jelly (stage 3). Client-only; nothing saved. |

## Phone-size critique

- **Strong:** 02, 04, 06 and 10.
- **Fine:** 05, 07, 08 and 09. The UI text is small at phone size, but the panels read.
- **03:** an establishing shot. The Bears are small but readable as colour dots.
- **11:** strong; four colours and both materials read at phone size.
- **Icon D:** at 150 px it reads as well as the 13 Nov icon. The Bear is a little smaller in the frame and the background is greener.
- **01:** the deck reads, but it is small in the frame. Don't upload it until it is recaptured on an account without passes (a Server & Clients test), because "Win pays" shows pass-boosted numbers.
- **All:** the Stars balances in the headers (284, 300, 232) come from test grants. The menus show desktop keyboard hints (WASD, ENTER, BKSP) because the touch emulator was not used. Captures are 1920×777 or 1649×734, cropped to 16:9 and scaled up about 1.39–1.47× with Lanczos.
