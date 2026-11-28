# Spencer's notes on beta (40), 2026-11-27

Build: beta (40), v137, runtime 91a5d282, Pocket Pals Beta. Played from `/freshsave`.
Shots: `shot-65-pet-buttons.webp` (pet screen: Dress up / Stats / Snacks), `shot-66-gift-card.webp` ("A gift from Bear!" Iris paint pot card),
`shot-67-deck.webp` (the playfield at the start of a round), `shot-68-results.webp` (the results screen, "So close!").

Overall: "looks decent over all".

## A. Onboarding and the garden

| # | Note (his words, trimmed) | Lane |
|---|---|---|
| 1 | "the pet runs thru meshes when showing you to something, and the distance it runs before turning around is too short, and it takes too long to turn back around and run again, needs to be smoother" | Opus bug (PetLead) |
| 2 | "Sometimes when petting the pet the eyes still clip into the head mesh like when looking at extremes" | Opus bug (PetCuddle eye look) |
| 3 | "it said free paint egg gift and it led me to the machine but i dont see a free paint egg? ... oh i see i was supposed to click the free egg on the bear at the machine" | Fable flow, Opus build |
| 4 | "after i got it and clicked paint bear it just got stuck on the looking at the egg machine" | Opus bug (camera stuck) |
| 5 | "this new ui is only used once, lets just click the machine and it says free egg and highlights the paint egg so we teach users how to do it that way" | Fable flow, Opus build: the free egg goes through the normal machine UI |
| 6 | "we need that onboarding label above the pet to follow it more smoothly, its all jittery" | Opus bug (NeedBubble follow) |
| 7 | "it says in the notification bar hatches tomorrow, can we just make it say like hatches X hrs or mins" | Opus (drop the "tomorrow" special case) |
| 8 | "the onboarding didnt teach me how to use the menus, customize the bear, pocket deck, or play the minigame or park?" | Fable design (part 2), Opus build |

## B. The Pocket Deck

| # | Note | Lane |
|---|---|---|
| 9 | "the very first transition to the pocket deck on first start from the loading screens needs to be smoother" | Fable look, Opus build |
| 10 | "when we drop the ball even if were touching can we show the A button being pressed ... and the same when aiming left and right with the touch controls" | Opus |
| 11 | "animate the pocket deck to kinda warp on the side the button is being pressed, so the pocket deck feels more responsive. Like its being pressed down / pressed backwards" | Fable motion, Opus build |
| 12 | "should we animate the actual ball drop game area on the screen? it feels a bit static and sad?" | Fable look, Opus build |
| 13 | "when opening the pocket deck again the old balls from the last game are briefly visible, can we make sure its fresh?" | Opus bug |
| 14 | "should we add a more interesting transition animation into the pocket deck?" | Fable motion |
| 15 | "and a difficulty selection when opening it again?" | Fable flow |
| 16 | "the pocket deck ui still looks a bit crude, maybe the labels in the top left of each box look too close to the corner? maybe not rounded enough? more animation?" | Fable look |
| 17 | "the end game screen/audio needs to be better / more exciting?" | Fable look + sound |
