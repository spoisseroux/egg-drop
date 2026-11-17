# UI spec after v816 phone QA (Fable, 2026-11-16)

Source: Spencer's five phone screenshots of v816. Spec only; nothing here is built or verified.

**Units.** The screenshots are 2000x920 px of an 874x402 pt phone, so **1 pt = 2.29 px**. Layout code works in pt. Sizes below are given as `pt (px)`. The deck in the screenshots is tier 0 (`bodyH` 310 pt, `SW` 124, `D` 88, `A` 80, `ib` 50).

## 1. Pocket Deck A/B (Game Boy Micro pair)

Code: `Screen.resolveCompact` in `src/client/DeckScreen.lua` (lines 228-239: `A`, `ib`, `ax`, `bxo`, `apart`, `dy`, `ay`, `g.a`, `g.item`) and `Screen:layoutCompact` (line 850 on).

**What is wrong today.** A is 80 pt (0.26 of body height) and B is 50 pt, so they read as one big button with a small one tucked under it. The pair is nearly vertical (about 70 degrees) and A sits 4 pt outside the grip line while B sits 21 pt inside it.

**Target.**

| Value | Rule | Tier 0 result |
|---|---|---|
| Diameter, both buttons | `btn = clamp(round(0.16 * bodyH), 44, 52)` pt. Replaces both `A` and `ib`. | 50 pt (114 px) |
| Edge gap between them | `gap = max(8, round(0.03 * bodyH))` pt | 9 pt |
| Centre distance | `apart = btn + gap` | 59 pt |
| Angle of the B-to-A line | 35 degrees above horizontal | `dx` 48, `dy` 34 pt |
| Pair midpoint | `(W - cx, dcy)`: the d-pad centre mirrored about the screen, on the d-pad's centre height (not `mid`) | wing centre |
| A centre | `(W - cx + dx/2, dcy - dy/2)` | 69% across the wing from the screen edge, 17 pt above d-pad centre |
| B centre | `(W - cx - dx/2, dcy + dy/2)` | 31% across the wing, 17 pt below |

- **Wing fit.** A's outer edge stays 8 pt or more inside the wing's outer edge, and B's inner edge 8 pt or more from the screen edge. If either fails (tier 2, `SW` 98), steepen the angle in 5 degree steps to a 45 degree maximum. Never shrink below 44 pt.
- **Drop `ax` and `bxo`.** The pair is symmetric about the grip line.
- **Look.** A keeps its green dome, B its dark dome (`#3A3E47`). Each gets the same recessed well (`btn + 10`). Letter size stays `0.46 * btn`. B keeps the item glyph and ring drawn over it.
- **Count badge.** Move it from B's top-right to B's **top-left**. Top-right now points into the gap towards A.
- **"Items" label.** Centred under B, 4 pt below its edge, `Label` style in `soft`, 17 pt tall. It shows only on the phone and only when it clears the body's bottom by 2 pt (the existing rule). It must stay inside the wing; it may sit under A's lower-left edge but must not touch A.
- **Touch targets.** Each hit area is `btn + 8` square (58 pt at tier 0, 52 pt minimum), centred on its button. Where the two overlap, cut both at the midpoint between the centres so neither steals the other's taps. Both are 44 pt or more at 874x402 and at 812x375, which is 100 px or more at 2000x920.
- **Thumb reach.** Both centres stay within 100 pt of the body's right edge and within 40 pt of the d-pad's centre height. A, the drop button, is the outer and upper one.
- **Left wing.** D-pad, MENU and wordmark do not change. The d-pad (88 pt) is now visibly the larger control, which is right for a Micro.

## 2. Material tab (was Finish)

Code: `src/client/FinishPanel.lua`, `src/client/HueEggView.lua`, copy in `src/shared/UICopy.lua` (`r4.customize.finish.*`, line 304).

**Rename.** Players see "Material" everywhere "Finish" appears: the tab, the Companions pane row (`CompanionsHub.lua:77`), `slot.finish`, "finish jars" (now "material jars"), `FinishChanged` ("This pet's material changed…"), `moreFinishes`, and the Book page "Toys & finishes" (now "Toys & materials"). Internal ids and saved keys stay as they are.

**Remove.** The "Look: Original" line, the unlabelled dot row, and both "Original" cards (`originalSheen`, `originalJelly`).

**Layout** in the existing left column (x 190-1240, y 388-866 px). No scrolling.

| Block | Position (px) | Size |
|---|---|---|
| Meter card | y 388-588 | 459 x 87 pt (1050 x 200 px) |
| Jar cards, 3 across | y 602-748 | each 146 x 64 pt (334 x 146 px), 10 pt gaps |
| Footer row | y 762-866 | 45 pt (104 px) tall |

**Meter card** (`raised` glass frame, 8 pt padding). It is read-only: no hit areas, no hover, no selection ring.

- **Shine meter**, left 66% of the card.
  - Label row: "Shine" in `Title`, left. The current stop in words, right, in mint: "Original", "Gloss 2/3" or "Matte 1/3".
  - Track: 6 pt high, full width, with 7 tick marks for stops -3 to +3. The centre tick is taller.
  - Marker: one 18 pt mint disc with a 2 pt white ring on the current stop. The track fills from the centre tick to the marker.
  - End labels under the track, `Label` in `soft`: "Matte" left, "Gloss" right.
