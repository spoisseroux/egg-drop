# Private v685 — published November 14, 2026

**Private phone-QA build.** Studio confirmed publish success and “Add publish notes to v685”; Open Cloud confirms PRIVATE with mobile/tablet enabled. Runtime matches reviewed `70e0440` (source checkpoint `00287c5` plus translation sync). Fresh saves remain enabled for private QA.

Includes world/collision/second-park/shared-fetch fixes, November14 UI/onboarding/report/loss-payout changes, tightened reusable native pet/item hatches and timed SFX, lucky Jelly Material pool4, and Moonpond. Spencer chose the current72s v3 garden/Deck music; v4 remains local only. Blip stays disabled; Names/visitor Hello are scopes only.

Verified before publish: 301 runtime sources match Studio; 498 script containers compile; zero capture helpers in Edit. Fresh preflight23pipeline tests/build/170native collision payloads pass; prior56server/36client suite history and20,920matching rays retained. **Translations synced (59 add/update, 4 delete)**; post-sync dryrun0/0. Actual phone/two-account/service acceptance is Spencer’s next pass, not claimed done.

[Actual animations/Jelly/new visuals](artifacts/qa-2026-11-14-v634/native-review/README.md) · [Release evidence](artifacts/qa-2026-11-14-v634/native-review/private-v685.json) · [Phone QA walkthrough](artifacts/qa-2026-11-14-v634/PRE-PUBLISH-QA.md). Public release remains on hold.

---

## Unpublished checkpoint — 2026-11-14

No experience publish; published QA baseline remains private v634. World/garden/QA fixes, native hatch/SFX, lucky Jelly pool4 and sparse garden/deck working music are integrated. Native56server/36client suites pass across initial runs and targeted reruns; fresh full-build20,920collision rays match. Native Studio download copies preserve all170physical payloads. Local translation CSV regenerated:591strings; cloud sync deferred until an authorized publish. [Current result and evidence](artifacts/qa-2026-11-14-v634/UNPUBLISHED-RESULT.md).

## Published baseline and history

**PUBLIC 2026-11-21: the cute Bear and the Aero faceplates are live, place version v1033, runtime 2b171c0** (Spencer: "Publish live now"). Rojo disconnected, strip report as before (removed only the two ZZSpecs folders; LoungeGreyboxArt is production), File > Publish from the dev window; Studio confirmed "Published new changes in Pocket Pals: Pet Garden" and offered notes for v1033. Rollback: Roblox version history to **v1032** (the v2 build). Translations synced (3 add/update, 0 delete). Saves untouched (no schema change). Servers restarted (Spencer: "Yes, restart"; Open Cloud restartServers 200 OK).

**LIVE CHECK 2026-11-22 (Spencer, v1051):** real Robux purchase of Handful on keehar01: Stars 26 -> 46, still 46 after rejoining. He did not see the "+20 Stars added" line. Back routes good; phone pass good. The right build was confirmed by Back from Deck style. Servers were not restarted.

**PUBLIC v1051 2026-11-22 00:58 EST: live fixes, runtime 8759eee** (Spencer: "push the fixes to live when done"; same build Published to Pocket Pals Beta at 00:57 first). LIVE-FIXES-PLAN-2026-11-22.md: StarsRoute (Back from the store reopens the screen it was opened from, with its pet, page and way back), store icons load on open with timer re-asks instead of at startup, six mesh ids out of the image preload, no pad focus on hidden rows, shellPattern link leak closed, one Back sound. Architect review (5 hazards applied), code review GO. Specs 20/20 in one fresh Studio session (StarsRoute 6 new, StoreView 11); Back traced in Studio from Hatch eggs, Companions, Wardrobe, Stats, Names, Toys, Customize, Deck style, Book, Quests. Studio and repo byte lengths matched for the 8 changed client files. Rojo stopped; strip: Server.ZZSpecs 81, Client.ZZSpecs 194, 0 left. Translations: 0 add/update, 0 delete. Listing opened: description matches, icon and 7 thumbnails Completed, campaign "Pocket Pals v2 store set" Learning ($0.08, 688 impressions, 12 clicks, reporting delayed). Not tested: gamepad, a real phone, a second pet in Stats/Names, a real Robux purchase. Servers NOT restarted: 1 player was online.

**CORRECTIONS 2026-11-22 to the 2026-11-21 entries below:** (1) 3b32b8a, 283546a and 2c644a5 (beta `/stars` command, sheet lip, audio, checker, store Back, wallet feedback, preload) went to beta and LIVE without the required code review; reviewed afterwards, 2026-11-22: GO WITH CHANGES, no blockers (by reading only); follow-ups in TODO. (2) The preload in 2c644a5 asked for 6 mesh ids as images (EggModels 4, HatchDisplayAssets 2): they fail with "Asset type does not match requested type" on live, and egg meshes are not preloaded by it. The errors were visible in Studio before the publish. Fixed and live in v1051. (3) MachineHub's order-dependent failure was blamed on ToyShell without evidence; the first failing run had no ToyShell (both failing runs had KitSurfaces just before it). Cause not found. (4) Free Studio test purchase of Handful on the live code 2026-11-22: prompt, receipt, Stars 20 -> 40 on server and wallet ("+20 Stars added"). Real Robux purchase still untested.

**PUBLIC 2026-11-21 23:23: Stars store access + Get Stars restyle + phone-pass fixes published to the live place 96451847774961, runtime 05824f9** (Spencer: "Checked, publish"; File > Publish from the dev window). Ships everything from betas (2) to (6): tap the header Stars wallet to open the store; short buy buttons open the "You need ★ N more" card (Play a round / Get Stars); the Get Stars page in the Toy Shell look with the new pass/pack icons; Back returns to where you came from; wallet tap feedback; rounded sheet lips and the checker kept inside the corners; Pocket menu phone padding; quieter brook and waterfalls, louder world music; menu art preloads at join. The beta-only `/stars` command is gated to the beta place and Studio. Rojo stopped and disconnected first; strip: removed ServerScriptService.Server.ZZSpecs (81) and Client.ZZSpecs (193), 0 left; review list LoungeGreyboxArt (production, kept). Translations synced: 37 add/update, 1 delete (table a4aa8436). Listing audit at publish was by reasoning only; redone 2026-11-22 against the public APIs: description matches DESCRIPTION-v2.txt, 7 thumbnails, icon and both pass icons Completed. Home Page tile and ad campaign not re-checked. Servers restarted (Spencer: "Yes, restart"; Open Cloud restartServers 200 OK). Version number not read back.

**BETA 2026-11-21 (6): Spencer's second phone pass, runtime 2c644a5** (Publish As from the dev window; live not touched or saved). Menu art preloads at join (Get Stars icons first; StylePreload 80 images, was 34). Back from a store opened elsewhere returns to that screen (or the Pocket menu, or the garden), not Hatch eggs. The wallet tap flashes, pops and clicks. Checker pattern: the bottom fade copies the surface fill and the pattern insets by the outline, so the rounded bottom corners are clean. Studio (focused): Pocket menu -> wallet -> store -> Back lands on the Pocket menu. Specs: ToyShell 8, KitSurfaces 9, StoreView 9, StylePreload 5, WalletStar 8, DeckHeader 4, BookView 14, DeckStyle 11, MachineHub 14 (alone).

**BETA 2026-11-21 (5): Get Stars page in the Toy Shell look, runtime 76b9d58** (Publish As from the dev window; live not touched or saved). Fable's mock built (`artifacts/stars-store-2026-11-21/`): Hatch-eggs header, cream offer rows with the 7 new icons (Images in `StoreCatalog.Icons`, badge until loaded), OWNED chips, one BEST VALUE sticker on the real best available pack, a tray with the stage icon, what you get and one Buy key. Architect and code review (GO WITH CHANGES) applied; the egg preview sounds no longer play behind the store. Specs: StoreView 9 (rewritten), HatchEggsList 18, EggShopReopen 7, CompactEggShop 4, StarsStoreAccess 8, CompactPhone 12 (HatchActions fails as on HEAD). Not verified: a real purchase on the beta (it has no products), the page on a real phone. Translations: not synced for the beta (new store.* strings).

**BETA 2026-11-21 (4): checker fade, runtime 283546a** (Publish As from the dev window; live not touched or saved). Spencer: "it's the grid pattern that's ungrounded at the bottom": the moving checker now fades fully out over the last two corner radii of every menu surface, so its square corners never show inside the rounded bottom. Specs: KitSurfaces 9, MachineHub 14 (fresh session), DeckStyle 11, BookView 14.

**BETA 2026-11-21 (3): Pocket Pals Beta has Spencer's phone-pass fixes, runtime 3b32b8a** (Publish As from the dev window; live not touched or saved). Phone menu sheets: the lip under each sheet is an offset copy of the rim, so the bottom corners are round (all 12 Kit.sheet menus). Pocket menu phone bottom pad 12 -> 22 px. Audio: brook bed .22/.40 -> .12/.24, waterfalls .30/.21 -> .22/.15 (the "wind"), world music .07 -> .088. Header wallet tap key at least 44 px tall. Beta/Studio-only owner command `/stars N` in chat sets the test save's Stars (for testing the need-more-Stars card). Stars store tap confirmed by Spencer on his phone (the store page itself still has the old look; Fable's redesign mock awaits his OK). Specs green: AmbientAudio 8, MachineHub 14, CompactPhone 12, StarsStoreAccess 8, WalletStar 8, DeckHeader 4, HatchEggsList 18, CompanionsHub 7, KitSurfaces 9, DeckStyle 11, BookView 14. Translations: not synced for the beta.

**BETA 2026-11-23 (12): garden hour (1-hour day/night), runtime 416ff26** (Publish As, overnight; live still v1054). Spencer: "should we add like a 1hr day night cycle?" → 34 min day / 8 golden / 12 bright night / 6 dawn, same clock for everyone, pets stay awake, night Book finds follow the hour. **Off unless switched on:** missing `garden_hour` = off, so on the beta type `/hour on` (owner, beta/Studio); `/hour at <0-3599>` jumps the clock; `/hour clear`. Needs Aero on; `FeatureFlags.DayNight` untouched; live keeps the dusk lock. Fable look (`GARDEN-HOUR-LOOK.md`) + review (GO for beta: night glow capped .6 while on, golden diffuse .2 / glare .30, warmer hazier dawn); plan architect-reviewed (two daylights unified, one Lighting writer, missing switch = off, sun/moon swap under the haze, exact holds); six slices built in parallel; code review GO WITH CHANGES (9 fixes applied). Specs: GardenHour 17, GardenHourPets 6, GardenHourBook 4, GardenLife 26, LifeSim 24, AeroFalls 21, HollowClock 7 + AeroWorld 3 (scratch runner), default runner 33. Studio: night (ClockTime 22.5, lamps, stars, fireflies), the Bear's face readable and awake at night (after the glow cap too), golden sunset, dawn; `/hour off` restores the Aero day exactly (10.5, 1.85, #7C8894, #8CAAC8); log clean. Not seen: the blends in motion, a phone, frame time during a blend. Rojo stopped; 325 ZZSpecs removed; 448 scripts hash-match (375953236).

**BETA 2026-11-23 (11): Dewdrop fruit, runtime 9272c61** (Publish As, overnight; live still v1054). World pass item 3, looks only (Spencer: fruit looks only): Fable's honey-to-coral drop with a lime leaf cap (`artifacts/world-pass-2026-11-22/FRUIT-LOOK.md`, unlike the Hue Egg citrus berry), 2-3 under each lime crown, a seeded drop in strong gusts, bounce, roll, rest 18 s, fade; a pet within 3 studs makes it hop. Inside Garden life (`/alive life off`). Code review GO WITH CHANGES (drops diverged per player: now decided from wind + server time over every crown, camera/budget/Reduced Motion only affect drawing; four clients agree in the spec). Specs LifeSim 21, GardenLife 21, default runner 30. Studio: drops hanging under the lime crown and one in the grass (`artifacts/world-pass-2026-11-22/dewdrops.jpg`), log clean. Not seen: a pet batting one, phone, frame time. Rojo stopped; 325 ZZSpecs removed; 444 scripts hash-match (1420200998).

**BETA 2026-11-23 (10): new first session (onboarding v3), waterfall layers, runtime e5edeb0** (Publish As from the dev window, overnight; live not published, still v1054). From the research (`research/ONBOARDING-RESEARCH-2026-11-23.md`, live funnel `research/FUNNEL-SNAPSHOT-2026-11-23.md`: half of new players reach a second round, D1 1%) and Fable's plan (`ONBOARDING-V3-PLAN-2026-11-23.md`, architect-reviewed): switches `onboard_follow|needs|nest` (`/onboard`), beta/Studio ceiling + Things. Follow the Bear replaces the five-card tour (hand bubble → greeting, then ball bubble + paw prints and a "Hatch eggs" label, idle hint, funnel step 5 still logged); need bubbles replace the "Hatch your first egg" pill (108 px tap area, smoothed, a tap on the Bear counts, G / L2); the Bear's Sleepy Nest by the arch (8 h egg, Tuck in, a 7-egg welcome week of fixed gifts ~200 Stars in all, then 4 Stars an egg; save field `nest`, exactly once, fails closed), a HUD chip, a "See you tomorrow" strip on deck and Dash results; v3 11-step funnel. Waterfall: Fable's seven layers on the client (strands, ribbons, lips, foam, rings, mist, rainbow; 14 draws near Tumble, 8 at budget 1, none at 2 or Reduced Motion). Reviews: architect on both plans; code reviews A+B (1 blocker + 4, applied), C+F (3, applied), D+E (1 blocker + 3, applied), waterfall GO (applied with Fable's numbers); Fable GO on waterfall and nest captures (fixes applied). Specs: default runner 30 suites, plus NestState 11, NestHost 13, FirstSession 16, NestClient 12, TomorrowStrip 7, BearNeeds 20, FollowBear 11, AeroFalls 11; AeroWorld 23 in Studio. Studio: no tour card, hand bubble → greeting → ball bubble + Hatch eggs label; nest by the arch "Ready in 8 h", Tuck in ("Sleep tight..."), chip, G key; waterfall layers seen. Not seen: hatching the egg (8 h), the strip on a real results screen, phone frame, the review-fix tweaks themselves. Rojo stopped; 325 ZZSpecs removed; 444 scripts hash-match (1992737429). Translations exported (36 new), not synced.

