-- Authored cosmetics only. One caller-owned 12Hz sampler; no jobs/instances/rays.
local Clock=require(script.Parent.HollowClock)
local Ambience={};Ambience.__index=Ambience
Ambience.Step=1/12;Ambience.Limit=18;Ambience.ActiveCap=3;Ambience.ViewDistance=80
local kinds={water=true,leaf=true,firefly=true}
local safetyProperties={"Anchored","CanCollide","CanTouch","CanQuery"}
local attributes={"HollowAmbientKind","HollowAmbientPhase","HollowAmbientPeriod","HollowAmbientAmplitude","HollowRestCFrame","HollowRestTransparency"}
local function finite(v)return type(v)=="number"and v==v and math.abs(v)<math.huge end
local function cosmetic(part)return part.Parent and part.Anchored and not part.CanCollide and not part.CanTouch and not part.CanQuery end
local function inView(camera,position)local point,visible=camera:WorldToViewportPoint(position);return visible and point.Z>0 end
function Ambience:transform(entry,value)
 if entry.lastCFrame~=value then entry.part.CFrame=value;entry.lastCFrame=value;self.cframeWrites+=1 end
end
function Ambience:alpha(entry,value)
 if entry.lastTransparency~=value then entry.part.Transparency=value;entry.lastTransparency=value;self.alphaWrites+=1 end
end
function Ambience:rest(entry)
 if not entry.valid or not cosmetic(entry.part)then return end
 self:transform(entry,entry.rest);self:alpha(entry,if entry.kind=="firefly"then 1 else entry.transparency)
 entry.moving=false
end
function Ambience:metadata(entry)
 if self.destroyed or self.records[entry.part]~=entry then return end
 local p=entry.part;local kind,phase,period,amplitude,rest,alpha=p:GetAttribute(attributes[1]),p:GetAttribute(attributes[2]),p:GetAttribute(attributes[3]),p:GetAttribute(attributes[4]),p:GetAttribute(attributes[5]),p:GetAttribute(attributes[6])
 if not kinds[kind]or not finite(phase)or not finite(period)or period<=0 or typeof(amplitude)~="Vector3"or typeof(rest)~="CFrame"or not finite(amplitude.X)or not finite(amplitude.Y)or not finite(amplitude.Z)or not cosmetic(p)then
  self:rest(entry);entry.valid=false;return
 end
 alpha=if finite(alpha)and alpha>=0 and alpha<=1 then alpha else p.Transparency
 if entry.valid and entry.kind==kind and entry.phase==phase%1 and entry.period==period and entry.amplitude==amplitude and entry.rest==rest and entry.transparency==alpha then return end
 entry.kind,entry.phase,entry.period,entry.amplitude,entry.rest,entry.transparency=kind,phase%1,period,amplitude,rest,alpha
 entry.lastCFrame,entry.lastTransparency=p.CFrame,p.Transparency;entry.valid=true
 self:rest(entry)
