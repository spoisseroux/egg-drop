local Sprite = {}
Sprite.__index = Sprite

local function layer(parent, name, color, position, size, z)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.Position = position
	frame.Size = size
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.ZIndex = z
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = frame
	frame.Parent = parent
	return frame
end

function Sprite.new(parent, source)
	local color = source.Color
	local deep = color:Lerp(Color3.fromRGB(17, 27, 45), 0.68)
	local body = layer(parent, source.Name, deep, UDim2.fromOffset(0, 0), UDim2.fromOffset(0, 0), 3)
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	local inner = layer(body, "Gel", Color3.new(1, 1, 1), UDim2.fromScale(0.055, 0.05),
		UDim2.fromScale(0.89, 0.88), 3)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, color:Lerp(Color3.new(1, 1, 1), 0.45)),
		ColorSequenceKeypoint.new(0.49, color),
		ColorSequenceKeypoint.new(1, color:Lerp(deep, 0.44)),
	})
	shade.Parent = inner
	local glint = layer(body, "Glint", Color3.fromRGB(255, 250, 236), UDim2.fromScale(0.2, 0.16),
		UDim2.fromScale(0.33, 0.105), 3)
	glint.Rotation = -20
	local fleck = layer(body, "Fleck", Color3.fromRGB(255, 250, 236), UDim2.fromScale(0.58, 0.15),
		UDim2.fromScale(0.12, 0.09), 3)
	fleck.BackgroundTransparency = 0.2
	return setmetatable({
		body = body,
		glint = glint,
		radius = source.Size.X / 2,
		position = source.Position,
		axis = Vector2.yAxis,
		strength = 0.16,
		age = 0,
		phase = source:GetAttribute("EggId") * 0.73,
	}, Sprite)
end

function Sprite:impact(normal, speed)
	self.axis = normal
	self.strength = math.clamp(speed / 34, 0.16, 0.48)
	self.age = 0
end

function Sprite:render(position, dt, now, project, drawSprite)
	self.age += dt
	local delta = position - self.position
	self.position = self.position:Lerp(position, 1 - math.exp(-34 * dt))
	local stretch = math.clamp(-delta.Y / self.radius * 0.22, 0, 0.15)
	local wave = self.strength * math.exp(-4.7 * self.age)
	local floorSqueeze = if self.axis.Y > 0.85
		then 0.09 * math.clamp(1 - (position.Y - self.radius) / 0.15, 0, 1)
		else 0
	local squeeze = wave * math.cos(self.age * 17) + floorSqueeze - stretch
	local breathe = math.sin(now * 2.4 + self.phase) * 0.017
	local offset = self.axis * self.radius * squeeze * 0.82
	local center = self.position - Vector3.new(offset.X, offset.Y, 0)
	local height = math.clamp(1 - squeeze + breathe, 0.56, 1.48)
	local angle = math.atan2(self.axis.X, self.axis.Y) + math.sin(self.age * 19) * wave * 0.44
	if drawSprite then
		local point, pixels = project(Vector2.new(center.X, center.Y))
		local diameter = self.radius * pixels * 2
		self.body.Position = UDim2.fromOffset(point.X, point.Y)
		self.body.Size = UDim2.fromOffset(diameter / height, diameter * height)
		self.body.Rotation = math.deg(angle)
		self.glint.Position = UDim2.fromScale(0.2 - squeeze * 0.12, 0.16 + squeeze * 0.09)
	end
	return center, 1 / height, height, angle, math.sin(self.age * 20) * wave * 2
end

function Sprite:destroy()
	self.body:Destroy()
end

return Sprite
