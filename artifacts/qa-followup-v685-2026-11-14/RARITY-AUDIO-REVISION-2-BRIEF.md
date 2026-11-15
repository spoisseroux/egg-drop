# Rarity audio revision 2 — make the answer clearly audible

Astra, 2026-11-14. Spencer listened to the actual matched Material Common/Rare auditions and said: **“The rare and common hatches are the same sound.”** That rejects the prior perceptual result. Source/runtime correctness and the unchanged combined peak did not establish an audible distinction. I cannot hear the files through my tools; the user's listening is the authoritative evidence.

Keep Common, the opening, the original body, reveal timing, tier classification and lifecycle behavior unchanged. Revise only the added post-receipt answer. Reuse the approved 80 ms `goal_tick` source through its dedicated owner; no new upload is needed.

| Tier | Time after the disclosed receipt beat | Pitch relative to the source | Starting gain |
|---|---|---|---|
| Common / Neutral | No new note | — | — |
| Uncommon | +0.24 s | +2 semitones | 0.22 |
| Rare, first note | +0.20 s | −2 semitones | 0.35 |
| Rare, answering note | +0.42 s | +5 semitones | 0.32 |

The Rare answer is an unmistakable **two-note upward fifth**, with 220 ms between attacks. Moving it later avoids the strongest existing tail. Relative to the rejected gain 0.035, the first note is 20 dB stronger; this deliberate increase is necessary to test a meaningfully different candidate. The second is a small, separate reply, not a shimmer hidden inside the first. With the source's actual duration and playback speeds, both notes fit comfortably within a **0.60 s owner lifetime after receipt**. No earlier anticipation cue or added waiting/interaction lock.

Use the exact same body-tail sample region as each note's support when measuring masking. Target the first Material Rare note at roughly **+3 to +8 dB RMS above its simultaneous body tail**. Adjust its gain within 0.30–0.45 if measurements require it; report the chosen gain. The later note lands in a much quieter tail, so a ratio to silence is not meaningful: retain the bounded fixed gain and report its actual peak/RMS. Report both whole-support and active-envelope measurements; do not use a whole 450/600 ms peak window as the only audibility check.

**The earlier roughly +1 dB combined-finish peak guideline is superseded for this revision.** Permit up to approximately +6 dB change in the complete finish-window peak if needed, while keeping the full mixed clip preferably below −3 dBTP and always free of clipping. Do not attenuate or normalize Common to make the comparison easier, and do not lower the whole Rare clip to compensate for its answer. If headroom requires adjustment, change only the added notes and report it. Existing body gain/speed stays 1/1. These numeric checks support the next listening test; they do not prove the two versions sound different.

Render fresh `revision-2` filenames to avoid a stale audio-player cache. Present a matched **Common → short gap → Rare** comparison as one playable clip, with the order clearly written, plus individually playable Common/Rare files if useful. Both use the same Material body at identical gain; no independent normalization. The two-note Rare answer should be recognizable on the first comparison at the same comfortable playback volume. A separate tail-only comparison may diagnose masking, but the full hatch comparison is the acceptance artifact.

Preserve existing cancel/skip/reopen/Reduced Motion/owner-loss behavior and no catch-up bursts. Update the answer lifetime and relevant timing checks consistently, and verify all five existing bodies for headroom. Do not revive a muted/rejected note when its asset later loads. Do not change v3 garden/Deck music, the world path or the accepted UI visuals.

Sol implements and measures this bounded revision; coordinator checks native runtime parity and presents the actual comparison. Normal user listening feedback determines acceptance. World-path integration/review continues independently.
