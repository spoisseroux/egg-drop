# Spencer's notes on beta (42), 2026-11-27

Build: beta (42), v144, runtime 3af66671, Pocket Pals Beta. Played from `/freshsave`. Overall: "otherwise great".
Shots: `shot-69-menu-pointer.png` (the Menu lesson pointer), `shot-70-first-deck.webp` (the Welcome deck: NEXT ball clipped, oval strokes behind the pips),
`shot-71-pet-screen.webp` (pet screen: no name, overlay not behind the top bar), `shot-72-gift-shop.webp` (the shop in gift mode), `shot-73-gift-card.webp` (the gift card).

## A. Pointer, shop and gifts

| # | Note (his words, trimmed) | Lane |
|---|---|---|
| 1 | "we need a better hand icon pointer thing, and can we make the highlight a circle too?" | Fable art, Opus build |
| 2 | "it says free egg above the bear, but not go to the egg machine" | Copy |
| 3 | "the disabled overlay on the other buttons looks f'd up, the corners are too rounded? and theres a second non animating stroke over the free paint egg we dont need" | Opus (shop gift mode) |
| 4 | "when we click paint egg, it should move the hand to point us to click hatch egg then" | Opus (pointer steps) |
| 5 | "why arent we using the regular hatch screen when doing the free egg hatch? Is that a one off? just use the fullscreen regular egg hatch anim/screen" | Opus (gift reveal = the normal hatch reveal) |

## B. Onboarding coverage

| # | Note | Lane |
|---|---|---|
| 6 | "after the egg when were playing a full game for the first time we need onboarding for the game too: how to read the ui, how to switch difficulty, quests, etc" | Fable design, Opus build |
| 7 | "the onboarding still doesnt cover the mini game and wardrobe and stats, snacks??? and a little section after dyeing showing how to reset the color" | Fable design, Opus build |
| 8 | "we also need to remember when a player has completed the onboarding so they dont have to repeat it on every update" | Opus (save fact, veteran rules) |

## C. First minutes

| # | Note | Lane |
|---|---|---|
| 9 | "the hat on the green bear on the right on the loading screen is clipping into its head" | Opus/Fable (loading pals) |
| 10 | "on the first pocket deck the next ball is weird and getting clipped" | Opus (WelcomeDeck2) |
| 11 | "weird oval strokes behind the grey transparent eggs below the egg on the first pocket deck" | Opus (WelcomeDeck2 pips) |
| 12 | "Can we get a better look of the egg when the stork is delivering it? and can the stork make a sound too? wings flapping? a bird noise?" | Fable camera, sound needs a source (no AI audio) |

## D. Pet screen and the pet

| # | Note | Lane |
|---|---|---|
| 13 | "the pet bear screen is missing a name too? it should just be pet until a name is assigned" | Opus |
| 14 | "the pick up icon is still old" | Fable/Opus (the ↑ button) |
| 15 | "the transparent overlay bg in the pet screen doesnt go behind the whole screen / notification area" | Opus (IgnoreGuiInset) |
| 16 | "when the pet is running it looks weird, the torso isnt moving with its feet, the torso is too high above the feet; when you pet and it jumps the torso and above move but not the feet" | Opus (rig pose) |
| 17 | "the pet is all jittery when petting it too, needs to animate smoother" | Opus (PetCuddle) |

## E. Garden

| # | Note | Lane |
|---|---|---|
| 18 | "Why wont my pet eat the fruit shaken off the tree? we should be able to shake the tree multiple times getting one fruit each time if theyre on there" | Opus |
| 19 | "birds are teleporting all over the place" | Opus |
| 20 | "fruit should be higher up in the tree mesh too like animal crossing" | Opus/Fable |
| 21 | "the rock at the bottom of the stairs going up to the terrace is missing a collider" | Opus (world) |

## F. Questions

- "what do we still have to do before shipping? night music?"
- "if i send you stems can you make them better"
