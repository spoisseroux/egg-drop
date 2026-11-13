# Compact v2 slim frame + Pocket Menu: implementation plan

2026-11-12, Claude (implementer). Source of truth: `UI-SPEC-COMPACT-FRAME-2026-11-12.md`, section 9 "Decisions" wins over sections 2-4.

## Goal

On phone-landscape (Compact) roots the deck reads as a handheld again: plate fills the root, one glass LCD between two slim shoulders, all HUD content inside the LCD. The MENU pill opens a new Pocket Menu on the deck screen. Desktop (Regular / Small) layout is unchanged.

## Geometry (one rule, three places)

`frame_geometry(W, H)` in `scripts/deck_art/build_compact_frame_mockups.py` stays the rule; `DeckScreen.resolveCompact` mirrors it; `CompactPhone.spec` asserts the printed tables.

| | Rule |
|---|---|
| Shoulders | `SW = 106 / 94 / 80` by tier (H >= 380, >= 340, else). Decision 2. |
| Hardware | D-pad Ø `88 / 80 / 68`, A Ø `92 / 82 / 70` (A must sit in the slimmer shoulder with its well). **B not drawn** on the compact HUD (decision 4). A centre `W - SW/2, round(.49 H)`. |
| D-pad hits | Left and right halves, each `max(44, D/2)` wide and `max(44, D)` high, shifted right if they would leave the root (tier 2: 0..44 and 44..88, i.e. 8 px into the bezel, never into screen content). |
| MENU | Drawn `min(72, SW-16) × 28`, hit `min(84, SW-8) × 44`, centred on the shoulder, bottom. |
| Wordmark | Left shoulder when `SW - 28 >= 64` (tier 0 and 1). |
| Glass / screen | `glass = SW, 4, W-2SW × H-8`; screen inset 5; content `x0 = SW+8 .. x1 = W-SW-8`, `y0 = 12 .. y1 = H-12`. |
| Board | `bh = LH`, `bw = round(LH * aspect)` (aspect 0.596), always **centred** in the screen. |
| Columns | `c2 = floor((LW - bw - 16) / 2)`. `c2 >= 144`: **wide** (spec 3.2, text goals, Daily quests card when it fits). `96 <= c2 < 144`: **narrow** (decision 5: board centred, icon-only goals). Under 96 (odd small windows only): v1-style one column kept as a fallback. |
| Narrow left | Row 0 `t0..L1` (t0 clears the keep-out): Chain card when >= 64 wide, else Chain in the Goals header. Row 1 Score. Then Goals (icon rows). Quest handle at the bottom (icon + count), **opens the quest log** (no drawer). |
| Narrow right | Next, Eggs (stacked label/value), Difficulty (bars + name), Win pays (stacked), Controls card when >= 2 rows fit. |
| Icon goal row | Tier egg Ø22 with its mark (+ for "or higher"), zone glyph (left / centre / right third of a mini tray; none for "anywhere"), chain / merge-count icon for those kinds; count Counter 13 right; done = check Ø20 in place of the count and the row dims. Full goal text on `AccessibleLabel`. |
| Controls card | Touch rows: Drag "Aim", A "Drop" (no B row). Keyboard / gamepad keep their key rows incl. Leave. Height follows the rows shown, bottom-anchored. |
| Sheets | `mg = 40 / 24 / 6` (W >= 800 / 700). The overlay content frame is offset by `mg - 6` and sized `W - 2(mg-6)`, so every v1 sheet rule written from the edge (`20`, `W-20`, `W-66`) moves in by `mg-6` with no per-screen edits; `kx`, `hx` are passed in the shifted coordinates. Grips get five thumb ridges when `mg >= 24`. |

Expected (to be confirmed by the generator): 844 wide c2 191, 740 wide c2 160, 932 wide c2 223, 568 narrow c2 100, 667 narrow c2 119. Board heights `H - 24` everywhere.

## Pocket Menu (decision 6)

