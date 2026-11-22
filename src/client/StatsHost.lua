-- v2 S3: wires the stats panel and the level-up line into the client (init.client.lua
-- passes its few shared pieces in `deps`, so that file only gains a mount call and the
-- hooks that open the panel). Its own ScreenGui (DisplayOrder 13, like the book) and its
-- own ContextAction while open.
--
-- deps: parent (PlayerGui), insetProbe (Frame), state() -> nursery snapshot,
--   activeId() -> companion pet id, appearance(petId), canOpen() -> bool,
--   prepare() (close other screens), held() -> bool (a round is on: hold the line),
--   reopenHub() (Back to the Companions hub), closed(reason)
-- Levels matter (all optional): openShop(area, ref) (the reward guide's "Go to shop"; nil = no
--   shop keys), quiet() -> bool (nothing else is on screen: a medal moment may play; nil = a rail
--   ticket instead), audio and playerGui for that moment.
local ContextActionService=game:GetService("ContextActionService")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local Kit=require(script.Parent.DeckKit)
local Panel=require(script.Parent.StatsPanel)
local Toasts=require(script.Parent.StatToasts)
local Rail=require(script.Parent.NotificationRail)
local Shared=game:GetService("ReplicatedStorage").Shared
local Levels=require(Shared.Levels)
local LevelGate=require(Shared.LevelGate)
local Medals=require(Shared.Medals)
local MedalView=require(script.Parent.MedalView)
local Host={}
Host.MedalTicket=6 -- seconds a medal ticket shows

-- Pure (S4): the medal queue of one session. `watch` is {levels, pending, joined}; levels are
-- {petId={stat=level}} of a snapshot. The first sight of a pet only records it, so joining (or
-- turning the part on) never replays old medals. Returns the number of new medals queued.
function Host.watchMedals(watch,levels)
 if not Levels.on("medals")then watch.levels=nil;watch.pending={};return 0 end
 local before=watch.levels
 watch.pending=watch.pending or {}
 local known,count={},0
 if before then
  for petId,row in pairs(levels)do if before[petId]then known[petId]=row end end
  for _,medal in ipairs(Medals.crossed(before,known))do table.insert(watch.pending,medal);count+=1 end
 end
 -- Levels never fall on screen: a smaller later snapshot cannot cross a medal twice.
 local kept=before or {}
 for petId,row in pairs(levels)do
  local old=kept[petId]
  if old==nil then kept[petId]=table.clone(row)else for stat,level in pairs(row)do old[stat]=math.max(old[stat]or 0,level)end end
 end
 watch.levels=kept
 return count
end
-- Pure: medal eggs waiting in a snapshot (0 while the part is off or the field is missing).
function Host.medalEggs(state)
 local egg=type(state)=="table"and state.statEgg
 local n=type(egg)=="table"and egg.medalEggs
 return if Levels.on("medals")and type(n)=="number"and n==n and n>=1 then math.floor(n)else 0
end

