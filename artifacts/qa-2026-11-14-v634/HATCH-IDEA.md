# Hatch idea to show before implementation

2026-11-14 · **CONCEPT ONLY / USER REVIEW REQUIRED BEFORE PRODUCTION HATCH REDO**. Sol may create an isolated Blender storyboard/animatic and mock receipt UI now. Do not edit production HatchCinematic/HatchReveal/receipt routing to install this idea until Spencer has seen and approved it. Other QA repairs continue independently. Sources: actual QA **14:36:49**, **14:44:48**, **14:59:47** and `notes.md`.

## The idea: the egg-shop display comes alive

Carry the actual patterned, glossy 3D egg out of the store preview into a soft dark-teal display stage. It rocks, cracks and opens; the Bear scrambles out, realizes someone is watching, and celebrates with a little hop and wave. The pet carries the moment. Replace the current black/gold diagonal banner, static hovering Bear and unrelated flat item dialog with one quiet curved stage and animated object.

**Concept canvas:** 812×354 phone first; desktop uses same proportions with extra breathing room. Upper safe band reserved for Roblox controls/notification rail. Stage left 58%, name/facts/actions right42%; before opening, egg centered in stage. Curved dark-teal backdrop `#132F31`, floor `#254544`, one warm cream oval pool of light, mint soft rim, peach accent only in the header. No hard cone spotlight, rotating sunburst or full-screen white flash. Show true materials/textures, including the user's current Bear look where relevant. A soft oval shadow grounds every object.

**Camera:** fixed perspective 38° lens-equivalent field of view, target at 55% of model height, camera about 3.6 model-heights away and 8° above horizontal. Egg fills ~55% of usable stage height. Bear reveal uses the same lens; frame its full body with 10% headroom. At the crack only, optional 6% dolly over300ms, never camera shake. Do not cut to an unrelated front portrait after the hatch. Existing drag-to-turn becomes available once settled; it pauses idle posing while held.

## First pet storyboard, 4.6 seconds before settled controls

| Time | Picture and pose | Sound |
|---|---|---|
| 0.00–0.35 | Store preview egg remains correctly textured as surrounding UI fades into stage; egg settles onto shadow with 3% vertical squash and rebounds once. No grey loading mesh. | Soft wooden tap, short air puff. Garden music ducks6dB. |
| 0.35–1.10 | Two curious rocks: yaw−8°/+11°, roll−6°/+7°, with unequal pauses. Shell speckles and pattern stay attached to its surface. | Two rounded knocks with a quiet plucked F5 then A5 answer. |
| 1.10–1.75 | One visible zigzag crack grows across the authored seam; egg leans toward the viewer then gathers itself (5% squash). Warm light leaks only through the opening. | Crisp soft shell tick; rising C6 pickup, no loud glass smash. |
| 1.75–2.10 | Cap lifts and tips aside; lower shell opens into two grounded pieces. Small6–10 peach/cream paper specks rise and fall in the stage only. Bear ears/head peek; eyes blink, hands reach shell rim. | Short bright original F6 chord/pluck, soft pop. |
| 2.10–2.70 | Bear pushes up with both hands, steps out, lands on feet; head lags then catches up. Arms spread, open happy expression. Respect rig limits; no stretched body mesh. | Soft two-foot pat and friendly synthesized coo. |
| 2.70–3.45 | Bear looks at camera, crouches (body down8%, head down3%), hops ~.12 body-heights, lands, then a smaller happy bounce. Hands lift on jump; happy eyes on landing. | Two tiny bell accents A5/C6; not a second reward fanfare. |
| 3.45–4.10 | One hand waves twice; head tilt8° toward raised hand. Shell pieces fade behind, shadow stays. Name appears on right with small “Your first friend”/“New friend” label. | Warm short held F-major6 voicing, no voice line. |
| 4.10–4.60 | Bear settles into breathing/blink idle; actions fade in. Later, sparse head-tilt or happy hand lift, not constant bouncing. | Duck releases over600ms. |

For a first Bear: one primary **Meet Bear** action, existing close/back behavior only where required for escape/recovery. Subsequent pet reveal may show **Meet [name]** and **Back**. Buttons remain stable once shown. Reduced Motion: three clear shell/peek/reveal poses with short dissolves, no dolly, flying confetti or hops; keep expressive face and a single small wave if allowed by setting semantics. Skip animation reaches the settled confirmed receipt, never skips server persistence.

## Non-pet reveals use the same stage, with meaningful object motion

Same patterned egg and opening at0–2.1s, then **one short demonstration** of the awarded item, name/facts/actions settled by3.5s. No generic large card thumbnail as the sole reveal.

- **Toy:** actual 3D toy emerges and performs its identity: ball bounces twice; bone gently turns and lands; sparkler does one restrained spark; wobble top spins, leans and rights itself. Small Bear at the stage edge watches and claps once; it does not obscure the toy. Buttons **Use now** / **Keep** (or existing semantics with clear copy); owning one Bear should not ask “Choose a pet” unnecessarily.
- **Hue/material:** Bear appears behind the cracked egg and turns three-quarter; awarded hue/finish resolves over250ms. One soft light sweep demonstrates gloss vs matte. Caption explicitly says “Preview” until equipped. **Use now** / **Keep**. Do not falsely imply application before confirmed equip.
- **Feature/wearable/charm:** preview the actual effect on Bear, medium-close enough to see it; head turns ±15° once or hand gestures toward it. Keep full item name and truthful slot. Avoid a blinding full-screen glitter layer.
- **Duplicate:** same honest object identity, brief softer flourish, then exact duplicate compensation from receipt. Never pretend it is new or use a long rare fanfare to obscure a duplicate.

Rarity affects **accent length and a small ring of particles**, not frame layout or the amount of screen covered: common two-note 250ms chime/6 specks; rare four-note600ms/10 specks; highest currently supported rarity one900ms chord flourish/16 specks. Reuse our original F-major motif from music brief. No new rarity claims, odds changes or near-miss roulette. Existing volume/mute remains authority.

## What to show Spencer now

Create a single concept contact sheet (six timed frames: store match, rock, crack, Bear peek, hop/wave, settled receipt), plus a **~6s Bear animatic** and **~4s Wobble Top animatic** using existing model/material assets and procedural stage. Label all **concept, not live game**. Include one actual-size812×354 composite, controls and topbar reserved area. Preview audio can use synthesized temporary cues from the music brief. Astra critiques actual frames before presenting; Spencer reviews the idea before production installation. Do not implement the production redesign merely because a mockup looks plausible.
