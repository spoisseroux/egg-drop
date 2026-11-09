# Garden baby asset workflow

Import `zivvi.fbx` and `ovelle.fbx` using the hashes in `softening-import.json`. The revised templates contain 16 and 15 semantic meshes respectively. The two v225 `garden-material-splits` files are historical. All current pieces carry one material per mesh. Apply the canonical role from each family's mesh manifest when Studio imports a monochrome mesh. Use the paw-relative center and size, including Ovelle's 0.088-stud hover. Preserve the original account IDs `pip` and `puddle`.

`PetAssets.rbxmx` stores the imported MeshParts and Roblox asset references. `default.project.json` mounts the two templates at `ReplicatedStorage.PetAssets`. The template pivot sits at the ground origin. The renderer turns the imported -Z front by Y pi exactly once.

The current XML and repair manifest contain exactly **31 single-material meshes: 16 Zivvi and 15 Ovelle**. Their asset IDs, sizes and local frames come from the actual Studio import in `artifacts/pet-softening-2026-11-08/studio-import-local.json`. Both models retain an identity `PawsOrigin` value. The secondary mitten tips are already separate family-FBX meshes, so no supplemental material patch is needed.

Every imported name, center and size matches Astra's authored manifests within **0.00001 stud** after front-axis conversion. `artifacts/pet-softening-2026-11-08/import-manifest-comparison.json` records each difference. This validates the import data; native mesh-resource validation and actual render review remain separate checks.

Some Rojo live reification paths create a MeshPart without its immutable mesh resource, even though the XML and built place retain the correct asset URI. After the first asset sync or a reconnect, validate the Edit templates before native acceptance or publishing:

1. Load `scripts/RepairPetAssets.lua` as a temporary ModuleScript in Studio Edit mode.
2. Call the returned function with `ReplicatedStorage.PetAssets` and `{validateOnly=true}`. After installing both revised templates, it must report all 31 valid parts.
3. If needed, call with `{limit=8}` until `complete` is true. Each call has at most8 asset creation attempts, skips already-valid parts, applies the resource to the existing named part, preserves its Size/CFrame, and destroys its temporary MeshPart. It performs no uploads.
4. Reconnect Rojo, validate again, and save the verified place. Remove the temporary tool ModuleScript when finished.

This tool is not part of the runtime tree. Runtime rendering performs no asynchronous asset creation: it clones healthy authored templates, or uses the faithful native recipe if any required resource is empty or has zero MeshSize. Both paths retain the same original pet IDs, size conversion, channels, and palette.
