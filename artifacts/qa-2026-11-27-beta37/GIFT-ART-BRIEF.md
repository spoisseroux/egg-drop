# Gift art brief: chip, ribbon, gift card, paint wipe, nest Peek (Fable, 2026-11-27)

For Opus, beta (40). **Everything is P1.** Final art for beta (39)'s placeholders (`GiftBubble`, `GiftReveal`) and the unbuilt Peek (`NestClient`). Looks and feel only: no rule, odds, grant or save change. Drawn from GUI instances and parts; the emoji glyphs (🎁 🎀 🧸) go. Read from code, not played.

**Kit.** Ink `#1B2A4A`. Glass: white at 85%. Gift pink `#FF6FA8`, deep `#D8327E`, light `#FFD3E6`. Gold `#FFC14D` is Stars only: none here. Pots (`HueCatalog`): rose `#FF327A`, tide `#008DFF`, citrus `#FFCC00`, iris `#9350FF`.

**The wrapped egg** (one drawing; 36, 44 and 28 px). An egg (rounded Frame 0.78 x 1.0, corner 50%), gradient `#FFFFFF` to `#C9F1FF`, 2 px ink stroke. A pink band down it (22% wide) and one across (18% high) meeting 42% from the top; there a bow: two pink loops (30% of the width, ±28 degrees) and a 4 px `#D8327E` knot. Aero glint: a 2 px white bar upper left and a separate dot below right.

## 1. The gift chip and the machine ribbon

**Chip** (over the pet; 36 px, hit 52, as built).
- The wrapped egg on a glass disc, 2 px ink stroke.
- Idle: the 1.2 s pulse goes. It bobs 3 px on a 2.4 s sine; every 6 s the bow wiggles once (±10 degrees, 0.3 s) with one 0.3 s glint (`AeroUI.sweep`). No sound, buzz, badge or number: it waits, it does not ask.
- Parking: scale 0, 1.15, 1.0 in 0.25 s; `cup_shine` at gain .25.
- Within 10 studs: scale 1.15. Beyond 60: 60% alpha. Hidden under any menu, card or the deck.
- Tap: `AeroUI.Press`, `menu`, `drop` buzz.
- The invite pill: its icon is the 44 px wrapped egg, glass fill, a 2 px pink stroke instead of ink, so a gift never reads as a need.

**Ribbon** (a real ribbon, not a dot).
- A matte pink sash across the dial (0.22 studs wide, 0.05 thick, 30 degrees) and a bow at its upper right: two 0.5 stud loops, a 0.18 knot, two 0.45 stud tails swaying ±6 degrees on a 3 s sine. Local, anchored, no collision or shadow.
- A tag under the bow: `BillboardGui` 92 x 30 px, glass, "Free egg!" (BuilderSansExtraBold 16, ink), the 28 px egg at its left. `MaxDistance` 60.
- Idle: one glint down the sash every 5 s. `machine_attract` once a session, the first time the player is within 20 studs.
- First crank tick: the bow unties (0.2 s), the sash slides off, falls 1.5 studs and fades (0.4 s); `blanket_rustle` at 1.3, `machine_light` buzz.
- Reduced Motion (both): no bob, wiggle, sway or glint; the untie is a 0.15 s fade.

## 2. The gift card

The paid card's system: `HatchItemStage`'s well in **Sky** (`#C9F1FF` core, `#2FA8F0` edge, still rays, 6 bubbles), glass plates, ink text, 340 x 300. What makes it a present:

1. **Wrapped corner.** A 26 px pink sash across the top-left corner at 45 degrees (1 px `#FFD3E6` top edge); a 44 px bow on the corner, 12 px over the edge.
2. **Gift tag** in place of the egg-type line: glass, 190 x 34 px, tilted -4 degrees, a 2 px pink string. "A gift from {pet}!" (FredokaOne 20).
3. **The giver.** The pet's headshot (64 px, 3 px white ring) over the top-right edge, as on `AllSetCard`.
4. **The item.** Paint: `HueJarArt`'s pot, 96 px; bubble rims and confetti take the pot colour. Toy: its icon, accent pink. No tier sticker, price or Stars.
5. **Words.** Name (ExtraBold 22); the real odds line as built, 14 px at 65%.
6. **Buttons.** Primary 170 x 52 in the **pot's colour** (ink label; white on iris and tide), idle glint every 6 s; "Later" a glass pill 110 x 52.

