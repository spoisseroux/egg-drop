-- Coach cards (v1 track A onboarding, ONBOARDING-V1-SCOPE-2026-11-13 sections 1 and 2.3).
--
--  * Welcome round: a card over the board says what the first round is for ("Hatch your
--    first friend", the Stars that come with the Bear). State-driven (no pet yet), not saved.
--  * Guided garden step, once, after the Bear: three short beats (machines, the Pocket menu,
--    the first quest). Each beat moves on by itself after a few seconds or on a tap; Skip
--    ends the step. It waits while a menu, the reveal or the greeting shot is up.
--  * One-time cards, each shown once ever (CoachMarks bits in the `coachMask` save field):
--    the fill line, the first visit to each machine, the first item, the first quest done,
--    and the playground.
--
-- Never blocks input: board cards take no input at all, garden cards only take a tap on
-- themselves, nothing binds keys, and every card leaves on its own. Presentation only; the
-- one remote is `send(id)` ("coachMark"), which the server turns into a saved bit.
--
-- QA v2 track R1:
--  * The Welcome card is now a small pill at the top of the board (it covered the aim guide
--    and cut its title on phones): it fades in, stays ~5 s and fades, or fades at the first drop.
--  * Machine first-visit cards wait for the reveal: "Hatch eggs" never shows over the Bear's
--    reveal (the hatch screen hosts it), only on a real visit after it.
--  * The garden step is unmissable: a beat starts only when the player stands still in the
--    free garden with no menu open and the window focused, and its clock pauses while the
--    window is unfocused or the player is away (no input). `replayGarden()` runs it again.
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Coach=require(Shared:WaitForChild("CoachMarks"))
local UICopy=require(Shared:WaitForChild("UICopy"))
local Pets=require(Shared:WaitForChild("PetCatalog"))
local Eggs=require(Shared:WaitForChild("EggCatalog"))
local Kit=require(script.Parent.DeckKit)
-- Slice E (overnight 2026-11-14): the earned-pet gate (lane S). Guarded: without the module
-- the arrival card simply never shows.
local function earnedPets()
 local module=Shared:FindFirstChild("EarnedPets")
 if not module then return nil end
 local ok,value=pcall(require,module)
 return if ok then value else nil
end

local Cards={}
Cards.__index=Cards
Cards.Duration=7      -- a one-time card's time on screen
Cards.BeatSeconds=8   -- a garden beat's time on screen before the next one (clock pauses when away)
Cards.IdleSeconds=1.2 -- the player stands still this long before a garden beat starts
Cards.AwaySeconds=20  -- no input for this long: the beat clock pauses (the card stays)
Cards.WelcomeSeconds=5 -- the Welcome pill's time on screen
Cards.WelcomeFadeIn=.25;Cards.WelcomeFadeOut=.4
Cards.BoardSeconds=6  -- fill-line and item cards on the board
Cards.ArrivalSeconds=20 -- the "a friend arrived" card (it has a button, so it stays longer)
Cards.Width=460
Cards.Machines=table.freeze({"hatch","style","companions","quests","book"})
-- Tint (Kit.Tint key) and icon per card.
Cards.Spec=table.freeze({
 welcome={tint="results",icon="egg"},
 machines={tint="hatch",icon="target"},hub={tint="quests",icon="settings"},quest={tint="quests",icon="quests"},
 fillLine={tint="hatch",icon="target"},item={tint="results",icon="sparkle"},questDone={tint="quests",icon="check"},
 hatch={tint="hatch",icon="egg"},style={tint="style",icon="faceplate"},companions={tint="companions",icon="paw"},
 quests={tint="quests",icon="quests"},book={tint="book",icon="book"},park={tint="companions",icon="paw"},
 petArrived={tint="companions",icon="paw"},
})

-- ── Pure rules (spec-checked) ───────────────────────────────────────────────
-- Title and line for a card. vars: {pet, reward, input = "Keyboard"|"Gamepad"|"Touch"}.
function Cards.copy(id,vars)
 vars=vars or {}
 local fill={pet=vars.pet or "Bear",reward=vars.reward or Coach.WelcomeStars}
 if id=="hub"then
  local key=if vars.input=="Gamepad"then "coach.hub.pad"elseif vars.input=="Touch"then "coach.hub.touch"else "coach.hub.key"
  return UICopy.get("coach.hub.title"),UICopy.get(key)
 end
 if id=="petArrived"then return UICopy.get("e2.arrived.title",fill),UICopy.get("e2.arrived.line",fill)end
 return UICopy.get("coach."..id..".title",fill),UICopy.get("coach."..id..".line",fill)
end
-- Slice E: "a friend arrived". Which earned pet has arrived and not been greeted yet?
-- ctx: {mask, seen, inventoryMask, earned = the EarnedPets module (default: Shared's)}.
-- Shown once ever (coach bit petArrived), to veterans too (the 7th stamp is never a new
-- player), and never while EarnedPets.enabled(pet) is false. Returns a pet id or nil.
function Cards.arrivalDue(ctx)
 ctx=ctx or {}
 local earned=ctx.earned or earnedPets()
 if type(earned)~="table"or type(earned.enabled)~="function"then return nil end
 if Coach.Bits.petArrived==nil or Coach.has(ctx.mask,"petArrived")then return nil end
 if type(ctx.seen)=="table"and ctx.seen.petArrived then return nil end
 local mask=if type(ctx.inventoryMask)=="number"then ctx.inventoryMask else 0
 for _,petId in ipairs(earned.Order or {})do
  if Pets.byId[petId]and earned.enabled(petId)and Eggs.isOwned(mask,petId)then return petId end
 end
 return nil
end
-- May the arrival card show now? Only in the free garden, settled, with no reveal open.
function Cards.arrivalReady(ctx,roomFor)
 return ctx.mode=="Room"and Cards.gardenFree(ctx)and not ctx.revealPending and(roomFor or 0)>=Coach.GardenSettle
  and(ctx.awayFor or 0)<Cards.AwaySeconds
end
-- Which one-time machine card is due? open = {hatch=bool,...}, used = attract.used (station ids).
function Cards.machineDue(open,used,ctx)
 open=open or {};used=used or {}
 -- The reveal (the starter Bear's too) plays on the Hatch eggs screen: no first-visit card
 -- over it; the card waits for a real visit once the reveal is closed (QA v2 R1.5).
 if ctx and ctx.revealPending then return nil end
 for _,id in ipairs(Cards.Machines)do
  if open[id]and Coach.wants(id,ctx)then return id end
 end
 for station,id in pairs(Coach.Stations)do
  if id~="park"and used[station]and Coach.wants(id,ctx)then return id end
 end
 return nil
end
-- Board card: which one now? ctx: phase, owned, mode, presented, over, merges, pressure, belt, mask, seen, totalWins.
function Cards.boardDue(ctx)
 if ctx.mode~="Board"or not ctx.presented then return nil end
 if(ctx.owned or 0)<=0 then
  return if ctx.phase=="Welcome"and(ctx.merges or 0)==0 then "welcome"else nil
 end
 if Coach.fillWanted(ctx)then return "fillLine"end
 if(ctx.belt or 0)>0 and ctx.over~=true and Coach.wants("item",ctx)then return "item"end
 return nil
end

-- Any machine screen open (open = {hatch=bool,...}).
function Cards.menuOpen(open)
 for _,on in pairs(open or {})do if on then return true end end
 return false
end
-- The garden is open: roaming, no menu (a shown beat hides otherwise).
function Cards.gardenOpen(ctx)
 return ctx.canRoam==true and not Cards.menuOpen(ctx.open)
end
-- The garden is free for a beat to start: open, and the window focused.
function Cards.gardenFree(ctx)
 return Cards.gardenOpen(ctx)and ctx.windowActive~=false
end
-- May a garden beat start now? ctx as step's (idleFor: seconds the player has stood still,
-- nil = unknown/still; awayFor: seconds since the last input, nil = 0), roomFor: seconds
-- the garden has been free, replay: the player asked to see the tips again.
function Cards.beatMayStart(ctx,roomFor,replay)
 if not Cards.gardenFree(ctx)then return false end
 if ctx.idleFor~=nil and ctx.idleFor<Cards.IdleSeconds then return false end
 if(ctx.awayFor or 0)>=Cards.AwaySeconds then return false end
 if(roomFor or 0)<Coach.GardenSettle then return false end
 if replay then return(ctx.owned or 0)>0 and not ctx.revealPending end
 return Coach.gardenReady({mask=ctx.mask,seen=ctx.seen,totalWins=ctx.totalWins,owned=ctx.owned,revealPending=ctx.revealPending,canRoam=true,roomFor=roomFor})
end
-- Does a shown card's clock run? Paused while the window is unfocused or the player is
-- away; a beat also pauses while the garden is not free (it hides then).
function Cards.clockRuns(ctx,kind)
 if ctx.windowActive==false or(ctx.awayFor or 0)>=Cards.AwaySeconds then return false end
 return(kind~="beat"and kind~="arrival")or Cards.gardenOpen(ctx)
end
-- Welcome pill: the longest line that fits `width` px (Strong 13), then the shorter ones.
function Cards.welcomeText(width)
 local copy=UICopy.section("r1.welcomePill")or {}
 local lines={copy.wide,copy.mid,copy.narrow}
 for _,line in ipairs(lines)do
  if line and Kit.measure(line,"Strong",13).X<=width then return line end
 end
 return lines[#lines]or ""
end
-- Welcome pill transparency at `age` seconds (fade in, hold, fade out); 1 = gone.
function Cards.welcomeFade(age,reduced)
 if age<0 then return 1 end
 if reduced then return if age<Cards.WelcomeSeconds+Cards.WelcomeFadeOut then 0 else 1 end
 if age<Cards.WelcomeFadeIn then return 1-age/Cards.WelcomeFadeIn end
 if age<Cards.WelcomeSeconds then return 0 end
 return math.clamp((age-Cards.WelcomeSeconds)/Cards.WelcomeFadeOut,0,1)
end

-- ── Instances ───────────────────────────────────────────────────────────────
local function card(parent,name,z,interactive)
 local root=Kit.node(if interactive then "TextButton"else "Frame",parent,{Name=name,BorderSizePixel=0,ZIndex=z,Active=interactive==true,
  AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,12),Size=UDim2.fromOffset(Cards.Width,72),Visible=false})
 if interactive then root.Text="";root.AutoButtonColor=false;root.Selectable=false end
 Kit.paint(root,"BackgroundColor3","panel");root.BackgroundTransparency=.04
 Kit.corner(root,Kit.Radius.card)
 local stroke=Kit.stroke(root,"stars",2,0)
 local disc=Kit.frame(root,"Disc",nil,UDim2.fromOffset(14,14),UDim2.fromOffset(40,40),999);disc.BackgroundTransparency=0
 local title=Kit.text(root,"Name","","text",{Name="Title",Position=UDim2.fromOffset(66,10),Size=UDim2.new(1,-120,0,24),TextSize=18,TextScaled=true,TextTruncate=Enum.TextTruncate.AtEnd})
 Kit.node("UITextSizeConstraint",title,{MaxTextSize=18,MinTextSize=13})
 local line=Kit.text(root,"Body","","soft",{Name="Line",Position=UDim2.fromOffset(66,34),Size=UDim2.new(1,-80,0,20),TextSize=15,TextWrapped=true,TextYAlignment=Enum.TextYAlignment.Top})
 -- Time left: a hairline along the bottom that drains.
 local bar=Kit.frame(root,"Time",nil,UDim2.new(0,16,1,-5),UDim2.new(1,-32,0,2),999);bar.BackgroundTransparency=0;bar.BackgroundColor3=Kit.Color.stars
 local scale=Kit.node("UIScale",root,{Scale=1})
 return{root=root,stroke=stroke,disc=disc,title=title,line=line,bar=bar,scale=scale,icon=nil,iconName=nil}
end

-- options: {gui = PlayerGui parent, boardParent = the deck's device root, z = board z,
--   send = function(id) (the coachMark remote), toaster = optional Kit.toaster host}
function Cards.new(options)
 options=options or {}
 local self=setmetatable({options=options,mask=0,totalWins=0,owned=0,seen={},beat=nil,garden=nil,boardCard=nil,
  questDone=false,questToldPending=false,starterStars=nil,toldStars=false,roomSince=nil},Cards)
 local gui=Kit.node("ScreenGui",options.gui,{Name="EggDropCoach",ResetOnSpawn=false,DisplayOrder=14,IgnoreGuiInset=false,
  ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 self.gui=gui
 local host=Kit.node("Frame",gui,{Name="CoachHost",BackgroundTransparency=1,Size=UDim2.fromScale(1,1),ZIndex=1,Active=false})
 self.host=host
 self.gardenView=card(host,"CoachCard",40,true)
 -- Skip (garden beats) / close (one-time cards): a 36 px hit inside the card's top right.
 local close=Kit.node("TextButton",self.gardenView.root,{Name="Skip",Text="",AutoButtonColor=false,BackgroundTransparency=1,Selectable=false,
  AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-6,0,6),Size=UDim2.fromOffset(52,28),ZIndex=self.gardenView.root.ZIndex+3})
 self.skipLabel=Kit.text(close,"Label",UICopy.get("coach.skip"),"dim",{Name="Text",Size=UDim2.fromScale(1,1),TextXAlignment=Enum.TextXAlignment.Center})
 self.skip=close
 close.Activated:Connect(function()self:dismiss("skip")end)
 self.gardenView.root.Activated:Connect(function()self:dismiss("tap")end)
 -- Beat dots (garden step only).
 local dots=Kit.frame(self.gardenView.root,"Beats",nil,UDim2.new(1,-48,1,-16),UDim2.fromOffset(36,6))
 self.dots={}
 for i=1,#Coach.GardenBeats do
  local d=Kit.frame(dots,"Dot"..i,nil,UDim2.fromOffset((i-1)*12,0),UDim2.fromOffset(6,6),999);d.BackgroundTransparency=0
  self.dots[i]=d
 end
 self.dotsRoot=dots
 -- Slice E: the arrival card's "Say hi" (switches the companion). Hidden on every other card.
 local sayHi=Kit.button(self.gardenView.root,"SayHi",{variant="primary",text=UICopy.get("e2.arrived.sayHi"),size=Vector2.new(150,40),textSize=16,selectable=false})
 sayHi.Visible=false;sayHi.ZIndex=self.gardenView.root.ZIndex+3
 sayHi.Activated:Connect(function()self:sayHi()end)
 self.sayHiButton=sayHi
 -- Board cards: their own host over the board rect (like BoardHints), never take input.
 if options.boardParent then
  local boardHost=Kit.node("Frame",options.boardParent,{Name="CoachBoard",BackgroundTransparency=1,ZIndex=options.z or 38,Active=false,Size=UDim2.fromOffset(0,0)})
  self.boardHost=boardHost
  self.boardView=card(boardHost,"CoachBoardCard",(options.z or 38)+1,false)
  self.boardView.root.Position=UDim2.new(.5,0,0,8)
  -- Welcome pill (QA v2 R6.2, moved to R1): small and quiet at the top of the board, so
  -- the aim guide stays clear. A CanvasGroup so one GroupTransparency fades all of it.
  local pill=Kit.node("CanvasGroup",boardHost,{Name="CoachWelcomePill",BackgroundTransparency=.12,BorderSizePixel=0,Active=false,
   AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,6),Size=UDim2.fromOffset(200,28),ZIndex=(options.z or 38)+2,Visible=false,GroupTransparency=1})
  Kit.paint(pill,"BackgroundColor3","panel");Kit.corner(pill,999)
  Kit.stroke(pill,"stars",1,.35)
  local egg=Kit.icon(pill,"egg",14,"stars");egg.AnchorPoint=Vector2.new(0,.5);egg.Position=UDim2.new(0,10,.5,0)
  self.pillText=Kit.text(pill,"Strong","","text",{Name="Line",Position=UDim2.fromOffset(30,0),Size=UDim2.new(1,-30,1,0),TextSize=13,TextXAlignment=Enum.TextXAlignment.Left})
  self.sticker=Kit.text(pill,"Counter","","stars",{Name="Reward",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-10,0,0),Size=UDim2.fromOffset(40,28),TextSize=13,TextXAlignment=Enum.TextXAlignment.Right})
  self.welcomePill=pill
  -- Board tips (fill line, first item; Spencer QA v2 phone: the card was far too
  -- intrusive): the same quiet pill as the Welcome, one short line, fades on its own.
  local tip=Kit.node("CanvasGroup",boardHost,{Name="CoachBoardPill",BackgroundTransparency=.12,BorderSizePixel=0,Active=false,
   AnchorPoint=Vector2.new(.5,0),Position=UDim2.new(.5,0,0,6),Size=UDim2.fromOffset(200,28),ZIndex=(options.z or 38)+2,Visible=false,GroupTransparency=1})
  Kit.paint(tip,"BackgroundColor3","panel");Kit.corner(tip,999)
  self.tipStroke=Kit.stroke(tip,"accent",1,.35)
  self.tipText=Kit.text(tip,"Strong","","text",{Name="Line",Position=UDim2.fromOffset(12,0),Size=UDim2.new(1,-24,1,0),TextSize=13,TextXAlignment=Enum.TextXAlignment.Center,TextTruncate=Enum.TextTruncate.AtEnd})
  self.boardPill=tip
 end
 -- The first-Stars toast sits under the garden card, never on it.
 self.toaster=Kit.toaster(host)
 self.toaster.placement=function()
  local view=self.gardenView.root
  return nil,(if view.Visible then view.Position.Y.Offset+view.Size.Y.Offset+10 else 12),false
 end
 return self
end

-- The board rect (the board viewport's UDim2s), as BoardHints:place.
function Cards:place(position,size)
 if not self.boardHost then return end
 self.boardHost.Position=position;self.boardHost.Size=size
 local W=size.X.Offset
 if W<=0 then W=self.boardHost.AbsoluteSize.X end
 self.boardW=W
end

-- Snapshot (owner): the saved mask, wins, the starter receipt and quest progress.
function Cards:sync(snapshot)
 if type(snapshot)~="table"then return end
 self.mask=Coach.merge(self.mask,Coach.mask(snapshot.coachMask))
 self.totalWins=type(snapshot.totalWins)=="number"and snapshot.totalWins or self.totalWins
 if type(snapshot.inventoryMask)=="number"then self.inventoryMask=snapshot.inventoryMask end
 local hatch=snapshot.lastHatch
 self.revealPending=type(hatch)=="table"
 if type(hatch)=="table"and hatch.starter==true then
  self.starterStars=if type(hatch.stars)=="number"then hatch.stars else Coach.WelcomeStars
 end
 -- First quest complete: a quest turning ready while this client watches (a save that
 -- already had one done when it joined sets the baseline and shows nothing).
 local done=Coach.questDone(snapshot.quests)
 if done and not self.questDone then
  self.questDone=true;self.questToldPending=self.synced==true
 end
 self.synced=true
end
function Cards:ctx(extra)
 local ctx={mask=self.mask,seen=self.seen,totalWins=self.totalWins,owned=self.owned,revealPending=self.revealPending,inventoryMask=self.inventoryMask}
 if extra then for key,value in pairs(extra)do if ctx[key]==nil then ctx[key]=value end end end
 return ctx
end
-- Shown once ever: remember for the session, save the bit (the server ORs it in).
function Cards:mark(id)
 if not Coach.Bits[id]or self.seen[id]then return end
 self.seen[id]=true
 self.mask=Coach.with(self.mask,id)
 if self.options.send then self.options.send(id)end
 if self.options.learned then
  for station,bitId in pairs(Coach.Stations)do if bitId==id then self.options.learned(station)end end
 end
end
function Cards:learned()
 if not self.options.learned then return end
 for station,id in pairs(Coach.Stations)do if Coach.has(self.mask,id)then self.options.learned(station)end end
end

local function paintCard(view,id,title,line,width)
 local spec=Cards.Spec[id]or Cards.Spec.welcome
 local tint=Kit.tintColor(spec.tint)or Kit.Color.stars
 view.stroke.Color=tint;view.disc.BackgroundColor3=tint;view.bar.BackgroundColor3=tint
 if view.iconName~=spec.icon then
  if view.icon then view.icon:Destroy()end
  view.icon=Kit.icon(view.disc,spec.icon,22,"ink");view.icon.AnchorPoint=Vector2.new(.5,.5);view.icon.Position=UDim2.fromScale(.5,.5)
  view.iconName=spec.icon
 end
 view.title.Text=title;view.line.Text=line
 -- Height from the wrapped line (Kit.measure is the cached synchronous measure).
 local lineW=math.max(60,width-80)
 -- Headroom: the cached measure uses a legacy font a little narrower than the drawn face,
 -- and LineHeight spaces the lines (Studio capture showed the second line cut off).
 local h=math.ceil(Kit.measure(line,"Body",15,math.floor(lineW*.88)).Y*(Kit.LineHeight or 1))
 view.line.Size=UDim2.new(1,-80,0,h+2)
 view.root.Size=UDim2.fromOffset(width,math.max(72,34+h+18))
end

function Cards:gardenWidth()
 local W=self.host.AbsoluteSize.X
 if W<=0 then return Cards.Width end
 -- The Menu + Deck dock moved to the bottom right (QA v2 R2), so the top centre only keeps
 -- clear of the Roblox controls: a 24 px gutter on phones, up to the full card width.
 return math.floor(math.clamp(W-2*24,240,Cards.Width))
end

-- Garden card: kind "beat" (the guided step) or "once" (a one-time card). `machine` ties a
-- first-visit card to its screen, so it leaves with it.
function Cards:showGarden(id,kind,vars,now,machine)
 local view=self.gardenView
 local title,line=Cards.copy(id,vars)
 paintCard(view,id,title,line,self:gardenWidth())
 local beatIndex=if kind=="beat"then table.find(Coach.GardenBeats,id)else nil
 self.dotsRoot.Visible=beatIndex~=nil
 for i,d in ipairs(self.dots)do d.BackgroundColor3=if beatIndex and i<=beatIndex then Kit.Color.stars else Kit.Color.dim end
 self.skipLabel.Text=string.upper(if kind=="beat"then UICopy.get("coach.skip")else UICopy.get("coach.gotIt"))
 self.skip.Size=UDim2.fromOffset(math.ceil(Kit.measure(self.skipLabel.Text,"Label",13).X)+20,28)
 view.title.Size=UDim2.new(1,-80-self.skip.Size.X.Offset,0,24)
 -- Slice E: the arrival card grows a button row under its line.
 local arrival=kind=="arrival"
 self.sayHiButton.Visible=arrival
 if arrival then
  local height=view.root.Size.Y.Offset
  local buttonW=math.min(150,view.root.Size.X.Offset-66-16)
  self.sayHiButton.Size=UDim2.fromOffset(buttonW,40);self.sayHiButton.Position=UDim2.fromOffset(66,height-12)
  view.root.Size=UDim2.fromOffset(view.root.Size.X.Offset,height+40)
 end
 view.root.Visible=true
 self.garden={id=id,kind=kind,shownAt=now,elapsed=0,machine=machine,petId=if arrival and type(vars)=="table"then vars.petId else nil,
  duration=if kind=="beat"then Cards.BeatSeconds elseif arrival then Cards.ArrivalSeconds else Cards.Duration}
 if not Kit.reduced()then view.scale.Scale=.9;Kit.tween(view.scale,Kit.Motion.toastIn,{Scale=1})end
 view.root:SetAttribute("CoachCard",id)
end
function Cards:hideGarden()
 self.garden=nil
 self.gardenView.root.Visible=false
 self.gardenView.root:SetAttribute("CoachCard",nil)
 if self.sayHiButton then self.sayHiButton.Visible=false end
end
-- Slice E: "Say hi" on the arrival card: the new friend becomes the companion (the caller
-- sends the existing `companion` action), then the card's bit is saved.
function Cards:sayHi()
 local current=self.garden
 if not current or current.kind~="arrival"then return false end
 self:hideGarden()
 if self.options.sayHi and current.petId then self.options.sayHi(current.petId)end
 self:mark("petArrived")
 return true
end
-- A tap moves the garden step on; Skip ends it; a one-time card just closes.
function Cards:dismiss(how)
 local current=self.garden
 if not current then return false end
 -- The arrival card has its own button: a stray tap on the card keeps it; "Got it" closes
 -- it for good without switching the companion.
 if current.kind=="arrival"then
  if how~="skip"then return false end
  self:hideGarden();self:mark("petArrived");return true
 end
 self:hideGarden()
 if current.kind=="beat"then
  if how=="skip"then self:finishGarden()else self:advance(current.id)end
 end
 return true
end
function Cards:advance(id)
 local nextBeat=Coach.nextBeat(id)
 self.beat=nextBeat
 if not nextBeat then self:finishGarden()end
end
function Cards:finishGarden()
 self.beat=nil;self.gardenDone=true;self.replaying=false
 self:mark("gardenIntro")
end
-- Show the garden tips again (a "Show tips again" entry, e.g. R3's How it works, calls
-- this). The beats start over from the first, under the same rules as the first time.
function Cards:replayGarden()
 if self.garden and self.garden.kind=="beat"then self:hideGarden()end
 self.gardenDone=false;self.replaying=true;self.beat=nil;self.roomSince=nil
 return true
end

-- Per frame. ctx (from the caller): mode ("Board"|"Room"), canRoam, presented (the board
-- is on screen), phase, over, merges, drops, pressure, belt (items on the belt), owned,
-- input, open = {hatch, style, companions, quests, book} (machine screens open), used
-- (attract stations used this session), pet (the companion's name), windowActive,
-- idleFor (seconds the character has stood still), awayFor (seconds since any input).
function Cards:step(now,ctx)
 self.owned=ctx.owned or self.owned
 local base=self:ctx(ctx)
 local dt=math.max(0,now-(self.lastNow or now));self.lastNow=now
 -- Garden ----------------------------------------------------------------
 local current=self.garden
 if current then
  if Cards.clockRuns(ctx,current.kind)then current.elapsed+=dt end
  local elapsed=current.elapsed
  local gone=elapsed>=current.duration
   or((current.kind=="beat"or current.kind=="arrival")and not Cards.gardenOpen(ctx))
   or(current.machine and not(ctx.open and ctx.open[current.machine]))
  if gone then
   self:hideGarden()
   -- A beat that ran out moves on; one hidden by a menu shows again when the garden is free.
   if current.kind=="beat"and elapsed>=current.duration then self:advance(current.id)end
   -- The arrival card that ran its full time is done (shown once ever); one hidden by a
   -- menu comes back when the garden is free.
   if current.kind=="arrival"and elapsed>=current.duration then self:mark("petArrived")end
  else
   self.gardenView.bar.Size=UDim2.new(math.clamp(1-elapsed/current.duration,0,1),-32,0,2)
  end
 end
 -- Time free in the garden (no menu, no open reveal): the garden step waits for it.
 if ctx.mode=="Room"and Cards.gardenFree(ctx)and not self.revealPending then self.roomSince=self.roomSince or now else self.roomSince=nil end
 if not self.garden then
  local vars={pet=ctx.pet,input=ctx.input,reward=self.starterStars}
  local machine=Cards.machineDue(ctx.open,ctx.used,base)
  local roomFor=if self.roomSince then now-self.roomSince else 0
  if machine then
   self:mark(machine);self:showGarden(machine,"once",vars,now,if ctx.open and ctx.open[machine]then machine else nil)
  elseif not self.gardenDone and Cards.beatMayStart(base,roomFor,self.replaying) then
   self.beat=self.beat or Coach.nextBeat(nil)
   if self.beat then self:showGarden(self.beat,"beat",vars,now)end
   -- The Welcome round's Stars, said once as the garden step opens (under the card).
   if self.starterStars and not self.toldStars then
    self.toldStars=true;self.toaster.show(UICopy.get("coach.firstStars.toast"),self.starterStars)
   end
  elseif Cards.arrivalDue(base)~=nil and Cards.arrivalReady(base,roomFor)then
   -- Slice E: a friend arrived (the 7th-stamp pet). Already the companion (the player
   -- switched in Companions first): nothing to offer, just save the bit.
   local petId=Cards.arrivalDue(base)
   if ctx.companionId==petId then self:mark("petArrived")
   else self:showGarden("petArrived","arrival",{pet=Pets.byId[petId].name,petId=petId},now)end
  elseif self.questToldPending and(ctx.mode~="Board"or ctx.over==true)then
   self.questToldPending=false
   if Coach.wants("questDone",base)then self:mark("questDone");self:showGarden("questDone","once",vars,now)end
  elseif ctx.canRoam and ctx.used and ctx.used.Park and Coach.wants("park",base)then
   self:mark("park");self:showGarden("park","once",vars,now)
  end
 end
 -- Board ------------------------------------------------------------------
 if self.boardView then self:stepBoard(now,ctx,base)end
end

-- The Welcome pill (QA v2 R6.2): shown once per session in the Welcome round, from the
-- first presented frame until ~5 s pass or the first drop (or merge), then it fades.
function Cards:stepWelcome(now,ctx,wanted)
 local pill=self.welcomePill;if not pill then return end
 if wanted and((ctx.drops or 0)>0 or(ctx.merges or 0)>0)and self.welcomeAt then self.welcomeOutAt=self.welcomeOutAt or now end
 if wanted and not self.welcomeDone and not self.welcomeAt then
  self.welcomeAt=now;self.welcomeOutAt=nil
  local width=math.floor(math.clamp((self.boardW or 300)-16,120,340))
  self.sticker.Text="★ +"..Coach.WelcomeStars
  local starW=math.ceil(Kit.measure(self.sticker.Text,"Counter",13).X)+10
  local text=Cards.welcomeText(width-30-starW-14)
  self.pillText.Text=text
  local textW=math.ceil(Kit.measure(text,"Strong",13).X)+2
  pill.Size=UDim2.fromOffset(math.min(width,30+textW+8+starW+10),28)
  self.pillText.Size=UDim2.new(0,textW,1,0)
  pill.Visible=true;pill:SetAttribute("CoachCard","welcome")
 end
 if not self.welcomeAt or self.welcomeDone then
  if pill.Visible then pill.Visible=false;pill:SetAttribute("CoachCard",nil)end
  return
 end
 local reduced=Kit.reduced()
 local fade=Cards.welcomeFade(now-self.welcomeAt,reduced)
 -- Leaving early (the first drop, the round over, the board gone): a quick fade out.
 if not wanted and not self.welcomeOutAt then self.welcomeOutAt=now end
 if self.welcomeOutAt then
  local out=if reduced then 1 else math.clamp((now-self.welcomeOutAt)/.25,0,1)
  fade=math.max(fade,out)
 end
 pill.GroupTransparency=fade
 if fade>=1 and now-self.welcomeAt>Cards.WelcomeFadeIn then
  self.welcomeDone=true;pill.Visible=false;pill:SetAttribute("CoachCard",nil)
 end
end
function Cards:stepBoard(now,ctx,base)
 local view=self.boardView
 local due=Cards.boardDue(base)
 self:stepWelcome(now,ctx,due=="welcome")
 local shown=self.boardCard
 if shown then
  if ctx.mode=="Board"and ctx.presented and now-shown.shownAt<Cards.BoardSeconds then
   view.bar.Size=UDim2.new(math.clamp(1-(now-shown.shownAt)/Cards.BoardSeconds,0,1),-32,0,2)
   return
  end
  self.boardCard=nil;view.root.Visible=false;view.root:SetAttribute("CoachCard",nil)
 end
 local tip=self.boardPill
 if tip and tip.Visible then
  local age=now-(self.tipAt or now)
  local fade=Cards.welcomeFade(age,Kit.reduced())
  if ctx.mode~="Board"then fade=1 end
  tip.GroupTransparency=fade
  if fade>=1 and age>Cards.WelcomeFadeIn then tip.Visible=false;tip:SetAttribute("CoachCard",nil)end
  return
 end
 if not due or due=="welcome"then return end
 self:mark(due)
 if tip then
  local width=math.floor(math.clamp((self.boardW or 300)-16,120,340))
  local text=UICopy.get("coach."..due..".short")
  self.tipText.Text=text
  local textW=math.ceil(Kit.measure(text,"Strong",13).X)+2
  tip.Size=UDim2.fromOffset(math.min(width,textW+24),28)
  tip.Visible=true;tip.GroupTransparency=1;tip:SetAttribute("CoachCard",due)
  self.tipAt=now
  return
 end
 local width=math.floor(math.clamp((self.boardW or 300)-16,200,380))
 local title,line=Cards.copy(due,{pet=ctx.pet,input=ctx.input,reward=Coach.WelcomeStars})
 paintCard(view,due,title,line,width)
 view.bar.Visible=true
 view.bar.Size=UDim2.new(1,-32,0,2)
 view.title.Size=UDim2.new(1,-80,0,24)
 view.root.Visible=true;view.root:SetAttribute("CoachCard",due)
 if not Kit.reduced()then view.scale.Scale=.9;Kit.tween(view.scale,Kit.Motion.toastIn,{Scale=1})end
 self.boardCard={id=due,shownAt=now}
end

function Cards:destroy()
 self.gui:Destroy()
 if self.boardHost then self.boardHost:Destroy()end
end

return Cards
