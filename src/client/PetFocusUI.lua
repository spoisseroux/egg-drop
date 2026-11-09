local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local UserInputService = game:GetService("UserInputService")
local Art = require(script.Parent.DeckArt)

local SaveNotice=require(script.Parent.SaveNotice)
local RigBounds=require(script.Parent.PetRigBounds)
local Focus = {}
Focus.__index = Focus
local serial = 0

-- Keep character settings separate from camera state so either can be restored
-- after a replacement camera, a reset, or a mode change. Release is idempotent.
function Focus.lockHumanoid(humanoid)
	if not humanoid then return function() end end
	local saved = {
		WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower,
		JumpHeight = humanoid.JumpHeight, AutoRotate = humanoid.AutoRotate,
		jumping = humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping),
	}
	humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate = 0, 0, 0, false
	humanoid.Jump = false
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	humanoid:Move(Vector3.zero)
	local released = false
	return function()
		if released then return end
		released = true
		-- A destroyed humanoid no longer needs restoration, but reset can leave
		-- the old character parented briefly. Restore that object, never its replacement.
		if not humanoid.Parent then return end
		humanoid.WalkSpeed, humanoid.JumpPower = saved.WalkSpeed, saved.JumpPower
		humanoid.JumpHeight, humanoid.AutoRotate = saved.JumpHeight, saved.AutoRotate
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, saved.jumping)
	end
end

function Focus.projectBounds(camera, model, root, rigFrame, rigSize)
	if not camera or not model or not model.Parent or root.AbsoluteSize.X <= 0 or root.AbsoluteSize.Y <= 0 then return nil end
	local box,size=rigFrame,rigSize
	if not box then box,size=model:GetBoundingBox()end
	local low, high = Vector2.new(math.huge, math.huge), Vector2.new(-math.huge, -math.huge)
	for x = -1, 1, 2 do for y = -1, 1, 2 do for z = -1, 1, 2 do
		-- WorldToScreenPoint and AbsolutePosition both use core-safe GUI coordinates.
		local point = camera:WorldToScreenPoint(box:PointToWorldSpace(size * Vector3.new(x, y, z) * 0.5))
		if point.Z <= 0 then return nil end
		local p = Vector2.new(point.X, point.Y) - root.AbsolutePosition
		low = Vector2.new(math.min(low.X, p.X), math.min(low.Y, p.Y))
		high = Vector2.new(math.max(high.X, p.X), math.max(high.Y, p.Y))
	end end end
	local left = math.clamp(low.X - 10, 0, root.AbsoluteSize.X)
	local top = math.clamp(low.Y - 10, 0, root.AbsoluteSize.Y)
	local right = math.clamp(high.X + 10, 0, root.AbsoluteSize.X)
	local bottom = math.clamp(high.Y + 10, 0, root.AbsoluteSize.Y)
	if right - left < 8 or bottom - top < 8 then return nil end
	local width,height=math.min(root.AbsoluteSize.X,math.max(44,right-left)),math.min(root.AbsoluteSize.Y,math.max(44,bottom-top))
	left=math.clamp((left+right-width)*.5,0,root.AbsoluteSize.X-width)
	top=math.clamp((top+bottom-height)*.5,0,root.AbsoluteSize.Y-height)
	return Vector2.new(left, top),Vector2.new(width,height)
end

local function frame(parent, name, position, size, color, z)
	local node = Instance.new("Frame")
	node.Name, node.Position, node.Size = name, position, size
	node.BorderSizePixel,node.BackgroundColor3,node.ZIndex,node.Parent=0,if type(color)=="string"then Art.paletteColor(color)else color,z or 1,parent
 if type(color)=="string"then Art.bind(node,{BackgroundColor3=color})end
	return node
end

local function button(parent, name, text, anchor, position, tint)
	local node = Instance.new("TextButton")
	node.Name, node.Text, node.Font, node.TextSize = name, text, Enum.Font.GothamBold, 14
	node.AnchorPoint, node.Position, node.Size = anchor, position, UDim2.fromOffset(108, 44)
	node.BackgroundColor3,node.TextColor3,node.BorderSizePixel=if type(tint)=="string"then Art.paletteColor(tint)else tint,Art.Silver,0
	node.ZIndex, node.Parent = 10, parent
	if type(tint)=="string"then Art.bind(node,{BackgroundColor3=tint})end;Art.bind(node,{TextColor3="text"})
 Art.corner(node, 10)
	Art.stroke(node, "line", 0.3, 1)
	return node
