# Egg Drop prototype archive

**Current gameplay:** [nectar, field runs and egg hatches](HATCH-LOOP.md).
The descriptions below record earlier prototype iterations, including the
superseded automatic four-pet charge ladder and rare achievement grants.

Pocket Deck is the in-world handheld. Scout is the default, with a
leaf-green shell, orange controls and a pale green LCD.
A player who opens the deck
stays in the lounge as an avatar holding the deck. Nearby players can see
the eggs move on its miniature display. Each player controls their own tray.

Start a new session on the board so the first action can be a drop. The
lounge unlocks after Pip hatches. During the session, the player chooses
when to move between the two views. A returning player starts with a fresh
tray and keeps their unlocked pets, hatch charge, personal best, companion,
trial completion, settings, and equipped deck appearance in a published game.

## How to play

Aim with the left and right buttons and press A to drop, or drag across the
display bar and release. On a keyboard, arrows or A/D aim and Space
drops. Controller D-pad and A use the same controls. Matching tiers merge.
The merge nudges nearby eggs and a quick sequence counts as a chain.
Merges earn points and fill hatch charge for Pip, Puddle, Wick, and Orbit.
After Pip hatches, the LCD shows the next unearned rare pet and your
progress in this round, below the regular hatch meter. Any rare can be
earned as soon as its challenge is met. The Pet Journal lists all three.
Choose **Track & play** on a locked rare to pin it to the LCD and recap
and return to the same tray. The pin stays through retries for the
session and clears when you hatch that pet.

| Rare pet | Challenge |
|---|---|
| Bloom Pip | Score 250 points in one round. |
| Foxfire Wick | Chain five merges. The LCD shows your best chain this round. |
| Eclipse Orbit | Merge two pairs of tier V jellies in one round. Each pair clears from the tray. |
Choose **Meet** to visit the new pet, or **Keep playing** to stay on the
board. **Say hi** plays a greeting and the pet's synth cue. Use **Pet
journal** to choose an owned companion. **Open deck** returns
to the same tray. On the way to Pip, the deck points out the controls
for your input, highlights a matching egg, and shows where merges fill
hatch charge. The guide advances from accepted drops and merges. Pip's
first visit opens with a greeting prompt in Sprout Hollow.

If the save cannot load after retrying, you can play a temporary session.
The notice stays visible while you play, and that session cannot write
to your save. If a write fails after a successful load, the game keeps
retrying and clears the notice when a write succeeds.

| State | What the player sees | What the game does |
|---|---|---|
| Join or respawn | Deck on first join. A respawn restores the current view. | Creates one tray per connection. A new avatar gets the right spawn and grip for its current mode. |
| Aim | Drag rail, next egg, and projected drop line | Shows a local aim preview. |
| Drop | The released egg falls and can bounce off a bank | Server validates aim, cadence, capacity, and spawn space. |
| Impact and merge | Jelly squash, sticky bridge, droplets, synth ticks and pops | Server resolves each pair once. Clients render the feedback. |
| Chain and charge | Rising cue, chain count, and hatch meter | A short window in board time groups consecutive merges. |
| Hatch | Egg cracks, shell flakes fly, and the new pet hops in | The four charge pets hatch in order. Pip opens the lounge. Each rare hatches when its challenge is first completed. |
| Entering Sprout Hollow | The deck LCD closes to a cyan scanline, then the camera pulls back from a mossy nest under the hatchery tree | Server accepts the visit, freezes tray physics and timers, and frees the avatar to move. |
| Sprout Hollow | A garden clearing with a canvas workbench, wooden field journal, creek, and footbridge | Nearby players can see the live tray on each player's horizontal handheld and see companions around the clearing. |
| Return | The room fades and the scanline opens back into the LCD | Restores the prior camera and deck pose and resumes the same eggs, charge, and round. |
| Overflow | Score, personal best, best chain, tier V clears, and progress toward the next hatch | Sustained occupancy above the line or the egg cap ends the round. Any hatches earned on the final move appear before the recap. |
| Try again | One button or Enter to start a fresh tray and drop immediately | Hatch charge, pet collection, best score, and equipment carry over. Rare challenge progress for the finished round starts fresh. |
| Customize | Shell and Sticker tabs with a handheld preview | Equip updates both the board and the held device. Close restores the equipped look. |
| Club | Three replay trials, SFX volume, and motion settings | Regular board play earns trial completions. The server unlocks the Club sticker after all three. |
| Leave | Avatar and deck disappear | Cleans up the session tray. |

## Audio

