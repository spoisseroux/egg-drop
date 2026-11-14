# v634 QA — menus and global UI implementation plan

2026-11-14 · Sol · **plan only, awaiting architect review and Astra QA brief**. No runtime edits made for this QA slice. Current unpublished onboarding/server changes stay frozen while coordinator verifies them. No publish. Blip/alien work is parked. **Hatch animation and reveal redesign require showing Spencer the idea first**: no production HatchCinematic/RevealStage edits belong to this plan.

## Reviewed implementation contract

**Architect GO WITH CHANGES received from systems Sol; Astra's `CREATIVE-BRIEF.md` is now read and governs visual details.** Runtime work still waits for the coordinator to finish the previous Welcome HUD verification. The exact decisions here supersede provisional alternatives in the component discussion below:

- Rail: one short line, 20px icon, preferred height40, max width300 at812×354; free topbar origin+8 and safe-right margin12, vertically centered with the Roblox capsule. Fade180ms / dwell3500ms / fade180ms. Defer nonurgent tips when the horizontal space cannot fit; no multi-line or centered fallback. Urgent save failures remain in their dedicated actionable flow. Coach detail lives in existing `?` help; compact first-use capsule may open it. TopbarInset is the unoccupied rectangle; never interpret its Max.X as the occupied controls' right edge.
- Focus: one geometry owner computes outer Back48×48, Pickup48×48, bond card48 high/content width150–190, gap8. Preserve all hearts and update petting/care exclusions from the final row. Exact styling radius12; do not let independent ownership re-anchor the pieces.
- Preview wells: one rounded inner clip; intact outer border and seam reserved6px inside the card. Help icons24 in32px wells; full body wrapping/scrolling, fixed footer, body floor12px. Never clip a paragraph to preserve a large picture.
- Disabled buy: filled face `#344545`, lip `#1F3030`, label `#AAB8B5`, border `#60716E`; same bounds, price retained, no hover/press motion or spend. Reserve the actual shortfall line's height. Only one quiet cue per accepted logical action; muted settings still apply.
- Preview personality: the main Bear preview gets a bounded idle interval7–12s as well as optional selection response; stop during rotation/drag, closed/offscreen state and Reduced Motion. Do not animate every cached card or change the equipped world pet.
- Readiness: timeout uses an intentional placeholder and offers retry, with route/selection generation fences. Continue usable navigation and avoid gray ready meshes; do not block every menu behind an unbounded preload.
- New background: append **Moonpond**, free for this repair batch, following Astra's exact palette/arc/dot contract. Static by default; no new reward, price, migrated id or old unlock change. Procedural actual previews require Astra critique.

## Evidence and goals

Source: `notes.md` and the copied original screenshots in `shots/`. Inspected the actual 14:42:17, 14:43:36, 14:44:48, 14:46:39, 14:47:18, 14:50:59, 14:52:24 and 14:54:30 images.

| QA evidence | Observed problem | Result to deliver |
|---|---|---|
| 14:42:17 and 14:44:48 | Large centered coach card covers garden/shop header; notices draw over current content. | One compact capsule to the **right of Roblox's top bar**, above game menus, with actual safe-area placement. |
| 14:43:36 | Pickup arrow overlaps the bond/hearts card. Back and pickup are shorter than the card. | Measured row: Back at left; bond card immediately left of Pickup at right; all three have equal physical height and no overlap. |
| 14:46:39, 14:50:59, 14:52:24, 14:54:30 | Border strokes/seams are cut at panel/list edges; square preview content survives under rounded frames. | Complete borders and a genuinely rounded preview mask, with a separate intact outer stroke. |
| 14:47:18; other menus requested too | Help body text becomes a single clipped line, despite a large icon area. | Every help set fits its complete localized text; smaller art and measured body space, scroll/reflow only where needed. |
| 14:44:48 and 14:52:24 notes | Gray eggs or incomplete textures show while content loads. | Prewarm likely content before entry; a bounded gate and intentional fallback prevent gray first frames and indefinite waits. |
| 14:50:59, 14:52:24 | Disabled Buy loses its surface; shortfall is inconsistent. | A clearly drawn, inert disabled button and the **actual positive Stars shortfall** at every Stars purchase. |
| 14:50:59 | Menu actions lack sound; preview Bear is static. | Quiet accepted-action feedback and restrained occasional preview reactions, respecting mute and Reduced Motion. |
| 14:54:30 | New background requested. | One original procedural background, only after Astra provides the creative contract; existing backgrounds/ids remain valid. |

The new first-spend and Welcome affordances must use these same owners after integration. Their transaction, grant, timer, navigation and acknowledgment fixes remain intact.

## Ownership and integration boundaries

