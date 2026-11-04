local CollectionService = game:GetService("CollectionService")

local Lounge = {}

local violet = Color3.fromRGB(117, 92, 164)
local mint = Color3.fromRGB(162, 234, 179)

local function part(parent, name, size, transform, color, collides)
	local piece = Instance.new("Part")
	piece.Name = name
	piece.Size = size
	piece.CFrame = transform
	piece.Color = color
	piece.Material = Enum.Material.SmoothPlastic
	piece.Anchored = true
	piece.CanCollide = collides == true
	piece.TopSurface = Enum.SurfaceType.Smooth
	piece.BottomSurface = Enum.SurfaceType.Smooth
	piece.Parent = parent
	return piece
end

local function sign(parent, words, color)
	local screen = Instance.new("SurfaceGui")
	screen.Face = Enum.NormalId.Back
	screen.CanvasSize = Vector2.new(600, 120)
	screen.LightInfluence = 0
	screen.Parent = parent
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = words
	text.TextColor3 = color
	text.TextScaled = true
	text.Font = Enum.Font.Code
	text.Parent = screen
end

function Lounge.create()
	local room = Instance.new("Model")
	room.Name = "EggDropLounge"
	local floor = part(room, "Floor", Vector3.new(40, 1, 32), CFrame.new(0, 3.5, 0),
		Color3.fromRGB(57, 46, 80), true)
	floor.Material = Enum.Material.Slate
	part(room, "BackWall", Vector3.new(40, 13, 1), CFrame.new(0, 10, -15.5), Color3.fromRGB(43, 34, 68), true)
	for _, side in ipairs({ -1, 1 }) do
		part(room, "SideWall", Vector3.new(1, 5, 32), CFrame.new(side * 19.5, 6.5, 0),
			Color3.fromRGB(66, 52, 93), true)
		part(room, "Bench", Vector3.new(8, 1.1, 2.8), CFrame.new(side * 12, 4.55, -8), violet, true)
		local lamp = part(room, "Lamp", Vector3.new(0.7, 4.4, 0.7), CFrame.new(side * 8, 8.3, -14.75), mint, false)
		lamp.Material = Enum.Material.Neon
		local light = Instance.new("PointLight")
		light.Color = mint
		light.Range = 18
		light.Brightness = 1.1
		light.Parent = lamp
	end
	part(room, "FrontRail", Vector3.new(40, 2, 0.7), CFrame.new(0, 5, 15.6),
		Color3.fromRGB(66, 52, 93), true)
	part(room, "PipMat", Vector3.new(8, 0.2, 6), CFrame.new(0, 4.1, -5), violet, true)
	for x = -3, 3, 2 do
		part(room, "MatStripe", Vector3.new(0.08, 0.02, 5.8), CFrame.new(x, 4.21, -5), mint, false)
	end
	local marquee = part(room, "Marquee", Vector3.new(13, 2.1, 0.26), CFrame.new(0, 11.5, -14.9),
		Color3.fromRGB(29, 22, 51), false)
	sign(marquee, "EGG DROP   /   LOUNGE", mint)
	room.Parent = workspace
end

local function attach(model, torso, name, size, offset, color)
	local piece = part(model, name, size, torso.CFrame * offset, color, false)
	piece.Anchored = false
	piece.Massless = true
	piece.CanTouch = false
	piece.CanQuery = false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = piece
	weld.Parent = piece
	return piece
end

