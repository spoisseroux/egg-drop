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
	local mount = CFrame.new(0, -0.42, -1.05) * CFrame.Angles(math.rad(37), 0, 0)
	local shell = attach(device, torso, "Shell", Vector3.new(1.12, 1.45, 0.21), mount, Palette.Shell)
	local stickerFace = Instance.new("SurfaceGui")
	stickerFace.Name = "StickerFace"
	stickerFace.Face = Enum.NormalId.Front
	stickerFace.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	stickerFace.CanvasSize = Vector2.new(112, 145)
	stickerFace.LightInfluence = 0
	stickerFace.MaxDistance = 34
	stickerFace.Parent = shell
	local decal = Instance.new("TextLabel")
	decal.Name = "Decal"
	decal.Position = UDim2.fromOffset(44, 103)
	decal.Size = UDim2.fromOffset(19, 19)
	decal.Rotation = -11
	decal.TextSize = 16
	decal.Font = Enum.Font.GothamBold
	decal.BorderSizePixel = 0
	decal.Parent = stickerFace
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, 4)
	rounded.Parent = decal
	attach(device, torso, "Bezel", Vector3.new(0.91, 0.94, 0.04),
		mount * CFrame.new(0, 0.2, -0.109), Palette.Rim)
	local screen = attach(device, torso, "Screen", Vector3.new(0.84, 0.87, 0.08),
		mount * CFrame.new(0, 0.2, -0.12), Palette.Tray)
	attach(device, torso, "Left", Vector3.new(0.105, 0.10, 0.07), mount * CFrame.new(-0.34, -0.43, -0.12), Palette.Ink)
	attach(device, torso, "Right", Vector3.new(0.105, 0.10, 0.07), mount * CFrame.new(-0.20, -0.43, -0.12), Palette.Ink)
	attach(device, torso, "Confirm", Vector3.new(0.13, 0.13, 0.07), mount * CFrame.new(0.29, -0.39, -0.12), Palette.Primary)
	attach(device, torso, "Customize", Vector3.new(0.15, 0.05, 0.04), mount * CFrame.new(-0.12, -0.58, -0.12), Palette.Ink)
	attach(device, torso, "Lounge", Vector3.new(0.15, 0.05, 0.04), mount * CFrame.new(0.12, -0.58, -0.12), Palette.Ink)
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