end

local function pointer(input)
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

function Focus.new(parentGui, callbacks)
	serial += 1
	local gui = Instance.new("ScreenGui")
	gui.Name, gui.ResetOnSpawn, gui.ScreenInsets = "EggDropPetFocus", false, Enum.ScreenInsets.CoreUISafeInsets
	gui.DisplayOrder, gui.ZIndexBehavior, gui.Parent = 9, Enum.ZIndexBehavior.Sibling, parentGui.Parent
	local root = frame(gui, "SafeContent", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), "ink")
	root.BackgroundTransparency = 1
	local panel = frame(root, "FocusControls", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), "ink", 2)
	panel.BackgroundTransparency, panel.Visible = 1, false
	local back = button(panel, "Back", "", Vector2.zero, UDim2.fromOffset(12, 12), "panel")
	back.Size=UDim2.fromOffset(44,44);back:SetAttribute("AccessibleLabel","Back to roaming")
	local shaft=frame(back,"ArrowShaft",UDim2.fromOffset(13,21),UDim2.fromOffset(20,3),"text",11)
	for _,sign in ipairs({-1,1})do
		local arm=frame(back,"ArrowArm",UDim2.fromOffset(11,if sign<0 then 16 else 24),UDim2.fromOffset(13,3),"text",11)
		arm.Rotation=sign*45
	end
	local helper = Instance.new("TextLabel")
	helper.Name, helper.Text, helper.Font, helper.TextSize = "PettingHint", "Hold and rub to pet", Enum.Font.GothamMedium, 12
	helper.AnchorPoint, helper.Position, helper.Size = Vector2.new(0.5, 1), UDim2.new(0.5, 0, 1, -14), UDim2.fromOffset(230, 26)
	helper.BackgroundColor3, helper.BackgroundTransparency, helper.TextColor3 = Art.Surface, 0.15, Art.Silver
	helper.BorderSizePixel, helper.ZIndex, helper.Parent = 0, 8, panel
	Art.bind(helper,{BackgroundColor3="panel",TextColor3="text"});Art.corner(helper, 10)
	local hint = helper:Clone()
	hint.Name, hint.AnchorPoint, hint.Position = "RoamPetHint", Vector2.new(1, 0), UDim2.new(1, -12, 0, 64)
	hint.Size, hint.TextSize, hint.Text, hint.Visible, hint.Parent = UDim2.fromOffset(180, 22), 11, "Tap your pet to say hi", false, root
	Art.bind(hint,{BackgroundColor3="panel",TextColor3="text"})
 local hit = Instance.new("TextButton")
	hit.Name, hit.Text, hit.BackgroundTransparency, hit.BorderSizePixel = "PettingArea", "", 1, 0
	hit.AutoButtonColor, hit.Selectable, hit.ZIndex, hit.Parent = false, false, 2, panel
	local glove = frame(panel, "PettingGlove", UDim2.fromOffset(0, 0), UDim2.fromOffset(26, 32), "ink", 5)
	glove.BackgroundTransparency, glove.Visible, glove.AnchorPoint = 1, false, Vector2.new(0.45, 0.35)
	local cream = Color3.fromHex("#FFF0CD")
	local palm = frame(glove, "Palm", UDim2.fromOffset(5, 11), UDim2.fromOffset(19, 18), cream, 6)
	Art.corner(palm, 0.5)
	for index = 0, 3 do
		local finger = frame(glove, "Finger" .. index, UDim2.fromOffset(5 + index * 5, 2 + math.abs(index - 1) * 2), UDim2.fromOffset(4, 18), cream, 6)
		Art.corner(finger, 0.5)
	end
	local thumb = frame(glove, "Thumb", UDim2.fromOffset(0, 13), UDim2.fromOffset(7, 13), cream, 6)
	thumb.Rotation = -38
	Art.corner(thumb, 0.5)
	Art.corner(frame(glove, "Cuff", UDim2.fromOffset(7, 27), UDim2.fromOffset(16, 5), Art.Leaf, 7), 0.3)
	local self = setmetatable({ gui = gui, root = root, panel = panel, back = back,
		hit = hit, glove = glove, helper = helper, hint = hint, callbacks = callbacks, connections = {},
		actionPrefix = "EggDropPetFocus" .. serial, active = false, windowActive=true, heldTouches={},retiredTouches=setmetatable({},{__mode="k"}),retiredMouse=false, roamDock=parentGui:FindFirstChild("LoungeControls") }, Focus)
	table.insert(self.connections, back.Activated:Connect(function()if self.active and self:canOwnInput()then callbacks.back()end end))
	table.insert(self.connections,UserInputService.TouchStarted:Connect(function(input)self.heldTouches[input]=true end))
	table.insert(self.connections,UserInputService.TouchEnded:Connect(function(input)self.heldTouches[input]=nil;self:endPointer(input)end))
	table.insert(self.connections,hit.InputBegan:Connect(function(input)self:beginPointer(input)end))
	table.insert(self.connections,UserInputService.InputChanged:Connect(function(input)
  if input.UserInputState==Enum.UserInputState.Cancel then self:endPointer(input)
  elseif self:pointerMatches(input)then self:movePointer(input,false)end
	end))
	table.insert(self.connections,UserInputService.InputEnded:Connect(function(input)self:endPointer(input)end))
	table.insert(self.connections,UserInputService.TextBoxFocused:Connect(function()self:cancelPointer()end))
	table.insert(self.connections,GuiService:GetPropertyChangedSignal("MenuIsOpen"):Connect(function()if GuiService.MenuIsOpen then self:cancelPointer()end end))
	table.insert(self.connections,UserInputService.LastInputTypeChanged:Connect(function(kind)
  local held=self.heldGreet
  if held then
   if kind~=held.device and not(held.device==Enum.UserInputType.Keyboard and kind==Enum.UserInputType.MouseMovement)then self:cancelPointer()end
  elseif kind~=Enum.UserInputType.Touch and kind~=Enum.UserInputType.MouseMovement and kind~=Enum.UserInputType.MouseButton1 then self:cancelPointer()end
	end))
	table.insert(self.connections, UserInputService.WindowFocusReleased:Connect(function()self:loseWindowFocus()end))
 table.insert(self.connections,UserInputService.WindowFocused:Connect(function()self:gainWindowFocus()end))
	table.insert(self.connections,UserInputService.GamepadDisconnected:Connect(function(kind)if self.openingADevice==kind then self.openingADevice=nil end;if self.heldGreet and self.heldGreet.device==kind then self:cancelPointer()end;if self.openingGreetDevice==kind then self.openingGreetDevice=nil end end))
	table.insert(self.connections, parentGui.Destroying:Connect(function() self:destroy() end))
	table.insert(self.connections,root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self.hintLayoutKey=nil;self.helperLayoutKey=nil;self:layoutRoamHint();self:layoutSaveHelper()end))
	Art.watchTextPreference(gui,function()return self.hint.Visible or self.helper.Visible end,function()self.hintLayoutKey=nil;self.helperLayoutKey=nil;self:layoutRoamHint();self:layoutSaveHelper()end)
	self:layoutRoamHint()
	return self
