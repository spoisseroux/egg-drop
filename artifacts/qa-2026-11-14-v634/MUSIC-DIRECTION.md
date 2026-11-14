# Original garden / Pocket Deck music pair

2026-11-14 · Astra composition brief for Sol synthesis. **Supersedes all previous music direction.** User asks for the pleasant, playful garden feeling associated with SA2 Battle's Chao/Hero gardens, with a different retro Pocket Deck treatment of our same tune/harmony. Borrow only broad mood: airy, gentle, slightly playful, comfortable to repeat. No copying, transcribing, sampling or soundalike recreation of those melodies/recordings. The notes below are a new original starting composition.

## Shared composition: “Little Afternoon”

F major,4/4,96 BPM. One16-bar phrase =40s; full loop32 bars =80s. Straight eighth grid with very light human timing ±8ms on garden accompaniment only; melody remains clear. All octaves scientific pitch (middle C=C4). Durations below are beats and sum4 per bar. `r` is rest. Compose exactly this melody first; make texture breathe rather than filling every silence.

| Bar | Harmony | Melody note(duration) |
|---|---|---|
| 1 | F6/9 | r(.5) A4(.5) C5(1) D5(.5) C5(.5) A4(1) |
| 2 | Dm7 | F5(1.5) E5(.5) D5(1) r(1) |
| 3 | Gm9 | Bb4(.5) D5(.5) A5(1) G5(.5) F5(.5) D5(1) |
| 4 | C6/9 | E5(1) D5(.5) C5(.5) G4(1) r(1) |
| 5 | Bbmaj7 | D5(1) F5(.5) E5(.5) D5(1) A4(1) |
| 6 | F/A | C5(.5) A4(.5) G4(1) A4(.5) C5(.5) F5(1) |
| 7 | Gm7 | D5(1.5) Bb4(.5) A4(.5) G4(.5) r(1) |
| 8 | C7sus → C7 (2 beats each) | G4(.5) C5(.5) D5(1) E5(1) r(1) |
| 9 | Dm9 | A4(.5) D5(1) F5(.5) E5(.5) D5(.5) C5(1) |
| 10 | Am7 | E5(1) C5(1) B4(.5) C5(.5) A4(1) |
| 11 | Bb6 | F5(.5) D5(.5) C5(.5) D5(.5) G5(1) F5(1) |
| 12 | Cadd9 | E5(1.5) D5(.5) G4(1) r(1) |
| 13 | Gm7 | Bb4(.5) D5(.5) F5(1) D5(.5) Bb4(.5) A4(1) |
| 14 | C7 | G4(1) E5(.5) D5(.5) C5(1) Bb4(1) |
| 15 | F6 | A4(.5) C5(.5) D5(1) C5(.5) A4(.5) G4(1) |
| 16 | C7sus | G4(1) C5(1) r(2) |

Bars17–32 repeat harmony/melody exactly, with accompaniment variation and the answer instrument taking bars21–24. Bar32 keeps its final2-beat rest to let the phrase breathe into bar1's half-beat rest. Do not add a big ending cadence or fade at the loop boundary.

Chord voicings (garden, soft midrange): F6/9=[F3,A3,C4,D4,G4]; Dm7=[D3,A3,C4,F4]; Gm9=[G3,Bb3,D4,F4,A4]; C6/9=[C3,G3,A3,D4,E4]; Bbmaj7=[Bb2,F3,A3,D4]; F/A=[A2,F3,A3,C4]; Gm7=[G2,F3,Bb3,D4]; C7sus=[C3,G3,Bb3,F4]; C7=[C3,G3,Bb3,E4]; Dm9=[D3,A3,C4,E4,F4]; Am7=[A2,G3,C4,E4]; Bb6=[Bb2,F3,G3,D4]; Cadd9=[C3,G3,D4,E4]; F6=[F3,A3,C4,D4]. Trim duplicative upper chord tones while melody plays in that register.

