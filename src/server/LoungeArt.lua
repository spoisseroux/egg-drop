local Art = {}

local ink = Color3.fromHex("#111A23")
local graphite = Color3.fromHex("#263644")
local blue = Color3.fromHex("#223E55")
local steel = Color3.fromHex("#536A7D")
local silver = Color3.fromHex("#AFC4CE")
local cyan = Color3.fromHex("#54D9F3")
local amber = Color3.fromHex("#FFC75A")

local function sign(parent, words, tint, subtitle)
	local screen = Instance.new("SurfaceGui")
	screen.Face = Enum.NormalId.Back
	screen.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	screen.CanvasSize = Vector2.new(640, 120)
	screen.LightInfluence = 0
	screen.Parent = parent

	local function line(name, value, y, height, color, font)
		local text = Instance.new("TextLabel")
		text.Name = name
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(0.9, height)
		text.Position = UDim2.fromScale(0.05, y)
		text.Text = value
		text.TextColor3 = color
		text.TextScaled = true
		text.Font = font
		text.Parent = screen
	end

	line("Heading", words, if subtitle then 0.07 else 0.15, if subtitle then 0.54 else 0.7, tint, Enum.Font.GothamBold)
	if subtitle then
		line("Index", subtitle, 0.66, 0.21, silver, Enum.Font.Code)
	end
end

local function lamp(part, color, range, brightness)
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Parent = part
end

