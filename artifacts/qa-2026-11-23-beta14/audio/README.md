# Beta 14 audio drafts: race song, finish cues, tip chimes, night garden

Opus, 2026-11-23, from Fable's `artifacts/qa-2026-11-23-beta14/RACE-AND-MUSIC-LOOK.md` (sections 1.1, 2, 3, 4).
**Drafts for Spencer to hear. Nothing is uploaded, nothing in `src/` changed.**

Every sound is additive synthesis in numpy (sine partials, shaped noise, FFT filters). No samples, no generated audio.
The night mix is DSP on Spencer's own `assets/audio/music/garden-loop.wav` (read only) plus a synthesized overlay.
Each script uses a fixed seed; two full runs gave byte-identical WAVs (all 28 sha256 equal).

## How it was measured

- **Loudness and true peak**: ffmpeg 8.0.1 `ebur128=peak=true` (full ITU-R BS.1770-4: K-weighting, 400 ms blocks,
  -70 / -10 LU gating; true peak by 4x oversampling). Not an approximation. Mono files are metered as one channel.
  Files shorter than 0.4 s have no integrated value, so those are judged on peak (as the spec asks).
- **Peak, RMS, first/last sample**: numpy on the written 16-bit PCM.
- **Loop seam**: last 50 ms of the loop joined to its first 50 ms. *Step ratio* = the sample step across the join divided
  by the 99.9th-percentile step around it. *Curvature ratio* = the largest second difference (a click detector) within
  2 ms of the join divided by the largest anywhere else in the 100 ms. Both under 1 = the join is smoother than the
  music on either side. Spencer's day loop scores 0.655 / 0.95 for comparison.
- JSON with every number, the full score ledgers and hashes: `race/race-report.json`, `stings/stings-report.json`,
  `tip-chimes/tip-chimes-report.json`, `night/night-report.json`.

## 1. Race song "Hop to It" (`scripts/synth_race_music.py`)

| File | What |
|---|---|
| `race/hop_to_it_120bpm_leadin3_loop32.wav` | 3.000 s lead-in + 32.000 s loop, 48 kHz stereo. Loop region 3 to 35 s |
| `race/hop_to_it_seam_audition_16s.wav` | Last 4 s of the loop into the first 4 s, twice: what the 35 to 3 jump sounds like |

| Measure | Target | Result |
|---|---|---|
| Frames | 1,680,000 | **1,680,000** (lead-in 144,000 + loop 1,536,000) |
| Bar math at 120 bpm | exact | beat = 24,000 frames, bar = 96,000, bar 1 at frame 144,000 (3.0 s), all integers (asserted) |
| Integrated | -19 LUFS | **-19.0** whole file; loop region alone -18.9 |
| Loudness range | < 3 LU | **2.3** loop region; 2.8 with the quieter lead-in |
| True peak | <= -6 dBTP | **-7.5** (no limiting needed) |
| Seam 35 to 3 | click-free | step ratio **0.032**, curvature ratio **0.67** |
| Lead-in into bar 1 | | frame 143,999 equals frame 1,679,999 exactly, so the first pass through 3.0 is the same sample path as every loop |

Two-file fallback (spec 2.1): cut frames 0 to 143,999 (lead-in) and 144,000 to 1,679,999 (loop) from this file; nothing to re-render.

## 2. Finish cues (`scripts/synth_dash_stings.py`)

| File | Length | Format | Integrated | True peak | Target |
|---|---|---|---|---|---|
| `stings/dash_win.wav` | 2.600 s | 48 kHz stereo | **-16.0 LUFS** (max momentary -12.0) | **-5.4** | about -16, <= -4.5 dBTP |
| `stings/dash_place.wav` | 1.800 s | 48 kHz stereo | **-18.0** (max M -16.0) | **-7.3** | about -18, <= -6 |
| `stings/dash_line.wav` | 0.600 s | 44.1 kHz mono | **-18.0** (max M -17.0) | **-6.4** | -18, <= -6 |
| `stings/dash_best.wav` | 0.900 s | 44.1 kHz mono | **-18.0** (max M -16.4) | **-6.6** | -18, <= -6 |
| `stings/star_land.wav` | 0.220 s | 44.1 kHz mono | (too short) | peak **-6.0 dBFS** | peak -6 |
| `stings/stars_total.wav` | 0.700 s | 44.1 kHz mono | -19.4 (max M -16.1) | peak **-4.0 dBFS** | peak -4 |

