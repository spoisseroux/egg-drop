local Lighting = game:GetService("Lighting")

local Art = {}
local grass = Color3.fromHex("#87984F")
local moss = Color3.fromHex("#647D3C")
local bark = Color3.fromHex("#765239")
local wood = Color3.fromHex("#AE7951")
local stone = Color3.fromHex("#C9BC9A")
local leaf = { Color3.fromHex("#55783D"), Color3.fromHex("#739447"), Color3.fromHex("#9BAE51") }

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
		local heading = random:NextNumber(0, math.pi * 2)
		for index = 0, 3 do
			local angle = heading + index * math.pi / 2
			local reach = size * random:NextNumber(0.20, 0.31)
			local height = size * random:NextNumber(0.54, 0.86)
			local frond = oval("Fern", x + math.cos(angle) * reach, y + height * 0.33, z + math.sin(angle) * reach,
				size * 0.23, height, size * 0.095, leaf[index % 3 + 1])
			frond.Material = Enum.Material.Grass
			frond.CFrame *= CFrame.Angles(0, -angle, 0) * CFrame.Angles(0, 0, -0.66)
		end
	end
	local function shrub(x, z, size)
		local shades = { leaf[1], leaf[2], leaf[3] }
		for i = 1, 3 do
			local angle = i * math.pi * 2 / 3
			local piece = oval("GroundFoliage", x + math.cos(angle) * size * 0.25, 4.15 + i * size * 0.06,
				z + math.sin(angle) * size * 0.22, size * 0.79, size * (0.44 + i * 0.08), size * 0.7, shades[i])
			piece.Material = Enum.Material.Grass
		end
	end
	local function flower(x, z, size, tint)
		local y = 4 + size * 0.55
		limb("FlowerStem", Vector3.new(x, 4, z), Vector3.new(x, y, z + 0.035), size * 0.08, moss)
		for i = 1, 5 do
			local theta = i * math.pi * 2 / 5
			oval("Petal", x + math.cos(theta) * size * 0.21, y, z + math.sin(theta) * size * 0.21,
				size * 0.29, size * 0.13, size * 0.29, tint).CastShadow = false
		end
		oval("FlowerHeart", x, y + 0.035, z, size * 0.26, size * 0.17, size * 0.26, Color3.fromHex("#E8AB53"))
	end

	Lighting.ClockTime = 14.85
	Lighting.Brightness = 2.13
	Lighting.Ambient = Color3.fromHex("#99927A")
	Lighting.OutdoorAmbient = Color3.fromHex("#9CA598")
	Lighting.ColorShift_Top = Color3.fromHex("#FFF4E5")
	Lighting.EnvironmentDiffuseScale = 0.28
	Lighting.EnvironmentSpecularScale = 0.18
	Lighting.ShadowSoftness = 0.65
	local air = Lighting:FindFirstChildOfClass("Atmosphere")
	if not air then
		air = Instance.new("Atmosphere")
		air.Parent = Lighting
	end
	air.Density = 0.20
	air.Offset = 0.05
	air.Color = Color3.fromHex("#D3E6F0")
	air.Decay = Color3.fromHex("#DCC69D")
	air.Haze = 0.95
	air.Glare = 0.08
	local grade = Lighting:FindFirstChild("SproutHollowGrade")
	if not grade then
		grade = Instance.new("ColorCorrectionEffect")
		grade.Name = "SproutHollowGrade"
		grade.Parent = Lighting
	end
	grade.Contrast = 0.025
	grade.Saturation = -0.035
	grade.TintColor = Color3.fromHex("#FFF5E5")

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
		local slope = oval("MeadowHill", hill[1], 1.5, hill[2], hill[3], hill[4], hill[5],
			if hill[2] < -40 then Color3.fromHex("#799C9D") else Color3.fromHex("#8BA562"))
		slope.Material = Enum.Material.Grass
	end
	for index = 1, 13 do
		local x = -36 + (index - 1) * 6
		local z = -25 - index % 3 * 4.1
		local y = if math.abs(x) > 22 then 6 else 5
		limb("DistantTrunk", Vector3.new(x, y - 1, z), Vector3.new(x, y + 4, z), 0.72, bark)
		local distant = oval("DistantCrown", x, y + 4.2, z, 5.6, 4.6, 4.5, leaf[index % #leaf + 1])
		distant.Material = Enum.Material.Grass
		if index % 3 ~= 0 then
			oval("DistantCrown", x + 1.44, y + 4.61, z - 0.8, 3.65, 3.3, 4,
				leaf[(index + 1) % #leaf + 1]).Material = Enum.Material.Grass
		end
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
	local waist = Vector3.new(-4.15, 7.0, -10.85)
	local fork = Vector3.new(-3.3, 10.2, -10.9)
	local crown = Vector3.new(-4.5, 13.0, -12.5)
	local function woodSpan(name, a, b, width, tint)
		local piece = limb(name, a, b, width, tint or bark)
		piece.Material = Enum.Material.Wood
		piece.Size = Vector3.new((b - a).Magnitude + width * 0.06, width, width)
		return piece
	end
	local function knot(position, diameter, tint)
		local piece = oval("TreeKnot", position.X, position.Y, position.Z, diameter, diameter * 1.1, diameter,
			tint or bark)
		piece.Material = Enum.Material.Wood
	end
	local trunk = woodSpan("HatchTreeTrunk", root - Vector3.new(0, 0.65, 0), waist, 3.35)
	trunk.CanCollide, trunk.CanQuery = true, true
	woodSpan("HatchTreeTrunk", waist, fork, 2.85)
	woodSpan("HatchTreeTrunk", fork, crown, 2.05)
	knot(waist, 3.31)
	knot(fork, 2.81)
	local rightElbow = Vector3.new(0.65, 11.9, -10.25)
	local rightTip = Vector3.new(4.3, 12.65, -10.8)
	woodSpan("ShelterBranch", fork, rightElbow, 1.92)
	woodSpan("ShelterBranch", rightElbow, rightTip, 1.24)
	knot(rightElbow, 1.87)
	for index, offset in ipairs({
		Vector3.new(-3.8, 0, 1.5), Vector3.new(-1.5, 0, 2.75), Vector3.new(2.8, 0, 2.05),
		Vector3.new(3.8, 0, -0.55), Vector3.new(1.0, 0, -2.7), Vector3.new(-2.55, 0, -1.8),
	}) do
		local start = root + offset * 0.16 + Vector3.new(0, 1.25, 0)
		local bend = root + offset * 0.63 + Vector3.new(0, 0.25, 0)
		woodSpan("TreeRoot", start, bend, 0.89)
		woodSpan("TreeRootTip", bend, root + offset, 0.52)
		oval("RootMoss", root.X + offset.X * 0.86, 4.18, root.Z + offset.Z * 0.88, 1.55, 0.34, 1.05,
			leaf[index % #leaf + 1]).Material = Enum.Material.Grass
	end
	for _, branch in ipairs({
		{ -8.8, 12.2, -10.8 }, { -7.5, 14.1, -13.7 }, { -0.7, 14.3, -13.8 },
		{ 2.75, 13.1, -8.65 }, { 5.3, 12.9, -12.4 }, { -4.0, 15.1, -11.25 },
	}) do
		local tip = Vector3.new(branch[1], branch[2], branch[3])
		local anchor = if tip.X > 1 then rightElbow elseif tip.Y > 13.5 then crown else fork
		local elbow = anchor:Lerp(tip, 0.60) + Vector3.new(0, -0.25, 0)
		woodSpan("HatchTreeBranch", anchor, elbow, 1.14)
		woodSpan("HatchTreeBranchTip", elbow, tip, 0.73)
		knot(elbow, 0.97)
		for index = 1, 4 do
			local theta = index * math.pi * 0.51
			local width = random:NextNumber(3.2, 4.9)
			local clump = oval("Canopy", tip.X + math.cos(theta) * 1.45, tip.Y + 0.65 + index * 0.32,
				tip.Z + math.sin(theta) * 1.25, width, width * random:NextNumber(0.62, 0.78),
				width * 0.91, leaf[if index == 4 then 3 elseif index == 1 then 1 else 2])
			clump.Material = Enum.Material.Grass
			if index == 2 then
				for side = -1, 1, 2 do
					local p = clump.Position + Vector3.new(side * width * 0.19, -clump.Size.Y * 0.24, width * 0.32)
					local accent = oval("CanopyLeaf", p.X, p.Y, p.Z, 0.43, 0.76, 0.18, leaf[3])
					accent.CFrame *= CFrame.Angles(0.34, side * 0.35, side * 0.55)
					accent.CastShadow = false
				end
			end
		end
	end
	for index = 0, 8 do
		local x = -3.6 + 0.37 * math.sin(index * 0.72)
		local y = 5.0 + index * 0.42
		local vine = oval("VineLeaf", x, y, -9.24 - index * 0.035, 0.42, 0.61, 0.12, leaf[index % #leaf + 1])
		vine.CFrame *= CFrame.Angles(0, 0, if index % 2 == 0 then 0.47 else -0.61)
	end
	for index = 1, 4 do
		oval("ShelfFungus", -4.9 + index * 0.10, 5.65 + index * 0.38, -9.75 - index * 0.08,
			0.76 - index * 0.074, 0.15, 0.52, Color3.fromHex("#CEAC79"))
	end
	limb("LanternCord", Vector3.new(0.82, 12.2, -9.6), Vector3.new(0.82, 8.7, -9.6), 0.085, bark)
	box("LanternCap", 0.82, 8.8, -9.6, 0.61, 0.12, 0.61, bark)
	local lantern = box("LanternGlass", 0.82, 8.47, -9.6, 0.47, 0.54, 0.47, Color3.fromHex("#FFC874"))
	lantern.Material = Enum.Material.Neon
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromHex("#FFD498")
	glow.Brightness = 0.65
	glow.Range = 9
	glow.Parent = lantern
	box("LanternBase", 0.82, 8.17, -9.6, 0.60, 0.11, 0.60, bark)

	local nest = box("HatchTop", 0, 4.115, -5, 5.8, 0.23, 4.6, stone, true)
	nest.Transparency = 1
	oval("MossNest", 0, 4.06, -5, 6.2, 0.34, 4.95, moss)
	for index = 1, 12 do
		local theta = index * math.pi / 6
		local x, z = math.cos(theta) * 2.82, -5 + math.sin(theta) * 2.11
		local rock = oval("NestStone", x, 4.17, z, 1.0 + index % 3 * 0.13, 0.36 + index % 2 * 0.06, 0.9,
			stone:Lerp(grass, index % 3 * 0.10))
		rock.Material = Enum.Material.Slate
		rock.CFrame *= CFrame.Angles(0, theta, 0)
		if index % 3 == 0 then
			oval("NestMoss", x + 0.12, 4.34, z - 0.07, 0.59, 0.12, 0.41, leaf[2]).Material = Enum.Material.Grass
		end
	end
	for _, x in ipairs({ -1.85, 1.87 }) do
		oval("HatcheryEgg", x, 4.63, -6.06, 0.65, 0.95, 0.59, Color3.fromHex("#EEE0AE"))
	end

	-- Overlapping pools form a bend. The shallow bank covers their joins.
	local waterEdge = Color3.fromHex("#73B7B2")
	local waterDeep = Color3.fromHex("#4F9DAF")
	local function waterShape(name, x, y, z, width, length, angle, tint)
		local layer = oval(name, x, y, z, width, 0.09, length, tint)
		layer.CastShadow = false
		layer.CFrame *= CFrame.Angles(0, math.rad(angle), 0)
	end
	for _, bend in ipairs({
		{ 16.9, -16.0, 5.6, 9.6, -16 }, { 17.8, -10.0, 6.7, 10.5, -9 },
		{ 18.65, -3.6, 6.35, 10.8, 3 }, { 18.05, 3.3, 6.75, 10.6, 11 },
		{ 16.9, 9.8, 6.2, 10.4, 8 }, { 16.55, 15, 5.95, 8.3, 1 },
	}) do
		local x, z, width, length, angle = table.unpack(bend)
		waterShape("Creek", x, 4.038, z, width, length, angle, waterEdge)
		waterShape("CreekDepth", x + 0.15, 4.069, z, width - 1.25, length - 0.22, angle, waterDeep)
	end
	for index = 0, 15 do
		local z = -16.8 + index * 2.04
		local x = 16.7 + 1.85 * math.exp(-((z + 2.2) / 8.8) ^ 2)
		local ripple = oval("WaterRipple", x + math.sin(index * 2.2) * 0.95, 4.117, z,
			random:NextNumber(0.60, 1.36), 0.015, 0.075, Color3.fromHex("#CBE9DC"))
		ripple.Transparency, ripple.CastShadow = 0.18, false
		ripple.CFrame *= CFrame.Angles(0, math.rad(index % 3 * 11 - 13), 0)
		if math.abs(z + 9.4) > 1.8 then
			local edge = x - 2.85 + math.sin(index * 1.8) * 0.35
			local rock = oval("CreekStone", edge, 4.12, z, random:NextNumber(0.65, 1.53),
				random:NextNumber(0.32, 0.65), random:NextNumber(0.58, 1.2), stone:Lerp(moss, (index % 4) * 0.10))
			rock.Material = Enum.Material.Slate
			rock.CFrame *= CFrame.Angles(0, index * 1.2, 0.13 * math.sin(index))
			if index % 2 == 0 then
				shrub(edge - 0.71, z + 0.48, 0.86)
				plant(edge - 0.24, 4, z - 0.46, 1.23)
				local farBank = math.min(x + 2.55, 21.02)
				plant(farBank, 4, z + 0.6, 1.1)
				oval("CreekStone", farBank - 0.1, 4.16, z - 0.18, 0.84, 0.44, 0.72, stone).Material = Enum.Material.Slate
			end
			if index % 4 == 1 then
				for reed = 1, 2 do
					local base = Vector3.new(edge - 0.16 + reed * 0.15, 4, z + reed * 0.15)
					local tip = base + Vector3.new(0.08, 0.79 + reed * 0.16, 0)
					limb("ReedStem", base, tip, 0.047, leaf[1]).CastShadow = false
					oval("Cattail", tip.X, tip.Y, tip.Z, 0.12, 0.25, 0.11, bark).CastShadow = false
				end
			end
		end
	end
	for _, rock in ipairs({
		{ 14.0, 5.0, -20.2, 4.9, 3.9, 3.8 }, { 19.2, 5.6, -20.7, 5.1, 4.9, 4.0 },
		{ 16.8, 5.1, -21.6, 4.7, 4.2, 3.6 }, { 19.1, 4.1, -18.5, 3.4, 2.0, 2.9 },
	}) do
		oval("CreekHeadRock", rock[1], rock[2], rock[3], rock[4], rock[5], rock[6],
			stone:Lerp(moss, 0.14)).Material = Enum.Material.Slate
	end
	local cascade = oval("CreekCascade", 17.0, 5.26, -19.24, 1.62, 2.62, 0.37, waterEdge)
	cascade.CFrame *= CFrame.Angles(math.rad(-13), 0, math.rad(-4))
	cascade.CastShadow = false
	for index = 1, 3 do
		local run = oval("CascadeStreak", 16.35 + index * 0.30, 5.12, -19.04,
			0.13 + index * 0.03, 2.17 - index * 0.16, 0.12, Color3.fromHex("#B7DAD6"))
		run.CFrame *= CFrame.Angles(math.rad(-13), 0, math.rad(-4))
		run.CastShadow = false
	end
	waterShape("CreekFoam", 17.0, 4.10, -18.82, 2.35, 0.79, -8, Color3.fromHex("#BCDAD1"))
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

	for _, cluster in ipairs({
		{ -7.5, -9.1, 1.7 }, { -2.1, -8.6, 1.33 }, { 1.75, -8.1, 1.42 }, { 4.2, -7.7, 1.14 },
		{ -13.9, -7.1, 1.28 }, { -8.35, -7.7, 1.0 }, { 9.1, -8.1, 1.05 }, { 13.75, -6.55, 1.15 },
		{ -17.7, 11.1, 1.9 }, { 11.4, 11.2, 1.38 }, { -6.4, 9.9, 0.95 }, { 5.6, 7.4, 0.87 },
		{ -7.9, 12.9, 2.4 }, { 10.2, 14.1, 2.35 }, { 14.2, 12.6, 1.8 },
	}) do
		local x, z, size = table.unpack(cluster)
		shrub(x, z, size)
		plant(x + size * 0.5, 4, z + size * 0.25, size * 0.76)
		plant(x - size * 0.5, 4, z + size * 0.39, size * 0.62)
	end
	-- Taller edge planting frames the arrival view while leaving the center path open.
	for _, patch in ipairs({ { -9.8, 5.7 }, { -7.9, 6.3 }, { 10.75, 2.85 }, { 12.45, 3.2 } }) do
		local x, z = patch[1], patch[2]
		local rock = oval("MeadowBoulder", x, 4.20, z, 1.9, 0.8, 1.28, stone:Lerp(moss, 0.15))
		rock.Material = Enum.Material.Slate
		rock.CFrame *= CFrame.Angles(0.05, x * 0.34, -0.11)
		shrub(x - 0.61, z + 0.4, 1.45)
		shrub(x + 0.59, z + 0.4, 1.08)
		plant(x + 0.88, 4, z - 0.25, 1.42)
		for i = 1, 3 do
			flower(x - 0.36 + i * 0.28, z + 0.75 + math.sin(i) * 0.21,
				0.68 - i * 0.06, Color3.fromHex("#FFF1CD"))
		end
	end
	for _, position in ipairs({
		Vector2.new(-3.5, -3.6), Vector2.new(3.8, -5.2), Vector2.new(-8.4, -5.1),
		Vector2.new(13.5, -6.5), Vector2.new(2.8, 6.9), Vector2.new(-3.2, 8.7), Vector2.new(5.4, 10.1),
	}) do
		for index = 1, 3 do
			flower(position.X + index * 0.26, position.Y + math.sin(index) * 0.3,
				0.55 + index * 0.05, Color3.fromHex("#FFF1CD"))
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
