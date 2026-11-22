-- Studio Client. Stat medals on screen (MedalView; V3-LEVELS-BUILD-PLAN-2026-11-22 S4), on and off.
--  * words, labels, the waiting line, the trim stat.
--  * drawn discs while the images are not uploaded; image layers once a tier has both ids.
--  * the six slots on the stats panel, the Marks row and trim on the inspect card (phones: inside the
--    summary strip, so the card still clears the top bar); nothing while the part is off.
--  * StatsHost: a crossing seen this session queues once; joining or turning the part on never replays;
--    the moment waits for quiet, several medals share one stage, A goes to Hatch eggs.
-- Usage: require(PlayerScripts.Client.ZZSpecs.MedalView)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local View=require(client.MedalView)
 local Panel=require(client.StatsPanel)
 local Host=require(client.StatsHost)
 local Inspect=require(client.PetInspect)
 local Levels=require(Shared.Levels)
 local Medals=require(Shared.Medals)
 local Stats=require(Shared.StatCatalog)
 local Pets=require(Shared.PetCatalog)
 local UICopy=require(Shared.UICopy)
 local Http=game:GetService("HttpService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function on()Levels.inject({flags={LevelsMatter=true},studio=true,shipped={track=true,gates=true,medals=true,juice=true}})end
 local function off()Levels.inject({flags={},studio=true})end
 local gui=Instance.new("ScreenGui");gui.Name="_MedalViewSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function settle(n)for _=1,n or 3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function snapshot(levels)
  local xp,level,total={},{},0
  for _,id in ipairs(Stats.Order)do local n=levels[id]or 1;xp[id]=Stats.xpFor(n);level[id]=n;total+=n end
  return{petStats={pets={pip={xp=xp,level=level,total=total}},bonus={}},inventoryMask=1,statEgg={pouch={}}}
 end
 local savedArt=View.Art
 local ok,problem=xpcall(function()
  test("pure: parts, labels, words, the waiting line and the trim",function()
   assert(not View.parts(0).icon and View.parts(1).icon and not View.parts(1).ring and View.parts(2).ring and not View.parts(2).petals and View.parts(3).petals and not View.parts(3).star and View.parts(4).star)
   assert(View.label("jump",1)=="Jump: "..UICopy.get("medal.sprout")and string.find(View.label("jump",0),"25",1,true))
   local words=View.words({{petId="pip",stat="jump",tier="sprout",level=25},{petId="pip",stat="heart",tier="bloom",level=50}},5)
   assert(words.stat=="heart"and words.name==UICopy.get("medal.bloom")and words.line==UICopy.get("medal.eggs",{count=5})and string.find(words.effect,"Jump 25",1,true)and string.find(words.effect,"Heart 50",1,true))
   assert(View.words({})==nil and View.words(nil)==nil and View.words({{stat="nope",tier="sprout"}})==nil)
   assert(View.ticket({{stat="jump",tier="sprout",level=25}})==UICopy.get("medal.earned",{name=UICopy.get("stats.tier.sprout")}))
   assert(View.waitingText(0)==nil and View.waitingText(1)==UICopy.get("medal.eggOne")and View.waitingText(3)==UICopy.get("medal.eggs",{count=3}))
   assert(View.trimStat({heart=74,jump=50})==nil and View.trimStat({heart=75,smarts=75})=="heart"and View.trimStat({heart=75,smarts=99})=="smarts"and View.trimStat(nil)==nil)
   for _,tier in ipairs(Medals.Tiers)do assert(View.Sting[tier.id],tier.id)end
  end)
  test("the uploaded art: every tier has a tint and a trim, eight different images",function()
   local seen,n={},0
   for count,tier in ipairs(Medals.Tiers)do
    local row=View.art(count);assert(row and row==View.Art[tier.level],tier.id)
    for _,id in ipairs({row.tint,row.trim})do assert(string.match(id,"^rbxassetid://%d+$")and not seen[id],id);seen[id]=true;n+=1 end
   end
   assert(n==8)
   local frame=Instance.new("Frame");frame.Size=UDim2.fromOffset(120,120);frame.Parent=gui
   local medal=View.new(frame,96);medal.set("jump",4)
   assert(medal.root.Tint.ImageColor3==Stats.ById.jump.color and medal.root.Trim.ImageColor3==Color3.new(1,1,1)and medal.root.Trim.ZIndex>medal.root.Tint.ZIndex,"only the tint layer takes the colour; the cream well is in the trim")
   frame:Destroy()
  end)
  test("drawn discs with no images; image layers once a tier has both ids",function()
   View.Art={}
   local frame=Instance.new("Frame");frame.Size=UDim2.fromOffset(120,120);frame.Parent=gui
   local medal=View.new(frame,48)
   medal.set("jump",0)
   assert(medal.root:FindFirstChild("Disc").Visible and medal.root:FindFirstChild("Icon_jump")==nil and medal.root:FindFirstChild("Ring").Visible==false)
   medal.set("jump",4)
   assert(medal.root.Disc.BackgroundColor3==Stats.ById.jump.color and medal.root.Ring.Visible and medal.root.Petals.Visible and medal.root.Icon_star.Visible and medal.root:FindFirstChild("Icon_jump"))
   View.Art={[25]={tint="rbxassetid://1",trim="rbxassetid://2"},[50]={tint="rbxassetid://3"}}
   medal.set("heart",1)
   assert(medal.root.Tint.Visible and medal.root.Tint.ImageColor3==Stats.ById.heart.color and medal.root.Trim.ImageTransparency==0 and not medal.root.Disc.Visible and medal.root:FindFirstChild("Icon_heart")and medal.root:FindFirstChild("Icon_jump")==nil)
   medal.set("heart",2);assert(not medal.root.Tint.Visible and medal.root.Disc.Visible,"half a row keeps the drawn discs")
   medal.set("heart",0);assert(medal.root.Tint.Visible and math.abs(medal.root.Trim.ImageTransparency-.65)<1e-3 and medal.root:FindFirstChild("Icon_heart")==nil)
   View.Art=savedArt;frame:Destroy()
  end)
  for _,size in ipairs({Vector2.new(1280,720),Vector2.new(844,390),Vector2.new(667,375)})do
   test(tostring(size).." stats panel: six slots inside the pet pane, under the total",function()
    on()
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local panel=Panel.new(host,{appearance=function()return{}end})
    panel:open({state=snapshot({power=26,energy=50,speed=75,smarts=99}),activeId="pip"},{});settle()
    local want={0,1,2,0,3,4}
    for index,medal in ipairs(panel.medalSlots)do
     assert(medal.root:GetAttribute("Count")==want[index]and medal.root:GetAttribute("Stat")==Stats.Order[index])
     local pane=medal.root.Parent
     local a,b=medal.root.AbsolutePosition,medal.root.AbsoluteSize
     assert(a.X>=pane.AbsolutePosition.X and a.X+b.X<=pane.AbsolutePosition.X+pane.AbsoluteSize.X+1 and a.Y+b.Y<=pane.AbsolutePosition.Y+pane.AbsoluteSize.Y+1,"slot "..index)
    end
    off();panel:setContext({state=snapshot({power=26})});assert(panel.medalSlots==nil)
    panel:destroy();host:Destroy()
   end)
   test(tostring(size).." inspect card: Marks, the trim, and the same card size rule",function()
    local plain=Inspect.geometry(size.X,size.Y)
    local marked=Inspect.geometry(size.X,size.Y,true)
    assert(plain.marks==false and plain.marksH==0 and marked.marks==true)
    assert(marked.H<=size.Y-58-12 and marked.W==plain.W and marked.statsH<=marked.bodyH,"the card still clears the top bar ("..marked.H..")")
   end)
  end
  test("inspect card: the row follows the public levels; off it is never made",function()
   local function card(part)
    part()
    local board=Instance.new("Folder")
    board:SetAttribute(Stats.PublicAttribute,Http:JSONEncode({v=1,pets={pip={levels={heart=80,power=26,energy=50,jump=3,speed=1,smarts=99},total=1}}}))
    local root=Instance.new("Frame");root.Size=UDim2.fromScale(1,1);root.Parent=gui
    local probe=setmetatable({root=root,spin=0,options={companions={boards=Instance.new("Folder")},garden={appearance=function()return{}end}}},Inspect)
    local identity={player=game:GetService("Players").LocalPlayer,pet=Pets.byId.pip,petId="pip",board=board}
    local built=probe:build(identity);built.identity=identity;probe.card=built;probe:paintStats()
    return probe,built,root
   end
   local probe,built,root=card(on)
   assert(built.stats.marks.row.Visible and built.frame:GetAttribute("TrimStat")=="smarts")
   local want={3,1,2,0,0,4}
   for index,medal in ipairs(built.stats.marks.slots)do assert(medal.root:GetAttribute("Count")==want[index])end
   built.identity.board:SetAttribute(Stats.PublicAttribute,Http:JSONEncode({v=1,pets={pip={levels={heart=3},total=8}}}));probe:paintStats()
   assert(built.frame:GetAttribute("TrimStat")==nil and not built.trim.Visible)
   off();probe:paintStats();assert(not built.stats.marks.row.Visible)
   for _,c in ipairs(built.inputs)do c:Disconnect()end;root:Destroy()
   probe,built,root=card(off)
   assert(built.stats.marks==nil and built.trim==nil and built.frame:FindFirstChild("MedalTrim")==nil)
   for _,c in ipairs(built.inputs)do c:Disconnect()end;root:Destroy()
  end)
  test("pure: crossings queue once; joining, a new pet and turning the part on only record",function()
   on()
   local watch={}
   assert(Host.watchMedals(watch,{pip={jump=30}})==0)
   assert(Host.watchMedals(watch,{pip={jump=50}})==1 and watch.pending[1].tier=="bloom")
   assert(Host.watchMedals(watch,{pip={jump=20}})==0 and Host.watchMedals(watch,{pip={jump=50}})==0,"a short snapshot never crosses twice")
   assert(Host.watchMedals(watch,{pip={jump=50},kit={jump=99}})==0)
   off();assert(Host.watchMedals(watch,{pip={jump=99}})==0 and #watch.pending==0 and Host.medalEggs({statEgg={medalEggs=4}})==0)
   on();assert(Host.watchMedals(watch,{pip={jump=99}})==0)
   assert(Host.medalEggs({statEgg={medalEggs=4}})==4 and Host.medalEggs({statEgg={}})==0 and Host.medalEggs(nil)==0 and Host.medalEggs({statEgg={medalEggs=0/0}})==0)
  end)
  test("a stage that cannot be built leaves nothing open, and the ticket says it",function()
   on()
   local Stage=require(client.HatchItemStage)
   local real=Stage.show
   local fine,wrong=pcall(function()
    for _,where in ipairs({"build","step"})do
     Stage.show=if where=="build"then function()error("no stage")end else function(...)
      local stage=real(...);stage.updateExternal=function()error("no step")end;return stage
     end
     local moment=View.Moment.new(parent,nil)
     assert(moment:show({{petId="pip",stat="jump",tier="sprout",level=25}},{waiting=1},{})==false,where)
     assert(not moment:isOpen()and not moment.gui.Enabled and moment.clock==nil and moment.stage==nil and moment.scene==nil,where)
     Stage.show=real
     assert(moment:show({{petId="pip",stat="jump",tier="sprout",level=25}},{waiting=1},{})and moment:isOpen(),"the next one plays")
     moment:destroy()
    end
    Stage.show=function()error("no stage")end
    local probe=Instance.new("Frame");probe.Size=UDim2.fromScale(1,1);probe.BackgroundTransparency=1;probe.Parent=gui
    local state=snapshot({jump=24})
    state.statEgg.medalEggs=1
    local api=Host.mount({parent=parent,insetProbe=probe,state=function()return state end,activeId=function()return "pip"end,appearance=function()return{}end,
     canOpen=function()return true end,prepare=function()end,held=function()return false end,openEggs=function()end,quiet=function()return true end,playerGui=parent})
    api.sync(state);state=snapshot({jump=25});state.statEgg.medalEggs=2;api.sync(state);settle(4)
    assert(not api.isBusy()and Host.medalEggs(state)==2 and api.open({stat="jump"}),"menus stay usable and the credit stands")
    api.destroy();probe:Destroy()
   end)
   Stage.show=real
   assert(fine,wrong)
  end)
  test("the moment: waits for quiet, one stage for several medals, A goes to the eggs",function()
   on()
   local probe=Instance.new("Frame");probe.Size=UDim2.fromScale(1,1);probe.BackgroundTransparency=1;probe.Parent=gui
   local state,quiet,eggs=snapshot({jump=24,heart=49}),false,0
   local api=Host.mount({parent=parent,insetProbe=probe,state=function()return state end,activeId=function()return "pip"end,appearance=function()return{}end,
    canOpen=function()return true end,prepare=function()end,held=function()return false end,openEggs=function()eggs+=1 end,quiet=function()return quiet end,playerGui=parent})
   api.sync(state);state=snapshot({jump=25,heart=50});api.sync(state)
   settle();assert(not api.isBusy(),"not while something is on screen")
   quiet=true;settle(4);assert(api.isBusy())
   local stage
   local medalGui=parent:FindFirstChild("EggDropMedal")
   for _,d in ipairs(medalGui:GetDescendants())do if d:GetAttribute("Medal")then stage=d end end
   assert(stage and stage:GetAttribute("Medal")=="bloom"and stage:GetAttribute("MedalStat")=="heart"and stage:GetAttribute("MedalCount")==2)
   assert(api.open({stat="jump"})==false,"the panel waits for it")
   api.destroy();assert(parent:FindFirstChild("EggDropMedal")==nil)
   local moment=View.Moment.new(parent,nil)
   assert(moment:show({{petId="pip",stat="jump",tier="starbloom",level=99}},{waiting=1},{eggs=function()eggs+=1 end}))
   moment:choose("eggs");assert(eggs==1 and not moment:isOpen())
   assert(moment:show({},{},{})==false,"nothing to show")
   moment:destroy();probe:Destroy()
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 View.Art=savedArt
 Levels.inject(nil)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
