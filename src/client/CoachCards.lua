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
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Coach=require(Shared:WaitForChild("CoachMarks"))
local UICopy=require(Shared:WaitForChild("UICopy"))
local Kit=require(script.Parent.DeckKit)

local Cards={}
Cards.__index=Cards
Cards.Duration=7      -- a one-time card's time on screen
Cards.BeatSeconds=6   -- a garden beat's time on screen before the next one
Cards.BoardSeconds=6  -- fill-line and item cards on the board
Cards.Width=420
Cards.Machines=table.freeze({"hatch","style","companions","quests","book"})
-- Tint (Kit.Tint key) and icon per card.
Cards.Spec=table.freeze({
 welcome={tint="results",icon="egg"},
 machines={tint="hatch",icon="target"},hub={tint="quests",icon="settings"},quest={tint="quests",icon="quests"},
 fillLine={tint="hatch",icon="target"},item={tint="results",icon="sparkle"},questDone={tint="quests",icon="check"},
 hatch={tint="hatch",icon="egg"},style={tint="style",icon="faceplate"},companions={tint="companions",icon="paw"},
 quests={tint="quests",icon="quests"},book={tint="book",icon="book"},park={tint="companions",icon="paw"},
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
 return UICopy.get("coach."..id..".title",fill),UICopy.get("coach."..id..".line",fill)
end
-- Which one-time machine card is due? open = {hatch=bool,...}, used = attract.used (station ids).
function Cards.machineDue(open,used,ctx)
 open=open or {};used=used or {}
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
 -- Board cards: their own host over the board rect (like BoardHints), never take input.
 if options.boardParent then
  local boardHost=Kit.node("Frame",options.boardParent,{Name="CoachBoard",BackgroundTransparency=1,ZIndex=options.z or 38,Active=false,Size=UDim2.fromOffset(0,0)})
  self.boardHost=boardHost
  self.boardView=card(boardHost,"CoachBoardCard",(options.z or 38)+1,false)
  self.boardView.root.Position=UDim2.new(.5,0,0,8)
  self.sticker=Kit.text(self.boardView.root,"Counter","","stars",{Name="Reward",AnchorPoint=Vector2.new(1,0),Position=UDim2.new(1,-14,0,10),Size=UDim2.fromOffset(70,24),TextSize=17,TextXAlignment=Enum.TextXAlignment.Right})
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
 local ctx={mask=self.mask,seen=self.seen,totalWins=self.totalWins,owned=self.owned,revealPending=self.revealPending}
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
 -- Clear of the garden's top-right dock (Menu + Deck, 116 px) on both sides.
 return math.floor(math.clamp(W-2*128,240,Cards.Width))
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
 view.root.Visible=true
 self.garden={id=id,kind=kind,shownAt=now,duration=if kind=="beat"then Cards.BeatSeconds else Cards.Duration,machine=machine}
 if not Kit.reduced()then view.scale.Scale=.9;Kit.tween(view.scale,Kit.Motion.toastIn,{Scale=1})end
 view.root:SetAttribute("CoachCard",id)
end
function Cards:hideGarden()
 self.garden=nil
 self.gardenView.root.Visible=false
 self.gardenView.root:SetAttribute("CoachCard",nil)
end
-- A tap moves the garden step on; Skip ends it; a one-time card just closes.
function Cards:dismiss(how)
 local current=self.garden
 if not current then return false end
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
 self.beat=nil;self.gardenDone=true
 self:mark("gardenIntro")
end

-- Per frame. ctx (from the caller): mode ("Board"|"Room"), canRoam, presented (the board
-- is on screen), phase, over, merges, pressure, belt (items on the belt), owned, input,
-- open = {hatch, style, companions, quests, book} (machine screens open), used (attract
-- stations used this session), pet (the companion's name), reduced.
function Cards:step(now,ctx)
 self.owned=ctx.owned or self.owned
 local base=self:ctx(ctx)
 -- Garden ----------------------------------------------------------------
 local current=self.garden
 if current then
  local elapsed=now-current.shownAt
  local gone=elapsed>=current.duration
   or(current.kind=="beat"and not ctx.canRoam)
   or(current.machine and not(ctx.open and ctx.open[current.machine]))
  if gone then
   self:hideGarden()
   -- A beat that ran out moves on; one hidden by a menu shows again when the garden is free.
   if current.kind=="beat"and elapsed>=current.duration then self:advance(current.id)end
  else
   self.gardenView.bar.Size=UDim2.new(math.clamp(1-elapsed/current.duration,0,1),-32,0,2)
  end
 end
 -- Time free in the garden (no menu, no open reveal): the garden step waits for it.
 if ctx.mode=="Room"and ctx.canRoam and not self.revealPending then self.roomSince=self.roomSince or now else self.roomSince=nil end
 if not self.garden then
  local vars={pet=ctx.pet,input=ctx.input,reward=self.starterStars}
  local machine=Cards.machineDue(ctx.open,ctx.used,base)
  if machine then
   self:mark(machine);self:showGarden(machine,"once",vars,now,if ctx.open and ctx.open[machine]then machine else nil)
  elseif not self.gardenDone and Coach.gardenReady(self:ctx({canRoam=ctx.canRoam,roomFor=if self.roomSince then now-self.roomSince else 0})) then
   self.beat=self.beat or Coach.nextBeat(nil)
   if self.beat then self:showGarden(self.beat,"beat",vars,now)end
   -- The Welcome round's Stars, said once as the garden step opens (under the card).
   if self.starterStars and not self.toldStars then
    self.toldStars=true;self.toaster.show(UICopy.get("coach.firstStars.toast"),self.starterStars)
   end
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

function Cards:stepBoard(now,ctx,base)
 local view=self.boardView
 local shown=self.boardCard
 if shown then
  local keep
  if shown.id=="welcome"then keep=Cards.boardDue(base)=="welcome"
  else keep=ctx.mode=="Board"and ctx.presented and now-shown.shownAt<Cards.BoardSeconds end
  if keep then
   if shown.id~="welcome"then view.bar.Size=UDim2.new(math.clamp(1-(now-shown.shownAt)/Cards.BoardSeconds,0,1),-32,0,2)end
   return
  end
  self.boardCard=nil;view.root.Visible=false;view.root:SetAttribute("CoachCard",nil)
 end
 local due=Cards.boardDue(base)
 if not due then return end
 if due~="welcome"then self:mark(due)end
 local width=math.floor(math.clamp((self.boardW or 300)-16,200,380))
 local title,line=Cards.copy(due,{pet=ctx.pet,input=ctx.input,reward=Coach.WelcomeStars})
 paintCard(view,due,title,line,width)
 view.bar.Visible=due~="welcome"
 view.bar.Size=UDim2.new(1,-32,0,2)
 self.sticker.Text=if due=="welcome"then "★ +"..Coach.WelcomeStars else ""
 view.title.Size=UDim2.new(1,if due=="welcome"then -136 else -80,0,24)
 view.root.Visible=true;view.root:SetAttribute("CoachCard",due)
 if not Kit.reduced()then view.scale.Scale=.9;Kit.tween(view.scale,Kit.Motion.toastIn,{Scale=1})end
 self.boardCard={id=due,shownAt=now}
end

function Cards:destroy()
 self.gui:Destroy()
 if self.boardHost then self.boardHost:Destroy()end
end

return Cards
