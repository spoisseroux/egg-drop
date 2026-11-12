# Pocket Deck UI design system

Design handoff for the Egg Drop client, originally based on commit `1cd0927`, 7 November 2026. Dimensions are Roblox UI offset pixels within the already inset content root. The design tables specify targets. Runtime24751c2 is now private **v93 Published**, verified in refreshed Studio Version History. The historical checkpoint below covers the original implementation, followed by the final input/coaching checks. [Morning handoff](MORNING-RUNDOWN.md).

## Current source of truth (2026-11-12)

The deck rebuild follows [UI-SPEC-2026-11-12.md](UI-SPEC-2026-11-12.md) (Fable). Where this file and the spec disagree, the spec wins. Part 1 is implemented: the glass tokens and components (`DeckKit`), the wide Pocket Deck Slim screen with the HUD inside the LCD (`DeckScreen`), results inside the deck (`DeckResults`), the view back arrow and the token pass over every sheet. The sections below that predate it are kept as history and marked where they are replaced. Studio captures: `artifacts/deck-rebuild/studio/`.

Phone landscape (Compact) layouts for the round HUD, picker, results, quest log and faceplate shop are specified in [UI-SPEC-COMPACT-2026-11-12.md](UI-SPEC-COMPACT-2026-11-12.md), with mockups in `artifacts/deck-rebuild/mockups/compact/`. It replaces the Compact notes below and section 7 of the main spec. Not implemented yet.

## Implementation checkpoint through `f6d1f4f`

- **Desktop deck.** At 1649×971, the finished LCD measured approximately 417 px across, or 430 px including its bezel, inside an approximately 830 px case. The LCD occupies about 50% of the case width (52% with bezel), within the 48–55% desktop target. Studio Version History confirmed private version 69 at `8b49b75`. The subsequent results below are branch and Studio verification. [UI redesign results](scripts/UIRedesign-results.json) · [Delivery record](UI-OVERNIGHT.md)
- **Phone landscape.** At the iPhone emulator’s 733×307 safe root, the menu now shows the first illustrated destination row with complete labels. Both egg recipes and prices fit above the pinned action. Rotation retained Sprout’s 24-nectar price and the 18-nectar shortfall against a wallet of 6. [Emulator reflow results](scripts/EmulatorReflow-results.json)
- **Style and Journal.** Style reserves a complete swatch row before choosing its preview size. X and Equip stay reachable while scrolling. Journal keeps X and Family goals visible, uses measured rows and shows an overflow cue until the last pet is reachable in full. Desktop and touch-emulator captures were checked at Medium and Largest text size. [Style and Journal results](scripts/StyleJournal-results.json)
- **Save notices.** The active screen presents the status. Load and save retries describe automatic recovery where the server performs it. A lost session directs the player to rejoin. An unreadable save makes no recovery promise. A fixture-injected retry retained the committed pet viewport, and actual close/reopen controls retained its hatch ID and balance. [Save-notice results](scripts/SaveNotice-results.json)

The two observed follow-ups were corrected before v93. Controller566a655 acquires a safe target on the first unfocused A without activating it;30 focused cases at Medium and Largest plus52 targeted regressions and actual Studio Gamepad1 navigation pass. Welcome24751c2 preserves each semantic phase with measured wrapping at native text size;56 checks at each preference and the actual Largest desktop Space/matching/Pip frames pass. The final Medium loop purchased new Wick once and reopened its exact committed result before Meet/Back. Astra approved the source, fixtures and final11 renders. Physical-phone comfort and physical-controller behavior remain unverified. [Overnight verification record](UI-OVERNIGHT.md)

## What the player should see

The tray is the brightest, largest continuous surface of a pocket-sized instrument. Warm, dark graphite sets off the fern shell, a pale LCD, clear blue water, and warm orange hardware. Seed, ripple, flame, and orbit silhouettes carry the game's identity into collection screens. The lounge keeps its open view. Menus feel like pages belonging to this instrument through one type system, one close affordance, and the same art seen on the board. Leave uninterrupted space around the whole device on a large monitor. Preserve player-selected finishes.

