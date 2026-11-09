# Spring Meadow actual walkthrough evidence

QA outputs only; runtime and Studio were untouched by this analysis.

## Capture conditions

Two local Studio clients used ordinary production player/visitor renderers. Both earned Zivvi and 6 Stars through the normal eight-Space starter flow before recording, per operator procedure. MCP `character_navigation` drove native avatar routes; this was **automated navigation, not hand-played keyboard input**. The operator reports no avatar position teleport.

There was one initial camera CFrame heading setup, then ordinary Custom camera outside normal pet focus. QA held actual noon/midnight at selected times, visibly labeled; this was **controlled lighting, not natural day progression**. Final wallet/light exports report Custom. The operator subsequently disabled both helpers and reported Controlled=false / actual ClockTime 7.504 / cameras Custom; that cleanup is separate operator evidence.

Original, preserved: `C:/Users/skunk/Videos/Roblox/Roblox-2026-11-09T12_25_48.792Z.mp4` (369.818 seconds, 816x400, H264/AAC, 91,431,696 bytes). Filename records the end, not start. Approximate start 2026-11-09T12:19:38.705Z; no embedded UTC timecode, so allow about 0.3 seconds aligning traces with video.

## Findings

1,437 samples cover 359.002 seconds. Cadence median 0.249993 s, range 0.232343-0.267174 s. These are sampled authoritative pet paths and replicated owner roots, not every rendered frame or foot-contact raycasts.

| Check | Player1 | Player2 |
| --- | --- | --- |
| Maximum sampled pet speed |17.9857 stud/s|17.8401 stud/s|
| Maximum recorded pet velocity |17.9966 stud/s|17.9638 stud/s|
| Pet root Y, every sample |4.025000095|4.025000095|
| Owner root Y range |6.99425-6.99836|6.98568-6.99902|
| Pet samples in buffered Spring water |0|0|
| Z64 route crossings, seconds after trace starts |west-out 9.999; east-return 151.510; west-out 155.760; east-return 197.257|east-out 24.247; west-return 215.757|

Both pet paths stay inside the 160x176 floor bounds. Stable root heights and visible lawn contact are consistent with floor support. No sampled pet fall, jump, water entry, or speed above 18 stud/s was found. This cannot independently certify each foot contact or exclude a brief between-sample event.

### Rest separation and interruption

West (-12.5, 4.025, 87) and East (-7.5, 4.025, 87) are exactly 5 studs apart. Both were occupied in 30 samples across 69.745-70.996 s, 121.261-124.010 s, and 145.761-148.509 s. Every anchored rest sample had zero root drift.

Eight logged `nookRest` actions each scheduled exactly 6 seconds. Action logging begins 91.6 seconds into the trace; earlier rest episodes lack complete scheduled-duration proof. Sampled states can retain a clamped final pose until the next action update, so state duration is not an independent stopwatch.

- Walking interrupted Player1 generation 164: scheduled 145.577-151.577 s; replacement follow starts 148.577 s, exactly 3 seconds into rest. Clip 04 covers it.
- Focus interrupted generation 167: scheduled 168.575-174.575 s; focus starts 171.842 s, 3.267 seconds into rest, and persists until about 187 s. Clip 05 covers it.
- Earlier focus 91.612-113.5 s spans the controlled noon-to-midnight change. Clip 03 covers it.

### Owner telemetry caveat

Replicated owner updates batch. Player1 shows 22.310 studs over 0.2497 s at 9.499 s (apparent 89.35 stud/s), followed by smaller catch-up updates; Player2 shows three apparent 20.56-23.16 stud/s updates around 213.76-214.51 s. Outliers remain in `../actual-walk-analysis.json`. Video shows ordinary running, but this trace alone **does not prove smooth avatars or establish a teleport**. No runtime fix was inferred.

### Economy and toy scope

Both wallet files have 38 samples spanning before and after the video. Every sampled state remains revision 2, 6 Stars (`nectar`), inventoryMask 1, and all five jars 0. No sampled reward/inventory change occurred during traversal, rest, or focus.

Native solo-Start smoke passed separately per operator. The current two-client Join attempt failed timing/input: **this recording does not establish successful paired return**. Earlier v297 paired evidence remains separate.

## Excerpts

Six 1x clips total 2,779,032 bytes (~2.65MiB). Original audio is retained as AAC 64 kbps; a 48 px factual header is added above the otherwise unchanged 816x400 recording. `clips.json` includes offsets, durations, bytes, and ffprobe verification.

| File | Original interval | Evidence |
| --- | --- | --- |
|01-west-out.mp4|00:00-00:28|P1 west-out;P2 east-out|
|02-separated-night-rests.mp4|01:56-02:10|Separate anchors under controlled night|
|03-focus-light-change.mp4|01:31-01:54|Focus with controlled noon-to-midnight switch|
|04-walk-interrupt-revisit.mp4|02:23-02:43|Walk cancellation, east-return, west-out|
|05-rest-focus-interrupt.mp4|02:46-03:10|Rest interrupted by focus; visitor nearby|
|06-return-to-hub.mp4|03:14-03:42|P1 east-return;P2 west-return to hub|

`walk-storyboard.png` is the curated six-frame contact sheet; `walk-contact-sheet.png` is a 22-frame overview. Full numeric results are in `../actual-walk-analysis.json`. This analysis did not change runtime/Studio or stage files in Git.
