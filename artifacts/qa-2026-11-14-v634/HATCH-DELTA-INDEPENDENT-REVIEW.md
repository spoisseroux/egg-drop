# Hatch camera and audio delta review

2026-11-14 · UI Sol reviewing World Sol's source · **GO**.

`HatchDisplayScene` caches padded transformed part-corner bounds across gesture extrema, restores the sampled pose after measurement, and refits the camera for aspect and late authored-rig replacement. Camera and scene ownership remain unchanged. Lower-shell local Ry(pi) is applied around each resource's center after its semantic assembly translation, preserving left/right placement. Conservative floor anchoring remains independent of the camera fit.

`BoardAudio` releases each display duck over 600 ms through one bounded recovery connection. Surviving owners continue taking the minimum gain, and refresh uses current volume/focus settings. Reactivation replaces recovery without multiplying gains. Stop/destroy removes the recovery owner. `AmbientAudio` applies that shared duck to its deck group while excluding its own deck-round duck as before. The display audio manifest is still empty at this review, so no held music or superseded burst is activated.

Coordinator reports current-disk native NativeFrustum 1, AudioDuck 3, LoopAudio 16 and AmbientAudio 7 passing. These support lifecycle/geometry/routing correctness; artistic/native sound and graphics acceptance remain separate.

## UI host follow-up

Coordinator's native fixture found a queued EggHatchView AbsoluteSize layout reparenting an already destroyed Notice. The UI owner added retirement before descendant destruction, disconnected geometry/input/egg clocks, canceled the preview, and fenced layout/render/update/selection callbacks. HatchNativeHost now has a third case exercising a scrolling Notice, destruction, queued callback drain, and inert late update. Both legacy RevealStage view constructors now explicitly select nativeDisplay=false because those cases inspect the old DeckKit button implementation. Four affected files compiled; native rerun and independent targeted source review requested. No receipt transaction or input protocol changed.
