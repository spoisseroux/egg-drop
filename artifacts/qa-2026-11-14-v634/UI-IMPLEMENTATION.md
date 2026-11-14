# Global/menu QA UI — frozen review snapshot

2026-11-14 · Sol implementation under reviewed QA-UI-PLAN and Astra CREATIVE-BRIEF. **Frozen for independent review and actual Studio fixtures. No publish.** Exact current source sizes/hashes: `UI-FREEZE-SOURCES.json`. Existing Welcome milestone evidence is finalized in `../remaining-build-2026-11-14/ONBOARDING-IMPLEMENTATION.md`.

## Implemented

- `NotificationQueue`/`NotificationRail`: one global bounded queue and topbar capsule, one-line40px/max300, fade180/dwell3500/fade180; dedupe, owner cancellation, deferred narrow layouts and persistent Park fallback preempted by real notices. Actual coordinator fixture caught rootY=-58; placement now converts the physical TopbarInset rectangle minus measured root origin exactly once. The coordinator observed corrected physical position216,9 with125×40 size; isolated cloned singleton recreation was then fixed with an owned-GUI seam and shutdown. Final real-module rerun remains pending.
- DeckKit toaster compatibility adapter routes old shop/report/deck notices into the same owner. CoachCards' large legacy cards/pills remain hidden; compact coaches use rail, preserve pause/grant/arrival state, and mark one-time tips only after actual presentation. First-spend CTA uses a rail status, preserving its exact saved-proof/navigation fences. Park integration is supplied by systems Sol.
- `FocusRow` computes Back48, Pickup48, bond48 high/150–190wide with8gap. GardenCare binds its existing button to this sole geometry owner. Pointer exclusions include bond/pickup; care authority unchanged.
- HowItWorks measures complete titles and paragraphs with inherited1.25 line spacing;24px icons in32px wells; portrait column fallback; bounded scrolling body and fixed footer. Full sentences are allocated rather than truncated. Text measurement cache includes PreferredTextSize.
- Disabled DeckKit buttons retain filled face/lip/border and readable price in Astra's palette while inert. Systems Sol supplied the equivalent native DeckArt.control change. `ShopPriceState` supplies exact positive shortfall to Faceplates/Balls/Wardrobe/Hatch and legacy item-buy status slots.
- Rounded CanvasGroup masks with one outer border cover Wardrobe/Ball/Background/Hatch/Customize preview wells; Faceplate miniature deck masks/preload placeholders added. Existing panel/grid/control geometry is retained.
- `UIAssetWarmup` reuses existing readiness queue accounting, deduplicates assets, caps2 engine requests/16-per-batch/128resources, times out to fallback, cancels route/selection listeners and supports bounded explicit retries. Egg viewport stays hidden until selected texture and mesh templates are ready; type change restores authored2D fallback, failure exposes Retry preview. Idle prewarm starts before usual menu entry. Faceplate thumbnails use intentional outline fallback until their exact image group is ready.
- Quiet enabled-button click cue at the client host;60ms dedupe shares existing accepted-action handlers and existing volume/mute audio owner. Main Wardrobe/Customize previews get7–12s existing-pose wave/tilt/smile cues, cancelled during input, Reduced Motion, hidden/closed and owner changes; cached cards/world pets unchanged.
- Moonpond is appended free after all existing background IDs. `MoonpondBackdrop` is native procedural geometry: six sparse broken oval arcs/five edge dots maximum, field dots suppressed, quiet center, static default and actual-case exclusions. Systems Sol supplied exterior/board/thumbnail delegates.
- Systems' results glue: actual device view/case rectangles; four-way navigation; visible Quests callback; difficulty changes send only existing heat selection, with2s/run-fenced label fallback; Replay alone resets. Hatch route remains available after a pet exists. Effort receipt1 says Good effort; goal-loss2 unchanged.

## Verification and coordinator invocation

`python scripts/testhelpers/run_qa_ui.py`: **19PASS** (NotificationQueue8, QAUIState4, UIAssetWarmup7). This executes real Luau queue/readiness/state implementations with engine services shimmed. Timeout tests prove stalled engine loads retain concurrency slots; late callbacks cannot satisfy a cancelled selection. Pure row tests cover320/390/640/812/1280 and pickup shown/hidden.