- New `src/client/PocketMenu.lua`, built on `Screen:addOverlay("DeckPocketMenu", 36, {lcd=true})`. An `lcd` overlay sits in the **screen rect** (phone) or the LCD (desktop, authored 848×608 and scaled like the others), opaque panel, so the shoulders and A / d-pad stay live.
- Items: Resume (primary), Restart round, Quit to garden, Hatch eggs, Customize. One column when it fits, two columns otherwise (568×320). Every row >= 44 high, 8 px gaps, nothing in the keep-out (rows start below `kh` where they would cross `kx`).
- Motion: open = vertical wipe of the clip window from 10% to 100% height, 0.16 s Quad Out; close 0.12 s Quad In then hide; Reduced Motion cuts. Token-guarded so a quick reopen cannot be hidden by a stale close.
- Input: touch / mouse activate rows. Keyboard / gamepad: arrows / d-pad move focus (Kit.focusRing), Space / Enter / A confirm, Backspace / B / M / Y / Start resume. On-screen d-pad and A drive it too; back arrow resumes.
- Confirm: Restart and Quit act at once when `Drops == 0` (empty board); mid-round the first press turns the row into "Tap again to restart" / "Tap again to quit" (destructive), a second press within 3 s confirms; moving focus or 3 s idle disarms.
- Pauses the round on open (`pause true`) and unpauses on any close, as the quest log does.
- Wiring (`init.client.lua`): MENU pill / M / Y / Start in a round open the Pocket Menu (desktop too). On results, MENU keeps opening the quest log (unchanged). With the quest log open, MENU closes it (unchanged).
  - Resume: close.
  - Restart: new server action `restart` (below), else on a finished round the existing `requestRetry()`.
  - Quit: `clientUI.leaveDeck()` (run is preserved by `RunReturn`, as leaving via the back arrow is today).
  - Hatch eggs: `visitEggs()` (switches to the garden and opens the egg shop / hatch view).
  - Customize: the same board-to-garden route as `visitEggs` with `open = roomView.care.openFree` (the companion editor the Care Cradle opens).
  - Quit / Hatch / Customize disabled with no pet (first session); Restart disabled with no field or a finished round.
- Daily quests card (wide) and quest handle (narrow) open the quest log; the desktop Daily quests card becomes a click target too, so desktop keeps a mid-round route to the log now that MENU opens the Pocket Menu.

## Server (one small addition)

`RunReturn.restart(board, ready, ownsPip, expectedSequence, initialize)`: only in Board mode, with a field and a live (not over) round, matching sequence, `available()` true, no pending payout; re-initialises the same field (`reset(board, preset, true)`), throttled by `Config.ResetInterval`. Forfeit: no payout, no quest credit beyond what merges already earned live. New `RunReturn.spec` cases (refuses over / wrong sequence / pending payout / Room mode; restarts a live run once).

## Files

- `scripts/deck_art/build_compact_frame_mockups.py`: new tiers, narrow layout, icon goals, no B, touch Controls rows, Pocket Menu mockup; regenerate PNGs; spec tables refreshed in the spec file (sections 2-4 tables + a section 10 "As built").
- `src/client/DeckScreen.lua`: `resolveCompact` rewrite; `layoutCompact` (glass, screen, lip / shade, shoulders, hide B); `buildCompactHud` / `setCompactHud` for wide / narrow / fallback; `addOverlay(..., {lcd})`; sheet offset in `placeOverlay` and the results layer; grips; `view()` gains `off`, `screen`.
- `src/client/DeckKit.lua`: `Kit.screenCard`, icon-goal row helper.
- `src/client/PocketMenu.lua` (new). `src/client/init.client.lua`: wiring above; `deckGoals` adds `kind / tier / plus / zone`.
- `src/server/RunReturn.lua`, `src/server/init.server.lua`: `restart`.
- `scripts/CompactPhone.spec.lua`: new tables, frame asserts, narrow layout, Pocket Menu cases. `scripts/RunReturn.spec.lua`: restart cases.

## Edge cases

| Case | Behaviour |
|---|---|
| Rotation / resize with Pocket Menu open | Relayout in place (onLayout), stays open, focus kept. |
| Round ends while Pocket Menu open | Results take over: Pocket Menu closes (refresh path closes it when `RoundOver`). |
| Leave Board mode while open | Closes, unpause sent. |
| Restart pressed twice quickly | Server throttle + sequence check; client disarms after sending. |
| Wider unibar (kx > 116) | `t0` rule; narrow Chain drops into the Goals header under 64. |
| No goals / status message | Narrow status text wraps over the full three-row card. |
| Keyboard on a phone-sized window | Controls card shows key rows; B hidden on HUD but Backspace still leaves. |

## Not this slice

- The HUD-glass-to-sheet grow transition (section 4 "Transition"): sheets keep v1's open. Follow-up.
- Physical phone run. Studio FIXTURE captures only.
- Desktop visual changes beyond: MENU opens the Pocket Menu, Controls card "MENU / M" row says "Menu", Daily quests card clickable.

