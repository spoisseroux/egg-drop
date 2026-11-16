-- RETIRED 2026-11-15 (QA v735 D5): the game no longer builds this. Moonpond is drawn by
-- DeckBackdrop's shared, animated motif bands. Kept for scripts/QAPreviewBounds.spec.lua.
-- Astra's Moonpond: original native GUI geometry, static in every motion mode.
-- Six broken oval arcs / five edge fireflies maximum; no uploaded bitmap asset.
local Moonpond={};Moonpond.__index=Moonpond
Moonpond.Spec=table.freeze({base="#102A35",pond="#173D49",pondInner="#1E4D56",arc="#3D777A",dot="#E7DAB0",reflection="#736C99",
 arcs=table.freeze({{.08,.22,.16,.52,20,130},{.08,.22,.24,.52,30,140},{.91,.62,.18,.58,170,140},
  {.91,.62,.28,.58,175,130},{.15,.86,.10,.55,190,110},{.15,.86,.21,.55,195,100}}),
 dots=table.freeze({{.035,.14},{.965,.22},{.06,.79},{.94,.87},{.09,.95}})})
local function node(parent,name,color,alpha)
 local f=Instance.new("Frame");f.Name=name;f.BackgroundColor3=Color3.fromHex(color);f.BackgroundTransparency=alpha or 0
 f.BorderSizePixel=0;f.Active=false;f.Selectable=false;f.Parent=parent;return f
end
local function corner(f)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(.5,0);c.Parent=f end
local function overlaps(x,y,w,h,r)
 return r and x<r.Max.X and x+w>r.Min.X and y<r.Max.Y and y+h>r.Min.Y
end
function Moonpond.new(parent,options)
 local spec=Moonpond.Spec;local root=node(parent,"Moonpond",spec.base);root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true
 local self=setmetatable({root=root,options=options or {},arcs={},dots={},layers={},stats={created=0,writes=0}},Moonpond)
 self.pond=node(root,"Pond",spec.pond);corner(self.pond)
 self.inner=node(root,"PondInner",spec.pondInner,.35);corner(self.inner)
 for i,arc in ipairs(spec.arcs)do
  for j=1,16 do local f=node(root,"Arc"..i.."_"..j,spec.arc,.80);table.insert(self.arcs,{root=f,spec=arc,segment=j})end
 end
 for i,p in ipairs(spec.dots)do local f=node(root,"Firefly"..i,spec.dot,.28);corner(f);table.insert(self.dots,{root=f,at=p})end
 self.reflection=node(root,"Reflection",spec.reflection,.88);corner(self.reflection);self.reflection.Rotation=-24
 self:setZIndex(parent.ZIndex+1)
 self.connection=root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:resize()end)
 self:resize();self.stats.created=#root:GetDescendants()+1
 return self
end
function Moonpond:setZIndex(z)
 self.root.ZIndex=z
 -- Board field (Global ZIndex): the pond shares the pattern's depth so it never rises above the balls.
 local inner=if self.options.field then z else z+1
 for _,f in ipairs(self.root:GetDescendants())do if f:IsA("GuiObject")then f.ZIndex=inner end end
end
-- caseRect is in this root's local physical pixels, not absolute screen pixels.
function Moonpond:resize(size,caseRect)
 if self.destroyed then return end
 size=size or self.root.AbsoluteSize
 if caseRect~=nil then self.caseRect=caseRect end
 if self.size==size and self.lastCase==self.caseRect then return end
 self.size,self.lastCase=size,self.caseRect;local w,h=size.X,size.Y
 self.pond.Position=UDim2.fromOffset(-w*.25,h*.81);self.pond.Size=UDim2.fromOffset(w*1.3,h*.57)
 self.inner.Position=UDim2.fromOffset(-w*.18,h*.89);self.inner.Size=UDim2.fromOffset(w*1.15,h*.43)
 local viewport=Rect.new(0,0,w,h)
 local visible=0
 for _,entry in ipairs(self.arcs)do
  local a=entry.spec;local start=math.rad(a[5]+a[6]*(entry.segment-1)/16);local finish=math.rad(a[5]+a[6]*entry.segment/16)
  local x1,y1=(a[1]+math.cos(start)*a[3])*w,(a[2]+math.sin(start)*a[3]*a[4])*h
  local x2,y2=(a[1]+math.cos(finish)*a[3])*w,(a[2]+math.sin(finish)*a[3]*a[4])*h
  local length=math.sqrt((x2-x1)^2+(y2-y1)^2);local x,y=(x1+x2)/2,(y1+y2)/2
  local f=entry.root;f.AnchorPoint=Vector2.new(.5,.5);f.Position=UDim2.fromOffset(x,y);f.Size=UDim2.fromOffset(length+.5,1)
  f.Rotation=math.deg(math.atan2(y2-y1,x2-x1))
  local quiet=x-length/2<w*.70 and x+length/2>w*.30
  -- Include line width, integer UDim position/size quantization and antialiasing.
  -- Cull wholly offscreen segments rather than claiming clipped pieces visible.
  local bx,by=math.min(x1,x2)-2,math.min(y1,y2)-2
  local bw,bh=math.abs(x2-x1)+4,math.abs(y2-y1)+4
  entry.bounds={x=bx,y=by,w=bw,h=bh}
  f.Visible=not quiet and overlaps(bx,by,bw,bh,viewport)and not overlaps(bx,by,bw,bh,self.caseRect)
  if f.Visible then visible+=1 end
 end
 for _,entry in ipairs(self.dots)do
  local x,y=entry.at[1]*w,entry.at[2]*h;local f=entry.root
  f.Size=UDim2.fromOffset(2,2);f.Position=UDim2.fromOffset(x,y)
  f.Visible=not self.options.field and overlaps(x,y,2,2,viewport)and not overlaps(x,y,2,2,self.caseRect)
 end
 local rw,rh=w*.08,math.max(1,h*.012)
 self.reflection.Size=UDim2.fromOffset(rw,rh);self.reflection.Position=UDim2.fromOffset(w*.92,h*.10)
 local angle=math.rad(24);local aw=rw*math.cos(angle)+rh*math.sin(angle);local ah=rw*math.sin(angle)+rh*math.cos(angle)
 local rx,ry=w*.92+rw/2-aw/2,h*.10+rh/2-ah/2
 self.reflection.Visible=overlaps(rx,ry,aw,ah,viewport)and not overlaps(rx,ry,aw,ah,self.caseRect)
 self.stats.visibleArcSegments=visible;self.stats.writes+=1
end
function Moonpond:step(_dt,_active,_reduced)self:resize()end
function Moonpond:destroy()
 if self.destroyed then return end;self.destroyed=true
 if self.connection then self.connection:Disconnect();self.connection=nil end
 self.root:Destroy()
end
return Moonpond
