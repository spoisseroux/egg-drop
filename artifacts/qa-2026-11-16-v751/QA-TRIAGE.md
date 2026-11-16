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
- **P5. Results Stars wallet chip** (added by Spencer after the first triage; shots/results-phone.png, bottom left "★ 18"). The chip's Star was a flat glyph. It must be the 3D WalletStar, like every other menu's Stars counter (the existing WalletStar module and Kit.WalletSpec, phone sizing at WalletStar.MinSize).

## P1 to P5 status (2026-11-16, in source, unpublished, checked in Studio Play at phone-size fixtures; not on a real phone)

- **P1 done (f9e92db, follow-up 3a1e906).** Root cause: the v735 fit stretched the body to the root and kept only 4 px at the sides and bottom and 2 px under the top bar. `resolveCompact` now picks the largest shell of one locked shape (`Screen.Fit.aspect`, 2.3:1 body plus bumpers) that leaves 8 px (`Fit.margin`) on every side of the area under the top bar, and centres it. The wordmark sits 28 px in from the body edge. DeckFit enforces the margin, the aspect and the centring at 812x354, 844x390, 926x428, 874x402, 750x402, 724x375, 667x375 and 568x320, with the fixture keep-outs and this client's `GuiService.TopbarInset`. Cost: on Spencer's phone the body is 734x319 (was 742x332), so the screen is 14 px shorter; narrower-than-19.5:9 roots show more background at the sides. The results goals pane closes its row spacing so both goals still show above the buttons.
- **P2 done (514e0a0).** Hatch no longer calls the panel egg's pop. Live: no flash or crack in the panel after the press, and the full-screen stage is up as soon as the result lands (about 0.2 s in Studio; it cannot start before the server answers).
- **P3 done (71aef17).** A tap wraps (`Results.nextDifficulty`); the d-pad still stops at the ends. Live: Medium, Hard, Easy, Medium, Hard on four taps. The in-round difficulty picker has three direct options and was left alone.
- **P4 done (86fbb82).** The hero Star was already 0.45 deep, which is what made it a blob when turned. It is now a 0.24 coin with a front light and darker rim, and the turn lingers face-on and hurries through edge-on. For about a tenth of the turn it is still a thin coin edge.
- **P5 done (c9b69cb).** `Kit.WalletSpec[28]` (Star 16 px, `WalletStar.MinSize`); the chip shows the 3D Star in Play.
- Captures: `verify/`. The files marked FIXTURE are Studio captures with the root forced to a phone size; the grey band is the 58 px top bar.

- **G1. Faster, more exciting egg drop.** A game-feel pass:
  - faster drops and less waiting between drops
  - snappier merges with juice (pop, squash, particles, screen kick that scales with tier)
  - chain and combo feedback (counter pops, rising pitch)
  - faster settle and round pacing, with near-overflow tension
  - keep it readable and fair on phone
- **P5. Results wallet chip** ("★ 18") uses the 3D WalletStar like every other menu (Spencer, 2026-11-16).
