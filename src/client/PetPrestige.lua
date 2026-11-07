local HttpService = game:GetService("HttpService")
local FamilyCrest = require(script.Parent.FamilyCrest)
local GuiService=game:GetService("GuiService")
local RigBounds=require(script.Parent.PetRigBounds)
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
		badge.Size, badge.StudsOffsetWorldSpace = UDim2.fromOffset(46, 26), Vector3.zero
		badge.Enabled=false;visual.prestigeBadge=badge
		badge.AlwaysOnTop, badge.LightInfluence, badge.MaxDistance = false, 0, 30
		badge.Parent = body
		local plate = shape(badge, "Crest", UDim2.fromOffset(0, 0), UDim2.fromScale(1, 1), Color3.fromHex("#314738"), 0.24)
		local stroke = Instance.new("UIStroke")
		stroke.Color, stroke.Thickness, stroke.Parent = tint, if rank == 3 then 2 else 1, plate
		FamilyCrest.create(plate, pet.family or pet.id, rank, UDim2.fromOffset(1, 1), UDim2.fromOffset(24, 24), 2)

		local text = Instance.new("TextLabel")
		text.Name, text.BackgroundTransparency = "Rank", 1
		text.Position, text.Size = UDim2.fromOffset(26, 0), UDim2.new(1, -27, 1, 0)
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
		local scale=visual.worldScale or 1
		emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12*scale), NumberSequenceKeypoint.new(1, 0) })
		emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 1) })
		emitter.Lifetime, emitter.Speed, emitter.SpreadAngle = NumberRange.new(0.45, 0.7), NumberRange.new(0.5*scale, 1.3*scale), Vector2.new(55, 55)
		emitter.Acceleration, emitter.Rate, emitter.Enabled = Vector3.new(0, 0.8*scale, 0), 0, false
		emitter.Parent = body
		visual.masteryEmitter, visual.masteryBurstIn = emitter, 3
	end
end

-- One native post-pose OBB and eight projections; no descendant walks,
-- raycasts, attachment parts or per-frame GUI allocation.
function Prestige.updateBadge(visual,camera)
	local badge=visual.prestigeBadge
	if not badge or not badge.Parent then return end
	local body=visual.model.PrimaryPart
	if not camera or not body or not visual.model.Parent then badge.Enabled=false;return end
	local viewport=camera.ViewportSize
	if viewport.X<1 or viewport.Y<1 or (camera.CFrame.Position-body.Position).Magnitude>badge.MaxDistance then badge.Enabled=false;return end
	local cf,size=RigBounds.get(visual)
	local left,top,right,bottom=math.huge,math.huge,-math.huge,-math.huge
	for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do
		local point=camera:WorldToViewportPoint(cf:PointToWorldSpace(Vector3.new(size.X*x,size.Y*y,size.Z*z)*.5))
		if point.Z<=.1 then badge.Enabled=false;return end
		left,top,right,bottom=math.min(left,point.X),math.min(top,point.Y),math.max(right,point.X),math.max(bottom,point.Y)
	end end end
	local center=camera:WorldToViewportPoint(cf.Position)
	local px=(left+right)*.5;local py=top-5-13
	local inset,bottomInset=GuiService:GetGuiInset()
	if right<inset.X or left>viewport.X-bottomInset.X or bottom<inset.Y or top>viewport.Y-bottomInset.Y then badge.Enabled=false;return end
	if px-23<inset.X+4 or px+23>viewport.X-bottomInset.X-4 or py-13<inset.Y+4 or py+13>viewport.Y-bottomInset.Y-4 then badge.Enabled=false;return end
	local unit=2*center.Z*math.tan(math.rad(camera.FieldOfView)*.5)/viewport.Y
	local position=cf.Position+camera.CFrame.RightVector*((px-center.X)*unit)+camera.CFrame.UpVector*((center.Y-py)*unit)
	badge.StudsOffsetWorldSpace=position-body.Position;badge.Enabled=true
end
function Prestige.crestReserve(visual)return if visual.prestigeBadge and visual.prestigeBadge.Parent then 32 else 0 end

function Prestige.update(visual, dt, reduced)
	Prestige.updateBadge(visual,workspace.CurrentCamera)
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
