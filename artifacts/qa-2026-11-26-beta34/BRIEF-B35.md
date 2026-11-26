# What changed for your beta (34) notes

Beta (35), place version v109, runtime 7674971b, on Pocket Pals Beta. **Live has not been touched.**
Test doc: `TEST-PASS-B35.md` (this folder). Your notes, one row each: `FEEDBACK.md`.

## Your 19 notes

| # | Your note | What was done |
|---|---|---|
| 1 | Spout leaf clips into the egg | The egg used to roll down the leaf's own line through the leaf. It now slides out of the base under the leaf and sits at the back of the cup, at least 0.013 studs clear the whole way (a spec checks it against the real shapes). The little hop that pushed it into the leaf is gone. |
| 2 | Stat Egg skips coming out of the machine | It had been left out on purpose in an earlier slice. It now plays the same machine shot, timing and sounds as the other eggs before its hatch, from every route (Hatch eggs, Hatch another, the medal Eggs button). |
| 3 | Goals need to be clearer | Each goal is now a sentence: "Make a green ● or bigger on the left", "Match two blue ● in the middle", "Make 3 quick merges in a row". Done goals say "Done!" in green. The results card uses the same words. |
| 4 | What does the chain do? | Checked in the code: each merge within 1.25 s of the last adds 10 points to it (Stars are not changed). The card now says "Quick merges in a row score more", and the number pops gold when it climbs. Phones (no room) get a one-time tip. |
| 5 | No quests button? | An earlier QA pass (13 Nov) removed the deck's quest chevron; the small PC layout never had a quests card. Now: an "Open" key on the Daily quests card, a quests key in the small layout, and the phone handle says "Quests". |
| 6 | Deck font bigger on PC | One knob, `DeckText.Desktop = 1.2`: deck and results text is 1.2x on PC. Phones unchanged. |
| 7 | Den entrance disconnected meshes | The den's inner shell had a plain grey front rim standing inside the rock arch; the gap behind it showed a strip of the terrace face (the "flap") and a grey slab. The mouth rock now wraps the arch with a lip over the rim, the terrace face stops above the mouth, and the rim's lining is re-textured as rock. The floor's stretched skirt is fixed too. |
| 8 | Missing faces at the stairs | They were the island's underside showing through where the lawn had been cut away round the bottom flight. The lawn is kept there and the path runs over it; a top-down ray sweep finds no more holes round the den and the path. The blocky rock patches on the cliff above the lower path are re-mapped as one rock. |
| 9 | New size feels great | Kept at 0.8 on the beta. |
| 10 | Pets walk through the slide | Every park walk was a straight line. Pets now route round every toy (its real, scaled footprint) and benches, entering a toy only at its own spot. The walk back to the ladder has 3.4 s instead of 2.2. |
| 11 | Walking more natural | Pets get going and settle in 0.4 s each (no more glide), turn before setting off, round corners in one curve, bob and waddle with each step (small pets step quicker), lean a little as they speed up, and pause to look round or sniff. Positions stay server-side; nothing new is sent per frame. |
| 12 | What are those pads? | Three old pet "rest daises" from the v7 world. Removed; plain lawn now. |
| 13 | Balls everyone and pets can kick | Three Bumble balls (felt, wicker, cork). Your own kick starts the same frame with its sound; the server checks it and sends the arc to everyone, and other players join the arc part-way and blend in over 0.15 s, so a bad connection means a later start, never a stutter or snap. A refused or clashing kick blends back. Pets sometimes nudge a resting ball. |
| 14 | Crunchy toys | Two leaf heaps, a row of six pop pods, a pebble tray and rattle gourds. All on your own screen (no network), reacting to you, other players and pets; sounds are stand-ins layered from the existing ASMR sounds until new takes are made. |
| 15 | Balloon on one string | Roped to both gate posts. |
| 16 | Egg on the rock | Now the game's own Companion Egg (cream, blue spots, the green band) in a twig-and-moss nest: a gentle rock, a big wobble every 35–50 s or when you walk up (sound, moss flecks, a buzz), a faint blue glow at night. |
| 17 | Something floating in the air | Nine paper lanterns over the hub, the bridge and the fountain: a warm faint core by day, glowing at night, kept clear of the trees; plus drifting seed fluff over the hub lawn by day. |
| 18 | Dash sign post through the text | The board hangs between two posts at its ends. |
| 19 | Reset my progress | `/freshsave` in chat, then rejoin (a new save each time); `/freshsave restore` brings yours back. |

## How it was checked

- Offline specs: 104 pass, 0 fail, including new ones for the goal words, the chain text, the balls' sim and network blend, the toys' and lanterns' placement, the Wobble Egg, the park routes and the walk.
- Code review: two passes (the garden/deck/egg merges, then pets), GO WITH CHANGES; every should-fix was fixed before publishing.
- Fable reviewed the Studio renders: the egg, the felt ball and the world fixes shipped as built; the lanterns, pods and gourds were rebuilt to her notes.
- Studio Play: everything mounts with no errors; a kick was accepted by the server and the ball rolled ~21 studs and settled in ~2 s; captures in `studio-b35/` and `studio-r8/`.

## Not done, or not checked

- **Pets** riding and walking, and a **two-player kick**: not watched in Studio (no pets in the Studio save, one player). Please watch E1–E3 and D6.
- **The deck changes and the pet walking go live with the next live update** (they're not beta-only, unlike the balls, toys, lanterns and egg). Tell me if you want any of them held back.
- New leaf/gravel/gourd sounds are stand-ins.
- Not seen on a real phone.
- A stray folder `C:\artifacts\qa-2026-11-26-beta34` (two Blender renders, copies are in the repo) can be deleted by hand.
