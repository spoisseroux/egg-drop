-- One committed result, persistent scene/pool, and one visible-owner clock.
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local Input=game:GetService("UserInputService")
local TextService=game:GetService("TextService")
local Art=require(script.Parent.DeckArt)
local Portrait=require(script.Parent.PetPortrait)
local Bounds=require(script.Parent.PetRigBounds)
local Shot=require(script.Parent.PetGreetingShot)
local IdleMotion=require(script.Parent.PetIdleMotion)
local Factory=require(script.Parent.PetFactory)
local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
local Cinematic={};Cinematic.__index=Cinematic;Cinematic.BitLimit=24
local live=setmetatable({},{__mode="k"})
local function frame(parent,name,color,z)
 local node=Art.frame(parent,name,color,UDim2.fromOffset(0,0),UDim2.fromOffset(1,1),z);node.Active,node.Selectable=false,false;return node
end
local function circle(parent,name,color,z)local node=frame(parent,name,color,z);node.AnchorPoint=Vector2.new(.5,.5);Art.corner(node,1000);return node end
local function place(node,x,y,w,h)node.Position=UDim2.fromOffset(x,y);node.Size=UDim2.fromOffset(math.max(1,w),math.max(1,h))end
local function label(parent,name,value,role,color)
 local node=Art.text(parent,name,value,UDim2.fromOffset(0,0),UDim2.fromOffset(1,1),color,14);Art.type(node,role,true);node.TextXAlignment=Enum.TextXAlignment.Center;return node
end
local function rest(visual,pet)visual.greeting=if(pet.family or pet.id)=="pip"or pet.id=="puddle"then 2 else 0;visual:update(0)end
local function include(visual,points)
 for _,entry in ipairs(visual.pieces)do local p=entry.part
  if entry.role~="ripple"and entry.faceRole~="spark"and p.Transparency<.99 then
   local cf,size=p.CFrame,p.Size
   if visual.definition then
    local pad=IdleMotion.padding(visual,entry)
    local r,u,l=cf.RightVector,cf.UpVector,cf.LookVector
    size=Vector3.new(math.abs(r.X)*size.X+math.abs(u.X)*size.Y+math.abs(l.X)*size.Z,
     math.abs(r.Y)*size.X+math.abs(u.Y)*size.Y+math.abs(l.Y)*size.Z,
     math.abs(r.Z)*size.X+math.abs(u.Z)*size.Y+math.abs(l.Z)*size.Z)+pad*2
    cf=CFrame.new(cf.Position)
   end
   Bounds.include(visual,cf,size)
   if points then for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do table.insert(points,cf:PointToWorldSpace(size*Vector3.new(x,y,z)*.5))end end end end
  end
 end
end
function Cinematic.new(parent,audio,reduceEffects,owns)
 local root=Art.frame(parent,"HatchCinematic","inset",UDim2.fromScale(0,0),UDim2.fromScale(1,1),42)
 root.Visible=false;root.ClipsDescendants=true;root.Active=false;Art.corner(root,14)
 local pool=frame(root,"HatchParticlePool","inset",47);pool.BackgroundTransparency=1;pool.Size=UDim2.fromScale(1,1)
 local self=setmetatable({frame=root,poolRoot=pool,bits={},audio=audio,reduceEffects=reduceEffects,owns=owns,epoch=0,age=0,active=false,connections={},ancestorConnections={},windowActive=true,writes=0},Cinematic)
 live[self]=true
 for i=1,24 do local bit=circle(pool,"HatchBit"..i,"accent",47);bit.Visible=false;self.bits[i]=bit end
 local function watch(signal,callback)table.insert(self.connections,signal:Connect(callback))end
 watch(root:GetPropertyChangedSignal("AbsoluteSize"),function()if self.result and not self.building then self:layout();self:refreshOwner()end end)
 watch(root.AncestryChanged,function()self:watchAncestors();self:refreshOwner()end)
 watch(GuiService:GetPropertyChangedSignal("MenuIsOpen"),function()self:refreshOwner()end)
 watch(GuiService:GetPropertyChangedSignal("ReducedMotionEnabled"),function()self:refreshOwner()end)
 watch(Input.WindowFocusReleased,function()self.windowActive=false;self:refreshOwner()end)
 watch(Input.WindowFocused,function()self.windowActive=true;self:refreshOwner()end)
 watch(Input.TextBoxFocused,function()self:refreshOwner()end);watch(Input.TextBoxFocusReleased,function()self:refreshOwner()end)
 watch(root.Destroying,function()self:destroy(true)end);self:watchAncestors();return self