**Entrance, 0.9 s.** 0.0 the card pops 0.85, 1.05, 1.0 in 0.3 s, `screen_rise`. 0.15 the sash draws (0.2 s) and the bow ties, `blanket_rustle` 1.2. 0.35 the pot drops 30 px and squashes 10%, `egg_tok_1`. 0.5 `rarity_common`, `pop` buzz, 12 confetti dots, one light sweep. 0.6 the tag swings -14 to -4 degrees. Buttons at 0.9.
**Exit.** Primary: the card folds into the pot (0.2 s), which arcs to the pet (0.35 s). Later: `screen_tuck`.
**Reduced Motion.** A 0.15 s fade; sound and buzz stay.

## 3. The paint wipe (1.8 s, in the garden)

Pet focus camera, side on, 4% closer over 0.3 s.

| t | What |
|---|---|
| 0.0 | The pot (1.2 studs) arrives 2.2 studs over the pet and tips 110 degrees. The pet looks up, eyes wide. `snack_sniff` |
| 0.25 | A 0.5 stud ribbon of paint lands on its head. The pet squashes 12%. `merge_jelly` at .8, `crack1` buzz |
| 0.4 to 1.0 | **The sweep**, crown to feet (paint pours down), Quad in-out. Leading edge: a 0.25 stud band of pot colour halfway to white, 6 drips 0.2 studs ahead. Behind it, the final colour. `shimmer_loop` .9 rising to 1.3, `creak` buzz |
| 1.0 | A 3 stud ring of pot colour spreads on the ground, fades in 0.4 s. `merge_bubble` 1.12 |
| 1.05 to 1.45 | The shake: ±14 degrees, four damped swings; 10 beads fly off (0.45 s). `shell_scatter`, `settle` buzz |
| 1.45 to 1.8 | It looks at each paw, then jump-spins. `snack_happy_squeak`, 10 sparkles, `pop` buzz |

Then 2 s under the pet: "{pet} is {colour}!". Face, eyes and secondary palette never tint. A duplicate pot: 60% length, "Deeper {colour}!".
**Reduced Motion.** A 0.4 s cross-fade, the ring, sound and `settle` buzz.
**Budget.** Pooled: 6 drips, 10 beads, 10 sparkles. AliveBudget 2: cross-fade and sound.

## 4. The nest Peek (2.4 s, on the tuck)

**Honest.** The nest egg never holds a pet: it holds `public.nest.gift` (hat, neck piece, toy, charm or Stars). The fun pass's "who is inside" and "the second pet" were wrong. The shadow is the gift's **real kind**, five ink shapes built from frames: hat (dome on a brim), neck (bow tie), toy (seamed ball), charm (diamond on a loop), stars (a star). The Stars chip is the true number. The name waits for the hatch.

Replaces the cream tile in `Client:peek`; the "Peek" verb plays the same look.

| t | See | Hear, feel |
|---|---|---|
| 0.0 | The blanket lands (built). The egg rocks ±6 degrees three times, each smaller; the Bear leans in | `egg_wobble`, then `egg_tok_1`, `egg_tok_2`; `settle` buzz |
| 0.6 | A zigzag crack of light opens across the front, 0.9 studs wide: cream `#FFF3C4` inside, the shell's lavender `#C9B4FF` at its edges; a `#C9B4FF` point light (range 8) on the nest and the Bear's face; four shafts fan 40 degrees | `egg_crack_glint`; `reveal_shimmer` at .3; `crack1` buzz |
| 0.8 | In the light, a 72 px disc: the kind's shape in ink, a white "?" (FredokaOne 34) bobbing 2 px. Below: the "+10 ★" chip and "Egg 1 of 7" | `reveal_hush`. The Bear gasps: hops back 0.4 studs, paws up, `bear_boop` at 1.2 |
| 1.9 | The crack closes (0.3 s), the disc shrinks into it, one Zzz puff. Pill: "Sweet dreams!" | `blanket_rustle`; `pet_coo_1` at .85 |
| 2.4 | The 2 s toast, then the Paint Egg invite 1.5 s later, as built | |

Light only: the shell is never broken or marked. No camera move, no card. The prompt is off for 3 s.
**Reduced Motion.** The light and the disc fade in and out (0.2 s), held 1.6 s; no rock, shafts or bob.

**Captures for my review** (600 x 360): the chip beside a need bubble; the ribbon at 10 and 40 studs, day and night; the card for four pots; the wipe at 0.7 s; the Peek at 0.9 s (a hat egg, a Stars egg).

**Spencer decides:** hiding the nest gift's name until the hatch (today's tile names it).
