# Revised hatch and music direction — Astra, 14 November 2026

Spencer likes the stage/shell direction in principle. He rejected the apparent ground-clipping entrance and absent eye expression, asks for a scale/fade entrance and more natural animation, wants to see item outcomes and hear exciting sound. **Revise the actual preview before production Bear hatch implementation.** This updates `HATCH-IDEA.md`; it does not authorize production hatch changes before the revised idea is shown. Other authorized QA work continues.

## Bear: six-second revised preview

Retain the current fixed camera, teal/cream stage, authored egg, phone layout and shell materials. Define H as final Bear height. At every pose, calculate the transformed minimum foot/mesh height and place it at floor + 0.005H + the explicit hop offset. Scale about the planted-foot anchor, never the model origin. No mesh point may start beneath the floor. Keep the light-pool plane from intersecting the toes.

| Seconds | Required visible motion / face | Sound cue |
|---|---|---|
| 0–0.65 | Egg holds, then two small unequal rocks: −5°, +8°, back to 0. Bear hidden. | Two rounded wood ticks, second slightly higher; quiet. |
| 0.65–1.25 | Brief held anticipation, zigzag crack grows; egg rocks once by 10° then settles. | Dry shell crack with small pitched glassy overtone; no alarm or blast. |
| 1.25–1.55 | Cap lifts diagonally away; lower halves separate beyond Bear's future foot width. Hide inner core before Bear appears. | Airy upward swish, about 180 ms. |
| 1.55–2.05 | Bear appears **already above the floor**, scale .72 → 1.04 → 1.00, opacity 0 → 1 by 1.82. No rising-from-below translation. Feet remain anchored. Face curious, then blink at 1.95. Head turns about 7° toward viewer. | Soft rubbery “bup” at 1.68, no copied voice sample. |
| 2.05–2.35 | Look at viewer, head tilts 8°; hands come slightly forward. Cap and lower halves move aside and fade completely by 2.30. | Tiny original two-note answer C5→D5, restrained. |
| 2.35–2.95 | Crouch to .92 body height for 120 ms (feet planted), then jump: apex +.11H at 2.66, land by 2.88. Shadow stays on floor and softens at apex. Joy face; subtle 1.04 vertical stretch in air, .94 landing squash, recover. | One rising plucky F5–A5–C6 reward flourish over 300 ms at takeoff, soft low thump at landing. |
| 2.95–3.75 | Two small hand waves at about 3.10 and 3.43, head counter-tilt; joy then pleased face. Name and receipt appear fully readable by 3.15. | Short gentle happy chirrup, synthesized, maximum 250 ms; avoid a second competing jingle. |
| 3.75–6.00 | Comfortable planted idle, pleased → neutral, one natural blink; clear actionable receipt. | Let reward tail breathe; no sound on every idle bob. |

### Real expression capability, not a new face design

`src/client/PetExpression.lua` already defines `curious` (eye 1.16), `joy` (eye .5, mouth open, hand .45, head .05), `pleased` (eye .58, smile) and their tilt/blush values. Use these through the existing visual/rig expression owner; do not create a parallel face clock. `PetFace.lua` explicitly preserves independent face shading and notes that expression/blink owns mark visibility. Check the actual Bear renderer mapping before assuming named poses affect its textured face.

The current Blender preview copies only the 16 basic Bear meshes (`scripts/qa20261114_hatch.py`), so static face geometry is not proof of runtime expression. For the revised concept, either render the real expression-capable rig, or animate eye meshes/highlights and an accurately documented mouth substitute in the isolated preview. Eye whites, pupils and highlights must compress/close together, with no floating circular pupils after a blink. A preview-only mouth must be marked as such; do not claim it is already supported in production. Prefer the actual supported open/smile face if available. Require front-frame comparison of curious, joy and pleased so the change is visible at phone size.

`PetIdleMotion.sample` supplies the existing .15-second blink and `PetIdleMotion.appendages` gives joy/curious a 10° ear perk and joy a quicker tail wag. `GardenPetVisual`/`PetPoseSampler` apply the pose. Use these capabilities for perked ears and a tiny happy tail finish. Do not promise spontaneous blink under Reduced Effects: the current sampler returns a frozen state there. Reduced-motion direction is a brief fade from .92 to1 over150 ms with static happy face; omit hop, squash, rocking and confetti, and respect the existing effect setting. Receipt correctness and skip/cancel remain owned by the existing reveal lifecycle.

## Show what item eggs yield

Produce the revised **Wobble Top** 4-second preview and a contact strip of existing item renderers: Hue fruit, wearable, finish sample, faceplate/background miniature where those egg outcomes exist. Use actual catalog payloads/assets; do not fabricate a new reward or claim an unimplemented egg.

