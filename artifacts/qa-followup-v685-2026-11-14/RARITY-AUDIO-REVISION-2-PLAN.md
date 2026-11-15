# Audible rarity answer revision 2

User listened to revision1 and found Rare/Common the same. The .035 answer was19.87/11.85dB below the actual Material tail in each exact source-support window. The old complete450ms peak statistic did not establish audibility.

Astra amendment: Common/Neutral and the approved opening/body remain bit exact. Only existing goal_tick accents change. Rare: receipt+.20/.42s, speeds2^(-2/12)/2^(5/12), gains.35/.32; answer owner ends+.60s. Uncommon: receipt+.24s, +2semitones, gain.22. No new assets, changed music, UI, pose, receipts or economy. Same canonical tiers/visible owner/skip/reopen/focus/device/reduced/cancel/drop semantics.

Measured candidate first Rare note on the actual Material body: +5.37dB RMS versus the exact same body-tail support, within Astra+3..+8dB target. Second begins in digital silence: report accent absolute RMS/peak, mark tail silence rather than divide/normalize against it. No final normalization. Old+1dB finish cap superseded; allow up to+6dB finish-window peak growth if needed, fullclip truepeak preferred belowâˆ’3dBTP and no clipping.

Owned changes: HatchRarityCue event values/end, policy and actualCinematic lifecycle test expectations plus exactZZ mirrors; qa20261114_rarity_audio.py emits NEW audio/revision-2-audible/*-revision-2 files only, preserving previous audition bytes. The generator must mirror policy exactly and hash source/policy/output files. Report per-event exact support and explicit5ms RMS-envelope-active-mask accent/base/mixRMS, contrast where nonzero, absolutepeak; full600ms combined sample/independent4xpeak, finite/clipping, unchanged Common and opening PCM, actualmono and complete originals.

Verification: actualcatalog offline5 and compile; independent source/output reconstruction; root fresh native policy5/owner3 then actualMaterial Common/Rare native playback. Primary new MP3/WAV is full Material Common → .65s digital-silence gap → Rare at identical unchanged body gain, with individual pair files also supplied. Numeric targets establish measurable separation/headroom, not listening approval.
