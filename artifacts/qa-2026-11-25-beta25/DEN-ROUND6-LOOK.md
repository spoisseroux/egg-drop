# Den, cliff path and terrace, art round 6 look (Fable, 2026-11-25)

Answers Spencer's beta (25) notes. Direction only; Opus builds. Original procedural Blender art only. Seen: `audit/AUDIT.md`, captures 01 to 04 (Studio, PC). **Not seen:** a phone frame, the steps close up, the terrace from on top, anything moving. Avatar = 6.4 studs. World stays matte, textured, muted; pets are the bright things.

## 1. The mouth

1. **Clear opening 18 wide x 11 high at the crown, 8.5 at the shoulders** (x -16..2, crown y 15.2): 1.7 avatars tall, five wide. Collision mouth moves with it.
2. **Shape:** a rough arch. Jambs lean in 8 to 10 degrees, crown 1.5 off centre.
3. **The timber door frame goes** (posts, lintel boards, bottom strip). The rock is the frame.
4. **Rock arch:** `W7_F_DenMouth` re-sculpted as two buttresses 4 to 5 thick and one brow overhanging 2.5; collar about 46 x 24, so 6+ of rock over the crown. Opening at least 35% of the collar's width.
5. **Timber as props only:** two raking props 1.0 square on the jambs; one sign board **8 x 2.2** hung on ropes under the brow, bottom edge 9.0 over the floor.
6. **Lanterns:** two, on hooks on the props at 7.5, existing mesh x 1.4. Amber crystals stay at the feet.
7. No marble may show or narrow the 18. Apron widens to x -28..6; its lawn edge stays at z -90.

## 2. Scale pass (per element, no global factor)

| Element | Now | Round 6 |
|---|---|---|
| Den room | 28 x 18.5 | **36 x 24**, grown north into the hill and sideways |
| Den wall top / peak | 6.8 / 11.8 over floor | **10 / 17** (keep 5+ of rock under the terrace, else peak 15) |
| Lanterns | at 8.0, range 14 | floor + 8.5, x 1.4, range 18 |
| Rug, Deck stump, stools, crates, board | greybox | x 1.25, re-spaced |
| Path width | 6 (8 at turn) | **9 (12 at turn)**, widened into the hill |
| Flight steps | rise .75, tread 1.4 | **rise 1.0, tread about 1.7, 9 wide** |
| Path back wall | 3 to 5 | **5 to 8** along the middle 60% |
| Lip stones | 0.8 to 1.8 high | **1.2 to 2.6 high, 2 to 5 long** |
| Rope stakes | 0.35 x 2.6 | **0.5 x 3.4** |
| Arrival notch | check | 10 clear |
| Lookout slab / log bench / tree / outcrops | 7 x 5 / 6 / 14 / 5 | **10 x 7 / 8 / 18 / 7** |
| Top Lawn toy frames | swing bar 5.6 | **x 1.25, bar 7.0**; seats and slots stay pet-sized |

**Must not grow:** the island footprint; garden, plaza and lawn; the terrace floor (76 x 44, y 29) and walls; the Top Lawn circle (13) and fetch radius; the path's route and slope; pets and pet seats.

## 3. Geometry rules

1. **Closed solids:** steps, path wall, terrace face, lip stones, stakes, props, gate: 0 open edges, 0 flipped, normals out. Each flight is one welded stair solid with sides and back, sunk 0.5.
2. **Sheets get skirts:** tread, grass strip, foot, terrace cap turn down 0.6 and end buried.
3. **Den shell:** inward normals; open edges only on the buried skirt and collar. Island rock cut by volume (shell grown 1.5), no partial triangles.
4. **Joins:** weld, or overlap 0.5+ at over 20 degrees. No coplanar faces, no cards.
5. **No shards:** no face under 0.05 square studs, no edge ratio over 8:1, no corner under 10 degrees, no loose island under 12 faces.
6. **Texel density:** 24 px per stud, within 20% of neighbours; rock cells 5 to 7 studs like the island; triplanar, never stretched planar.
7. **Gate to upload:** `mesh-audit.json` at zeros on every FBX, then an orbit from the lawn, each shelf, the turn, the lookout and inside the den.
8. **Budget:** shell 8,000 triangles, path set 8,000, terrace 5,000, race gate 600. One new light.

**Bad spots seen**

- 01: grass flaps floating in the collar (left of the brow, upper right); the brow is two overlapping slabs with a seam; slab cards left of the mouth with mixed cell sizes; floating planks and rope at the path's foot.
- 02: grey and tan shards mid-face under the path; a pale ghost box west of the mouth; the path is one thin stripe; a thumb fin on the skyline.
- 03: the wall right of the path is stacked flat cards with hard edges and jumping cell size; two blank pale triangles; slivers along the wall top; a grass wedge hanging off the terrace lip; no steps readable.
- 04: a rock flap through the dome over the gate; a blocky slab left of the mouth; paw stones still blue-white; the Deck screen pure white.

## 4. The Garden Dash gate

1. **Size:** clear **9 wide x 9 high**, posts 1.0 square, banner top 11, pennant pole to 13.
2. **Silhouette:** two posts, a banner beam with a **checker band 1.4 deep**, one swallow-tail pennant. Nothing else in the den has checks or a flag.
3. **Colour:** matte painted timber. Posts **teal #2F7F8C** with **cream #EFE3C8** bands; checker cream and **charcoal #2E2A28**; pennant **coral #E2603F**. The room's only saturated object.
4. **Light:** seven bulbs under the beam, Neon **#FFD27A**, 0.35 across; one `PointLight` #FFE2A8, brightness 1.2, range 12, no shadows. Dim the Deck screen below the bulbs.
5. **Sign:** board 6 x 1.6 under the beam: the localised "Garden Dash" string and a running-paw icon.
6. **Floor:** checker start mat 9 x 4; paw stones re-laid as a line from the mouth to it.
7. **Placement:** west alcove, facing within 30 degrees of the mouth centre, nothing over 3 high between. From the mouth at 844 x 390 it fills a fifth of the frame height.

## 5. My review checklist (PC and 844 x 390)

**Ship when**

1. CAM-MOUTH30 noon and night: a cave you walk into; two avatars and two pets abreast with headroom; no shed, white, tan or floaters.
2. From the mouth, the gate reads before the Deck screen.
3. CAM-DEN-BACK: nothing through the dome; lamp pools.
4. CAM-FOOT, CAM-SHELF2, CAM-TURN: steps read as steps; two avatars pass; one continuous wall.
5. CAM-HUB: a shadowed notch; toys and tree on the skyline.
6. Audit at zeros; phone p75 no worse than the Hub.

**Fix when**

1. Any back face, hole or sliver from a reachable or garden viewpoint.
2. Cell size jumps between neighbouring rock.
3. The opening reads under 1.5 avatars, or the collar still dwarfs it.
4. The gate reads as furniture, or spills lemon on the walls.
5. Anything grew onto the lawn.
6. A pet stalls or clips on the wider path.
