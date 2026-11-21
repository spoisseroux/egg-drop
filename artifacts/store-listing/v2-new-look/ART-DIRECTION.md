# Pocket Pals store look: "Dewdrop" (ART DIRECTION)

Fable, 21 November 2026. **Replaces the visual direction in `../v3-launch-v2/SCOPE.md`.** That file's facts still stand and are not repeated here: the v2 pitch and honesty guards (section 1), Roblox sizes and ad rules (sections 2 to 4), the test plan and budget ranges (section 4), capture logistics (section 5). Nothing here is captured, uploaded or spent. Board: `style-board.png` (rebuild with `python build_style_board.py`).

## The look in one paragraph

**Dewdrop.** One hero, one colour field, one wet highlight. Every image is a clean studio shot of our own things (a pet, two pets, the Pocket Deck, an egg) standing on a glossy floor in front of a single saturated sky-to-light gradient, lit from the top left, with a few glass bubbles drifting through and a short reflection underneath. Type is lowercase, white and round, with no outlines. Six colour fields (Sky, Aqua, Leaf, Sun, Blossom, Grape) give each frame its own colour, so the thumbnail row reads like a colour line-up. It drops the dusk pink, sticker rims, bursts and block-cap titles of the current page entirely.

## What the references contribute (principles only)

Research note: Wikipedia and Nintendo's launch release confirmed the Micro's positioning (pocket-sized, "chic", swappable faceplates) and Wikipedia confirmed Frutiger Aero's traits and dates (about 2004 to 2013). I could not retrieve scans of the Micro print ads or the Sonic Adventure print ads (archive sites refused automated reads), so the ad-layout points for those two are from my own knowledge of that work, not from a page I read today. Reference images from Spencer would firm this up (see the last section).

| Reference | Composition | Type | Colour | Finish and light | Motion |
|---|---|---|---|---|---|
| **Game Boy Micro (2005)** | One small object, lots of empty space, centred or on a third. Same object repeated in a row with different faces: the line-up. | Small, lowercase, quiet. The object does the talking. | One flat colour field per ad; the product is the accent. | Studio product shot: hard gloss, clean rim light, short floor reflection. | None. Stillness reads as confident. |
| **Sonic Adventure era (1998 to 2002)** | One strong diagonal; hero leaning out of the frame toward the viewer; low camera. | Slanted, heavy, pushed forward. | Blue sky over green ground, white cloud, one hot accent. | Bright midday light, crisp edges. | Direction of travel, a streak or two, never a busy burst. |
| **Frutiger Aero (2004 to 2013)** | Subject floating over sky, water or grass with a clear horizon. | Humanist rounded sans, friendly, lots of air. | Fresh blues and greens with yellow; gradients from saturated to near-white. | Gloss on everything, glass panels with a white rim, bubbles, soft lens glow, bokeh. | Drift: bubbles and light rays, slow. |
| **Chao Garden mood** | Small round creatures in a calm, enclosed garden with water. Eye level with the creature. | (none: it is a mood) | Soft and toy-like, a little pastel inside the saturated field. | Gentle, shadowless, safe. | Idle life: sitting, waving, napping, a hop. |

**What we take:** the Micro's restraint and line-ups, Sonic's single diagonal and slanted type (ads only), Aero's gloss, glass, bubbles and sky-water gradients, the garden's eye-level calm. **What we do not take:** anyone's logo, characters, console shape, product photo, wordmark shape, packaging layout or UI chrome. No Nintendo, Sega, Microsoft or Apple marks or look-alikes; no rings, no checkerboard hills, no window chrome, no orb-style start button. The Pocket Deck is our own in-game handheld and is shown only as it renders in the game.

## Palette