## Garden arrangement

- Lead is a **soft wooden marimba/plucked mallet**, not a sharp digital sine ping. Synthesize fundamental + subdued2nd/3rd partials, 8ms rounded attack,180–450ms decay scaled by note length, lowpass around4.5kHz, no hard clipping. Melodic velocity .60–.78, phrase accents on the longer notes. Avoid identical note gain throughout.
- Answer is a breathy soft flute/ocarina-like synth on bars5–8 and21–24, lead marimba rests there. Mostly sine with low-level filtered breath noise; attack35ms, release80ms, subtle3.5Hz pitch motion <5 cents starting late. No piercing high chirp/vibrato on every note.
- Accompaniment: nylon/harp-like plucks on chord tones at beats0,.75,1.5,2.5 (bar1,3,etc); gentler dyads on0 and2 in alternating bars. Select root/third/fifth/sixth with good voice leading; no full chord arpeggio machine at every sixteenth.
- Rounded bass root on beat0 (1.25 beats), fifth on beat2.5 (.75 beat), occasional third approach on beat3.5 (.5beat) only every fourth bar. Keep fundamental above45Hz, little sub energy. Soft brush/shaker on offbeat eighths at very low level, a muted wooden tap on beats1 and3 every second bar. No heavy kick/snare.
- Warm airy sustained pad only on bars9–12 and25–28, very quiet. Sparse bell droplets once every4 bars maximum; no birds/water samples baked into music because world ambience already owns those.
- Small room reverb, ~.8s decay,8–12% wet. Mild stereo spread ±20%; centered melody/bass survives phone mono. Arrangement should feel leisurely and cheerful, not sleepy, solemn, saccharine or a frantic arcade loop.

## Pocket Deck arrangement

Same key,96 BPM,80s structure, exact principal melody and harmonic changes. Different timbres/rhythm make it feel like the toy handheld playing our garden tune.

- Lead band-limited pulse at25% duty blended with triangle (pulse .35, triangle .65), attack6ms, release45ms. Lowpass5kHz; no harsh unfiltered square peaks. Keep melody in the written octave; optional quieter octave echo only on sustained notes.
- Triangle bass with same roots/fifths, shorter90–140ms notes. Chord accompaniment alternates two soft pulse voices on offbeats, occasional eighth-note chord-tone run at phrase ends; no constant sixteenth arpeggio. Very quiet shaped-noise hat at eighths and soft noise snare on2/4, with rounded synthesized kick on1/3.
- Dry/tiny-room sound (3–5% wet), narrower stereo. Raise rhythmic energy through articulation, not loudness or tempo. Avoid quoting recognizable console jingles. Use the original first-bar A4–C5–D5–C5–A4 motif for tiny UI confirmations only when it won't compete with music.
- During reveal/menus: preserve mute/music volume; duck active music for reward audio rather than playing two full tracks. Switch garden↔deck through180–300ms equal-power fade. If both share transport, preserve bar phase; otherwise crossfade without a loud overlapping downbeat.

## Sol preview/export requirements

Synthesize **both original80s loops now** into local WAV artifacts,48kHz stereo, plus20s comparison excerpts and a simple filename/title report. No external recordings or generated-music services. Print duration/peak/RMS or integrated loudness if tooling supports it; target ~−20LUFS garden and ~−19LUFS deck, true/sample peak ≤−1dBFS. Loudness-match preview excerpts within1dB so arrangement preference is fair. These are mix targets, not permission to squash dynamics.

Make loops genuinely seamless: render reverb tails into a cyclic buffer or fold the final tail into the opening at matching phase, without a click or silence gap. Audition end→start twice and mono fold-down; ensure no clipped samples, DC step, harsh note onset or overly repetitive high percussion. Provide a short seam-check excerpt containing last4s + first4s twice. Astra listens/reviews before installation. Keep prior audio until approved replacement is concretely auditionable; no publish in this task.
