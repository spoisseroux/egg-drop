-- Original jewel-pond hatch art. Static native GUI geometry, one existing owner clock.
local Art=require(script.Parent.DeckArt)
local Eggs=require(script.Parent.EggArt)
local Stage={};Stage.__index=Stage
local function frame(parent,name,color,z)
 local n=Art.frame(parent,name,color,UDim2.fromOffset(0,0),UDim2.fromOffset(1,1),z);n.Active,n.Selectable=false,false;return n
end
local function oval(parent,name,color,z)
 local n=frame(parent,name,color,z);n.AnchorPoint=Vector2.new(.5,.5);Art.corner(n,1000);return n
end
function Stage.new(parent,rare,recipe)
 local self=setmetatable({rare=rare},Stage);recipe=recipe or "meadow"
 self.pond=frame(parent,"JewelPond",Color3.new(1,1,1),43);self.pond.ClipsDescendants=true;Art.corner(self.pond,14)
 local gradient=Instance.new("UIGradient");gradient.Rotation=90;gradient.Color=ColorSequence.new({ColorSequenceKeypoint.new(0,Color3.fromHex("#2457D0")),ColorSequenceKeypoint.new(1,Color3.fromHex("#16B7CA"))});gradient.Parent=self.pond
 Art.stroke(self.pond,Color3.fromHex("#BAFFF4"),.35,1)
 local sheen=frame(self.pond,"GlassSheen",Color3.new(1,1,1),44);sheen.Position=UDim2.fromScale(.08,.035);sheen.Size=UDim2.fromScale(.30,.018);sheen.BackgroundTransparency=.45;Art.corner(sheen,5)
 self.disc=oval(parent,"DiscoveryHalo",Color3.fromHex("#D7FFF1"),44);self.disc.BackgroundTransparency=.12
 self.discStroke=Art.stroke(self.disc,if rare then Color3.fromHex("#FF9365")else Color3.fromHex("#E7FFF2"),.55,2)
 self.cradle=oval(parent,"CradleRing",Color3.fromHex("#BDFFF0"),45);self.cradle.BackgroundTransparency=.58;Art.stroke(self.cradle,if rare then Color3.fromHex("#FFD05B")else Color3.fromHex("#E7FFF2"),.38,1)
 local arc=frame(self.cradle,"NarrowWhiteArc",Color3.new(1,1,1),46);arc.Position=UDim2.fromScale(.20,.16);arc.Size=UDim2.new(.60,0,0,2);arc.BackgroundTransparency=.24;Art.corner(arc,2)
 self.shell=frame(parent,"Shell",Color3.new(1,1,1),46);self.shell.BackgroundTransparency=1;self.shell.AnchorPoint=Vector2.new(.5,.5)
 Eggs.create(self.shell,recipe,UDim2.fromScale(0,0),UDim2.fromScale(1,1),47,"CompanionShell")
 self.shellScale=Instance.new("UIScale");self.shellScale.Parent=self.shell
 self.crack=frame(self.shell,"Crack",Color3.new(1,1,1),55);self.crack.BackgroundTransparency=1;self.crack.Size=UDim2.fromScale(1,1)
 for i,data in ipairs({{.21,.49,.24,24},{.40,.53,.23,-28},{.58,.50,.22,22}})do
  local edge=frame(self.crack,"Seam"..i,Color3.fromHex("#24438F"),56);edge.Position=UDim2.fromScale(data[1],data[2]);edge.Size=UDim2.new(data[3],0,0,2);edge.Rotation=data[4]
 end
 self.top=frame(parent,"UpperPatternedShellHalf",Color3.new(1,1,1),46);self.top.BackgroundTransparency=1;self.top.AnchorPoint=Vector2.new(.5,.5)
 self.topArt=Eggs.createPiece(self.top,recipe,"upper",UDim2.fromScale(0,0),UDim2.fromScale(1,1),47)
 self.bottom=frame(parent,"LowerPatternedShellHalf",Color3.new(1,1,1),46);self.bottom.BackgroundTransparency=1;self.bottom.AnchorPoint=Vector2.new(.5,.5)
 self.bottomArt=Eggs.createPiece(self.bottom,recipe,"lower",UDim2.fromScale(0,0),UDim2.fromScale(1,1),47)
 -- Split motifs sit behind the 3D/pixel hero (50), so the first reveal has a clean face.
 for _,half in ipairs({self.top,self.bottom})do
  for _,node in ipairs(half:GetDescendants())do if node:IsA("GuiObject")then node.ZIndex=47 end end
 end
 self.top.Visible,self.bottom.Visible=false,false;return self
