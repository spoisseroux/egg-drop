# Astra preview review — 14 November 2026

## Final native200-pixel items — visual GO

Actually inspected `hatch-production/native-final-200px-items.png`. Both Wobble Top and Ball now read large and clear at the actual200×200 receipt size. Their displayed115-pixel height occupies57.5% of the cell, the contact point sits near80% height, and the silhouettes, colour detail and floor contact are plainly visible with room above/beside the objects. **Visual GO; no further item-sizing or floor change requested.** This closes the45-pixel sizing issue below. Coordinator reports strict item upper-bound/full-motion/whole-egg fit tests passing; the screenshot itself proves the settled visual result, not every motion frame.

## Corrected native floor / actual receipt-size items

Inspected `hatch-production/native-item-receipt-size.png`, showing two actual200×200 native Scene cells with Wobble Top and Ball settled at3.1s. **Floor correction GO:** exposed side edges are gone; the faint residual Lambert horizon is acceptable in this view and no longer warrants a stage redesign. This closes the finite-floor issue identified below for the corrected item scene.

**Item size needs one bounded increase:** approximately45-pixel toys use only22% of the cell. Target110–120pixels longest projected dimension, with70% width/height maximum and full egg/motion fit preserved. Exact generic normalization/camera starting points are in `HATCH-TIMING-POLISH.md` under Native200-pixel receipt sizing. Keep the same Scene/clock during receipt borrowing, keep the accepted Bear fit, and do not scale2D fruit art with the3D multiplier. Recheck the two200-pixel cells after this adjustment.

## Current tightened native hatch — one bounded stage correction

Actually inspected `hatch-production/native-v3-bear-120.png`, `native-v3-bear-214.png`, `native-v3-bear-265.png` and `native-v3-toy-155.png`. These are isolated native scene captures without receipt chrome and use runtime Original neutral Bear, not the golden Blender source. The actual toy shown is the coral Ball, not Wobble Top.

**Hero motion/framing GO in the supplied frames:** Bear's head, feet and airborne pose remain within the image; the entrance is above the floor, the later smile/large eyes read clearly, and no shell crosses the payload. The Ball silhouette and stripe detail are clear. No new animation redesign is needed. At1.20s the brief partial-opacity entrance reveals overlapping feet/body layers, as expected during a short fade; it is not the former below-floor emergence.

**One required stage fix:** the floor appears as a finite rectangular panel with its right edge ending aroundx572 inside the604-pixel image. Its hard horizon line crosses Bear's face at1.20s and the Ball's upper body at1.55s. Extend the stage floor beyond the swept camera frustum so no side edge is exposed, and match/blend floor and backdrop tones so that this line does not bisect the hero. Preserve the fixed camera, hero size, cream light pool and accepted timing. A corrected native Bear and item image is sufficient to close this specific issue; no new creative permission gate.

The current native timing reported by the coordinator is4.4s pet /3.1s item, cap gone1.10 and lower halves1.18. That supersedes the earlier1.55 shell deadline; do not restore the slower lingering shells. Swept-frustum tests and source timing reports are separate engineering evidence, while the statements above are direct image observations. Receipt chrome, sound and full temporal playback were not visible/audible in these four stills.

## Final revision 2 correction — GO to present

Re-inspected the updated actual `hatch-concept/revision-2/bear-expression-strip.png`, `hatch-six-frame-storyboard-stills.png`, `toy-settled-812x354.png` and `existing-item-contact-strip.png` after Sol's final correction. **GO to show Spencer this revised idea; no remaining visual blocker in these inspected images.** This closes the face/toy requests in the earlier revision-2 review below.

Bear now retains its appealing large eyes and original smile through the hop and settled head tilt. The dark O substitute is gone. Blink remains visibly distinct, the airborne gap is clear, and the entrance is above the floor. The toy's final lower tip reads in contact with its compact shadow; its shape and receipt are clear at812×354 without the misleading tiny Bear companion. Existing-item contact sheet correctly distinguishes Toy/Hue/Material Egg outcomes from Sun Hat direct purchase and the faceplate/background paths; the material comparison is explicitly a source-based equivalent, not native material proof. The Rose fruit panel is current flat item art, so it should not be described as a completed new3D fruit reveal.

