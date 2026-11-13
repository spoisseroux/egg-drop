# Batch 2026-11-13: round items + smiley balls + themes, dusk world, feel alive

Spencer approved (2026-11-13, "go with all of these", "lets get building!"). Sources:
`ROUND-ITEMS-AND-BALL-THEMES-SCOPE-2026-11-13.md`, `FEEL-ALIVE-DIRECTION-2026-11-13.md`,
mockups in `artifacts/round-items-2026-11-13/` and `artifacts/feel-alive-2026-11-13/`.
Mood reference images: `reference/` (spencer-7/8 for vegetation and ground flowers,
spencer-9 for the dusk sky, lighting and colours). Mood only: keep everything original.

## Decisions (Spencer)

Round
- Smileys are the default ball theme. Numerals AND tier motifs go; Marbles (today's look) is a free theme.
- Kittens theme: real cat ears (today they are cut off and read as pigs).
- Next / Then balls animate their faces like the board balls.
- Results count-up: a very short blip per +1 ("rings counting up"), fast, each blip cut by the next.
- Items come only from power-up balls (star-marked ball in the normal queue; merging it grants an item). No Power-up Egg in v1. 3-slot belt per round; full belt = new item lost with a "Belt full" toast.
- B opens the item carousel during a round (round freezes); leaving is MENU or the back arrow.
- Phones: the item button is ALWAYS there (under A). Pressed with no items: a "You have no items" note appears on screen and softly fades after 1-2 s.
- First items: Swap, Pop, Magnet, Bomb.
- Ball themes: Deck style "Balls" tab (mockup approved). Prices: Smileys + Marbles free, Gumdrops 20, Gems 40, Planets 40, Kittens 80. No fruit theme. Save v11.
- Spencer asked whether themes should come from eggs instead ("players need to play forever"): direct purchase ships now; a "play forever" retention scope (incl. cosmetic eggs) is a separate Fable pass.
- Pocket Deck theme no longer tints the whole UI: only the deck and its background.

World
- Day/night cycle OFF for now: lock to dusk (warm sky, pink cloud sea, golden light) per reference spencer-9.
- Re-tune world textures, colours and lighting to match the dusk sky.
- Declutter: remove all 12 props listed in the feel-alive spec.
- Flowers: flat, upward-facing ground textures (flower patches/decals on the grass), not billboards; across the island, replacing the 3D flower clusters.
- Add 3D frond/leaf bushes (low-poly fronds at rock bases and path edges), original models.
- Brook bed: OFF during Pocket Deck rounds. The deck gets its own music (placeholder now; Spencer makes the real one; add to AUDIO-HANDOFF.md).
- Stations remember they were used (session now; saved later with coachMask).
- Attract: Care cradle approved as mocked. Pocket Deck station: build on the real model (the mockup's two thumbsticks don't exist). Egg nest icon: the egg glyph was upside down; fix.

Scopes (Fable, docs + mockups only)
- UI personality: minor tweaks so the UI (incl. the Pocket Deck screens) feels less generic / "vibe coded".
- Play forever: long-term retention (cosmetic egg/gacha with disclosed odds vs direct buy, collections, rotating shop, mastery), within Roblox policy.

## Slices and file ownership (one Studio; implementers write code + specs, coordinator tests)

| Slice | Owns |
|---|---|
| R1 Ball look + themes | JellyLCD/JellySprite/JellySpanSurface/JellyPalette, Pico8 ramps, new BallThemes shared catalog, Deck style Balls tab (new BallShop.lua + FaceplateShop tab row), Next/Then in DeckScreen, goal/quest/results colour circles, DeckKit theme-tint scope, DeckResults/RecapFeedback count blips, server theme purchase + save v11 |
| R2 Items | server simulation + BoardRound power-up balls, items (Swap/Pop/Magnet/Bomb) server-validated, belt state, new ItemCarousel.lua, phone item button + "You have no items" note in DeckScreen (button only), input routing in init.client.lua round region |
| W1 World look | HollowClock (dusk lock), LoungeWorldV7Art lighting/sky, world v7 palette/textures, declutter re-merge (Blender background), ground flower decals, frond bush meshes |
| W2 Life | new AmbientAudio.lua (brook bed, waterfalls, birds), deck music placeholder + world mute in rounds, new StationAttract.lua, pet life tuning (PetIdleMotion*/PetExpression/PetFace/PetCoo*), AUDIO-HANDOFF.md |

R1 renders a power-up ball when the egg carries the attribute R2 defines (`PowerUp=true`); R2 defines it.
Uploads (meshes, textures, audio) go through Open Cloud; audio quota ~100/30 days (28 used).

## Architect review changes (2026-11-13)

1. **Save v11 (R1):** HatchProgress quest cleanup must run for `version >= 10` (today `== 10` makes a v11 record fail with InvalidData after any quest-catalogue change). Keep the v10 `valid()`, add a v11 `valid()` and a 10->11 upgrade (`ballThemes={owned={...},equipped="smileys"}`) written like the 9->10 `petWearables` step; purchase op ids bound to theme id + price (as FaceplateState). Update the TODO rollback note to "not past the v11 commit".
2. **Span budget (R1):** before painting, count the spans a frame needs; over 1350, re-raster that frame with simpler faces (eyes only on the two smallest tiers); the sticky `failed` path only for frames still over 1536. Test Kittens first (~+100 spans).
3. **Stale items (R2):** `reset()` clears belt/armed attributes; every `item` request carries `ResetId` + a sequence; the server rejects stale ones.
4. **Phone item button (R2):** always shown under A; with an empty belt it shows "You have no items" and fades after ~1.5 s.
5. **Item rules (R2):** live round only, not over, no payout pending, item really on the belt, nothing already armed. Swap refused if it would pass the 24-drop budget; power-up marks swap with tiers. Pop/Bomb remove balls outside `merged` (never reach field:observe, score, chargeHatch, recordTrials); Bomb capped at 4. Popping a star ball loses its item. Belt = `board.belt`, published as an attribute, never saved.
6. **Pause (R2):** `carouselOpen` is a third input to `clientUI.syncPause` (no separate pause request); the `item` action is accepted while paused; grace already freezes (Heartbeat skips round:step).
7. **Power-up balls (R2):** star slots from a separate random stream (seed + fixed offset) so seeds stay deterministic; `merge()` keeps the star flag from either input; Next/Then read a published per-slot flag; off in Welcome / field 0 / guided rounds.
8. **Sequencing:** R2 lands the `PowerUp` attribute + belt schema first, R1 renders them. In init.client.lua / DeckScreen.lua, R2 owns input routing + the item button, R1 owns Next/Then; re-read before every edit. W1 lands the dusk lock in `HollowClock.sample` first; W2 tunes clock-dependent things (faces, ambience) after.
9. **Cut/defer if needed:** Magnet last (new force code; Swap/Pop/Bomb first); frond-bush meshes if the upload quota gets tight; Pocket Deck attract last.

## Spencer, later 2026-11-13: "Yes, add them; proceed with all recommended for the rest"

- Save v11 also adds play-forever fields: lifetime `stats`, `stamps` (no-reset stamp card), `book` (collection book) — fields + defaults now (R1), features later.
- Play-forever recommendations accepted (PLAY-FOREVER-SCOPE-2026-11-13.md): direct buy for themes/faceplates/wardrobe; Style Egg later (12 Stars, odds shown, no duplicates, items also sold directly); Kittens 120 Stars + a 160 tier later; everything rotates back, no one-time exclusives; v1 retention set = lifetime counters, collection book with milestone rewards, no-reset stamp card replacing the flat daily gift; weeks 1-8 roadmap per the scope.
- UI personality recommendations accepted (UI-PERSONALITY-SCOPE-2026-11-13.md): Fredoka One display face, button lips + stitched seams, copy voice + string table, pet peek (desktop first), fixed house palette with one accent per screen; a face on the Star. Build after this batch.
