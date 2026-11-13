# UI spec: menu screens and round look (redesign, 2026-11-12)

Design only. Nothing here is built. It answers Spencer's v515 QA notes 1 to 5 (Companions, Hatch eggs, headers, deck background, round look).

- Mockups: `artifacts/redesign-2026-11-12/menus/` (1:1 Roblox pixels, plus `@2x`). Generator: `python scripts/deck_art/build_redesign_menu_mockups.py`.
- Sizes drawn: desktop 1920x1080 and phone 812x354.
- The mockups are concept drawings from this spec's numbers, not Studio captures. The pet and the egg shells are existing renders. Odds and prices are read from the catalogs as of today.
- Celebrations are a separate spec (`UI-SPEC-REDESIGN-CELEBRATIONS-2026-11-12.md`).

## 0. Rules that every screen here shares

**One screen family.** Every menu below is the Wardrobe pattern, which Spencer likes: header, an optional tab row, a list or card grid, and a pinned preview pane with one primary action. Companions, Customize and Hatch eggs move from the old `DeckArt` card (640x640, text tabs, `x` close) to this pattern.

**Frames.**

| | Desktop (1920x1080) | Phone (812x354) |
|---|---|---|
| Container | 848x608 Kit panel, radius 30, centred, `UIScale = min(1.2, (W-24)/848, (H-24)/608)` = 1.2, so 1018x730 on screen | Compact sheet at `0, kh+2` = `0, 60`, size 812x294 (as built today) |
| Shade | black 35% over the garden or deck | none; the plate shows in the 60 px strip above |
| Content area | x 24..824, y 84..536 | x 20..792, y 64..282 of the sheet (screen y 124..334) |
| Hint bar | y 566, glyph chips left, one promise line right | none (touch) |
| Text floor | 13 | 12 |

Numbers below are panel units on desktop (multiply by 1.2 for screen pixels) and screen pixels on the phone.

**Type and colour** come from `DeckKit` unchanged: Title 26/20, Heading 20/16, Body 16/14, Small 14/12, Label 13/12 caps, Counter mono. The accent marks focus, the selected tab and the primary button only. Stars are always gold.

### 0.1 Shared header (one component)

Mockup: `00-shared-header.png`.

Used by Companions, Pets, Customize, Wardrobe, Deck style (Faceplates and Backgrounds) and Hatch eggs. New `Kit.header(parent, options)`; no screen builds its own header after this.

| Part | Desktop | Phone |
|---|---|---|
| Eyebrow (the parent screen, Label 13 dim) | at 24, 14 | not shown |
| Title | Title 26 at x 24, centre y 48 | Title 20 at x 24, centre y 34 |
| Back circle | 44x44, right edge at 824, centre y 44 | drawn 36x36, right edge at W-20, centre y 34; hit area 44x44 |
| Stars capsule | 44 high, 8 px left of the back circle | 36 high, 8 px left of the back circle |
| Capsule content | star 22, Counter 18, padding 18 | star 18, Counter 15, padding 15 |
| Hairline | none (the tab row or content starts at y 84) | y 60, x 20..W-20, white 7% |

- **The back circle and the Stars capsule are the same height** on both sizes (44 and 44; 36 and 36) and share one centre line. Today they are 56 and 40 on desktop and 44 and 32 on the phone.
- Order from the right edge is always back, then Stars. Nothing else goes in the header. The old "Backgrounds" ghost button in the Faceplates header becomes a tab (section 4).
- The capsule grows to the left with its number. The title truncates before it reaches the capsule.
- Back does one thing: go up one level in the map below. B, Backspace and Esc do the same.
- Options: `title`, `eyebrow`, `wallet` (false hides the capsule on a screen with nothing to buy; none of the screens here hide it).

### 0.2 Icon tabs

`Kit.tabs` gains an optional icon per segment: icon (label size + 4) and label side by side, 7 px apart, centred in the segment. Track 44 high with Strong 16 on desktop, 36 high with Strong 14 on the phone; hit frames stay 44 high. Never icon only: the label stays at every size. If a segment cannot fit icon plus label with 6 px each side, drop the icons for the whole row, not the labels.

### 0.3 Navigation map

