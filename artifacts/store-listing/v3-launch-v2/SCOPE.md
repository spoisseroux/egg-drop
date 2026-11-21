# Pocket Pals v2: new icon, thumbnails and ad campaign (SCOPE)

Fable, 21 November 2026. **A scope for Spencer to approve. Nothing is made, captured, uploaded or spent.** Folder name: store page set 3, for game v2 (live 20 November, runtime `aeae2d9`).

Rules for everything below: real Studio captures of the live build plus hand/procedural compositing (the `build_v2.py` / `compose_v2.py` method). No AI or stock art, video or audio. Only things a player can do in v2. No drawn-on buttons, no Robux, no "free", no "new/update" badges, no subjective claims.

## 1. The pitch

**Problem carried over:** the first Sponsored test got 0.8% CTR but only about 1 in 10 clickers pressed Play. Store page v2 (19 Nov) fixed the ad-to-page match, but it sells the v1 game: one Bear, toys and jars.

| | v1 page (live now) | v2 pitch |
|---|---|---|
| Hook | Merge · Hatch · Dress up | **Merge · Hatch · Train your pet** (dress-up moves to its own frame) |
| Pet | "Your Bear" | **"Your pals"**: Bear and Bunny |
| Why keep playing | collect toys and looks | **six stats that level up** (Heart, Power, Energy, Jump, Speed, Smarts) and a total level |
| Hatch | toys and jars | **Stat Eggs hatch snacks** you feed your pet; the Pop-Out stage; the RARE! moment |
| Stays | Pocket Deck merge (still how Stars are earned), dress-up, Pet Park, deck styles | same |

Short line (ads, socials): *Merge on your Pocket Deck, hatch snacks, train your pet's stats.*