This lane is allocated DeckKit, CoachCards/toasters, PetFocusUI, shop views, help modules, loading helper and new background tooling after review. Existing init.client and UICopy remain this lane's shared hosts; other QA workers provide exact glue blocks. `DeckScreen.lua` transfers to systems Sol **after coordinator's current baseline verification**; do not edit it in parallel. Coordinate exact focus/Pickup geometry with the `GardenCareClient` owner, because Pickup is created there, not in PetFocusUI. Source files added below are proposed ownership, not permission to overlap another lane.

Expected source touch list: new `NotificationRail.lua`, `UIAssetWarmup.lua`, `ShopPriceState.lua`, optionally `PreviewFeedback.lua`; `DeckKit.lua`, `CoachCards.lua`, `PetFocusUI.lua`, `HowItWorks.lua`, `EggHatchView.lua`, `EggPreview3D.lua`, `FaceplateShop.lua`, `BackgroundShop.lua`, `BallShop.lua`, `WardrobeShop.lua`, `HueEggView.lua` and item buy panels where their distinct button/shortfall owners require changes. Limited init.client/UICopy glue. Existing art/background files only after Astra's brief. Root coordinates any GardenCareClient/RoomView or DeckScreen changes with their owners.

## 1. One top-bar notification and coach owner

Current `Kit.toaster` creates a separate centered queue under every caller's host. CoachCards separately builds a large centered garden card; DeckScreen/CoachCards/BugReportSheet override toast placement. Thus changing one default coordinate cannot fix the screenshots, global layering or simultaneous queues.

Create one client `NotificationRail` with a dedicated ScreenGui above game sheets. Use `ScreenInsets.TopbarSafeInsets` and react to actual inset/root changes; map coordinates exactly once. Roblox documents TopbarInset as the **unoccupied** top-bar rectangle, not the rectangle occupied by its controls. Its boundaries are dynamic. Do not guess the right edge as a fixed 116px or add Core/Device insets twice. Verify rectangle conversion with actual CoreGui measurements on coordinator's client. References: [GuiService](https://create.roblox.com/docs/reference/engine/classes/GuiService), [ScreenInsets](https://create.roblox.com/docs/reference/engine/enums/ScreenInsets).

Proposed contract: `enqueue(owner, key, {title?, text, amount?, icon?, duration?, acknowledge?, dismiss?}) -> handle`; `handle.cancel()`; owner destruction removes that owner's queued/presented work and disconnects listeners. One presented capsule, bounded queue, stable-key deduplication, generation-fenced delayed hides, and no per-frame instance creation. Receipt/save failure notices outrank cosmetic nudges without interrupting irreversible acknowledgment state. No player data is stored.

Park integration (systems Sol): expose `status(owner,key,initial) -> handle:update({text,icon?,active?,priority?}), handle:cancel()` for persistent low-priority fallback content. Updates compare fields and reuse the same provider, never enqueue once per frame. Every queued notice outranks persistent status; show one stable highest-priority active provider only when the queue is empty, preventing park status from starving awards/coaches. Owner destruction removes both queued and status work. Park facade should register one provider for the current exact membership site, not duplicate arrival/grove chips. Tests cover queue preemption, return to the latest status, idempotent update and owner cancellation.

Default visual proposal for Astra: left-align in the free top-bar area with a small gap after Roblox controls; quiet rounded dark glass, compact icon, short text and optional Stars value; max width around 360px but bounded by actual free width. Use the top-bar row rather than a centered banner below it. No tooltip or help overlay should cover the capsule. Preserve readable body type and all meaningful copy. For narrow free areas, measure first and reduce decoration before using measured multi-line compact copy; **Astra must settle the fallback when the complete instruction/action cannot fit**. Never overlap Roblox controls, silently clip teaching text or shrink a dismiss action below its accepted touch target.

`Kit.toaster(host).show(message,stars)` becomes a compatibility adapter into the shared rail; existing callers do not each create another ScreenGui/queue. Reconcile the three explicit placement overrides so they no longer move global notices back over the screen. CoachCards keeps its saved bits, garden beat progression, Skip/Got it/Say hi semantics and pause gates, but presents through the compact rail owner. Preserve exact acknowledgment timing: a queued/superseded card is not counted as seen. This is a presentation change, not an automatic skip of teaching steps.

Audit other notice owners, including ItemCarousel grant pills and care notices, and move global notices into the same rail. Keep direct field validation beside its field and action-local heart/Star effects with the action they explain; list every remaining owner in the result artifact so “across the board” is not inferred from only the first toast screenshot.

