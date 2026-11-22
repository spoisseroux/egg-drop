# Bright previews, Stars sound, +N banner: direction (Fable, 2026-11-22)

## 1. Light: D

`Kit.PetLight`: Ambient **215,215,215**, LightColor **200,200,200**, direction unchanged (upper left, not the "front" of H and I).

- B and C are flat: Bunny shading spread 13, white pets become paper cut-outs on plum.
- E and G push yellow to lemon (254,223,91; true 255,208,75) and bleach the lavender belly.
- H and I light from the front and lose the belly's roundness.
- D keeps true colours (253,212,83; 251,129,161), white at 254,253,251 and spread 38/36. F is D with less shape.
- Keep it neutral: the old warm tint is what turned white into 229,221,212.

White pets on the plum stage are fine under D; ears, blush and under-shade hold the form.

Headshot disc (`PetHeadshot.backdrop`): change it. A white head on cream 255,244,220 has almost no edge.
- Lerp toward cream **.40** (was .55).
- If every channel of the result is 225 or more, use lilac **226,214,242**.
- No outline: a ViewportFrame cannot stroke the pet.

`MaterialFinishPreview:142`: leave it. Its directed 255,246,226 light over 128,155,157 ambient is what separates gloss from matte.

## 2. Sound: candidate A at volume 0.70

`scripts/synth_stars_bought.py` (seeded; numpy, wave, house helpers). C major pentatonic, no pop, no even trill.

| | length | peak | RMS | centroid | clipped | last 10 ms |
|---|---|---|---|---|---|---|
| A | 1.20 s | -3.0 dBFS | -18.5 dBFS | 1505 Hz | 0 | -92.5 dBFS |
| B | 1.10 s | -3.0 dBFS | -17.9 dBFS | 1380 Hz | 0 | -88.5 dBFS |

- **A, "shower, then home".** Five glass notes drop like Stars into a jar (E7 C7 D7 A6 G6, slightly uneven, each with a tiny tick), a soft warm C chord lands at 0.42 s, one high glint answers at 0.64 s: "tinkle-tinkle, ahh, ting".
- **B, "bounce up, ta-daa".** Four notes climb and quicken (C6 E6 G6 C7), thin glitter, a two-step finish at 0.36 and 0.50 s. Closer to the Uncommon hatch sting, so A is the pick.

At 0.70 A peaks at -6.1 dBFS, level with `quest_complete`. No music duck.

## 3. Banner

A sticker inside the stage well, lower third, centred, over the icon's number (which it repeats). It never leaves the well, so it cannot reach the Buy key.

| | desktop (848 panel) | phone 844x390 |
|---|---|---|
| height | 40 | 28 |
| centre y | well.h - 30 | well.h - 22 |
| max width | well.w - 24 | 126 |
| side padding | 16 | 10 |
| text size | 22, shrink to 14 | 14, shrink to 11 |

- Face `stars` (255,193,77); text and Star glyph `ink` (21,20,58); 2 px `cream` border; `ink` drop at (1,3); tilt -4; ZIndex well + 6; not selectable.
- In, 0.28 s: scale .6 to 1.08 to 1, 12 px rise, 0.12 s fade; stage sparkles flash white 0.3 s. The cue starts with it.
- Hold 4.0 s from the last start. Restart: new text, 0.18 s pulse to 1.08.
- Out: 0.2 s fade, 6 px rise.
- Reduced Motion: 0.12 s fade in and out only. Same words, same 4 s.

## Not judged

The sound by ear. Headshots on the new disc and the Pocket menu tile under D (no captures). Whether the candidate grid used neutral greys.

## Render review (Fable, 2026-11-22, Studio captures of the warm build)

Built light: Ambient 215,213,210, LightColor 200,194,182. Measured on the white Bear (pet pixels only).

| capture | old mean | new mean | new p5 / p50 | at 250+ |
|---|---|---|---|---|
| Companions | 209,204,195 | 231,229,227 | 180 / 236 | 38% |
| Wardrobe | 214,210,199 | 237,235,233 | 189 / 248 | 48% |
| Pets stage | - | 231,229,228 | 180 / 237 | 39% |
| Material | - | 230,227,225 | 178 / 232 | 34% |
| Pocket tile | 227,223,223 | 226,222,222 | 160 / 230 | 31% |

- **Companions, Wardrobe, Customize, Material: pass.** The cream cast is gone (R-B spread 14 down to 4) and white reads white. Keep the warm variant; no light change.
- **Pocket tile: pass on the result, not proven as a change.** tile-old and tile-new measure the same, so tile-old is not a true "before" (or the tile was never the dark one). Recapture a real before only if someone needs the proof.
- **Headshot disc: change.** The undyed secondary is #A8A5AE for every pet, so every undyed pet gets a disc of about 203,197,192 (HSV S 0.05): dingy grey under a white head. Rule, on the lerped disc: use lilac 226,214,242 when **S < 0.08**, or when every channel is 225 or more (existing). 0.08 leaves one-dose pastel discs (pale Tide is about S 0.10) alone.
- **Original colour / White cards: change.** Swatch renders 253,253,253 behind a white Bear. In `HueEggView.lua` (the `swatch=` at lines 1639 and 1644, painted by `CustomizeCards.dress`): when the resolved colour has S < 0.08 and V >= 0.60, paint lilac 226,214,242; otherwise the true colour. This covers white main and the grey undyed secondary. Jar tiles keep their fruit colour. One shared helper with the disc rule.
- **Got worse, accepted:** the lit side of a white pet now clips (38 to 48% of pet pixels at 250+, was 0%), so the Wardrobe close-up head is flatter. Body is true #FFFFFF, shade side still 180 to 189, ears, muzzle and blush hold the form. If Spencer calls it flat, drop Ambient only to 205,203,200. Nothing else regressed.
- Not judged: a dyed or non-white pet under the built light, phone size, the locked Bunny silhouette (unchanged).
