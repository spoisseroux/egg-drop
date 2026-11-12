# Overnight improvement pass, 2026-11-12

Scope only; nothing here is built yet. Another agent is working tonight on the backwards handheld hold, the semi-transparent egg-drop background (`DeckBackdrop`) and the menu redesign (`DeckMenu`, menu chrome). This plan stays out of those files, or shares a palette with them.

## 1. The core loop today, honestly

**Loop:** play a 24-drop round on the Pocket Deck → win 6–8 Stars (`FieldRun.lua:115`) → buy an item egg (Toy 8, Material 16, Feature 32) → apply the item to the Bear at the cradle → pet the Bear for +1 Star (daily cap) → play again.

**What's fun.** Merges feel physical: the deck shakes by tier and chain (`DeckMergeJolt`) and the pitch climbs with the chain (`BoardAudio:mergePitch`). Two-goal rounds (`FieldObjectives`) give aiming a purpose, which fixes the old "spam A" problem. Petting with a purr, the Sparkler and the egg crack are charming.

**What's flat.**
- **The two halves never touch.** While you play, the pet just rests (`GardenState.lua:86`, `input.mode=="Board"` → `"rest"`). Nothing you do on the deck shows up in the pet, and nothing the pet does matters on the deck.
- **The pet has a narrow range of expression.** Six poses exist (`PetExpression`), but `GardenActivity.lua:169` only reaches curious, pleased, sleepy and startled (startled only during toy play). The Bear's `EarL/R` and `Tail` are separate parts, yet `GardenPetVisual` never moves them: the ears never flick and the tail never wags. Expression is just eye scale and mouth swaps.
- **The Bear has someone else's voice.** `PetCatalog` gives the Bear Zivvi's `pet` cue, so it doesn't sound plush.
- **Losing pays nothing.** A failed round pays 0 Stars and only advances the dailies. There's no near-miss feedback, and the `overflow` and `retry` cues are loaded but never played (`BoardAudio.cues` compared with the call sites in `init.client.lua`).
- **Merges show no score.** `FieldEffects` gives a halo and one chain caption, but no numbers.
- **The colour is muddy.** Three overlapping palettes (`DeckPalette`, `JellyPalette`, the 8 LCD sets in `DeckThemes`), and the menus are opaque charcoal.
- **Not much to chase.** All three toys take about 3 wins. After that, only Feature (32) and Hue remain. Nothing calls you back each day except the 3 dailies and the gift.

**The biggest friction:** after the first few rounds the deck and the garden feel like two separate games, and the pet, the thing players are meant to love, gives too little back.

## 2. Improvements by bucket

Effort: S < 2h, M is half a day, L is a day or more. **ON** = overnight-feasible (S/M, low risk, verifiable in Studio Play).

### A. Design and loop
| # | Item | Player benefit | Files | Effort | Risk | ON |
|---|---|---|---|---|---|---|
| A1 | Pet cheers you on during a round (§3, step 5) | The deck feeds the pet, so the two halves connect | `GardenPetVisual`, `init.client.lua` (merge/round serials) | M | Low | Yes |
| A2 | Consolation Star when you lose but merged at tier III or higher | Losing still feels like progress | `FieldRun`, `HatchProgress` transaction, `RoundRecap` | M | Med (economy, needs Spencer) | No |
| A3 | Pet "wants" bubble (play with toy, be petted, watch me play) with a small bonus | Gives a garden goal each session | `GardenState`, `RoomView`, new `PetWants` | L | Med | No |
| A4 | Special eggs on the board (rainbow wildcard, a rare one in 24 drops) | A drop decision beyond aim | `BoardSimulation`, `BoardConfig`, `JellySprite` | L | High (balance, server sim) | No |

