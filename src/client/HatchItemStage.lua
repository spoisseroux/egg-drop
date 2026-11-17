-- Full-screen item reveal (QA v685 H2 / H3 / H5): Toy, Hue, Material and Feature eggs.
-- The screen dims to a dark stage, the egg wobbles in a rarity-coloured beam that builds, the shell bursts
-- (flash, rings, rays, shards), the item pops onto a card that flies to its seat, the name
-- slams in under a rarity banner, and the reveal ends on the host's own receipt actions.
-- QA R4 (2026-11-15): it opens and leaves by CelebrationKit's shared rules. The screen dims
-- to the stage, then the egg fades in and eases up (QA v735 H1: slower, eased both ways); stage:dismiss() lets the content sink into
-- the dark and the dark lift off the menu or garden underneath, in its own top-level gui.
-- QA R2 (2026-11-15): the card is a lit backdrop in the tier's colour (HatchRarityCue.Look
-- back / backDeep), and a 3D result (a toy, a feature, the Bear wearing a finish) turns
-- slowly on it once the name is out (HatchDisplayScene:setSpin).
--   HatchItemStage.show(parent,{scene,kind,tier,...}) -> stage
-- It borrows the hatch's one native scene (HatchDisplayScene) and follows the hatch's one
-- clock through stage:updateExternal(age, sample); it owns no reward, receipt or asset.
--
-- options:
--   scene       HatchDisplayScene (required); kind "toy"|"hue"|"material"|"feature"
--   tier        "Common"|"Uncommon"|"Rare"|"Neutral" (HatchRarityCue.tier)
--   name()      the item's name, read once the receipt is ready (never before)
--   detail()    the host's supporting line (where it went, what to do next)
--   description() one fun line about the item (QA R1), drawn above the host's line;
--               default Stage.describe(kind, result) from UICopy hatch.reveal.describe
--   actions()   {{source=GuiButton, primary=bool, act=function}}: the host's receipt
--               buttons. The stage mirrors their text / enabled / visible and calls `act`.
--   onSkip()    a press before the receipt is ready; onClose() the corner close
--   owns(), reduced(), instant (start on the settled frame), consumeSkipInput()
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local Kit=require(script.Parent.DeckKit)
local C=require(script.Parent.CelebrationKit)
local Pose=require(script.Parent.HatchDisplayPose)
local Rarity=require(script.Parent.HatchRarityCue)
local Copy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
local Look=require(game:GetService("ReplicatedStorage").Shared.LookEggCatalog)
local Stage={};Stage.__index=Stage
-- Customization Egg (slice 4): a Hue-route result can be a finish jar or a charm; the banner
-- and the fun line say which ("RARE CHARM", "UNCOMMON FINISH JAR").
function Stage.resultKind(kind,result)
 if kind=="hue"and type(result)=="table"then
  local k=Look.kind(result.itemId)
  if k=="finish"or k=="charm"then return k end
 end
 return kind
end

-- ── Pure rules (specs cover these) ───────────────────────────────────────────
Stage.BurstAt=Rarity.BurstAt;Stage.CardAt=1.06;Stage.SlideAt=1.26;Stage.SettleAfter=.50;Stage.ReducedFade=.15
Stage.ShardLife=.95;Stage.RingLife=.50;Stage.EggScale=1.42;Stage.GlowDiscs=40
Stage.CardShare=.78 -- the tilted card behind the item, as a share of its seat (was 1.04; v842)
Stage.SpinSpeed=math.rad(42);Stage.SpinEase=.8;Stage.BackLights=18
-- Pure: the turn (radians) `t` seconds after the name landed: eases in, then a steady 42 deg/s.
function Stage.spinAt(t)
 if t<=0 then return 0 end
 local e=Stage.SpinEase
 return Stage.SpinSpeed*(if t<e then t*t/(2*e)else t-e*.5)
end
Stage.Dim=1;Stage.Backdrop=Color3.fromHex("#06070B");Stage.Card=Color3.fromHex("#141823");Stage.Ink=Color3.fromHex("#0E0F12")
local function ramp(t,start,duration)return math.clamp((t-start)/duration,0,1)end
local function smooth(a,b,t)local u=math.clamp((t-a)/(b-a),0,1);return u*u*(3-2*u)end
local function backOut(x)local c1=1.70158;local c3=c1+1;return 1+c3*(x-1)^3+c1*(x-1)^2 end
local function quintOut(x)return 1-(1-x)^5 end
local function quadOut(x)return 1-(1-x)^2 end
local function hash(i,salt)local x=math.sin(i*12.9898+salt*78.233)*43758.5453;return x-math.floor(x)end
Stage.hash=hash

-- Timeline on the hatch clock (seconds). The name appears exactly when the receipt is
-- ready (HatchDisplayPose.ItemReady), never earlier: the reward stays undisclosed until then.
function Stage.sample(t,reduced)
 t=math.max(0,t or 0);local R=Pose.ItemReady
 if reduced then
  local on=t>=Stage.ReducedFade
  return {t=t,reduced=true,fade=ramp(t,0,Stage.ReducedFade),build=1,shake=0,burstAge=math.huge,flash=0,beam=.55,rays=1,
   card=1,slide=1,named=on,name=1,banner=1,detail=1,buttons=1,input=on,settled=on,pre=0}
 end
 local s={t=t,reduced=false,fade=1}
 s.build=smooth(.08,.94,t)                          -- glow and beam ramp up with the wobble
 s.shake=if t<Stage.BurstAt then smooth(.55,.95,t)else 0
 s.burstAge=t-Stage.BurstAt                         -- shards, rings (negative before the burst)
 s.flash=if t<Stage.BurstAt then 0 else 1-quadOut(ramp(t,Stage.BurstAt,.32))
 s.beam=if t<Stage.BurstAt then .12+.88*s.build else .55+1.05*(1-quadOut(ramp(t,Stage.BurstAt,.60)))
 s.rays=quadOut(ramp(t,Stage.BurstAt,.25))
 s.card=backOut(ramp(t,Stage.CardAt,.30))           -- the card flips in behind the item
 s.slide=quintOut(ramp(t,Stage.SlideAt,.36))        -- and flies to its seat
 s.named=t>=R;s.name=backOut(ramp(t,R,.22))         -- name slam
 s.banner=quintOut(ramp(t,R+.10,.22));s.detail=ramp(t,R+.20,.18)
 s.buttons=quadOut(ramp(t,R+.08,.20));s.input=t>=R
 s.settled=t>=R+Stage.SettleAfter
 s.pre=1-ramp(t,Stage.BurstAt-.05,.15)              -- "A little surprise" line
 return s