```
Care Cradle / Pocket Menu "Customize"
  -> Companions (hub)                      back: garden
       -> Pets (pet selector)              back: Companions
       -> Wardrobe (slot tabs)             back: Companions
       -> Customize                        back: Companions
            tabs: Hue | Charm | Materials | Toys     (Features hidden, see 2.4)
Egg shelf / Pocket Menu "Hatch eggs"
  -> Hatch eggs                            back: garden
       -> hatch cinematic -> receipt "Use now" -> Customize on the matching tab
Deck MENU > Deck style
  -> Deck style, tabs: Faceplates | Backgrounds     back: deck
```

Deep links keep working: a receipt's "Use now" opens Customize on its tab with Companions under it, so Back still lands on the hub.

### 0.4 Input (all screens)

| Action | Keyboard | Gamepad | Touch |
|---|---|---|---|
| Move focus | arrows, WASD | d-pad, left stick | tap selects |
| Switch tab | Q / E | LB / RB | tap the tab |
| Act on the focused item | Enter, Space | A | the pane button, or a second tap on the selected card |
| Back one level | Backspace, Esc | B | back circle |

Focus is owned by each screen, as in `WardrobeShop`. The focus ring and glyph chips hide after touch input (existing `Kit.touchHidesFocus` rule). The first tap on a card only selects it and updates the preview; it never spends Stars.

### 0.5 Transitions

- Screen in: 160 ms Quad Out, fade plus 8 px rise. Out: 120 ms Quad In.
- Hub to child: the child slides in 24 px from the right while fading in (160 ms). Back reverses it. The header stays put: only the title text cross-fades, so the Stars capsule and back circle never move.
- Tab change: the pill slides 140 ms (existing), the grid cross-fades 90 ms.
- Preview change: instant swap, then a 120 ms settle (scale 1.04 to 1).
- Reduced Motion: every one of these is a cut.

## 1. Companions hub (new parent screen)

Mockups: `01-companions-hub-desktop-1920x1080.png`, `01-companions-hub-phone-812x354.png`.

The hub answers "what can I do with my pet" before any tab row appears. Three large rows, each with an icon, a name, one line of what it is for, and a status.

| Row | Icon | Line | Status (right or under) | Opens |
|---|---|---|---|---|
| Pets | paw | Choose who follows you around the garden | the active pet's name | pet selector |
| Wardrobe | shirt | Hats, shirts and more, bought with Stars | "N owned" | `WardrobeShop` |
| Customize | wand | Hue, charm, materials and toys | "N new items" in gold with a dot when a hatched item is waiting to be used, else blank | Customize |

**Desktop.** Left pane 24, 84, 328x452: preview well 296x248 with the live pet (same `ViewportFrame` set-up as Wardrobe), name Title 24, a "Following" chip, then four read-only rows (Wearing, Charm, Finish, Toy) at 28 px pitch. Right: three rows 456x140 at x 368, y 84 / 240 / 396. In a row: 72 px icon disc at x+24, Heading 22 at x+116, Body 15 soft under it, status Label 12 under that, chevron at the right edge. The focused row takes the `selected` fill, a 2 px accent stroke, the focus ring, and its icon disc turns accent with an ink icon.

**Phone.** Left pane 20, 124, 200x210 (well 176x130, name 18, "Following you" 12). Right: three rows 560x64 at x 232, y 124 / 197 / 270. Icon disc 44, Strong 16, Small 12, status right-aligned before the chevron. Each row is a 64-high touch target.

**Behaviour.** Opens with focus on the row last used (Customize the first time). With one pet (v1) the Pets row stays: it shows the pet's name and opens the selector with one card, so the screen does not change shape when a second pet arrives. The pane is read-only; it is the "who am I dressing" anchor.

**Pets (selector).** Same frame, no tab row: a 2-column card grid (portrait swatch, name, "Following" or "Follow"), preview pane with the focused pet and a primary "Follow" button. Not mocked; it is the Wardrobe layout with pets as the items.

## 2. Customize (icon tabs, Charm with "None")

Mockups: `02-customize-charm-desktop-1920x1080.png`, `02-customize-charm-phone-812x354.png`.

### 2.1 Tabs

Hue (drop), Charm (sparkle), Materials (sphere), Toys (ball). Pet and Wardrobe leave the tab row: they are hub rows now. Four tabs give each one room for icon plus label on the phone (132 px per segment).

### 2.2 Charm tab

"Charm On" and "Charm Off" are removed. **None is the first card in the grid**, a normal option like the others.

