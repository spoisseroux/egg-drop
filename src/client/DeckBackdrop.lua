-- One bounded exterior/preview surface: 16 bands, no instance churn after new().
local Backdrop={};Backdrop.__index=Backdrop
Backdrop.Period=24;Backdrop.Step=1/15
local function frame(parent,name)
 local f=Instance.new("Frame");f.Name,f.BorderSizePixel,f.BackgroundTransparency=name,0,1
 f.Active,f.Selectable,f.ZIndex=false,false,parent.ZIndex+1;f.Parent=parent;return f
end
local function assign(self,node,property,value,category)
 if node[property]==value then return end
 node[property]=value;self.stats.writes+=1;self.stats[category]=(self.stats[category]or 0)+1
end
function Backdrop.new(parent)
 local started=os.clock()
 local root=frame(parent,"PatternSurface");root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true
 local self=setmetatable({root=root,home=parent,homeOffset=root.ZIndex-parent.ZIndex,layers={},bands={},elapsed=0,phases=setmetatable({},{__mode="k"}),stats={stripHosts=16,primitives=0,created=1,writes=0,ticks=0}},Backdrop)
 for layer=1,2 do for row=1,8 do
  local host=frame(root,"Band"..layer.."_"..row);host.ClipsDescendants=true
  local canvas=frame(host,"RepeatCanvas");local entry={host=host,canvas=canvas,layer=layer,row=row,pieces={}}
  for tile=0,3 do for mark=1,2 do
   local body=frame(canvas,"Motif");local core=frame(body,"Highlight")
   local curve=Instance.new("UICorner");curve.Parent=body
   local inset=Instance.new("UICorner");inset.Parent=core
   table.insert(entry.pieces,{body=body,core=core,curve=curve,inset=inset,tile=tile,mark=mark})
   self.stats.primitives+=2;self.stats.created+=4
  end end
  table.insert(self.bands,entry);self.stats.created+=2
 end end
 self.layers[1]={node=root,offset=0}
 for _,node in ipairs(root:GetDescendants())do if node:IsA("GuiObject")then table.insert(self.layers,{node=node,offset=node.ZIndex-root.ZIndex})end end
 self.stats.constructionMs=(os.clock()-started)*1000
 root.Destroying:Connect(function()self.destroyed=true end)
 return self
end
function Backdrop:configure(id,theme)
 if self.id==id and self.theme==theme then return false end
 self.id,self.theme=id,theme;self.bucket=nil;self.colorBucket=nil;self.resting=false
 assign(self,self.root,"BackgroundTransparency",0,"styleWrites");assign(self,self.root,"BackgroundColor3",theme.backdrop,"colorWrites")
 self.colorsApplied=false
 for _,b in ipairs(self.bands)do for _,p in ipairs(b.pieces)do
  local layer=b.layer
  local x=p.tile*.25+(if p.mark==1 then .03 else .16)
  local y=if p.mark==1 then .20 else .69
  assign(self,p.body,"Position",UDim2.fromScale(x,y),"geometryWrites")
  if id=="creek"then
   assign(self,p.body,"Size",UDim2.fromScale(.095,if layer==1 then .14 else .08),"geometryWrites");assign(self,p.body,"Rotation",0,"geometryWrites");assign(self,p.curve,"CornerRadius",UDim.new(.5,0),"styleWrites")
   assign(self,p.core,"Position",UDim2.fromScale(.06,.21),"geometryWrites");assign(self,p.core,"Size",UDim2.fromScale(.88,.58),"geometryWrites");assign(self,p.inset,"CornerRadius",UDim.new(.5,0),"styleWrites")
  else
   assign(self,p.body,"Size",UDim2.fromScale(.0275,if layer==1 then .12 else .07),"geometryWrites");assign(self,p.body,"Rotation",45,"geometryWrites");assign(self,p.curve,"CornerRadius",UDim.new(0,2),"styleWrites")
   assign(self,p.core,"Position",UDim2.fromScale(.25,.25),"geometryWrites");assign(self,p.core,"Size",UDim2.fromScale(.5,.5),"geometryWrites");assign(self,p.inset,"CornerRadius",UDim.new(0,1),"styleWrites")
  end
  assign(self,p.body,"BackgroundTransparency",if layer==1 then .72 else .86,"styleWrites")
  assign(self,p.core,"BackgroundTransparency",if id=="creek"then .12 else .38,"styleWrites")
 end end
 self:colors(.2);return true
end
function Backdrop:colors(phase)
 if self.id=="creek"and self.colorsApplied then return end;self.colorsApplied=true
 for _,b in ipairs(self.bands)do
  local tone=if self.id=="lantern"then self.theme.buttons:Lerp(self.theme.trim,(math.sin(phase*math.pi*2*b.layer)+1)/2)else self.theme.band:Lerp(self.theme.trim,if b.layer==1 then .4 else .72)
  for _,p in ipairs(b.pieces)do assign(self,p.body,"BackgroundColor3",tone,"colorWrites");assign(self,p.core,"BackgroundColor3",if self.id=="creek"then self.theme.backdrop else self.theme.trim,"colorWrites") end
 end
