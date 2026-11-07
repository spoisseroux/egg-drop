-- Original Droplet Puddle: a low gel body and a raised, waving water tail.
-- Origin is the floor; the face looks along +Z. The host drives update().
local Bounds=require(script.Parent.PetRigBounds)
local PuddleVisual = {}
PuddleVisual.__index = PuddleVisual

local COLORS = {
	gel = Color3.fromRGB(147, 209, 238),
	deep = Color3.fromRGB(92, 164, 202),
	light = Color3.fromRGB(211, 245, 252),
	ink = Color3.fromRGB(43, 47, 76),
	cheek = Color3.fromRGB(166, 183, 232),
}

local function piece(self, name, size, frame, color, rounded, role)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = name == "Body"
	part.CastShadow = role ~= "ripple"
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

function PuddleVisual.new(parent, position, _pet, worldScale)
	local model = Instance.new("Model")
	model.Name = "Puddle"
	model:SetAttribute("PetFamily", "Puddle")
	local self = setmetatable({
		model = model,
		worldScale = worldScale or 1, worldContext=worldScale~=nil,
		origin = position,
		pieces = {},
		time = 0,
		greeting = 3,
		lastFrame = -1,
	}, PuddleVisual)

	-- Broad liquid skirt and overlapping lobes keep the silhouette low and soft.
	piece(self, "PuddleSkirt", Vector3.new(2.55, 0.34, 1.91),
		CFrame.new(0, 0.18, 0), COLORS.deep, true)
	local body = piece(self, "Body", Vector3.new(2.39, 1.65, 1.82),
		CFrame.new(-0.06, 0.91, 0), COLORS.gel, true)
	model.PrimaryPart = body
	for _, side in ipairs({ -1, 1 }) do
		piece(self, "LiquidLobe", Vector3.new(0.64, 0.34, 0.73),
			CFrame.new(side * 0.89, 0.23, 0.45), COLORS.gel, true)
	end

	-- The narrow root and swollen tip form one unmistakable sideways droplet.
	-- It sits behind the cheek, out to the right where the lounge camera sees it.
	piece(self, "TailRoot", Vector3.new(1.00, 0.36, 0.43),
		CFrame.new(1.07, 0.54, -0.25) * CFrame.Angles(0, 0, 0.28), COLORS.deep, true, "tail")
	piece(self, "TailDrop", Vector3.new(0.55, 0.84, 0.53),
		CFrame.new(1.62, 0.92, -0.25) * CFrame.Angles(0, 0, -0.48), COLORS.gel, true, "tail")
	piece(self, "TailGlint", Vector3.new(0.14, 0.27, 0.045),
		CFrame.new(1.67, 1.09, 0.005) * CFrame.Angles(0, 0, -0.48), COLORS.light, true, "tail")

	-- Surface-mounted eyes tilt upward slightly to meet the elevated camera.
	for _, side in ipairs({ -1, 1 }) do
		local eye = CFrame.new(side * 0.38 - 0.06, 1.11, 0.855)
			* CFrame.Angles(-0.15, side * 0.12, 0)
		piece(self, "Eye", Vector3.new(0.23, 0.31, 0.09), eye, COLORS.ink, false, "eye")
		piece(self, "EyeSpark", Vector3.new(0.065, 0.075, 0.035),
			eye * CFrame.new(0.025, 0.07, 0.06), COLORS.light, false, "spark")
		piece(self, "Cheek", Vector3.new(0.25, 0.10, 0.06),
			CFrame.new(side * 0.66 - 0.06, 0.88, 0.77), COLORS.cheek, true)
	end
	piece(self, "Smile", Vector3.new(0.17, 0.055, 0.07),
		CFrame.new(-0.06, 0.82, 0.92), COLORS.ink, false)
	for _, side in ipairs({ -1, 1 }) do
		piece(self, "SmileCorner", Vector3.new(0.05, 0.085, 0.065),
			CFrame.new(side * 0.10 - 0.06, 0.85, 0.915), COLORS.ink, false)
	end
	-- Creamy, opaque highlights read as gel without transparent sorting artifacts.
	piece(self, "GelGlint", Vector3.new(0.48, 0.12, 0.28),
		CFrame.new(-0.43, 1.59, 0.34) * CFrame.Angles(0.38, 0, -0.15), COLORS.light, true)
	piece(self, "GelGlintDot", Vector3.new(0.13, 0.08, 0.14),
		CFrame.new(-0.08, 1.68, 0.22), COLORS.light, true)

	-- A reusable segmented ring lives on the mat, never grows the instance count.
	for i = 0, 23 do
		local theta = i * math.pi * 2 / 24
		piece(self, "GreetingRipple", Vector3.new(0.31, 0.035, 0.055),
			CFrame.new(math.sin(theta), 0.035, math.cos(theta))
				* CFrame.Angles(0, theta, 0), COLORS.light, false, "ripple")
	end
	model.Parent = parent
	self:update(0)
	return self
