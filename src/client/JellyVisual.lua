local Jelly = {}
Jelly.__index = Jelly

local function layer(parent, name, color)
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.CastShadow = false
	part.Color = color
	part.Size = Vector3.one

	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = part
	part.Parent = parent
	return { part = part, mesh = mesh }
end

function Jelly.new(parent, source)
	local model = Instance.new("Model")
	model.Name = source.Name
	local color = source.Color
	local self = setmetatable({
		model = model,
		radius = source.Size.X / 2,
		axis = Vector2.yAxis,
		strength = 0.23,
		age = 0,
		phase = source:GetAttribute("EggId") * 0.8,
		rim = layer(model, "GelRim", color:Lerp(Color3.fromRGB(53, 47, 99), 0.44)),
		body = layer(model, "GelBody", color),
		glint = layer(model, "GelGlint", color:Lerp(Color3.new(1, 1, 1), 0.75)),
		fleck = layer(model, "GelFleck", color:Lerp(Color3.new(1, 1, 1), 0.62)),
	}, Jelly)
	model.Parent = parent
	return self
end

function Jelly:impact(normal, speed)
	self.axis = normal
	self.strength = math.clamp(speed / 55, 0.13, 0.43)
	self.age = 0
end

local function pose(layerPart, transform, scale)
	layerPart.part.CFrame = transform
	layerPart.mesh.Scale = scale
end

function Jelly:render(position, dt, now)
	self.age += dt
	local squeeze = self.strength * math.exp(-5.7 * self.age) * math.cos(self.age * 19)
	local breathe = math.sin(now * 2.1 + self.phase) * 0.014
	local width, height = 1 + squeeze * 0.55 - breathe, 1 - squeeze + breathe
	local r = self.radius
	local axis = Vector3.new(self.axis.X, self.axis.Y, 0)
	local center = position - axis * (r * squeeze * 0.7)
	local turn = math.atan2(-self.axis.X, self.axis.Y)
	local tilt = math.sin(self.age * 24) * math.exp(-6 * self.age) * self.strength * 0.4
	local transform = CFrame.new(center) * CFrame.Angles(0, 0, turn + tilt)
	local diameter = r * 2
	pose(self.rim, transform, Vector3.new(width, height, 0.74) * diameter)
	pose(self.body, transform * CFrame.new(0, r * 0.05 * height, r * 0.12),
		Vector3.new(width * 0.93, height * 0.9, 0.76) * diameter)
	-- Counter-rotate the glints toward the light as the gel stretches.
	local glintAngle = -turn - tilt
	local lightX = -0.28 * math.cos(glintAngle) - 0.31 * math.sin(glintAngle)
	local lightY = -0.28 * math.sin(glintAngle) + 0.31 * math.cos(glintAngle)
	local highlight = transform * CFrame.new(r * lightX * width, r * lightY * height, r * 0.78)
	pose(self.glint, highlight * CFrame.Angles(0, 0, glintAngle - 0.35),
		Vector3.new(width * 0.31, height * 0.13, 0.08) * diameter)
	pose(self.fleck, highlight * CFrame.new(r * 0.37, r * 0.15, -r * 0.02), Vector3.one * r * 0.15)
	return center
end

function Jelly:destroy()
	self.model:Destroy()
end

return Jelly
