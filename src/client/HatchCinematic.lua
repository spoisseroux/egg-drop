local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Art = require(script.Parent.DeckArt)
local Portrait = require(script.Parent.PetPortrait)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)

local Cinematic = {}
Cinematic.__index = Cinematic

local function round(parent, name, color, position, size, z)
	local node = Art.frame(parent, name, color, position, size, z)
	node.AnchorPoint = Vector2.new(0.5, 0.5)
	Art.corner(node, 1000)
	return node
end

local function text(parent, name, content, position, size, color, maximum)
	local node = Art.text(parent, name, content, position, size, color, maximum, Enum.Font.GothamBold)
	Art.fitText(node, maximum, 10, 6, true)
	return node
end

function Cinematic.new(parent, audio, reduceEffects)
	local frame = Art.frame(parent, "HatchCinematic", Art.Ink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 42)
	frame.Visible = false
	frame.ClipsDescendants = true
	Art.corner(frame, 14)
	local self = setmetatable({
		frame = frame, audio = audio, reduceEffects = reduceEffects, epoch = 0,
		tweens = {}, active = false,
	}, Cinematic)
	frame:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if self.active and self.startedAt and os.clock() - self.startedAt > 0.15 then
			-- Resizing must not leave the reveal offscreen or its footer permanently locked.
			self:finishStatic()
		elseif not self.active and self.frame.Visible and self.result then
			self:clearHero()
			self.frame:ClearAllChildren()
			Art.corner(self.frame, 14)
			self:drawResult(self.result)
		end
	end)
	return self
end

function Cinematic:clearHero()
	if self.heroConnection then
		self.heroConnection:Disconnect()
		self.heroConnection = nil
	end
	if self.heroVisual then
		self.heroVisual:destroy()
		self.heroVisual = nil
	end
	if self.heroViewport then
		self.heroViewport:Destroy()
		self.heroViewport = nil
	end
end

function Cinematic:createHero(parent, pet, animate)
	self:clearHero()
	local viewport = Instance.new("ViewportFrame")
	viewport.Name = "PetHero3D"
	viewport.Size = UDim2.fromScale(1, 1)
	viewport.BackgroundTransparency = 1
	viewport.BorderSizePixel = 0
	viewport.ZIndex = 50
	viewport.Ambient = Color3.fromRGB(190, 204, 178)
	viewport.LightColor = Color3.fromRGB(255, 240, 212)
	viewport.LightDirection = Vector3.new(-1, -1.4, -3)
	viewport.Parent = parent
	self.heroViewport = viewport
	local ok = pcall(function()
		local world = Instance.new("WorldModel")
		world.Name, world.Parent = "PetStage", viewport
		local family = pet.family or pet.id
		local visualModule = if family == "pip" then script.Parent.PipVisual
			elseif family == "puddle" then script.Parent.PuddleVisual else script.Parent.BonusPetVisual
		local visual = require(visualModule).new(world, Vector3.zero, pet)
		self.heroVisual = visual
		-- Each family has a different crown/tail width. Frame its real bounds plus
		-- greeting headroom so leaves and rare flames cannot be cropped.
		local bounds, dimensions = visual.model:GetBoundingBox()
		local camera = Instance.new("Camera")
		camera.Name, camera.FieldOfView = "HeroCamera", 30
		local target = Vector3.new(bounds.Position.X, bounds.Position.Y + 0.22, 0)
		local extent = math.max(dimensions.Y + 0.80, dimensions.X + 0.35)
		local distance = extent / (2 * math.tan(math.rad(camera.FieldOfView / 2))) * 1.04
		camera.CFrame = CFrame.lookAt(target + Vector3.new(0.22, 0.10, distance), target)
		camera.Parent = viewport
		viewport.CurrentCamera = camera
		parent:SetAttribute("RenderMode", "3D")
		if animate and not self.reduceEffects() then
			visual:greet()
			local elapsed = 0
			local connection
			local function stop()
				connection:Disconnect()
				if self.heroConnection == connection then self.heroConnection = nil end
			end
			connection = RunService.RenderStepped:Connect(function(dt)
				if self.heroVisual ~= visual or not self.frame.Visible or not viewport.Parent then
					stop()
					return
				end
				elapsed += dt
				if self.reduceEffects() or elapsed >= 1.8 then
					visual:update(3)
					stop()
				else
					visual:update(dt)
				end
			end)
			self.heroConnection = connection
		else
			visual:update(3)
		end
	end)
	if not ok then
		self:clearHero()
		parent:SetAttribute("RenderMode", "PixelFallback")
		Portrait.create(parent, pet, parent.Size.Y.Offset / 13, UDim2.fromScale(0.5, 0.5), 50)
	end
end

function Cinematic:stopMotions()
	for _, motion in ipairs(self.tweens) do motion:Cancel() end
	table.clear(self.tweens)
end

function Cinematic:cancel()
	self.epoch += 1
	self:stopMotions()
	self:clearHero()
	self.active = false
	self.frame.Visible = false
	self.frame:ClearAllChildren()
	self.onComplete = nil
end

