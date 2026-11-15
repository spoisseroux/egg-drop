# Hatch reveal redesign, 2026-11-15 (QA v685 H1, H2, H3, H5)

**Not published.** Branch `feat/egg-drop-arcade-polish`, commits `bdc573d`, `2ccd618` and the commit that adds this folder. Private v685 is unchanged.

**Nobody has watched this play live or listened to it yet.** The frames below are real Studio renders of the real modules, stepped by hand. Spencer's eye and ear on a phone are the acceptance test.

## Look here first

| What | File |
|---|---|
| Common vs Rare item reveal, phone, frame by frame | `sheets/phone-common-vs-rare-side-by-side.jpg` |
| Pet reveal, phone, frame by frame | `sheets/phone-812x354-pet-bear-contact-sheet.jpg` |
| All four reveals moving (slowed to 0.4x) | `sequences/phone-812x354-all-four-grid-slow-0.4x.gif` |
| Rare item reveal on PC, moving | `sequences/pc-item-rare-jelly-slow-0.4x.gif` |
| The three rarity sounds in a row | `audio/common-then-uncommon-then-rare.mp3` |

## What changed

**Pets (H1).** The Smash-style screen is back: black stage, spotlight, silhouette, colour burst, slanted headline, name plate with popping letters, confetti popper, drag to spin, Back / Meet. The egg opening Codex built is the lead-in on that same stage: the egg wobbles and cracks in a narrow spotlight, the shell opens with a flash, and the silhouette rises as the shells clear. The first-friend flow is unchanged (B is Back).

**Items (H2, H5): Toy, Hue, Material, Feature.** A new full-screen reveal:

1. the screen dims to a dark stage
2. the egg wobbles while a rarity-coloured glow and beam build
3. the shell bursts: flash, expanding rings, rays, shards
4. the item pops onto a card that flips in, then flies to the left
5. the name slams in over a coloured streak, under a rarity banner
6. it ends on the game's own receipt buttons (Use now / Store / Keep, or Give to Bear / Store for the first toy)

The old "Squeaky Carrot unlocked!" card is gone from view; its buttons are the ones on the reveal.

**Rarity (H3).** Each tier has its own look and its own sound line.

| | Common (and untiered) | Uncommon | Rare |
|---|---|---|---|
| Colour | soft cream-white | green | blue-violet |
| Rays / shards / rings | 6 / 10 / 1 | 10 / 18 / 1 | 16 / 30 / 2 |
| Sparkles around the card | none | 6 | 12 |
| Sound | 3 notes: wobble, crack, slam | 5 notes: two rising notes, shimmer, slam, chime | 9 notes: four rising notes over an octave, whoosh, higher shimmer, fanfare, slam, long rising total |

Only existing uploaded sounds, varied by pitch, gain and layering. No new uploads. Nothing AI-generated, in art or audio. The loudness check and its limits are in `audio/LOUDNESS.md`.

**Reduced Motion.** One 150 ms fade to the settled screen: no wobble, burst, confetti or sound line. Reopening a saved receipt also starts settled and silent.

## Decisions I made that Spencer may want to reverse

- **The pet no longer hops and waves out of the egg.** That animation belonged to the plain screen. On the Smash stage the pet rises as a silhouette, spins in and strikes its greeting pose, as it did before Codex's rebuild. The hop and wave code is still there, unused for pets.
- **Receipts unlock sooner.** Pets: 2.65 s to 2.05 s. Items: 2.2 s to 1.65 s. The buttons now arrive with the name slam instead of after a pause. The 4.4 s and 3.1 s hatch sounds are unchanged and play out under the settled screen.
- **The item stage is fully dark, not a see-through dim.** At 90% and 96% dim the old receipt card and the garden ghosted through; `real-flow/` shows the final opaque version.
- **The item reveal also shows when a saved receipt is reopened** (settled, no animation), so there is one receipt look.
- **Toys and Hue jars say "NEW TOY" / "NEW COLOUR JAR"** and use the Common look and sound, because they have no authored rarity. I did not invent tiers for them.

## What is real and what is a fixture

**Time-stepped frames (`frames/`, `sheets/`, `sequences/`).** `scripts/RevealCaptureFixture.lua` runs the real `HatchCinematic`, `HatchDisplayScene`, `RevealStage`, `HueItemReveal` and `HatchItemStage` in Studio Play on synthetic results (no purchase, save or sound) and advances their real step functions in fixed 1/30 s steps, so each frame is at an exact time. The item receipt buttons are stand-ins for `HueEggView`'s. The GIFs are those frames held for their real gaps: 13 frames over 3.2 s, so they show the beats, not smooth motion.

**Real game flow (`real-flow/`).** A fresh Studio save, five real drops to earn the Bear, then a real Toy Egg bought with Stars:

