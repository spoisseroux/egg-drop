-- The wallet's 3D Star (Spencer 2026-11-13: "more interesting, glistening, maybe a
-- rotating 3D model"). Kit.wallet keeps its 2D Star icon (and the P3 eyes) as the
-- fallback and for Stars under 16 px; from 16 px up, once the StarToken mesh loads
-- (CelebrationKit.loadStarMesh: one AssetService template per session, cloned per
-- wallet), a ViewportFrame with that Star replaces the icon in exactly the icon's
-- rect, so the capsule, the number and their positions never move.
--
-- Motion, one 6 s cycle: a gentle sway (eyes on, front-facing) for 4.4 s, then one
-- eased full turn in 1.6 s; as it lands, a four-point sparkle twinkles on the upper
-- tip and the Star brightens for 0.6 s. A soft gold glow and a light from behind
-- give the rim its gold. The eyes slide and narrow with the yaw and hide past 40
-- degrees (as on the results hero). Reduced Motion: a still front-facing Star, no
-- sway, turn or sparkle. If the mesh cannot be created the 2D Star stays.
--
-- One shared clock for every wallet: PetPeek's RenderStepped subscriber list (key
-- "WalletStar"), only while a 3D wallet is in the DataModel. A tick allocates
-- nothing: spin frames, eye rects, sparkle scales and light colours are tables
-- built once; properties are written only when their step changes; a wallet that
-- is not visible (any hidden ancestor, a disabled or detached ScreenGui) is skipped
-- and rechecked every 0.25 s.
local GuiService=game:GetService("GuiService")
local Assets=require(script.Parent.DeckAssets)
local Star={}
-- QA v2 R3.3: 16, so the compact header capsule (36 high, an 18 px Star) and the
-- 32 / 40 deck wallets (17 / 22 px) all get the 3D Star; only tiny Stars stay 2D.
Star.MinSize=16
Star.Cycle=6
Star.SwayTime=4.4 -- then the turn takes Cycle-SwayTime
Star.SwayDegrees=16
Star.GlintTime=.6
Star.FaceYaw=40
Star.ViewScale=1.3 -- the viewport is this much larger than the icon rect (centred)
Star.Fill=.92 -- the Star's height as a share of the icon size
Star.VisibilityRecheck=.25
Star.SpinStep=3 -- degrees per cached spin frame
Star.ClockKey="WalletStar"

-- ── Pure ─────────────────────────────────────────────────────────────────────
-- Yaw (degrees, 0..360) and glint phase (0..1, or nil) at time t.
function Star.pose(t)
 local u=t%Star.Cycle
 local yaw
 if u<Star.SwayTime then yaw=Star.SwayDegrees*math.sin(u/Star.SwayTime*math.pi*2)
 else local s=(u-Star.SwayTime)/(Star.Cycle-Star.SwayTime);yaw=360*s*s*(3-2*s)end
 local glint=if u<Star.GlintTime then u/Star.GlintTime else nil
 return yaw%360,glint
end
-- The face turn (-180..180) for a yaw, or nil when the face hides.
function Star.faceTurn(yaw)
 local w=((yaw or 0)+180)%360-180
 if math.abs(w)>Star.FaceYaw then return nil end
 return w
end

-- ── Cached tables (built once) ───────────────────────────────────────────────
local spinFrames={}
for i=0,math.floor(360/Star.SpinStep)-1 do spinFrames[i]=CFrame.Angles(0,math.rad(i*Star.SpinStep),0)end
local spinCount=math.floor(360/Star.SpinStep)
local GlintSteps=12
local sparkleScale,sparkleAlpha,ambientSteps,glowAlpha={},{},{},{}
local AmbientBase,AmbientBright=Color3.fromRGB(206,192,166),Color3.fromRGB(255,240,200)
for i=0,GlintSteps do
 local k=math.sin(i/GlintSteps*math.pi) -- 0 -> 1 -> 0
 sparkleScale[i]=.2+.9*k;sparkleAlpha[i]=1-k
 ambientSteps[i]=AmbientBase:Lerp(AmbientBright,k*.8)
 glowAlpha[i]=.78-.3*k
end

-- ── Loader (replaceable for specs) ───────────────────────────────────────────
-- loader(callback): calls back (possibly later) with a MeshPart template or nil.
local loader=nil
local function defaultLoader(callback)require(script.Parent.CelebrationKit).loadStarMesh(callback)end
function Star.setLoader(fn)loader=fn end
function Star.getLoader()return loader end
local reducedOverride=nil
function Star.setReduced(value)reducedOverride=value end -- specs only: true/false/nil
local function reduced()
 if reducedOverride~=nil then return reducedOverride end
 return GuiService.ReducedMotionEnabled
