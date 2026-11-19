# v2 second pet, redesigned: the Bunny

Fable (as Astra), 2026-11-19. This replaces **section 1 (the Kitten)** of `V2-PET-AND-SNACKS-SCOPE-2026-11-19.md` as the creative direction for the second pet. That file is not edited; everything in it about adoption, the account closet, stats per pet and the staged plan still applies with "Bunny" in place of "Kitten". Proposal until Spencer says yes.

Spencer on the Kitten: "the cat is too ugly? look of aesthetic docs on how to make things cute af, and choose a animal to base on yourself."

So I did three things:

1. Researched cuteness and wrote house rules with numbers: `CUTE-DESIGN-RULES.md`.
2. Graded the Bear and the Kitten against them. The Kitten passed 3 of 18.
3. Picked a new animal and built it to the rules. It passes 17 of 18.

Images are in `artifacts/v2-pet-redesign-2026-11-19/`:

| File | What it shows |
|---|---|
| `01-bunny-turnaround.png` | Front, three-quarter, side, back next to the Bear; phone-size silhouettes; hat test; colours |
| `02-before-after-kitten-vs-bunny.png` | The old Kitten next to the Bunny at the same scale |
| `03-bunny-face-measured.png` | The face with the rule numbers drawn on it |
| `04-bear-tweaks.png` | The live Bear next to a tweaked copy (a study only) |
| `build_bunny.py`, `build_sheets.py`, `bunny-blockout.blend`, `bunny-report.json` | How to rebuild every image, and the measurements |

All geometry is original, built in Blender by script. No generated models, no imported models, no AI images.

## 1. The pick

**A Bunny.** Long round ears, one of them flopped. Peach body, cream socks, cotton tail.

### The shortlist

Scored 1 to 5 against the cute rules and the game's needs.

| | Bunny | Kitten, rebuilt round | Puppy | Duckling |
|---|---|---|---|---|
| Fits the cute rules (round, simple, few parts) | 5 | 4 | 5 | 4 |
| Reads at phone size | 5 | 4 | 3 | 3 |
| Differs from the Bear's silhouette | 5 | 3 | 2 | 4 |
| Wearables fit on the shared Bear body | 3 | 4 | 4 | 2 |
| A clear favourite stat | 5 (Jump) | 4 (Jump) | 4 (Speed) | 3 (Energy) |
| Kids love it | 5 | 5 | 5 | 4 |
| **Total** | **28** | **24** | **23** | **20** |

- **Kitten, rebuilt round.** Possible. But a cat's ears with the points rounded off turn into small triangles with soft corners, and from across the lawn those sit close to the Bear's round ears. The cat's other tell is a long thin tail, which breaks rule P5.
- **Puppy.** As cute as the Bunny up close. Floppy ears hang beside the head, so the phone-size silhouette is "a round head, a bit wider". Too close to the Bear. A good third pet with one ear up.
- **Duckling.** Charming, but no ears means two dead wearable slots (ear piercings, earrings), the beak sits where eyewear and mouth items go, and the front silhouette is a plain blob.
- **Bunny.** The ears are the whole design: one shape, readable from every side at 96 px, and made of nothing but round forms. Jump is the obvious stat. The cost is the hat slot, which the ear tip-out solves (section 4).

My earlier scope marked the Bunny down because "tall ears fight every hat". That was wrong: I had not tested it. `01-bunny-turnaround.png` shows a Bear-sized cap on the Bear's hat anchor with the ears tipped out.

## 2. Shape

Everything below is on the blockout and measured in `bunny-report.json`.

- **Body, hands, feet:** the Bear's, unchanged in size. Every torso, wrist and foot item fits.
- **Head:** the Bear's head at the same size, so `fit.Head = 1` and every hat, horn and pair of glasses keeps its anchor. Only smoothed (rule S1). I did not reshape it this time; reshaping is what flattened the Kitten.
- **Ears:** two long paddles, 0.62 studs long and 0.30 wide, with fully round tips. They sit on the existing `EarL` / `EarR` swap anchors, tipped 13 degrees out. **The right ear flops** out and a little forward from 40% of the way up. That is the pet's one imperfection (rule S6) and its charm point.
- **Face:** dark sparkle eyes with two catchlights and no white ring; a small pink nose; a tiny "w" mouth; a low cream snout pad a fifth of the head wide; two blush ovals.
- **Tail:** a round cotton ball in the secondary colour, 50% bigger than the Bear's tail.
- **Height:** 1.85 studs to the ear tip against the Bear's 1.48. The body is the same size; the extra is all ear.