end
-- Pure: shard `i` of `count` at `age` seconds after the burst, around (0,0) in units of
-- the seat size. Returns x, y, rotation (deg), alpha (0..1) or nil when it is gone.
function Stage.shard(i,count,age)
 if age<0 or age>Stage.ShardLife then return nil end
 local angle=(i/count)*math.pi*2+hash(i,21)*.7
 local speed=1.5+1.6*hash(i,22)
 local drag=2.2;local travel=(1-math.exp(-drag*age))/drag
 local x=math.cos(angle)*speed*travel
 local y=math.sin(angle)*speed*travel*.8+.9*age*age
 local fade=if age>Stage.ShardLife-.35 then 1-(age-(Stage.ShardLife-.35))/.35 else 1
 return x,y,(if hash(i,23)<.5 then -1 else 1)*(200+500*hash(i,24))*age,fade
end
-- Banner words: "RARE FINISH", "COMMON FINISH", and "NEW TOY" for an item with no tier.
function Stage.bannerText(tier,kind)
 local kindWord=Copy.get("hatch.reveal.kind."..(if Copy.has("hatch.reveal.kind."..tostring(kind))then kind else "item"))
 if tier=="Common"or tier=="Uncommon"or tier=="Rare"then return Copy.get("hatch.reveal.banner",{tier=Copy.get("hatch.reveal.tier."..tier),kind=kindWord})end
 return Copy.get("hatch.reveal.fresh",{kind=kindWord})
end
-- QA R1: the item's one fun line (60 characters at most), by kind and id; an item with no
-- line of its own gets its kind's line. Pure: it never reads ownership.
local idField={toy="toyId",material="finishId",hue="itemId",feature="featureId"}
function Stage.describe(kind,result)
 local lookKind=Stage.resultKind(kind,result)
 if lookKind=="finish"then return Copy.get("hatch.reveal.describe.finishJar."..result.itemId)end
 if lookKind=="charm"then return Copy.get("hatch.reveal.describe.charm."..Look.shape(result.itemId))end
 local id=type(result)=="table"and idField[kind]and result[idField[kind]]
 local key=if type(id)=="string"then "hatch.reveal.describe."..kind.."."..id else nil
 if key and Copy.has(key)then return Copy.get(key)end
 return Copy.get("hatch.reveal.describe.other."..(if idField[kind]then kind else "item"))
end
local function luminance(c)
 local function lin(x)return if x<=.03928 then x/12.92 else((x+.055)/1.055)^2.4 end
 return .2126*lin(c.R)+.7152*lin(c.G)+.0722*lin(c.B)
end
function Stage.inkOn(color)return if(luminance(color)+.05)/(luminance(Stage.Ink)+.05)>=4.5 then Stage.Ink else Color3.new(1,1,1)end

-- QA v775 note 11: the corner close sat 12 px from the physical screen corner (the stage
-- covers the whole screen, so on a phone that is the rounded corner, outside the safe area).
-- Pure: its top-left and size. `safe` = {l, t, r, b}, how far the device safe area sits
-- inside the stage; `bar` = {maxX, height}, the right end and height of the free strip of
-- Roblox's top bar in stage px (GuiService.TopbarInset). The close keeps Stage.CloseInset
-- to the safe area's right and top edges, and drops under the top bar when Roblox draws
-- its own controls where it would sit.
Stage.CloseSize=44
Stage.CloseInset=table.freeze({phone=table.freeze({x=24,y=16}),regular=table.freeze({x=32,y=28})}) -- phone x = the stage margin: level with the buttons' right edge
function Stage.closeRect(W,H,phone,safe,bar)
 safe=safe or {}
 local size=Stage.CloseSize
 local inset=if phone then Stage.CloseInset.phone else Stage.CloseInset.regular
 local x=W-math.max(0,safe.r or 0)-inset.x-size
 local y=math.max(0,safe.t or 0)+inset.y
 if bar and bar.height and bar.maxX and bar.height>y and bar.maxX<x+size then y=bar.height+8 end
 x=math.clamp(x,0,math.max(0,W-size));y=math.clamp(y,0,math.max(0,H-size))
 return math.floor(x),math.floor(y),size
end
-- The device safe area (the ScreenInsets.DeviceSafeInsets probe gui) and the top bar's free
-- strip, both in `root` px. No probe (a spec fixture): no insets.
function Stage.safeArea(root)
 local safe={l=0,t=0,r=0,b=0}
 local holder=root:FindFirstAncestorOfClass("PlayerGui")
 local probe=holder and holder:FindFirstChild("EggDropInsetProbe")
 if not(probe and probe:IsA("GuiBase2d"))or root:GetAttribute("CoversScreen")~=true then return safe,nil end
 local rp,rs,pp,ps=root.AbsolutePosition,root.AbsoluteSize,probe.AbsolutePosition,probe.AbsoluteSize
 if ps.X<=0 or ps.Y<=0 then return safe,nil end
 safe.l=math.max(0,pp.X-rp.X);safe.t=math.max(0,pp.Y-rp.Y)
 safe.r=math.max(0,rp.X+rs.X-pp.X-ps.X);safe.b=math.max(0,rp.Y+rs.Y-pp.Y-ps.Y)
 local inset=GuiService.TopbarInset
 local bar=if inset.Height>0 and inset.Width>0 then {maxX=inset.Max.X,height=inset.Height}else nil
 return safe,bar
end