**BETA 2026-11-23 (9): island edges, textured lime trees, funnel order fix, runtime 6119afa** (Publish As from the dev window, overnight; live not published, still v1054). World pass 1 (`WORLD-PASS-2026-11-22.md`, Fable scope + architect check; Spencer "Cool" to the recommended answers): offline edge sweep (`artifacts/world-pass-2026-11-22/edge-sweep.md`: four walkable climbs incl. the east grass ramp by spawn that also led off the island) answered by 18 invisible walls (`IslandBounds`, ceiling + beta, remote `island_bounds`, `/bounds`), and a return to the last safe spot after a fall or leaving the ring (server, held in deck/race/hatch, 3 s cooldown). Lime crowns get Fable's leaf map (`rbxassetid://127425168647805`, part white). Funnel (already live since slice A): strict step order, genuinely new saves only, FirstPet/FirstHatch/FiveMinutes events (feature branch copy; the live hotfix `hotfix/first-session-funnel` cf9e7ee is reviewed GO and waits for Spencer). Reviews: edges GO WITH CHANGES (error counter, greeting rays exclude the walls: applied), funnel GO. Specs: IslandBounds 7, IslandBoundsHost 7 (offline and Studio), AeroWorld 21 (Studio), FirstSession 10, default runner 26. Studio: walking and jumping at the east ramp, the spur and the pool bowl stayed at ground level; dropped off the island, back at the last spot in 1.1 s; crowns leafy and lime. Not walk-tested: the jump-only candidates in edge-sweep.md and a rim walk past 34 low ring boxes. Rojo stopped; 325 ZZSpecs copies removed; 434 scripts hash-match (1430245628).

**BETA 2026-11-22 (8): garden life (Alive step 5), runtime 4820205** (Publish As from the dev window; live not published, still v1054; new Alive feature `life`: ceiling `AliveLife` + beta/Studio, remote `alive_life`, `/alive life on|off|clear`). Spencer picked it ("Latter"). Plan `ALIVE-LIFE-BUILD-PLAN-2026-11-22.md` (architect: 4 blockers folded in). Client only, no saves or remotes: petals off the lime blossom crowns in gusts (cap 40), camera soap bubbles in two sizes (cap 8), a round bird lands on the crown where its chirp plays and leaves when you come within 12 studs (3), butterflies over flower patches (4). Hidden in deck rounds, hatches and your own race; Reduced Motion: nothing flies, birds sit; budget levels halve then hide. Fable: LOOK.md, round 2 LOOK-R2.md after real captures (bird and butterfly redone with drawn decals), REVIEW-R2 NO-GO on the bird face-on, fixed (two eye discs, corner-first beak), front and side captured: GO. Six textures script-drawn and uploaded (ids in LOOK.md, LOOK-R2.md). Code review GO (bubble size per emitter fixed with two emitters; chirp-hook warn). Offline specs: LifeSim 14, GardenLife 14, AmbientAudio 9, Alive 4, default runner 26 suites. Studio: all four kinds seen; `Alive_life` off removes everything and on restores; frame time 16.7 ms on and off (desktop, pairs). Output log clean. Rojo stopped; 323 ZZSpecs copies removed; 430 scripts hash-match the repo (185280206). No new strings. Not done: pet looks at birds (C2), bubble pop and wing sounds, crowns sway, phone pass.

**BETA 2026-11-22 (7): Garden finds (S9), runtime 85780f2** (Publish As from the dev window; live not published, still v1054; beta/Studio ceiling `Finds.PlaceId` plus remote `garden_finds`; `/finds on|off|clear`). Plan `V3-FINDS-BUILD-PLAN-2026-11-22.md` (architect: 4 blockers folded in). Each player's own sparkles on four lawns (24 spots from the walk map), first after 60 active s then every 240, 3 waiting, 12 paid a day on the save (`finds` field), +8 Smarts XP each (Bonus doubles it: Studio showed +16). Things to do row "Garden finds" above Dash (Show me dimmed with nothing waiting); tip 3 "Something sparkles" (coach bit 14). Code reviews: server GO WITH CHANGES (settle a held find on leave so the Play date write is not skipped; errors reset after a clean step), client GO (Dash row seen only inside the scroll window). Offline specs: FindsState 8, FindsHost 16, FindsClaim 8, FindsConfig 7, FindsClient 9, ThingsTrail 8, ThingsTips 11, all Dash and CloseProgress suites pass. Studio: sparkle at (-71,-41) after the timer, walked onto it: taken 0.4 s, claimed +16 Smarts, level-up toast; second play: east (44,-10) at 61 s, row "1 find waiting", Show me marker, pop and "+16 Smarts" on screen. Output log: no Finds errors. Rojo stopped; 323 ZZSpecs copies removed; 427 scripts hash-match the repo (1283086380). Translations exported (10 new strings), not synced (beta). Listing not audited (beta). Not done: pet sniff pose, real sparkle art and sound (stand-ins: built-in spark, snack sounds), phone, gamepad, two players.

**BETA 2026-11-22 (6): blue garden, Dash Meadow, Things to do, runtime 21f890e** (Publish As 16:55 EST; live not published, still v1054; beta/Studio ceilings plus remotes `aero_world`, `garden_dash`, `things_to_do`, `things_tips`; `/aero`, `/todo` chat). Frutiger Aero Medium, first layer (light lowered from the plan after the Bear washed out; lime or coral trees, flat); Garden Dash moved to the east meadow (179 studs, race camera, avatar hidden, bridge caps and crowns clear, waiting pad at (69, -14)); Things to do page in the Pocket menu with Show me trails, two tips, How cards. Code reviews: Dash Meadow GO WITH CHANGES (applied), Aero GO (applied), Things to do GO WITH CHANGES (4 applied), integrator's own last changes GO WITH CHANGES (applied; the final one-file fix after it was checked by specs only). Specs: server 85 pass / 9 fail, client 183 pass / 20 fail, every failure also in `artifacts/alive-2026-11-22/baseline-specs.json`; 6 suites re-run after the last fix. Studio: one full race on the new course (33.2 s), second race joined from the new pad and started with a menu open; avatar, camera and see-through parts restored; Aero off restores the garden; `things_to_do` off mid-trail clears it and gives the six-tile hub. 7,488 course points measured, none bad. No new console errors. Not tested: phone, gamepad, two players, the two tips on screen, Stats On and Time Trial on this course, frame time. Translations exported, not synced. Listing not audited (beta). Stray old copies of 7 scripts sit under StarterPlayerScripts in the place file (not touched).

**BETA 2026-11-22 (5): Garden Dash (S5 to S7), runtime 5f340ee** (Publish As; live untouched, still v1054; beta/Studio ceiling plus remote `garden_dash`; prizes off unless `garden_dash_prizes` is true). Plan `V3-DASH-BUILD-PLAN-2026-11-22.md`; code reviews: server GO WITH CHANGES (6 applied), client GO WITH CHANGES (10 applied). Studio, real keys: gate, two full Just for Fun races (39.2 s, 38.1 s), Dash and puff, bridge, results; a race with prizes on showed +2 Stars (1 of 5 today); Leave asks first; a character reset keeps the race; the off switch mid-race ends it, restores the camera and a deck round starts. No new console errors. Course re-measured on the built garden: 8,776 points, none without ground, none off by more than .35 stud (one tree rerouted). Server Dash, HatchProgress and parity suites green; 19 of 20 chosen client specs green after the last change (CompactPhone unfinished). Fixed on the way: 3 or more queued results lost every prize; RT released Dash; a sliding thumb jumped; the HUD read "1st" after finishing. Known: your avatar blocks the view at the start; trees cross the camera; placeholder button pictures and names overlap. Not tested: phone, gamepad, two players, stepping stones, Stats On and Time Trial, the full client list with Dash, daily cap past 1, frame time. Left out: ghost, Today cup, ribbons on cards, art, sounds. Translations exported, not synced. Evidence `artifacts/dash-2026-11-22/`.

**BETA 2026-11-22 (4): "Levels matter" (S1 reward track, S2 gates, S4 medals, S3 deck juice), runtime ed8a1a6** (Publish As 05:58 EST; live untouched, still v1054; `Levels.on` needs the beta place or Studio, plus remote `levels_matter` and `/levels` chat). Plan `V3-LEVELS-BUILD-PLAN-2026-11-22.md`. Reviews: architect plan; Code Reviewer GO WITH CHANGES (7, all applied); short final review GO WITH CHANGES (applied); Fable on captures (6 applied, 2 declined). Saves: two optional fields (`hatching.medalEggsUsed`, `deckJuice`); a new-build save loads and transacts in HEAD and back (offline VM); off = same save and snapshot JSON as before. Studio: server 74 plus 10 new, same 9 baseline failures, on and off; client on and off in the baseline set only, after three rounds of fixes; off refuses gated wearable, ball and plate (NotForSale, no Star change); on refuses below level and sells once at level; medal egg opened once with the daily nest untouched. Fixed on the way (live has them today): desktop Balls rows 5 to 7 could not be reached by mouse; scroll-to-selected mixed scaled and unscaled pixels in Balls and Faceplates. Same scroll-to code still in Backgrounds, Companions pets, Wardrobe, Book, Quests: not changed. Not tested: two clients (Marks row, park looks), medal tiers 50 to 99 on screen, pops, trails and starts by eye in a round, a phone, gamepad, real ConfigService keys. storm_glass texture was still in review. Translations exported (1148 strings), not synced. Evidence `artifacts/levels-2026-11-22/`.

**BETA 2026-11-22 (3): alive steps 0 to 4, runtime 90ae236** (Publish As; live untouched, still v1054; nothing Alive can run on the live place, `Alive.ceiling`). Springs on presses, tabs, toggles, selection and the Star hop; menus rise and fade; one wind for bushes, pennants, flags and chimes with a rustle (131058187750745); remote off switches (`alive_springs|menus|close|wind`, `/alive` chat). Plan `ALIVE-BUILD-PLAN-2026-11-22.md`; architect plan review (12 changes) and code review GO WITH CHANGES, all four applied. Studio: flags on 186 client (20 fail, all in the baseline 22) and 74 server (same 9 as baseline); flags off matches baseline. Agent play-through: every Pocket menu screen, 10x open/close, live switch flips settle in 1 to 2 frames, client and server wind agree at 20 points, frame p50/p95 16.7/18.0 ms and draws/triangles the same on and off (desktop only). A blank green round seen by QA came from the scripted welcome skip: the same start works when the welcome round is played with real keys. Not tested: a phone, two real clients, gamepad, rounds in depth with springs, the rustle by ear, perf with a menu held open, wind ms. Evidence `artifacts/alive-2026-11-22/`.

**PUBLIC v1054 2026-11-22 01:52 EST: bright pet previews, Stars bought sound, "+N Stars" sticker, runtime 54dca26** (Spencer: "Publish to live, but dont restart the servers bc people are online!!, it looks good"). Servers NOT restarted: the one running server had the same id and 1 player before and after the publish (06:50:59Z, 06:52:11Z); by 06:54:00Z it was no longer listed. Servers restarted 2026-11-22 07:15Z (200 OK) on Spencer's later word ("no ones online rn so you can restart the servers"), with 0 playing and no public server listed just before. Same build as the beta below. v1054 is the 01:39 Studio autosave (after the strip), now marked published; 1052 and 1053 are unpublished autosaves. Code review of the first diff GO WITH CHANGES (applied), then of the post-review fixes GO (left: rebuying a pack before its first grant lands can replay the old sticker or skip one; presentation only). All 14 changed scripts hash-matched between Studio and the commit; zero ZZSpecs; Rojo stopped. Translations synced (2 add/update, 0 delete). Output log read: only the known 203785492 and EditableImage lines plus my own inspection errors. Listing audited: description, icon and 7 detail thumbnails opened and match (nothing needed; Home Page set has one active, picture not seen); campaign "Pocket Pals v2 store set" Learning ($0.19, 1,867 impressions, 24 clicks; reporting delayed). The game page shows "Maturity: Minimal, Ages 16+": expected (Spencer: "we need 100 hep before we can make below 16").

**BETA 2026-11-22: Pocket Pals Beta has bright pet previews, the Stars bought sound and the "+N Stars" sticker, runtime 54dca26** (Publish As 01:39 EST; live untouched, still v1051). One `Kit.petLight` for eight menu previews; pale or grey discs behind a pet are lilac. Plan `BRIGHT-PREVIEWS-AND-PURCHASE-SOUND-PLAN-2026-11-22.md`; architect applied; Fable passed the renders with two fixes applied; code review GO WITH CHANGES applied (one optional item not done: a Throttled rejection disarms an earlier prompt for the same pack). Specs green on the final code: StoreView 12, PurchaseCue 9 (new), StarsRoute 6, StarsStoreAccess 8, UICopy 8. Green after the lilac fix: HueEggView 15, CompanionsHub 7, NameScreen 6, MachineHub 14. Green before the lilac and review fixes, not re-run: KitSurfaces 9, HatchEggsList 18, CompactEggShop, WalletStar 8, DeckHeader 4, ToyShell 8, CompactPhone 12, ArcadeAudio 11, PetInspect, PetPeek 10, BookView 14, EggShopReopen, DeckStyle 11, UIShellQA 13. R4Content:139 fails (recorded before as failing on HEAD; not re-checked on HEAD here). Free Studio test purchase (before the review fix): sound played with the grant, sticker shown, PromptProductPurchaseFinished fired on the client when Roblox's window closed and the sticker came back once. Measured: Pocket menu tile pet 212,205,198 to 233,228,229. Sound asset 105056947696236 Approved. Not checked: a dyed, matte or jelly pet under the built light, a real phone, the sound by ear. Translations: exported (+2 strings), not synced; sync at the next live publish. Evidence: artifacts/bright-previews-2026-11-22/.