| Name | Hex | Use |
|---|---|---|
| Sky | `#1E9BFF` | Brand colour. Icon and lead thumbnail. |
| Deep Sky | `#0A58CA` | Top of the Sky field; text drop; solid-tag text. |
| Aqua | `#27D3E6` | Water, second field. |
| Leaf | `#5AD65A` | Grass, third field. |
| Lime | `#B8F23C` | Highlight on Leaf only. |
| Sun | `#FFD23F` | Stars, fourth field. One Sun accent is allowed on any frame (the Star). |
| Blossom | `#FF7EB6` | Fifth field. |
| Grape | `#8B6CFF` | Sixth field. |
| Cloud | `#FFFFFF` | All type, glass rims, highlights. |
| Ink Navy | `#0C2A4A` | Shadows and small print. Replaces black everywhere. |

Field gradients (top to horizon): Sky `#0A6BE0 > #6FD0FF`, Aqua `#0FA9C9 > #9AF3F0`, Leaf `#2FB344 > #C6F56A`, Sun `#FFB400 > #FFEE8A`, Blossom `#FF5FA2 > #FFC2DC`, Grape `#6747E8 > #C3B2FF`. One field per image. Pets keep their true in-game colours; pick the field that contrasts with the pet (white Bear on Sky, Rose on Aqua, never Tide on Sky).

## Type

Fonts found in the repo and on this machine:

| Face | Where | Licence | Use in Dewdrop |
|---|---|---|---|
| **Fredoka One** | In-game titles (`Enum.Font.FredokaOne`); file ships with Roblox | SIL OFL 1.1 | The **pocket pals** wordmark, lowercase. Keeps a thread to the game. |
| **Nunito Black / Black Italic** | Installed (`C:\Windows\Fonts`); also in Roblox | SIL OFL 1.1 | Headlines. Upright on thumbnails; Italic on ads for the forward lean. |
| **Quicksand Bold** | Installed | SIL OFL 1.1 | Tags and second lines. |
| Builder Sans / Builder Extended | In-game UI; used in ad-v1 titles | Roblox's own typeface; I found no licence file for use outside Roblox | **Stop using it in marketing art.** Fine in real UI captures. |

No download is needed. If a rounder, more "console" headline is wanted later, **M PLUS Rounded 1c ExtraBold** (OFL, Google Fonts) is the alternative; say so and I will test it against Nunito.

Rules: lowercase; Cloud white; one soft drop shadow in the field's deep tone, no outline, no gradient fill, no yellow. At most a wordmark, one headline of up to three words, and one tag per image. Everything readable at 480 × 270: headline cap height at least 9% of frame height. Keep text out of the bottom 15% (Roblox overlays).

## Finish and light

- **Light** from top left on everything. One soft glow in that corner, at most five faint diagonal light rays. No lens-flare starbursts.
- **Floor**: horizon at about 72% of frame height, bright lip, then slightly deeper. Subjects stand on it with a small contact shadow in Ink Navy and a reflection no taller than 38% of the subject, fading out.
- **Gloss**: a curved top-half highlight on tags, chips and tiles. Never painted onto the pets or the deck; they keep the game's own shading (honesty: they must look as they do in play).
- **Glass tag**: pill, white at about 30% with a 3 px white rim. A solid white tag with Deep Sky text for the one thing that must be read. Tags are labels, never drawn to look like a button to press.
- **Bubbles**: three to five per image, three sizes, thin rim, highlight top left, none over a face or text. They are decoration, not a game feature, so they stay sparse and obviously background.
- **No** sticker rims, ink outlines, confetti, radial bursts, vignettes, textures or drop-in emoji.

## Composition rules

1. One hero per image; a second subject must be clearly smaller or behind.
2. At least 35% of the frame is empty field.
3. Hero on the floor, eye level, looking at the camera.
4. Line-ups: equal size, equal gaps, one row, colours in palette order.
5. Thumbnails are still and level. Only ads may tilt, and then one diagonal only (about 12 degrees).
6. Check every piece at 480 × 270 and the icon at 150 px before it goes to Spencer.

## Concepts

All captures are real Studio captures of the live v2 build, matted from black/white or grey pairs as before. "C-numbers" refer to the capture list in `../v3-launch-v2/SCOPE.md` section 5. The deck in the style board is the old pre-Toy-Shell cut-out and is a placeholder.

### Icons (512 × 512, checked at 150)