- `real-first-bear-hatch-waiting-unfocused.jpg`: the real `EggHatchView` opened the Smash stage, full screen, with the egg in the spotlight.
- `real-toy-egg-purchase-waiting-unfocused.jpg`: the real `HueEggView` opened the item stage, full screen. Read back from the live GUI: tier Neutral, name still hidden, and the stage's buttons mirror the host's real ones ("Give to Bear" as the main button, "Store").

**Both are frozen on the egg**, because Studio was not the focused window and the hatch clock only runs with focus. I tried to click Studio into focus and the click was cancelled, so I did not try again. **The live animation and the live button presses in the real game are therefore not captured and not verified.** The Bear's reveal was acknowledged over the remote to move on, not by pressing Meet.

Sizes captured: phone 812x354 (13 frames each: pet, Common, Rare, untiered toy), phone 844x390 (settled pet, Common and Rare, plus the Rare burst), PC 1649x734 (the Studio viewport: 6 pet frames, 5 Common, 5 Rare), Reduced Motion and a saved-receipt reopen at 780x360. Portrait was laid out and spec-checked at 390x844 but not captured. **No physical phone.**

## Verified

- **16 hatch suites, 93 cases pass** in Studio Play on the final code: HatchItemStage 9 (new), RevealStage 14, HueEggView 15, HatchCinematic 10, UICopy 8, HatchRarityCue 7, HueItemReveal 5, HatchRarityAudio 4, HatchDisclosure 4, HatchDisplayPose 4, HatchIdentity 3, HatchAudioDuck 3, HatchNativeHost 3, HatchNativeItemFit 2, HatchNativeCinematic 1, HatchNativeFrustum 1.
- Specs I rewrote because I changed what they assumed: HatchRarityCue, HatchRarityAudio, HatchDisplayPose, HatchNativeCinematic, HatchDisclosure, RevealStage (lead-in case added). HatchDisclosure now also checks the item stage shows no name and no rarity word before the receipt beat.
- `init.client.lua` is untouched: still 219 column-0 locals.
- Saves untouched: no server file changed.
- Every tier sound is loaded in the client, and its length matches the local WAV used for the loudness model.

## Not done, or not clean

- **`HatchActions` spec fails (1 suite), and it failed before this work.** Its first case presses Meet in the same instant the hatch opens; since Codex's native rebuild that press is taken as a skip. I confirmed this by reading the code path (my change to `HatchCinematic` is audio-only), not by re-running the old commit. The spec needs updating; I left it.
- **`UICopy` spec was failing before this work** on `hub.chip.book` and `hub.chip.quests` placeholders. I filled its sample table, so it passes now.
- **Uncommon cannot be seen or heard in the game today.** Only Feature eggs have an Uncommon item and they are behind a flag that is off. Uncommon is covered by specs and the audio mix only; there is no Uncommon capture.
- **Hue and Feature reveals were not captured**, only Material and Toy. They use the same stage.
- **Controller focus on the item stage is not tested by hand.** The host still owns focus on its hidden buttons and the stage draws a ring on the matching button. A spec covers the mirrored text and enabled state; the ring is not covered, and nobody has used a gamepad on it.
- **The first-toy coach** points at the host's receipt button, which now sits under the stage. Not checked.
- **Translations not synced.** Eleven new strings are in `UICopy` (`hatch.reveal.*`: COMMON, UNCOMMON, RARE, the item kinds, "NEW {kind}", Close). Run the export and sync before the next publish.
- Seen while driving the real flow, not mine and not fixed: the Hatch eggs page drew its egg list over the egg detail (`real-flow/real-hatch-eggs-shop-before-toy-hatch.jpg`). It opened right after I acknowledged the Bear over the remote, so it may be an artefact of that.
- `HatchReceiptStage.lua` (Codex's plain pet screen) is no longer used. Not deleted.

## Files

- New: `src/client/HatchItemStage.lua`, `scripts/HatchItemStage.spec.lua`, `scripts/RevealCaptureFixture.lua`
- Changed: `src/client/RevealStage.lua` (egg lead-in), `HatchRarityCue.lua` (looks and sound lines), `HatchDisplayPose.lua` (ready times), `HatchDisplayScene.lua` (bare stage), `HatchCinematic.lua` (plays every due note), `HueItemReveal.lua` and `HueEggView.lua` (open the stage, lend it the receipt buttons), `src/shared/UICopy.lua`
- This folder: `build_evidence.py` is the script that cut the frames, sheets and GIFs from the raw Studio captures. It is kept as a record: the raw captures lived in a session folder and were not kept, so it cannot be re-run. `audio/mix_rarity_audition.py` rebuilds the audio from `assets/audio` and can be re-run.
