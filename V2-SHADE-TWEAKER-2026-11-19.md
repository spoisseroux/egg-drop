# V2 shade tweaker: Shade Drops (2026-11-19)

Written by Fable (as Astra). A proposal for Spencer to approve and Sol to build. Nothing here is built, and no `src/` file was changed.

Spencer's ask: "we need a shade color tweaker, so something we can get from eggs that lets us lighten or darken the color, for both first and secondary colors."

Mockups: `artifacts/v2-shade-tweaker-2026-11-19/`. Every number marked `[PLACEHOLDER]` is tunable and should be checked on a phone in Studio before it is fixed.

## Answers

| Question | Answer |
|---|---|
| What is it called? | **Shade Drops.** Two items: the **Sun Drop** (lighter) and the **Moon Drop** (darker). |
| What does one use do? | It **opens the next step** lighter (Sun) or darker (Moon) for one colour of one pet, and the pet wears that step. |
| Consumed or unlocked? | **Both, in the kind way.** The drop is used up, but the step it opens is **yours to keep** on that pet and colour. Moving between opened steps is free, any time. |
| How many steps? | **3 lighter and 3 darker** around the Original shade. The body (Main) stops at **2 darker**. The save can hold 5 each way, so more can be offered later. |
| Is it reversible? | Yes. **Original shade** is always free, and so is every step already opened. |
| Does a new hue reset the shade? | No. The shade is a step, not a colour, so it carries over to any dye. Opened steps are never lost. |
| Where do drops come from? | The **Customization Egg**, as a new pool version (9% each `[PLACEHOLDER]`). No new egg. |
| Is there a free way to try? | Yes. **Step 1 each way is open for everyone**, and every locked step can be tried on for free. The egg itself costs Stars, which are earned by playing. |
| Where is it in the game? | Customize, Hue tab: one **shade row** under the Main / Secondary switch. |
| Does it touch old saves or receipts? | No. Three new optional fields, two new actions, one new pool version. Nothing is renumbered, removed or reread. |
| Biggest thing for Sol | **Do not append to `LookEggCatalog.ItemOrder`.** `FoundLimit=1023` is a frozen 10-bit bound and all 10 bits are used. Drops get their own field (section 4). |

## 1. The item

### Name

- **Shade Drops** is the family name: jars change the colour, drops change how light or dark it is.
- **Sun Drop** makes a colour lighter. **Moon Drop** makes it darker. The garden already has day and night, and a sun and a crescent read without colour.
- I avoided food names (milk, cocoa) because v2 adds Snacks that pets eat.
- If Spencer wants it plainer: **Light Drop** and **Dark Drop**. Nothing else changes.

### What one use does

- Each pet has two colours: Main and Secondary. Each colour has its own row of steps.
- **Step 1 lighter and step 1 darker are open from the start**, on every pet, for free.
- One Sun Drop opens the next lighter step on one colour of one pet, and the pet moves to it at once. A Moon Drop does the same for darker.
- After that the step stays open on that pet and colour. Tap any open step to wear it. Tap **Original shade** to go back. Both are free.

### Why "opens a step" and not "one jar per move"

Hue jars are spent on every dose. I do not recommend that here:

- Children want to try, compare and go back. Paying a drop to undo a step punishes that.
- Shade is a small change. It should feel like a dial you own, not a cost.
- Drops still have lasting value, because steps are opened **per pet and per colour**. A new pet (the Bunny, the Kitten) starts with only step 1.

Cost of everything on one pet: 4 Sun Drops and 3 Moon Drops. Most children will want one or two steps.

### Steps and the safe range

Spencer's example was 5 lighter to 5 darker. I recommend 3 each way for now. On a phone-sized pet, 5 each way are too close to tell apart, and past 3 darker the pet stops looking like a soft toy. The save holds 5 each way (section 4), so steps 4 and 5 can be offered later without touching any save.

| | Lighter | Darker | Why |
|---|---|---|---|
| **Main** (body) | 3 | **2** | `CUTE-DESIGN-RULES` C1 wants a light pastel body. Two darker steps keep 83% of the brightness. `PET-STYLE-GUIDE` also warns that a very dark body looks flat at night. |
| **Secondary** | 3 | 3 | Paw tips, inner ears, charm and horns can go deeper. The muzzle is also secondary, so it stops before the nose and mouth get lost. |

The maths is the game's own `PetPalette.tint`, a mix in linear light:

- Lighter: mix towards white by **25%, 50%, 72%** `[PLACEHOLDER]`. It never reaches pure white (rule C5).
- Darker: mix towards black by **18%, 34%, 48%** `[PLACEHOLDER]`. This keeps the hue and the saturation, so it reads as a deeper colour, not a muddy one.

