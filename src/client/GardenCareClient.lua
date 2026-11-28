local Replicated=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local Art=require(script.Parent.DeckArt);local Layout=require(Replicated.Shared.GardenCareLayout)
local Copy=require(Replicated.Shared.UICopy)
local Client={};Client.__index=Client
local reasons={BayOccupied="busy",NoDrySpace="dry",OutOfReach="closer",IdentityChanged="changed",ClaimChanged="ended",Saving="saving"}
local function button(parent,name,text,callback)
 local n=Instance.new("TextButton");n.Name=name;n.Text=text;n.Size=UDim2.fromOffset(150,44);n.Parent=parent;n.ZIndex=15;n.BorderSizePixel=0
 Art.bind(n,{BackgroundColor3="raised",TextColor3="text"});Art.button(n,12);Art.type(n,"Action");n.Activated:Connect(callback);return n
end
-- Beta (42) D14 (POINTER-STORK-BRIEF 3): the carry keys' icon. The pickUp / setDown PNG (CareIcons, 30 px, centred)
-- once its id is uploaded; while it is 0, the old frame-built arrow. `image` overrides the id (specs). Returns the drawn
-- node: the ImageLabel "CareIcon" or DeckArt's "CarryArrow"; the other one is hidden.
function Client.icon(node,up,image)
 local Icons=require(script.Parent.CareIcons)
 if image==nil then image=Icons.image(Icons.nameFor(up))end
 local icon=node:FindFirstChild("CareIcon");local arrowNode=node:FindFirstChild("CarryArrow")
 node.Text=""
 if image then
  if not icon then
   icon=Instance.new("ImageLabel");icon.Name="CareIcon";icon.BackgroundTransparency=1;icon.BorderSizePixel=0
   icon.AnchorPoint=Vector2.new(.5,.5);icon.Position=UDim2.fromScale(.5,.5);icon.ScaleType=Enum.ScaleType.Fit;icon.Active=false
   icon.Parent=node
  end
  icon.Size=UDim2.fromOffset(Icons.Size,Icons.Size);icon.ZIndex=node.ZIndex+2;icon.Image=image;icon.Visible=true
  if arrowNode then arrowNode.Visible=false end
  return icon
 end
 if icon then icon.Visible=false end
 arrowNode=Art.carryArrow(node,if up then "up"else "down");arrowNode.Visible=true
 return arrowNode
