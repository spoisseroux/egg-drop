# Egg Drop prototype

Pocket Deck is the in-world handheld. Stone is the default shell, with
graphite plastic, a cold silver rim, a cyan power light, and an amber drop
button. A player who opens the deck
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
Choose **Meet** to visit the new pet, or **Keep playing** to stay on the
board. **Say hi** plays a greeting and the pet's synth cue. Use **Pet
journal** to choose an owned companion. **Open deck** returns
to the same tray. First-session
hints appear in the footer and advance after an accepted drop and a merge.

| State | What the player sees | What the game does |
|---|---|---|
| Join or respawn | Deck on first join. A respawn restores the current view. | Creates one tray per connection. A new avatar gets the right spawn and grip for its current mode. |
| Aim | Drag rail, next egg, and projected drop line | Shows a local aim preview. |
| Drop | The released egg falls and can bounce off a bank | Server validates aim, cadence, capacity, and spawn space. |
| Impact and merge | Jelly squash, sticky bridge, droplets, synth ticks and pops | Server resolves each pair once. Clients render the feedback. |
| Chain and charge | Rising cue, chain count, and hatch meter | A short window in board time groups consecutive merges. |
| Hatch | Egg cracks, shell flakes fly, and the new pet hops in | The server records the pet. Pip opens the lounge. The other three hatch in order. |
| Entering Sprout Hollow | The deck LCD closes to a cyan scanline, then the camera pulls back from a mossy nest under the hatchery tree | Server accepts the visit, freezes tray physics and timers, and frees the avatar to move. |
| Sprout Hollow | A garden clearing with a canvas workbench, wooden field journal, creek, and footbridge | Nearby players can see the live tray on each player's horizontal handheld and see companions around the clearing. |
| Return | The room fades and the scanline opens back into the LCD | Restores the prior camera and deck pose and resumes the same eggs, charge, and round. |
| Overflow | Round score, personal best, and retry | Sustained occupancy above the line or the egg cap ends the round. Fresh drops get grace. |
| Try again | Four starter eggs and a fresh round score | Hatch charge, pet collection, best score, and equipment carry over. |
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
Completed goals survive retries. The reward appears in the Sticker tab.

Studio verification covered a two-drop triple chain and Pip hatch with
both motion settings, all three trials and all four pets through ordinary
drops, the locked and earned sticker paths, and the trip to the lounge
and back. A sustained overflow fixture verified that retry resets the
round while preserving the best score, collection, and settings. A
profile fixture checked reload and concurrent updates using Studio's
in-memory store. The Club panel kept 44 px controls in a shortened
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

The landscape Pocket Deck has a wide faceplate with a centered LCD,
an aim rocker on the left, an A button on the right, and Customize and
Lounge along the lower edge. The avatar's held deck uses the same layout.
Portrait screens move the main controls below the LCD. Both orientations
use the same tall tray proportions. The backdrop covers the full viewport,
while the controls sit inside the Roblox safe area.

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
hops, waves its tail, and sends out a ripple when greeted. **Wick** is a
pocket flame and **Orbit** is a small moon with a tilted ring. The lineup
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
