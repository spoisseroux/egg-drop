--!nocheck
-- World finish art: the Studio readback (WORLD-FINISH-ART-BUILD.md). Run with execute_luau in the Pocket Pals Beta place,
-- EDIT mode (InsertService:LoadAsset; nothing is parented, nothing saved). The models are the slices' rows in
-- assets/world/world-finish/world-finish-uploads.json ("model.assetId").
--
-- It prints one line per slice, "WFREADBACK <slice> <json>" with json = {slice, assetId, parts = [{name, meshId,
-- meshSize}]}. Save each JSON to a file and run, from the repo, once per slice (den first):
--   python scripts/build_world_finish_pack.py --readback <slice> <file>
-- which records assets/world/world-finish/world-finish-readback-<slice>.json and rewrites assets/world/WorldFinish.rbxmx
-- and src/server/WorldFinishData.lua (the pack then carries the bound slices' templates); `--check` must then PASS
-- without a "no Studio readback" note. Commit the three files.
local MODELS = {
	{ slice = "den", id = 122736005677248 },
	{ slice = "path", id = 111136020424731 },
	{ slice = "terrace", id = 127139808708242 },
}

local InsertService = game:GetService("InsertService")
local HttpService = game:GetService("HttpService")
local lines = {}
for _, m in ipairs(MODELS) do
	local ok, model = pcall(function() return InsertService:LoadAsset(m.id) end)
	if not ok then
		table.insert(lines, "WFREADBACK " .. m.slice .. " FAILED " .. tostring(model))
		continue
	end
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
	table.insert(lines, "WFREADBACK " .. m.slice .. " " .. HttpService:JSONEncode({ slice = m.slice, assetId = tostring(m.id), parts = parts }))
end
for _, line in ipairs(lines) do print(line) end
return table.concat(lines, "\n")