end
function Cinematic:reduced()return if type(self.reduceEffects)=="function"then self.reduceEffects()==true else self.reduceEffects==true end
function Cinematic:visible()
 local node=self.frame
 while node do
  if node:IsA("GuiObject")and not node.Visible then return false end
  if node:IsA("ScreenGui")and not node.Enabled then return false end
  node=node.Parent
 end
 return self.frame.Parent~=nil
end
function Cinematic:owned()
 return not self.destroyed and self:visible()and self.windowActive and not GuiService.MenuIsOpen and Input:GetFocusedTextBox()==nil and(not self.owns or self.owns())and(not self.audio or self.audio.deviceActive~=false)
end
function Cinematic:watchAncestors()
 for _,c in ipairs(self.ancestorConnections)do c:Disconnect()end;table.clear(self.ancestorConnections)
 local node=self.frame
 while node do
  if node:IsA("GuiObject")or node:IsA("ScreenGui")then
   table.insert(self.ancestorConnections,node:GetPropertyChangedSignal(if node:IsA("ScreenGui")then "Enabled"else "Visible"):Connect(function()self:refreshOwner()end))
  end
  node=node.Parent
 end
end
function Cinematic:disconnectClock()if self.connection then self.connection:Disconnect();self.connection=nil end end
function Cinematic:cue(name,pitch,volume)if self.audio and self:owned()and not self:reduced()then self.audio:play(name,pitch,volume,self.audioOwner)end end
function Cinematic:stopAudio()if self.audio and self.audio.stopOwner and self.audioOwner then self.audio:stopOwner(self.audioOwner)end end
function Cinematic:clearHero()
 if self.heroVisual then self.heroVisual:destroy();self.heroVisual=nil end
 if self.heroViewport then self.heroViewport:Destroy();self.heroViewport=nil end
 self.heroCamera,self.heroPoints,self.envelopeFrame,self.envelopeSize,self.sweptPoints,self.outlineCenter=nil,nil,nil,nil,nil,nil
end
function Cinematic:cancel()
 self.epoch+=1;self:disconnectClock();self:stopAudio();self.active=false;self.onComplete=nil;self.onPresented=nil;self.presented=false
 self:clearHero();if self.stage then self.stage:Destroy();self.stage=nil end;if self.resultRoot then self.resultRoot:Destroy();self.resultRoot=nil end
 self.result=nil;self.liveBits=0;self.frame.Visible=false;for _,bit in ipairs(self.bits)do bit.Visible=false end
 self.quietPainted=nil
end
function Cinematic:destroy(fromSignal)
 if self.destroyed then return end;self:cancel();self.destroyed=true;live[self]=nil
 for _,c in ipairs(self.connections)do c:Disconnect()end;for _,c in ipairs(self.ancestorConnections)do c:Disconnect()end
 table.clear(self.connections);table.clear(self.ancestorConnections);if not fromSignal then self.frame:Destroy()end