| Card | Swatch | Status line |
|---|---|---|
| None | slashed circle, soft grey | "No charm", or WEARING when no charm is shown |
| Snowflake, Ring, Pebble | the charm drawn in the pet's Secondary colour | WEARING (accent caps) on the saved one, else "Free" |

- Focusing a card previews it on the pet at once (None hides the charm). The pane shows the name, a FREE chip, one line ("Floats beside Zivvi in its Secondary colour") and the primary button: **Wear**, or disabled "Wearing" on the saved card.
- Selecting None sends `charm(petId, false)`. Selecting a shape sends `charm(petId, true, shape)`. One request per press; the pane says "Saving..." until the server answers, as today.
- Under the grid on desktop, a quiet tip card says where the colour comes from ("Change it on the Hue tab"). Not on the phone: no room, and the pane line already says it.

**Desktop.** Tabs 24, 84, 800x44. Pane 24, 144, 328x392 (well 296x196, name at y 386, two lines, button 288x56 at y 464). Grid from 371, 147: cards 217x96, 12 apart, 2 columns. Tip card 371, 372, 446x72.

**Phone.** Tabs 20, 124, 528x36. Pane 560, 124, 232x210 (well 208x86, name 18, one line 12, button 208x44). Grid from 23, 175: cards 258x64, 8 apart, 2 columns.

### 2.3 The other tabs (same frame, not mocked)

- **Hue:** a Main | Secondary two-segment control replaces the two buttons; the fruit dose rows become cards (colour swatch, name, "3 of 5", owned count). The pane previews the result and holds "Use 1 fruit".
- **Materials** and **Toys:** cards as in Wardrobe (swatch, name, WEARING / Owned / "From a Material Egg"). The first card is Standard for materials and None for toys, matching Charm.

### 2.4 Features: hide for now

Recommendation: hide the Features tab, and take the Feature Egg off the Hatch eggs list with it, until horns and wings read well in the garden and claws read at all. Saved features stay on pets and keep rendering; nothing is deleted. Hiding the tab but selling the egg would sell items with nowhere to use them, so the two go together (open question 1).

## 3. Hatch eggs

Mockups: `03-hatch-eggs-desktop-1920x1080.png`, `03-hatch-eggs-phone-812x354.png`.

**Left: the list, text only.** One row per egg: name (Heading 18 / Strong 15), one line of what it gives (Small), price in gold at the right with the star. No egg picture in the row. The selected row takes the `selected` fill and accent stroke.

**Right: the selected egg.**

1. **3D preview.** A `ViewportFrame` with the egg model on a small turntable. It spins about 20 degrees per second, and every 2.4 to 3.6 s it does a "something inside" beat: a 6 to 9 degree tilt to one side, a quick counter-tilt, a 4% squash and a short hop (0.35 s in all), with a soft tick. Beats are randomised so two looks never match. Reduced Motion: no spin, no beats; the egg sits at a three-quarter angle.
2. **Name and price chip.**
3. **Description**, two lines at most, Body 15 / Small 12.
4. **Odds.** Label "ODDS" with "1 toy per egg" at the right, then one row per outcome: name left, value right in Counter. Values come from `OddsText.format`, so equal thirds read "1 in 3" and the list never adds up to 99.9%. With more than three outcomes on the phone the rows go to two columns.
5. **Primary button** "Hatch (star) 8". With too few Stars it is disabled and the line above it says "N more Stars needed" in danger text.

| Egg | Line | Description | Odds today |
|---|---|---|---|
| Toy Egg, 8 | A toy to carry and chase | Something is rattling around in here. Hatches one toy your pet can carry and play with. | Ball, Bone, Sparkler: 1 in 3 each |
| Material Egg, 16 | A new body finish | Smooth and heavy. Hatches one finish that changes how your pet's body catches the light. | Gloss 50%, Matte 50% |
| Hue Egg, 8 | Fruit that shifts colour | It smells like fruit. Hatches one colour fruit to feed your pet. | from `HueCatalog` |
| Feature Egg, 32 | Horns, claws or wings | (hidden with Features, see 2.4) | Horn buds 50%, Claws 35%, Folded wings 15% |

