--!nocheck
-- World finish art: the Studio readback (WORLD-FINISH-ART-BUILD.md). Run with execute_luau in the Pocket Pals Beta place,
-- EDIT mode (InsertService:LoadAsset; nothing is parented, nothing saved). Set SLICE and MODEL to the slice's row in
-- assets/world/world-finish/world-finish-uploads.json ("model.assetId").
--
-- It prints one line "WFREADBACK <json>": {slice, assetId, parts = [{name, meshId, meshSize}]}. Save the JSON part to a
-- file and run, from the repo:
--   python scripts/build_world_finish_pack.py --readback <slice> <file>
-- which records assets/world/world-finish/world-finish-readback-<slice>.json and writes assets/world/WorldFinish.rbxmx
-- and src/server/WorldFinishData.lua (the pack then carries that slice's templates; commit all three).
local SLICE = "den"
local MODEL = 93629425333486

local InsertService = game:GetService("InsertService")
local HttpService = game:GetService("HttpService")
local ok, model = pcall(function() return InsertService:LoadAsset(MODEL) end)
if not ok then error("LoadAsset " .. MODEL .. " failed: " .. tostring(model)) end
local parts = {}
for _, d in ipairs(model:GetDescendants()) do
	if d:IsA("MeshPart") then
		local id = d.MeshId
		if id == "" and d.MeshContent then id = d.MeshContent.Uri or "" end
		table.insert(parts, { name = d.Name, meshId = id, meshSize = { d.MeshSize.X, d.MeshSize.Y, d.MeshSize.Z } })
	end
end
table.sort(parts, function(a, b) return a.name < b.name end)
model:Destroy()
local line = "WFREADBACK " .. HttpService:JSONEncode({ slice = SLICE, assetId = tostring(MODEL), parts = parts })
print(line)
return line