## Test plan

- Generator: its asserts (44 targets, 8 gaps, keep-out, text fits) at 844, 740, 932, 568, 667; `--tables` copied into the spec.
- `CompactPhone.spec` (client): tables at five sizes; glass inside the root with 4 px rims; every HUD card and the board inside the screen; columns / mode per size; board `H-24` and aspect; hardware outside the glass; no B on the HUD; keep-out / 44 / overlap / text-fit audit of the built HUD; quests card iff wide and it fits; sheet body edges `mg+14`, `W-mg-14`; Pocket Menu open / close / reduced motion / focus move / confirm-twice / resume via back; Pocket Menu audit at 568 and 844.
- Also run DeckScreen, DeckBoot, DeckResults, DeckQuests (client) and FaceplatePurchase, RunReturn (server).
- Studio FIXTURE captures: HUD 844×390, 740×360, 568×320 (and 667×375), Pocket Menu open, a results sheet, desktop round HUD.
- Live Play: open the Pocket Menu from the MENU pill and M, Resume, Restart mid-round (confirm), Quit, Hatch eggs, Customize.

## Risks

- 568×320 narrow columns are 100 px: Difficulty "Medium" at Strong 15 and keyboard glyph rows are the tightest fits; the audit decides, fallback is the one-column layout.
- Icon goals hide the words; the picker (before the round) and results still show the full goal text, and the row's AccessibleLabel carries it.
- Gamepad Y no longer opens the quest log mid-round (it opens the Pocket Menu). Results / picker keep their quest shortcuts.

## Architect review (Software Architect subagent) and adjustments

| Original plan | Revised (reviewer's concern) |
|---|---|
| Sheet offset applied in `placeOverlay` only | Also offset the results layer content by hand, and give `FaceplateShop:fit` the same `mg` view (it builds its own view from the full root). |
| Pocket Menu pauses with `pause true` / `false` | One shared pause flag: `updateShade` sends `pause modalShade.Visible` on every modal change and would unpause behind the menu. New `clientUI.syncPause()` sends `modalShade or ((questLog or pocket) and not RoundOver)`; used by `updateShade`, quest log open / close and Pocket Menu open / close. |
| Daily quests card clickable on desktop | `openQuestLog` refuses while the Pocket Menu is open, so the log cannot stack on it and unpause on close. |
| Pocket Menu input in its own handler | Added to the `EggDropDeckOverlay` (+700) gate first, so B / Backspace and M / Y never fall through to `EggDropPickerBack` (leave) or `EggDropCustomize` (quest log); the on-screen `A`, `B`, `back`, `dpad` chains check it first too. |
| Restart re-runs the same field (`sameField = true`) | Same seed = same egg queue, a replay exploit. Restart keeps the field **template** and draws a **new seed**, has its own 3 s cooldown, and clears `menuPaused`. |
| D-pad overhang | Kept; hit frames sit above the glass in ZIndex. |
| Narrow mode | Confirmed; goal icons map `bank(±1)` to left / right from the public goal data. |

## Code review (Code Reviewer subagent): GO WITH CHANGES, and what changed

| Finding | Resolution |
|---|---|
| 1. MENU now opens the Pocket Menu, so keyboard / gamepad lose the quest log mid-round | Q / LB open the quest log in a round (`EggDropDeckOverlay`); the Daily quests card / handle is clickable on phone and desktop. |
| 2. Pocket Menu could open over the translucent difficulty picker | The picker layer hides while the menu is open and comes back on close. |
| 3. A refused restart left `keepHeatAfter` behind | Cleared after 2.5 s if the sequence did not change; Restart disabled for 3.5 s after a request. |
| 4. Restart lets a player stay on a field / reroll the opening queue after one drop | Accepted trade-off (it is a restart); documented in spec 10.2. A learned queue cannot be replayed (new seed). |
| 5. Hatch / Customize unpause before the garden switch | Accepted (same as leaving via the back arrow). |
| 7-9. No-op lines, duplicated grip breakpoints, sequence integer check | Removed; `DeckScreen.gripMargin` shared with `FaceplateShop`; `RunReturn.restart` checks NaN / integer like `retry`. |

Live checks also caught: the MENU pill image was a sub-44 target (now the 44 px Hit child only), keyboard glyph text at 11 (glyphs now 24), sheet focus ring offset by the inset (`Kit.focusRing` reads the host's UIPadding), glare over phone sheets / the Pocket Menu (hidden), and Restart enabled on the Welcome board (now needs a field).