## Evidence behind the decisions

- **Egg Drop at native resolution.** In capture 01 at 1649×971 the case spans about 1155 px and the bezel about 370 px. Each grip is roughly as wide as the screen. Most of each grip sits empty between a small upper readout and the controls at its bottom. In capture 02 the recap is about 444×304. Score, best, chain, clears, payout, wallet, reward sources and two decisions compete inside it. In 06 and 07 the menu contents stop halfway down a 620 px panel. Mastery in 08 spends ~132 px per family while the explanation renders in tiny type. Capture 12 visibly layers a boot aperture across an already displayed recap. The user also reports cropped destination tops. Capture 06 establishes the need for spacing above the first row, but cannot establish which resize or scroll state caused clipping. Code inspection finds a first row at y=0 in a clipped scrolling body and a menu open path that retains scroll when already on Play. Both need explicit coverage. [Baseline screenshots](artifacts/ui-pass/)
- **Pet Simulator 99.** In BIG Games' Rank Rewards capture the rank name, bar and count occupy one colored summary column. The reward grid beside it has consistent icon slots, quantities and action positions. The corner X stays outside the scrollable reward list. The Items capture uses a labeled Pinned section and clear silhouettes on a shared field. Apply the grouping, stable corners, and art hierarchy to mastery, daily and recap. Our reward is automatic and the receipt is informational. [Official update](https://www.biggames.io/post/pet-simulator-99-update-99) · [Rank Rewards screenshot](https://bigblog-storage.s3.us-east-1.amazonaws.com/ps99_psx_classic_rank_rewards_ui_7fd0da4de2.png) · [Pinned Items screenshot](https://bigblog-storage.s3.us-east-1.amazonaws.com/ps99_psx_classic_inventory_pinned_ui_b8ebdf89b8.png)
- **Adopt Me!** Uplift's Hotbar screenshot shows item silhouettes in consistent circular wells along one edge and leaves the player and nearby pet visible. The Profile screenshot groups each statistic's icon, short label and value within one tile. The X sits at the upper right. Apply that proximity to our family rank and marks, and use a small edge dock in free roam. These are observations of publisher screenshots, independent of sales or retention. [Official update](https://www.playadopt.me/news/profile-and-qol-improvements) · [Hotbar screenshot](https://cdn.sanity.io/images/d4ypzn9i/production/b44d3f1d69ba6e7d589e3d89554da315135ab9fb-1920x1080.jpg?w=750) · [Profile screenshot](https://cdn.sanity.io/images/d4ypzn9i/production/f2dc32fc2d53c09b7d30e0e482d344d9cb8458d5-1920x1080.png?w=750)
- **Platform behavior.** Roblox recommends responsive arrangements, input-specific hints, legible text, and clear focus. `TextScaled` opts text out of preferred text sizing. Wrapping and content-sized rows accommodate larger text. Keep interactive surfaces inside `CoreUISafeInsets`. The existing edge-to-edge visual layer can cover the device behind those controls. The 44 px target is this project's existing control requirement. [Adaptive design](https://create.roblox.com/docs/production/publishing/adaptive-design) · [Accessibility and player preferences](https://create.roblox.com/docs/production/publishing/accessibility) · [ScreenGui inset behavior](https://create.roblox.com/docs/reference/engine/classes/ScreenGui#ScreenInsets)

## Shared visual contract

Replaced by UI-SPEC-2026-11-12 sections 2 and 3, implemented in `src/client/DeckKit.lua` (tokens and constructors) on top of `DeckArt` (theme registry, sheet helpers). Summary:

| Role | Value | Use |
| --- | --- | --- |
| Glass `panel` / `raised` / `well` | #15171B / #23262C / #0C0D10, leaning 14% / 16% / 10% toward the plate's `deep` | LCD and sheets / cards, rows, secondary buttons / board well, tracks, pills |
| `selected` | `raised` 14% toward the accent | Selected card, row or tile, with a 2 px accent stroke |
| Text `text` / `soft` / `dim` | #F3F4F6 / #C3C8D0 / #959BA5 | Titles and values / supporting lines / labels. `dim` is a touch lighter than the spec's #8A909A so 13 px labels keep 4.5:1 on every plate's `raised` |
| `ink` | #0E0F12 | Text on accent or gold fills |
| `stars` / `danger` / `good` | #FFC14D / #FF5A6E / #7BE495 | Stars, overflow and Hard, Easy. Never tinted by the plate |
| `accent` | the plate's bright colour | Only: selected tab pill, primary fill, progress, selected stroke, check marks, and the hardware (A, d-pad arrows, LED) |

Type: Builder Sans for words, Roboto Mono for anything that ticks (`DeckKit.Type`: Display 40/30, Title 26/20, Heading 20/16, Body 16/14, Small 14/12, Label 13/12 caps, Counter 18/15, Counter L 34/22). `TextScaled` stays off. `DeckArt.Font` and `DeckArt.SheetFont` now use the same faces, so every sheet reads the same.

Spacing 4, 8, 12, 16, 24, 32. Radii: button 12, card and quest row 14, list row 10, tile 12, pills full. One 1 px white 14% `UIStroke` on every card, row, track and pill. Focus: one 2.5 px white ring 4 px outside the control with a soft glow (`DeckKit.focusRing`); legacy `Art.button` sheets use the same 2.5 px white stroke. Primary buttons carry a 3 px lower edge and a white 18% top sheen. Press settles the content 2 px and darkens 8%; hover lightens 6%; disabled is 60% and leaves the selection tree. Reduced Motion turns every tween into its final value.

Components (all in `DeckKit`): `button` (secondary, primary, reward, ghost, destructive), `tabs`, `card`, `toggle`, `progress` (bar and segmented), `toaster`, `listRow`, `chip`, `wallet`, `glyph`, `check`, `icon` (from `ui/icons.png`), `backArrow`, `focusRing`.

## Layout and interaction

### Handheld and board

Replaced by UI-SPEC sections 1, 4, 5.1 and 7, implemented in `DeckScreen.lua`.

- **Geometry.** `DeckScreen.resolve(root, aspect)` owns the wide deck: `s = min((W-48)/1600, (H-60)/800, 1)`; below 0.75 the deck switches to Compact with `s = (H-8)/608` so the LCD fills the safe height and the case bleeds. The 1600x800 body carries the `shell.json` sprite stack (shadow, shoulders, band, faceplate, plate overlay, wordmark, glass, glare, d-pad disc, Menu pill, A and B). The deck is capped at s = 1 so the 1920x1080 reference matches the mockups (deck at 160,150; LCD at 536,246).
- **LCD.** Regular screens are authored at 848x608 and Compact at 417x299, each with one `UIScale`. The board takes the centre well (height fixed by the padding, width from `(Config.Width + .8) / (Config.Height + .8)`); the existing board renderer is placed over it. Left panel: Score, Chain, Goals, Daily quests. Right panel: Next, Eggs left, Difficulty badge (Medium until part 2), Win pays, Controls (follow the last input type). Compact drops Daily quests, Controls and Best.
- **Status.** "Falling", "Settling" and save waits replace the Goals label row. The first-pet lessons show inside the Goals card.
- **Layers.** The shell and HUD live in their own Sibling-ordered `EggDropDeck` gui (DisplayOrder 9, the canopy backdrop moved to 8) so the board gui (10) draws over the LCD well; the glare and the results screen sit above the board in the board gui.
- **Input.** The d-pad disc has four 44 px+ quadrants (left/right aim; all four drive menus). A drops or confirms, B and the view's back arrow leave, the Menu pill opens the menu. Keyboard and gamepad presses flash the hardware. Drag-to-aim on the board is unchanged.
- **Portrait and square** keep the legacy stacked case (`DeckLayout`), now inside the `LegacyCase` container, with the new tokens.

### Pocket Menu, Daily, Mastery

Work in `DeckMenu.lua`. Share a header/tab band and one scroll body. Set standard width around 620–720 px, content-driven height. Compute from selected page, cap at safe height, and keep the header/tab locations stable within the panel. Give the scroll body its own top and bottom padding and reserve the scrollbar gutter. Include actual measured row heights and padding in CanvasSize. On page changes open at the first complete row. During a snapshot preserve scroll and focused row. Prevent reflow from moving an activated control under the pointer. A small complete Play/Daily page should end shortly after its last meaningful content.

- **Play.** Header reads Pocket menu, current wallet, Play/resume action when relevant, X. Give each destination one whole, optically centered illustration above a clear verb/noun and one functional secondary line. In narrow portrait use full-width horizontal rows if three columns cannot fit 16 px titles. In short landscape use a compact horizontal row of choices when names fit. Keep the wallet/egg affordance tied to the actual currently selected recipe, cost and progress. Verify that the top stroke, sprout leaves, and journal portrait clear both the tab band and scroll clip.
- **Daily.** Three independent contract cards with one clear emblem (sprout, chain links, score diamond), task, current/target, a thick enough progress strip and a droplet/value. Use source-specific identity and a checked Earned state. Keep the independent six-nectar gift with its claim/claimed state. Use a row of three on desktop, a list on narrow screens, and a scrollable body on shallow screens. These cards report automatically credited contracts. Give the gift the only claim affordance.
- **Mastery.** Lead with the selected next-run family. If a run is in progress show its locked family separately when relevant. Use one compact panel per family containing crest, family name, selected/locked status, rank and marks together, and one explicit next condition. Rank II may require several missing challenge names, so wrap and grow that panel. Rank III shows mastered state. Group locked families into shorter illustrated rows with a single unlock condition. Prefer a stack on narrow screens and a two-column grid only when widths support real text. Selection remains an explicit owned-family action. Keep the journal shortcut navigational. A locked card must not appear claimable.

### Phone landscape body height

Studio’s touch-enabled iPhone 17 Pro landscape emulator produced a 749×381 viewport and a 733×307 safe root. The 283 px menu left 97 px for a 176 px destination card, hiding every caption on entry. The shop body had 77 px for a pair of choices requiring 177 px when stacked. These measurements come from device emulation. Physical thumb comfort requires a phone playtest.

- **Menu.** Before placing the card, subtract the measured header, tabs, insets and footer (if present) from its available height. If the body cannot show a complete illustrated destination with its caption and focus edge, condense the header and use measured horizontal art-and-label buttons. Make this decision from the same destination footprint on every tab so their screen positions remain stable. At initial scroll position show the first complete destination row. On shallow Mastery screens put the selected family, marks and next goal before the general earning instructions.
- **Egg shop.** Budget for the measured heading, X and pinned action before comparing the remaining body with the footprint of both recipe choices. When the stacked pair would be cut off, use two adjacent, complete targets of at least 44 px each, with both names, illustrations and the selected outline visible. Keep secondary details and odds scrollable. Rotation retains the selected recipe, price and shortfall. The roomy shop, portrait layout when both choices fit, and hatch reveal follow their existing arrangements.

### Round results (replaces Round recap)

The floating recap card and `RoundRecap.lua` are gone. `DeckResults.lua` renders UI-SPEC 5.3 inside the LCD; `RunReceipt` and `RecapFeedback` remain the data owners and the count-up clock.

1. Outcome eyebrow (ROUND CLEAR in accent; OVERFLOW / GOALS MISSED in danger) and the field title with the difficulty.
2. Stars total counted up from 0 (once per saved receipt); a loss reads "0 Stars".
3. Payout card (Round win, Daily quests, Pass bonus, Total, wallet pill; "Saving…" while pending) and Goals card (checks plus Score / Best / Chain and NEW BEST).
4. Quest strip (daily contracts finished this round; "You can hatch an egg" when affordable).
5. Replay (primary, A) and Leave to garden (secondary, B). Two targets only: left/right move, A/Enter/Space confirm, B/Backspace leave, touch or mouse tap either. The first A during the count-up only finishes it. A pending save disables Replay and moves focus to Leave. Leave puts the deck away (the old Lounge path).

Compact results use one row of two 190x120 cards and 190x48 buttons. Portrait shows the compact results fitted over the stacked case.

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