end

-- ── Registry + shared clock ──────────────────────────────────────────────────
local wallets={}
local clockOn=false
local step
local function clock()return require(script.Parent.PetPeek)end
local function syncClock()
 local want=#wallets>0
 if want and not clock().isSubscribed(Star.ClockKey)then clock().subscribe(Star.ClockKey,function(now)step(now)end);clockOn=true
 elseif not want and clockOn then clock().unsubscribe(Star.ClockKey);clockOn=false end
end
local function register(w)
 if w.registered or w.dead then return end
 w.registered=true;table.insert(wallets,w);w.visibleAt=0;syncClock()
end
local function unregister(w)
 if not w.registered then return end
 w.registered=false
 local at=table.find(wallets,w);if at then table.remove(wallets,at)end
 syncClock()
end
function Star.count()return #wallets end
function Star.clockRunning()return clock().isSubscribed(Star.ClockKey)end

local function onScreen(object)
 local node=object
 while node do
  if node:IsA("GuiObject")then if not node.Visible then return false end
  elseif node:IsA("LayerCollector")then
   if not node.Enabled then return false end
   return node:FindFirstAncestorOfClass("PlayerGui")~=nil or node:FindFirstAncestorOfClass("CoreGui")~=nil
  end
  node=node.Parent
 end
 return false
end

local function apply(w,yaw,glint)
 local index=math.floor(yaw/Star.SpinStep+.5)%spinCount
 if w.spin~=index then w.spin=index;w.part.CFrame=spinFrames[index]end
 local turn=Star.faceTurn(index*Star.SpinStep)
 local show=turn~=nil
 if w.face.Visible~=show then w.face.Visible=show end
 if show then
  local q=math.floor(turn+.5)
  if w.turn~=q then w.turn=q;w.face.Position=w.facePos[q];w.face.Size=w.faceSize[q]end
 end
 local g=if glint then math.floor(glint*GlintSteps+.5)else -1
 if w.glint~=g then
  w.glint=g
  local on=g>=0
  if w.sparkle.Visible~=on then w.sparkle.Visible=on end
  local k=if on then g else 0
  if on then w.sparkleScale.Scale=sparkleScale[k];w.sparkle.Rotation=k*7 end
  w.viewport.Ambient=ambientSteps[k];w.glow.BackgroundTransparency=glowAlpha[k]
 end
end
step=function(now)
 local still=reduced()
 for index=#wallets,1,-1 do
  local w=wallets[index]
  if w then
   if now>=w.visibleAt then w.visible=onScreen(w.holder);w.visibleAt=now+Star.VisibilityRecheck end
   if w.visible then
    if still then apply(w,0,nil)else
     local yaw,glint=Star.pose(now)
     apply(w,yaw,glint)
    end
   end
  end
 end
end
Star._step=function(now)step(now)end -- specs: one deterministic tick

-- ── Build ────────────────────────────────────────────────────────────────────
local function make(class,parent,props)
 local object=Instance.new(class)
 for key,value in pairs(props)do object[key]=value end
 object.Parent=parent;return object
end
local function round(parent)make("UICorner",parent,{CornerRadius=UDim.new(.5,0)})end

