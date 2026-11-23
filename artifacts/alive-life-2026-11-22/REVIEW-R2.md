# Garden life, round 2 review (Fable, 2026-11-22)

**Verdict: NO-GO, for the bird's front view only.** One small fix (3 parts, below), then GO on the lead's own check of two captures; no further review round from me is needed. Butterfly, petals and bubbles pass as built.

Seen: all six `round2/` captures against `round1/`. The lead's four notes are all correct.

| Thing | Capture | Verdict |
|---|---|---|
| Bird, 3/4 | bird-side | Pass. Round, cute, the cream-rimmed eye and glint carry it. Wing is small and reads as a cheek fin, not a wing (later). |
| Bird, front | bird-front | Fail. No eyes visible at all: the through-cylinder shows only two navy ear-muffs. Beak is a flat yellow rectangle. A faceless bird a quarter of the time. |
| Butterfly | butterfly-open, -up | Pass. Lobes, veins, edge dots and body all read in both poses. Huge step from round 1. |
| Petals | petals-burst | Pass. Cream separates from crown and rock; small but visible, where round 1 was invisible. Judge size in a real gust, in motion. |
| Bubbles | bubble, bird-front | Pass. Unchanged look, rings read against rock and sky. |

## Fix now: bird face (replaces LOOK-R2 parts 2 and 3)

Offsets from root, forward -Z, degrees. None of this has been rendered: check it.

| Part | Shape | Size | CFrame | Decal |
|---|---|---|---|---|
| Eye R | Cylinder (axis X) | 0.06, 0.46, 0.46 | `CFrame.new(0.425, 0.128, -0.357) * Angles(0, 40, 0) * Angles(0, 0, 13)` | `bird-eye.png` on **Right** only |
| Eye L | Cylinder (axis X) | 0.06, 0.46, 0.46 | `CFrame.new(-0.425, 0.128, -0.357) * Angles(0, -40, 0) * Angles(0, 0, -13)` | `bird-eye.png` on **Left** only |
| Beak | Block | 0.26, 0.26, 0.26 | `CFrame.new(0, -0.04, -0.64) * Angles(-35.26, 0, 0) * Angles(0, 45, 0)` | beak colour, no decal |

- Eyes: two thin discs lying on the ball, turned 40 forward and 13 up, in place of the one 1.18 cylinder. Part colour stays #161C38. From the front each shows as an oval about 0.29 wide, from the side about 0.34 wide.
- Beak: a cube with one corner pointing forward, back half buried in the ball. Front view becomes a three-faced point (flat face on top, ridge below), side view a triangle about 0.27 long. Tip at z -0.865.
- Bird is now 6 parts (was 5).
- **Pass test, two captures (dead front, and side-on at 90):** front shows both pupils and a pointed beak with three shaded faces; side shows a round rimmed eye and no navy outside the body silhouette. If the beak fails, fall back to the round 2 wedge at 0.22, 0.22, 0.42, same offset, and publish anyway.

## Later (not blocking)

- **Wing, perched:** plate 0.04, 0.80, 0.56 (was 0.66, 0.46); right `CFrame.new(0.60, -0.08, 0.20) * Angles(0, -12, 0) * Angles(-55, 0, 0)`, left mirrored (x -0.60, yaw +12). The eyes moving forward frees the flank.
- **Petals:** if Spencer does not notice them in a gust, size 0.10 → 0.85 (±0.10), 1 → 0.75 (±0.10), and raise the "Never" maximum to 0.95.
- **Butterfly body:** if it reads as a brick up close, 0.08, 0.08, 0.50.

## Not yet seen (say so in the PLAY-BUILD entry)

Tide and Sun birds; both flying flap poses; Citrus, Iris and Tide butterflies and the underside; pink-crown petals; petals in a real gust rather than a test burst; small and large bubble in one frame.