end

function Focus:now()return if self.clock then self.clock()else os.clock()end
function Focus:retireFocusHint()
	self.focusLessonRetired=true
	self.helper.Visible=self.saveNotice~=nil and self.active
end
function Focus:retireRoamHint()self.roamHintRetired=true;if not self.saveNotice then self.hint.Visible=false end end
function Focus:cancelPointer(released)
 if self.pointer and not released then
  if self.pointer.UserInputType==Enum.UserInputType.Touch then
   self.retiredTouches=self.retiredTouches or setmetatable({},{__mode="k"});self.retiredTouches[self.pointer]=true
  elseif self.pointer.UserInputType==Enum.UserInputType.MouseButton1 then self.retiredMouse=true end
 end
	if self.contactAttempted then
		self.contactAttempted=false
		if self.callbacks.petContact then self.callbacks.petContact(false)end
	end
 self.heldGreet=nil
	self.pointer,self.previousPoint,self.strokeDistance,self.contactDeadline=nil,nil,0,nil
	self.wasRub,self.rubAccepted=false,false
	self.glove.Visible=false
end
function Focus:loseWindowFocus()
 local held=self.heldGreet
 local blockedE=self.openingGreetE or(held and held.key==Enum.KeyCode.E)
 local blockedDevice=self.openingGreetDevice or(held and held.key==Enum.KeyCode.ButtonX and held.device)
 self.windowActive=false;self:cancelPointer();self.openingMouse=false;self.openingADevice=nil
 self.openingGreetE=blockedE;self.openingGreetDevice=blockedDevice;self.openingTouches={}
 if self.heldTouches then table.clear(self.heldTouches)end
