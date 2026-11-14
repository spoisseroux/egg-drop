# Egg Drop translations (v1 track C)

Written 2026-11-13. This covers what the code now does for Roblox automatic translation, what Spencer has to click in Creator Hub, and what stays in English on purpose.

## How it works

Roblox automatic translation has two parts:

1. **Automatic Text Capture** records the text that players see in the UI.
2. **Automatic translation** machine-translates the captured strings, plus any table entries you upload, into the languages you turn on.

For a player whose Roblox language is not English, each label that has `AutoLocalize` on shows the translated text. The code's job is to mark which labels to translate and to keep the longer translations from being cut off. The code changes:

| Piece | Where |
|---|---|
| Translation rules. Words are translated. Counters (scores, Stars, `n/m`), key caps (A, B, LB, ESC), pet names, the game's name and rich text built from parts are not, so they are never translated and never captured once per value. | `Kit.FixedRoles` / `Kit.fixedText` / `Kit.localizeRich` in `src/client/DeckKit.lua`; call sites in CompanionsHub, HueEggView, HatchCinematic, DeckResults, DeckScreen, QuestLog, DifficultyPicker, BallShop, BookView, init.client |
| Text-fit guard. This applies only to players whose Roblox language or locale is not English, and to the Studio pseudo locale, so English players see no change. A Kit label whose box was sized for its English text gets an ellipsis instead of a hard cut, and wraps when its box has room for two lines. English text that already runs past its box on purpose is left alone. A Kit button's auto-sized label stops at the button's inner width and truncates. | `Kit.guardText`, `Kit.capButtonLabel`, `Kit.translating` / `Kit.setTranslating` in DeckKit |
| Pseudo locale. `UICopy.pseudo` makes a string about 35% longer, with accented letters and `[brackets]`, and keeps `{placeholders}` and `<tags>`. `FeatureFlags.PseudoLocale=true` turns it on for every `UICopy.get`. It works in Studio only; a live server ignores the flag. | `src/shared/UICopy.lua`, `src/shared/FeatureFlags.lua` (keep it `false`) |
| String export: 376 strings, of which 180 are UICopy keys and 196 are catalogue entries (item, ball, faceplate, background, finish, toy, fruit, feature, charm, wearable, round item, quest, store, book and egg names, pitches and descriptions). | `assets/localization/egg-drop-strings.csv`, made by `python scripts/export_localization_csv.py` |
| Review list of 629 strings that are still hard-coded in client UI code. 145 of them are fragments of sentences built by concatenation. | `artifacts/localization/hardcoded-strings.csv` (written by the same script) |
| Fit spec. It builds 13 screens at 1920x1080 and 812x354, swaps every translatable label to its pseudo translation and reports CLIP, GROWS, TRUNC and ENGLISH rows. | `scripts/LocalizationFit.spec.lua` (+ copy in `src/client/ZZSpecs/LocalizationFit.lua`) |

**Run the spec** (Client datamodel, during Play):
```lua
local c=game.Players.LocalPlayer.PlayerScripts.Client
require(c.ZZSpecs.LocalizationFit)(c, game.Players.LocalPlayer.PlayerGui)        -- report only
require(c.ZZSpecs.LocalizationFit)(c, game.Players.LocalPlayer.PlayerGui,{strict=true}) -- fail on any CLIP
```
The report is printed to the output and returned in `.report`. The spec has not been run yet, because this track was done without Studio.

**Re-export the CSV** after you change UICopy or a catalogue: `python scripts/export_localization_csv.py`.

### CSV format

The columns are `Key, Source, Context, Example`, which is the format a Roblox localization table upload accepts.

- **Context is left empty on purpose.** In a Roblox table, Context is an instance path, and an entry that has a Context only applies to that one instance. A descriptive note there would stop the entry from matching anything.
- **Example** says where the string shows, and gives a filled-in example for each string with a `{placeholder}` (for instance `Brave? Medium pays 6 to 8`).
- There is one entry per Source, because Roblox matches captured text on Source. Duplicates are listed as `also <key>`.
- Keys:
  - `ui.<UICopy key>`
  - `catalog.<Module>.<path>`

Translators must keep each `{placeholder}` exactly as it is.

**Strings with values.** Labels showing strings with placeholders (`{count} Stars short`, `Play date {count}/{target}`) render the filled text. Automatic capture records each value it sees as its own string, so the keyed entries in the CSV are there for review and for a later `Translator:FormatByKey` path. Counters with unbounded values (scores, wallet amounts, `BEST n`) are marked not to translate, so they do not flood the table.

## What Spencer clicks in Creator Hub

Creator Hub menu names move around, so use the closest match if a label below differs. You can do all of this before the public launch. Translations apply to private servers too.

1. Go to **create.roblox.com → Creations → Egg Drop** (the experience for place 96451847774961) **→ Localization** in the left navigation. Then open **Settings**:
   - Check that **Source language** is **English**.
   - Turn on **Automatic Text Capture**. This captures the UI strings while people play, including everything that is still hard-coded.
   - Turn on **Use translated content**.
2. Open **Languages** and add these languages, then turn on **Automatic translation** for each one:

   | Language | Code in the table |
   |---|---|
   | Spanish | `es` |
   | Portuguese (Brazil) | `pt` |
   | French | `fr` |
   | German | `de` |
   | Indonesian | `id` |
   | Japanese | `ja` |
   | Korean | `ko` |
   | Thai | `th` |
   | Chinese (Simplified) | `zh-cjv` |
   | Chinese (Traditional) | `zh-tw` |

   They cover most of Roblox's non-English audience. German and French run the longest. Thai, Japanese, Korean and Chinese run shorter than English but need the fallback fonts that Roblox provides automatically.
