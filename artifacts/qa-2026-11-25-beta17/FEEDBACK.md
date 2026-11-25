# Beta (17) QA, Spencer, 2026-11-25 (night): triage + overnight plan (Opus)

Source: `C:\Users\skunk\Documents\obsidian-spencer\pocketpals\qa pass nov 24 2026.md`, 6 screenshots in `shots/`.
Spencer: "do everything agentically bc im going to bed? overnight ... you should have more usage now".

## Direction
- **The small-cave Play Den "sucks": skip it.** Build the cliff path, the larger cave (the real Play Den) and the new tiered area now.
- "What is the meadow pad?" (the Garden Dash start pad in the east meadow; explain in plain words in the morning).
- **Race music:** placeholders for the race song and the race finish song.
- **Race start and finish area models:** better, more cohesive.
- **"Think more about how we can make the world look more alive; research how to make a Roblox world feel alive and high quality."**
- **Pet park by the cliff:** a different layout and shape from the other one, more natural to the landscape, with some intrigue.
- **River stepping stones:** give them colliders (shot 012655).

## Bugs
- **U1 HUD chips (shot 012050):** "Pets playing" (bottom right) hides behind the egg chip; move the egg chip into the notification area? The top chip says "Games 0/3": what does it mean? Should it say "Pets playing 0/3"? Is 3 the max? Redundant with the bottom one.
- **U2 PC cursor locked to the camera on the napping egg card (shot 012230):** can't click "Got it". "How do I unlock my cursor on PC? It's confusing."
- **U3 Peek with E just opens that card:** Peek should show the egg, not the help card.
- **U4 Hatch eggs egg preview (shot 012340):** the circle/effects behind the egg are misaligned depending on screen size.
- **U5 The crank and capsule still never seen:** "the hatch animation just immediately started". Want it like a capsule toy machine: the egg comes out of the machine, then the hatch animation (likely cause: the buy happens with the Hatch eggs screen open, so the crank plays hidden behind the UI and the reveal starts at once).
- **U6 A weird shadow always off to the right after hatching (shot 012422).**
- **U7 Bubble billboards shouldn't rotate** (the lighting highlights make them look fake).
- **U8 The Bunny floats in the air (shot 012940):** it behaves as if held (the put-down arrow shows) while Spencer isn't holding it; stuck in the air. He was standing on the cliff above the den.

## Overnight routing
- Fable (world): research "alive, high-quality Roblox worlds"; the cliff pet park; the race start/finish area; river stones look. Fable (UX): the capsule sequence (original, not a copy of any game's machine), HUD chips, Peek, bubbles.
- Opus (world): take over the island session's cliff path + larger cave + terrace top pack (branch `claude/cliff-den-scope`; its collision failed Studio probes; the island session is out of usage until Nov 29), Play Den step B, retire the small-cave step A.
- Opus (bugs): U2, U4, U6, U8, river stone colliders.
- Opus (audio): race song + finish sting placeholders (drafts from 2026-11-23, `audio/` on branch `worktree-agent-a228c4a3651a98d28`).
- Then: Fable's specs built, reviews, Studio checks, Fable on captures; publish beta (18) if green.
