-- One bounded exterior/preview surface: 16 bands, no instance churn after new().
-- QA v735 D5: Moonpond is one of these patterns now (crescent moons on the first layer,
-- small stars on the second, drifting and twinkling in the plate's colours like Canopy,
-- Creek and Lantern). It used to be a separate static renderer (MoonpondBackdrop: arcs,
-- five dots and its own navy palette) that opted out of every pose and colour tick.
local Backdrop={};Backdrop.__index=Backdrop
Backdrop.Period=24;Backdrop.Step=1/15
Backdrop.MotifOpacity=.88
-- v859 phone notes: the 68% floor read as an opaque green wall around the deck. Now a light
-- tint: about 78% of the garden shows through, the motifs (MotifOpacity) stay on top of it.
-- Reduce transparency (GuiService.PreferredTransparency 0) still makes it opaque.
Backdrop.ExteriorOpacity=.22
-- The floor carries it directly (CanvasGroup GroupTransparency did not render in
-- Studio captures). Borrowed previews and plain surfaces keep an opaque floor.
local function frame(parent,name)
 local f=Instance.new("Frame");f.Name,f.BorderSizePixel,f.BackgroundTransparency=name,0,1
 f.Active,f.Selectable,f.ZIndex=false,false,parent.ZIndex+1;f.Parent=parent;return f
end
local function roundedRoot(parent,name)
 if parent:IsA("CanvasGroup")then return frame(parent,name)end
 local root=Instance.new("CanvasGroup");root.Name=name;root.BackgroundTransparency=1;root.BorderSizePixel=0
 root.Active,root.Selectable=false,false;root.ZIndex=parent.ZIndex+1;root.ClipsDescendants=true;root.Parent=parent
 local source=parent:FindFirstChildOfClass("UICorner")
 local corner=Instance.new("UICorner");corner.CornerRadius=if source then source.CornerRadius else UDim.new(0,8);corner.Parent=root
 return root
end
local function assign(self,node,property,value,category)
 if node[property]==value then return end
 node[property]=value;self.stats.writes+=1;self.stats[category]=(self.stats[category]or 0)+1
end
function Backdrop.new(parent,options)
 local started=os.clock()
 local root=frame(parent,"PatternSurface");root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true
 local self=setmetatable({root=root,home=parent,exterior=options and options.exterior==true,homeOffset=root.ZIndex-parent.ZIndex,layers={},bands={},elapsed=0,phases=setmetatable({},{__mode="k"}),stats={stripHosts=16,primitives=0,created=1,writes=0,ticks=0}},Backdrop)
 for layer=1,2 do for row=1,8 do
  local host=frame(root,"Band"..layer.."_"..row);host.ClipsDescendants=false
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
 self:floor();assign(self,self.root,"BackgroundColor3",theme.backdrop,"colorWrites")
 self.colorsApplied=false
 for _,b in ipairs(self.bands)do for _,p in ipairs(b.pieces)do
  local layer=b.layer
  if id=="creek"then
   assign(self,p.body,"Rotation",0,"geometryWrites");assign(self,p.curve,"CornerRadius",UDim.new(.5,0),"styleWrites")
   assign(self,p.core,"Position",UDim2.fromScale(.09,.25),"geometryWrites");assign(self,p.core,"Size",UDim2.fromScale(.82,.5),"geometryWrites");assign(self,p.inset,"CornerRadius",UDim.new(.5,0),"styleWrites")
  elseif id=="canopy"then
   assign(self,p.body,"Rotation",if p.mark==1 then -32 else 28,"geometryWrites");assign(self,p.curve,"CornerRadius",UDim.new(.5,0),"styleWrites")
   assign(self,p.core,"Position",UDim2.fromScale(.88,.2),"geometryWrites");assign(self,p.core,"Size",UDim2.fromScale(.65,.9),"geometryWrites");assign(self,p.inset,"CornerRadius",UDim.new(.5,0),"styleWrites")
  elseif id=="moonpond"then
   -- Layer 1, a crescent: a disc with a smaller disc in the floor's colour inside it,
   -- touching its rim (what is left is the moon). Layer 2, a star: a dot with a bright centre.
   assign(self,p.body,"Rotation",if layer==1 then(if p.mark==1 then -28 else 22)else 0,"geometryWrites");assign(self,p.curve,"CornerRadius",UDim.new(.5,0),"styleWrites")
   assign(self,p.core,"Position",if layer==1 then UDim2.fromScale(.21,.03)else UDim2.fromScale(.25,.25),"geometryWrites")
   assign(self,p.core,"Size",if layer==1 then UDim2.fromScale(.78,.78)else UDim2.fromScale(.5,.5),"geometryWrites");assign(self,p.inset,"CornerRadius",UDim.new(.5,0),"styleWrites")
  else
   assign(self,p.body,"Rotation",45,"geometryWrites");assign(self,p.curve,"CornerRadius",UDim.new(0,2),"styleWrites")
   assign(self,p.core,"Position",UDim2.fromScale(.25,.25),"geometryWrites");assign(self,p.core,"Size",UDim2.fromScale(.5,.5),"geometryWrites");assign(self,p.inset,"CornerRadius",UDim.new(0,1),"styleWrites")
  end
  assign(self,p.body,"BackgroundTransparency",1-(if layer==1 then .66 else .45)*Backdrop.MotifOpacity,"styleWrites")
  assign(self,p.core,"BackgroundTransparency",if id=="moonpond"and layer==1 then 0 else 1-(if id=="creek"then .88 else .78)*Backdrop.MotifOpacity,"styleWrites")
 end end
 self.size=nil;self:colors(.2);return true
