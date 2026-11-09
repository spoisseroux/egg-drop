# The five new Sprout Hollow babies

[Five-asset manifest](five-asset-manifest.json) · [Front, profile and expression studies](five-babies-gallery.png) · [Six expressions per baby](five-babies-expressions.png) · [Independent color channels](five-babies-hue-study.png) · [Journal icons](journal-portraits.png) · [Clean FBX re-import checks](fbx-verification.json)

The editable Blender scene contains all five families. Each FBX contains exactly one baby at its own ground origin, including an alternate O-mouth and a secondary-colored Dot. Expression morphs accompany the imported meshes; the runtime can pose named semantic pieces independently. The gallery depicts Blender renders. Roblox Studio import, asset permission, runtime shape selection, animation and lighting are separate checks.

| Display | Stable saved ID | Import template | Separate meshes | Triangles | Approximate native Parts |
|---|---|---|---:|---:|---:|
| Tikket | `wick` | `tikket` | 19 | 6,108 | 27 |
| Nuum | `orbit` | `nuum` | 16 | 4,988 | 22 |
| Vezzi | `bloom_pip` | `vezzi` | 19 | 6,332 | 24 |
| Kiprik | `foxfire_wick` | `kiprik` | 20 | 6,732 | 28 |
| Nolli | `eclipse_orbit` | `nolli` | 17 | 5,848 | 25 |

Use each per-family mesh manifest to map Studio object names and roles. Every mesh has one material and a `PigmentUV` layer. Native recipes use game coordinates, +Y up, +Z front and soles at Y=0. Apply the existing FBX template front conversion once. The world renderer's 0.72 scale multiplied by each native scale factor reproduces authored stud dimensions. Journal pixel maps use the previous 13×13 symbol set. New public names resolve from the same permanent saved IDs.

`fallbackParts` is optional. Each component has `shape`, `center`, `size` and `xyzEulerDeg`. Centers and sizes are fractions of the parent semantic piece dimensions, before the child's rotation. Transform the parent, translate by componentwise center × scaled parent size, then apply local XYZ rotation. Set the final component size to componentwise size × scaled parent size. Components retain the source piece's channel and color role. Eyes, mouth, teeth, glints and blush have independent protected roles. The Dot and alternate mouth affect bounds only when visibly active.

Rebuild renders with Blender 5.1's background mode, `--factory-startup --python author_pet_sculptures.py -- --all`. Use `--refresh nolli` to update a single family and reassemble the Blender lineup; `--pet tikket` isolates the first family. Run `compose_pet_gallery.py --all` using Pillow to assemble the render sheets. The sculpt source contains the neutral anatomy, face keys, studio light/material setup and hue variants. Re-exported FBX files can have different headers; use the hashes in the current package manifest when verifying an import.
