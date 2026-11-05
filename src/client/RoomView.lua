local Players = game:GetService("Players")
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local PipVisual = require(script.Parent.PipVisual)
local PuddleVisual = require(script.Parent.PuddleVisual)
local BonusPetVisual = require(script.Parent.BonusPetVisual)
local RoomCompanions = require(script.Parent.RoomCompanions)
local Art = require(script.Parent.DeckArt)
local DeckTransition = require(script.Parent.DeckTransition)
local Config = require(ReplicatedStorage.Shared.BoardConfig)
local Pets = require(ReplicatedStorage.Shared.PetCatalog)

local Room = {}
Room.__index = Room

local visuals = { pip = PipVisual, puddle = PuddleVisual }

local function createPet(parent, origin, pet, masteryMask)
	local visual = visuals[pet.family or pet.id] or BonusPetVisual
	local result = visual.new(parent, origin, pet)
	local family = pet.family or pet.id
	local index = table.find({ "pip", "puddle", "wick", "orbit" }, family)
	if index and masteryMask and bit32.band(masteryMask, bit32.lshift(1, index - 1)) ~= 0 then
		local sparkles = Instance.new("Sparkles")
		sparkles.Name, sparkles.SparkleColor = "FamilyMastery", pet.accent or pet.color
		sparkles.Parent = result.model.PrimaryPart
		result.masterySparkles = sparkles
	end
	return result
end

local function frame(parent, name, size, position, color, z)
	local node = Instance.new("Frame")
	node.Name = name
	node.Size = size
	node.Position = position
	node.BackgroundColor3 = color
	node.BorderSizePixel = 0
	node.ZIndex = z
	node.Parent = parent
	return node
end

local function button(parent, name, title, position, tint)
	local node = Instance.new("TextButton")
	node.Name = name
	node.Size = UDim2.new(0.5, -4, 0, 44)
	node.Position = position
	node.BackgroundColor3 = tint
	node.BorderSizePixel = 0
	node.Text = title
	node.TextColor3 = if tint == Art.Cyan then Art.Ink else Art.Silver
	node.Font = Enum.Font.GothamMedium
	node.TextSize = 14
	node.ZIndex = 9
	node.Parent = parent
	Art.button(node, 6)
	Art.fitText(node, 14, 10, 5)
	return node
end

local function tween(object, seconds, properties)
	local motion = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), properties)
	motion:Play()
	return motion
end

