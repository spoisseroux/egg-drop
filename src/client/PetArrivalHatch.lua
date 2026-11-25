-- Round 3 (Spencer 2026-11-20: "the bunny should have an awesome hatch animation like the bear!
-- make it epic"). An earned pet's arrival as a hatch: the Companion Egg wobbles, cracks and opens
-- on the full-screen RevealStage and the Bunny jumps out with the Rare pet jackpot (RevealStage.Rare,
-- on the pet's own clock). It plays where the arrival card used to and instead of it
-- (CoachCards.arrivalDue / arrivalReady: a paid, earned or granted pet, the free garden with no
-- menu open, saved once through coach bit petArrived); its Meet does what the card's Say hi did.
-- Client only: nothing is granted or saved here.
-- Host rules (architect review): an own ScreenGui above the menus (DisplayOrder 16, as
-- StatEggReveal), one HatchDisplayScene (kind "companion") in a hidden home frame, the stage on an
-- external clock this host drives every frame and holds at zero until the scene is ready (the pet's
-- AuthoredMesh; the scene times itself out at 3.5 s), the tier line from HatchRarityCue, a key sink
-- so nothing reaches the character, the movement lock, and the top-bar rail held while it is up.
--   local hatch=PetArrivalHatch.new(playerGui,audio)
--   hatch:play(petId,{appearance=,name=,onDone=function(meet)end}) -> true when it opened
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local RunService=game:GetService("RunService")
local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
local Kit=require(script.Parent.DeckKit)
local RevealStage=require(script.Parent.RevealStage)
local Pose=require(script.Parent.HatchDisplayPose)
local Rarity=require(script.Parent.HatchRarityCue)
local Lock=require(script.Parent.MovementLock)
local Hatch={};Hatch.__index=Hatch
Hatch.DisplayOrder=16;Hatch.Action="EggDropArrivalHatch";Hatch.Priority=Enum.ContextActionPriority.High.Value+830
Hatch.LockReason="arrivalHatch";Hatch.DrainSeconds=.15
local K=Enum.KeyCode
-- Every key the garden or the character would take (walk, jump, interact, the menus' B / Esc).
Hatch.Keys=table.freeze({K.Space,K.W,K.A,K.S,K.D,K.E,K.Q,K.Up,K.Down,K.Left,K.Right,
 K.ButtonA,K.ButtonB,K.Return,K.KeypadEnter,K.Escape,K.Backspace})

-- ── Pure rules (specs cover these) ───────────────────────────────────────────
-- The hatch's result (never a server receipt) and its presentation tier (the Bunny is Rare).
function Hatch.result(petId)
 local tier=Rarity.tier("companion",{petId=petId})
 return {id="arrival:"..tostring(petId),petId=petId,rare=tier=="Rare",arrival=true},tier
end
-- The host clock runs until the tier line has played (under Reduced Motion the sting sits at
-- 0.30 s, past the pet's 0.15 s cross-fade), then holds on the settled frame.
function Hatch.clockEnd(tier,reduced)
 local T=Rarity.timing(tier,"companion",reduced==true)
 local finish=T.duration
 for _,event in ipairs(Rarity.events(tier,T.ready,reduced==true,"companion"))do finish=math.max(finish,event.at+.1)end
 return finish
end
-- A press settles the stage only once the receipt is ready: the once-ever hatch plays in full
-- (Fable brief 3, as the first Bear's does), and the input opens with the buttons.
function Hatch.canSkip(age,tier,reduced)return(age or 0)>=Rarity.timing(tier,"companion",reduced==true).ready end
-- What a sunk key does here: B / Esc / Backspace close a settled stage (the bit is saved, the
-- companion stays) and only settle it before; every other key is the stage's own (RevealStage
-- reads them itself) or is kept from the character.
function Hatch.keyAction(key,settled)
 if key==K.ButtonB or key==K.Escape or key==K.Backspace then return if settled then "close"else "settle"end
 return "sink"
end

-- The top-bar rail waits under the hatch (its tickets keep their time): NotificationRail holds
-- while Rail.held() is true, so the hatch joins that check once.
local holds,wrapped=0,false
local function holdRail(on)
 if not wrapped then
  wrapped=true
  local ok,Rail=pcall(require,script.Parent.NotificationRail)
  if ok and type(Rail)=="table"and type(Rail.held)=="function"then
   local base=Rail.held
   Rail.held=function()return holds>0 or base()end
  end
 end
 holds=math.max(0,holds+(if on then 1 else -1))
end
function Hatch.railHeld()return holds>0 end

-- ── Host ────────────────────────────────────────────────────────────────────
function Hatch.new(playerGui,audio)
 local gui=Instance.new("ScreenGui");gui.Name="EggDropArrivalHatch";gui.ResetOnSpawn=false;gui.DisplayOrder=Hatch.DisplayOrder
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ScreenInsets=Enum.ScreenInsets.None;gui.IgnoreGuiInset=true;gui.Enabled=false;gui.Parent=playerGui
 local host=Instance.new("Frame");host.Name="StageHost";host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui
 local home=Instance.new("Frame");home.Name="ArrivalSceneHome";home.BackgroundTransparency=1;home.Size=UDim2.fromScale(1,1);home.Visible=false;home.Parent=gui
 local self=setmetatable({gui=gui,host=host,home=home,audio=audio,open=false,age=0},Hatch)
 -- Beta (17) U2: the Meet button needs a free PC cursor (ModalCursor's registry).
 self.unregisterCursor=require(script.Parent.ModalCursor).register(self,function()return self.open end)
 return self
end
function Hatch:isOpen()return self.open end
function Hatch:play(petId,info)
 if self.open or self.destroyed then return false end
 local pet=Pets.byId[petId];if not pet then return false end
 info=info or {}
 local result,tier=Hatch.result(petId)
 local reduced=Kit.reduced()
 self.petId,self.tier,self.reducedStart,self.onDone=petId,tier,reduced,info.onDone
 self.age,self.owner,self.skippedAt=0,{},nil
 self.timing=Rarity.timing(tier,"companion",reduced)
 self.endAt=Hatch.clockEnd(tier,reduced)
 self.cue=Rarity.new("companion",result,self.timing.ready,reduced)
 -- Open before the stage starts, so its first frame sees an owned stage.
 self.open=true;self.gui.Enabled=true
 local ok,problem=pcall(function()
  self.scene=require(script.Parent.HatchDisplayScene).new(self.home,{kind="companion",pet=pet,result=result,appearance=info.appearance,reduced=reduced})
  self.stage=RevealStage.show(self.host,{pet=pet,name=info.name,appearance=info.appearance,scene=self.scene,externalClock=true,result=result,
   tag=RevealStage.tagKind(result,"companion"),description=pet.description,voice=false,audio=self.audio,
   reduced=function()return Kit.reduced()end,owns=function()return self.open end,
   buttons={{id="meet",text="Meet "..(info.name or pet.name or "friend"),glyph="A",primary=true}},
   onButton=function(id)if id=="meet"then self:finish(true)end end,
   onSkip=function()self:skip()end,
   canSkip=function()return Hatch.canSkip(self.age,tier,reduced)end,
   consumeSkipInput=function()return self.skippedAt~=nil and os.clock()-self.skippedAt<Hatch.DrainSeconds end})
 end)
 if not ok then
  warn("Arrival hatch could not open: "..tostring(problem))
  self.onDone=nil;self:close();return false
 end
 holdRail(true);self.railHold=true
 Lock.shared():acquire(Hatch.LockReason)
 ContextActionService:BindActionAtPriority(Hatch.Action,function(_,state,input)
  if not self.open or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
  if state==Enum.UserInputState.Begin and self.stage then
   local action=Hatch.keyAction(input.KeyCode,self.stage:isSettled())
   if action=="close"then self:finish(false)elseif action=="settle"then self.stage:back()end
  end
  return Enum.ContextActionResult.Sink
 end,false,Hatch.Priority,table.unpack(Hatch.Keys))
 self.clock=RunService.RenderStepped:Connect(function(dt)self:step(dt)end)
 self:step(0)
 return true
end
-- The hatch clock: sampled every frame, held at zero until the scene is ready.
function Hatch:step(dt)
 local stage,scene=self.stage,self.scene
 if not self.open or not stage or stage.destroyed or not scene then return end
 local ready=scene.ready==true
 if ready then self.age=math.min(self.endAt,self.age+math.clamp(dt or 0,0,.1))end
 local sample=Pose.sample(self.age,"companion",self.reducedStart,self.tier)
 scene:render(sample)
 stage:updateExternal(self.age,sample)
 if not ready or not self.audio or type(self.audio.play)~="function"then return end
 for _,event in ipairs(self.cue:due(self.age,sample.receiptReady==true,true))do
  pcall(function()self.audio:play(event.cue,event.speed,event.gain,self.owner)end)
 end
end
-- A settling press (RevealStage already settled itself; canSkip held it until the receipt):
-- the same press never also presses Meet.
function Hatch:skip()
 if not self.open then return false end
 self.skippedAt=os.clock()
 return true
end
-- Meet (true) or B / Esc (false): the stage leaves smoothly in its own gui, then the caller hears.
function Hatch:finish(meet)
 if not self.open then return false end
 local done=self.onDone;self.onDone=nil
 self:close()
 if done then done(meet==true)end
 return true
end
function Hatch:close()
 self.open=false
 ContextActionService:UnbindAction(Hatch.Action)
 if self.clock then self.clock:Disconnect();self.clock=nil end
 if self.cue then self.cue:cancel()end
 Lock.shared():release(Hatch.LockReason)
 if self.railHold then self.railHold=false;holdRail(false)end
 local stage,scene=self.stage,self.scene
 self.stage,self.scene=nil,nil
 if stage then
  local function gone()if scene then scene:destroy()end end
  if not stage:dismiss(gone)then stage:destroy();gone()end
 elseif scene then scene:destroy()end
 self.gui.Enabled=false
end
-- Torn down with the client gui: the bit stays unsaved, so the hatch plays next session.
function Hatch:destroy()
 if self.destroyed then return end
 self.onDone=nil
 if self.open then self:close()end
 if self.audio and type(self.audio.stopOwner)=="function"and self.owner then pcall(function()self.audio:stopOwner(self.owner)end)end
 if self.unregisterCursor then self.unregisterCursor()end
 self.destroyed=true;self.gui:Destroy()
end
return Hatch
