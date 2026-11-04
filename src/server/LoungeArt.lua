local Lighting = game:GetService("Lighting")

local Art = {}
local grass = Color3.fromHex("#87A951")
local moss = Color3.fromHex("#6C9047")
local bark = Color3.fromHex("#795035")
local wood = Color3.fromHex("#AE7951")
local stone = Color3.fromHex("#C9BC9A")
local leaf = { Color3.fromHex("#658D43"), Color3.fromHex("#7FA64C"), Color3.fromHex("#97B75B") }

local function sign(parent, title)
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Back
	surface.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	surface.CanvasSize = Vector2.new(520, 100)
	surface.LightInfluence = 0.15
	surface.Parent = parent
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Position = UDim2.fromScale(0.06, 0.1)
	text.Size = UDim2.fromScale(0.88, 0.8)
	text.Text = title
	text.TextScaled = true
	text.Font = Enum.Font.GothamBold
	text.TextColor3 = Color3.fromHex("#FFF0C8")
	text.Parent = surface
end

function Art.build(room, part)
	local random = Random.new(1702)
	local function box(name, x, y, z, w, h, d, tint, collide)
		local piece = part(room, name, Vector3.new(w, h, d), CFrame.new(x, y, z), tint, collide)
		piece.CanTouch = false
		piece.CanQuery = collide == true
		return piece
	end
	local function oval(name, x, y, z, w, h, d, tint)
		local piece = box(name, x, y, z, w, h, d, tint)
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = piece
		return piece
	end
	local function limb(name, a, b, width, tint)
		local center = (a + b) / 2
		local piece = box(name, center.X, center.Y, center.Z, (a - b).Magnitude + width * 0.45, width, width, tint)
		piece.Shape = Enum.PartType.Cylinder
		local up = if math.abs((b - a).Unit.Y) > 0.98 then Vector3.zAxis else Vector3.yAxis
		piece.CFrame = CFrame.lookAt(center, b, up) * CFrame.Angles(0, math.pi / 2, 0)
		return piece
	end
	local function plant(x, y, z, size)
		for index = -1, 1 do
			local frond = oval("Fern", x + index * size * 0.22, y + size * 0.35, z, size * 0.23, size, size * 0.22,
				leaf[index + 2])
			frond.CFrame *= CFrame.Angles(0, 0, -index * 0.56)
		end
	end
	local function flower(x, z, size, tint)
		local y = 4 + size * 0.55
		limb("FlowerStem", Vector3.new(x, 4, z), Vector3.new(x, y, z + 0.035), size * 0.08, moss)
		for i = 1, 5 do
			local theta = i * math.pi * 2 / 5
			oval("Petal", x + math.cos(theta) * size * 0.21, y, z + math.sin(theta) * size * 0.21,
				size * 0.29, size * 0.13, size * 0.29, tint)
		end
		oval("FlowerHeart", x, y + 0.035, z, size * 0.26, size * 0.17, size * 0.26, Color3.fromHex("#E8AB53"))
	end

	Lighting.ClockTime = 15.1
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromHex("#817F71")
	Lighting.OutdoorAmbient = Color3.fromHex("#A3A795")

	box("Floor", 0, 3.5, 0, 44, 1, 35, grass, true)
	box("MeadowGround", 0, 2.85, -24, 400, 0.85, 280, grass)
	for _, side in ipairs({ -1, 1 }) do
		box("GardenBoundary", side * 21.6, 9, 0, 0.6, 10, 35, grass, true).Transparency = 1
		box("GardenBoundary", 0, 9, side * 17.2, 44, 10, 0.6, grass, true).Transparency = 1
	end
	for _, hill in ipairs({
		{ -32, -21, 35, 11, 28 }, { -16, -31, 31, 14, 25 }, { 11, -34, 34, 12, 26 },
		{ 33, -29, 38, 19, 32 }, { 19, -53, 66, 22, 33 }, { -39, -49, 45, 23, 38 },
		{ 33, 2, 29, 12, 33 }, { -31, 0, 29, 8, 31 },
		{ -69, -62, 74, 27, 49 }, { -32, -87, 65, 25, 44 }, { 29, -90, 69, 29, 54 }, { 75, -64, 67, 26, 50 },
	}) do
		oval("MeadowHill", hill[1], 1.5, hill[2], hill[3], hill[4], hill[5],
			if hill[2] < -40 then Color3.fromHex("#7B9E88") else Color3.fromHex("#8DA867"))
	end
	for index = 1, 13 do
		local x = -36 + (index - 1) * 6
		local z = -25 - index % 3 * 4.1
		local y = if math.abs(x) > 22 then 6 else 5
		limb("DistantTrunk", Vector3.new(x, y - 1, z), Vector3.new(x, y + 4, z), 0.72, bark)
		oval("DistantCrown", x, y + 4.2, z, 5.6, 4.6, 4.5, leaf[index % #leaf + 1])
	end

	-- A curved route links the player entrance, nest, and field stations.
	for index, tile in ipairs({
		{ 2.5, 13.3 }, { 1.1, 11.5 }, { -0.4, 9.7 }, { -1.1, 7.8 }, { -0.8, 5.8 },
		{ 0.1, 3.7 }, { 0.7, 1.7 }, { 0.5, -0.5 }, { -0.2, -2.2 },
		{ -3.2, -1.2 }, { -5.7, -2.5 }, { -8.0, -3.5 }, { 3.9, -1.6 },
		{ 6.3, -2.8 }, { 8.8, -3.5 }, { 12.0, -7.5 }, { 13.9, -8.9 }, { 15.3, -9.5 },
	}) do
		local p = oval("SteppingStone", tile[1], 4.026, tile[2], 2.0 + index % 3 * 0.24, 0.13, 1.45, stone)
		p.CFrame *= CFrame.Angles(0, index * 0.67, 0)
	end

	-- The branching tree frames Pip without blocking the hatchery camera.
	local root = Vector3.new(-3.4, 4.05, -10.9)
	local fork = Vector3.new(-3.8, 9.0, -11.0)
	local crown = Vector3.new(-4.1, 13.1, -11.5)
	local trunk = limb("HatchTreeTrunk", root, fork, 2.6, bark)
	trunk.CanCollide, trunk.CanQuery = true, true
	limb("HatchTreeTrunk", fork, crown, 1.95, bark)
	for index, offset in ipairs({ Vector3.new(-2.2, 0, 0.7), Vector3.new(1.9, 0, 1.35), Vector3.new(0.65, 0, -2.3) }) do
		limb("TreeRoot", root + Vector3.new(0, 0.68, 0), root + offset, 0.63, bark)
		oval("RootMoss", root.X + offset.X, 4.16, root.Z + offset.Z, 1.8, 0.33, 1.2, leaf[index])
	end
	for index, branch in ipairs({
		{ -8.2, 12.4, -11.6 }, { 0.5, 12.7, -9.8 }, { 3.8, 13.2, -11.1 },
		{ -6.6, 14.5, -13.6 }, { -1.4, 15.1, -13.8 }, { -3.3, 15.7, -9.4 },
	}) do
		local tip = Vector3.new(branch[1], branch[2], branch[3])
		limb("HatchTreeBranch", if index > 3 then crown else fork, tip, if index == 3 then 0.9 else 1.2, bark)
		oval("Canopy", tip.X, tip.Y + 0.6, tip.Z, 6.9, 3.45, 5.8, leaf[index % #leaf + 1])
		oval("Canopy", tip.X - 0.5, tip.Y + 1.55, tip.Z + 0.65, 4.1, 2.6, 3.95, leaf[(index + 1) % #leaf + 1])
	end
	limb("LanternCord", Vector3.new(0.82, 12.2, -9.6), Vector3.new(0.82, 8.7, -9.6), 0.085, bark)
	box("LanternCap", 0.82, 8.8, -9.6, 0.61, 0.12, 0.61, bark)
	local lantern = box("LanternGlass", 0.82, 8.47, -9.6, 0.47, 0.54, 0.47, Color3.fromHex("#FFC874"))
	lantern.Material = Enum.Material.Neon
	box("LanternBase", 0.82, 8.17, -9.6, 0.60, 0.11, 0.60, bark)

	local nest = box("HatchTop", 0, 4.115, -5, 5.8, 0.23, 4.6, stone, true)
	nest.Transparency = 1
	oval("MossNest", 0, 4.06, -5, 6.2, 0.34, 4.95, moss)
	for index = 1, 12 do
		local theta = index * math.pi / 6
		oval("NestStone", math.cos(theta) * 2.82, 4.15, -5 + math.sin(theta) * 2.11,
			1.05, 0.36, 0.9, stone:Lerp(grass, index % 3 * 0.10))
	end
	for _, x in ipairs({ -1.85, 1.87 }) do
		oval("HatcheryEgg", x, 4.63, -6.06, 0.65, 0.95, 0.59, Color3.fromHex("#EEE0AE"))
	end

	-- Water follows the far edge of the walkable clearing, with a real bridge deck.
	local water = oval("Creek", 18.2, 4.03, -1.5, 7.7, 0.13, 33, Color3.fromHex("#68B6C6"))
	water.Material = Enum.Material.Glass
	water.Transparency = 0.16
	for index = 1, 10 do
		local z = -15.5 + index * 2.65
		local ripple = oval("WaterRipple", 17.8 + math.sin(index * 2.2) * 1.4, 4.105, z, 1.1, 0.012, 0.13,
			Color3.fromHex("#B7E5DA"))
		ripple.Transparency = 0.37
		oval("CreekStone", 15.02 + math.sin(index) * 0.58, 4.18, z, 1.05, 0.5, 0.76, stone)
		if index % 2 == 0 then
			plant(14.45, 4, z + 0.6, 0.85)
		end
	end
	for index = 0, 10 do
		local x = 14.3 + index * 0.64
		box("BridgePlank", x, 4.25, -9.4, 0.62, 0.21, 2.4, if index % 2 == 0 then wood else bark, true)
	end
	for _, z in ipairs({ -10.53, -8.27 }) do
		for _, x in ipairs({ 14.4, 17.6, 20.7 }) do
			box("BridgePost", x, 4.76, z, 0.20, 1.18, 0.20, bark)
		end
		box("BridgeRail", 17.6, 5.13, z, 6.45, 0.13, 0.13, wood)
	end

	for _, station in ipairs({
		{ x = -11, id = "Customize", title = "Deck workbench", action = "Customize" },
		{ x = 11, id = "Journal", title = "Field journal", action = "Open journal" },
	}) do
		local x, id = station.x, station.id
		for _, side in ipairs({ -1, 1 }) do
			box("TableLeg", x + side * 2.05, 4.66, -6.3, 0.34, 1.32, 1.62, bark, true)
		end
		local top = box(id .. "Top", x, 5.41, -6.3, 5.15, 0.24, 2.25, wood, true)
		sign(box(id .. "Sign", x, 6.2, -7.2, 4.65, 0.68, 0.18, bark), station.title)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = station.action
		prompt.ObjectText = station.title
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 7
		prompt:SetAttribute("PocketClubStation", id)
		prompt.Parent = top
	end

	for _, x in ipairs({ -13.5, -8.5 }) do
		box("AwningPost", x, 5.8, -7.75, 0.22, 3.6, 0.22, bark)
	end
	local awning = box("CanvasAwning", -11, 7.55, -6.9, 5.65, 0.12, 2.35, Color3.fromHex("#EBDAAC"))
	awning.CFrame *= CFrame.Angles(math.rad(-9), 0, 0)
	box("FieldGuideCover", 11, 5.59, -6.15, 1.65, 0.16, 0.94, bark)
	for _, side in ipairs({ -1, 1 }) do
		box("FieldGuidePage", 11 + side * 0.39, 5.69, -6.15, 0.76, 0.07, 0.85, Color3.fromHex("#FFF0C8"))
	end
	box("DisplayDeck", -11.2, 5.91, -6.0, 0.55, 0.86, 0.15, Color3.fromHex("#303B49"))
	box("DisplayLCD", -11.2, 6.04, -5.91, 0.37, 0.46, 0.04, Color3.fromHex("#71CAD6"))
	box("DisplayA", -11.06, 5.54, -5.91, 0.095, 0.09, 0.045, Color3.fromHex("#F0B850"))
	for _, side in ipairs({ -1, 1 }) do
		box("GardenBench", side * 11.8, 4.66, 12.6, 5.3, 0.22, 1.48, wood, true)
		for _, x in ipairs({ 10.0, 13.6 }) do
			box("BenchLeg", side * x, 4.26, 12.6, 0.28, 0.52, 1.24, bark)
		end
	end

	for index = 1, 29 do
		local x = random:NextNumber(-19, 13)
		local z = random:NextNumber(-15.7, 13)
		if math.abs(x) > 5 or z < -7 then
			plant(x, 4, z, random:NextNumber(0.45, 0.92))
			if index % 3 == 0 then
				flower(x + 0.53, z, random:NextNumber(0.42, 0.58), Color3.fromHex("#FFF1CD"))
			end
		end
	end
	for _, position in ipairs({
		Vector2.new(-3.5, -3.6), Vector2.new(3.8, -5.2), Vector2.new(-8.4, -5.1),
		Vector2.new(13.5, -6.5), Vector2.new(2.8, 6.9), Vector2.new(-3.2, 8.7), Vector2.new(5.4, 10.1),
	}) do
		for index = 1, 3 do
			flower(position.X + index * 0.23, position.Y + math.sin(index) * 0.3, 0.43, Color3.fromHex("#FFF1CD"))
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 4 do
			local x = side * (17.9 + i * 0.44)
			local z = 12.1 + math.sin(i * 1.5) * 1.4
			oval("EntryRock", x, 4.17, z, 1.7, 0.75, 1.3, stone:Lerp(moss, 0.17))
			plant(x - side * 0.53, 4, z + 0.64, 1.13)
		end
	end
end

return Art