end
function Cinematic:complete()local callback=self.onComplete;self.onComplete=nil;if callback then callback()end end
function Cinematic:createHero()
 local preparationStarted=os.clock()
 local viewport=Instance.new("ViewportFrame");viewport.Name="PetHero3D";viewport.Size=UDim2.fromScale(1,1);viewport.BackgroundTransparency=1;viewport.BorderSizePixel=0;viewport.ZIndex=50
 viewport.Ambient=Color3.fromRGB(190,204,178);viewport.LightColor=Color3.fromRGB(255,240,212);viewport.LightDirection=Vector3.new(-1,-1.4,-3);viewport.Parent=self.heroHost;self.heroViewport=viewport
 local ok=pcall(function()
  if self.forceFallback then error("isolated pixel fallback fixture")end
  local world=Instance.new("WorldModel");world.Name="PetStage";world.Parent=viewport
  local visual=Factory.new(world,Vector3.zero,self.pet,nil,self.appearance);self.heroVisual=visual
  local idleFrozen=visual.idleMotionFrozen;visual.idleMotionFrozen=true;rest(visual,self.pet)
  Bounds.begin(visual);include(visual);Bounds.finish(visual);self.neutralFrame,self.neutralSize=Bounds.get(visual)
  self.heroPoints=Shot.captureSilhouette(visual,self.neutralFrame)
  -- Bounded authored animation sample, once per result. Relayout reuses it.
  local time,greeting=visual.time,visual.greeting;self.sweptPoints={};Bounds.begin(visual);include(visual,self.sweptPoints);visual:greet()
  for _=1,48 do visual:update(1/30);include(visual,self.sweptPoints)end
  Bounds.finish(visual);self.envelopeFrame,self.envelopeSize=Bounds.get(visual);self.envelopeSize+=Vector3.one*.10
  visual.time,visual.greeting,visual.idleMotionFrozen=time,greeting,idleFrozen;visual:update(0);visual.rigBoundsFrame,visual.rigBoundsSize=self.neutralFrame,self.neutralSize
  local camera=Instance.new("Camera");camera.Name="HeroCamera";camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera;self.heroCamera=camera;self.renderMode="3D"
 end)
 if not ok then self:clearHero();self.renderMode="PixelFallback";self.portrait=Portrait.create(self.heroHost,self.pet,1,UDim2.fromScale(.5,.5),50,false,self.appearance)end
 self.heroHost:SetAttribute("RenderMode",self.renderMode)
 self.heroPreparationMs=(os.clock()-preparationStarted)*1000
end
function Cinematic:fitHero(width,height,stageHeight)
 if not self.heroCamera then
  if self.portrait then local unit=math.max(.1,math.min(width/13,stageHeight*.59/11,height/13));local scale=self.portrait:FindFirstChild("HatchPortraitScale")or Instance.new("UIScale");scale.Name="HatchPortraitScale";scale.Scale=unit;scale.Parent=self.portrait end
  return
 end
 local aspect=width/math.max(1,height);local tangent=math.tan(math.rad(30)*.5)
 local hx,vy=tangent*aspect*.94,tangent*.94
 local right,left,top,bottom,near=-math.huge,-math.huge,-math.huge,-math.huge,-math.huge
 -- Fixed front camera: exact support distance in one pass over the cached sweep.
 for _,p in ipairs(self.sweptPoints)do
  right,left=math.max(right,p.Z+p.X/hx),math.max(left,p.Z-p.X/hx)
  top,bottom=math.max(top,p.Z+p.Y/vy),math.max(bottom,p.Z-p.Y/vy)
  near=math.max(near,p.Z+.55)
 end
 local target=Vector3.new((right-left)*hx*.5,(top-bottom)*vy*.5,0)
 local horizontal,vertical=(right+left)*.5,(top+bottom)*.5
 local safe=math.max(horizontal,vertical,near)+.04
 local wanted=math.min(.90,.59*stageHeight/math.max(1,height))
 local function candidate(distance)return CFrame.lookAt(target+Vector3.new(0,0,distance),target)end
 local function occupancy(distance)return Shot.projectedPointsHeight(candidate(distance),self.heroPoints,self.neutralFrame,30)end
 local low,high=safe,math.max(safe,3)
 for _=1,12 do if occupancy(high)<=wanted then break end;high*=1.3 end
 for _=1,22 do local mid=(low+high)*.5;if occupancy(mid)<=wanted then high=mid else low=mid end end
 self.heroCamera.CFrame=candidate(high)
 local transform=self.heroCamera.CFrame:ToObjectSpace(self.neutralFrame)
 local minX,maxX,minY,maxY=math.huge,-math.huge,math.huge,-math.huge
 local pixelScale=height/(2*tangent)
 for _,point in ipairs(self.heroPoints)do
  local p=transform:PointToWorldSpace(point);local x,y=p.X/-p.Z*pixelScale,-p.Y/-p.Z*pixelScale
  minX,maxX,minY,maxY=math.min(minX,x),math.max(maxX,x),math.min(minY,y),math.max(maxY,y)
 end
 self.outlineCenter=self.center+Vector2.new((minX+maxX)*.5,(minY+maxY)*.5)
 self.outlineHalfWidth,self.outlineHalfHeight=(maxX-minX)*.5,(maxY-minY)*.5
 self.heroFraction=occupancy(high)*height/math.max(1,stageHeight)
 self.fitLimited=self.heroFraction<wanted*height/math.max(1,stageHeight)-.015
 self.fitReason=if not self.fitLimited then "target"elseif horizontal>vertical and horizontal>near then "swept width"elseif height<stageHeight*.65 then "text reserve"else "full greeting"

