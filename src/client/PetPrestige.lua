local HttpService = game:GetService("HttpService")
local Prestige = {}
local families = { "pip", "puddle", "wick", "orbit" }
local roman = { "I", "II", "III" }
local colors = {
	pip = Color3.fromHex("#99CD75"), puddle = Color3.fromHex("#75D5DF"),
	wick = Color3.fromHex("#FFBF64"), orbit = Color3.fromHex("#C3ACF2"),
}

function Prestige.read(board, pet)
	local family = pet.family or pet.id
	local encoded = board:GetAttribute("MasteryRanks")
	local rank = 0
	if type(encoded) == "string" then
		local ok, ranks = pcall(HttpService.JSONDecode, HttpService, encoded)
		if ok and type(ranks) == "table" then
			local value = ranks[family]
			if type(value) == "table" then value = value.rank end
			if type(value) == "number" then rank = math.clamp(math.floor(value), 0, 3) end
		end
	end
	local index = table.find(families, family)
	local legacy = index and bit32.band(board:GetAttribute("MasteryMask") or 0, bit32.lshift(1, index - 1)) ~= 0
	return rank, legacy == true
end

local function shape(parent, name, position, size, tint, round, rotation)
	local node = Instance.new("Frame")
	node.Name, node.Position, node.Size = name, position, size
	node.BorderSizePixel, node.BackgroundColor3, node.Rotation = 0, tint, rotation or 0
	node.Parent = parent
	if round then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(round, 0)
		corner.Parent = node
	end
	return node
end

function Prestige.attach(visual, pet, rank, legacy)
	local body = visual.model.PrimaryPart
	if not body then return end
	visual.model:SetAttribute("MasteryRank", rank)
	visual.model:SetAttribute("LegacyMasteryFinish", legacy == true)
	local tint = colors[pet.family or pet.id] or pet.color
	if rank > 0 then
		local badge = Instance.new("BillboardGui")
		badge.Name, badge.Adornee = "FamilyPrestigeBadge", body
		badge.Size, badge.StudsOffsetWorldSpace = UDim2.fromOffset(46, 26), Vector3.new(1.05, 0.55, 0)
		badge.AlwaysOnTop, badge.LightInfluence, badge.MaxDistance = false, 0, 30
		badge.Parent = body
		local plate = shape(badge, "Crest", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), Color3.fromHex("#314738"), 0.24)
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness, stroke.Parent = tint, if rank == 3 then 2 else 1, plate
		local family = pet.family or pet.id
		if family == "pip" then
			shape(plate, "Leaf", UDim2.fromOffset(7, 5), UDim2.fromOffset(10, 16), tint, 0.5, 35)
		elseif family == "puddle" then
			shape(plate, "Droplet", UDim2.fromOffset(6, 8), UDim2.fromOffset(13, 13), tint, 0.5)
			shape(plate, "DropTip", UDim2.fromOffset(9, 5), UDim2.fromOffset(7, 7), tint, 0.1, 45)
		elseif family == "wick" then
			shape(plate, "Flame", UDim2.fromOffset(7, 5), UDim2.fromOffset(11, 16), tint, 0.3, 12)
			shape(plate, "FlameCore", UDim2.fromOffset(10, 11), UDim2.fromOffset(5, 8), Color3.fromHex("#FFF0C1"), 0.4)
		else
			local orbit = shape(plate, "Orbit", UDim2.fromOffset(5, 8), UDim2.fromOffset(16, 10), tint, 0.5, -25)
			shape(orbit, "Hole", UDim2.fromOffset(2, 2), UDim2.new(1, -4, 1, -4), plate.BackgroundColor3, 0.5)
			shape(plate, "Moon", UDim2.fromOffset(11, 4), UDim2.fromOffset(7, 7), Color3.fromHex("#FFF0C1"), 0.5)
		end
		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency = "Rank", 1
		text.Position, text.Size = UDim2.fromOffset(23, 0), UDim2.new(1, -24, 1, 0)
		text.Text, text.Font, text.TextSize, text.TextColor3 = roman[rank], Enum.Font.GothamBold, 12, Color3.fromHex("#FFF0C1")
		text.Parent = plate
	end
	if rank >= 2 then
		local finish = Instance.new("Highlight")
		finish.Name, finish.Adornee = "FamilyAccentFinish", visual.model
		finish.DepthMode, finish.FillTransparency = Enum.HighlightDepthMode.Occluded, 1
		finish.OutlineColor, finish.OutlineTransparency, finish.Parent = tint, 0.65, visual.model
	end
	if rank >= 3 or legacy then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Name, emitter.Texture = "FamilyFlourish", "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color, emitter.LightEmission = ColorSequence.new(tint), 0.3
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime, emitter.Speed, emitter.SpreadAngle = NumberRange.new(0.45, 0.7), NumberRange.new(0.5, 1.3), Vector2.new(55, 55)
		emitter.Acceleration, emitter.Rate, emitter.Enabled = Vector3.new(0, 0.8, 0), 0, false
		emitter.Parent = body
		visual.masteryEmitter, visual.masteryBurstIn = emitter, 3
	end
end

function Prestige.update(visual, dt, reduced)
	if not visual.masteryEmitter then return end
	if reduced then
		visual.masteryEmitter:Clear()
		return
	end
	visual.masteryBurstIn = (visual.masteryBurstIn or 0) - dt
	if visual.masteryBurstIn <= 0 then
		visual.masteryBurstIn = 6
		visual.masteryEmitter:Emit(5)
	end
end

return Prestige