Measured on the sheet (`01-bear-shade-steps.png`):

| Colour | 3 lighter | Original | Darkest offered |
|---|---|---|---|
| Undyed body, white | no change | `#FFFFFF` | `#D4D4D4` (2 darker) |
| Undyed secondary, grey | `#EBEAEC` | `#A8A5AE` | `#7D7A81` (3 darker) |
| Body, Rose x2 | `#FFEAEE` | `#FFA4B8` | `#D48899` (2 darker) |
| Body, Iris x5 (strongest dye) | `#E7E0FF` | `#9350FF` | `#7941D4` (2 darker) |
| Secondary, Tide x3 | `#DFE7FC` | `#4791F4` | `#336BB6` (3 darker) |

Three things the sheet shows:

1. **Sun Drops are the cute direction.** A strong dye sits at 35 to 100% saturation. Three lighter steps bring Rose x2 down to 8 to 24%, which is the pastel range rule C1 asks for. Today there is no way to get a soft pastel from a strong dye.
2. **Lighter does nothing on the undyed white body.** Those dots "rest" (section 3) and a Sun Drop cannot be spent there, so no drop is ever wasted.
3. **A face guard is needed for the deepest dyes.** A darker step is not offered if the result's relative luminance falls below **0.10** `[PLACEHOLDER]`. On an Iris x5 secondary this rests step 3 darker, where the mouth would have 2.4 to 1 contrast against the muzzle. That dot rests too.

Honest limits: the sheet is a Blender render of the live Bear, not a Studio capture. The darker body steps look a little dusty in it. Check both ends on a phone, by day and at night, before fixing the numbers. The white ring round the dyed Bear's eyes is the known E4 issue in the Bear restyle lane, not part of this proposal.

## 2. Where you get it

### From the Customization Egg, as pool version 2

I recommend the Customization Egg, not a new egg and not the retired Hue Egg. It is already the egg for how a pet looks, and its rules already cover shown odds, pity, the fixed order for restricted players and quotes that bind a pool version.

Proposed odds `[PLACEHOLDER]`. M is the number of egg charms still missing. Every column is whole percentages and sums to exactly 100, so the shown odds are the real odds.

| Item | M = 3 | M = 2 | M = 1 | M = 0 | Pool 1 today |
|---|---:|---:|---:|---:|---:|
| Rose, Tide, Citrus, Iris (each) | 14 | 14 | 14 | 14 | 17 |
| **Sun Drop** | **9** | **9** | **9** | **9** | n/a |
| **Moon Drop** | **9** | **9** | **9** | **9** | n/a |
| Gloss | 7 | 8 | 9 | 10 | 10 to 13 |
| Matte | 7 | 8 | 9 | 10 | 10 to 13 |
| Jelly | 6 | 6 | 6 | 6 | 6 |
| Each missing charm | 2 | 2 | 2 | n/a | 2 |
| **Sum** | **100** | **100** | **100** | **100** | 100 |

- Check: hues and drops are 74. Then 74 + 14 + 6 + 6, 74 + 16 + 6 + 4, 74 + 18 + 6 + 2 and 74 + 20 + 6 + 0 are each 100.
- **Charm odds and pity do not change** (2% each, a charm on the 15th egg). Nobody's charm chase gets worse.
- Hue jars drop from 17% to 14% each. This is the cost, and the odds panel shows it.
- About 1 egg in 5.5 gives a drop. A named drop takes about 11 eggs on average.

### The frozen rules, one by one

| Rule | How this respects it |
|---|---|
| `ItemOrder` bits are append-only | Nothing is appended. All 10 bits of `lookFound` are used and `FoundLimit=1023` is frozen. Drops are tracked in a new field, `shadeFound`. |
| Retuning the tables is a new pool version | `PoolVersion=2`, and `PoolVersions` becomes `{[1]=true,[2]=true}`. Pool 1's table stays in the catalogue so old quotes and receipts still validate. |
| Odds sum to 100 and are shown | See the table. The odds panel lists Sun Drop and Moon Drop as their own rows. |
| Restricted players get a fixed, shown order | `Sun Drop` and `Moon Drop` are appended to the end of the pool 2 jar order. The existing rule holds: the item you hold fewest of, ties to the first in the order. The button names it ("Next: Sun Drop"). |
| Prices only grow | The price stays 12 Stars. `Prices` is not touched. |
| `catalogVersion` | Stays `"hue-items-v1"`. Changing it would reject every stored Hue receipt. |
| Stored bounds are frozen, tunables never validate a save | Section 4 separates them the same way `SheenLimit` and `SheenStops` do. |