For the toy: 0–1.25 egg rock/crack; 1.25–1.60 shell clears; 1.60–2.05 toy fades/scales .80→1.03→1 about its contact point; 2.05–2.75 one distinctive wobble (±12° diminishing to±3°), small yaw turn to show volume; 2.75–4 settled receipt. **Omit the miniature Bear** in this object-only shot: the prior comparison implied the toy was larger than the pet. Frame the toy at about 60% of available stage height and give it a clear contact shadow. Cap never crosses its handle after recognition. Use the real “Use now”/“Keep” semantics only in the production-approved flow; preview stays explicitly non-live.

Other item treatment: Hue fruit rotates a restrained 15° and settles; wearable appears on a properly scaled Bear bust; finish appears as a labelled before/after Bear; faceplate/background appears on the unchanged Pocket Deck shell. No items emerge from below the floor. Same crack/pop family, then one brief material-appropriate accent (wood toy tap, fruit plop, cloth flutter, finish shimmer). Make the reward distinctive through timing and timbre, not escalating volume or a prolonged rarity fanfare.

Render MP4 **with synchronized original sound** plus silent GIF and stills, so Spencer can actually judge “exciting.” Target the full reward burst at roughly −18 LUFS short-term, true peak ≤−3 dBTP; duck music 6 dB during the cue, recover over600 ms, obey mute. This is a starting mix target, not a listening verdict. I have not heard the previous cue WAVs.

## Music revision: quirkier, lighter, more character

Spencer asks for more of the playful, unusual Hero Garden feeling. Keep our original F-major tune/harmony; no transcription, sampling or matching of Sonic melodies. The current composition can gain personality from irregular phrasing, a rounded bass answer and contrasting toy-like instruments. This supersedes the earlier straight, fairly even arrangement instruction.

- **Tempo104 BPM,4/4,32 bars, about73.846 seconds.** Both garden and deck share this tempo and existing principal note order/chord sequence from `MUSIC-DIRECTION.md`.
- Garden lead: round wooden pluck with a hollow, lightly nasal resonant component (fundamental + second partial at−14dB, third at−22dB; 8ms attack,180–300ms decay, lowpass4kHz). Alternate it with soft flute/ocarina in the existing answer bars. Avoid an uninterrupted pure sine nursery tune.
- Introduce light **56:44 eighth swing** on accompaniment only. Melody keeps clear written durations; shorten every second half-beat note to80% gate to make room for its answer. Strong notes .78 gain, short pickups .55, phrase ends .65. No constant quantized staccato at identical volume.
- Bass becomes a gentle round “bomp”: root at beat0 for.65 beat, fifth at1.75 for.4, root octave at2.5 for.45; leave beat3 empty except every fourth bar, where a quiet approach tone lands at3.5. Sine/triangle blend, fast rounded attack,150–220ms decay. Keep it friendly, not a deep kick.
- Quirky answers only in the melody's existing rests: bar2 beat3 [A4(.25),G4(.25),F4(.5)]; bar4 beat3 [D5(.25),C5(.75)]; bar7 beat3 [Bb4(.25),A4(.25),G4(.5)]; bar8 beat3 [G4(.5),C5(.5)]; bar12 beat3 [E5(.25),D5(.25),C5(.5)]. Play on a quiet rounded toy-reed voice about9dB below lead. Repeat in bars18/20/23/24/28 with one fewer note, never louder.
- Warm chord dyads on offbeats .5 and2.25, alternating bars with sparse harp notes; remove continuous pad except the existing middle phrase. Add one dry hollow woodblock syncopation at beat2.75 in odd bars, alternate with a soft shaker in even bars. No busy drum kit or constant high bell droplets.
- One very short pitch scoop (≤2 semitones,60ms) on the toy-reed answer at bars4 and20 only. It is a playful voice gesture, not a cartoon slide whistle throughout the loop. Leave bar32's two-beat rest intact.
- Pocket Deck keeps this **same tune, tempo, harmony and answer timing**, but changes to rounded band-limited pulse/triangle, narrow stereo and tiny noise taps. Its rhythm can be more precise; do not replace the tune with generic arcade arpeggios.
- Keep prior loudness targets and deliver matched20-second excerpts plus full/seam/mono files. No audio approval is inferred from numbers. Show new audible previews alongside the revised hatch; preserve old files for comparison.

## Preview gate

Request revised Bear/toy MP4s, expression strip and two music excerpts. Astra reviews actual visual frames; Spencer hears the cues/music. Stage is approved in principle, **new Bear motion is still a proposed implementation** until this revised idea is shown and accepted. No publish.
