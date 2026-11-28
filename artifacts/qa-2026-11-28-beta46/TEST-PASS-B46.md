# Test pass: beta (46), 2026-11-28

**Build:** Pocket Pals Beta (place 107705084891479), **v162**, repo `972ac506`. Live untouched.

Covers the **Hidden Grove** world and rotation slice 2: **toy colours**, the **Deck Egg**, and **Angel Wings**. It builds on the beta (45) test doc (`artifacts/qa-2026-11-28-beta45/TEST-PASS-B45.md`), which is still open for your notes. Live is not touched.

**Start:**
- Use `/freshsave`, then rejoin.
- The grove is **off by default**. Type `/alive grove on`; it also needs the Aero look, which is on by default.
- Every other new piece is on by default on the beta. Each has a switch, so `off` tells you which piece caused a problem.

## A. The Hidden Grove (`/alive grove on|off`)

The garden you play on is unchanged. Around it, a deep green hollow replaces the open sky:
- a turquoise moat;
- three pale limestone cliff tiers with moss ledges, ferns and hanging vines;
- four waterfall gorges;
- nine giant trees whose crowns frame the sky opening;
- six tree houses with rope bridges and lanterns (scenery only);
- god rays from the sun gap.

| Try | Look for |
|---|---|
| Stand on the hub lawn and look all the way round | It feels enclosed and cosy, not dark. Pale warm stone, lime moss, sky through the opening. |
| Look toward the sun gap (south-east, mid-morning) | Soft god rays drift down onto the lawn without blowing it out. |
| Walk the rim and look down at the moat | No gap between the island's cliffs and the moat bank. The rocky underside of the old floating island is gone. |
| Night: wait for it, or `/hour at 3200` | Lanterns on the ledges and tree houses glow warm and aqua, and the rays turn cool cyan. Stays bright enough to see. |
| Ride a balloon or watch them | Balloons float under the canopy, never into the crowns. |
| Garden Dash, Sky Falls, the den, the park | Nothing on the island moved. The Sky Falls now lands in the moat. |
| Phone | Frame rate in the garden with the grove on: 5 rays, no extra waterfall streaks. |
| `/alive grove off` | The old floating-island sky comes back exactly. |

In-game shots from the first pass, before Fable's art fix: `artifacts/qa-2026-11-28-grove/studio/`. That pass showed bluish stone, square vines and faint rays; the art pass now on the beta fixes all three.

## B. Toy colours (`/rack toys on|off`)

- **Toy Colour Egg, 15 Stars.** Its tile appears in Hatch eggs once you own a toy, and has a "New" dot.
- **Daily picks:** each day it offers 3 toy colours, and at least one of them is for a toy you own.
- **Locked picks:** a pick for a toy you don't own says "Get toy".
- **Odds:** tap any odds row to see each colour on its toy.
- **Hatching:** the toy shows in its new colour, with a rarity sticker. "Use it!" gives your pet's toy that colour.
- **Other players** see that colour on your pet's toy, so try with two players.
- **Customize → Toys:** a swatch row under the toy, with "Original" first, then the colours you own. Tap to switch.

Checked in Studio: the tile, the Snow Squeaky Carrot at 100%, the reveal, and "Use it!", which other players see as the published colour.

## C. The Deck Egg (`/rack deck on|off`)

- **Deck Egg, 60 Stars.** Its tile appears after the Snack gift. Each day it offers 2 faceplates and 2 ball themes, with rarities, and owned ones drop out.
- **Deck style is now a closet.** Plates and ball themes you don't own say "From the Deck Egg" and have a "More at the Deck Egg" button.
- **What doesn't change:** plates you own stay yours and equip as before. Starter, Book and level-goal plates stay earned.
- **This week:** no plate or ball deals.
- **Hatching:** the plate or balls show flat on the stage, with a sticker. "Use it!" equips it, and the glass deck repaints to the new plate.

**Not checked in Studio**, because it needs the Snack gift on a fresh save. Please run through it.

## D. Angel Wings (`/rack wings on|off`)

- **Where they come from:** only on wings days, as the Outfit Egg's 1% Sparkle pick. They are never guaranteed and never sold.
  - **Today, 28 November, is a wings day until 05:00 UTC.** The next one is 7 December.
- **Look:** white feathered wings with a soft flap, a gold halo and a sparkle finish. Your pet's own grown wings rest while these are on.
- **Wardrobe:** a Back tab appears only once your pet owns the wings.
- **Today's picks:** tap the Angel Wings row. The card should show the Bear wearing the wings.
  - In the first Studio pass that card was a flat white disc, because only the first eight cards got previews.
  - The fix is in this build: scroll down to the wings card to see it.

## Known stand-ins and gaps

- **Prices** for the Toy Colour Egg (15) and the Deck Egg (60) are placeholders, and so are the toy colours' hexes.
- **Wings** come only for Bear and Bunny.
- **Deck plates** don't come in colour variants.
- **The toy reveal's glow** uses the toy's own rarity. The sticker shows the colour's rarity.

## Before live (decisions, not tests)

- **Charm pity:** cut, with no grandfathering (your call tonight).
- **Grove:** it needs a live switch, store thumbnails and a listing audit.
- **The 128-wearables cap:** the loosened save validator has to ship to live first.
- **Server cost:** cache today's picks per pet.
