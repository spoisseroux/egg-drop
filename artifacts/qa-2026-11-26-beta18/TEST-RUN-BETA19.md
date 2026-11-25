# Pocket Pals QA run: beta (19)

**Where:** Pocket Pals Beta (place 107705084891479). Live is v1199 (the funnel and Hatch another fixes only).
**What's new since beta (18):** the ASMR hatch with vibration, and the beta (18) known issues. Everything in the beta (18) checklist (`TEST-RUN.md`) still applies.

---

## 1. The ASMR hatch (sounds made for the game, not heard by anyone yet)

- [ ] Hatch any egg. Under the usual hatch you should hear the egg settle, two cracks, a creak, a pop at the open and a few shell crumbs. A soft exhale on the first hatch, then every third one.
- [ ] Hatch 5 in a row ("Hatch another"). **Does it vary enough that it never sounds like a loop?** Each egg type has its own shell pitch.
- [ ] **Too loud or too quiet against the hatch music?** Does the pop hide the rarity sting?
- Switch: `/alive asmr off` gives exactly the old hatch.

## 2. Vibration (phone or gamepad)

- [ ] **On a phone:** does the hatch buzz at the cracks and the pop? Does a Pocket Deck merge give a small tick, and a big chain or a clear a stronger one?
- [ ] A long chain never buzzes non-stop (it is capped at 6 a second).
- [ ] Settings → **Vibration On/Off** (shown on phones and with a gamepad; hidden on PC without one). Off stops it at once.
- [ ] The egg machine's dial clicks tick too.

## 3. Beta (18) known issues

- [ ] **The top bar over a Stat Egg:** open a Stat Egg from Hatch eggs, and one from pet focus over the garden. The top bar stays hidden for the whole reveal and comes back after Close. "Hatch another" no longer flashes it.
- [ ] **River stones:** each bank's landing is a rock slab laid over the kerb. Walk lawn → landing → stones → other bank without jumping. **Does it read as a crossing now?** (In Studio the kerb's marble still shows a little next to the west landing.)
- [ ] **Den mouth:** bushes and a boulder now cover the tan faces beside the mouth. The den crystals glow amber, not lemon, by day and at night.
- Known: thin seams in the den walls (the wall mesh needs a mesh pass).

## Not in this build

The night garden song, the race results animation, art for the terrace and the den, pets on the cliff path. The live first-session changes (no garden tour, tomorrow strip, welcome bonus, paw trail to your pet) go to the live game, not the beta.

## Notes

(write here)
