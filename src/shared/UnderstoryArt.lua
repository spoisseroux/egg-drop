-- The understory's uploads (GARDEN-B38-BRIEF 4b, P1). Pure data, shared. Every id below is a PLACEHOLDER (nil) until the
-- coordinator uploads the files and writes the returned ids here; while a mesh's id or the atlas is nil, that kind is
-- simply not drawn (UnderstoryClient builds nothing for it, never an error). The blob is optional: without it the
-- bushes stand on the lawn with no shade decal.
--
-- Uploads (Creator Hub / Open Cloud, the place's creator):
--   1. assets/world/understory/understory.fbx     as a 3D Model (Mesh import, one Model, three MeshParts):
--        Understory_B38_Bush, Understory_B38_BushFlower, Understory_B38_Reeds. Read each MeshPart's MeshId back and
--        write it in Meshes[...].id below (rbxassetid://<number>). Keep the file as exported (no rescale on import).
--   2. assets/world/understory/understory-atlas.png as an Image (Decal): its image id -> Atlas.
--   3. assets/world/understory/understory-blob.png  as an Image (Decal): its image id -> Blob.
-- Sizes and centres are scripts/build_understory_meshes.py's manifest (assets/world/understory/understory-manifest.json):
-- Roblox studs, centre = the mesh's bounds centre from the plant's foot (before the import's pi turn about Y).
local Art={}
Art.Atlas="rbxassetid://76727805564009"  -- understory-atlas.png (512 x 512), uploaded 2026-11-27
Art.Blob="rbxassetid://133625189983278"   -- understory-blob.png (64 x 64, alpha), uploaded 2026-11-27
Art.Meshes=table.freeze({
	bush=table.freeze({name="Understory_B38_Bush",id="rbxassetid://102659434093003",tris=320,               -- uploaded 2026-11-27 (model 80017802312689)
		size=Vector3.new(2.963,2.0,3.0),centre=Vector3.new(0,.85,0)}),
	flower=table.freeze({name="Understory_B38_BushFlower",id="rbxassetid://116451634812610",tris=320,       -- uploaded 2026-11-27 (model 80017802312689)
		size=Vector3.new(2.963,2.0,3.0),centre=Vector3.new(0,.85,0)}),
	reeds=table.freeze({name="Understory_B38_Reeds",id="rbxassetid://133148870275248",tris=38,              -- uploaded 2026-11-27 (model 80017802312689)
		size=Vector3.new(1.8683,3.1344,2.0191),centre=Vector3.new(-.0175,1.5172,-.0868)}),
})

local function filled(id)return type(id)=="string"and string.match(id,"^rbxassetid://%d+$")~=nil end
Art.filled=filled
-- A kind is drawn only with its mesh and the atlas both uploaded.
function Art.ready(kind,art)
	art=art or Art
	local mesh=art.Meshes[kind]
	return mesh~=nil and filled(mesh.id)and filled(art.Atlas)
end
return table.freeze(Art)
