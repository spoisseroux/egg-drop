# Approved hatch host integration

2026-11-14 · UI Sol · implementation staged against backlog's agreed native APIs. Revised preview was shown and Astra reviewed actual corrected output; implementation is authorized. No additional user approval gate. No publish.

## Staged host code

- `EggHatchView.showRevealStage`: forwards the exact committed `result`, same `scene` and `externalClock`; returns the Stage handle for native borrowing, retaining legacy `true` when no scene is provided. The host never creates or destroys the shared scene; existing `stage:destroy()` releases its borrow through the Stage implementation. Existing receipt ID, presentation generation, ack/retry and action callbacks are preserved. Companion `Cinematic:play` sets `nativeDisplay=true`.
- `HueItemReveal`: production defaults `nativeDisplay=true`; exposes `inputLocked` and `receiptReady` through the cinematic state API. Reads `getItemGraphic()` for native display and does not dereference old shell internals. Exact same-result reuse does not relock while decorative animation continues. Existing receipt/assignment actions still use the cinematic's Skip/input drain; the native owner must return false from Skip after receipt readiness. Explicit `nativeDisplay=false` remains the legacy fixture path.
- `EggPreview3D.cloneTemplates()`: returns nil until its existing three-part cache is ready; otherwise returns independent cloned BottomShell/TopShell/Core. The scene owns those clones. This adds no loader, callback, shared-template mutation or asynchronous clone path.

`HatchNativeHost(client,parent)` is a two-case host-contract fixture using real host/adapters with synthetic scene/cinematic interfaces: readiness while the decorative owner remains active; same-ID reuse/reopen; no access to absent legacy internals; exact borrowed scene/result identity and no host destruction of cinematic ownership. It does **not** claim native art, scene contact, asset loading or audio validation. `HueItemReveal.spec` explicitly exercises old legacy compatibility; the new native sampler/scene/lifecycle tests belong to backlog. All host/spec source compiles. Native/backend tests wait for backlog's coherent source/asset readiness.

Architect review GO WITH CHANGES requires single scene ownership, external-clock Stage without another intro RenderStepped, receipt-ready callback distinct from decorative completion, same-input drain, scoped native reveal face hook preserving source smile and actual blink, floor/swept envelope proof, native UV-preserving lower-shell halves and owner-safe audio duck recovery. The approved direction is not a reason to relax those tests. Missing assets must remain an honest settled usable receipt.

UI Sol retains init.client, UICopy, EggHatchView, HueEggView and existing item-host glue; backlog owns production cinematic/stage/new adapters, scoped renderer hook and audio. Exact text/audio host blocks are applied when supplied. No transaction, grant, price, odds, receipt acknowledgment or remote protocol change is part of this host work.

## Current verification and teardown follow-up

Coordinator ran current-disk Host2, HueItemReveal5, NativeCinematic1, Pose4, NativeFrustum1, AudioDuck3, LoopAudio16 and AmbientAudio7 green. Both legacy RevealStage View constructors now explicitly use nativeDisplay=false; they inspect legacy Stage/DeckKit buttons rather than the new native helper.

A real native fixture error exposed late AbsoluteSize layout reparenting a destroyed Notice. EggHatchView now retires before descendant destruction, disconnects input/geometry/egg clocks, cancels the preview and invalidates queued selection work; layout/render/update refuse a retired or unparented shade. isOpen and ownsInput also immediately return false for that owner. HatchNativeHost now has a **third** real-host teardown case asserting scrolling Notice ownership before destruction, inert late layout/update, disconnected links and no remaining input ownership. Backlog's targeted source review requested this last owner-state check; it is applied/compiled. Coordinator rerun remains pending.
