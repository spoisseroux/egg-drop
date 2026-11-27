-- The cuter petting screen (ONBOARDING-V3-BRIEF section 4, beta 37 notes; Spencer: "cuter UI, cuter interactions").
-- Behind Alive "pet2" (FeatureFlags.AlivePet2, the beta place and Studio, ConfigService `alive_pet2`, owner chat
-- /alive pet2 on|off|clear), read when the screen opens; off, PetFocusUI never builds this and the screen is exactly
-- as before. Presentation only: PetFocusUI's pointer rules and callbacks.pet() still decide the contact and the Star,
-- and nothing here is saved or sent. The rules (fill, drain, stages, lean, look, sizes, spots) are PetCuddle's.
--
-- What it draws, all in the focus panel, all original GUI shapes (no image uploads):
--   under  the Aero edge vignette (#58B8F2 to #0E5FB8 at 25%) and 6 slow bubbles at 12%.
--   plates the round glass Back face (PetFocusUI's own Back key keeps its input), the top-centre name pill (name and
--          bond pips or the Heart chip), the Happy heart on the right edge that fills from the bottom, the bottom
--          "Rub {pet}!" hint that fades after the first rub (and carries "{pet} loves this!" once a visit).
--   over   the mitten (white, #1B2A4A outline): the cursor on a computer, 28 px above the finger on touch, moved by the
--          left stick on a gamepad (X rubs); it tilts with the rub and squashes on contact. Hearts, sparkles, the burst.
-- The pet: its eyes and head follow the hovering mitten and its body leans into a rub (pet.cuddle, read by
-- GardenPetVisual); P2: each spot answers and the favourite spot (from the pet's id) fills twice as fast.
-- Sound: the purr's pitch follows the heart (BoardAudio:setPurrPitch), a fur brush loop follows the hand's speed, the
-- belly squeak, the burst chime. Haptics: `settle` at each third, `pop` on the burst. Reduced Motion: no tilt, squash,
-- lean, wiggle, floating hearts or drifting bubbles; the heart, the eyes, sound and buzz stay.
local GuiService=game:GetService("GuiService")
local SoundService=game:GetService("SoundService")
local TextService=game:GetService("TextService")
local TweenService=game:GetService("TweenService")
local UserInputService=game:GetService("UserInputService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local C=require(Shared.PetCuddle)
local UICopy=require(Shared.UICopy)

local Cuddle={};Cuddle.__index=Cuddle
-- STAND-INS (marked): the brief's new `fur_brush` loop and the belly squeak are not made yet. EMPTY SLOT: BrushId = 0
-- plays the stand-in below, an existing placeholder loop (shimmer_loop, assets/audio/placeholder) slowed right down.
Cuddle.BrushId=0
Cuddle.BrushStandIn=table.freeze({id=120156969856514,speed=.5})
-- STAND-IN: the belly squeak is the snack's happy squeak (BoardAudio cue), a little higher.
Cuddle.Squeak=table.freeze({cue="snack_happy_squeak",speed=1.15,gain=.35,gap=1.2})
-- The burst's chime is the Star chime (PetAffection.ChimeId, a placeholder itself), higher than the Star's.
Cuddle.Chime=table.freeze({speed=1.35,gain=.45})
-- The heart sprite (assets/ui/bond/heart-burst.png, white, tinted): the same uploaded image the bond burst uses.
Cuddle.HeartImage="rbxassetid://78220417355081"

local WHITE=Color3.new(1,1,1)
local INK=Color3.fromHex("#0E0F12")
local HAND_INK=Color3.fromHex(C.Hand.ink)
local PINK=Color3.fromHex(C.Hearts.colour)
local GOLD=Color3.fromHex(C.Hearts.sparkle)
local SKY=Color3.fromHex("#58B8F2")
local DEEP=Color3.fromHex("#0E5FB8")
local PAD=Color3.fromHex("#FFB3CF")

-- The switch, read once per visit (pcall: a missing Alive module is off).
function Cuddle.on()
 local ok,on=pcall(function()return require(Shared.Alive).on(C.Feature)end)
 return ok and on==true
end

local function make(class,parent,props)
 local node=Instance.new(class)
 for key,value in pairs(props or {})do node[key]=value end
 node.Parent=parent
 return node
end
local function frame(parent,name,z,props)
 local node=make("Frame",parent,{Name=name,BorderSizePixel=0,BackgroundColor3=WHITE,ZIndex=z or 1})
 for key,value in pairs(props or {})do node[key]=value end
 return node
end
local function round(node,radius)make("UICorner",node,{CornerRadius=if typeof(radius)=="UDim"then radius else UDim.new(0,radius)})return node end
local function outline(node,color,thickness,transparency)
 return make("UIStroke",node,{Color=color,Thickness=thickness,Transparency=transparency or 0,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
end
-- A white glass plate (85%), a soft white rim and a top highlight.
local function glass(parent,name,z)
 local plate=frame(parent,name,z,{BackgroundTransparency=.15})
 round(plate,UDim.new(.5,0));outline(plate,WHITE,1.5,.35)
 make("UIGradient",plate,{Rotation=90,Color=ColorSequence.new(WHITE,Color3.fromHex("#E4F3FF"))})
 return plate
end
local function label(parent,name,z,size)
 return make("TextLabel",parent,{Name=name,BackgroundTransparency=1,Font=Enum.Font.BuilderSansExtraBold,TextSize=size or 16,TextColor3=INK,
  Text="",ZIndex=z,Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center,TextYAlignment=Enum.TextYAlignment.Center})
end
local function width(text,size)
 local ok,v=pcall(TextService.GetTextSize,TextService,text,size,Enum.Font.BuilderSansExtraBold,Vector2.new(4000,200))
 return if ok then v.X else #text*size*.55
end

-- The mitten: a 56 px box drawn from rounded frames (scaled to 48 on a computer). The thumb sits under the mitt so the
-- outlines read as one shape; a pink pad and three toe beans on the palm.
local function mitten(parent,z)
 local box=frame(parent,"Mitten",z,{BackgroundTransparency=1,Size=UDim2.fromOffset(56,56),AnchorPoint=Vector2.new(.5,.3),Visible=false})
 local scale=make("UIScale",box,{Name="HandScale"})
 local line=C.Hand.outline
 local thumb=round(frame(box,"Thumb",z,{Position=UDim2.fromOffset(5,19),Size=UDim2.fromOffset(15,22),Rotation=-32}),UDim.new(.5,0))
 outline(thumb,HAND_INK,line)
 local mitt=round(frame(box,"Mitt",z+1,{Position=UDim2.fromOffset(12,3),Size=UDim2.fromOffset(32,40)}),UDim.new(.5,0))
 outline(mitt,HAND_INK,line)
 local cuff=round(frame(box,"Cuff",z+2,{Position=UDim2.fromOffset(13,40),Size=UDim2.fromOffset(30,12)}),6)
 outline(cuff,HAND_INK,line)
 round(frame(box,"Pad",z+3,{BackgroundColor3=PAD,Position=UDim2.fromOffset(22,22),Size=UDim2.fromOffset(13,10)}),UDim.new(.5,0))
 for i,at in ipairs({{18,13},{25,9},{32,13}})do
  round(frame(box,"Bean"..i,z+3,{BackgroundColor3=PAD,Position=UDim2.fromOffset(at[1]-1,at[2]),Size=UDim2.fromOffset(6,6)}),UDim.new(.5,0))
 end
 return box,scale
end

-- The Happy heart: an ink-rimmed glass heart; the pink fill rises inside a clip from the bottom; a white glint.
local function happyHeart(parent,z)
 local root=frame(parent,"HappyHeart",z,{BackgroundTransparency=1,AnchorPoint=Vector2.new(1,.5),Size=UDim2.fromOffset(72,72)})
 local pop=make("UIScale",root,{Name="HeartPop"})
 local rim=make("ImageLabel",root,{Name="Rim",BackgroundTransparency=1,Image=Cuddle.HeartImage,ImageColor3=HAND_INK,ImageTransparency=.55,
  AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.52),Size=UDim2.fromScale(1.1,1.1),ZIndex=z})
 local base=make("ImageLabel",root,{Name="Glass",BackgroundTransparency=1,Image=Cuddle.HeartImage,ImageColor3=WHITE,ImageTransparency=.15,
  Size=UDim2.fromScale(1,1),ZIndex=z+1})
 local clip=frame(root,"FillClip",z+2,{BackgroundTransparency=1,ClipsDescendants=true,AnchorPoint=Vector2.new(0,1),Position=UDim2.fromScale(0,1),Size=UDim2.fromScale(1,0)})
 local fill=make("ImageLabel",clip,{Name="Fill",BackgroundTransparency=1,Image=Cuddle.HeartImage,ImageColor3=PINK,AnchorPoint=Vector2.new(0,1),
  Position=UDim2.fromScale(0,1),Size=UDim2.fromOffset(72,72),ZIndex=z+2})
 local glint=round(frame(root,"Glint",z+3,{BackgroundTransparency=.25,Position=UDim2.fromScale(.2,.2),Size=UDim2.fromScale(.16,.12),Rotation=-30}),UDim.new(.5,0))
 return{root=root,pop=pop,rim=rim,base=base,clip=clip,fill=fill,glint=glint}
end

-- deps: {audio = BoardAudio (or nil), reduced() -> bool, affection() -> PetAffection (or nil), first() -> bool (the
-- guide's first pet: PetCuddle.First, read when the screen opens), firstDone() (that first visit's burst played)}.
function Cuddle.new(focus,deps)
 deps=deps or {}
 local panel=focus.panel
 local self=setmetatable({focus=focus,deps=deps,active=false,state=C.new(),connections={},hearts={},sparkles={},bubbles={},
  look={yaw=0,pitch=0,x=0,y=0},leanW=0,lookW=0,spotW=0,velocity=Vector2.zero,pose={}},Cuddle)
 -- Under the controls: the vignette and the bubbles.
 local under=frame(panel,"CuddleUnder",1,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Visible=false,Interactable=false})
 self.under=under
 for _,edge in ipairs({{"Top",UDim2.new(1,0,.2,0),UDim2.fromScale(0,0),90},{"Bottom",UDim2.new(1,0,.2,0),UDim2.fromScale(0,.8),-90},
  {"Left",UDim2.new(.14,0,1,0),UDim2.fromScale(0,0),0},{"Right",UDim2.new(.14,0,1,0),UDim2.fromScale(.86,0),180}})do
  local band=frame(under,"Vignette"..edge[1],1,{Size=edge[2],Position=edge[3],BackgroundTransparency=0})
  make("UIGradient",band,{Rotation=edge[4],Color=ColorSequence.new(DEEP,SKY),
   Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,.75),NumberSequenceKeypoint.new(1,1)})})
 end
 for i=1,6 do
  local size=14+((i*7)%4)*6
  local bubble=round(frame(under,"Bubble"..i,2,{BackgroundTransparency=.88,Size=UDim2.fromOffset(size,size),AnchorPoint=Vector2.new(.5,.5)}),UDim.new(.5,0))
  outline(bubble,WHITE,1.5,.6)
  self.bubbles[i]={node=bubble,x=({.05,.12,.9,.95,.24,.78})[i],phase=i/6,speed=10+i*2.5}
 end
 -- Over the controls: the plates, the hearts, the mitten (all decorative: no input).
 local over=frame(panel,"CuddleOver",40,{BackgroundTransparency=1,Size=UDim2.fromScale(1,1),Visible=false,Interactable=false})
 self.over=over
 self.pill=glass(over,"NamePill",41)
 self.pillName=label(self.pill,"PetName",42,16);self.pillName.AutoLocalize=false
 self.pillName.TextXAlignment=Enum.TextXAlignment.Left;self.pillName.TextTruncate=Enum.TextTruncate.AtEnd
 self.heart=happyHeart(over,41)
 self.hint=glass(over,"RubHint",41);self.hint.AnchorPoint=Vector2.new(.5,1)
 self.hintText=label(self.hint,"Words",42,16);self.hintText.AutoLocalize=false
 self.favour=frame(over,"FavouriteSpot",43,{BackgroundTransparency=1,Size=UDim2.fromOffset(40,40),AnchorPoint=Vector2.new(.5,.5),Visible=false})
 for i=1,3 do
  local s=frame(self.favour,"Twinkle"..i,43,{BackgroundColor3=GOLD,BackgroundTransparency=.5,Size=UDim2.fromOffset(7,7),AnchorPoint=Vector2.new(.5,.5),Rotation=45,
   Position=UDim2.fromScale(({.2,.75,.5})[i],({.3,.4,.85})[i])})
  round(s,2)
 end
 for i=1,14 do
  local h=make("ImageLabel",over,{Name="Heart"..i,BackgroundTransparency=1,Image=Cuddle.HeartImage,ImageColor3=PINK,Visible=false,
   AnchorPoint=Vector2.new(.5,.5),ZIndex=44})
  round(frame(h,"Glint",45,{BackgroundTransparency=.1,Position=UDim2.fromScale(.22,.22),Size=UDim2.fromScale(.2,.15),Rotation=-30}),UDim.new(.5,0))
  self.hearts[i]={node=h}
 end
 for i=1,12 do
  local s=round(frame(over,"Sparkle"..i,44,{BackgroundColor3=GOLD,AnchorPoint=Vector2.new(.5,.5),Rotation=45,Visible=false}),2)
  self.sparkles[i]={node=s}
 end
 self.hand,self.handScale=mitten(over,50)
 -- The round glass face over PetFocusUI's Back key (built here, shown only while this is on).
 local back=focus.back
 local face=glass(back,"CuddleBackFace",(back.ZIndex or 10)+1);face.Size=UDim2.fromScale(1,1);face.Visible=false;face.Interactable=false
 local arrow=frame(face,"Arrow",(back.ZIndex or 10)+2,{BackgroundTransparency=1,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromOffset(22,22)})
 round(frame(arrow,"Stem",arrow.ZIndex,{BackgroundColor3=INK,AnchorPoint=Vector2.new(0,.5),Position=UDim2.fromOffset(3,11),Size=UDim2.fromOffset(17,4)}),2)
 for i,turn in ipairs({-45,45})do
  round(frame(arrow,"Head"..i,arrow.ZIndex,{BackgroundColor3=INK,AnchorPoint=Vector2.new(0,.5),Position=UDim2.fromOffset(2,11+(if i==1 then -4 else 4)),
   Size=UDim2.fromOffset(11,4),Rotation=turn}),2)
 end
 self.backFace=face
 -- Pointer tracking (positions only; PetFocusUI keeps every decision about contact).
 local function local_(input)return Vector2.new(input.Position.X,input.Position.Y)-focus.root.AbsolutePosition end
 table.insert(self.connections,UserInputService.InputChanged:Connect(function(input)
  if not self.active then return end
  if input.UserInputType==Enum.UserInputType.MouseMovement then self.mouseAt=local_(input)
  elseif input.UserInputType==Enum.UserInputType.Touch and input==self.touch then self.touchAt=local_(input)end
 end))
 table.insert(self.connections,UserInputService.InputBegan:Connect(function(input)
  if not self.active then return end
  if input.UserInputType==Enum.UserInputType.MouseButton1 then self.mouseAt=local_(input)
  elseif input.UserInputType==Enum.UserInputType.Touch and not self.touch then self.touch=input;self.touchAt=local_(input)end
 end))
 table.insert(self.connections,UserInputService.InputEnded:Connect(function(input)
  if input==self.touch then self.touch=nil;self.touchAt=nil end
 end))
 return self
end

function Cuddle:reduced()
 local ok,r=pcall(function()return self.deps.reduced and self.deps.reduced()end)
 return GuiService.ReducedMotionEnabled or(ok and r==true)
end
function Cuddle:audio()return self.deps.audio end

-- The screen opened with the switch on: a fresh visit.
function Cuddle:begin()
 if self.active or self.destroyed then return end
 -- the guide's first pet (deps.first, read once as the screen opens): the 3 s heart, and the burst closes the screen
 local okFirst,first=pcall(function()return self.deps.first and self.deps.first()end)
 self.active=true;self.state=C.new(okFirst and first==true)
 self.firstBurstAt,self.closing=nil,false
 self.hinted=false;self.hintUntil=nil;self.lovedUntil=nil;self.spot=nil;self.spotAge=0;self.burstAge=nil;self.heartClock=0
 self.leanW,self.lookW,self.spotW,self.blush,self.shownFill=0,0,0,0,0
 self.padAt=nil;self.stickAt=Vector2.zero;self.lastHand=nil;self.velocity=Vector2.zero
 self.mouseAt=nil
 local ok,at=pcall(function()return UserInputService:GetMouseLocation()-GuiService:GetGuiInset()-self.focus.root.AbsolutePosition end)
 if ok and typeof(at)=="Vector2"then self.mouseAt=at end
 self.under.Visible,self.over.Visible=true,true
 self.hint.Visible=true;self.hint.BackgroundTransparency=.15;self.hintText.TextTransparency=0
 local face=self.backFace;face.Visible=true
 local back=self.focus.back
 local saved={transparency=back.BackgroundTransparency,children={}}
 self.backSaved=saved
 back.BackgroundTransparency=1
 for _,child in ipairs(back:GetChildren())do
  if child:IsA("UIStroke")then saved.children[child]=child.Enabled;child.Enabled=false
  elseif child:IsA("GuiObject")and child~=face then saved.children[child]=child.Visible;child.Visible=false end
 end
 local stroke=self.hint:FindFirstChildOfClass("UIStroke");if stroke then stroke.Transparency=.35 end
 local affection=self.deps.affection and self.deps.affection()
 if affection then affection.quiet=true end
 for _,h in ipairs(self.hearts)do h.node.Visible=false;h.age=nil end
 for _,s in ipairs(self.sparkles)do s.node.Visible=false;s.age=nil end
 self:layout(true)
end
-- The screen closed (or the switch went off): put everything back exactly.
function Cuddle:finish()
 if not self.active then return end
 self.active=false
 self.under.Visible,self.over.Visible=false,false
 self.hand.Visible=false
 if self.hidCursor then self.hidCursor=false;UserInputService.MouseIconEnabled=true end
 local back=self.focus.back
 self.backFace.Visible=false
 local saved=self.backSaved
 if saved then
  back.BackgroundTransparency=saved.transparency;self.backSaved=nil
  for child,was in pairs(saved.children)do
   if child.Parent==back then if child:IsA("UIStroke")then child.Enabled=was else child.Visible=was end end
  end
 end
 local affection=self.deps.affection and self.deps.affection()
 if affection then affection.quiet=false end
 local audio=self:audio()
 if audio and audio.setPurrPitch then audio:setPurrPitch(1)end
 if self.brush then self.brush.Volume=0;self.brush:Stop()end
 if self.pet then self.pet.cuddle=nil;self.pet.poseDirty=true;self.pet=nil end
 self.touch,self.touchAt=nil,nil
end

-- Screen rects (local to the focus root) the pointer should not start a rub on.
function Cuddle:blocks(point)
 if not self.active then return false end
 for _,node in ipairs({self.pill,self.heart.root})do
  if node.Visible then
   local p,s=node.AbsolutePosition-self.focus.root.AbsolutePosition,node.AbsoluteSize
   if point.X>=p.X and point.X<=p.X+s.X and point.Y>=p.Y and point.Y<=p.Y+s.Y then return true end
  end
 end
 return false
end

-- A gamepad's left stick (PetFocusUI forwards Thumbstick1 while this is on).
function Cuddle:stick(position)
 if typeof(position)~="Vector3"then self.stickAt=Vector2.zero;return end
 local v=Vector2.new(position.X,-position.Y)
 self.stickAt=if v.Magnitude<.15 then Vector2.zero else v
end

function Cuddle:layout(force)
 local size=self.focus.root.AbsoluteSize
 local info=self.focus.bondInfo
 local key=tostring(size)..":"..tostring(info and info.name)..":"..tostring(info and info.heart)..":"..tostring(info and info.bond and info.bond.shown)
 if not force and key==self.layoutKey then return end
 self.layoutKey=key
 local L=C.layout(size.X,size.Y)
 self.sizes=L
 -- The Happy heart: right edge, centred.
 self.heart.root.Size=UDim2.fromOffset(L.heart,L.heart)
 self.heart.root.Position=UDim2.new(1,-L.edge-4,.5,0)
 self.heart.fill.Size=UDim2.fromOffset(L.heart,L.heart)
 -- The name pill: top centre, name then the chip (Heart level) or the bond pips.
 local name=(info and info.name)or ""
 self.pillName.TextSize=L.text
 local nameW=math.ceil(width(name,L.text))+2
 local chipW=0
 if info and info.heart then
  if not self.chip then
   local ok,chip=pcall(function()return require(script.Parent.StatsPanel).statChip(self.pill)end)
   if ok then self.chip=chip end
  end
  if self.pips then self.pips.set(nil)end
  if self.chip then
   local stat=info.stat or {id="heart",level=info.heart}
   self.chip.root.ZIndex=43;self.chip.set(stat.id,stat.level,L.phone);chipW=self.chip.width+8
  end
 elseif info and info.bond then
  if not self.pips then
   local ok,pips=pcall(function()return require(script.Parent.BondPips).new(self.pill,true)end)
   if ok then self.pips=pips end
  end
  if self.chip then self.chip.set(nil)end
  if self.pips then self.pips.root.ZIndex=43;self.pips.set(info.bond,false);chipW=self.pips.width+10 end
 else
  if self.chip then self.chip.set(nil)end
  if self.pips then self.pips.set(nil)end
 end
 local h=L.pill
 local maxW=math.max(120,size.X-2*(L.edge+L.back+12)-(if self.focus.pickupButton and self.focus.pickupButton.Visible then 60 else 0))
 local w=math.clamp(18+nameW+chipW+16,96,maxW)
 self.pill.Visible=name~=""
 self.pill.AnchorPoint=Vector2.new(.5,0);self.pill.Position=UDim2.new(.5,0,0,L.edge);self.pill.Size=UDim2.fromOffset(w,h)
 self.pillName.Position=UDim2.fromOffset(18,0);self.pillName.Size=UDim2.new(0,math.max(10,w-18-chipW-16),1,0)
 local chipRoot=(self.chip and self.chip.root.Visible and self.chip.root)or(self.pips and self.pips.root.Visible and self.pips.root)
 if chipRoot then chipRoot.AnchorPoint=Vector2.new(1,.5);chipRoot.Position=UDim2.new(1,-14,.5,0)end
 -- The hint: bottom centre.
 self.hintText.TextSize=L.text
 if not self.lovedUntil then self:setHint(UICopy.get("pet.cuddle.rub",{pet=if name~=""then name else UICopy.get("pet.cuddle.friend")}))end
end
function Cuddle:setHint(text)
 self.hintWords=text
 self.hintText.Text=text
 local L=self.sizes or C.layout(800,400)
 local w=math.ceil(width(text,L.text))+36
 self.hint.Size=UDim2.fromOffset(w,L.pill-4)
 self.hint.Position=UDim2.new(.5,0,1,-L.edge-2)
end
function Cuddle:fadeHint()
 if self.hinted then return end
 self.hinted=true
 local info=TweenInfo.new(.4,Enum.EasingStyle.Quad)
 TweenService:Create(self.hint,info,{BackgroundTransparency=1}):Play()
 TweenService:Create(self.hintText,info,{TextTransparency=1}):Play()
 local stroke=self.hint:FindFirstChildOfClass("UIStroke");if stroke then TweenService:Create(stroke,info,{Transparency=1}):Play()end
end
-- "{pet} loves this!" for 1.8 s, in the hint's place.
function Cuddle:showLoved(name)
 self:setHint(UICopy.get("pet.cuddle.loves",{pet=name}))
 self.hint.BackgroundTransparency=.15;self.hintText.TextTransparency=0
 local stroke=self.hint:FindFirstChildOfClass("UIStroke");if stroke then stroke.Transparency=.35 end
 self.lovedUntil=os.clock()+1.8
end

local function pop(scale,peak)
 scale.Scale=peak
 TweenService:Create(scale,TweenInfo.new(.25,Enum.EasingStyle.Back,Enum.EasingDirection.Out),{Scale=1}):Play()
end
function Cuddle:spawnHeart(at,size,velocity,life)
 for _,h in ipairs(self.hearts)do
  if not h.age then
   h.age,h.life,h.from,h.vel,h.size=0,life or C.Hearts.life,at,velocity,size
   h.node.Size=UDim2.fromOffset(size,size);h.node.Position=UDim2.fromOffset(at.X,at.Y);h.node.ImageTransparency=0;h.node.Visible=true
   return true
  end
 end
 return false
end
function Cuddle:spawnSparkle(at,velocity)
 for _,s in ipairs(self.sparkles)do
  if not s.age then
   s.age,s.life,s.from,s.vel=0,.6,at,velocity
   s.node.Size=UDim2.fromOffset(8,8);s.node.Position=UDim2.fromOffset(at.X,at.Y);s.node.BackgroundTransparency=0;s.node.Visible=true
   return true
  end
 end
 return false
end
function Cuddle:stepParticles(dt)
 for _,h in ipairs(self.hearts)do
  if h.age then
   h.age+=dt
   local t=h.age/h.life
   if t>=1 then h.age=nil;h.node.Visible=false
   else
    local at=h.from+h.vel*h.age+Vector2.new(math.sin(h.age*5+h.from.X)*4,0)
    local grow=if t<.2 then t/.2 else 1-(t-.2)*.25
    h.node.Position=UDim2.fromOffset(at.X,at.Y)
    h.node.Size=UDim2.fromOffset(h.size*grow,h.size*grow)
    h.node.ImageTransparency=if t>.6 then(t-.6)/.4 else 0
   end
  end
 end
 for _,s in ipairs(self.sparkles)do
  if s.age then
   s.age+=dt
   local t=s.age/s.life
   if t>=1 then s.age=nil;s.node.Visible=false
   else
    local at=s.from+s.vel*s.age*(1-t*.5)
    local k=math.sin(t*math.pi)
    s.node.Position=UDim2.fromOffset(at.X,at.Y);s.node.Size=UDim2.fromOffset(4+8*k,4+8*k);s.node.BackgroundTransparency=t*.8
   end
  end
 end
end

function Cuddle:burst(centre,reduced)
 self.burstAge=0
 pop(self.heart.pop,1.35)
 if not reduced then
  for i=1,C.Hearts.burst do
   local a=(i-1)/C.Hearts.burst*math.pi*2+.3
   self:spawnHeart(centre,26,Vector2.new(math.cos(a),math.sin(a)-.6)*130,.9)
  end
  for i=1,C.Hearts.sparkles do
   local a=(i-.5)/C.Hearts.sparkles*math.pi*2
   self:spawnSparkle(centre,Vector2.new(math.cos(a),math.sin(a))*(150+(i%3)*30))
  end
 end
 if not self.chime then
  local ok,id=pcall(function()return require(script.Parent.PetAffection).ChimeId end)
  if ok and id then self.chime=make("Sound",SoundService,{Name="EggDropCuddleChime",SoundId="rbxassetid://"..id,Volume=Cuddle.Chime.gain,PlaybackSpeed=Cuddle.Chime.speed})end
 end
 local group=SoundService:FindFirstChild("EggDropSFX")
 if self.chime and group and group:IsA("SoundGroup")and group.Volume>0 then self.chime.SoundGroup=group;self.chime.TimePosition=0;self.chime:Play()end
 pcall(function()require(script.Parent.Haptics).play("pop")end)
end

function Cuddle:stepBrush(dt,gain)
 if not self.brush then
  local id=if Cuddle.BrushId>0 then Cuddle.BrushId else Cuddle.BrushStandIn.id
  self.brush=make("Sound",SoundService,{Name="EggDropCuddleBrush",SoundId="rbxassetid://"..id,Looped=true,Volume=0,
   PlaybackSpeed=if Cuddle.BrushId>0 then 1 else Cuddle.BrushStandIn.speed})
 end
 local group=SoundService:FindFirstChild("EggDropSFX")
 local audible=group and group:IsA("SoundGroup")and group.Volume>0
 if audible and self.brush.SoundGroup~=group then self.brush.SoundGroup=group end
 local v=C.ease(self.brush.Volume,if audible then gain else 0,dt,.1)
 self.brush.Volume=v
 if v>.003 and not self.brush.IsPlaying then self.brush:Play()elseif v<=.003 and self.brush.IsPlaying then self.brush:Stop()end
end

local function inputKind()
 local kind=UserInputService:GetLastInputType()
 if kind==Enum.UserInputType.Touch then return "touch"end
 if string.match(kind.Name,"^Gamepad")then return "gamepad"end
 return "mouse"
end

-- Every frame of an open screen (PetFocusUI:update). box: the pet's on-screen rect {position, size} (root-local), or nil.
function Cuddle:step(dt,camera,pet,boxAt,boxSize)
 if not self.active or self.destroyed then return end
 dt=math.clamp(dt or 0,0,.1)
 local focus=self.focus
 local reduced=self:reduced()
 if pet~=self.pet then
  if self.pet then self.pet.cuddle=nil;self.pet.poseDirty=true end
  self.pet=pet
 end
 self:layout(false)
 local size=focus.root.AbsoluteSize
 local can=focus.active and focus.panel.Visible and focus:canOwnInput()
 local tray=focus.snacksOpen and focus:snacksOpen()
 -- The hint hides under the snack tray and a save notice; "loves this" comes and goes.
 if self.lovedUntil and os.clock()>=self.lovedUntil then
  self.lovedUntil=nil;self.hinted=false
  self:setHint(UICopy.get("pet.cuddle.rub",{pet=(focus.bondInfo and focus.bondInfo.name)or UICopy.get("pet.cuddle.friend")}))
  self:fadeHint()
 end
 self.hint.Visible=not tray and focus.saveNotice==nil
 -- The bond card's place is the pill now.
 if focus.bondCard and focus.bondCard.Visible then focus.bondCard.Visible=false end
 -- The mitten.
 local kind=inputKind()
 local handSize,offset=C.hand(kind)
 local at
 if kind=="mouse"then at=self.mouseAt
 elseif kind=="touch"then at=self.touchAt and self.touchAt+offset
 else
  local centre=if boxAt then boxAt+boxSize*.5 else size*.5
  self.padAt=self.padAt or centre
  self.padAt+=self.stickAt*C.Hand.stick*dt
  self.padAt=Vector2.new(math.clamp(self.padAt.X,0,size.X),math.clamp(self.padAt.Y,0,size.Y))
  at=self.padAt
 end
 local held=focus.heldGreet~=nil and focus.heldGreet.active==true
 local contact=focus:contactValid()
 if at and held and kind=="gamepad"and self.stickAt.Magnitude<.15 and not reduced then
  -- X held with the stick still: the mitten rubs in a small circle on its own.
  local t=os.clock()*9;at=at+Vector2.new(math.cos(t)*7,math.sin(t*2)*3)
 end
 local visible=can and at~=nil
 if kind=="mouse"and visible then
  if not self.hidCursor then self.hidCursor=true;UserInputService.MouseIconEnabled=false end
 elseif self.hidCursor then self.hidCursor=false;UserInputService.MouseIconEnabled=true end
 if at and self.lastHand then
  local v=(at-self.lastHand)/math.max(dt,1/240)
  self.velocity=self.velocity:Lerp(v,math.min(1,dt/C.Hand.ease))
 else self.velocity=Vector2.zero end
 self.lastHand=at
 local speed=self.velocity.Magnitude
 self.hand.Visible=visible
 if visible then
  self.hand.Position=UDim2.fromOffset(at.X,at.Y)
  local tilt=if reduced then 0 else C.handTilt(self.velocity.X)
  self.hand.Rotation=C.ease(self.hand.Rotation,tilt,dt,.12)
  local scale=(handSize/56)*(if reduced then 1 else C.handScale(contact or(focus.pointer~=nil)))
  self.handScale.Scale=C.ease(self.handScale.Scale,scale,dt,.08)
 end
 -- The heart.
 local rubbing=C.rubbing(contact,speed,held)
 if rubbing then self:fadeHint()end
 local u,v
 if at and boxAt and boxSize.X>0 and boxSize.Y>0 then u,v=(at.X-boxAt.X)/boxSize.X,(at.Y-boxAt.Y)/boxSize.Y end
 local over=u~=nil and u>=-.1 and u<=1.1 and v>=-.1 and v<=1.1
 local spot=if over then C.spotAt(math.clamp(u,0,1),math.clamp(v,0,1))elseif held then "head"else nil
 local favourite=C.favourite(pet and(pet.petId or pet.id)or(focus.bondInfo and focus.bondInfo.name))
 local onFavourite=rubbing and spot==favourite
 local events=C.step(self.state,dt,rubbing,onFavourite)
 local s=self.state
 local audio=self:audio()
 if events.stage then pop(self.heart.pop,1.18);pcall(function()require(script.Parent.Haptics).play("settle")end)end
 local centre=if boxAt then boxAt+boxSize*Vector2.new(.5,.45)else size*.5
 if events.burst then
  self:burst(centre,reduced)
  -- the first visit's burst spends it: every later visit is a normal one (deps.firstDone)
  if s.first and not self.firstBurstAt and self.deps.firstDone then pcall(self.deps.firstDone)end
  self.firstBurstAt=self.firstBurstAt or os.clock()
 end
 -- the first visit: C.First.close s after the burst the screen closes by itself (as Back: the wave, the ease out). A
 -- refused close (back() false: the camera mid-transition) tries again next frame while the screen is up.
 if not self.closing and C.closeDue(s,self.firstBurstAt,os.clock())then
  self.closing=true
  local back=focus.callbacks and focus.callbacks.back
  if back then task.defer(function()
   if not self.active then return end
   local ok,went=pcall(back)
   if not ok or went==false then self.closing=false end
  end)end
 end
 if onFavourite and not s.lovedShown then
  s.lovedShown=true;self:showLoved((focus.bondInfo and focus.bondInfo.name)or UICopy.get("pet.cuddle.friend"))
 end
 self.shownFill=C.ease(self.shownFill,s.fill,dt,.15)
 self.heart.clip.Size=UDim2.fromScale(1,math.clamp(self.shownFill,0,1))
 -- Hearts from the hand while rubbing, from 33%.
 local every,heartSize=C.heartEvery(s.stage)
 if rubbing and every and at and not reduced then
  self.heartClock+=dt
  if self.heartClock>=every then
   self.heartClock-=every
   local rise=C.Hearts.rise[1]+(C.Hearts.rise[2]-C.Hearts.rise[1])*((s.rubbed*3.7)%1)
   self:spawnHeart(at+Vector2.new(((s.rubbed*53)%1-.5)*28,-10),heartSize,Vector2.new(((s.rubbed*31)%1-.5)*30,-rise/C.Hearts.life),C.Hearts.life)
  end
 else self.heartClock=0 end
 self:stepParticles(dt)
 -- The favourite spot's faint sparkles, after 4 s of rubbing elsewhere.
 local hint=rubbing and spot~=favourite and s.elsewhere>=C.FavouriteHint and boxAt~=nil
 self.favour.Visible=hint==true
 if hint then
  local c=C.SpotCentre[favourite]
  self.favour.Position=UDim2.fromOffset(boxAt.X+boxSize.X*c.X,boxAt.Y+boxSize.Y*c.Y)
  self.favour.Rotation=if reduced then 0 else(os.clock()*40)%360
 end
 -- Bubbles drift up (still under Reduced Motion).
 for _,b in ipairs(self.bubbles)do
  local y=if reduced then .85-b.phase*.6 else(1-((os.clock()*b.speed/math.max(size.Y,1)+b.phase)%1))
  b.node.Position=UDim2.new(b.x,0,y,0)
 end
 -- Sounds: the purr's pitch with the heart, the brush with the hand's speed, the belly squeak.
 if audio and audio.setPurrPitch then audio:setPurrPitch(C.purrPitch(s.fill))end
 self:stepBrush(dt,if contact then C.brushGain(speed)else 0)
 if rubbing and spot~=self.spot then
  self.spot,self.spotAge=spot,0
  if spot=="belly"and audio and audio.play and os.clock()-(self.lastSqueak or -math.huge)>=Cuddle.Squeak.gap then
   self.lastSqueak=os.clock();audio:play(Cuddle.Squeak.cue,Cuddle.Squeak.speed,Cuddle.Squeak.gain)
  end
 end
 if rubbing then self.spotAge+=dt end
 -- The pet.
 if not pet or pet.destroyed then return end
 local near=over or(u~=nil and u>=-.6 and u<=1.6 and v>=-.6 and v<=1.6)
 self.lookW=C.ease(self.lookW,if visible and near then 1 else 0,dt,C.Look.ease*3)
 self.leanW=C.ease(self.leanW,if contact and not reduced then 1 else 0,dt,C.Lean.ease)
 self.spotW=C.ease(self.spotW,if rubbing then 1 else 0,dt,.25)
 -- Screen right in the pet's own X (it faces the camera): +1 or -1.
 local sideSign=1
 if camera then
  local localRight=CFrame.Angles(0,pet.yaw or 0,0):VectorToObjectSpace(camera.CFrame.RightVector)
  sideSign=if localRight.X<0 then -1 else 1
 end
 local dx,dy=0,0
 if u then dx,dy=math.clamp((u-.5)*2,-1.5,1.5),math.clamp((v-.3)*2,-1.5,1.5)end
 local yaw,pitch,ex,ey=C.look(Vector3.new(dx*sideSign,-dy,1.4),self.lookW)
 local leanPitch,leanRoll=C.lean(math.clamp(dx,-1,1)*sideSign,self.leanW)
 local sp=C.spotPose(self.spot,self.spotAge,math.clamp(dx,-1,1)*sideSign,reduced)
 local w=self.spotW
 local hop,sway=0,0
 if self.burstAge then
  self.burstAge+=dt
  hop,sway=C.burstPose(self.burstAge,reduced)
  if self.burstAge>=C.BurstSeconds then self.burstAge=nil end
 end
 self.blush=C.ease(self.blush,math.clamp((s.fill-C.Stages[1])/(C.Stages[2]-C.Stages[1]),0,1)*.7,dt,.3)
 local p=self.pose
 p.headYaw,p.headPitch,p.headRoll=yaw,pitch+sp.headPitch*w,sp.headRoll*w
 p.eyeX,p.eyeY=ex,ey
 p.eye=1+(sp.eye-1)*w
 p.stretch,p.ear,p.sway,p.hop=sp.stretch*w,sp.ear*w,sp.sway*w+sway,sp.hop*w+hop
 p.pitch,p.roll,p.blush=leanPitch,leanRoll,self.blush
 pet.cuddle=p;pet.poseDirty=true
end

function Cuddle:destroy()
 if self.destroyed then return end
 self:finish()
 self.destroyed=true
 for _,c in ipairs(self.connections)do c:Disconnect()end
 table.clear(self.connections)
 if self.brush then self.brush:Destroy()end
 if self.chime then self.chime:Destroy()end
 self.under:Destroy();self.over:Destroy();self.backFace:Destroy()
end
return Cuddle