**BETA 2026-11-21 (2): Pocket Pals Beta has Stars store access, runtime c69fcee** (Publish As from the dev window; live not touched or saved; Studio still targets the live place). The Stars wallet in every menu header opens the Robux store (through Hatch eggs); short buy buttons stay dim and open a "You need ★ N more" card with Play a round / Get Stars (Wardrobe, Deck style plates and balls, Names Egg, Bunny adopt, Hatch eggs). Plan `STARS-STORE-ACCESS-PLAN-2026-11-21.md`; architect review applied; code review GO WITH CHANGES applied. Specs green in Studio Play: StarsStoreAccess 8 (new), HatchEggsList 18, CompactEggShop 4, EggShopReopen 7, DeckStyle 11, CompanionsHub 7, NameScreen 6, UIShellQA 13, ShelfDeal 7, ConfirmDialog 3, WalletStar 8, DeckHeader 4, KitSurfaces 9 (R4Content and HatchActions fail the same on HEAD). Studio: a tap on the Pocket menu wallet closes the menu and opens Hatch eggs; the store page needs a focused window (Studio unfocused refuses it, as the old Get Stars button does), so the store opening is checked on the beta. The beta has no Robux products, so its store shows the passes only. Translations: not synced for the beta (new starsShort.* strings); sync at the next live publish. Evidence: artifacts/stars-store-2026-11-21/.

**BETA 2026-11-21: Pocket Pals Beta has the cute Bear and the Aero faceplates, runtime 2b171c0** (Publish As from the dev window; live not touched or saved). The starter Bear uses Fable's v2 cute model (rounder head, snout pad, dark textured eyes with no white ring, blush; model 113193601678263), with every eye and cheek piece conformed to the head's curve (model 88598931173890) after Spencer saw the eyes clip at the top. The Bunny's pieces and item frames are unchanged; its eye items get the same no-clip fix. Three new faceplates: Cloud Glass (40), Lagoon (100), Dewy Meadow (100). Architect review GO WITH CHANGES applied; code review GO. Specs green in Studio Play (PetAttachments 10, GardenPetVisual 11, WearableVariants 6, WearablePurchase 12, CompanionsHub 7, RevealStage 21, HatchItemStage 17, FaceplatePurchase, BackgroundAppearanceCatalog 8, DeckStyle 11). Translations synced (3 add/update, 0 delete). Evidence: artifacts/v2-bear-ship-2026-11-21/. Not verified: a real phone; the faceplates on a held deck in Play.

**PUBLIC 2026-11-20: Pocket Pals v2 Published to the live place 96451847774961 — runtime aeae2d9** (Spencer: "push the update to main ... Both"; File > Publish from the dev window, live saves `EggDropLaunchV3`; servers restarted, Spencer: "Yes"; Open Cloud restartServers 200 OK). Everything from the beta builds (3) to (7): stats + XP, stats panel, inspect Stats, Stat Eggs / pouch / feeding, the Bunny (adopt or 7 stamps) with its arrival hatch, Toy Shell restyle, v2 hatch and the 3D Stat Egg, naming, notification tickets, confirm dialog, Spencer's review rounds 1 to 3. Rojo disconnected; strip: removed ServerScriptService.Server.ZZSpecs (81) and Client.ZZSpecs (189), 0 left; review list LoungeGreyboxArt (production, kept). The beta Star grant is gated to the beta place id. Translations synced: 226 add/update, 5 delete (table a4aa8436). Version number not read back.

**BETA 2026-11-20 (7): Pocket Pals Beta has the round 3 follow-ups, runtime aeae2d9** (Publish As from the dev window; live not touched or saved): the item hatch card's X goes back to Hatch eggs, Hatch another stays on screen (disabled) while the card leaves, a hatch survives a long frame and a skip still rings the tier sting, and the phone Pocket menu fits its tiles with its rounded bottom on screen. Translations: no string changes.

**BETA 2026-11-20 (6): Pocket Pals Beta has Spencer's review round 3, runtime 542e760** (Publish As from the dev window; live not touched or saved): the Stat Egg hatches on the 3D egg (own gem-belt shell, stone roulette, the won stat's colour at the burst, Feast jackpot), one sound line for every egg (wobble/crack + tier sting, body bed off), the Bunny's arrival plays as a Rare pet hatch (in place of the arrival card, once per save via petArrived), a confirm dialog for every big spend and restart/quit/reset, rounded inner corners on the Rare edge, stat stage under the top bar and Close back to Hatch eggs, taller notification tickets (5 s), vivid wallet Star, brighter pet previews, shorter phone Pocket menu tiles, Name tile, Snacks key without the count, Keeper title hidden, snack pouch X, no scroll fades, new Hatch eggs glint and peek glare. Translations: not synced for the beta (new confirm.* strings); sync at the next live publish.

**BETA 2026-11-20 (5): Pocket Pals Beta has Spencer's review round 2, runtime c49fbae** (Publish As from the dev window; live not touched or saved): Toy Shell notification tickets (timer bar, newest on the right, scrolling row, dissolve, tap opens the menu), Star sways and spins on a gain, one-time 1,000 Star beta grant for the owner, Companions 2 x 3 grid with Stats and Name tiles, pet headshots, naming screen reopen fix + waiting-slot ring + lifted keys, petting screen Stats/Snacks bottom left + pouch fixes, Toy Shell deck handoff shade, hatch content below the top bar, small edge fades on scrolling lists. Translations: not synced for the beta (new strings: stats.row, names.row, names.rowUnnamed, names.slots.optional, stats.snacks.close); sync at the next live publish.

**BETA 2026-11-20 (4): Pocket Pals Beta has Spencer's review fixes, runtime cb76c23** (Publish As from the dev window at 16:49 EST; live not touched or saved): Stats and Name above the preview pet, no floating garden name tags (name on the petting card and inspect cards), sugar topper with the stat icon on every snack, the new "Star Bank" Stars counter. The capsule under hatched items was already gone in (3); the Bunny clipping was a capture fixture. Captures: artifacts/v2-review-fixes-2026-11-20/. Translations: not synced for the beta (one changed string, names.shows.where).

**BETA 2026-11-20 (3): Pocket Pals Beta has the full v2 build, runtime 385fb2b** (Publish As from the dev window at 01:28 EST; live not touched): stats core + XP, stats panel, inspect Stats tab, Stat Eggs / pouch / feeding / boosts, the Bunny (adopt 400 Stars or 7 stamps, Jump favourite), production snacks, Toy Shell restyle with deck-matched menus and Classic option, v2 hatch (Pop-Out Stage, rare jackpot, lid/iris), Pocket Buddies icons, curated naming + Names Egg. Review pack: artifacts/v2-review-2026-11-20/ (sheets 1-6, REVIEW-v2.md). Not checked: real phone, two accounts, the live hatch animation and sounds end to end.

**BETA 2026-11-19 (2): Pocket Pals Beta updated to runtime 3b0b90c** (Publish As from the dev window; live not touched): v942 + White second colour + v2 stats core and XP from play (S1+S2, 5bcfb0d) + stats panel, level-up line and results Stats strip (S3, 3b0b90c), rune atlas art. Not yet in: inspect Stats tab, level rewards/gates, Stat Eggs/snacks/feeding, Bunny, Toy Shell restyle, new hatch. Spencer tests everything in one pass at the end.

**PUBLIC v942 Published 2026-11-19 — runtime 5834b05 (v935 + S0 counters only), servers restarted (Spencer: "Yes, restart"; Open Cloud restartServers 200 OK).** Spencer: "you can publish those counters now". Built from a separate checkout of 5834b05 served by Rojo (launch.project.json), so the White second colour (b9c90ed) is NOT live. All 8 files that differ from HEAD verified byte-equal to 5834b05 in Studio before publish; Rojo disconnected; strip script: 0 removed (ZZSpecs absent). Adds optional save counters questsDaily, questsWeekly, fetches (no UI). Translations: no string changes.

**BETA 2026-11-19: first build in the private Pocket Pals Beta** (place 107705084891479, universe 10777916361; Publish As from the dev window, live place not saved or changed). Runtime 6a5e61d: live v935 plus S0 counters (5834b05) and the second colour from white + free White option (b9c90ed). Test content (ZZSpecs) left in. Own saves (fresh), no Robux products. Collaborators: keehar01 (owner), solidSkunk (Edit). Translations: not synced for the beta.

**Store page v2 2026-11-19 (live):** icon C (pink Sparkle Eyes Bear with the Prism Flare deck, `artifacts/store-listing/v2/icon/icon-C-bear-deck-1024.png`) saved in Creator Hub; the 8 v1 Experience Detail thumbnails deleted (Spencer approved; copies in `artifacts/store-listing/v1/UPLOAD-THESE/`) and the 6 v2 thumbnails uploaded in order 1 lead, 3 dress up, 4 merge chains, 2 hatch, 5 friends, 6 decks. Checked on the public game page.

**Ads 2026-11-18:** Sponsored campaign "Pocket Pals launch test" (id 140d5d57-ccec-4266-815f-ab115eff4fa4), approved by Spencer in chat ("A, yes $5/day x3"): objective PLAYS, $5/day DAILY budget, 3 days (2026-11-18 06:20Z to 2026-11-21 04:59Z), card (Visa ending 8632, billing account ebcd19bc-...), devices phone/tablet/desktop, all players, automated bid. Creative: ad image A (`artifacts/store-listing/ad-v1/ad-v1-1920x1080.png`, asset 97803040112547), ad review APPROVED. Read results via Analytics SponsoredAdsClicks/Impressions/SpendUsd.

**PUBLIC v935 Published 2026-11-18 — runtime ff28ba9, servers restarted (Spencer: "Publish + restart").** v933 plus readable phone goal rows (Merges / Chain / ball with up arrow and LEFT, RIGHT, MID instead of pictograms) and three Hard goals ending above the Quest handle. CompactPhone 12, DeckFit 5, DeckScreen 8, DeckRoundQA 10, ItemCarousel 8; capture `artifacts/qa-2026-11-17-v933/hard-three-goals-844x390.png`. Translations: no table changes ("Merges", "Chain", LEFT/RIGHT/MID are hard-coded). Test content stripped.

**PUBLIC LAUNCH 2026-11-17 (~22:21 ET):** Spencer released Pocket Pals: Pet Garden publicly on v933 (runtime a80ed37). Open Cloud confirms universe 10774758591 `visibility: PUBLIC`. Age rating still reads unspecified in the API.

