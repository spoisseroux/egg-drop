-- Local prompt presentation; all return reservations and paths remain server-owned.
local Players=game:GetService("Players")
local Shared=game:GetService("ReplicatedStorage").Shared
local Layout=require(Shared.GardenLayout)
local Intent=require(script.Parent.GardenToyIntent)
local Toy={};Toy.__index=Toy
function Toy.describe(snapshot,ownerId,now)
 local toy=snapshot and snapshot.toy;if not toy then return nil,""end
 local a=toy.returnAction
 if a then
  local status=if type(a.startTime)=="number"and now<a.startTime then "Pets coming…"else "Returning…"
  if a.participants and a.participants[tostring(ownerId)]then return nil,status end
  if a.state=="waiting"and not a.receiverId and a.starterId~=ownerId and now<a.joinUntil then return "toyJoin","Join return",a.id end
  return nil,status
 end
 if toy.ownerId then return "toyStart","Start a return"end
 return "toyStart","Start a return"
end
function Toy.new(garden,part,options)
 local self=setmetatable({garden=garden,part=part,options=options or {},connections={}},Toy)
 local remotes=self.options.remotes or game:GetService("ReplicatedStorage"):WaitForChild("Remotes")
 self.intent=Intent.new(function(packet)local remote=self.options.remote or remotes:FindFirstChild("GardenIntent");if remote then remote:FireServer(packet)end end)
 local prompt=Instance.new("ProximityPrompt");prompt.Name="GardenReturnPrompt";prompt.ObjectText="Garden ball";prompt.ActionText="Start a return"
 prompt.KeyboardKeyCode,prompt.GamepadKeyCode=Enum.KeyCode.E,Enum.KeyCode.ButtonX;prompt.MaxActivationDistance=7;prompt.RequiresLineOfSight=false;prompt.HoldDuration=0;prompt.ClickablePrompt=true
 prompt.Enabled=false;prompt.Parent=part;self.prompt=prompt
 local status=Instance.new("BillboardGui");status.Name="GardenReturnStatus";status.Size=UDim2.fromOffset(190,44);status.StudsOffsetWorldSpace=Vector3.new(0,.85,0);status.MaxDistance=12;status.Enabled=false;status.Parent=part;self.status=status
 local label=Instance.new("TextLabel");label.Size=UDim2.fromScale(1,1);label.BackgroundColor3=Color3.fromHex("#D7FFF1");label.TextColor3=Color3.fromHex("#193D32");label.BorderSizePixel=0;label.Font=Enum.Font.Nunito;label.TextSize=16;label.TextWrapped=true;label.Parent=status;self.statusLabel=label
 table.insert(self.connections,label:GetPropertyChangedSignal("TextBounds"):Connect(function()status.Size=UDim2.fromOffset(190,math.max(44,label.TextBounds.Y+12))end))
 local corner=Instance.new("UICorner");corner.CornerRadius=UDim.new(0,12);corner.Parent=label
 table.insert(self.connections,prompt.Triggered:Connect(function(who)if who==nil or who==Players.LocalPlayer then self:activate()end end))
 local waiting
 local function bindResult(result)
  if self.destroyed or self.resultConnection or not result then return end
  self.resultConnection=result.OnClientEvent:Connect(function(packet)if self.intent:result(packet)and packet.status=="Rejected"then self.message="Try again near the ball";self.messageAge=2 end end)
  table.insert(self.connections,self.resultConnection)
  if waiting then waiting:Disconnect();waiting=nil end
 end
 if self.options.result then bindResult(self.options.result)else
  -- The folder may replicate before its child. Keep one bounded late binder until attached.
  waiting=remotes.ChildAdded:Connect(function(child)if child.Name=="GardenToyResult"and child:IsA("RemoteEvent")then bindResult(child)end end)
  table.insert(self.connections,waiting);bindResult(remotes:FindFirstChild("GardenToyResult"))
 end
 return self
end
function Toy:refresh()
 local actor,position,enabled=self.options.context()
 local horizontal=position and Vector2.new(position.X-Layout.Toy.X,position.Z-Layout.Toy.Z).Magnitude or math.huge
 self.near=enabled==true and actor~=nil and actor.mode=="Room"and horizontal<=7 and math.abs(position.Y-Layout.Toy.Y)<=6
 local pending=self.intent.pending
 if pending and actor then
  local p=pending.packet
  if p.petId~=actor.petId or p.characterId~=actor.characterId or p.petGeneration~=actor.petGeneration then self.intent:abandon()end
 end
 self.actor=actor
 local kind,label,actionId=Toy.describe(self.garden.snapshot,self.garden.playerId,self.garden.now())
 self.kind,self.actionId=kind,actionId
 pending=self.intent.pending
 if pending then label=if pending.retryReady then "Retry return"else "Starting return…"end
 self.prompt.ActionText=label
 self.prompt.Enabled=self.near and((pending and pending.retryReady)or(not pending and kind~=nil))or false
 self.statusLabel.Text=if(self.messageAge or 0)>0 then self.message else label
 self.status.Enabled=self.near and(not self.prompt.Enabled or(self.messageAge or 0)>0)
end
function Toy:activate()
 self:refresh();if not self.prompt.Enabled then return false end
 if self.intent.pending then return self.intent:retry()end
 return self.intent:request(self.kind,self.actor,self.actionId)
end
function Toy:step(dt)
 if self.destroyed then return end
 self.messageAge=math.max(0,(self.messageAge or 0)-dt)
 self:refresh()
 if self.near then self.intent:step(dt)else self.intent:abandon()end
end
function Toy:inReach()return self.near==true end
function Toy:destroy()
 if self.destroyed then return end;self.destroyed=true;self.intent:abandon()
 for _,c in ipairs(self.connections)do c:Disconnect()end;self.prompt:Destroy();self.status:Destroy();self.near=false
end
return Toy
