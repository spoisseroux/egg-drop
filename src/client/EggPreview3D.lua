-- 3D egg preview for the Hatch eggs pane (UI-SPEC-REDESIGN-MENUS 3, assets/eggs/EGG-PREVIEW-FX.md).
-- One ViewportFrame with the shell/core meshes from Shared.EggModels; every glow, sparkle and
-- flash is a 2D frame over or under it. One RenderStepped loop, paused while inactive; no
-- Instances are created per frame. Mesh templates load once per session through
-- AssetService:CreateMeshPartAsync (MeshId is not scriptable) and are cloned per preview.
-- Until they load, or when loading fails, `loaded` stays false and the caller keeps its 2D egg.
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local Models=require(game:GetService("ReplicatedStorage").Shared.EggModels)
local Kit=require(script.Parent.DeckKit)
local Preview={};Preview.__index=Preview
local Parts={"BottomShell","TopShell","Core"}

-- Replaceable for specs (stub a failure, or return plain MeshParts).
function Preview.createMesh(uri)
 return game:GetService("AssetService"):CreateMeshPartAsync(Content.fromUri(uri))
end
local templates,loadState,waiters,generation={},"idle",{},0
function Preview.resetCache()templates={};loadState="idle";waiters={};generation+=1 end
function Preview.loadState()return loadState end
-- Loads the three templates once; `done(ok)` runs (deferred) when they are ready or failed.
function Preview.loadTemplates(done)
 if loadState=="ready"or loadState=="failed"then local ok=loadState=="ready";task.defer(done,ok);return end
 table.insert(waiters,done)
 if loadState=="loading"then return end
 loadState="loading"
 local gen=generation;local found={}
 task.spawn(function()
  local ok=true
  for _,key in ipairs(Parts)do
   local success,part=pcall(Preview.createMesh,Models.Egg[key].mesh)
   if gen~=generation then return end -- a reset (specs) superseded this load
   if success and typeof(part)=="Instance"and part:IsA("MeshPart")then found[key]=part
   else ok=false;warn("Egg preview mesh failed ("..key.."): "..tostring(part));break end
  end
  if ok then for key,part in pairs(found)do templates[key]=part end end
  loadState=if ok then "ready"else "failed"
  local list=waiters;waiters={}
  for _,fn in ipairs(list)do task.spawn(fn,ok)end
 end)
end

-- Pure: the "something inside" beat, t seconds into a 0.35 s beat (FX doc 2). Tilt to `amp`
-- degrees on `side` (0.10 s), counter-tilt to -4 (0.08 s), settle (0.17 s); squash to 0.96
-- for 0.08 s; hop `hopH` studs over the last 0.20 s. Returns tilt (deg), squashY, hop (studs).
Preview.BeatLength=.35
function Preview.beat(t,amp,side,hopH)
 if t<=0 or t>=Preview.BeatLength then return 0,1,0 end
 local tilt
 if t<.10 then local u=t/.10;tilt=amp*(1-(1-u)*(1-u))
 elseif t<.18 then local u=(t-.10)/.08;tilt=amp+(-4-amp)*u
 else local u=(t-.18)/.17;tilt=-4*(1-u)*(1-u) end
 local squash=if t<.08 then 1-.04*math.sin(t/.08*math.pi)else 1
 local hop=if t>=.15 then hopH*math.sin((t-.15)/.20*math.pi)else 0
 return side*tilt,squash,hop
end
-- Pure: crack-light lift (studs) and CrackFlash transparency, ft seconds into a flash.
function Preview.flash(ft)
 if ft<0 or ft>=.25 then return 0,1 end
 local lift=if ft<.12 then .05*ft/.12 elseif ft<.22 then .05*(1-(ft-.12)/.10)else 0
 local tr=if ft<.125 then 1-.65*(ft/.125)else .35+.65*((ft-.125)/.125)
 return lift,tr
end
-- Pure: per-type rhythm (FX doc 3).
function Preview.rhythm(id)
 if id=="material"then return{gapMin=3.2,gapMax=4.4,double=false,hop=.06,sparkles=6}end
 if id=="toy"then return{gapMin=2.4,gapMax=3.6,double=true,hop=.08,sparkles=6}end
 if id=="feature"then return{gapMin=2.4,gapMax=3.6,double=true,hop=.06,sparkles=8}end
 return{gapMin=2.4,gapMax=3.6,double=true,hop=.06,sparkles=6}
end

local function circle(parent,name,z)
 local f=Kit.frame(parent,name,nil,UDim2.new(),UDim2.fromOffset(10,10),999);f.BackgroundTransparency=1;f.AnchorPoint=Vector2.new(.5,.5);f.ZIndex=z;return f
