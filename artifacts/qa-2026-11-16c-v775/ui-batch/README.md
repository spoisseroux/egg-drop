# v775 QA, UI / sound batch (notes 6 to 12, 14, 15)

Studio Play, 2026-11-16. Captures are the live game at a forced 750x402 phone fixture
(`EggDrop.Backdrop` and the menu hosts set to 750x402, keep-out pinned to 116x58), cropped
on two magenta markers with `scripts/deck_art/crop_fixture_capture.py`. Two are marked
FIXTURE or EMULATED: see below. Nothing here is from a real phone. No publish, no
translation sync.

## What each capture shows

| Note | Before | After |
|---|---|---|
| 7 Toys row | `before-07-companions-toys-row` (four rows) | `after-07-companions-three-rows` |
| 8 toy preview | (a still toy stood at the pet's feet) | `after-08-toy-card-tap-selects-and-previews`, `after-08-toy-preview-loop-filmstrip-ball-bone-deck` |
| 9 animated tiles | `before-09-pocket-menu-static-tiles` | `after-09-pocket-menu-animated-tiles`, `after-09b-...-a-second-later` |
| 11 hatch X | `before-11-...-12px-from-corner-FIXTURE`, `before-11-...-EMULATED-874x402` | `after-11-...-24px-in-level-with-buttons-FIXTURE`, `after-11-...-EMULATED-874x402` |
| 14 deck board | `before-14-deck-board-bottom-750x402` | `after-14-deck-board-bottom-750x402`, `-844x390`, `-568x320` |
| 15 Pet Park | `before-15-pet-park-beside-garden` | `after-15-pet-park-beside-garden`, `compare-15-pet-park-before-left-after-right` |

Notes 6 (waterfall), 10 (equip sound) and 12 (click audio) are sound: no picture.

- **FIXTURE (note 11):** the real reveal needs Studio's window in front, so the stage is
  `scripts/RevealCaptureFixture.lua` (the real `HatchItemStage` on a synthetic Ball). The
  "before" frame is the same stage with the close put back at its old 12 / 10 px.
- **EMULATED (note 11):** the same stage at 874x402 with pink bands over Spencer's phone's
  62 px side insets and 21 px home bar. The fixture stage has no real safe area, so the close
  was placed by hand at the value `HatchItemStage.closeRect` returns for those insets (the
  rule itself is covered by the spec).
- **Filmstrip (note 8):** Studio in the background pauses the pane's clock, so the loop was
  stepped by hand: one viewport per frame at 0.05, 0.5, 0.95, 1.4 and 1.8 s, through the
  same `PetPlayVisual` preview path the pane uses (Ball, Bone, Pocket Deck).

## Self-critique

**Good**

- 9: the four tiles read as alive at a glance and none is busy. The eggs and the Bear are
  the strongest; the Bear's portrait has headroom so the "This week" sticker no longer sits
  on its ears.
- 14: the board now reads as one tray. The grey base joins the two corner banks, the corners
  are round in the screen's own colour, and the dark strip under the pile is gone.
- 15: the kerb and posts sit in the lawn instead of glowing on it; next to the balustrade
  they are the same stone.
- 7: three rows fill the sheet down to the pet pane's bottom edge (they stopped 48 px short).

**Weak, or worth another look**

- 8: on a phone the preview well is short (about 88 px), so the pet and its toy are small.
  The loop is readable but not generous. A taller well on the Toys tab would sell it better.
- 9: the Book tile only floats and tips. It is gentle, as asked, but it is the least
  interesting of the four. The deck's ball is 4 px on a phone tile: visible, not striking.
- 9: the Companions pet raises its paw to its face rather than waving wide. That is the
  existing visitor-hello wave; a bigger wave would need a new pose.
- 11: on Spencer's phone the close is now 86 px in from the glass edge while "Use now" still
  runs to 24 px from it, into the side inset (see the EMULATED capture). The close is right;
  the buttons are the odd ones out. Not changed here: it moves an approved layout.
- 14: the board was not moved. Its rect already ends on the screen's last row, level with
  the HUD cards; what read as "high" was the dark strip under the floor. If it still reads
  high on the phone, the next step is to grow the board 3 px into the screen's padding.
- 15: the equipment's orange wood is still warm under the dusk light. It is a step darker
  and browner, but it is the brightest thing in the park.

## Not verified

- **Nothing was heard.** Studio was in the background for the whole pass, and the game mutes
  its audio then. The click helper's "asked for" count rose on every real mouse click (the
  Pets row included, and `equip` / `unequip` on the second tap of a toy card), but the click,
  equip and unequip sounds and the waterfall's new falloff need ears.
- No real phone, no real safe-area insets, no touch input (clicks were mouse clicks).
- The park palette image is a new upload (86494931505767). It rendered in Studio; its
  moderation state read "Reviewing" at upload.
