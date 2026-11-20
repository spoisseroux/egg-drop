# Notification row and pet headshots (Astra, 2026-11-20)

No new uploaded images.

## 1. Notifications: "Toy tickets" (`NotificationRail.lua`)

Each line is a small cream key, like `Kit.tile`. Colours follow the deck (`Kit.color`); only the icon disc and timer bar carry the kind colour.

### Card

| Bar height | Card H | lip | face | radius | disc | text | y |
|---|---|---|---|---|---|---|---|
| 56 and up | 40 | 4 | 36 | 12 | 24 | 14 | `height-44` (as today) |
| 32 to 55 | 32 | 3 | 29 | 10 | 20 | 13 | `(height-32)/2` |
| under 32 | hidden | | | | | | |

- Face `cream`, lip `creamLip`, 2 px `ink` stroke (inner, `Kit.inner`). Text `ink`, BuilderSans Medium, one line, truncated at the end.
- Layout: 8, disc, 8, text, (6 + 14 chevron if tappable), 12. Width min 96, max 260 (220 when the free bar is under 600 px).
- Icon disc: circle, 1.5 px `ink` stroke. `Kit.icon` / `Kit.check` where one exists, else the old glyph in `Kit.DisplayFace`.

| Kind | Disc fill | Icon | Bar fill |
|---|---|---|---|
| Stars (`amount`) | `well` | `Kit.icon("star")`, `stars` | `stars` |
| done ✓ | `go` | check, `ink` | `go` |
| level up ▲ | `selected` | ▲ | `go` |
| info • | `tray` | •, `onShell` | `inkSoft` |
| warning ! | `tomato` | !, white | `tomato` |

- Stars: no "★" in the text; `+N` in `Kit.DisplayFace` after the message.
- Chevron `›`: `inkSoft`, 20 px.

### Timer bar

3 px tall, radius 2, inside the face 4 px above its bottom edge, inset 10 px each side. Track `ink` at 0.85 transparency. Fill starts full and shrinks toward the left, linear, over `duration` (default 3.5 s). Held (a tip or notice card is open): the fill freezes and turns `inkSoft` until the card closes.

### Row

- An X-only `ScrollingFrame` (bar thickness 0) at x 8, width `inset.Width-16`. Position cards by code (no UIListLayout) so they can tween. Gap 6. Oldest left, newest right.
- Max 4 timed cards plus 1 status; the rest wait in `NotificationQueue`. New cards are admitted at least 0.4 s apart. Every shown card runs its own clock.
- Overflow: tween `CanvasPosition` to the newest in 0.25 s Quad Out, unless the player dragged the row in the last 2 s.
- Edge fade: a `CanvasGroup` with a `UIGradient` transparency ramp over 16 px on each side that hides content. If the gradient does not mask the group in Studio, hard clip.
- Replaces the v775 "one line, 3 s gap" rule (`Rail.Gap`); the hold while a card is open stays.

### Motion

| Event | Normal | Reduced Motion |
|---|---|---|
| In | 0.22 s: from 16 px right, fade in, UIScale 0.9 to 1 Back Out | fade 0.15 s |
| Out | 0.25 s dissolve: fade out, UIScale to 0.92 | fade 0.15 s |
| Close gap | others slide left 0.2 s Quad Out, after the dissolve | snap |
| Hover / press | face white / face drops by the lip in 0.06 s | same |

Tap: `Rail.activate`. If a card opened, the ticket stays paused and dissolves when the card closes; otherwise it dissolves at once. Touch hit area at least 44 px tall.

### Status kind (no timer)

Face `selected` (lemon), lip `selectedLip`, no bar. Pinned leftmost. Disc icon breathes (transparency 0 to 0.4, 1.2 s loop; still under Reduced Motion).

## 2. Pet headshots (`CompanionsHub.lua:467`, RoomCompanions rows)

`PetPortrait.lua` is a 13 x 13 pixel sprite, recoloured per appearance, with a locked look: keep it as the fallback. For the live render reuse `CardPreviewCache` (lazy, visible cards only, 8 live, posed once).

| Item | Spec |
|---|---|
| Host | Existing `Swatch` (`side = cardH-20`), radius 10, 2 px `ink` stroke |
| Backdrop | Pet's secondary colour (`PetPalette.resolve(id, appearance).secondary`) lerped 0.55 toward `cream` |
| Camera | Cache framing with a head option: yaw -0.35 (as now), 6 degrees above eye line, look at `box.Position + (0, size.Y*0.18, 0)`, fit `size.Y*0.62` to the frame. Head and shoulders; ear or horn tips may crop up to 10% |
| Following pet | 2 px `selected` ring inside the stroke |
| Locked / unadopted | Same viewport, `ImageColor3` black, `ImageTransparency` 0.35, backdrop `tray`; 14 px lock icon bottom right, `onShellSoft` |
| Placeholder | `Portrait.create(swatch, pet, math.floor(side/13), centre, z, locked, appearance)` shows at once; hide it when the viewport attaches |
| Fallback | Sprite stays when `side < 40`, the 8-live budget is full, or the rig fails |

One helper (say `PetHeadshot.attach(host, pet, appearance, locked)`) for both lists replaces the paw. The Pets tab icon stays a paw.

## Acceptance

Screenshots, phone and desktop, two decks: 1, 3 and 6 lines, held and status tickets, the 36 px bar; Pets page with a locked pet.