end
-- well: a Frame (clips). options: audio, reduced() -> bool.
function Preview.new(well,options)
 local self=setmetatable({well=well,options=options or {},type="toy",loaded=false,active=false,clock=0,yaw=0,
  nextBeat=1,nextFlash=5,sparkles={},parts={}},Preview)
 local z=well.ZIndex+1
 -- Bloom: one soft disc (centre-weighted gradient). Three hard discs read as a muddy
 -- target in Studio (2026-11-13); a gradient fades to nothing at the rim.
 self.bloom={}
 do local d=circle(well,"Bloom1",z);d.BackgroundColor3=Color3.new(1,1,1);d:SetAttribute("Share",1);self.bloom[1]=d
  Kit.node("UIGradient",d,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})}) end
 self.shadow=circle(well,"EggShadow3D",z);self.shadow.BackgroundColor3=Color3.new(0,0,0)
 local viewport=Kit.node("ViewportFrame",well,{Name="EggViewport",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=z+1,Visible=false,
  Ambient=Color3.fromRGB(150,160,165),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(.5,-.8,-.6)})
 local world=Kit.node("WorldModel",viewport,{});local camera=Kit.node("Camera",viewport,{FieldOfView=20})
 camera.CFrame=CFrame.lookAt(Vector3.new(0,1.5,5.2),Vector3.new(0,.7,0));viewport.CurrentCamera=camera
 self.viewport,self.world,self.camera=viewport,world,camera
 self.crack=circle(well,"CrackFlash",z+2)
 Kit.node("UIGradient",self.crack,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})})
 self.glint=circle(well,"Glint",z+2);self.glint.BackgroundColor3=Color3.new(1,1,1);self.glint.Rotation=-32
 self.sheenClip=Kit.frame(well,"SheenClip",nil,UDim2.new(),UDim2.fromOffset(10,10));self.sheenClip.ClipsDescendants=true;self.sheenClip.AnchorPoint=Vector2.new(.5,.5);self.sheenClip.ZIndex=z+2
 self.sheen=Kit.frame(self.sheenClip,"Sheen",nil,UDim2.new(),UDim2.fromScale(.18,1.6));self.sheen.BackgroundColor3=Color3.new(1,1,1);self.sheen.BackgroundTransparency=1;self.sheen.Rotation=20;self.sheen.AnchorPoint=Vector2.new(.5,.5)
 self.white=Kit.frame(well,"HatchFlash",nil,UDim2.new(),UDim2.fromScale(1,1));self.white.BackgroundColor3=Color3.new(1,1,1);self.white.BackgroundTransparency=1;self.white.ZIndex=z+4
 for i=1,12 do
  local holder=Kit.icon(well,"sparkle",16,"text");holder.Name="Sparkle"..i;holder.AnchorPoint=Vector2.new(.5,.5);holder.Visible=false;holder.ZIndex=z+3
  local inks={};for _,part in ipairs(holder:GetDescendants())do if part:GetAttribute("IconInk")and part:IsA("GuiObject")then part.ZIndex=z+3;table.insert(inks,part)end end
  self.sparkles[i]={holder=holder,inks=inks,start=-1,wait=math.random()*1.2,x=0,y=0,size=12,turn=0,burst=false}
 end
 well:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:measure()end)
 self:measure();self:showOverlays(false);self:paintStatic()
 Preview.loadTemplates(function(ok)if ok and not self.destroyed then self:build()end end)
 return self
end
-- The 3D egg's own glow, shadow and glint show only once the meshes are in.
function Preview:showOverlays(on)
 for _,d in ipairs(self.bloom)do d.Visible=on end
 self.shadow.Visible=on;self.glint.Visible=on;self.crack.Visible=on;self.sheenClip.Visible=on
end
function Preview:cue(name)
 local audio=self.options.audio;if not audio or not audio.play then return end
 pcall(function()audio:play(name,1,.5)end)
end
function Preview:reduced()
 return GuiService.ReducedMotionEnabled or(self.options.reduced and self.options.reduced()==true)or false
