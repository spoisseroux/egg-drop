-- Studio Client. The "Next at N" line, the stat guide and the reward dots (StatGuide, StatsPanel,
-- StatsHost, StatToasts; V3-LEVELS-BUILD-PLAN-2026-11-22 S1), with the track on and off.
--  * rows: earned / next / later, shop rows until owned, the row a ticket opens on.
--  * the panel: next line(s), a dot for a reward since it was last open, A or a tap opens the guide,
--    left / right and LB / RB change stat, B goes back, "Go to shop" closes into the shop; a snapshot
--    keeps the row; the runtime switch rebuilds it. Off: none of it exists. Three screen sizes.
--  * tickets name the reward and open the guide on it; a tap while the panel is open switches it.
--  * trick tickets replace the bond toast (StatToasts.trickUps).
-- Usage: require(PlayerScripts.Client.ZZSpecs.StatGuide)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Guide=require(client.StatGuide)
 local Panel=require(client.StatsPanel)
 local Toasts=require(client.StatToasts)
 local Levels=require(Shared.Levels)
 local Rewards=require(Shared.StatRewards)
 local Stats=require(Shared.StatCatalog)
 local UICopy=require(Shared.UICopy)
 local K=Enum.KeyCode
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local ALL={track=true,gates=true,medals=true,juice=true}
 local function on(shipped)Levels.inject({flags={LevelsMatter=true},studio=true,shipped=shipped or ALL})end
 local function off()Levels.inject({flags={},studio=true})end
 parent=parent:FindFirstAncestorOfClass("PlayerGui")or parent -- a gui inside a gui has no layout of its own
 local panels={} -- closed whatever happens, or an open panel covers every later spec
 local gui=Instance.new("ScreenGui");gui.Name="_StatGuideSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local function snapshot(levels)
  local xp,level,total={},{},0
  for _,id in ipairs(Stats.Order)do local n=levels[id]or 1;xp[id]=Stats.xpFor(n);level[id]=n;total+=n end
  return{petStats={pets={pip={xp=xp,level=level,total=total}},bonus={}},inventoryMask=1,statEgg={pouch={}},petWearables={},ballThemes={owned={}},faceplates={}}
 end
 local ok,problem=xpcall(function()
  test("pure: off has no rows, no line and no dots",function()
   off()
   assert(#Guide.rows("jump",5,nil)==0 and Guide.nextText("jump",1)==nil and next(Guide.dots({jump=1},{jump=99}))==nil)
  end)
  test("pure: earned, next and later; shop rows until owned; the asked row opens",function()
   on()
   local rows=Guide.rows("jump",15,snapshot({}))
   local seen={earned=0,next=0,later=0}
   local nextLevel
   for _,entry in ipairs(rows)do
    seen[entry.state]+=1
    assert((entry.state=="earned")==(entry.row.level<=15),entry.row.id)
    if entry.state=="next"then nextLevel=nextLevel or entry.row.level;assert(entry.row.level==nextLevel,"one level is next")end
    assert(type(entry.text)=="string"and entry.text~=""and entry.shop==(entry.row.kind=="gate"),entry.row.id)
    if entry.shop then assert(entry.status==UICopy.get("stats.guide.shop"))end
   end
   assert(seen.earned>0 and seen.next>0 and seen.later>0)
   local st=snapshot({});st.petWearables={pip={owned={"partyhat_lime"}}}
   for _,entry in ipairs(Guide.rows("jump",15,st))do if entry.row.ref=="partyhat_lime"then assert(not entry.shop and entry.status==UICopy.get("stats.guide.earned"))end end
   st.ballThemes={owned={"tangerine_pop"}};assert(Guide.owned({kind="gate",area="balls",ref="tangerine_pop"},st)and not Guide.owned({kind="gate",area="plates",ref="sky_fizz"},st))
   assert(rows[Guide.start(rows)].state=="next"and rows[Guide.start(rows,"medal_jump_bloom")].row.id=="medal_jump_bloom")
   assert(Guide.start({},nil)==1)
   -- The line: free, shop, then the top level.
   local free=Rewards.next("jump",15)
   assert(Guide.nextText("jump",15)==UICopy.get(if free.kind=="gate"then "stats.next.gate"else "stats.next.free",{level=free.level,name=Guide.text(free)}))
   assert(Guide.nextText("jump",14)==UICopy.get("stats.next.gate",{level=15,name="Lime Party Hat"}),Guide.nextText("jump",14))
   assert(Guide.nextText("jump",99)==UICopy.get("stats.next.top"))
   local dots=Guide.dots({jump=14,heart=1},{jump=15,heart=1});assert(dots.jump and not dots.heart)
   assert(next(Guide.dots(nil,{jump=99}))==nil,"a pet not seen before has no dots")
  end)
  test("pure: rows are 44 px on screen at any fit scale",function()
   for _,phone in ipairs({true,false})do
    for _,scale in ipairs({.5,.7,.9,.95,1,1.167,1.2})do assert(Guide.rowHeight(phone,scale)*scale>=44,tostring(scale))end
    for _,odd in ipairs({0,-1,0/0})do assert(Guide.rowHeight(phone,odd)>=44)end
   end
   assert(Guide.rowHeight(false,1)==46 and Guide.rowHeight(false,1.2)==46 and Guide.rowHeight(false,nil)==46)
  end)
  for _,size in ipairs({Vector2.new(1280,720),Vector2.new(1649,734),Vector2.new(1000,560),Vector2.new(844,390),Vector2.new(667,375)})do
   test(tostring(size).." panel: next line, dots, the guide and its keys",function()
    on()
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local went
    local panel=Panel.new(host,{appearance=function()return{}end,shop=function(row)went=row end});table.insert(panels,panel)
    panel:noteLevels(snapshot({jump=14}).petStats)
    local st=snapshot({jump=15,speed=99})
    panel:open({wallet=1,state=st,activeId="pip"},{stat="jump"});settle()
    assert(panel.nextLines[1].label.Text==Guide.nextText("jump",15)and(panel.nextLines[2]~=nil)==(panel.view==nil),"one line on phones, two on desktop")
    local strip,line=panel.detail,panel.nextLines[1].root
    assert(line.AbsolutePosition.Y+line.AbsoluteSize.Y<=strip.AbsolutePosition.Y+strip.AbsoluteSize.Y+1,"the line is inside the strip")
    assert(panel.guideHit.AbsoluteSize.Y>=44,"a 44 px target")
    assert(panel.tiles[4].dot.Visible and not panel.tiles[1].dot.Visible,"a dot on Jump only")
    panel:openGuide();settle()
    assert(panel.mode=="guide"and panel.guide.root.Visible and not panel.tiles[1].button.Visible and not panel.detail.Visible and panel.ring.target==panel.guide.views[panel.guide.index].root)
    for _,view in ipairs(panel.guide.views)do
     assert(view.root.AbsoluteSize.Y>=44,tostring(size).." 44 px rows: "..view.root.AbsoluteSize.Y.." at scale "..panel.scale.Scale)
     local label=view.text;assert(label.AbsolutePosition.X+label.AbsoluteSize.X<=view.root.AbsolutePosition.X+view.root.AbsoluteSize.X,view.entry.row.id)
    end
    local index=panel.guide.index
    panel:input(K.DPadDown);assert(panel.guide.index==index+1);panel:input(K.DPadUp);assert(panel.guide.index==index)
    panel:input(K.ButtonR1);assert(panel.guide.stat=="speed"and panel.root:GetAttribute("SelectedStat")=="speed");panel:input(K.Left);assert(panel.guide.stat=="jump")
    -- Back to the tiles, then A on the tile opens it again.
    panel:input(K.ButtonB);assert(panel.mode=="stats"and panel.visible and panel.tiles[1].button.Visible and panel.detail.Visible)
    panel:input(K.ButtonA);assert(panel.mode=="guide")
    panel:input(K.ButtonX);assert(panel.mode=="snacks");panel:input(K.ButtonB);assert(panel.mode=="stats")
    -- A ticket while the panel is open: that stat, that row; a snapshot keeps it.
    assert(panel:focusStat("power","pip","medal_power_bloom")and panel.guide.root:GetAttribute("FocusedReward")=="medal_power_bloom")
    panel:setContext({state=st});assert(panel.guide.root:GetAttribute("FocusedReward")=="medal_power_bloom")
    assert(panel:focusStat("heart","pip")and panel.mode=="stats"and Panel.Order[panel.index]=="heart")
    -- "Go to shop" closes into the shop, and what was seen has no dot next time.
    panel:openGuide("jump");for i,view in ipairs(panel.guide.views)do if view.shop then panel.guide:select(i);break end end
    assert(panel.guide:act()and went and went.kind=="gate"and not panel.visible)
    panel:open({state=st,activeId="pip"},{stat="speed",guide=true,row="medal_speed_starbloom"});settle()
    assert(panel.guide.root:GetAttribute("FocusedReward")=="medal_speed_starbloom"and not panel.tiles[4].dot.Visible)
    -- The runtime switch flips off, then on, while it is open.
    off();panel:setContext({state=st});assert(panel.mode=="stats"and panel.guideHit==nil and panel.guide==nil and panel.tiles[1].dot==nil and panel.medalSlots==nil)
    on();panel:setContext({state=st});assert(panel.guideHit~=nil and #panel.medalSlots==6)
    panel:destroy();host:Destroy()
   end)
   test(tostring(size).." panel off: no line, no dots, no guide; A still boings a tile",function()
    off()
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local panel=Panel.new(host,{appearance=function()return{}end});table.insert(panels,panel)
    panel:open({state=snapshot({jump=15}),activeId="pip"},{stat="jump",guide=true,row="x"});settle()
    assert(panel.mode=="stats"and panel.detail:FindFirstChild("GuideOpen")==nil and panel.detail:FindFirstChild("NextLine")==nil and panel.body:FindFirstChild("StatGuide")==nil)
    assert(panel.tiles[1].button:FindFirstChild("RewardDot")==nil and panel.medalSlots==nil)
    if panel.view then assert(panel.detail.Size.Y.Offset==54)end
    assert(panel:openGuide()==false);panel:input(K.ButtonA);assert(panel.mode=="stats")
    panel:destroy();host:Destroy()
   end)
  end
  local function toasts(width)
   local queued,opened={},nil
   local t=Toasts.new({rail={enqueue=function(_,key,data)queued[key]=data;return{cancel=function()end}end},fits=function(text)return #text<=width end,
    open=function(...)opened={...}end,now=function()return 0 end})
   return t,queued,function()return opened end
  end
  local function xp(levels)local row={};for stat,level in pairs(levels)do row[stat]=Stats.xpFor(level)end;return{pets={pip={xp=row}}}end
  test("tickets name the reward and open the guide on it; plain words when it does not fit or is off",function()
   on()
   local t,queued,opened=toasts(60)
   t:update(xp({jump=14}));t:update(xp({jump=15}))
   local key,data=next(queued)
   assert(data.text==UICopy.get("stats.levelUpReward",{name="Jump",count=15,reward="Lime Party Hat"}),data.text)
   data.activate();assert(opened()[1]=="jump"and opened()[2]=="pip"and opened()[3]=="wardrobe_partyhat_lime")
   -- Another stat merges in; the tap still goes to the reward.
   t:update(xp({jump=15,power=2}));queued[key].activate();assert(string.find(queued[key].text,"Power 2",1,true)==1 and opened()[1]=="jump")
   t,queued,opened=toasts(10);t:update(xp({jump=14}));t:update(xp({jump=15}));key,data=next(queued)
   assert(data.text=="Jump 15");data.activate();assert(opened()[3]=="wardrobe_partyhat_lime","the tap still knows it")
   off();t,queued,opened=toasts(60);t:update(xp({jump=14}));t:update(xp({jump=15}));key,data=next(queued)
   assert(data.text=="Jump 15");data.activate();assert(opened()[1]=="jump"and opened()[3]==nil)
  end)
  test("trick tickets: once per trick, never at the first snapshot; Heart's own are marked",function()
   local function st(bond,heart)return{bond={pip=bond},petStats={pets={pip={level={heart=heart}}}}}end
   off();assert(#Toasts.trickUps({},st(0,9))==0 and not Toasts.tricksOn())
   on()
   local seen={}
   assert(#Toasts.trickUps(seen,st(0,4))==0,"baseline")
   local events=Toasts.trickUps(seen,st(0,5))
   assert(#events==1 and events[1].heart and events[1].level==2 and events[1].text==UICopy.get("stats.reward.trick",{name=UICopy.get("bond.trick.l2")}))
   events=Toasts.trickUps(seen,st(75,5));assert(#events==1 and not events[1].heart and events[1].level==3,"Bond brought this one")
   assert(#Toasts.trickUps(seen,st(75,10))==0 and #Toasts.trickUps(seen,st(0,1))==0,"never lost, never twice")
   assert(#Toasts.trickUps(seen,{petStats={pets={pip={level={heart=40}},kit={level={heart=40}}}}})==1,"a pet first seen only records")
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 Levels.inject(nil)
 for _,panel in ipairs(panels)do pcall(function()panel:destroy()end)end
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