end
function Cinematic:minimumHeightForWidth(width,height)
 if not self.caption then return 160 end
 -- Candidate geometry owns its font contract. Never read the last painted sizes:
 -- a narrow stacked stage may otherwise change the next full-width decision.
 height=height or 180
 local landscape=width>=360 and width/math.max(1,height)>=2
 local roomy=(height>=300 and width>=360)or landscape
 local wrap=math.max(1,if landscape then width-math.floor(width*.56)-24 else width-24)
 local function measured(value,size,font,minimum)
  return math.max(minimum or 0,math.ceil(TextService:GetTextSize(value,size,font,Vector2.new(wrap,10000)).Y)+4)
 end
 local name=measured(self.pet.name,if roomy then 26 else 20,Art.Font.Heading,24)
 local tag=measured(self.tag.Text,if roomy then 16 else 12,Art.Font.Supporting,18)
 local caption=measured(self.caption.Text,if roomy then 16 else 12,Art.Font.Supporting,18)
 return math.max(160,math.ceil(name+tag+caption+(if landscape then 64 else 40)))
end

function Cinematic:layout()
 if not self.resultRoot then return end
 local w,h=math.max(1,self.frame.AbsoluteSize.X),math.max(1,self.frame.AbsoluteSize.Y);self.layoutWidth,self.layoutHeight=w,h
 self.landscapeLayout=w>=360 and w/h>=2
 local roomy=(h>=300 and w>=360)or self.landscapeLayout
 Art.roomyType(self.caption,"Supporting",not roomy,roomy);Art.roomyType(self.heading,"Heading",not roomy,roomy);Art.roomyType(self.tag,"Supporting",not roomy,roomy)
 if roomy then self.heading.TextSize=26 end
 local short=h<140
 self.heading.Text=if short then (if self.result.rare then "Rare · "else "")..(if self.result.duplicate then "Duplicate · "else "")..self.pet.name else self.pet.name
 local heroX,heroY,heroW,heroH,textX,textW=12,0,w-24,1,12,w-24
 if self.landscapeLayout then heroW=math.max(1,math.floor(w*.56)-18);textX=heroW+30;textW=math.max(1,w-textX-12)end
 local captionH=Art.textHeight(self.caption,textW,18);local nameH=Art.textHeight(self.heading,textW,24);local tagH=if not short then Art.textHeight(self.tag,textW,18)else 0
 self.tag.Visible=tagH>0
 local tagY=if self.landscapeLayout then 44 else 4
 place(self.tag,textX,tagY,textW,math.max(1,tagH))
 local nameY=if self.landscapeLayout then tagY+tagH+6 else math.max(tagH+8,h-captionH-nameH-12)
 place(self.heading,textX,nameY,textW,nameH);place(self.caption,textX,nameY+nameH+4,textW,captionH)
 if self.landscapeLayout then heroY,heroH=8,math.max(1,h-16)else heroY=tagH+10;heroH=math.max(1,nameY-heroY-8)end
 self.minimumHeight=self:minimumHeightForWidth(w,h)
 self.center,self.bandTop,self.bandHeight=Vector2.new(heroX+heroW*.5,heroY+heroH*.5),heroY,heroH
 place(self.heroHost,heroX,heroY,heroW,heroH);self:fitHero(heroW,heroH,h);self.heroPixels=math.min(h*.55,heroH*.85)
 local r,c=self.heroPixels,self.center
 self.shell.Size=UDim2.fromOffset(r*.60,r*.80);self.shell.Position=UDim2.fromOffset(c.X,c.Y)
 self.cradle.Position=UDim2.fromOffset(c.X,c.Y+math.min(heroH*.40,r*.36));self.cradle.Size=UDim2.fromOffset(math.min(heroW,r*1.15),math.max(4,r*.11))
 self.halo.Position=UDim2.fromOffset(c.X,c.Y);self.halo.Size=UDim2.fromOffset(math.min(heroW,r*1.40),math.min(heroH,r*1.10))
 if self.anticipation then place(self.anticipation,textX,math.max(0,h-40),textW,30)end
 self:paint()