end
function Focus:gainWindowFocus()self.windowActive=true end

function Focus:checkContactDeadline()
 if self.windowActive==false then self:cancelPointer();return true end
 local held=self.heldGreet
 if held and not held.active and self:now()-held.started>=.35 then
  if not self.active or not self:canOwnInput()or not self.callbacks.canReact()then self:cancelPointer();return true end
  held.active=true;self.contactAttempted=true
  if self.callbacks.petContact then self.callbacks.petContact(true,"held")end
 end
	if self.contactDeadline and self:now()>=self.contactDeadline then
		-- A brief rest ends the reward lease, not ownership of this finger. Only
		-- fresh deliberate motion can restart it; idle updates never do.
		self.contactDeadline=nil;self.strokeDistance=0;self.rubAccepted=false
		if self.contactAttempted then self.contactAttempted=false;if self.callbacks.petContact then self.callbacks.petContact(false)end end
		self.glove.Visible=false
		return true
	end
	return false
end
function Focus:pointerMatches(input)
	return self.pointer and(input==self.pointer or(self.pointer.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseMovement))
end
function Focus:inside(point)
	local at,size=self.hit.Position,self.hit.Size
	if point.X<at.X.Offset or point.Y<at.Y.Offset or point.X>at.X.Offset+size.X.Offset or point.Y>at.Y.Offset+size.Y.Offset then return false end
	for _,node in ipairs({self.back,self.helper})do
		if node and node.Visible then
			local p,s=node.AbsolutePosition-self.root.AbsolutePosition,node.AbsoluteSize
			if point.X>=p.X and point.X<=p.X+s.X and point.Y>=p.Y and point.Y<=p.Y+s.Y then return false end
		end
	end
	return true
end
function Focus:beginPointer(input)
 if not pointer(input)or self.windowActive==false or self.pointer or not self.active or not self:canOwnInput()or not self.callbacks.canReact()then return false end
 if(input.UserInputType==Enum.UserInputType.Touch and self.retiredTouches and self.retiredTouches[input])
  or(input.UserInputType==Enum.UserInputType.MouseButton1 and self.retiredMouse)then return false end
 if(self.openingMouse and input.UserInputType==Enum.UserInputType.MouseButton1)or(self.openingTouches and self.openingTouches[input])then return false end
	local point=Vector2.new(input.Position.X,input.Position.Y)-self.root.AbsolutePosition
	if not self:inside(point)then return false end
 if self.heldGreet then self:cancelPointer()end
	self.pointer,self.previousPoint,self.strokeDistance=input,point,0
	self.pointerStartedAt,self.wasRub,self.rubAccepted=self:now(),false,false
	self:movePointer(input,true);return true
end
function Focus:movePointer(input,began)
 if input.UserInputState==Enum.UserInputState.Cancel then self:endPointer(input);return end
	if not self.pointer then return end
	if not self.active or not self:canOwnInput()or not self.callbacks.canReact()then self:cancelPointer();return end
	self:checkContactDeadline()
	if not self.pointer then return end
	local point=Vector2.new(input.Position.X,input.Position.Y)-self.root.AbsolutePosition
	if not self:inside(point)then self:cancelPointer();return end
	local traveled=if self.previousPoint then(point-self.previousPoint).Magnitude else 0
	self.glove.Position,self.glove.Visible=UDim2.fromOffset(point.X,point.Y),true
	self.glove.Rotation=if self.previousPoint then math.clamp((point.X-self.previousPoint.X)*.7,-16,16)else 0
	self.previousPoint=point
	if not began then self.strokeDistance+=traveled end
	if not began and self.strokeDistance>=9 then
		self.wasRub=true
		if not self.rubAccepted then
			self.rubAccepted=self.callbacks.pet()==true
			if self.rubAccepted then self:retireFocusHint()end
		end
		if self.rubAccepted and not self.contactAttempted then
			self.contactAttempted=true;self.contactDeadline=self:now()+.8
			if self.callbacks.petContact then self.callbacks.petContact(true,"pointer")end
		end
	end
	if self.contactAttempted and traveled>.5 then self.contactDeadline=self:now()+.8 end