end
function Backdrop:resize()
 local size=self.root.AbsoluteSize;if self.size==size then return end;self.size=size;self.resting=false
 for _,b in ipairs(self.bands)do
  local top=math.floor((b.row-1)*size.Y/8+.5);local bottom=math.floor(b.row*size.Y/8+.5)
  assign(self,b.host,"Position",UDim2.fromOffset(0,top),"geometryWrites");assign(self,b.host,"Size",UDim2.fromOffset(size.X,bottom-top),"geometryWrites")
  assign(self,b.canvas,"Size",UDim2.fromOffset(size.X*2,size.Y),"geometryWrites");b.top=top
 end
 self.bucket=nil
end
function Backdrop:pose(phase)
 local size=self.size
 for _,b in ipairs(self.bands)do
  local amplitude=size.X*(if b.layer==1 then .026 else .044)
  local direction=if self.id=="lantern"and b.row%2==0 then -1 else 1
  local offset=math.sin(phase*math.pi*2*b.layer+b.row*.56)*amplitude*direction
  assign(self,b.canvas,"Position",UDim2.fromOffset(-size.X*.5+offset,-b.top),"poseWrites")
 end
 self.stats.ticks+=1
end
-- Global-Z sheets need the borrowed surface above its opaque preview face.
-- Cache geometry's authored depths once; no descendants are discovered on ticks.
function Backdrop:setOwner(owner)
 if self.root.Parent~=owner then assign(self,self.root,"Parent",owner,"ownerWrites");self.size=nil;self.resting=false end
 if self.layerOwner==owner and self.ownerZ==owner.ZIndex then return end
 self.layerOwner,self.ownerZ=owner,owner.ZIndex
 local base=owner.ZIndex+(if owner==self.home then self.homeOffset else 1)
 for _,entry in ipairs(self.layers)do assign(self,entry.node,"ZIndex",base+entry.offset,"layerWrites")end
end
function Backdrop:releaseOwner(owner)
 if self.destroyed or self.root.Parent~=owner or not self.home.Parent then return end
 self:setOwner(self.home);assign(self,self.root,"Visible",false,"visibilityWrites")
end
function Backdrop:update(owner,now,visible,reduced)
 if self.destroyed then return end
 self:setOwner(owner)
 if self.phaseOwner~=owner or self.activeId~=self.id or not self.phaseState then
  self.phaseOwner=owner
  local states=self.phases[owner];if not states then states={};self.phases[owner]=states end
  self.phaseState=states[self.id];if not self.phaseState then self.phaseState={elapsed=0};states[self.id]=self.phaseState end
  self.elapsed=self.phaseState.elapsed;self.activeId=self.id;self.lastTime=nil;self.resting=false;self.bucket=nil;self.colorBucket=nil
 end
 assign(self,self.root,"Visible",visible,"visibilityWrites")
 if not visible then self.lastTime=nil;return end
 self:resize()
 if reduced then
  if not self.resting then self:pose(.2);self:colors(.2);self.resting=true end
  self.lastTime=nil;return
 end
 if self.resting then self.bucket=nil end;self.resting=false
 self.elapsed=(self.elapsed+(if self.lastTime then math.max(0,now-self.lastTime)else 0))%Backdrop.Period;self.lastTime=now
 self.phaseState.elapsed=self.elapsed
 local bucket=math.floor(self.elapsed/Backdrop.Step+1e-6)
 if self.bucket==bucket then return end;self.bucket=bucket
 self:pose(bucket*Backdrop.Step/Backdrop.Period)
 local colorBucket=math.floor(self.elapsed)
 if self.colorBucket~=colorBucket then self.colorBucket=colorBucket;self:colors(colorBucket/Backdrop.Period)end
end
function Backdrop.thumbnail(host,id,theme)
 local root=host:FindFirstChild("PatternThumbnail")
 if not root then
  root=frame(host,"PatternThumbnail");root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true
  for i=1,2 do local body=frame(root,"Body"..i);frame(body,"Core");local c=Instance.new("UICorner");c.Parent=body;local inner=Instance.new("UICorner");inner.Parent=body.Core end
 end
 root.BackgroundTransparency=0;root.BackgroundColor3=theme.backdrop
 for i=1,2 do
  local body=root["Body"..i];body.BackgroundTransparency=if i==1 then .25 else .55
  body.BackgroundColor3=if id=="lantern"then theme.buttons else theme.trim
  body.Position=UDim2.fromScale(if i==1 then .12 else .56,if i==1 then .2 else .55)
  body.Size=if id=="lantern"then UDim2.fromScale(.2,.4)else UDim2.fromScale(.35,.3)
  body.Rotation=if id=="lantern"then 45 elseif id=="canopy"then -25 else 0
  body:FindFirstChildOfClass("UICorner").CornerRadius=if id=="lantern"then UDim.new(0,1)else UDim.new(.5,0)
  body.Core.Position,body.Core.Size=UDim2.fromScale(.12,.25),UDim2.fromScale(.76,.5)
  body.Core.BackgroundTransparency=if id=="canopy"then 1 else .1
  body.Core.BackgroundColor3=if id=="creek"then theme.backdrop else theme.trim
  body.Core:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(.5,0)
 end
 return root
end
function Backdrop:destroy()if self.destroyed then return end;self.destroyed=true;self.root:Destroy()end
return Backdrop
