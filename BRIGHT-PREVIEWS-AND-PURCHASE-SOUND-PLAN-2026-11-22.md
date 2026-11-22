# Bright pet previews and a Stars purchase sound: plan (Opus, 2026-11-22)

Spencer after the live check: "can we make a cool sound play when we bought stars tho"; "i dont remember seeing +20 stars added"; "the pet previews are a little dark/washed out. can we make them bright in the ui menus across the boards, even on the pocket menu icon thing too?"

## Part 1: bright pet previews

Eight previews share one ViewportFrame light (ambient 206,202,194; light 128,122,110; from 542e760): `CardPreviewCache:57` (cards and headshots), `CompanionsHub:255` (also the stats panel and naming), `HueEggView:124` (180 copies it), `MachineHubArt:307` (Pocket menu tile), `PetInspect:298`, `PetPeek:136`, `WardrobeShop:258` and `:552`.

Measured on the head, live code, 2026-11-22 (`artifacts/bright-previews-2026-11-22/light-candidates.jpg`, round 2 `light-candidates-2.jpg`):

| | NOW | B 245/120 | D 215/200 | E 190/255 |
|---|---|---|---|---|
| white Bear (true 255) | 229,221,212 | 254,253,252 | 254,253,251 | 254,254,254 |
| yellow Bear (true 255,208,75) | 226,180,68 | 253,209,80 | 253,212,83 | 254,223,91 |
| rose Bunny (true 255,120,154) | 226,108,132 | 253,124,157 | 251,129,161 | 252,137,171 |
| shading spread (white Bear / Bunny) | 45 / 36 | 33 / 13 | 38 / 36 | 44 / 41 |
| head clipped to pure white | 0% | 47 to 53% | 46% | 56 to 58% |

1. `Kit.PetLight` (ambient, color, direction) and `Kit.petLight(viewport)` in `DeckKit`, used by all eight. No literals left in those files.
2. Values: Fable's pick. My recommendation is D.
3. Not changed: eggs, jars, snacks, wallet Star, hatch and reveal stages (their own directed light), the garden, the deck tray. `MaterialFinishPreview:142` shows finishes; Fable says whether it joins.

## Part 2: purchase sound and a "+N Stars" you can see

1. New cue `stars_bought` in `BoardAudio` (asset id, `cues` list), made by a numpy script in the repo (no AI audio, no samples from elsewhere), about 1 s, uploaded as an Audio asset.
2. `StoreView:handleResult` calls `onGranted(kind)` for `product` and `pass` results; `init.client` plays the cue. Never for `rejected`, never from `setState`.
3. If the sound is refused when the grant lands (window not focused, voice not loaded), it plays once when Roblox's window closes or the game regains focus, within 10 s, else not at all.
4. A gold "+20 Stars" banner over the tray's stage, at least 24 px tall, held 4 s, restarted when `MarketplaceService.PromptProductPurchaseFinished` fires, because Roblox's "Purchase completed" window covers the page when the grant lands. The status line stays as today. Reduced Motion: no pop, same words.
5. One grant, one sound: a repeated result for the same balance and key within 2 s does not replay it.

## Edge cases

| Case | Behaviour |
|---|---|
| Grant arrives with the store closed | Sound plays; no banner; the wallet already shows it |
| SFX off / device inactive | No sound; banner still shows |
| Late receipt on rejoin | No StoreResult is shown for it today; unchanged |
| Two packs bought quickly | Each plays; the banner shows the latest |
| White pet on the cream headshot disc | Fable checks the contrast; a disc or outline change is hers to call |
| Locked silhouettes (ImageColor black) | Unaffected; spec |

## Test plan

Specs: `PetLight` (all eight use it, no old literals), StoreView (banner, onGranted once, not on rejected), BoardAudio cue present, plus CompanionsHub, MachineHub, UIShellQA, HueEggView, KitSurfaces, HatchEggsList, StarsStoreAccess, WalletStar, ArcadeAudio. Studio: before/after captures of every preview at desktop and phone size with white, dyed, gloss, matte and jelly pets; one free test purchase with the banner and the cue's play count read; whether `PromptProductPurchaseFinished` fires on the client and when. I cannot hear the sound: Spencer and the waveform (length, peak, LUFS) judge it.

## Release

Beta after a code review. Live only on Spencer's word.
