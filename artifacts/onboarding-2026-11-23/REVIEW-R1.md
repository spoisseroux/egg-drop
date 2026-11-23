# Sleepy Nest: review R1 (Fable, 2026-11-23)

Seen: all six captures in `studio/` (1 to 6), plus crops of 4, 5 and 6.

**Verdict: GO for the private beta.** Nothing is broken or off-brand. Three small fixes before Spencer looks, the rest later.

## What works
- Up close (6) the nest is right: the weave holds on the cylinders, no smear, the two browns read as woven. Keep the Texture.
- The egg is the best thing in the frame: lilac, zigzag band, star, soft shine. The moon flag reads at once.
- The "Ready in 8 h." pill is legible at 10 studs. "Sleep tight. It will wait for you." lands.
- The HUD chip is clear and sits level with the dock; "8 h" reads.

## Fix now (before Spencer's look)
1. **The Tuck in prompt fires at arrival and covers the egg (4).** `MaxActivationDistance` 6 (spawn is 10 away), and `UIOffset = Vector2.new(0, 72)` so it sits under the nest, never on it.
2. **The info line is too much and unreadable (4, 5).** White stroked 10 px text on grass, two lines. Show line two only within 8 studs (not 14). Drop `nest.count` ("Egg 1 of 7") from the world label; keep it for the gift tile. Put `nest.inside` in its own cream pill, ink text, 13 px, 4 px under the first.
3. **G keycap is too small and sits on the bubble's tail (4, 5).** Cap 22 x 22 px (now about 14), text Strong 14, moved to the bubble's top right: anchor (1, 0), offset (+6, -6).
4. **Hide the nest label while the pet focus camera is on (6).** It floats over the Bear's head and reads as the Bear's speech.

## Fix later
5. **At 10 studs the rim reads as a hexagonal planter, not a nest (4, 5).** Go to 8 rolls: a = 22.5 + 45k, 1.25 long, 0.80 across, y 0.50, ends tipped +10 / -10. Base stays 3.0.
6. **Cushion reads as a flat white plate.** Colour #FFE9C2, 2.4 across, and add a second disc 1.5 across, 0.10 thick at y 0.70, #FFF4DA, so it domes.
7. **Egg is small from the dais.** `small` scale 1.25 to 1.5, `glow` 1.6 to 1.75. Rocking and ready stay 2.0.
8. **Leaves read as a lime slab behind the egg (6).** `ImageColor3` #8FCF6A, plate 0.8 x 0.48, or delete if it still blocks.
9. **Chip:** icon looks about 14 px with a loose gap. Icon 22 (18 compact), 6 px to the text, pill about 76 px wide for "8 h", 8 px left of the dock. Navy next to green dock is fine: it is a status, not a button.
10. **Prompt style:** the stock dark Roblox prompt is the only off-kit thing in the frame. Give it the Kit cream prompt when there is a slot.

## Not shown, still wanted
- The egg's face: every capture is from behind or blocked by the Bear. One shot from the dais side at 4 studs.
- The Bear curled at (1.9, 0, -1.3) after the yawn: in 5 it is still on the dais.
- The gift tile, the glow / rocking / ready looks, one hatch, the chip in gold, and a phone-size arrival frame.

## Arrival clutter
With fix 1 and 2 the arrival frame carries one pill, one bubble and the chip. That is fine. As captured (pill, two lines, prompt, bubble, G, chip) it is one too many.