| Measure | Rule | Bunny |
|---|---|---|
| Head, as a share of height to the crown | 50 to 60% | 55% |
| Eye width over head width | 14 to 18% | 16% |
| Eye line, up the head | 38 to 46% | 41% |
| Eye centres apart, over head width | 44 to 50% | 47% |
| Nose and mouth width | 7% and 10% or less | 6% and 8.5% |
| Sharp points | 0 | 0 |

**Triangles, honestly.** The blockout is 5,600 triangles because I smoothed the Bear's parts by blunt subdivision. That is over the 4,000 ceiling and is not shippable. A real retopology lands at about **3,000** (head 1,200, body and limbs 900, ears 500, tail and face 400), which is over the style guide's 1,800 target. The eyes, catchlights, blush and mouth become textures on small patches, like the Bear's.

## 3. Colours: "Peach Milk"

| Part | Colour | Note |
|---|---|---|
| Primary | `#FFC6B8` | Head, ears, upper body. Saturation 28%, value 100% (rule C1) |
| Secondary | `#FFF6EC` | Socks, belly, ear insides, snout pad, tail, charms |
| Nose | `#F58CA5` | Fixed |
| Blush | `#FFB0BC` | Fixed; shifts warmer on yellow and orange dyes |
| Eye | `#2B1A20` | Fixed; warm near-black with white catchlights |

- Peach is warm, reads as "soft toy", and sits opposite the garden's greens, so the pet pops on the lawn without being loud.
- It is clearly not the white Bear, even at phone size.
- Both body colours can still be dyed with Hue jars. The two-colour gradient system is unchanged.

## 4. Wearables

| Slot | Result |
|---|---|
| Hat | Works with **ear tip-out**: when a hat is on, the rig tilts the ears from 13 to 40 degrees. One rotation on two existing anchors. Shown on the sheet |
| Horns | Anchors sit between the ears; clear at sizes S1 to S3. S4 and S5 need a look |
| Ear piercings, earrings | Anchors move onto the long ears (helix a third of the way up). The flopped ear needs its own placement |
| Eyes, eyewear, cheeks, forehead | Same head, so the anchors hold. `EyeL/R` and `FaceBridge` drop 0.085 studs with the eye line |
| Neck, torso, back, wrists, feet | Unchanged. The round tail clears capes better than the Kitten's long one did |
| Charms | `CharmFloat` clears the ears by 0.07 studs. `CharmRight` sits close to the flopped ear and may need a nudge |

## 5. Personality

**Shy, then silly.** The Bear is the huggy one who runs up to you. The Bunny hangs back for a second, peeks, then bounces over and cannot stop bouncing. It is nosy, easily startled and quick to forgive. Its ears say everything it feels.

## 6. Favourite stat: Jump

**+10% Jump XP**, fixed for the species. It takes the Kitten's place in the scope exactly, so no stat rule changes. The Bear keeps Heart.

| Stat | How the Bunny shows it |
|---|---|
| Heart | Leans into your hand; both ears fold back flat; a slow blink |
| Power | A big thump of one foot on the merge pop |
| Energy | A "binky": a hop with a mid-air twist, then a lap round you |
| **Jump** | **Favourite.** Springs onto the swing and the slide in one go; ears trail behind and land a beat late |
| Speed | Zigzag dash to a thrown toy; skids past it, comes back |
| Smarts | Stands tall on its toes, ears straight up, nose twitching, before it finds a sparkle spot |

## 7. Idle and reactions

Timings follow `CUTE-DESIGN-RULES.md` section 6. All Bear poses work on day one because the rig is shared.

