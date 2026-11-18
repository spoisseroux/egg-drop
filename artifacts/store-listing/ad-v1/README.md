# Pocket Pals: Pet Garden, lead ad / Sponsored thumbnail (ad-v1)

Built 18 November 2026 for the public game. Nothing is uploaded; Spencer picks.

**Revision r2 (current `ad-v1-*` files), from Spencer's notes:** the deck is now the **Prism Flare** showcase faceplate (bought in Studio with test Stars), frozen mid-round on a ×3 chain (11 eggs left, no "Settling…" pill), colour-lifted and given an ink rim so the pastel shell holds against the pink sky. The blue Bear has **Sparkle eyes and no glasses** (Sun Hat, Beads, "w" mouth). The egg is now the game's own egg meshes and Companion Egg texture built in the 3D stage in the hatch pose (top shell lifted and tipped over the glowing core, as `EggPreview3D` poses it), clean and outlined, with a warm halo and rays. The first version is kept as `ad-v1-r1-*.png` (its raw captures stay in `raw/`; `build_ad.py` now builds r2 only).

| File | What it is |
|---|---|
| `ad-v1-1920x1080.png` | **Variant A (lead).** Tilted POCKET PALS wordmark (icon D style: Builder Extended Bold, cream, ink outline, gold underline, 4°) with the MERGE · HATCH · DRESS UP pill under it. |
| `ad-v1-B-1920x1080.png` | **Variant B.** Same art, straight and larger wordmark, the tagline pill along the bottom over the deck. |
| `*-480x270.png` | Small-size previews (Lanczos) for the Sponsored-slot check. |
| `build_ad.py` | Rebuilds every layer and both variants from `raw/`. |

## What's in the frame

Every picture element is a Studio Play capture from place 96451847774961 (2026-11-18, nothing saved or published). The only additions are the wordmark and tagline (the game's own Roblox fonts), the white/ink sticker outlines, drop shadows, warm glows, the celebration rays behind the merge (drawn in the style of the results Star's rays) and a light colour grade. No AI or stock imagery.

- **Pocket Deck** (r2: Prism Flare faceplate, Smileys balls): a real Easy round frozen on a CHAIN ×3 merge (score 240, 11 eggs left). r1 used the mint faceplate on the round's last-drop ×4. The frame was frozen by cloning the deck ScreenGuis the instant the chain counter changed, then captured over black and white mattes. The deck is warped in perspective (left edge nearer).
- **Merge pop**: the same frame's ball cluster (purple, pink and orange balls with faces, the ×4 label and the +50 ring), with the LCD background keyed out, enlarged 1.9× (nearest neighbour, it is pixel art) and laid over its own spot.
- **Stars**: the game's 3D StarToken (`CelebrationKit.star`), five sizes and turns, with motion ghosts.
- **Bears**: client-only `PetFactory` Bears in frozen real poses. Front: white plush Bear in the red Pom Beanie, Bell Collar, Happy eyes and Blush, hugging its Ball (stretch beat). Back: Tide (blue) Bear with Gloss, Sun Hat, Specs, Beads and the "w" mouth, waving (wave beat). Lit by a small client PointLight for fill.
- **Egg** (r2): `Shared.EggModels` TopShell/BottomShell/Core meshes via `CreateMeshPartAsync`, Companion Egg colour map, top lifted 0.16 and tipped 14° over the Neon core (raw `eggs3d-*.jpg`, middle egg; the intact Companion and Toy Eggs beside it are spares). r1 used the hatch cinematic through `RevealCaptureFixture` at 0.97 s.
- **Background**: the dusk garden (stone arch, floating island, pink clouds), blurred.

## Layers (`layers/`)

`bg` (blurred garden), `deck` (difference matte, untrimmed: coords = capture − (270, 60)), `merge_pop`, `bear_white`, `bear_tide`, `egg_solid`, `egg_light` (black-frame light for screen blending), `star_a`–`star_e`.

## Raw captures (`raw/`)

Studio `screen_capture` frames, 1920×777 (the 2107×853 viewport at 0.91). Pairs named `*-black.jpg` / `*-white.jpg` (or `*-grey.jpg` for 3D shots in r2: white Neon glows into the subject's edges, 50% grey does not) are the same frozen frame over a black and a white backdrop (a Neon part for the 3D Bears, a full-screen Frame for UI): alpha = 1 − (white − black) / (white bg − black bg). Also kept for reference: `deck-chain4-garden.jpg` (the frozen frame over the garden), `tray-chain3-pop-garden.jpg` (an earlier ×3 freeze), `results-so-close-star.jpg`, `garden-island-wide.jpg`.

## Regenerate

`python artifacts/store-listing/ad-v1/build_ad.py` (numpy + Pillow; the fonts come from the local Roblox install). To reshoot: Studio Play, `DeckNetHarness.setup()` for a fresh save and a field round, drop through the `PlayerGui.EggDropClientSim` bindable (`"drop"`; BoardRequest drops are ignored now the deck is client-run), and freeze on `ChainFeedback.Text` ≥ ×3/×4 by cloning `EggDrop`, `EggDropDeck`, `EggDropBleed` and `EggDropOverlays` (clone all first, then disable the originals) and hiding `FROZEN_EggDropBleed.BoardBacking`. For Bears, build `PetFactory.new(...)` clones high above the map with a Neon backdrop, override `PetIdleBeats.step` to force a beat and phase, run `update` for ~2.5 s so the authored meshes load, then stop updating.

## Self-critique r2 (480×270)

- Title, tagline, the green smiley cluster, both Bears and the egg all read. The egg is now clean and reads as "about to hatch".
- The Prism Flare shell is pastel and needed the ink rim to separate from the sky; it reads premium but less punchy than a dark plate (Night Orb would contrast more).
- The green balls' faces are smaller than r1's purple ball; a faint copy of the cluster shows in the LCD under the pop.

## Self-critique r1 (480×270)

- **Reads:** POCKET PALS, the smiling ball cluster, both Bears and the egg read at 480×270. The tagline pill reads in both variants.
- **Focal point:** the merge pop (with the big Star beside it) is the brightest, most saturated thing; the Bears are the second read. The egg is the weakest element: pale against the warm sky, its crack only reads up close.
- **Clutter:** the deck's goal and quest text is noise at small size but sits in a dark panel, so it doesn't compete. The deck's own POCKET DECK wordmark echoes the title; cropping further left would remove it but lose the D-pad that says "handheld".
- **Improvement pass done:** replaced a photo-card pop-out with a keyed, outlined ball cluster; moved the egg out from behind the deck; shrank the Bears so their heads aren't cropped; replaced captured rays (cut at the capture edge) with clean rays; fixed the egg's matte (the reveal's light is drawn over the shell) and filled its crack with warm light; final contrast and saturation lift.
- **Not achieved:** no Lime Gel faceplate (the default mint faceplate is shown); the merge frame is the round's last drop, so a small "Settling…" pill shows above the field; the CHAIN ×4 label inside the pop is small (the in-game ×4); no Stars-flying frame exists in game, so the Stars are composited sprites of the real token.
