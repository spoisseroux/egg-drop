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
 local Kit=require(client.DeckKit)
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

  test("QA v2 R1: beats wait for a free, still, present player; machine cards wait for the reveal; the pill fades",function()
  local base={canRoam=true,owned=1,mask=0,seen={},totalWins=0,open={}}
  local function with(t)local c=table.clone(base);for k,v in pairs(t)do c[k]=v end;return c end
  assert(Cards.beatMayStart(with({}),Coach.GardenSettle,false))
  assert(not Cards.beatMayStart(with({open={hatch=true}}),10,false),"never over a menu")
  assert(not Cards.beatMayStart(with({windowActive=false}),10,false),"never on an unfocused window")
  assert(not Cards.beatMayStart(with({idleFor=.2}),10,false),"waits until the player stands still")
  assert(not Cards.beatMayStart(with({awayFor=Cards.AwaySeconds}),10,false),"not while away")
  assert(not Cards.beatMayStart(with({revealPending=true}),10,true),"never over the reveal, even on replay")
  assert(not Cards.beatMayStart(with({mask=Coach.with(0,"gardenIntro")}),10,false)and Cards.beatMayStart(with({mask=Coach.with(0,"gardenIntro")}),10,true),"replay ignores the saved bit")
  assert(Cards.clockRuns(with({}),"beat")and not Cards.clockRuns(with({awayFor=99}),"beat")and not Cards.clockRuns(with({windowActive=false}),"once"))
  assert(Cards.clockRuns(with({canRoam=false,open={hatch=true}}),"once")and not Cards.clockRuns(with({canRoam=false}),"beat"))
  assert(Cards.machineDue({hatch=true},{},{owned=1,mask=0,seen={},totalWins=0,revealPending=true})==nil,"the starter reveal is not a Hatch eggs visit")
  assert(Cards.welcomeFade(0,false)==1 and Cards.welcomeFade(1,false)==0 and Cards.welcomeFade(Cards.WelcomeSeconds+Cards.WelcomeFadeOut,false)==1)
  assert(Cards.welcomeFade(1,true)==0 and Cards.welcomeFade(Cards.WelcomeSeconds+1,true)==1,"Reduced Motion: a cut")
  assert(Cards.welcomeText(1000)==UICopy.get("r1.welcomePill.wide")and Cards.welcomeText(1)==UICopy.get("r1.welcomePill.narrow"))
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
   -- Since 70e0440 every coach notice is a line on the shared top-bar rail
   -- (NotificationRail): the old card and pill instances stay built but hidden. The rail
   -- runs on real frames, so `shows` pumps them; a card's own clock only runs while the
   -- rail is drawing it. v2 tickets: several lines can show side by side, so these look
   -- for one line's ticket among them; `quiet` waits for every coach line to leave.
   local Rail=require(client.NotificationRail)
   local RunService=game:GetService("RunService")
   local function ticketOf(text)
    for _,entry in ipairs(Rail.shown())do if entry.text==text then return entry end end
    return nil
   end
   local function shows(text,seconds)
    local deadline=os.clock()+(seconds or 2)+.5
    repeat if ticketOf(text)then return true end;RunService.RenderStepped:Wait()until os.clock()>deadline
    return false
   end
   local function quiet()
    local deadline=os.clock()+2
    repeat
     local any=false
     -- (A timed toast may still be on its own 5 s clock, round 3: only the coach lines count.)
     for _,entry in ipairs(Rail.shown())do if entry.item and entry.item.owner==cards.host and string.sub(tostring(entry.item.key),1,6)~="toast:"then any=true end end
     if not any then return true end
     RunService.RenderStepped:Wait()
    until os.clock()>deadline
    return false
   end
   local function garden()return cards.garden and cards.garden.id or nil end
   local function legacyHidden()
    return not cards.gardenView.root.Visible and not cards.boardView.root.Visible
     and not(cards.welcomePill and cards.welcomePill.Visible)and not(cards.boardPill and cards.boardPill.Visible)
   end
   -- Welcome round on the board.
   cards:sync({coachMask=0,totalWins=0,quests={daily={}}})
   step(0,{mode="Board",canRoam=false,presented=true,owned=0,phase="Welcome",merges=0})
   assert(cards.welcomeRail and legacyHidden(),"the Welcome line goes to the rail, not the big card or the old pill")
   assert(shows(UICopy.get("qa.coach.welcome")),"the Welcome line is on the rail")
   local railGui=Rail.view()
   local welcome=ticketOf(UICopy.get("qa.coach.welcome"))
   -- Its entrance (fade, UIScale 0.9 to 1) settles before it is measured.
   local settle=os.clock()+1
   while welcome.ticket:FindFirstChildOfClass("UIScale").Scale~=1 and os.clock()<settle do RunService.RenderStepped:Wait()end
   local cardH=Rail.size(game:GetService("GuiService").TopbarInset.Height).card
   assert(railGui.DisplayOrder>cards.gui.DisplayOrder and welcome.card.AbsoluteSize.Y==cardH
    and welcome.ticket:GetAttribute("Truncated")~=true,"one 40 px ticket above the menus, its line never cut")
   -- QA v735 H5: every line can be tapped; this one opens its notice card.
   assert(welcome.ticket.Active==true and welcome.ticket:FindFirstChild("More",true).Visible,"a tap on the Welcome line opens its notice card")
   step(1,{mode="Board",canRoam=false,presented=true,owned=0,phase="Welcome",merges=0,drops=1})
   assert(cards.welcomeRail==nil and quiet(),"it leaves at the first drop")
   step(1.5,{mode="Board",canRoam=false,presented=true,owned=0,phase="Welcome",merges=0})
   assert(cards.welcomeRail==nil,"once a session")
   -- Reveal open: no garden step yet.
   cards:sync({coachMask=0,totalWins=0,lastHatch={id="s",petId="pip",starter=true,stars=6},quests={daily={}}})
   step(10);step(14)
   assert(garden()==nil,"waits for the reveal")
   cards:sync({coachMask=0,totalWins=0,quests={daily={}}})
   step(20);assert(garden()==nil,"waits for the greeting to settle")
   step(23);assert(garden()=="machines"and cards.garden.kind=="beat"and legacyHidden(),"beat 1: machines")
   -- The Welcome round's Stars are said once as the garden step opens. The toast (priority 0)
   -- is admitted before the beat (priority -1), which joins it on the right 0.4 s later.
   step(23.01);assert(shows(UICopy.get("coach.firstStars.toast")),"the Welcome Stars toast comes first")
   local toast=ticketOf(UICopy.get("coach.firstStars.toast"))
   assert(toast.kind=="stars"and toast.card:FindFirstChild("Amount",true).Text=="+6","its Stars show as +6 after the line")
   assert(cards.garden.elapsed==0,"a queued beat's clock has not started")
   assert(shows((Cards.copy("machines",{pet="Bear",input="Keyboard"})),6),"then the beat's title is on the rail")
   local beat=ticketOf((Cards.copy("machines",{pet="Bear",input="Keyboard"})))
   assert(beat and beat.ticket.Active==true,"a tap on the line opens How it works")
   cards:dismiss("tap")
   step(23.1);assert(garden()=="hub","beat 2: hub (a tap moves on)")
   step(23.2,{canRoam=false});assert(garden()==nil,"a menu hides the beat")
   step(23.3,{canRoam=false})
   step(26);step(29);assert(garden()=="hub","the beat comes back after the menu")
   step(29.01);assert(shows(UICopy.get("coach.hub.title")))
   local life=cards.garden.duration
   step(29.01+life+.1)
   assert(garden()=="quest","beat 3: quest (moves on by itself after its time on the rail)")
   cards:dismiss("skip")
   assert(table.find(sent,"gardenIntro"),"the step is saved when it ends")
   step(60);step(64)
   assert(garden()==nil,"the garden step never repeats")
   -- QA v2 R1.6: replayable on request, under the same rules.
   assert(cards:replayGarden())
   step(65,{idleFor=.2});step(68,{idleFor=.3});assert(garden()==nil,"waits while the player walks")
   step(68.5,{idleFor=5});assert(garden()=="machines","replay starts from beat 1")
   step(68.51,{idleFor=5});assert(shows((Cards.copy("machines",{pet="Bear",input="Keyboard"}))))
   step(80,{idleFor=5,awayFor=60});step(95,{idleFor=5,awayFor=60})
   assert(garden()=="machines"and cards.garden.elapsed<life,"the clock pauses while the player is away")
   -- v2 tickets: other coach lines may share the row, so this checks the beat's own line.
   do local line=(Cards.copy("machines",{pet="Bear",input="Keyboard"}));local deadline=os.clock()+2
    while ticketOf(line)and os.clock()<deadline do RunService.RenderStepped:Wait()end
    assert(ticketOf(line)==nil,"and the line leaves the rail meanwhile")end
   step(96,{idleFor=5,windowActive=false});step(120,{idleFor=5,windowActive=false})
   assert(garden()=="machines"and cards.garden.elapsed<life,"and while the window is unfocused")
   cards:dismiss("skip");step(121)
   -- First visit to Hatch eggs, once. The bit is saved when the rail presents the line.
   open.hatch=true;step(70)
   assert(garden()=="hatch"and cards.garden.kind=="once"and not table.find(sent,"hatch"),"queued, not saved before it is seen")
   -- QA v735 H5: a first visit reads as a tip ("Tip: Hatch eggs"), not a bare title.
   step(70.01);assert(shows(Cards.railLine("hatch","once",{pet="Bear",input="Keyboard"},true).text))
   assert(table.find(sent,"hatch")and learned.Eggs,"first visit line; the station is learned")
   open.hatch=false;step(71);assert(garden()==nil and quiet(),"leaves with its screen")
   open.hatch=true;step(72);assert(garden()==nil,"never twice")
   open.hatch=false
   local counts={}
   for _,id in ipairs(sent)do counts[id]=(counts[id]or 0)+1 end
   for id,n in pairs(counts)do assert(n==1,id.." sent once")end
   -- A saved mask from the server (another device) suppresses the card here too.
   cards:sync({coachMask=Coach.with(0,"book"),totalWins=0,quests={daily={}}})
   open.book=true;step(80);assert(garden()~="book","saved elsewhere: not shown")
   open.book=false
   -- First quest done, on the results or in the garden.
   cards:sync({coachMask=0,totalWins=0,quests={daily={{ready=true}}}})
   step(90,{mode="Board",canRoam=false,presented=true,over=false,phase="Playing"})
   assert(garden()~="questDone","not mid-round")
   step(91,{mode="Board",canRoam=false,presented=true,over=true,phase="Complete"})
   assert(garden()=="questDone"and legacyHidden())
  end)
  cards:destroy();gui:Destroy()
  assert(ok,problem)
 end)

 -- QA v775, "the tips change randomly": a line ran out under the card the player had
 -- opened from it and the next line (or the tour) took its place.
 test("QA v775: a card is open: the garden side stands still (pure clock)",function()
  local gui=Instance.new("ScreenGui");gui.Name="_CoachHoldSpec";gui.Parent=parent
  local sent,opened={},0
  local cards=Cards.new({gui=parent,send=function(id)table.insert(sent,id)end,tour=function()opened+=1;return true end})
  local ok,problem=pcall(function()
   local open={}
   local function step(t,extra)
    local ctx={mode="Room",canRoam=true,presented=false,owned=1,input="Keyboard",open=open,used={},pet="Bear",idleFor=5,cardOpen=false}
    for k,v in pairs(extra or {})do ctx[k]=v end
    cards:step(t,ctx)
   end
   cards:sync({coachMask=0,totalWins=0,quests={daily={}}})
   -- The garden step is due, but a notice card is open: the tour never opens over it.
   step(0);step(10,{cardOpen=true});step(60,{cardOpen=true})
   assert(opened==0 and cards.garden==nil and not cards.tourOpen,"no tour and no line over an open card")
   step(61);assert(opened==0,"after the card closes the garden settles again first")
   step(61+Coach.GardenSettle+.1);assert(opened==1 and cards.tourOpen,"then the tour opens")
   -- A first-visit line whose card is open: its clock stops, it never leaves, nothing else starts.
   cards.tourOpen=false;cards:finishGarden()
   open.hatch=true;step(70)
   assert(cards.garden and cards.garden.id=="hatch")
   cards.garden.elapsed=1
   open.hatch=false;open.book=true
   step(71,{cardOpen=true});step(500,{cardOpen=true,used={Park=true}})
   assert(cards.garden and cards.garden.id=="hatch"and cards.garden.elapsed==1,"held: not timed out, not replaced, not closed with its screen")
   step(500.1)
   assert(cards.garden and cards.garden.id=="book","once the card closes the next line is queued (the rail rests before it shows)")
  end)
  cards:destroy();gui:Destroy();assert(ok,problem)
 end)

 test("Things to do live: the last branch's line; interrupted before it shows it is not saved; shown, it is saved and counted once",function()
  local RunService=game:GetService("RunService")
  local gui=Instance.new("ScreenGui");gui.Name="_CoachThingsSpec";gui.Parent=parent
  local sent,due,why,showed={},nil,nil,nil
  local cards=Cards.new({gui=parent,send=function(id)table.insert(sent,id)end})
  local ok,problem=pcall(function()
   local clock=0
   local function step(dt)
    clock+=dt
    cards:step(clock,{mode="Room",canRoam=true,presented=false,owned=1,input="Keyboard",open={},used={},pet="Bear",idleFor=5,cardOpen=false})
   end
   cards:sync({coachMask=Coach.with(0,"gardenIntro"),totalWins=0,quests={daily={}}})
   for _=1,5 do step(1)end
   assert(cards.garden==nil and cards.stepCtx==nil,"without options.things: as before")
   cards.options.things={due=function()return due,due end,blocked=function()return why end,show=function(id)showed=id end}
   due="parkInvite";step(.1);assert(cards.garden and cards.garden.kind=="intro"and cards.garden.line.notice=="parkInvite"and #sent==0)
   why="menu";due=nil;step(.1);assert(cards.garden==nil and #sent==0 and not cards.seen.parkInvite,"interrupted: it comes back later")
   why=nil;due="parkInvite";step(.1);due=nil
   local deadline=os.clock()+6
   repeat step(RunService.RenderStepped:Wait())until #sent>0 or os.clock()>deadline
   assert(sent[1]=="parkInvite"and #sent==1 and cards.introShown==1 and cards.seen.parkInvite)
   why="race";step(.1);assert(cards.garden==nil,"a race starts: the line leaves")
   for _=1,10 do step(1)end
   assert(#sent==1 and showed==nil)
   cards.options.things.due=function()error("broken")end
   step(.1);assert(cards.options.things==nil and cards.garden==nil,"an error turns the tips off, not the coach");step(.1)
  end)
  cards:destroy();gui:Destroy();assert(ok,problem)
 end)

 test("QA v775 live: the rail never advances or replaces a line while a card is open",function()
  local Rail=require(client.NotificationRail);local How=require(client.HowItWorks)
  local RunService=game:GetService("RunService")
  local gui=Instance.new("ScreenGui");gui.Name="_CoachCalmSpec";gui.Parent=parent
  local cards=Cards.new({gui=parent,send=function()end})
  local ok,problem=pcall(function()
   local open={};local clock=0
   -- v2 tickets: the coach's own lines on the row (other lines may show beside them).
   local function railHas(text)
    for _,entry in ipairs(Rail.shown())do if entry.text==text then return true end end
    return false
   end
   -- Real frames for up to `seconds`: the cards step on the real dt; returns every coach line seen.
   local function run(seconds,stop)
    local seen={};local deadline=os.clock()+seconds
    repeat
     clock+=RunService.RenderStepped:Wait()
     cards:step(clock,{mode="Room",canRoam=true,presented=false,owned=1,input="Keyboard",open=open,used={},pet="Bear",idleFor=5})
     local any=false
     for _,entry in ipairs(Rail.shown())do if entry.item and entry.item.owner==cards.host then seen[entry.text]=true;any=true end end
     if not any then seen["-"]=true end
    until os.clock()>deadline or(stop and stop())
    return seen
   end
   local function only(seen,allowed)
    for text in pairs(seen)do if not table.find(allowed,text)then return false,text end end
    return true
   end
   cards:sync({coachMask=Coach.with(0,"gardenIntro"),totalWins=0,quests={daily={}}})
   local hatch=Cards.railLine("hatch","once",{pet="Bear",input="Keyboard"},true).text
   local book=Cards.railLine("book","once",{pet="Bear",input="Keyboard"},true).text
   open.hatch=true
   run(4,function()return railHas(hatch)end)
   assert(railHas(hatch),"the first-visit line shows")
   -- The player opens its card and reads it for longer than the line's whole time.
   assert(How.open("hatch")and Rail.held(),"a card is open: the rail holds")
   local elapsed=cards.garden.elapsed
   open.book=true -- another line is due meanwhile
   local seen=run(cards.garden.duration+1.5)
   local fine,other=only(seen,{hatch})
   assert(fine,"the rail changed under the open card: "..tostring(other))
   assert(cards.garden and cards.garden.id=="hatch"and cards.garden.elapsed==elapsed,"no clock ran")
   assert(How.isOpen()and How.openId()=="hatch","the card the player opened stays until they close it")
   How.close("fixture");open.hatch=false
   -- The line leaves with its screen; the next line shows once the card has closed (the v775
   -- calm gap is retired by the v2 tickets spec).
   seen=run(4,function()return railHas(book)end)
   assert(railHas(book),"the next line shows")
   fine,other=only(seen,{"-",hatch,book})
   assert(fine,"a stray line showed: "..tostring(other))
  end)
  How.close("fixture");cards:destroy();gui:Destroy();assert(ok,problem)
 end)

 return{passed=#cases,cases=cases}
end
