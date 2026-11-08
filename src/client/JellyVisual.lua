local Jelly = {}
Jelly.__index = Jelly
local JellyPalette=require(game:GetService("ReplicatedStorage").Shared.JellyPalette)

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
	local palette=JellyPalette.resolve(source.Color)
	local self = setmetatable({
		model = model,
		radius = source.Size.X / 2,
		axis = Vector2.yAxis,
		strength = 0.23,
		age = 0,
		phase = source:GetAttribute("EggId") * 0.8,
		rim = layer(model, "GelRim", palette.rim),
		lower=layer(model,"GelLower",palette.lower),
		body = layer(model, "GelBody", palette.body),
		glint = layer(model, "GelGlint", palette.glint),
		fleck = layer(model, "GelFleck", palette.upper),
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

function Jelly:render(position, dt, now, _, _, reduced)
	self.age += dt
	local squeeze = if reduced then 0 else self.strength * math.exp(-5.7 * self.age) * math.cos(self.age * 19)
	local breathe = if reduced then 0 else math.sin(now * 2.1 + self.phase) * 0.014
	local width, height = 1 + squeeze * 0.55 - breathe, 1 - squeeze + breathe
	local r = self.radius
	local axis = Vector3.new(self.axis.X, self.axis.Y, 0)
	local center = position - axis * (r * squeeze * 0.7)
	local turn = if reduced then 0 else math.atan2(-self.axis.X, self.axis.Y)
	local tilt = if reduced then 0 else math.sin(self.age * 24) * math.exp(-6 * self.age) * self.strength * 0.4
	local transform = CFrame.new(center) * CFrame.Angles(0, 0, turn + tilt)
	local diameter = r * 2
	pose(self.rim, transform, Vector3.new(width, height, 0.74) * diameter)
	pose(self.lower,transform*CFrame.new(0,0,r*.12),Vector3.new(width*.93,height*.90,.76)*diameter)
	pose(self.body, transform * CFrame.new(0, r * 0.16 * height, r * 0.22),
		Vector3.new(width * 0.88, height * 0.77, 0.70) * diameter)
	-- Counter-rotate the glints toward the light as the gel stretches.
	local glintAngle = -turn - tilt
	local lightX = -0.28 * math.cos(glintAngle) - 0.43 * math.sin(glintAngle)
	local lightY = -0.28 * math.sin(glintAngle) + 0.43 * math.cos(glintAngle)
	local highlight = transform * CFrame.new(r * lightX * width, r * lightY * height, r * 1.02)
	pose(self.glint, highlight * CFrame.Angles(0, 0, glintAngle - 0.35),
		Vector3.new(width * 0.22, height * 0.09, 0.08) * diameter)
	-- A broad colored lobe sits behind the tight cream light, both toward the
	-- fixed upper-left lamp while the original rim retains its spring silhouette.
	pose(self.fleck,transform*CFrame.new(r*lightX*.75*width,r*lightY*.75*height,r*.94),Vector3.new(width*.40,height*.28,.08)*diameter)
	return center
end

function Jelly:destroy()
	self.model:Destroy()
end

return Jelly