**Desktop.** List rows 328x72 at x 24, y 84, 12 apart (five fit). Pane 368, 84, 456x452: well 424x152, name at y 280, description from y 298, odds label y 352, rows 24 high at 28 px pitch from y 372, button 424x56 at y 464.

**Phone.** List rows 220x56 at x 20, y 124, 8 apart (three fit; a fourth makes the list scroll). Pane 252, 124, 540x210. There is no height for a vertical stack at 354, so the egg well (150x186) sits at the pane's left and the name, description, odds and button stack to its right in the same reading order Spencer asked for.

**Behaviour.** A / Enter / the button hatches the selected egg (one press, as today: the price is on the button). Up and down move the list; the preview swaps at once. When an item pool is fully owned the odds block is replaced by "All toys owned" and the button is disabled.

## 4. Deck style: Faceplates and Backgrounds, one header

Mockups: `04-deck-style-faceplates-*.png`, `05-deck-style-backgrounds-*.png`.

Today Faceplates is a Kit screen and Backgrounds is the old `DeckArt` card with a different title, close button and tab strip. Both become one screen:

- **Header:** the shared header. Eyebrow "POCKET DECK", title "Deck style", Stars capsule, back circle. Identical on both tabs.
- **Tab row:** Faceplates | Backgrounds with icons, in the same position and size as Wardrobe's slot tabs. LB / RB and Q / E switch. The ghost "Backgrounds" button in the header is removed.
- **Faceplates tab:** as built, moved down one row. Desktop: pane 24, 144, 328x392; grid 4 columns of 104x88 cards from 371, 147 (16 plates, no scroll). Phone: pane right, 3 columns of 169x64 cards, scrolling.
- **Backgrounds tab:** the same pane and card grid. Cards: pattern swatch, name, status (IN USE / Earned / the unlock rule with a lock). The pane previews the pattern where it will really show (section 5), with "Use" as the primary. Backgrounds are earned, never bought; the Stars capsule stays in the header anyway so the header never changes between tabs.
- Settings and Pocket Trials rows that live in the old card move to the Pocket Menu and the quest log, where they already have homes. (If Spencer wants them kept here, they become a third tab; they do not go back under the grid.)

## 5. Deck background: keep it, and put it on the screen

Mockups: `06-background-in-screen-creek-desktop-1920x1080.png`, `06-background-in-screen-creek-phone-812x354.png`, `06-background-patterns-on-board.png`, and the preview pane in `05-*`.

**Recommendation: keep the three backgrounds and draw the chosen one inside the LCD, in the board well behind the eggs.** Drop the exterior backdrop pattern on the phone (it is never visible there); desktop keeps its exterior backdrop as it is.

Why keep it:
- Two of the three are earned (Creek from the High Roller trial, Lantern at Rank II). Retiring the feature takes away rewards players already hold.
- The board well is the one surface every device shows for the whole round. On a phone the plate fills the root, so anything outside the glass cannot work.
- It gives the round some of the "more exciting" Spencer asked for at no cost to readability, because it is very quiet.

How it is drawn:
- One tone: the plate accent mixed 25% toward white, at **6% opacity** on the well. No second colour, no animation during a round (it may drift 4 px over 20 s on results and menus; never under Reduced Motion).
- Pattern cell 40 px on desktop and scaled with the board on the phone (about 23 px at 812x354). Canopy is paired seeds, Creek is ripple arcs, Lantern is small lanterns.
- It sits under the eggs, the aim guide, the fill line and the danger haze. Eggs keep at least 3:1 against it by construction (they are saturated mid-tones on a near-black well).
- The Backgrounds pane preview is a mini screen with the pattern at 13% so the choice is readable at thumbnail size. Card swatches use 27%.

If it tests as noise in play, the fallback is the same pattern only on the results and menu sheets' backgrounds, not retirement.

## 6. Round look

Mockups: `07-round-board-before-after.png` (five boards side by side), `07-round-after-calm-phone-812x354.png`, `07-round-after-warning-phone-812x354.png`, `07-round-after-warning-desktop-1920x1080.png`, `07-round-before-phone-812x354.png`.

### 6.1 Remove

- **The circle around the balls.** The amber `MatchHint` ring that follows the matching egg goes. So does the dark rim band on every egg sprite.
- **The yellow border around the board.** No stroke, rail or rim colour round the well. The well reads as a recess instead: a vertical gradient (the well colour lifted 7% toward the accent at the top, 35% toward black at the floor) and a 26 px inner shadow at the top edge. The sloped banks at the bottom corners are a lighter step of the well colour (9% toward white), with no outline.

