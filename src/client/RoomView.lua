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

local greetingTarget = Vector3.new(0, 5.8, -5)
local greetingCamera = CFrame.lookAt(Vector3.new(4, 8.2, 3.8), greetingTarget)
local visuals = { Pip = PipVisual, Puddle = PuddleVisual }

local function pose(camera, close)
	local viewport = camera.ViewportSize
	local aspect = math.max(0.3, viewport.X / math.max(1, viewport.Y))
	local portrait = aspect < 1
	local target = if close then Vector3.new(0, 6.0, -5) else Vector3.new(0, 7.4, -4.5)
	local side = math.min(1, aspect)
	local offset = if close then Vector3.new(2.8 * side, 3.5, if portrait then 14.5 else 12)
		else Vector3.new(8 * side, 5.3, 19.7)
	return {
		CFrame = CFrame.lookAt(target + offset, target),
		Focus = CFrame.new(target),
		FieldOfView = if portrait then 63 else 55,
	}
end

local function createPet(parent, origin, pet)
	local visual = visuals[pet.name] or BonusPetVisual
	return visual.new(parent, origin, pet)
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
	return node
end

local function tween(object, seconds, properties)
	local motion = TweenService:Create(object, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), properties)
	motion:Play()
	return motion
end

function Room.new(gui, board, progress, audio, onReturn, onCustomize, onCollection, overlayOpen, reduceEffects)
	local controls = frame(gui, "LoungeControls", UDim2.new(0.9, 0, 0, 110), UDim2.new(0.5, 0, 1, -16), Art.Surface, 8)
	controls.AnchorPoint = Vector2.new(0.5, 1)
	controls.Visible = false
	Art.panel(controls, 10)
	local max = Instance.new("UISizeConstraint")
	max.MaxSize = Vector2.new(430, 110)
	max.Parent = controls
	local heading = Instance.new("TextLabel")
	heading.Name = "Heading"
	heading.Size = UDim2.new(0.56, 0, 0, 44)
	heading.Position = UDim2.fromScale(0.045, 0)
	heading.BackgroundTransparency = 1
	heading.Text = "Pip’s lounge"
	heading.TextColor3 = Art.Silver
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextSize = 17
	heading.Font = Enum.Font.GothamBold
	heading.ZIndex = 9
	heading.Parent = controls
	local collection = button(controls, "Collection", "Pet journal", UDim2.new(0.60, 0, 0, 3), Art.Raised)
	collection.Size = UDim2.new(0.375, 0, 0, 44)
	local greet = button(controls, "GreetPet", "Say hi", UDim2.new(0.025, 0, 0, 51), Art.Raised)
	greet.Size = UDim2.new(0.29, 0, 0, 44)
	local leave = button(controls, "OpenHandheld", "Open deck", UDim2.new(0.335, 0, 0, 51), Art.Cyan)
	leave.Size = UDim2.new(0.33, 0, 0, 44)
	local customize = button(controls, "Customize", "Customize", UDim2.new(0.685, 0, 0, 51), Art.Raised)
	customize.Size = UDim2.new(0.29, 0, 0, 44)

	local self = setmetatable({
		board = board,
		progress = progress,
		controls = controls,
		heading = heading,
		transition = DeckTransition.new(gui, board.Tray),
		audio = audio,
		mode = "Board",
		target = "Board",
		lastSwitchAt = -math.huge,
		petIndex = 1,
		companions = RoomCompanions.new(progress.Parent, createPet),
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
		audio:play(Pets[self.petIndex].cue)
		if reduceEffects() then
			return
		end
		local camera = workspace.CurrentCamera
		self.pet:greet()
		if camera then
			self:cancelCameraTween()
			self.cameraTween = tween(camera, 0.58, { CFrame = greetingCamera, Focus = CFrame.new(greetingTarget) })
			local closeup = self.cameraTween
			task.delay(2.7, function()
				if self.mode == "Room" and not self.busy and self.cameraTween == closeup
					and workspace.CurrentCamera == camera then
					self.cameraTween = tween(camera, 0.75, pose(camera, false))
				end
			end)
		end
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
			self.pet:update(dt)
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

function Room:choosePet(name)
	local owned = self.progress:GetAttribute("OwnedPets") or 0
	for index = 1, owned do
		if Pets[index].name == name then
			self.requestedPet = index
			return
		end
	end
end

function Room:showPet(index)
	local owned = math.max(1, self.progress:GetAttribute("OwnedPets") or 0)
	self.petIndex = math.clamp(index, 1, owned)
	if self.pet then
		self.pet:destroy()
	end
	local pet = Pets[self.petIndex]
	self.pet = createPet(workspace, Vector3.new(0, 4.23, -5), pet)
	if not self.reduceEffects() then
		self.pet:greet()
	end
	self.heading.Text = string.format("%s  ·  %d/%d", Pets[self.petIndex].name, owned, #Pets)
end

function Room:cancelCameraTween()
	if self.cameraTween then
		self.cameraTween:Cancel()
		self.cameraTween = nil
	end
end

function Room:restoreCamera()
	self:cancelCameraTween()
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
		self.viewportChanged = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			if self.mode == "Room" and workspace.CurrentCamera == camera then
				self:useRoomCamera(false)
			end
		end)
	else
		self:cancelCameraTween()
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local start = pose(camera, animate)
	camera.CFrame, camera.Focus, camera.FieldOfView = start.CFrame, start.Focus, start.FieldOfView
	if animate then
		self.cameraTween = tween(camera, 0.46, pose(camera, false))
	end
end

function Room:show(mode, animate)
	if mode == "Room" then
		local equipped = Pets.byId[self.progress:GetAttribute("CompanionId")]
		self:showPet(self.requestedPet or (equipped and equipped.index) or 1)
		self.requestedPet = nil
		self:useRoomCamera(animate)
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
				self.audio:play(if self.mode == "Room" then Pets[self.petIndex].cue else "menu")
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
