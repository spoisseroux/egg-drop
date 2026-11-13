-- One tiny transparent framebuffer shared by every jelly on the board.
-- Redesign (UI-SPEC-REDESIGN-MENUS 6): no rail or rim rows round the well, a
-- banded vertical gradient with a top inner shadow, lighter banks, and vivid
-- eggs with no outline: a deep / body / light ramp, a glint, a per-tier motif
-- and a one-level bloom that only ever lands on untouched well pixels.
-- Ball themes (batch 2026-11-13 R1): `draw` with a `face` record paints the
-- equipped BallThemes look: cleaner face shading (one glint, deep lower right,
-- light crescent, rim light on the three larger sizes), an upright crude face
-- from BallFaces, cat ears, a star on power-up balls. No numerals, no motifs
-- (Marbles keeps today's motif shading). Before painting, a frame whose span
-- demand is over SimplifyAbove is re-rastered with simpler faces; only a frame
-- still over the surface cap takes the sticky failure path.
local AssetService = game:GetService("AssetService")
local Config = require(game:GetService("ReplicatedStorage").Shared.BoardConfig)
local SpanSurface = require(script.Parent.JellySpanSurface)
local JellyPalette=require(game:GetService("ReplicatedStorage").Shared.JellyPalette)
local BallThemes=require(game:GetService("ReplicatedStorage").Shared.BallThemes)
local BallFaces=require(script.Parent.BallFaces)

local LCD = {}
LCD.__index = LCD
LCD.Width = 64
LCD.Height = math.round(LCD.Width * (Config.Height + 0.8) / (Config.Width + 0.8))
LCD.MergeDuration = 0.32
-- Bloom: each egg throws its own colour onto the well (1.28 r, about 30%); the
-- egg that matches the held one throws its light colour further and stronger.
LCD.BloomReach, LCD.BloomAlpha = 1.28, 0.3
LCD.MatchReach, LCD.MatchAlpha = 1.5, 0.6
-- Well: the gradient is a fixed set of bands so the static geometry never
-- depends on the plate (palette swaps recolor rectangles, never rebuild them).
LCD.ShadowRows, LCD.GradientBands = 4, 12
-- Span budget (BUILD-PLAN architect change 2): over 1350 a frame is re-rastered
-- with simpler faces (eyes only on the two smallest sizes, kitten ears from size 3).
LCD.SimplifyAbove = 1350
LCD.EarReach = 1.32

local WIDTH, HEIGHT = LCD.Width, LCD.Height
local SIZE = Vector2.new(WIDTH, HEIGHT)
local leftWall = WIDTH * 0.4 / (Config.Width + 0.8)
local rightWall = WIDTH - leftWall
local ceiling = HEIGHT * 0.4 / (Config.Height + 0.8)
local floor = HEIGHT - ceiling
local bank = Config.Bank * HEIGHT / (Config.Height + 0.8)
local BLACK, WHITE = Color3.new(0, 0, 0), Color3.new(1, 1, 1)

local function rgba(color)
	return math.floor(color.R * 255 + 0.5)
		+ math.floor(color.G * 255 + 0.5) * 256
		+ math.floor(color.B * 255 + 0.5) * 65536
		+ 4278190080
end

-- Packed ARGB blend; integer maths only, no allocation.
local function mix(a, b, t)
	local ar, ag, ab = a % 256, math.floor(a / 256) % 256, math.floor(a / 65536) % 256
	local br, bg, bb = b % 256, math.floor(b / 256) % 256, math.floor(b / 65536) % 256
	return math.floor(ar + (br - ar) * t + 0.5) + math.floor(ag + (bg - ag) * t + 0.5) * 256
		+ math.floor(ab + (bb - ab) * t + 0.5) * 65536 + 4278190080
end
LCD.mix = mix

-- Egg tones, indexed by role. [6] is the motif kind (JellyPalette.Motifs).
local DEEP, BODY, LIGHT, GLINT, MOTIF, KIND = 1, 2, 3, 4, 5, 6
local palettes={}
local paletteCount=0
local function palette(color)
	local key=rgba(color);local cached=palettes[key]
	if cached then return cached end
	local roles=JellyPalette.resolve(color)
	cached={rgba(roles.deep),rgba(roles.body),rgba(roles.light),rgba(roles.glint),rgba(roles.motif),roles.motifKind or 1}
	if paletteCount<64 then palettes[key]=cached;paletteCount+=1 end
	return cached
end
LCD.tones = palette

-- Ring of dots for tier V, in light space (precomputed; no trig per pixel).
local ringDots = {}
for k = 0, 5 do
	local angle = k * math.pi / 3 + math.pi / 6
	ringDots[k * 2 + 1], ringDots[k * 2 + 2] = math.cos(angle) * 0.6, math.sin(angle) * 0.6
end
local function motifAt(kind, lx, ly)
	if kind == 2 then -- two soft bands
		return (ly > -0.06 and ly < 0.08) or (ly > 0.26 and ly < 0.38)
	elseif kind == 3 then -- speckles
		return (lx - 0.34) ^ 2 + (ly + 0.14) ^ 2 < 0.014 or (lx + 0.16) ^ 2 + (ly - 0.38) ^ 2 < 0.014
			or (lx - 0.42) ^ 2 + (ly - 0.16) ^ 2 < 0.01
	elseif kind == 4 then -- two stars (diamonds at this grid)
		return math.abs(lx - 0.3) + math.abs(ly + 0.02) < 0.15 or math.abs(lx + 0.12) + math.abs(ly - 0.4) < 0.12
	elseif kind == 5 then -- ring of dots
		for k = 1, 11, 2 do
			if (lx - ringDots[k]) ^ 2 + (ly - ringDots[k + 1]) ^ 2 < 0.012 then return true end
		end
	end
	return false
end

-- lx, ly: offset over the lit extents (-1..1, upper-left negative); q: ellipse radius squared.
local function shade(tones, lx, ly, q)
	if ((lx + 0.28) / 0.22) ^ 2 + ((ly + 0.43) / 0.14) ^ 2 < 1 then return tones[GLINT] end
	-- The small dot sits just above the glint and left of centre, clear of the mark.
	if ((lx + 0.1) / 0.07) ^ 2 + ((ly + 0.64) / 0.07) ^ 2 < 1 then return tones[GLINT] end
	if q > 0.72 and ly > 0.45 then return tones[LIGHT] end
	if lx + ly > 0.62 then return tones[DEEP] end
	if ((lx + 0.35) / 0.57) ^ 2 + ((ly + 0.36) / 0.4) ^ 2 < 1 then return tones[LIGHT] end
	local kind = tones[KIND]
	if kind > 1 and motifAt(kind, lx, ly) then return tones[MOTIF] end
	return tones[BODY]
end
LCD.shade = shade

-- ── Themed balls ───────────────────────────────────────────────────────────
-- Extra roles after the six legacy ones.
local LIGHTMID, INK, BLUSH, STAR, MAGNET = 7, 8, 9, 10, 11
local toneIndex = { ink = INK, glint = GLINT, light = LIGHT, blush = BLUSH }
local function shadeLean(t, lx, ly, q)
	local tex = t.texture
	if tex == "facet" then
		if ly < -0.52 then return t[LIGHT] end
		if lx + ly > 0.55 then return t[DEEP] end
		if lx < -0.42 then return t[LIGHTMID] end
		return t[BODY]
	end
	-- One small glint, high and left, clear of the eyes.
	if ((lx + 0.42) / 0.2) ^ 2 + ((ly + 0.62) / 0.12) ^ 2 < 1 then return t[GLINT] end
	if tex == "sugar" and ly > 0.38 then
		if ly > 0.62 or q > 0.8 then return t[LIGHT] end
		return t[LIGHTMID]
	end
	if lx + ly > 0.62 then return t[DEEP] end
	local tier = t.tier
	if tier >= 3 and q > 0.72 and ly > 0.45 then return t[LIGHT] end
	if tex == "planet" then
		if tier <= 2 and ((lx - 0.3) ^ 2 + (ly - 0.2) ^ 2 < 0.05 or (lx + 0.35) ^ 2 + (ly - 0.45) ^ 2 < 0.03) then return t[DEEP] end
		if tier == 3 and ((lx + 0.3) ^ 2 / 0.12 + (ly + 0.05) ^ 2 / 0.05 < 1 or (lx - 0.25) ^ 2 / 0.06 + (ly - 0.45) ^ 2 / 0.03 < 1) then return t[LIGHT] end
		if tier == 4 and ((ly > -0.1 and ly < 0.04) or (ly > 0.34 and ly < 0.44) or (ly > -0.6 and ly < -0.52)) then return t[LIGHTMID] end
		if tier == 5 and math.abs(ly - 0.12 - lx * 0.22) < 0.07 then return t[LIGHT] end
		return t[BODY]
	end
	if lx + ly < -0.95 then return t[LIGHT] end
	return t[BODY]
end
LCD.shadeLean = shadeLean

local themeCache = {}
local function themeTones(theme, tier)
	tier = math.clamp(math.floor(tier or 1), 1, 5)
	local key = theme.id .. tier
	local cached = themeCache[key]
	if cached then return cached end
	local ramp = theme.ramps[tier]
	local body, deep, light = Color3.fromHex(ramp.body), Color3.fromHex(ramp.deep), Color3.fromHex(ramp.light)
	local motifKind, motif = 1, body:Lerp(WHITE, JellyPalette.MotifOpacity)
	if theme.texture == "motif" then
		local roles = JellyPalette.byTier[tier]
		motifKind, motif = roles.motifKind or 1, roles.motif
	end
	local blushBase = Color3.fromHex("#FF3F7A")
	local blush = if tier ~= 4 then body:Lerp(blushBase, 0.62) else deep:Lerp(blushBase, 0.3)
	cached = { rgba(deep), rgba(body), rgba(light), rgba(WHITE), rgba(motif), motifKind,
		rgba(body:Lerp(light, 0.5)), rgba(Color3.fromHex(theme.ink)), rgba(blush),
		rgba(Color3.fromHex("#FFE14D")), rgba(Color3.fromHex("#FF3B4E")) }
	cached.tier, cached.texture, cached.style = tier, theme.texture, theme.face
	cached.ears = theme.earsFrom ~= nil and tier >= theme.earsFrom
	cached.shader = if theme.face == "none" or theme.texture == "motif" then shade else shadeLean
	themeCache[key] = cached
	return cached
end
LCD.themeTones = themeTones

-- Cat ears: pointed triangles leaning out, in light space (radius 1). The apex
-- stands 0.27 r above the head; ears never count for collisions or the fill line.
local EARS = { { -0.70, -1.27, -0.16, -0.86, -1.0, -0.36 }, { 0.70, -1.27, 0.16, -0.86, 1.0, -0.36 } }
local function inTriangle(px, py, ax, ay, bx, by, cx, cy)
	local d1 = (px - bx) * (ay - by) - (ax - bx) * (py - by)
	local d2 = (px - cx) * (by - cy) - (bx - cx) * (py - cy)
	local d3 = (px - ax) * (cy - ay) - (cx - ax) * (py - ay)
	return not ((d1 < 0 or d2 < 0 or d3 < 0) and (d1 > 0 or d2 > 0 or d3 > 0))
end
local function earTone(t, ux, uy)
	if uy > -0.3 or uy < -1.35 then return nil end
	for side, e in ipairs(EARS) do
		if inTriangle(ux, uy, e[1], e[2], e[3], e[4], e[5], e[6]) then
			if t.tier >= 4 then
				-- Inner pink: the same triangle at half size about its centroid.
				local gx, gy = (e[1] + e[3] + e[5]) / 3, (e[2] + e[4] + e[6]) / 3
				if inTriangle(gx + (ux - gx) * 2, gy + (uy - gy) * 2, e[1], e[2], e[3], e[4], e[5], e[6]) then return t[BLUSH] end
			end
			if side == 2 and math.abs(ux) > 0.78 then return t[DEEP] end
			return t[BODY]
		end
	end
	return nil
end
LCD.earTone = earTone

-- Marks drawn in place of the face (R2 items). Offsets as BallFaces: -1 is left of centre.
local STAR_SMALL = { { 0, 0 }, { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 } }
local STAR_BIG = { { 0, 0 }, { -1, 0 }, { 1, 0 }, { 0, -1 }, { 0, 1 }, { -2, 0 }, { 2, 0 }, { 0, -2 }, { 0, 2 } }
local MAGNET_MARK = { { -2, -1, MAGNET }, { -2, 0, MAGNET }, { -2, 1, MAGNET }, { 1, -1, MAGNET }, { 1, 0, MAGNET }, { 1, 1, MAGNET },
	{ -1, 2, MAGNET }, { 0, 2, MAGNET }, { -2, -2, GLINT }, { 1, -2, GLINT } }
local BOMB_MARK = { { -1, -1, INK }, { 0, -1, INK }, { -2, 0, INK }, { -1, 0, INK }, { 0, 0, INK }, { 1, 0, INK }, { -2, 1, INK }, { -1, 1, INK },
	{ 0, 1, INK }, { 1, 1, INK }, { -1, 2, INK }, { 0, 2, INK }, { 1, -2, LIGHT }, { 2, -3, STAR } }

-- target:putPixel(x, y, packed) clips to its own surface. `face` = { tier, expr,
-- dx, star, mark }. Faces stay upright; only the face moves when it shivers.
local function paintFace(target, cx, cy, r, t, face, simple)
	local ax, ay = math.round(cx) + (face.dx or 0), math.round(cy)
	local limit = (r - 0.6) ^ 2
	local mark = face.mark
	local list
	if mark == "magnet" then list = MAGNET_MARK elseif mark == "bomb" then list = BOMB_MARK end
	if list then
		for _, p in ipairs(list) do
			local x, y = ax + p[1], ay + p[2]
			if (x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2 <= limit then target:putPixel(x, y, t[p[3]]) end
		end
		return
	end
	if face.star then
		-- A power-up ball: a twinkling star instead of a face (scope A6).
		local big = t.tier >= 2 and face.expr ~= "blink"
		for _, p in ipairs(if big then STAR_BIG else STAR_SMALL) do
			local x, y = ax + p[1], ay + p[2]
			if (x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2 <= limit + 1 then
				target:putPixel(x, y, if p[1] == 0 and p[2] == 0 then t[GLINT] else t[STAR])
			end
		end
		return
	end
	local pixels = BallFaces.pixels(t.style, t.tier, face.expr, simple)
	if not pixels then return end
	for _, p in ipairs(pixels) do
		local x, y = ax + p[1], ay + p[2]
		if (x + 0.5 - cx) ^ 2 + (y + 0.5 - cy) ^ 2 <= limit then target:putPixel(x, y, t[toneIndex[p[3]]]) end
	end
end
LCD.paintFace = paintFace

-- Static preview of one ball (Next / Then / theme cards): runs of one colour per
-- row on a small square grid at the tier's real LCD size. Cached per look.
local Canvas = {}
Canvas.__index = Canvas
function Canvas:putPixel(x, y, c)
	if x >= 0 and y >= 0 and x < self.size and y < self.size then self.px[y * self.size + x + 1] = c end
end
local runCache, runCount = {}, 0
function LCD.ballRuns(themeId, tier, expr, dx, star, mark)
	local theme = BallThemes.get(themeId)
	tier = math.clamp(math.floor(tier or 1), 1, 5)
	local key = theme.id .. "|" .. tier .. "|" .. (expr or "idle") .. "|" .. (dx or 0) .. "|" .. tostring(star == true) .. "|" .. tostring(mark)
	local hit = runCache[key]
	if hit then return hit end
	local t = themeTones(theme, tier)
	local r = Config.Tiers[tier].radius * WIDTH / (Config.Width + 0.8)
	local margin = if t.ears then math.ceil(r * 0.3) + 1 else 1
	local size = math.ceil(r * 2) + margin * 2
	local cx = size / 2
	local cy = size / 2 + (if t.ears then margin * 0.5 else 0)
	local canvas = setmetatable({ size = size, px = table.create(size * size, 0) }, Canvas)
	for y = 0, size - 1 do
		for x = 0, size - 1 do
			local ux, uy = (x + 0.5 - cx) / r, (y + 0.5 - cy) / r
			local q = ux * ux + uy * uy
			if q <= 1 then
				canvas.px[y * size + x + 1] = t.shader(t, ux, uy, q)
			elseif t.ears then
				local ear = earTone(t, ux, uy)
				if ear then canvas.px[y * size + x + 1] = ear end
			end
		end
	end
	paintFace(canvas, cx, cy, r, t, { tier = tier, expr = expr or "idle", dx = dx or 0, star = star == true, mark = mark }, false)
	local runs = {}
	for y = 0, size - 1 do
		local x = 0
		while x < size do
			local c = canvas.px[y * size + x + 1]
			local start = x
			x += 1
			while x < size and canvas.px[y * size + x + 1] == c do x += 1 end
			if c ~= 0 then table.insert(runs, table.freeze({ start, y, x - start, c })) end
		end
	end
	hit = table.freeze({ size = size, runs = table.freeze(runs) })
	if runCount >= 512 then table.clear(runCache); runCount = 0 end
	runCache[key] = hit
	runCount += 1
	return hit
end
function LCD.packedColor(packed)
	return Color3.fromRGB(packed % 256, math.floor(packed / 256) % 256, math.floor(packed / 65536) % 256)
end

local defaultBoard={outside=Color3.fromHex("#2C4D30"),base=Color3.fromHex("#C6DFA0"),dither=Color3.fromHex("#BBD395"),rail=Color3.fromHex("#749154"),rim=Color3.fromHex("#385632"),guide=Color3.fromHex("#54783E")}

-- Row -> band index: 1..ShadowRows is the inner shadow under the top edge, then
-- the gradient from the lifted top to the darkened floor.
local bandRows = table.create(HEIGHT)
do
	local span = floor - ceiling - LCD.ShadowRows
	for y = 0, HEIGHT - 1 do
		local depth = y + 0.5 - ceiling
		local band
		if depth < LCD.ShadowRows then
			band = math.clamp(math.floor(depth) + 1, 1, LCD.ShadowRows)
		else
			band = LCD.ShadowRows + math.clamp(math.floor((depth - LCD.ShadowRows) / span * LCD.GradientBands) + 1, 1, LCD.GradientBands)
		end
		bandRows[y + 1] = band
	end
end
LCD.bandOfRow = function(y) return bandRows[y + 1] end

-- Packed, pairwise-distinct static tones for a board palette. Order is fixed:
-- guide, bank, then every band, so a palette swap maps tone i to tone i.
local function boardTones(colors)
	if typeof(colors) ~= "table" or typeof(colors.base) ~= "Color3" or typeof(colors.guide) ~= "Color3" then return nil end
	local seen, list = {}, {}
	local function distinct(color)
		local value = rgba(color)
		local r = value % 256
		local rest = value - r
		for step = 0, 255 do
			local candidate = rest + (r + step) % 256
			if not seen[candidate] then seen[candidate] = true; table.insert(list, candidate); return candidate end
		end
		table.insert(list, value); return value
	end
	local base = colors.base
	local accent = if typeof(colors.accent) == "Color3" then colors.accent else colors.guide
	local top, bottom = base:Lerp(accent, 0.07), base:Lerp(BLACK, 0.35)
	local tones = { guide = distinct(colors.guide), bank = distinct(base:Lerp(WHITE, 0.09)), bands = {}, list = list }
	for band = 1, LCD.ShadowRows do
		tones.bands[band] = distinct(top:Lerp(BLACK, 0.3 * (1 - (band - 1) / LCD.ShadowRows)))
	end
	for band = 1, LCD.GradientBands do
		tones.bands[LCD.ShadowRows + band] = distinct(top:Lerp(bottom, (band - 0.5) / LCD.GradientBands))
	end
	return tones
end
LCD.boardTones = boardTones

local function boardPixels(tones,regions)
	local pixels = buffer.create(WIDTH * HEIGHT * 4)
	local threshold = tones.guide
	for y = 0, HEIGHT - 1 do
		local inset = math.max(0, bank - (floor - (y + 0.5)))
		local band = tones.bands[bandRows[y + 1]]
		local inWell = y + 0.5 <= floor
		for x = 0, WIDTH - 1 do
			local color = band
			if inWell and inset > 0 and (x + 0.5 < leftWall + inset or x + 0.5 > rightWall - inset) then
				color = tones.bank
			elseif inWell and regions and regions.enabled and y >= ceiling then
				local function boundary(worldX)
					return x==math.floor(WIDTH*(.5+worldX/(Config.Width+.8)))
				end
				if boundary(-regions.bound)or boundary(regions.bound)
					or(regions.active=="center"and(boundary(regions.min)or boundary(regions.max)))then color=threshold end
			end
			buffer.writeu32(pixels, (y * WIDTH + x) * 4, color)
		end
	end
	return pixels
end

-- Sampling is clipped before entering the loops: work never exceeds the fixed 64x107 grid.
-- Used by merges only; plain eggs take the inlined path in LCD:draw.
local function raster(self, minX, minY, maxX, maxY, tones, sample)
	local shader = tones.shader or shade
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
				buffer.writeu32(self.pixels, (y * WIDTH + x) * 4, shader(tones, lightX, lightY, lightX * lightX + lightY * lightY))
			end
		end
	end
end

local function foreground(tones)return{[tones.bank]=true}end

function LCD.new(parent, options)
	options=options or {}
	local tones=boardTones(options.palette or defaultBoard) or boardTones(defaultBoard)
	local background=boardPixels(tones)
	local function span()
		local pixels=buffer.create(WIDTH*HEIGHT*4)
		local surface=SpanSurface.new(parent,background,WIDTH,HEIGHT,options.maxSpans or 1536)
		if not surface then return nil end
		return setmetatable({surface=surface,label=surface.root,background=background,pixels=pixels,failed=false,backend="span",boardPalette=options.palette or defaultBoard,tones=tones,guideColor=tones.guide},LCD)
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
	return setmetatable({image=editable,label=label,background=background,pixels=buffer.create(WIDTH*HEIGHT*4),failed=false,backend="image",boardPalette=options.palette or defaultBoard,tones=tones,guideColor=tones.guide},LCD)
end
-- Recolor the existing board, cached static rectangles and already painted
-- frame together. The live gel pixels and bounded dynamic pool are retained.
function LCD:setPalette(colors)
 if self.destroyed or self.failed then return false end
 if self.boardPalette==colors then return true end
 local tones=boardTones(colors);if not tones or #tones.list~=#self.tones.list then return false end
 local replacements={}
 for index,value in ipairs(self.tones.list)do replacements[value]=tones.list[index]end
 local background=boardPixels(tones,if self.backend=="image"then self.regions else nil);local oldGuide,newGuide=self.guideColor,tones.guide
 if not self.painted then buffer.copy(self.pixels,0,background)else
  for y=0,HEIGHT-1 do for x=0,WIDTH-1 do
   local offset=(y*WIDTH+x)*4;local pixel=buffer.readu32(self.pixels,offset)
   if pixel==buffer.readu32(self.background,offset)then buffer.writeu32(self.pixels,offset,buffer.readu32(background,offset))
   elseif pixel==oldGuide and self.guidePixels and self.guidePixels[offset]then buffer.writeu32(self.pixels,offset,newGuide)end
  end end
 end
 local ok=pcall(function()
  if self.surface then
   assert(self.surface:setBackground(background,replacements));assert(self.surface:paint(self.pixels))
  else self.image:WritePixelsBuffer(Vector2.zero,SIZE,self.pixels)end
 end)
 if not ok then self.failed=true;self.label.Visible=false;return false end
 self.background,self.boardPalette,self.guideColor,self.tones=background,colors,newGuide,tones
 if self.regionHost and self.surface then self.surface:attachRegions(self.regionHost,foreground(tones))end
 return true
end
-- Called only when the quest/appearance changes; gel pixels are drawn later.
function LCD:setRegions(enabled,active,bound,minX,maxX)
    local key=tostring(enabled)..":"..tostring(active)..":"..tostring(bound)..":"..tostring(minX)..":"..tostring(maxX)
    if self.regionKey==key then return end
    self.regionKey=key;self.regions={enabled=enabled==true,active=active,bound=bound or 2.6,min=minX or -1,max=maxX or 1}
    if self.backend=="image"then self.background=boardPixels(self.tones,self.regions)end
end
function LCD:attachRegions(host)
    if not self.surface then return false end
    self.regionHost=host
    self.surface:attachRegions(host,foreground(self.tones))
    return true
end
function LCD:getStats()
	return if self.surface then self.surface.stats else{backend=self.backend,failed=self.failed}
end

-- The equipped ball theme (BallThemes id). Faces and colours come from it for
-- every `draw` that passes a `face` record; the board's geometry never changes.
function LCD:setBallTheme(id)
	local theme = BallThemes.get(id)
	if self.theme == theme then return false end
	self.theme = theme
	return true
end
function LCD:getBallTheme() return (self.theme or BallThemes.get(BallThemes.Default)).id end

-- Board pixel write with the well's clip (walls, ceiling, floor and banks).
function LCD:putPixel(x, y, color)
	if x < 0 or y < 0 or x >= WIDTH or y >= HEIGHT then return end
	if y + 0.5 < ceiling or y + 0.5 > floor then return end
	local inset = math.max(0, bank - (floor - (y + 0.5)))
	if x + 0.5 < leftWall + inset or x + 0.5 > rightWall - inset then return end
	buffer.writeu32(self.pixels, (y * WIDTH + x) * 4, color)
end

-- Every frame command is recorded (pooled tables, no per-frame allocation once
-- warm) so an over-budget frame can be re-rastered with simpler faces.
local function record(self, kind)
	local count = (self.commandCount or 0) + 1
	self.commandCount = count
	local commands = self.commands
	if not commands then commands = {}; self.commands = commands end
	local command = commands[count]
	if not command then command = {}; commands[count] = command end
	command.kind = kind
	return command
end

function LCD:beginFrame()
	if self.guidePixels then table.clear(self.guidePixels)else self.guidePixels={}end
	self.rasterStarted=os.clock()
	self.commandCount=0;self.frameFaces=false
	buffer.copy(self.pixels, 0, self.background)
end

local function drawGuide(self, aim)
 local origin=Config.launchPosition()
 local tangent=origin+Config.launchVelocity(aim).Unit*Config.GuideLength
 local function pixel(point)
  return Vector2.new(WIDTH*(.5+point.X/(Config.Width+.8)),HEIGHT*(.5-(point.Y-Config.Height/2)/(Config.Height+.8)))
 end
 local function dot(point)
  local p=pixel(point);local x,y=math.floor(p.X),math.floor(p.Y)
  if x>=leftWall and x<rightWall and y>=ceiling and y<floor then
   local offset=(y*WIDTH+x)*4
   buffer.writeu32(self.pixels,offset,self.guideColor);self.guidePixels[offset]=true
  end
 end
 for index=0,8 do dot(origin:Lerp(tangent,index/8))end
 for index=1,Config.PreviewCount do dot(Config.flightPoint(aim,index*Config.PreviewStep))end
end
function LCD:drawGuide(aim)
	if not self.replaying then record(self, "guide").aim = aim end
	drawGuide(self, aim)
end

local function drawBall(self, center, radiusX, radiusY, angleRadians, color, ripple, match, face)
	if self.failed or radiusX <= 0 or radiusY <= 0 then return end
	local tones
	if face and face.tier then tones = themeTones(self.theme or BallThemes.get(BallThemes.Default), face.tier)
	else tones = palette(color) end
	local shader = tones.shader or shade
	local ears = tones.ears == true and (not self.simple or tones.tier >= 3)
	local c, s = math.cos(angleRadians), math.sin(angleRadians)
	local wobble = math.clamp(ripple or 0, -1, 1) * 0.075
	local lightRadiusX=math.sqrt((radiusX*c)^2+(radiusY*s)^2)
	local lightRadiusY=math.sqrt((radiusX*s)^2+(radiusY*c)^2)
	local bloom = self.bloom ~= false
	local bloomReach = if not bloom then 1.09 elseif match then LCD.MatchReach else LCD.BloomReach
	local bloomSquared = bloomReach * bloomReach
	local reach = if ears then math.max(bloomReach, LCD.EarReach) else bloomReach
	local reachSquared = reach * reach
	local glow = if match then tones[LIGHT] else tones[BODY]
	local alpha = if match then LCD.MatchAlpha else LCD.BloomAlpha
	local cx, cy = center.X, center.Y
	local minX = math.max(math.ceil(leftWall - 0.5), math.floor(cx - lightRadiusX * reach - 1))
	local minY = math.max(math.ceil(ceiling - 0.5), math.floor(cy - lightRadiusY * reach - 1))
	local maxX = math.min(math.floor(rightWall - 0.5), math.ceil(cx + lightRadiusX * reach + 1))
	local maxY = math.min(math.floor(floor - 0.5), math.ceil(cy + lightRadiusY * reach + 1))
	local pixels, background = self.pixels, self.background
	for y = minY, maxY do
		local inset = math.max(0, bank - (floor - (y + 0.5)))
		local rowStart = math.max(minX, math.ceil(leftWall + inset - 0.5))
		local rowEnd = math.min(maxX, math.floor(rightWall - inset - 0.5))
		local dy = y + 0.5 - cy
		for x = rowStart, rowEnd do
			local dx = x + 0.5 - cx
			local nx, ny = (dx * c + dy * s) / radiusX, (-dx * s + dy * c) / radiusY
			local q = nx * nx + ny * ny
			if q <= reachSquared then
				local offset = (y * WIDTH + x) * 4
				-- A bounded polynomial ripple gives a soft asymmetric edge without per-pixel trig.
				local edge = 1 + wobble * (nx * nx - ny * ny) * nx
				local ear = if ears and q > edge * edge then earTone(tones, dx / lightRadiusX, dy / lightRadiusY) else nil
				if q <= edge * edge then
					buffer.writeu32(pixels, offset, shader(tones, dx / lightRadiusX, dy / lightRadiusY, q))
				elseif ear then
					buffer.writeu32(pixels, offset, ear)
				elseif bloom and q <= bloomSquared then
					local under = buffer.readu32(pixels, offset)
					if under == buffer.readu32(background, offset) then
						buffer.writeu32(pixels, offset, mix(under, glow, alpha))
					end
				end
			end
		end
	end
	if face and face.tier and (tones.style ~= "none" or face.star or face.mark) then
		self.frameFaces = true
		paintFace(self, cx, cy, math.min(radiusX, radiusY), tones, face, self.simple == true)
	end
end

-- `match` marks the egg that matches the held one: a stronger, wider light bloom.
-- Bloom is written only where the pixel is still the untouched well, so it sits
-- under every egg, the aim guide and anything drawn earlier.
-- `face` (optional) = { tier, expr, dx, star, mark }: draw in the equipped ball
-- theme with that face. Without it the egg keeps the legacy vivid look (specs,
-- benchmark baseline). The caller may reuse the table; fields are copied.
function LCD:draw(center, radiusX, radiusY, angleRadians, color, ripple, match, face)
	if not self.replaying then
		local command = record(self, "draw")
		command.center, command.rx, command.ry, command.angle = center, radiusX, radiusY, angleRadians
		command.color, command.ripple, command.match = color, ripple, match
		command.tier = face and face.tier
		if face then command.expr, command.dx, command.star, command.mark = face.expr, face.dx, face.star, face.mark end
	end
	drawBall(self, center, radiusX, radiusY, angleRadians, color, ripple, match, face)
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

local function mergeBlob(self, first, second, target, radius, resultRadius, color, age, tier)
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
	local tones = if tier then themeTones(self.theme or BallThemes.get(BallThemes.Default), tier) else palette(color)
	raster(self, math.min(a.X, b.X, target.X) - margin, math.min(a.Y, b.Y, target.Y) - margin,
		math.max(a.X, b.X, target.X) + margin, math.max(a.Y, b.Y, target.Y) + margin,
		tones, function(x, y)
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
-- `tier` (optional): the merged blob takes that size's themed colours.
function LCD:merge(first, second, target, radius, resultRadius, color, age, tier)
	if not self.replaying then
		local command = record(self, "merge")
		command.first, command.second, command.target, command.radius = first, second, target, radius
		command.resultRadius, command.color, command.age, command.tier = resultRadius, color, age, tier
	end
	mergeBlob(self, first, second, target, radius, resultRadius, color, age, tier)
end

-- Re-raster this frame from its recorded commands with simpler faces.
-- `bare`: last resort, draw every ball with no face at all (code review 2026-11-13).
local function replay(self, bare)
	self.replaying, self.simple = true, true
	if self.guidePixels then table.clear(self.guidePixels) end
	buffer.copy(self.pixels, 0, self.background)
	local face = self.replayFace or {}
	self.replayFace = face
	for index = 1, self.commandCount or 0 do
		local command = self.commands[index]
		if command.kind == "guide" then drawGuide(self, command.aim)
		elseif command.kind == "draw" then
			local withFace = nil
			if command.tier and not bare then
				face.tier, face.expr, face.dx, face.star, face.mark = command.tier, command.expr, command.dx, command.star, command.mark
				withFace = face
			end
			drawBall(self, command.center, command.rx, command.ry, command.angle, command.color, command.ripple, command.match, withFace)
		elseif command.kind == "merge" then
			mergeBlob(self, command.first, command.second, command.target, command.radius, command.resultRadius, command.color, command.age, command.tier)
		end
	end
	self.replaying, self.simple = false, false
end
LCD.replay = replay

function LCD:finishFrame()
	if self.failed then return false end
	if self.surface and self.frameFaces then
		-- Pre-count (architect change 2): over SimplifyAbove re-raster with simpler
		-- faces; only a frame still over the cap reaches the sticky failure below.
		local stats = self.surface.stats
		local demand = self.surface:demand(self.pixels)
		stats.preDemand = demand
		stats.peakPreDemand = math.max(stats.peakPreDemand or 0, demand)
		if demand > LCD.SimplifyAbove then
			replay(self)
			stats.simplifiedFrames = (stats.simplifiedFrames or 0) + 1
			-- Still over the cap with simple faces: drop faces for this frame rather
			-- than take the sticky failure path (the board would stay hidden).
			if self.surface:demand(self.pixels) > self.surface.limit then
				replay(self, true)
				stats.barefacedFrames = (stats.barefacedFrames or 0) + 1
			end
		end
	end
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
    if self.regionHost and self.regionHost.Parent==self.label then
        self.regionHost.Parent=self.label.Parent;self.regionHost.ZIndex=2
        for _,node in ipairs(self.regionHost:GetDescendants())do if node:IsA("GuiObject")then node.ZIndex=2 end end
    end
	if self.surface then self.surface:destroy()else self.label:Destroy();self.image:Destroy()end
end

return LCD