function Room.new(gui, board, progress, audio, onReturn, onCustomize, onCollection, overlayOpen, reduceEffects, onEggs)
	local controls = frame(gui, "LoungeControls", UDim2.new(1, -32, 0, 78), UDim2.new(0.5, 0, 0, 10), Art.Surface, 8)
	controls.AnchorPoint = Vector2.new(0.5, 0)
	controls.Visible = false
	Art.panel(controls, 10)
	local max = Instance.new("UISizeConstraint")
	max.MaxSize = Vector2.new(440, 78)
	max.Parent = controls
	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Size = UDim2.new(0.94, 0, 0, 25)
	heading.Position = UDim2.fromScale(0.045, 0)
	heading.BackgroundTransparency = 1
	heading.Text = "Pip’s lounge"
	heading.TextColor3 = Art.Silver
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextSize = 17
	heading.Font = Enum.Font.GothamBold
	heading.TextTruncate = Enum.TextTruncate.AtEnd
	heading.ZIndex = 9
	heading.Parent = controls
	Art.fitText(heading, 15, 10, 0)
	local welcome = Art.text(controls, "FirstVisit", "Say hi to Pip!", UDim2.new(0.045, 0, 0, 26),
		UDim2.new(0.54, 0, 0, 16), Art.Muted, 11, Enum.Font.GothamMedium)
	welcome.TextXAlignment = Enum.TextXAlignment.Left
	welcome.Visible = false
	local greet = button(controls, "GreetPet", "Say hi", UDim2.new(0, 8, 0, 27), Art.Raised)
	local leave = button(controls, "OpenHandheld", "Open deck", UDim2.new(0.25, 4, 0, 27), Art.Cyan)
	local customize = button(controls, "Customize", "Style", UDim2.new(0.50, 0, 0, 27), Art.Raised)
	local collection = button(controls, "Collection", "Pets", UDim2.new(0.75, -4, 0, 27), Art.Raised)
	local eggs = button(controls, "Eggs", "Eggs", UDim2.fromOffset(0, 27), Art.Amber)
	eggs.TextColor3 = Art.Ink
	leave.Text, greet.Text = "Deck", "Hi"
	for i, control in ipairs({ greet, leave, eggs, customize, collection }) do
		control.Position = UDim2.new((i - 1) / 5, 8 - (i - 1) * 3, 0, 27)
		control.Size = UDim2.new(0.2, -10, 0, 44)
	end
	eggs.Activated:Connect(function() if not overlayOpen() and onEggs then onEggs() end end)

	local self = setmetatable({
		board = board,
		progress = progress,
		controls = controls,
		heading = heading,
		welcome = welcome,
		greetButton = greet,
		transition = DeckTransition.new(gui, board.Tray),
		audio = audio,
		mode = "Board",
		target = "Board",
		lastSwitchAt = -math.huge,
		shownPet = Pets[1],
		companions = RoomCompanions.new(progress.Parent, createPet, reduceEffects),
	}, Room)
	self.reduceEffects = reduceEffects
	collection.Activated:Connect(function()
		if self.mode == "Room" and not self.busy and not overlayOpen() then
			onCollection()
		end
	end)
	greet.Activated:Connect(function()
		if self.busy or overlayOpen() or not self.pet then
			return
		end
		if self.focusing then self:useRoomCamera(false) else self:focusPet() end
	end)
	leave.Activated:Connect(function()
		if not self.busy and not overlayOpen() then
			self:requestSwitch(onReturn)
		end
	end)
	customize.Activated:Connect(function()
		if not self.busy and not overlayOpen() then
			onCustomize()
		end
	end)
	Players.LocalPlayer.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 5)
		if self.mode == "Room" and humanoid then
			task.defer(function()
				if self.mode == "Room" then
					self:useRoomCamera(false)
				end
			end)
		end
	end)
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if self.mode == "Room" then
			self:useRoomCamera(false)
		end
	end)
	RunService.RenderStepped:Connect(function(dt)
		if self.pet then
			local character = Players.LocalPlayer.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if self.focusing and humanoid and humanoid.MoveDirection.Magnitude > 0.05 then
				self:useRoomCamera(false)
			end
			if root and not self.focusing then
				self.followIn = (self.followIn or 0) - dt
				if self.followIn <= 0 then
					self.followIn = 0.10
					local desired = root.Position - root.CFrame.LookVector * 2.4 + root.CFrame.RightVector * 2.4
					local params = RaycastParams.new()
					params.FilterDescendantsInstances = { character, self.pet.model }
					params.RespectCanCollide = true
					local ground = workspace:Raycast(desired + Vector3.new(0, 5, 0), Vector3.new(0, -50, 0), params)
					self.followTarget = Vector3.new(desired.X, if ground then ground.Position.Y + 0.02 else 4.02, desired.Z)
				end
				if self.followTarget then
					self.pet.origin = self.pet.origin:Lerp(self.followTarget,
						if (self.pet.origin - self.followTarget).Magnitude > 24 then 1 else 1 - math.exp(-7 * dt))
				end
			end
			self.pet:update(dt)
			if self.pet.masterySparkles then self.pet.masterySparkles.Enabled = not self.reduceEffects() end
			self.companions:update(dt)
		end
	end)
	return self
end

function Room:requestSwitch(callback)
	if self.busy or self.switchQueued then
		return
	end
	local remaining = Config.ModeSwitchInterval - (os.clock() - self.lastSwitchAt)
	if remaining <= 0 then
		callback()
		return
	end
	local origin = self.mode
	self.switchQueued = true
	task.delay(remaining, function()
		self.switchQueued = false
		if not self.busy and self.mode == origin and self.target == origin then
			callback()
		end
	end)
end

function Room:choosePet(pet)
	self.requestedPet = pet
end

