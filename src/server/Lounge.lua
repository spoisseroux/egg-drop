local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.DeckPalette)
local Themes = require(ReplicatedStorage.Shared.DeckThemes)
local Stickers = require(ReplicatedStorage.Shared.DeckStickers)

local LoungeArt = require(script.Parent.LoungeArt)

local Lounge = {}

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

function Lounge.create()
	local room = Instance.new("Model")
	room.Name = "EggDropLounge"
	LoungeArt.build(room, part)
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

local function paintDevice(device, themeId, stickerId)
	local theme = Themes.ById[themeId] or Themes.ById[Themes.Default]
	device.Shell.Color = theme.shell
	device.FrontPlate.Color = theme.shell:Lerp(theme.trim, 0.18)
	device.Bezel.Color = theme.trim
	device.Confirm.Color = theme.buttons
	Stickers.paint(device.Shell.StickerFace.Decal, stickerId)
end

function Lounge.setAppearance(character, themeId, stickerId)
	local device = character and character:FindFirstChild("PocketDeck")
	if device then
		paintDevice(device, themeId, stickerId)
	end
end

function Lounge.setMode(character, userId, mode, themeId, stickerId)
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
	local mount = CFrame.new(0, -0.39, -1.02) * CFrame.Angles(math.rad(22), 0, 0)
	local shell = attach(device, torso, "Shell", Vector3.new(1.05, 1.65, 0.21), mount, Palette.Shell)
	attach(device, torso, "FrontPlate", Vector3.new(1.00, 1.60, 0.025),
		mount * CFrame.new(0, 0, -0.104), Palette.Shell)
	local stickerFace = Instance.new("SurfaceGui")
	stickerFace.Name = "StickerFace"
	stickerFace.Face = Enum.NormalId.Front
	stickerFace.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	stickerFace.CanvasSize = Vector2.new(105, 165)
	stickerFace.LightInfluence = 0
	stickerFace.MaxDistance = 34
	stickerFace.Parent = shell
	local decal = Instance.new("TextLabel")
	decal.Name = "Decal"
	decal.Position = UDim2.fromOffset(45, 112)
	decal.Size = UDim2.fromOffset(15, 15)
	decal.Rotation = -11
	decal.TextSize = 12
	decal.Font = Enum.Font.GothamBold
	decal.BorderSizePixel = 0
	decal.Parent = stickerFace
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, 4)
	rounded.Parent = decal
	-- Mount the decal on the face plate so the new layered shell cannot cover it.
	stickerFace.Adornee = device.FrontPlate
	stickerFace.ZOffset = 1
	attach(device, torso, "Bezel", Vector3.new(0.91, 0.93, 0.04),
		mount * CFrame.new(0, 0.275, -0.132), Palette.Rim)
	local screen = attach(device, torso, "Screen", Vector3.new(0.63, 0.855, 0.035),
		mount * CFrame.new(0, 0.275, -0.159), Color3.fromHex("#182C39"))
	local power = attach(device, torso, "Power", Vector3.new(0.055, 0.055, 0.027),
		mount * CFrame.new(0.391, 0.66, -0.153), Color3.fromHex("#54D9F3"))
	power.Material = Enum.Material.Neon
	attach(device, torso, "AimRocker", Vector3.new(0.27, 0.13, 0.06),
		mount * CFrame.new(0.24, -0.32, -0.135), Palette.Ink)
	attach(device, torso, "AimDivider", Vector3.new(0.018, 0.105, 0.012),
		mount * CFrame.new(0.24, -0.32, -0.168), Palette.Rim)
	local buttonA = attach(device, torso, "Confirm", Vector3.new(0.06, 0.19, 0.19),
		mount * CFrame.new(-0.24, -0.32, -0.145) * CFrame.Angles(0, math.pi / 2, 0), Palette.Primary)
	buttonA.Shape = Enum.PartType.Cylinder
	attach(device, torso, "Customize", Vector3.new(0.13, 0.044, 0.04), mount * CFrame.new(-0.13, -0.60, -0.128), Palette.Ink)
	attach(device, torso, "Lounge", Vector3.new(0.13, 0.044, 0.04), mount * CFrame.new(0.05, -0.60, -0.128), Palette.Ink)
	for index = 0, 2 do
		attach(device, torso, "SpeakerSlot", Vector3.new(0.018, 0.11, 0.017),
			mount * CFrame.new(-0.25 - index * 0.052, -0.66, -0.124) * CFrame.Angles(0, 0, math.rad(-22)), Palette.Ink)
	end
	paintDevice(device, themeId, stickerId)
	local badge = Instance.new("BillboardGui")
	badge.Name = "Playing"
	badge.Adornee = screen
	badge.Size = UDim2.fromOffset(145, 21)
	badge.StudsOffset = Vector3.new(0, 2.2, 0)
	badge.MaxDistance = 25
	badge.Parent = screen
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundColor3 = Palette.Ink
	text.BackgroundTransparency = 0.18
	text.BorderSizePixel = 0
	text.Text = "PLAYING EGG DROP"
	text.TextColor3 = Palette.Primary
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
			target.Position = Vector3.new(if side == "Left" then -0.54 else 0.54, -0.62, 0.075)
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

function Lounge.spawn(character, slot, player, deckState)
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
	local mode, themeId, stickerId = deckState()
	Lounge.setMode(character, player.UserId, mode, themeId, stickerId)
end

return Lounge