Tests: changing top-bar safe rect/notch/GUI insets; two simultaneous hosts; deduplication/queue cap; priority; owner destroy; a late timer cannot hide the next item; no double acknowledgment; coach pause/replay/Skip and existing coach bits unchanged; PC/812x354/narrow free-area fixtures with actual bounds above menus. Screenshot actual Roblox top bar alongside the capsule.

## 2. Focus row: bond card, Pickup and Back

Current PetFocusUI anchors BondCard to the top-right 12px margin and sizes it from pips/name/label; GardenCareClient anchors Pickup to that same point and fixes it to 44x44. The screenshot is consistent with two independent owners choosing the same space.

Define one pure row geometry helper, owned by PetFocusUI, receiving safe root size, measured bond width/height, Pickup availability and text preference. Let the bond card's measured height set the row height (at least 44px); make Pickup and Back square hit rects of that same physical height. Anchor Pickup at the existing right-safe margin, card to its left with an explicit gap, and Back at the left-safe margin. Compact card may shorten decorative padding before clipping any heart or level meaning. Equal-height applies after physical scaling. Height/width changes update only on actual layout/preference/bond changes.

Provide GardenCareClient the exact pickup rect through an API/callback; update `carePickupWidth` and focus/petting hit exclusions from the final rect, not stale 44px constants. Care ownership, carry requests and camera/input locks stay unchanged. Explain hearts in the existing help copy using actual `BondCatalog` progression/tricks; do not invent a currency multiplier or petting reward.

Tests: all bond levels, localized pet/level names, PreferredTextSize, pickup shown/hidden/pending, Room/focus/care transitions, card left of Pickup, equal heights, no intersection with Back/CoreGui or petting hit region. Actual focused Bear captures at desktop and 812x354.

## 3. Borders, seams and preview masks in every shop

Inspect Hatch eggs, Companions/Customize, Wardrobe and all Deck style tabs in their real compact and regular owners. Capture clipping ancestors and stroke bounds before edits. `Kit.card` adds outer stroke/seam; scroll views and full-size child previews can clip those independently. Existing `scrollBleed` is already used in BackgroundShop/BallShop, so do not blindly add a second bleed or disable every scroller's clipping.

Use a consistent separation: unclipped outer card/stroke within reserved scroll padding; an inset rounded `CanvasGroup` or equivalent proven GUI mask owns preview content; camera/Viewports/images/pattern overlays stay inside that mask. A plain Frame's UICorner does not by itself establish descendant masking. Preserve required list clipping, scrolling and focus visibility. Inset row selection/focus strokes sufficiently that all four sides survive the first/last row and right edge. Preserve preview camera framing, current grid column counts and actual hit targets.

Tests: first/last/selected rows at scroll extrema, 1/2/3-column layouts, preview corner sentinel colors outside the rounded mask, stroke bounds within clip rect, long title/chip/price rows, tab-scroller extremes, theme variants and transparent patterns. Actual screenshots for every shop family, rather than one shared component assertion alone.

## 4. Help cards: measure complete text before art

`HowItWorks.layout` already measures text and tries to shrink pictures, yet the screenshot displays a clipped single line. Inspect the constructed labels and Kit.text/type defaults as well as computed heights; do not assume icon size alone is the cause. Current help always lays every card side by side and retains a relatively large illustration/title allocation.

Build from text requirements: measured body width/height for the actual font/PreferredTextSize/localization, complete title, then bounded compact illustration (starting around 28–32px, exact Astra rule pending). Set explicit wrapping/truncation behavior on body labels and allocate the measured height after final styling. Reduce picture and decorative padding first. If full text plus footer still exceeds the available safe height, use an inner vertical scroll area or reviewed fewer-column layout, keeping the close/Got it controls fixed and reachable. Never shrink body text until it becomes unreadable or crop the end of a sentence.

Walk **all** `How.Sets`: Hatch, Deck style, Companions/Wardrobe/Customize, Quests/stamps, Book, Park and Settings/help entries. Update bond explanation from real rules; stamp copy must describe existing once-daily stamps, not suggest egg hatches award stamps. A proposed relocation of stamp UI is a separate product decision; no duplicate stamp grant or new save field.

Tests: every localized body/title fully contained or reachable by scroll; footer does not cover text; regular/812x354/640x360/portrait, preferred text sizes and pseudo-locale; stamp illustration; keyboard/gamepad focus and B/Back; Resize while open; same-size reopen no leaked instances/connections.

## 5. Prewarm assets with a bounded fallback

`EggPreview3D.loadTemplates` loads meshes, marks ready and later assigns per-type texture IDs; that does not prove the color map is fetched. Faceplate images likewise have no inspected prewarm gate. Extend readiness to include the content actually rendered, not only MeshPart creation.