function Cinematic:motion(object, seconds, properties, style, direction)
	local motion = TweenService:Create(object,
		TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out), properties)
	table.insert(self.tweens, motion)
	motion:Play()
	return motion
end

function Cinematic:layoutResult(result)
	local pet = Pets.byId[result.petId] or Pets[1]
	local size = self.frame.AbsoluteSize
	local height = math.max(1, size.Y)
	local compact = height < 140
	local heroSize = math.clamp(math.min(height - (if compact then 50 else 82), size.X - 28), 22, 260)
	local centerY = if compact then math.max(12, (height - 43) * 0.5) else height * 0.43
	return pet, heroSize, centerY, compact
end

function Cinematic:drawResult(result, animate)
	local pet, heroSize, centerY, compact = self:layoutResult(result)
	local color = if result.rare then Art.Amber else Art.Leaf
	local root = Art.frame(self.frame, "Result", Art.Ink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 47)
	root.BackgroundTransparency = 1
	local halo = round(root, "DiscoveryHalo", color, UDim2.new(0.5, 0, 0, centerY),
		UDim2.fromOffset(heroSize * 1.43, heroSize * 1.1), 47)
	halo.BackgroundTransparency = 0.94
	Art.stroke(halo, color, 0.70, 2)
	local hero = Art.frame(root, "Hero", Art.Ink, UDim2.new(0.5, 0, 0, centerY),
		UDim2.fromOffset(heroSize, heroSize), 49)
	hero.AnchorPoint = Vector2.new(0.5, 0.5)
	hero.BackgroundTransparency = 1
	self:createHero(hero, pet, animate)
	local scale = Instance.new("UIScale")
	scale.Name, scale.Parent = "RevealScale", hero
	local tagText = if result.duplicate then (if result.rare then "RARE FAMILY DUPLICATE" else "FAMILY DUPLICATE")
		elseif result.rare then "RARE DISCOVERY" else "A NEW LITTLE WONDER"
	local tag = text(root, "Rarity", tagText,
		UDim2.fromOffset(8, 5), UDim2.new(1, -16, 0, 18), color, 12)
	tag.Visible = not compact
	local heading = text(root, "PetName", pet.name,
		UDim2.new(0, 8, 1, -43), UDim2.new(1, -16, 0, 23), Art.Silver, 25)
	local family = (result.family or pet.family or pet.id):gsub("^%l", string.upper)
	local detail = if result.duplicate
		then string.format("%s family  +1 mastery  ·  %d / 3", family, math.clamp(result.mastery or 0, 0, 3))
		else "A new friend for Sprout Hollow"
	if result.duplicate and (result.mastery or 0) >= 3 then detail = family .. " family sparkle unlocked!" end
	local caption = text(root, "Mastery", detail, UDim2.new(0, 8, 1, -21), UDim2.new(1, -16, 0, 19),
		if result.duplicate then Art.Leaf else Art.Muted, 12)
	return root, hero, scale, heading, caption
end

function Cinematic:finishStatic()
	if not self.active or not self.result then return end
	self.epoch += 1
	self:stopMotions()
	self:clearHero()
	self.frame:ClearAllChildren()
	Art.corner(self.frame, 14)
	self:drawResult(self.result)
	self.active = false
	local complete = self.onComplete
	self.onComplete = nil
	if complete then complete() end
end

