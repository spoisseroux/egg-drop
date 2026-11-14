# Local music pair and hatch concept — tooling plan

14 November 2026 · Sol implementation · **systems Sol architect GO; reports/UI Sol independent code review GO**. Creative authority: Astra's `MUSIC-DIRECTION.md` and `HATCH-IDEA.md`. User authorization is for actual local previews now, **no production hatch installation, Studio, Play, uploads, publish, commits or source-blend saves**. All alien/Blip work is parked.

## Owned files and outputs

- New `scripts/qa20261114_music.py`: deterministic NumPy/stdlib synthesis, WAV writing, FFmpeg measurement and auditions.
- New `scripts/qa20261114_hatch.py`: isolated background Blender scene, append copies of authored Bear/egg meshes and materials, concept poses/lighting/frames only.
- New `scripts/qa20261114_media.py`: ordinary Pillow contact-sheet/UI compositing and FFmpeg/GIF preview encoding.
- New artifacts only: this folder's `audio/` and `hatch-concept/`. No production manifest, runtime audio IDs, HatchCinematic, RevealStage or other lane's source changes.

## A. Actual music previews

Compose **Little Afternoon**, exactly Astra's F-major, 96 BPM, 16-bar melody/harmony repeated into 32 bars/80 seconds. Score events are explicit note/duration tables with bar-duration assertions and a JSON score ledger. No copied recordings, external music service or generated imagery.

Garden: rounded additive wooden mallet (8ms attack, subdued partials, 180–450ms decay); soft flute replacing lead bars5–8 and21–24; sparse nylon/harp chord tones/dyads; bass roots/fifths; quiet offbeat shaker/brush and occasional wood taps; pad only bars9–12/25–28; occasional bell. Melody/bass centered; accompaniment pan <=20%, deterministic <=8ms timing variation only for garden accompaniment. Small room ~.8s, 8–12% wet.

Deck: same principal score, band-limited25%-pulse/triangle lead (.35/.65), triangle bass, soft offbeat chord voices, restrained original noise percussion and rounded kick. No harsher/louder/tempo-based substitute for articulation. Tiny room3–5%, narrow stereo.

Synthesize into48kHz stereo cyclic buffers, wrapping tails and circular reverb. Round attacks/releases avoid discontinuities. Remove DC, gain-adjust using FFmpeg integrated loudness where available (garden target~-20LUFS, deck~-19LUFS), ceiling <=-1dBFS/true-peak; report actual values if peak ceiling prevents exact target. No dynamics squash. Save80s16-bit PCM loops, loudness-matched20s excerpts (within1dB), and for each a seam audition **last4s+first4s twice =16s**. Include mono auditions/metrics and an explicit filename/title report. Existing music remains unchanged.

Tests: exact80s/48k/2ch metadata;32bars and repeated melody identity; all bar durations4beats; finite/no clipped samples, DC, sample/true peak, RMS/LUFS, mono energy, boundary jump versus nearby derivatives. Seam metrics supplement actual listening, not a claim of subjective approval. Astra listens before installation. Runtime integration recommendation only: preserve current music/mute owner, duck6dB for reveal, equal-power180–300ms garden↔deck crossfade; owner agents implement later after actual approval.

## B. Actual hatch concept media

Load source models into a fresh **background-only** Blender scene by library append/copy. Isolate Bear's actual base meshes/face, excluding alternate face pieces, wearables and loose attachments; retain authored proportions/materials. Reuse authored egg shell meshes/UV/color textures. Wobble Top comes from the actual existing toy procedural specification if no authored source mesh exists; document that provenance. Hash input blends/textures before and after; never save them or export a production FBX.

Create one fixed38° perspective camera, cream oval light pool on curved dark-teal stage, gentle warm key/mint rim and grounded shadows. Phone concept812×354, top58px reserved; stage left58%, facts/actions right42%. Single perspective/canvas across opening and receipt. A six-frame contact sheet at store/rock/crack/peek/hop-wave/settled timings; one actual-size812×354 settled composite; **~6s Bear** and **~4s Wobble Top** animatics,12fps minimum, MP4 plus a lighter GIF if useful.

Animate copied object groups with bounded rig-style pivots: egg squash/unequal rocks, authored seam opening, cap tip and grounded lower shell, Bear peek/push/step/hop/two waves/settle. No stretched body geometry or unrelated front-portrait cut. Preserve Bear base face; blink/happy expression only if existing authored variants can be isolated safely. Six to ten small procedural stage-only paper specks, no white flash. Right-hand name/facts/action labels fade in at specified times; final buttons stay fixed. Item top spins/leans/rights itself; small Bear watches without occluding it. Concept audio uses original synthesized short F-major cues; all media explicitly says **CONCEPT — NOT LIVE GAME**. Reduced-motion alternative can be shown as three static clear frames in the sheet; this preview does not install a setting implementation.

Tests: frames/codec/fps/duration/resolution verified with FFprobe/Pillow; six exact storyboard frames; both full bodies/egg/tops fit stage and reserved-band/action rectangles; no loose duplicate Bear parts; source SHA unchanged; stage/UI captions disclose concept and preview state. Render actual first/peek/settled frames for Astra before claiming acceptance. If rig constraints prevent literal scrambled steps or a lower-half split, show and label the honest bounded concept rather than damaging source geometry or inventing production readiness.

## Export and integration hazards

- Run Blender separately from user's live scene. Do not call source-building scripts that overwrite authored blends/assets. Input `.blend` paths are read-only; only artifact renders/optional new concept scene may be written.
- Avoid decoding/resampling loops through lossy formats for timing tests. WAV is authority; preview MP4/AAC/GIF is an audition convenience. Preserve seamless sample count and report encoder padding where relevant.
- Do not normalize every musical note separately, over-pan melody, fill every silence or bake garden birds/water into tracks. The same explicit melody/harmony must survive both arrangements.
- GUI compositing is a concept depiction, not a Studio screenshot or proof of runtime input/persistence. No new prices/odds/rewards/rarity claims appear.
- No watched-file deletion and no other lane's generated files. Keep failed renders/logs as evidence; replace only this lane's local preview outputs when iterating.

Review sequence: systems Sol architect GO → synth/render actual artifacts → checks → Astra listens/critiques actual frames → iterate if needed → show previews to Spencer. A concept rendering GO does not authorize production hatch installation; Spencer must first see and approve the idea.
