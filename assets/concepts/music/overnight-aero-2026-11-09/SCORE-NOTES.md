# Two pieces for Egg Drop

These audition scores are original compositions for the garden and the handheld. Every note, rest, chord attack and percussion hit is written in the adjacent JSON scores. The existing Pocket Apricot music remains the default.

## Creek With One Shoe

**92 BPM · 4/4 · D major · 24 bars · 62.608685 seconds at 44.1 kHz.** The piano plays D–F♯–A–B as if a baby were testing the creek stones one foot at a time. The answer comes from lower down and off to the left. In bars 9 through 12 the piano player lifts both hands. The bass carries the crossing and a water glass answers in bar 10. Its second answer in bar 14 lands a fourth higher. At the end of bar 24, let the last little E keep ringing over the return to D6/9.

| Voice | Synthesis and playing direction |
|---|---|
| porcelain_keys | Felt tine. Sine fundamental, 0.23× second partial at 2.002f, 0.055× fourth partial. Attack 11 ms, fundamental decay 0.65 s, upper partial decay 0.14 s, release 0.16 s. Gentle roll already written into each chord. |
| porcelain_lead | Rounder, single-tine cousin. Fundamental, 0.16× second, 0.04× third. Attack 14 ms, decay 0.8 s, release 0.20 s. Keep its attack soft enough for the pluck to sound like a separate player. |
| bulb_bass | Sine with 0.22× second and 0.06× third for small speakers. Attack 18 ms, decay 0.9 s, release 0.12 s. Centered. |
| gumdrop | Left-hand muted pluck. Sine plus a short, gently falling third-harmonic formant. Attack 6 ms, decay 0.19 s, release 0.10 s. A soft wooden consonant and a round vowel. |
| water_glass | Fundamental with a faint 2.70f FM modulator. Modulation index falls from 0.65 to 0 in 50 ms. Attack 7 ms, decay 0.52 s, release 0.36 s. |
| cushion_kick | Sine descends from about 84 to 51 Hz in 35 ms. Attack 6 ms, decay 0.12 s. |
| paper_brush | Seeded noise with most energy between 1 and 3.8 kHz. Attack 8 ms, decay 60 ms. |

Keep the garden room shallow. Feed the opposite channel at 73 ms × 0.09, 117 ms × 0.065 and 201 ms × 0.035. Use circular delay. Preserve the open middle section.

## Pocket Skip

**120 BPM · 4/4 · E major · 24 bars · 48.000 seconds.** The bass gives the player a sixteenth-note foothold, then leaves the end of each second bar to a three-note glass answer. The little left-hand reed calls appear in only six bars. In the middle eight, the bass trades registers while the rim plays once per bar and the chords lose a voice. The final D♯ is a pickup to the low E on the next lap.

| Voice | Synthesis and playing direction |
|---|---|
| thread_bass | Smooth pulse made with sine, 0.30× second, 0.10× third. Attack 13 ms, decay 0.26 s, release 65 ms. Keep each short repeated note distinct. |
| rubber_chord | Damped synthetic mallet. Sine plus 0.27× partial at 2.01f and 0.08× partial at 3.96f. Attack 6 ms, decay 0.18 s, release 90 ms. Lower notes have slightly more body. |
| glass_button | Small bright answer with a strong fundamental and a secondary 2.6f partial at 0.17 level. Attack 6 ms, decay 0.27 s, release 0.14 s. Give it a short soft reflection on the left. |
| reed_button | Hollow synthesized reed. Fundamental, 0.18× third, 0.035× fifth. Attack 19 ms, mild 4.8 Hz amplitude tremolo after the attack, decay 0.38 s, release 0.09 s. |
| button_kick | Pitch descends from 110 to 55 Hz in 26 ms, sine with a little second harmonic, attack 3 ms, decay 95 ms. |
| maple_rim | Two damped sines at 540 and 840 Hz with a short noise tap. Attack 2 ms, decay 30 ms. |
| paper_tick | A 29 ms brushed noise tick with the top rolled off at 5 kHz. The pulse belongs to the bass. |
| spring | A very short pitch bend up about two semitones, with a lightly nasal second harmonic and an 80 ms decay. It marks three interior turns. |

Use a shorter room on the deck. Opposite-channel taps at 49 ms × 0.055 and 94 ms × 0.035. Keep the rim and kick dry.

## Render and review

Each event is an array following the score's named column order. Bar numbers begin at 1 and beat offsets begin at 0. MIDI 60 is C4. The rendered start frame is the nearest integer to `((bar − 1) × 4 + beat) × 60 / BPM × 44100`. Gate is measured in quarter notes, followed by the instrument's release in seconds. The amplitude is linear before equal-power panning. Normalize oscillators consistently and apply one constant stereo gain to the completed piece. The explicit microtiming carries the phrasing. Render the seeded noise in event order.

Render 44,100 Hz stereo PCM with every release and early reflection folded across the loop period. Use the nearest whole frame for the full 96 beats, 2,761,043 frames for the garden and 2,116,800 for the deck. Do not add an intro, a fade into silence or MP3 padding to the sample-accurate master. Aim for −18 LUFS integrated and ≤−1 dBTP with stable dynamics. Provide the source renderer, PCM WAV and small MP3 listening copy for each piece. Inspect the exact delivered WAVs for stereo/mono integrated loudness, sample peak, true peak, seam step per channel, local consecutive-sample steps and SHA-256. Compare the garden's two bell answers and the deck's bar-24 pickup on a second lap. Use Pocket Apricot as the level-matched reference and add the actual aim/drop/merge/hatch cues for a listening check when available.
