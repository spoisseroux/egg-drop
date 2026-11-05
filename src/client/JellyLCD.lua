-- One tiny transparent framebuffer shared by every jelly on the board.
local AssetService = game:GetService("AssetService")
local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)

local LCD = {}
LCD.__index = LCD
LCD.Width = 84
LCD.Height = 112
LCD.MergeDuration = 0.32

local WIDTH, HEIGHT = LCD.Width, LCD.Height
local SIZE = Vector2.new(WIDTH, HEIGHT)
local WHITE = Color3.fromHex("#F4F8E9")
local INK = Color3.fromHex("#142D20")
local leftWall = WIDTH * 0.4 / (Config.Width + 0.8)
local rightWall = WIDTH - leftWall
local ceiling = HEIGHT * 0.4 / (Config.Height + 0.8)
local floor = HEIGHT - ceiling
local bank = Config.Bank * HEIGHT / (Config.Height + 0.8)

local function rgba(color)
	return math.floor(color.R * 255 + 0.5)
		+ math.floor(color.G * 255 + 0.5) * 256
		+ math.floor(color.B * 255 + 0.5) * 65536
		+ 4278190080
end

local function palette(color)
	return { rgba(color:Lerp(INK, 0.65)), rgba(color:Lerp(INK, 0.27)),
		rgba(color), rgba(color:Lerp(WHITE, 0.7)) }
end

local function boardPixels()
	local pixels = buffer.create(WIDTH * HEIGHT * 4)
	local outside = rgba(Color3.fromHex("#2C4D30"))
	local background = rgba(Color3.fromHex("#C6DFA0"))
	local dither = rgba(Color3.fromHex("#BBD395"))
	local rail = rgba(Color3.fromHex("#749154"))
	local rim = rgba(Color3.fromHex("#385632"))
	local warning = rgba(Color3.fromHex("#8B652D"))
	local warningY = math.floor(floor - Config.OverflowY * HEIGHT / (Config.Height + 0.8))
	for y = 0, HEIGHT - 1 do
		local inset = math.max(0, bank - (floor - (y + 0.5)))
		for x = 0, WIDTH - 1 do
			local edge = math.min(x + 0.5 - leftWall - inset, rightWall - inset - x - 0.5, floor - y - 0.5)
			local color = outside
			if edge > 0 then
				color = if y == warningY and x % 5 < 3 then warning
					elseif y % 7 == 0 and x % 7 == (math.floor(y / 7) % 2) * 3 then dither else background
			elseif edge > -1.8 then
				color = if edge > -0.8 then rail else rim
			end
			buffer.writeu32(pixels, (y * WIDTH + x) * 4, color)
		end
	end
	return pixels
end

local guide = rgba(Color3.fromHex("#54783E"))

-- Sampling is clipped before entering the loops: work never exceeds 84x112.
local function raster(self, minX, minY, maxX, maxY, colors, sample)
	if self.failed then return end
	minX, minY = math.max(math.ceil(leftWall - 0.5), math.floor(minX)),
		math.max(math.ceil(ceiling - 0.5), math.floor(minY))
	maxX, maxY = math.min(math.floor(rightWall - 0.5), math.ceil(maxX)),
		math.min(math.floor(floor - 0.5), math.ceil(maxY))
	for y = minY, maxY do
		local inset = math.max(0, bank - (floor - (y + 0.5)))
		local rowStart = math.max(minX, math.ceil(leftWall + inset - 0.5))
		local rowEnd = math.min(maxX, math.floor(rightWall - inset - 0.5))
		for x = rowStart, rowEnd do
			local distance, lightX, lightY = sample(x + 0.5, y + 0.5)
			if distance <= 0 then
				local tone = 3
				if distance > -0.85 then
					tone = 1
				elseif lightY + lightX * 0.25 > 0.36 then
					tone = 2
				elseif ((lightX + 0.28) / 0.34) ^ 2 + ((lightY + 0.4) / 0.16) ^ 2 < 1 then
					tone = 4
				end
				buffer.writeu32(self.pixels, (y * WIDTH + x) * 4, colors[tone])
			end
		end
	end
end

function LCD.new(parent)
	local editable, label
	local ok = pcall(function()
		editable = AssetService:CreateEditableImage({ Size = SIZE })
		if not editable then error("EditableImage allocation unavailable") end
		label = Instance.new("ImageLabel")
		label.Name = "JellyLCD"
		label.BackgroundTransparency = 1
		label.BorderSizePixel = 0
		label.Size = UDim2.fromScale(1, 1)
		label.Position = UDim2.fromScale(0, 0)
		label.ZIndex = 3
		label.Visible = false
		label.ResampleMode = Enum.ResamplerMode.Pixelated
		label.ImageContent = Content.fromObject(editable)
		label.Parent = parent
	end)
	if not ok then
		if label then label:Destroy() end
		if editable then editable:Destroy() end
		return nil
	end
	return setmetatable({
		image = editable, label = label, background = boardPixels(),
		pixels = buffer.create(WIDTH * HEIGHT * 4), failed = false,
	}, LCD)
