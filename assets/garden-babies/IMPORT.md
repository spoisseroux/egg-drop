# Garden baby asset workflow

The FBX and Blender files are Astra's authored source. `PetAssets.rbxmx` stores the imported, monochrome semantic MeshParts and their Roblox asset references. `default.project.json` mounts this folder at `ReplicatedStorage.PetAssets`. The template pivot is paws-at-zero; the runtime adapter turns the imported -Z front by Y pi exactly once.

Some Rojo live reification paths create a MeshPart without its immutable mesh resource, even though the XML and built place retain the correct asset URI. After the first asset sync or a reconnect, validate the Edit templates before native acceptance or publishing:

1. Load `scripts/RepairPetAssets.lua` as a temporary ModuleScript in Studio Edit mode.
2. Call the returned function with `ReplicatedStorage.PetAssets` and `{validateOnly=true}`. It must report all33 valid parts.
3. If needed, call with `{limit=8}` until `complete` is true. Each call has at most8 asset creation attempts, skips already-valid parts, applies the resource to the existing named part, preserves its Size/CFrame, and destroys its temporary MeshPart. It performs no uploads.
4. Reconnect Rojo, validate again, and save the verified place. Remove the temporary tool ModuleScript when finished.

This tool is not part of the runtime tree. Runtime rendering performs no asynchronous asset creation: it clones healthy authored templates, or uses the faithful native recipe if any required resource is empty or has zero MeshSize. Both paths retain the same original pet IDs, size conversion, channels, and palette.