end
-- Screen geometry of the egg in the well (camera: FOV 20 at 5.2 studs -> 1.834 studs tall; closer since 2026-11-13 so the egg fills the well).
function Preview:measure()
 local s=self.well.AbsoluteSize;local H=math.max(1,s.Y);local W=math.max(1,s.X)
 local k=H/1.834
 self.geo={W=W,H=H,k=k,cx=W/2,cy=H/2+.05*k,ew=1.0*k,eh=1.3*k,phone=math.min(W,H)<=150}
 local g=self.geo
 for i,d in ipairs(self.bloom)do local share=d:GetAttribute("Share");d.Size=UDim2.fromOffset(g.ew*2.6*share,g.ew*2.6*share);d.Position=UDim2.fromOffset(g.cx,g.cy)end
 self.crack.Size=UDim2.fromOffset(g.ew*1.3,g.eh*.25)
 self.glint.Size=UDim2.fromOffset(g.ew*.10,g.ew*.26)
 self.sheenClip.Size=UDim2.fromOffset(g.ew,g.eh);self.sheenClip.Position=UDim2.fromOffset(g.cx,g.cy)
end
function Preview:build()
 if self.loaded then return end
 for _,key in ipairs(Parts)do
  local spec=Models.Egg[key]
  local part=templates[key]:Clone()
  part.Name=key;part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CastShadow=false
  part.Size=spec.size
  if key=="Core"then part.Material=Enum.Material.Neon;part.TextureID=""
  else part.Material=Enum.Material.SmoothPlastic;part.Reflectance=.08 end
  part.CFrame=CFrame.new(spec.center);part.Parent=self.world
  self.parts[key]=part
 end
 self.loaded=true;self.viewport.Visible=true;self:showOverlays(true)
 self:setType(self.type,true)
 if self.options.onLoaded then self.options.onLoaded()end
 self:paintStatic()