function Room:showPet(pet)
	local owned = self.progress:GetAttribute("OwnedPets") or 0
	local trials = self.progress:GetAttribute("TrialMask") or 0
	if not pet or not Pets.isUnlocked(pet, owned, trials, self.progress:GetAttribute("InventoryMask")) then
		pet = Pets[1]
	end
	self.shownPet = pet
	if self.welcome.Visible then
		self.welcome.Text = "Say hi to " .. pet.name .. "!"
	end
	if self.pet then
		self.pet:destroy()
	end
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local position = if root then root.Position + root.CFrame.RightVector * 2.4 else Vector3.new(0, 4.02, -5)
	self.pet = createPet(workspace, Vector3.new(position.X, 4.02, position.Z), pet, self.progress:GetAttribute("MasteryMask"))
	self.followIn, self.followTarget = 0, nil
	if not self.reduceEffects() then
		self.pet:greet()
	end
	self.heading.Text = string.format("Sprout Hollow  ·  %s  ·  %d/%d", pet.name,
		Pets.ownedCount(owned, trials, self.progress:GetAttribute("InventoryMask")), #Pets.collection)
end

function Room:cancelCameraTween()
	if self.cameraTween then
		self.cameraTween:Cancel()
		self.cameraTween = nil
	end
end

function Room:restoreCamera()
	self:cancelCameraTween()
	self.focusing = false
	self.greetButton.Text = "Say hi"
	if self.viewportChanged then
		self.viewportChanged:Disconnect()
		self.viewportChanged = nil
	end
	local saved = self.savedCamera
	self.savedCamera = nil
	if saved and saved.camera.Parent then
		saved.camera.CFrame = saved.transform
		saved.camera.Focus = saved.focus
		saved.camera.FieldOfView = saved.fov
		saved.camera.CameraType = saved.type
	end
end

function Room:useRoomCamera(animate)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if not self.savedCamera or self.savedCamera.camera ~= camera then
		self:restoreCamera()
		self.savedCamera = {
			camera = camera, type = camera.CameraType, transform = camera.CFrame,
			focus = camera.Focus, fov = camera.FieldOfView,
		}
	else
		self:cancelCameraTween()
	end
	self.focusing = false
	self.greetButton.Text = "Say hi"
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid then
		camera.CameraSubject = humanoid
	end
	camera.FieldOfView = 65
	if root and not self.roamed then
		local target = root.Position + Vector3.new(0, 1, 0)
		camera.CFrame = CFrame.lookAt(target + Vector3.new(5, 6, 12), target)
	end
	self.roamed = true
	camera.CameraType = Enum.CameraType.Custom
end

function Room:focusPet()
	local camera = workspace.CurrentCamera
	if not camera or not self.pet or self.mode ~= "Room" then return end
	self:cancelCameraTween()
	self.focusing = true
	self.greetButton.Text = "Roam"
	self.audio:play(self.shownPet.cue)
	if not self.reduceEffects() then self.pet:greet() end
	-- Present the pet in front of the avatar, clear of the avatar's silhouette.
	local root = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
	local side = if root and root.Position.Z > 9 then -1 else 1
	if root then
		self.pet.origin = Vector3.new(root.Position.X, 4.02, root.Position.Z + 4.5 * side)
	end
	self.pet.yaw = if side == 1 then 0 else math.pi
	local target = self.pet.origin + Vector3.new(0, 1.25, 0)
	local portrait = camera.ViewportSize.X < camera.ViewportSize.Y
	local destination = CFrame.lookAt(target + Vector3.new(1.2, 1.6, side * (if portrait then 9 else 7.4)), target)
	camera.CameraType = Enum.CameraType.Scriptable
	local epoch = (self.focusEpoch or 0) + 1
	self.focusEpoch = epoch
	if self.reduceEffects() then
		camera.CFrame, camera.Focus, camera.FieldOfView = destination, CFrame.new(target), 43
	else
		self.cameraTween = tween(camera, 0.45, { CFrame = destination, Focus = CFrame.new(target), FieldOfView = 43 })
	end
	task.delay(2.8, function()
		if self.mode == "Room" and not self.busy and self.focusing and self.focusEpoch == epoch
			and workspace.CurrentCamera == camera then self:useRoomCamera(false) end
	end)
end

function Room:show(mode, animate)
	self.welcome.Visible = false
	if mode == "Room" then
		local meet = self.requestedPet ~= nil
		self.welcomeNext = nil
		local equipped = Pets.byId[self.progress:GetAttribute("CompanionId")]
		self:showPet(self.requestedPet or equipped)
		self.requestedPet = nil
		self:useRoomCamera(animate)
		if meet then
			task.delay(0.35, function()
				if self.mode == "Room" and self.pet then self:focusPet() end
			end)
		end
	else
		self.companions:clear()
		if self.pet then
			self.pet:destroy()
			self.pet = nil
		end
		self:restoreCamera()
	end
	self.controls.Visible = mode == "Room"
	self.board.Visible = mode == "Board"
	if mode == "Room" and string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then
		GuiService.SelectedObject = self.controls.OpenHandheld
	elseif mode == "Board" and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.controls) then
		GuiService.SelectedObject = nil
	end
end

function Room:setMode(mode)
	if self.target ~= mode then
		self.lastSwitchAt = os.clock()
	end
	self.target = mode
	if self.busy or self.mode == mode then
		return
	end
	self.busy = true
	task.spawn(function()
		while self.mode ~= self.target do
			local animate = not self.reduceEffects()
			if animate then
				if self.mode == "Room" then
					self:cancelCameraTween()
				end
				self.transition:cover(self.mode == "Board")
			end
			animate = animate and not self.reduceEffects()
			if self.mode ~= self.target then
				self.mode = self.target
				self:show(self.mode, animate)
				self.audio:play(if self.mode == "Room" then self.shownPet.cue else "menu")
			end
			if animate then
				self.transition:reveal(self.mode == "Board")
				if self.cameraTween and self.cameraTween.PlaybackState == Enum.PlaybackState.Playing then
					self.cameraTween.Completed:Wait()
				end
			else
				self.transition:hide()
			end
		end
		self.busy = false
	end)
end

return Room
