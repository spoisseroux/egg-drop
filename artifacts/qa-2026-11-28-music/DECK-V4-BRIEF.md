# Pocket Deck v4 brief: "Marimba Pop" (Fable, 2026-11-28)

For the Opus implementer: a new `build_deck_v4` in `scripts/build_music.py`, deterministic, seeded. Spencer's ask: a different deck song, likely faster, in the spirit of drop-and-merge puzzle games, still on the garden's melody and harmony. Nothing here has been heard; every level is a starting point.

**The idea.** The garden tune re-played by a toy band: marimba lead, muted nylon-string chops on the offbeats, a round bouncing bass, hand percussion. No stems on the bed, no square/triangle leads, no risers, booms or crashes (v3's EDM drop goes). Style reference is the genre only: bright, compact, light percussion, air between notes.

## 1. Tempo and length

- **140 BPM** (was 117, +20%). The hook is all 8th notes; at 140 they run 4.7 a second, lively without sounding sped-up. The grid is exact: bar = 75,600 frames, 16th = 4,725 frames at 44.1 kHz.
- **Main: 64 bars = 4,838,400 frames = 109.71 s.** **Lite: 32 bars = 2,419,200 frames = 54.86 s** (exactly half).
- Sync rule for both files: melody bar = `(bar-1) % 16 + 1`, chord bar = `(bar-1) % 8 + 1`. Then lite and main can swap at the same `TimePosition % 54.857` with a 0.5 s equal-power fade and never disagree on a note.

## 2. Transcription (measured from the main stems, offset 2257 frames)

Slots are 16ths, 0-15. Two rhythm cells: **X** = slots 0, 4, 6, 8, 10, 12; **Y** = slots 0, 2, 4, 8, 10, 12. Each note is short (about 1.5 slots). In the stem the notes on slots 6 and 10 of cell X are 7-8 dB softer: keep them 5 dB down.

**Melody (16 bars)**

| Bar | Cell | Notes | Bar | Cell | Notes |
|---|---|---|---|---|---|
| 1 | X | C4 E4 G4 C5 G4 E4 | 9 | X | C4 E4 G4 C5 G4 E4 |
| 2 | Y | G4 A4 G4 E4 G4 E4 | 10 | Y | E4 A4 E4 E4 G4 E4 |
| 3 | X | C4 E4 G4 C5 G4 E4 | 11 | X | C4 E4 G4 C5 G4 E4 |
| 4 | Y | E4 G4 E4 C4 E4 C4 | 12 | Y | E4 G4 E4 C4 G4 C4 |
| 5 | X | E4 G4 E4 B4 G4 E4 | 13 | X | E4 G4 B4 C5 B4 G4 |
| 6 | Y | E4 A4 E4 G4 B4 G4 | 14 | Y | E4 A4 E4 G4 B4 G4 |
| 7 | X | E4 G4 B4 C5 G4 E4 | 15 | X | E4 G4 B4 C5 G4 E4 |
| 8 | Y | E4 G4 E4 C4 E4 C4 | 16 | Y | E4 G4 E4 C4 E4 C4 |

**Chords (8 bars, four-note voicings), lead2 and bass**

| Bar | Chord, first half | Chord, second half | New bass roots | Lead2 (slots 12, 14) | Spencer's bass (slots 10, 12, 14) |
|---|---|---|---|---|---|
| 1 | F3 A3 C4 D4 (Dm7) | E3 G3 A3 C4 (Am7) | D, A | B4 D5 | D A D |
| 2 | F3 A3 C4 D4 (F6) | same | F, F | D5 B4 | A A A |
| 3 | D3 F#3 A3 B3 (D6) | E3 G3 A3 C4 (Am7) | D, A | C5 A4 | G G G |
| 4 | E3 F#3 A3 C4 (Am6) | D3 F#3 A3 B3 (D6) | A, D | G4 A4 | G G F# |
| 5 | as bar 1 | as bar 1 | D, A | D5 B4 | D A D |
| 6 | as bar 2 | as bar 2 | F, F | B4 D5 | B B A |
| 7 | G3 B3 D4 E4 (G6) | E3 G3 B3 D4 (Em7) | G, E | A4 C5 | C A G |
| 8 | E3 F#3 A3 C#4 (A6) | D3 F#3 A3 B3 (D6) | A, D | A4 G4 | A G F# |

In the stem the chords are stabs on **slot 3** (first chord) and **slot 8** (second), about 2 slots long. Lead2 is two 8ths on beat 4; the rest of its stem is echo.

**Verification.** Melody: 96/96 table notes are the strongest pitch in the stem at their slot; a sine re-synthesis correlates 0.80-0.88 per bar with the stem's spectrogram (0.09-0.47 when shifted a bar as a control). Lead2: 16/16. Chords: 64/64 half-bars across all 32 bars show exactly these four notes as the four strongest pitches. Spencer's bass is a sub (D1-C2), read by pitch tracking only: treat that column as approximate. The "new bass roots" are my reading of the harmony `[check by ear; bars 4 and 8 could take F# instead of A]`.

Notes: there is no single key. Bars 1, 2, 5, 6 use F and C; bars 3, 4, 7, 8 use F# (and C# in bar 8). Any added note must be a chord tone of its half-bar or one of the melody's E, G, A. The old deck lead stem differs from this melody in 14 of 48 notes (F and D variants); v4 uses the garden version above.

## 3. Instruments (all synthesized; centre unless noted)

| Layer | Recipe | Range |
|---|---|---|
| **Marimba** (lead) | partials 1, 3.93 (-14 dB, tau 60 ms), 9.6 (-24 dB, tau 20 ms); fundamental tau 0.28 s at C5, scaled by (523/f)^0.6; 3 ms attack; 5 ms noise thump band-passed 1.2 kHz at -18 dB; velocity scales the upper partials | melody +12 (C5-C6) |
| **Glock** (doubling) | free-bar partials 1, 2.76 (-16 dB), 5.4 (-26 dB); taus 0.5 / 0.15 / 0.05 s; low-pass 6 kHz; 9 dB under the marimba | melody +24 |
| **Nylon chop** (comp) | Karplus-Strong per chord note: noise burst low-passed 3 kHz, loop filter 0.5(1 + z^-1) x 0.996, fractional delay tuning; strum 9 ms per string, direction alternating; damp with an exponential, tau 70 ms (chop) or 250 ms (held); pan 20% left | voicings as written |
| **Bass** | sine + 2f triangle (-10 dB) + 3f (-18 dB); pitch falls 40 cents in 25 ms; tau 0.22 s; 4 ms click low-passed 800 Hz; then the existing `phone_weight` | D2-A2 |
| **Ocarina** (lead2) | sine + 2f (-20 dB) + 3f (-28 dB), breath noise band-passed at f (Q 8, -26 dB), 25 ms attack, vibrato 5.5 Hz +/-12 cents after 120 ms; both dyad notes sound together, held 3 slots; pan 20% right | as written |
| **Music box** | existing `s_music_box` | melody +12 |
| **Pad** (breather only) | existing `pad_render(TAB_PAD)`, low-pass 1.4 kHz | voicings |
| **Kit** | existing `s_kick` at -3 dB, low-pass 3 kHz; rim = high `s_tok`; `s_shaker` 16ths, 56% swing; clap = three 8 ms noise bursts band-passed 1.2 kHz, tau 90 ms; tambourine = noise high-passed 6 kHz, tau 50 ms; `s_tom` fills | |

Room: `room_size=.2`, sends marimba -16, glock -12, ocarina -12, chop -20 dB; bass and kick dry. Timing: seeded +/-5 ms on pitched notes, none on kick or bass.

Optional, flag `--without garden-ghost`: in the breather only, Spencer's own melody stem bars 1-8, time-stretched to 140 BPM (rate 1.1966), low-passed 2 kHz, 12 dB under the music box. `[keep only if the stretch is clean]`

## 4. Arrangement (main, 64 bars)

Comp patterns: **bounce** = chops on slots 2, 6, 10, 14, chord changing at slot 8; **stab** = Spencer's rhythm (slots 3 and 8, held). Bass **two-step** = root on slot 0, next root on slot 8, a pickup on slot 14 a fifth below the coming root.

| Bars | Section | Hook | Comp / bass | Percussion |
|---|---|---|---|---|
| 1-8 | A hello | marimba | bounce; bass slots 0 and 8 only | shaker, rim on 2 and 4, no kick |
| 9-16 | A2 | marimba + glock on the X bars; ocarina dyads from bar 13 | bounce; two-step | + kick on 1 and 3 |
| 17-24 | B answer | marimba in bars 17-18, 21-22 only; ocarina dyads answer in every bar, repeated at slot 4 of the empty bars | **stab**; bass walks 8ths on chord tones | kick, rim, no shaker; tom fill bar 24 |
| 25-32 | A3 | marimba, glock throughout | bounce; two-step | full; tambourine on offbeats |
| 33-40 | C breather | music box, slots 0 and 8 only | pad; bass whole notes; chops out | none; two plips, one pip pair |
| 41-48 | D build | marimba an octave lower (as written), -4 dB | bounce returns at bar 41; two-step from 45 | rim 8ths; kick from 45; tom run in bar 48, silence on its last 8th |
| 49-56 | E lift | marimba + glock + ocarina dyads held as thirds | bounce, all four strings; bass adds the octave on slots 4 and 12 | kick on every beat (soft), claps on 2 and 4, tambourine 16ths |
| 57-64 | E2 home | as E for 57-60; glock and claps leave at 61 | bounce; two-step | kick back to 1 and 3; bar 64 beats 3-4: marimba and a tok fill only |

A 3-minute round hears this 1.6 times; the hook changes instrument or density in every section and rests in B and C. Bar 64 is as thin as bar 1, so the loop point is quiet.

## 5. Lite (32 bars, results and menus)

Same tempo, chords and sync rule. No kick, rim or claps; shaker at -26 dB in bars 9-16 and 25-32 only.

| Bars | Content |
|---|---|
| 1-16 | nylon plays each voicing as a rising 8th-note arpeggio, tau 250 ms; bass roots on slots 0 and 8; music box hook on slots 0 and 8 only |
| 17-24 | no hook; ocarina dyads; pad under the arpeggio |
| 25-32 | marimba hook, soft (-6 dB), full cells in 25-28, slots 0 and 8 only in 29-32 |

## 6. Mix targets

- Main **-17.5 LUFS** (+/-0.3), true peak at or under **-1.5 dBTP**. Lite **-22 LUFS**, true peak at or under -6 dBTP.
- Merge SFX room: bell cut -3 dB at 3 kHz (Q 1) on the bus; 2-5 kHz band at least 24 dB under the full-band level in every 8-bar section.
- Shape: bars 49-60 sit 1.0-1.5 LU over bars 1-16; bars 33-40 sit 2-3 LU under. Loudness range at or under 5 LU.
- Phone (mono, high-pass 300 Hz) at -20 LUFS or louder; mono loss under 0.5 dB; under 4% of energy above 6 kHz.
- Render three loops, keep the middle; decode the OGG and confirm frame counts and seams.
- Outputs: `pocket-deck-v4`, `pocket-deck-lite-v4` (WAV + OGG q6), `report-v4.json`, and a preview: v3 for 20 s, then v4 bars 1-16 and 41-56.

## 7. Listening checklist for Spencer

1. Is it clearly your garden tune, and clearly a different song from v3?
2. Is 140 the right speed? (132 and 148 are one constant away.)
3. Phone speaker: can you hear the bass bounce and the marimba?
4. Play three full rounds with SFX on. Does a merge sound ever get buried? Anything you want to turn off by round three?
5. Does the lift at bar 49 feel like a reward, and the breather at 33 like a rest rather than a hole?
6. Do the bass notes in bars 4 and 8 sound right against the tune?
7. Results screen: does the lite feel like the same song sitting down?
