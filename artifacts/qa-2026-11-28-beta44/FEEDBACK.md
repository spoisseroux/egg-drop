# Spencer's notes on beta (44), 2026-11-28

Build: beta (44), v151, runtime 4d40ea17, Pocket Pals Beta. Shots: `shot-74-gift-stage.webp` (the gift on the hatch stage), `shot-75-deck-tour.png` (the deck tour on Goals), `shot-76-results-buttons.png` (results: Replay / level / Hatch / Leave).
Music: "the new pocket deck songs sound great, and the new world ones" (garden v4, deck v5): ship them in this batch; use the deck song for the Garden Dash too (racers only).

## A. Hatch, machine and gifts

| # | Note (his words, trimmed) | Lane |
|---|---|---|
| 1 | "the background on the item preview on the hatch screen needs to have rounded corners too?" (shot-74: the preview's sky/grass corners are square inside the rounded frame) | UI |
| 2 | "i didnt hear the crank sound when hatching an egg?" | Audio bug |
| 3 | "the your free egg is inside the machine prompt over the pet needs to go away as soon as we press the hatch egg button" | Gifts |

## B. Onboarding

| # | Note | Lane |
|---|---|---|
| 4 | "after the first three combos to hatch the egg in onboarding the ui became weird, like the egg preview on the right became really small and weird?" | Welcome deck bug |
| 5 | "lets make it say in a bubble over its head 'lets try playing a game!' when prompting us to press the button to start the pocket deck tutorial" | Teach |
| 6 | "make sure that highlighted stroke in the pocket deck tutorial only shows up after the pocket deck starting up animation finishes" | Teach |
| 7 | "i still think the spacing and checklist size on the goals etc needs to look better, and be more clear somehow?" (shot-75) | Fable look |
| 8 | "can we have the pocket deck onboard show how to open quests there" | Teach |
| 9 | "what does score even do? more stars?" | Design answer + teach copy |
| 10 | "dont make the player finish a whole game then, just go thru the onboarding things there and close the pocket deck automatically and continue to the next thing" | Teach |
| 11 | "the pet says you can hatch one! when the next onboarding task is the pocket deck game onboarding, make it not do this" | Teach / BearNeeds |
| 12 | "it says you are done! before the player finishes the whole tutorial" | Teach |
| 13 | "the onboarding doesnt go over dressing up and materials still? or is it breaking when im navigating away from it to type to you?" | Teach (focus loss?) |
| 14 | "maybe to complete onboarding we can just put dress up your pet, customize your pet, fill your collection book, change your deck style, finish quests, etc in the things to do so players can learn they can do those things from there, rather than dragging on the tutorial" | Design: Things to do |

## C. Pet and garden

| # | Note | Lane |
|---|---|---|
| 15 | "the petting still feels weird, like the pets head jitters around" | Pet |
| 16 | "its pathfinding still sounds weird and unnatural running to the egg to tuck it in" | Lead |
| 17 | "the footprints leading to stuff are sometimes not facing the right way, and they need to pathfind around objects" | Trail |
| 18 | "I cant click my pet to open the petting screen, why???" | Bug (critical) |
| 19 | "i shake trees and hear the fruit fall but i never see it fall it just disappears" | Fruit bug |
| 20 | "add a collider to the garden entrance mesh etc, remove the sign by it, and the icon above the sign" | World |

## D. Deck and Dash

| # | Note | Lane |
|---|---|---|
| 21 | "dont you think the replay button is too close to the difficulty button? its unevenly spaced" (shot-76) | UI |
| 22 | "a server message when a race is about to begin? for other players to know to join? and a server message of who wins? like player name's pet [pet name if there is one besides default] won the garden dash!" | Dash |
| 23 | "footsteps dont appear when clicking show me on garden dash in the things to do" | Trail bug |
| 24 | "we can remove the play den from things to do for now" | Things |
| 25 | "lets use the new pocket deck song for the garden dash too (only for those participating)" | Audio |