### The free source

- **Step 1 each way is free and always open.** It needs no grant, no flag and no save data, so it cannot go wrong for an old save.
- **Trying is free:** any locked step can be previewed on the pet. Stars are earned from quests, so the egg can be opened without paying.
- Later, if wanted: a fixed Sun Drop and Moon Drop as quest or Book rewards. These are fixed gifts, not random, so the paid random item policy does not apply to them.

### Saves and receipts

- No save version bump. The hatching record stays v11 and gains optional fields; a missing field is valid.
- No stored receipt is reread or reshaped. Every existing action keeps its exact keys, and a pool 1 `lookBuy` receipt stays valid because pool 1 stays listed.
- **Rollout is expand, then contract**, as in plan risk R1. A server from before this change would reject a save holding the new fields or actions. So: ship the validators with nothing selling, record that place version as the new rollback floor in `PLAY-BUILD.md`, publish with "Migrate to latest update", then switch pool 2 on.

## 3. The Customize UI

See `02-customize-shade-row-844x390@2x.png` and `03-shade-row-states.png`.

### Where it sits

- Customize, **Hue** tab. The existing **Main / Secondary** switch already picks the colour.
- The **shade row** goes straight under that switch and above the jar cards. It shows the row for the chosen colour, so both colours get the same control.
- It is a row of dots, not a draggable slider. Dots are bigger targets for small thumbs, they work the same on a pad, and each one can show a lock.

### The row

- Sun at the left end, moon at the right. Main shows 6 dots (3, 2, 1, Original, 1, 2). Secondary shows 7.
- **Each dot is filled with the real colour that step gives** on this pet, with its current dye.
- Under each dot: its number, or "Original".

| Dot state | Looks like | Tap or A |
|---|---|---|
| Open | Plain dot | Wear it. Free. |
| Wearing now | Green ring and a tick | Nothing |
| Locked | A small padlock on the dot | Try it on. The button then offers the drop. |
| Focus | White ring (the house focus ring) | |
| Resting | Dark dot with a dash | Nothing. The pane says why ("Already as light as it goes"). |

### Live preview and the pane

- Moving to a dot shows that shade on the pet in the preview pane at once, with the Wardrobe's **TRY-ON** chip and two small dots comparing **NOW** and **TRY**.
- The jar cards' little pets also show the current shade, so a child sees the dye and the shade together.
- The pane's title is the step in plain words ("2 lighter"). Its button, by state:
  - open step: **Wear this shade**
  - locked step, drop in hand: **Use 1 Sun Drop**, with "You have 2. Opened steps are yours to keep."
  - locked step, no drop: **Find drops in the Customization Egg**, which opens the egg. Never a dead end.
  - a locked step two away: "Open step 2 first."
- Leaving the tab without pressing the button drops the try-on. Nothing is saved by browsing.
- One small card under the jars shows the drop counts and the egg link.

### Original shade and Original colour

- **Original shade** is the middle dot. On a pad it also has its own button (Y).
- **Original colour** (the existing free card) still resets the dye only. The shade step stays, and the opened steps stay open. The card's preview shows exactly what you will get.
- This keeps the existing `hueClear` action untouched. Question 4 below asks whether Spencer would rather it reset both.

### Phone, PC and pad

| | How |
|---|---|
| Phone | Tap a dot. Dots are 26 px with 44 px touch targets, 46 px apart. No dragging. Fits the 492 px left column at 844 x 390. |
| PC | Click a dot. Hover tries it on. Arrow keys move, Enter wears or uses. |
| Pad | D-pad up from the jar cards reaches the row. Left and right move. A wears or uses. Y is Original shade. LB swaps Main and Secondary, as now. |

## 4. Data and save shape (for Sol)

Three optional fields, two actions, one resolver change.

### Stored (hatching record v11, all optional)

| Field | Shape | Missing means | Validator (frozen bounds) |
|---|---|---|---|
| `shadeInventory` | `{sun=n, moon=n}` | both zero | keys in {sun, moon}; integers 0..`Hue.StackLimit` |
| `petShade` | `{[petId]={main=row, secondary=row}}`, where `row={at=-5..5, sun=0..5, moon=0..5}` | Original shade, nothing opened by drops | owned pet, `Hue.Supported`, exact keys, integers, `-moon-1 <= at <= sun+1` |
| `shadeFound` | bitmask 0..3 (bit 0 Sun, bit 1 Moon) | 0 | integer; the Book reads it |

