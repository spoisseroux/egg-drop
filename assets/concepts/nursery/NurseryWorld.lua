local World = {}
World.__index = World
local colors = { pip = Color3.fromHex("#A4D66B"), puddle = Color3.fromHex("#80D6F2"),
	wick = Color3.fromHex("#FFA63C"), orbit = Color3.fromHex("#C7AEF3") }

local function part(parent, name, size, pos, color, shape)
	local p = Instance.new("Part")
	p.Name, p.Size, p.Position, p.Color = name, size, pos, color
	p.Anchored, p.CanCollide, p.CanTouch = true, false, false
	p.Material = Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Parent = parent
	return p
end

function World.new(userId, slot, displayName, onOpen)
	local model = Instance.new("Model")
	model.Name = "Nursery_" .. userId
	model:SetAttribute("NurseryOwnerId", userId)
	local index = (slot - 1) % 10
	local origin = Vector3.new((index % 5 - 2) * 7.4, 4.4, if index < 5 then 13.1 else -13.1)
	local base = part(model, "Cradle", Vector3.new(3.4, 0.65, 2.4), origin, Color3.fromHex("#83582E"))
	part(model, "Moss", Vector3.new(3.05, 0.28, 2.08), origin + Vector3.new(0, .4, 0), Color3.fromHex("#527B38"))
	local egg = part(model, "Egg", Vector3.new(1.4, 1.8, 1.4), origin + Vector3.new(0, 1.4, 0), colors.pip, Enum.PartType.Ball)
	local glow = Instance.new("PointLight")
	glow.Color, glow.Range, glow.Brightness = colors.pip, 7, 0.3
	glow.Parent = egg
	local leaves = {}
	for i, sign in ipairs({ -1, 1 }) do
		local leaf = part(model, "Leaf" .. i, Vector3.new(.8, .16, .48), origin + Vector3.new(sign * .8, .65, 0), colors.pip, Enum.PartType.Ball)
		leaf.CFrame *= CFrame.Angles(0, 0, sign * .35)
		leaves[i] = leaf
	end
	local sockets = {}
	for i, sign in ipairs({ -1, 1 }) do
		sockets[i] = part(model, "Finish" .. i, Vector3.new(.45, .6, .45), origin + Vector3.new(sign * 1.1, .85, .45), colors.pip, Enum.PartType.Ball)
		sockets[i].Transparency = 1
	end
	local tag = Instance.new("BillboardGui")
	tag.Name, tag.Size, tag.StudsOffset, tag.MaxDistance = "NurseryLabel", UDim2.fromOffset(190, 42), Vector3.new(0, 3.2, 0), 24
	tag.Parent, tag.Adornee = base, base
	local title = Instance.new("TextLabel")
	title.Size, title.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	title.Font, title.TextSize, title.TextColor3 = Enum.Font.GothamBold, 12, Color3.fromHex("#F4F8E9")
	title.TextStrokeTransparency = .45
	title.Text = displayName .. "’s nursery"
	title.Parent = tag
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name, prompt.ActionText, prompt.ObjectText = "OpenNursery", "Tend egg", displayName .. "’s nursery"
	prompt.MaxActivationDistance, prompt.HoldDuration, prompt.RequiresLineOfSight = 10, 0, false
	prompt:SetAttribute("NurseryOwnerId", userId)
	prompt.Parent = base
	local connection = prompt.Triggered:Connect(function(player)
		if player.UserId == userId then onOpen(player) end
	end)
	model.Parent = workspace:WaitForChild("EggDropLounge")
	return setmetatable({ model = model, base = base, egg = egg, glow = glow, leaves = leaves,
		sockets = sockets, label = title, name = displayName, origin = origin, connection = connection }, World)
end

function World:near(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - self.origin).Magnitude <= 12
end

function World:update(state)
	local project = state.project
	local fraction = if project then project.funded / (if project.recipe == "sprout" then 24 else 18) else 0
	self.egg.Transparency = if project then 0 else .75
	self.egg.Size = Vector3.new(1.1, 1.4, 1.1) * (1 + fraction * .35)
	self.glow.Brightness = .3 + fraction * .5
	self.egg.Color = if project and project.guaranteed then Color3.fromHex("#FFC85A") else colors.pip
	self.label.Text = self.name .. "’s nursery\n" .. (if project then
		(if project.ready then "Ready to hatch!" else string.format("Growing · %d nectar", project.funded)) else "Choose an egg")
	local unlocked = {}
	for _, family in ipairs({ "pip", "puddle", "wick", "orbit" }) do
		if (state.mastery[family] or 0) >= 3 then table.insert(unlocked, family) end
	end
	for i, socket in ipairs(self.sockets) do
		local family = state.display and state.display[i] or unlocked[i]
		socket.Transparency = if family and colors[family] then 0 else 1
		if family and colors[family] then socket.Color = colors[family] end
	end
end

function World:destroy()
	self.connection:Disconnect()
	self.model:Destroy()
end

return World