-- Layout. Landscape (phone and PC): the egg plays at the centre, then the card flies to
-- the left third and the name, banner and actions take the right. Portrait stacks them.
function Stage.geometry(W,H)
 local L={W=W,H=H,landscape=W>=H*1.15,phone=Kit.compactRule(W,H)or W<760}
 local s=if L.phone then math.min(W/812,H/354)else math.min(W/1920,H/1080);L.s=s
 L.margin=if L.phone then 24 else math.floor(88*s)
 L.btnH=if L.phone then 48 else math.max(48,math.floor(72*s));L.gap=if L.phone then 10 else math.max(10,math.floor(16*s))
 L.btnText=if L.phone then 16 else math.max(16,math.floor(22*s))
 L.nameSize=if L.phone then math.max(24,38*s)else math.max(34,118*s)
 L.bannerSize=if L.phone then 12 else math.max(14,28*s)
 L.detailSize=if L.phone then 13 else math.max(14,28*s)
 L.preSize=if L.phone then 14 else math.max(16,26*s)
 if L.landscape then
  L.seat=math.floor(math.min(H*.64,W*.34,600))
  L.cx0,L.cy0=W*.5,H*.50
  L.cx1,L.cy1=math.floor(W*.29),H*.50
  L.textX=math.floor(W*.50);L.textW=W-L.textX-L.margin
  local bannerH=math.floor(L.bannerSize*1.7);local nameH=math.floor(L.nameSize*1.2)
  local block=bannerH+nameH+math.floor(L.detailSize*3.2)
  L.bannerY=math.max(if L.phone then 56 else 0,math.floor((H-L.btnH-L.margin-block)*.5))
  L.nameY=L.bannerY+bannerH+math.floor(L.nameSize*.14);L.detailY=L.nameY+nameH+math.floor(L.detailSize*.9)
  L.btnY=H-L.btnH-(if L.phone then 16 else math.floor(112*s))
  L.btnX=L.textX;L.btnW=L.textW
  L.preY=math.min(H-L.preSize*2,L.cy0+L.seat*.5+L.preSize*.4)
 else
  L.seat=math.floor(math.min(W*.62,H*.36))
  L.cx0,L.cy0=W*.5,H*.40
  L.cx1,L.cy1=W*.5,math.floor(H*.30)
  L.textX=L.margin;L.textW=W-L.margin*2
  L.bannerY=math.floor(L.cy1+L.seat*.5+16)
  L.nameY=L.bannerY+math.floor(L.bannerSize*1.7)+6;L.detailY=L.nameY+math.floor(L.nameSize*1.2)+8
  L.btnY=H-L.btnH-math.max(24,L.margin);L.btnX=L.margin;L.btnW=W-L.margin*2
  L.preY=L.cy0+L.seat*.5+L.preSize
 end
 -- v842 phone notes: the tilted card behind the item is 75% of its old size (1.04 of the seat).
 L.cardW,L.cardH=math.floor(L.seat*Stage.CardShare),math.floor(L.seat*Stage.CardShare)
 return L
end

-- ── View ────────────────────────────────────────────────────────────────────
local function layer(root,name,n)
 local f=Kit.frame(root,name,nil,UDim2.new(),UDim2.fromScale(1,1));f.ZIndex=root.ZIndex+n;return f
end
local function fill(parent,name,color,transparency)
 local f=Kit.frame(parent,name,nil,UDim2.new(),UDim2.fromOffset(1,1));f.BackgroundTransparency=transparency or 0;f.BackgroundColor3=color
 f.AnchorPoint=Vector2.new(.5,.5);return f
end

function Stage.show(parent,options)
 assert(options and options.scene,"HatchItemStage needs the hatch's native scene")
 local tier=if Rarity.Look[options.tier]then options.tier else "Neutral"
 local self=setmetatable({options=options,scene=options.scene,tier=tier,look=Rarity.Look[tier],kind=Stage.resultKind(options.kind or "item",options.result),
  age=0,clock=0,connections={},buttons={},watched={},shards={},rays={},rings={},sparkles={}},Stage)
 local root=Kit.frame(parent,"ItemRevealStage",nil,UDim2.new(),UDim2.fromScale(1,1))
 root.ZIndex=options.zIndex or 80;root.BackgroundColor3=Stage.Backdrop;root.BackgroundTransparency=1;root.Active=true;root.ClipsDescendants=true
 root:SetAttribute("RevealTier",tier);root:SetAttribute("RevealKind",self.kind)
 self.root=root
 -- The host screen sits in an inset gui; cover the whole screen (fixtures pass cover=false).
 if options.cover~=false then Kit.coverScreen(root)end
 self:build()
 self.reducedStart=self:reduced()
 self.openedAt=os.clock()
 self.instant=options.instant==true
 if self.instant then self.age=Pose.ItemDuration end
 self.borrowToken=self.scene:borrow(self.seat)
 if self.scene.setBare then self.scene:setBare(true,false)end
 self:layout()
 table.insert(self.connections,root:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()self:layout()end))
 table.insert(self.connections,GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()self:paintFocus()end))
 self:refresh();self:paint()
 self.connection=RunService.RenderStepped:Connect(function(dt)self:step(dt)end)
 return self
end
function Stage:reduced()
 local r=self.options.reduced
 if type(r)=="function"then return r()==true end
 if r~=nil then return r==true end
 return Kit.reduced()
end
function Stage:owned()
 if self.destroyed or self.leaving or not self.root.Parent then return false end
 local node=self.root
 while node do
  if node:IsA("GuiObject")and not node.Visible then return false end
  if node:IsA("ScreenGui")and not node.Enabled then return false end
  node=node.Parent
 end
 return not self.options.owns or self.options.owns()==true
end

