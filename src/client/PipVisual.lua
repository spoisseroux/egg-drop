-- Original Pip stand-in. Origin is the floor; the face looks along +Z.
-- The host owns the render connection, interaction, and synth greeting cue.
local PipVisual = {}
PipVisual.__index = PipVisual

local COLORS = {
	ink = Color3.fromRGB(53, 47, 79),
	cream = Color3.fromRGB(255, 231, 174),
	shell = Color3.fromRGB(255, 244, 216),
	shellShade = Color3.fromRGB(214, 199, 166),
	green = Color3.fromRGB(116, 185, 113),
	leafLight = Color3.fromRGB(183, 219, 127),
	leafDark = Color3.fromRGB(65, 116, 92),
	peach = Color3.fromRGB(235, 153, 131),
}

local function piece(self, name, size, frame, color, rounded, role)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = name == "Body"
	part.CastShadow = true
	part.Material = Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = color
	part.Size = size
	if rounded then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = self.model
	table.insert(self.pieces, { part = part, size = size, frame = frame, role = role })
	return part
end

function PipVisual.new(parent, origin, pet)
	local isBloom = pet and pet.id == "bloom_pip"
	local bodyColor = if isBloom then pet.color else COLORS.cream
	local model = Instance.new("Model")
	model.Name = if isBloom then pet.name else "Pip"
	model:SetAttribute("PetFamily", "Pip")
	local self = setmetatable({
		model = model,
		origin = origin,
		pieces = {},
		time = 0,
		greeting = 2,
		lastFrame = -1,
	}, PipVisual)

	-- Tiny moss slippers support a wide, bottom-heavy egg silhouette.
	for _, side in ipairs({ -1, 1 }) do
		piece(self, "Slipper", Vector3.new(0.57, 0.28, 0.70),
			CFrame.new(side * 0.49, 0.14, 0.20), COLORS.leafDark, true)
	end
	local body = piece(self, "Body", Vector3.new(1.83, 2.06, 1.56),
		CFrame.new(0, 1.43, 0), bodyColor, true)
	model.PrimaryPart = body
	-- A dark lower rim gives the broken shell a readable pixel-scale outline.
	piece(self, "ShellRim", Vector3.new(2.01, 0.98, 1.73),
		CFrame.new(0, 0.67, 0), COLORS.ink, true)
	piece(self, "ShellBowl", Vector3.new(1.96, 0.94, 1.68),
		CFrame.new(0, 0.72, 0), COLORS.shell, true)
	for i = 0, 9 do
		local theta = i * math.pi * 2 / 10
		local frame = CFrame.new(math.sin(theta) * 0.81, 1.00, math.cos(theta) * 0.67)
			* CFrame.Angles(0, theta, math.rad(45))
		piece(self, "ShellTooth", Vector3.new(0.38, 0.38, 0.22), frame,
			if i % 3 == 0 then COLORS.shellShade else COLORS.shell, false)
	end
	for _, side in ipairs({ -1, 1 }) do
		piece(self, "Flipper", Vector3.new(0.30, 0.64, 0.40),
			CFrame.new(side * 0.91, 1.19, 0.06) * CFrame.Angles(0, 0, side * 0.22),
			bodyColor, true, if side == -1 then "wave" else nil)
		piece(self, "Eye", Vector3.new(0.23, 0.34, 0.09),
			CFrame.new(side * 0.35, 1.66, 0.745), COLORS.ink, false, "eye")
		piece(self, "EyeSpark", Vector3.new(0.065, 0.075, 0.035),
			CFrame.new(side * 0.35 - 0.035, 1.74, 0.80), COLORS.shell, false, "spark")
		piece(self, "Cheek", Vector3.new(0.22, 0.12, 0.055),
			CFrame.new(side * 0.58, 1.43, 0.655), COLORS.peach, false)
	end
	piece(self, "Smile", Vector3.new(0.18, 0.065, 0.055),
		CFrame.new(0, 1.37, 0.79), COLORS.ink, false)
	for _, side in ipairs({ -1, 1 }) do
		piece(self, "SmileCorner", Vector3.new(0.055, 0.09, 0.055),
			CFrame.new(side * 0.10, 1.405, 0.79), COLORS.ink, false)
	end
	-- The sprig leans left. Two broad leaf lobes read even without color.
	local crown = CFrame.new(-0.03, 2.36, 0) * CFrame.Angles(0, 0, math.rad(24))
	piece(self, "SprigStem", Vector3.new(0.14, 0.65, 0.16),
		crown * CFrame.new(0, 0.26, 0), COLORS.leafDark, false, "sprig")
	piece(self, "WideLeaf", Vector3.new(0.72, 0.25, 0.40),
		crown * CFrame.new(-0.26, 0.49, 0) * CFrame.Angles(0, 0, -0.30),
		COLORS.green, true, "sprig")
	piece(self, "NewLeaf", Vector3.new(0.53, 0.22, 0.33),
		crown * CFrame.new(0.22, 0.59, 0) * CFrame.Angles(0, 0, 0.58),
		COLORS.leafLight, true, "sprig")
	piece(self, "LeafPixel", Vector3.new(0.22, 0.055, 0.16),
		crown * CFrame.new(-0.26, 0.60, 0.09) * CFrame.Angles(0, 0, -0.30),
		COLORS.leafLight, false, "sprig")
	if isBloom then
		local bloom = crown * CFrame.new(0.03, 0.86, 0.09)
		for index = 0, 4 do
			local angle = index * math.pi * 2 / 5
			piece(self, "Petal", Vector3.new(0.28, 0.40, 0.18),
				bloom * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.20, 0), bodyColor, true, "sprig")
		end
		piece(self, "Pollen", Vector3.new(0.22, 0.22, 0.18),
			bloom * CFrame.new(0, 0, 0.10), COLORS.cream, true, "sprig")
	end
	model.Parent = parent
	self:update(0)
	return self
