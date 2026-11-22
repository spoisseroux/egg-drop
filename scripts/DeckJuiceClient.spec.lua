-- Studio Client. Deck juice, client part (FieldEffects, DeckFlourish; V3-LEVELS-BUILD-PLAN-2026-11-22 S3):
-- the part off, a missing or broken attribute and unknown ids are exactly the classic pop; a chosen pop
-- uses the same four slots and six fragments; nothing is made per merge; the start flourish plays once a
-- round, never on a running one, and the first drop cuts it; Reduced Motion and AliveBudget level 2 cut
-- everything; and a round's score, balls and hash are the same with every choice on and off.
-- Usage: require(PlayerScripts.Client.ZZSpecs.DeckJuiceClient)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shared=game.ReplicatedStorage.Shared
 local Effects=require(client.FieldEffects);local Flourish=require(client.DeckFlourish)
 local Budget=require(client.AliveBudget)
 local Juice=require(Shared.DeckJuiceCatalog);local Levels=require(Shared.Levels)
 local Http=game:GetService("HttpService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local root=Instance.new("Frame");root.Name="_DeckJuiceSpec";root.Size=UDim2.fromOffset(354,594);root.BackgroundTransparency=1;root.Parent=parent
 local folder=Instance.new("Folder")
 local function on(juice)Levels.inject({flags={LevelsMatter=juice==true},studio=true,shipped={track=true,gates=true,medals=true,juice=true}})end
 local function ask(value)folder:SetAttribute(Juice.Attribute,if type(value)=="table"then Http:JSONEncode(value)else value);task.wait()end
 local made={}
 local views={}
 local function layer(options)
  local fx=Effects.new(root);table.insert(made,fx)
  if options~=false then
   fx:attachJuice({board=folder,views=views,launchY=17.8,project=function(p)return Vector2.new(177+p.X*30,594-p.Y*30),30 end,ready=type(options)=="function"and options or nil})
  end
  return fx
 end
 local color=Color3.fromRGB(82,173,242)
 local function emit(fx,now,tier,chain)return fx:emit("merge",Vector2.new(100,120),18,color,tier or 3,chain or 1,fx.serial,now,nil,false,30)end
 -- Every drawn value of the four slots, for an exact comparison.
 local function picture(fx)
  local out={}
  local function add(...)for _,v in ipairs({...})do table.insert(out,tostring(v))end end
  for _,slot in ipairs(fx.slots)do
   add(slot.ring.Visible,slot.ring.Size,slot.ring.Position,slot.stroke.Transparency,slot.stroke.Thickness,slot.stroke.Color)
   for _,f in ipairs(slot.fragments)do add(f.Visible,f.Position,f.Size,f.Rotation,f.BackgroundColor3,f.BackgroundTransparency,f:FindFirstChildOfClass("UICorner").CornerRadius,#f:GetChildren())end
  end
  return table.concat(out,"|")
 end
 local realLevel=Budget.level
 local ok,problem=pcall(function()
  test("readJuice: known ids only; missing, broken, unknown, classic and the wrong kind are classic",function()
   local function read(value)local a,b,c=Effects.readJuice(value);return tostring(a)..","..tostring(b)..","..tostring(c)end
   assert(read(nil)=="nil,nil,nil"and read("")=="nil,nil,nil"and read("{")=="nil,nil,nil"and read(5)=="nil,nil,nil"and read("7")=="nil,nil,nil")
   assert(read(Http:JSONEncode({pop="classic",trail="aurora_later",start=3}))=="nil,nil,nil"and read(Http:JSONEncode({pop="comet",trail="fizz",start="confetti"}))=="nil,nil,nil")
   assert(read(Http:JSONEncode({pop="fizz",trail="comet",start="ready",hat="x"}))=="fizz,comet,ready")
   for _,row in ipairs(Juice.ByKind.pop)do assert(Effects.Pops[row.id],row.id)end
   for _,row in ipairs(Juice.ByKind.start)do assert(Flourish.Styles[row.id],row.id)end
  end)
  test("off, or classic: no pools, and frame by frame the pop that shipped",function()
   on(false);ask({pop="confetti",trail="comet",start="ready"})
   local plain,off=layer(false),layer()
   on(true);ask(nil);local missing=layer();ask({pop="nope",trail="nope",start="nope"});local unknown=layer()
   on(false)
   local n=#plain.root:GetDescendants()
   for _,fx in ipairs({plain,off,missing,unknown})do
    assert(fx.popStyle==nil and fx.trail==nil and fx.flourish==nil and #fx.root:GetDescendants()==n)
    fx:setOwner(true,10,false)
   end
   for step=0,30 do
    local now=100+step/60
    if step%5==0 then for _,fx in ipairs({plain,off,missing,unknown})do emit(fx,now,1+step%5,1+step//10)end end
    for _,fx in ipairs({plain,off,missing,unknown})do fx:update(now)end
    local want=picture(plain)
    assert(picture(off)==want and picture(missing)==want and picture(unknown)==want,"frame "..step)
   end
   local writes=plain.stats.writes;assert(off.stats.writes==writes and missing.stats.writes==writes,"the same work")
   -- the switch flips on, then off, under a mounted layer
   on(true);ask({pop="confetti"});assert(off.popStyle=="confetti"and missing.popStyle=="confetti")
   on(false);ask({pop="confetti",hat="x"});assert(off.popStyle==nil and missing.popStyle==nil)
  end)
  for _,id in ipairs({"confetti","fizz"})do
   test(id..": the same slots and fragments, its own shapes, nothing made per merge, all gone in time",function()
    on(true);ask({pop=id})
    local fx=layer();assert(fx.popStyle==id and #fx.slots==4 and #fx.slots[1].fragments==6)
    fx:setOwner(true,20,false)
    local n=#fx.root:GetDescendants()
    assert(emit(fx,200));fx:update(200.1)
    local slot=fx.slots[1];assert(slot.style==id and slot.ring.Visible)
    for j,f in ipairs(slot.fragments)do assert(f.Visible and f.Size.X.Offset>=4 and f.Size.Y.Offset>=3 and slot.edges[j].Enabled and not f.Active,j)end
    -- a 15-merge chain stays in the pool; the priority rule still decides
    for k=1,15 do emit(fx,200.2+k*.06,1+k%5,k);fx:update(200.2+k*.06)end
    assert(#fx.root:GetDescendants()==n and fx.stats.accepted+fx.stats.rejected>=16)
    fx:update(203);assert(fx.stats.active==0);for _,s in ipairs(fx.slots)do for _,f in ipairs(s.fragments)do assert(not f.Visible)end end
    -- an impact or a drop ring never takes the style
    assert(fx:emit("impact",Vector2.new(50,50),12,color,1,1,20,204,Vector2.new(0,-1)));fx:update(204.05)
    for _,s in ipairs(fx.slots)do if s.active then assert(s.style==nil);for _,f in ipairs(s.fragments)do assert(not f.Visible)end end end
    -- bounded, the same every time
    for j=1,6 do for s=0,20 do
     local t=s/20;local x,y,w,h,_,fade=Effects.popPose(id,j,t,1-(1-t)*(1-t),Effects.fragmentReach(5))
     assert(math.abs(x)<=3.2 and math.abs(y)<=3.6 and w>0 and w<=.6 and h>0 and fade>=0 and fade<=1 and x==(Effects.popPose(id,j,t,1-(1-t)*(1-t),Effects.fragmentReach(5))))
    end end
    -- back to classic mid-life: the pool is put back as it was made
    emit(fx,210);ask({pop="classic"});assert(fx.popStyle==nil and fx.stats.active==0)
    local plain=layer(false);plain:setOwner(true,20,false)
    emit(fx,211);emit(plain,211);fx:update(211.1);plain:update(211.1)
    for j,f in ipairs(fx.slots[1].fragments)do
     local p=plain.slots[1].fragments[j]
     assert(f.Position==p.Position and f.Size==p.Size and f.Rotation==0 and f.BackgroundColor3==p.BackgroundColor3 and f:FindFirstChildOfClass("UICorner").CornerRadius==UDim.new(.5,0)and not fx.slots[1].edges[j].Enabled)
    end
   end)
  end
  test("Reduced Motion keeps today's still pop; level 2 goes back to classic for the session",function()
   on(true);ask({pop="confetti",trail="comet",start="ready"})
   local fx=layer();fx:setOwner(true,30,true);assert(emit(fx,300));fx:update(300.05)
   assert(fx.slots[1].ring.Visible and fx.slots[1].style==nil and fx.slots[1].duration==.18)
   for _,f in ipairs(fx.slots[1].fragments)do assert(not f.Visible)end
   fx:setOwner(true,30,false)
   Budget.level=function()return 2 end
   assert(emit(fx,301)and fx.popStyle==nil and fx.slots[1].style==nil)
   Budget.level=realLevel
  end)
  test("the host's hooks: a trail only with views, ballAdded is nothing while classic, the owner covers it",function()
   on(true);ask({trail="bubble"})
   local fx=layer();assert(fx.trail and fx.trail.style=="bubble");fx:setOwner(true,40,false)
   local source={Position=Vector3.new(0,17.8,0),Size=Vector3.new(1,1,1)};views[source]={tier=2}
   fx:ballAdded(source);assert(fx.trail.stats.followed==1)
   fx:setOwner(false,40,false);assert(fx.trail.source==nil)
   local pool=#fx.root:GetDescendants()
   ask({trail="classic"});assert(fx.trail==nil);fx:ballAdded(source);ask({trail="comet"});assert(fx.trail.style=="comet"and #fx.root:GetDescendants()==pool,"one pool, reused")
   local bare=Effects.new(root);table.insert(made,bare);bare:attachJuice({board=folder});assert(bare.trail==nil)
   table.clear(views)
  end)
  test("start flourish: once a round, waits for a bare screen, never on a running round, the first drop cuts it",function()
   on(true);ask({start="lightning"})
   local ready=false
   local fx=layer(function()return ready end)
   local f=fx.flourish;assert(f and f.style=="lightning"and not f.root.Visible)
   for _,node in ipairs(f.root:GetDescendants())do if node:IsA("GuiObject")then assert(not node.Active and not node.Selectable,node.Name)end end
   local n=#fx.root:GetDescendants()
   fx:observeDrop(50,0);fx:setOwner(true,50,false);fx:update(400);assert(not f.root.Visible and f.pending,"the boot is still up")
   ready=true;fx:update(400.1);assert(f.root.Visible and f.playing)
   for k=0,70 do fx:update(400.1+k/60)end;assert(not f.root.Visible and not f.playing and f.stats.played==1,"one second")
   fx:setOwner(false,50,false);fx:setOwner(true,50,false);fx:update(403);assert(f.stats.played==1,"not again after a pause")
   fx:observeDrop(51,0);fx:setOwner(true,51,false);fx:update(404);fx:update(404.1);assert(f.playing)
   assert(fx:observeDrop(51,1)==true and not f.root.Visible and not f.playing,"the first drop cuts it")
   fx:observeDrop(52,7);fx:setOwner(true,52,false);fx:update(405);assert(f.stats.played==2,"a running round")
   ready=false;fx:observeDrop(53,0);fx:setOwner(true,53,false);fx:update(406);fx:update(406+Flourish.Wait+.1);ready=true;fx:update(409);assert(f.stats.played==2,"too late is skipped")
   fx:observeDrop(54,0);fx:setOwner(true,54,true);fx:update(410);assert(f.stats.played==2,"Reduced Motion")
   Budget.level=function()return 2 end;fx:observeDrop(55,0);fx:setOwner(true,55,false);fx:update(411);Budget.level=realLevel;assert(f.stats.played==2,"level 2")
   ask({start="ready"});assert(f.style=="ready");fx:observeDrop(56,0);fx:setOwner(true,56,false);fx:update(412);assert(f.playing)
   fx:setOwner(true,56,true);assert(not f.root.Visible,"Reduced Motion turned on");assert(#fx.root:GetDescendants()==n,"nothing made per round")
   for id,s in pairs(Flourish.Styles)do
    local last=0
    for k=0,100 do local d,o=Flourish.lid(id,k/100);assert(d>=0 and d<=1 and o>=last and o<=1);last=o end
    assert(s.opened<Flourish.Duration and select(2,Flourish.lid(id,s.opened))==1)
   end
   assert(Flourish.lampsLit(0)==0 and Flourish.lampsLit(.2)==1 and Flourish.lampsLit(.6)==3)
  end)
  test("determinism: a seeded round is the same to the last ball with every effect on, off and Reduced",function()
   local Sim=require(Shared.BoardSim);local Config=require(Shared.BoardConfig)
   local inputs={};for k=0,39 do inputs[k+1]={tick=k*80,kind="drop",aim=(k*37%101)/100}end
   local function round(choice,reduced)
    on(choice~=nil);ask(choice)
    local fx=if choice then layer()else layer(false)
    fx:observeDrop(60,0);fx:setOwner(true,60,reduced==true)
    local merges,drops=0,0
    local result=Sim.replay(90210,Config.DefaultPreset,inputs,3600,{hashEvery=32,onStep=function(sim,merged)
     local now=1000+sim.tick/120
     if sim.drops>drops then
      drops=sim.drops;fx:observeDrop(60,drops)
      local egg=sim.eggs[#sim.eggs];local source={Position=Vector3.new(egg.x,egg.y,0),Size=Vector3.new(egg.radius*2,egg.radius*2,1)}
      views[source]={tier=egg.tier};fx:ballAdded(source)
     end
     for _ in ipairs(merged)do merges+=1;fx:emit("merge",Vector2.new(100+merges%9*20,300),18,color,1+merges%5,1+merges%6,60,now,nil,false,20)end
     if sim.tick%2==0 then fx:update(now)end
    end})
    table.clear(views)
    assert(merges>5 and drops>20,"a real round")
    return table.concat(result.hashes,",").."|"..result.accepted.."|"..merges
   end
   local classic=round(nil)
   for _,choice in ipairs({{pop="confetti",trail="comet",start="ready"},{pop="fizz",trail="bubble",start="lightning"}})do
    assert(round(choice)==classic and round(choice,true)==classic)
   end
  end)
  test("the sim, lockstep and server never name the juice",function()
   for _,name in ipairs({"BoardSim","BoardRoundSim","BoardLockstep","BoardSimLaunch","BoardConfig"})do
    local source=Shared:FindFirstChild(name);local text="";pcall(function()text=source.Source end)
    assert(not string.find(text,"Juice",1,true),name)
   end
  end)
  test("teardown: late events and a late attribute do nothing",function()
   on(true);ask({pop="fizz",trail="bubble",start="ready"})
   local fx=layer();fx:destroy();fx:destroy()
   ask({pop="confetti"});assert(not emit(fx,500));fx:ballAdded({});fx:update(500);assert(fx.popStyle=="fizz"and fx.root.Parent==nil)
  end)
 end)
 Budget.level=realLevel;Levels.inject(nil)
 for _,fx in ipairs(made)do fx:destroy()end
 root:Destroy();folder:Destroy();assert(ok,problem)
 return{passed=#cases,cases=cases}
end
