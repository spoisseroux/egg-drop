# Music v3 — sparse, strange little garden sounds

Spencer rejected the104-BPM preview: “too full,” “too much like forefront midi,” and missing weird samples. **The prior two arrangements are rejected for integration. Stop their production wiring/uploads.** Keep hatch animation work moving independently. This brief supersedes the104-BPM arrangement in `HATCH-MUSIC-REVISION.md` and the earlier full music direction. Make **one24-second audition**, not an A/B menu or another finished80-second track.

## What to make

A mostly quiet little garden sound collage with original, tactile, slightly odd one-shots. The tune should feel like something glimpsed behind the scene, not a lead instrument playing at the listener. No drum kit, bass ostinato, continuous arpeggio, flute lead, seven-voice MIDI arrangement or constant bell notes. Maximum two prominent events at once; never fill every rest. Leave at least65% of the timeline without a new foreground attack.

Create a real local **one-shot WAV bank first**, then sequence/resample those files with variation. Use the coordinator's incoming CC0 rubber-toy and bubble recordings as the primary character; supplement only the hollow knock/rattle with original synthesis if needed. Do not copy or sample Sonic audio. Label source recordings versus original synthetic additions honestly.

## Authorized recording sources and handoff

**Paused checkpoint:** Spencer pressed Escape to stop computer use and the coordinator is ending the turn. The CC0 source URLs were verified by the coordinator, but recordings have **not** been downloaded. No v3 audition exists yet; no native tightened-hatch or Jelly-v2 visual GO is implied. All seven earlier104-BPM loop/burst uploads remain unused and on HOLD. Resume with actual recorded-foley acquisition/provenance and a short audition before integration. No publish.

