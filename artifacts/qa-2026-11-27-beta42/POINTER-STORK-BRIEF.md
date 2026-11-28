# Pointer, stork and pick-up brief (beta 42 notes 1, 4, 12, 14)

Fable, 2026-11-27. For the Opus implementer. All art is GUI primitives or PNGs we render with our own script; no generated art or audio.

## 1. The lesson pointer (`src/client/TeachPointer.lua`)

### 1a. The ring: concentric with the target, plus a circle ripple
Pure `Pointer.shape(w,h)`:
- `w/h <= 1.35` (round or square-ish: Menu, Deck, Back): **circle**, diameter `max(w,h)+12`, UICorner `(.5,0)`.
- wider (tiles, Hatch free!): a ring `(w+12, h+12)` whose corner is **the target's own UICorner radius + 6** (read it; scale radii resolve against `min(w,h)`; no UICorner: 14). A full capsule would cut the tile's corners; a concentric ring is what reads as "right".
- The circle Spencer asked for shows on every target as the **tap ripple** (1c).

Ring look: two frames, no fill. Under: UIStroke white, 7 px, transparency .35. Over: UIStroke pink `#FF6FA8`, 4 px. Pulse in **px, not scale** (12% of a 600 px tile is the wobble in shot-72): pad 6 to 12 px and back each 1.2 s, cosine. Drop the UIScale. Reduced Motion: still at pad 6.

### 1b. The hand: a white mitten with a pink cuff
It echoes the cuddle mitten on the pet screen (shot-71). Canvas 56 x 64 px, art points **down**, fingertip at (28,64). Rects are `x,y,w,h`:

| Part | Rect | Corner | Fill |
|---|---|---|---|
| Cuff | 13,0,30,12 | 6 | pink `#FF6FA8` |
| Palm | 8,8,40,30 | 14 | white |
| Thumb (Rotation 25) | 41,16,13,20 | 6.5 | white |
| Knuckle L | 9,31,13,13 | 6.5 | white |
| Knuckle R | 34,31,13,13 | 6.5 | white |
| Finger | 20,28,16,36 | 8 | white |
| Palm pad | 23,15,10,10 | 5 | `#FFB3CF` |
| Cuff trim | 13,9,30,3 | 1.5 | `#E0528C` |

**One outline, not per-part strokes** (the stroke crossing the palm is why the current one looks crude). Three layers, no UIStroke:
1. Shadow: every part in ink `#1B2A4A`, transparency .75, offset (0,3).
2. Ink: every part (not pad or trim) in ink, grown 2.5 px each side (corner +2.5).
3. Fill: the table above. White parts get a UIGradient, Rotation 90, `#FFFFFF` to `#E6ECF7`.

Scale: UIScale 1.0; .8 when the viewport is under 500 px tall.

Rotation about the fingertip: a transparent `Holder` 112 x 128, AnchorPoint (.5,.5), positioned at the tip point; the canvas sits in its top half (Position 28,0). Rotate the Holder.

Where it points (pure `Pointer.tip(rect,screen)`):
- round: target centre + `(.2s,.2s)`, `s=min(w,h)`. Wide: `(x+.68w, y+.6h)` (clear of the title and the FREE badge).
- **From below-right** by default: Holder Rotation 150. If the target's bottom is within 80 px of the screen bottom (the Menu button): **from above-left**, Rotation -30, tip mirrored to centre - `(.2s,.2s)`, and the label rises 48 px more.

### 1c. Motion (pure `Pointer.beat(t)`, period 1.2 s, along the hand's own axis)
| t (s) | Hand |
|---|---|
| 0 to .55 | hover 10 px back from the tip point, bob +-2 px (sine) |
| .55 to .70 | dip the 10 px to touch, Quad In |
| .70 to .80 | press: UIScale x .92, ring over-stroke flashes white for 80 ms |
| .80 to 1.0 | lift back, Back Out (3 px overshoot) |
| 1.0 to 1.2 | rest |

**Ripple** at .70: a circle at the tip, pink 3 px stroke, diameter 28 to 76 px, transparency .1 to 1, .45 s, Quad Out. One pooled frame.

### 1d. Moving between targets (note 4: Paint Egg tile, then Hatch free!)
`show()` with a new target while visible:
- Same ScreenGui: the tip **glides** .38 s, Quint Out, on an arc (midpoint lifted 24 px toward screen-up, hand UIScale 1.08 mid-flight, rotation eased if the side flips). Old ring fades in .12 s; new ring pops at .26 s (pad 20 to 6, alpha 0 to 1, .18 s). The beat restarts at t=.55, so it **taps on landing**.
- Other ScreenGui: fade out .12 s, fade in .18 s there.
- First show: slide in 40 px along its axis, fade .2 s.
- The shop sends tile, then Hatch free! when the tile is picked (ring only the current target; shot-72 rings both).

Unchanged: nothing takes input; Reduced Motion shows ring and label only, no glide; gamepad has no hand. Specs: `shape`, `tip`, `beat`.

## 2. The stork (`FirstHatchStory.lua` `aimCamera`, `OnboardV2.lua` `V2.Stork`)