### 6.2 Eggs: vivid, no ring

| Tier | Body | Deep (shade) | Light (highlight, bloom) | Motif |
|---|---|---|---|---|
| I | `#2E8BFF` | `#0A3FD6` | `#8FE1FF` | plain |
| II | `#FF8A1A` | `#E0400A` | `#FFD45C` | two soft bands |
| III | `#22E06A` | `#04963F` | `#B4FF7A` | speckles |
| IV | `#FF4DA6` | `#C4126F` | `#FFB0DC` | two stars |
| V | `#A66BFF` | `#5B21D6` | `#E3C8FF` | ring of dots |

- Shading: a radial ramp from Deep (lower right) through Body to Light (upper left), a rim light of Light along the lower edge, one bright glint and one small dot. No outline of any colour.
- **Bloom:** each egg throws its own colour onto the well, radius 1.28 r, about 30% opacity. This is what separates neighbours now that the ring is gone, and it is most of the "exciting".
- Motifs are white at 23% inside the body. They give each tier a second cue besides colour (colour-blind support, and the mark is too small to read on a phone).
- Tier mark: white ExtraBold with a Deep drop shadow, shown when the egg radius is 12 px or more. Below that the motif and colour carry the tier. At 812x354 only tier III and up show marks.
- Tier V moves from yellow to violet so it no longer sits next to orange and gold Stars.
- **Match hint without a ring:** the egg that matches the held one gets a stronger bloom (Light, 1.5 r, about 60%) and two small white sparkles that twinkle at 1.2 Hz. Reduced Motion: steady bloom, no twinkle.
- Next and Then in the HUD use the same sprites.

### 6.3 Danger state: say what is wrong, and how long

Today a thin red line pulses, "CLEAR THE LINE" appears in red and a blip repeats. It reads as "you lost" and never says what the line is.

| State | When | Line | Above the line | Message | Sound |
|---|---|---|---|---|---|
| Calm | nothing over the line | dashed, white 24%, 1.5 px, with a small "FILL LINE" tag at its right end | nothing | none | none |
| Warning | an egg rests over the line (`OverflowPressure > 0`) | solid **amber** `#FFB02E`, 4 px, glowing; it is the timer and drains from both ends toward the middle | amber haze, 0% at the top to 27% at the line | chip on the line: a countdown ring with the seconds left, "Stack too high", "Merge to clear · 3s" | one soft low "uh-oh" on entry, then a quiet tick per second |
| Last second | under 1 s of grace left | the same line in **red** `#FF5A6E` | red haze to 43% | "Merge now · 1s" | ticks double in rate |
| Cleared | the stack drops back under | line flashes white once and returns to calm | haze fades in 200 ms | chip swaps to "Safe" for 0.6 s | a short rising chime |

- Red is saved for the last second. Amber says "act now, you still can".
- The chip is 40 high (Strong 13 and Small 12) and straddles the line, centred. It fits the 163 px phone board. It draws over eggs; the eggs above the line are the problem, so covering their tops is acceptable.
- **First time only:** the round pauses for one coach card the first time a player ever crosses the line: "Eggs resting above the fill line end the round. Merge them to bring the stack down." with a "Got it" button. Stored once per player.
- The side pressure track and the "CLEAR THE LINE" text are removed. The Goals card status label is not used for this; the eyes are on the board.
- Reduced Motion: no pulse and no haze animation; the line shortens in steps once per second. Colour, text and the countdown still change.
- Losing still routes to the existing round-end presentation. This spec only covers the seconds before it.

## 7. What changes in code

No code was changed for this spec.