local function build(pill,icon,size,template)
 local z=icon.ZIndex
 local holder=make("Frame",pill,{Name="Star3D",BackgroundTransparency=1,BorderSizePixel=0,AnchorPoint=icon.AnchorPoint,Position=icon.Position,
  Size=UDim2.fromOffset(size,size),ZIndex=z,Active=false,Selectable=false,Interactable=false,Visible=true})
 local glow=make("Frame",holder,{Name="Glow",BackgroundColor3=Color3.fromRGB(255,193,77),BackgroundTransparency=glowAlpha[0],BorderSizePixel=0,
  AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.52),Size=UDim2.fromScale(1.25,1.25),ZIndex=z,Active=false})
 round(glow)
 -- A centred band on a round frame reads as a soft halo (as on the results Star).
 make("UIGradient",glow,{Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})})
 local viewport=make("ViewportFrame",holder,{Name="StarViewport",BackgroundTransparency=1,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(Star.ViewScale,Star.ViewScale),ZIndex=z+1,Active=false,Selectable=false,Interactable=false,
  Ambient=AmbientBase,LightColor=Color3.fromRGB(255,214,120),LightDirection=Vector3.new(-.55,-.6,.6)})
 local Models=require(game:GetService("ReplicatedStorage").Shared.EggModels).Star
 local part=template:Clone()
 part.Size=Models.size;part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false;part.CastShadow=false
 part.CFrame=spinFrames[0];part.Parent=viewport
 local camera=make("Camera",viewport,{FieldOfView=30})
 viewport.CurrentCamera=camera
 local share=Star.Fill/Star.ViewScale
 local distance=(Models.size.Y*.5)/math.tan(math.rad(15))/share+Models.size.Z*.5
 camera.CFrame=CFrame.lookAt(Vector3.new(0,0,distance),Vector3.zero)
 -- Eyes: the uploaded eyes cell when there is one, else two ink dots (as on the 2D Star).
 local face=make("Frame",holder,{Name="StarFace3D",BackgroundTransparency=1,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(1,1),ZIndex=z+2,Active=false})
 local faceId=Assets.Personality and Assets.Personality.starFace
 if faceId then
  make("ImageLabel",face,{Name="StarFace",BackgroundTransparency=1,Image=faceId,ImageRectOffset=Vector2.new(128,0),ImageRectSize=Vector2.new(128,128),
   Size=UDim2.fromScale(1,1),ZIndex=z+2,Active=false})
 else
  for side=-1,1,2 do
   local eye=make("Frame",face,{Name="StarEye",BorderSizePixel=0,BackgroundColor3=Color3.fromHex("#3B2608"),AnchorPoint=Vector2.new(.5,.5),
    Position=UDim2.fromScale(.5+side*.11,.54),Size=UDim2.fromOffset(math.max(2,math.floor(size*.12+.5)),math.max(3,math.floor(size*.18+.5))),
    ZIndex=z+2,Active=false})
   round(eye)
  end
 end
 -- Four-point sparkle on the upper tip.
 local sparkle=make("Frame",holder,{Name="Sparkle",BackgroundTransparency=1,BorderSizePixel=0,AnchorPoint=Vector2.new(.5,.5),
  Position=UDim2.fromScale(.74,.2),Size=UDim2.fromOffset(math.floor(size*.62),math.floor(size*.62)),ZIndex=z+3,Visible=false,Active=false})
 local scale=make("UIScale",sparkle,{Scale=sparkleScale[0]})
 local thick=math.max(2,math.floor(size*.09+.5))
 for _,vertical in ipairs({true,false})do
  local bar=make("Frame",sparkle,{Name="Ray",BorderSizePixel=0,BackgroundColor3=Color3.new(1,1,1),AnchorPoint=Vector2.new(.5,.5),
   Position=UDim2.fromScale(.5,.5),Size=if vertical then UDim2.new(0,thick,1,0)else UDim2.new(1,0,0,thick),ZIndex=z+3,Active=false})
  round(bar)
  make("UIGradient",bar,{Rotation=if vertical then 90 else 0,Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.5,0),NumberSequenceKeypoint.new(1,1)})})
 end
 -- Eye rects for every whole degree of turn the face shows (-FaceYaw..FaceYaw).
 local facePos,faceSize={},{}
 for q=-Star.FaceYaw,Star.FaceYaw do
  local r=math.rad(q)
  facePos[q]=UDim2.new(.5,math.floor(math.sin(r)*size*.3+.5),.5,0);faceSize[q]=UDim2.fromScale(math.cos(r),1)
 end
 holder:SetAttribute("WalletStar3D",true)
 return{holder=holder,viewport=viewport,part=part,camera=camera,face=face,sparkle=sparkle,sparkleScale=scale,glow=glow,
  facePos=facePos,faceSize=faceSize,spin=0,turn=nil,glint=nil,visible=false,visibleAt=0,registered=false}
end

-- Kit.wallet calls this for its Star icon. Returns a handle {state="loading"|"3D"|"2D",
-- wallet=<record when 3D>}; under MinSize nothing happens (state "2D").
function Star.attach(pill,icon,size)
 local handle={state="2D"}
 if size<Star.MinSize then return handle end
 handle.state="loading"
 local load=loader or defaultLoader
 load(function(template)
  if handle.state~="loading"then return end
  if not template or not pill.Parent or not icon.Parent then handle.state="2D";return end
  local ok,w=pcall(build,pill,icon,size,template)
  if not ok then
   local partial=pill:FindFirstChild("Star3D");if partial then partial:Destroy()end
   handle.state="2D";warn("Wallet 3D Star could not be built; keeping the 2D Star: "..tostring(w));return
  end
  handle.wallet,handle.state=w,"3D"
  icon.Visible=false
  apply(w,0,nil)
  w.ancestry=pill.AncestryChanged:Connect(function()
   if pill:IsDescendantOf(game)then register(w)else unregister(w)end
  end)
  w.destroying=pill.Destroying:Connect(function()w.dead=true;unregister(w);w.ancestry:Disconnect();w.destroying:Disconnect()end)
  if pill:IsDescendantOf(game)then register(w)end
 end)
 return handle
end
return Star