function Stage:build()
 local root=self.root;local look=self.look;local color=look.color
 -- 1 glow, 2 beam, 3 rays, 4 rings, 5 card, 6 scene seat, 7 shards + sparkles, 8 flash,
 -- 9 text, 10 skip pad, 11 buttons.
 local glowLayer=layer(root,"Glow",1)
 -- A soft round glow from nested discs (one disc with a gradient shows its edge).
 self.glow={}
 for index=1,Stage.GlowDiscs do
  local disc=fill(glowLayer,"TierGlow"..index,color,1);Kit.node("UICorner",disc,{CornerRadius=UDim.new(.5,0)});self.glow[index]=disc
 end
 local beamLayer=layer(root,"Beam",2)
 self.beamWide=fill(beamLayer,"BeamWide",color,1)
 C.gradient(self.beamWide,0,{{0,1},{.5,.25},{1,1}})
 self.beamCore=fill(beamLayer,"BeamCore",Color3.new(1,1,1):Lerp(color,.25),1)
 C.gradient(self.beamCore,0,{{0,1},{.5,0},{1,1}})
 -- Rays: bars through the centre, each lit on one half only, turning slowly as a group.
 local rayLayer=layer(root,"Rays",3)
 self.rayGroup=Kit.frame(rayLayer,"RayGroup",nil,UDim2.new(),UDim2.fromOffset(10,10));self.rayGroup.AnchorPoint=Vector2.new(.5,.5)
 for index=1,look.rays do
  local ray=fill(self.rayGroup,"Ray"..index,if index%2==0 then look.second else color,1)
  ray.Position=UDim2.fromScale(.5,.5);ray.Rotation=(index-1)*360/look.rays+hash(index,31)*8
  C.gradient(ray,90,{{0,1},{.08,.55},{.36,.85},{.5,1},{1,1}})
  self.rays[index]=ray
 end
 local ringLayer=layer(root,"Rings",4)
 for index=1,look.rings do
  local ring=fill(ringLayer,"Ring"..index,color,1);Kit.node("UICorner",ring,{CornerRadius=UDim.new(.5,0)})
  local stroke=Kit.node("UIStroke",ring,{Color=if index==1 then color else look.second,Thickness=4,Transparency=1})
  self.rings[index]={node=ring,stroke=stroke};ring.Visible=false
 end
 -- Card: a lit backdrop in the tier's colour with a tier-coloured rim, tilted a little; the
 -- item stands on it. The colour runs light at the top to deep at the floor, and a soft
 -- round light (nested discs, so no edge shows) sits behind the item.
 local cardLayer=layer(root,"CardLayer",5)
 self.card=fill(cardLayer,"ItemCard",Color3.new(1,1,1),0);self.card.Rotation=-3;self.card.Visible=false
 self.card:SetAttribute("BackdropTop",look.back);self.card:SetAttribute("BackdropFloor",look.backDeep)
 self.cardCorner=Kit.node("UICorner",self.card,{CornerRadius=UDim.new(0,18)})
 self.cardStroke=Kit.node("UIStroke",self.card,{Color=color,Thickness=3,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
 self.cardBack=Kit.node("UIGradient",self.card,{Name="TierBackdrop",Rotation=90,Color=ColorSequence.new({
  ColorSequenceKeypoint.new(0,look.back),ColorSequenceKeypoint.new(.62,look.back:Lerp(look.backDeep,.55)),ColorSequenceKeypoint.new(1,look.backDeep:Lerp(Color3.new(0,0,0),.18))})})
 self.cardLights={}
 for index=1,Stage.BackLights do
  local share=1-(index-1)/Stage.BackLights*.86
  local disc=Kit.frame(self.card,"BackLight"..index,nil,UDim2.fromScale(.5,.47),UDim2.fromScale(.94*share,.86*share))
  disc.AnchorPoint=Vector2.new(.5,.5);disc.BackgroundColor3=Color3.new(1,1,1);disc.BackgroundTransparency=.968
  Kit.node("UICorner",disc,{CornerRadius=UDim.new(.5,0)});self.cardLights[index]=disc
 end
 -- The floor the item stands on: a soft darker pool low on the card.
 self.cardFloor=Kit.frame(self.card,"FloorPool",nil,UDim2.fromScale(.5,.815),UDim2.fromScale(.6,.09))
 self.cardFloor.AnchorPoint=Vector2.new(.5,.5);self.cardFloor.BackgroundColor3=look.backDeep:Lerp(Color3.new(0,0,0),.5);self.cardFloor.BackgroundTransparency=.82
 C.gradient(self.cardFloor,0,{{0,1},{.3,0},{.7,0},{1,1}})
 Kit.node("UICorner",self.cardFloor,{CornerRadius=UDim.new(.5,0)})
 -- v850: items are centred in the card now, so a floor pool low on it read as a stray band.
 self.cardFloor.Visible=false
 local seatLayer=layer(root,"SeatLayer",6)
 self.seat=Kit.frame(seatLayer,"NativeSceneSeat",nil,UDim2.new(),UDim2.fromOffset(10,10));self.seat.AnchorPoint=Vector2.new(.5,.5)
 local sparkLayer=layer(root,"Burst",7)
 for index=1,look.shards do
  local tint=if index%3==0 then Color3.new(1,1,1)elseif index%3==1 then color else look.second
  local shard=fill(sparkLayer,"Shard"..index,tint,0);shard.Visible=false
  if index%4==0 then Kit.node("UICorner",shard,{CornerRadius=UDim.new(.5,0)})end
  self.shards[index]=shard
 end
 for index=1,look.sparkles do
  local spark=C.sparkle(sparkLayer,math.floor(14+12*hash(index,41)),if index%2==0 then color else Color3.new(1,1,1));spark.Visible=false
  self.sparkles[index]=spark
 end
 local flashLayer=layer(root,"Flash",8)
 self.flash=fill(flashLayer,"TierFlash",Color3.new(1,1,1):Lerp(color,.35),1);self.flash.AnchorPoint=Vector2.zero;self.flash.Size=UDim2.fromScale(1,1)
 -- Text: the waiting line, the rarity banner, the name and one supporting line.
 local textLayer=layer(root,"Text",9)
 self.pre=C.display(textLayer,Copy.get("hatch.display.wait"),20,Color3.fromHex("#FFF0D2"),{Name="SurpriseLabel",TextXAlignment=Enum.TextXAlignment.Center})
 self.pre.AnchorPoint=Vector2.new(.5,0)
 self.banner=Kit.frame(textLayer,"RarityBanner",nil,UDim2.new(),UDim2.fromOffset(10,10),4);self.banner.BackgroundTransparency=0;self.banner.BackgroundColor3=color
 self.banner.Rotation=-3;self.banner.Visible=false
 self.bannerText=C.display(self.banner,Stage.bannerText(self.tier,self.kind),14,Stage.inkOn(color),{Name="BannerText",TextXAlignment=Enum.TextXAlignment.Center,Size=UDim2.fromScale(1,1)})
 self.nameGroup=Kit.frame(textLayer,"NameGroup",nil,UDim2.new(),UDim2.fromOffset(10,10));self.nameGroup.Rotation=-3;self.nameGroup.Visible=false
 self.nameScale=Kit.node("UIScale",self.nameGroup,{Scale=1})
 self.nameShadow=C.display(self.nameGroup,"",40,color,{Name="NameShadow"})
 self.name=C.display(self.nameGroup,"",40,Color3.new(1,1,1),{Name="ItemName"});self.name.ZIndex=self.nameShadow.ZIndex+1
 self.underline=Kit.frame(self.nameGroup,"Underline",nil,UDim2.new(),UDim2.fromOffset(10,4),2);self.underline.BackgroundTransparency=0;self.underline.BackgroundColor3=color
 -- A tier-coloured streak behind the name, fading to the right edge (sweeps in with it).
 self.streak=Kit.frame(textLayer,"NameStreak",nil,UDim2.new(),UDim2.fromOffset(10,10));self.streak.BackgroundTransparency=.8;self.streak.BackgroundColor3=color
 self.streak.Rotation=-3;self.streak.ZIndex=textLayer.ZIndex;self.streak.Visible=false
 C.gradient(self.streak,0,{{0,1},{.08,.1},{.55,.55},{1,1}})
 -- The item's fun line (QA R1), then the host's line, stacked under the name.
 self.lines=Kit.frame(textLayer,"Lines",nil,UDim2.new(),UDim2.fromOffset(10,10));self.lines.Visible=false
 self.linesList=Kit.node("UIListLayout",self.lines,{FillDirection=Enum.FillDirection.Vertical,SortOrder=Enum.SortOrder.LayoutOrder,Padding=UDim.new(0,4)})
 self.describe=Kit.text(self.lines,"BodyMedium","","text",{Name="Description",TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
  AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),LayoutOrder=1})
 self.describe.TextColor3=Color3.fromHex("#FFF6E4");self.describe.Visible=false
 self.detail=Kit.text(self.lines,"BodyMedium","","text",{Name="Detail",TextWrapped=true,TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top,
  AutomaticSize=Enum.AutomaticSize.Y,Size=UDim2.new(1,0,0,0),LayoutOrder=2})
 self.detail.TextColor3=Color3.fromHex("#B9B4A6");self.detail.Visible=false
 -- A press anywhere before the receipt is ready skips to it; it never acts.
 self.skip=Kit.node("TextButton",root,{Name="SkipReveal",Text="",AutoButtonColor=false,BackgroundTransparency=1,Size=UDim2.fromScale(1,1),
  ZIndex=root.ZIndex+10,Selectable=false})
 self.skip:SetAttribute("AccessibleLabel",Copy.get("r1.hatchHints.hatch"))
 table.insert(self.connections,self.skip.Activated:Connect(function()
  if self:owned()and not self:inputOpen()and self.options.onSkip then self.options.onSkip()end
 end))
 local ui=layer(root,"Controls",11);self.ui=ui
 self.selectionNone=Instance.new("Frame");self.selectionNone.BackgroundTransparency=1
 for index,variant in ipairs({"secondary","primary"})do
  local button=Kit.button(ui,if variant=="primary"then "StagePrimary"else "StageSecondary",{variant=variant,text="",selectable=false})
  button.Visible=false
  local entry={node=button,primary=variant=="primary"}
  table.insert(self.connections,button.Activated:Connect(function()self:activate(entry)end))
  self.buttons[index]=entry
 end
 self.close=Kit.node("TextButton",ui,{Name="StageClose",Text="×",AutoButtonColor=false,BackgroundColor3=Stage.Card,BackgroundTransparency=.15,
  TextColor3=Color3.fromHex("#FFF0D2"),TextSize=24,Font=Enum.Font.GothamBold,Size=UDim2.fromOffset(44,44),ZIndex=ui.ZIndex+1,Selectable=false,Visible=false})
 Kit.node("UICorner",self.close,{CornerRadius=UDim.new(.5,0)})
 self.close:SetAttribute("AccessibleLabel",Copy.get("hatch.reveal.close"))
 table.insert(self.connections,self.close.Activated:Connect(function()
  if self:owned()and self:inputOpen()and self.options.onClose then self.options.onClose()end
 end))
 self.ring=Kit.focusRing(ui)
 -- The leave cover: the stage's own dark, drawn over everything while it leaves.
 self.cover=Kit.frame(root,"LeaveCover",nil,UDim2.new(),UDim2.fromScale(1,1));self.cover.ZIndex=root.ZIndex+20
 self.cover.BackgroundColor3=Stage.Backdrop;self.cover.BackgroundTransparency=1;self.cover.Visible=false
end

function Stage:inputOpen()return self.lastSample~=nil and self.lastSample.input==true end
function Stage:isSettled()return self.lastSample~=nil and self.lastSample.settled==true end
function Stage:activate(entry)
 if not self:owned()or(self.options.consumeSkipInput and self.options.consumeSkipInput())then return false end
 if not self:inputOpen()then if self.options.onSkip then self.options.onSkip()end;return false end
 local action=entry.action
 if not action or not entry.enabled or type(action.act)~="function"then return false end
 action.act();return true
end
-- Pull the host's receipt buttons and lines. Called on build, when a mirrored button
-- changes, and when the receipt becomes ready.
function Stage:refresh()
 if self.destroyed then return end
 local actions=if self.options.actions then self.options.actions()or {}else {}
 for _,entry in ipairs(self.buttons)do entry.action=nil end
 for _,action in ipairs(actions)do
  local entry=if action.primary then self.buttons[2]else self.buttons[1]
  if not entry.action then entry.action=action end
  local source=action.source
  if typeof(source)=="Instance"and not self.watched[source]then
   self.watched[source]=true
   for _,property in ipairs({"Text","Visible","Interactable"})do
    table.insert(self.connections,source:GetPropertyChangedSignal(property):Connect(function()if not self.refreshing then self:refresh()end end))
   end
  end
 end
 self.refreshing=true
 for _,entry in ipairs(self.buttons)do
  local action=entry.action;local source=action and action.source
  entry.shown=action~=nil and(source==nil or source.Visible)
  entry.enabled=entry.shown and(source==nil or source.Interactable)
  if action then Kit.setText(entry.node,if source then source.Text else action.text or "")end
  entry.live=nil -- the next paint applies enabled / visible
 end
 self.refreshing=false
 self:pullText()
 self.staticDone=false
 self:paintFocus()
end
-- The name and the supporting line, only once the receipt is ready (disclosure rule).
function Stage:pullText()
 if not self:inputOpen()then return end
 local name=if self.options.name then self.options.name()else nil
 if type(name)=="string"and name~=""and self.nameValue~=name then
  self.nameValue=name;self.name.Text=string.upper(name);self.nameShadow.Text=self.name.Text
  self.root:SetAttribute("AccessibleLabel",name);self:layoutText()
 end
 local detail=if self.options.detail then self.options.detail()else nil
 if type(detail)=="string"and self.detail.Text~=detail then self.detail.Text=detail end
 local describe
 if self.options.description then describe=self.options.description()else describe=Stage.describe(self.kind,self.options.result)end
 if type(describe)=="string"and self.describe.Text~=describe then self.describe.Text=describe end
end
function Stage:paintFocus()
 if self.destroyed or not self.ring then return end
 local selected=GuiService.SelectedObject
 for _,entry in ipairs(self.buttons)do
  if entry.action and entry.action.source==selected and selected~=nil and entry.node.Visible and not Kit.lastInputTouch()then self.ring.attach(entry.node,12);return end
 end
 self.ring.hide()
end

function Stage:layout()
 if self.destroyed then return end
 local size=self.root.AbsoluteSize;local W,H=math.max(1,size.X),math.max(1,size.Y)
 local L=Stage.geometry(W,H);self.L=L;self.staticDone=false
 self.seat.Size=UDim2.fromOffset(L.seat,L.seat)
 self.card.Size=UDim2.fromOffset(L.cardW,L.cardH)
 local corner=math.max(10,math.floor(L.seat*.09));self.cardCorner.CornerRadius=UDim.new(0,corner)
 self.cardStroke.Thickness=math.max(2,math.floor(L.seat*.014+.5))
 self.rayGroup.Size=UDim2.fromOffset(L.seat*3.2,L.seat*3.2)
 for index,ray in ipairs(self.rays)do
  ray.Size=UDim2.new(0,math.max(6,math.floor(L.seat*(if index%2==0 then .05 else .10))),1,0)
 end
 self.pre.TextSize=math.floor(L.preSize);self.pre.Size=UDim2.fromOffset(W,math.floor(L.preSize*1.6));self.pre.Position=UDim2.fromOffset(W*.5,L.preY)
 local bannerSize=math.floor(L.bannerSize);self.bannerText.TextSize=bannerSize
 local bw=C.measure(self.bannerText.Text,bannerSize).X+math.floor(bannerSize*1.6)
 self.bannerW=bw;self.banner.Size=UDim2.fromOffset(bw,math.floor(bannerSize*1.7))
 self.describe.TextSize=math.floor(L.detailSize);self.detail.TextSize=math.max(12,math.floor(L.detailSize*.9))
 self.lines.Position=UDim2.fromOffset(L.textX,L.detailY);self.lines.Size=UDim2.fromOffset(L.textW,math.floor(L.detailSize*4.4))
 local align=if L.landscape then Enum.TextXAlignment.Left else Enum.TextXAlignment.Center
 self.describe.TextXAlignment=align;self.detail.TextXAlignment=align
 local bwidth=math.floor((L.btnW-L.gap)/2);if not L.phone then bwidth=math.min(bwidth,math.floor(340*L.s)+40)end
 local right=L.btnX+L.btnW
 for index=2,1,-1 do
  local entry=self.buttons[index]
  entry.node.Size=UDim2.fromOffset(bwidth,L.btnH)
  local state=Kit.buttonState(entry.node);if state then state.label.TextSize=L.btnText;state.label.Size=UDim2.fromOffset(0,L.btnH)end
  right-=bwidth;entry.x=right;right-=L.gap
 end
 local safe,bar=Stage.safeArea(self.root)
 local closeX,closeY=Stage.closeRect(W,H,L.phone,safe,bar)
 self.close.Position=UDim2.fromOffset(closeX,closeY)
 self:layoutText()
 if self.scene and not self.scene.destroyed then self.scene:layout()end
 self:paint()
end
-- The name shrinks to its column (never below 18 px) instead of clipping.
function Stage:layoutText()
 local L=self.L;if not L then return end
 local text=self.name.Text
 local wanted=C.measure(text,L.nameSize).X
 local size=if wanted>L.textW-12 then math.max(18,math.floor(L.nameSize*(L.textW-12)/math.max(1,wanted)))else math.floor(L.nameSize)
 self.name.TextSize=size;self.nameShadow.TextSize=size
 local w=C.measure(text,size).X+8;local h=math.floor(size*1.2)
 local drop=math.max(2,math.floor(size*.06))
 self.name.Position,self.name.Size=UDim2.new(),UDim2.fromOffset(w,h)
 self.nameShadow.Position,self.nameShadow.Size=UDim2.fromOffset(drop,drop),UDim2.fromOffset(w,h)
 self.nameW,self.nameH=w,h
 self.underline.Position=UDim2.fromOffset(0,h);self.underlineH=math.max(3,math.floor(size*.09))
 self.nameGroup.Size=UDim2.fromOffset(w+drop,h+self.underlineH+2)
 -- The name group is tilted 3 degrees about its centre, so its left end sits lower: the
 -- supporting line starts under that end.
 local sink=math.ceil(w*.5*math.sin(math.rad(3)))
 self.lines.Position=UDim2.fromOffset(L.textX,L.nameY+h+self.underlineH+sink+math.floor(L.detailSize*.5))
 self.streak.Size=UDim2.fromOffset(L.W,math.floor(h*1.25))
end

function Stage:currentSample()
 local reduced=self.reducedStart or self:reduced()
 return Stage.sample(self.age,reduced)
end
function Stage:paint()
 local L=self.L;if not L or self.destroyed then return end
 local s=self:currentSample();local was=self.lastSample;self.lastSample=s
 if s.input and not(was and was.input)then self:refresh()
 elseif s.input and not self.staticDone then self:pullText()end -- the host fills its lines a frame later
 local look=self.look;local clock=self.clock;local reduced=s.reduced
 local still=reduced or self.instant
 -- Idle path: only the slow turn and the twinkles move once settled.
 if self.staticDone and s.settled then self:paintIdle(s,still);return end
 -- The dim follows real time from the moment the stage opens (the egg may still be loading,
 -- or waiting for its window). The egg fades in with it and eases up to size (QA R4).
 -- (`openElapsed` is a capture fixture's fixed clock.)
 local opening=C.openSample(self.openElapsed or math.max(os.clock()-self.openedAt,s.t))
 local dim=if reduced then s.fade else opening.dim
 local openScale=if still then 1 else opening.scale
 if self.scene and type(self.scene.setVeil)=="function"then self.scene:setVeil(if still then 0 else 1-opening.content)end
 -- The screen dims all the way to a dark stage (the pet reveal's is black too), so the
 -- garden and the host's receipt card underneath never ghost through.
 self.root.BackgroundTransparency=1-Stage.Dim*(if self.instant then 1 else dim)
 -- The showcase centre: the egg plays in the middle, then the card flies to its seat.
 local slide=if still then 1 else s.slide
 local shake=if still then 0 else s.shake*look.shake*math.max(.6,L.s)
 local cx=L.cx0+(L.cx1-L.cx0)*slide+math.sin(clock*47)*shake
 local cy=L.cy0+(L.cy1-L.cy0)*slide+math.cos(clock*39)*shake*.5
 self.cx,self.cy=cx,cy
 -- The egg plays large; the scene eases down to the card's size as the card flies.
 local seat=math.floor(L.seat*(1+(Stage.EggScale-1)*(1-slide))*openScale+.5)
 self.seat.Position=UDim2.fromOffset(cx,cy);self.seat.Size=UDim2.fromOffset(seat,seat)
 -- Glow and beam: they build with the wobble, flare at the burst, then rest.
 local build=if still then 1 else s.build
 local beam=if still then .55 else s.beam
 local glowSize=L.seat*(1.0+.7*build)*(.9+.3*look.beam)
 local glowAlpha=math.min(.5,(.03+.33*build)*(.6+.5*look.beam))*(if reduced then s.fade else 1)
 -- Each disc adds a little; together they reach `glowAlpha` at the centre.
 local discAlpha=1-(1-glowAlpha)^(1/#self.glow)
 for index,disc in ipairs(self.glow)do
  local share=1-(index-1)/#self.glow*.88
  disc.Position=UDim2.fromOffset(cx,cy);disc.Size=UDim2.fromOffset(glowSize*1.3*share,glowSize*share);disc.BackgroundTransparency=1-discAlpha
 end
 local wide=L.seat*(.30+.55*build)*look.beam*math.min(1.5,.75+beam*.5)
 self.beamWide.Position=UDim2.fromOffset(cx,L.H*.5);self.beamWide.Size=UDim2.fromOffset(wide,L.H*1.2)
 self.beamWide.BackgroundTransparency=1-math.min(.85,.42*beam*(.5+.5*look.beam))*(if reduced then s.fade else 1)
 self.beamCore.Position=UDim2.fromOffset(cx,L.H*.5);self.beamCore.Size=UDim2.fromOffset(math.max(2,wide*.30),L.H*1.2)
 self.beamCore.BackgroundTransparency=1-math.min(.9,.36*beam*look.beam)*(if reduced then s.fade else 1)
 -- Rays.
 local rays=if still then 1 else s.rays
 self.rayGroup.Position=UDim2.fromOffset(cx,cy);self.rayGroup.Visible=rays>0
 local rayAlpha=(if s.settled or still then .16 else .16+.30*(1-ramp(s.t,Stage.BurstAt+.2,.7)))*rays*(.55+.45*look.beam)
 for _,ray in ipairs(self.rays)do ray.BackgroundTransparency=1-rayAlpha end
 self.rayGroup.Rotation=if reduced then 0 else clock*look.spin
 -- Burst: flash, rings and shards (never under Reduced Motion or on a reopen).
 local burst=if still then math.huge else s.burstAge
 self.flash.BackgroundTransparency=1-(if still then 0 else look.flash*s.flash)
 for index,ring in ipairs(self.rings)do
  local age=burst-(index-1)*.12
  local on=age>=0 and age<Stage.RingLife
  ring.node.Visible=on
  if on then
   local u=quadOut(age/Stage.RingLife);local d=L.seat*(.4+2.2*u)
   ring.node.Position=UDim2.fromOffset(cx,cy);ring.node.Size=UDim2.fromOffset(d,d)
   ring.stroke.Transparency=u;ring.stroke.Thickness=math.max(1,5*(1-u)*math.max(.7,L.s*1.5))
  end
 end
 local long=math.max(6,math.floor(L.seat*.055));local short=math.max(3,math.floor(long*.45))
 for index,shard in ipairs(self.shards)do
  local x,y,rotation,fade=Stage.shard(index,#self.shards,burst)
  shard.Visible=x~=nil
  if x then
   shard.Position=UDim2.fromOffset(cx+x*L.seat,cy+y*L.seat)
   shard.Size=UDim2.fromOffset(long*(.6+.8*hash(index,25)),short);shard.Rotation=rotation;shard.BackgroundTransparency=1-fade
  end
 end
 self:paintSparkles(s,still)
 -- Card flip: the width opens from an edge-on sliver with a little overshoot.
 local card=if still then 1 else s.card
 self.card.Visible=card>.02
 self.card.Position=UDim2.fromOffset(cx,cy);self.card.Size=UDim2.fromOffset(math.max(2,L.cardW*math.abs(card)),L.cardH*(.86+.14*math.min(1,card)))
 self.card.BackgroundTransparency=0
 -- Waiting line.
 local pre=if still then 0 else s.pre
 self.pre.Visible=pre>0;self.pre.TextTransparency=1-pre*(if still then 1 else opening.content)
 -- Banner slides in from the right; the name slams (2.3x -> 1 with an overshoot).
 local banner=s.banner
 self.banner.Visible=banner>0 and s.named
 local bannerX=if L.landscape then L.textX else math.floor((L.W-(self.bannerW or 0))*.5)
 self.banner.Position=UDim2.fromOffset(bannerX+(1-banner)*L.W*.5,L.bannerY)
 self.nameGroup.Visible=s.named and self.nameValue~=nil
 local nameX=if L.landscape then L.textX else math.floor((L.W-(self.nameW or 0))*.5)
 self.nameGroup.Position=UDim2.fromOffset(nameX,L.nameY)
 self.nameScale.Scale=if reduced or s.t>=Pose.ItemReady+.22 then 1 else math.max(.2,2.3-1.3*s.name)
 local nameAlpha=if reduced then s.fade else math.min(1,ramp(s.t,Pose.ItemReady,.08))
 self.name.TextTransparency=1-nameAlpha;self.nameShadow.TextTransparency=1-nameAlpha
 self.underline.Size=UDim2.fromOffset(math.max(1,(self.nameW or 1)*.86*math.clamp(s.name,0,1)),self.underlineH or 4)
 self.streak.Visible=self.nameGroup.Visible and L.landscape
 self.streak.Position=UDim2.fromOffset(nameX-math.floor(L.nameSize*.5)+(1-math.clamp(s.name,0,1))*L.W*.4,L.nameY-math.floor((self.nameH or 0)*.06))
 self.streak.BackgroundTransparency=1-(.16+.10*look.beam)*nameAlpha
 -- The fun line arrives first, the host's line just behind it.
 self.lines.Visible=s.detail>0
 self.describe.Visible=s.detail>0 and self.describe.Text~="";self.describe.TextTransparency=1-s.detail
 local late=if reduced then s.detail else math.clamp(s.detail*2-1,0,1)
 self.detail.Visible=late>0 and self.detail.Text~="";self.detail.TextTransparency=1-late
 -- Actions rise in; the close sits in the top-right corner.
 local rise=(1-s.buttons)*12
 for _,entry in ipairs(self.buttons)do
  entry.node.Visible=s.input and entry.shown==true
  entry.node.Position=UDim2.fromOffset(entry.x or 0,L.btnY+rise)
  local live=entry.enabled==true and s.input
  if entry.live~=live then entry.live=live;Kit.setEnabled(entry.node,live)end
 end
 self.close.Visible=s.input and self.options.onClose~=nil
 self.skip.Visible=not s.input;self.skip.Active=not s.input
 self.root:SetAttribute("InputLocked",not s.input);self.root:SetAttribute("ReceiptReady",s.input)
 self:paintSpin(s)
 if s.settled and opening.done then self.staticDone=true;self:paintFocus()end
end
function Stage:paintSparkles(s,still)
 local L=self.L;local on=(s.named or still)and not s.reduced
 for index,spark in ipairs(self.sparkles)do
  if spark.Visible~=on then spark.Visible=on end
  if on then
   local a=hash(index,42)*math.pi*2;local r=L.seat*(.52+.30*hash(index,43))
   spark.Position=UDim2.fromOffset((self.cx or L.cx1)+math.cos(a)*r,(self.cy or L.cy1)+math.sin(a)*r*.85)
   local tw=.5+.5*math.sin(self.clock*(2.0+hash(index,44)*1.6)+index*1.7)
   C.fadeSparkle(spark,math.floor((1-tw)*20+.5)/20)
  end
 end
end
-- QA R2: a 3D result turns slowly once its name is out. Never under Reduced Motion; a
-- reopened receipt turns too (it is the idle, not the entrance).
function Stage:paintSpin(s)
 local scene=self.scene
 if not scene or scene.destroyed or type(scene.setSpin)~="function"then return end
 if s.reduced or self:reduced()or not s.named then
  if self.spinning then self.spinning=false;self.spinFrom=nil;scene:setSpin(0)end
  return
 end
 self.spinFrom=self.spinFrom or self.clock
 self.spinning=scene:setSpin(Stage.spinAt(self.clock-self.spinFrom))
end
function Stage:paintIdle(s,still)
 self:paintSpin(s)
 if s.reduced then return end
 if self.look.spin~=0 then self.rayGroup.Rotation=self.clock*self.look.spin end
 if #self.sparkles>0 then self:paintSparkles(s,still)end
end

-- The hatch clock (HatchCinematic:paint). The stage's own frame clock only animates.
function Stage:updateExternal(age,sample)
 if self.destroyed then return end
 self.age=math.max(0,age or 0);self.poseSample=sample
end
-- QA R4: leave instead of vanishing. The stage moves to its own top-level gui (its host may
-- hide or change page in the same frame), stops taking input, lets its content sink into the
-- dark, then lifts the dark off whatever is underneath. `after` runs once it is gone (the
-- reveal keeps the borrowed scene alive until then). False (and nothing done) when the stage
-- was not on screen in the last moment: the caller destroys it as before.
function Stage:dismiss(after)
 if self.destroyed or self.leaving then return false end
 if not self.seenAt or os.clock()-self.seenAt>.1 then return false end
 local gui=C.detach(self.root);if not gui then return false end
 self.leaving={at=os.clock(),gui=gui,after=after,seat=self.seat.Size,card=self.card.Size}
 if self.connection then self.connection:Disconnect();self.connection=nil end
 for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
 if self.ring then self.ring.hide()end
 self.root.Active=false;self.root.Interactable=false;self.skip.Visible=false
 self.root:SetAttribute("Leaving",true)
 self.cover.Visible=true
 self.connection=RunService.RenderStepped:Connect(function()self:paintLeave()end)
 self:paintLeave()
 return true
end
function Stage:paintLeave(elapsed)
 local leave=self.leaving;if not leave or self.destroyed then return end
 local s=C.leaveSample(elapsed or os.clock()-leave.at)
 if s.done then
  local after=leave.after;self:destroy()
  if after then after()end
  return
 end
 if s.lift<=0 then
  self.cover.BackgroundTransparency=1-s.content
  if not self:reduced()then
   self.seat.Size=UDim2.fromOffset(leave.seat.X.Offset*s.scale,leave.seat.Y.Offset*s.scale)
   self.card.Size=UDim2.fromOffset(leave.card.X.Offset*s.scale,leave.card.Y.Offset*s.scale)
  end
  return
 end
 if not leave.cleared then
  leave.cleared=true
  for _,child in ipairs(self.root:GetChildren())do if child:IsA("GuiObject")and child~=self.cover then child.Visible=false end end
  self.root.BackgroundTransparency=1
 end
 self.cover.BackgroundTransparency=s.lift
end
function Stage:step(dt)
 if self.destroyed or self.leaving then return end
 if C.onScreen(self.root)then self.seenAt=os.clock()end
 -- Without its owner (a hidden screen, an unfocused window) nothing animates, but the frame
 -- still follows the host's layout.
 if self:owned()then self.clock+=math.clamp(dt,0,.1)end
 self:paint()
end
function Stage:getStats()
 local s=self.lastSample or Stage.sample(self.age,false)
 return {age=self.age,tier=self.tier,kind=self.kind,settled=s.settled,input=s.input,named=self.nameValue,instant=self.instant,
  shards=#self.shards,rays=#self.rays,rings=#self.rings,sparkles=#self.sparkles,sharedScene=true,externalClock=true,
  phone=self.L and self.L.phone,landscape=self.L and self.L.landscape}
end
function Stage:destroy()
 if self.destroyed then return end
 self.destroyed=true
 if self.connection then self.connection:Disconnect();self.connection=nil end
 for _,c in ipairs(self.connections)do c:Disconnect()end;table.clear(self.connections)
 if self.ring then self.ring.hide()end
 local scene=self.scene;self.scene=nil
 if scene and not scene.destroyed then scene:release(self.borrowToken)end
 self.root:Destroy()
 if self.leaving and self.leaving.gui then self.leaving.gui:Destroy()end
 if self.selectionNone then self.selectionNone:Destroy()end
end
return Stage