**Private v933 Published 2026-11-17 — LAUNCH BUILD, runtime a80ed37, servers restarted. FRESH SAVE STORE `EggDropLaunchV3`.** Client-run Pocket Deck ON for everyone (`DeckClientSim=true`; Welcome round on today's path). Sim check off. Includes v931 (hatch x stores) and everything since v898. Studio soak: fresh save -> Welcome -> pet -> 3 lockstep rounds at lag 0 / 0.6 s / jitter: all ended, 0 refused, 0 stalls, 0 resyncs, final hash equal, payout matched and saved. Specs LaunchFlags 3, SessionRecovery 8, DeckHeldScale 3, WorldBackdropFidelity 2. Translations: no table changes (loading screen copy is hard-coded, English only). Test content stripped. Next: Spencer clicks Manage audience -> Release publicly.

**Private v931 Published 2026-11-17 — runtime 5339ee6, servers restarted. SAVES PERSIST (`EggDropLaunchV2`).** v929 plus: the hatch reveal's corner x stores the result like Store (Spencer: after x, the next egg opened the stored result instead of hatching). HatchFlowE2E 7, CustomizeNewItem 5, HatchActions 29, HatchItemStage 13. Client-run deck still ON only for Spencer's test accounts. Test content stripped.

**Private v929 Published 2026-11-17 — runtime 2913af1, servers restarted. SAVES PERSIST (`EggDropLaunchV2`).** v922 QA: Spencer, "the feel instant now" (client-run deck on his phone). Adds B4 (2913af1: server hash stream every 0.25 s, rollback with eased correction, rejoin mid-round; forced desync fixed in 0.2 s at lag 0, 2.6 s at 0.6 s lag; 0 mismatches in 6 lag/loss runs), no PLAYING badge over held decks, hatch result buttons 40 px up and 72 px in on phones (HatchItemStage 13, HatchFlowE2E 6, RevealStage 17). Client-run deck still ON only for Spencer's test accounts. Needs: Spencer's phone and PC pass, then flip `DeckClientSim` for everyone with a fresh save store for launch. Test content stripped.

**Private v922 Published 2026-11-17 — runtime 137051d, servers restarted. SAVES PERSIST (`EggDropLaunchV2`).** Client-run board B1 (31373c5, tick round host), B2 (5c89c54, server lockstep), B3 (e311a91, the owner's deck draws its own host: tap-to-ball and merge delay 0 frames at lag 0 / 0.6 s / jitter in Studio, hashes and payouts equal). ON ONLY for Spencer's test accounts (`DeckClientSimTesters`, SimCheck.isOwner: keehar01, solidSkunk); everyone else plays today's path (`DeckClientSim=false`). No hash rollback yet (B4): a desync is counted, and a stalled client falls back to today's path after 5 s. Needs: Spencer's phone feel test. Test content stripped.

**Private v903 Published 2026-11-17 — runtime 979f3f1, servers restarted. SAVES PERSIST (`EggDropLaunchV2`).** v898 plus client-run board slice B0 (5c3f084): shared plain-number `BoardSim` with hash/replay (not used by the live board; `DeckClientSim=false`) and the owner-only sim check (keehar01 and Spencer's phone account): at join the client replays three seeded rounds and the server compares 164 hashes; a toast shows match or mismatch. Studio: match (digest 05a4e5ecb8ad2f44). Spencer, 2026-11-17: "Sim check: match" on his phone and on PC (cross-platform determinism confirmed). Test content stripped.

**Private v898 Published 2026-11-17 — LAUNCH CANDIDATE, runtime 7662362, servers restarted. SAVES PERSIST (`EggDropLaunchV2`).** v890 QA. Poor connections (7662362; architect review then code review GO WITH CHANGES, applied): ghosts bind to their ball by ack or by the Part's `DropToken`; backstops 8 s (no answer) and 3 s (bound, never drawn), and a ball merged before any Part existed ends on its merge event; quick taps take the right tier; server drop queue 0.3 -> 0.8 s. Studio H.taps at 0 and 0.6 s lag: 0 refused, 0 fades, 0 upward jumps. Predicted merges built but OFF (1 of 4 confirmed in Studio): the merge pause needs the client-run board (`artifacts/qa-2026-11-17-v887/client-sim-plan.md`, Option B). Join (58c0b69): ReplicatedFirst loading screen preloads the world (Studio 388 items, 3.5 s; Skip at 10 s, leaves by itself at 25 s); hatch assets prewarmed at start, hatch asset budget 1.2 -> 3.5 s, egg templates retried after a failure (the hatch animation skipped on a slow join). Deck music .15 -> .105. Translations: no string changes (loading screen text is new hard-coded copy, not in the table yet). Test content stripped. Not tried on a phone.

**Private v890 Published 2026-11-17 — LAUNCH CANDIDATE, runtime 6b12cbf, servers restarted. SAVES PERSIST in a NEW store `EggDropLaunchV2` (every account starts fresh; V1 saves kept, not read).** The pink wall Spencer saw from his second account was the held Pocket Deck: `Lounge.slimTemplate` cloned Rojo-synced deck parts (MeshId set, wrong mesh initial size), so the Shell and FrontPlate drew at raw export scale (~184 studs) on whoever had the deck out, visible to everyone. Every part is now rebuilt from its mesh id at template size (spec DeckHeldScale; captures `artifacts/qa-2026-11-17-v887/`). v889's backdrop-fidelity change was not the cause (kept as a guard). Onboarding unchanged: a fresh save starts on the Welcome round with no pet. Specs DeckHeldScale 3, LaunchFlags 3, SessionRecovery 8; server 50/67 (17 need other args). Translations: no string changes. Test content stripped. Not tried on a phone.

**Private v889 Published 2026-11-17 — LAUNCH CANDIDATE, runtime b3e8f20, servers restarted. SAVES PERSIST.** v887 phone QA: (1) the pink wall in the garden was the backdrop cloud sea at Automatic fidelity (a phone at a low graphics level drew a coarse LOD through the island); the 8 backdrop meshes are RenderFidelity Precise in the native pack (`scripts/world_backdrop_fidelity.py`, only that chunk moved, proof re-signed, `world_native_collision.py --check` PASS; spec WorldBackdropFidelity). Client-only per device, never seen by other players. (2) the white focus ring draws for a gamepad only (`Kit.ringGamepadOnly`); screens keep their green selected state. (3) LCD merge blob 0.16 s ease-out (was 0.22 s smoothstep, which read as a pause before merging). Difficulty picker unchanged: until the first saved win a session's first three rounds run Easy with no picker (`HeatRequest.guided`). Specs DeckScreen 8, DeckResults 18, MachineHub 14 (flaky once), JellyLCD 10, WorldBackdropFidelity 2. Translations: no string changes. Test content stripped before publish. Not tried on a phone.

**Private v887 Published 2026-11-17 — LAUNCH CANDIDATE, runtime 5d33dce, servers restarted. SAVES PERSIST.** Ghost ball now simulates its own fall, bounce and settle and hands over where it meets the server ball (5741807): 0 upward jumps and 0 land-pause-rebounce at 0/100 ms/jitter (v880: 2-5); phone perf (5d33dce): no per-frame tables, at most 6 live ghosts, hitch steps clamped. Reviews GO WITH CHANGES, applied. Test content stripped before publish. Not tried on a phone.

**Private v880 Published 2026-11-17 — LAUNCH CANDIDATE, runtime f73374a, servers restarted. SAVES PERSIST.** Adds the faceplate/deck texture preload (f93ba39, f73374a) to v875; test content stripped again before publish (Rojo disconnected). Store listing live in Creator Hub: icon D with title (in moderation), 8 Experience Detail thumbnails in order (Pocket Deck merge, custom deck, Make your Bear yours, Bear with ball, Pet Park, toy hatch, garden, Book), Home Page has 5 uploaded with the Pocket Deck shot active. Next: Spencer's test pass on v880 (real purchase, rejoin, second account, mobile data), then Manage audience -> Release publicly.

**Private v875 Published 2026-11-17 — LAUNCH CANDIDATE, runtime 31c6006 + l10n, pushed; servers restarted. SAVES PERSIST (TestFreshSaves=false, namespace EggDropLaunchV1).** Launch build: LaunchFlags spec pins the v1 flags; hueBuy closed (old receipts replay); pity-egg odds show the charm split; Toy Egg 16.67% with a rounding note; Book draws the Pocket Deck toy in 3D. Test content stripped before publish (strip_test_content.lua: both ZZSpecs folders and Baseplate_RetiredByGreybox; Rojo disconnected first). Universe: name Pocket Pals: Pet Garden, description, voice off, VR off, private servers 50 R$, server size 12, questionnaire submitted. Review GO WITH CHANGES (non-blocking). Specs: server 64/64, client 150/168. Next: Spencer picks icon/thumbnails, test pass (real purchase, rejoin, second account, mobile data), then Release publicly. NOTE: reconnecting Rojo (default.project.json) re-adds ZZSpecs in Studio; strip again before any future publish.

**Private v870 Published 2026-11-17 — runtime bb2a246, pushed; servers restarted. FRESH SAVES.** v859 notes: hatch receipt card hidden during the hatch (restored on every stage exit), in-world icon press shows no dark box, deck shade 68% -> 22% so the garden shows behind, A nudged left / B down-right, inspect button waits 1.2 s before switching and keeps a fixed orbit, pet leash 19 studs (wander targets clamped). Phone deck uses the desktop art (glossy green A, dark B, paw speaker, item count badge on B). Toy Egg odds read "1 in 6" (OddsAudit spec). Universe: voice chat off, VR off, private servers 100 R$/month, description set; content questionnaire submitted by Spencer (rating pending). Reviews GO. Specs: client 150/168 (18 known), server 63/63. Not checked: a real phone.

**Private v859 Published 2026-11-17 — runtime e0d150e, pushed; servers restarted. FRESH SAVES.** Pocket Deck ghost ball on (S5): the ball shows on the tap frame and the next tap opens at its touch-down (server settle rule 0.46 s); with 150-250 ms jitter tap-to-ball 548 -> 0 ms, tap-to-next-tap 885 -> 466 ms, 0 refusals; handoff gap ~2 px. Merge HUD refresh trimmed. v850 notes: toy reveal offers Give to <pet> and Store (the first-toy flow had renamed the second button and it ran the legacy picker; picker removed), Store only with no pet; toy preview and held Pocket Deck use the garden grip / two-paw hold; reveal items centred; teal reveal backdrop replaced with warm cream-peach; Companions shows no focus ring on touch. Reviews GO WITH CHANGES, all fixes in (ed34756, e0d150e). Specs: server 64/64, client 147/166 (known + MachineHub full-suite flake). Not checked: a real phone.

**Private v850 Published 2026-11-16 — runtime ee5fadf, pushed; servers restarted. FRESH SAVES.** v842 phone notes: Customization Egg now plays its full hatch and sound, and a waiting result no longer hijacks another egg's Hatch (the look egg buys through the Hue intent; the hatch hand-off only knew 'hue'; 45de7ff) with a new end-to-end hatch-flow spec (Customization, Toy, Customization). A/B letters centred; reveal card ~75%; Sparkler uses particle sparks (2D sparks in the reveal), no mesh star; jars rebuilt to read from every side (closed liquid, 3D symbols, Model 81983006633272, Approved). Also the shownMode fallback (d322c1b). Specs: client 147/165 (18 known), server 63/63; quick review GO. Translations: no changes. Not checked: real phone, sounds by ear.

**Private v842 Published 2026-11-16 — runtime 812685b, pushed; servers restarted. FRESH SAVES.** v834 phone notes: deck close no longer shrinks first (insets change under the shade), world behind the deck stays put (stale camera restore removed), waterfalls halved with tighter rolloff, Toys row last in Companions, goal/quest circles centred. Fable deck layout pass (DECK-LAYOUT-SPEC-v834.md): wider wings, A 76 / B 48 on a 55 degree diagonal, larger wordmark, smaller MENU; every phone uses icon goals. Six monotone ball themes (Pea Soup, Pocket Grey 40; Amber, Deep Sea, Bubblegum 100; Midnight 250). Specs: client 148/162 (14 known), server 63/63; quick review GO WITH CHANGES (non-blocking). Translations synced (42 add/update, 8 delete). Not checked: real phone insets on close, sounds by ear.

**Private v834 Published 2026-11-16 — runtime 510d78c, pushed; servers restarted via Open Cloud. FRESH SAVES.** Spencer: A and B back to their pre-v816 sizes (A 80, B 50 on most phones) on the old diagonal, nudged 6 px left (3 on small phones) and ~8 px down off the right edge. DeckFit, CompactPhone, ItemCarousel pass. No new strings (no translation sync needed). Everything else as v833.

**Private v833 Published 2026-11-16 — runtime 0892a89, pushed; servers restarted via Open Cloud. FRESH SAVES (TestFreshSaves).** Quick Links "Add publish notes to v833".
# Pocket Pals — smooth Pocket Deck networking, Toys screen, Material tab

**New since v816 (v816 phone notes 16-21):**
- Pocket Deck networking (deck-network-plan.md, architect-reviewed, slices S0-S4 on, S5 ghost ball off): owner-only 30 Hz snapshot stream, client render clock with interpolation, merges/score/sounds on the render clock, drop ack + one-deep server queue, tap sound and dispenser kick on the tap frame, shared Parts at 8 Hz. Studio with 150-250 ms jitter: hitches 27-31 -> 1-3, longest freeze ~400 ms -> 84-183 ms.
- Toys are their own Companions row and screen (tap previews, Give to Bear equips); Customize is Hue, Charm, Material. Finish renamed Material; Material tab redesigned (Shine and Jelly meters, jar cards, empty state, Back to original).
- Pocket Deck A/B in Game Boy Micro layout; wallet 3D Star held still.
- The first-play popover under the Roblox menu is Roblox's own top-bar tip, not ours.

Verified before publish: server 63/63 (64 with the BoardNet spec), client 149/162 (13 known); code review GO WITH CHANGES, all six fixes in (131e0ae, db7b23e, 23f00e8). **Translations synced (34 add/update, 20 delete).** Not checked: a real phone on mobile data, bandwidth with several players, any audio by ear.

**Private v816 Published 2026-11-16 — runtime a63f95d, pushed; servers restarted via Open Cloud. FRESH SAVES (TestFreshSaves).** Quick Links "Add publish notes to v816".
# Pocket Pals — Customization Egg, UI juice, deck performance

**New since v775 (Spencer's v775 phone notes, `artifacts/qa-2026-11-16c-v775/notes.md`):**
- Tips never replace an open card; the always-on "Tap your pet to say hi" hint is gone (now in Your garden guide).
- Customization Egg replaces the Hue Egg: hue jars, Gloss/Matte/Jelly finishes (7 sheen stops, Jelly stages), rare charms (2% each, pity at 15, restricted accounts get a fixed order). New pets start with no charm; existing saves keep Snowflake/Ring/Pebble. New jar art (symbols inside the jars). Book: "Toys & finishes" page and a Charms page.
- UI: click audio on every button, equip/unequip sounds, hatch X inset, Toys row removed from Companions, toy preview in Customize (tap previews, tap again equips), animated Pocket menu tiles, waterfall rolloff, deck board bottom cleanup, darker Pet Park.
- Pocket Deck performance: script time per frame 1.30 -> 0.68 ms, >20 ms frames 27 -> 7 in scripted rounds (`deck-perf.md`).

Verified before publish: server specs 63/63, client 142/165 (the rest are the known list, argument-mismatch specs and perf harnesses); console clean of new errors; code review GO WITH CHANGES, fixes in d85e7db. **Translations synced (85 add/update, 6 delete).** Not checked: a real phone, any audio by ear, the garden pet wearing a charm and finish.

**Private v775 Published 2026-11-16 — runtime f8d7e66, pushed; servers restarted via Open Cloud. FRESH SAVES (TestFreshSaves).** Quick Links "Add publish notes to v775".
# Pocket Pals — v1 economy, new toys, Spencer's music, phone UI notes

**New since v760:**
- Phone UI notes 1 to 8 from the v760 pass: handheld composed around the mid line, "Skip tutorial" button, background motifs always on behind the deck, Hatch eggs / Deck style / Customize at the Pocket menu's size, in-game UI tinted by the faceplate, no stale "Hatch your first egg" pill, no preview seams, Customize shows NEW instead of replaying a receipt.
- v1 economy: one ladder 40 / 100 / 250 (wardrobe, faceplates, balls); eggs Toy 20, Hue 12, Feature 40; Material Egg off for v1. Welcome round pays 14 Stars so the first Toy Egg is affordable. The Book's Toys page counts the 6 toys only (100% reachable).
- New toy models (Fable): bone, ball and the rest rebuilt (model 134846528553129).
- Spencer's own music: garden = lobby loop (70486364707324, vol 0.07), Pocket Deck = gameboy loop (107339572876342, vol 0.15).

Verified before publish: server specs 59/59, client 140/154 (the 14 failures are the long-standing known set); Play has no script errors, held toy uses the new meshes, deck music plays; five new assets moderation Approved. Code review (4f963e7..HEAD): GO WITH CHANGES, both fixes applied in f8d7e66. **Translations synced (9 add/update, 3 delete).** Not checked: a real phone, garden music by ear in a focused window.

**Private v760 Published 2026-11-16 — runtime 85ba59e, pushed; servers restarted via Open Cloud. FRESH SAVES (TestFreshSaves).** Quick Links "Add publish notes to v760".
# Pocket Pals — deck fit, faster rounds, results polish

**New:**
- **Pocket Deck on phone:** the whole handheld is aspect-locked and centred, with at least 8 px of clearance below Roblox's top bar.
- **Hatch:** opens straight into the full-screen stage, with no in-panel hatch.
- **Results:**
  - The difficulty button cycles Easy → Medium → Hard → Easy.
  - The Star is rim-lit and reads as a Star while it spins.
  - The Stars chip uses the 3D Star.
- **Faster, punchier rounds:**
  - The round clock runs at 1.3x.
  - Drop cooldown is 0.2 s, and the next ball is ready in about 0.5 s.
  - The settle takes 2.3 s.
  - Merges are snappier, and the screen kick scales with tier and chain.
  - The chain pitch climbs to an octave.
  - The fill line has a heartbeat and a danger tick.
  - A Medium round takes about 33 s.

**Passed before publish:** server 58/58; client 134/149 (all failures long-standing); Code Reviewer GO (no blockers). Translations unchanged (0 add/update).

**Not checked live:** a real phone; the screen kick and the new pitch, heard live.

## Historical (earlier builds)

**Private v751 Published 2026-11-16 — runtime 664c7e9, pushed; servers restarted via Open Cloud. FRESH SAVES (TestFreshSaves).** Quick Links "Add publish notes to v751".
# Pocket Pals — v735 QA fixes, new sounds, world palette, v1 prices

**New:**
- **Pocket Deck on phone:** it fits the safe area on every open. Cause: the compact layout drew the body 32 px past the bottom; the DeckFit spec now guards it at 5 sizes.
- **Deck animation:** opening and closing are smooth, and the power-on always finishes.
- **Rounds:** the fill-line warning only fires near the line, and the left/right areas are back.
- **Deck style:** Moonpond animates.
- **Results:** the Star spins all the way round again, the headline uses the display font, and the entry eases in.
- **Hatch:** a softer entry and brand-new synthesized rarity sounds (Common / Uncommon / Rare).
- **Toys:** the Ball is now a tennis ball.
- **Help:** the Companions How it works has a Hatch eggs card. The top pills open explanation cards, and the first-session tour is four cards.
- **World:** greyer marble, darker grass, bluer water, a brown path.
- **Park:** "Pets playing n/9" above the buttons, and "Park full" when it's full.
- **Prices:** Wardrobe 25/50/100, faceplates 30/60/120, balls 30/60/60/160. Eggs are unchanged.

**Passed before publish:** server 56/56; client 133/147 (the failures are long-standing, plus one fixture); world collision 12/12; all solid world meshes precise; Code Reviewer GO WITH CHANGES (the tour/notice fix applied). Translations synced (59 add/update). The rarity sounds were approved by moderation.

**Not seen live:** a real phone; the new sound inside a live hatch; a real tap on a notice pill.

## Historical (earlier builds)

**Private v735 Published 2026-11-15 — runtime 2208bab, committed and pushed; old servers restarted via Open Cloud. FRESH SAVES (TestFreshSaves).** Quick Links "Add publish notes to v735".
# Pocket Pals — Spencer's v685 QA fixes, new reveals, inspect card

**New:**
- Smash-style pet reveal is back (egg opening inside it; soft glowy Bear that waves).
- Items get an exciting reveal: rarity glow and beam, burst, card flip, name slam, banner, a distinct sound per rarity, fun descriptions, and a turning 3D result on a coloured backdrop.
- Smooth transitions in and out. No extra Hatch confirmation.
- Pocket Deck fits below Roblox's top bar on phone, with a steady camera on open. Moon background stays behind the balls.
- Hatch eggs and Companions clipping fixed; notification pill centred; fuller Pocket menu; Toys row in Companions; daily stamp chip on Hatch eggs.
- Tap your pet more easily. Inspect other players' pets on a profile card (Say hello; turn greetings off in Settings).
- New Pocket Deck toy (Toy Egg). Pets carry their toy and sit for longer.
- Lamppost moved off the first bridge. The game is now called Pocket Pals.

**Passed before publish:** server 56/56; client 126/140 (all 14 failures long-standing); world collision test 12/12; Code Reviewer GO (one fix applied); translations synced (82 add/update, 10 delete).

**Not seen live yet:** Say hello with two accounts; the Pocket Deck toy in hand; the full hatch flow in motion on a phone.

## Historical (earlier builds)

**Private v634 Published 2026-11-14 — runtime f75cf12, committed and pushed. FRESH SAVES (TestFreshSaves).** Quick Links "Add publish notes to v634".
# Egg Drop — world flicker fix

The 38 overlapping surface pairs behind the flicker at the aqueduct spring, colonnade caps and nearby trim are gone (six world meshes re-uploaded, precise collision rebuilt). Everything else as v633. World specs pass. 196 smaller same-facing pairs in other structures are logged in `artifacts/overnight-2026-11-14/FLICKER-FIX.md`.

## Historical v633 (follow-ups)

**Private v633 Published 2026-11-14 — runtime 783eb0e, committed and pushed. FRESH SAVES (TestFreshSaves).** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v633".
# Egg Drop — follow-ups: bond 6-10, Stargazer, Leaf charm, phone menus, round camera

**New:**
- Bond levels 6–10 (gold hearts) with tricks at every level from 3. The pet sits still for you again from level 1; at level 2 it sits sooner.
- The Stargazer faceplate (earned at Discoveries 100%), the Leaf charm (14 stamps) and a heart burst sprite on level-up.
- Hatch eggs and Customize phone menus use the newer phone layout; Background and Ball shop grids no longer clip their first cards.
- With the deck open, the camera parks above you looking toward the hub.
- Kitty W squashes with the mouth expressions.

**Passed before publish:** server 44/44; client green except long-standing; Code Reviewer GO; translations synced (9 add/update, 1 delete).

**Not fixed:** world flicker (38 coplanar pairs; see FOLLOWUP-ART.md).

## Historical v628 (overnight content)

**Private v628 Published 2026-11-14 (overnight) — runtime 2183795, committed and pushed. FRESH SAVES (TestFreshSaves): everyone starts from zero again.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v628".
# Egg Drop — overnight content: recolours, weekly shelf, new wearables, toys, charms, Discoveries, bond levels

**New:**
- Wardrobe: 6 new items (Blush Stickers, Party Hat, Bow Tail, Acorn Pendant, Friendship Bands, Round Specs) and 10 recolours. Eyewear, Cheek and Wrist tabs; the tab strip scrolls on phone.
- Deck style: Grape Soda and Rose Chrome faceplates, the Bubbles ball theme.
- Weekly shelf: 3 items at 20% off, resetting Mondays, with a "This week" line in the hub.
- Toy Egg: Wobble Top and Squeaky Carrot. Earned Heart and Star charms. 6 new Discoveries.
- Bond: pets earn bond from petting, rounds and Play dates. Levels show as pips, with a level-up toast and two tricks.
- Blip (second pet, free on the 7th stamp) is in the code but OFF (FeatureFlags.SecondPet=false) until his model is imported.

**Passed before publish:** server 44/44; client all green except the long-standing failures; Code Reviewer GO; translations synced (79 add/update, 1 delete).

**Test:**
- Wardrobe tabs on phone; recolour cards; the new wearables on the Bear.
- Shelf chips and prices in all three shops.
- Toy Egg odds pane (now 5 rows).
- Bond pips after petting.
- Charms tab (Heart and Star lock lines).
- Book thumbnails for the new items.

## Historical v615 (slice A)

**Private v615 Published 2026-11-14 — runtime d4c21cc, committed and pushed. FRESH SAVES (TestFreshSaves): everyone starts from zero again.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v615".
# Egg Drop — slice A: new face items, analytics, no Reset Hue jar

**New:** Wardrobe Eyes gains Happy Eyes, Lash Eyes and Round Eyes, and Mouth gains Kitty W (15 Stars each, with Book thumbnails). Hue Eggs roll the 4 fruits at 25% each (no Reset jar; jars you already hold still work). Analytics: a 9-step new-player funnel and events for egg opens, stamps, Play dates, the petting cap, Book milestones, Wardrobe equips, Robux purchases, and rounds/wallet at session end.

**Passed before publish:** server 32/32 (new FirstSessionFunnel); BookView, PetAttachments, R4Content, LocalizationFit pass; Architect + Code Reviewer GO WITH CHANGES applied. Translations synced (3 add/update, then 2 add/update + 1 delete for the eye swap).

**Test:** buy and wear each new face item; open the Book's Wardrobe page; Hue Egg odds read 25% x4. After a session, Creator Analytics > Funnels (Onboarding) and Custom events should show data (can take hours).

## Historical v609 (QA pass v2)

**Private v609 Published 2026-11-13 — runtime 6c77cb4, committed and pushed. FRESH SAVES (TestFreshSaves): everyone starts from zero again.** Studio Output: "Published new changes in "Egg Drop" to Roblox." Place saved v609. Phone results capture `artifacts/qa-2026-11-13-v2/studio/phone-results-748x294.jpg`.
# Egg Drop — QA pass v2 fixes (PC + phone)

Every item in `artifacts/qa-2026-11-13-v2/QA-TRIAGE.md`: full-screen reveal with confetti; first Bear's Back goes to the garden; Meet Bear framed in front of you; garden tips wait until you're idle (replay from Settings / ?); Hatch eggs shine and sparkles on the egg, the Bear cheers on Hatch, the list scrolls. No walking with any menu, reveal or the deck up; the camera no longer clips the island; Menu/Deck buttons moved bottom-right; hints show your device's real keys. One full-screen dim per menu on PC and phone, taller phone menus, the 3D Star in every menu, a new Quests screen (stamp card now lives there), a ? "How it works" on every machine. None per Wardrobe slot, hats sit on the head, Customize previews, brighter colours and a free "Original colour", ball previews drop in, Equipped is a greyed button, tab labels no longer vanish. One-piece station pins with names (Hatch eggs marker back), desk thumbsticks gone, marble lining flicker fixed, petting +1 ★ after 1.5 s (10 a day) with a sparkle and chime. Phone deck: the full handheld, big left/right in rounds, up/down in menus, B = Back in menus. Board tips are a small fading pill; the phone results headline and Star moved down.

**Passed before publish:** server 31/31; client green except the 7 long-standing failures; LocalizationFit 0 clip (13 screens x 2 sizes); translations synced (453 strings). Architect re-cut + Code Reviewer GO WITH CHANGES, all applied. World meshes re-uploaded with precise collision.

**Test:** the whole QA v2 list on PC and phone; hold W while opening a machine; orbit the camera into the ground; each machine's ?; Settings > Show tips again; petting for ~1.5 s.

**Note:** forward-only build (petting cap 10 and "Original colour" receipts fail v600's checks); fine while fresh saves are on.

## Historical v600 (v1 batch)

**Private v600 Published 2026-11-13 — runtime 2bf12d6, committed and pushed. FRESH SAVES (TestFreshSaves): everyone starts from zero on this build.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v600". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · capture `artifacts/v1-2026-11-13/welcome-card-desktop.jpg`.
# Egg Drop — v1 batch: onboarding, bug reports, translations, book art

**New:** a "Hatch your first friend · ★ +6" card on a fresh save's first round (the fill line can't end that round; the Bear grant pays +6 Stars); a three-beat garden walkthrough after the Bear (machines, hub, first quest); one-time tips (fill line, first visit to each machine and the book, Pet Park, first item, first quest); +2 Stars for a missed round with a goal met. Settings → "Report a bug / Suggest something" (filtered note, rate-limited, owner-only reader). Translations: 376 strings in the cloud table, auto-translated into 18 languages, synced every build; translated text truncates or shrinks instead of clipping. Original Bookworm faceplate; the collection book shows thumbnails.

**Passed before publish:** server 30/30 (new CoachMask, BugReports, SessionRecovery); client 76 (7 long-standing failures unchanged; new CoachCards, BookView cards, LocalizationFit 0 clips on 13 screens x 2 sizes). Code Reviewer GO WITH CHANGES, all applied. Translations synced (0 add/update, 0 delete; 376 in table). Place saved v600.

**Test:** fresh save start to Bear (card, +6, walkthrough, each machine's tip once); a missed round with a goal met (+2, "Goal met" row); send a bug report and a suggestion; the book's thumbnails and the Bookworm plate (finish 3 pages); a second account in the park for duos; set your Roblox language to Spanish to see translations (may take hours to appear).

**Before launch:** TestFreshSaves=false; shard bug-report day keys; confirm Park; store listing in Creator Hub (`artifacts/store-listing/`).

## Historical v590 (QA fixes + machine hub)

**Private v590 Published 2026-11-13 — runtime cf7d99d, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v590". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · Studio captures `artifacts/qa-2026-11-13/studio/`.
# Egg Drop — QA pass fixes and the machine hub

Fixes from Spencer's 2026-11-13 QA pass (`artifacts/qa-2026-11-13/QA-TRIAGE.md`): the camera stays still in the Pocket Deck; no screws; cleaner goals and side panels; a lose sound; the results Star no longer flashes, pops in or resets its spin; the flourish plays out; "Settling…" while the last ball lands; the whole deck shakes on merges; item icons and a "+ Magnet" toast; an aim/drop hint for new players. Menus: one dim layer, Wardrobe/Customize/Book slide in, Wardrobe shows item previews, style changes apply instantly, alt-tab keeps your cursor and the music, petting pays +1 ★ after ~4 s (still 5 a day). World: you can no longer walk off the edge, flags wave without flicker, clouds bob, less bloom, scrolling water, flat animated waterfalls with foam, lamps off the paths, bridges meet the paths, river lining capped, hub benches/toys and kiosk joysticks gone. Pet Park: slide and benches face the right way (one 5-seat bench inside), a park icon, pets walk in with you, and pets pair up. **Machine hub:** M opens tiles for Hatch eggs, Deck style, Companions, Quests, Collection book and Settings (a pause menu in rounds); Pocket Trials gone; real stamp art; results show "Today: ★ earned".

**Passed before publish:** server 26/26; client 75 (7 long-standing failures unchanged). Code Reviewer GO WITH CHANGES, all applied. Place saved v590 with world collision and textures restored.

**Test:** everything in the QA list; two accounts in the park for duos; the hub from the garden and pause in a round; petting for ~4 s.

**Still open:** onboarding (beyond the idle hint), bug reporting, translations; Bookworm faceplate art; book thumbnails.

## Historical v583 — Pet Park playground, easier pet click, 3D wallet Star

**Private v583 Published 2026-11-13 — runtime 73e0b9f, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v583". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · Studio captures `artifacts/pet-park-2026-11-13/studio/`.

New since v568: a **Pet Park playground** on the lawn by the east picnic table. Walk inside the flowered edge (or sit on a bench with the "Sit" prompt) and your pet plays on its own: swings, slide, see-saw (needs a second pet), sandbox (castle grows in 3 stages), ball corner; duo activities pair it with another player's pet. A small chip shows the **Play date** (3 activities a day = +4 Stars). Your pet has a much bigger click/tap area (whole body, 16 studs), and the wallet Star is a turning, glinting 3D Star. The tree and shrubs inside the playground are gone, and the hub marble and trim have their textures back (they had been plain white since v550).

**Passed before publish:** server specs 25/25 (ParkDirector, PlayDate, ParkMount, garden, saves), client specs 68/68 (ParkClient, ParkPetPose, PetClickTarget, WalletStar ...). Architect review + Code Reviewer GO WITH CHANGES (all applied). Solo playground cycle seen live in Studio.

**Test (two accounts):** both players stand in the playground: see-saw, sandbox together and ball toss between your two pets; one player walks out mid see-saw (the other pet hops off); sit on a bench; Play date chip reaching 3/3 and +4 Stars; Roblox chat bubbles. Also tap/click your pet from a distance, and watch the wallet Star.

**Still open:** pets land a little in front of swings/see-saw and walk back; gate orbs don't bob; the playground switch (`FeatureFlags.Park`) is on in this private build only.

## Historical v568 — play forever: collection book, stamp card, records

**Private v568 Published 2026-11-13 — runtime a8dc779, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v568". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · Studio captures `artifacts/play-forever-2026-11-13/studio/`.

New since v558: a **Collection book** (Pocket Menu and Companions hub): Balls, Faceplates, Wardrobe, Toys and Discoveries pages with % bars; each page pays 5 / 5 / 10 / 15 Stars at 25 / 50 / 75 / 100%, once; three full pages earn the book-only **Bookworm** faceplate (placeholder art). A **Records** page shows your lifetime numbers. The daily gift is now a **stamp card**: 4, 4, 5, 5, 6, 6, then 12 on the seventh day played, never resets. Egg odds show as percentages; in regions where paid random items are restricted, Star-priced eggs give the next item in a fixed order ("Next: ...").

**Passed before publish:** server specs 18/18 (new BookClaim, StampCard, LifetimeCounters, RestrictedEggs), client specs 64/64 (new BookView, StampCardView). Architect review + Code Reviewer GO (policy cache fix applied).

**Test:** Pocket Menu → Collection book (claim a milestone, open Records), the stamp card on the daily page and in Hatch eggs (stamp today, come back tomorrow), buy a ball theme and see the Balls page move, on desktop and phone.

**Still open:** Bookworm art; book item thumbnails; the "+12 Stars" pop briefly overlaps the stamp tagline; a slow claim can show a false timeout until the next refresh.

## Historical v558 — UI personality pass

**Private v558 Published 2026-11-13 — runtime 9586f02, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v558". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · Studio captures `artifacts/ui-personality-2026-11-13/studio/`.

New since v550: Fredoka One for titles, names and buttons; friendlier copy (one string table, `src/shared/UICopy.lua`); a fixed house palette with one tint per screen (peach Hatch, lilac Deck style, pink Companions, sky Quests, gold results: a dot, a squiggle under the title, a halftone fade); A/B hint caps like the deck's buttons; lips on things you press and stitched seams on panels you read; tilted sticker chips for prices, tiers and "New best"; an LCD dot grid in preview windows; boing and tab squash motion (off under Reduced Motion); your pet peeks into Hatch eggs, Deck style, results and Quests on desktop; the Star has a face (wallet eyes, results hero); empty states with a line in voice.

**Passed before publish:** all 62 previously-green client specs (new UICopy 6, KitSurfaces 8, PetPeek 10). Architect review + Code Reviewer (GO WITH CHANGES: text measuring made synchronous; tiles release a stuck press).

**Test:** Deck style (all three tabs), Hatch eggs, a round's results (win and miss: the pet hops or droops, the Star face watches the count), Quests with every daily claimed, the Wardrobe with nothing owned, all on desktop and phone (no peek on phone).

**Still open:** icon redraw (T10); phone Deck style detail pane overlaps its finish and status lines (older); Hatch/results/Quests peek positions checked only by specs so far.

## Historical v550 — round items, smiley ball themes, dusk world, garden life

**Private v550 Published 2026-11-13 — runtime 0cc2c3a, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." and Quick Links "Add publish notes to v550". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · Studio captures `artifacts/batch-2026-11-13/captures/`.

New since v539: smiley balls by default (no numerals), Deck style **Balls** tab (Smileys and Marbles free, Gumdrops 20, Gems 40, Planets 40, Kittens 120 with cat ears), Next/Then faces animate, goal text uses colour names/circles, results count-up blips. Round items: star (power-up) balls fill a 3-slot belt; **B** opens the item carousel and pauses the round (Swap, Pop, Magnet, Bomb); phones get an item button under A ("You have no items" when empty). Items are off in the Welcome round, guided rounds and before your first win. The faceplate now tints only the deck. Garden locked at dusk with new sky, warmer textures, 12 props removed, flat flower patches and frond bushes; brook, waterfall and bird ambience (off during rounds) and a Pocket Deck music placeholder; stations pulse an icon until used; pets sit, look at you, idle and coo more. Save is now v11 (do not roll back past 0cc2c3a).

**Passed before publish:** server specs 14/14 (HatchProgress 27, RoundItems 15, BallThemePurchase, ToyFeatureProgress 21, WorldRoutes 7, GardenGreyboxWorld 9, RunReturn 24, …); client 62/71 (7 pre-existing failures; JellyRenderOwner needs a new probe; HardwareDeck needs a live Ready round). Code Reviewer GO WITH CHANGES, all three fixes made. Re-uploaded world meshes got their precise collision rebuilt in Studio and the place saved (v550) before publishing.

**Test:** win a round, then play another to see star balls, the belt chip and B carousel (use Swap/Pop/Bomb/Magnet); Deck style → Balls (buy Gumdrops, equip); the results count-up blips; walk the dusk garden (waterfall gets louder, birds, flower patches, bushes, nothing blocks the arrival path); stations' icons; a pet sitting by you; on your phone, the item button and "You have no items".

**Still open:** desktop Items card (a small board chip stands in); hub floor glare and tan rocks vs the reference; all audio placeholders; not checked on a physical phone.

## Historical v539 — redesign: celebrations, menus, round look, 3D eggs and Star


**Private v539 Published 2026-11-13 — runtime 8d4e432, committed and pushed.** Studio Output: "Sent message to server to publish" and Quick Links "Add publish notes to v539". [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/publish-2026-11-13/private-published-v539.jpg) · Studio captures `artifacts/redesign-2026-11-12/studio/`.

New since the QA-fix build: full-screen hatch reveal stage (spotlight, drag to spin, name plate); results screen with a 3D Star, count-up, next-egg meter, quest progress and a Hatch button; round look (no rings or yellow border, vivid eggs, tier V violet, fill line that turns amber and says "Stack too high · Merge to clear"); your Deck style background drawn in the board; Deck style screen (Faceplates | Backgrounds); Companions hub (Pets / Wardrobe / Customize) with Charm "None"; Hatch eggs as a list with a spinning 3D egg. Placeholder sounds for every new cue.

**Passed before publish:** 46/53 client specs (7 pre-existing failures unrelated to this build), all server specs (OverflowGraceLeft 6, RunReturn 24, WorldRoutes 6, HatchProgress 27, HueProgress 18, Wearable/FaceplatePurchase); every module loads; board span peak 1229/1536; two Code Reviewer passes, all findings fixed.

**Test:** a round to the fill line (Hard is fastest), a win and a missed round (results + 3D Star), Hatch eggs (3D egg, hatch), the hatch reveal (drag to spin), Companions → Customize → Charm None, Deck style Backgrounds, on your phone.

**Still open:** the Features tab and Feature Egg are hidden on purpose; fill-line coach card (needs a save field); sounds are placeholders; not yet checked on a physical phone.

## Historical — QA bug fixes after v515

**Private build Published 2026-11-12 (the publish after v515) — runtime 7e017dc, committed and pushed.** Studio Output: "Published new changes in "Egg Drop" to Roblox." [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/qa-bugs-2026-11-12/private-published-qa-bugs.jpg) · captures in `artifacts/qa-bugs-2026-11-12/`.

Fixes from Spencer's v515 QA pass: the Pocket Menu on a fresh save explains its locked rows and the d-pad moves through them; on phones the deck, quest log, picker, results, Wardrobe and Faceplates sit below the Roblox controls and the screen is a little narrower; Wardrobe cards are no longer clipped; the "Dot" charm is called Snowflake; the hatch reveal pet fades in once loaded (no stretched/dark Bear); water flow lies flat on the river; stairs, column tops and trees render both sides; the lantern rope reaches the tree; the hub is dimmer at night.

**Passed before publish:** CompactPhone 10/10, DeckScreen 8, DeckResults 8, DeckQuests 5, DeckBoot, PetAttachments 8, WorldRoutes 6, HatchProgress 27, RunReturn 24, WearablePurchase, FaceplatePurchase. Code Reviewer GO WITH CHANGES (both changes made).

**Test:** fresh-save Pocket Menu on the phone; the round, quest log and Wardrobe tops on the phone; a hatch reveal; the river, rotunda stairs and hub at night.

**Still open:** Wardrobe item thumbnails, Charm "None" row, vase crowding, waterfall sound, redesigns from the QA pass (hatch reveal stage, egg screen, Companions menu, results screen, deck style header), Easy payout, physical-phone and save/rejoin checks.

## Historical v515 — phone deck frame, Pocket Menu, wearable fixes

**Private v515 Published 2026-11-12 — runtime 30aa1ba, committed and pushed.** Studio Output: "Published new changes in Egg Drop to Roblox", v515. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/publish-2026-11-12/private-published-v515.jpg).

New since v505: phones get the slim Pocket Deck frame (one wide screen between slim shoulders, A at mid height, no B on touch, centred board with icon goals on small phones; UI-SPEC-COMPACT-FRAME-2026-11-12.md section 10). MENU opens the Pocket Menu (Resume, Restart round, Quit to garden, Hatch eggs, Customize; the round pauses; Restart/Quit confirm mid-round). Quest log opens from the Daily quests card or Q. The tee's right sleeve renders; Little Hoops hang from the ear lobes; Wardrobe swatches use the pet's colours; faceplate op-id fix; sparkle-eye shine fix; odds read "1 in 3".

**Passed before publish:** CompactPhone 9/9, DeckScreen 8, DeckBoot 10, DeckResults 8, DeckQuests 5, RunReturn 24, FaceplatePurchase 10, WearablePurchase 11, PetAttachments 8. Live check: deck accent matches the equipped plate.

**Test:** on the phone: round HUD readability, drag-aim and A, MENU → each Pocket Menu item (Restart and Customize were not checked live), Daily quests card → quest log, results sheet; the Wardrobe (tee sleeves, hoops, swatches); a faceplate purchase.

**Still open:** physical-phone check, live save/rejoin, two-player check, restart mid-round live, Customize from the Pocket Menu live, wings drop rate (15%). Audio is with Spencer.

## Historical v505 — Bear, Pocket Deck, quests, wearables

**Private v505 Published 2026-11-12 — runtime bf5c728, committed and pushed.** Studio Output: "Published new changes in Egg Drop to Roblox", v505. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/publish-2026-11-12/private-published-v505.jpg).

What is in it: the plush Bear as the v1 pet (two-tone body, night glow), World 1 floating sky island with matte materials, rebuilt Pocket Deck (wide screen, in-deck results, back arrow, faceplates for Stars, retro boot), daily/weekly quests with a saved reroll, Easy/Medium/Hard (x0.8/x1/x1.5 Stars), Feature Egg horns and wings growing S1-S5 (wings flap), 13 wearables in the Wardrobe at the Care Cradle (15/30/60 Stars, save v10), a split shirt that follows the arms, compact phone layouts.

**Passed before publish:** WearablePurchase 11/11, CompactPhone 8/8, PetAttachments 8/8, HatchProgress 27/27, FaceplatePurchase 9/9 and a Play smoke test (fresh save, Space x5 earns the Bear).

**Test:** play a few rounds on each difficulty → finish daily quests and reroll one → buy a faceplate → buy and wear items in the Wardrobe → check the Bear at night → try it on a phone.

**Still open:** physical-phone layout check, live save/rejoin, two-player check, faceplate op-id reuse can report a false "Saved", Wardrobe swatches are grey for secondary-tinted items, the 3D deck faceplate texture did not load in Studio, the wings drop rate (15%) is grindy, and the left sparkle-eye shine sits close to the pupil. Audio is with Spencer (AUDIO-HANDOFF.md).

## Historical v397 — round feedback and clear rewards

**Private v397 Published — runtime b733167, committed and pushed.** Refreshed native Version History verifies **Round feedback and white zero notches - b733167**. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/round-juice-2026-11-09/private-published-v397-b733167.jpg) · [Screenshot gallery](artifacts/round-juice-2026-11-09/GALLERY.html) · [Verification](artifacts/round-juice-2026-11-09/VERIFY.md).

Every hue0 notch is now white on both Main/Secondary, with a dark current-dose check; saved colours, stages1–5, inventory and confirmed one-channel Reset are unchanged. Accepted Drop gives the entire device a small tap. A witnessed round ends with final-ball bounce and bounded seed/ribbon confetti, retiring on replay/leave. Recap has one exact payout breakdown and one actual-goal checklist, without redundant source cards, hints or BEST kicker. Egg shop uses three measured offers per row and accessible narrow fallback. Matte/Gloss receipts show a lit teal sample with ground shadow. All five egg families have complementary cold-load shell pieces and a120ms open-shell gap before the reward enters.

**Passed:**250 unique client cases/26 suites (preference/focus reruns overlap),40 isolated server cases/3 suites,171/171 native source matches and compiles, cold Rojo and diff checks, independent Sol source review and Astra rendered review. Actual ordinary controls completed both Bank goals:1010 points, chain9,12 Stars =6 Quest +6 Daily. A65-frame trace observed one art owner,12 confetti pieces then zero. Actual earned8-Star Toy Egg awarded Ball and applied it to Zivvi; quick replay and garden re-entry opened empty new rounds. Desktop and iPhone17Pro emulator shop navigation passed. Original Medium/Automatic/default viewport restored, QA removed, Studio Edit.

**Test:** Drop/merge feel →finish round and quick retry →scroll all five egg choices →Toy/Feature Use now at cradle →white0/current hue checks and one-fruit confirmations →Matte/Gloss readability →rejoin on phone and verify Stars/items/appearance. Physical-phone, live rejoin, current two-owner visitor behaviour, ordinary overflow and longer human fun/balance remain open. Existing EditableImage-disabled/legacy wrong-type warnings and intermittent failed egg-image fetches remain; fallbacks were tested and no security settings changed. Garnet/Ink colour trials remain design-only; versioned catalog/receipt compatibility and Ink Main night contrast are still TODO.

## Historical v389 — device, hatching and personal play

# Egg Drop — device, hatching and personal play

**Private v389 Published — runtime13afc44, committed and pushed.** Refreshed native Version History verifies **Personal toys, features and hatches - 13afc44**. [Publication proof](artifacts/device-hatch-play-2026-11-09/private-published-v389-13afc44.jpg). [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Current gallery](artifacts/device-hatch-play-2026-11-09/GALLERY.html) · [Exact checks and limits](artifacts/device-hatch-play-2026-11-09/VERIFY.md).

The complete handheld now recoils together, with correct touch/aim mapping. Ended runs clear under cover before a fresh board appears; active suspended games keep their state. Larger measured type, shared scroll bounds, four-column pet cards, a horizontal halo and plain action faces replace the reported layout defects. Companion customization/switching is at the care cradle; Deck style is at the workbench. Pocket Menu keeps Hatch eggs, Pocket Trials and Settings. Exact saved-item Use now remains available without granting general editor access.

Five original patterned eggs share registered cracking halves, bounded rays/sparkles and one-shot audio; skip, repeat-open, Reduced Motion and interruption do not duplicate results. A matching saved fruit application starts a brief bite in the live preview. All hue/items, wallet and reward authority remain on the server.

**Toy Egg: 8 earned Stars.** Unlocks one remaining Ball, Bone or Sparkler permanently; freely select a toy or None per pet at the cradle. Quiet grounded pets play briefly during ordinary garden idle, stopping for movement, carry, care or focus. Selected toys are public appearance data; visitor motion is rendered locally and is not frame-synchronized. The old shared world-ball activity and props are removed.

**Feature Egg: 32 earned Stars.** Horn buds 50%, Claws 35%, Folded wings 15%. One stored item grows that feature on one pet by one stage through five. Freely show 0 through the earned stage; all three may coexist. Features are cosmetic. Full rolled stock refuses with no debit; odds do not silently change. The four-pet new-hatch pool and all seven retained owned IDs remain unchanged.

**Verification:** 190 unique client cases/21 suites at Largest (182-case batch plus bounded shop-reopen 7 and first-row 1), backend 126/11 and affected garden 47/5 (13 overlap backend). All 169 runtime sources match native Studio and compile; final Rojo/diff checks pass. Astra asset/geometry/phone review and independent Sol source review pass. Actual earned controls covered 24-drop merging/rewards, zero-old-frame reset, Toy Egg buy/equip and full Sparkler episodes. iPhone Studio emulation covered actual Touch A/aim/Menu/hatch; seeded owner editor/feature/fruit fixtures are labeled separately.

**Still open:** physical-phone performance, live-service save/rejoin, real multi-client visitor/carry/bay contention and longer human play. Feature purchases/growth and fruit animation use isolated exact transaction/presentation tests, not a naturally earned 32-Star walkthrough in this pass. Existing EditableImage-disabled and legacy wrong-asset-type notices remain. No account/security settings changed. Garnet/Ink, gradients/Metal, stats/training, textured larger garden and replacement retired-pet designs remain on TODO. No production-readiness or proven fun/retention claim.

## Historical v370 — playful care and material eggs

# Egg Drop — playful care and material eggs

**Private v370 Published — runtime97c64d0, committed and pushed.** Refreshed native Version History verifies **Playful care and material eggs - 97c64d0**. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/playful-care-2026-11-09/private-published-v370-97c64d0.jpg) · [Screenshot gallery](artifacts/playful-care-2026-11-09/GALLERY.html) · [Verification](artifacts/playful-care-2026-11-09/VERIFY.md).

Companions now has Pet / Hue / Charm / Materials tabs. Hue rows show0–5 with the saved dose checked; any notch offers exactly one next fruit, or explains no stock/max. Zero does not reset; Reset Hue still targets one confirmed channel. Confirmation art retires on every exit, and decisions omit routine Saved/Review use. The first Pet row has real top inset. Solid carry arrows and playful measured supporting type replace the older treatment. Short result cards show the item and both actions together.

**Material Egg:16 earned Stars**, initially50/50 Gloss/Matte, then100% the remaining finish. Account unlocks are permanent; applying Standard/Gloss/Matte per pet is free and reversible. No duplicates or spending when complete. Metal is excluded because its native trial resembled Gloss; gradients also remain TODO. Existing pigments, facial roles and historical receipts are preserved.

Charm changes request an immediate coalesced durable save instead of waiting for the periodic12s flush. One isolated actual Ring click reached durable confirmation in117ms; this is not live-service latency evidence. Daytime coats are brighter while accepted night emission remains unchanged. Device-art shake is stronger and tier/chain based, exterior backdrop has8% garden bleed, and three original egg images replace the capsule silhouettes. Ripple relay, Bank bounce and Mirror marks add compatible two-stage objective variety.

**Passed:**219client cases/25suites at Medium;190cases/24suites at Largest, plus the29-case hatch suite at Medium;191server cases/19suites. Preference reruns overlap and must not be added.149exact source matches/compiles, cold Rojo/diff checks, independent Sol reviews and Astra rendered GO. Actual24-drop Bank/Creek rounds earned rewards; actual Stars purchased Gloss and selected it for Zivvi. Six-seed new-objective solver replay passed6/6,5/6,5/6; ordinary native completion of those new templates remains open. Final clean launch/5actualSpace presses earned the starter. QA removed,7unique native material profiles, production scripts enabled, Medium/Automatic/default viewport restored.

**Still open:** physical phone/touch, live-service save/rejoin, real multi-owner carry/bay contention, R6 controls, lowest graphics and longer human play. Existing EditableImage-disabled/legacy asset-type notices remain; no security setting changed. Dark-red/black pigments, Metal/gradients, features/stats/training and the textured garden remain on TODO. No production-readiness or proven fun/retention claim.

## Historical v358 — companion editor and luminous pets

# Egg Drop — companion editor and luminous pets

**Private v358 Published — runtime4bf7893, pushed.** Refreshed native Studio Version History marks v358 Published. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/companion-editor-2026-11-09/private-published-v358-4bf7893.jpg) · [Screenshot gallery](artifacts/companion-editor-2026-11-09/GALLERY.html) · [Exact checks and limits](artifacts/companion-editor-2026-11-09/VERIFY.md).

