# What changed for your beta (40) notes

Beta (41) on Pocket Pals Beta. **Live has not been touched.**
Your notes: `FEEDBACK.md`. Test doc: `TEST-PASS-B41.md`. Designs: Fable `DECK-FEEL-BRIEF.md`, `ONBOARDING-P2-BRIEF.md`; architect `ARCH-REVIEW-P2.md`.

| # | Your note | What was done |
|---|---|---|
| 1 | The pet runs through meshes; runs too short; turns too slowly | Bushes, reeds and plant clumps are now no-go circles that the route bends around (the server checks the same list with a pet-wide sweep, not a thin ray). The Bear runs 22 studs ahead (was 12) and waits until you're within 14 (was 7), or runs on as soon as you head its way. It turns in a quick arc instead of stop-pivot-wait, and if you keep following it trots on, looking back over its shoulder |
| 2 | Petting eyes clip at the extremes | The eyes now move inside an oval (less up and down than sideways) and roll round the head instead of sliding flat |
| 3, 5 | Couldn't find the free Paint Egg; just use the machine | The chip on the Bear is gone. The invite leads you to the machine, whose prompt says **Free egg!**. It opens the normal Hatch eggs screen with the Paint Egg already picked, a pink ring, a FREE sticker, a pointing hand and **Hatch free!**. The other eggs are dimmed but still work. The Toy and Snack gifts work the same way |
| 4 | Stuck looking at the egg machine after "Paint Bear!" | Every machine shot now has an owner that gives the camera back, and the machine takes it back itself if nothing does. The pet screen never stores a stuck camera |
| 6 | The label over the pet is jittery | It hangs on its own anchor over the pet's steady position (not its wobbling body), updated every frame after the camera, with no dead zone |
| 7 | "Hatches tomorrow" | Always a countdown: "Hatches in 8 h", "It hatches in 8 h", "Sweet dreams! It hatches in 8 h." |
| 8 | Onboarding didn't teach menus, customizing, the deck, park, minigame | Five short lessons, one at a time, with a pointing hand on the real button. Each one finishes as soon as you do the thing yourself, any time, and never times out into "done". **Dress up**: "Paint Bear!" now lights Pet screen → Dress up → Paint, so you learn where it lives. **Pocket Deck**: "Play!". **Menu**: "What's next?" lights the Menu, then Things to do. **Pet Park**: "Throw it!". **Garden Dash**: "Go!" (switch `/onboard teach`) |
| 9, 14 | Smoother first transition; a more interesting open | Under 1.3 s to play: the handheld rises with a little overshoot, a scanline opens the screen, the panels slide in and the ball drops in. On first start the loading sky fades straight into the deck, so the garden never flashes in between |
| 10 | Show A / the d-pad pressed on touch | Every input now presses the drawn buttons: touch release, click, Space, gamepad. A sinks and springs back; the d-pad side shows while you aim |
| 11 | The deck should "press back" on the side you press | The whole handheld leans 2–3 px toward the pressed side with a soft shade on that half (aim never shifts) |
| 12 | The play area feels static | The pattern drifts; the held ball breathes and blinks; the aim dots and fill line march; landings puff; merges flash the border; chains glow gold |
| 13 | Old balls flash on reopen | Fixed (always on): the screen stays hidden until it has drawn the new round |
| 15 | Difficulty on reopen | Tap the Easy/Medium/Hard card (or press Up/Down) before your first drop |
| 16 | Panels look crude | Rounder cards, the tag pills set in from the corner with a lip, Balls left and the level in pills, and motion only when a value changes |
| 17 | The end screen and sound should be more exciting | A 1.9 s reveal: title slam, goal stamps, rows flip in, the Star lands, the stars count up with a rising blip, a burst and confetti, a "New best!" stamp. A skips to the end. A "so close" ending sounds softer, not sad |

## Also found and fixed while testing

- **The Bear hid behind you again at "Pet me!"**: it only held the egg's spot for 1.4 s, then trotted to your far side. It now keeps the spot for 10 s, facing you.
- **Some onboarding steps needed one round too many**: the Welcome round is not a saved round, but "Play for Stars", the +5 welcome gift, the free Toy Egg and the deck lesson counted it as round one. They now count real rounds only.

## How it was checked

- Offline specs: all pass (see the PLAY-BUILD entry for the count).
- Reviews: architect on the free eggs and part 2 (GO WITH CHANGES, all 7 applied); a code review of the whole batch (GO WITH CHANGES, all 6 applied).
- Studio Play from a fresh save:
  - Deck, egg, Meet Bear: the Bear now in view.
  - Petting: the eyes stay inside the head with the hand far off; the screen closed by itself.
  - The lead: "This way!", runs about 22 studs and waits, "Come on!".
  - The nest: "Tuck it in! / It hatches in 8 h" and "Sweet dreams! It hatches in 8 h."
  - The machine said **Free egg!**, the shop's gift mode worked, and the card appeared.
  - **Paint Bear!** went to the pet screen with Dress up lit, then Paint with the pot ready. The Bear turned blue and the camera came back.
  - The deck: the new open and panels; results counted up with "New best!"; reopen fresh with no old balls. No script errors.

## Known

- In the shop, the pointer's "Hatch free!" label sits over the Toy Egg tile.
- The "New best!" stamp covers the score line on the results.
- The full boot sheet showed on a later open, not only the first of the session.
- Not seen on a phone or gamepad. Park and Dash lessons, the Snack gift and the menu lesson weren't reached by hand.