| | Name | In frame | Capture | Type | Background |
|---|---|---|---|---|---|
| **A** | **Two Pals in the Blue** | White Bear (Pom Beanie) and a Rose Bunny (ears up), head and shoulders, cheek to cheek, both looking at camera; the Bunny's ears nearly touch the top edge. One bubble top right. | C2 Bear close-up, C3 Bunny close-up, grey pairs, same camera height and FOV 35 | None | Sky field, floor at 80% |
| B | One Pal | A single white Bear face filling 70% of the square, slight head tilt, one Star resting on the floor beside it. | C2 | None | Sky field |
| C | Pocket Deck | The Pocket Deck as a product shot, three-quarter view, tilted 5 degrees, screen showing a live merge; the Bear's ears and eyes peeking over its top edge. | C4 deck freeze (Toy Shell look), C2 | None | Aqua field |

**Pick: A.** Two faces and the ear silhouette read at 150 px, white and pink on blue has the strongest contrast on the palette, and it matches the lead thumbnail and Ad B. B is the safe challenger. C is the most "Micro" idea but the deck screen turned to mush at 150 px last time; it works better as a thumbnail.

### Thumbnails (1920 × 1080, six frames, one field each)

| # | Field | Headline / tag | In frame | Capture |
|---|---|---|---|---|
| 1 | Sky | wordmark **pocket pals** / tag: merge · hatch · train | "The line-up": white Bear standing left, Rose Bunny beside it, the Pocket Deck to the right, tilted 5 degrees with a reflection, a merge visible on its screen. | C2, C3, C4 |
| 2 | Sun | **train your pet** / tag: six stats to level up | Bear cheering left; right, the six stat tiles lifted from the real stats panel as one even row (icons and level numbers as captured, one bar mid-fill). | C8 stats panel at total level 60 to 120, C2 cheer beat |
| 3 | Leaf | **hatch snacks** / tag: 3 stat eggs a day | Stat Egg in hatch pose centre, one Snack risen above it; a Nibble and a Feast smaller on the floor either side, the Feast with the game's own RARE! stamp. | C5, C6 |
| 4 | Blossom | **meet the bunny** / tag: 7 daily stamps or 400 stars | Three Bunnies in an even row: white, Rose, Tide; ears up, down, tipped. No hats, so the ears are the story. | C3 |
| 5 | Aqua | **merge big chains** / tag: on your pocket deck | The Pocket Deck large and centred, product-shot style, mid chain with the real chain counter visible; three merge pieces (real captures) floating out above it; Bunny small at the right edge, cheering. | C4 at ×4, C3 |
| 6 | Grape | **dress up your pals** | Six pets in one even row, colours in palette order, each in a different outfit: four Bears, two Bunnies. | C2, C3; reuse the four v2 Bear cut-outs only if the live Bear is unchanged |

Order 1 to 6. The Pop-Out stage RARE frame from the old scope becomes an optional seventh, shown as a full real screenshot inside a white-rimmed rounded window on the Grape field. Home personalization: activate 1, 2, 4 and 6.

### Sponsored ads (1920 × 1080, checked at 480 × 270)

| | Name | Copy | In frame | Tests |
|---|---|---|---|---|
| **A** | The Line-up | pocket pals / merge · hatch · train | Thumbnail 1 as is. | Control; equals the page. |
| **B** | Two Pals | pocket pals / your pocket pets | Bear and Bunny very large, cropped at the chest, right of centre; wordmark left; nothing else but two bubbles. Sky field. Captures: C2, C3 close-ups. | Faces against features. |
| **C** | Sky Hop | **your pocket pets** (italic) / tag: pocket pals | One 12 degree diagonal: Sky above, Leaf grass below. Bunny mid-hop top right, Bear running or cheering lower centre, both leaning the same way. Captures: the real hop and cheer idle beats (C2, C3). No finish line, no "race": racing is not in v2. | Energy against calm. |

The winner becomes the lead thumbnail, as before. Budget, metrics and stop rules: unchanged from the old scope, section 4.

### Video idea: "Colour Flip" (9:16, about 10 s, off-platform)