Round results use readable dark ink, a better Stars emblem and already-open scrolling details; the obsolete selected-egg progress area and Details button are gone. **Companions** replaces Journal entry routes with Pet / Hue / Charm tabs, square live owned-pet previews, a fixed live preview and independently scrolling choices. Main and Secondary remain separate, and item use still asks for confirmation. Charm On / Off is explicit; Ring is one original continuous torus. The editor has a bare X and no Stars/carry footer. Closing the physical machine returns the confirmed pet to your arms; the down arrow sets it down safely. Forced cleanup remains separate.

Pets are brighter at night through pet-local emissive PBR surfaces, with darker eyes, visible catchlights and a more luminous charm. Day/night and the garden's global lighting are unchanged. All seven retained designs render with this treatment; the Companion Egg still offers four pets and preserves already-owned retired pets.

**Passed:**161 client cases/20 suites at both Medium and Largest (overlapping preference runs),145 server cases/15 suites,144 exact native source matches and zero compile errors, Rojo build, independent Sol source review and Astra visual review. Ordinary earned Studio controls covered welcome, pickup, walking, placement, saved Ring, X→carry, set-down, overflow receipt and hatch route. Seven-owned previews/positive14-Star receipt and material lineups are labeled fixtures. Six paired seven-pet material rounds showed stable frame time and +0.132ms pet CPU p95. Test objects removed; Medium/Automatic/default viewport restored.

