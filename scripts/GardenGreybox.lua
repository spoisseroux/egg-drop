-- v1 garden greybox (2026-11-11). Original enclosed-garden layout at the
-- proportions measured from the Chao Garden reference (about x0.5 scale):
-- ~240 x 200 stud floor, ~60-stud cliff ring on north and east with a cave
-- gap, west pond ~36 x 65 fed by a waterfall, creek with a crossing, east
-- terraces, west stepping pillars, landmark tree, hub stations, open south rim
-- looking out to sea. Untextured blocks only; this is for walking and
-- agreeing proportions before Spencer models the final kit (ART-HANDOFF.md s7).
--
-- Usage (Studio Edit, command bar or MCP): require(<this module>)(workspace, Vector3.new(1000, 0, 0))
-- Builds Workspace.GardenGreybox, replacing an existing one. +Z is south (spawn side).
return function(parent, origin)
	origin = origin or Vector3.new(1000, 0, 0)
	local old = parent:FindFirstChild("GardenGreybox")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "GardenGreybox"
	local colors = {
		grass = Color3.fromRGB(120, 196, 104), cliff = Color3.fromRGB(150, 138, 196), cliffDark = Color3.fromRGB(118, 106, 168),
		water = Color3.fromRGB(70, 160, 225), sea = Color3.fromRGB(40, 110, 190), path = Color3.fromRGB(226, 208, 160),
		wood = Color3.fromRGB(140, 100, 64), leaf = Color3.fromRGB(70, 150, 80), station = Color3.fromRGB(235, 235, 240),
		ref = Color3.fromRGB(255, 120, 90),
	}
	local function folder(name) local f = Instance.new("Folder"); f.Name = name; f.Parent = model; return f end
	local groups = {
		ground = folder("Ground"), cliffs = folder("Cliffs"), water = folder("Water"), terraces = folder("Terraces"),
		props = folder("Props"), stations = folder("Stations"), labels = folder("Labels"), scale = folder("ScaleReference"),
	}
	local function part(group, name, size, center, color, opts)
		opts = opts or {}
		local p = Instance.new(opts.class or "Part")
		p.Name = name
		p.Anchored = true
		p.Size = size
		p.CFrame = CFrame.new(origin + center) * (opts.rot or CFrame.identity)
		p.Color = color
		p.Material = opts.material or Enum.Material.SmoothPlastic
		p.Transparency = opts.transparency or 0
		p.CanCollide = opts.collide ~= false
		p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
		if opts.shape then p.Shape = opts.shape end
		p.Parent = groups[group]
		return p
	end
	local function label(text, position)
		local a = Instance.new("Part")
		a.Name = "Label_" .. text:gsub("%W", "")
		a.Anchored, a.CanCollide, a.CanQuery, a.Transparency, a.Size = true, false, false, 1, Vector3.one
		a.Position = origin + position
		local g = Instance.new("BillboardGui")
		g.Size, g.AlwaysOnTop, g.MaxDistance = UDim2.fromOffset(220, 40), true, 400
		local t = Instance.new("TextLabel")
		t.Size, t.BackgroundTransparency, t.Text = UDim2.fromScale(1, 1), 0.3, text
		t.BackgroundColor3, t.TextColor3, t.TextScaled, t.Font = Color3.new(0, 0, 0), Color3.new(1, 1, 1), true, Enum.Font.GothamBold
		t.Parent = g
		g.Parent = a
		a.Parent = groups.labels
	end

	-- Ground: main floor east of the pond/creek, west strip split around them.
	part("ground", "FloorMain", Vector3.new(170, 2, 200), Vector3.new(35, -1, 0), colors.grass)
	part("ground", "FloorWestNorth", Vector3.new(34, 2, 5), Vector3.new(-111, -1, -97.5), colors.grass)
	part("ground", "FloorWestOuter", Vector3.new(26, 2, 200), Vector3.new(-107, -1, 0), colors.grass)
	part("ground", "FloorPondEast", Vector3.new(7, 2, 70), Vector3.new(-53.5, -1, -65), colors.grass)
	part("ground", "FloorCreekWest", Vector3.new(14, 2, 130), Vector3.new(-87, -1, 35), colors.grass)
	part("ground", "FloorCreekEast", Vector3.new(16, 2, 130), Vector3.new(-58, -1, 35), colors.grass)
	part("ground", "SouthRimLip", Vector3.new(240, 3, 4), Vector3.new(0, 0.5, 102), colors.grass)
	part("ground", "SouthCliffFace", Vector3.new(260, 44, 6), Vector3.new(0, -22, 106), colors.cliffDark)
	part("ground", "SouthInvisibleWall", Vector3.new(240, 30, 2), Vector3.new(0, 15, 101), colors.grass, { transparency = 1 })
	part("ground", "WestInvisibleWall", Vector3.new(2, 30, 200), Vector3.new(-121, 15, 0), colors.grass, { transparency = 1 })
	label("Arrival / spawn (looks north)", Vector3.new(0, 8, 78))

	-- Water: pond (west), waterfall from the north cliff, creek south to the rim.
	part("water", "PondBasin", Vector3.new(38, 2, 72), Vector3.new(-75, -4, -65), colors.cliffDark)
	part("water", "PondWater", Vector3.new(36, 1, 70), Vector3.new(-75, -1.5, -65), colors.water, { transparency = 0.25, collide = false })
	part("water", "PondIsland", Vector3.new(4, 12, 12), Vector3.new(-76, -1, -60), colors.grass, { shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, 0, math.rad(90)) })
	part("water", "Waterfall", Vector3.new(12, 56, 2), Vector3.new(-75, 27, -99), colors.water, { transparency = 0.15, collide = false })
	part("water", "WaterfallFoam", Vector3.new(16, 1, 6), Vector3.new(-75, -0.8, -95), Color3.new(1, 1, 1), { collide = false })
	part("water", "CreekBed", Vector3.new(14, 2, 130), Vector3.new(-73, -3, 35), colors.cliffDark)
	part("water", "CreekWater", Vector3.new(12, 1, 130), Vector3.new(-73, -1.5, 35), colors.water, { transparency = 0.25, collide = false })
	part("water", "Sea", Vector3.new(2000, 1, 2000), Vector3.new(0, -40, 900), colors.sea, { collide = false })
	label("Pond + island", Vector3.new(-75, 10, -62))
	label("Waterfall", Vector3.new(-75, 60, -92))

	-- Creek crossings: a bridge and stepping stones.
	part("props", "Bridge", Vector3.new(16, 1, 10), Vector3.new(-73, 0.5, 10), colors.wood)
	for i, z in ipairs({ 55, 61, 67 }) do
		part("props", "SteppingStone" .. i, Vector3.new(1, 5, 5), Vector3.new(-77 + i * 2, -0.5, z), colors.path, { shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, 0, math.rad(90)) })
	end
	label("Creek crossing", Vector3.new(-73, 8, 10))

	-- Cliff ring: staggered blocks on the north and east, cave gap in the north.
	local northX = { { -120, -88, 62 }, { -88, -40, 56 }, { -40, 10, 64 }, { 30, 70, 58 }, { 70, 125, 66 } }
	for i, s in ipairs(northX) do
		local w = s[2] - s[1]
		part("cliffs", "North" .. i, Vector3.new(w, s[3], 22), Vector3.new((s[1] + s[2]) / 2, s[3] / 2, -111), if i % 2 == 0 then colors.cliffDark else colors.cliff)
	end
	part("cliffs", "CaveLintel", Vector3.new(20, 40, 22), Vector3.new(20, 40, -111), colors.cliff)
	part("cliffs", "CaveBack", Vector3.new(20, 20, 4), Vector3.new(20, 10, -120), colors.cliffDark)
	label("Cave mouth (blocked for v1)", Vector3.new(20, 24, -98))
	local eastZ = { { -100, -55, 60 }, { -55, -5, 54 }, { -5, 45, 62 }, { 45, 100, 50 } }
	for i, s in ipairs(eastZ) do
		local d = s[2] - s[1]
		part("cliffs", "East" .. i, Vector3.new(22, s[3], d), Vector3.new(131, s[3] / 2, (s[1] + s[2]) / 2), if i % 2 == 0 then colors.cliffDark else colors.cliff)
	end
	part("cliffs", "NECorner", Vector3.new(30, 70, 30), Vector3.new(128, 35, -108), colors.cliff)
	part("cliffs", "WestOutcrop", Vector3.new(18, 30, 40), Vector3.new(-129, 15, -80), colors.cliffDark)

	-- East terraces against the cliff, with ramps.
	part("terraces", "TerraceLow", Vector3.new(40, 8, 80), Vector3.new(100, 4, -20), colors.grass)
	part("terraces", "TerraceHigh", Vector3.new(30, 16, 50), Vector3.new(105, 8, -75), colors.grass)
	part("terraces", "RampLow", Vector3.new(10, 8, 24), Vector3.new(68, 4, 8), colors.grass, { class = "WedgePart", rot = CFrame.Angles(0, math.rad(90), 0) })
	part("terraces", "RampHigh", Vector3.new(10, 8, 20), Vector3.new(100, 12, -40), colors.grass, { class = "WedgePart", rot = CFrame.Angles(0, math.rad(180), 0) })
	part("terraces", "RestNookRoof", Vector3.new(16, 2, 14), Vector3.new(112, 18, 10), colors.cliff)
	part("terraces", "RestNookPostA", Vector3.new(2, 9, 2), Vector3.new(105, 12.5, 4), colors.wood)
	part("terraces", "RestNookPostB", Vector3.new(2, 9, 2), Vector3.new(105, 12.5, 16), colors.wood)
	label("Low terrace + rest nook", Vector3.new(100, 16, -10))
	label("High terrace lookout", Vector3.new(105, 26, -75))

	-- West stepping pillars up to a lookout ledge above the pond.
	for i, h in ipairs({ 4, 8, 12, 16, 20 }) do
		part("props", "Pillar" .. i, Vector3.new(h, 7, 7), Vector3.new(-108, h / 2, 40 - i * 9), colors.path, { shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, 0, math.rad(90)) })
	end
	part("props", "PillarLedge", Vector3.new(18, 22, 12), Vector3.new(-110, 11, -16), colors.cliff)
	label("Stepping pillars to ledge", Vector3.new(-108, 30, 10))

	-- Landmark tree, visible from everywhere.
	part("props", "LandmarkTrunk", Vector3.new(26, 5, 5), Vector3.new(10, 13, -30), colors.wood, { shape = Enum.PartType.Cylinder, rot = CFrame.Angles(0, 0, math.rad(90)) })
	part("props", "LandmarkCanopy", Vector3.new(30, 30, 30), Vector3.new(10, 32, -30), colors.leaf, { shape = Enum.PartType.Ball })
	label("Landmark tree / hatch tree", Vector3.new(10, 52, -30))

	-- Hub stations on the arrival lawn, readable from spawn.
	local stations = {
		{ "CareMachine", Vector3.new(8, 8, 8), Vector3.new(-30, 4, 45), "Care machine" },
		{ "Workbench", Vector3.new(10, 4, 5), Vector3.new(30, 2, 45), "Deck workbench" },
		{ "JournalStand", Vector3.new(4, 5, 3), Vector3.new(50, 2.5, 25), "Journal" },
		{ "PlayBench", Vector3.new(12, 3, 4), Vector3.new(0, 1.5, 55), "Handheld bench" },
		{ "ToyLawn", Vector3.new(30, 0.2, 30), Vector3.new(-15, 0.1, 10), "Shared toy lawn" },
	}
	for _, s in ipairs(stations) do
		part("stations", s[1], s[2], s[3], s[1] == "ToyLawn" and colors.path or colors.station)
		label(s[4], s[3] + Vector3.new(0, s[2].Y / 2 + 6, 0))
	end
	part("props", "PathToTree", Vector3.new(8, 0.2, 80), Vector3.new(5, 0.1, 20), colors.path)
	for i, x in ipairs({ -40, 60, 85, -20 }) do
		part("props", "Lantern" .. i, Vector3.new(1, 8, 1), Vector3.new(x, 4, 70 - i * 20), colors.wood)
	end

	-- Scale reference: R15-height avatar (5.5) and a v1 baby (1.5) at spawn.
	part("scale", "Avatar_5_5", Vector3.new(2, 5.5, 1), Vector3.new(-4, 2.75, 72), colors.ref)
	part("scale", "Baby_1_5", Vector3.new(1.4, 1.5, 1.2), Vector3.new(-1, 0.75, 72), colors.ref)

	local spawnPivot = Instance.new("Part")
	spawnPivot.Name = "GreyboxSpawn"
	spawnPivot.Anchored, spawnPivot.CanCollide, spawnPivot.Transparency, spawnPivot.Size = true, false, 1, Vector3.new(4, 1, 4)
	spawnPivot.CFrame = CFrame.lookAt(origin + Vector3.new(0, 3, 80), origin + Vector3.new(0, 3, 0))
	spawnPivot.Parent = model
	model.PrimaryPart = spawnPivot
	model.Parent = parent
	return model
end