end

function PipVisual:greet()
	self.greeting = 0
	self.lastFrame = -1
	self:update(0)
end

function PipVisual:update(dt)
	if not self.model.Parent then
		return
	end
	if dt ~= dt or dt == math.huge or dt < 0 then
		dt = 0
	end
	self.time += dt
	self.greeting += dt
	local frame = math.floor(self.time * 12)
	if frame == self.lastFrame then
		return
	end
	self.lastFrame = frame
	local t = frame / 12
	local g = self.greeting
	local bounce, squash, wave = 0, 0, 0
	if g < 0.18 then
		squash = 0.12 * math.sin(g / 0.18 * math.pi / 2)
	elseif g < 0.76 then
		local u = (g - 0.18) / 0.58
		bounce = 0.56 * math.sin(u * math.pi)
		squash = -0.10 * math.sin(u * math.pi)
		wave = math.sin(u * math.pi) * 0.85
	elseif g < 1.25 then
		local u = (g - 0.76) / 0.49
		squash = 0.12 * math.sin(u * math.pi) * (1 - u)
	end
	local breathe = math.sin(t * 2.2) * 0.012
	local scale = Vector3.new(1 + squash * 0.48 - breathe, 1 - squash + breathe, 1 + squash * 0.30)
	local root = CFrame.new(self.origin + Vector3.new(0, bounce, 0))
		* CFrame.Angles(0, math.sin(t * 1.1) * 0.035, math.sin(t * 1.8) * 0.025)
	local blink = (t % 4.8 > 4.62) or (g > 0.30 and g < 0.61)
	for _, entry in ipairs(self.pieces) do
		local rest = entry.frame
		local pose = CFrame.new(rest.Position * scale) * rest.Rotation
		local size = entry.size * scale
		if entry.role == "wave" then
			pose *= CFrame.Angles(0, 0, -wave)
		elseif entry.role == "sprig" then
			-- Rotation around its base prevents the sprig from sliding off the head.
			local base = CFrame.new(Vector3.new(0, 2.36, 0) * scale)
			pose = base * CFrame.Angles(0, 0, math.sin(t * 2.5) * 0.045 + wave * 0.12)
				* base:Inverse() * pose
		elseif entry.role == "eye" and blink then
			size = Vector3.new(size.X, 0.065, size.Z)
		end
		entry.part.Transparency = if entry.role == "spark" and blink then 1 else 0
		entry.part.Size = size
		entry.part.CFrame = root * pose
	end
end

function PipVisual:destroy()
	self.model:Destroy()
end

return PipVisual
