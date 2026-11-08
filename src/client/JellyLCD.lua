-- One tiny transparent framebuffer shared by every jelly on the board.
local AssetService = game:GetService("AssetService")
local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
local SpanSurface = require(script.Parent.JellySpanSurface)
local JellyPalette=require(game:GetService("ReplicatedStorage").Shared.JellyPalette)

local LCD = {}
LCD.__index = LCD
LCD.Width = 64
LCD.Height = math.round(LCD.Width * (Config.Height + 0.8) / (Config.Width + 0.8))
LCD.MergeDuration = 0.32

local WIDTH, HEIGHT = LCD.Width, LCD.Height
local SIZE = Vector2.new(WIDTH, HEIGHT)
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

local palettes={}
local paletteCount=0
local function palette(color)
	local key=rgba(color);local cached=palettes[key]
	if cached then return cached end
	local roles=JellyPalette.resolve(color)
	cached={rgba(roles.rim),rgba(roles.lower),rgba(roles.body),rgba(roles.upper),rgba(roles.glint)}
	if paletteCount<64 then palettes[key]=cached;paletteCount+=1 end
	return cached
end

local defaultBoard={outside=Color3.fromHex("#2C4D30"),base=Color3.fromHex("#C6DFA0"),dither=Color3.fromHex("#BBD395"),rail=Color3.fromHex("#749154"),rim=Color3.fromHex("#385632"),guide=Color3.fromHex("#54783E")}
local boardRoles={"outside","base","dither","rail","rim"}
local function boardPixels(colors)
 colors=colors or defaultBoard
	local pixels = buffer.create(WIDTH * HEIGHT * 4)
	local outside = rgba(colors.outside)
	local background = rgba(colors.base)
	local dither = rgba(colors.dither)
	local rail = rgba(colors.rail)
	local rim = rgba(colors.rim)
	for y = 0, HEIGHT - 1 do
		local inset = math.max(0, bank - (floor - (y + 0.5)))
		for x = 0, WIDTH - 1 do
			local edge = math.min(x + 0.5 - leftWall - inset, rightWall - inset - x - 0.5, floor - y - 0.5)
			local color = outside
			if edge > 0 then
				color = if y % 7 == 0 and x % 7 == (math.floor(y / 7) % 2) * 3 then dither else background
			elseif edge > -1.8 then
				color = if edge > -0.8 then rail else rim
			end
			buffer.writeu32(pixels, (y * WIDTH + x) * 4, color)
		end
	end
	return pixels
end

local guide = rgba(Color3.fromHex("#54783E"))

-- Sampling is clipped before entering the loops: work never exceeds the fixed 64x107 grid.
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
				elseif ((lightX + 0.28) / 0.22) ^ 2 + ((lightY + 0.43) / 0.14) ^ 2 < 1 then
					tone = 5
				elseif ((lightX + 0.35) / 0.57) ^ 2 + ((lightY + 0.36) / 0.4) ^ 2 < 1 then
					tone = 4
				end
				buffer.writeu32(self.pixels, (y * WIDTH + x) * 4, colors[tone])
			end
		end
	end
end

function LCD.new(parent, options)
	options=options or {}
	local background=boardPixels(options.palette)
	local function span()
		local pixels=buffer.create(WIDTH*HEIGHT*4)
		local surface=SpanSurface.new(parent,background,WIDTH,HEIGHT,options.maxSpans or 1536)
		if not surface then return nil end
		return setmetatable({surface=surface,label=surface.root,background=background,pixels=pixels,failed=false,backend="span",boardPalette=options.palette or defaultBoard,guideColor=rgba((options.palette or defaultBoard).guide)},LCD)
	end
	if options.backend=="span"then return span()end
	local editable,label
	local ok=pcall(function()
		editable=AssetService:CreateEditableImage({Size=SIZE})
		if not editable then error("EditableImage allocation unavailable")end
		-- Allocation alone can succeed while the experience cannot access writes.
		-- Establish capability before choosing the image owner; never change settings.
		editable:WritePixelsBuffer(Vector2.zero,SIZE,background)
		label=Instance.new("ImageLabel");label.Name="JellyLCD";label.BackgroundTransparency=1;label.BorderSizePixel=0
		label.Size,label.Position=UDim2.fromScale(1,1),UDim2.fromScale(0,0);label.ZIndex,label.Visible=3,false
		label.ResampleMode=Enum.ResamplerMode.Pixelated;label.ImageContent=Content.fromObject(editable);label.Parent=parent
	end)
	if not ok then
		if label then label:Destroy()end;if editable then editable:Destroy()end
		return if options.backend=="image"then nil else span()
	end
	return setmetatable({image=editable,label=label,background=background,pixels=buffer.create(WIDTH*HEIGHT*4),failed=false,backend="image",boardPalette=options.palette or defaultBoard,guideColor=rgba((options.palette or defaultBoard).guide)},LCD)