end
function Focus:endPointer(input)
	if input.UserInputType==Enum.UserInputType.MouseButton1 then self.openingMouse=false;self.retiredMouse=false end
 if input.UserInputType==Enum.UserInputType.Touch and self.retiredTouches then self.retiredTouches[input]=nil end
	if self.openingTouches then self.openingTouches[input]=nil end
	local matches=input==self.pointer or(self.pointer and self.pointer.UserInputType==Enum.UserInputType.MouseButton1 and input.UserInputType==Enum.UserInputType.MouseButton1)
	if not matches then return end
	local point=Vector2.new(input.Position.X,input.Position.Y)-self.root.AbsolutePosition
	local distance=(self.strokeDistance or 0)+(if self.previousPoint then(point-self.previousPoint).Magnitude else 0)
	if input.UserInputState~=Enum.UserInputState.Cancel and not self.wasRub and distance<9 and self:now()-(self.pointerStartedAt or 0)<=.45 and self.active and self:canOwnInput()and self.callbacks.canReact()and self:inside(point)then
		if self.callbacks.greet()==true then self:retireFocusHint()end
	end
	self:cancelPointer(true)
end

function Focus:setActive(active)
	active = active == true
	if self.destroyed or self.active == active then return end
	self.active, self.panel.Visible = active, active and self:canOwnInput()
	-- A transparent fullscreen frame still participates in GUI hit testing.
	-- Only raise this surface above game navigation while focus owns input.
	self.gui.DisplayOrder = if self.panel.Visible then 40 else 9
	self:cancelPointer()
	local prefix = self.actionPrefix
	if active then
  self.openingGreetE=UserInputService:IsKeyDown(Enum.KeyCode.E)
  local greetKind=UserInputService:GetLastInputType()
  self.openingGreetDevice=if string.match(greetKind.Name,"^Gamepad")and UserInputService:IsGamepadButtonDown(greetKind,Enum.KeyCode.ButtonX)then greetKind else nil
		self.openingMouse=UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1)
		self.openingTouches={};for input in pairs(self.heldTouches)do self.openingTouches[input]=true end
		local kind=UserInputService:GetLastInputType()
		self.openingADevice=if string.match(kind.Name,"^Gamepad")and UserInputService:IsGamepadButtonDown(kind,Enum.KeyCode.ButtonA)then kind else nil
		local priority = Enum.ContextActionPriority.High.Value + 200
		ContextActionService:BindActionAtPriority(prefix .. "Back", function(_, state)
			return self:handleBack(state)
		end, false, priority + 1, Enum.KeyCode.ButtonB)
		ContextActionService:BindActionAtPriority(prefix .. "Greet", function(_, state,input)
			return self:handleGreet(state,input)
		end, false, priority, Enum.KeyCode.E, Enum.KeyCode.ButtonX)
		ContextActionService:BindActionAtPriority(prefix .. "Move", function(_,state,input)return self:handleMove(state,input)end,
			false, priority, Enum.PlayerActions.CharacterForward, Enum.PlayerActions.CharacterBackward,
			Enum.PlayerActions.CharacterLeft, Enum.PlayerActions.CharacterRight, Enum.PlayerActions.CharacterJump,
			Enum.KeyCode.W, Enum.KeyCode.A, Enum.KeyCode.S, Enum.KeyCode.D, Enum.KeyCode.Up, Enum.KeyCode.Down,
			Enum.KeyCode.Left, Enum.KeyCode.Right, Enum.KeyCode.Space, Enum.KeyCode.Thumbstick1, Enum.KeyCode.ButtonA)
		if string.match(UserInputService:GetLastInputType().Name, "^Gamepad") then GuiService.SelectedObject = self.back end
	else
		if self.focusLessonStarted then self:retireFocusHint()end
		self.openingADevice=nil;self.openingTouches=nil;self.openingMouse=false;self.openingGreetE=false;self.openingGreetDevice=nil
		for _, suffix in ipairs({ "Back", "Greet", "Move" }) do ContextActionService:UnbindAction(prefix .. suffix) end
		if GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.panel) then GuiService.SelectedObject = nil end
	end
end

function Focus:layoutActions()self.controlHeight=44 end

