-- Studio Client. Overnight 2026-11-14 slice F (SYSTEMS-SCOPE 5.4, 5.5; VISUAL-BRIEF 5): bond UI.
--  * BondPips.info: level, shown pips (capped at the shipped level), progress to the next
--    level; nil without bond data, so every caller shows nothing.
--  * Pips render: five hearts, filled = accent at full strength, empty = fainter and smaller;
--    the bar under them shows progress and hides at the cap; 18 px desktop, 14 px phone.
--  * Level-up detection fires once per pet per level; the first snapshot is the baseline.
--  * The toast names the trick ("Bond level 2 · New trick: Sit").
--  * The flourish: six pooled hearts in the lightened secondary colour, none under Reduced
--    Effects (the pip and the toast carry it).
--  * The focus card (PetFocusUI) and the Companions pane show the pips; no bond data, no pips.
--  * Tricks 1-2 (RoomView.bondTricks): Hello waves once per session per pet; the owner-still
--    sit needs level 2; without bond data nothing is gated.
-- Usage: require(PlayerScripts.Client.ZZSpecs.BondView)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Pips=require(client.BondPips)
 local Kit=require(client.DeckKit)
 local UICopy=require(Shared.UICopy)
 local Pets=require(Shared.PetCatalog)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_BondViewSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 -- The spec's own catalogue (the scope's numbers), so it does not depend on tuning.
 local Catalog={MaxLevelShipped=5,Thresholds={0,25,75,150,250,350}}
 function Catalog.level(xp)
  local level=1
  for index=2,Catalog.MaxLevelShipped do if xp>=Catalog.Thresholds[index]then level=index end end
  return level
 end
 local petId=Pets.active[1].id
 local ok,problem=xpcall(function()
  test("pure: info gives level, shown pips and progress; nil without bond data",function()
   assert(Pips.info(nil,petId,Catalog)==nil and Pips.info({},nil,Catalog)==nil,"no bond map or no pet: nothing")
   local a=Pips.info({[petId]=0},petId,Catalog);assert(a.level==1 and a.shown==1 and a.progress==0 and not a.max)
   local b=Pips.info({[petId]=50},petId,Catalog);assert(b.level==2 and math.abs(b.progress-.5)<1e-6)
   local c=Pips.info({[petId]=249},petId,Catalog);assert(c.level==4 and c.shown==4 and c.progress<1)
   local d=Pips.info({[petId]=250},petId,Catalog);assert(d.level==5 and d.shown==5 and d.max and d.progress==1)
   local e=Pips.info({[petId]=99999},petId,Catalog);assert(e.shown==5 and e.max,"XP past the cap still shows five")
   local f=Pips.info({},petId,Catalog);assert(f.level==1 and f.xp==0,"a pet with no XP yet is level 1")
   local g=Pips.info({[petId]="x"},petId,Catalog);assert(g.xp==0,"malformed XP reads 0")
   assert(Pips.cap({MaxLevelShipped=9})==5 and Pips.cap({MaxLevelShipped=3})==3 and Pips.cap({})==5,"never more pips than hearts")
   assert(Pips.label(a)==UICopy.get("bond.short",{count=1})and Pips.label(d)==UICopy.get("bond.max",{count=5})and Pips.label(nil)=="")
   Pips.override=nil
   -- The real catalogue (lane K), when it is in the build.
   if Pips.catalog()then
    local real=Pips.info({[petId]=0},petId)
    assert(real and real.shown==1 and Pips.info(nil,petId)==nil)
   else assert(Pips.info({[petId]=10},petId)==nil,"no catalogue: no bond UI")end
  end)
  test("pure: a level-up fires once per pet per level; the first snapshot is the baseline",function()
   local seen={}
   assert(#Pips.levelUps(seen,{[petId]=80},Catalog)==0,"joining at level 3 shows nothing")
   assert(#Pips.levelUps(seen,{[petId]=100},Catalog)==0,"same level")
   local events=Pips.levelUps(seen,{[petId]=150},Catalog)
   assert(#events==1 and events[1].petId==petId and events[1].level==4)
   assert(#Pips.levelUps(seen,{[petId]=150},Catalog)==0 and #Pips.levelUps(seen,{[petId]=151},Catalog)==0,"once per level")
   assert(#Pips.levelUps(seen,{[petId]=10},Catalog)==0,"XP never shows a level going down")
   assert(#Pips.levelUps(seen,{[petId]=200},Catalog)==0,"and a level already shown is not shown again")
   -- A second pet that first appears after the baseline starts from level 1.
   events=Pips.levelUps(seen,{[petId]=200,other=30},Catalog)
   assert(#events==1 and events[1].petId=="other"and events[1].level==2)
   events=Pips.levelUps(seen,{[petId]=250,other=75},Catalog)
   assert(#events==2 and events[1].petId<events[2].petId,"both pets, in a stable order")
   -- Past the cap: no sixth level-up while five ship.
   assert(#Pips.levelUps(seen,{[petId]=9999,other=75},Catalog)==0)
   assert(#Pips.levelUps(nil,{[petId]=1},Catalog)==0 and #Pips.levelUps({},nil,Catalog)==0)
   -- An empty first snapshot still sets the baseline.
   local fresh={};Pips.levelUps(fresh,{},Catalog)
   events=Pips.levelUps(fresh,{[petId]=25},Catalog);assert(#events==1 and events[1].level==2)
  end)
  test("pure: the toast names the trick; every shipped level has a trick name",function()
   for level=1,5 do
    local trick=Pips.trickName(level)
    assert(type(trick)=="string"and trick~=""and trick==UICopy.get("bond.trick.l"..level),"trick "..level)
    assert(Pips.toastText(level)==UICopy.get("bond.levelUp",{count=level,name=trick}))
   end
   assert(Pips.trickName(6)==nil and Pips.toastText(6)==UICopy.get("bond.levelUpPlain",{count=6}))
   assert(Pips.toastText(2)=="Bond level 2 · New trick: Sit")
  end)
  for _,compact in ipairs({false,true})do
   test((if compact then "phone"else "desktop").." pips: five hearts, filled and empty read apart, bar shows progress",function()
    local frame=Instance.new("Frame");frame.Size=UDim2.fromOffset(300,80);frame.BackgroundTransparency=1;frame.Parent=gui
    local row=Pips.new(frame,compact)
    local size=if compact then 14 else 18
    assert(row.size==size and #row.pips==5 and row.root.Visible==false,"hidden until it has a pet")
    assert(row.width==5*size+4*4 and row.height==size+4+3)
    row.set(Pips.info({[petId]=50},petId,Catalog));settle()
    assert(row.root.Visible and row.root:GetAttribute("BondLevel")==2)
    for index,pip in ipairs(row.pips)do
     local filled=index<=2
     assert(pip.root:GetAttribute("Filled")==filled)
     -- An empty pip is drawn smaller (its UIScale), about its own centre.
     local drawn=if filled then size else size*Pips.EmptyScale
     assert(math.abs(pip.root.AbsoluteSize.X-drawn)<=1 and pip.root.Size.X.Offset==size and pip.root.AnchorPoint==Vector2.new(.5,.5),"pip "..index.." size")
     assert(math.abs(pip.root.GroupTransparency-(if filled then 0 else Pips.EmptyAlpha))<1e-4 and math.abs(pip.scale.Scale-(if filled then 1 else Pips.EmptyScale))<1e-4)
     assert(pip.root.GroupColor3==Kit.color(if filled then "accent"else "line"))
     if index>1 then assert(pip.root.Position.X.Offset-row.pips[index-1].root.Position.X.Offset==size+4,"4 px gaps")end
    end
    assert(row.bar.root.Visible and row.bar.root.AbsoluteSize.Y==3 and math.abs(row.bar.value-.5)<1e-6,"3 px bar at half way")
    -- A level-up fills the next pip (the pop settles back to full size).
    row.set(Pips.info({[petId]=75},petId,Catalog),true)
    assert(row.pips[3].root:GetAttribute("Filled")==true and row.root:GetAttribute("BondLevel")==3)
    task.wait(Pips.PopSeconds+.15)
    assert(math.abs(row.pips[3].scale.Scale-1)<.01 and row.pips[3].root.GroupTransparency<1e-4,"the popped pip settles")
    row.set(Pips.info({[petId]=250},petId,Catalog))
    assert(not row.bar.root.Visible and row.pips[5].root:GetAttribute("Filled"),"five filled, no bar at the cap")
    row.set(nil);assert(not row.root.Visible and row.root:GetAttribute("BondLevel")==nil)
    frame:Destroy()
   end)
  end
  test("flourish: six pooled hearts in the lightened secondary colour; none under Reduced Effects",function()
   local Affection=require(client.PetAffection)
   assert(Affection.BondHearts==6 and Affection.BondSeconds==.9 and Affection.BondRise==.6 and Affection.BondDrift==.25)
   local start,peak,finish=Affection.bondHeart(0),Affection.bondHeart(.35),Affection.bondHeart(1)
   assert(math.abs(start.size-.14)<1e-6 and math.abs(peak.size-.20)<1e-6 and finish.size==0,"size 0.14 -> 0.20 -> 0")
   assert(start.rise==0 and math.abs(finish.rise-.6)<1e-6 and start.alpha==0 and finish.alpha==1,"rises 0.6 studs and fades out")
   local secondary=Color3.fromHex("#33539E")
   assert(Affection.bondColor(secondary)==secondary:Lerp(Color3.new(1,1,1),.2),"secondary, 20% toward white")
   local folder=Instance.new("Folder");folder.Name="_BondViewSpecWorld";folder.Parent=workspace
   local affection=Affection.new(folder)
   local model=Instance.new("Model");local part=Instance.new("Part");part.Anchored=true;part.Parent=model;model.PrimaryPart=part;model.Parent=folder
   assert(affection:bondBurst(secondary,false)==0,"no pet, no burst")
   affection.pet={model=model,worldScale=1}
   assert(affection:bondBurst(secondary,true)==0 and affection.bondHearts==nil,"Reduced Effects: no hearts, and no pool built")
   assert(affection:bondBurst(secondary,false)==6 and #affection.bondHearts==6)
   local pool=affection.bondHearts
   affection:stepBond(.3)
   local shown=0;for _,heart in ipairs(pool)do if heart.gui.Enabled then shown+=1 end end
   assert(shown==6,"all six are up at 0.3 s ("..shown..")")
   for _,heart in ipairs(pool)do assert(heart.part.Position.Y>part.Position.Y+1,"hearts start at head height and rise")end
   affection:stepBond(.9)
   for _,heart in ipairs(pool)do assert(not heart.gui.Enabled,"gone after the burst")end
   assert(affection.bondAge==nil)
   assert(affection:bondBurst(secondary,false)==6 and affection.bondHearts==pool,"the pool is reused")
   affection:setPet(nil);for _,heart in ipairs(pool)do assert(not heart.gui.Enabled,"a pet change clears the burst")end
   affection:destroy();folder:Destroy()
  end)
  test("focus card: the pet's name with its pips; hidden without bond data",function()
   local Focus=require(client.PetFocusUI)
   local holder=Instance.new("Folder");holder.Name="_BondViewSpecFocus";holder.Parent=parent
   local parentGui=Instance.new("Frame");parentGui.Size=UDim2.fromScale(1,1);parentGui.BackgroundTransparency=1;parentGui.Parent=holder
   local focus=Focus.new(parentGui,{back=function()end,canReact=function()return true end,greet=function()return true end,pet=function()return true end})
   assert(focus.bondCard and focus.bondCard.Visible==false and focus.bondCard.Parent==focus.panel,"the card lives on the focus panel")
   focus:setBond({name="Bear",bond=Pips.info({[petId]=50},petId,Catalog)})
   assert(focus.bondCard.Visible and focus.bondName.Text=="Bear"and focus.bondCard:GetAttribute("BondLevel")==2)
   assert(focus.bondLevel.Text==UICopy.get("bond.short",{count=2}))
   assert(focus.bondCard.AnchorPoint==Vector2.new(1,0)and focus.bondCard.Active==false,"top right, takes no input")
   local pips=focus.bondPips
   assert(pips.root.Position.X.Offset+pips.width<=focus.bondCard.Size.X.Offset-12,"the pips are inside the card")
   assert(pips.root.Position.Y.Offset+pips.height<=focus.bondCard.Size.Y.Offset,"the bar is inside the card")
   focus:setBond({name="Bear",bond=Pips.info({[petId]=75},petId,Catalog)},true)
   assert(focus.bondCard:GetAttribute("BondLevel")==3 and focus.bondPips==pips,"a level-up reuses the row")
   focus:setBond(nil);assert(not focus.bondCard.Visible)
   focus:setBond({name="Bear"});assert(not focus.bondCard.Visible,"no bond info, no card")
   focus:destroy();holder:Destroy()
  end)
  test("Companions pane: pips with the name when the snapshot carries bond; the old layout without",function()
   if not Pips.catalog()then return end
   local Hub=require(client.CompanionsHub)
   for _,size in ipairs({Vector2.new(1280,720),Vector2.new(812,354)})do
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local hub=Hub.new(host,{appearance=function()return{}end})
    hub:open({wallet=1,state={inventoryMask=1,bond={[petId]=0}},activeId=petId});settle()
    assert(hub.pips and hub.pips.root.Visible and hub.pips.root:GetAttribute("BondLevel")==1,tostring(size).." hub pane pips")
    local pane=hub.pips.root.Parent
    local right=hub.pips.root.AbsolutePosition.X+hub.pips.root.AbsoluteSize.X
    assert(right<=pane.AbsolutePosition.X+pane.AbsoluteSize.X+.5 and hub.pips.root.AbsolutePosition.X>=pane.AbsolutePosition.X-.5,"pips inside the pane")
    hub:setPage("pets");settle()
    assert(hub.pips and hub.pips.root.Visible and hub.pips.root:GetAttribute("BondLevel")==1,tostring(size).." selector pane pips")
    hub:setPage("hub");settle()
    hub:setContext({state={inventoryMask=1}});settle()
    assert(hub.pips==nil,"no bond in the snapshot: no pips")
    hub:destroy();host:Destroy()
   end
  end)
  test("tricks 1-2: Hello waves once per pet per session; Sit needs level 2; no bond data gates nothing",function()
   local Room=require(client.RoomView)
   local Beats=require(client.PetIdleBeats)
   local function room(bond)
    local pet={idleBeatsEnabled=true,ownerNearStill=true,gaitWeight=0,ownerStillNearFor=9,model=Instance.new("Model")}
    local self=setmetatable({pet=pet,shownPet={id=petId,name="Bear"},bond=bond,mode="Room",target="Room",reduceEffects=function()return false end},Room)
    return self,pet
   end
   if not Pips.catalog()then
    local self,pet=room({[petId]=0});self:bondTricks(false)
    assert(pet.bondLevel==nil and pet.ownerStillNearFor==9 and pet.idleBeat==nil,"no catalogue: nothing changes")
    return
   end
   local self,pet=room(nil);self:bondTricks(false)
   assert(pet.bondLevel==nil and pet.ownerStillNearFor==9 and pet.idleBeat==nil,"no bond in the snapshot: behaviour as before")
   self,pet=room({[petId]=0});self:bondTricks(false)
   assert(pet.bondLevel==1 and pet.ownerStillNearFor==0,"level 1: no owner-still sit yet")
   assert(pet.idleBeat and pet.idleBeat.kind=="wave"and pet.idleBeat.duration==Beats.Durations.wave,"Hello: a wave")
   pet.idleBeat.kind=nil;self:bondTricks(false);assert(pet.idleBeat.kind==nil,"only the first time this session")
   local threshold=require(Shared.BondCatalog).Thresholds[2]
   self,pet=room({[petId]=threshold});self.bondHello={[petId]=true};self:bondTricks(false)
   assert(pet.bondLevel==2 and pet.ownerStillNearFor==9,"level 2: the owner-still sit is unlocked")
   self,pet=room({[petId]=0});self:bondTricks(true);assert(pet.idleBeat==nil,"Reduced Effects: no wave")
   self,pet=room({[petId]=0});pet.ownerNearStill=false;self:bondTricks(false);assert(pet.idleBeat==nil,"the owner must stand near")
   -- playBeat never interrupts a running beat and refuses unknown beats.
   self,pet=room({[petId]=0});assert(self:playBeat("stretch")and pet.idleBeat.kind=="stretch"and not self:playBeat("wave")and not self:playBeat("nope"))
  end)
 end,function(e)Pips.override=nil;return tostring(e).." | "..debug.traceback()end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