3. Upload `assets/localization/egg-drop-strings.csv` to the experience's localization table. Do this from the Localization page's table upload, or from Studio: **Plugins → Localization Tools → Tables → Upload CSV** (or the cloud table upload).
   - If the uploader asks whether to **replace** or **update/merge**, choose **merge**, so the strings that capture has already recorded are kept.
   - Automatic translation then fills every language for the uploaded entries.
4. Review the translations, the `ui.` keys first:
   - These are the menu lines.
   - Odds, prices, "Just for looks. Never an advantage." and "No surprises. The odds never change." must stay exact in meaning.
   - Then check the catalogue names.
   - Entries you edit by hand override the machine translation.
5. Optional, and part of track E: under **Localization**, translate the **experience name and description**, and the **pass and developer product names** that appear on Roblox's own purchase prompt. The in-game Store names are already in the CSV.
6. Check the result:
   - Set your Roblox account language to Español and join the private server.
   - Or, in Studio, use **Test → Player Emulator → Locale**.
   - For a fit check without real translations, run the spec above, or set `FeatureFlags.PseudoLocale=true` in Studio only and play.

## What stays English on purpose

- **Pet names**: Bear, Zivvi, Ovelle, Tikket, Nuum, Vezzi, Kiprik, Nolli and the new babies. They are names, so they are not exported, and the labels that show only a name are off:
  - the Companions pane and pet cards
  - the Pets row status
  - the hatch reveal heading
  - the Hue Egg card

  Sentences that contain a name, such as "Bear still thinks you're great.", are still translated as a whole.
- **Numbers**: every `Counter` label is off. This covers scores, Stars, wallet amounts, `n/m` progress, `×chain`, `BEST n` and prices on counters. Three counters that show words opt back in:
  - the ball status (`IN USE`, `Owned`)
  - the book milestone chip
  - the Tidy line on the difficulty cards
- **Key and button caps**: A, B, LB, RB, ESC, MENU and the + glyph, on every `Kit.glyph`.
- **The game's name**: "EGG DROP" on the difficulty picker and on the device shell, and the "PD·01" model stamp.
- **Rich text built from parts**: goal lines with tier circles (for example "Match ● + ● in CENTER") on the HUD and results, and quest titles once "tier IV" has become a circle. A label is translated again as soon as its text has no markup. Plain quest titles such as "Win 2 rounds" are translated.
- **Roman tier numerals** (I to V) inside that markup.

## Clip list

### Measured offline

The line widths come from `scripts/UICopy.spec.lua`. The text was measured with the Roblox Builder Sans and Fredoka One fonts at the pseudo locale's length.

| String | English | Pseudo | Box | Now |
|---|---|---|---|---|
| `hatch.footer.desktop` "Give one a shake. The odds are on the label." | 277 | 383 | 316 | ellipsis (guard) |
| `hatch.egg.toy/hue/material.line`, phone egg row | 91-132 | 119-182 | 116 | ellipsis (already AtEnd) |
| `style.balls.pitch` | 218 | 302 | 288 | ellipsis (already AtEnd) |
| `style.promise.balls` / `.backgrounds`, hint bar | 222 / 235 | 305 / 319 | 300 | ellipsis (guard) |
| `results.nudge.up` "Brave? Medium pays 6 to 8" | 198 | 265 | 212 | ellipsis (guard) |
| `results.leave.mid`, phone Leave button | 117 | 155 | 124 | ellipsis (button cap) |
| `book.title` on the desktop hub tile | 164 | 219 | 216 | ellipsis (already AtEnd) |

Every other line with a known width fits at +35%:
- the hub tile names
- the Hatch eggs promise and phone note
- the results wallet line and desktop Leave button
- the book claim buttons, Records and entry lines
- the shop status and the belt note

So **nothing in the measured set hard-clips any more**. The labels above show an ellipsis in the long languages (mostly German and French).

### Still open

These are not fixed, or not verified:

- **The spec has not been run in Studio.** It is the authority on the 13 screens. Every label it reports as CLIP is outside the guard; TRUNC rows are where the ellipsis lands.
- **Labels the guard does not cover**, because they are not made with `Kit.text` or `Kit.button`:
  - the device shell and readouts made with `Art.text` / `Art.type` in `init.client.lua`
  - the Settings buttons in `DeckPicker`. They are Art TextButtons whose height follows the English text. Track B is editing this file, so it was left alone.
  - the Hatch reveal card buttons in `EggHatchView` (Meet, Get Stars)
  - `PetFocusUI`, `HatchCinematic`, the legacy `DeckMenu`
- **Kit chips** are sized to their English text (for example "2 TO CLAIM", "DONE", "NEW BEST", tier stickers). A longer translation gets an ellipsis inside the chip; the chip does not grow.
- **Fragments**: 145 strings are concatenated, for example `"Use it on "..pet`, `"Hatch "..egg`, `"Tidy stack pays "..n` and `"Locked - "..`. Automatic capture translates the whole rendered sentence, so they work, but:
  - each value is a separate captured string
  - word order cannot change
  - the CSV cannot pre-supply them

  The fix is to move them into UICopy with `{placeholders}`. The full list is in `artifacts/localization/hardcoded-strings.csv`.
- **A `Translator:FormatByKey` path for UICopy strings with values** was not built. It is a follow-up: once the table holds translations, `UICopy.get` could format the keyed entry for the player's locale and mark that label not to translate.