Six cuts of about 1.5 s. Each is a real gameplay clip (merge chain, egg hatch, feeding bite, stat level-up, Bunny hop, dressed pair) playing full-size inside a white-rimmed rounded window; behind the window the field snaps Sky, Aqua, Leaf, Sun, Blossom, Grape on each cut, with one lowercase word per beat (merge, hatch, feed, train, meet, dress up). Ends on Icon A with the wordmark. Game SFX and the game's own lyric-free music. The 30 s store-page video stays full-frame real gameplay per the old shot list; only its end card and captions change to this look.

## What Spencer can do to make this easier

1. **Reference folder.** Drop 5 to 15 images you like into `artifacts/store-listing/v2-new-look/refs/` (Micro ads, Sonic ads, Aero wallpapers, anything), and say what you like in each in a word or two. I use them for principles only; they are never traced or shipped.
2. **Icon pick:** A (Two Pals), B (One Pal) or C (Pocket Deck). I recommend A.
3. **Which pets and outfits to feature.** My defaults: white Bear with Pom Beanie, Rose Bunny with nothing on its head. Tell me your favourites, and whether the Bear "cute" restyle will ship soon (if yes, I wait rather than shoot twice).
4. **Lowercase "pocket pals" wordmark:** OK to change from the current block-cap title?
5. **Ad budget and length** (old scope suggested $10 a day for 7 days; your number).
6. **Is the game still limited to 16+ accounts?** It decides the audience and whether a "Qualify for Kids and Select" campaign comes first.
7. **Creator Hub read access** for Opus (first campaign's final numbers, thumbnail performance, any icon experiment tool).
8. **A widest-possible Studio window** (or a 4K monitor) for the capture session, and 20 minutes of your time to record the video takes on an account without passes.

## Next steps once approved

Opus: captures C2 to C6 and C8 in the beta place (107705084891479), nothing saved or published. Fable: `compose_dewdrop.py` beside the board script, Icon A and thumbnail 1 first for Spencer's eye, then the rest. Spencer: uploads.

Sources read 21 Nov 2026: [Game Boy Micro (Wikipedia)](https://en.wikipedia.org/wiki/Game_Boy_Micro), [Nintendo launch release via Nintendo World Report](https://www.nintendoworldreport.com/pr/10725/game-boy-micro-in-september-at-99), [Frutiger Aero (Wikipedia)](https://en.wikipedia.org/wiki/Frutiger_Aero), [Chao (Wikipedia)](https://en.wikipedia.org/wiki/Chao_(Sonic_the_Hedgehog)), [Chao Garden (Sonic Retro)](https://info.sonicretro.org/Chao_garden), [Cook and Becker on Sonic art](https://www.cookandbecker.com/en/article/262/30-years-of-sonic-the-hedgehog.html). Roblox policy sources are listed in the old scope.

## Update 2026-11-21: Aero faceplates, what to feature, shot list

Fable. This section overrides anything above that it contradicts. Nothing is uploaded, published, captured or spent.

### Spencer's answers

| Question | Answer |
|---|---|
| Icon | Make **all three** (A, B, C), then show him. No pick yet. |
| Wordmark | Lowercase **pocket pals** is approved. |
| Ad budget | **$5 a day for 7 days** ($35), not spent. Replaces the $10 a day suggestion. That is thin for three creatives, so run **A and C only**; B waits. |
| Age | The game stays **16+ limited**, so the ad audience is **17+**. No Kids and Select campaign. |
| References | He has none. `refs/REFERENCES.md` (looked at in the browser, nothing saved) is the reference set. |
| Bear | The cute restyle (`pet-bear-v2-cute.blend`) ships now. All captures use it; no old Bear cut-outs are reused. |
| Deck | The Pocket Deck in the icon, thumbnails and ads wears a Frutiger Aero faceplate that players can really buy. |

### Three Aero faceplates

Built in the existing pipeline: `scripts/deck_art/build_faceplates.py` (functions `cloud_glass`, `lagoon`, `dewy_meadow`; rows appended as orders 21 to 23), textures in `assets/deck/faceplates/` at 1024 × 499 RGBA with the rounded alpha, rows in `faceplates.json`. All drawn in code (numpy and PIL); nothing traced or generated. Sheet: `aero-faceplates.png` (rebuild with `python build_aero_sheet.py`). The sheet is plate art on the repo's shell mock-up, not a Studio render.

| id | Name | Tier | Stars | What it is | Overlay | Differs from |
|---|---|---|---|---|---|---|
| `cloud_glass` | **Cloud Glass** | common | **40** | The hero. Pale sky at the top through sky blue to a cobalt rim, six white clouds inside the shell, one glass band across the top third, a thin bright rim line. | gloss | Aqua Pop is blue at the top, white below and covered in bubbles. This runs the other way and has clouds, no bubbles. |
| `lagoon` | **Lagoon** | rare | **100** | Clear turquoise water under a pale mint sky: a lit waterline, a soft net of light on the bed, one splash arc over the right grip, a few droplets. | water | Tidepool is deep blue and all caustics. Creek is clear plastic with ribs. This is light, two fields, with a surface. |
| `dewy_meadow` | **Dewy Meadow** | rare | **100** | Two glossy emerald hills with a wet highlight on each crest, pink-lilac cloud on the horizon, white to pale cyan sky, dew drops. | gloss | Lime Gel is one lime gel slab. Canopy is a leaf print. This is a scene, green and white. |

Prices sit on the live ladder (40 / 100 / 250). Cloud Glass is common so a new player can own the deck from the ads early. All three use the silver band and dark engraving. All detail sits on the grips and the top and bottom strips, because the glass hides the middle.

**Not done, for the primary agent and Opus:**

1. Upload the three PNGs. `asset-ids.json` has a `pending` block with null ids; move each into `faceplates` once uploaded.
2. `src/shared/DeckThemes.lua` is **not** written by any script (its comment says "Generated", but no generator exists), so I did not touch it. Paste-ready rows, with Toy Shell palettes solved by the `build_revision1.py` method, are in `aero-plates-DeckThemes-rows.lua.txt`. The ids also go into `Themes.Order`. Specs that count plates need new numbers (`FaceplatePurchase.spec.lua` expects 18 in `Order`; `DeckStyle.spec.lua` expects 20 shop tiles).
3. The Toy Shell hues are my proposal and have not been seen in the menus: Cloud Glass 211 (between Aqua Pop 205 and Tidepool 216, so check the three side by side), Lagoon 180, Dewy Meadow 146 with a lilac tag.
4. Three new names need the translation sync before publish.
5. **Honesty gate:** no ad or thumbnail showing an Aero plate goes live before that plate can be bought in the live place.

One change to flag: `build_faceplates.py` still held the old 20 / 40 / 80 prices, and running it would have written them into `faceplates.json`. I set its `PRICE` to 40 / 100 / 250 to match `DeckThemes.lua`. The JSON rows for the existing sold plates therefore moved from a stale 30 / 60 / 120 to 40 / 100 / 250. I found no game code that reads that JSON.

### What we feature

- **The Bear** is always the white cute Bear in the **Butter Pom Beanie** (`beanie_butter`) with **Blush Stickers** (`blush`). White on blue is our strongest contrast, and the butter pom is the one Sun accent a frame is allowed. The same outfit in every shot makes the character recognisable from icon to ad.
- **The Bunny** is always **Rose** dye (`rose`), ears bare, with **Pearl Beads** (`beads`). No hat: the ears are the silhouette.
- **The deck** is always **Cloud Glass**. Lagoon and Dewy Meadow wait for the later line-up frames (thumbnail 5 can show all three in a row).
- Everything worn costs 40 Stars. Nothing in the lead images is a showcase item.
- Cloud Glass is sky blue, so on the Sky field it stands low, against the pale horizon, where its cobalt rim separates it. Icon C moves from the Aqua field to **Leaf** (blue deck on green: sky over grass).

### Shot list for Studio

Setup for every shot: beta place 107705084891479, fixture save, nothing saved or published. FOV 35. Camera at the subject's eye height unless stated. Blink off, idle beat forced. Key light from top left. Every capture is a **cut-out**: shoot each as a matched pair on plain backdrops (pets on the grey Neon pair as before; the deck with its screen lit on a black and white pair so the screen glow mattes cleanly). No shot needs a real garden background; fields, floor, reflections, bubbles and type are composited. Use the widest window available, with the subject at 70% of frame height or more.

| Shot | Used in | Subject | Dye | Items | Plate | Camera and pose | Notes |
|---|---|---|---|---|---|---|---|
| S1 | Icon A (and Ad B later) | Bear, head and shoulders | none (white) | `beanie_butter`, `blush` | none | Front, turned 10° to its left, level, looking at camera, idle smile. | Leave room above the pom. |
| S2 | Icon A | Bunny, head and shoulders | `rose` | `beads` | none | Front, turned 10° to its right, level, ears fully up. | Same camera distance and height as S1, so the two sit cheek to cheek at one scale. Whole ear length in frame. |
| S3 | Icon B | Bear, face | none | `blush` only, no hat | none | Front, head tilted about 8°, level, face filling the frame. | The bare head shows the new ears and eyes. The Star is added in compositing from the UI Star art. |
| S4 | Icon C, thumbnail 1, Ad A | Pocket Deck, screen lit | n/a | n/a | `cloud_glass` | Three-quarter: yawed 25° to its left, pitched 10° toward camera, level. | Screen shows a live merge at ×3 or more (chain-freeze method). Also one **straight-on** frame for thumbnail 5. Black and white pair. |
| S5 | Icon C | Bear, eyes and ears | none | `blush`, no hat | none | Front, level, camera a little below eye height so the Bear looks down over an edge. | Only the top third of the head is used; it peeks over the deck. |
| S6 | Thumbnail 1, Ad A | Bear, full body, standing | none | `beanie_butter`, `blush` | none | Front three-quarter (20° to its left), level, wave or idle. Feet in frame for the contact shadow. | Hero of the frame, left of centre. |
| S7 | Thumbnail 1, Ad A | Bunny, full body | `rose` | `beads` | none | Front three-quarter (20° to its right), level, ears up, sitting or standing. | Composited a little smaller and behind the Bear. |
| S8 | Ad C | Bunny, mid-hop | `rose` | `beads` | none | Side three-quarter (45°), camera low (about knee height), top of the hop arc, ears back. | Record the hop and pick the frame. It travels left to right, rising. |
| S9 | Ad C | Bear, cheer | none | `beanie_butter`, `blush` | none | Same 45° and low camera as S8, arms up at the peak of the cheer. | Leans the same way as S8. |

The Rose dye should read as a clear mid pink, not hot pink. Record how many doses the fixture used so the colour is one a player can reach.

Layouts (as in the concepts above except where stated):

- **Icon A, two pals:** S1 and S2 on the Sky field, floor at 80%, one bubble top right, no type.
- **Icon B, one pal:** S3 on the Sky field, face at 70% of the square, one Star on the floor.
- **Icon C, pocket deck:** S4 on the **Leaf** field, tilted 5°, S5 peeking over its top edge. Check the screen at 150 px; if it turns to mush, enlarge the merge pieces in the freeze, never in paint.
- **Thumbnail 1 and Ad A, the line-up:** Sky field. S6 left, S7 beside it, S4 right, low on the floor with a reflection. Wordmark **pocket pals**, tag "merge · hatch · train". Ad A is this frame unchanged.
- **Ad C, sky hop:** one 12° diagonal, Sky above, Leaf below. S8 top right, S9 lower centre. Italic "your pocket pets", tag "pocket pals". No deck here: it is the energy test and a third subject would break the one-diagonal rule. Nothing that reads as racing.

Order: S1, S2, S3, S5, S6, S7, S8 and S9 can be shot now. **S4 waits** for the Cloud Glass upload and its DeckThemes row. I compose the three icons first and show Spencer, then thumbnail 1, then Ad C.
