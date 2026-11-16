# QA 2026-11-16 (Spencer, phone, private v751): triage

- **P1. Pocket Deck on phone still isn't right** (shots/deck-phone.png).
  - The handheld's top bumpers sit right under Roblox's buttons.
  - The bottom of the body runs to the screen edge: its rounded bottom corners aren't visible.
  - The side curves crowd the POCKET DECK wordmark.
  - The whole handheld, every rounded corner included, must sit inside the safe area below Roblox's top bar, with a visible margin all round. Keep its aspect ratio locked and centre it. Shrink the shell if needed and let the screen content scale with it.
  - Make DeckFit stricter: margin ≥ 8 px on every side, and the top below the top bar's bottom edge.
- **P2. Hatch transition.** When you press Hatch, the egg in the Hatch eggs panel plays its own hatch animation before the full-screen stage takes over. Start the full-screen stage immediately, with no in-panel hatch, so you only ever see one continuous hatch.
- **P3. Results difficulty button.** Results → difficulty can only go up, so after Hard you can't go back. Tapping should cycle Easy → Medium → Hard → Easy. The same cycle applies anywhere else difficulty is picked by tapping.
- **P4. Results Star.** The full 3D spin passes edge-on and reads as a yellow blob (shots/results-phone.png). Keep the spin, but make every angle read as a Star: give it some thickness, rim shading, and spend less time edge-on.
- **G1. Faster, more exciting egg drop.** A game-feel pass:
  - faster drops and less waiting between drops
  - snappier merges with juice (pop, squash, particles, screen kick that scales with tier)
  - chain and combo feedback (counter pops, rising pitch)
  - faster settle and round pacing, with near-overflow tension
  - keep it readable and fair on phone
