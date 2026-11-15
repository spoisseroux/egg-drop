# Rarity answer revision 2 independent review — GO

2026-11-14. Reviewer Sol /backlog_audit; author separate UI Sol. The user rejected revision1 as perceptually indistinguishable. This review certifies the new source/PCM evidence; listening remains the acceptance evidence. No runtime edits, upload or publish by reviewer.

Only runtime policy constants change: Rare receipt+.20/.42s, speeds−2/+5semitones, gains.35/.32; Uncommon+.24s,+2semitones,.22; answer ownership600ms. Existing Cinematic reads that constant and preserves the previously reviewed same-clock disclosure, cancellation, expiry/no-catch-up and muted/unloaded drop semantics. No opening/body pitch or gain change, no added wait or action lock. Old1dB finish limit is explicitly superseded by Astra's revision2 brief.

Independent validation:

- All22 preserved source/previous-audition hashes,18 new output hashes, final generator/policy hashes match. Historical audition bytes remain unchanged.
- Reconstructed actual Material Rare output from the approved body and goal_tick PCM: exact quantized match. Complete Common equals source; every pre-receipt sample remains identical. Primary comparison is exact Common148800frames +31200digital-zero gap +Rare148800frames =328800frames/6.85s at48kHz.
- Independently measured first-note whole-support accent/tail contrast+5.3685056913dB (4310frames), active-envelope+5.6356253100dB (3886frames). The declared centered5ms RMS envelope threshold1% is explicit and accent/body use identical indices. Second-note body is digital silence for whole/active support; contrast correctly stays null and absolute RMS/peak are reported.
- All mono outputs match channel averaging within.5LSB. Independently measured comparison4× peak−4.76783dBFS. Generator/report checks all five bodies under all three patterns, no clipping, full4× peaks below−3, note ends inside600ms and no normalization. Whole-window peak remains unchanged; the report appropriately uses exact-note masking contrast rather than treating that as an audibility verdict.
- Runtime policy and both canonical/ZZ specs compile; both mirror pairs byte-identical. Updated tests assert actual new attack times/pitches/gains and later owner end; no receipt/visual/economy expansion.

GO for coordinator nativepolicy5/owner3 and the clearly labeled new Common→Rare local listening comparison. No claim that the reviewer heard it, that taste is approved, or that these changes are published.
