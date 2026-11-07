-- One focus acquisition per pointer/controller handoff. Never activates a control.
local Focus={};Focus.__index=Focus
local PASS,SINK=Enum.ContextActionResult.Pass,Enum.ContextActionResult.Sink
local function gamepad(kind)return kind~=nil and string.match(kind.Name,"^Gamepad")~=nil end
local function same(owner,root,epoch)return owner and owner.root==root and (owner.epoch or 0)==epoch end
function Focus.live(node,root,playerGui,selectable)
	if not node or not node.Parent or not node:IsA("GuiObject") or not playerGui or not node:IsDescendantOf(playerGui)
		or (root and not node:IsDescendantOf(root)) then return false end
	if node.AbsoluteSize.X<=0 or node.AbsoluteSize.Y<=0 then return false end
	if selectable and (not node.Selectable or not node.Interactable)then return false end
	local ancestor=node
	while ancestor do
		if ancestor:IsA("GuiObject") and (not ancestor.Visible or not ancestor.Interactable)then return false end
		if ancestor:IsA("ScreenGui") and not ancestor.Enabled then return false end
		ancestor=ancestor.Parent
	end
	return true
end
function Focus.new(dependencies)
	local self=setmetatable({d=dependencies,epoch=0,connections={},holds={},inputKind=dependencies.input()},Focus)
	self:sync();return self
end
function Focus:invalidate(clearGesture)
	self.epoch+=1;self.queued=nil;self.pendingRelease=nil;self.armed=false
	for _,held in pairs(self.holds)do held.valid=false end
	if clearGesture then table.clear(self.holds)end
end
function Focus:sync()
	local context=self.d.read()
	local owner=if not context.blocked and not context.native then context.owner else nil
	if owner and not Focus.live(owner.root,nil,self.d.playerGui(),false)then owner=nil end
	if not same(owner,self.ownerRoot,self.ownerEpoch) and (owner or self.ownerRoot)then
		self:invalidate(false);self.ownerRoot=owner and owner.root;self.ownerEpoch=owner and (owner.epoch or 0)
		self.armed=owner~=nil
	end
	self.owner=owner
	if context.native then self:invalidate(true)end
	return context
end
function Focus:validSelection(node)
	return self.owner~=nil and Focus.live(node,self.owner.root,self.d.playerGui(),true)
end
function Focus:ticketCurrent(ticket)
	self:sync()
	return not self.destroyed and ticket.epoch==self.epoch and same(self.owner,ticket.root,ticket.ownerEpoch)
		and self.inputKind==ticket.input and self.d.input()==ticket.input and gamepad(ticket.input)
end
function Focus:acquire(ticket)
	if not self:ticketCurrent(ticket)or not self.armed or next(self.holds)~=nil or self.d.aDown(ticket.input)then return false end
	if self:validSelection(self.d.selected())then
		local selected=self.d.selected()
		if self.owner.ensure then self.owner.ensure(selected)end
		if self:ticketCurrent(ticket)then self.armed=false;self.pendingRelease=nil end
		return false
	end
	local owner=self.owner
	local target=owner.target and owner.target()
	if not self:validSelection(target)then target=owner.fallback end
	if not self:validSelection(target)then return false end
	if owner.ensure then owner.ensure(target)end
	if not self:ticketCurrent(ticket)then return false end
	-- Native direction/focus handling gets the first chance, including scroll callbacks.
	if self:validSelection(self.d.selected())then self.armed=false;self.pendingRelease=nil;return false end
	if not self:validSelection(target)then return false end
	self.d.select(target);self.armed=false;self.pendingRelease=nil;return true
end
function Focus:queueAcquire()
	if self.destroyed or not self.owner or not self.armed or not gamepad(self.inputKind)then return end
	if self.queued then return end
	local ticket={epoch=self.epoch,root=self.owner.root,ownerEpoch=self.owner.epoch or 0,input=self.inputKind}
	self.queued=ticket
	self.d.afterInput(function()
		if self.destroyed or self.queued~=ticket then return end
		self.queued=nil;self:acquire(ticket)
	end)
end
function Focus:onOwnerChanged()
	if self.destroyed then return end
	self:sync()
	self:queueAcquire()
end
function Focus:onInputTypeChanged(kind)
	if self.destroyed then return end
	if kind==self.inputKind then self:sync();self:queueAcquire();return end
	self:invalidate(false);self.inputKind=kind;self:sync()
	if gamepad(kind)and self.owner then self.armed=true;self:queueAcquire()end
end
function Focus:onNavigation(input)
	if self.destroyed or not gamepad(input.UserInputType)then return end
	if self.inputKind~=input.UserInputType then self:onInputTypeChanged(input.UserInputType)else self:sync()end
	self:queueAcquire()
end
function Focus:queueReleased()
	local release=self.pendingRelease
	if next(self.holds)==nil and release and release.epoch==self.epoch
		and same(self.owner,release.root,release.ownerEpoch) and self.inputKind==release.device then self:queueAcquire()end
end
function Focus:onGamepadDisconnected(device)
	if self.destroyed then return end
	self.holds[device]=nil
	if self.inputKind==device then self:invalidate(false);self.inputKind=nil
	else self:queueReleased()end
end
function Focus:handleA(state,input)
	if self.destroyed or not input or input.KeyCode~=Enum.KeyCode.ButtonA or not gamepad(input.UserInputType)then return PASS end
	local context=self:sync()
	if context.native then return PASS end
	local device=input.UserInputType
	local held=self.holds[device]
	if held then
		if state==Enum.UserInputState.End or state==Enum.UserInputState.Cancel then
			self.holds[device]=nil;self.queued=nil
			if state==Enum.UserInputState.End and held.valid and held.epoch==self.epoch
				and same(self.owner,held.root,held.ownerEpoch) and self.inputKind==device then
				self.pendingRelease=held
			elseif state==Enum.UserInputState.Cancel then self:invalidate(false);self.armed=self.owner~=nil end
			self:queueReleased()
		end
		return SINK
	end
	if state~=Enum.UserInputState.Begin then return PASS end
	-- Valid native focus is never intercepted, even if UIS's device notification
	-- trails this unequivocal Gamepad A InputObject.
	if self:validSelection(self.d.selected())then self.armed=false;self.pendingRelease=nil;return PASS end
	if self.inputKind~=device then
		self:invalidate(false);self.inputKind=device;self:sync();self.armed=self.owner~=nil
	end
	if not self.owner or not self.armed then return PASS end
	self.queued=nil;self.pendingRelease=nil
	self.holds[device]={device=device,root=self.owner.root,ownerEpoch=self.owner.epoch or 0,epoch=self.epoch,valid=true}
	return SINK
end
function Focus:watch(signal,callback)
	table.insert(self.connections,signal:Connect(function(...)
		if self.destroyed then return end
		if callback then callback(...)else self:onOwnerChanged()end
	end))
end
function Focus:destroy()
	if self.destroyed then return end
	self:invalidate(true);self.destroyed=true;self.owner,self.ownerRoot=nil,nil
	for _,connection in ipairs(self.connections)do connection:Disconnect()end;table.clear(self.connections)
end
return Focus