end

function LCD:beginFrame()
	buffer.copy(self.pixels, 0, self.background)
end

function LCD:drawGuide(center)
	local x = math.floor(center.X)
	local limit = math.floor(floor - math.max(0, bank - (x + 0.5 - leftWall), bank - (rightWall - x - 0.5)))
	for y = math.floor(center.Y) + 1, limit, 4 do
		buffer.writeu32(self.pixels, (y * WIDTH + x) * 4, guide)
	end
end

function LCD:draw(center, radiusX, radiusY, angleRadians, color, ripple)
	if self.failed or radiusX <= 0 or radiusY <= 0 then return end
	local c, s = math.cos(angleRadians), math.sin(angleRadians)
	local wobble = math.clamp(ripple or 0, -1, 1) * 0.075
	local extentX = math.sqrt((radiusX * c) ^ 2 + (radiusY * s) ^ 2) * 1.09 + 1
	local extentY = math.sqrt((radiusX * s) ^ 2 + (radiusY * c) ^ 2) * 1.09 + 1
	local scale = math.min(radiusX, radiusY)
	raster(self, center.X - extentX, center.Y - extentY, center.X + extentX, center.Y + extentY,
		palette(color), function(x, y)
			local dx, dy = x - center.X, y - center.Y
			local nx, ny = (dx * c + dy * s) / radiusX, (-dx * s + dy * c) / radiusY
			local q = nx * nx + ny * ny
			if q > 1.19 then return 1, 0, 0 end
			-- A bounded polynomial ripple gives a soft asymmetric edge without per-pixel trig.
			local edge = 1 + wobble * (nx * nx - ny * ny) * nx
			return (math.sqrt(q) - edge) * scale, nx, ny
		end)
end

local function smoothMin(a, b, k)
	local h = math.max(k - math.abs(a - b), 0) / k
	return math.min(a, b) - h * h * k * 0.25
end

local function capsule(x, y, a, b, radius)
	local dx, dy = b.X - a.X, b.Y - a.Y
	local lengthSquared = dx * dx + dy * dy
	local t = 0
	if lengthSquared > 0.0001 then
		t = math.clamp(((x - a.X) * dx + (y - a.Y) * dy) / lengthSquared, 0, 1)
	end
	local px, py = x - a.X - dx * t, y - a.Y - dy * t
	return math.sqrt(px * px + py * py) - radius
end

function LCD:merge(first, second, target, radius, resultRadius, color, age)
	if self.failed or radius <= 0 then return end
	local t = math.clamp(age / LCD.MergeDuration, 0, 1)
	t = t * t * (3 - 2 * t)
	local a, b = first:Lerp(target, t), second:Lerp(target, t)
	local lobe = radius * (0.90 - 0.70 * t)
	local core = radius * 0.42 * (1 - t) + resultRadius * t
	local neck = radius * (0.22 + 0.12 * t)
	local blend = math.max(0.5, radius * 0.22 * (1 - t))
	local margin = math.max(radius, resultRadius) + blend + 1
	raster(self, math.min(a.X, b.X, target.X) - margin, math.min(a.Y, b.Y, target.Y) - margin,
		math.max(a.X, b.X, target.X) + margin, math.max(a.Y, b.Y, target.Y) + margin,
		palette(color), function(x, y)
			local ax, ay, bx, by = x - a.X, y - a.Y, x - b.X, y - b.Y
			local tx, ty = x - target.X, y - target.Y
			local d = smoothMin(math.sqrt(ax * ax + ay * ay) - lobe,
				math.sqrt(bx * bx + by * by) - lobe, blend)
			d = smoothMin(d, capsule(x, y, a, target, neck), blend)
			d = smoothMin(d, capsule(x, y, b, target, neck), blend)
			d = smoothMin(d, math.sqrt(tx * tx + ty * ty) - core, blend)
			return d, tx / radius, ty / radius
		end)
end

function LCD:finishFrame()
	if self.failed then return false end
	local ok = pcall(function()
		self.image:WritePixelsBuffer(Vector2.zero, SIZE, self.pixels)
	end)
	if not ok then
		self.failed = true
		self.label.Visible = false
	end
	return ok
end

function LCD:destroy()
	self.failed = true
	self.label:Destroy()
	self.image:Destroy()
end

return LCD
