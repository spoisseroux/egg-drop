# Store listing for "Hatch a Handheld Pal" (drafts)

Fable, 25 November 2026. **Nothing here is uploaded, posted or spent.** Spencer sees these first.
Rebuild all art with `python build_v3.py` (extends `../v2-new-look/icons/build_icons.py` and `set/build_set.py`).
Every image is our own Studio cut-outs plus code-drawn type, chips and effects. No AI imagery, no outside assets.

## Why it changes

The diagnosis (`../../growth-2026-11-26/DIAGNOSIS-REPO.md` sections 4 and 5) found the pitch did not fit in five
words, and the store did not show the first minute. All 176 plays came from ads, and about 0.2% of ad impressions
became plays (`CREATOR-HUB-2026-11-25.md`). 98% of players who start reach the Bear, so the hatch is the proven
moment. The store now leads with it: **merge balls on the handheld, the Bear hatches, raise it in the garden.**

## Before and after

| Asset | Live now | Draft | Why |
|---|---|---|---|
| Name | Pocket Pals: Pet Garden | Hatch a Handheld Pal (Spencer's pick) | The name states the verb and the object. |
| First line | "Pocket Pals is a cozy merge game with cute pets to raise..." (155 chars) | "Hatch a pal on your handheld, then raise it in the garden. Merge balls on your Pocket Deck and your first pal, the Bear, cracks out of its egg." (143) | Hook first. The verb lands in three words. |
| Description | 869 chars, a feature list | `DESCRIPTION.txt`, 835 chars: first minute, every day, fair play | Matches the live first session (Welcome bonus, say hi, first toy, tomorrow's stamp and quests). Fair-play lines are unchanged. |
| Icon | `icon-J.png`: Bear and Bunny, deck in the corner, "pocket pals" wordmark | `icon-K.png`: the Bear popping out of a cracked egg on the Pocket Deck's screen. **No text.** | The old wordmark is the old name. The new name is 20 characters and can't be read at 150 px, so the icon is a picture of the name. |
| Thumbnail 1 | `T1-pocket-pals`: wordmark, four verbs, six chips | `T1-hatch-a-handheld-pal.png`: the name, the same hatch, three numbered chips (**play your handheld**, hatch your pal, raise it in the garden), and on the left three dressed pals, a Feast snack, a Stat Egg, a Customization Egg, toys and dye jars | A hook, then the first minute in order, then what you get after it. Round 2 (Spencer: "a bit bare"): chip 1 reworded and the left side filled with real items. |
| Thumbnails 2 to 7 | "pocket pals" corner mark | Same art, corner mark reads "hatch a handheld pal" | Checked pixel for pixel: nothing outside the mark changed, so every printed name, price and count is still the live one. |
| Home Page tile | T1 (old) | New T1 | Same promise on Home as on the page. |
| Ads | ad-A, B, C from v2 (paused, old name on them) | Three new ones, D, E and F, plus B rebuilt as the control. See "The ads". | Each tests one promise: the first minute, the pals, raising. |

## Decisions

- **Icon without text.** Pick `icon-K.png`. It shows the bare white Bear, because that is what a new player hatches.
  `icon-K-beanie.png` keeps the Butter Pom Beanie from icon J (a 40 Star hat) if you want the old face carried over.
  `icons-JK.png` shows J and both K versions at 512, 150 and 50 px.
- **Words.** "balls", "merge" and "hatch" everywhere. "Pocket Deck" stays as the handheld's in-game name.
- **Carousel order follows the first minute:** hatch, merge, eggs, level up, dress up, play, decks.

## What is stylised (so you can judge the honesty)

- The deck's screen in icon K, T1 and ad-D is drawn, the same way icon J's was: Bubbles-theme balls on a pastel
  screen. It is not a real frame.
- The egg is the real Toy Egg capture, split along its own painted crack. The Welcome round's egg on the real
  screen is a flat cream egg. The Bear is the real capture (S3), with the paws from S10.
- The deck wears Cloud Glass (40 Stars), as in the live set. A new player's deck has the default plate.
- Shots H1 and H2 below replace the drawn parts with real ones.

## Found on the way

- **The round HUD still says "EGGS LEFT"** for drops left (`src/client/DeckScreen.lua` lines 1197 to 1421, also
  visible in live T3 and T6). With the store now saying "balls", that label is the last place the two words mix.
  It needs a copy change and a translation sync, then a recapture of the two deck frames.
- "Stamp 7 brings home a Bunny" reads from `UICopy tomorrow.stampPet`. Opus: confirm it holds on live for a save
  without the Bunny before the description goes up. The Welcome bonus line assumes G1 (`StarterBonus`) is live.
- The repo was on `feat/egg-drop-arcade-polish` while I built, not the live line. The pixel check above is what
  shows the retitled frames still carry live values.

## Upload plan (Spencer, after his OK)

| Where in Creator Hub | File | Note |
|---|---|---|
| Basic Settings > Description | `DESCRIPTION.txt` | 835 chars. Paste, then recount in the field. |
| Basic Settings > Name | Hatch a Handheld Pal | If not already changed. Translate the name too. |
| Place > Icon | `icon-K.png` (512 x 512) | Goes through moderation. Keep J until K shows Completed. |
| Thumbnails (detail page), in this order | `T1-hatch-a-handheld-pal`, `T2-merge`, `T3-hatch-eggs`, `T4-level-up`, `T5-dress-up`, `T6-play`, `T7-decks` | Delete the 7 live ones after the new ones are Completed. Record the new ids beside `../v2-new-look/set/live-asset-ids.json`. |
| Home Page thumbnail | `T1-hatch-a-handheld-pal.png` | Single active tile, personalization off (Home impressions are 0, so there is nothing to test yet). |
| Ads Manager | `ad-D-merge-hatch.png` | Not until you say go. See below. |

Ad one-liner (`AD-LINE.txt`, 42 chars): *Merge balls. Hatch a pal on your handheld.*

## The ads

**Is ad D the only ad? No.** Three v2 ads exist in Ads Manager, all paused and all carrying the old name:
ad-A (the old T1 line-up), ad-B ("merge. hatch. repeat.") and ad-C ("make it yours"), in `../v2-new-look/set/`.
The new set is four files here, all 1920 x 1080:

| File | Headline | What it shows | What it tests |
|---|---|---|---|
| `ad-D-merge-hatch.png` | merge balls. hatch a pal. | The real deck frozen mid-merge (Chain ×4), the Bear bursting out of his egg on top of it, balls and toys flying, three dressed pals, a Feast snack and a Stat Egg. Chip: "then raise it in the garden". | The literal first minute. My lead. |
| `ad-E-pals.png` | hatch a pal. make it yours. | The Bear hatching in the middle of six pals in their dyes and outfits, the four dye jars, "hats · outfits · 4 dyes · 6 charms". | Faces and colour against gameplay. |
| `ad-F-raise.png` | raise your pal | The Pet Park, the Bear up front with a Feast snack and the handheld toy, pals on the swing and see-saw, the six stat icons, LEVEL UP. Chip: "feed · train · dress up · play". | What you do after the hatch. |
| `ad-B-control.png` | merge. hatch. repeat. | The old ad B unchanged, corner mark now the new name. | Control: the old look. |

`ads-at-size.png` shows all four at 728, 480, 256 and 150 px wide on dark and light. Headlines read down to 256;
at 150 only the shapes carry it (the Bear in the egg, the row of pals, the park). I did not find Roblox's exact
sponsored tile sizes in the repo, so those four widths are my stand-ins: check on a phone before any spend.

- **Read:** plays ÷ impressions first, then D1 of each cohort. Old baseline: about 0.2% of impressions became plays,
  click-through 0.8 to 1.3%, play-through about 10%.
- **Budget:** four creatives at $5 a day is thin. Either D and E against B first, with F in a second week, or a
  larger daily budget. Your call.
- **Rule:** the winner's image becomes thumbnail 1 and its line the description's first line.
- **Hold:** the diagnosis says keep spend off until a build shows D1 of 4% or more. Any spend needs your explicit go.
- **Honesty notes:** ad D's deck is a real frame, and it still reads "EGGS LEFT" in small print. Ad E shows two
  species (Bear and Bunny) in different dyes and outfits, not seven kinds of pet. Ad F's backdrop is the Pet Park,
  not the garden, so its headline says "raise", not "garden".

## Shot list (Studio, beta place, nothing saved or published)

Same setup as the S-shots in `../v2-new-look/ART-DIRECTION.md`: FOV 35, key light top left, matched backdrop pairs.

| Shot | For | Subject | Camera and pose | Notes |
|---|---|---|---|---|
| H1 | T1, icon K, ad-D | Pocket Deck straight-on, **Welcome round**, the mystery egg at its last crack stage, two or more balls on the board | As S4-straight. Black and white pair. | Replaces the drawn screen. Also one frame on the **default** plate. Shoot after the "EGGS LEFT" copy fix. |
| H2 | Icon K, T1 | Bare white Bear (no hat, Blush only), front-on, **both arms up** (cheer peak), head and chest | Level, as S10. Grey pair, plus a paws-only pair like S10-paws. | Replaces the S3 head and S10 paws composite with one real pose. |
| H3 | A new "raise it in the garden" frame | The Bear in the live garden beside the avatar, the say-hi line and paw prints showing | GUIs hidden except the say-hi line. FOV 40, Bear eye height, day lighting. One wide plate without pets. | No garden plate exists in the Dewdrop captures. It would replace T7-decks. |
| H4 | T2-merge, T7-decks | The two real deck frames again | As D-bigmerge and D-cloud | Only after the HUD says balls. |
| H6 | Ad F, a true garden version | Wide garden plate, day lighting, no pets, no GUIs, camera at pet eye height looking across the lawn to the egg machine | FOV 45. One with and one without the Sleepy Nest. | Lets ad F say "raise it in the garden" over the real garden. |
| H7 | Ad F, ad E | The Bear waving and the Bunny jumping again, **at 2x the old capture size** (subject 1,000 px tall or more) | As A-B1-wave and A-J2-jump | The current ones are about 500 px tall and go soft when they lead a frame. Ad F uses the standing Bear for now. |
| H5 | Video (optional) | 10 s screen recording: three drops, the merge, the egg cracks, the Bear, the garden | Phone-size window, a fresh save, no passes | The first minute as it plays. No voice, game music only. |
