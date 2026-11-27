# Pet customization audit (Fable, 2026-11-27)

Spencer's note 11: "should we redo the materials and color and hue and stuff system first?" (before the onboarding
teaches customizing).

**Answer: do not rebuild it. Simplify its front door first (one small slice), then teach it.** The rendering and the
saved data are sound. What a new player meets is the problem: the words, the number of doors, and not being able to
choose a colour.

## What exists today

| Piece | State | What it does |
|---|---|---|
| White and grey pets | live | a blank pet you colour in. The best idea in the system |
| Customization Egg, 12 Stars | live | one random jar: Rose, Tide, Citrus or Iris (17% each), Gloss or Matte (10 to 13%), Jelly (6%), or a rare charm (2% each, guaranteed by the 15th egg) |
| Hue | live | four pigments on Main and Secondary, 0 to 5 doses each, six mixes; an older "ranks and presets" model sits under it |
| Material (was Finish) | live | two meters: Shine, seven stops from Chalky to Glassy, and Jelly, three stages. One jar moves one stop |
| Charm | live | three shapes from the egg, three earned |
| Wardrobe | live | slot tabs, fixed prices 40 / 100 / 250 Stars, live preview, "This week" |
| Material Egg, Hue Egg | retired | still in code and a string ("Hue Egg") |
| Feature Egg, 40 Stars | off (`Features=false`) | horn buds, claws, folded wings |
| Stat Egg, 15 Stars | live | a training snack; not a look |

## What is confusing or weak

1. **You cannot choose your colour.** A kid who wants a blue Bear buys an egg and gets Citrus, or Matte. One blue jar
   takes about six eggs on average (70 Stars); a full five-dose blue about 29 eggs (350 Stars) and a pile of unwanted
   jars. The first thing a child wants from a white pet is the one thing left to chance.
2. **The words.** Hue, Material, Customization Egg, jar, dose, Main, Secondary, Rose, Tide, Citrus, Iris, Chalky,
   Satin, Glassy, Misty. Fifteen terms for "colour" and "shiny". "Tide" is blue and "Iris" is purple; a seven-year-old,
   or a translated string, will not get there.
3. **Too many doors.** Colour, charm and material are in Customize; outfits are in the Wardrobe, opened from the
   Companions editor at the Care Cradle; toys are a third screen; jars come from the egg machine. Nothing on the pet
   says "dress me".
4. **Material is two meters fed by consumables.** Shine goes both ways with two different jars, Jelly stacks on top.
   It previews well and explains badly.
5. **Eggs mean five things**: a pet, a toy, a jar, a snack, (hidden) a body part. The Customization Egg wears the Hue
   Egg's art and the Stat Egg wears the Feature Egg's.
6. **Features are off**, so the most dramatic change (wings, horns) is not there to teach.

## What a kid understands today

- The Wardrobe, completely: see the hat on my pet, see the price, buy, wear, take off.
- "My pet is white and I can paint it": the idea, not the route.
- Not: why the egg gave the wrong thing, Shine versus Jelly, a dose, or where any of it lives.

## Recommendation

**Simplify first, as one slice before onboarding part 2; do not redo the system.** Teaching today's front door means
writing tutorial steps for words we should delete, and the tutorial's first promise ("paint your Bear") would end at a
random egg. The data, renderer and frozen save bounds stay untouched: this is names, layout and one new way to get a
colour. If only one thing is done, let the player pick their first colour.

## Outline: "Paint, Shine, Dress"

**One door.** A "Dress up" button on the pet's focus screen (the Care Cradle still works). One screen, the pet large
in the middle, four tabs: **Colour, Shine, Outfit, Charm.** Toys stay with play.

**Colour (was Hue).**
- Jars become **paint pots**, named Pink, Blue, Yellow, Purple. Mixes show as their result (orange, green) in a
  ten-swatch ring.
- Two targets shown as pictures: the body, and the tummy and ears.
- Tap a swatch: the pet previews it. Five pips show depth; "Paint" spends one pot and fills one pip. The first pot is
  already 44% strength, so one pot visibly works.
- **Choose-your-pot:** sell single pots at a fixed price beside the egg (suggest 15 Stars against the egg's 12: the
  egg is the cheaper surprise, the pot the sure thing).

**Shine (was Material).** One slider read as Soft, Normal, Shiny, the seven stops as ticks. Jelly is a second row,
"See-through", three steps. Same jars and rules; only the picture changes.

**Outfit.** The Wardrobe, unchanged, behind the one door.

**Charm.** As now, with earn rules on locked ones.

**Eggs.** Customization Egg becomes **Paint Egg** with its own shell art. Stat Egg becomes **Snack Egg**, listed apart
from looks. "Hue Egg" and the Material Egg leave every visible string. The Feature Egg stays off until wings and horns
get their own slice, then joins as a fifth tab, "Extras".

**Onboarding part 2, after this lands.** "Your Bear is all white. Pick a colour!" One free pot of the player's choice,
paint, the Bear reacts. Then one free common hat. Two steps, each a choice, each visible to everyone in the garden.

## Cost and decisions

Mostly UICopy, layout and one fixed-price purchase path. No migration; `lookFound`, doses, finish rows and stored
prices are untouched. The renames need the localization export and sync. Spencer decides: the pot price, and the two
free gifts.