All28 frozen runtime/spec files compiled using `luau-compile --null`; actual init.client compiles and retains219 column-zero locals. Compilation is not visual acceptance.

Fresh/cloned current-disk client specs (coordinator owns Studio):

- `NotificationQueue(client)` →8; `QAUIState(client)` →4; `UIAssetWarmup(client)` →7.
- `GlobalUIBounds(client,PlayerGui)` →10: actual capsule coordinates versus physical Roblox TopbarInset,40px/max300, disabled Kit/native state. This test caught the real Y bug before correction. It now uses Rail.view() and also proves distinct equal-value awards queue separately while explicit operation IDs dedupe. Must rerun current corrected source.
- `HelpCardsBounds(client,PlayerGui)` →36: six help sets×812×354/640×360/390×700×normal/pseudo. Actual wrapping/TextBounds, keyboard/gamepad scroll to the last card and back, scroll reachability and fixed footer; restores pseudo state/root size after execution.
- `QAPreviewBounds(client,PlayerGui,{keepFixture=true})` →7 and leaves `_QAPreviewBounds`: actual rounded-mask sentinel, field/static Moonpond and case-exclusion samples. This is an actual fixed-size GUI fixture, not a phone emulator. Capture for Astra; coordinator removes the kept fixture.
- Recheck previous `WelcomePresentation`, `WelcomeHUDBounds`, `FirstSpendGuide` and ClientLocalBudget after host integration; this lane has not claimed those old GUI tests against new QA runtime.

## Pending acceptance / parked refinements

Independent code review, corrected rail live bounds, all GUI fixtures and Astra actual screenshots are pending. Physical devices, service-backed reconnect and translated production text are not implied. Full real-menu screenshots are still needed for Hatch/Customize/Wardrobe/Faceplates/Backgrounds/Balls at first/last rows and cold first-open; native rounded-mask compositor behavior and complete name/odds fit must be judged from actual captures. Detailed long-name/chip reflow and further preview camera/animation refinements are parked during this freeze.

Remaining notice audit: ItemCarousel's local item-grant pill and GardenCare action-local notice remain existing owners; urgent save notices stay dedicated actionable flows. No claim that every unrelated notice has migrated. No source economy/catalog price, odds, transaction, reward or grant changes belong to this lane. Music and hatch tooling review was source-only GO; production hatch redesign remains behind Spencer's idea-preview approval. No Blip, upload, install, commit, watched-file deletion or place publish was performed.


## Independent review fixes — current frozen revision

Systems Sol review GO WITH CHANGES (`UI-INDEPENDENT-REVIEW.md`) identified inaccessible help overflow under directional-key sinks and accidental deduplication of distinct identical awards. Both are fixed: Up/Down/W/S/DPad scroll the bounded body while preserving footer/Back ownership; toaster uses a per-show identity by default and accepts an explicit stable operation key when supplied. ActualGUI fixture regressions cover both. Narrow320 focus row now caps the bond card to184px so Back gap stays8px; unmeasured/zero-size initialization stays safe and level label uses the final card width. Missing quest accessibility copy `hub.quests.title` is added. Rail exposes own-view lookup and explicit destroy, automatically disconnecting on ModuleScript destruction; Warmup also releases its Heartbeat on clone destruction. Offline19 and affected source compilation remain green. Exact hashes refreshed after these review fixes; actual Studio rerun/review acceptance remains coordinator-owned.


## Coordinator current-disk native results and final geometry repair

Fresh coherent Client Play reports GlobalUIBounds10PASS (actual physical capsule216,9), HelpCardsBounds36PASS, InPlaceResults5PASS, RecapFeedback11PASS, DeckResults16PASS, WelcomePresentation5PASS, FirstSpendGuide3PASS and ParkClient10PASS including live facade. Missing quest key is resolved. Systems Sol targeted re-review GO for all required UI fixes; Rail cloned-module cleanup no longer recreates duplicate named GUIs.

QAPreviewBounds initially failed its full-case exclusion assertion because wholly offscreen arc segments retained Visible=true despite native parent clipping. The renderer now explicitly culls offscreen segments and uses conservative padded AABBs for line thickness, UDim integer quantization and antialiasing before actual-case rejection. Reflection exclusion now uses its rotated rectangle's calculated AABB; dots also cull against the viewport. Partial-case fixture asserts every visible segment intersects the viewport and clears the case. These2files compile; offline19 still passes; this last native fixture rerun/Astra actual preview remains pending.