end

function Cinematic:buildScene()
 self.pet=Pets.byId[self.result.petId]or Pets[1]
 self.stage=Art.frame(self.frame,"HatchStage","inset",UDim2.fromScale(0,0),UDim2.fromScale(1,1),43)
 self.halo=circle(self.stage,"DiscoveryHalo",if self.result.rare then Art.Amber else "accent",44);self.halo.BackgroundTransparency=.92;self.haloStroke=Art.stroke(self.halo,if self.result.rare then Art.Amber else self.pet.color,.82,1)
 Art.bind(self.halo,{BackgroundColor3=function()return self.pet.color:Lerp(Art.paletteColor("accent"),.18)end})
 self.cradle=circle(self.stage,"CradleRing","raised",45);self.cradle.BackgroundTransparency=.65;Art.stroke(self.cradle,"line",.78,1)
 self.shell=circle(self.stage,"Shell",self.pet.color:Lerp(Art.Silver,.72),46);Art.shade(self.shell,1,.78);Art.stroke(self.shell,"accent",.2,2);self.shellScale=Instance.new("UIScale");self.shellScale.Parent=self.shell
 self.crack=label(self.shell,"Crack","╱╲","Heading","accent");self.crack.AnchorPoint=Vector2.new(.5,.5);self.crack.Position=UDim2.fromScale(.5,.5);self.crack.Size=UDim2.fromScale(.7,.7)
 self.resultRoot=Art.frame(self.frame,"Result","inset",UDim2.fromScale(0,0),UDim2.fromScale(1,1),49);self.resultRoot.BackgroundTransparency=1
 self.heroHost=frame(self.resultRoot,"Hero","inset",49);self.heroHost.BackgroundTransparency=1;self.heroScale=Instance.new("UIScale");self.heroScale.Parent=self.heroHost
 local rare=self.result.rare==true
 local tag=if self.result.duplicate then(if rare then "RARE FAMILY DUPLICATE"else "FAMILY DUPLICATE")elseif rare then "RARE DISCOVERY"else "A NEW LITTLE WONDER"
 self.tag=label(self.resultRoot,"Rarity",tag,"Supporting",if rare then Art.Amber else "accent");self.heading=label(self.resultRoot,"PetName",self.pet.name,"Heading","text")
 local family=(self.result.family or self.pet.family or self.pet.id):gsub("^%l",string.upper)
 local detail=if self.result.duplicate then string.format("%s family  +1 mark  ·  %d total",family,self.result.mastery or 0)elseif self.result.starter and self.result.starterGoal then self.result.starterGoal else "A new friend for Sprout Hollow"
 if self.result.duplicate and(self.result.promotedTo or 0)>0 then detail="+1 mark · "..family.." rank "..({"I","II","III"})[self.result.promotedTo].." unlocked!"elseif self.result.duplicate and self.result.masteryHint then detail=self.result.masteryHint end
 self.caption=label(self.resultRoot,"Mastery",detail,"Supporting","muted");self:createHero();self:layout()
 self.anticipation=label(self.stage,"Anticipation","Something is stirring…","Body","muted")
 place(self.anticipation,12,math.max(0,self.layoutHeight-40),self.layoutWidth-24,30)
 self.beats={{.45,"charge",.92,.25},{.88,"merge_bubble",.92,.25},{if rare then 1.72 else 1.22,"hatch",if rare then .92 else 1.02,.65},{(if rare then 1.72 else 1.22)+.28,self.pet.cue,1,.5}}
 if rare then table.insert(self.beats,{1.28,"charge",1.18,.26})end
 for i,node in ipairs(self.bits)do
  local index=i
  Art.bind(node,{BackgroundColor3=function()
   if index>=13 and index<=16 then return Color3.fromHex("#FFF0CD"):Lerp(self.pet.color,.10)end
   if index>=17 and index<=20 then
    if index%2==1 then return Art.Amber end
    return if(self.pet.family or self.pet.id)=="orbit"then self.pet.color else self.pet.accent or self.pet.color
   end
   return if self.result and self.result.rare and(index%3==0 or(index>=17 and index<=20))then Art.Amber elseif index%2==0 then self.pet.color else Art.paletteColor("accent")
  end})
 end