function Focus:layoutRoamHint()
	if self.destroyed then return end
	local size=self.root.AbsoluteSize
	local dock=self.roamDock
	local dockBottom=if dock and dock.Parent then dock.AbsolutePosition.Y+dock.AbsoluteSize.Y-self.root.AbsolutePosition.Y+8 else 64
	local key=self.hint.Text..tostring(size)..tostring(dockBottom)..GuiService.PreferredTextSize.Name
	if self.hintLayoutKey==key then return end;self.hintLayoutKey=key
	Art.type(self.hint,if self.saveNotice then "Body"else "Supporting",size.Y<280)
	local width=math.min(math.max(1,size.X-24),math.max(180,math.min(if self.saveNotice then math.max(1,size.X-24)else 360,Art.textWidth(self.hint)+16)))
	local height=Art.textHeight(self.hint,width,24)+8
	local y=math.max(8,math.min(dockBottom,math.max(8,size.Y-height-8)))
	self.hint.AnchorPoint=Vector2.zero
	self.hint.Position,self.hint.Size=UDim2.fromOffset(math.max(8,size.X-width-12),y),UDim2.fromOffset(width,height)
end

function Focus:layoutSaveHelper()
	local size=self.root.AbsoluteSize
	local value=if self.saveNotice then self.saveNotice.detail else self.helper.Text
	local key=value..tostring(size)..GuiService.PreferredTextSize.Name..tostring(self.saveNotice~=nil)
	if self.helperLayoutKey==key then return end;self.helperLayoutKey=key
	local topHint=not self.saveNotice and size.X>size.Y and size.Y<420
	local available=size.X-24
	if topHint then
		-- CoreUISafeInsets already excludes system controls. Preserve the Back lane
		-- symmetrically so the one existing lesson sits in sky, clear of the pet's feet.
		local lane=self.back.Position.X.Offset+self.back.Size.X.Offset+12
		available=size.X-lane*2
	end
	if self.saveNotice then self.helper.Text=value end
	Art.type(self.helper,"Supporting",if self.saveNotice then size.Y<280 else true)
	local width=math.max(1,math.min(available,Art.textWidth(self.helper)+16))
	self.helper.Size=UDim2.fromOffset(width,Art.textHeight(self.helper,width,26)+8)
	self.helper.AnchorPoint=Vector2.new(.5,if topHint then 0 else 1)
	self.helper.Position=if topHint then UDim2.new(.5,0,0,8)else UDim2.new(.5,0,1,-14)
end
function Focus:setSaveNotice(notice)
	if SaveNotice.key(self.saveNotice)==SaveNotice.key(notice)then return false end
	self.saveNotice=notice;self.hintLayoutKey=nil;self.helperLayoutKey=nil
	if notice then self.hint.Text=notice.detail;self.helper.Text=notice.detail else
		local pad=string.match(UserInputService:GetLastInputType().Name,"^Gamepad")
		self.hint.Text=if pad then "X  Say hi to your pet"elseif UserInputService.TouchEnabled then "Tap your pet to say hi"else "E  Say hi to your pet"
		self.helper.Text=if pad then "X  Pet    B  Back"else "Tap or rub to pet"
	end
	self:layoutRoamHint();self:layoutSaveHelper();return true
end