### B. Feedback and juice
| # | Item | Player benefit | Files | Effort | Risk | ON |
|---|---|---|---|---|---|---|
| B1 | Floating "+score" pops at each merge, coloured by tier, with an escalating chain caption ("×2 ×3 ×4!") | You can see why a merge was worth more | `FieldEffects` (already pooled), `init.client.lua` merge handler | M | Low | Yes |
| B2 | Wire the unused `overflow` (danger) and `retry` cues, and pulse the overflow line red while armed | Danger reads before you lose | `init.client.lua`, `BoardAudio`, `JellyLCD` | S | Low | Yes |
| B3 | Stars count up in the recap with an ascending tick (reuse `charge` pitched up per Star) | Payout feels earned | `RoundRecap`, `RecapFeedback` | S | Low | Yes |
| B4 | Haptics on drop, merge and clear (`HapticService`, gamepad and mobile) | Tactile handheld feel | `BoardAudio` or new `DeckHaptics` | S | Low | No (Studio can't verify) |
| B5 | Hitstop: freeze render for 40–60 ms on a tier V clear | Big moments land | `init.client.lua` renderer | S | Med (render owner) | No |

### C. Pet expressiveness and interactivity
| # | Item | Player benefit | Files | Effort | Risk | ON |
|---|---|---|---|---|---|---|
| C1 | Procedural ear flicks and tail wag, driven by expression | The Bear feels alive at any distance | `GardenPetVisual` (pieces loop ~l.275), `PetIdleMotion` | M | Low | Yes |
| C2 | Petting that builds: tap is a boop (squash and giggle); holding goes pleased → affectionate, with hearts and a faster wag | Petting has a payoff curve | `RoomView` (contact ~l.760–870), `PetAffection` (recolour petals as hearts) | M | Low | Yes |
| C3 | Idle personality beats: yawn, stretch, sneeze, spin, wave at an owner standing still | Rewards watching your pet | `PetIdleMotion`, `GardenPetVisual` | M | Low | Yes |
| C4 | Use the unused expressions: startled when bumped or when an egg crashes nearby, affectionate on greet | More readable emotional range | `GardenActivity.lua:169`, `PetExpression` | S | Low | Folded into C3 |
| C5 | Visiting pets greet each other with a mutual hop and chirp | Social garden moments | `RoomCompanions`, `GardenState` peer actions | L | Med (multiplayer) | No |
| C6 | Blendshape-free mouth set for the Bear: w, o, ^ (alpha decals) | More faces | Bear assets, `GardenPetVisual` | M | Med (asset upload) | No |

### D. Visual (PICO-8 palette plan)
Add one token module, `src/shared/Pico8.lua`, holding the 16 standard colours: 0 `#000000`, 1 `#1D2B53`, 2 `#7E2553`, 3 `#008751`, 4 `#AB5236`, 5 `#5F574F`, 6 `#C2C3C7`, 7 `#FFF1E8`, 8 `#FF004D`, 9 `#FFA300`, 10 `#FFEC27`, 11 `#00E436`, 12 `#29ADFF`, 13 `#83769C`, 14 `#FF77A8`, 15 `#FFCCAA`. The menu agent can consume it too.

| Element | PICO-8 (rim / body / highlight) |
|---|---|
| Tier I jelly | 1 / 12 / 6 |
| Tier II | 4 / 9 / 15 |
| Tier III | 3 / 11 / 7 |
| Tier IV | 2 / 14 / 15 |
| Tier V ("gold") | 4 / 10 / 7 |
| Jelly mark and ink | 0 |
| Overflow line, danger, error | 8, plus a word (never colour alone) |
| Stars, amber, A button cap | 10 with shadow 9 |
| Focus ring | 12 |
| Primary action | 11 fill, ink 0 |
| Board background (semi-transparent) | 0 at 35–45% opacity; dither 1 |
| Menu glass (PS-style) | 0 at 25–35% opacity, raised card 5, text 7, secondary text 6, deck-theme tint at 10–15% |
| Pet hearts, Star award, sleepy "z" | 14, 10, 13 |

| # | Item | Player benefit | Files | Effort | Risk | ON |
|---|---|---|---|---|---|---|
| D1 | Add the `Pico8` module and retint the 5 tiers and danger line | Bright, coherent arcade look | new `src/shared/Pico8.lua`, `BoardConfig.Tiers`, `JellyPalette.colors` | S | Low (7 Jelly/Theme specs to rerun) | Yes |
| D2 | Snap the deck theme LCD palettes to PICO-8 ramps | Every shell matches | `DeckThemes` | M | Med (saved theme ids stay, colours only) | No (wait for the menu agent) |
| D3 | Optional `Enum.Font.Arcade` for score and chain numerals only | Retro numerals | `FieldEffects`, `StarText` | S | Low | No (taste call) |

### E. Audio and SFX
Roblox audio must come from (a) an upload: extend the original synth bank (`scripts/synth_egg_drop.py`) and upload it through Open Cloud, which counts against the monthly quota and waits on moderation; or (b) Roblox-owned free sounds found with the Studio Creator Store search. New ids go in `BoardAudio.assetIds` and the TODO "confirm all SFX load" gate.

| Event | Cue | Sound |
|---|---|---|
| Aim tick (exists) | `aim` | Soft click, keep it |
| Drop (exists) | `drop` | Short "plip" |
| Land (exists) | `land`/`bank` | Wet jelly thud, pitched by impact |
| Merge I–IV (exists) | `merge_bubble`/`merge_jelly` | Bubble pop, rising per tier |
| Chain accent (exists) | `merge_chain` | Bright arpeggio note, rising per link |
| Tier V clear | `clear_v` (new) | Sparkly glass chime with a downward whoosh |
| Overflow armed | `overflow` (exists, unused) | Low two-note warning blip, repeated while armed |
| Round won | `win` (new) | 4-note major chiptune jingle, about 1.2 s |
| Round lost | `lose` (new) | Descending "wah-wah", soft and short, not mean |
| Star count tick | `charge` (pitched) | Coin tick rising each Star |
| Retry | `retry` (exists, unused) | Cartridge "ka-chunk" |
| Bear boop or tap | `bear_boop` (new) | Plush squeak, 3 pitch variants |
| Bear happy | `bear_chirp` (new) | Tiny rising "mew-hm" hum |
| Bear yawn or sleepy | `bear_yawn` (new) | Breathy descending hum |
| Toy squeak | `toy_squeak` (new) | Rubber squeak on ball/bone bite |
| UI deny | `deny` (new) | Dull buzz (other UI keeps the `menu` variants) |
| Egg buy | `purchase` (new) | Coin purse "cha-ching" |
| Garden ambience | loop (new) | Birds by day, crickets by night, tied to `HollowClock` |

| # | Item | Effort | Risk | ON |
|---|---|---|---|---|
| E1 | Wire the existing unused cues (B2) and pitched Star ticks (B3) | S | Low | Yes |
| E2 | Bear voice set (boop, chirp, yawn) through `PetCatalog.cue` | M | Med (needs upload or Creator Store ids) | Yes, if ids can be got tonight |
| E3 | Win and lose stingers, `clear_v`, `deny`, `purchase` | M | Med (upload) | No (batch the upload) |
| E4 | Day/night garden ambience | M | Low | No |

### F. Engagement and retention (soft launch)
| # | Item | Benefit | Effort | Risk | ON |
|---|---|---|---|---|---|
| F1 | Daily streak (days played), with a cosmetic every 3rd day (sticker or charm shape) | A reason to return tomorrow | M | Med (save schema) | No |
| F2 | First win of the day pays double | A strong daily hook that stays cheap | S | Med (economy, needs Spencer) | No |
| F3 | Pet remembers you: a bigger greeting after time away, scaled by absence | Emotional return hook | M | Low | No (needs a save timestamp) |
| F4 | Photo pose: hold the Bear to the camera with a frame | Shareable, social | M | Low | No |
| F5 | Charm Egg as the late Star sink (already approved in PET-STYLE-GUIDE) | Long-term goal | L | Med | No |

## 3. Overnight batch (implementation order)

Run the Jelly, Theme, PetPersonalPlay and garden visual specs after each step (via ZZSpecs copies). Commit each step on its own and keep `TODO.md` current.

1. **D1: PICO-8 tokens and tier retint.**
   - Studio check: the five tiers render with the table's hexes on the Scout and Creek shells, tier marks stay legible, and the overflow line is `#FF004D`.
   - `JellyPalette.resolve(BoardConfig.Tiers[n].color)` returns the tier entry.
   - The Jelly and ThemeLCD specs pass, with expected hexes updated.
2. **B2/E1: danger and retry.**
   - Stack eggs past `OverflowY`. When the meter arms, `overflow` plays once (repeating no faster than every 0.6 s) and the line pulses red. It stops when the danger clears.
   - Retry plays `retry` once.
   - Neither sound plays under the menu or on a hidden board.
3. **B1: merge score pops.**
   - Each accepted merge shows "+N", where N equals the server's score delta, at the merge point in the tier's colour. It fades within 0.7 s, with at most 4 on screen.
   - Chains of 2 or more show "×N" in 9 → 10 → 8 as the chain grows.
   - Reduced Effects shows no motion, only the final score.
   - No new Instances are created per event (reuse the pool).
4. **B3: Star count-up.**
   - A won round's recap counts 0 → payout with one pitched `charge` tick per Star (pitch +3% each). The final value matches the receipt.
   - Reduced Effects shows the final value instantly.
   - A zero payout shows "0" with no ticks.
5. **A1: Bear cheers you on.**
   - With the deck up (the board is now semi-transparent), a tier III+ merge or a chain of 3 or more makes the resting Bear hop (greet amplitude) with the "pleased" face and a chirp. These reactions are limited to one every 1.5 s.
   - A win plays a double hop. A loss shows "startled" for 0.4 s, then "sleepy".
   - The pet's server state never changes (presentation only).
   - Visiting players see nothing new.
6. **C1: ears and tail.**
   - In Play near the Bear: the tail wags at about 1 Hz on neutral, about 3 Hz on pleased or affectionate, and is still when sleepy.
   - The ears perk (+10°) on curious, droop (−15°) when sleepy, and flick once every 4–9 s at random.
   - Reduced Effects freezes all of this.
   - Bounds padding in `PetIdleMotion.padding` covers the new rotation, so there's no clipping in the cradle preview.
7. **C2: petting that builds.**
   - Tapping E: squash 0.15 s, plus `pet` (or `bear_boop`) at a random pitch from 0.96 to 1.08.
   - Holding E: pleased at 0–1 s, then affectionate from 1 s, with pink (14) hearts replacing the petals and a fast tail wag.
   - The Star award behaviour and the daily cap are unchanged (`PetContact` untouched).
8. **C3/C4: idle personality beats.**
   - When the Bear has been idle for more than 8 s, it does one of yawn, stretch, sneeze, look-around, or wave (wave only if the owner has stood still within 6 studs), no more than one per 10 s.
   - The schedule is seeded per pet, so the same pet behaves the same way across a rejoin.
   - Never during carry, care, toy or focus.
9. **E2: Bear voice (only if ids are available tonight).**
   - The Bear uses a `bear_*` cue set. All new ids preload without warnings in the Output.
   - Otherwise, skip this step and note it in TODO.

## 4. Later
- **Needs Spencer's call (economy or save):** A2, F1, F2.
- **Larger builds:** A3, A4, C5, C6, F3, F4, F5.
- **After tonight's menu work:** D2, D3.
- **Needs an audio upload batch:** E3, E4, and a decision on the garden music draft.
- **Needs a device:** B4, B5, and a physical-phone check of every juice item at Largest text.
