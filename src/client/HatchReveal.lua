local TweenService = game:GetService("TweenService")
local Palette = require(game:GetService("ReplicatedStorage").Shared.DeckPalette)
local Art = require(script.Parent.DeckArt)

local Reveal = {}
Reveal.__index = Reveal

local function shape(parent, name, color, position, size, z)
	local piece = Instance.new("Frame")
	piece.Name = name
	piece.AnchorPoint = Vector2.new(0.5, 0.5)
	piece.Position = position
	piece.Size = size
	piece.BackgroundColor3 = color
	piece.BorderSizePixel = 0
	piece.ZIndex = z
	local round = Instance.new("UICorner")
	round.CornerRadius = UDim.new(0.5, 0)
	round.Parent = piece
	piece.Parent = parent
	return piece
end

function Reveal.new(card, pet, audio)
	local layer = Instance.new("Frame")
	layer.Name = "HatchAnimation"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 11
	layer.Parent = card
	local scale = Instance.new("UIScale")
	scale.Parent = pet
	return setmetatable({ layer = layer, pet = pet, scale = scale, audio = audio, epoch = 0, tweens = {} }, Reveal)
end

function Reveal:cancel()
	self.epoch += 1
	for _, tween in ipairs(self.tweens) do
		tween:Cancel()
	end
	table.clear(self.tweens)
	self.layer:ClearAllChildren()
	self.scale.Scale = 1
	self.pet.Interactable = true
end

function Reveal:playTween(node, seconds, properties, style)
	local tween = TweenService:Create(node, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad), properties)
	table.insert(self.tweens, tween)
	tween:Play()
end

function Reveal:start(valid, cue, color)
	self:cancel()
	local epoch = self.epoch
	local function after(seconds, action)
		task.delay(seconds, function()
			if self.epoch == epoch and valid() then
				action()
			end
		end)
	end
	local center = UDim2.new(0.5, 0, 0, 108)
	local egg = shape(self.layer, "HatchEgg", color, center, UDim2.fromOffset(58, 68), 13)
	local outline = Instance.new("UIStroke")
	outline.Color, outline.Thickness = Art.Silver, 2
	outline.Parent = egg
	shape(egg, "Glint", Palette.Paper, UDim2.fromScale(0.31, 0.25), UDim2.fromOffset(18, 7), 14).Rotation = -24
	local crack = Art.pixels(egg, "Crack", { "..XX", ".XX.", ".X..", "XX..", ".XX.", "..X." },
		{ X = Art.Ink }, 3, UDim2.new(0.5, -6, 0.45, 0), 15)
	crack.Visible = false
	self.scale.Scale = 0.05
	self.pet.Interactable = false
	self.audio:play("hatch_rise")
	self:playTween(egg, 0.17, { Size = UDim2.fromOffset(69, 54), Rotation = -11 })
	after(0.17, function()
		crack.Visible = true
		self:playTween(egg, 0.18, { Size = UDim2.fromOffset(55, 72), Rotation = 9 })
	end)
	after(0.36, function()
		egg:Destroy()
		self.audio:play("hatch")
		self:playTween(self.scale, 0.36, { Scale = 1 }, Enum.EasingStyle.Back)
		local ring = shape(self.layer, "HatchRing", Palette.Amber, center, UDim2.fromOffset(45, 45), 12)
		ring.BackgroundTransparency = 1
		local glow = Instance.new("UIStroke")
		glow.Color, glow.Thickness = Art.Amber, 2
		glow.Parent = ring
		self:playTween(ring, 0.48, { Size = UDim2.fromOffset(176, 94) })
		self:playTween(glow, 0.48, { Transparency = 1 })
		for index = 1, 6 do
			local angle = index * math.pi / 3
			local x, y = math.cos(angle), math.sin(angle)
			local shard = Art.frame(self.layer, "ShellChip", color, center + UDim2.fromOffset(x * 13, y * 13),
				UDim2.fromOffset(8 + index % 3 * 3, 8), 13)
			shard.AnchorPoint = Vector2.new(0.5, 0.5)
			shard.Rotation = math.deg(angle)
			self:playTween(shard, 0.44, {
				Position = center + UDim2.fromOffset(x * 83, y * 39), Rotation = math.deg(angle) + 65,
				BackgroundTransparency = 1,
			})
		end
		for i = 1, 8 do
			local angle = i * math.pi / 4
			local tint = if i % 2 == 0 then Art.Amber else Art.Cyan
			local fleck = Art.frame(self.layer, "PixelRay", tint, center, UDim2.fromOffset(9, 3), 12)
			fleck.AnchorPoint = Vector2.new(0.5, 0.5)
			fleck.Rotation = math.deg(angle)
			self:playTween(fleck, 0.52, {
				Position = center + UDim2.fromOffset(math.cos(angle) * 83, math.sin(angle) * 44),
				Size = UDim2.fromOffset(15, 2), BackgroundTransparency = 1,
			})
		end
	end)
	after(0.65, function()
		self.audio:play(cue, 1, 0.53)
	end)
	after(0.94, function()
		self:cancel()
	end)
end

return Reveal