function Lounge.setMode(character, userId, mode)
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	local torso = character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	if not root or not torso then
		return
	end
	local device = character:FindFirstChild("PocketDeck")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if mode == "Room" then
		if device then
			device:Destroy()
		end
		if humanoid then
			for _, name in ipairs({ "DeckLeft", "DeckRight" }) do
				local grip = humanoid:FindFirstChild(name)
				if grip then
					grip:Destroy()
				end
			end
		end
		root.Anchored = false
		return
	end
	root.Anchored = true
	if device then
		return
	end

	device = Instance.new("Model")
	device.Name = "PocketDeck"
	device:SetAttribute("BoardUserId", userId)
	local mount = CFrame.new(0, -0.42, -1.05) * CFrame.Angles(math.rad(37), 0, 0)
	local shell = attach(device, torso, "Shell", Vector3.new(1.12, 1.45, 0.21), mount, violet)
	local screen = attach(device, torso, "Screen", Vector3.new(0.84, 0.87, 0.08),
		mount * CFrame.new(0, 0.2, -0.12), Color3.fromRGB(31, 46, 58))
	attach(device, torso, "DPad", Vector3.new(0.26, 0.08, 0.07), mount * CFrame.new(-0.26, -0.43, -0.12), Color3.fromRGB(44, 32, 65))
	attach(device, torso, "DPadStem", Vector3.new(0.08, 0.24, 0.07), mount * CFrame.new(-0.26, -0.43, -0.12), Color3.fromRGB(44, 32, 65))
	attach(device, torso, "Confirm", Vector3.new(0.13, 0.13, 0.07), mount * CFrame.new(0.29, -0.39, -0.12), mint)
	attach(device, torso, "Action", Vector3.new(0.12, 0.12, 0.07), mount * CFrame.new(0.12, -0.5, -0.12),
		Color3.fromRGB(241, 151, 146))
	local badge = Instance.new("BillboardGui")
	badge.Name = "Playing"
	badge.Adornee = screen
	badge.Size = UDim2.fromOffset(145, 21)
	badge.StudsOffset = Vector3.new(0, 2.2, 0)
	badge.MaxDistance = 25
	badge.Parent = screen
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Color3.fromRGB(32, 27, 52)
	text.BackgroundTransparency = 0.18
	text.BorderSizePixel = 0
	text.Text = "PLAYING EGG DROP"
	text.TextColor3 = mint
	text.Font = Enum.Font.Code
	text.TextSize = 12
	text.Parent = badge
	device.Parent = character
	CollectionService:AddTag(device, "EggDropHandheld")
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = character:FindFirstChild(side .. "UpperArm")
		local hand = character:FindFirstChild(side .. "Hand")
		if humanoid and arm and hand then
			local target = Instance.new("Attachment")
			target.Name = side .. "Grip"
			target.Position = Vector3.new(if side == "Left" then -0.55 else 0.55, -0.34, 0.02)
			target.Parent = shell
			local grip = Instance.new("IKControl")
			grip.Name = "Deck" .. side
			grip.Type = Enum.IKControlType.Position
			grip.ChainRoot = arm
			grip.EndEffector = hand
			grip.Target = target
			grip.Parent = humanoid
		end
	end
end

function Lounge.spawn(character, slot, player, mode)
	local root = character:WaitForChild("HumanoidRootPart", 5)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not root or not humanoid then
		return
	end
	local torsoName = if humanoid.RigType == Enum.HumanoidRigType.R15 then "UpperTorso" else "Torso"
	if not character:WaitForChild(torsoName, 5) then
		return
	end
	local timeout = os.clock() + 5
	while player.Character == character and not character:IsDescendantOf(workspace) and os.clock() < timeout do
		task.wait()
	end
	if player.Character ~= character or not character:IsDescendantOf(workspace) then
		return
	end
	local x = ((slot - 1) % 5 - 2) * 5.5
	local z = 4 + math.floor(((slot - 1) % 10) / 5) * 5
	local height = 4 + humanoid.HipHeight + root.Size.Y / 2 + 0.1
	local leg = if humanoid.RigType == Enum.HumanoidRigType.R6 then character:FindFirstChild("Left Leg") else nil
	if leg then
		height += leg.Size.Y
	end
	character:PivotTo(CFrame.new(x, height, z) * CFrame.Angles(0, math.pi, 0))
	Lounge.setMode(character, player.UserId, mode())
end

return Lounge