end
function Cinematic:paint()
 if not self.stage then return end
 local rare=self.result.rare==true;local split=if rare then 1.72 else 1.22;local revealed=not self.active or self.age>=split
 self.resultRoot.Visible=revealed;self.shell.Visible=not revealed;self.crack.Visible=self.age>=.60 and not revealed
 if self.anticipation then
  self.anticipation.Visible=not revealed
  local value=if rare and self.age>1.15 then "A rare glow…"elseif self.age>.6 then "A little more…"else "Something is stirring…"
  if self.anticipation.Text~=value then self.anticipation.Text=value end
 end
 self.shell.Rotation=if self.active then math.sin(self.age*22)*math.min(8,self.age*7)else 0
 self.shellScale.Scale=if self.active then .88+math.min(1,self.age/.45)*.12+math.sin(self.age*12)*.025 else 1
 self.heroScale.Scale=if self.active and revealed then 1+math.sin(math.min(1,(self.age-split)/.48)*math.pi)*.07 else 1
 local quiet=self:reduced()or not self:owned();self.halo.Rotation=if rare and not quiet then self.age*8 else 0
 self.haloStroke.Transparency=if not revealed then .72-math.max(0,math.sin(self.age*12))*.45 elseif rare then .70 else .84
 self:paintBits(revealed,quiet)
end
-- Every role has an authored trajectory; all reuse the same24 passive slots.
function Cinematic:burstBit(index,age,rare)
 local r=self.heroPixels;local theta,x,y,w,h,rotation
 local plate=index>=13 and index<=16
 local ray=rare and index>=17 and index<=20
 local delay=if ray or index>=21 then .13 else 0
 if age<delay then return 0,0,1,1,0,1,false end
 local t=math.clamp((age-delay)/(.75-delay),0,1);local eased=1-(1-t)^3
 local alpha=if t<.67 then .10 else .10+.90*(t-.67)/.33
 local center=self.outlineCenter or self.center
 if plate then
  local slot=index-13;local side=if slot%2==0 then -1 else 1;local vertical=if slot<2 then -1 else 1
  x=self.center.X+side*r*(.29+.56*eased)
  y=self.center.Y+vertical*r*(.12+.40*eased)-math.sin(t*math.pi)*r*.18
  w,h=if slot<2 then r*.18 else r*.23,if slot<2 then r*.25 else r*.12
  rotation=side*(12+eased*112)+vertical*8
 elseif ray then
  theta=math.rad(35+(index-17)*90)
  local rx=(self.outlineHalfWidth or r*.4)*1.20;local ry=(self.outlineHalfHeight or r*.5)*1.12
  local radial=.88+.34*eased
  x,y=center.X+math.cos(theta)*rx*radial,center.Y+math.sin(theta)*ry*radial
  w,h=4,r*(.15+.17*eased);rotation=math.deg(theta)-90
 else
  theta=if index<=12 then index/12*math.pi*2 else math.rad(45+(index-21)*90)
  local rx=math.min(self.heroHost.Size.X.Offset*.44,r*.86);local ry=math.min(self.bandHeight*.43,r*.62)
  x,y=center.X+math.cos(theta)*rx*eased,center.Y+math.sin(theta)*ry*eased
  w,h=if index%3==0 then 5 else 3,if index%3==0 then 9 else 5;rotation=math.deg(theta)+eased*60
 end
 return x,y,w,h,rotation,alpha,true