**Still open:** physical phone, live-service save/rejoin, live visitor/bay contention, R6 owner controls, dedicated owned-editor baseline performance comparison and longer human play. Test-enabled-session Focus interference has no established cause; clean ordinary sessions pass. Existing EditableImage/legacy wrong-asset-type notices remain. No production-readiness or fun/retention claim.

## Historical v344 — carry and care machine

**Private v344 Published — Carry and care machine - 5b829e6.** Runtime is committed and pushed; refreshed native Studio Version History shows Published. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/carry-machine-2026-11-09/private-published-v344-5b829e6.png) · [Screenshots and walking film](artifacts/carry-machine-2026-11-09/GALLERY.html) · [Exact tests and limits](artifacts/carry-machine-2026-11-09/VERIFY.md).

Tap your pet, choose **Pick up**, walk to the **Field journal** and use **Place [pet]**. The original cradle opens the live Hue/Charm editor. Pick up again, set down on clear dry ground, or close to resume following. Owned-pet switching asks for confirmation and changes the public pet only after exact saved proof; existing menu shortcuts remain.

Astra accepted the earned R15/Zivvi walk-turn-stop and the actual Largest iPhone17Pro emulator editor. The arms remain a supported cradle while the legs walk. Compact Charm keeps the complete live pet and all three choices visible. Unsafe set-down preserves the hold; deck/close paths release their exact bay.

