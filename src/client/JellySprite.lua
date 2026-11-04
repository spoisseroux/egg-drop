local Sprite = {}
Sprite.__index = Sprite

local rows = 16

local function block(parent, name, color)
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BorderSizePixel = 0
	frame.BackgroundColor3 = color
	frame.ZIndex = 3
	frame.Parent = parent
	return frame
end

function Sprite.new(parent, source)
	local body = block(parent, source.Name, source.Color)
	body.BackgroundTransparency = 1
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	local color = source.Color
	local rimColor = color:Lerp(Color3.fromRGB(40, 29, 67), 0.55)
	for index = 0, rows - 1 do
		local y = (index + 0.5) / rows
		local half = math.floor(math.sqrt(1 - (2 * y - 1) ^ 2) * rows / 2 + 0.5) / rows
		local rim = block(body, "Rim", rimColor)
		rim.Position = UDim2.fromScale(0.5 - half, index / rows)
		rim.Size = UDim2.fromScale(2 * half, 1 / rows)
		if index > 0 and index < rows - 1 then
			local shade = if index < 5 then color:Lerp(Color3.new(1, 1, 1), 0.25)
				elseif index > 10 then color:Lerp(rimColor, 0.28)
				else color
			local fill = block(rim, "Gel", shade)
			local inset = 1 / rows / (2 * half)
			fill.Position = UDim2.fromScale(inset, 0)
			fill.Size = UDim2.fromScale(1 - inset * 2, 1)
		end
	end
	local white = color:Lerp(Color3.new(1, 1, 1), 0.83)
	local glint = block(body, "Glint", white)
	glint.Position = UDim2.fromScale(4 / rows, 3 / rows)
	glint.Size = UDim2.fromScale(5 / rows, 1 / rows)
	local fleck = block(body, "Fleck", white)
	fleck.Position = UDim2.fromScale(3 / rows, 4 / rows)
	fleck.Size = UDim2.fromScale(2 / rows, 1 / rows)
	return setmetatable({
		body = body,
		radius = source.Size.X / 2,
		axis = Vector2.yAxis,
		strength = 0.22,
		age = 0,
		phase = source:GetAttribute("EggId") * 0.73,
	}, Sprite)
end

function Sprite:impact(normal, speed)
	self.axis = normal
	self.strength = math.clamp(speed / 38, 0.16, 0.55)
	self.age = 0
end

function Sprite:render(position, dt, now, project)
	self.age += dt
	local squeeze = self.strength * math.exp(-4.6 * self.age) * math.cos(self.age * 18)
	local breathe = math.sin(now * 2.5 + self.phase) * 0.018
	local offset = self.axis * self.radius * squeeze * 0.86
	local center = position - Vector3.new(offset.X, offset.Y, 0)
	local point, pixels = project(Vector2.new(center.X, center.Y))
	local diameter = self.radius * pixels * 2
	self.body.Position = UDim2.fromOffset(point.X, point.Y)
	self.body.Size = UDim2.fromOffset(diameter * (1 + squeeze * 0.78 - breathe),
		diameter * (1 - squeeze + breathe))
	self.body.Rotation = math.deg(math.atan2(self.axis.X, self.axis.Y))
		+ math.sin(self.age * 21) * math.exp(-5 * self.age) * self.strength * 36
	return center
end

function Sprite:destroy()
	self.body:Destroy()
end

return Sprite