end
function Backdrop:floor()
 local seeThrough=self.exterior and self.root.Parent==self.home
 assign(self,self.root,"BackgroundTransparency",if seeThrough then (1-Backdrop.ExteriorOpacity)*math.clamp(game:GetService("GuiService").PreferredTransparency,0,1) else 0,"styleWrites")
end
function Backdrop:colors(phase)
 if self.id=="creek"and self.colorsApplied then return end;self.colorsApplied=true
 if self.id=="moonpond"then
  -- Moons keep one pale tone; the stars twinkle between the plate's face colour and its
  -- highlight, each row a little out of step (one colour tick a second, like Lantern's glow).
  local moon=self.theme.face:Lerp(self.theme.highlight,.9)
  for _,b in ipairs(self.bands)do
   local twinkle=(math.sin(phase*math.pi*2*3+b.row*1.9)+1)/2
   local star=self.theme.face:Lerp(self.theme.highlight,.2+.8*twinkle)
   for _,p in ipairs(b.pieces)do
    assign(self,p.body,"BackgroundColor3",if b.layer==1 then moon else star,"colorWrites")
    assign(self,p.core,"BackgroundColor3",if b.layer==1 then self.theme.backdrop else self.theme.highlight:Lerp(Color3.new(1,1,1),.5),"colorWrites")
   end
  end
  return
 end
 for _,b in ipairs(self.bands)do
  local tone=if self.id=="lantern"then self.theme.buttons:Lerp(self.theme.trim,(math.sin(phase*math.pi*2*b.layer)+1)/2)else self.theme.face:Lerp(self.theme.highlight,if b.layer==1 then .55 else .9)
  for _,p in ipairs(b.pieces)do assign(self,p.body,"BackgroundColor3",tone,"colorWrites");assign(self,p.core,"BackgroundColor3",if self.id=="creek"then self.theme.backdrop else self.theme.trim,"colorWrites") end
 end
end
function Backdrop:resize()
 local size=self.root.AbsoluteSize;if self.size==size then return end;self.size=size;self.resting=false
 local pitch=if size.X>=1000 then 64 else 46
 local motif=if size.X>=1000 then 28 else 22
 self.stats.pitch,self.stats.motifWidth=pitch,motif
 -- QA v760: the exterior pattern is always there. Each layer's 64 motifs sit on one even
 -- grid over the whole surface (the second layer half a cell across and down), the
 -- handheld simply sits on top of them, and nothing is switched off for being behind it.
 -- They used to be packed into the gutters around the case and hidden whenever a drift
 -- carried one over the case's rectangle, so they popped in and out beside the deck.
 -- To keep the print as dense as before where it shows, the cells deep under the case
 -- (56 px or more inside it) keep one motif in nine: enough that the pattern is still
 -- there while the handheld rises into place. The grid is the finest one that fits.
 local exterior=self.root.Parent==self.home
 local cells
 if exterior then
  local case=self.case
  if not case then
   local ch=math.min(724,math.max(1,size.Y-24));local cw=math.min(size.X-24,ch*1.52)
   case={x=(size.X-cw)/2,y=(size.Y-ch)/2,w=cw,h=ch}
  end
  local inset=56
  local step=pitch-2
  repeat
   step+=2
   cells={{},{}}
   local cols,rows=math.ceil(size.X/step),math.ceil(size.Y/step)
   local fits=true
   for layer=1,2 do
    local shift=if layer==2 then .5 else 0
    for row=0,rows-1 do for col=0,cols-1 do
     local x,y=(col+.25+shift)*step,(row+.25+shift)*step
     local deep=x>case.x+inset and x<case.x+case.w-inset and y>case.y+inset and y<case.y+case.h-inset
     if x<size.X+motif and y<size.Y+motif and(not deep or(col%3==0 and row%3==0))then table.insert(cells[layer],{x,y})end
    end end
    if #cells[layer]>64 then fits=false;break end
   end
  until fits or step>=400
  self.stats.pitch=step
 else
  pitch=math.max(pitch,size.X/32,size.Y/16);self.stats.pitch=pitch
 end
 for _,b in ipairs(self.bands)do
  assign(self,b.host,"Position",UDim2.fromOffset(0,0),"geometryWrites");assign(self,b.host,"Size",UDim2.fromOffset(size.X,size.Y),"geometryWrites")
  assign(self,b.canvas,"Size",UDim2.fromOffset(size.X*2,size.Y),"geometryWrites");b.top=0
  for _,p in ipairs(b.pieces)do
   local index=(b.row-1)*8+p.tile*2+p.mark-1;local x,y
   p.unused=false
   if not exterior then
    x=10+(index%8)*pitch+(if b.layer==2 then pitch*.5 else 0);y=8+math.floor(index/8)*pitch
   elseif cells[b.layer][index+1]then
    local cell=cells[b.layer][index+1]
    x=cell[1]-motif/2;y=cell[2]-motif/2
   else
    p.unused=true;x,y=-2*motif,-2*motif
   end
   local w=if self.id=="creek"then motif elseif self.id=="canopy"then motif*.56 elseif self.id=="moonpond"then(if b.layer==1 then motif*.74 else motif*.26)else motif*.72
   local h=if self.id=="creek"then motif*.4 elseif self.id=="canopy"then motif*.86 elseif self.id=="moonpond"then w else motif*.85
   p.bounds={x=x,y=y,w=w,h=h}
   assign(self,p.body,"Position",UDim2.fromOffset(x,y),"geometryWrites");assign(self,p.body,"Size",UDim2.fromOffset(w,h),"geometryWrites")
  end
 end
 self.bucket=nil
end
function Backdrop:setCase(rect)
 local prior=self.case
 if prior and prior.x==rect.x and prior.y==rect.y and prior.w==rect.w and prior.h==rect.h then return end
 self.case=rect;self.size=nil
end
function Backdrop:pose(phase)
 for _,b in ipairs(self.bands)do
  local amplitude=if b.layer==1 then 13 else 20
  local direction=if self.id=="lantern"and b.row%2==0 then -1 else 1
  local offset=math.sin(phase*math.pi*2*b.layer+b.row*.56)*amplitude*direction
  local dy=math.sin(phase*math.pi*2+b.row*.7)*(if b.layer==1 then 8 else 12)
  assign(self,b.canvas,"Position",UDim2.fromOffset(offset,dy),"poseWrites")
  -- Every motif in use stays on (QA v760): the handheld covers the ones behind it.
  for _,piece in ipairs(b.pieces)do assign(self,piece.body,"Visible",not piece.unused,"visibilityWrites")end
 end
 self.stats.ticks+=1
end
-- Global-Z sheets need the borrowed surface above its opaque preview face.
-- Cache geometry's authored depths once; no descendants are discovered on ticks.
function Backdrop:setOwner(owner)
 if self.root.Parent~=owner then assign(self,self.root,"Parent",owner,"ownerWrites");self.size=nil;self.resting=false;self:floor()end
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
  root=roundedRoot(host,"PatternThumbnail");root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true
  for i=1,2 do local body=frame(root,"Body"..i);frame(body,"Core");local c=Instance.new("UICorner");c.Parent=body;local inner=Instance.new("UICorner");inner.Parent=body.Core end
 end
 root.BackgroundTransparency=0;root.BackgroundColor3=theme.backdrop
 root.Body1.Visible=true;root.Body2.Visible=true
 if id=="moonpond"then
  -- A crescent and a star, the same two pieces the surface drifts.
  local moon,star=root.Body1,root.Body2
  moon.BackgroundTransparency=.1;moon.BackgroundColor3=theme.face:Lerp(theme.highlight,.9)
  moon.AnchorPoint=Vector2.new(.5,.5);moon.Position=UDim2.fromScale(.36,.48);moon.Size=UDim2.fromScale(.5,.5);moon.SizeConstraint=Enum.SizeConstraint.RelativeYY;moon.Rotation=-28
  moon:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(.5,0)
  moon.Core.Position,moon.Core.Size=UDim2.fromScale(.21,.03),UDim2.fromScale(.78,.78)
  moon.Core.BackgroundTransparency=0;moon.Core.BackgroundColor3=theme.backdrop
  moon.Core:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(.5,0)
  star.BackgroundTransparency=.2;star.BackgroundColor3=theme.highlight
  star.AnchorPoint=Vector2.new(.5,.5);star.Position=UDim2.fromScale(.74,.32);star.Size=UDim2.fromScale(.16,.16);star.SizeConstraint=Enum.SizeConstraint.RelativeYY;star.Rotation=0
  star:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(.5,0)
  star.Core.Position,star.Core.Size=UDim2.fromScale(.25,.25),UDim2.fromScale(.5,.5)
  star.Core.BackgroundTransparency=0;star.Core.BackgroundColor3=theme.highlight:Lerp(Color3.new(1,1,1),.5)
  star.Core:FindFirstChildOfClass("UICorner").CornerRadius=UDim.new(.5,0)
  return root
 end
 for i=1,2 do
  root["Body"..i].AnchorPoint=Vector2.zero;root["Body"..i].SizeConstraint=Enum.SizeConstraint.RelativeXY
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

-- In-board pattern (UI-SPEC-REDESIGN-MENUS 5): the chosen background drawn in
-- the board well in one tone (plate accent 25% toward white) at 6%. One bounded
-- pool of single-piece motifs, built once; geometry is written only when the
-- size or the pattern changes. Static: no animation during a round.
Backdrop.BoardOpacity=.06
Backdrop.BoardCellRatio=.141 -- 23 px on the 163 px phone board
Backdrop.BoardCellMax=40 -- 40 px on desktop
Backdrop.BoardColumns,Backdrop.BoardRows=11,18
local Board={};Board.__index=Board
Backdrop.Board=Board
function Backdrop.boardTone(theme)
 local accent=theme and(theme.accent or theme.trim)or Color3.fromHex("#8FD9B6")
 return accent:Lerp(Color3.new(1,1,1),.25)
end
function Backdrop.boardCell(width)
 return math.clamp(math.floor(width*Backdrop.BoardCellRatio+.5),12,Backdrop.BoardCellMax)
end
function Backdrop.board(parent)
 local root=roundedRoot(parent,"BoardPattern");root.Size=UDim2.fromScale(1,1);root.ClipsDescendants=true;root.Visible=false
 local self=setmetatable({root=root,pieces={},stats={created=1,writes=0,visible=0},period=0},Board)
 -- DECK-FEEL-BRIEF 4: the motifs ride one slide so the pattern can drift (Board:setDrift, Alive deckfeel); at rest
 -- (offset 0) it is the pattern exactly as before. Not counted in the stats (the motifs' budget is unchanged).
 local slide=frame(root,"Slide");slide.Size=UDim2.fromScale(1,1);slide.ZIndex=root.ZIndex;self.slide=slide
 -- The arc fade hides the lower half of a ring so Creek reads as ripples.
 local fade=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(.54,1),NumberSequenceKeypoint.new(1,1)})
 for index=1,Backdrop.BoardColumns*Backdrop.BoardRows do
  local shape=frame(slide,"Motif");shape.Visible=false;shape.ZIndex=root.ZIndex
  local corner=Instance.new("UICorner");corner.Parent=shape
  local stroke=Instance.new("UIStroke");stroke.Enabled=false;stroke.ApplyStrokeMode=Enum.ApplyStrokeMode.Border;stroke.Parent=shape
  local gradient=Instance.new("UIGradient");gradient.Rotation=90;gradient.Transparency=fade;gradient.Enabled=false;gradient.Parent=stroke
  self.pieces[index]={shape=shape,corner=corner,stroke=stroke,gradient=gradient,col=(index-1)%Backdrop.BoardColumns,row=math.floor((index-1)/Backdrop.BoardColumns)}
  self.stats.created+=4
 end
 self.connection=root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:layout()end)
 root.Destroying:Connect(function()self.destroyed=true;if self.connection then self.connection:Disconnect();self.connection=nil end end)
 return self