- **Jelly meter**, right 30% of the card, separated by a 1 pt divider.
  - Label row: "Jelly" in `Title`, left. "0/3" right.
  - Three pill segments, each 6 pt high, on the same line as the Shine track. Filled segments are mint, empty ones are the track colour.
- **Helper line** across the bottom of the card, `Label` in `soft`: "Use Gloss jars to add shine, Matte jars to soften."
- Moving a stop animates the marker or segment over 0.2 s.

**Jar cards** (Gloss, Matte, Jelly). Each has a 40 pt icon, the name in `Title`, the count ("×2"), and a state pill at the right, 52 x 24 pt:

| State | Pill | Card |
|---|---|---|
| Has jars, can use | "Use", mint fill, ink text | normal |
| Has jars, meter at its end | "Max", outline only | normal; the pane shows the existing `maxSheen` / `maxJelly` line |
| No jars | "×0", outline, 50% opacity | whole card at 50% opacity, still tappable |

The whole card is the tap target. Tapping selects it and previews the result on the pet in the right-hand well. The pane's main button applies it ("Use a Gloss jar"), as today. With no jars the button is disabled and reads "No Gloss jars".

**Footer row.**

- Left: shown only when the player has no jars at all. One line, `Label`: "Find jars in the Customization Egg ›". The whole line is a 44 pt high button in mint that opens the Customization Egg. The pane under a jar name shows the same line when that jar's count is 0.
- Right: one **"Back to original"** button, 150 x 45 pt, outline style. It shows only when Shine is not at Original or Jelly is above 0. Tapping it selects the reset and previews it; the pane button confirms with the existing line ("Back to original from {look}. Free."). It resets both meters in one action. The server clears one axis per request today (`LookState`), so the engineer either sends both or adds a combined request.

**Colour and type.** Use the kit tokens already on this panel: `raised` frames, `Title` and `Label` text, `Kit.Color.text`, `soft` and `ink`, and the mint of the selected tab for the marker, fills, "Use" pill and link. No new colours.

## 3. Toys become their own category

**Companions rows** (`CompanionsHub.lua:29-32`). Four rows in the same column (y 283-878 px): each **59 pt (136 px) tall with 7 pt gaps**. The icon disc drops from 44 pt to 37 pt. Title and subtitle keep their styles; the subtitle stays on one line.

| Row | Icon | Subtitle | Right side |
|---|---|---|---|
| Pets | paw | unchanged | pet name |
| Wardrobe | shirt | unchanged | "N OWNED" |
| **Toys** | bone (the old tab's icon) | "Pick a toy and watch your pet play" | "N OWNED" (toys owned, not counting None), plus the NEW badge for unseen toys |
| Customize | wand | **"Hue, charm and material"** | none |

**Customize** keeps three tabs: Hue, Charm, Material. The tab bar keeps its width and splits into three equal segments.

**Toys screen.** Same panel, header "Toys", wallet chip and back button as the other screens.

| Block | Position (px) | Size |
|---|---|---|
| Toy grid, 2 columns | x 190-1100, from y 300 | cards 195 x 64 pt (446 x 146 px), 8 pt gaps, scrolls |
| Preview pane | x 1130-1815 | 299 pt (685 px) wide |
| Preview well | y 310-690 | **278 x 166 pt (637 x 380 px)** |
| Name row | y 704-754 | toy name left (`Heading`), "Playing with Bear" right (`Label`, `soft`) |
| Main button | y 766-866 | full pane width, 44 pt tall |

- The old well was 209 x 87 pt (478 x 200 px). The new one has about 2.5 times the area, and the pet fills 70% of its height.
- The first card is "None". The grid's last line is "More toys hatch from Toy Eggs."
- **Tap to preview.** Tapping a card selects it and the well plays the current pet playing with that toy: a 3 to 4 second clip that loops without a visible seam, three-quarter front camera, starting within 0.15 s. Switching toys cross-fades over 0.15 s. "None" shows the pet idling.
- Tapping does not equip. The main button does: "Give to Bear", or "Equipped" (disabled) for the toy already in use.
- The loop stops when the screen closes. With reduced motion on, show the play pose as a still.

## 4. Two notes

**The popover (first play, 41d2663b).** Not ours. It is black with a caret pointing at the Roblox menu button, a white X and a Roblox-blue button; nothing in our kit is black or that blue, and the Roblox menu icon carries a blue notification dot in every screenshot. It reads as a Roblox top-bar tip whose text did not load. We cannot restyle or close it. Two things to check on our side:

1. Confirm no instance of ours matches it (search PlayerGui while it shows).
2. The Welcome "Skip tutorial" pill is not visible anywhere in that screenshot. Check where it sits on first play; if it is under the popover, move it to the right of the guide pill ("Match eggs. Hatch a friend.").

**The wallet chip (bug to check).** In both Customize screenshots the 3D Star in the wallet chip renders as a thin orange sliver, with a different width in each. Companions shows it face-on. It looks like the star is caught edge-on (spinning, or the chip's camera is lost when Customize opens). The star should face the camera and hold still on every screen.
