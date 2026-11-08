# Arcade benchmark evidence

The six arcade-benchmark-{frozen,current,current-effects}-{span,cheap}.json files are native LocalScript measurements in one foreground desktop Studio Play session. Each uses20 warm-up and90 measured frames in idle, falling, pile24 and multiMerge scenes,24 pieces,64×107 logical cells and a1536-span cap.

The frozen snapshot is commit2f1755b's JellyLCD, JellySpanSurface, JellySprite, DeckArt and BoardConfig source. Geometry is unchanged; the fixture receives the corresponding old colors too. The current running game remains common to all runs. Consequently whole-client RenderStepped includes Studio and that common game, not a complete historical executable. The frozen run does not measure the old per-event tween effects; current+FX cost is reported separately rather than implying that comparison.

cpuPaintMs is meaningful for the30Hz LCD passes. The cheap renderer paints its bounded bands on each sample, so use cpuAllMs for cheap cost. fieldEffectsCpuMs is separately timed. Pool statistics include scenario warm-up and are scenario-scoped; idle clears the owner and emits nothing. fieldEffectsInstances and fieldEffectsFinalInstances establish62→62 descendants; post-warm span creations are0 and the maximum current+FX demand/allocation is882/1536.

Later changes to boot readiness, recap gesture cues and removal of the duplicate RoomView arrival tick did not change the measured renderer, palette, pool, workload or DSP. The final source was recompiled and those changed paths were independently replayed. These desktop figures do not establish physical-phone speed, long-session behavior, listening preference or human fun.