Independent review of systems' final board text/entrance fixes is GO: row/goal height includes actual LineHeight, fifth nativeGUI case checks true wrapped TextBounds plus6px spacing, and opening timestamp resets only for a new opening. Jelly technical architecture reviewed GO for isolated native proof first, with no runtime implementation/activation from this lane.


## Native mask constraint and first-toy handoff follow-up

The coordinator's actual pink-sentinel capture disproved visual rounded-mask acceptance despite structural7PASS. Roblox documents CanvasGroup flattening only under a Sibling LayerCollector. Source audit found Hatch/Customize/DeckStyle share default-Global EggDropOverlays; Wardrobe/Companions/Book/Deck/Help already use Sibling. After scoped architect GO, only EggDropOverlays is explicitly Sibling, preserving its audited modal/safe-content/route/shade/handoff ordering. Preview fixture is now explicitly Sibling with sentinel above fill; it also asserts every mounted rounded-mask owner is Sibling. Actual menu/header/back/focus/receipt-dim and route-transition captures remain required; prior structural assertions are not a visual pass. Reference: https://raw.githubusercontent.com/Roblox/creator-docs/main/content/en-us/reference/engine/classes/CanvasGroup.yaml .

The real first Toy Give saved the exact equip andack, charged8 correctly andclosedUI, but no beat appeared. Confirmed defects: follow-only readiness deadlocked against stationary autonomous rest, and Give used elapsed visual.time while normal personal play uses absolute cosmeticTime/serverNow. Systems Sol owns the strict shared PersonalToyOpportunity resolver and normal RoomView/Companions/Play integration: a short existing clip fits the published safe ordinary rest without changing server duration, park/care/contact/focus/pair/reservation/movement vetoes remain, exact activity token cancels takeover,9–16s normal cooldown remains.

UI host is extracted as FirstSpendToyHost for a meaningful regression. It uses the normal shared clock, asks Play.sample first, never rewinds quiet time, preserves a cooldown when observing an already-started prop, offers one pending opportunity, and confirms only actual ToyActive/sample proof. Guide retains pending handoff until true, checks navigation generation again after callback, and rejects a replacement character/pet identity. Marker OnboardingToyBeat is set only on actual normal prop activation. New FirstSpendToyHost(client,parent)3 native cases combine exact saved equip receipt +realGuide+Factory+normalPlay+published1.5s rest; tests distinguish elapsed/server clocks, existing active cooldown and park/replacement refusal. FirstSpendGuide is now4offlinePASS; solver2002/WelcomeState4 unchanged. All affected files compile and client remains219 locals. Native host3/Opportunity5/Guide4 and actual Give beat rerun remain pending.


## Native confirmation and coordinate-basis correction

Coordinator actual latest regressions: FirstSpendToyHost3, PersonalToyOpportunity5, FirstSpendGuide4, PetPersonalPlay17 allPASS. The scoped Sibling mask fixture7 now renders a genuinely rounded pink sentinel in native Studio; prior Global structural7PASS was not a visual pass. Actual first-Give phone flow remains a separate observation.

A later native phone capture also disproved the rail's earlier absolute-coordinate bounds assertion: root.AbsolutePosition=(208,-58), pill.AbsolutePosition=(216,9), GetGuiInset.TopLeft=(0,58), physicalTopbarInset=(208,0,801,58), yielding physicalpillY67 below the bar. The rail now maps physicalTopbar.Min minus measuredGuiInset minus measuredroot.AbsolutePosition, plus inset-local geometry. Expected UIAbs=(216,-49), physical=(216,9). GlobalUIBounds now asserts physicalPosition=AbsolutePosition+GetGuiInset and prints both coordinate bases. No58px constant is used. This latest rail/native capture rerun is pending; earlier passing bounds must not be treated as visual acceptance.

Production hatch/music implementation is now authorized after the revised preview was shown and Astra's actual GO; the earlier idea-preview gate is satisfied for that accepted direction. Backlog owns production cinematic/stage/audio/newadapters; this lane retains host glue and UICopy. Architect review GO WITH CHANGES requires explicit persistent-scene ownership/cleanup, receiptReady/inputLocked separate from decorative clock, scoped native face hook and owned600ms min-gain duck recovery. No repeat user approval is requested. No publish.