end
function Cinematic:paintBits(revealed,quiet)
 local rare=self.result.rare==true;local split=if rare then 1.72 else 1.22
 local count=if rare then 8 else 6;local burstAge=self.age-split;local burst=burstAge>=0 and burstAge<.75 and self.active
 self.liveBits=0
 for i,node in ipairs(self.bits)do
  local show=not quiet and self.bandHeight>=20 and((burst and i<=(if rare then 24 else 16))or(revealed and i<=count)or(not revealed and i<=4))
  local x,y,w,h,rotation,alpha
  if show and burst then x,y,w,h,rotation,alpha,show=self:burstBit(i,burstAge,rare)
  elseif show then
   local theta=i*math.pi*2/count+self.age*.62+(i%3)*.18
   local rx=math.min(self.heroHost.Size.X.Offset*.42,self.heroPixels*.75);local ry=math.min(self.bandHeight*.40,self.heroPixels*.52)
   if not revealed then local pull=1-math.clamp(self.age/.45,0,1)*.35;rx*=pull;ry*=pull end
   x,y=self.center.X+math.cos(theta)*rx,self.center.Y+math.sin(theta)*ry
   w,h=if i%3==0 then 5 else 3,if i%3==0 then 9 else 5
   rotation,alpha=math.deg(theta)+self.age*12,.26+(math.sin(self.age*1.8+i)+1)*.16
  end
  node.Visible=show
  if show then
   self.liveBits+=1
   local angle=math.rad(rotation);local ex=(math.abs(math.cos(angle))*w+math.abs(math.sin(angle))*h)*.5
   local ey=(math.abs(math.sin(angle))*w+math.abs(math.cos(angle))*h)*.5
   local left,right=self.heroHost.Position.X.Offset+ex+2,self.heroHost.Position.X.Offset+self.heroHost.Size.X.Offset-ex-2
   local top,bottom=self.bandTop+ey+2,self.bandTop+self.bandHeight-ey-2
   x,y=math.clamp(x,left,math.max(left,right)),math.clamp(y,top,math.max(top,bottom))
   node.Position=UDim2.fromOffset(x,y);node.Size=UDim2.fromOffset(w,h);node.Rotation=rotation;node.BackgroundTransparency=alpha;self.writes+=4
  end
 end
end

function Cinematic:finishStatic()
 if not self.resultRoot then return end
 self.active=false;self.age=math.max(self.age,self.duration or 0);self:stopAudio()
 if self.heroVisual then self.heroVisual.reducedEffects=self:reduced();rest(self.heroVisual,self.pet)end
 self:paint();self.quietPainted=not self:owned()or self:reduced();self:complete()
end
function Cinematic:refreshOwner()
 if self.destroyed or not self.result or self.building then return end
 if not self:owned()then
  self:disconnectClock();self:stopAudio();if self.presented and self.active then self:finishStatic()elseif self.resultRoot and not self.quietPainted then self:paint();self.quietPainted=true end;return
 end
 local epoch=self.epoch
 if not self.presented then
  self.presented=true;local callback=self.onPresented;self.onPresented=nil;if callback then callback()end
  if self.epoch~=epoch or not self.result then return end
  if self.active and not self:reduced()then self:cue("hatch_rise",if self.result.rare then .82 else .94,.48)end
 end
 if self:reduced()then self:disconnectClock();if self.active or not self.quietPainted then self:finishStatic()end;return end
 self.quietPainted=nil
 if not self.active then self:complete();if self.epoch~=epoch or not self.result then return end end
 if not self.connection then self.deviceEpoch=if self.audio then self.audio.deviceEpoch or 0 else 0;self.connection=RunService.RenderStepped:Connect(function(dt)if self.epoch==epoch then self:step(dt)end end)end