| Kind | Bear today | Bunny adds |
|---|---|---|
| Idle | Look about, sway, sit | **Nose twitch** (always on: three quick twitches, pause 1 to 2 s). Straight ear turns toward sounds. Sits like a loaf. Now and then it washes its face with both paws |
| Walk | Toddle | Small double hops; ears bounce 0.12 s behind and overshoot 12 degrees |
| Happy | Hop, blush | Binky. The flopped ear pops straight up for a moment, then falls again |
| Surprised | Small jump | Freezes, both ears shoot up, one foot thump |
| Sad or tired | Sit and nod | Both ears droop to the sides; flops onto its side to sleep |
| Eating | Nod and bite | Very fast tiny nibbles, cheeks puffing |
| Blink | Every few seconds | 2.5 to 5 s at random, 0.2 s long, one in five doubled; always on a head turn |

New animation work: two bones per ear (the ears carry the acting), a nose twitch, a foot thump. The rest is posing.

## 8. Art list

| Asset | What | Notes |
|---|---|---|
| Model | Smoothed head; ears L/R and inner ears L/R; snout pad; nose; tail | About 3,000 triangles. Body, hands, feet from the Bear |
| Eye texture | "Sparkle" eye, 128 px: dark oval, two catchlights, **no ring** | Also the eye for the Bear tweak, if approved |
| Face textures | "w" mouth 32 px (Closest filtering); blush decal 64 px | Blush is new for every pet |
| Alternates | One round eye and one sleepy eye; mouth "v" and small "o" | Hidden variants, like the Bear's |
| Rig | Ear bones (2 each), ear tip-out pose for hats, moved ear and eye anchors | All 46 anchors kept |
| Animation | Nose twitch, hop walk, binky, thump, ear droop, face wash, side flop | |
| Sound | Two soft squeaks, a happy hum, a foot thump, fast nibbling | Recorded or synthesised in-house. No generated audio |
| Portrait and icons | Journal portrait 256 px, pet chip 96 px, adoption basket | |
| Store art | One thumbnail with both pets | |

## 9. Bear tweaks (a note, not a change)

The rules show the Bear's body is right and its face is a little off. `04-bear-tweaks.png` compares the live Bear with a copy that has four edits:

1. **Sparkle eyes, no white ring.** The ring is invisible on the white Bear and becomes a stare on every dyed Bear.
2. **Eye line 0.055 studs lower** (52% up the head to 45%).
3. **Muzzle, nose and mouth 16% smaller** (muzzle from 33% of head width to 28%).
4. **Blush, and a smoothed head and body.**

I think the tweaked Bear is clearly cuter and the two pets look like a family with it. But it changes the face of a pet players already own in a live game, so it is Spencer's decision. The eye change alone gives most of the gain and is one texture.

## 10. Open questions for Spencer

1. **Bunny, yes or no?** If you would rather keep a cat, I can build a round one to the same rules; it scored second.
2. **The flopped ear:** keep it, or two straight ears? I would keep it. It could also become a Personality roll later (left, right, both, neither).
3. **Peach Milk** as the starting colour?
4. **Triangle budget:** may a pet go to 3,000? The round outline needs it. The 4,000 ceiling stays. Note this pulls against your 2026-11-12 call to lower the Bear to about 1,200 for the Dreamcast look (the smoother `pet-bear-smooth.blend` was set aside then). If you want to keep that look, the Bunny can ship at about 1,900 with a ten-sided head like the Bear's; it loses rule S1 and keeps every other rule.
5. **Eye ring:** drop the white ring on the Bunny only, or on the Bear too (section 9)?
6. **Gloss:** roughness 0.5 on big forms instead of 0.35, so highlights stay soft?
7. **Ear tip-out for hats:** fine as shown, or should hats sit in front of the ears?
8. **Name:** "Bunny" as the species name, like "Bear"?

## 11. What happens to the Kitten

Parked, not deleted. Its blockout and sheet stay in `artifacts/v2-pet-snacks-2026-11-19/` as the "before". A cat can come back as a later pet, built to `CUTE-DESIGN-RULES.md` from the start: round ears, a short thick tail, no fluff spikes, no eye ring, a pastel coat.
