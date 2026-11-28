# V3 music review (Fable, 2026-11-28)

Reviewed by measurement, not by ear: `*-v3.wav` against `*-v2.wav`, plus the v3 arrangement in `scripts/build_music.py` (commit 28d8aed8). "Phone" = mono, high-passed at 300 Hz.

| Track | Verdict |
|---|---|
| garden-day-v3 | SHIP TO SPENCER (two optional tweaks) |
| garden-night-v3 | NEEDS CHANGES (small) |
| pocket-deck-v3 | NEEDS CHANGES (the drop does not lift) |
| pocket-deck-lite-v3 | SHIP TO SPENCER |

## Evidence

**Day.** Matches the ask. Onsets 7.6 -> 4.3 per second, spectral flux 1.4 -> 0.95 (0.58 in pad-only bars 1-8, 33-40), 2-5 kHz share -21.5 -> -28.5 dB, short-term loudness range 5.0 -> 1.9 LU. Melody blocks sit +0.7 LU up. Risks: the pad never lets go (0% of 50 ms frames fall 10 dB under the mean; v2 had 8-22%), and the shaker is effectively inaudible (5-10 kHz share -41 dB), so pad-only and shaker blocks are the same texture (mel similarity 0.96-0.98). Phone loudness -25.9 (v2 -23.4).

**Night.** Too static. Short-term range 1.1 LU, 8-bar blocks 0.96-0.99 similar, nothing above 5 kHz (-78 dB share, digital silence), 2-5 kHz at -40 dB except in the music-box bars. 16 of 20 music-box notes sit in bars 9-16 and 41-48, so bars 1-8, 17-24, 33-40, 49-56 (16 s each) are pad and bass with one cricket at -25 dB under the bed. Phone loudness -28.7 (v2 -24.1): the bed nearly vanishes on phones.

**Deck.** More exciting than v2 overall (+1.4 LU, lows +10 dB, gaps 24% -> 2%), but the drop is an anticlimax:
- Bar 16 -16.6 LUFS, bar 17 -17.9: loudness falls 1.3 LU at the drop. Bars 17-20 -17.83 vs 13-16 -17.16, 21-24 -17.34.
- 300 Hz-2 kHz falls 2 dB (lead out, nothing replaces it); 2-5 kHz and above 5 kHz are flat against bars 1-16 (-42 dBFS), while the bar-16 roll is 8 dB brighter than the drop it lands on.
- Only the lows rise (+2 dB under 120 Hz), and phones lose that: phone loudness -20.2 vs v2 -20.4, so on mobile v3 barely differs.
- No gap before the impact (last beat of 16 at -20.0 dB RMS, first beat of 17 at -19.8).
- Bars 9-16 and 25-32 are 0.99 similar. No harsh 2-5 kHz peaks (max -28.5 dBFS in the roll).

**Seams.** Day and night wrap step is 2.1-2.4x the p99 sample step; high-frequency energy there is 26 dB under a barline, so no click expected. Night OGG seam is +8.7 dB over its median barline: listen once at the loop point.

## Changes for `build_v3`

Deck (required):
1. Section gain after `glue`, before `finish`: bars 1-14 -1.0 dB, bars 17-20 +1.0 dB, 30 ms ramps. Target: 17-20 at least 1.0 LU above 1-16.
2. Drop hook, bars 17-20: play `melody_line(deck_notes, 0, 4, +1, src_len_bars=8)` on `TAB_PULSE` at `reld(-5)`, send -18. Real lead still returns at 21.
3. Hats: 16th closed hats (noise high-passed 7 kHz, 30 ms) bars 9-32 at `reld(-18)`; open hat on offbeats bars 17-20 at `reld(-13)`. Kit high shelf -4 -> -1 dB. Target: above 5 kHz in 17-20 at least 4 dB over 1-16.
4. Gap and impact: gate everything except the riser from `pos(16, 4.5)` to `pos(17)`; boom `reld(-6)` -> `reld(-2)`; add a noise crash (high-passed 3 kHz, 1.2 s decay) at `pos(17)`, `reld(-12)`.
5. Phone weight: bass pulse mix 0.6 -> 1.0 and low-pass 1400 -> 2200 Hz; add a 3 ms 2.5 kHz click to the kick. Target phone loudness -19.0 or louder.
6. Bars 29-32: keep the four-on-the-floor kick so the last phrase differs from 13-16.

Night (required):
7. Spread the music box: add one note (`keep={8}`, `rel(-10)`) in bars 3, 7, 19, 23, 35, 39, 51, 55.
8. Pad and chords low-pass 1100 -> 1600 Hz.
9. Crickets `rel(-22)` -> `rel(-15)`, add bars 14, 30, 46, 62.

Day (optional):
10. Shaker `rel(-29)` -> `rel(-23)`, brush `rel(-30)` -> `rel(-25)`.
11. Bars 33-40: pad -6 dB, leaving `chords_soft` and bass, for real space.
