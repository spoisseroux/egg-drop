# Remaining feedback rail migration

2026-11-14 · source staged/frozen; no publish.

Backlog architect GO: finish the already approved single notification owner, without changing carousel or carry controls. `ItemCarousel` now sends empty/full feedback and one-line item grants (glyph, item name and star-ball origin) through NotificationRail. It creates no Note/Grant overlays. Each accepted feedback call has a distinct serial; destruction cancels the owner and late calls are inert.

`GardenCareClient` now sends refused-action feedback through the same rail. Seven localized concise messages fit the one-line contract; reason and exact operation sequence stay attached. Existing terminal-operation removal prevents duplicate notices, stale-character callbacks remain inert, and a callback that retires the client cannot enqueue afterward. Carry transport, ownership, save and dedicated urgent-save flows are unchanged. The former CareNotice widget is absent.

Changed runtime: `src/client/ItemCarousel.lua`, `src/client/GardenCareClient.lua`, `src/shared/UICopy.lua`. DeckScreen and rail placement geometry are unchanged. Separately, the reviewed EggHatchView retirement fix now makes both isOpen and ownsInput refuse a retired/unparented shade immediately.

Verification: affected 12 Luau files compiled. Actual offline Care transport 13 and RailFeedback queue 3 pass; NotificationQueue 8, QAUIState 4, typed UIAssetWarmup 10 remain green. `scripts/testhelpers/run_rail_feedback.py` runs real feedback/transport/queue source with only engine/UI dependencies injected; it is not a render claim.

Coordinator native rerun: ItemCarousel, DeckRoundQA, GardenCareClient 13, GardenCareStartup 2, RailFeedback 3, GlobalUIBounds 11 (adds actual font measurement of every new feedback line). Host teardown: HatchNativeHost 3 and RevealStage with both explicit legacy seams. Independent code review requested from Backlog; actual live feedback capture and current-disk native tests remain separate gates.

Native fixture correction: the first RailFeedback run exposed its invalid `chip={}` mock when real DeckKit.boing called Instance methods. The fixture now creates an actual Frame owner and child BeltChip, asserts the native BoingScale under ordinary motion, and destroys every owner in cleanup. Production animation is unchanged. Canonical and ZZ mirror compile; offline helper now runs Care13 only because this Feedback3 fixture deliberately requires native GUI Instances. Coordinator native rerun and targeted review requested.