end
-- Global ZIndex: the motifs share the root's depth so they never rise above the
-- gel spans (the caller picks the depth per renderer backend).
function Board:setZIndex(z)
 if self.destroyed or self.z==z then return end;self.z=z
 assign(self,self.root,"ZIndex",z,"layerWrites")
 if self.slide then self.slide.ZIndex=z end
 for _,p in ipairs(self.pieces)do assign(self,p.shape,"ZIndex",z,"layerWrites")end
end
-- DECK-FEEL-BRIEF 4: the pattern's downward drift, `px` into its two-row period (DeckFeel.patternOffset); nil = rest.
function Board:setDrift(px)
 if self.destroyed or not self.slide then return end
 local y=if px and self.period>0 then math.floor(px%self.period)-self.period else 0
 if self.driftY~=y then
  -- Drifting needs the extra rows below the well (laid out once when it starts or stops).
  local relayout=(self.driftY==nil or self.driftY==0)~=(y==0)
  self.driftY=y;self.slide.Position=UDim2.fromOffset(0,y)
  if relayout then self.size=nil;self:layout()end
 end
end
function Board:periodPx()return self.period end
function Board:cellPx()return self.stats.cell or 0 end
function Board:configure(id,theme)
 if self.destroyed then return false end
 local tone=Backdrop.boardTone(theme)
 if self.id==id and self.tone==tone then return false end
 self.id,self.tone=id,tone;self.size=nil
 local fill=1-Backdrop.BoardOpacity
 for _,p in ipairs(self.pieces)do
  -- Creek: ripple arcs. Moonpond: every other cell is a moon, drawn the same way (a ring
  -- whose far side fades out leaves a crescent); the cells between are star dots.
  local moon=id=="moonpond"and Board.isMoon(p.col,p.row)
  local creek=id=="creek"or moon
  assign(self,p.gradient,"Rotation",if moon then 0 else 90,"styleWrites")
  assign(self,p.shape,"BackgroundColor3",tone,"colorWrites");assign(self,p.stroke,"Color",tone,"colorWrites")
  assign(self,p.shape,"BackgroundTransparency",if creek then 1 else fill,"styleWrites")
  assign(self,p.stroke,"Enabled",creek,"styleWrites");assign(self,p.gradient,"Enabled",creek,"styleWrites")
  assign(self,p.stroke,"Transparency",fill,"styleWrites")
  assign(self,p.corner,"CornerRadius",if id=="lantern"then UDim.new(.38,0)else UDim.new(.5,0),"styleWrites")
  assign(self,p.shape,"Rotation",if id=="canopy"then 30 else 0,"geometryWrites")
 end
 self:layout();return true
