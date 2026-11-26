--!nocheck
-- Round 6: rebuild ServerStorage.WorldBeta (the beta overlay pack, CLIFF-DEN-ISLAND-SCOPE) in Studio EDIT from the
-- uploaded beta FBXs, the way the round-2 pack was built by hand (assets/world/world-beta-native.json note):
--   every CliffDenData.parts entry becomes a MeshPart from its readback mesh (AssetService:CreateMeshPartAsync),
--   precise collision (and CanQuery) where `collide`, Box and no query otherwise;
--   a visual part copies its live template's look (the part it replaces, or a live part of the same material):
--   Material, Color, TextureID, CastShadow, DoubleSided and its SurfaceAppearance;
--   a W7C_ collision tile is invisible (Transparency 1, no shadow, single-sided).
-- Run with execute_luau in Edit (Rojo NOT serving, or it may write the pack back). It runs in a task and reports
-- through _G.WBPACK = {done, built, missing, err}. Nothing is saved; export with the chunk script after.
local VISUAL, COLLISION = 98284784411093, 103168916149306

_G.WBPACK = { done = false, built = 0, missing = {}, err = nil }
task.spawn(function()
	local ok, err = pcall(function()
		local AssetService = game:GetService("AssetService")
		local InsertService = game:GetService("InsertService")
		local SS = game:GetService("ServerStorage")
		local Data = require(game.ReplicatedStorage.Shared.CliffDenData:Clone())
		local live = SS.WorldAssets:FindFirstChild("WorldV7", true)
		assert(live, "no live WorldV7 templates")
		-- readback: the uploaded models' mesh ids by part name
		local meshes = {}
		for _, id in ipairs({ VISUAL, COLLISION }) do
			local model = InsertService:LoadAsset(id)
			for _, d in ipairs(model:GetDescendants()) do
				if d:IsA("MeshPart") then
					local uri = d.MeshId
					if uri == "" and d.MeshContent then uri = d.MeshContent.Uri or "" end
					meshes[d.Name] = uri
				end
			end
			model:Destroy()
		end
		-- the live part each shown part replaces
		local replaces = {}
		for _, pair in ipairs(Data.swap) do
			if pair.show and pair.hide then replaces[pair.show] = pair.hide end
		end
		local function template(name)
			local r = replaces[name]
			if r and live:FindFirstChild(r) then return live:FindFirstChild(r) end
			local mat = string.match(name, "__([%a_]+)") or ""
			mat = string.gsub(mat, "_+$", "")   -- "cliff_rock_1916" matches as "cliff_rock_" (the tile number is digits)
			for _, p in ipairs(live:GetChildren()) do
				if p:IsA("MeshPart") and string.sub(p.Name, -(#mat + 2)) == "__" .. mat then return p end
			end
			return nil
		end
		local out = Instance.new("Model")
		out.Name = "WorldV7"
		local names = {}
		for name in pairs(Data.parts) do table.insert(names, name) end
		table.sort(names)
		for i, name in ipairs(names) do
			local info = Data.parts[name]
			local uri = meshes[name]
			if not uri or uri == "" then
				table.insert(_G.WBPACK.missing, name)
				continue
			end
			local collide = info.collide == true
			local part = AssetService:CreateMeshPartAsync(Content.fromUri(uri), {
				CollisionFidelity = if collide then Enum.CollisionFidelity.PreciseConvexDecomposition else Enum.CollisionFidelity.Box,
			})
			part.Name = name
			part.Anchored = true
			part.Size = Vector3.new(info.size[1], info.size[2], info.size[3])
			part.CFrame = CFrame.new(info.center[1], info.center[2], info.center[3])
			part.CanCollide, part.CanQuery, part.CanTouch = collide, collide, false
			if string.sub(name, 1, 4) == "W7C_" then
				part.Transparency, part.CastShadow, part.DoubleSided = 1, false, false
			else
				local t = template(name)
				if t then
					part.Material, part.Color, part.TextureID = t.Material, t.Color, t.TextureID
					part.CastShadow, part.DoubleSided, part.Transparency = t.CastShadow, t.DoubleSided, t.Transparency
					for _, child in ipairs(t:GetChildren()) do
						if child:IsA("SurfaceAppearance") then child:Clone().Parent = part end
					end
				else
					table.insert(_G.WBPACK.missing, name .. " (no template)")
				end
			end
			part.Parent = out
			_G.WBPACK.built = i
			if i % 10 == 0 then task.wait() end
		end
		local pack = SS:FindFirstChild("WorldBeta")
		assert(pack, "no ServerStorage.WorldBeta")
		local old = pack:FindFirstChild("WorldV7")
		if old then old:Destroy() end
		out.Parent = pack
		pack:SetAttribute("Version", Data.version)
	end)
	_G.WBPACK.err = if ok then nil else tostring(err)
	_G.WBPACK.done = true
end)
return "started"