end
function Stage:layout(x,y,w,h,center,pixels)
 self.pond.Position,self.pond.Size=UDim2.fromOffset(x,y),UDim2.fromOffset(w,h)
 self.center,self.pixels=center,pixels
 self.disc.Position,self.disc.Size=UDim2.fromOffset(center.X,center.Y),UDim2.fromOffset(math.max(1,math.min(w-8,pixels*1.44)),math.max(1,math.min(h-8,pixels*1.15)))
 self.cradle.Position,self.cradle.Size=UDim2.fromOffset(center.X,center.Y+math.min(h*.40,pixels*.36)),UDim2.fromOffset(math.min(w-8,pixels*1.15),math.max(4,pixels*.11))
 self.shell.Position,self.shell.Size=UDim2.fromOffset(center.X,center.Y),UDim2.fromOffset(pixels*.60,pixels*.80)
 for _,half in ipairs({self.top,self.bottom})do half.Size=UDim2.fromOffset(pixels*.60,pixels*.80)end
end
local function pose(self,node,art,dx,dy,angle,upper,ease)
 local c,r=self.center,self.pixels
  local rotation=angle*ease;local a=math.rad(rotation);local cs,sn=math.cos(a),math.sin(a)
  local square=r*.60;local loY,hiY=if upper then -.44 else -.03,if upper then .03 else .40
  local minX,minY,maxX,maxY=math.huge,math.huge,-math.huge,-math.huge
  for side=-1,1,2 do for row=0,1 do
   local x,y=side*.36,if row==0 then loY else hiY
   local px,py=(x*cs-y*sn)*square,(x*sn+y*cs)*square
   minX,minY,maxX,maxY=math.min(minX,px),math.min(minY,py),math.max(maxX,px),math.max(maxY,py)
  end end
  local p,size=self.pond.Position,self.pond.Size
  local left,right=p.X.Offset+4-minX,p.X.Offset+size.X.Offset-4-maxX
  local top,bottom=p.Y.Offset+4-minY,p.Y.Offset+size.Y.Offset-4-maxY
  local x=math.clamp(c.X+dx*r*ease,left,math.max(left,right));local y=math.clamp(c.Y+dy*r*ease,top,math.max(top,bottom))
  node.Position=UDim2.fromOffset(x,y);art.Rotation=rotation
  node:SetAttribute("ArtLeft",x+minX);node:SetAttribute("ArtRight",x+maxX);node:SetAttribute("ArtTop",y+minY);node:SetAttribute("ArtBottom",y+maxY)
 end
function Stage:split(age,visible)
 local upper=self.topArt.RegisteredShell.ShellImage;local lower=self.bottomArt.RegisteredShell.ShellImage
 local ready=upper.IsLoaded and lower.IsLoaded
 self.top:SetAttribute("AtlasReady",ready);self.bottom:SetAttribute("AtlasReady",ready)
 self.top.Visible,self.bottom.Visible=visible,visible
 -- Each half has a complementary native fallback. Never put the whole shell
 -- back in front of the already-visible hero when image fetching fails.
 if visible then self.shell.Visible=false end
 if not visible then return end
 local u=math.clamp(age/.18,0,1);local ease=1-(1-u)^3;local c,r=self.center,self.pixels
 -- Bounds are the registered shell's opaque art, rather than its transparent
 -- square. Both native and atlas halves use this same conservative silhouette.

 pose(self,self.top,self.topArt,-.30,-.25,-22,true,ease)
 pose(self,self.bottom,self.bottomArt,.33,.20,20,false,ease)
end
return Stage
