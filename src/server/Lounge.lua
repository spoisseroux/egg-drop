local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.DeckPalette)
local Themes = require(ReplicatedStorage.Shared.DeckThemes)
local Stickers = require(ReplicatedStorage.Shared.DeckStickers)

local LoungeArt = require(script.Parent.LoungeArt)
local WorldLayout = require(ReplicatedStorage.Shared.HollowWorldLayout)
local Players = game:GetService("Players")

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

-- Feet-on-ground spawn frame for a player slot. Legacy: rows near the hub.
-- v7: a small grid on the arrival dais, facing the hub across the bridge.
function Lounge.spawnFrame(slot, humanoid, root, room)
	local lift = humanoid.HipHeight + root.Size.Y / 2 + 0.1
	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		local leg = humanoid.Parent and humanoid.Parent:FindFirstChild("Left Leg")
		if leg then
			lift += leg.Size.Y
		end
	end
	if WorldLayout.WorldVersion ~= "v7" then
		local x = ((slot - 1) % 5 - 2) * 5.5
		local z = 4 + math.floor(((slot - 1) % 10) / 5) * 5
		return CFrame.new(x, 4 + lift, z) * CFrame.Angles(0, math.pi, 0)
	end
	local spawn = WorldLayout.Spawn
	local at = spawn:PointToWorldSpace(Vector3.new(((slot - 1) % 5 - 2) * 3, 0, math.floor(((slot - 1) % 10) / 5) * 3.5))
	local ground = at.Y
	if room then
		local params = RaycastParams.new()
		params.FilterType, params.FilterDescendantsInstances, params.RespectCanCollide = Enum.RaycastFilterType.Include, { room }, true
		local hit = workspace:Raycast(at + Vector3.new(0, 20, 0), Vector3.new(0, -40, 0), params)
		if hit then
			ground = hit.Position.Y
		end
	end
	return CFrame.new(at.X, ground + lift, at.Z) * spawn.Rotation
end

-- v7 FallCatch: anyone who drops off the island is put back on the arrival dais.
local function watchFallCatch(room)
	local catch = room:FindFirstChild("FallCatch")
	if not catch then
		return
	end
	local busy = {}
	catch.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not player or not humanoid or not root or busy[player] then
			return
		end
		busy[player] = true
		root.AssemblyLinearVelocity = Vector3.zero
		character:PivotTo(Lounge.spawnFrame(player.UserId % 5 + 1, humanoid, root, room))
		task.delay(1, function()
			busy[player] = nil
		end)
	end)
end

function Lounge.create()
	local room = Instance.new("Model")
	room.Name = "EggDropLounge"
	LoungeArt.build(room, part)
	room.Parent = workspace
	watchFallCatch(room)
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
	device.FrontPlate.Color = theme.face or theme.shell:Lerp(theme.trim, 0.27)
	device.Bezel.Color = theme.trim
	device.Screen.Color = if theme.lcd then theme.lcd.base else Color3.fromHex("#C6DFA0")
	device.AimRocker.Color = theme.rocker or Color3.fromHex("#283744")
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
	-- The device's Front (screen, controls, sticker) faces back toward the holder's
	-- face: turned 180 degrees about Y and tipped 22 degrees up toward the eyes.
	-- Device +X therefore lies on the holder's left, so the rocker reads left and A right.
	local mount = CFrame.new(0, -0.39, -1.02) * CFrame.Angles(math.rad(-22), math.pi, 0)
	local shell = attach(device, torso, "Shell", Vector3.new(1.84, 0.87, 0.17), mount, Palette.Shell)
	attach(device, torso, "FrontPlate", Vector3.new(1.78, 0.81, 0.025),
		mount * CFrame.new(0, 0, -0.085), Palette.Shell)
	local stickerFace = Instance.new("SurfaceGui")
	stickerFace.Name = "StickerFace"
	stickerFace.Face = Enum.NormalId.Front
	stickerFace.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	stickerFace.CanvasSize = Vector2.new(178, 81)
	stickerFace.LightInfluence = 0
	stickerFace.MaxDistance = 34
	stickerFace.Parent = shell
	local decal = Instance.new("Frame")
	decal.Name = "Decal"
	decal.Position = UDim2.fromOffset(119, 17)
	decal.Size = UDim2.fromOffset(48, 48)
	decal.Rotation = -11
	decal.BorderSizePixel = 0
	decal.Parent = stickerFace
	local rounded = Instance.new("UICorner")
	rounded.CornerRadius = UDim.new(0, 4)
	rounded.Parent = decal
	-- Mount the decal on the face plate so the new layered shell cannot cover it.
	stickerFace.Adornee = device.FrontPlate
	stickerFace.ZOffset = 1
	attach(device, torso, "Bezel", Vector3.new(0.69, 0.74, 0.026),
		mount * CFrame.new(0, 0.022, -0.109), Palette.Rim)
	local screen = attach(device, torso, "Screen", Vector3.new(0.49, 0.665, 0.029),
		mount * CFrame.new(0, 0.022, -0.131), Color3.fromHex("#C6DFA0"))
	local power = attach(device, torso, "Power", Vector3.new(0.055, 0.055, 0.027),
		mount * CFrame.new(-0.75, 0.25, -0.102), Color3.fromHex("#C2EC74"))
	power.Material = Enum.Material.Neon
	attach(device, torso, "AimRocker", Vector3.new(0.27, 0.13, 0.06),
		mount * CFrame.new(0.59, -0.24, -0.112), Palette.Ink)
	attach(device, torso, "AimDivider", Vector3.new(0.018, 0.105, 0.012),
		mount * CFrame.new(0.59, -0.24, -0.146), Palette.Rim)
	local buttonA = attach(device, torso, "Confirm", Vector3.new(0.06, 0.19, 0.19),
		mount * CFrame.new(-0.60, -0.24, -0.120) * CFrame.Angles(0, math.pi / 2, 0), Palette.Primary)
	buttonA.Shape = Enum.PartType.Cylinder
	attach(device, torso, "Customize", Vector3.new(0.18, 0.05, 0.04), mount * CFrame.new(0.59, 0.10, -0.107), Palette.Ink)
	attach(device, torso, "Lounge", Vector3.new(0.18, 0.05, 0.04), mount * CFrame.new(0.59, 0.0, -0.107), Palette.Ink)
	for index = 0, 2 do
		attach(device, torso, "SpeakerSlot", Vector3.new(0.018, 0.11, 0.017),
			mount * CFrame.new(-0.65 - index * 0.044, 0.12, -0.107) * CFrame.Angles(0, 0, math.rad(-22)), Palette.Ink)
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
			-- Shell +X is the holder's left; grip from the holder's side of the shell.
			target.Position = Vector3.new(if side == "Left" then 0.88 else -0.88, -0.27, -0.10)
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
	character:PivotTo(Lounge.spawnFrame(slot, humanoid, root, workspace:FindFirstChild("EggDropLounge")))
	local mode, themeId, stickerId = deckState()
	Lounge.setMode(character, player.UserId, mode, themeId, stickerId)
end

return Lounge