**Honesty guards (apply to every frame and clip):**
- **The Bunny is earned, not rolled.** It arrives free on the 7th daily stamp or is adopted for 400 Stars, then plays a Rare pet hatch. Say "Meet the Bunny", never "hatch rare pets" (no egg sells pets).
- **The Feast is a 10% outcome** (Nibble 60, Snack 30, Feast 10; a Feast is promised by the 8th egg). It can appear as "RARE!" (the game's own stamp) but never as the typical result: the lead image and the ad show the egg and a Nibble or Snack; the Feast gets one labelled frame.
- **Don't say "jackpot" to players.** It is our internal word and reads as gambling on a kids' page. Player-facing word: "RARE!".
- **Stat numbers must be reachable.** Capture a panel a keen first-week player could have (total level about 60 to 120 of 594), not a maxed fixture.
- Stat Eggs are limited to 3 a day ("today's nest"); don't imply endless hatching.
- The hook and description text (LISTING.md sections 2 and 3) also need a v2 rewrite: a small follow-up, see question 8.

## 2. Icon (512 × 512, checked at 150)

What icon C taught us (see `v2/contact-sheet.png` at 150 px): the pink Bear reads, the deck under it is grey mush, and nothing in it says "v2". Most pet-game icons are one animal face on sky blue or green with yellow block letters; we stay in dusk pink, violet, teal and gold with ink outlines and the sticker rim.

| | Concept | In frame | Colour | Versus icon C and competitors |
|---|---|---|---|---|
| **A** | **Two Pals** | White Bear (Pom Beanie, blush) and a dyed Bunny (Rose or Tide, ears up, Flower Crown) cheek to cheek, big faces, both looking at camera. One small Star between them. No text, no deck. | Gold-to-pink burst, violet corner vignette | Two silhouettes, and the Bunny's ears break the square: a shape no neighbour on the shelf has. Says "pets, plural". Drops the unreadable deck. |
| B | Snack Time | One Bear, mouth open, holding a two-layer Snack with its stat-icon topper; three Pocket Buddies stat icons (Heart, Jump, Speed) arcing over its head. | Teal (keeps C's colour for continuity), orange snack | Says "feed and train", which no competitor icon says. Risk: the snack is small at 150 px and may read as "food game". |
| C | Rare Hatch | Bunny popping out of the Companion Egg on the Berry Blast purple stage, the rainbow Rare edge as the icon border. | Violet and magenta, rainbow rim | Most "event" energy. Risk: implies pets come from eggs (the Bunny is earned), and a rainbow rim is the standard "rare pet" cliché. |

**Pick: A, Two Pals.** It is the only one that reads at 150 px without help, it tells returning players something changed, and it uses the same two pets as the lead thumbnail and the ad, so icon, page and ad make one promise. B is the test challenger. C is not recommended.

**How we test it.** Roblox's icon page describes one icon per locale and no icon experiment, so (unless Creator Hub now shows one; see question 6):
1. Baseline: note 7 days of icon C numbers in Creator Analytics > Acquisition (impressions and click-through, by source: Home, Search).
2. Swap to A for 7 days with ads and thumbnails unchanged. Then B for 7 days only if A is not clearly better.
3. Decide on Home + Search CTR. Ignore days with a publish or an ad change.

At today's traffic this is directional, not statistical; the ad test in section 4 gives the cleaner signal on the same art.

## 3. Thumbnails (1920 × 1080, 7 frames)

Same system as v2: cut-out subjects on one sky colour, sticker rim, one light burst, title top left in the icon D wordmark style, two short lines, nothing important in the bottom 15%, POCKET PALS pill on frames 2 to 7. Under 3 MB each.

| # | Headline | Subject | Real capture needed | Reuse |
|---|---|---|---|---|
| 1 | **POCKET PALS** / pill: MERGE · HATCH · TRAIN YOUR PET | Deck mid-chain with the merge popping out, white Bear and dyed Bunny in front, the gem-belt Stat Egg cracking with a Snack rising out, two stat icons. Pink dusk sky. | Deck frozen on a ×3+ chain **in the v2 Toy Shell look** (LCD trays and HUD tabs changed, so the ad-v1 and v2 deck plates are out of date); Bear and Bunny cut-outs; 3D Stat Egg in hatch pose; a Snack with topper | v2 frame 1 layout; StarToken layers |
| 2 | **TRAIN** / **YOUR PET** | Bear cheering beside six large stat tiles lifted from the stats panel (icons, level numbers, one bar mid-fill), "Total level" chip. Gold sky. | Stats panel, desktop, a named pet at total level about 60 to 120 with uneven stats, over black and white for matting; Bear in the cheer beat | None |
| 3 | **HATCH** / **TASTY SNACKS** | Stat Egg open on the Pop-Out stage well; Nibble, Snack and Feast fanned out with their toppers; a Bear mid-bite. Lime Soda green. | Pop-Out stage frames (Uncommon burst); the three snack sizes as 3D cut-outs; the feed bite and happy wiggle beat | None (toy and jar layers are not used) |
| 4 | **MEET** / **THE BUNNY** | Three Bunnies: white with Flower Crown, Rose with Specs, Tide with Sun Hat; ears up, down, and tipped under the hat. Small line under the title: "Collect 7 daily stamps or adopt with Stars" (true, and it stops the frame reading as a paid pet). Teal sky. | Three client-only Bunny rigs, catalogue colours and wearables, wave / sit / hop beats, grey-backdrop matte | None |
| 5 | **RARE!** / **BIG HATCH MOMENTS** | One real frame of the Rare stamp on the Pop-Out stage: Berry Blast, rainbow edge, confetti cannons, a Feast, the game's own RARE! stamp. Shown nearly as captured (16:9 crop, light grade) so it is unmistakably real. | A live Stat Egg hatch landing a Feast at the stamp beat (about 2.3 s), desktop 16:9, plus a spare 0.4 s later | None |
| 6 | **MERGE** / **BIG CHAINS** | Deck on a ×3 to ×5 chain, gems bursting out, Stars, the Bunny cheering this time. Indigo sky. | New deck freeze in the Toy Shell look (Sorbet Sky + Gems or Night Orb + Kittens), ideally ×4 | v2 frame 4 layout; replaces it |
| 7 | **DRESS UP** / **YOUR PALS** | Six pets: four Bears and two Bunnies, six colours, finishes and outfits. Sky blue as now. | Two dressed Bunnies; re-shoot Bears only if the live Bear differs from the 19 Nov cut-outs | Four Bear cut-outs from v2 frame 3, if still accurate |

**Order:** 1, 2, 3, 4, 5, 6, 7. The lead keeps the ad's promise; 2 and 3 are the two things the v1 page could not say. **Home personalization:** activate 1, 2, 4 and 7 (Roblox needs 2 to 5 active and reports impressions, qualified plays and qualified play-through rate per thumbnail).

**Retired:** v2 frames 2 (hatch surprise eggs: toys and jars are now the smaller story), 5 (play with friends: clones, weak read) and 6 (customize your deck). Keep 5 and 6 as spares; "friends" should wait for a real two-account capture.

## 4. Ad campaign

**What Roblox offers (Ads Manager docs, read 21 Nov 2026):** an experience campaign shows as a sponsored tile on Home and in search results, using **16:9 thumbnails, up to 10 per campaign, spread evenly across players**, each switchable on or off. Auto-bid only; daily or lifetime budget; objectives **Plays**, **Earnings (limited)** and **Qualify for Kids and Select**; goal and audience are locked after launch. That page describes no video creative for these campaigns, so video is for the store page and off-platform. Ad images are moderated (about 24 h) under the same "must be in the game" rules.

**Creatives (all 1920 × 1080, checked at 480 × 270):**

| | Creative | Copy on image | What it tests |
|---|---|---|---|
| **A** | Lead thumbnail 1 as is | POCKET PALS · MERGE · HATCH · TRAIN YOUR PET | The whole game (control; equals the page) |
| **B** | "Two Pals": Bear and Bunny huge, deck small behind, one Star | POCKET PALS · YOUR POCKET PETS | Pet first: does a face beat a feature list? |
| **C** | "Snack": Bear mid-bite on a Snack, three stat icons popping, the level-up line as the game shows it | POCKET PALS · FEED · TRAIN · LEVEL UP | The new v2 loop on its own |

Whichever wins becomes the page's lead thumbnail (the "promise matched" rule), so B and C are built as full thumbnails, not ad-only art.

**Test plan (ranges only; the amount is Spencer's call):**
- **One campaign, three thumbnails, even rotation**, objective Plays, all devices, same audience as test 1 so results compare. 5 to 7 days. Total between **$35 and $105** ($5 to $15 a day). The low end gives each creative about a third of the first test's volume, so expect a direction, not proof.
- **Decide on, in order:** (1) play-through, plays ÷ clicks per creative (it was about 10%; the aim is to at least double it); (2) cost per play; (3) CTR against the 0.8% baseline; (4) D1 retention and average playtime of ad-acquired players, so a clickbait creative cannot win.
- **Store page lift:** compare the page's play-through from non-ad sources for the 7 days before and after the new thumbnails go up.
- **Rule:** switch off a creative under half the leader's play-through after about 150 clicks. If nothing beats 15% play-through, stop spending and look at the page and the first minute of play instead.
- **Optional second step (question 3):** a separate small campaign on **Qualify for Kids and Select** if the game is still limited to 16+ accounts, since that gate caps the audience for a kids' game.

**Creator Analytics to record daily (one sheet):** Sponsored impressions, clicks, spend and plays per creative; Acquisition by source (Home, Search, Sponsored, share links); the Thumbnail Performance table (impressions, qualified plays, qualified play-through, winning segment); icon CTR; D1/D7 and playtime for new users; Audience Reach / highly engaged player count; first hatch and first Stat Egg funnel steps if those events exist.

**Video (real gameplay only).** Two cuts from one recording session.

*H1: store-page video, 16:9, about 30 s, game SFX and the game's own lyric-free music, no voice.* Roblox allows 3 uploads a month and rejects count.

| Beat | Seconds | Shot | Overlay (sparing) |
|---|---|---|---|
| 1 | 0 to 4 | Deck mid-round: two drops, a ×3 chain, shake | Merge on your Pocket Deck |
| 2 | 4 to 7 | Results Star and the Stats strip ticking XP | none |
| 3 | 7 to 13 | Stat Egg on the Pop-Out stage: wobble, crack, burst, snack card | Hatch snacks |
| 4 | 13 to 17 | Feeding in the stats panel: bite, happy wiggle, icon burst | none |
| 5 | 17 to 21 | Stats panel: a bar fills, level-up line | Train six stats |
| 6 | 21 to 25 | The Bunny's arrival hatch, RARE! stamp, then Bear and Bunny in the garden | Meet the Bunny |
| 7 | 25 to 28 | Naming screen: a name locks in, name on the petting card | Name your pal |
| 8 | 28 to 31 | Dressed Bear and Bunny at dusk, slow push, wordmark | Pocket Pals |

*V1: vertical 9:16, 12 to 14 s, for TikTok / Shorts / Reels.* Opens on the action, game name fixed top left, one text line per beat.

| Beat | Seconds | Shot |
|---|---|---|
| 1 | 0 to 2 | Chain ×3 landing, already moving on frame 1 |
| 2 | 2 to 6 | Stat Egg wobble, crack, snack pops out |
| 3 | 6 to 9 | Pet eats it, wiggle |
| 4 | 9 to 12 | Stat bar fills, level up |
| 5 | 12 to 14 | Bear and Bunny look at camera, name card |

*V2 (8 to 10 s):* the Bunny's Rare arrival hatch uncut, ending on its face. Off-platform posts keep the playbook's rules: aim at 16+ viewers while the gate stands, no "ask your parents", commercial-content toggle on.

## 5. Capture plan

**Who:** Opus stages and captures in Studio (Play in the **beta place** 107705084891479 or an in-memory save in the dev window; nothing saved or published; no `src/` edits; fixtures stay client-side and are removed). Fable writes the per-shot sheet, composes in new `build_v3.py` / `compose_v3.py` scripts beside the v2 ones, and reviews every frame at 480 × 270 and 150 px. Spencer records the video (an account without passes, or Studio + OBS) and does every upload.

| # | Capture | Notes |
|---|---|---|
| C1 | **Fixture save**: Bear and Bunny owned and named, Stars for eggs, total level about 60 to 120 with uneven stats, one snack of each size in the pouch | Studio test grants only. Record the exact values in the build README so the numbers are defensible. |
| C2 | **Dressed Bear** cut-outs: white + Pom Beanie + Bell Collar (cheer, hug-ball, mid-bite); the four v2 colours again only if the live Bear changed | Grey Neon backdrop pairs, blinking off, forced `PetIdleBeats`, as in v2 |
| C3 | **Dressed Bunny** cut-outs: white + Flower Crown, Rose + Specs, Tide + Sun Hat; wave, sit, hop, cheer; ears up and tipped | Same method. Check ear clipping under full hats (the review found a fixture clip). |
| C4 | **Deck freezes** in the Toy Shell look: a ×3+ for the lead and a ×4 for frame 6, black and white pairs | `DeckNetHarness` and the chain-freeze clone method in the ad-v1 README |
| C5 | **3D Stat Egg**: intact and in hatch pose (gem-belt shell lifted over the core), grey pairs | `Shared.EggModels` path, as ad-v1 r2 |
| C6 | **Snacks**: Nibble, Snack and Feast as 3D cut-outs, six toppers | From the hatch stage or the pouch preview |
| C7 | **Pop-Out stage frames**, native 16:9 desktop: an Uncommon burst and a **Feast at the RARE! stamp** | Live hatches, not the 844 × 390 review fixtures. The Feast may take up to 8 eggs and the nest allows 3 a day; if the fixture lifts that limit in Studio, say so in the README. |
| C8 | **Stats panel**, desktop, black and white pairs; plus the feed bite and wiggle beats | Pet name short and friendly, from the curated list |
| C9 | **Bunny arrival** Rare hatch at the stamp (video beat 6 and a spare still) | Plays once per save: needs `petArrived` unset |
| C10 | **Garden pair**: dressed Bear and Bunny at dusk, GUIs hidden, FOV 35 | Video end card and creative B's background |
| C11 | **Video takes** for H1, V1 and V2: 1920 × 1080 at 60 fps and a 9:16 pass | Spencer; Opus can pre-stage the save |

Capture at the widest Studio viewport available (v2 lost sharpness at 1649 × 734).

## 6. Effort, order, questions

| Piece | Effort | Who |
|---|---|---|
| Shot sheet for C1 to C10 | S | Fable |
| Studio captures C1 to C10 | M | Opus |
| Icon A and challenger B | S | Fable |
| Thumbnails 1 to 7 | L | Fable |
| Ad creatives B and C (A is thumbnail 1) | S | Fable |
| Video H1, V1, V2: record and edit | M | Spencer, from Fable's cut list |
| Listing text for v2 (hook, description) | S | Fable drafts, Spencer pastes |
| Campaign setup, tracking sheet, daily read-out | S | Opus, after Spencer approves the spend |

**Order:** approve this scope > shot sheet > captures > icon and lead thumbnail first (Spencer picks) > remaining thumbnails and ad creatives > Spencer uploads the page art > 2 quiet days for a page baseline > ad test, 5 to 7 days > switch the lead to the winner > icon swap test > video.

**Questions for Spencer (my recommendation in bold):**
1. Icon: Two Pals (A), Snack Time (B) or Rare Hatch (C)? **A, with B built as the challenger.**
2. Ad budget and length? **$10 a day for 7 days ($70), the middle of the $35 to $105 range. Your call; nothing is spent until you give the number.**
3. Is the game still limited to 16+ accounts, and what is the highly engaged player count? **If still gated, add a second small campaign on "Qualify for Kids and Select" after the creative test, not instead of it.**
4. May the page lead with "Train your pet" and move dress-up to frame 7? **Yes: it is what v2 added, and dress-up still gets a full frame.**
5. Video now or after the stills? **After. Stills decide the ad test, and the 3-a-month upload limit is better spent once the cut matches the winning creative.**
6. OK for Opus to look (read-only) in Creator Hub for an icon or thumbnail experiment tool and the first campaign's final numbers? **Yes: it changes how we test and gives the real baseline.**
7. Show the RARE! Feast frame (thumbnail 5)? **Yes, as one clearly real frame in slot 5, never in the lead or the ad.** Say no to keep rare outcomes off the page entirely.
8. Rewrite the hook and description for v2 in the same pass? **Yes: the live text still says "your plush Bear" and has no stats, snacks or Bunny.**
9. The Bear v2 "cute" restyle is still waiting on you. **If it will ship in v3, say so now: I would hold the icon's Bear and frame 7 until it is live rather than shoot twice.**
10. Seven thumbnails, or pad to ten with the old friends and deck frames? **Seven. Weak frames lower the average.**

**Not verified:** whether Creator Hub has an icon experiment (the docs show none); whether Ads Manager accepts video for experience campaigns (the docs page describes thumbnails only); the first campaign's final CTR and play-through since the v2 page went up; current Kids and Select status. Sources, read 21 Nov 2026: Roblox Creator docs for [Ads Manager](https://create.roblox.com/docs/production/promotion/ads-manager), [Thumbnails](https://create.roblox.com/docs/production/publishing/thumbnails) and [Icons](https://create.roblox.com/docs/production/publishing/experience-icons).
