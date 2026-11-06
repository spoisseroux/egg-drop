-- Static, asset-free family/rank artwork. Hosts survive repeated HUD updates.
local Art = require(script.Parent.DeckArt)
local Crest = {}
local colors = { pip = Color3.fromHex("#99CD75"), puddle = Color3.fromHex("#75D5DF"),
	wick = Color3.fromHex("#FFBF64"), orbit = Color3.fromHex("#C3ACF2") }

local function shape(parent, name, x, y, width, height, color, radius, rotation)
	local node = Art.frame(parent, name, color, UDim2.fromScale(x, y), UDim2.fromScale(width, height), parent.ZIndex + 1)
	node.Rotation = rotation or 0
	if radius then
		local corner = Instance.new("UICorner")
		corner.CornerRadius, corner.Parent = UDim.new(radius, 0), node
	end
	return node
end

function Crest.update(host, family, rank, muted)
	family = if colors[family] then family else "pip"
	rank = math.clamp(math.floor(rank or 0), 0, 3)
	local key = family .. ":" .. rank .. ":" .. tostring(muted == true)
	if host:GetAttribute("CrestKey") == key then return host end
	host:SetAttribute("CrestKey", key)
	host:SetAttribute("Family", family)
	host:SetAttribute("Rank", rank)
	local previous = host:FindFirstChild("Artwork")
	if previous then previous:Destroy() end
	local root = Art.frame(host, "Artwork", Art.Ink, UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), host.ZIndex)
	root.BackgroundTransparency = 1
	local tint = if muted then Art.Muted:Lerp(Art.Raised, .4) else colors[family]
	if rank == 3 then
		for i = 0, 5 do
			local angle = i * math.pi / 3
			shape(root, "BloomPetal", .32 + math.cos(angle) * .32, .32 + math.sin(angle) * .32, .36, .36, tint, .5)
		end
	end
	if rank > 0 then
		local inset = if rank == 3 then .23 else .12
		local plate = shape(root, if rank == 2 then "FramedSeal" else "RoundSeal", inset, inset, 1 - inset * 2, 1 - inset * 2,
			Art.Ink, if rank == 2 then .14 else .5)
		Art.stroke(plate, Art.Silver, .1, if rank == 2 then 2 else 1)
		if rank == 2 then
			local inner = shape(plate, "InnerFrame", .13, .13, .74, .74, Art.Ink, .12)
			Art.stroke(inner, tint, .1, 1)
		end
	end
	local motif = Art.frame(root, "Motif", tint,
		UDim2.fromScale(if rank > 0 then .24 else .12, if rank > 0 then .24 else .12),
		UDim2.fromScale(if rank > 0 then .52 else .76, if rank > 0 then .52 else .76), root.ZIndex + 4)
	motif.BackgroundTransparency = 1
	if family == "pip" then
		shape(motif, "Stem", .46, .31, .09, .58, tint, .4)
		shape(motif, "LeafLeft", .10, .22, .35, .52, tint, .5, -45)
		shape(motif, "LeafRight", .56, .02, .35, .52, tint, .5, 45)
	elseif family == "puddle" then
		shape(motif, "Droplet", .27, .24, .47, .48, tint, .5)
		shape(motif, "DropletTip", .35, .11, .30, .30, tint, .1, 45)
		shape(motif, "Ripple", .12, .80, .76, .08, tint, .5)
	elseif family == "wick" then
		shape(motif, "Flame", .26, .12, .50, .76, tint, .4, 12)
		shape(motif, "FlameTip", .48, .04, .25, .38, tint, .12, 30)
		shape(motif, "FlameCore", .41, .45, .22, .37, Art.Silver, .5)
	else
		local ring = shape(motif, "OrbitRing", .07, .38, .86, .34, tint, .5, -28)
		ring.BackgroundTransparency = 1
		Art.stroke(ring, tint, 0, 1.5)
		shape(motif, "Moon", .42, .10, .36, .36, tint, .5)
		shape(motif, "Satellite", .08, .65, .16, .16, Art.Silver, .5)
	end
	return host
end

function Crest.create(parent, family, rank, position, size, z, muted)
	local host = Art.frame(parent, "FamilyCrest", Art.Ink, position, size, z or parent.ZIndex + 1)
	host.BackgroundTransparency = 1
	Crest.update(host, family, rank, muted)
	return host
end

return Crest
