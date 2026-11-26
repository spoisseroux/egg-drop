-- The Pocket Deck juice pass (AERO-JUICE-BRIEF 2, Fable 2026-11-26; Spencer: "make the game much more asmr-y and
-- satisfying to play ... but keep it still working"). Presentation only: nothing here reads or writes BoardSim,
-- BoardRoundSim, the lockstep or any server state; it is told about merges, drops and contacts after they happened and
-- draws, plays and buzzes on top. Behind Alive "deckjuice" (AliveDeckJuice, beta and Studio, ConfigService
-- `alive_deckjuice`, owner chat /alive deckjuice on|off|clear) so it can be compared with the deck as it was.
--
-- P1 the merge: the impact frame and the IV/V hold (JellyLCD, `hold`), the lobes' squash, the overshoot wobble 1.10,
--    .96, 1.02, 1.0 over 260 ms, a second ring on IV and V (FieldEffects), glass beads with gravity (6; 12 on tier V
--    and clears, 12 at most), neighbours' faces bumped 1 px away (6 at most), three sound layers at most (body by
--    tier, the sparkle from chain 2, the sub on IV, V and clears), the music ducked 2 dB on V and clears, and the drop
--    and land buzzes (Haptics, my own board only). The shake (DeckMergeJolt) is unchanged.
-- P2 combos: chain 3 tints the well's top shadow, 4 sends beads up both banks, 5 and up punches one praise word, 7 and
--    up sweeps the faceplate's gloss; nothing stacks on a clear.
-- P3 drop and land: the held ball breathes, the dropped one stretches, the first contact squashes with two dust
--    beads, the land cue pitched by tier and the land buzz; the aim dots drift.
-- P4 idle life: a glint twinkle, the matching ball's bloom pulse, a bubble up the well after 5 s without a drop.
-- P5 lives in AeroUI (rolling counters, caustics, scanline, glints, press, goal chips).
--
-- Phone budget: pools only (12 beads, 8 bubbles, made once), at most MaxWrites property writes a frame (hides always
-- go through), at most 6 one-shot voices a merge. AliveBudget level 1: no caustics, no idle bubbles, a single ring.
-- Level 2: the body sound, the overshoot and the buzz only. Reduced Motion: no hold, beads, wobble, sweeps, scrolls
-- or drift; counters jump; sound, buzz and slow colour tints stay.
local Shared=game:GetService("ReplicatedStorage").Shared
local Alive=require(Shared.Alive)
local Themes=require(Shared.BallThemes)
local UICopy=require(Shared.UICopy)
local Config=require(Shared.BoardConfig)
local Budget=require(script.Parent.AliveBudget)

local Juice={};Juice.__index=Juice
Juice.Feature="deckjuice"