**Verification:** prior full301-case/36-suite checkpoint retained; final145 server cases/15 suites and45 affected cases/7 suites at actual Largest pass (overlapping reruns, not new independent counts). All142 runtime sources match and compile; Rojo passes. Native controls covered earned pickup, walking, placement, Ring saving, pickup/set-down and close/deck interruptions. Medium/default viewport restored; clean Edit/production entries enabled; QA removed.

**Open checks:** the separate two-player Studio launcher refused to start because Studio is out of date. Actual visitor carry, real R6 controls, physical phone and live-service save/rejoin remain unverified. Isolated two-owner/receipt/lease tests and synthetic R6 geometry are labeled separately. Owned-pet switching is verified through isolated exact-save/UI cases rather than a naturally earned second-pet walkthrough. Minor redundant Charm copy may stay hidden after size-only return to desktop until refresh. The larger textured garden and expanded item systems remain on TODO; no public release or economy changes.

## Historical v326 — complete pets and live Customize

# Egg Drop � complete pets and live Customize

**Private v326 Published � Whole pets and live Customize - 3c6b61b.** Runtime is committed and pushed, verified in refreshed native Studio Version History. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) � [Publication proof](artifacts/care-feedback-2026-11-09/private-published-v326-3c6b61b.png) � [Care gallery with recordings](artifacts/care-feedback-2026-11-09/GALLERY.html) � [Verification](artifacts/care-feedback-2026-11-09/VERIFY.md).

Complete semantic pets remain visible while authored meshes load. Customize now idles, blinks and moves the charm, with exact five-notch result swatches. Reset consumes one jar for one explicitly confirmed Main or Secondary channel. Accepted merges nudge the device art while aim and hit targets stay fixed. Quieter coo poses use existing approved original family audio; four new original auditions remain local.

181 native cases across 23 suites, 132 source matches and zero compile errors, Rojo build, actual earned controls and Largest phone-emulator customization pass. Six paired seven-rig performance rounds show no measured CPU regression in the isolated warmed Studio workload. Accelerated coo playback passed, but a 160-second ordinary roam produced no coo; normal frequency remains unverified. Physical phone, live-service rejoin and human fun remain open. Carry/machine and original garden are next, not included in v326.

## Historical v316 � neutral companions

# Egg Drop — neutral companions

**Private v316 Published — Neutral companions and four-pet pool - c549451.** Runtime c549451 is pushed and verified in refreshed native Version History. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/pet-materials-2026-11-09/private-published-v316-c549451.png) · [Scope and verification](NEUTRAL-ROSTER.md) · [Exact hue chart](artifacts/pet-materials-2026-11-09/current-hue-palette.png).

Undyed bodies start white; paws, charms and secondary accents start light grey. Existing Main/Secondary hue items and doses remain; hands/cuffs now follow Secondary. New Companion Eggs offer Zivvi, Ovelle, Tikket and Nuum. Vezzi/Kiprik/Nolli remain usable if already owned, with preserved stable IDs and receipts. The absent rare pool suspends the rare guarantee without erasing saved progress.

125 native source matches / zero compile errors, isolated Rojo build and148 native fixture cases across15 suites pass. Ordinary welcome controls earned the white Zivvi reveal. An actual follow-up focus attempt did not establish focus with the controller emulator visible; do not count it as passed. Physical-phone and live-rejoin limits remain. The separate gloss/night-material experiment is preserved locally and **not included in v316**.

## Historical v309 — Spring Meadow and Aero babies

**Private v309 Published — Spring Meadow and shared resting - b71c702.** Runtime b71c702 is committed and pushed; refreshed native Studio Version History verifies Published. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Proof](artifacts/spring-meadow-2026-11-09/private-published-v309-b71c702.png) · [Gallery](artifacts/spring-meadow-2026-11-09/GALLERY.md) · [Verification](artifacts/spring-meadow-2026-11-09/VERIFY.md) · [Morning handoff](MORNING-RUNDOWN.md).

The garden now has **160 ×176 studs /37.5% more floor area**, a dry south loop, spring landmark and gathering lawn with two separate six-second pet resting spots. Existing shops, ten spawns, bridge, nook, shared return, all seven babies and item-egg rules remain. No client runtime, schema, economy or reward change in the extension. Astra art/motion/Largest-phone focus and independent Sol source review have GO.

**124 native source matches/zero compile errors; Rojo;198 server cases/21 suites;91 focus cases/six suites;13 final geometry cases** pass. Actual local two-owner routes/rest/focus and unchanged wallets are recorded. Synthetic performance initially triggered a10.41% midnight rig-CPU increase; the declared repeat retained all six final rounds, combined+9.40% (~0.104ms). Phone/service-scale performance is unproved.

Standalone Roblox Player still requires user sign-in for live rejoin; no live VM/profile test ran. The browser connection failed on the v309 census refresh, so no new server census is claimed. Publication itself is native-verified. Physical phone, longer human play, flatter night shading, narrow gray far horizon and old outer-boardwalk pet support remain limits. No access/security/public-release changes.

## Historical v297 — Aero babies and shared garden

**Private v297 Published — Aero babies and shared garden - `2e9da43`.** Runtime commit `2e9da43` is pushed; publication is verified in refreshed native Studio Version History. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/aero-garden-2026-11-09/private-published-v297-2e9da43.png) · [Current gallery](artifacts/aero-garden-2026-11-09/GALLERY.md) · [Exact verification and limits](artifacts/aero-garden-2026-11-09/VERIFY.md).