end
-- Canopy: paired seeds; Creek: staggered ripple arcs; Lantern: small lanterns;
-- Moonpond: crescents and star dots on alternate cells.
function Board.isMoon(col,row)return(col+row)%2==0 end
function Board.place(id,col,row,cell)
 local stagger=if row%2==1 then cell*.5 else 0
 if id=="moonpond"then
  if Board.isMoon(col,row)then return col*cell+cell*.26,row*cell+cell*.24,cell*.48,cell*.48 end
  return col*cell+cell*.42,row*cell+cell*.42,cell*.16,cell*.16
 elseif id=="creek"then
  return col*cell+stagger+cell*.18,row*cell*.85+cell*.2,cell*.64,cell*.64
 elseif id=="lantern"then
  return col*cell+stagger+cell*.36,row*cell+cell*.3,cell*.28,cell*.38
 end
 -- Seeds pair across two columns: a tight pair, then a wider gap.
 local x=col*cell+(if col%2==0 then cell*.55 else cell*.08)-(if row%2==1 then cell else 0)
 return x,row*cell+cell*.27,cell*.2,cell*.46
end
function Board:layout()
 if self.destroyed or not self.id then return end
 local size=self.root.AbsoluteSize
 if self.size==size then return end;self.size=size
 local cell=Backdrop.boardCell(size.X);self.stats.cell=cell
 -- Two rows repeat the pattern (seeds, lanterns and moons alternate by row; creek rows are .85 of a cell apart).
 self.period=math.floor((if self.id=="creek"then cell*.85 else cell)*2+.5)
 local thickness=math.max(1,math.floor(cell*.06+.5))
 local shown=0
 for _,p in ipairs(self.pieces)do
  local x,y,w,h=Board.place(self.id,p.col,p.row,cell)
  local visible=size.X>0 and x<size.X and y<size.Y+(if self.driftY and self.driftY~=0 then self.period else 0)and x+w>0
  if visible then
   assign(self,p.shape,"Position",UDim2.fromOffset(math.floor(x+.5),math.floor(y+.5)),"geometryWrites")
   assign(self,p.shape,"Size",UDim2.fromOffset(math.floor(w+.5),math.floor(h+.5)),"geometryWrites")
   assign(self,p.stroke,"Thickness",if self.id=="moonpond"then math.max(2,math.floor(cell*.11+.5))else thickness,"styleWrites");shown+=1
  end
  assign(self,p.shape,"Visible",visible,"visibilityWrites")
 end
 self.stats.visible=shown
end
function Board:setVisible(visible)
 if self.destroyed then return end
 assign(self,self.root,"Visible",visible==true and self.id~=nil,"visibilityWrites")
end
function Board:destroy()if self.destroyed then return end;self.destroyed=true;if self.connection then self.connection:Disconnect();self.connection=nil end;self.root:Destroy()end
return Backdrop