end
function Cinematic:step(dt)
 if not self.result or not self:owned()or self:reduced()then self:refreshOwner();return end
 if dt>.25 or(self.audio and self.deviceEpoch~=(self.audio.deviceEpoch or 0))then self.deviceEpoch=if self.audio then self.audio.deviceEpoch or 0 else 0;self:finishStatic();return end
 local before=self.age;self.age+=math.max(0,dt);local epoch=self.epoch
 if self.active then
  local rare=self.result.rare==true;local split=if rare then 1.72 else 1.22
  for _,beat in ipairs(self.beats)do
   if before<beat[1]and self.age>=beat[1]then self:cue(beat[2],beat[3],beat[4]);if self.epoch~=epoch then return end;if beat[1]==split and self.heroVisual then self.heroVisual:greet()end end
  end
  if self.age>=self.duration then self:finishStatic();if self.epoch~=epoch then return end end
 end
 self.sampleAge=(self.sampleAge or 0)+dt
 if self.sampleAge>=1/30 then local elapsed=self.sampleAge;self.sampleAge=0
  if self.heroVisual and(not self.active or self.resultRoot.Visible)then self.heroVisual.reducedEffects=false;self.heroVisual:update(elapsed)end
  self:paint()
 end
end
function Cinematic:play(result,onComplete,options)
 if self.destroyed then return end
 self:cancel();options=options or {};self.appearance=options.appearance;self.building=true;self.result=result;self.pet=Pets.byId[result.petId]or Pets[1]
 self.duration=if result.rare then 3.1 else 2.5;self.age=0;self.sampleAge=0;self.onComplete=onComplete;self.onPresented=options.onPresented;self.audioOwner={}
 self.active=not options.skipIntro and not self:reduced();self.startedAt=os.clock();self.frame.Visible=true;self:buildScene();self.building=false
 if not self.active then self.age=self.duration;self:paint()end
 local epoch=self.epoch;self:refreshOwner();if self.epoch==epoch and not self.active then self:complete()end
end
function Cinematic:setAppearance(appearance)
 self.appearance=appearance
 if self.heroVisual and self.heroVisual.applyAppearance then self.heroVisual:applyAppearance(appearance)end
 if self.portrait then Portrait.apply(self.portrait,appearance)end
end
function Cinematic:getStats()
 local hidden;local node=self.frame
 while node do
  if node:IsA("GuiObject")and not node.Visible or node:IsA("ScreenGui")and not node.Enabled then hidden=node:GetFullName();break end
  node=node.Parent
 end
 local ownsCallback=not self.owns or self.owns()
 local ownerState=if self.ownerState then self.ownerState()else nil
 return{allocatedBits=#self.bits,liveBits=self.liveBits or 0,clock=self.connection~=nil,active=self.active,age=self.age,epoch=self.epoch,renderMode=self.renderMode,heroFraction=self.heroFraction,fitLimited=self.fitLimited,fitReason=self.fitReason,sweptPoints=if self.sweptPoints then #self.sweptPoints else 0,writes=self.writes,heroPreparationMs=self.heroPreparationMs,
  resultId=self.result and self.result.id,building=self.building==true,presented=self.presented==true,owned=self:owned(),hiddenAncestor=hidden,windowActive=self.windowActive,coreMenu=GuiService.MenuIsOpen,textCapture=Input:GetFocusedTextBox()~=nil,ownsCallback=ownsCallback,audioDeviceActive=not self.audio or self.audio.deviceActive~=false,deviceEpoch=self.audio and self.audio.deviceEpoch,completionPending=self.onComplete~=nil,ownerState=ownerState}
end
-- Read-only QA getter: does not change visibility, ownership, time or receipts.
function Cinematic.inspect()
 local values={};for cinematic in pairs(live)do table.insert(values,cinematic:getStats())end;return values
end
return Cinematic