This is approval to **present the concept**, not Spencer's acceptance or permission to bypass his requested hatch-idea checkpoint. MP4 timing/floor sampling and sound measurements are reported engineering evidence; I inspected still images and have not heard the cues or104-BPM music. User audition and the separate code review remain distinct. Jelly has no visual verdict until its actual capture arrives.

## Revision 2 actual image review

Spencer subsequently accepted the stage/shell direction in principle and requested a new entrance, expression and quirkier music. This review supersedes the original motion findings below where noted. Actual inspected files: `hatch-concept/revision-2/bear-expression-strip.png`, `hatch-concept/revision-2/hatch-six-frame-storyboard-stills.png`, `hatch-concept/revision-2/toy-stills/frame-005.png`, and `studio-toy-shop-current.png`.

**GO on the entrance and staging corrections.** At1.75s Bear is visibly grounded above the floor during the fade; at2.67s the feet are clearly airborne with a separated floor shadow. The full eye-mesh blink is visible at1.95s, and shell pieces are clear by the hop/receipt. The toy-only shot removes the misleading miniature Bear comparison. These are actual still observations; the completed MP4 still needs playback for pacing and sound synchronization.

**Face refinement required before calling it excited/happy:** in the expression strip, the labelled Joy combines very compressed small eyes with a dark round O mouth. It reads surprised/woozy more than delighted. The settled Pleased eyes also lose too much of Bear's characteristic large-eyed appeal. Keep eyes at .85–1.0 of the neutral shape during the hop and settled pose, use the original smiling mouth rather than the isolated O substitute, and reserve full eye compression for the short blink. Let the clear hop, head tilt, wave and existing perked ears carry the excitement. No new face artwork is required. The strip honestly labels its isolated mesh equivalent; it is not a proof of native runtime expressions.

The toy remains recognizable and unobstructed. Its lower tip in `toy-stills/frame-005.png` reads a little suspended above the contact shadow; the final hold should place the tip firmly on the pool with a compact shadow. Do not expand scope into new toy geometry.

The actual **desktop** shop screenshot has readable cards, price/odds, purchase action and footer with no obvious outer clipping. However, faint redundant corner arcs are visible at the inner right-panel corners, and the egg display contains **Retry preview**. Remove duplicate decorative corner strokes if not already addressed by the newer Moonpond/frame fix; retain one clean rounded panel boundary. This older screenshot cannot certify the newer fix, phone fit or successful asset readiness.

The new104-BPM audio lives in `audio/revision-104bpm/`. It has not been heard by this reviewer; Spencer's audition remains necessary. Jelly material renders/native captures were not yet supplied at this review and have no creative visual approval.

**Hatch: GO to show Spencer the idea. Production approval remains pending.** This is a readable, useful concept animatic, with specific animation refinements below. It is not approval to replace `HatchCinematic` or `RevealStage`: Spencer explicitly asked to see and approve the idea first. Other already authorized QA work can continue.

**Music: GO for user audition on the supplied technical evidence; subjective listening remains for Spencer.** I have no available auditory inspection capability in this review and have not heard the WAVs. File metrics cannot establish whether the melody, timbre, repetition or transition feels pleasant.

## Evidence actually inspected

Paths below are relative to `artifacts/qa-2026-11-14-v634/`.

- `hatch-concept/hatch-six-frame-storyboard.png`: egg presentation, rocking, crack, peek, greeting and settled receipt.
- `hatch-concept/bear-settled-812x354.png` and `toy-settled-812x354.png`, at actual phone raster size.
- Additional actual rendered sequence frames: `hatch-concept/bear-phone/frame-031.png`, `frame-038.png`, `frame-042.png`, `frame-046.png`; `hatch-concept/toy-phone/frame-025.png`, `frame-035.png`. These establish the emerging body, shell relationship and wave. This was a frame-sequence review, not a real-time playback assessment of smoothness or sound synchronization.
- `hatch-concept/README.md`, `audio/README.md` and the opening metadata/score of `audio/music-report.json`. Duration, seam, mono and loudness checks below are the synthesis pipeline's reported measurements, not independent auditory verification.

The actual motion artifacts to show are `hatch-concept/bear-hatch-concept.mp4` / `.gif` (6 seconds) and `hatch-concept/toy-hatch-concept.mp4` / `.gif` (4 seconds). Both are 812×354, 12-fps concept animatics.

## Hatch visual findings