end
-- The key itself: a 48 px round key (the brief's round skin; FocusRow already gives Pick up 48 x 48).
local function arrow(node,up,label)
 node.Text="";node.Size=UDim2.fromOffset(48,48);node:SetAttribute("AccessibleLabel",label)
 for _,holder in ipairs({node,node:FindFirstChild("FocusKeyline")})do
  local corner=holder and holder:FindFirstChildOfClass("UICorner");if corner then corner.CornerRadius=UDim.new(.5,0)end
 end
 Client.icon(node,up)
end
function Client.new(room,gui,options)
 options=options or {}
 -- The ordinary ScreenGui already owns CoreUISafeInsets. Keep bottom controls
 -- in its own full safe-area Frame, independent of the focus sheet's lifetime.
 local controls=Instance.new("Frame");controls.Name="GardenCareControls";controls.Size=UDim2.fromScale(1,1);controls.BackgroundTransparency=1;controls.BorderSizePixel=0
 controls.Active=false;controls.Selectable=false;controls.ZIndex=15;controls.Parent=gui
 local self=setmetatable({room=room,gui=gui,controls=controls,uiRoot=controls,ownerId=Players.LocalPlayer.UserId,seq=0,operations={},connections={},pulseAt=0,
  notifications=options.notifications or require(script.Parent.NotificationRail)},Client)
 self.pickup=button(room.focusUI.panel,"PickUp","Pick up",function()self:request("carePickup",nil,function(packet)if packet.status=="Accepted"or packet.status=="Saved"then room:setPetContact(false);room:useRoomCamera(false)end end)end)
 arrow(self.pickup,true,"Pick up companion")
 room.focusUI:bindPickup(self.pickup)
 self.setDown=button(controls,"CarrySetDown","Set down",function()self:request("careSetDown")end)
 arrow(self.setDown,false,"Set companion down")
 self.setDown.AnchorPoint=Vector2.new(.5,1);self.setDown.Position=UDim2.new(.5,0,1,-16);self.setDown.Visible=false
 local remotes=Replicated:WaitForChild("Remotes")
 local function bind(remote)
  if self.result or remote.Name~="GardenCareResult"or not remote:IsA("RemoteEvent")then return end
  self.result=remote;table.insert(self.connections,remote.OnClientEvent:Connect(function(packet)self:receive(packet)end))
 end
 local result=remotes:FindFirstChild("GardenCareResult");if result then bind(result)end
 table.insert(self.connections,remotes.ChildAdded:Connect(bind));return self
end
function Client:actor()
 if self.actorProvider then return self.actorProvider()end
 return self.room.garden:get(Players.LocalPlayer.UserId,self.room.shownPet.id,Players.LocalPlayer.Character)
end
function Client:character()return if self.characterProvider then self.characterProvider()else Players.LocalPlayer.Character end
function Client:send(packet)
 local remote=self.remote or Replicated.Remotes:FindFirstChild("GardenIntent");if not remote then return false end
 remote:FireServer(packet);return true
end
function Client:request(kind,target,done)
 if self.destroyed then return false end
 local count=0;for _,op in pairs(self.operations)do count+=1;if op.packet.kind==kind then return false end end
 if count>=8 then return false end
 local actor=self:actor();if not actor then return false end
 self.seq+=1
 local packet={kind=kind,seq=self.seq,petId=actor.petId,characterId=actor.characterId,petGeneration=actor.petGeneration,actorGeneration=actor.generation,
  claimId=actor.care and actor.care.claimId,targetId=target,revision=self.revision and self.revision()or nil}
 self.operations[packet.seq]={packet=packet,done=done,at=os.clock(),tries=1,character=self:character()}
 if not self:send(packet)then self.operations[packet.seq]=nil;return false end;return true
end
function Client:receive(packet)
 if self.destroyed or type(packet)~="table"then return end
 local op=self.operations[packet.seq];if not op or packet.kind~=op.packet.kind then return end
 if packet.status=="Pending"then op.saving=true;return end
 self.operations[packet.seq]=nil
 if packet.kind=="careRelease"or packet.kind=="carePlace"then self.releasing=nil end
 if op.character~=self:character()then return end
 if packet.status=="Accepted"or packet.status=="Saved"then
  if op.done then op.done(packet)end
  if packet.kind=="carePlace"then self.wantMachine=true end
  if packet.kind=="carePickup"or packet.kind=="careSetDown"or packet.kind=="careRelease"then self.wantMachine=false;if self.closeMachine then self.closeMachine()end end
 else
  if op.done then op.done(packet)end
  if self.destroyed then return end
  self.notifications.enqueue(self.controls or self,"care:"..packet.seq,
   {text=Copy.get("care.notice."..(reasons[packet.reason]or "retry")),icon="!",reason=packet.reason})
 end
end
function Client:release(done)
 local actor=self:actor()
 if not actor or not actor.care then if done then done()end;return true end
 self.wantMachine=false;self.releasing=true
 return self:request("careRelease",nil,function(packet)self.releasing=nil;if done then done(packet)end end)
end
function Client:station()
 local actor=self:actor()
 if actor and actor.mode=="Carried"then return self:request("carePlace")end
 if actor and actor.mode=="Docked"then self.wantMachine=true;if self.openMachine then self.openMachine(actor)end;return true end
 -- Free hands: the prompt reads "Open companions", so open the editor for the
 -- equipped pet without docking it.
 if self.openFree then return self.openFree()==true end
 return false
end
function Client:keepsDock(actor,bay)
 return actor==nil and self.docked==true and bay~=nil and bay.id==self.boundClaim and bay.ownerId==(self.ownerId or Players.LocalPlayer.UserId)
  and self.boundCharacter==self:character()and self.room.mode=="Room"and self.room.target=="Room"
end
function Client:reconcilePickup(actor)
 if not actor or not actor.care or actor.care.state~="Carried"then return false end
 for seq,operation in pairs(self.operations)do
  local packet=operation.packet
  if packet.kind=="carePickup"and packet.claimId~=nil and operation.character==self:character()
   and actor.petId==packet.petId and actor.characterId==packet.characterId and actor.petGeneration==packet.petGeneration
   and actor.generation==packet.actorGeneration+1 then
   -- This exact authoritative transition is the confirmation when its remote
   -- receipt is slower or lost. Retire the captured operation once, before the
   -- generic Docked cleanup can classify the snapshot as a forced exit.
   self:receive({kind="carePickup",seq=seq,status="Accepted",snapshotConfirmed=true})
   return true
  end
 end
 return false
end
function Client:step()
 if self.destroyed then return end
 local room=self.room;local actor=self:actor();local state=actor and actor.care and actor.care.state
 local snapshot=room.garden.snapshot;local bay=snapshot and snapshot.careBay;local gap=self:keepsDock(actor,bay)
 self:reconcilePickup(actor)
 local wasVisible=self.pickup.Visible
 self.pickup.Visible=room.focusing and not room.focusTransitioning and not room.overlayOpen()
 if wasVisible~=self.pickup.Visible then room.focusUI:layoutFocusRow()end
 local pickupPending,setDownPending=false,false
 for _,operation in pairs(self.operations)do if operation.packet.kind=="carePickup"then pickupPending=true elseif operation.packet.kind=="careSetDown"then setDownPending=true end end
 -- Perf (v775): Art.control below owns Interactable (enabled = not pending), which is
 -- where both buttons always ended each frame. Writing Interactable here first made
 -- DeckArt's Interactable watcher restyle each button off and back on every frame.
 self.pickup:SetAttribute("AccessibleLabel",if pickupPending then "Picking up companion…"else "Pick up companion")
 self.pickup:SetAttribute("Pending",pickupPending)
 -- Beta (17) U8: a hold the server forced (no dry ground when the bay or a release let go) is not the
 -- player carrying: no put-down arrow, no lease pulse; the server lands the pet when it can.
 local forced=state=="Carried"and actor.care.forced==true
 self.setDown.Visible=state=="Carried"and not forced and room.mode=="Room"and not room.busy and not room.menuOpen and not room.overlayOpen()
 self.setDown:SetAttribute("AccessibleLabel",if setDownPending then "Setting companion down…"else "Set companion down")
 self.setDown:SetAttribute("Pending",setDownPending)
 Art.control(self.pickup,pickupPending,not pickupPending);Art.control(self.setDown,setDownPending,not setDownPending)
 local now=os.clock()
 for seq,op in pairs(self.operations)do
  if op.character~=self:character()then self.operations[seq]=nil;if op.done then op.done({kind=op.packet.kind,seq=seq,status="Rejected",reason="IdentityChanged"})end
  elseif now-op.at>2 and op.tries<3 then
   op.tries+=1;op.at=now;self:send(op.packet)
  elseif now-op.at>20 and not op.saving then self.operations[seq]=nil;if op.done then op.done({kind=op.packet.kind,seq=seq,status="Rejected",reason="TimedOut"})end end
 end
 if state=="Docked"or state=="Carried"then
  local uiLive=self.gui.Parent~=nil and(if self.gui:IsA("ScreenGui")then self.gui.Enabled else self.gui.Visible)
  local owns=uiLive and room.mode=="Room"and room.target=="Room"and((state=="Carried"and not forced)or(self.wantMachine and(not self.isMachineOpen or self.isMachineOpen(actor.care.claimId))))
  if owns and not self.releasing and now>=self.pulseAt then
   self.pulseAt=now+.5;self.seq+=1
   self:send({kind="carePulse",seq=self.seq,petId=actor.petId,characterId=actor.characterId,petGeneration=actor.petGeneration,actorGeneration=actor.generation,claimId=actor.care.claimId})
  end
  if state=="Docked"and self.wantMachine and self.openMachine then self.openMachine(actor)end
 end
 if state=="Docked"then self.boundClaim=actor.care.claimId;self.boundCharacter=self:character()end
 if state~="Docked"and not gap and self.docked then self.wantMachine=false;if self.closeMachine then self.closeMachine()end end
 self.docked=state=="Docked"or gap
 local lounge=workspace:FindFirstChild("EggDropLounge");local machine=lounge and lounge:FindFirstChild("CareMachine")
 local token=bay and bay.id or false
 if machine and self.artToken~=token then
  self.artToken=token
  local key=if bay then "CareOccupiedColor"else "CareRestColor"
  for _,p in ipairs(machine:GetChildren())do if p:IsA("BasePart")then local color=p:GetAttribute(key);if color then p.Color=Color3.fromHex(color)end end end
  -- v7: the visible cradle's mobile glow and lamp carry the same free/occupied state.
  for _,name in ipairs({"World","Lights"})do
   local folder=lounge:FindFirstChild(name)
   if folder then for _,item in ipairs(folder:GetDescendants())do
    if item:GetAttribute("CareStatusSurface")==true and(item:IsA("BasePart")or item:IsA("Light"))then
     local color=item:GetAttribute(key);if color then item.Color=Color3.fromHex(color)end
    end
   end end
  end
 end
 if room.stations then for _,prompt in ipairs(room.stations.prompts)do if prompt:GetAttribute("PocketClubStation")=="Journal"then
  prompt.ActionText=if state=="Carried"then "Place "..room.shownPet.name elseif state=="Docked"then "Care for "..room.shownPet.name elseif bay then "Machine occupied"else "Open companions"
 end end end
end
function Client:destroy()
 if self.destroyed then return end
 -- Best effort exact release; server carry lease also retires a lost UI owner.
 self:release();self.destroyed=true
 for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.operations);self.room.focusUI:bindPickup(nil);self.pickup:Destroy();self.setDown:Destroy()
 self.notifications.cancelOwner(self.controls or self)
 if self.controls then self.controls:Destroy()end
end
return Client