### 2a. Camera
Today: one frame, 13 studs back, FOV 55. The 1.3-stud egg is about 10% of screen height and never read. New `V2.StorkCam`, eye = `land + toPlayer*dist + up - right*side`, blended with smoothstep, same `1-exp(-5dt)` follow:

| Beat | t (s) | dist | up | side | FOV | Look at |
|---|---|---|---|---|---|---|
| Arrive | 0 to 1.1 | 13 | 3.6 | 2.4 | 55 | `land:Lerp(stork,.6)+(0,1.2,0)` |
| Push in | 1.1 to 1.9 | to 5.2 | to 2.2 | 2.4 | to 42 | the bundle's centre |
| Close | 1.9 to release | 5.2 | 2.2 | 2.4 | 42 | the bundle, then the egg on the ground `+(0,.65,0)` |
| Thank you | release to +.75 | 8 | 2.6 | 2.0 | 48 | `land+(0,2.6,0)` (egg and nodding stork both in frame) |
| Hand-off | +.75 to total | to 5 | to 1.6 | to 0 | to 40 | `land+(0,.8,0)` = the crack frame, so `toCrack` has nothing to tween |

- Side 2.4 keeps the push-in clear of the player (standing 6 studs back); check it in a render, raise to 2.8 if a shoulder clips.
- At 5.2 studs and FOV 42 the egg is about 32% of screen height.
- Lengthen the lowering and settle: `hover=3.1, release=3.7, total=5.0` (was 2.8 / 3.3 / 4.6). The egg is close and readable for 1.8 s (1.9 to 3.7), plus the settle rock in frame. `V2.Leave` is release-relative and stays.
- Check in the hang that the egg's top third shows over the blanket rim; if not, open the bundle's mouth .25 stud.
- Reduced Motion: cut straight to the Close frame.

### 2b. Sound: it is wired, the slots are empty
`BoardAudio.StorkIds` has `stork_flap_a/b/c`, `stork_clack`, `blanket_rustle` all `= 0`, and `scripts/synth_asmr.py` has no recipe for them. `stepStork` already plays a flap per wing beat (3 Hz to 1.5 Hz, vol .35), two clacks and the rustle. So: synthesise, upload, fill the ids, and add one cue `stork_coo`.

Usable now from the repo: `AmbientAudio` `bird_chirp_1..6` (uploaded, ours) at PlaybackSpeed .6 as a stand-in coo; `spin_whoosh` / `streak_whoosh` (BoardAudio) at .3 volume, speed 1.4 as a stand-in flap. From outside: Creator Store wing or dove recordings need Spencer's OK per download.

Recipes for `synth_asmr.py` (44.1 kHz mono, peak -6 dBFS, 5 ms fades, using its `grain`, `burst`, `chirp`, `modes`, `resonator`):
- **Flap** (.28 s): (1) air: white noise, band-pass Q 1.2 sweeping 900 to 350 Hz over 180 ms, attack 35 ms raised cosine, decay tau 70 ms, -10 dB; (2) feathers: `grain` 2.5 to 6 kHz, starts 20 ms, attack 8 ms, tau 30 ms, 55 Hz tremolo depth .4, -20 dB; (3) body: sine 95 to 70 Hz, 60 ms, tau 25 ms, -18 dB. b: 1000 to 400 Hz, length x .9. c: 800 to 300 Hz, x 1.1, -3 dB.
- **Coo** (.5 s, "hoo-roo"): sine 520 to 440 Hz over 160 ms, 60 ms gap, 440 to 390 Hz over 220 ms; harmonics 2nd -14 dB, 3rd -24 dB; 28 Hz tremolo depth .35 (the purr); each note attack 30 ms, release 80 ms; breath noise 600 to 1500 Hz at -28 dB; low-pass 2.2 kHz. Play once at `t=S.glide`, vol .4, and at the nod, speed 1.12.
- **Clack** (60 ms; storks really do bill-clatter): `modes` 1100 / 1750 / 2600 Hz, tau 18 / 12 / 8 ms, plus `snap` cut 1500.
- **Rustle** (.45 s): `grain` 3 to 9 kHz, three swells at 0 / 120 / 260 ms, tau 60 ms, -14 dB.

## 3. The pick-up icon (`GardenCareClient.lua` `arrow()` -> `DeckArt.carryArrow`)
It is the old 22 x 24 arrow of 1 px strips on a square cream key. Replace both carry keys:
- **Key**: the round skin the Back key now wears (48 px circle, white, ink edge); `FocusRow` already gives 48 x 48.
- **Icon**: `pickUp` / `setDown` PNGs in the DashIcons style (256 px, transparent, ink `#15143A`, round caps, plus white tintable copies), from `scripts/build_item_icons.py`, ids in `DashIcons.Ids`, shown at 30 x 30:
  - Pal head: filled circle r 46 at (128,112); ears r 18 at (92,74) and (164,74); two eye holes r 7 at (112,110) and (144,110).
  - Cupped hand: an open arc under it, centre (128,150), r 78, 20 to 160 degrees, stroke 22.
  - Lift marks: two short strokes above the ears, (76,34)-(92,50) and (180,34)-(164,50), stroke 14. `setDown`: no marks; a flat ground line (56,236)-(200,236), stroke 14, hand arc r 70.
- Stand-in until uploaded: keep `carryArrow`.