The board and lounge use original synthesized sound effects. Replacement
music is being auditioned separately. Studio plays the checked-in WAVs
from its local content folder. Published playback needs asset IDs in
`BoardAudio.lua`. Three score auditions and their synth scripts live under
[`assets/concepts/music`](assets/concepts/music). The earlier audition has
Window Seat at 0:00 and Paper Moon at 0:55. Pocket Apricot is a separate draft.

In **Customize → Club**, cycle SFX between Full, Quiet, and Off. Motion Low
removes decorative jelly wobble, moving merge bursts, hatch animation,
the animated lounge handoff, and the lounge greeting camera. Roblox's Reduce Motion setting
also enables this mode. Egg movement, marks, and scoring stay visible.

## Pocket Trials

Chain three merges, score 250 in a round, and merge two tier V jellies.
Each goal can be earned in a different round. The Club tab shows your best
chain in the current round and its score until those goals are earned.
Completed goals survive retries. High Roller also unlocks Bloom Pip in the
Pet Journal. Completing the three Club trials adds the Club sticker to the
Sticker tab. Foxfire Wick and Eclipse Orbit have their own challenges.

Studio verification covered a two-drop triple chain and Pip hatch with
both motion settings, all three trials and all four pets through ordinary
drops, the locked and earned sticker paths, and the trip to the lounge
and back. A sustained overflow fixture verified that retry resets the
round while preserving the best score, collection, and settings. A
profile fixture checked reload and concurrent updates using Studio's
in-memory store. Bloom Pip was verified through regular drops, from a
locked journal entry to its rare hatch and equipped lounge model. A
Studio tray reset preserved the unlock without replaying the reveal.
The Club panel kept 44 px controls in a shortened
landscape viewport. Published saves and physical phone controls remain
to be tested.

## Deck customization

Astra's art direction uses hardware shapes on the deck, sparse blue LCD
pixels in the tray, and dark panels with cyan status and amber rewards.
The original pixel egg mark ties the case and the Club reward together.
Trial goals use graphic badges, progress bars, and written completion.
Each pet has a distinct pixel portrait shared by the journal and hatchery.
The reveal adds a stepped crack, shell chips, and rays. Reduced motion
keeps the same finished composition visible immediately. These graphics
are built into the UI and load without uploaded images.

Choose Stone, Ice, Brick, or Moss from Customize on the board or in the
lounge. Pick Star, Glitch, Seed, or Blank for the front sticker slot.
Hatching Wick unlocks a flame sticker.
The picker previews the front of the handheld. On the board you can also
see changes on the full deck before you equip. The shell and sticker carry
through retry, respawn, and room transitions. Published servers save the
pair in the player profile. Studio uses session memory.

The landscape Pocket Deck has a wide faceplate with a centered LCD, an
aim rocker and utility keys on the left, and A on the right. The avatar's
held deck uses the same layout. On standard portrait screens, Customize
and Lounge stay on the left while A moves below the LCD. The backdrop
covers the full viewport while controls sit inside the Roblox safe area.

## Pixel display and jelly

