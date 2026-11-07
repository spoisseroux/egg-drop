# Pocket Deck UI design system

Design handoff for the Egg Drop client, originally based on commit `1cd0927`, 7 November 2026. Dimensions are Roblox UI offset pixels within the already inset content root. The design tables specify targets. The checkpoint below records implementation and verification through `f6d1f4f`.

## Implementation checkpoint through `f6d1f4f`

- **Desktop deck.** At 1649×971, the finished LCD measured approximately 417 px across, or 430 px including its bezel, inside an approximately 830 px case. The LCD occupies about 50% of the case width (52% with bezel), within the 48–55% desktop target. Studio Version History confirmed private version 69 at `8b49b75`. The subsequent results below are branch and Studio verification. [UI redesign results](scripts/UIRedesign-results.json) · [Delivery record](UI-OVERNIGHT.md)
- **Phone landscape.** At the iPhone emulator’s 733×307 safe root, the menu now shows the first illustrated destination row with complete labels. Both egg recipes and prices fit above the pinned action. Rotation retained Sprout’s 24-nectar price and the 18-nectar shortfall against a wallet of 6. [Emulator reflow results](scripts/EmulatorReflow-results.json)
- **Style and Journal.** Style reserves a complete swatch row before choosing its preview size. X and Equip stay reachable while scrolling. Journal keeps X and Family goals visible, uses measured rows and shows an overflow cue until the last pet is reachable in full. Desktop and touch-emulator captures were checked at Medium and Largest text size. [Style and Journal results](scripts/StyleJournal-results.json)
- **Save notices.** The active screen presents the status. Load and save retries describe automatic recovery where the server performs it. A lost session directs the player to rejoin. An unreadable save makes no recovery promise. A fixture-injected retry retained the committed pet viewport, and actual close/reopen controls retained its hatch ID and balance. [Save-notice results](scripts/SaveNotice-results.json)

Two observed issues remain beyond this checkpoint. Switching from pointer or touch to gamepad can leave Menu, Style, Journal or the egg shop without a selected control. The desktop welcome instruction can clip “Space” at Largest text size. Their corrections are pending. Physical-phone comfort and physical-controller behavior remain unverified. [Overnight verification record](UI-OVERNIGHT.md)

## What the player should see

The tray is the brightest, largest continuous surface of a pocket-sized instrument. Warm, dark graphite sets off the fern shell, a pale LCD, clear blue water, and warm orange hardware. Seed, ripple, flame, and orbit silhouettes carry the game's identity into collection screens. The lounge keeps its open view. Menus feel like pages belonging to this instrument through one type system, one close affordance, and the same art seen on the board. Leave uninterrupted space around the whole device on a large monitor. Preserve player-selected finishes.

## Evidence behind the decisions