| File | Change |
|---|---|
| `src/client/DeckKit.lua` | Add `Kit.header` (0.1). `Kit.wallet` and `Kit.backArrow` take the shared height (44 regular, 36 drawn / 44 hit compact). `Kit.tabs` takes an optional icon per label (0.2). |
| `src/client/DeckAssets.lua`, `scripts/deck_art/build_mockups.py` (`export_ui_assets`) | New icon cells: paw, shirt, wand, drop, sparkle, sphere, ball, none, pattern, chevron. |
| `src/client/WardrobeShop.lua` | Use `Kit.header`; delete its own title, wallet and back code. No layout change below y 84 / y 64. |
| `src/client/FaceplateShop.lua` | Use `Kit.header` with title "Deck style"; remove the Backgrounds ghost button; add the two-segment icon tab row; move pane and grid down one row (desktop grid 4x4 at 104x88). Host the Backgrounds tab (or a small sibling `BackgroundShop.lua` built on the same pane and tile code). |
| `src/client/DeckPicker.lua` | Becomes the owner only: opens the Deck style screen on a tab, relays equip / preview / save notices. Its own card, `x` close, text tabs and background swatch list are removed. Settings and Trials rows leave it. |
| New `src/client/CompanionsHub.lua` | The hub (section 1) and the Pets selector. |
| `src/client/HueEggView.lua` | Becomes Customize: Kit panel and sheet, `Kit.header`, icon tabs Hue / Charm / Materials / Toys. Remove `PetTab`, `WardrobeTab`, `ShowCharm`, `HideCharm`; add the None card that calls `requestCharm(false)`. Feature tab behind a flag (off). Receipt "Use now" routes keep working. |
| `src/client/EditorTabRail.lua` | Retired once Customize uses `Kit.tabs`. |
| `src/client/MaterialPanel.lua`, `ToyPanel.lua`, `FeaturePanel.lua` | Re-skinned to the card grid plus pane (2.3). `FeaturePanel` is not constructed while the flag is off. |
| `src/client/EggHatchView.lua` | List plus preview pane (section 3). `liveOrder` drops `"feature"` while Features is hidden. The grid of egg tiles and the per-tile odds copy are removed; odds render once, in the pane, still through `OddsText.format`. |
| `src/client/EggArt.lua` / new egg models | The spinning preview needs a 3D egg per type in a `ViewportFrame` (Astra: four low-poly shells textured from the existing atlas art). Fallback until they exist: the 2D shell with the tilt and hop only. |
| `src/client/init.client.lua`, `RoomView.lua`, `PocketMenu.lua` | Cradle and Pocket Menu "Customize" open the hub. Remove `MatchHint` ring, `DangerTrack`, `DangerText`; add the fill-line tag, the haze, the countdown chip and the first-time coach card; `overflowLineTransparency` and `overflowCue` are replaced by the state table in 6.3. |
| `src/client/JellyLCD.lua`, `JellySpanSurface.lua`, `JellySprite.lua`, `JellyVisual.lua` | Board: no rail / rim rows, gradient well, lighter banks, the background pattern layer. Eggs: no rim band, new ramps, bloom, motifs, mark only at radius >= 12 px. |
| `src/shared/JellyPalette.lua`, `Pico8.lua` (`TierRamps`) | The five tier ramps in 6.2 replace the PICO-8 ramps for eggs. |
| `src/client/DeckArt.lua`, `DeckBackdrop.lua` | `Art.setBackground` also feeds the board pattern; the exterior pattern is skipped under the compact rule. |
| `src/client/BoardAudio.lua` | Replace the repeating `overflow` blip with the entry cue, the per-second tick and the cleared chime (Astra to author). |
| Specs in `scripts/` | Update the specs that assert the old tab names, `ShowCharm` / `HideCharm`, the hatch grid, the picker card and the overflow cue. |

Suggested build order: (1) `Kit.header` and icon tabs, applied to Wardrobe and Faceplates; (2) Deck style Backgrounds tab plus the board pattern; (3) hub and Customize; (4) Hatch eggs; (5) round look and danger state.

## 8. Open questions for Spencer

1. **Hide Features, and the Feature Egg with it?** Recommendation: yes to both, behind one flag, until horns and wings read well. Saved features keep rendering. Selling the egg with no tab to use it in would be worse than either alternative.
2. **Deck background inside the board, or retire it?** Recommendation: keep it, inside the board well at 6%, as mocked. Two of the three are earned rewards, and the well is the only place a phone can show it.
3. **Tier V egg goes from yellow to violet?** Recommendation: yes. Yellow sits too close to orange tier II and to gold Stars once the dark rims are gone. If the yellow top tier matters to you, keep it and move tier II to red-orange instead.
4. **A one-time pause for the fill-line coach card?** Recommendation: yes, once per player, the first time the stack crosses the line. It is the only place the rule is ever stated; without it the new chip explains the moment but not the rule.
