local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Palette = require(ReplicatedStorage.Shared.DeckPalette)
local Themes = require(ReplicatedStorage.Shared.DeckThemes)

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
	task.spawn(Lounge.warmDeck) -- the held-deck meshes, before the first player
	local room = Instance.new("Model")
	room.Name = "EggDropLounge"
	LoungeArt.build(room, part)
	room.Parent = workspace
	watchFallCatch(room)
end

-- Pocket Deck Slim (UI-SPEC-2026-11-12 section 9): nine meshes from
-- pocket-deck-slim.fbx, kept as a template whose part CFrames are the
-- part-space centres. Each piece is welded at torso * mount * centre.
local ServerStorage = game:GetService("ServerStorage")
local AssetService = game:GetService("AssetService")
-- Mesh ids of the uploaded pocket-deck-slim.fbx (model asset 96845902742297).
-- Rojo's live sync cannot write MeshPart.MeshId, so a template part without a
-- mesh is rebuilt once with CreateMeshPartAsync and cached.
local SlimMeshes = {
	Shell = 115225104888385, FrontPlate = 79518867373692, Bezel = 111898830930565, Screen = 70629451066803,
	AimRocker = 97228572660844, Confirm = 107899862395983, Back = 96763978132853, Customize = 95398375566470,
	Power = 133032069698309,
}
local slimCache, slimBuilding
local function slimTemplate()
	if slimCache then return slimCache end
	while slimBuilding do task.wait() end
	if slimCache then return slimCache end
	local source = ServerStorage:FindFirstChild("PocketDeckSlim")
	if not source then return nil end
	slimBuilding = true
	local model = Instance.new("Model")
	model.Name = "PocketDeckSlimResolved"
	for _, piece in ipairs(source:GetChildren()) do
		if piece:IsA("MeshPart") then
			local resolved = piece
			if piece.MeshId == "" and SlimMeshes[piece.Name] then
				local ok, made = pcall(AssetService.CreateMeshPartAsync, AssetService, "rbxassetid://" .. SlimMeshes[piece.Name])
				if ok and made then
					made.Name, made.Size, made.CFrame = piece.Name, piece.Size, piece.CFrame
					resolved = made
				else
					warn("Egg Drop: deck mesh", piece.Name, made)
				end
			end
			local copy = if resolved == piece then piece:Clone() else resolved
			copy.Parent = model
		end
	end
	slimBuilding = false
	slimCache = model
	return model
end
local function weldPiece(piece, torso, offset)
	piece.CFrame = torso.CFrame * offset
	piece.Anchored = false
	piece.Massless = true
	piece.CanCollide, piece.CanTouch, piece.CanQuery = false, false, false
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = torso
	weld.Part1 = piece
	weld.Parent = piece
	return piece
end

local Colors = { glass = Color3.fromHex("#0C0D10"), bezel = Color3.fromHex("#08090B"), pad = Color3.fromHex("#1D1F25"), back = Color3.fromHex("#3A3E47") }
local function paintDevice(device, themeId)
	local theme = Themes.ById[themeId] or Themes.ById[Themes.Default]
	local accent = theme.accent or theme.buttons
	local shell = device:FindFirstChild("Shell")
	if shell then
		shell.Color = theme.bandTint or Color3.new(1, 1, 1)
		shell.Material = Enum.Material.Metal
	end
	local plate = device:FindFirstChild("FrontPlate")
	if plate then
		-- The plate has a planar 0..1 UV, so the faceplate texture maps straight on.
		local held = theme.held3d or {}
		plate.TextureID = theme.texture or ""
		plate.Color = if theme.texture then Color3.new(1, 1, 1) else theme.face or theme.shell
		plate.Material = Enum.Material[held.material or "SmoothPlastic"] or Enum.Material.SmoothPlastic
		plate.Reflectance = held.reflectance or 0
		plate.Transparency = held.transparency or 0
	end
	local function paint(name, color, material)
		local piece = device:FindFirstChild(name)
		if piece then
			piece.Color = color
			if material then piece.Material = material end
		end
	end
	paint("Bezel", Colors.bezel)
	if device:FindFirstChild("Bezel") then device.Bezel.Reflectance = 0.15 end
	paint("Screen", if theme.lcd then theme.lcd.base else Colors.glass)
	paint("AimRocker", Colors.pad)
	paint("Customize", Colors.pad)
	paint("Back", Colors.back)
	paint("Confirm", accent)
	paint("Power", accent, Enum.Material.Neon)
end

function Lounge.warmDeck()
	slimTemplate()
end

function Lounge.setAppearance(character, themeId)
	local device = character and character:FindFirstChild("PocketDeck")
	if device then
		paintDevice(device, themeId)
	end
end

function Lounge.setMode(character, userId, mode, themeId)
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
	local template = slimTemplate()
	if not template then
		warn("Egg Drop: ServerStorage.PocketDeckSlim is missing; no held deck")
		return
	end
	-- Building the template can yield once; re-check after it.
	if character:FindFirstChild("PocketDeck") or not character.Parent or not torso.Parent then
		return
	end

	device = Instance.new("Model")
	device.Name = "PocketDeck"
	device:SetAttribute("BoardUserId", userId)
	-- The device's Front (screen, controls) faces back toward the holder's
	-- face: turned 180 degrees about Y and tipped 22 degrees up toward the eyes.
	-- Device +X therefore lies on the holder's left, so the pad reads left and A right.
	local mount = CFrame.new(0, -0.39, -1.02) * CFrame.Angles(math.rad(-22), math.pi, 0)
	for _, source in ipairs(template:GetChildren()) do
		if source:IsA("BasePart") then
			local piece = source:Clone()
			weldPiece(piece, torso, mount * source.CFrame)
			piece.Parent = device
		end
	end
	local shell, screen = device:FindFirstChild("Shell"), device:FindFirstChild("Screen")
	if not shell or not screen then
		device:Destroy()
		return
	end
	device.PrimaryPart = shell
	paintDevice(device, themeId)
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
	local mode, themeId = deckState()
	Lounge.setMode(character, player.UserId, mode, themeId)
end

return Lounge