function Cinematic:play(result, onComplete)
	self:cancel()
	self.result = result
	self.onComplete = onComplete
	self.active, self.startedAt = true, os.clock()
	self.frame.Visible = true
	Art.corner(self.frame, 14)
	if self.reduceEffects() then
		self.audio:play("hatch", 1, 0.65)
		self:finishStatic()
		return
	end
	local epoch = self.epoch
	local function later(seconds, callback)
		task.delay(seconds, function()
			if self.active and self.epoch == epoch and self.frame.Parent then
				if self.reduceEffects() then self:finishStatic() else callback() end
			end
		end)
	end
	local pet, heroSize, centerY, compact = self:layoutResult(result)
	local rare = result.rare == true
	local accent = if rare then Art.Amber else Art.Leaf
	local burstAt = if rare then 1.85 else 1.35
	local endAt = if rare then 3.35 else 2.65
	local center = UDim2.new(0.5, 0, 0, centerY)
	local stage = Art.frame(self.frame, "HatchStage", Art.Ink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 43)
	stage.BackgroundTransparency = 1
	local glow = round(stage, "InnerLight", accent, center,
		UDim2.fromOffset(heroSize * 0.6, heroSize * 0.6), 43)
	glow.BackgroundTransparency = 0.96
	local glowEdge = Art.stroke(glow, accent, 0.85, 2)
	local ring = round(stage, "CradleRing", Art.Field, center + UDim2.fromOffset(0, heroSize * 0.35),
		UDim2.fromOffset(heroSize * 1.1, heroSize * 0.20), 44)
	Art.stroke(ring, Art.Leaf, 0.6, 2)
	local rig = Art.frame(stage, "Shell", pet.color:Lerp(Art.Silver, 0.74), center,
		UDim2.fromOffset(heroSize * 0.60, heroSize * 0.80), 46)
	rig.AnchorPoint = Vector2.new(0.5, 0.5)
	Art.corner(rig, 1000)
	Art.shade(rig, 1, 0.78)
	Art.stroke(rig, accent, 0.18, 2)
	local shellScale = Instance.new("UIScale")
	shellScale.Scale, shellScale.Parent = 0.83, rig
	local highlight = round(rig, "ShellGlint", Art.Silver, UDim2.fromScale(0.30, 0.23),
		UDim2.fromScale(0.21, 0.075), 47)
	highlight.Rotation = -28
	local crack = Art.pixels(rig, "Crack", { "..X..", ".XX..", ".X...", ".XX..", "..X..", "..XX.", "...X." },
		{ X = accent }, math.max(1, heroSize / 45), UDim2.fromScale(0.5, 0.32), 48)
	crack.AnchorPoint = Vector2.new(0.5, 0)
	crack.Visible = false
	local anticipation = text(stage, "Anticipation", "Something is stirring…",
		UDim2.new(0, 8, 1, -30), UDim2.new(1, -16, 0, 24), Art.Muted, 16)
	self.audio:play("hatch_rise", if rare then 0.82 else 0.94, 0.62)
	self:motion(shellScale, 0.38, { Scale = 1.02 }, Enum.EasingStyle.Back)
	later(0.42, function()
		self.audio:play("charge", 0.92, 0.35)
		self:motion(rig, 0.17, { Rotation = -7, Size = UDim2.fromOffset(heroSize * 0.66, heroSize * 0.73) })
	end)
	later(0.65, function()
		crack.Visible = true
		anticipation.Text = "A little more…"
		self:motion(rig, 0.22, { Rotation = 6, Size = UDim2.fromOffset(heroSize * 0.56, heroSize * 0.87) })
		self:motion(glowEdge, 0.5, { Transparency = 0.10, Thickness = if rare then 4 else 3 })
		self:motion(glow, 0.5, { BackgroundTransparency = 0.85,
			Size = UDim2.fromOffset(heroSize * 1.15, heroSize * 1.15) })
	end)
	later(1.02, function()
		self:motion(rig, 0.20, { Rotation = -3, Size = UDim2.fromOffset(heroSize * 0.64, heroSize * 0.76) })
		self.audio:play("merge_bubble", 0.84, 0.28)
	end)
	if rare then
		later(1.30, function()
			anticipation.Text = "A rare glow…"
			anticipation.TextColor3 = Art.Amber
			self:motion(rig, 0.30, { Rotation = 4 })
			self:motion(shellScale, 0.35, { Scale = 1.12 })
			self.audio:play("charge", 1.12, 0.42)
		end)
	end
	later(burstAt, function()
		rig.Visible, anticipation.Visible = false, false
		self.audio:play("hatch", if rare then 0.92 else 1.02, 0.78)
		local _, _, scale, heading, caption = self:drawResult(result, true)
		scale.Scale = 0.08
		heading.TextTransparency, caption.TextTransparency = 1, 1
		self:motion(scale, 0.50, { Scale = 1 }, Enum.EasingStyle.Back)
		self:motion(heading, 0.36, { TextTransparency = 0 })
		self:motion(caption, 0.50, { TextTransparency = 0 })
		self:motion(glow, 0.64, { Size = UDim2.fromOffset(heroSize * 2.4, heroSize * 1.8), BackgroundTransparency = 1 })
		self:motion(glowEdge, 0.64, { Transparency = 1 })
		-- Four split shell plates, then a bounded garden-seed burst. No persistent emitters.
		for index = 1, 4 do
			local side = if index % 2 == 0 then 1 else -1
			local vertical = if index <= 2 then -1 else 1
			local shard = round(stage, "ShellPlate", pet.color:Lerp(Art.Silver, 0.72), center,
				UDim2.fromOffset(heroSize * 0.30, heroSize * 0.35), 51)
			self:motion(shard, 0.70, {
				Position = center + UDim2.fromOffset(side * heroSize * 0.9, vertical * heroSize * 0.6),
				Rotation = side * (80 + index * 15), BackgroundTransparency = 1,
			})
		end
		local count = if rare then 20 else 14
		for index = 1, count do
			local angle = index / count * math.pi * 2
			local radius = heroSize * (0.72 + (index % 3) * 0.17)
			local tint = if index % 3 == 0 then pet.color elseif index % 2 == 0 then accent else Art.Silver
			local seed = round(stage, "BloomSeed", tint, center,
				UDim2.fromOffset(if index % 3 == 0 then 5 else 3, if index % 3 == 0 then 12 else 5), 52)
			self:motion(seed, 0.55 + (index % 4) * 0.09, {
				Position = center + UDim2.fromOffset(math.cos(angle) * radius, math.sin(angle) * radius * 0.65),
				Rotation = math.deg(angle) + 90, BackgroundTransparency = 1,
			})
		end
	end)
	later(burstAt + 0.40, function() self.audio:play(pet.cue, if rare then 1.06 else 1, 0.60) end)
	later(endAt, function() self:finishStatic() end)
end

return Cinematic