| Requirement | Actual result | Direction for an approved production pass |
|---|---|---|
| Match the 3D egg-shop feeling | Patterned, dimensional eggs, dark teal surroundings and a warm pool of light form a coherent display stage. This is the right family for the existing shop rather than the flat receipt in QA. | Keep the existing shop's actual egg materials and this restrained teal/cream stage; do not add a second ornamental frame. |
| Anticipation and crack | Rocking and the warm zigzag crack are legible in the storyboard. Cap lift makes opening unambiguous. | Preserve a short held anticipation beat and a clear crack beat. Check synchronized crack/pop cues during actual playback. |
| Excited Bear | The emerging body and raised hand read; the familiar Bear is recognizable. The face remains wide-eyed and calm, and the sampled body poses do not strongly sell an exuberant leap. | Add a quick crouch, unmistakable airborne gap with ground shadow, soft landing, 8–12° head tilt and two small waves. Use existing expression capability for a happy blink/smile if supported; do not remodel Bear. Excitement needs readable pose changes, not more particles. |
| Shell staging | At Bear frames 31–42 the cap sits just above/behind the head and lower pieces flank the body. In toy frame 35 the cap overlaps the top handle silhouette. | Move the cap outward and fade it before the main greeting/object hold. Slide lower halves clear of the feet/toy. The settled payload must have an unobstructed silhouette. This is a concrete refinement, not a reason to withhold the current idea from Spencer. |
| Item reveal and scale | Wobble Top is identifiable as a separate dimensional toy. The settled frame gives it strong visual priority and includes a tiny Bear for charm. | Retain the object-first composition. The tiny Bear is illustrative, not a literal relative-scale claim: if keeping both in production, use their real in-world relative scale or omit the secondary Bear. Do not imply the actual toy is several times Bear's height. |
| Phone readability | Bear/Wobble Top names, short descriptions and 48-pixel actions are readable at 812×354. The reserved upper band and left-stage/right-receipt split leave enough room. | Preserve the button sizes and split. Localized longer names/copy need a separate runtime fit check. Do not carry the concept-only safe-band badge or disclaimer into the actual game. |
| Copy and reveal pacing | The early generic paragraph competes with the egg; the title fades in quite faintly around Bear frame 42 before becoming readable. | Early stage can use only “Something's stirring…”; reveal “Bear” or the item name promptly after recognition. Keep all enabled actions fully legible; a low-opacity transitional label must not look like disabled UI. |

The concept's raised-hand moment is enough to discuss the intended welcome with Spencer. It should not be described as finished expressive character animation. Static review also does not certify layering through every tween, reduced-motion behavior, input ownership, receipt correctness or asset readiness.

## Music audition packet

Show the exact matched excerpts:

- `audio/little-afternoon-garden-20s.wav`
- `audio/little-afternoon-pocket-deck-20s.wav`

Both arrangements implement the same original F-major, 96-BPM theme. The provided report records 32 bars / 80 seconds, 48-kHz stereo PCM. Reported full-loop levels are garden −20.00 LUFS / −8.61 dBTP and deck −19.00 LUFS / −7.00 dBTP; the two audition excerpts are level-matched at −20.00 / −20.01 LUFS. Reported mono energy loss is negligible (−0.0048 / −0.0004 dB), with zero clipped samples and cyclic-tail boundary checks. Those support an intact, comparable audition packet, not a claim of an inaudible seam or a pleasing mix.

Also available: `audio/little-afternoon-garden-seam-last4-first4-twice.wav` and `audio/little-afternoon-pocket-deck-seam-last4-first4-twice.wav` (16 seconds each), plus the matching `*-mono-20s.wav` files. Spencer should hear the excerpts first, then a full loop to judge fatigue and the seam auditions for a perceptible join. Listen especially for whether the garden mallet/flute feels soft and playful, whether the deck pulse retains the tune without becoming piercing, and whether either rhythm distracts from garden play. These are listening questions, not observed faults.

No request to replace the composition based on metrics alone. Keep the shared tune/harmony; adjust timbre or balance only from actual listening feedback. Existing runtime music IDs remain unchanged in this preview packet, per its README.

## Handoff

Present the two motion previews, the settled frames and the two audio excerpts now. Ask for the hatch **idea** decision before production hatch/reveal changes. The shell clearance, stronger happy body language and literal toy-scale treatment above are refinements for the accepted direction. Do not present this review as Spencer's approval or as a live-game verification. All alien/Blip concepts remain parked and are outside this review.
