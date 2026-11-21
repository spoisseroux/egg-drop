# Store set redo: 7 thumbnails and 3 ads (Fable, 2026-11-21)

Spencer: "We need to redo all the thumbnails / update them. And the ads." On thumb-1-lineup and ad-C-skyhop: "we need more info, what are these? The second is so sparse".

The six live thumbnails (`live-before/contact.png`) have the right structure: one feature per image, dense, a big caption. What is wrong is the look: old Bear model, caps wordmark, pink and purple gradients. This set keeps their structure slot for slot and remakes each in icon J's look, with the cute Bear and the Rose Bunny, and adds toys and stats. The two new-look drafts are retired: they have the look but no information.

## 1. What is live (public v1033, read from the code)

- **Pets:** Bear (starter) and Bunny (`blip`, 400 Stars or the 7th stamp, favourite stat Jump). Other PetCatalog rows are retired: never show them.
- **Wearables** (Bear rig, Bunny inherits; 40 / 100 / 250 Stars): hats `beanie`, `partyhat`, `sunhat`, `flowercrown`; shirts `tee`, `hoodie`; neck `beads`, `bellcollar`, `acorn`; ears `ring`, `starstud`; eyes `sparkle`, `sleepy`, `happy`, `lash`, `round`; mouth `blep`, `w`; tail `heart`, `bowtail`; `blush`, `bands`, `specs`. Ten recolours (`beanie_mint/butter/grape`, `tee_berry/forest/tangerine`, `sunhat_cocoa/peach`, `bellcollar_silver/rose`).
- **Dyes:** jars `rose`, `tide`, `citrus`, `iris`, finishes `gloss`, `matte`, `jelly`. They hatch from the Customization Egg; they are not bought directly, so no price on a jar.
- **Pocket Deck:** 21 shop faceplates (8 free, 13 at 40 / 100 / 250), 13 ball themes, five ball sizes. Results line: "Score · Best · Chain ×n".
- **Toys** (Toy Egg, never a duplicate): `ball`, `bone`, `sparkler`, `wobble_top`, `squeaky_carrot`, `pocket_deck`.
- **Stats:** Heart, Power, Energy, Jump, Speed, Smarts, level 1 to 99; Keeper tiers Seedling, Sprout, Bloom, Full Bloom, Starbloom. Stat Egg hatches a Nibble, Snack or Feast (Feast = ×3 XP).
- **Eggs:** Toy 20, Stat 15, Customization 12, Names 8 Stars.
- **Park** is on: swing, slide, see-saw, dig, ball.
- **Not live, never show:** day/night, Features tab, level rewards, capes, Garden Dash, the old rainbow egg from live thumbnails 1 and 4 (use the real egg models).

## 2. Shared look

1920x1080. Sky field with a soft radial glow behind the subject (the old sunburst, in white at 15%), 4 to 6 bubbles, glass tiles and chips with a gloss line. Caption top left in the glossy lowercase Aero type, two lines at most, cap height at least 120 px. Small **pocket pals** wordmark bottom right, except on T1 where it is the caption. Subjects fill at least 60% of the frame: the old set's density is the target.

## 3. The set (carousel order)

### T1 "pocket pals" + "merge · hatch · dress up" (replaces thumbnail 1; Ad A)
- **Layout:** as live thumbnail 1. Deck F3 large on the left, bleeding off the edge, screen readable. Bear F1 right of centre, Rose Bunny F2 beside him, Stat Egg F10 top right. Wordmark top left, tagline in a glass pill under it.
- **In code:** tagline pill; three small chips along the bottom, "6 toys", "23 outfits", "21 decks" (counts computed from the catalogues at build time).

### T2 "dress up your pal" (replaces "DRESS UP YOUR BEAR")
- **Layout:** five pets shoulder to shoulder across the full width: F7a, F7b, F1, F7c, F2. Hero Bear in the middle, largest.
- **In code:** a name-and-price chip under each ("Flower Crown ★250", "Peach Sun Hat ★100", "Butter Pom Beanie ★40", "Star Hoodie ★250", "Pearl Beads ★40"); four dye dots top right in the HueCatalog hexes, labelled Rose, Tide, Citrus, Iris.

### T3 "merge big chains" (same caption)
- **Layout:** deck F4 straight-on at 65% of the width, left. Bear F6 peeking over its top right corner.
- **Screen (real client, chain-freeze):** Bubbles theme, at least 9 balls, one size-V, real score, "Chain ×4".
- **In code:** "Chain ×4" burst overlapping the screen edge; a five-ball size ladder down the right (Sky, Peach, Melon, Blossom, Violet, in the Bubbles ramps) with merge arrows.

### T4 "hatch surprise eggs" (same caption)
- **Layout:** as live thumbnail 4. Bunny F13 left, looking at a cracked Toy Egg F10 right of centre with light shafts; the six toys F11 and four dye jars F14 flying out in an arc. Stat and Customization Eggs whole, lower right.
- **In code:** price chips on the three eggs ("Toy Egg ★20", "Stat Egg ★15", "Customization Egg ★12"); a "never a duplicate" tag on the Toy Egg; sparkle marks.

