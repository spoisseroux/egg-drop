# v3 big test pass: what's built and how to test it

Spencer, 2026-11-22: "Keep track of what we've been implementing for a big test pass." **Kept current:** every slice adds its row when it lands on the beta, and ticks or notes come back here after the pass. Test on **Pocket Pals Beta** (place 107705084891479): it has its own saves and no Robux products. Live (96451847774961) is untouched at v1054.

Each piece has an owner chat switch on the beta (you only): `on`, `off` puts the game back as it was, `clear` follows the remote config. Use `off` to tell which piece caused a problem.

## On the beta now (beta (12), runtime 416ff26)

| # | Piece | Beta | What to try | Switch |
|---|---|---|---|---|
| 1 | **Bouncy menus and wind** (Alive 0-4) | (3) | Press buttons, tabs, toggles: they spring. Open and close menus fast: nothing sticks or doubles. Bushes, pennants, flags and chimes move with gusts; a soft rustle | `/alive springs|menus|close|wind off` |
| 2 | **Levels matter** (reward track, gated items, medals, deck juice) | (4) | Stats panel says what the next level gives. Wardrobe: a locked item shows "Needs Jump 15" and buying it costs nothing. A pet reaching 25 in a stat gets a free egg. Deck juice choices (pop, trail, start) | `/levels off` |
| 3 | **Garden Dash** | (5), moved in (6) | Walk to the pad in the east meadow, race once (Just for Fun, then Stats On, Time Trial). Avatar hides, camera follows the pet, everything comes back after. Prizes are off unless `garden_dash_prizes` is set | `/dash off` |
| 4 | **Blue garden** (Frutiger Aero Medium) | (6) | Blue sky, glossy water, egg dome, station rims, **lime trees**. Pets' faces readable in the light | `/aero off`, `/aero coral` |
| 5 | **Things to do** (Pocket menu) + tips | (6) | Pocket menu > Things to do: Play, Show me (footprints to the place), "?" cards. The park and race tips show once | `/todo off`, `/todo tips off` |
| 6 | **Garden finds** | (7) | After about a minute of walking a gold sparkle appears on a lawn; walk to it with your pet: pop, "+16 Smarts". 3 waiting at most, 12 a day; Things to do row "N finds waiting" with Show me | `/finds off` |
| 7 | **Garden life** | (8) | A round bird lands on the crown where you hear a chirp, hops, flies off when you get close; butterflies over flowers; soap bubbles drift by; petals off the lime trees in gusts. Gone in deck rounds and races | `/alive life off` |
| 8 | **Textured lime trees** | (9) | Lime crowns show leaf clumps and highlights, still lime, never olive or white | `/aero off` |
| 9 | **Island edges** | (9) | Try to climb the mountains (east grass ramp by spawn, the north spur, behind the waterfall pool) and walk or jump off the island: blocked, or you're put back where you last stood. Pets never stuck behind a wall | `/bounds off` |
| 11 | **New first session: follow the Bear + need bubbles** | (10) | On a NEW save: no tour cards; a hand bubble over the Bear (tap it, tap the Bear, or press G / L2) opens the greeting; then a ball bubble, paw prints and a "Hatch eggs" label; stand still 20 s for a hint. Returning saves see none of it | `/onboard follow off`, `/onboard needs off` |
| 12 | **The Bear's Sleepy Nest + welcome week** | (10) | Next to the arch: "Ready in 8 h", walk up and Tuck in. After 8 h, Hatch: a gift (day 1 a beanie + 10 Stars ... day 7 a Nest Charm + 25), the next egg starts; HUD chip counts down. Never pays twice; nothing to buy | `/onboard nest off` |
| 13 | **"See you tomorrow" strip** | (10) | On deck results and Dash results: nest time, tomorrow's stamp Stars, new quests | `/onboard nest off` |
| 14 | **Waterfall layers** | (10) | Strands, white edges, foam, ripple rings, mist (fades near the camera), a faint rainbow | `/aero off` |
| 15 | **Dewdrop fruit** | (11) | Under the lime trees: honey-coral drops with a leaf cap; in a strong gust some fall, bounce and roll, rest, then fade. Walk your pet near one: it hops. Two players see the same drops | `/alive life off` |
| 16 | **Garden hour (1-hour day/night)** | (12) | OFF until you type `/hour on`. Then `/hour at 3100` (night: lamps, stars, fireflies; the Bear awake and readable), `/hour at 2600` (golden), `/hour at 120` (dawn), `/hour at 1000` (day); watch a blend (e.g. `/hour at 2350`) for jumps; `/hour off` puts the normal day back | `/hour off`, `/hour clear` |

## Built, not on the beta yet

| # | Piece | Status | What to try |
|---|---|---|---|
| 10 | **First-session tracking fix (live hotfix)** | Reviewed GO; waits for your go to publish live | Nothing to see in game; the funnel in Creator Hub becomes accurate |
| 15 | **Dewdrop fruit** (Garden life, looks only) | Built on a branch, offline specs green; Studio and Fable's capture review next | Two or three glossy honey-coral drops hang under each lime tree and sway; in a strong gust one lets go, bounces twice, rolls downwind, rests, fades and grows back later. Your pet beside a fallen one bats it once. Never on a find, the race course or the park; nothing to collect. Reduced Motion: they just hang. Switch: `/alive life off` |
| 17 | **Island re-export: swaying trees, new waterfall, fountain** | Built on branch `claude/island-reexport-337cd0`, checked in Studio, Fable GO, code review GO; waits for your OK to publish to the beta | Trees sway from the trunk top (gentle in the breeze, a lean in a gust; 6 nearest on a phone); lime trees matte, less neon; walk the camera into a crown: it goes see-through. Tumble Falls: white water streaming over dark wet rock, spray and a foam apron at the foot, rocks you can't walk through. The meadow bubble spring is now a stone fountain with a jet and a splash you can hear up close. `/aero off` puts today's trees, falls and spring back at once; `/alive wind off` keeps the new trees but still |

## Scoped, not built

World pass (`WORLD-PASS-2026-11-22.md`): 1-hour garden day/night, crowns swaying (after one island re-export). ASMR keycaps and crunch (`V3-SCOPE` 13, needs your sound picks). v4 Pocket Deck cartridges (`V4-POCKET-DECK-SCOPE-2026-11-22.md`).

## Check on every device (never tested yet)

- **Phone:** frame rate in the garden with everything on; menus fit; touch on finds, Things to do, race.
- **Gamepad:** Things to do rows, race controls, menus.
- **Two players:** race together; each sees only their own sparkles; birds and butterflies are each player's own (others won't see the same bird).
- **Ambience off:** no birds appear (expected: they follow the chirps).

## Known stand-ins and gaps

Sparkle and pop sound are placeholders; no pet sniff on finds; no pet reaction to birds; bubble and wing sounds not made; Garden Dash has no ghost, cup or art; translations exported, not synced (synced at the next live publish).

## Before any of this goes live (not yours to test; listed so nothing is forgotten)

Move each beta ceiling to the live place: `Alive.PlaceId`, `Levels.PlaceId`, `Dash`, `Aero`, `Things.PlaceId`, `Finds.PlaceId` (and the bounds and garden-hour ones when built); set each remote key in the live config first; translations sync; store listing audit.

## Results

| Date | Device | Piece | OK / problem |
|---|---|---|---|
| | | | |