end
-- Recolor the existing board, cached static rectangles and already painted
-- frame together. The live gel pixels and bounded dynamic pool are retained.
function LCD:setPalette(colors)
 if self.destroyed or self.failed then return false end
 if self.boardPalette==colors then return true end
 local seen,replacements={},{}
 for _,role in ipairs(boardRoles)do
  if typeof(colors[role])~="Color3"then return false end
  local value=rgba(colors[role]);if seen[value]then return false end;seen[value]=true
  replacements[rgba(self.boardPalette[role])]=value
 end
 if typeof(colors.guide)~="Color3"then return false end
 local background=boardPixels(colors);local oldGuide,newGuide=self.guideColor,rgba(colors.guide)
 if not self.painted then buffer.copy(self.pixels,0,background)else
  for y=0,HEIGHT-1 do for x=0,WIDTH-1 do
   local offset=(y*WIDTH+x)*4;local pixel=buffer.readu32(self.pixels,offset)
   if pixel==buffer.readu32(self.background,offset)then buffer.writeu32(self.pixels,offset,buffer.readu32(background,offset))
   elseif pixel==oldGuide and x==self.guideX and y>=self.guideFirst and y<=self.guideLast and (y-self.guideFirst)%4==0 then buffer.writeu32(self.pixels,offset,newGuide)end
  end end
 end
 local ok=pcall(function()
  if self.surface then
   assert(self.surface:setBackground(background,replacements));assert(self.surface:paint(self.pixels))
  else self.image:WritePixelsBuffer(Vector2.zero,SIZE,self.pixels)end
 end)
 if not ok then self.failed=true;self.label.Visible=false;return false end
 self.background,self.boardPalette,self.guideColor=background,colors,newGuide;return true
end
function LCD:getStats()
	return if self.surface then self.surface.stats else{backend=self.backend,failed=self.failed}
end

function LCD:beginFrame()
 self.guideX=nil
	self.rasterStarted=os.clock()
	buffer.copy(self.pixels, 0, self.background)
end

function LCD:drawGuide(center)
	local x = math.floor(center.X)
	local limit = math.floor(floor - math.max(0, bank - (x + 0.5 - leftWall), bank - (rightWall - x - 0.5)))
	self.guideX,self.guideFirst,self.guideLast=x,math.floor(center.Y)+1,limit
 for y = self.guideFirst, limit, 4 do
		buffer.writeu32(self.pixels, (y * WIDTH + x) * 4, self.guideColor)
	end
end

function LCD:draw(center, radiusX, radiusY, angleRadians, color, ripple)
	if self.failed or radiusX <= 0 or radiusY <= 0 then return end
	local c, s = math.cos(angleRadians), math.sin(angleRadians)
	local wobble = math.clamp(ripple or 0, -1, 1) * 0.075
	local lightRadiusX=math.sqrt((radiusX*c)^2+(radiusY*s)^2)
	local lightRadiusY=math.sqrt((radiusX*s)^2+(radiusY*c)^2)
	local extentX,extentY=lightRadiusX*1.09+1,lightRadiusY*1.09+1
	local scale = math.min(radiusX, radiusY)
	raster(self, center.X - extentX, center.Y - extentY, center.X + extentX, center.Y + extentY,
		palette(color), function(x, y)
			local dx, dy = x - center.X, y - center.Y
			local nx, ny = (dx * c + dy * s) / radiusX, (-dx * s + dy * c) / radiusY
			local q = nx * nx + ny * ny
			if q > 1.19 then return 1, 0, 0 end
			-- A bounded polynomial ripple gives a soft asymmetric edge without per-pixel trig.
			local edge = 1 + wobble * (nx * nx - ny * ny) * nx
			-- Only inside/rim classification is consumed by raster; squared tests
			-- produce exactly the same classes without a square root per pixel.
			if q>edge*edge then return 1,0,0 end
			local inner=math.max(0,edge-.85/scale)
			return if q>inner*inner then -.5 else -1,dx/lightRadiusX,dy/lightRadiusY
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
	local lightRadiusX=math.max(core,math.abs(a.X-target.X)+lobe,math.abs(b.X-target.X)+lobe)+blend
	local lightRadiusY=math.max(core,math.abs(a.Y-target.Y)+lobe,math.abs(b.Y-target.Y)+lobe)+blend
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
			return d,tx/lightRadiusX,ty/lightRadiusY
		end)
end

function LCD:finishFrame()
	if self.failed then return false end
	local rasterMs=(os.clock()-(self.rasterStarted or os.clock()))*1000
	if self.surface then self.surface.stats.rasterMs=rasterMs end
	local ok
	if self.surface then
		local painted,result=pcall(self.surface.paint,self.surface,self.pixels);ok=painted and result
		if not painted then self.surface.stats.failure="paint-error";self.surface.failed=true end
	else
		ok=pcall(function()self.image:WritePixelsBuffer(Vector2.zero,SIZE,self.pixels)end)
	end
	if not ok then
		self.failed = true
		self.label.Visible = false
	end
	if ok then self.painted=true end
	return ok
end

function LCD:destroy()
	if self.destroyed then return end
	self.destroyed=true
	self.failed = true
	if self.surface then self.surface:destroy()else self.label:Destroy();self.image:Destroy()end
end

return LCD
