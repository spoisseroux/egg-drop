-- Studio Client. v1 track A onboarding: coach cards (CoachCards.lua + Shared.CoachMarks).
-- First-session flow order (Welcome round -> Bear reveal -> guided garden step: machines, hub,
-- first quest -> free), each one-time card shown once ever (saved bit or seen this session),
-- the Welcome card over the board, the fill-line card only on a field round nearing the line,
-- first-visit machine cards, and that no card takes input it does not own.
-- Usage: require(PlayerScripts.Client.ZZSpecs.CoachCards)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Coach=require(Shared.CoachMarks)
 local UICopy=require(Shared.UICopy)
 local Cards=require(client.CoachCards)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local fresh={mask=0,seen={},totalWins=0}

 test("first-session flow order: welcome, reveal, garden step, then free",function()
  assert(Coach.stage({owned=0})=="welcome","no pet: the Welcome round")
  assert(Coach.stage({owned=1,revealPending=true,mask=0,seen={},totalWins=0})=="reveal","Bear owned, reveal open")
  assert(Coach.stage({owned=1,mask=0,seen={},totalWins=0})=="garden","then the guided garden step")
  assert(Coach.stage({owned=1,mask=Coach.with(0,"gardenIntro"),seen={},totalWins=0})=="free","once ever")
  assert(Coach.stage({owned=1,mask=0,seen={},totalWins=Coach.VeteranWins})=="free","veterans skip it")
  -- The garden step waits for a free garden, after the greeting settles.
  local ready={owned=1,mask=0,seen={},totalWins=0,canRoam=true,roomFor=Coach.GardenSettle}
  assert(Coach.gardenReady(ready))
  assert(not Coach.gardenReady({owned=1,mask=0,seen={},totalWins=0,canRoam=false,roomFor=10}),"never over a menu")
  assert(not Coach.gardenReady({owned=1,mask=0,seen={},totalWins=0,canRoam=true,roomFor=1}),"not before the greeting settles")
  assert(not Coach.gardenReady({owned=1,revealPending=true,mask=0,seen={},totalWins=0,canRoam=true,roomFor=10}),"not during the reveal")
  -- Beats: machines, hub, quest, one each.
  assert(Coach.nextBeat(nil)=="machines"and Coach.nextBeat("machines")=="hub"and Coach.nextBeat("hub")=="quest"and Coach.nextBeat("quest")==nil)
 end)

 test("board cards: Welcome until the first merge, fill line only on a field round near the line, first item",function()
  local base={mode="Board",presented=true,mask=0,seen={},totalWins=0}
  local function with(t)local c=table.clone(base);for k,v in pairs(t)do c[k]=v end;return c end
  assert(Cards.boardDue(with({owned=0,phase="Welcome",merges=0}))=="welcome")
  assert(Cards.boardDue(with({owned=0,phase="Welcome",merges=1}))==nil,"leaves at the first merge")
  assert(Cards.boardDue(with({owned=0,phase="Welcome",merges=0,mode="Room"}))==nil,"board only")
  assert(Cards.boardDue(with({owned=1,phase="Playing",pressure=.3}))=="fillLine")
  assert(Cards.boardDue(with({owned=1,phase="Playing",pressure=.1}))==nil,"only when the stack nears the line")
  assert(Cards.boardDue(with({owned=1,phase="Welcome",pressure=.9}))==nil,"never in the Welcome round")
  assert(Cards.boardDue(with({owned=1,phase="Playing",pressure=.9,over=true}))==nil,"not on results")
  assert(Cards.boardDue(with({owned=1,phase="Playing",pressure=.9,mask=Coach.with(0,"fillLine")}))==nil,"once ever")
  assert(Cards.boardDue(with({owned=1,phase="Playing",belt=1}))=="item")
  assert(Cards.boardDue(with({owned=1,phase="Playing",belt=1,seen={item=true}}))==nil,"item once")
  assert(Cards.boardDue(with({owned=1,phase="Playing",presented=false,pressure=.9}))==nil,"never under a menu")
 end)

 test("first visit to each machine: the open screen or a used station, once each",function()
  local ctx={owned=1,mask=0,seen={},totalWins=0}
  for _,id in ipairs(Cards.Machines)do
   assert(Cards.machineDue({[id]=true},{},ctx)==id,id.." first visit")
   assert(Cards.machineDue({[id]=true},{},{owned=1,mask=Coach.with(0,id),seen={},totalWins=0})==nil,id.." once")
  end
  assert(Cards.machineDue({},{Eggs=true},ctx)=="hatch"and Cards.machineDue({},{Customize=true},ctx)=="style"and Cards.machineDue({},{Journal=true},ctx)=="companions")
  assert(Cards.machineDue({},{Park=true},ctx)==nil,"the playground has its own card")
  assert(Cards.machineDue({hatch=true},{},{owned=0,mask=0,seen={},totalWins=0})==nil,"nothing before the first pet")
  assert(Coach.questDone({daily={{ready=true}}})and Coach.questDone({weekly={{claimed=true}}})and not Coach.questDone({daily={{ready=false}}}))
 end)

 test("every card's copy resolves (no placeholder left), hub copy follows the input",function()
  for id in pairs(Cards.Spec)do
   local title,line=Cards.copy(id,{pet="Bear",input="Keyboard"})
   assert(type(title)=="string"and title~=""and not string.find(title,"{",1,true)and not string.find(title,"coach.",1,true),id.." title")
   assert(type(line)=="string"and line~=""and not string.find(line,"{",1,true)and not string.find(line,"coach.",1,true),id.." line")
  end
  assert(select(2,Cards.copy("hub",{input="Keyboard"}))==UICopy.get("coach.hub.key"))
  assert(select(2,Cards.copy("hub",{input="Gamepad"}))==UICopy.get("coach.hub.pad"))
  assert(select(2,Cards.copy("hub",{input="Touch"}))==UICopy.get("coach.hub.touch"))
  assert(string.find(select(2,Cards.copy("companions",{pet="Bear"})),"Bear",1,true),"pet name fills")
 end)

 test("live: the garden step runs once in order, each card is marked once, nothing binds input",function()
  local gui=Instance.new("ScreenGui");gui.Name="_CoachSpec";gui.Parent=parent
  local board=Instance.new("Frame");board.Size=UDim2.fromOffset(400,600);board.Parent=gui
  local sent,learned={},{}
  local cards=Cards.new({gui=parent,boardParent=board,z=5,send=function(id)table.insert(sent,id)end,learned=function(s)learned[s]=true end})
  local ok,problem=pcall(function()
   cards:place(UDim2.new(),UDim2.fromOffset(400,600))
   assert(cards.gui.DisplayOrder>=14 and cards.gardenView.root.Selectable==false and cards.skip.Selectable==false,"no gamepad selection taken")
   assert(cards.boardView.root.Active==false,"board cards take no input")
   local open,used={},{}
   local function step(t,extra)
    local ctx={mode="Room",canRoam=true,presented=false,owned=1,input="Keyboard",open=open,used=used,pet="Bear"}
    for k,v in pairs(extra or {})do ctx[k]=v end
    cards:step(t,ctx)
   end
   -- Welcome round on the board.
   cards:sync({coachMask=0,totalWins=0,quests={daily={}}})
   step(0,{mode="Board",canRoam=false,presented=true,owned=0,phase="Welcome",merges=0})
   assert(cards.boardView.root.Visible and cards.boardView.root:GetAttribute("CoachCard")=="welcome")
   assert(string.find(cards.sticker.Text,tostring(Coach.WelcomeStars),1,true),"the Welcome card shows its Stars")
   step(1,{mode="Board",canRoam=false,presented=true,owned=0,phase="Welcome",merges=1})
   assert(not cards.boardView.root.Visible,"gone at the first merge")
   -- Reveal open: no garden step yet.
   cards:sync({coachMask=0,totalWins=0,lastHatch={id="s",petId="pip",starter=true,stars=6},quests={daily={}}})
   step(10);step(14)
   assert(not cards.gardenView.root.Visible,"waits for the reveal")
   cards:sync({coachMask=0,totalWins=0,quests={daily={}}})
   step(20);assert(not cards.gardenView.root.Visible,"waits for the greeting to settle")
   step(23);assert(cards.gardenView.root:GetAttribute("CoachCard")=="machines","beat 1: machines")
   cards:dismiss("tap")
   step(23.1);assert(cards.gardenView.root:GetAttribute("CoachCard")=="hub","beat 2: hub (a tap moves on)")
   step(23.2,{canRoam=false});assert(not cards.gardenView.root.Visible,"a menu hides the beat")
   step(23.3,{canRoam=false})
   step(26);step(29);assert(cards.gardenView.root:GetAttribute("CoachCard")=="hub","the beat comes back after the menu")
   step(29+Cards.BeatSeconds+.1);step(29+Cards.BeatSeconds+.2)
   assert(cards.gardenView.root:GetAttribute("CoachCard")=="quest","beat 3: quest (moves on by itself)")
   cards:dismiss("skip")
   assert(table.find(sent,"gardenIntro"),"the step is saved when it ends")
   step(60);step(64)
   assert(not cards.gardenView.root.Visible,"the garden step never repeats")
   -- First visit to Hatch eggs, once.
   open.hatch=true;step(70)
   assert(cards.gardenView.root:GetAttribute("CoachCard")=="hatch"and learned.Eggs,"first visit card; the station is learned")
   open.hatch=false;step(71);assert(not cards.gardenView.root.Visible,"leaves with its screen")
   open.hatch=true;step(72);assert(not cards.gardenView.root.Visible,"never twice")
   open.hatch=false
   local counts={}
   for _,id in ipairs(sent)do counts[id]=(counts[id]or 0)+1 end
   for id,n in pairs(counts)do assert(n==1,id.." sent once")end
   -- A saved mask from the server (another device) suppresses the card here too.
   cards:sync({coachMask=Coach.with(0,"book"),totalWins=0,quests={daily={}}})
   open.book=true;step(80);assert(cards.gardenView.root:GetAttribute("CoachCard")~="book","saved elsewhere: not shown")
   open.book=false
   -- First quest done, on the results or in the garden.
   cards:sync({coachMask=0,totalWins=0,quests={daily={{ready=true}}}})
   step(90,{mode="Board",canRoam=false,presented=true,over=false,phase="Playing"})
   assert(cards.gardenView.root:GetAttribute("CoachCard")~="questDone","not mid-round")
   step(91,{mode="Board",canRoam=false,presented=true,over=true,phase="Complete"})
   assert(cards.gardenView.root:GetAttribute("CoachCard")=="questDone")
  end)
  cards:destroy();gui:Destroy()
  assert(ok,problem)
 end)

 return{passed=#cases,cases=cases}
end