-- ── Numbers (the brief's) ───────────────────────────────────────────────────────────────────────────────────────
Juice.Hold=.04 -- tiers IV and V: the impact frame held this long (presentation only)
Juice.HoldFrom=4
Juice.Overshoot=table.freeze({table.freeze({0,1.10}),table.freeze({.09,.96}),table.freeze({.17,1.02}),table.freeze({.26,1})})
Juice.Beads=table.freeze({count=6,big=12,max=12,life=.45,reach=2.6})
Juice.Nudge=table.freeze({reach=1.5,max=6,seconds=.12})
Juice.TierPitch=table.freeze({1.12,1,.92,.84,.76})
Juice.ChainSemitones=table.freeze({0,2,4,5,7,9,11,12}) -- BoardAudio.ChainSemitones
Juice.Gain=table.freeze({body=.56,sparkle=.18,sub=.35,land=.34})
Juice.Jitter=table.freeze({speed=.03,db=1})
Juice.Duck=table.freeze({seconds=.25,db=2})
Juice.Sparkle=table.freeze({"merge_glass_tick_a","merge_glass_tick_b","merge_glass_tick_c"})
Juice.Combo=table.freeze({tint=3,banks=4,praise=5,sweep=7})
Juice.TintFor,Juice.PraiseFor,Juice.SweepFor,Juice.BankBeads=.3,.6,.4,4
Juice.Praise=table.freeze({{5,"deck.praise.bubbly"},{6,"deck.praise.fizzy"},{7,"deck.praise.sparkly"},{8,"deck.praise.sky"}})
Juice.PunchScale=1.45
Juice.Breath=table.freeze({amp=.03,period=1.6})
Juice.Stretch=table.freeze({amount=.06,seconds=.08})
Juice.Land=table.freeze({amount=.10,seconds=.14,dust=2})
Juice.AimDrift=6 -- LCD px a second
Juice.Twinkle=table.freeze({min=1.2,max=2.5,seconds=.12})
Juice.Pulse=table.freeze({amp=.15,hz=.8})
Juice.Idle=table.freeze({after=5,every=2,max=3,rise=22})
Juice.BubblePool=8
Juice.Scan=table.freeze({every=7,travel=.9,alpha=.05,height=2})
Juice.MaxWrites=40

-- What runs at an AliveBudget level and under Reduced Motion (pure).
local LevelTwo=table.freeze({body=true,overshoot=true,haptics=true})
local LevelOneOff=table.freeze({caustics=true,bubbles=true,echo=true})
local ReducedOff=table.freeze({hold=true,squash=true,overshoot=true,beads=true,nudge=true,banks=true,sweep=true,breath=true,
 stretch=true,landsquash=true,dust=true,drift=true,twinkle=true,bubbles=true,counters=true,caustics=true,scanline=true,
 glint=true,press=true,chips=true,punch=true,echo=true})
Juice.Features=table.freeze({"hold","squash","overshoot","echo","beads","nudge","body","sparkle","sub","duck","haptics",
 "tint","banks","praise","punch","sweep","breath","stretch","landsquash","dust","landcue","drift","twinkle","pulse",
 "bubbles","counters","caustics","scanline","glint","press","chips"})
function Juice.allows(feature,level,reduced)
 if not table.find(Juice.Features,feature)then return false end
 level=level or 0
 if level>=2 and not LevelTwo[feature]then return false end
 if level>=1 and LevelOneOff[feature]then return false end
 if reduced and ReducedOff[feature]then return false end
 return true
end

-- The switch. Specs set an override (true / false / nil = the real switch).
local override=nil
function Juice.setSwitch(value)override=value end
function Juice.switch()
 if override~=nil then return override==true end
 local ok,on=pcall(Alive.on,Juice.Feature)
 return ok and on==true
end

-- ── Pure shapes ─────────────────────────────────────────────────────────────────────────────────────────────────
-- The merge's presentation hold for a tier (seconds).
function Juice.holdFor(tier)return if(tier or 1)>=Juice.HoldFrom then Juice.Hold else 0 end
-- The overshoot scale `t` seconds after the blob hands over; nil once it is over (1.0).
function Juice.overshoot(t)
 local keys=Juice.Overshoot
 if t<0 then return keys[1][2]end
 if t>=keys[#keys][1]then return nil end
 for i=2,#keys do
  local a,b=keys[i-1],keys[i]
  if t<=b[1]then local u=(t-a[1])/(b[1]-a[1]);u=u*u*(3-2*u);return a[2]+(b[2]-a[2])*u end
 end
 return nil
end
function Juice.beadCount(tier,cleared)return if cleared or(tier or 1)>=5 then Juice.Beads.big else Juice.Beads.count end
-- Bead `j` of `n` from a merge of `radius` px: start velocity (px/s) and size (px).
function Juice.beadStart(j,n,radius,tier)
 local angle=(j-1)*2*math.pi/n+.35
 local speed=radius*(Juice.Beads.reach+.2*math.clamp(tier or 1,1,5))/Juice.Beads.life
 return math.cos(angle)*speed,math.sin(angle)*speed-speed*.35,math.clamp(radius*.18,3,9)
end
-- A bead's offset and look `t` seconds in: x, y (px from its start), size scale, transparency.
function Juice.beadAt(vx,vy,t,life,gravity)
 local u=math.clamp(t/life,0,1)
 return vx*t,vy*t+.5*gravity*t*t,1-.35*u,.05+.95*math.clamp((u-.6)/.4,0,1)
end
-- What a chain earns (nothing on a clear: the clear has its own).
function Juice.combo(chain,cleared)
 chain=math.floor(tonumber(chain)or 1)
 if cleared then return{tint=false,banks=false,praise=nil,sweep=false}end
 local key=nil
 for _,row in ipairs(Juice.Praise)do if chain>=row[1]then key=row[2]end end
 return{tint=chain>=Juice.Combo.tint,banks=chain>=Juice.Combo.banks,praise=key,sweep=chain>=Juice.Combo.sweep}
end
function Juice.praiseText(chain)
 local key=Juice.combo(chain,false).praise
 return if key then UICopy.get(key)else nil
end
-- Sound (pure; r1..r3 are 0..1 random numbers). Body: bubble on tiers I to III, jelly on IV and V, down by tier, up the
-- chain's scale (held at the octave past chain 8).
local function semis(chain)
 chain=math.max(1,math.floor(tonumber(chain)or 1))
 return Juice.ChainSemitones[math.min(chain,#Juice.ChainSemitones)]
end
local function jitter(r1,r2)
 return 1+(r1*2-1)*Juice.Jitter.speed,10^((r2*2-1)*Juice.Jitter.db/20)
end
function Juice.bodyPlay(tier,chain,r1,r2)
 tier=math.clamp(math.floor(tonumber(tier)or 2),1,5)
 local speed,gain=jitter(r1 or .5,r2 or .5)
 return(if tier<=3 then "merge_bubble"else "merge_jelly"),Juice.TierPitch[tier]*2^(semis(chain)/12)*speed,Juice.Gain.body*gain
end
-- Sparkle: chain 2 and up; never the same variant twice running; an octave up past chain 8.
function Juice.sparklePlay(chain,r1,r2,r3,last)
 local list=Juice.Sparkle
 local choices={}
 for _,cue in ipairs(list)do if cue~=last then table.insert(choices,cue)end end
 local cue=choices[math.clamp(math.floor((r3 or 0)*#choices)+1,1,#choices)]
 local speed,gain=jitter(r1 or .5,r2 or .5)
 local octave=if(tonumber(chain)or 1)>#Juice.ChainSemitones then 2 else 1
 return cue,2^(semis(chain)/12)*octave*speed,Juice.Gain.sparkle*gain
end
function Juice.subPlay(tier,cleared,r1,r2)
 if not(cleared or(tier or 1)>=4)then return nil end
 local speed,gain=jitter(r1 or .5,r2 or .5)
 return "merge_thump",speed,Juice.Gain.sub*gain
end
-- Which layers a merge plays (three at most): body always, sparkle on chain 2+ or a clear, sub on IV, V and clears.
function Juice.layers(tier,chain,cleared)
 local out={"body"}
 if cleared or(tonumber(chain)or 1)>=2 then table.insert(out,"sparkle")end
 if cleared or(tier or 1)>=4 then table.insert(out,"sub")end
 return out
end
function Juice.ducks(tier,cleared)return cleared==true or(tier or 1)>=5 end
function Juice.breath(now)return 1+Juice.Breath.amp*math.sin(now*2*math.pi/Juice.Breath.period)end
-- The dropped ball's stretch along its fall (`age` seconds old): long and narrow scales, or nil when over.
function Juice.stretch(age)
 if age<0 or age>=Juice.Stretch.seconds then return nil end
 local k=Juice.Stretch.amount*(1-age/Juice.Stretch.seconds)
 return 1/(1+k*.5),1+k
end
-- The first contact's squash `age` seconds in: wide and short scales, or nil when recovered.
function Juice.landSquash(age)
 if age<0 or age>=Juice.Land.seconds then return nil end
 local u=1-age/Juice.Land.seconds;local k=Juice.Land.amount*u*u
 return 1+k*.5,1-k
end
function Juice.pulse(now)return 1+Juice.Pulse.amp*math.sin(now*2*math.pi*Juice.Pulse.hz)end
-- The aim dots' phase (0..1 of a step) at `now`, for a step `spacing` LCD px long.
function Juice.drift(now,spacing)return(now*Juice.AimDrift/math.max(.5,spacing))%1 end
-- Neighbours of a merge at (x, y) (world units) within reach x the result's radius: up to max {id, dir}.
function Juice.nudges(list,x,y,radius,except,out)
 out=out or {};table.clear(out)
 local reach=Juice.Nudge.reach*radius
 for _,b in ipairs(list)do
  if #out>=Juice.Nudge.max then break end
  if b.id~=except then
   local dx,dy=b.x-x,b.y-y
   local gap=reach+(b.radius or 0)
   if dx*dx+dy*dy<gap*gap and math.abs(dx)>.01 then table.insert(out,{id=b.id,dir=if dx>0 then 1 else -1})end
  end
 end
 return out
end
-- Idle bubbles: one is due when the board has been still `after` s, `every` s apart, fewer than `max` up.
function Juice.bubbleDue(now,lastDrop,lastBubble,active)
 return now-lastDrop>=Juice.Idle.after and now-lastBubble>=Juice.Idle.every and active<Juice.Idle.max
end
-- The next twinkle `r` (0..1) after now.
function Juice.nextTwinkle(now,r)return now+Juice.Twinkle.min+(Juice.Twinkle.max-Juice.Twinkle.min)*(r or .5)end

-- ── The layer ───────────────────────────────────────────────────────────────────────────────────────────────────
-- options: parent (the board's effects frame, overlay px), audio (BoardAudio), faces (BallFaces), haptics, deck
-- (function -> DeckScreen or nil), reduced (function), random (function -> 0..1; specs pass one).
function Juice.new(options)
 options=options or {}
 local rng=Random.new()
 local self=setmetatable({parent=options.parent,audio=options.audio,faces=options.faces,haptics=options.haptics,
  deckOf=options.deck or function()return nil end,reducedOf=options.reduced or function()return false end,
  random=options.random or function()return rng:NextNumber()end,
  isOn=false,level=0,reduced=false,checkedAt=-math.huge,
  born={},landed={},seen={},seenCount=0,nudgeOut={},
  lastDrop=-math.huge,lastBubble=-math.huge,twinkleId=nil,twinkleUntil=0,nextTwinkleAt=0,lastSparkle=nil,nextScan=0,
  stats={writes=0,frame=0,peak=0,beads=0,bubbles=0,skipped=0}},Juice)
 return self
end
function Juice:refresh(now)
 if now-self.checkedAt<.5 then return end
 self.checkedAt=now
 self.isOn=Juice.switch()
 self.level=Budget.level()
 local ok,reduced=pcall(self.reducedOf);self.reduced=ok and reduced==true
end
function Juice:can(feature)return self.isOn and Juice.allows(feature,self.level,self.reduced)end
-- The hold a merge of `tier` is drawn with: nil while the switch is off (JellyLCD draws it as before).
function Juice:mergeHold(tier)
 if not self.isOn then return nil end
 if self:can("hold")then return Juice.holdFor(tier)end
 return if self:can("squash")then 0 else nil -- level 2 and Reduced Motion: the classic blob
end

local function put(self,object,key,value,force)
 if object[key]==value then return end
 if not force and self.stats.frame>=Juice.MaxWrites then self.stats.skipped+=1;return end
 object[key]=value;self.stats.frame+=1;self.stats.writes+=1
end
local function frame(parent,name,z)
 local f=Instance.new("Frame");f.Name=name;f.BorderSizePixel=0;f.BackgroundTransparency=1;f.Active=false;f.Selectable=false
 f.AnchorPoint=Vector2.new(.5,.5);f.ZIndex=z or 6;f.Visible=false;f.Parent=parent
 return f
end
local function round(parent)local c=Instance.new("UICorner");c.CornerRadius=UDim.new(.5,0);c.Parent=parent;return c end
function Juice:build()
 if self.root or not self.parent then return end
 local root=Instance.new("Frame");root.Name="AeroJuice";root.BackgroundTransparency=1;root.Size=UDim2.fromScale(1,1)
 root.Active,root.Selectable,root.ClipsDescendants=false,false,true;root.ZIndex=6;root.Parent=self.parent
 self.root=root
 self.beads={}
 for i=1,Juice.Beads.max do
  local f=frame(root,"Bead"..i,7);round(f);f.BackgroundColor3=Color3.new(1,1,1)
  local spec=frame(f,"Spec",8);round(spec);spec.AnchorPoint=Vector2.zero;spec.Position=UDim2.fromScale(.2,.16);spec.Size=UDim2.fromScale(.34,.34)
  spec.BackgroundColor3=Color3.new(1,1,1);spec.BackgroundTransparency=.1;spec.Visible=true
  self.beads[i]={node=f,active=false,start=0}
 end
 self.bubbles={}
 for i=1,Juice.BubblePool do
  local f=frame(root,"Bubble"..i,6);round(f);f.BackgroundColor3=Color3.new(1,1,1)
  local rim=Instance.new("UIStroke");rim.Color=Color3.new(1,1,1);rim.Thickness=1;rim.Transparency=.45;rim.Parent=f
  local spec=frame(f,"Spec",7);round(spec);spec.AnchorPoint=Vector2.zero;spec.Position=UDim2.fromScale(.22,.18);spec.Size=UDim2.fromOffset(2,2)
  spec.BackgroundColor3=Color3.new(1,1,1);spec.BackgroundTransparency=.2;spec.Visible=true
  self.bubbles[i]={node=f,rim=rim,active=false,start=0}
 end
 local tint=Instance.new("Frame");tint.Name="WellTint";tint.BorderSizePixel=0;tint.Active=false;tint.Size=UDim2.fromScale(1,.07)
 tint.BackgroundTransparency=1;tint.ZIndex=5;tint.Visible=false;tint.Parent=root
 local fade=Instance.new("UIGradient");fade.Rotation=90;fade.Transparency=NumberSequence.new(.3,1);fade.Parent=tint
 self.tint=tint
 local word=Instance.new("TextLabel");word.Name="Praise";word.BackgroundTransparency=1;word.BorderSizePixel=0;word.Active=false
 word.AnchorPoint=Vector2.new(.5,.5);word.Position=UDim2.fromScale(.5,.3);word.Size=UDim2.new(1,-8,0,40);word.ZIndex=9;word.Visible=false
 word.Font=Enum.Font.GothamBlack;word.TextSize=26;word.TextColor3=Color3.new(1,1,1);word.TextStrokeColor3=Color3.fromHex("#15102B")
 word.TextStrokeTransparency=.15;word.Parent=root
 self.word=word
 local scan=Instance.new("Frame");scan.Name="Scanline";scan.BorderSizePixel=0;scan.Active=false;scan.BackgroundColor3=Color3.new(1,1,1)
 scan.BackgroundTransparency=1-Juice.Scan.alpha;scan.Size=UDim2.new(1,0,0,Juice.Scan.height);scan.ZIndex=8;scan.Visible=false;scan.Parent=root
 self.scan=scan
 -- P5: the light-net on the well too (AeroUI; nothing until its image is uploaded).
 pcall(function()require(script.Parent.AeroUI).caustics(root)end)
 self.stats.instances=#root:GetDescendants()+1
end
function Juice:hideAll()
 if not self.root then return end
 for _,b in ipairs(self.beads)do b.active=false;put(self,b.node,"Visible",false,true)end
 for _,b in ipairs(self.bubbles)do b.active=false;put(self,b.node,"Visible",false,true)end
 put(self,self.tint,"Visible",false,true);put(self,self.word,"Visible",false,true);put(self,self.scan,"Visible",false,true)
 self.tintUntil,self.wordUntil=nil,nil
end
function Juice:clear()
 table.clear(self.born);table.clear(self.landed)
 self:hideAll()
end

-- A bead from the pool: a free one, else the oldest.
local function takeBead(self)
 local chosen
 for _,b in ipairs(self.beads)do if not b.active then return b end;if not chosen or b.start<chosen.start then chosen=b end end
 return chosen
end
local function launch(self,point,vx,vy,size,color,now,life,gravity)
 local b=takeBead(self);if not b then return end
 b.active,b.start,b.x,b.y,b.vx,b.vy,b.size,b.life,b.gravity=true,now,point.X,point.Y,vx,vy,size,life,gravity
 put(self,b.node,"BackgroundColor3",color,true);put(self,b.node,"Size",UDim2.fromOffset(size,size),true)
 put(self,b.node,"Position",UDim2.fromOffset(point.X,point.Y),true);put(self,b.node,"BackgroundTransparency",.05,true)
 self.stats.beads+=1 -- shown by step from its start time
end
local function gravity(self)
 local h=if self.root then self.root.AbsoluteSize.Y else 420
 return math.max(200,h*1.6)
end
-- The merge as drawn (P1). ctx: point (overlay px), radius (px), tier, id, x, y (world), worldRadius, list
-- (BallFaces inputs), now, popStyle (a chosen Levels pop keeps its own fragments: no beads then).
function Juice:merge(ctx)
 if not self.isOn then return end
 local now=ctx.now or os.clock()
 if ctx.id~=nil then self:mark(ctx.id)end
 if self:can("beads")and not ctx.popStyle and self.root then
  local n=Juice.beadCount(ctx.tier,ctx.cleared)
  local color=Themes.lightColor(ctx.tier)
  local g=gravity(self)
  for j=1,n do
   local vx,vy,size=Juice.beadStart(j,n,ctx.radius,ctx.tier)
   launch(self,ctx.point,vx,vy,size,color,now,Juice.Beads.life,g)
  end
 end
 if self:can("nudge")and self.faces and ctx.list then
  for _,n in ipairs(Juice.nudges(ctx.list,ctx.x,ctx.y,ctx.worldRadius or 1,ctx.id,self.nudgeOut))do
   self.faces:nudge(n.id,n.dir,now,Juice.Nudge.seconds)
  end
 end
end
-- The blob handed over to the new ball: its overshoot starts.
function Juice:bornAt(id,now)if self:can("overshoot")and id~=nil then self.born[id]=now end end
-- The chain the server (or the mirror) counted (P2).
function Juice:playCombo(ctx)
 if not self.isOn or not self.root then return end
 local now=ctx.now or os.clock()
 local c=Juice.combo(ctx.chain,ctx.cleared)
 if c.tint and self:can("tint")then
  put(self,self.tint,"BackgroundColor3",Themes.lightColor(ctx.tier),true);put(self,self.tint,"BackgroundTransparency",.15,true)
  put(self,self.tint,"Visible",true,true);self.tintAt,self.tintUntil=now,now+Juice.TintFor
 end
 if c.banks and self:can("banks")then
  local size=self.root.AbsoluteSize
  local color=Themes.lightColor(ctx.tier)
  local rise=-(size.Y*.9)/.7
  for k=1,Juice.BankBeads do
   for side=0,1 do
    local x=if side==0 then 6 else size.X-6
    launch(self,Vector2.new(x,size.Y-8-k*10),0,rise,5,color,now+(k-1)*.06,.7,0)
   end
  end
 end
 if c.praise and self:can("praise")then
  local text=UICopy.get(c.praise)
  put(self,self.word,"Text",text,true);put(self,self.word,"TextColor3",Themes.lightColor(ctx.tier):Lerp(Color3.new(1,1,1),.55),true)
  self.wordSize=math.clamp(math.floor(self.root.AbsoluteSize.X*.11),18,34)
  self.wordPunch=self:can("punch")
  put(self,self.word,"TextSize",if self.wordPunch then math.floor(self.wordSize*Juice.PunchScale+.5)else self.wordSize,true)
  put(self,self.word,"TextTransparency",0,true);put(self,self.word,"TextStrokeTransparency",.15,true);put(self,self.word,"Visible",true,true)
  self.wordAt,self.wordUntil=now,now+Juice.PraiseFor
 end
 if c.sweep and self:can("sweep")then
  local deck=self.deckOf()
  if deck and deck.sweepFinish then deck:sweepFinish(Juice.SweepFor)end
 end
end
-- Sound (P1). which: "body" (the impact: body, sub, duck), "chain" (the sparkle, once the chain is known) or "all".
-- false while the switch is off (the caller plays today's cues).
function Juice:mergeSound(tier,chain,id,cleared,which,gainScale)
 local audio=self.audio
 if not self.isOn or not audio then return false end
 local r=self.random
 if which~="chain"then
  if self:can("body")then
   local cue,speed,gain=Juice.bodyPlay(tier,chain,r(),r())
   audio:play(cue,speed,gain*(gainScale or 1))
  end
  if self:can("sub")then
   local cue,speed,gain=Juice.subPlay(tier,cleared,r(),r())
   if cue then audio:playLayer(cue,speed,gain)end
  end
  if self:can("duck")and Juice.ducks(tier,cleared)then audio:duck("aero",Juice.Duck.seconds,10^(-Juice.Duck.db/20))end
 end
 if which~="body"and(cleared or(chain or 1)>=2)and self:can("sparkle")then
  local cue,speed,gain=Juice.sparklePlay(chain,r(),r(),r(),self.lastSparkle)
  self.lastSparkle=cue
  audio:playLayer(cue,speed,gain)
 end
 return true
end
-- Ids already counted as landed (merge results, a round's starting pile), bounded.
function Juice:mark(id)
 if self.seen[id]then return end
 self.seenCount+=1
 if self.seenCount>512 then table.clear(self.seen);self.seenCount=0 end
 self.seen[id]=true
end
-- A drop the board accepted (P3): the release buzz, and the idle clock restarts.
function Juice:dropped(now)
 self.lastDrop=now
 if self:can("haptics")and self.haptics then self.haptics.play("drop")end
end
-- First contacts in an impact batch (P3). batch: {{id, normal, speed}, ...}; where(id) -> overlay px point, px radius,
-- tier (nil when the ball is not drawn); plopped: the board's own plop sounded for this batch.
-- Review B37: exactly one land cue per batch. `busy` (the board's plop gap has not passed) keeps this one quiet too; it
-- answers true when it played the batch's cue, and the board then plays no plop of its own for the batch.
function Juice:impacts(batch,now,busy,where)
 if not self.isOn then return false end
 local sounded=busy==true
 local played=false
 for _,impact in ipairs(batch)do
  local id=impact[1]
  if id~=nil and not self.seen[id]and(impact[3]or 0)>=4 then
   self:mark(id)
   local point,radius,tier=where(id,impact[2])
   if point then
    if self:can("landsquash")then self.landed[id]=now end
    if self:can("dust")and self.root then
     local color=Themes.lightColor(tier):Lerp(Color3.new(1,1,1),.35)
     for side=-1,1,2 do launch(self,point,side*radius*1.6,-radius*1.2,3,color,now,.3,gravity(self))end
    end
    if not sounded and self:can("landcue")and self.audio then
     sounded=true
     played=self.audio:play("land",Juice.TierPitch[math.clamp(tier or 1,1,5)],Juice.Gain.land)~=false
    end
    if self:can("haptics")and self.haptics then self.haptics.play("land")end
   end
  end
 end
 return played
end
-- The drawn size of ball `id` (LCD radii scales): the overshoot, the land squash and the fresh drop's stretch.
function Juice:shape(id,bornAt,now)
 if not self.isOn then return 1,1 end
 local kx,ky=1,1
 local b=self.born[id]
 if b then local k=Juice.overshoot(now-b);if k then kx*=k;ky*=k else self.born[id]=nil end end
 local l=self.landed[id]
 if l then local sx,sy=Juice.landSquash(now-l);if sx then kx*=sx;ky*=sy else self.landed[id]=nil end end
 if bornAt and self:can("stretch")then local sx,sy=Juice.stretch(now-bornAt);if sx then kx*=sx;ky*=sy end end
 return kx,ky
end
function Juice:held(now)return if self:can("breath")then Juice.breath(now)else 1 end
function Juice:twinkle(id,now)return if self.twinkleId==id and now<self.twinkleUntil then 1 else 0 end
-- Per LCD frame: the aim dots' drift and the match bloom's pulse.
local spacing=nil
function Juice:frame(lcd,now)
 if not lcd then return end
 if not self.isOn then lcd.guidePhase,lcd.matchPulse=0,1;return end
 if not spacing then
  local ok,v=pcall(function()return Config.launchVelocity(.5).Magnitude*Config.PreviewStep*64/(Config.Width+.8)end)
  spacing=if ok and type(v)=="number"and v>0 then v else 3
 end
 lcd.guidePhase=if self:can("drift")then Juice.drift(now,spacing)else 0
 lcd.matchPulse=if self:can("pulse")then Juice.pulse(now)else 1
end
-- Every presented frame. list: the BallFaces inputs (for the twinkle).
function Juice:step(now,list)
 self:refresh(now)
 self.stats.frame=0
 if not self.isOn then if self.root then self:hideAll()end;return end
 self:build()
 if not self.root then return end
 if self.lastDrop==-math.huge then self.lastDrop=now end -- idle counts from the first frame shown
 -- Beads.
 for _,b in ipairs(self.beads)do if b.active then
  local t=now-b.start
  if t>=b.life then b.active=false;put(self,b.node,"Visible",false,true)
  elseif t<0 then put(self,b.node,"Visible",false,true) -- a bank bead waiting for its turn
  else
   put(self,b.node,"Visible",true,true)
   local x,y,k,fade=Juice.beadAt(b.vx,b.vy,t,b.life,b.gravity)
   put(self,b.node,"Position",UDim2.fromOffset(b.x+x,b.y+y))
   put(self,b.node,"BackgroundTransparency",fade)
   local s=math.max(2,math.floor(b.size*k+.5));put(self,b.node,"Size",UDim2.fromOffset(s,s))
  end
 end end
 -- Idle bubbles (P4).
 local size=self.root.AbsoluteSize
 local active=0
 for _,b in ipairs(self.bubbles)do if b.active then
  local t=now-b.start;local y=b.y0-b.speed*t
  if y<6 or not self:can("bubbles")then b.active=false;put(self,b.node,"Visible",false,true)
  else
   active+=1
   put(self,b.node,"Position",UDim2.fromOffset(b.x0+math.sin(t*2.2+b.phase)*6,y))
  end
 end end
 if self:can("bubbles")and Juice.bubbleDue(now,self.lastDrop,self.lastBubble,active)then
  for _,b in ipairs(self.bubbles)do if not b.active then
   self.lastBubble=now
   local d=math.floor(6+self.random()*5)
   b.active,b.start,b.x0,b.y0,b.phase=true,now,size.X*(.2+.6*self.random()),size.Y-8,self.random()*6
   b.speed=Juice.Idle.rise*math.max(.6,size.Y/420)
   put(self,b.node,"Size",UDim2.fromOffset(d,d),true);put(self,b.node,"BackgroundTransparency",.82,true)
   put(self,b.node,"Position",UDim2.fromOffset(b.x0,b.y0),true);put(self,b.node,"Visible",true,true)
   self.stats.bubbles+=1
   break
  end end
 end
 -- The well's tint (P2, chain 3).
 if self.tintUntil then
  if now>=self.tintUntil then put(self,self.tint,"Visible",false,true);self.tintUntil=nil
  else put(self,self.tint,"BackgroundTransparency",.15+.85*((now-self.tintAt)/Juice.TintFor))end
 end
 -- The praise word (P2).
 if self.wordUntil then
  if now>=self.wordUntil then put(self,self.word,"Visible",false,true);self.wordUntil=nil
  else
   local age=now-self.wordAt
   local fade=math.clamp((age-(Juice.PraiseFor-.25))/.25,0,1)
   put(self,self.word,"TextTransparency",fade);put(self,self.word,"TextStrokeTransparency",.15+.85*fade)
   if self.wordPunch then
    local u=math.clamp(age/.1,0,1);u=1-(1-u)*(1-u)
    put(self,self.word,"TextSize",math.floor(self.wordSize*(Juice.PunchScale+(1-Juice.PunchScale)*u)+.5))
   end
  end
 end
 -- The scanline down the LCD glass (P5): every Scan.every s, Scan.travel s top to bottom.
 if self:can("scanline")then
  if now>=self.nextScan then self.scanAt=now;self.nextScan=now+Juice.Scan.every end
  local t=self.scanAt and(now-self.scanAt)/Juice.Scan.travel
  if t and t<1 then
   put(self,self.scan,"Visible",true,true);put(self,self.scan,"Position",UDim2.fromOffset(0,math.floor(t*size.Y)))
  else put(self,self.scan,"Visible",false,true)end
 else put(self,self.scan,"Visible",false,true)end
 -- The glint twinkle (P4): one ball every 1.2 to 2.5 s.
 if self:can("twinkle")and list and now>=self.nextTwinkleAt then
  self.nextTwinkleAt=Juice.nextTwinkle(now,self.random())
  if #list>0 then
   local pick=list[math.clamp(math.floor(self.random()*#list)+1,1,#list)]
   self.twinkleId,self.twinkleUntil=pick.id,now+Juice.Twinkle.seconds
  end
 end
 self.stats.peak=math.max(self.stats.peak,self.stats.frame)
end
function Juice:getStats()return table.clone(self.stats)end
function Juice:destroy()
 if self.destroyed then return end
 self.destroyed=true
 if self.root then self.root:Destroy();self.root=nil end
end
return Juice