The LCD draws the tray, guides, eggs, and merge shapes on an 84 × 112
grid. A pixel Pip blinks and reacts to merges next to the next-egg
readout. Hatch charge lights up in separate cells. An impact squashes
the silhouette and sends a ripple around it.
At a merge, two lobes draw together and settle into the larger egg.
The server currently collides circles. Shape-aware squeezing would need
its own physics prototype. Sobosuba's developer describes using a ring
of rigid bodies, skin tension, and pressure to preserve the blob's volume.
[Developer notes](https://www.reddit.com/r/godot/comments/1vlxww3/my_softbody_physics_merging_game/).

Small merges use a quick bubble pop and large merges use a lower squish
with a short crackle. Chains add a quieter rising accent while the
size-specific merge cue still plays. The sounds are synthesized from
scratch, drawing on the different sound textures described by
[PeachyBbies](https://peachybbies.com/pages/pb25-quiz) and
[Snoopslimes](https://snoopslimes.co/blogs/news/snoops-fall-slime-texture-guide-blog).

## Pets

**Pip** is the playable starter. Astra
made it as a cream egg in a broken dark shell with green feet, squared
eyes, blush, and a tilted two-leaf sprig. It breathes, blinks, hops, and
waves. **Puddle** is a low blue gel pet with a droplet tail. It squashes,
hops, waves its tail, and sends out a ripple when greeted. **Wick** and
**Foxfire Wick** greet with two hops and a flick of flame. **Orbit** and
**Eclipse Orbit** float up while their moons sweep around their bodies. The lineup
below is the concept roster. Variant names and colors
are working art directions. [View the 36 pet concepts](assets/concepts/pet-lineup.svg).

| Family | Seed shape and three variants |
|---|---|
| Pip | Egg with a shell hem. Seed has one tilted leaf, Bud has paired leaves, and Bloom wears a pink flower. |
| Puddle | Flat blue gel with a tail. Droplet has a round tail, Ribbon has a sweep, and Crest has a three-point fin. |
| Wick | Warm jelly with a flame. Ember has a curled tip, Flare leans upward, and Crown has three tips. |
| Pebble | Squat egg with a stone cap. Chip has a low slab, Crystal has a blue spike, and Geode has a violet cap. |
| Flutter | Egg with paired fins. Moth has round lobes, Kite has angular tips, and Fan has scalloped edges. |
| Bristle | Egg with a swept tuft. Brush is leafy, Quill has a long lavender point, and Brushfire has uneven coral spikes. |
| Puff | Low egg with a cloud cap. Wisp has a short pale crest, Cloud has a broad blue cap, and Thunderhead has a tall purple cap. |
| Bell | Hanging shell with a clapper. Chime has a curved top, Gong has a flat handle, and Lantern has a bright gold body. |
| Spool | Banded jelly with a trailing strand. Thread has a little bead, Ribbon has a forked tail, and Coil curls back on itself. |
| Reef | Jelly with a branching crown. Twig has a split sprig, Fan has three prongs, and Coral Crown has the broadest branches. |
| Dune | Sand-colored egg with a sail. Drift has one curve, Ridge has a flat crest, and Twin Crest has two peaks. |
| Orbit | Jelly with a tilted ring. Crescent has an open arc, Ring has a full blue loop, and Eclipse has a segmented lilac loop. |

## Verification

The arcade polish was played in Studio using the on-screen controls.
Two drops and three merges hatched Pip. The hint advanced after the first
drop and merge, and the hatch effect cleared before returning to the same
tray from the lounge.
Layout checks covered 320 × 568 and 390 × 844 portrait sizes plus two
landscape sizes, accounting for the Studio top inset.

The customization pass verified in Studio that Cancel restores the
equipped look, Equip updates both the board and held device, and changing
shells in the lounge preserves the same tray on return.

In an earlier multiplayer pass, forged drop and retry requests in the lounge
left the frozen egg positions alone. The two-client Studio run saw another
player's live screen change from four eggs to five on the drop and three
after its chain. A repeated-drop run reached overflow, and clicking retry returned
to four eggs with zero charge and the lounge still unlocked.

Studio verified both hatches, meeting Puddle, switching back to Pip,
and reloading the earned collection from the in-memory profile. A private
published build is needed to verify a leave and rejoin in the Roblox
client, uploaded synth playback, and touch on a phone.
# Phone feedback pass — November 5, 2026

The phone playtest exposed fast collection completion through repeated A presses.
The current seven-pet roster and thresholds are prototype values, not a validated
retention or monetization design. See [the gameplay review brief](GAMEPLAY-HANDOFF.md).
No daily drop gate or payment system has been added.

Scout replaces Sherbet's colors while keeping its saved ID. The interface now
uses botanical forest panels, leaf-green hardware, orange controls and a pale
green LCD. The smooth renderer shares that LCD background when image APIs are
unavailable. Full-screen artwork and modal dimming are separate from safely
inset content. Landscape utility buttons sit above the lower thumb controls.
Hatch text scales within padded bounds. Short screens shrink the pet stage,
keeping 44px buttons. The journal scrolls entries with Close always visible.

Sprout Hollow defaults to a following Roblox camera and a companion beside the
player. Say hi briefly presents the pet closer, then restores free roaming.
Moving, switching modes, respawning or replacing the camera cancels focus.
The compact lounge HUD sits at the top, leaving walking and jumping clear.
The lounge still needs activities beyond greeting and its two menu stations.

The sky follows a real 24-hour clock, shared by clients using server time.
Hollow time is **UTC−5 fixed year-round**, configured by
`HollowClock.TimeZoneOffsetHours`. It is not each player's local timezone and
does not implement daylight saving. Night keeps ambient fill and strengthens
lantern light. Native bloom is subtle. These are supported Roblox lighting and
GUI effects; there is no arbitrary custom GPU shader implementation.

Verification: Rojo build and Luau compilation; real Studio GUI drops, hatch,
Meet, timed camera return, movement with camera/companion follow, and interrupted
greeting-to-deck transition. Layout fixtures exercised 844×300, 667×285,
568×198 and 390×740 safe content areas. Landscape bottom margins measured
30/30/16px, utility-to-arrow gaps 36/26/16px and hatch footer buttons stayed
44px. Foxfire Wick's full title and button text fit at the smallest size.
Journal Close stayed visible at each size and at simulated cutout offsets.
Full-screen dimming covered the complete viewport and safe content origins
matched. Clock samples checked midnight, dawn, noon and evening.
These are Studio checks; fresh physical-phone and live multiplayer tests remain.
