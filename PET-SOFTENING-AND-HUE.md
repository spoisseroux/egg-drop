# Softer babies and Hue Eggs

Zivvi and Ovelle should look young before either one moves. Give their faces room for a blink, let their weight settle, and keep the brightest colors for small details that players can eventually choose. This pass replaces the two v225 model designs. The next progression slice introduces Hue Eggs and the single Stars wallet.

![Comparison of the v225 and revised Blender models at the same scale](assets/garden-babies/softening-comparison.png)

## Two silhouettes

| | Form and face | Base and accents |
|---|---|---|
| Zivvi | A rounded dumpling with a broad forehead, two low uneven crown bumps and a planted stance. The small mouth retains six ivory milk teeth. Its curious pose tilts the head. Its affectionate pose folds the hands under the cheeks. | Warm porcelain `#E5DBD0`, dusty rose `#C595A0`, cocoa-plum eyes `#443641`, muted peach cheeks `#D9A6A2`. |
| Ovelle | A gently asymmetric river-pebble head on a short hovering body. Each shoulder ends in one short attached mitten with a small colored tip. The fine crescent mouth and suspended feet distinguish Ovelle from Zivvi at garden distance. | Pale cool stone `#D3DBD9`, soft sage `#A2BCAA`, charcoal eyes `#404149`, powder-rose cheeks `#D6AFB0`. |

Both use a small floating dot in their secondary color. Keep the dark eyes and their catchlights readable at night. Concentrate highlight on cheeks, crown and mittens while preserving a rounded transition into shadow. Recheck in the actual garden after imported mesh repair and under the hatch viewport’s separate light. The matched Blender views establish form and palette. The Roblox engine determines the final material rendering.

## Life and movement

- Blink once over 120–170 ms every 3.2–5.4 s, with a stable phase per owner. Lower the lids quickly, pause briefly, then reopen. A sleeping or affectionate eye keeps its pose. During contact the hands fold, eyes close and existing accepted-contact feedback takes priority. At release the curious eyes reopen.
- Give the chest a slow 2.5–3.4 s breath with at most 0.018 stud of head travel, grounded feet and occasional 2–3° gaze shifts with long holds. Animate the dot in its own local offset, lagging the head by about a quarter-second. Bound its vertical travel to ±0.06 stud, lateral travel to ±0.018, and squash to 4%. Reserve its swept volume only while visible. Reduced motion shows the settled expression and keeps the charm still.
- Select paths on the existing server decision clock. Derive each moving leg’s duration from its length and an explicit baby walking speed. Ease into and out of short actions. Join subsequent legs to the previous sampled position and heading, turn toward a greeting partner before arrival, and hold on the spot between decisions. Reserve teleportation for explicit respawn or discontinuities already handled by the host. Keep the authoritative 7-stud care check and the independent camera lens. The owner and both observers sample the same server start time.
- Verify a 45-second two-client trace across solo toy play, approach, paired greeting, rest, focus, Back and Deck. Record the largest ordinary one-frame displacement and heading change. Capture the same walk at 30 and 60 FPS, both faces before/during/after contact, the dot on/off, Reduced and a ranked crest. Check 749×381 and portrait with 55–65% reachable body coverage and full visible dot clearance. Compare whole-frame timing and node counts with the v225 scene.

## PocketDeck

Use stronger directional bands, halftone or broken arcs and sharper light/dark color transitions in exterior gutters. Size them to read at phone scale while keeping the existing pattern allocation and one sampled motion owner. Reduced motion keeps a composed still. The LCD remains clear enough to judge a drop. Remove DROP, FALLING and other state captions adjacent to the physical A control from every layout; keep the A face, its action description, the 44 px target and gesture instructions. Keep the highlight requested behind the balls distinct from ball materials and from reward or charge states. Inspect it with each rendering backend and at the first bright field row.

## Next progression slice • Hue Eggs

**One purchase buys one named direction on one chosen, owned baby.** Offer four deterministic Hue Eggs at a proposed private-test price of **8 Stars** each. Show the actual pet, current body colors, resulting colors, direction, rank increase, secondary unlock and resulting wallet before the player spends. A fresh account with the six-Star welcome grant can afford one after a daily gift or a successful field run. The price is a test value. Measure time to the first reachable egg with real play.