end
function Ambience:track(part)
 if not part:IsA("BasePart")or part.Name:sub(1,14)~="HollowAmbient_"or self.records[part]or #self.entries>=Ambience.Limit then return end
 local entry={part=part,connections={},index=#self.entries+1};self.entries[entry.index]=entry;self.records[part]=entry
 local function changed()self:metadata(entry)end
 for _,name in ipairs(attributes)do table.insert(entry.connections,part:GetAttributeChangedSignal(name):Connect(changed))end
 for _,name in ipairs(safetyProperties)do table.insert(entry.connections,part:GetPropertyChangedSignal(name):Connect(changed))end
 self:metadata(entry)
end
function Ambience:remove(part,restore)
 local entry=self.records[part];if not entry then return end
 -- Streaming removal must never race the parent change with a Part write.
 -- Only an explicit owner rebind/destroy restores still-owned cosmetics.
 if restore then self:rest(entry)end;self.records[part]=nil
 for _,c in ipairs(entry.connections)do c:Disconnect()end
 local last=table.remove(self.entries);if last~=entry then self.entries[entry.index]=last;last.index=entry.index end
end
function Ambience:bind(room)
 if self.room==room then return end
 for _,c in ipairs(self.roomConnections)do c:Disconnect()end;table.clear(self.roomConnections)
 while #self.entries>0 do self:remove(self.entries[#self.entries].part,true)end
 self.room=room;self.elapsed=0;self.lastEnabled=false
 if not room then return end
 table.insert(self.roomConnections,room.DescendantAdded:Connect(function(part)if not self.destroyed and self.room==room then self:track(part)end end))
 table.insert(self.roomConnections,room.DescendantRemoving:Connect(function(part)if not self.destroyed and self.room==room then self:remove(part,false)end end))
 self.scans+=1;for _,part in ipairs(room:GetDescendants())do self:track(part)end
end
function Ambience:step(dt,camera,enabled,reduced)
 if self.destroyed then return end
 enabled=enabled==true and camera~=nil and camera.Parent~=nil and self.room~=nil
 if not enabled or reduced then
  if self.lastEnabled~=enabled or self.lastReduced~=reduced or not self.rested then for _,entry in ipairs(self.entries)do self:rest(entry)end;self.rested=true end
  self.lastEnabled,self.lastReduced=enabled,reduced;self.elapsed=0;return
 end
 self.lastEnabled,self.lastReduced,self.rested=enabled,reduced,false
 self.elapsed+=dt;if self.elapsed<Ambience.Step then return end;self.elapsed%=Ambience.Step
 local now=self.now();local daylight=self.daylight();local origin=camera.CFrame.Position
 self.ticks+=1
 local eligible=self.eligible;table.clear(eligible)
 for _,entry in ipairs(self.entries)do
  entry.selected=false
  if entry.valid and cosmetic(entry.part)then
   entry.distance=(entry.rest.Position-origin).Magnitude
   if entry.distance<=Ambience.ViewDistance and not(entry.kind=="firefly"and daylight>.3)and self.view(camera,entry.rest.Position)then table.insert(eligible,entry)end
  end
 end
 table.sort(eligible,function(a,b)return if a.distance==b.distance then a.index<b.index else a.distance<b.distance end)
 for i=1,math.min(Ambience.ActiveCap,#eligible)do eligible[i].selected=true end
 for _,entry in ipairs(self.entries)do
  if entry.valid and cosmetic(entry.part)then
   if not entry.selected then self:rest(entry)else
    local cycle=((now%entry.period)/entry.period+entry.phase)%1;local angle=cycle*math.pi*2
    local a=entry.amplitude;local offset=Vector3.new(a.X*math.sin(angle),a.Y*math.sin(angle*2),a.Z*math.cos(angle))
    local alpha=entry.transparency
    if entry.kind=="water"and math.abs(a.Y)>math.abs(a.X)+math.abs(a.Z)then
     offset=a*(1-cycle*2);alpha=alpha+(1-alpha)*(math.abs(cycle*2-1)^2)
    elseif entry.kind=="firefly"then alpha=math.clamp(alpha+.22*(1+math.sin(angle*2))*.5,0,1)end
    local pose=CFrame.new(offset)*entry.rest
    if entry.kind=="leaf"then pose*=CFrame.Angles(0,0,math.sin(angle)*math.rad(2))end
    self:transform(entry,pose);self:alpha(entry,alpha);entry.moving=true
   end
  end
 end
end
function Ambience:stats()
 local valid,active=0,0;for _,e in ipairs(self.entries)do if e.valid then valid+=1 end;if e.moving then active+=1 end end
 return{candidates=#self.entries,parts=valid,active=active,connections=#self.connections+#self.roomConnections+#self.entries*(#attributes+#safetyProperties),scans=self.scans,ticks=self.ticks,cframeWrites=self.cframeWrites,alphaWrites=self.alphaWrites}
end
function Ambience:getStats()return self:stats()end
function Ambience:destroy()
 if self.destroyed then return end
 self:bind(nil);self.destroyed=true;for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
end
function Ambience.new(options)
 options=options or {};local world=options.world or workspace
 local self=setmetatable({world=world,now=options.now or function()return workspace:GetServerTimeNow()end,view=options.view or inView,daylight=options.daylight or Clock.daylight,
  records={},entries={},eligible={},connections={},roomConnections={},elapsed=0,scans=0,ticks=0,cframeWrites=0,alphaWrites=0},Ambience)
 table.insert(self.connections,world.ChildAdded:Connect(function(room)if not self.destroyed and room.Name=="EggDropLounge"then self:bind(room)end end))
 table.insert(self.connections,world.ChildRemoved:Connect(function(room)if not self.destroyed and self.room==room then self:bind(nil)end end))
 self:bind(world:FindFirstChild("EggDropLounge"));return self
end
return Ambience