function Art.build(room, part)
	local function box(name, x, y, z, w, h, d, color, collides, material)
		local item = part(room, name, Vector3.new(w, h, d), CFrame.new(x, y, z), color, collides)
		item.CanTouch = false
		item.CanQuery = collides == true
		item.Material = material or Enum.Material.SmoothPlastic
		return item
	end
	local function rail(name, x, y, z, w, h, d, color)
		return box(name, x, y, z, w, h, d, color, false, Enum.Material.Neon)
	end
	local function disk(name, x, y, z, diameter, height, color, material)
		local item = box(name, x, y, z, height, diameter, diameter, color, false, material)
		item.Shape = Enum.PartType.Cylinder
		item.CFrame *= CFrame.Angles(0, 0, math.pi / 2)
		return item
	end

	box("Floor", 0, 3.5, 0, 40, 1, 32, graphite, true)
	box("BackWall", 0, 10, -15.5, 40, 13, 1, ink, true)
	box("RearCrown", 0, 15.75, -14.7, 40, 1.35, 2.4, graphite, false, Enum.Material.Metal)
	box("Ceiling", 0, 16.8, 0, 40, 0.65, 32, graphite)
	box("CeilingInlay", 0, 16.43, 0, 23.4, 0.12, 29.3, ink)
	box("FrontRail", 0, 5, 15.6, 40, 2, 0.7, graphite, true)
	box("FrontWall", 0, 10.4, 16.25, 40, 13.3, 0.55, graphite, true)
	box("RearInset", 0, 9.1, -14.87, 35.5, 10.4, 0.22, graphite)
	box("DisplayBezel", 0, 10.15, -14.66, 22.6, 8, 0.30, steel, false, Enum.Material.Metal)
	box("DisplayGlass", 0, 10.15, -14.46, 22, 7.48, 0.2, blue)
	rail("DisplayScanEdge", 0, 13.62, -14.30, 20.9, 0.055, 0.05, cyan)
	for _, side in ipairs({ -1, 1 }) do
		box("SideWall", side * 19.5, 6.5, 0, 1, 5, 32, graphite, true)
		box("RimCap", side * 19.5, 9.05, 0, 1.12, 0.16, 31.6, steel)
		box("UpperWall", side * 19.5, 12.75, 0, 1, 7.5, 32, blue, true)
		for z = -12, 12, 6 do
			box("WallRib", side * 18.92, 12.72, z, 0.14, 7.25, 0.13, steel)
		end
		local ceilingPanel = rail("CeilingPanel", side * 6.2, 16.32, -1.7, 0.18, 0.09, 17.4, silver)
		local softLight = Instance.new("SurfaceLight")
		softLight.Face = Enum.NormalId.Bottom
		softLight.Angle = 140
		softLight.Brightness = 0.95
		softLight.Range = 24
		softLight.Color = Color3.fromHex("#CEE9FF")
		softLight.Parent = ceilingPanel
		box("RearTower", side * 17.2, 9.6, -14.45, 2.5, 11, 0.95, graphite, false, Enum.Material.Metal)
		box("TowerInset", side * 17.2, 9.55, -13.92, 1.75, 8.8, 0.18, ink)
		local towerLight = rail("TowerLamp", side * 17.2, 10.15, -13.77, 0.12, 5.2, 0.10, cyan)
		lamp(towerLight, cyan, 14, 0.55)
		for i = 1, 4 do
			box("RearVent", side * (12 + i * 0.55), 6.25, -14.67, 0.22, 3, 0.12, steel)
		end
		for _, x in ipairs({ 11.7, 14.3 }) do
			box("BenchFoot", side * x, 4.32, 6.5, 0.32, 0.64, 1.98, steel)
		end
		box("Bench", side * 13, 4.69, 6.5, 7, 0.64, 2.8, ink, true)
		box("BenchBack", side * 13, 5.30, 5.31, 7, 1.22, 0.42, graphite, true)
		for index = -1, 1 do
			box("BenchCushion", side * 13 + index * 2.14, 5.08, 6.61, 2.03, 0.25, 2.12, Color3.fromHex("#385976"))
		end
		rail("BenchTrim", side * 13, 4.58, 7.92, 6.5, 0.045, 0.05, cyan)
		rail("AisleTrace", side * 3.8, 4.035, 3.0, 0.065, 0.025, 13.0, cyan)
		rail("BranchTrace", side * 7.35, 4.035, -1.25, 7.05, 0.025, 0.065, cyan)
	end

	-- Pixel artwork inset in the rear display. The steps echo the deck's LCD.
	local silhouette = { 0.6, 0.85, 0.7, 1.3, 1.05, 0.8, 1.6, 1.2, 0.72, 1.0, 0.64, 0.87 }
	for i, height in ipairs(silhouette) do
		for _, side in ipairs({ -1, 1 }) do
			box("CircuitSilhouette", side * (2.85 + i * 0.63), 6.62 + height / 2, -14.30,
				0.57, height, 0.04, graphite)
		end
	end
	local marquee = box("Marquee", 0, 11.4, -14.21, 15.1, 1.87, 0.12, ink)
	sign(marquee, "POCKET CLUB", silver, "EGG DROP   /   SOCIAL ARCADE")
	rail("MarqueePin", 0, 10.42, -14.13, 13.6, 0.055, 0.055, cyan)
	for row, pixels in ipairs({ "..X..", ".....", "..X..", ".....", "..X..", ".X.X.", "X...X", "X..XX", ".XXX." }) do
		for column = 1, #pixels do
			if pixels:sub(column, column) == "X" then
				box("EggInsignia", (column - 3) * 0.18, 10.05 - row * 0.18, -14.29, 0.17, 0.17, 0.045, cyan)
			end
		end
	end

	for i = 1, 9 do
		box("AisleTile", 0, 4.013, 9.85 - i * 1.41, 7.42, 0.025, 1.34,
			if i % 2 == 0 then graphite else blue)
	end
	disk("HatchBase", 0, 4.09, -5, 7.5, 0.18, ink, Enum.Material.Metal)
	disk("HatchRing", 0, 4.165, -5, 7.03, 0.075, amber, Enum.Material.Neon)
	local hatchTop = disk("HatchTop", 0, 4.19, -5, 6.82, 0.08, graphite, Enum.Material.Slate)
	hatchTop.CanCollide, hatchTop.CanQuery = true, true
	local display = box("HatchDisplay", 0, 8.06, -9.55, 6.65, 1.12, 0.3, ink)
	sign(display, "HATCHERY", amber)
	for _, side in ipairs({ -1, 1 }) do
		box("HatchColumn", side * 3.0, 6.06, -9.55, 0.31, 4.24, 0.42, steel)
		rail("HatchTrim", side * 3.02, 6.13, -9.31, 0.07, 3.6, 0.06, amber)
	end
	local stageLight = box("StageLamp", 0, 7.3, -3.1, 0.1, 0.1, 0.1, amber)
	stageLight.Transparency = 1
	lamp(stageLight, Color3.fromHex("#FFE7B6"), 12, 0.65)

	for _, station in ipairs({
		{ x = -11, id = "Customize", label = "DECK WORKBENCH", tint = cyan, index = "01" },
		{ x = 11, id = "Journal", label = "PET JOURNAL", tint = amber, index = "02" },
	}) do
		local x, id, tint = station.x, station.id, station.tint
		box(id .. "Counter", x, 4.68, -6.3, 6.8, 1.35, 2.4, graphite, true, Enum.Material.Metal)
		box(id .. "Kickplate", x, 4.28, -5.07, 6.3, 0.24, 0.08, ink)
		rail(id .. "Edge", x, 5.10, -5.06, 6.3, 0.058, 0.07, tint)
		local top = box(id .. "Top", x, 5.45, -6.3, 7.1, 0.23, 2.62, steel, true)
		box(id .. "ScreenFrame", x, 6.63, -7.44, 6.82, 1.32, 0.29, steel)
		sign(box(id .. "Sign", x, 6.63, -7.25, 6.52, 1.05, 0.12, ink), station.label, tint, station.index)
		for i = -1, 1 do
			local itemX = x + i * 1.72
			box(id .. "DisplayTile", itemX, 5.62, -6.22, 1.18, 0.11, 0.83, ink)
			if id == "Customize" then
				local chip = box("SampleDeck", itemX, 5.78, -6.23, 0.76, 0.20, 0.57, blue:Lerp(tint, (i + 2) * 0.22))
				chip.CFrame *= CFrame.Angles(0, i * 0.24, 0)
			else
				local specimen = box("Specimen", itemX, 5.91, -6.23, 0.6, 0.53, 0.52, tint:Lerp(cyan, (i + 1) * 0.38))
				specimen.Shape = Enum.PartType.Ball
			end
		end
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = if id == "Customize" then "Customize" else "Open journal"
		prompt.ObjectText = if id == "Customize" then "Deck workbench" else "Pet journal"
		prompt.RequiresLineOfSight = false
		prompt.MaxActivationDistance = 7
		prompt:SetAttribute("PocketClubStation", id)
		prompt.Parent = top
	end
end

return Art