end
-- One ColorMap swap on both shells plus the core and glow colours.
function Preview:setType(id,quiet)
 local t=Models.Types[id]or Models.Types.toy
 local changed=id~=self.type;self.type=id;self.rhythm=Preview.rhythm(id)
 if self.parts.TopShell then
  self.parts.TopShell.TextureID=t.colorMap;self.parts.BottomShell.TextureID=t.colorMap
  self.parts.Core.Color=t.core
 end
 self.crack.BackgroundColor3=t.crackLight
 for _,d in ipairs(self.bloom)do d.BackgroundColor3=t.bloom end
 for i,s in ipairs(self.sparkles)do local c=t.particles[(i-1)%#t.particles+1];for _,ink in ipairs(s.inks)do ink.BackgroundColor3=c end end
 if changed and not quiet then self:cue("egg_select");self.hatchStart=nil end
 self:paintStatic()
end
function Preview:pose(yaw,tilt,hop,sy,lift,topUp,topTip,topFade,coreScale)
 if not self.loaded then return end
 local pivot=Models.Egg.spinPivot;local sx=2-sy
 local root=CFrame.new(0,hop,0)*CFrame.new(pivot)*CFrame.Angles(0,0,math.rad(tilt))*CFrame.Angles(0,yaw,0)*CFrame.new(-pivot)
 for _,key in ipairs(Parts)do
  local spec=Models.Egg[key];local part=self.parts[key]
  local c=spec.center
  local scale=if key=="Core"then coreScale else 1
  -- Resizing a MeshPart costs more than moving it: write Size only when it changes.
  local sizeKey=sy*1000+scale
  if self.sizeKeys==nil then self.sizeKeys={}end
  if self.sizeKeys[key]~=sizeKey then self.sizeKeys[key]=sizeKey;part.Size=Vector3.new(spec.size.X*sx*scale,spec.size.Y*sy*scale,spec.size.Z*sx*scale)end
  local cf=root*CFrame.new(c.X,c.Y*sy,c.Z)
  if key=="TopShell"then cf=CFrame.new(0,lift+topUp,0)*cf*CFrame.Angles(math.rad(-topTip),0,math.rad(-topTip*.5));part.Transparency=topFade end
  part.CFrame=cf
 end
end
-- Reduced Motion: three-quarter angle, steady Bloom, two static sparkles.
function Preview:paintStatic()
 if not self:reduced()and self.active then return end
 local g=self.geo
 self:pose(math.rad(-28),0,0,1,0,0,0,0,1)
 self:paintBloom(.6)
 self.crack.BackgroundTransparency=1;self.white.BackgroundTransparency=1;self.sheen.BackgroundTransparency=1
 self.shadow.Size=UDim2.fromOffset(g.ew*1.05,g.ew*.18);self.shadow.Position=UDim2.fromOffset(g.cx,g.cy+g.eh*.5);self.shadow.BackgroundTransparency=.55
 self.glint.Position=UDim2.fromOffset(g.cx-g.ew*.24,g.cy-g.eh*.5+g.eh*.26);self.glint.BackgroundTransparency=if self.loaded then .4 else 1
 for i,s in ipairs(self.sparkles)do
  local show=i<=2 and self.loaded
  s.holder.Visible=show
  if show then
   s.holder.Size=UDim2.fromOffset(12,12);s.holder.Position=UDim2.fromOffset(g.cx+(if i==1 then 1 else -1)*g.ew*.75,g.cy-(if i==1 then .3 else -.2)*g.eh)
   for _,ink in ipairs(s.inks)do ink.BackgroundTransparency=.1 end
  end
 end
end
function Preview:paintBloom(transparency)
 for _,d in ipairs(self.bloom)do d.BackgroundTransparency=1-(1-transparency)*.7 end
end
function Preview:spawnSparkle(s,now,burst)
 local g=self.geo;local a=math.random()*math.pi*2
 local r=(if burst then 0 else .6+.4*math.random())*g.ew
 s.x=g.cx+math.cos(a)*r;s.y=(if burst then g.cy+g.eh*.5-.58*g.eh else g.cy)+math.sin(a)*r*.8
 s.dx,s.dy=0,0
 if burst then local out=(.8+.6*math.random())*g.ew;s.dx,s.dy=math.cos(a)*out,math.sin(a)*out end
 local big=if g.phone then 12 else 20;local small=if g.phone then 6 else 8
 s.size=small+(big-small)*math.random();s.turn=(if math.random()<.5 then -1 else 1)*30;s.start=now;s.burst=burst==true
 s.length=if burst then .45 else .7
end
function Preview:stepSparkles(now)
 local count=if self.hatchStart then 12 else self.rhythm.sparkles
 if self.geo.phone and not self.hatchStart then count=math.max(2,math.floor(count/2))end
 local twinkle=self.type=="feature"
 for i,s in ipairs(self.sparkles)do
  if i>count then s.holder.Visible=false
  else
   if s.start<0 or now-s.start>s.length+s.wait then self:spawnSparkle(s,now,false);s.wait=.4+1.2*math.random()end
   local u=(now-s.start)/s.length
   if u>=0 and u<=1 then
    local scale=math.sin(u*math.pi);if twinkle then scale*=.75+.25*math.sin(now*math.pi*2.4)end
    local size=s.size*scale
    s.holder.Visible=size>.5
    s.holder.Size=UDim2.fromOffset(size,size);s.holder.Rotation=s.turn*u
    s.holder.Position=UDim2.fromOffset(s.x+s.dx*u,s.y+s.dy*u)
    local tr=1-math.sin(u*math.pi)
    for _,ink in ipairs(s.inks)do ink.BackgroundTransparency=tr end
   else s.holder.Visible=false end
  end
 end
end
function Preview:burst(now,count,seam)
 local n=0
 for _,s in ipairs(self.sparkles)do
  if n>=count then break end
  if s.start<0 or now-s.start>s.length then self:spawnSparkle(s,now,seam);s.wait=.4+1.2*math.random();n+=1 end
 end
end
function Preview:step(dt)
 if not self.active or self.destroyed then return end
 if self:reduced()then
  if not self.staticPainted then self.staticPainted=true;self:paintStatic()end
  if self.hatchStart then
   local t=self.clock-self.hatchStart;local u=math.clamp(t/.2,0,1);self.clock+=dt
   if t>=1.6 then self.hatchStart=nil;self:pose(math.rad(-28),0,0,1,0,0,0,0,1)
   else self:pose(math.rad(-28),0,0,1,0,.5*u,0,0,1)end
  end
  return
 end
 self.staticPainted=false
 dt=math.min(dt,.1);self.clock+=dt;local now=self.clock;local g=self.geo;local r=self.rhythm
 local tilt,sy,hop,lift,topUp,topTip,topFade,coreScale=0,1,0,0,0,0,0,1
 local bloom=.64+.08*math.sin(now*math.pi*2/1.6)
 if self.hatchStart then
  -- Hatch (FX doc 4): three growing beats, anticipation, pop, core swell and white flash.
  local t=now-self.hatchStart
  for i,amp in ipairs({8,11,14})do local bt=t-(i-1)*.12;if bt>0 and bt<Preview.BeatLength then tilt,sy,hop=Preview.beat(bt,amp,if i%2==0 then -1 else 1,r.hop)end end
  bloom=math.max(.3,bloom-t)
  if t>=.4 and t<.5 then sy=.9;lift=.05;self.crack.BackgroundTransparency=0 end
  if t>=1.6 then
   -- The pop has played; if the hatch was refused the shop stays open, so settle back.
   self.hatchStart=nil;self.burstDone=nil;self.white.BackgroundTransparency=1;self.crack.BackgroundTransparency=1
  elseif t>=.5 then
   local u=math.clamp((t-.5)/.22,0,1);local back=1+2.7*(u-1)^3+1.7*(u-1)^2
   topUp=.55*back+math.max(0,t-.72)*.4;topTip=16*back;topFade=math.clamp((t-.72)/.25,0,1)
   coreScale=1+.35*math.clamp((t-.5)/.2,0,1)
   self.white.BackgroundTransparency=math.clamp(.2+.8*((t-.5)/.3),0,1);self.crack.BackgroundTransparency=1
   if not self.burstDone then self.burstDone=true;self:burst(now,12,true)end
  end
 else
  self.yaw+=math.rad(20)*dt
  if not self.beatStart and now>=self.nextBeat then
   self.beatStart=now;self.beatAmp=6+3*math.random();self.beatSide=if math.random()<.5 then -1 else 1
   self.double=r.double and math.random()<.25
   self:burst(now,3,true)
  end
  if self.beatStart then
   local bt=now-self.beatStart
   tilt,sy,hop=Preview.beat(bt,self.beatAmp,self.beatSide,r.hop)
   if bt>=.15 and not self.hopCued then self.hopCued=true;self:cue("egg_wobble")end
   if bt>=Preview.BeatLength then
    if not self.flashStart then self.flashStart=now;self:cue("egg_crack_glint")end;self.hopCued=false
    if self.double then self.double=false;self.beatStart=now+.12;self.beatAmp*=.6
    else self.beatStart=nil;self.nextBeat=now+r.gapMin+(r.gapMax-r.gapMin)*math.random()end
   end
  end
  if now>=self.nextFlash then self.nextFlash=now+5+2*math.random();if not self.flashStart then self.flashStart=now;self:cue("egg_crack_glint")end end
  if self.flashStart then
   local fl,tr=Preview.flash(now-self.flashStart)
   lift=fl;self.crack.BackgroundTransparency=tr
   if tr<1 then bloom=.45 end
   if now-self.flashStart>=.25 then self.flashStart=nil end
  else self.crack.BackgroundTransparency=1 end
  coreScale=1+math.floor((.05*math.sin(now*math.pi*2/1.6))*200+.5)/200
 end
 self:pose(self.yaw,tilt,hop,sy,lift,topUp,topTip,topFade,coreScale)
 -- 2D overlays follow the hop.
 local hopPx=hop*g.k
 self:paintBloom(bloom)
 if self.type=="hue"then
  local list=Models.Types.hue.particles;local f=(now/6*#list)%#list;local a=math.floor(f)
  local c=list[a+1]:Lerp(list[(a+1)%#list+1],f-a);for _,d in ipairs(self.bloom)do d.BackgroundColor3=c end
 end
 self.crack.Position=UDim2.fromOffset(g.cx,g.cy+g.eh*.5-.58*g.eh-hopPx)
 local shrink=1-.15*math.clamp(hop/math.max(.01,r.hop),0,1)
 self.shadow.Size=UDim2.fromOffset(g.ew*1.05*shrink,g.ew*.18*shrink);self.shadow.Position=UDim2.fromOffset(g.cx,g.cy+g.eh*.5)
 self.shadow.BackgroundTransparency=.55+.15*(1-shrink)/.15
 self.glint.Size=UDim2.fromOffset(g.ew*.10*(2-sy),g.ew*.26);self.glint.Position=UDim2.fromOffset(g.cx-g.ew*.24,g.cy-g.eh*.24-hopPx);self.glint.BackgroundTransparency=.4
 if self.type=="material"and not g.phone then
  local u=(now%4)/.8
  self.sheen.BackgroundTransparency=if u<1 then .75 else 1;self.sheen.Position=UDim2.fromScale(-.2+1.4*math.min(u,1),.5)
 else self.sheen.BackgroundTransparency=1 end
 self:stepSparkles(now)
end
function Preview:setActive(on)
 on=on==true and not self.destroyed
 if on==self.active then return end
 self.active=on
 if on then
  self.connection=RunService.RenderStepped:Connect(function(dt)self:step(dt)end)
  self.staticPainted=false
 else
  if self.connection then self.connection:Disconnect();self.connection=nil end
  self.hatchStart=nil;self.burstDone=nil;self:paintStatic()
 end
end
-- Hatch press: pop the top shell (fire and forget; never delays the request).
function Preview:hatch()
 if not self.loaded then return false end
 self.hatchStart=self.clock;self.burstDone=nil;self.staticPainted=false
 return true
end
function Preview:destroy()
 if self.destroyed then return end
 self.destroyed=true;self:setActive(false)
 for _,part in pairs(self.parts)do part:Destroy()end
end
return Preview