Coordinator verified the source pages as CC0; acquisition with provenance remains pending: [Squeak toy sounds](https://opengameart.org/content/squeak-toy-sounds) and [Bubble sound effects](https://opengameart.org/content/bubble-sound-effects). My web fetch was restricted, so that license verification is attributed to the coordinator, not a new independent check. Use the local files/provenance manifest the coordinator supplies on resume; retain original author, source URL, license and source filename in the final manifest even where attribution is not required. Do not use the login-gated Freesound candidate or describe these third-party recordings as our own recorded foley.

Prefer one isolated clean squeak and two contrasting little bubble/plop events. Trim silence with8–15ms boundary fades while retaining the natural attack. Keep each recognizable: maximum±3 semitones resampling, no continuous looping. One secondary squeak can use a brief60–90ms grain at−12dB relative to its main sample, delayed120–180ms; do not granularize the whole bed. Main squeak at7.2s, a short softer variant can replace the chirplet at16.7s. Bubble samples occupy3.1,14.4 and22.6s, with different source excerpts. Source audio without voices is the intended input; reject any slice containing speech rather than burying it in the mix.

One quiet rounded F2 bass pluck at9.3s may replace that scheduled low knock; another C3 at20.4s may sit beneath the knock at least12dB lower. No bass pulse between these events. Sample-led, not melody-led. Keep the small-room .45–.65s decay, pre-delay12–18ms, wet roughly12–16% on squeak/plops; bed is very quiet and does not become a reverb wash. At least1.5 seconds without a new foreground sound between most gestures. No more than two clearly audible foreground layers.

**Implementation ownership:** new music files/tooling under the assigned v3 lane only; coordinate exact script ownership with the primary agent. Do not edit the concurrently changing hatch/native reveal or other audio-owner files simply to generate this audition. All v3 audition artifacts go under `audio/revision-3-sparse/`; rejected104-BPM outputs remain unchanged for history.

## Sample bank and synthetic fallback recipes

Use actual source recordings for the water-plop and rubber-squeak rows. The synthesis recipes below are fallback experiments only if the licensed recordings are unusable, not a reason to substitute MIDI-like tones for the newly available recordings. Render synthetic additions at48kHz with a deterministic seed; each source variant remains documented. These are starting physical/spectral recipes, not a promise of a convincing sound without audition.

| File family | Starting sound design | Duration / character |
|---|---|---|
| `hollow-knock` | A2–4ms noise impulse exciting **inharmonic** resonances near620,1040,1730Hz with different45/90/35ms decays; add low wooden body near180Hz with70ms decay. Rounded onset, soft saturation; no equal-tempered note assignment. | .12–.22s. Small hollow object, not a xylophone key. |
| `water-plop` | Two damped nonlinear chirps: core330→110Hz over55ms; weaker bubble850→240Hz over95ms, tiny delayed second bubble after70ms; damped filtered-noise contact at onset. Vary pitch curves and bubble spacing, not just sample playback pitch. | .18–.32s. Small wet, rounded plop, no laser zap or kick. |
| `rubber-squeak` | Soft friction-noise burst through two moving resonances800→1400→950Hz and2100→1700Hz, slightly irregular amplitude, quiet subharmonic body; no sustained saw/square oscillator. Round edges8–15ms. | .16–.28s. Tiny toy squeak, not a whistle solo. |
| `wordless-chirplet` | Short breath/noise excitation plus a subdued harmonic core, formant-like resonances shift gently; two unequal lobes separated35ms, with a small pitch inflection. Keep it nonverbal and abstract, no simulated syllable or recognizable character voice. | .22–.40s. One curious little chirrup, used once. |
| `soft-rattle` | Three to five tiny irregular ceramic/wood ticks over180ms, each different level and resonance; roll off above5kHz. | .18–.25s. A little object settling, not shaker percussion. |

Render sources to WAV; sequence those actual files. Per hit, vary start offset by0–4ms, gain by±1.5dB, playback speed by≤8%, and pan by≤12%. Do not make a “sample bank” consisting of the old melodic sine/pulse instruments renamed as foley. Inspect envelopes for click-free edges, but do not remove the little noisy resonant character. Use a small shared room, early reflections at roughly23/41/67ms and a quiet .45–.65s tail; no huge ambient wash. Avoid artificial stereo tricks that disappear on phone mono.

## One24-second audition schedule

Loose feel, no audible metronome or forced104-BPM grid. Times are starting points, not a demand to quantize natural tails.

| Seconds | Event |
|---|---|
| 0–1.8 | Quiet opening. Very soft airy F3/C4 dyad fades in over1.2s, already well behind the scene. |
| 1.8 | One hollow knock, slightly left. |
| 3.1 | One small plop, slightly right. |
| 5.5 | One soft rattle; leave the following space empty. |
| 7.2 | One rubber squeak, restrained. Dyad fades out by8.0. |
| 9.3 | One low hollow-knock variant. |
| 11.6–12.9 | **Only melodic fragment:** original A4(.25s)–C5(.35s)–D5(.40s), soft distant plucked tone about12dB quieter than the principal one-shot peaks. No answering counter-melody. |
| 14.4 | One small plop, different source variant. |
| 16.7 | One wordless chirplet, then silence. |
| 18.8 | F3/C4 airy dyad returns very quietly, fades by22.0. |
| 20.4 | Hollow knock + one tiny secondary tick after.13s. |
| 22.6 | Quiet plop variant; tail decays naturally across the end. |

The bed must be barely there: no bright attack, no lush chord stack and no continuous broadband hiss. Do not add the earlier bass, flute, drums or full16-bar melody underneath “to complete it.” The sparse sounds are the point.

## Mix and delivery

Starting peak hierarchy: main one-shots about−12dBFS, chirplet/squeak a little quieter, hidden motif around−26dBFS, bed around−38dBFS RMS. Keep true peak below−3dBTP. **Do not normalize this sparse passage up to the old−20LUFS target if it makes every little sound loud.** Report actual level instead. Supply stereo and honest(L+R)/2 mono, plus a sound-bank strip with gaps so Spencer can hear what the samples are. Keep hiss/clicks under control without flattening the character.

Deliver `audio/revision-3-sparse/garden-texture-audition-24s.wav`, `garden-texture-audition-mono-24s.wav`, individual edited sample WAVs and their provenance/source recipe/seed list. Also make a short playable preview artifact if needed by the interface. This is an audition, not an installed loop. No deck arrangement yet: once this garden character is accepted, translate the **same tiny original motif and event spacing** into a sparse handheld treatment instead of reviving the rejected busy deck tune.

I have not heard the previous or new files and cannot certify subjective sound quality from filenames or measurements. Spencer's actual audition decides whether this is sufficiently airy, odd and pleasant. The final long loop and its seam/mute/duck tests follow a successful short audition; no old rejected uploads count as the approved replacement.