The item-egg economy from v274 continues unchanged. Explore the usable creek bridge and curved rest nook on the existing **160 × 128** floor. Five replacement babies — **Tikket, Nuum, Vezzi, Kiprik and Nolli** — retain all saved identities/ownership; Zivvi and Ovelle retain their original bodies. All seven share saved Main/Secondary pigments, protected faces and expressive planted motion.

Journal → Customize offers free **Dot / Ring / Pebble** and saved visibility. Published source has `SelectionsEnabled=true` and `PetCharmVersion=2`, with old-client visibility compatibility and opaque future-shape retention. On the clear lawn beyond the benches, **Start a return**, then another nearby owner can **Join return** during the three-second window. Pets approach at their own validated pace and perform a five-second send/return. The toy gives **no rewards**, spends nothing and changes no inventory.

**Evidence:** 123 native source matches / zero compile errors, Rojo build, **172 server cases / 19 suites** and **292 client cases / 36 suites** without duplicate reruns. Ordinary two-client Start / Join / release has Astra film GO; both owners' wallets and inventories stayed unchanged. Actual two-way bridge walking, nook rest, continuous-care Saved awards and short-landscape Largest phone-emulator focus were observed. Medium text and clean Edit were restored before publication. The 6:11 AM post-publication census found one Team Create edit server and no gameplay writer. Night is readable but flatter, with weak individual Vezzi teeth.

Live join was attempted through the authenticated browser but reached Download Roblox while the standalone player was signed out; no live VM/profile test ran. Signing in to the standalone player remains the prerequisite, not a reproduced game or DataStore fault. Physical-phone performance, live save/rejoin, service-scale latency and longer human play remain untested.

The liked music remains default; two new original local listening drafts are in the gallery, with technical approval and subjective listening pending. Nursery, battling, clothing/stat eggs, new currency and public release remain deferred. [Remaining work](TODO.md) · [Current handoff](OVERNIGHT-AERO.md).

## Historical private v274 handoff — retained item-egg rules

# Egg Drop — item eggs and Aero companions

**Private v274 Published — Item eggs and Aero companions — `bb8c60b`.** Verified in refreshed Studio Version History. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/item-eggs-aero-2026-11-09/private-published-v274-bb8c60b.png) · [Screenshots and walking films](artifacts/item-eggs-aero-2026-11-09/GALLERY.md) · [Exact verification and limits](artifacts/item-eggs-aero-2026-11-09/VERIFY.md).

1. Aim the welcome board for guaranteed Zivvi and6Stars. Then play unlimited24-drop field rounds: complete both goals for6Stars, or8 with the low-pile bonus; eligible contracts add their stated rewards.
2. Hatch eggs is one grid: **Companion Egg18Stars** or **Hue Egg8Stars**. Companion odds remain35/25/20/10/5/3/2percent across the seven stable identities; after7common rolls the next is rare-only50/30/20. Duplicates say Already owned and grant nothing. Existing paid legacy receipts remain recoverable.
3. A Hue Egg rolls Rose/Tide/Citrus/Iris/Reset at20%each. The exact jar and wallet debit save before reveal. Duplicate jars stack. Store, Use now and closing/reopening never reroll or charge twice.
4. Journal → each pet's Customize icon → Hue has separate **Main/Secondary** targets, four0–5dose bars and counted jars. Five equal doses fully dye a channel; other hues mix using vivid authored anchors. Confirmation shows pet, channel, dose and stock changes. Reset consumes one jar and restores only the chosen channel. Original-color reset refuses without spending. Charm visibility/shape editing is in this page, not petting.
5. All7identities display applied coats in world/portrait/hatch/visitors. Wallet, held stock, tokens and receipts are owner-private; applied doses are cosmetic public descriptors. Historical entitlements/tokens migrate without repeating grants.
6. Roots and foot planting update smoothly; expressive poses sample15times/sec. Faster facing, anchored support feet, modest weight transfer and independent charm bounce replace sliding. Night is brighter without white clipping, but surfaces remain flatter than noon.

Family mastery remains frozen. The optional daily gift is6Stars; contracts retain Win2rounds+4, Chain3+3, Score500+3. No play cap, paid luck, new currency, nursery or public release. The currently liked music stays default; two new original listening drafts are saved separately.

**Evidence:**112source matches/compiles, Rojo build,102server cases and143client cases at actual Medium/Largest; these are repeated preferences, not extra independent cases. Actual earned Iris purchase/store/cancel/use and phone-emulator menu paths passed. Physical phone, fresh service-backed save/rejoin, live multiplayer/latency and long human play remain open. Current overnight work is [TODO](TODO.md) and [OVERNIGHT-AERO](OVERNIGHT-AERO.md).

## Historical v250 handoff

# Egg Drop — pet loop reset

**Private v250 Published — Pet loop reset and angle aim - a3fce0c.** Confirmed in refreshed Studio Version History after reviewed commit/push and tests. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/pet-loop-reset-2026-11-09/private-published-v250-a3fce0c.png). Accepted runtime: [PET-LOOP-RESET.md](PET-LOOP-RESET.md).

[Reset gallery](artifacts/pet-loop-reset-2026-11-09/GALLERY.md) · [Exact verification and limits](artifacts/pet-loop-reset-2026-11-09/VERIFY.md) · [Economy/save rules](HATCH-LOOP.md).

## Current loop

1. Aim and merge on the welcome board for guaranteed **Zivvi**, then Meet or explore Sprout Hollow. Zivvi/Ovelle retain stored IDs `pip`/`puddle`; sparse veteran ownership and pending receipts stay intact.
2. Open the PocketDeck for unlimited **24-drop rounds**. Bank Pair, Creek Crossing and Lantern Chain rotate. Read the active goal, use the fixed center launch and keep the pile low. Aim maps symmetrically to **±35 degrees at speed 10**; all input paths use the same server-derived spawn/vector. Thin region-threshold lines replace filled/highlighted regions.
3. Both goals earn **6 Stars**, or **8** with the low-pile bonus. Full-budget failed rounds may earn their eligible skill contracts. Recap shows the exact saved amount and selected egg progress. Unfinished rounds survive lounge visits; returning after a completed saved round starts a fresh field. Reconnect starts a new physical board.
4. Hatch tree or Menu → Hatch eggs → **Companion eggs** offers Mixed Meadow (18 Stars) and Sprout Focused (24). Selection is free; only explicit Hatch spends. Close/reopen preserves the exact committed result. A duplicate says **Already owned**, grants nothing and does not change equip unless Meet is chosen. Rare duplicates still resolve the rare guarantee.
5. **Hue Egg** costs **8 Stars** and creates one saved, unassigned held item. Close/reopen retains it. After hatching, choose an actually owned supported Zivvi/Ovelle and one hue, then explicitly **Apply to [pet]**. That exact token advances one hue grade, at most III, without a second debit. No second purchase while stock is held; no purchase when supported owned pets have no further eligible grade.
6. **Colors** is free: learned Body and Accent picks, six two-base Mix recipes, Original body / Default accent, and **Reset to original colors**. Reset preserves grades, unlocks, held stock and charm visibility. Previewing never saves or spends. Body tint strengths are **.65 / .84 / 1.0**, with vivid Rose `#FF327A`, Tide `#008DFF`, Citrus `#FFCC00`, Iris `#9350FF`; protected face roles remain authored.

## Collection and return goals

Seven stable catalog identities remain. Meadow odds are **35/25/20/10/5/3/2%** for Zivvi, Ovelle, Wick, Orbit, Bloom Pip, Foxfire Wick and Eclipse Orbit. Focused is **80% Zivvi /20% Bloom Pip**. After seven non-rare companion hatches, the next is rare-only; this does not guarantee a missing common. Hue Eggs have no rarity roll, pity effect or companion inventory bit.

**Family mastery is frozen.** No new round/hatch marks, challenges, promotions or overhead rank badges; no active Family goals route. Historical marks, receipts and cosmetic entitlements are retained. New saved-win cosmetic gates are **Gloaming at 3 wins**, **Copperleaf and Lantern background at 10**, with old earned entitlements still valid. Honey remains 1 saved win; independent Pocket Trials and other achievement cosmetics remain separate.

Stars are the existing `nectar` wallet one-for-one. Welcome credit is 6; the optional daily gift is 6. Contracts are Win 2 rounds +4, Chain 3 +3 and Score 500 +3 under their valid completed-round rules. Hollow rollover is fixed **05:00 UTC**, with no daily play cap or paid luck.

## Focus, motion and current evidence

Pet focus pauses the server's sampled public actor; a covered owner-local shot never becomes public movement or reach proof. Back restores the current public actor and roaming view, not a stale staged root. The owner avatar is locally masked only for its private shot. Back and labeled Hide/Show charm retain independent targets. Walking drives visible gait; focus, rest and reduced motion suppress it. Night uses the reviewed shaded-head treatment with restrained torso lighting; source-rig comparisons are labeled separately.

Fresh integration matched and compiled **104 sources**. Verified Largest Hue suites passed **13+12**, with fresh uncached presentation suites **13+3+2+3**. Native controls completed 24 drops, settled at **670 /+14 Stars**, then bought a held Hue Egg **20→12**. Actual buy/reopen/apply, independent accent, free mix and reset records are linked in VERIFY. The final ~14-second care input reacted but awarded **0 Stars**; do not count it as observed award proof.

Actual two-client telemetry passed public-pose continuity and owner-only avatar masking through focus/Back. Walking samples showed about .13 studs vertical range over ~18 studs travel. These are pose/mask samples, **not a fixed-camera visual film**. The observed idle sample near the creek showed only rest/follow; safe wander has planner/host test coverage, not live proof from that sample. Physical phone comfort, live-service save/rejoin, latency and longer human play remain unverified. Nursery, additional base forms and public release remain deferred.

## Historical publication records — superseded rules

The records below describe older published builds. Their mastery, old directional Hue purchase and region-fill behavior do not override the accepted reset above.

### Private v241 — 2026-11-08

**Private v241 Published — Stars and Hue Eggs - 7145db9**, verified in refreshed Studio Version History after tests, reviewed commit and push. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/hue-eggs-2026-11-08/private-published-v241-7145db9.png) · [Hue gallery](artifacts/hue-eggs-2026-11-08/GALLERY.md).

145unique Largest client cases and59isolated server cases passed;60Medium checks repeated successfully. Actual desktop earned purchases, duplicate-click single charging, independent free selections, fresh phone-emulator swipe/earn route and actual two-client same-rig palette propagation passed. Physical phone, private-client rejoin and live latency remain unverified. [Hue screenshots](artifacts/hue-eggs-2026-11-08/GALLERY.md) · [Exact Hue evidence](artifacts/hue-eggs-2026-11-08/BUILD-EVIDENCE.md).

The v241 Hue flow selected pet/direction before purchase and used subtle 12%/23%/35% tints. That historical flow is replaced by the generic held Hue Egg and vivid .65/.84/1.0 grades above.

### Private v232 — 2026-11-08

Previous checkpoint: **private v232 — Softer babies and smooth movement - 355fad7**, confirmed in refreshed Studio Version History after tests, commit and push. [Play Egg Drop](https://www.roblox.com/games/96451847774961/Egg-Drop) · [Publication proof](artifacts/pet-softening-2026-11-08/private-published-v232-355fad7.png). This supersedes private v225. Nursery, paid products and public release remain deferred.

The latest pass softens Zivvi and Ovelle into neutral porcelain/pebble babies, replaces Ovelle's suspended arms with attached mittens, and adds seeded blinks, breathing, slow gaze and a softly independent Dot bounce. Shared follow paths ease through turns and braking. The PocketDeck backdrop is stronger, its A-adjacent caption is removed, and both bank overlays sit behind the jelly colors. **114 unique native client /98 isolated server checks passed**, alongside actual desktop/phone-emulator controls and a two-client Studio session with saved charm propagation and leave cleanup. [Current screenshots](artifacts/pet-softening-2026-11-08/GALLERY.md) · [Exact evidence and live movement limits](artifacts/pet-softening-2026-11-08/BUILD-EVIDENCE.md).

## Prior published v180 verification and limits

Final:81runtime sources matched/compiled, Rojo build and diff check passed. Companion client61 and isolated server69 passed; completed/live-return regression21 passed. Earlier slices have their own named layout, appearance, solver, audio and lifecycle suites in the evidence. These repeats are not summed as new coverage.

Actual final controls completed welcome → Pip →24-drop Bank660/chain4 →Saved+12 wallet6→18 →18Meadow Wick →X/reopen sameID/revision →Meet →Back →fresh Creek0/24 with no old recap. Actual foreground29-second petting saved two+1 awards with one purr voice; emulated touch, muted/reduced eligibility, same-finger leave/reentry and window interruption were checked. Source-rendered seven-pet night lineup is a lighting/rig fixture, not seven owned/live peers.

288 production-solver comparisons included72 fast-center rounds, all overflowed and won0; objective-aware policy won24/24 for each template. Nine legal winning traces replayed exactly. These are automated policies, not proof of human difficulty, fun or retention. A rejected lateral-chain experiment is retained as nonshipping evidence.

Short final desktop Room sample:180frames after30warm-up, p95 17.850ms, no new Room node growth; existing62-node arcade FX benchmarks stayed pooled. Engine playback events verify sound ownership/loading/looping, not an audible mix/seam judgment. Optional EditableImage remains unavailable under unchanged settings; tested native GUI spans render the LCD. Known external asset203785492 warnings remain.

Still needed: your physical-phone comfort/performance check, live multiplayer, actual private-client save/rejoin and longer human play/balance/audio testing. This is a private playable prototype, not a production-readiness or proven-retention claim.

[Before/after gallery](artifacts/living-world-2026-11-07/GALLERY.md) · [Exact build/test notes](artifacts/living-world-2026-11-07/BUILD-EVIDENCE.md) · [Accepted design and boundaries](LIVING-WORLD-AND-ARCADE-PASS.md) · [Full economy/save rules](HATCH-LOOP.md).

## Simple layout edits

Tune small layout values in `src/client/DeckLayout.lua` Settings; `src/shared/DeckThemes.lua` holds palettes and `src/client/DeckArt.lua` shared design roles. Restart Play after changes and inspect desktop plus phone emulation. Dragging generated UI during Play is temporary; source/Rojo is the saved version. Keep44px input targets and screen clearance.