| Egg | Direction and preview swatch | First use |
|---|---|---|
| Rose Hue Egg | Rose `#D988A1` | Adds Rose 1 and makes Rose available as a secondary on this pet. |
| Tide Hue Egg | Blue `#77AAD3` | Adds Tide 1 and unlocks its blue secondary. |
| Citrus Hue Egg | Yellow `#E7C764` | Adds Citrus 1 and unlocks its yellow secondary. |
| Iris Hue Egg | Violet `#A994D4` | Adds Iris 1 and unlocks its violet secondary. |

Each pet has four small integer ranks, initially zero, each capped at three. Eating a Rose egg advances only that pet’s Rose rank by one and selects Rose as its active body direction. The other three ranks keep their exact values. Rank 1, 2 and 3 use increasingly strong body tints, with initial weights **12%, 23%, 35%** between the authored base and the direction swatch in the same linear-light color space used by the preview. Verify their actual visible separation in noon, dusk and hatch lighting. Facial ink, blush, mouth and ivory remain authored colors. A free body selector offers Original plus every learned direction. Selecting Original restores the original body immediately while retaining every rank.

Secondary choice is independent. An owned swatch recolors only the feet, mitten details and optional dot. Default uses that species’ original secondary. All learned secondary choices remain selectable without spending, including while the dot is off. Preserve the prior selected secondary when an egg unlocks another; offer **Equip Rose accents** as a separate explicit action. If a direction is already rank 3, show **Max rank** and prevent spending. A table of four named ranks is easier to read than a composite of several tint directions.

**Example.** Zivvi has Tide 2, Rose 0 and default dusty-rose accents. A Rose Hue Egg changes the saved Tide 2 / Rose 0 to Tide 2 / Rose 1, spends exactly 8 Stars, selects Rose body and unlocks its secondary. The player may return to the Tide body and equip Rose accents. The dot adopts Rose whenever visible. A third Rose purchase from rank 2 reaches rank 3; a fourth attempt costs zero.

### Storage, replay and unlocks

1. Present the current nectar balance as Stars at one-for-one value throughout the game. Keep the same existing authoritative balance field and all historical amounts and IDs. Run, daily, petting and hatch transactions still share one wallet. Keep each existing hatch result, companion inventory, cost, miss count, mastery, appearance unlock and daily day.
2. Key ranks by the existing persistent pet ID (`pip` displays Zivvi, `puddle` displays Ovelle). Begin sales for the two revised species. Existing owners start with their original colors and four zero ranks. Keep records sparse. Store debit, rank increment, unlocked direction, active body and receipt ID in the **same committed record and update** as the wallet. Do not grant colors in a separate profile write after spending. The existing per-pet Dot boolean remains independently confirmed.
3. A Hue request includes a unique operation ID, exact pet, hue, quoted rank and expected wallet revision. The server validates ownership, current rank, cap, price and balance against canonical state. A stale preview refreshes without charging. Duplicate/retried operations return the original receipt exactly once. Serialize with concurrent run/claim/pet payouts and companion purchases. A pending saved reveal remains recoverable. If the current host requires it to be resolved before spending, honor that fence and show the pending action.
4. Confirm colors only after a saved result. Publish a compact selected-body/grade/secondary token to nursery UI, equipped model, hatch, journal portrait and visitor snapshot. Validate every free equip against saved per-pet unlocks. Reject unknown or cross-pet secondary IDs. A player can switch pets and return without losing either selection. Render pending or rejected operations with the last confirmed palette on observers.
5. Keep Hue Eggs visibly separate from Companion, Training and Supply offers. Hue purchases never add pet inventory bits, roll rarity, change pity, modify battle power, reduce another stat, or seize a hatch acknowledgment. Keep Hue Eggs earned with Stars, with no purchase odds, extra currency or daily use limit beyond the visible per-pet rank cap.

### Acceptance for progression

- Migrate sparse legacy snapshots and replay pending run/hatch/daily receipts. Compare the old balance to the new Stars readout, every owned bit, pity and result ID before/after, including prices, contracts, receipts, prompts, gift text, hatch UI and accessibility labels.
- Exercise one successful use, repeat use, duplicate click, reconnect after save, timeout then confirmed retry, stale wallet/rank, cap, insufficient Stars, unsupported pet, switched pet, simultaneous wallet award and client-provided arbitrary color. Inspect both the balance and saved color; no half-applied grant.
- Verify free independent body/secondary equip, Original, hatch/journal preview, hidden then restored dot, and second-client observer colors, including Medium/Largest layouts and native phone. Keep all RGB/tint math in one tested palette resolver across those views.