- **Egg Drop at native resolution.** In capture 01 at 1649×971 the case spans about 1155 px and the bezel about 370 px. Each grip is roughly as wide as the screen. Most of each grip sits empty between a small upper readout and the controls at its bottom. In capture 02 the recap is about 444×304. Score, best, chain, clears, payout, wallet, reward sources and two decisions compete inside it. In 06 and 07 the menu contents stop halfway down a 620 px panel. Mastery in 08 spends ~132 px per family while the explanation renders in tiny type. Capture 12 visibly layers a boot aperture across an already displayed recap. The user also reports cropped destination tops. Capture 06 establishes the need for spacing above the first row, but cannot establish which resize or scroll state caused clipping. Code inspection finds a first row at y=0 in a clipped scrolling body and a menu open path that retains scroll when already on Play. Both need explicit coverage. [Baseline screenshots](artifacts/ui-pass/)
- **Pet Simulator 99.** In BIG Games' Rank Rewards capture the rank name, bar and count occupy one colored summary column. The reward grid beside it has consistent icon slots, quantities and action positions. The corner X stays outside the scrollable reward list. The Items capture uses a labeled Pinned section and clear silhouettes on a shared field. Apply the grouping, stable corners, and art hierarchy to mastery, daily and recap. Our reward is automatic and the receipt is informational. [Official update](https://www.biggames.io/post/pet-simulator-99-update-99) · [Rank Rewards screenshot](https://bigblog-storage.s3.us-east-1.amazonaws.com/ps99_psx_classic_rank_rewards_ui_7fd0da4de2.png) · [Pinned Items screenshot](https://bigblog-storage.s3.us-east-1.amazonaws.com/ps99_psx_classic_inventory_pinned_ui_b8ebdf89b8.png)
- **Adopt Me!** Uplift's Hotbar screenshot shows item silhouettes in consistent circular wells along one edge and leaves the player and nearby pet visible. The Profile screenshot groups each statistic's icon, short label and value within one tile. The X sits at the upper right. Apply that proximity to our family rank and marks, and use a small edge dock in free roam. These are observations of publisher screenshots, independent of sales or retention. [Official update](https://www.playadopt.me/news/profile-and-qol-improvements) · [Hotbar screenshot](https://cdn.sanity.io/images/d4ypzn9i/production/b44d3f1d69ba6e7d589e3d89554da315135ab9fb-1920x1080.jpg?w=750) · [Profile screenshot](https://cdn.sanity.io/images/d4ypzn9i/production/f2dc32fc2d53c09b7d30e0e482d344d9cb8458d5-1920x1080.png?w=750)
- **Platform behavior.** Roblox recommends responsive arrangements, input-specific hints, legible text, and clear focus. `TextScaled` opts text out of preferred text sizing. Wrapping and content-sized rows accommodate larger text. Keep interactive surfaces inside `CoreUISafeInsets`. The existing edge-to-edge visual layer can cover the device behind those controls. The 44 px target is this project's existing control requirement. [Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design) · [Accessibility and player preferences](https://create.roblox.com/docs/production/publishing/accessibility) · [ScreenGui inset behavior](https://create.roblox.com/docs/reference/engine/classes/ScreenGui#ScreenInsets)

## Shared visual contract

Use one small token table and the existing `DeckArt` constructors for the generated Luau Frames. Keep hardware finish fields in `DeckThemes`, with existing saved IDs. In the default Scout finish a dark outline around an inset LCD and two readable physical clusters give the case its handheld silhouette. A light top lip and a dark bottom seam communicate molded depth. A compact asymmetric speaker grille and a single sticker recess are sufficient detail.

| Role | Starting color | Pairing and use |
| --- | --- | --- |
| Ink / shadow | #282722 | Dark text on bright controls, instrument seams, modal scrim. Use a neutral scrim near 55–65% opacity. |
| Panel / raised / inset | #353630 / #45483E / #292C27 | Opaque modal, selectable card, recessed meter or number well. Use value and border changes so static cards and actions differ. |
| Text / secondary | #F5F6F1 / #CDD1C7 | Body and supporting text on those dark surfaces. Use secondary for explanations. Keep amounts and choices prominent. |
| Scout shell / face / lip | #326855 / #48866A / #8EB49D | Physical casing. Keep the desktop background quieter and darker than the case. |
| LCD / LCD ink | #D2E5BB / #213D37 | Tray and legible markings. Maintain differing tier colors and silhouettes, left/right labels, and the overflow line. |
| Leaf / nectar / focus | #A8DE78 / #FFBF50 / #83D7EF | Leaf for affirmative state/primary route, amber for earned currency and the physical drop cap, aqua for a 2 px keyboard/controller focus ring. Use ink text on bright fills. |
| Danger | #FF907B | Overflow, error or warning plus a word or threshold marker. Never use warning color alone. |

Tokens are starting swatches. Verify contrast of final composited text backgrounds, including selected, claimed, disabled and dimmed states. Use 4.5:1 for normal functional text and 3:1 for large text and essential boundaries as project checks. Aim for recognizable luminance steps between the scene, case, LCD, card and action. Keep dialog surfaces warm neutral charcoal even in Creek and Canopy. Avoid a uniform green filter over both the subject and its surroundings. Themes change the case and scene backing while reward, warning, focus and text keep stable meanings.

| Role | Standard / compact size | Face and rule |
| --- | --- | --- |
| Confirmed nectar or outcome number | 32–36 / 24–28 | GothamBold, one dominant value |
| Dialog title | 24–26 / 20 | GothamBold, sentence case |
| Card title / major action | 18 / 16 | GothamBold, wrap if needed |
| Body / action | 16 / 14 | Gotham or existing legible sans, one to two lines |
| Supporting | 14 / 12 | Sans for words. Code face only for short hardware marks or counters |
| Cosmetic plate etching | 11–12 | Optional and removable in compact layout. No essential information here |

Spacing scale 4, 8, 12, 16, 24, 32. On standard dialogs use 20–24 outer padding, 12–16 between groups and 4–8 within related data. On compact dialogs use 6–12. Standard card radius 10–12, panel 16–20, button 8–10. Reserve fully round silhouettes for physical A, token art and small pills. Use a 1–2 px structural edge and, for raised actions, a 2–3 px lower edge. Do not add a tick, decorative line, icon, or border to every label. Keep contrast stronger near interactive and earned elements.

**Reusable pieces.** Header = title, optional wallet/status and 44×44 close. Tab = text plus selected underline or distinctly filled segment. Primary button = leaf with ink lettering. Secondary = raised surface with light lettering and visible edge. A claim is an action only while available. A pending/disabled action has explicit state text and no activation. Pressed buttons settle 1–2 px without moving the hit target. Focus uses an outer aqua ring with room inside the clip rectangle. Give the X two simple crossed strokes or a legible multiplication glyph, a stable control name and a discoverable Close label. Keep it out of scroll content.

**Art grammar.** Retain existing `EggArt`, `PetPortrait`, `FamilyCrest` and their silhouettes. Use 20–24 px utility glyphs, 28–40 px family/contract emblems, 56–80 px illustrated destination art. A pet journal gets a pet portrait, hatch gets its egg, style gets a miniature of the actual shell, nectar always gets the same amber droplet. Frame each subject in its own reserved safe well with 8 px breathing room on regular screens and 4 px on compact. Measure the drawn silhouette including protruding leaves, not just its parent frame. Preserve art aspect and meaningful outlines. Use ordinary Frames, gradients, corners, strokes, existing synth cues, and the current ViewportFrame pets.

## Layout and interaction

### Handheld and board

`DeckLayout.resolve` owns geometry. `init.client.lua` consumes its rectangles once against the interactive root's AbsoluteSize. Preserve the simulation aspect `(Config.Width + .8)/(Config.Height + .8)` and aiming through the actual tray. Compute tray and control requirements FIRST and center the resulting shell. Avoid feeding excess horizontal viewport width into grip width.

| Root class | Tray and rails | Controls |
| --- | --- | --- |
| Roomy landscape, typically ≥800×480 | Start at available height minus outer margins and bezel. Aim for a desktop tray height of 600–700 px when available. Use two equal rails about 150–205 px each, 12–16 px bezel gaps and 10–16 px outer shell padding. At reference desktop size the tray should occupy about 48–55% of shell width. Shrink to fit actual root. | Place wallet and one quest block in the upper left, queue and remaining drops in the upper right. At regular height center the physical controls in the lower portion, roughly 65–80% down the shell. Preserve room around thumb caps and speakers. |
| Short landscape and narrow landscape | Prioritize safe height for the tray. Allow rail share to increase where control minimums require it. Solve width for two 44 px arrows plus gap in a single rail before allocating excess to decoration. A 160 px-high safe root is an explicit exception to the roomy ratio. | Use concise wallet/quest text, compact queue and count. Hide trim, vents and unused hints before essential information. Keep every actionable rectangle distinct, ≥44×44, out of both tray and neighbor. |
| Portrait or square | Stack top status, fixed-aspect centered tray, objective/queue and bottom controls. Use available height after reserving each band's actual height. Use a single-column sheet for collection content. | A and aim stay in the bottom band. Keep targets inside the safe frame, retain the selected egg and current run on rotate, and cancel active drag on relayout. |

Board states need an immediately identifiable destination, two matching pieces and result, remaining drops with exact count, distinct Dropping/Next, and action readiness. Label banks RIGHT/LEFT and show check marks on completion. Preserve A key/gamepad and drag-to-drop paths, save-wait and falling/settling messages, and accepted-drop-only pulses. Existing status text and counts win priority over vent/sticker art. Empty grip areas should visually frame a reachable physical control cluster. For the 1649×971 desktop reference, record tray width divided by total shell width. If this drifts outside the target, identify which measured control minimum required the extra width. Use a narrower shell rather than filling spare grip area with decoration.

Center the drop caption on A and measure clearance from nearby readouts and controls. The decorative “Drop” label may disappear. If there is no room for a blocking reason beside A, the existing quest/status line displays “Falling”, “Settling” or the current save-wait reason until input is ready. Restore the full objective immediately. Keep both queue tiers, the count, the wallet and the 44 px targets available.

### Pocket Menu, Daily, Mastery

Work in `DeckMenu.lua`. Share a header/tab band and one scroll body. Set standard width around 620–720 px, content-driven height. Compute from selected page, cap at safe height, and keep the header/tab locations stable within the panel. Give the scroll body its own top and bottom padding and reserve the scrollbar gutter. Include actual measured row heights and padding in CanvasSize. On page changes open at the first complete row. During a snapshot preserve scroll and focused row. Prevent reflow from moving an activated control under the pointer. A small complete Play/Daily page should end shortly after its last meaningful content.

- **Play.** Header reads Pocket menu, current wallet, Play/resume action when relevant, X. Give each destination one whole, optically centered illustration above a clear verb/noun and one functional secondary line. In narrow portrait use full-width horizontal rows if three columns cannot fit 16 px titles. In short landscape use a compact horizontal row of choices when names fit. Keep the wallet/egg affordance tied to the actual currently selected recipe, cost and progress. Verify that the top stroke, sprout leaves, and journal portrait clear both the tab band and scroll clip.
- **Daily.** Three independent contract cards with one clear emblem (sprout, chain links, score diamond), task, current/target, a thick enough progress strip and a droplet/value. Use source-specific identity and a checked Earned state. Keep the independent six-nectar gift with its claim/claimed state. Use a row of three on desktop, a list on narrow screens, and a scrollable body on shallow screens. These cards report automatically credited contracts. Give the gift the only claim affordance.
- **Mastery.** Lead with the selected next-run family. If a run is in progress show its locked family separately when relevant. Use one compact panel per family containing crest, family name, selected/locked status, rank and marks together, and one explicit next condition. Rank II may require several missing challenge names, so wrap and grow that panel. Rank III shows mastered state. Group locked families into shorter illustrated rows with a single unlock condition. Prefer a stack on narrow screens and a two-column grid only when widths support real text. Selection remains an explicit owned-family action. Keep the journal shortcut navigational. A locked card must not appear claimable.

### Phone landscape body height

Studio’s touch-enabled iPhone 17 Pro landscape emulator produced a 749×381 viewport and a 733×307 safe root. The 283 px menu left 97 px for a 176 px destination card, hiding every caption on entry. The shop body had 77 px for a pair of choices requiring 177 px when stacked. These measurements come from device emulation. Physical thumb comfort requires a phone playtest.

- **Menu.** Before placing the card, subtract the measured header, tabs, insets and footer (if present) from its available height. If the body cannot show a complete illustrated destination with its caption and focus edge, condense the header and use measured horizontal art-and-label buttons. Make this decision from the same destination footprint on every tab so their screen positions remain stable. At initial scroll position show the first complete destination row. On shallow Mastery screens put the selected family, marks and next goal before the general earning instructions.
- **Egg shop.** Budget for the measured heading, X and pinned action before comparing the remaining body with the footprint of both recipe choices. When the stacked pair would be cut off, use two adjacent, complete targets of at least 44 px each, with both names, illustrations and the selected outline visible. Keep secondary details and odds scrollable. Rotation retains the selected recipe, price and shortfall. The roomy shop, portrait layout when both choices fit, and hatch reveal follow their existing arrangements.

### Round recap

Keep `RunReceipt`, `RecapFeedback` and the matching Saved sequence as data owners. Give the ordinary field recap its own sizing in `init.client.lua` and `RoundRecap.lua`. Do not change the welcome pet dialog as a side effect. Regular sheet width 560–640 px, height dictated by measured content, with a pinned decision footer. Use the following order.

1. Specific outcome such as “Both banks complete” or the actual missed side/overflow reason.
2. Large amber drop and confirmed “+14 nectar” (example) with one small source line “Quest +8 · Daily +6”.
3. Selected egg drawing and name adjacent to the saved bank, a bounded progress bar, and a plain shortfall or Ready to hatch label. Bank may exceed cost. Clamp the bar, retain the real balance in text.
4. Score and best, peak chain, and clears as one quiet metrics row on roomy screens. Details exposes the line-item receipt, marks, challenge progress and earned promotions. A player can read the full receipt without shrinking it into the summary.
5. Keep replay and hatch actions at stable positions. Use Hatch eggs as the visual primary when affordable and Try again otherwise. Preserve gamepad focus until the player moves it. Button captions express the actual next action.

Pending shows a saving status and existing safe navigation. Stale receipts cannot animate or announce a reward. A legitimately earned zero reads zero. Use one brief transfer toward the balance after a confirmed award. Reduced effects shows the same final values immediately. On short landscape pin the outcome and footer, scroll the center summary/details, and collapse secondary metrics into Details. At 568×160, budget roughly 44 px footer, 28 px outcome, 8 px shell insets and a scrollable center; controls remain reachable and no compressed secondary type is required.

### Egg shop, reveal, journal, deck style, lounge

- **Egg shop** (`EggHatchView`). Preserve both named recipe choices, artwork, exact odds, current pool/rare protection, selected outline and separate purchase action. Apply shared type, wallet and surface tokens to surrounding chrome. Keep the compact recipe switches and pinned cost/shortfall. Choosing a recipe previews it and never submits a purchase.
- **Reveal** (`HatchReveal`, `HatchCinematic`). Keep the 3D subject dominant, the name and reward status directly below, and Meet / Play again reachable. Replace visible “Close” with the shared upper-right X throughout crack and result. It dismisses and preserves the result ID. It never acknowledges, equips or buys. Meet is the filled primary, replay secondary. Keep duplicate mark, promotion, save errors and retry semantics legible.
- **Journal** (`PetJournal`). Pin the shared X and Family goals outside the scrolling pet list. Measure each name, status, family rank and portrait well at the player’s preferred text size. Switch to one column when the two-column text width is insufficient. On gamepad entry focus the first owned selectable pet, including when earlier catalog entries are locked. Preserve sparse inventory and the existing legacy trial-tracking route. Family goals opens Mastery without equipping a pet. Only activating an eligible pet row requests its existing equip or track action.
- **Deck style** (`DeckPicker`). In the 733×307 touch-emulator safe area, only 17 px of each 44 px footer action fit at first open. Pin a 44 px X on every tab and a fully visible Equip action on Shell and Sticker. Scroll the preview, named swatches and Club content inside the remaining space. Show the shell and face hues together with the hardware accent. Preserve the pending preview across rotation, scrolling and tab switches. X, controller Back and forced dismissal restore the currently equipped appearance. Equip captures both preview IDs before dismissal and sends one apply request. Club sound and motion controls retain their existing immediate setting changes.
- **Lounge / pet focus** (`RoomView`, `PetFocusUI`). Use a compact Menu/Deck dock in safe space. Keep touch joystick and Roblox top bar clear; a native CoreGui overlay temporarily owns input. Keep Back, Greet and the rub hint visible over bright skies. Preserve unobstructed pet, cosmetic glove, movement/camera restore and reduced effects. Avoid extra screen furniture in free roam.

### Presentation ownership

Resolve ownership before showing a transition and before every delayed visual or sound. Reuse the existing room-switch epoch, hatch navigation generation and receipt identity where appropriate. An interactive overlay owns its hit targets, focus, shortcuts and scrim. A covered page must not receive A/Enter or pointer release. Remove hidden siblings from directional navigation, and restore focus to the opener when practical.

| Route | Render and input ownership |
| --- | --- |
| Initial board or deliberate lounge → live board | One optional logo aperture inside the tray during arrival. Inputs resume after entry. At reduced motion, go directly to ready. |
| Ended board, pending reveal, menu, journal, shop, style or recap owns presentation | Suppress/cancel boot immediately, including delayed dots and chime. Returning to a board that already ended opens its recap cleanly. A replicated refresh, resize, replay, shop close or menu close does not independently start a boot. |
| Mid-boot route change, new modal, respawn or teardown | Invalidate delayed work, cancel relevant tweens, hide the aperture, and recompute the current input owner. The old task cannot hide or unlock its successor. |
| Reveal X vs Meet / replay | X retains the committed result. Meet/replay acknowledge the exact ID through existing navigation semantics. Never resubmit a purchase from a transition. |
| Round completes while menu is open | Keep a single presentation owner. Defer the recap until the menu releases ownership or explicitly transition to it. Never leave an interactive board or recap under another interactive sheet. |

## Verification and evidence

Capture full native frames with viewport, resulting safe-root dimensions, active skin, input, state, revision and source (actual path or isolated fixture). Compare at 100% before publishing. Include after images alongside baseline 01–12 and distinguish Studio emulator results from physical device observations.

| Capture | Required states and observable checks |
| --- | --- |
| Desktop near baseline 1649×971 and 1280×720 | Same shell/tray aspect and measured occupancy, playable D-pad/A and utility caps, coherent clusters and retained strip. Capture ready and bank-complete; show physical input once. |
| Wide desktop or tablet 1024×768 | Stable compact handheld mass, real upper bound on grips, visible banks and distinct wallet/queue. Extra viewport room stays outside the shell. |
| 844×390 and 667×285 safe landscape | Actual drag/release, bank labels, A and menu; tab body starts below tabs, all three complete destinations at entry or clearly scrollable. Snapshot never resets scroll while reading. |
| 568×198 and 568×160 safe landscape | Each action ≥44×44, verify at least one whole interactive row in shop and menu, scroll the receipt, switch tabs, use both footer actions. Allow clipping only at intentional scroll edges; first card at rest is complete. |
| 390×740 portrait, plus 350 px narrow root | Rotating during drag clears play input. Portrait menus reflow, bodies scroll, pinned actions remain visible; check locked/higher rank challenge text. |
| Menu set | Capture Play at first open and after Mastery scroll, Daily with different progress/claim states, Mastery selected/locked/upper-rank, journal, and style preview/cancel. Capture exact status or mark missing state as a fixture. |
| Round set | Saved positive/zero, pending, daily-only on failed run, Details, affordable/short egg, progression/promotion. Show readable outcome, payout, next egg and two decisions. Validate data against receipt/profile. |
| Reveal and transitions | Capture mid-crack X and fully revealed pet; X→reopen same result, normal Meet/replay. Record fresh boot, ordinary lounge return, ended board return, HUD refresh, rapid open/close and reduced motion. Aperture and any modal must never coexist. |
| Preferences, focus and skins | Compare default and alternate case on same screen. Verify max preferred text on wrapping menu/receipt, reduced motion, dark/light lounge scenery. Navigate tabs, cards, Details and footer with keyboard/gamepad; selected target remains visible. |

Review by looking at the native captures before relying on fixture counts. A mixed boot/recap frame, clipped first destination art, unreadable goal text, two competing primary actions, a non-scrollable cut-off reward, or an oversized desktop grip calls for another layout iteration. Geometry tests establish bounds and authority checks establish data correctness. Physical thumb comfort, TV viewing distance, live rejoin and player preference need their respective environments.

## Implementation sequence

1. Establish shared role tokens and text/button helpers; resolve shell/tray/rail rectangles and input ownership. Capture before moving on.
2. Build the menu chrome and card families, then recap summary/details with content-driven sizing and pinned controls. Validate short safe roots using the real action paths.
3. Bring the egg/reveal, journal, deck style and room controls into the same visual grammar. Keep existing art and authority boundaries.
4. Review native renders against the matrix, correct visual regressions, and rerun existing client, navigation and transaction tests plus targeted geometry/ownership checks. Do not modify prices, odds, rewards, progression, persistence, server gameplay or world content for this UI pass.