function Focus:update(camera, pet, roamHint)
	if self.destroyed then return end
	self:layoutActions()
	local ownsInput = self:canOwnInput()
	self.panel.Visible = self.active and ownsInput
	self.gui.DisplayOrder = if self.panel.Visible then 40 else 9
	local feedback=(self.feedbackUntil or 0)>os.clock()
	self.hint.Visible = not self.active and ownsInput and (feedback or(roamHint==true and not self.roamHintRetired)or self.saveNotice~=nil)
	local kind = UserInputService:GetLastInputType()
	self.hint.Text = if self.saveNotice then self.saveNotice.detail elseif feedback then self.feedbackText elseif string.match(kind.Name, "^Gamepad") then "X  Say hi to your pet"
		elseif UserInputService.TouchEnabled then "Tap your pet to say hi" else "E  Say hi to your pet"
	self:layoutRoamHint()
	if not self.active then return end
	self.helper.Text = if self.saveNotice then self.saveNotice.detail elseif string.match(kind.Name, "^Gamepad") then "Hold X to pet · B Back" else "Tap or rub · hold E to pet"
	self:layoutSaveHelper()
	local canReact = ownsInput and self.callbacks.canReact()
	if self.currentPet~=pet or self.currentCamera~=camera then self:cancelPointer()end
	self.currentPet,self.currentCamera=pet,camera
	local rigFrame,rigSize
	if pet and pet.model and pet.model.Parent then rigFrame,rigSize=RigBounds.getBody(pet)end
	local position,size=Focus.projectBounds(camera,pet and pet.model,self.root,rigFrame,rigSize)
	if position and canReact and not self.saveNotice then self.focusLessonStarted=true end
	self.helper.Visible=self.saveNotice~=nil or(self.focusLessonStarted and not self.focusLessonRetired)
	self:checkContactDeadline()
	self.hit.Visible, self.hit.Interactable = position ~= nil and canReact, canReact
	if position then
        local top=math.max(position.Y,(self.controlHeight or 44)+24)
        local bottom=position.Y+size.Y
        self.hit.Position,self.hit.Size=UDim2.fromOffset(position.X,top),UDim2.fromOffset(size.X,math.max(0,bottom-top))
        if bottom-top<8 then self.hit.Visible=false;self.hit.Interactable=false end
    end
	if not canReact or not position then self:cancelPointer() end
	if not ownsInput and GuiService.SelectedObject and GuiService.SelectedObject:IsDescendantOf(self.panel) then GuiService.SelectedObject = nil end
end

function Focus:canOwnInput()
	return self.windowActive~=false and not GuiService.MenuIsOpen and UserInputService:GetFocusedTextBox() == nil
		and (not self.callbacks.canOwnInput or self.callbacks.canOwnInput())
end

function Focus:handleBack(state)
	if not self.active or not self:canOwnInput() then return Enum.ContextActionResult.Pass end
	if state == Enum.UserInputState.Begin then self.callbacks.back() end
	return Enum.ContextActionResult.Sink
end

function Focus:contactValid()
 if self.windowActive==false or not self.contactAttempted or not self.active or not self:canOwnInput()or not self.callbacks.canReact()then return false end
 return(self.heldGreet~=nil and self.heldGreet.active)or(self.pointer~=nil and self.contactDeadline~=nil and self:now()<self.contactDeadline)
end
function Focus:handleGreet(state,input)
 local device=if input then input.UserInputType else Enum.UserInputType.Keyboard
 local key=if input then input.KeyCode else Enum.KeyCode.E
 local opener=(key==Enum.KeyCode.E and self.openingGreetE)or(key==Enum.KeyCode.ButtonX and self.openingGreetDevice==device)
 if opener then
  if state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then if key==Enum.KeyCode.E then self.openingGreetE=false else self.openingGreetDevice=nil end end
  return if self.active and self:canOwnInput()then Enum.ContextActionResult.Sink else Enum.ContextActionResult.Pass
 end
 local held=self.heldGreet
 if held and held.device==device and held.key==key and(state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel)then self:cancelPointer();return Enum.ContextActionResult.Sink end
 if self.windowActive==false or not self.active or not self:canOwnInput()then self:cancelPointer();return Enum.ContextActionResult.Pass end
 if state==Enum.UserInputState.Begin and not held and self.callbacks.canReact()then
  self:cancelPointer()
  if self.callbacks.greet()==true then
   self:retireFocusHint();self.heldGreet={device=device,key=key,started=self:now(),active=false}
  end
 end
 return Enum.ContextActionResult.Sink
end

function Focus:handleMove(state,input)
	if not self.active or not self:canOwnInput()then return Enum.ContextActionResult.Pass end
	if input and input.KeyCode==Enum.KeyCode.ButtonA then
		if self.openingADevice==input.UserInputType then
			if state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then self.openingADevice=nil end
			return Enum.ContextActionResult.Sink
		end
		if GuiService.SelectedObject==self.back then return Enum.ContextActionResult.Pass end
	end
	return Enum.ContextActionResult.Sink
end

function Focus:showFeedback(message)
    self.feedbackText=message;self.hint.Text=message;self.hint.Visible=true
    self.feedbackUntil=os.clock()+3
end
-- Charm editing lives in each Journal row's customization page.
function Focus:setCharmVisible()end

function Focus:destroy()
	if self.destroyed then return end
	self:setActive(false)
	self:cancelPointer()
	self.destroyed = true
	for _, connection in ipairs(self.connections) do connection:Disconnect() end
	table.clear(self.connections)
	self.gui:Destroy()
end

return Focus