### T5 "play with friends" (same caption)
- **Layout:** the only non-Sky frame. Background F15, a real client capture of the park (swing and slide visible). In front, cut-outs: Bear F8 with the Ball, Bunny F9 mid-hop with the Squeaky Carrot, Bear F7a small on the see-saw side. Lift the plate toward Sky blue and Leaf green in grading so it sits with the set; no pink.
- **In code:** caption, wordmark, motion dots behind the Bunny, one chip "swing · slide · see-saw".

### T6 "customize your deck" (same caption)
- **Layout:** as live thumbnail 6. Three decks F5 fanned: `cloud_glass` front, `prism_flare` and `lagoon` behind. Each screen a different ball theme.
- **In code:** chips "Cloud Glass ★40", "Lagoon ★100", "Prism Flare ★250"; a strip of ball-theme dots (Smileys, Gems, Kittens, Bubbles, Midnight) each drawn from its size-III ramp; a chip "21 decks · 13 ball themes".

### T7 "level up your pal" (new slot)
- **Layout:** Bunny F13 left third. Right two thirds, a glass **stats card**. Feast snack F12 bottom centre between them.
- **In code:** the card from StatCatalog: six real icons (`assets/ui/stat-icons/icon-*-128.png`) in catalogue colours, bars reading Heart 14, Power 12, Energy 9, Jump 11, Speed 8, Smarts 7 (total 61, so the header "Sprout Keeper" is true); a "+1 LEVEL" burst on Jump from `levelup-burst-jump`; chip "Feast ×3 XP".

### Ads (1920x1080, 17+, $5/day x 7)
- **Ad A = T1** unchanged. The broad one.
- **Ad B = T3** with the caption "merge. hatch. repeat." For 17+ the merge game is the hook.
- **Ad C = T2** with the caption "make it yours" and no price chips.

Run all three at equal budget; keep the best after day 3.

## 4. Studio shot list

Black/grey pairs, fixed rig. Arms stay at or below shoulder height. Check each dress set through `PetAttachmentRules.normalize` first and drop what it removes.

| Shot | Subject | Dye (main doses) | Dress / ids | Pose and camera |
|---|---|---|---|---|
| F1 | Bear, full body | none | `beanie_butter`, `blush` | Reuse S6. |
| F2 | Bunny, full body | rose ×3 | `beads` | Reuse S7. |
| F3 | Deck, three-quarter | n/a | plate `cloud_glass`, balls `bubbles` | Reuse S4. |
| F4 | Deck, straight-on | n/a | `cloud_glass`, `bubbles` | Screen square to camera, chain-freeze at ×4, a size-V ball on board. |
| F5 | Three decks | n/a | `cloud_glass` + `bubbles`; `prism_flare` + `kittens`; `lagoon` + `gems` | Front one straight-on, back two yawed 15° left and right. |
| F6 | Bear, top of head | none | `blush`, `specs` | Reuse the S5 camera. |
| F7a | Bear, full body | tide ×3 | `flowercrown`, `specs`, `tee_berry` | Front, 15° left, idle smile. |
| F7b | Bear | citrus ×2 | `sunhat_peach`, `bellcollar`, `heart` | Front, 15° right. |
| F7c | Bear | iris ×3 | `partyhat`, `starstud`, `hoodie`, `sparkle` | Front, wave at shoulder height. |
| F8 | Bear with toy | none | `beanie_butter`, `blush`; toy `ball` | `parkBall` pose, three-quarter, low camera. |
| F9 | Bunny with toy | rose ×3 | `beads`; toy `squeaky_carrot` | Top of the hop, as S8, carrot visible. |
| F10 | Eggs | n/a | Toy, Stat, Customization Egg models | Front, level; Toy Egg whole and at the crack. |
| F11 | Six toys | n/a | `ball`, `bone`, `sparkler`, `wobble_top`, `squeaky_carrot`, `pocket_deck` | One per frame, three-quarter, one scale. |
| F12 | Feast snack | n/a | size `feast`, Jump icing | Three-quarter, from slightly above. |
| F13 | Bunny, full body | rose ×3 | `beads`, `bowtail` | Happy idle, 20° left, looking right. |
| F14 | Dye jars | n/a | `rose`, `tide`, `citrus`, `iris` | One per frame, as F11. |
| F15 | Park plate | n/a | n/a | Real client, park empty, eye height, swing and slide in frame, midday-bright lighting as the client shows it. |

## 5. Priority

1. **T1** (thumbnail 1 and Ad A): reuses S4, S6, S7; needs only F10.
2. **T3** (and Ad B): one new capture, F4.
3. **T2** (and Ad C): F7a to F7c.
4. **T6:** F5.
5. **T4:** F11, F13, F14.
6. **T7:** F12 and the code-drawn card.
7. **T5:** F8, F9, F15.

Upload as a full swap when T1 to T6 are done, so the carousel never mixes two looks.

## 6. If time is short

- Cut **T7**; put a three-icon stat strip on T1's chips instead.
- Then simplify **T5** to a Sky field with a Leaf floor and no park plate (drops F15).
- Then draw F14's jars and T6's back two decks from their catalogue colours and faceplate textures.
- Minimum: T1, T2, T3, T4, T6 and the three ads.

## 7. Rules

No AI imagery; no other game's characters, logos or layouts. Only our Studio captures and code-drawn art. Every name, price and count printed comes from a catalogue at build time. Nothing smaller than 44 px at full size; check every frame at 480x270.
