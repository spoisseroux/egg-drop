-- Studio Client. Overnight 2026-11-14 slice E (SYSTEMS-SCOPE 1.3, 1.6): the earned pet's
-- arrival card and the stamp card's tease. Both stay hidden while EarnedPets.enabled(pet)
-- is false (the build's default: FeatureFlags.SecondPet=false).
--  * Cards.arrivalDue: owns the earned pet, coach bit petArrived unset, not shown this
--    session. It never goes through Coach.wants, so a veteran (5+ wins) still gets it.
--  * The card shows only in the free, settled garden; it hides under a menu and comes back.
--  * "Say hi" calls sayHi(petId) (the caller sends the `companion` action) and saves the
--    bit; "Got it" saves the bit without switching; a stray tap on the card keeps it; its
--    full time also saves the bit. Already the companion: the bit is saved with no card.
--  * StampCardView: "Someone's on the way…" with the stamps left, only while the pet is
--    enabled, not owned and still ahead.
-- Usage: require(PlayerScripts.Client.ZZSpecs.ArrivalCard)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Cards=require(client.CoachCards)
 local View=require(client.StampCardView)
 local Coach=require(Shared.CoachMarks)
 local Pets=require(Shared.PetCatalog)
 local Eggs=require(Shared.EggCatalog)
 local UICopy=require(Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local holder=Instance.new("Folder");holder.Name="_ArrivalCardSpec";holder.Parent=parent
 -- The earned pet: the last pet in the collection stands in when the real one is not in
 -- the catalogue yet, so the rules are exercised either way.
 local earnedId=if Pets.byId.blip then "blip"else Pets.collection[#Pets.collection].id
 local bit=Eggs.bit(earnedId)
 local every=bit32.lshift(1,#Pets.collection)-1
 local on={Order={earnedId},Rules={[earnedId]={stamps=7}},enabled=function(id)return id==earnedId end}
 local off={Order={earnedId},Rules={[earnedId]={stamps=7}},enabled=function()return false end}
 local free={mode="Room",canRoam=true,open={},windowActive=true,awayFor=0,idleFor=5,owned=1}
 local ok,problem=xpcall(function()
  test("the real gate is off in this build: no card, no tease",function()
   local Flags=require(Shared.FeatureFlags)
   if Flags.SecondPet==true then return end -- the week-1 build turns it on
   assert(Cards.arrivalDue({mask=0,inventoryMask=every,seen={}})==nil,"flag off: no arrival card even when the bit is owned")
   assert(View.tease({stamps=3,inventoryMask=1})==nil and View.model({stamps=6,inventoryMask=1}).tease==nil,"flag off: no tease")
  end)
  test("pure: arrivalDue needs the pet enabled and owned, the bit unset, and not seen this session",function()
   assert(Coach.Bits.petArrived==10,"coach bit 10")
   assert(Cards.arrivalDue({mask=0,inventoryMask=every,seen={},earned=on})==earnedId)
   assert(Cards.arrivalDue({mask=0,inventoryMask=every,seen={},earned=off})==nil,"not enabled")
   assert(Cards.arrivalDue({mask=0,inventoryMask=bit32.band(every,bit32.bnot(bit)),seen={},earned=on})==nil,"not owned")
   assert(Cards.arrivalDue({mask=Coach.with(0,"petArrived"),inventoryMask=every,seen={},earned=on})==nil,"bit saved")
   assert(Cards.arrivalDue({mask=0,inventoryMask=every,seen={petArrived=true},earned=on})==nil,"seen this session")
   assert(Cards.arrivalDue({mask=0,seen={},earned=on})==nil and Cards.arrivalDue({earned={}})==nil,"no mask / no gate")
   -- A veteran still gets it (Coach.wants would say no at 5+ wins).
   assert(not Coach.wants("petArrived",{mask=0,totalWins=50,owned=2}))
   assert(Cards.arrivalDue({mask=0,totalWins=50,inventoryMask=every,seen={},earned=on})==earnedId,"veterans too")
   -- Other bits do not hide it.
   assert(Cards.arrivalDue({mask=Coach.with(Coach.with(0,"gardenIntro"),"questDone"),inventoryMask=every,seen={},earned=on})==earnedId)
  end)
  test("pure: the card waits for the free, settled garden",function()
   assert(Cards.arrivalReady(free,Coach.GardenSettle))
   assert(not Cards.arrivalReady(free,Coach.GardenSettle-.1),"not settled yet")
   for _,change in ipairs({{mode="Board"},{canRoam=false},{open={hatch=true}},{windowActive=false},{revealPending=true},{awayFor=Cards.AwaySeconds}})do
    local ctx=table.clone(free);for key,value in pairs(change)do ctx[key]=value end
    assert(not Cards.arrivalReady(ctx,10),"blocked by "..next(change))
   end
   assert(Cards.clockRuns(free,"arrival")and not Cards.clockRuns({canRoam=true,open={book=true}},"arrival"),"its clock pauses under a menu")
   local title,line=Cards.copy("petArrived",{pet="Blip"})
   assert(title==UICopy.get("e2.arrived.title")and line==UICopy.get("e2.arrived.line",{pet="Blip"})and string.find(line,"Blip",1,true))
   assert(Cards.Spec.petArrived~=nil and Cards.ArrivalSeconds>Cards.Duration)
  end)
  local function build()
   local sent,greeted={},{}
   local cards=Cards.new({gui=holder,send=function(id)table.insert(sent,id)end,sayHi=function(petId)table.insert(greeted,petId)end})
   return cards,sent,greeted
  end
  -- Drives the real step with the arrival gate swapped in (the card reads ctx.earned).
  local function step(cards,now,extra)
   local ctx=table.clone(free);ctx.earned=on
   for key,value in pairs(extra or {})do ctx[key]=value end
   cards:step(now,ctx)
  end
  test("the card shows once the garden is settled, with Say hi; Say hi switches and saves the bit",function()
   local cards,sent,greeted=build()
   cards:sync({coachMask=Coach.with(0,"gardenIntro"),totalWins=40,inventoryMask=every})
   step(cards,0);assert(cards.garden==nil,"not before the garden settles")
   step(cards,Coach.GardenSettle+.1)
   assert(cards.garden and cards.garden.id=="petArrived"and cards.garden.kind=="arrival"and cards.garden.petId==earnedId)
   local view=cards.gardenView
   assert(view.root.Visible and view.root:GetAttribute("CoachCard")=="petArrived"and cards.sayHiButton.Visible)
   assert(view.title.Text==UICopy.get("e2.arrived.title")and string.find(view.line.Text,Pets.byId[earnedId].name,1,true))
   local button=cards.sayHiButton
   assert(button.Size.Y.Offset>=40 and button.Position.Y.Offset+button.Size.Y.Offset<=view.root.Size.Y.Offset-8,"the button sits inside the card")
   assert(button.Position.Y.Offset>=view.line.Position.Y.Offset+view.line.Size.Y.Offset,"under the line")
   assert(#sent==0,"nothing is saved until the player answers")
   assert(cards:dismiss("tap")==false and cards.garden~=nil,"a stray tap keeps the card")
   assert(cards:sayHi()==true and greeted[1]==earnedId and #greeted==1)
   assert(table.concat(sent,",")=="petArrived"and cards.garden==nil and not view.root.Visible and not button.Visible)
   assert(Coach.has(cards.mask,"petArrived"))
   step(cards,Coach.GardenSettle+5);step(cards,Coach.GardenSettle+10)
   assert(cards.garden==nil and #sent==1 and #greeted==1,"shown once")
   assert(cards:sayHi()==false)
   cards:destroy()
  end)
  test("Got it saves the bit without switching; the full time saves it too; a menu only hides it",function()
   local cards,sent,greeted=build()
   cards:sync({coachMask=Coach.with(0,"gardenIntro"),totalWins=40,inventoryMask=every})
   step(cards,0);step(cards,3)
   assert(cards.garden and cards.garden.kind=="arrival")
   assert(cards:dismiss("skip")==true and #greeted==0 and table.concat(sent,",")=="petArrived","Got it: saved, companion unchanged")
   cards:destroy()
   -- A menu opens over it: hidden, nothing saved, back when the garden is free again.
   cards,sent,greeted=build()
   cards:sync({coachMask=Coach.with(0,"gardenIntro"),totalWins=40,inventoryMask=every})
   step(cards,0);step(cards,3);assert(cards.garden~=nil)
   step(cards,4,{open={companions=true}})
   assert(cards.garden==nil and #sent==0,"hidden under the menu, not saved")
   step(cards,5);step(cards,5+Coach.GardenSettle+.1)
   assert(cards.garden and cards.garden.kind=="arrival","it comes back")
   -- Its full time on screen: gone, and saved (each card shows once ever).
   local now=5+Coach.GardenSettle+.1
   for _=1,Cards.ArrivalSeconds+2 do now+=1;step(cards,now)end
   assert(cards.garden==nil and table.concat(sent,",")=="petArrived"and #greeted==0)
   cards:destroy()
  end)
  test("already the companion: the bit is saved with no card; not owned or flag off: nothing",function()
   local cards,sent=build()
   cards:sync({coachMask=Coach.with(0,"gardenIntro"),totalWins=40,inventoryMask=every})
   step(cards,0,{companionId=earnedId});step(cards,3,{companionId=earnedId})
   assert(cards.garden==nil and table.concat(sent,",")=="petArrived")
   cards:destroy()
   cards,sent=build()
   cards:sync({coachMask=Coach.with(0,"gardenIntro"),totalWins=40,inventoryMask=bit32.band(every,bit32.bnot(bit))})
   step(cards,0);step(cards,3);assert(cards.garden==nil and #sent==0,"not owned")
   cards:destroy()
   cards,sent=build()
   cards:sync({coachMask=Coach.with(0,"gardenIntro"),totalWins=40,inventoryMask=every})
   step(cards,0,{earned=off});step(cards,3,{earned=off});assert(cards.garden==nil and #sent==0,"gate off")
   cards:destroy()
  end)
  test("stamp card: the tease counts the stamps left and stops when the pet is owned or reached",function()
   View.Earned=off
   assert(View.tease({stamps=3,inventoryMask=1})==nil)
   View.Earned=on
   local tease=View.tease({stamps=3,inventoryMask=1});assert(tease and tease.petId==earnedId and tease.remaining==4)
   assert(View.tease({stamps=6,inventoryMask=1}).remaining==1 and View.tease({stamps=0,inventoryMask=1}).remaining==7)
   assert(View.tease({stamps=7,inventoryMask=1})==nil and View.tease({stamps=30,inventoryMask=1})==nil,"reached: the arrival card takes over")
   assert(View.tease({stamps=3,inventoryMask=bit32.bor(1,bit)})==nil,"owned")
   assert(View.tease(nil)==nil and View.tease({})~=nil and View.tease({}).remaining==7)
   local model=View.model({stamps=5,inventoryMask=1,dailyAvailable=true})
   assert(model.tease and model.tease.remaining==2)
   local lines=View.lines(model)
   assert(lines[1]==UICopy.get("e2.tease.many",{count=2})and lines[2]==UICopy.get("e2.tease.short")and View.line(model)==lines[1])
   assert(View.lines(View.model({stamps=6,inventoryMask=1}))[1]==UICopy.get("e2.tease.one"))
   -- Built: the line shows the tease (the short one when the long one cannot fit).
   local frame=Instance.new("Frame");frame.Size=UDim2.fromOffset(400,120);frame.BackgroundTransparency=1
   local gui=Instance.new("ScreenGui");gui.Name="_ArrivalCardSpecStamp";gui.Parent=parent;frame.Parent=gui
   local card=View.new(frame,{});card:layout(360,false);card:set({stamps=5,inventoryMask=1,dailyAvailable=true})
   assert(card.lineLabel.Text==lines[1]and card.root:GetAttribute("Tease")==true)
   card:layout(150,true);assert(card.lineLabel.Text==lines[2],"narrow cards get the short tease")
   View.Earned=off;card:set({stamps=5,inventoryMask=1,dailyAvailable=true})
   assert(card.root:GetAttribute("Tease")==false and card.lineLabel.Text==UICopy.get("stamp.next",{reward=card.cardModel.reward}),"gate off: the usual line")
   View.Earned=nil
   card:destroy();gui:Destroy()
  end)
 end,function(e)View.Earned=nil;return tostring(e).." | "..debug.traceback()end)
 holder:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
