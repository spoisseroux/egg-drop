# Egg Drop UI redesign overnight — 2026-11-07

## Active request and checkpoint

User reviewed the actual screenshots and rejected their design coherence. Work through 9 AM America/New_York, November 7, 2026; then finish a safe checkpoint, publish only tested/reviewed private changes, give a self-contained screenshot rundown and pause the existing heartbeat. Branch `feat/egg-drop-arcade-polish`; starting commit `1cd0927` (implementation `6c73611`), private place96451847774961 version48. Preserve untracked `artifacts/ui-pass` evidence and unrelated user files. Never target `roblox_suica_collector`.

## Success criteria

A readable, coherent set of real game screens across PC, landscape phone and portrait: bounded handheld proportions, no clipped art/text, a clear reward-first recap, appropriately sized family progress, consistent surface/type/icon/button vocabulary, and transitions that cannot open through a menu. Fix the result Close caption to a corner X while retaining acknowledgement/cancel behavior. Preserve the egg choice layout and illustrations the user liked.

Astra owns reference-grounded design and architecture (`UI-DESIGN-SYSTEM.md`) plus implementation/screenshot critique. Sol implements the approved client modules and tests. Root coordinates Studio, integration evidence, commits, private publication and scheduling. Follow review-driven-build; the user has authorized autonomous implementation and iteration without another approval stop.

## Current diagnosis

- Shell width1150 and height620 are independently capped. Height-derived tray width355 leaves approximately385px grips, while controls stay44–90px. This is structural leftover-space sizing, not a PC screenshot stretch.
- Boot lives under a different ScreenGui from the recap and runs without exclusive modal ownership.
- Menu body starts at0 and can retain old CanvasPosition on fresh open. Its first illustrations/strokes can clip at the scroll edge.
- Mastery uses132px rows with tiny shrinking text and large hint slots.
- Recap is limited to300px height and440px width on desktop and repeats several reward/score concepts without a single dominant hierarchy.
- Hatch result close retains literal Close inside a44px square.

## Coherent implementation sequence

1. **Design and architecture:** inspect first-party Roblox game screenshots plus official Roblox adaptive/accessibility guidance. Define source-backed rules, original art direction, shared tokens, component states, responsive geometry and acceptance matrix. Review the full plan before code.
2. **Foundation and handheld:** shared role typography, spacing, material/button/header rules; bounded rails and height-driven board without changing physics aspect. Fix modal/boot input and presentation ownership before overlay styling.
3. **Menus and progression:** content-sized menu, top-safe illustrations, reset fresh-open scroll, legible family cards, graphical compact contracts, result X. Keep egg choices and every purchase/acknowledgement guard.
4. **Recap and visual review:** earned nectar first, clearly separated score/best and bank progress, details on demand, pinned next actions. Preserve committed receipt authority and animation cancellation.
5. **Acceptance and delivery:** native tests/build/console, actual controls, screenshots at desktop and mobile-sized fixtures, Astra visual critique, fix/retest, commit/push and verified private publication. Each reviewed working slice finishes before a new one begins.

## Explicit edge cases

| Case | Required behavior |
| --- | --- |
| Tall/wide PC | Hardware remains bounded; no leftover-space grip expansion or tiny type on a large slab |
| Short landscape / portrait / resize | Deliberate reflow, no overlap,44px targets, no physics stretch; essential text readable |
| Fresh menu open / tab switch | First item fully visible; stale scroll does not cut off content |
| Long names / complete mastery | No clipping, negative progress, or invented rank; exact next condition readable |
| Boot while recap/hatch/menu owns UI | Wait, defer or cancel under the reviewed state policy; never run over another modal |
| Reduced effects / mute / teardown | No stale animation/input lock; authoritative values static and readable |
| Saving / failed / stale reward | No invented payout or replay; original sequence and transaction guards preserved |
| Result close X | Same cancellation/acknowledgement semantics as current Close |

## Validation contract

Run Rojo build and native source compilation. Preserve relevant existing UI/receipt/transaction/save cases (previous baseline139); add behavior-focused cases for proportion bounds, minimum role text, fresh scroll/art insets, modal/boot races and X routing. Test actual menu, deck, recap, hatch and pet-focus navigation. Compare screenshots at1649×913,1280×720,844×390,568×160 and390×740 safe content; note when a test is a GUI fixture rather than an actual device emulator. A screenshot must be critiqued for hierarchy/clarity, not accepted merely because bounds tests pass.

Physical phone comfort, live shared multiplayer, live-account DataStore rejoin, fun and retention cannot be certified by desktop fixtures. No nursery, paid luck, daily play caps, public release, account/privacy/security changes, new economy or arbitrary custom shader claim in this pass.

## Progress

- [x] Audit current screenshots and structural code causes.
- [x] Resume existing heartbeat with updated November7 scope and9AM cutoff.
- [x] Complete/reference/review design system. Astra approved `UI-DESIGN-SYSTEM.md`, based on inspected publisher screenshots and Roblox platform guidance.
- [ ] Implement coherent client pass with Sol. Step1 foundation/handheld/presentation ownership in progress; native verification and Astra render review precede Step2 menu/recap/chrome.
- [ ] Astra code and screenshot review; resolve blockers.
- [ ] Native and actual-control acceptance; honest before/after gallery.
- [ ] Commit/push, verify existing private publication, morning rundown.
