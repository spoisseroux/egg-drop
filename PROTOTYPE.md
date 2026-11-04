# Egg Drop prototype

Pocket Deck is the in-world handheld. A graphite shell with electric blue
and amber accents frames the full-screen merge game. A player who opens it
stays in the lounge as an avatar holding the deck. Nearby players can see
the eggs move on its miniature display. Each player controls their own tray.

Start a new session on the board so the first action can be a drop. The
lounge unlocks after Pip hatches. During the session, the player chooses
when to move between the two views. Once persistent progress exists, a
returning player can be offered their last location and a resume button.
The prototype starts each new connection with a fresh tray.

## How to play

Drag the rail and release to place the next egg. Matching tiers merge.
The merge nudges nearby eggs and a quick sequence counts as a chain.
Merges fill six points of hatch charge. The guaranteed starter reveal
awards Pip for the round. Choose **Meet Pip** to close the deck, or
**Keep playing** to stay on the board. **Greet Pip** plays a bounce, wave,
and two-note cry. **Open deck** returns to the same tray. First-session
hints appear in the footer and advance after an accepted drop and a merge.

| State | What the player sees | What the game does |
|---|---|---|
| Join or respawn | Deck on first join. A respawn restores the current view. | Creates one tray per connection. A new avatar gets the right spawn and grip for its current mode. |
| Aim | Drag rail, next egg, and projected drop line | Shows a local aim preview. |
| Drop | The released egg falls and can bounce off a bank | Server validates aim, cadence, capacity, and spawn space. |
| Impact and merge | Jelly squash, sticky bridge, droplets, synth ticks and pops | Server resolves each pair once. Clients render the feedback. |
| Chain and charge | Rising cue, chain count, and hatch meter | A short window in board time groups consecutive merges. |
| Starter hatch | Egg winds up and cracks, shell flakes fly, and Pip hops in with a chirp in under a second | Unlocks the lounge for the rest of the session. Both choices are available during the reveal. |
| Entering the lounge | Deck shutters close and the music moves into the room arrangement | Server accepts the visit, freezes tray physics and timers, and frees the avatar to move. |
| Lounge | 3D Pip, other avatars, their decks, and a return button | Pip greets locally. Nearby miniature screens project each owner's current egg positions. The server ignores board requests from room mode. |
| Return | Shutters reopen onto the previous tray | Restores the deck pose and resumes the same eggs, charge, and round. |
| Overflow | Tray full card and retry | Sustained occupancy above the line or the egg cap ends the round. Fresh drops get grace. Music quiets. |
| Retry | Four starter eggs and an empty meter | Resets the round. A room unlocked earlier in the session stays available. |
| Music off | The Music button reads off in both views | Mutes both looping arrangements. The original feedback cues still play. |
| Leave | Avatar and deck disappear | Cleans up the session tray. |

## Music

Both original synth arrangements run on the same eight-bar, 84 BPM
progression. The board uses a short triangle-wave melody with a quiet pulse
echo and rests between phrases. The lounge uses a sparser version of the
motif. Both loops run together so their crossfade follows the
same beat. The score ducks during the hatch and stays quieter at overflow.
This local Studio setup uses the checked-in WAVs in its content folder.
Published Roblox playback needs the uploaded asset IDs in BoardAudio.lua.

## Deck customization

Start with four curated presets: Graphite Circuit, Glacier, Lava Relay, and
Forest Expedition. In the lounge, a Customize Deck panel can preview the
front of the handheld and its full-screen frame before applying a preset.
The choice carries across both views, including the device other players
see in your avatar's hands.

Next, let players mix unlocked shells, button caps, screen trim, and one
backplate decal. The board surface, egg colors and marks, hints, and action
contrast stay consistent across all presets. Save catalog IDs in the player
profile and let the server validate what the player owns and equips. Start
with free presets and add earned cosmetics after pet progression is in place.

## Pets

**Pip** is the playable starter and the only 3D pet in this build. Astra
made it as a cream egg in a broken dark shell with green feet, squared
eyes, blush, and a tilted two-leaf sprig. It breathes, blinks, hops, and
waves. The lineup below is the concept roster. Variant names and colors
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

Puddle and Wick are the next two 3D art targets for Astra. Check that the
trio reads at 32 px and from lounge distance before extending the roster.
Keep the body rig reusable and give each family a distinct original synth cry.

## Verification

The arcade polish was played in Studio using the on-screen controls.
Two drops and three merges hatched Pip. The hint advanced after the first
drop and merge, and the hatch effect cleared before returning to the same
tray from the lounge. The music toggle kept its setting across both views.
Layout checks covered 320 × 568 and 390 × 844 portrait sizes plus two
landscape sizes, accounting for the Studio top inset.

In an earlier multiplayer pass, forged drop and retry requests in the lounge
left the frozen egg positions alone. The two-client Studio run saw another
player's live screen change from four eggs to five on the drop and three
after its chain. The two loop assets loaded and switched volume with the
view. A repeated-drop run reached overflow, and clicking retry returned
to four eggs with zero charge and the lounge still unlocked.

The room is a small shared prototype. The final pet art, longer progression,
save behavior, and phone playtest are separate milestones.
