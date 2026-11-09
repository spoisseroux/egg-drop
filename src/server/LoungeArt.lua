local Lighting = game:GetService("Lighting")
local WorldLayout=require(game:GetService("ReplicatedStorage").Shared.HollowWorldLayout)
local GardenArt=require(script.Parent.LoungeGardenArt)
local SpringArt=require(script.Parent.LoungeSpringArt)

local Art = {}
local grass = Color3.fromHex("#72B85B")
local moss = Color3.fromHex("#427E58")
local bark = Color3.fromHex("#765239")
local wood = Color3.fromHex("#AE7951")
local stone = Color3.fromHex("#C9BC9A")
local leaf = { Color3.fromHex("#427E58"), Color3.fromHex("#69A75C"), Color3.fromHex("#A4C875") }
local function lawn(x,z)return x>-14 and x<10 and z>-13 and z<8 end

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
	local function shrub(x, z, size, banked)
		local shades = { leaf[1], leaf[2], leaf[3] }
		for i = 1, 3 do
			local angle = i * math.pi * 2 / 3
			local piece = oval("GroundFoliage", x + math.cos(angle) * size * 0.25, 4.15 + i * size * 0.06,
				z + math.sin(angle) * size * 0.22, size * 0.79, size * (0.44 + i * 0.08), size * 0.7, shades[i])
			piece.Material = Enum.Material.Grass
			if banked then piece:SetAttribute("HollowBankPlant",true)end
		end
	end
	local function flower(x, z, size, tint, banked)
		local y = 4 + size * 0.55
		local stem=limb("FlowerStem", Vector3.new(x, 4, z), Vector3.new(x, y, z + 0.035), size * 0.08, moss)
		if banked then stem:SetAttribute("HollowBankPlant",true)end
		for i = 1, 5 do
			local theta = i * math.pi * 2 / 5
			local petal=oval("Petal", x + math.cos(theta) * size * 0.21, y, z + math.sin(theta) * size * 0.21,
				size * 0.29, size * 0.13, size * 0.29, tint)
			petal.CastShadow=false;if banked then petal:SetAttribute("HollowBankPlant",true)end
		end
		local heart=oval("FlowerHeart", x, y + 0.035, z, size * 0.26, size * 0.17, size * 0.26, Color3.fromHex("#E8AB53"))
		if banked then heart:SetAttribute("HollowBankPlant",true)end
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
	grade.Saturation = 0.015
	grade.TintColor = Color3.fromHex("#F1F7FF")

	local ground = box("Floor", 0, WorldLayout.FloorTop-.5, WorldLayout.FloorCenterZ, WorldLayout.Width, 1, WorldLayout.Depth, grass, true)
	ground:SetAttribute("PlayableWidth", WorldLayout.Width)
	ground:SetAttribute("PlayableDepth", WorldLayout.Depth)
	box("MeadowGround", 0, 2.85, -24, 400, 0.85, 280, grass)
	for _, side in ipairs({ -1, 1 }) do
		box("GardenBoundary", side * (WorldLayout.Width*.5-.4), 12, WorldLayout.FloorCenterZ, 0.8, 16, WorldLayout.Depth, grass, true).Transparency = 1
		box("GardenBoundary", 0, 12, WorldLayout.FloorCenterZ+side * (WorldLayout.Depth*.5-.4), WorldLayout.Width, 16, 0.8, grass, true).Transparency = 1
	end
	for _, hill in ipairs({
		{ -32, -21, 35, 11, 28 }, { -16, -31, 31, 14, 25 }, { 11, -34, 34, 12, 26 },
		{ 33, -29, 38, 19, 32 }, { 19, -53, 66, 22, 33 }, { -39, -49, 45, 23, 38 },
		{ 43, 2, 29, 12, 33 }, { -43, 0, 29, 8, 31 },
		{ -69, -62, 74, 27, 49 }, { -32, -87, 65, 25, 44 }, { 29, -90, 69, 29, 54 }, { 75, -64, 67, 26, 50 },
	}) do
		local slope = oval("MeadowHill", hill[1] * 2.5, 1.5, hill[2] * 2.5, hill[3], hill[4], hill[5],
			if hill[2] < -40 then Color3.fromHex("#799C9D") else Color3.fromHex("#8BA562"))
		slope.Material = Enum.Material.Grass
	end
	for index = 1, 13 do
		local x = -58 + (index - 1) * 9.5
		local z = -53 - index % 3 * 4.1
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
	lantern:SetAttribute("HollowLampFixture",true)
	lantern.Material = Enum.Material.Neon
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromHex("#FFD498")
	glow.Brightness = 0.65
	glow.Range = 9
	glow.Shadows=false
	glow:SetAttribute("HollowLamp",true)
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
		local meadow=x<0
		oval("HatcheryEgg",x,if meadow then 4.85 else 4.63,-6.06,if meadow then 1.10 else .65,if meadow then 1.45 else .95,if meadow then .98 else .59,
			if meadow then Color3.fromHex("#E5E9B5") else Color3.fromHex("#EEE0AE"))
		if meadow then
			-- The same leaf/seed identity as the existing Meadow recipe; no new egg type.
			for _,side in ipairs({-1,1}) do
				local mark=oval("MeadowEggLeaf",x+side*.12,5.13,-5.55,.32,.15,.035,leaf[1])
				mark.CFrame*=CFrame.Angles(0,0,side*math.rad(24));mark.CastShadow=false
			end
			oval("MeadowEggSeed",x,4.67,-5.55,.18,.24,.035,leaf[1]).CastShadow=false
		end
	end
	-- A browsable marker at the nest's front edge, with no movement/camera collision.
	box("EggsSignPost",0,4.88,-3.5,.15,1.65,.15,bark)
	local eggsSign=box("EggsSign",0,5.5,-3.5,2.45,.64,.14,Color3.fromHex("#38694A"))
	sign(eggsSign,"Eggs")
	local eggPrompt=Instance.new("ProximityPrompt")
	eggPrompt.Name,eggPrompt.ObjectText,eggPrompt.ActionText="BrowseEggs","","Browse eggs"
	eggPrompt.UIOffset=Vector2.new(72,-16)
	eggPrompt.Style=Enum.ProximityPromptStyle.Default
	eggPrompt.KeyboardKeyCode,eggPrompt.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX
	eggPrompt.ClickablePrompt,eggPrompt.RequiresLineOfSight,eggPrompt.HoldDuration=true,false,0
	eggPrompt.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton
	eggPrompt.MaxActivationDistance=5
	eggPrompt:SetAttribute("PocketClubStation","Eggs")
	eggPrompt.Parent=eggsSign

	-- Overlapping pools form a bend. The shallow bank covers their joins.
	local waterEdge = Color3.fromHex("#45C5D0")
	local waterDeep = Color3.fromHex("#267BA0")
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
	for index = 0, 15 do
		local x = 12.8 + index * 0.64
		local plank=box("BridgePlank", x, 4.25, -9.4, 0.62, 0.21, 4.5, if index % 2 == 0 then wood else bark, true)
        plank:SetAttribute("GardenWalkableSpan","PrimaryBridge")
	end
	for _, z in ipairs({ -11.88, -6.92 }) do
		for _, x in ipairs({ 12.8, 17.6, 22.4 }) do
			box("BridgePost", x, 4.76, z, 0.20, 1.18, 0.20, bark)
		end
		box("BridgeRail", 17.6, 5.13, z, 9.8, 0.13, 0.13, wood)
	end

	-- New walkable wings keep the original tree grove at its natural scale.
	-- Broad routes lead to a quiet orchard, picnic clearing and creek outlook.
	local function trail(a, b, count)
		for i = 1, count do
			local t = i / count
			local p = a:Lerp(b, t)
			local wobble = math.sin(t * math.pi * 2) * 1.1
			local tile = oval("MeadowTrail", p.X + wobble, 4.027, p.Y, 2.6, 0.12, 1.7, stone)
			tile.CFrame *= CFrame.Angles(0, i * 0.53, 0)
		end
	end
	trail(Vector2.new(-5, 2), Vector2.new(-35, -22), 16)
	trail(Vector2.new(-5, 4), Vector2.new(-35, 23), 16)
	trail(Vector2.new(5, 5), Vector2.new(37, 24), 16)
	trail(Vector2.new(20, -9.4), Vector2.new(41, -28), 12)
	trail(Vector2.new(3, 13), Vector2.new(0, 39), 13)
	for _, patch in ipairs({
		{ -34, -22, 14, 12 }, { -33, 24, 15, 12 }, { 37, 24, 15, 12 }, { 40, -28, 12, 10 },
	}) do
		local x, z, w, d = table.unpack(patch)
		oval("ClearingMoss", x, 4.015, z, w, 0.03, d, grass:Lerp(leaf[3], 0.14)).CastShadow = false
		for i = 0, 6 do
			local angle = i * math.pi * 2 / 7
			local sx,sz=x+math.cos(angle)*w*.54,z+math.sin(angle)*d*.54
			local banked=x==40 and z==-28 and (i==0 or i==1)
			if banked then sx,sz=if i==0 then 47 else 42,if i==0 then -34 else -18.8 end
			shrub(sx,sz,1.2+i%3*.22,banked)
			if i % 2 == 0 then
				local fx,fz=x+math.cos(angle)*w*.46,z+math.sin(angle)*d*.46
				local bankedFlower=x==40 and z==-28 and i==0
				if bankedFlower then fx,fz=46,-33 end
				flower(fx,fz,.8,Color3.fromHex("#FFF1CD"),bankedFlower)
			end
		end
	end
	for _, position in ipairs({ { -38, -29 }, { -28, -27 }, { -43, 13 }, { -38, 31 }, { 44, -34 }, { 48, 29 }, { -14, 36 } }) do
		local x, z = position[1], position[2]
		local height = random:NextNumber(5.2, 7.4)
		local trunk = limb("OrchardTrunk", Vector3.new(x, 4, z), Vector3.new(x + 0.3, 4 + height, z), 0.85, bark)
		trunk.Material, trunk.CanCollide, trunk.CanQuery = Enum.Material.Wood, true, true
		for j = 1, 3 do
			local theta = j * math.pi * 2 / 3
			oval("OrchardCrown", x + math.cos(theta) * 1.1, 4 + height + j * 0.28, z + math.sin(theta) * 1.1,
				5.4, 3.6, 4.8, leaf[j]).Material = Enum.Material.Grass
		end
	end
	for _, picnic in ipairs({ { -34, 24 }, { 38, -28 } }) do
		local x, z = picnic[1], picnic[2]
		box("PicnicTop", x, 5.3, z, 5.2, 0.25, 2.4, wood, true)
		for _, side in ipairs({ -1, 1 }) do
			box("PicnicSeat", x, 4.75, z + side * 2.1, 5.8, 0.22, 0.9, wood, true)
			for _, edge in ipairs({ -1, 1 }) do
				box("PicnicSupport", x + edge * 1.9, 4.63, z + side * 0.7, 0.3, 1.2, 0.3, bark)
			end
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		for i = 1, 4 do
			local z = side * (17 + i * 6.4)
			local x = 17.5 + math.sin(i * 0.6) * 2.7
			waterShape("MeadowCreek", x, 4.038, z, 6.4, 9.2, side * 8, waterEdge)
			waterShape("MeadowCreekDepth", x + 0.15, 4.069, z, 5.0, 8.9, side * 8, waterDeep)
			for bank = -1, 1, 2 do
				plant(x + bank * 3.1, 4, z, 1.2)
				oval("MeadowCreekStone", x + bank * 3.05, 4.16, z + 1.1, 1.0, 0.45, 0.85, stone)
			end
		end
	end
	waterShape("OutlookPond", 28, 4.038, 29, 17, 13, -15, waterEdge)
	waterShape("OutlookPondDepth", 28, 4.069, 29, 14.5, 10.8, -15, waterDeep)
	for i = 0, 12 do
		local x = 17.0 + i * 0.58
		box("MeadowBridgePlank", x, 4.25, 22.0, 0.56, 0.21, 2.8, if i % 2 == 0 then wood else bark, true)
	end
	for _, z in ipairs({ 20.7, 23.3 }) do
		box("MeadowBridgeRail", 20.5, 5.13, z, 7.4, 0.15, 0.15, wood)
		for _, x in ipairs({ 17.1, 20.5, 23.9 }) do box("MeadowBridgePost", x, 4.7, z, 0.2, 1.2, 0.2, bark) end
	end
	for i = 0, 11 do
		local angle = i * math.pi * 2 / 12
		local x, z = math.cos(angle) * (WorldLayout.Width*.5-5), WorldLayout.FloorCenterZ+math.sin(angle) * (WorldLayout.Depth*.5-5)
		shrub(x, z, 2.3)
		plant(x - 1.2, 4, z + 0.9, 2.1)
		oval("BoundaryStone", x + 0.6, 4.4, z - 0.5, 2.5, 1.1, 1.7, stone:Lerp(moss, 0.2))
	end

	-- Raise the complete service assemblies; supports keep their original floor seats.
	local serviceLift=1.10
	for _, station in ipairs({
		{ x = -11, id = "Customize", title = "Deck workbench", action = "Style deck" },
		{ x = 11, id = "Journal", title = "Care machine", action = "Open companions" },
	}) do
		local x, id = station.x, station.id
		for _, side in ipairs({ -1, 1 }) do
			box("TableLeg", x + side * 2.05, 4.66+serviceLift*.5, -6.3, 0.34, 1.32+serviceLift, 1.62, bark, true)
		end
		local top = box(id .. "Top", x, 5.41+serviceLift, -6.3, 5.15, 0.24, 2.25, wood, true)
		sign(box(id .. "Sign", x, 6.2+serviceLift, -7.2, 4.65, 0.68, 0.18, bark), station.title)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = station.action
		prompt.ObjectText = ""
		prompt.UIOffset=Vector2.new(if x<0 then 112 else 72,-12)
		prompt.RequiresLineOfSight = false
		prompt.KeyboardKeyCode,prompt.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX
		prompt.ClickablePrompt,prompt.HoldDuration=true,0
		prompt.Exclusivity=Enum.ProximityPromptExclusivity.OnePerButton
		prompt.MaxActivationDistance = 7
		prompt:SetAttribute("PocketClubStation", id)
		prompt.Parent = top
	end

	for _, x in ipairs({ -13.5, -8.5 }) do
		box("AwningPost", x, 5.8+serviceLift*.5, -7.75, 0.22, 3.6+serviceLift, 0.22, bark)
	end
	local awning = box("CanvasAwning", -11, 7.55+serviceLift, -6.9, 5.65, 0.12, 2.35, Color3.fromHex("#EBDAAC"))
	awning.CFrame *= CFrame.Angles(math.rad(-9), 0, 0)
	require(script.Parent.LoungeCareArt)(room)
	-- One readable journal station: a raised field guide and painted family seals.
	-- These small decorations leave the existing table/prompt and paths intact.
	for _, side in ipairs({ -1, 1 }) do
		box("FieldGuideStand", 11 + side * 0.78, 5.67+serviceLift, -6.45, 0.24, 0.28, 0.62, bark)
	end
	local guide = box("FieldGuideCover", 11, 5.83+serviceLift, -6.15, 2.32, 0.16, 1.42, Color3.fromHex("#38694A"))
	guide.CFrame *= CFrame.Angles(math.rad(18), 0, 0)
	local function bookDetail(name, offset, size, color)
		local piece = box(name, 0, 0, 0, size.X, size.Y, size.Z, color)
		piece.CFrame = guide.CFrame * CFrame.new(offset)
		piece.CastShadow = false
		return piece
	end
	bookDetail("FieldGuideSpine", Vector3.new(0, 0.12, 0), Vector3.new(0.11, 0.11, 1.37), Color3.fromHex("#CFB56D"))
	for _, side in ipairs({ -1, 1 }) do
		bookDetail("FieldGuidePage", Vector3.new(side * 0.55, 0.12, 0), Vector3.new(1.02, 0.07, 1.26), Color3.fromHex("#FFF0C8"))
		for row = 0, 1 do
			local seal = bookDetail("FieldGuideFamilySeal", Vector3.new(side * 0.55, 0.17, -0.34 + row * 0.52),
				Vector3.new(0.22, 0.035, 0.22), ({ Color3.fromHex("#77AC59"), Color3.fromHex("#ECA65B"),
					Color3.fromHex("#6EBDCC"), Color3.fromHex("#9D8DC9") })[(if side < 0 then 1 else 3) + row])
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType, mesh.Parent = Enum.MeshType.Sphere, seal
			bookDetail("FieldGuideInk", Vector3.new(side * 0.55, 0.17, -0.12 + row * 0.52),
				Vector3.new(0.56, 0.018, 0.025), Color3.fromHex("#859171"))
		end
	end
	bookDetail("FieldGuideRibbon", Vector3.new(0.32, 0.10, 0.78), Vector3.new(0.15, 0.035, 0.48), Color3.fromHex("#CFB56D"))
	box("JournalWayfinderPost", 5.8, 4.9, 3.8, 0.16, 1.8, 0.16, bark)
	local wayfinder = box("JournalWayfinder", 5.8, 5.65, 3.8, 2.7, 0.64, 0.13, Color3.fromHex("#38694A"))
	sign(wayfinder, "Journal  →")
	box("DisplayDeck", -11.2, 5.77+serviceLift, -6.0, 1.02, 0.47, 0.15, Color3.fromHex("#303B49"))
	box("DisplayLCD", -11.2, 5.77+serviceLift, -5.91, 0.28, 0.39, 0.04, Color3.fromHex("#71CAD6"))
	box("DisplayRocker", -11.53, 5.77+serviceLift, -5.91, 0.15, 0.07, 0.04, bark)
	box("DisplayA", -10.87, 5.77+serviceLift, -5.91, 0.095, 0.09, 0.045, Color3.fromHex("#F0B850"))
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
		if lawn(x,z)then continue end
		shrub(x, z, size)
		plant(x + size * 0.5, 4, z + size * 0.25, size * 0.76)
		plant(x - size * 0.5, 4, z + size * 0.39, size * 0.62)
	end
	-- Taller edge planting frames the arrival view while leaving the center path open.
	for _, patch in ipairs({ { -9.8, 5.7 }, { -7.9, 6.3 }, { 10.75, 2.85 }, { 12.45, 3.2 } }) do
		local x, z = patch[1], patch[2]
		if lawn(x,z)then continue end
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
		if lawn(position.X,position.Y)then continue end
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

	-- The expansion is appended after the original seeded hub draws. Every
	-- route assembly remains authored at human scale and the same ground level.
	local function routeTrail(points)
		for i=2,#points do
			trail(points[i-1],points[i],math.max(3,math.ceil((points[i]-points[i-1]).Magnitude/2)))
		end
	end
	routeTrail(WorldLayout.Routes.Orchard)
	routeTrail(WorldLayout.Routes.OrchardReturn)
	routeTrail(WorldLayout.Routes.EastReturn)
	trail(Vector2.new(41,-28),WorldLayout.Routes.Boardwalk[1],3)
	waterShape("LanternPool",61,4.038,-17,25,21,-12,waterEdge)
	waterShape("LanternPoolDepth",61,4.069,-17,22.5,18.5,-12,waterDeep)
	local function boardwalk(a,b,openSide)
		local from,to=Vector3.new(a.X,4.11,a.Y),Vector3.new(b.X,4.11,b.Y)
		local length=(to-from).Magnitude
		local cf=CFrame.lookAt((from+to)*.5,to)
		local deck=box("LanternBoardwalkDeck",0,0,0,WorldLayout.BoardwalkWidth,.22,length+.8,wood,true)
		deck.CFrame=cf;deck.Material=Enum.Material.WoodPlanks
		deck:SetAttribute("HollowRouteSolid",true)
		for _,side in ipairs({-1,1})do
			if side==openSide then continue end
			-- Open the final two studs at each joint for both walking lanes.
			-- A full-length inside rail otherwise clips the turning shoulder.
			local railLength=math.max(1,length-4)
			local rail=box("LanternBoardwalkRail",0,0,0,.16,.15,railLength,bark,true)
			rail.CFrame=cf*CFrame.new(side*(WorldLayout.BoardwalkWidth*.5-.15),2.05,0)
			for _,endSide in ipairs({-1,1})do
				local post=box("LanternBoardwalkPost",0,0,0,.23,2.25,.23,bark,true)
				post.CFrame=cf*CFrame.new(side*(WorldLayout.BoardwalkWidth*.5-.15),1.0,endSide*railLength*.5)
			end
		end
	end
	for i=2,#WorldLayout.Routes.Boardwalk do
		-- The return trail enters the northwest edge of the second span.
		-- Leave that whole edge open rather than fencing across a walking route.
		boardwalk(WorldLayout.Routes.Boardwalk[i-1],WorldLayout.Routes.Boardwalk[i],if i==3 then 1 else nil)
	end
	boardwalk(WorldLayout.Routes.EastReturn[1],WorldLayout.Routes.EastReturn[2])
	local outlook=box("LanternLookoutDeck",64,4.11,-14,10,.22,9,wood,true)
	outlook.Material=Enum.Material.WoodPlanks;outlook:SetAttribute("HollowRouteSolid",true)
	-- A low, broad landing is the landmark; paired lamps reveal its return gap.
	box("LanternLookoutSeat",68,4.85,-14,1.1,.24,3.5,wood,true)
	for _,z in ipairs({-15.2,-12.8})do box("LanternLookoutSeatLeg",68,4.42,z,.5,.85,.5,bark,true)end
	oval("OrchardGladeMoss",-59,4.02,-34,15,.035,13,grass:Lerp(leaf[3],.22)).CastShadow=false
	for i,tree in ipairs({{-65,-41,6.8},{-55,-43,7.7},{-69,-29,6.1},{-51,-38,7.0}})do
		local x,z,h=table.unpack(tree)
		local trunk=limb("GladeOrchardTrunk",Vector3.new(x,4,z),Vector3.new(x+.35,4+h,z),.8,bark)
		trunk.Material,trunk.CanCollide,trunk.CanQuery=Enum.Material.Wood,true,true
		for j=1,3 do
			local angle=j*math.pi*2/3+i*.4
			oval("GladeOrchardCrown",x+math.cos(angle)*1.3,4+h+j*.24,z+math.sin(angle)*1.1,
				5.4+i*.22,3.3+j*.18,4.7,leaf[(i+j)%#leaf+1]).Material=Enum.Material.Grass
		end
		flower(x+.9,z+.6,1.1,Color3.fromHex("#E9DAAE"))
	end
	box("GladeBenchSeat",-64,4.85,-34,1.2,.24,4.6,wood,true)
	box("GladeBenchBack",-64.65,5.4,-34,.16,.8,4.6,bark,true)
	for _,z in ipairs({-35.5,-32.5})do box("GladeBenchLeg",-64,4.42,z,.5,.85,.5,bark,true)end
	for i,point in ipairs(WorldLayout.Lamps)do
		local x,z=point.X,point.Y
		box("HollowLampStand",x,4.7,z,.20,1.4,.20,bark)
		box("HollowLampBase",x,5.4,z,.7,.13,.7,bark)
		local glass=box("HollowLampGlass",x,5.78,z,.5,.65,.5,Color3.fromHex("#FFD08A"))
		glass.Material=Enum.Material.Neon;glass.CastShadow=false;glass:SetAttribute("HollowLampFixture",true)
		box("HollowLampCap",x,6.17,z,.76,.14,.76,bark)
		local hook=limb("HollowLampHandle",Vector3.new(x-.2,6.25,z),Vector3.new(x+.2,6.25,z),.08,bark)
		hook.CastShadow=false
		if WorldLayout.LitLamps[i]then
			local light=Instance.new("PointLight");light.Name="HollowPathLight"
			light.Color,light.Range,light.Brightness,light.Shadows=Color3.fromHex("#FFD5A0"),11,.65,false
			light:SetAttribute("HollowLamp",true);light.Parent=glass
		end
	end
	-- One small fork marker; the destinations introduce no interaction prompts.
	local forkSign=box("HollowRouteFork",43,5.2,-22,.95,1.8,.16,bark)
	sign(forkSign,"Pool  →")
	local function ambient(name,kind,position,size,tint,phase,period,amplitude,transparency)
		local bit=box("HollowAmbient_"..name,position.X,position.Y,position.Z,size.X,size.Y,size.Z,tint)
		bit.CastShadow=false;bit.Transparency=transparency
		if kind=="firefly"then bit.Material=Enum.Material.Neon end
		if kind=="leaf"then bit.CFrame*=CFrame.Angles(.1,phase*math.pi*2,.2)end
		bit:SetAttribute("HollowAmbientPhase",phase)
		bit:SetAttribute("HollowAmbientPeriod",period)
		bit:SetAttribute("HollowAmbientAmplitude",amplitude)
		bit:SetAttribute("HollowRestCFrame",bit.CFrame)
		bit:SetAttribute("HollowRestTransparency",bit.Transparency)
		bit:SetAttribute("HollowAmbientKind",kind) -- Complete metadata before eligibility.
	end
	GardenArt.build(room,part)
    SpringArt.build(room,part)
	for i=1,5 do
		ambient("Water"..i,"water",Vector3.new(52+i*2.7,4.13,-25+(i%3)*5.0),Vector3.new(1.3,.025,.09),
			Color3.fromHex("#D2EBDB"),(i-1)/6,7+i%3,Vector3.new(.35,0,0),.42)
		ambient("Leaf"..i,"leaf",Vector3.new(-65+i*1.7,5.1+(i%3)*.5,-38+(i%2)*9),Vector3.new(.32,.045,.19),
			Color3.fromHex("#C8DA82"),(i-1)/6,8+i%3,Vector3.new(.35,.20,.18),.12)
		ambient("Firefly"..i,"firefly",Vector3.new(56+(i%3)*4,5.2+(i%2)*.6,-12+(i%2)*5),Vector3.new(.10,.10,.10),
			Color3.fromHex("#FFE2A0"),(i-1)/6,6+i%3,Vector3.new(.18,.24,.14),.22)
	end
end

return Art
