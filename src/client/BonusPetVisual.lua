local Visual = {}
Visual.__index = Visual
local GREET_TIME = 0.86
local flameHinge = CFrame.new(0, 1.8, 0)

local function piece(self, name, size, offset, color, ball, animated)
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Color = color
	part.Material = Enum.Material.SmoothPlastic
	if ball then
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = part
	end
	part.Parent = self.model
	table.insert(self.pieces, { part = part, offset = offset, animated = animated })
	return part
end

function Visual.new(parent, origin, pet)
	local model = Instance.new("Model")
	model.Name = pet.name
	model:SetAttribute("PetFamily", if pet.family == "wick" then "Wick" elseif pet.family == "orbit" then "Orbit" else pet.name)
	local self = setmetatable({ model = model, origin = origin, pieces = {}, time = 0, greeting = 0, lastFrame = -1 }, Visual)
	local ink = Color3.fromHex("#392846")
	local wick = pet.id == "wick" or pet.family == "wick"
	self.wick = wick
	model.PrimaryPart = piece(self, "Body", Vector3.new(1.9, 1.8, 1.55), CFrame.new(0, 1.2, 0), pet.color, true)
	for _, side in ipairs({ -1, 1 }) do
		piece(self, "Foot", Vector3.new(0.53, 0.24, 0.64), CFrame.new(side * 0.52, 0.18, 0.25), pet.color, true)
		piece(self, "Eye", Vector3.new(0.13, 0.21, 0.07), CFrame.new(side * 0.28, 1.38, 0.72), ink)
		piece(self, "Cheek", Vector3.new(0.23, 0.08, 0.07), CFrame.new(side * 0.44, 1.12, 0.70),
			if wick then Color3.fromHex("#FFD0A2") else Color3.fromHex("#F4D2F5"), true)
	end
	piece(self, "Mouth", Vector3.new(0.15, 0.07, 0.07), CFrame.new(0, 1.13, 0.77), ink)
	if pet.id == "foxfire_wick" then
		for _, side in ipairs({ -1, 1 }) do
			local tip = CFrame.new(side * 0.36, 2.15, -0.04) * CFrame.Angles(0, 0, -side * 0.48)
			piece(self, "Foxfire", Vector3.new(0.55, 1.18, 0.52), tip, pet.accent, true, true)
			piece(self, "FoxfireCore", Vector3.new(0.28, 0.68, 0.32), tip * CFrame.new(0, -0.18, 0.17),
				Color3.fromHex("#E5FFF9"), true, true)
		end
	elseif wick then
		piece(self, "Flame", Vector3.new(0.78, 1.19, 0.7), CFrame.new(0.17, 2.12, -0.08)
			* CFrame.Angles(0, 0, math.rad(-24)), Color3.fromHex("#F6C557"), true, true)
		piece(self, "FlameCore", Vector3.new(0.35, 0.54, 0.36), CFrame.new(0.19, 2.03, 0.23),
			Color3.fromHex("#FFF1AD"), true, true)
	else
		for index = 0, 13 do
			local angle = index * math.pi * 2 / 14
			local x, z = math.cos(angle) * 1.12, math.sin(angle) * 0.91
			piece(self, "OrbitRing", Vector3.new(0.49, 0.12, 0.31),
				CFrame.new(x, 0.93 + x * 0.26, z) * CFrame.Angles(0, -angle + math.pi / 2, 0),
				pet.accent or Color3.fromHex("#806BBA"), true)
		end
		piece(self, "Moon", Vector3.new(0.37, 0.37, 0.37), CFrame.new(1.1, 1.47, 0.47),
			if pet.accent then Color3.fromHex("#292249") else Color3.fromHex("#FFF0AF"), true, true)
		if pet.id == "eclipse_orbit" then
			piece(self, "MoonHalo", Vector3.new(0.46, 0.46, 0.24), CFrame.new(1.03, 1.51, 0.40), pet.accent, true, true)
		end
	end
	self:update(0)
	model.Parent = parent
	return self
end

function Visual:greet()
	self.greeting = GREET_TIME
end

function Visual:update(dt)
	self.time += dt
	self.greeting = math.max(0, self.greeting - dt)
	local frame = math.floor(self.time * 24)
	if frame == self.lastFrame then
		return
	end
	self.lastFrame = frame
	local hop = 0
	local flourish = CFrame.identity
	if self.greeting > 0 then
		local phase = 1 - self.greeting / GREET_TIME
		if self.wick then
			hop = 0.52 * math.sin(phase * math.pi * 2) ^ 2
			local flick = 0.34 * math.sin(phase * math.pi * 4) * math.sin(phase * math.pi)
			flourish = flameHinge * CFrame.Angles(0, 0, flick) * flameHinge:Inverse()
		else
			hop = 0.70 * math.sin(phase * math.pi)
			local sweep = phase * phase * (3 - 2 * phase)
			flourish = CFrame.Angles(0, sweep * math.pi * 2, 0)
		end
	end
	local pivot = CFrame.new(self.origin + Vector3.new(0, hop + 0.045 * (1 + math.sin(self.time * 4)), 0))
		* CFrame.Angles(0, (self.yaw or 0) + math.sin(self.time * 2.4) * 0.08, math.sin(self.time * 3) * (0.03 + hop * 0.19))
	for _, item in ipairs(self.pieces) do
		item.part.CFrame = pivot * (if item.animated then flourish * item.offset else item.offset)
	end
end

function Visual:destroy()
	self.model:Destroy()
end

return Visual
