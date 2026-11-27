# What changed for your beta (37) notes

Beta (38), place version v133, runtime eb3f94fd, on Pocket Pals Beta. **Live has not been touched.**
Test doc: `TEST-PASS-B38.md`. Your notes: `FEEDBACK.md`.

| # | Your note | What was done |
|---|---|---|
| 1 | Bear teleports behind us, behind a fence | It was standing where the egg opened, but the camera came back facing away, so you and a fence post hid it. Now the Bear stands on that spot for a beat, faces you, and the camera comes back from the side with both of you in frame; then it follows |
| 2 | "Tuck the egg in" lags, then catches up | It ignored small moves, then chased on a spring. The worded bubble is now attached to the pet |
| 3 | Switched to Play for Stars / "You're all set" on its own | It was a 20 s timeout that skipped prompts. Gone: a prompt stays until you really do it; ignored, it hops and chirps. (Also fixed: the bubble hid after 20 s with no input) |
| 4 | Why is tucking first? Keep it? | Fable kept the nest second: the deck is where new players disappear, so the nest (the reason to come back tomorrow) has to come before it. What was missing was why, so the words now say it: "Follow Bear! / A new egg is waiting", "Tuck the egg in! / It hatches tomorrow" |
| 5 | Should the pet run to the egg, beckoning? No soft-blocks | Yes: the Bear runs ahead along the paths, stops, looks back and beckons; if you don't follow it comes back ("This way!"), after 3 tries it parks as a moon chip you can tap; deck, menus, leaving the garden, swapping the pet, a missing nest are all handled; nothing times out into done. The server checks every route |
| 6 | Footsteps pulsing, more eye-catching, everywhere | "Glow steps" on every trail: bigger cream-gold paws, a pulse wave toward the goal, a target ring, readable at night; when the Bear leads, prints pop in under its feet |
| 7 | "You're all set" more fun | Bear jump-spin, Aero bubbles and confetti, three stamps (Pet, Nest, Stars) with rising chimes, a punchy title, "What's next?" opens Things to do |
| 8 | Petting screen cuter, Nintendogs-like | A mitten hand, the pet leans in and watches the hand, a Happy heart that fills to a burst, reactions per spot, a favourite spot per pet, purr that rises; mechanic inspiration only, all our own look |
| 9 | First "drop a ball" deck cuter | Glass sky card with a looping picture, big gold countdown, egg on grass knocking from inside, egg pips, sparks and combo words |
| 10 | Onboarding doesn't cover park, mini games, wardrobe | Designed as part 2 (one invite at a time after "You're all set", never pushy); not built yet. The wardrobe invite waits on Paint, Shine, Dress settling |
| 11 | Redo materials/colour/hue first? | Fable: simplify, don't rebuild. You said build it: one Dress up door (Colour, Shine, Outfit, Charm), paint pots you can pick (15 Stars, placeholder), Shine as a slider, Paint Egg and Snack Egg names. Save data unchanged |
| 12 | Plain balls | Felt is a patchwork, plus a polka-dot ball and a ringed ball (painted textures later) |
| 13 | Balloons crowded, some higher | Seven at three heights, two far skyline ones, none over the hub |
| 14 | Balloons too loud | A third as loud, heard only within 16 studs |
| 15 | Shake trees, fruit in the trees | Fruit now sits in the leaves (five a tree, seven at Blossom Point); a Shake prompt at each fruit tree (R / X / tap); the bump still works |
| 16 | Bigger trees, more plants | Shade trees x1.35, three edge trees x1.6, fruit trees x1.15 (new trunk meshes uploaded); 32 bushes and 14 reed clumps added (new meshes, two Fable rounds) |

## How it was checked

- Offline specs: 130 pass.
- Reviews: architect on the paint pots (5 changes applied); code review of the batch and of the Bear's lead (all should-fixes applied).
- Studio Play: deck, stork, crack, Bear card, garden; found and fixed two real bugs there (the Bear hidden behind you, the bubble vanishing after 20 s idle).
- Hash 594 scripts 1797993840 = repo; specs stripped; Rojo stopped. Translations exported (beta: no sync).

## Not checked

- Petting, the lead, all-set, Dress up, a pot buy and Shake played by hand (the test tools can't press those). A phone.

## Waiting on you

1. Your test pass (`TEST-PASS-B38.md`).
2. Paint pot price: 15 Stars OK?
3. Optional: a one-time "+5 ★ welcome gift" on "You're all set", and one free pot + one free hat in onboarding part 2.