Add `UIAssetWarmup` with deduplicated groups, bounded batch size/concurrency, one in-flight request per asset/group and injected clock/loader for specs. Prewarm initial egg meshes/maps plus likely first menu assets during existing noninteractive boot/idle. Warm the selected/visible faceplate and preview textures rather than all wardrobe assets at once. Use `ContentProvider:PreloadAsync` callbacks/statuses and actual existing asset readiness where relevant. No new uploads are needed for this fix.

Menu entry may await a short bounded gate; failed/unavailable assets use existing authored/procedural 2D placeholders and the menu remains usable. Continue background loading without an infinite spinner or repeated request storm. A late result must match current open route/generation and selected item; Back, tab change or another menu cancels delayed opening/upgrade. Show a 3D egg only after both its meshes and currently selected texture are ready; keep the existing fallback visible until then. A timeout cannot turn a gray untextured mesh into the claimed ready result.

Tests: cold cache, warm cache, slow/failing mesh/texture, one missing content id, timeout, changed egg type, Back during warmup, repeated open/close, owner destroyed and late callbacks; maximum concurrent loads/instances; no duplicated preload across visible previews. Actual first-open captures after a cold client, not just warm reopens.

## 6. Disabled buttons and consistent actual shortfall

`DeckKit.baseFill` currently uses transparency .4 for disabled fills, hides their lip and dims label further. Revise disabled styling to retain an opaque/clearly visible muted button surface and outline while keeping `Interactable/Active` and action guards false. Astra supplies exact palette/contrast; do not use opacity as the only disabled signal. Enabled, pending, owned/In use, locked and Retrying stay distinct.

Add a pure shared Stars purchase state/shortfall helper or use one reviewed existing equivalent: positive difference = `max(0, effectiveQuotedPrice - confirmedWallet)`. Feed the actual discount/price already selected by ShelfDeal/catalogs; no duplicated price constants. Use one localized shortfall line near every Stars purchase button. Audit Faceplates, Balls, Wardrobe, Hatch eggs and Hue/Material/Toy/Feature buy flows, plus any fixed Stars unlock found during the audit. Backgrounds currently are earned, not bought: retain their real unlock reason, never fabricate a Stars cost. Do not change Robux policy, catalogs, odds, transactions or reward values.

Tests: wallet 0 / price-1 / exact price / surplus, weekly discounted/full price, wallet changes while open, pending save, retry, already owned, locked progression, no spurious shortfall on free/owned/earned backgrounds. Disabled mouse/touch/gamepad activation sends zero purchase commands. Cross-shop copy uses the same exact number and plural rules.

## 7. Quiet interaction feedback and preview personality

Route accepted menu presses/tab changes through one small feedback owner using existing BoardAudio cues and mute/music/SFX settings. Deduplicate a Kit-level cue and an existing host `accepted()` callback for the same action so one press does not play twice. Disabled actions remain inert. Preview reactions run only for the selected main preview on meaningful accepted user selection/interaction, with a cooldown and injected randomness; no reaction per refresh, every card or every frame. Astra sets the restrained blink/head-tilt/hop vocabulary. Reduced Motion uses a static expression response. No gameplay pet action, currency or mastery changes.

Tests: accepted action one cue, duplicate plumbing one cue, disabled zero, muted zero, rapid navigation cooldown, selection unchanged zero reaction, preview offscreen/closed/destroyed zero work, deterministic chance injection and Reduced Motion.

## 8. One new background after Astra brief

Read `DeckBackgrounds`, `PatternBackdrop` and AppearanceCatalog before choosing a new id. Append, never renumber/remove existing identities. Astra supplies original pattern, palette, motion, name, unlock rule and tiny thumbnail requirements. Implement through the current procedural background owner, with one registered animation clock and static Reduced Motion. The new id must preview/equip/save/rejoin and appear consistently on the board, exterior and shop thumbnail. Do not infer a new price, progression reward or unlock solely from this QA screenshot. No AI image generation; render actual procedural art for Astra review.

## Order, review and acceptance

Architect review of this plan first; incorporate Astra's exact QA brief before visual choices. Implement notifications/focus geometry → help fit and shared disabled/shortfall rules → per-shop clipping/readiness/feedback → approved background. Independent code review after each meaningful ownership batch, fix blockers, compile actual entry points and retain 219 client column-zero locals. Coordinator owns Studio, live fresh-clone tests, actual screenshot evidence, TODO/integration and later localization export/sync. No commit/publish by this lane.

Final evidence must map each screenshot timestamp to changed owner, test result and matched after capture. Physical phones, cold service-backed content fetch and runtime CoreGui behavior remain labeled unverified until actually exercised. Existing onboarding, report sharding, park/fetch and telemetry work must remain preserved; do not reuse old cached requires as new-source verification.