- `at` is the step the pet wears. Positive is lighter, negative is darker, 0 is Original.
- `sun` and `moon` count the steps opened **by drops**. The free step is not stored: opened lighter steps = `sun + 1`.
- **`ShadeLimit=5` is the frozen stored bound.** The offered caps (Main 3 and 2, Secondary 3 and 3), the mix weights and the face guard are tunable. They clamp at render and at use, and are never used to validate a save. This is the `SheenLimit` and `SheenStops` pattern (plan risk R6).

### Actions (in `HueState`, beside `finishUse`)

| Action | Fields | Effect |
|---|---|---|
| `shadeUse` | `id, catalogVersion, petId, channel, itemId, shade, pendingResultId` | Spends one drop. `sun` or `moon` goes up by 1 and `at` moves to the new step. `shade` is the row the client saw; a mismatch gives `ShadeChanged`, as `counts` does in `hueUse`. |
| `shadeSet` | `id, catalogVersion, petId, channel, at, shade` | Free. Moves `at` inside the opened range. `at=0` is Original shade. |

- Refusals: `EmptyStock`, `MaxShade` (at the offered cap), `NoChange` (the step would not change the colour, or the face guard rests it), `LockedShade`, `ShadeChanged`.
- Receipts follow `finishUse`: `shadeBefore`, `shadeAfter`, `inventoryBefore`, `inventoryAfter`. A stored receipt must validate under any cap up to `ShadeLimit`, as `LookEggCatalog.stepValid` does.
- `shadeSet` is sent only when the child presses the button, never while browsing, so the 64-receipt ring is not flooded.
- `lookBuy` with `poolVersion=2` may give `sun` or `moon`. It lands in `shadeInventory` and sets the `shadeFound` bit.

### Server-owned apply

- The client never sends a colour. It sends a step.
- `Hue.appearance` adds two integers to the public appearance: `mainShade` and `secondaryShade`.
- `PetPalette.resolve` applies the shade **last**, after legacy presets and doses: `tint(colour, white or black, weight[step])`, with the step clamped to the offered cap and the face guard. One place, so the charm, horns, claws and wearables that take the secondary follow without extra work.
- Put the weights, caps and guard in one shared module (a `ShadeCatalog`), so the client preview and the server use the same maths.
- Rendering needs no new material templates. Body colour and `SurfaceAppearance.Color` can already change while the game runs.

### Catalogue changes

- `LookEggCatalog`: a per-pool table set and jar order. Pool 1 is unchanged. Pool 2 adds `sun` and `moon` with kind `"shade"`.
- Shade items get no `lookFound` bit, so the asserts on bits and `#ItemOrder<=10` must skip them. `fixedNext` reads `shadeInventory` for them.
- New UICopy keys, then the usual `export_localization_csv.py` and `sync_localization.py`.

### Suggested slices

1. **Foundation, dark.** `ShadeCatalog`, the three fields, validators, both actions accepted, pool 2 listed but not selling. New rollback floor.
2. **Free steps.** The resolver, the shade row, step 1 each way. No drops yet. This alone answers most of Spencer's ask and is safe to ship early.
3. **Drops.** Pool 2 on sale, odds panel rows, reveal, receipt, Book entries.

## 5. Mockups

All in `artifacts/v2-shade-tweaker-2026-11-19/`. No generated art.

| File | What it shows |
|---|---|
| `01-bear-shade-steps.png` | The Bear undyed (white and grey), dyed (Rose x2, Tide x3) and at the strongest dye, at every step of each colour, with hex values and the steps that are not offered. |
| `02-customize-shade-row-844x390@2x.png` | Customize, Hue tab, phone landscape: wearing 1 lighter, trying the locked 2 lighter. |
| `03-shade-row-states.png` | The row's states, the two drops, and the input map. |
| `render_bear_passes.py` | Renders three passes of the live Bear from `pet-bear.blend` in background Blender. Saves nothing back. |
| `build_mockups.py` | The colour maths and all three sheets. Reuses the house parts from `artifacts/v2-scope-2026-11-19/build_mockups.py`. |

The drop icons are drawn placeholders; final art should join the jar set. The header in `02` is the v2-scope house frame; the live Customize header stays as it is.

## 6. Questions for Spencer

1. **Names.** Sun Drop and Moon Drop, or the plainer Light Drop and Dark Drop?
2. **Kept or spent.** A drop opens a step for good (recommended), or one drop per move like hue jars?
3. **Steps.** 3 each way now, with room for 5 in the save (recommended), or 5 from day one?
4. **Original colour.** Reset the dye only (recommended, no change to a live action), or the dye and the shade together?
5. **Hue odds.** Is 17% to 14% per hue jar an acceptable cost for adding drops to the same egg?