end

function PuddleVisual:greet()
	self.greeting = 0
	self.lastFrame = -1
	self:update(0)
end

function PuddleVisual:update(dt)
	if not self.model.Parent then
		return
	end
	if dt ~= dt or dt == math.huge or dt < 0 then
		dt = 0
	end
	self.time += dt
	self.greeting += dt
	-- Position, heading and pose update every render frame while following.
	local t, g = self.time, self.greeting
	local squash, bounce, wave = 0, 0, 0
	if g < 0.20 then
		squash = 0.18 * math.sin(g / 0.20 * math.pi / 2)
	elseif g < 0.72 then
		local u = (g - 0.20) / 0.52
		bounce = 0.36 * math.sin(u * math.pi)
		squash = -0.14 * math.sin(u * math.pi)
	elseif g < 1.50 then
		local u = (g - 0.72) / 0.78
		squash = 0.16 * math.cos(u * math.pi * 3) * (1 - u) ^ 2
	end
	if g < 1.50 then
		wave = math.sin(g * 15) * math.sin(g / 1.50 * math.pi) * 0.48
	end
	local reduced=self.reducedEffects==true
	if reduced then bounce,squash,wave=0,0,0 end
	local gait=self.gaitWeight or 0;local stride=self.gaitPhase or 0
	squash+=math.sin(stride*2)*.025*gait
	local worldScale=self.worldScale
	local breathe = if reduced then 0 else math.sin(t * 2.1) * 0.018
	local scale = Vector3.new(1 + squash * 0.55 - breathe * 0.4, 1 - squash + breathe, 1 + squash * 0.30)
	local root = CFrame.new(self.origin + Vector3.new(0, bounce*worldScale, 0))
		* CFrame.Angles(0, (self.yaw or 0) + (if reduced then 0 else math.sin(t * 0.9) * 0.025), 0)
	local blink = t % 5.1 > 4.93
	local tailBase = CFrame.new(Vector3.new(0.90, 0.49, -0.25) * scale)
	if self.worldContext then Bounds.begin(self)end
	for _, entry in ipairs(self.pieces) do
		local rest = entry.frame
		local pose = CFrame.new(rest.Position * scale) * rest.Rotation
		local size = entry.size * scale
		local transparency = 0
		if entry.role == "ripple" then
			local u = (g - 0.72) / 0.80
			local radius = 1.1 + math.clamp(u, 0, 1) * 0.85
			pose = CFrame.new(rest.X * radius, rest.Y, rest.Z * radius * 0.78) * rest.Rotation
			size = Vector3.new(entry.size.X * radius, entry.size.Y, entry.size.Z)
			transparency = if not reduced and u >= 0 and u < 1 then 0.20 + u * 0.80 else 1
			entry.part.CFrame = CFrame.new(self.origin) * (CFrame.new(pose.Position*worldScale)*pose.Rotation)
		else
			if entry.role == "tail" then
				pose = tailBase * CFrame.Angles(0, 0, (if reduced then 0 else math.sin(t * 2.8) * 0.06) + wave)
					* tailBase:Inverse() * pose
			elseif entry.role == "eye" and blink then
				size = Vector3.new(size.X, 0.055, size.Z)
			elseif entry.role == "spark" and blink then
				transparency = 1
			end
			entry.part.CFrame = root * (CFrame.new(pose.Position*worldScale)*pose.Rotation)
		end
		entry.part.Size = size*worldScale
		entry.part.Transparency = transparency
		if self.worldContext and entry.role~="ripple"then Bounds.include(self,entry.part.CFrame,entry.part.Size)end
	end
	if self.worldContext then Bounds.finish(self)end
end

function PuddleVisual:destroy()
	self.model:Destroy()
end

return PuddleVisual