function Host.mount(deps)
 local gui=Instance.new("ScreenGui")
 gui.Name="EggDropStats";gui.ResetOnSpawn=false;gui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets;gui.DisplayOrder=13
 gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.ClipToDeviceSafeArea=false;gui.Parent=deps.parent
 local host=Instance.new("Frame");host.Name="StatsHost";host.BackgroundTransparency=1;host.Size=UDim2.fromScale(1,1);host.Parent=gui
 local function syncInsets()
  local wanted=Kit.compactInsets(deps.insetProbe.AbsoluteSize)
  if gui.ScreenInsets~=wanted then gui.ScreenInsets=wanted end
 end
 local connections={deps.insetProbe:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncInsets)}
 local function context()
  local state=deps.state()
  return{wallet=state and state.nectar or 0,state=state or {},activeId=deps.activeId(),inRound=deps.inRound~=nil and deps.inRound()==true}
 end
 local api={}
 local panel=Panel.new(host,{
  appearance=function(petId)return deps.appearance(petId)end,
  back=function(from)if from=="hub"and deps.reopenHub then deps.reopenHub()end end,
  closed=function(reason,from)if deps.closed then deps.closed(reason,from)end end,
  -- v2 Stat Snacks (SnackHost): feed in place on the preview, step its eating, Hatch eggs.
  feed=function(snackId,options)return deps.feed~=nil and deps.feed(snackId,options)==true end,
  step=function(dt)if deps.step then deps.step(dt)end end,
  cancelFeed=function()if deps.cancelFeed then deps.cancelFeed()end end,
  openEggs=deps.openEggs,
  shop=if deps.openShop then function(row)deps.openShop(row.area,row.ref)end else nil})
 api.panel=panel
 -- options: stat, petId, from ("hub" | "focus" | "rail"), slideFrom.
 function api.open(options)
  if panel:isOpen()or api.isBusy()or not deps.state()or not deps.canOpen()then return false end
  deps.prepare()
  if GuiService.SelectedObject then GuiService.SelectedObject=nil end
  syncInsets()
  return panel:open(context(),options)
 end
 function api.isOpen()return panel:isOpen()end
 -- The store route reopens this panel as it was.
 function api.current()return if panel:isOpen()then{petId=panel.petOverride,from=if panel.from=="hub"then "hub"else nil,stat=Panel.Order[panel.index],snacks=if panel.mode=="snacks"then true else nil,
  guide=if panel.mode=="guide"then true else nil}else nil end
 function api.close(reason)return panel:close(reason or "close")end
 -- The medal moment (S4): medals crossed this session, one stage for all that wait together.
 local watch,moment={},nil
 function api.isBusy()return moment~=nil and moment:isOpen()end
 local function eggsRoute()
  if not deps.openEggs then return false end
  if panel:isOpen()then panel:close("eggs")end
  deps.openEggs();return true
 end
 local function medalTicket(key,text,stat,petId)
  if not text then return end
  Rail.enqueue(host,key,{text=text,icon="★",duration=Host.MedalTicket,activate=function()
   if not stat then return eggsRoute()end
   if panel:focusStat(stat,petId)then return true end
   return api.open({stat=stat,petId=petId,from="rail"})
  end})
 end
 local function medalStep()
  if not watch.pending or #watch.pending==0 or api.isBusy()or panel.feeding then return end
  if deps.held and deps.held()then return end
  if deps.quiet and deps.playerGui then
   if panel:isOpen()or deps.quiet()~=true or not deps.canOpen()then return end
   local crossed=watch.pending;watch.pending={}
   moment=moment or MedalView.Moment.new(deps.playerGui,deps.audio)
   moment:show(crossed,{waiting=Host.medalEggs(deps.state())},{eggs=if deps.openEggs then eggsRoute else nil})
   return
  end
  -- No stage in this build: one ticket names the best medal.
  local crossed=watch.pending;watch.pending={}
  watch.serial=(watch.serial or 0)+1
  local words=MedalView.words(crossed)
  if words then medalTicket("medal:"..watch.serial,MedalView.ticket(crossed),words.stat,crossed[1].petId)end
 end
 local toasts=Toasts.new({rail=Rail,owner=host,held=deps.held,
  -- S1: a tapped ticket while the panel is open switches it to that stat (today: just dismisses).
  focus=function(stat,petId,rowId)return Levels.on("track")and panel:focusStat(stat,petId,rowId)end,
  open=function(stat,petId,rowId)api.open({stat=stat,petId=petId,from="rail",guide=rowId~=nil,row=rowId})end})
 api.toasts=toasts
 function api.sync(state)
  if type(state)~="table"then return end
  toasts:update(state.petStats)
  panel:noteLevels(state.petStats)
  Host.watchMedals(watch,LevelGate.levels(type(state.petStats)=="table"and state.petStats.pets or nil))
  -- At join: one ticket while medal eggs wait.
  if not watch.joined and Levels.on("medals")and type(state.petStats)=="table"then
   watch.joined=true
   medalTicket("medal:join",MedalView.waitingText(Host.medalEggs(state)))
  end
  if panel:isOpen()then panel:setContext(context())end
 end
 -- Held lines flush once the round's results show (checked each frame; cheap).
 table.insert(connections,game:GetService("RunService").Heartbeat:Connect(function()
  if toasts.pending then toasts:flush()end
  medalStep()
 end))
 local K=Enum.KeyCode
 local keys={K.One,K.Two,K.Three,K.Four,K.Five,K.Six,K.F,K.Left,K.Right,K.Up,K.Down,K.A,K.D,K.W,K.S,K.Q,K.E,K.X,K.ButtonX,K.ButtonL1,K.ButtonR1,K.DPadLeft,K.DPadRight,K.DPadUp,K.DPadDown,
  K.Space,K.Return,K.KeypadEnter,K.ButtonA,K.ButtonB,K.Backspace,K.Escape,K.M,K.ButtonY,K.ButtonStart}
 -- Above the Companions hub (High+790) and the Wardrobe (High+800): the panel owns input while open.
 ContextActionService:BindActionAtPriority("EggDropStats",function(_,state,input)
  if not panel:isOpen()or UserInputService:GetFocusedTextBox()or GuiService.MenuIsOpen then return Enum.ContextActionResult.Pass end
  if state==Enum.UserInputState.Begin then panel:input(input.KeyCode)end
  return Enum.ContextActionResult.Sink
 end,false,Enum.ContextActionPriority.High.Value+805,table.unpack(keys))
 syncInsets()
 function api.destroy()
  ContextActionService:UnbindAction("EggDropStats")
  for _,c in ipairs(connections)do c:Disconnect()end
  if moment then moment:destroy()end
  panel:destroy();gui:Destroy()
 end
 return api
end
return Host
