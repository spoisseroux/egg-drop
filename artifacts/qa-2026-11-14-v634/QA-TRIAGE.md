# QA triage — Spencer, November14, private v634

Source: exact `notes.md` copy of `C:\Users\skunk\Documents\obsidian-spencer\roblox qa pass nov 14.md`, plus14 referenced screenshots in `shots/`. Filenames preserve capture timestamps. The original note and attachments are untouched.

This pass layers onto the active unpublished world/park/onboarding build. **Do not publish.** Blip is parked: Spencer hates all new alien designs too and may want a different pet later. **Show the proposed new hatch animation to Spencer before production implementation.** Other authorized QA fixes can proceed safely in parallel with disjoint file ownership and review.

## Q1 — Phone Pocket Deck and board navigation

1. **143543:** Repair the garbled phone hardware: duplicate/misaligned arcs, textures and shell layers. Retain the full handheld and background, matching the PC design. Reproduce the actual phone geometry before changing it.
2. **143543:** Make bottom-left Quests clickable during a round; open readable quests without discarding the round. Preserve touch, keyboard and gamepad operation and existing pause/overlay rules.

## Q2 — Results stay inside the same Pocket Deck

3. **145600:** Preserve the playing shell, camera and LCD rectangles. Results animate new content into the existing left/center/right screen regions; do not switch to a differently framed handheld.
4. **145600:** Fix the double surface/texture visible on the rotating results Star's side. Verify front, side, back and movement rather than hiding the problem with a fixed camera.
5. **145600:** Review losing-round Stars. Current goal-met pay is not sufficient feedback for Spencer; scope a truthful score/participation-based payout for meaningful play, with no AFK, zero-input or retry farming. Keep one authoritative reward transaction.
6. **145600:** Results action becomes **Hatch eggs**, closes the deck and opens the egg store, rather than directly choosing/hatching a Toy Egg.
7. **145600:** Give the wallet more top clearance inside the LCD.
8. **145600:** Enable all four on-screen D-pad directions in results for actions and difficulty selection, with matching keyboard/gamepad navigation.

## Q3 — Global notification capsules and pet focus controls

9. **144217,144448:** Replace centered/under-topbar notifications with one quiet capsule to the **right of Roblox's topbar controls**, above game UI. Measure actual safe/CoreGui space; do not overlap the topbar, menus, wallet or phone controls. Apply consistently across notification sources.
10. **144336:** Put Bear's bond/heart card to the left of Pickup; it currently sits behind that button.
11. **144336:** Back, bond card and Pickup share a consistent height, with usable phone hit targets.

## Q4 — Menus, loading, help, affordability and feedback

12. **144448,145224:** Prewarm egg/faceplate/menu textures before exposing previews; prevent a blank gray egg or unfinished texture flash. Use a bounded loading/fallback state instead of blocking forever.
13. **144639:** Clean clipped borders and residual square corners in Hatch eggs, especially the right edge.
14. **144718:** Hatch eggs help text is cut off. Reduce oversized step illustrations and fit/wrap/scroll the explanatory text, including translated text.
15. **145005:** Check the Companions help screen for the same clipping issue.
16. **145005:** Explain what the heart meters do in clear player copy: bond progression and its rewards, rather than unexplained decoration.
17. **145005,145059,145224,145430:** Clean clipped borders/corners around Bear/item/faceplate/background preview wells across the menu family.
18. **145059,145224,145430:** Unaffordable Buy stays a visible, styled disabled button; it must not become transparent or look missing. Keep input inert and feedback truthful.
19. **145224:** Use one consistent shortfall convention wherever Stars can be spent, computed from the actual quote/deal price and current wallet.
20. **145059 onward:** Add restrained menu press sounds and occasional preview Bear reactions; avoid random reactions stealing focus or repeating every redraw. Respect sound/reduced-motion preferences.
21. **145430:** Add another original deck background, scoped by Astra and implemented procedurally by Sol.
22. **144718, untimed follow-up:** Reconcile stamp placement. Stamps track played days rather than egg count; keep the full daily card in Quests and make the relationship discoverable from Hatch eggs/help unless Spencer requests another layout.

## Q5 — Hatch/reveal redesign: idea first

23. **143649:** Replace the poor transition/hatch sequence with a coherent animation matching the patterned3D egg and atmosphere of the Hatch eggs store.
24. **143649:** Newly hatched Bear animates and shows excitement; do not present a static model and dialogue as the payoff.
25. **145947:** Item hatching also needs an engaging reveal. Scope shared stage language and an actual item demonstration, with sound/excitement appropriate to real item metadata; do not invent rarity claims or misleading odds.
26. **Untimed explicit instruction after144718:** Astra scopes this and Spencer sees the idea **before production implementation**. Produce a concept storyboard/animatic for review; leave production `HatchCinematic`/`RevealStage` redesign untouched until approval. Texture/preload and existing-menu bug fixes are separate work.

## Q6 — Pet Park progress clarity and reliability

27. **145500:** Investigate long delay before1/3; inspect approach, activity duration, cancellation, actor reservations and completion acknowledgement for stalls or collisions. Recheck on the new two-park/fetch implementation.
28. **145500:** Clarify2/3 with only one pet: this is daily completed activities, not number of pets/players. Solo play counts by design. Use explicit activities/progress copy and an active-activity cue; do not award unfinished activities merely to make the counter move sooner.

## Q7 — Music direction superseded

29. **Untimed closing paragraph:** Replace the prior music direction with an original pleasant/fun garden placeholder inspired by the feel of SA2 Battle Chao Garden/Hero Garden.
30. **Untimed closing paragraph:** Pocket Deck gets a distinct retro arrangement sharing the new original tune/harmony. Astra scopes the composition; Sol synthesizes, previews and integrates it. Preserve music/SFX controls and existing reveal ducking.

## Ownership and gates

- **Astra:** actual screenshot review, shared visual direction, hatch idea/storyboard, original paired music brief, background brief and critique of actual results.
- **Sol board/results lane:** Q1–Q2 and Q6, plus relevant authoritative reward code. Takes `DeckScreen.lua` only after the current Welcome checkpoint is tested and ownership is explicitly transferred.
- **Sol menus/global lane:** Q3–Q4; owns `init.client.lua` and `UICopy.lua` host edits for the QA batch. Other lanes supply append/glue blocks. Preserves the existing Welcome/first-spend implementation.
- **Coordinator:** source/screenshot archive, triage, architecture/code-review routing, Studio controls/tests/captures, integration and unpublished checkpoint. Preserve pre-existing unrelated dirty files.
- **Hatch production gate:** idea must be shown and approved first. **Place-publish hold remains active.** Physical-device, true two-owner and published-service checks are separate from isolated Studio fixtures.

The above default decisions resolve explanatory questions without reopening already delivered UI personality or changing the stamp economy. Newly found regressions are added here with evidence as they appear.
