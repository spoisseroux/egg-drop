# Pocket Pals: Pet Garden, store page v2 (icon + thumbnails)

Drafts, 19 November 2026. Nothing is uploaded; Spencer picks. Built because the Sponsored test got clicks (0.8% CTR) but only about 1 in 10 clickers pressed Play: the ad promised more than the page showed.

## What a player must get in 2 seconds

1. **A cute Bear that is yours** (big face, big eyes, an outfit).
2. **A fast merge game on a handheld** (smiling balls popping, a chain number, Stars).
3. **Eggs to hatch** (a cracking egg with light coming out).
4. **Dress up** (many Bears, many looks).

**Hook:** "Merge on your Pocket Deck, hatch eggs, dress up your Bear." The lead image says all three in one frame, exactly as the approved ad does, so the page keeps the ad's promise.

## Look

- **Subjects are cut out and big.** v1 was mostly full-screen UI captures: honest, but at phone size they read as menus. v2 puts the Bear, the egg and the deck on plain colour so each reads as a shape first.
- **One outline treatment everywhere:** white sticker edge, thin ink rim, soft drop shadow. It is what makes the pale plush Bear hold on any background.
- **One title style:** the icon D wordmark (Builder Extended Bold, cream, ink outline, gold rule, 3 to 4 degree tilt), two short lines, top left. A small POCKET PALS pill signs frames 2 to 6.
- **Colour:** most Roblox pet and merge pages are blue sky, green grass and yellow block letters. We stay in the game's own dusk palette (pink, violet, teal, gold) with ink outlines and cream type, and the handheld deck is the motif nobody else has. Each frame has one sky colour chosen to oppose its subject: warm deck on indigo, cool Bear on gold, rainbow egg on violet.
- **Light:** one burst with rays behind the focal point, in the style of the results Star's rays.
- **Truth:** every picture element is a Studio capture of this game. Captions only claim what v1 ships: there is one pet (the Bear), so the egg frame says "Hatch surprise eggs" and shows what the Toy Egg and Customization Egg hold, not "rare pals".

## Thumbnail order

The first image decides most Play presses and the second is what a swipe shows, so they carry the pitch. The rest answer "what else is there".

| # | File (`thumbnails/`) | Idea | Why here |
|---|---|---|---|
| 1 | `1-lead-merge-hatch-dress-up.png` | Prism Flare deck mid-chain, merge popping out, white and blue Bears, rainbow egg cracking, POCKET PALS + MERGE · HATCH · DRESS UP | Matches the ad, so a clicker lands on what they clicked. Whole game in one frame. |
| 2 | `3-dress-up-your-bear.png` | Six Bears, six colours, finishes and outfits | The pet is the emotional pull; customization is the strongest "I want mine" image. |
| 3 | `4-merge-big-chains.png` | Sorbet Sky deck on a ×3 chain, gems bursting out, Stars, Bear cheering | Shows the actual play. |
| 4 | `2-hatch-surprise-eggs.png` | Customization Egg cracking, toys and jars flying out, Bear amazed | The reward loop. |
| 5 | `5-play-with-friends.png` | Six Bears in the Pet Park (one real frame) | Social proof, the world is 3D. |
| 6 | `6-customize-your-deck.png` | Three faceplates, three ball themes | Depth for collectors. |

(File numbers follow the build order; the table is the recommended upload order.)

## Icons (`icon/`, 1024 and 150)

| File | What |
|---|---|
| `icon-A-bear-title` | Current identity punched up: white Bear, red Pom Beanie, Bell Collar, Ball, pink garden, tilted POCKET PALS. Bigger face, clean cut-out with the sticker rim, light burst, deeper sky. |
| `icon-B-hatch` | Blue Bear popping out of the rainbow Customization Egg, top shell flying, on gold to orange. No text. |
| `icon-C-merge-pal` | Pink Bear with Sparkle Eyes over a row of smiling merge balls and a Star, on teal. No text. |

**Recommended icon: B.** It is the only one that says "hatch" and "pet" in a single silhouette, it has the strongest warm/cool contrast, and it reads at 150 px without text (the experience name sits under the icon anyway). A is the safe choice if the page should stay recognisable to the first players.

## Self-critique (checked at 150 px and 480×270) and the improvement pass

| Image | First pass | Changed |
|---|---|---|
| Icon A | Reads. Title sat on the hat. | Bear lowered, title larger. Bear's eyes are plain: less charm than B and C. |
| Icon B | Top shell touched the ear, hat cut by the top edge. | Bear smaller and lower, shell moved to the corner. The shell piece is small at 150 px but the egg and Bear read. |
| Icon C | The ×3 tag and balls cluttered the chest; balls cut off. | Tag removed, balls smaller, Bear higher. Still the busiest icon: three ideas (Bear, balls, Star). |
| 1 lead | Reads like the ad; rainbow egg is clearer than the ad's pale egg. | Bears larger than the ad. Deck text is noise at phone size but sits in the dark screen. |
| 2 hatch | Caption one thin line; items collided with it. | Two-line caption, items re-fanned to the right. Eleven items is a lot; the egg and the pink Bear are still the two reads. |
| 3 dress up | Bears small, empty band on top. | Bears about 13% larger, two-line caption. Strongest frame after the lead. |
| 4 merge | Caption thin. | Two-line caption, deck lowered. The +20/+40/+60 rings cover part of the left gem. |
| 5 friends | Caption thin. | Two-line caption. Bears are mid-size because it is one real frame; the purple Bear is hidden behind the pink one. |
| 6 decks | Back decks crowded the caption. | Decks moved down and right. Reads as "three consoles"; screens are small. |

## Still to improve

- Capture at a wider Studio viewport: this session's window gave 1649×734 frames, so close-up Bears are scaled about 1.3 to 1.4×.
- Frame 5 with real second players (and name tags) once there are testers; the Bears here are client-side clones in the live park.
- A ×4 or ×5 chain for frame 4, and a Kittens round with a cleaner pop for frame 6.
- A/B the icon in Creator Hub (B against A) rather than guessing.

## How it was made

`python build_v2.py` rebuilds everything from `raw/` (and the ad-v1 captures): `layers/` cut-outs, `icon/`, `thumbnails/`, `contact-sheet.png`. `compose_v2.py` holds the layouts.

Captures: Studio Play, place 96451847774961, in-memory save, nothing saved or published, no source edits. Bears are client-only `PetFactory` Bears with catalogue colours (hue doses), finishes (Gloss, Jelly) and wearables, held in rig poses by forcing `PetIdleBeats` (wave, cheer, sit) with blinking off, shot over black and light Neon backdrops and difference-matted. Eggs are the `Shared.EggModels` meshes and colour maps in the hatch pose; toys from `PetToyGeometry`, jars from `JarModel`. Decks are real Easy rounds frozen on a chain (GUI clones) over black and white: Night Orb + Kittens (×2) and Sorbet Sky + Gems (×3), bought with Studio test Stars; Prism Flare and Scout come from ad-v1. Added in PIL: text in the game's Roblox fonts, outlines, shadows, rays, glints, gradients, grade. In frame 5 the top and bottom strips are mirrored sky and grass to reach 16:9. No AI or stock imagery.