All six start and end on exactly zero. `dash_win`'s F chord lands at 0.400 s in the file, as specced (start it 0.15 s into the card, the hit lands at 0.55).

## 3. Tip chime set (`scripts/synth_tip_chime_set.py`)

18 files, `tip-chimes/tip_chime_{wood,kalimba,glock}_{1..6}.wav`, 44.1 kHz mono. Variants as Fable's table
(1 G5 C6, 2 E5 A5, 3 A5 E6, 4 E5 G5 C6, 5 D5 G5 A5, 6 G5 E5 C6).

| Timbre | Lengths (1 to 6) | Sample peaks | RMS (all six) | First / last sample |
|---|---|---|---|---|
| wood | .36 .36 .37 .42 .42 .42 s | -3.0 to -3.6 dBFS | **-15.73** (0.00 dB spread) | 0 / 0 |
| kalimba | .38 .38 .39 .44 .44 .44 s | -3.0 to -4.0 | **-15.36** (0.00 dB spread) | 0 / 0 |
| glock | .38 .38 .39 .44 .44 .44 s | -3.0 to -5.0 | **-14.60** (0.00 dB spread) | 0 / 0 |

Every file is under 0.45 s, starts from zero (0.5 ms fade-in under the mallet's strike) and ends with a 30 ms fade to zero.

## 4. Night garden (`scripts/synth_garden_night.py`)

| File | What |
|---|---|
| `night/garden_night_loop.wav` | The night mix, 2,894,770 frames at 44.1 kHz stereo: the same length as the day loop to the frame |
| `night/garden_day_to_night_preview_20s.wav` | Day 0 to 6 s, an 8 s in-step crossfade (6 to 14 s), night 14 to 20 s. The game blends over 120 s; this is squeezed so the change is easy to hear |

| Measure | Target | Result |
|---|---|---|
| Day file (unchanged) | | -17.6 LUFS, LRA 2.3, -1.9 dBTP (matches the manifest) |
| Night integrated | 3 LU under day: -20.6 | **-20.6 LUFS** |
| Loudness range | < 4 LU | **2.4** |
| True peak | <= -6 dBTP | **-6.3** (no limiting needed) |
| Seam | click-free | step ratio **0.27**, curvature ratio **0.20** (smoother than the day loop's own seam) |
| Steps | | 1.8 kHz 4th-order low-pass (circular FFT); rider max cut 3.0 dB, active 17% of the time; wrapped room .22; music box 12 LU and pad 20 LU under the bed |

What I measured in Spencer's loop (numpy, not by ear): 117.000 bpm from its length (128 beats), 117.2 bpm from onset
autocorrelation; the first 20 ms are 1.9x the track's average level, so frame 0 reads as the downbeat; the bass sits on E in
most odd bars and **F# outweighs F** (0.35 vs 0.29 of the top pitch class), so I read it as **E minor**, not A minor.

## Deviations from the spec, and why

1. **Output folder.** Spec says `assets/audio/drafts/`; the brief said `artifacts/qa-2026-11-23-beta14/audio/`. I followed the brief.
2. **Tip chime peak -3 dBFS, not -1.** The brief said -1; Fable's section 4 deliberately moved it from -1 to -3. I followed
   the spec. Raising all 18 by 2 dB is a one-line change if Spencer wants -1. Note: wood 4 and 6 and glock 4 have a true peak of -2.9 / -3.0 dBTP (sample peak exactly -3).
3. **Race mix: bell double -14 dB (spec -10), pad -20 dB (spec -24).** At the spec's numbers bars 13 to 16 measured
   2.2 LU over the rest and bars 9 and 10 dipped, giving a loudness range of 3.6 LU against the < 3 target. The new
   numbers give 2.3.
4. **Lead-in tails into bar 1.** The spec asks for the lead-in's tails to run on into bar 1 *and* for the loop region to
   be seamless; both cannot be exactly true, because a seamless loop region already holds bar 16's wrapped tails at 3.0.
   I crossfade (equal power) the lead-in into the loop's own last 40 ms just before GO, so 3.0 is reached exactly as on every
   loop. The pickup D5 hands over to bar 16's ringing tail in those 40 ms, under the downbeat; it should not be audible `[check by ear]`.
5. **Night overlay notes: Fable's C becomes B** (C5 to B4 in bar 16, C6 to B5 in bar 24), per her own rule for E minor (point above).
6. **Preview crossfade is equal gain, not equal power.** See risk 1.
7. **Formats.** `dash_win` and `dash_place` are 48 kHz stereo (section 2.3 says stereo 48 kHz for `dash_win`; `dash_place`
   matched it). The four small cues are 44.1 kHz mono (section 2.5).
8. **Chime lengths.** Fable's table lists 0.36 to 0.42 s, which fits the wood recipe (.26 s note). Kalimba and glock notes are
   .28 s, so their files are 0.02 s longer (0.38 to 0.44 s). All still under 0.45.
9. **"-18 LUFS short-term" for `dash_line` and `dash_best`** is met as the integrated (gated 400 ms block) loudness of the
   cue. A 3 s short-term window is longer than either sound.
10. **Lead-in shaker** rises -18 to -6 dB *relative to the lead*, read literally from section 2.2; it peaks 6 dB over the
    loop's off-beat shaker for half a second before GO `[check by ear; easy to pull down]`.

## Risky by the numbers

1. **Equal-power day/night crossfade (spec 3.3) would swell.** Day and night are the same performance in step and correlate
   at **0.97**. At mid-blend equal power measures **-16.4 LUFS**, 1.4 LU *louder than day* (-17.8 on the same 30 s) and
   4.5 LU over night. Equal gain (day x (1-w), night x w) falls smoothly: -19.4 at mid-blend. The code should use equal gain.
   If the voices drift out of step on the phone, the highs decorrelate and the right curve sits between the two.
2. **Tip chimes at the low speed step**: at 0.891 the wood 3-note chimes last 0.47 s and kalimba/glock 0.49 s, over the
   0.45 limit. Fable's fallback (low step 0.944) gives 0.44 / 0.47 s; only wood fits under 0.45 at every speed with it.
3. **Night rider works harder than "the loudest transients"**: it is cutting at some depth 17% of the time (never more
   than 3 dB). Spencer's loop is already dense (LRA 2.3), so there is little between its hits and its average.
4. **Key reading** (E minor) and the downbeat at frame 0 are measured, not heard. If the music-box answers rub, the notes
   are in the `OVERLAY` table at the top of the script.
5. `stars_total` peaks at -4 dBFS as specced, which is -19.4 LUFS: about 1.4 LU under `dash_place`. At play volume .5 it may sit low against the stings.

## 2026-11-25: race song and finish cues wired as beta placeholders

Spencer: "put a placeholder for race music, and race finish song". On `feat/egg-drop-arcade-polish` only the race song and
the six stings came over (the tip chimes and the night mix stay on `worktree-agent-a228c4a3651a98d28`). Masters copied
unchanged to `assets/audio/custom/egg_drop_race_song.wav`, `egg_drop_dash_{win,place,best,line}.wav`,
`egg_drop_star_land.wav`, `egg_drop_stars_total.wav`; uploaded as Audio (ids and moderation in `asset-ids.json`).
Wired behind the Dash ceiling (beta place and Studio): `AmbientAudio.setRace`, `DashClient` (song, `dash_line`, stings),
`BoardAudio.DashIds`. Still not heard by Spencer.
