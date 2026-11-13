-- Studio Client. Compact (phone landscape) deck screens: Compact v2, the slim frame
-- (UI-SPEC-COMPACT-FRAME-2026-11-12, section 9 decisions) and the Pocket Menu.
-- The breakpoint rule, the frame geometry tables at 844x390, 740x360, 932x430,
-- 568x320 and 667x375 (printed by scripts/deck_art/build_compact_frame_mockups.py
-- --tables), the built round HUD (targets >= 44, nothing interactive or text in the
-- Roblox keep-out, no overlapping targets, text >= 12 that fits, board aspect, no B),
-- the Pocket Menu, and every menu sheet with its plate grips.
-- Usage: require(PlayerScripts.Client.ZZSpecs.CompactPhone)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Screen=require(client.DeckScreen);local Kit=require(client.DeckKit)
 local Results=require(client.DeckResults);local Picker=require(client.DifficultyPicker)
 local Log=require(client.QuestLog);local Shop=require(client.FaceplateShop)
 local Pocket=require(client.PocketMenu)
 local aspect=(11+.8)/(19+.8)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function same(r,t)
  if t==nil then return r==nil end
  return r~=nil and r.x==t[1]and r.y==t[2]and r.w==t[3]and r.h==t[4]
 end
 local function show(r)return if r then string.format("%d,%d,%dx%d",r.x,r.y,r.w,r.h)else "nil"end
 local sizes={Vector2.new(568,320),Vector2.new(667,375),Vector2.new(740,360),Vector2.new(844,390),Vector2.new(932,430)}
 local gui=Instance.new("ScreenGui");gui.Name="_CompactPhoneSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function frame(size)
  local root=Instance.new("Frame");root.Name="Root";root.Size=UDim2.fromOffset(size.X,size.Y);root.BackgroundTransparency=1;root.Parent=gui
  return root
 end
 -- Shared checks over a built root: targets, keep-out, overlap and text.
 local function audit(root,label,kx,kh,skip)
  local origin=root.AbsolutePosition
  local targets={}
  for _,node in ipairs(root:GetDescendants())do
   if node:IsA("GuiObject")and node.Visible then
    local visible=true;local p=node.Parent
    while p and p~=root do if p:IsA("GuiObject")and not p.Visible then visible=false;break end;p=p.Parent end
    if visible then
     if node:IsA("GuiButton")and node.Active and not(skip and skip(node))then
      local s=node.AbsoluteSize
      assert(s.X>=44-.5 and s.Y>=44-.5,label..": target under 44 "..node:GetFullName().." "..tostring(s))
      local x,y=node.AbsolutePosition.X-origin.X,node.AbsolutePosition.Y-origin.Y
      assert(not(x<kx-.5 and y<kh-.5),label..": target in the keep-out "..node:GetFullName())
      table.insert(targets,node)
     elseif node:IsA("TextLabel")and node.Text~=""then
      assert(node.TextSize>=12,label..": text under 12 "..node:GetFullName().." "..node.TextSize)
      if node.TextTruncate==Enum.TextTruncate.None and not node.TextWrapped and node.AutomaticSize==Enum.AutomaticSize.None then
       assert(node.TextFits,label..": text does not fit "..node:GetFullName().." '"..node.Text.."'")
      end
      local x,y=node.AbsolutePosition.X-origin.X,node.AbsolutePosition.Y-origin.Y
      assert(not(x<kx-.5 and y<kh-.5),label..": text in the keep-out "..node:GetFullName())
     end
    end
   end
  end
  for i=1,#targets do for j=i+1,#targets do
   local a,b=targets[i],targets[j]
   if not a:IsDescendantOf(b)and not b:IsDescendantOf(a)then
    local ap,as,bp,bs=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
    local overlap=ap.X<bp.X+bs.X-.5 and bp.X<ap.X+as.X-.5 and ap.Y<bp.Y+bs.Y-.5 and bp.Y<ap.Y+as.Y-.5
    assert(not overlap,label..": targets overlap "..a.Name.." / "..b.Name)
   end
  end end
  return targets
 end
 local function inside(r,o)return r.x>=o.x and r.y>=o.y and r.x+r.w<=o.x+o.w and r.y+r.h<=o.y+o.h end
 local function apart(r,o)return r.x+r.w<=o.x or o.x+o.w<=r.x or r.y+r.h<=o.y or o.y+o.h<=r.y end
 local hudData={score=2340,chain=3,
  goals={{text="Merge II in the centre",short="II centre",done=true,progress=2,target=2,icon={kind="merge",tier=2,plus=false,zone="center"}},
   {text="Make III on RIGHT",short="III+ RIGHT",progress=1,target=2,icon={kind="merge",tier=3,plus=true,zone="right"}},
   {text="Make a tier IV",short="Tier IV",progress=0,target=1,icon={kind="merge",tier=4,plus=true,zone="any"}}},
  daily={{title="Win 2 rounds",progress=2,target=2,done=true,ready=true},{title="Chain 4 merges",progress=3,target=4},{title="Tier IV on Hard",progress=0,target=1}},
  next={2,1,1},eggsLeft=14,budget=24,difficulty="Medium",multiplier="×1",winPays="9–12",input="Touch"}
 local ok,problem=xpcall(function()
  test("breakpoint: landscape and (H < 500 or W < 1000) is Compact; desktop, the 1024x768 band and portrait are not",function()
   for _,size in ipairs({Vector2.new(568,320),Vector2.new(740,360),Vector2.new(844,390),Vector2.new(932,430),Vector2.new(999,600),Vector2.new(1400,499),Vector2.new(733,307)})do
    local g=Screen.resolve(size,aspect)
    assert(g.mode=="Compact"and g.phone and Kit.compactRule(size.X,size.Y),"compact "..tostring(size))
   end
   for _,pair in ipairs({{Vector2.new(1920,1080),"Regular"},{Vector2.new(1300,700),"Regular"},{Vector2.new(1024,768),"Small"},{Vector2.new(1000,500),"Small"}})do
    local g=Screen.resolve(pair[1],aspect)
    assert(g.mode==pair[2]and not g.phone and not Kit.compactRule(pair[1].X,pair[1].Y),"not compact "..tostring(pair[1]).." got "..g.mode)
   end
   assert(not Kit.compactRule(390,844)and not Kit.compactRule(600,520))
  end)
  test("frame geometry matches the spec tables at the five sizes",function()
   local want={
    [844]={H=390,layout="wide",board={313,12,218,366},score={120,12,113,44},chain={241,12,64,44},goals={114,64,191,132},quests={114,238,191,140},handle=nil,next={539,12,191,64},eggs={539,84,191,44},difficulty={539,136,191,44},winPays={539,188,191,44},controls={539,264,191,114},dpad={9,154,88,88},dpadLeft={9,154,44,88},dpadRight={53,154,44,88},menu={17,346,72,28},menuHit={11,338,84,44},a={791,191},aHit={741,141,100,100},wordmark={14,64,78,30},mg=40,cw=238,pocketCols=1,pocketFirst={272,89,300,44},pocketLast={272,297,300,44}},
    [740]={H=360,layout="wide",board={270,12,200,336},score={120,12,142,44},chain=nil,goals={102,64,160,132},quests={102,214,160,134},handle=nil,next={478,12,160,64},eggs={478,84,160,44},difficulty={478,136,160,44},winPays={478,188,160,44},controls={478,262,160,86},dpad={7,143,80,80},dpadLeft={3,143,44,80},dpadRight={47,143,44,80},menu={11,316,72,28},menuHit={5,308,84,44},a={693,176},aHit={648,131,90,90},wordmark={14,64,66,26},mg=24,cw=214,pocketCols=1,pocketFirst={220,74,300,44},pocketLast={220,282,300,44}},
    [932]={H=430,layout="wide",board={345,12,242,406},score={120,12,145,44},chain={273,12,64,44},goals={114,64,223,132},quests={114,278,223,140},handle=nil,next={595,12,223,64},eggs={595,84,223,44},difficulty={595,136,223,44},winPays={595,188,223,44},controls={595,304,223,114},dpad={9,174,88,88},dpadLeft={9,174,44,88},dpadRight={53,174,44,88},menu={17,386,72,28},menuHit={11,378,84,44},a={879,211},aHit={829,161,100,100},wordmark={14,64,78,30},mg=40,cw=268,pocketCols=1,pocketFirst={316,109,300,44},pocketLast={316,317,300,44}},
    [568]={H=320,layout="narrow",board={196,12,176,296},score={88,64,100,44},chain={120,12,68,44},goals={88,116,100,108},quests=nil,handle={88,264,100,44},next={380,12,100,44},eggs={380,64,100,44},difficulty={380,116,100,44},winPays={380,168,100,44},controls={380,222,100,86},dpad={6,129,68,68},dpadLeft={0,129,44,68},dpadRight={44,129,44,68},menu={8,276,64,28},menuHit={4,268,72,44},a={528,157},aHit={489,118,78,78},wordmark=nil,mg=6,cw=169,pocketCols=2,pocketFirst={97,106,183,44},pocketLast={288,158,183,44}},
    [667]={H=375,layout="narrow",board={229,12,209,351},score={102,64,119,44},chain={120,12,101,44},goals={102,116,119,132},quests=nil,handle={102,319,119,44},next={446,12,119,64},eggs={446,84,119,44},difficulty={446,136,119,44},winPays={446,188,119,44},controls={446,249,119,114},dpad={7,150,80,80},dpadLeft={3,150,44,80},dpadRight={47,150,44,80},menu={11,331,72,28},menuHit={5,323,84,44},a={620,184},aHit={575,139,90,90},wordmark={14,64,66,26},mg=6,cw=202,pocketCols=1,pocketFirst={183,82,300,44},pocketLast={183,290,300,44}},
   }
   for _,size in ipairs(sizes)do
    local w=want[size.X];local W,H=size.X,size.Y
    local g=Screen.resolve(size,aspect,{kx=116,kh=58})
    assert(g.layout==w.layout,W.." layout "..tostring(g.layout))
    for _,name in ipairs({"board","score","chain","goals","quests","handle","next","eggs","difficulty","winPays","controls","dpad","dpadLeft","dpadRight","menu","menuHit","aHit","wordmark"})do
     assert(same(g[name],w[name]),string.format("%d %s: %s",W,name,show(g[name])))
    end
    assert(g.a.X==w.a[1]and g.a.Y==w.a[2],W.." A centre")
    assert(g.mg==w.mg and g.cw==w.cw and g.ch==H-140 and g.actionY==H-66,W.." sheet")
    assert(g.pocket.cols==w.pocketCols and same(g.pocket.items[1],w.pocketFirst)and same(g.pocket.items[5],w.pocketLast),W.." pocket "..show(g.pocket.items[1]))
    -- Structure: 4 px of plate above and below the glass; every card and the board in the screen;
    -- the d-pad, MENU, back and A on the shoulders; the board H - 24 high at the sim aspect.
    assert(g.glass.y==4 and g.glass.y+g.glass.h==H-4 and g.glass.x==g.SW and g.glass.x+g.glass.w==W-g.SW,W.." glass rims")
    local screen={x=g.x0,y=g.y0,w=g.LW,h=g.LH}
    for _,name in ipairs({"board","score","chain","goals","quests","handle","next","eggs","difficulty","winPays","controls"})do
     if g[name]then assert(inside(g[name],screen),W.." "..name.." outside the screen")end
     if g[name]then assert(not(g[name].x<116 and g[name].y<58),W.." "..name.." in the keep-out")end
    end
    for _,name in ipairs({"dpad","menu","back"})do assert(apart(g[name],g.glass),W.." "..name.." on the glass")end
    assert(apart({x=g.a.X-g.A/2,y=g.a.Y-g.A/2,w=g.A,h=g.A},g.glass),W.." A on the glass")
    assert(g.board.h==H-24 and math.abs(g.board.w-g.board.h*aspect)<=.5+1e-6,W.." board height and aspect")
    assert(g.board.x-g.x0==g.x1-(g.board.x+g.board.w)or math.abs((g.board.x-g.x0)-(g.x1-g.board.x-g.board.w))<=1,W.." board centred")
    assert((g.quests~=nil)==(g.layout=="wide"),W.." quests card only in two text columns")
   end
  end)
  test("round HUD at each size: targets, keep-out, text, A on the right shoulder, no B",function()
   for _,size in ipairs(sizes)do
    local root=frame(size)
    local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true)
    local quests=0;s:on("quests",function()quests+=1 end)
    s:setHud(hudData)
    task.wait()
    local label=tostring(size);local g=s.geometry
    audit(root,label.." HUD",116,58)
    local a=s.buttons.A.hit.AbsolutePosition+s.buttons.A.hit.AbsoluteSize/2-root.AbsolutePosition
    assert(math.abs(a.X-g.a.X)<=1 and math.abs(a.Y-g.a.Y)<=1 and a.X>g.x1,label.." A on the right shoulder at mid height")
    assert(not s.buttons.B.holder.Visible,label.." B is not drawn (decision 4)")
    assert(s.menu.Visible and s.menuHit.AbsoluteSize.Y>=44,label.." MENU on the shoulder")
    assert(s.lcd.AbsoluteSize.Y==size.Y-24,label.." board at H - 24")
    assert(s.hud.questDot.Visible,label.." ready dot")
    assert(s.hud.goalsEyebrow.Text=="GOALS 1/3",label.." goals header")
    -- Narrow columns use icon goals; wide columns keep the words.
    local first=s.hud.goals[1]
    if g.layout=="narrow"then
     assert(first.icon and first.egg.ball.Visible and first.check.root.Visible and not first.count.Visible,label.." done icon goal shows the check")
     assert(s.hud.goals[2].plus.Visible and s.hud.goals[2].zone.root.Visible and not s.hud.goals[3].zone.root.Visible,label.." + and zone glyphs")
     assert(s.hud.goals[2].row:GetAttribute("AccessibleLabel")=="Make III on RIGHT",label.." icon row carries the words")
    else assert(first.text and first.text.Text=="II centre",label.." text goals")end
    -- Touch Controls: Aim and Drop only.
    if s.hud.controls then
     local texts={};for _,slot in ipairs(s.hud.controls)do if slot.text.Text~=""then table.insert(texts,slot.text.Text)end end
     assert(#texts==2 and texts[1]=="Aim"and texts[2]=="Drop",label.." touch controls "..table.concat(texts,","))
     assert(s.hud.controlsCard.AbsoluteSize.Y==30+2*28,label.." card follows its rows")
    end
    -- The quests card / handle opens the quest log.
    local hit=s.hud.questsHit;assert(hit and hit.AbsoluteSize.X>=44 and hit.AbsoluteSize.Y>=44,label.." quests target")
    s.callbacks.quests();assert(quests>=1,label.." quests callback")
    -- Keyboard: three rows with Leave (wide columns have room).
    if s.hud.controls and #s.hud.controls>=3 then
     local data=table.clone(hudData);data.input="Keyboard";s:setHud(data);task.wait()
     assert(s.hud.controls[3].text.Text=="Leave",label.." keyboard keeps Leave")
     audit(root,label.." HUD keyboard",116,58)
    end
    root:Destroy()
   end
  end)
  test("Pocket Menu: pure focus steps on one and two columns, skipping disabled rows",function()
   local all={true,true,true,true,true}
   assert(Pocket.step(1,0,1,1,all)==2 and Pocket.step(5,0,1,1,all)==5 and Pocket.step(1,1,0,1,all)==1)
   assert(Pocket.step(1,1,0,2,all)==4 and Pocket.step(3,1,0,2,all)==5 and Pocket.step(4,-1,0,2,all)==1 and Pocket.step(5,0,1,2,all)==5)
   assert(Pocket.step(1,0,1,1,{true,false,true,true,true})==3,"skips a disabled row")
   assert(Pocket.step(1,0,1,1,{true,false,false,false,false})==1,"nothing enabled below")
  end)
  test("Pocket Menu at 568, 740 and 844: in the screen, audit, arming, routes and close",function()
   for _,size in ipairs({Vector2.new(568,320),Vector2.new(740,360),Vector2.new(844,390)})do
    local label=tostring(size)
    local root=frame(size)
    local s=Screen.new({parent=root,overlayParent=root,viewRoot=root})
    local calls={}
    local function cb(id)return function()table.insert(calls,id)end end
    local menu=Pocket.new(s:addOverlay("Pocket",36,{lcd=true}),{resume=cb("resume"),restart=cb("restart"),quit=cb("quit"),hatch=cb("hatch"),customize=cb("customize")})
    s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true)
    s:setHud(hudData)
    menu:open({empty=false,canRestart=true,canQuit=true,canHatch=true,canCustomize=true})
    task.wait(.3)
    local g=s.geometry;local layer=menu.overlay.layer;local o=root.AbsolutePosition
    local lp=layer.AbsolutePosition-o
    assert(layer.Visible and lp.X==g.screen.x and lp.Y==g.screen.y and layer.AbsoluteSize.X==g.screen.w and layer.AbsoluteSize.Y==g.screen.h,label.." in the screen rect")
    assert(not menu.shutters[1].Visible,label.." wipe finished")
    audit(layer,label.." pocket",116-g.screen.x,58-g.screen.y)
    for i,button in ipairs(menu.buttons)do
     local p=button.AbsolutePosition-o;local want=g.pocket.items[i]
     assert(p.X==want.x and p.Y==want.y and button.AbsoluteSize.X==want.w and button.AbsoluteSize.Y==44,label.." row "..i)
    end
    -- Keyboard / gamepad focus.
    assert(menu.focusIndex==1)
    menu:move(0,1);assert(menu.focusIndex==2,label.." down")
    -- Mid-round Restart asks once more; moving away disarms; a second press acts.
    menu:confirm();assert(menu.armed=="restart"and #calls==0 and Kit.buttonState(menu.buttons[2]).label.Text=="Tap again to restart",label.." armed")
    menu:move(0,1);assert(menu.armed==nil and Kit.buttonState(menu.buttons[2]).label.Text=="Restart round",label.." disarmed by moving")
    menu:move(0,-1);menu:confirm();menu:confirm();assert(calls[1]=="restart",label.." restart after the second press")
    -- Empty board: Quit acts at once. Disabled rows do nothing.
    table.clear(calls)
    menu:open({empty=true,canRestart=true,canQuit=true,canHatch=false,canCustomize=true})
    menu:activate(3,true);assert(calls[1]=="quit",label.." empty board quits at once")
    menu:activate(4,true);assert(#calls==1,label.." disabled Hatch does nothing")
    menu:activate(5,true);assert(calls[2]=="customize",label.." customize")
    menu:activate(1,true);assert(calls[3]=="resume",label.." resume")
    -- Close hides the layer after the out wipe; a quick reopen is not hidden by the stale close.
    assert(menu:close()and not menu.visible);menu:open({empty=true});task.wait(.25)
    assert(layer.Visible and menu.visible,label.." reopen survives the stale close")
    menu:close();task.wait(.25);assert(not layer.Visible,label.." closed")
    assert(not menu:close(),label.." second close is a no-op")
    -- Relayout while open keeps it open (rotation / resize).
    menu:open({empty=false});s:layout(Vector2.new(740,360),aspect,{kx=116,kh=58});task.wait()
    assert(menu.visible and layer.Visible and #menu.buttons==5,label.." survives a relayout")
    root:Destroy()
   end
  end)
  test("Pocket Menu on the desktop LCD (Regular stays unchanged)",function()
   local size=Vector2.new(1920,1080)
   local root=frame(size)
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root})
   local menu=Pocket.new(s:addOverlay("Pocket",36,{lcd=true}),{})
   local g=s:layout(size,aspect)
   assert(g.mode=="Regular"and s.buttons.B.holder.Visible and s.menu.Visible,"desktop keeps B and MENU")
   menu:open({empty=true});task.wait(.3)
   local layer=menu.overlay.layer
   assert(layer.AbsoluteSize.X==math.floor(g.lcd.w+.5)or math.abs(layer.AbsoluteSize.X-g.lcd.w)<=1,"desktop: the LCD rect")
   audit(layer,"desktop pocket",0,0)
   root:Destroy()
  end)
  test("menu sheets at each size: picker, results, quest log and shop with the plate grips",function()
   for _,size in ipairs(sizes)do
    local label=tostring(size)
    local root=frame(size)
    local s=Screen.new({parent=root,overlayParent=root,viewRoot=root})
    local pick=Picker.new(s:addOverlay("Picker",32),{})
    local log=Log.new(s:addOverlay("Log",34),{})
    s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true)
    local g=s.geometry;local mg=g.mg;local off=mg-6
    local res=Results.new(s.resultsContent,{})
    pick:show({selected="medium",pays={easy={5,6},medium={6,8},hard={9,12}},wallet=128,goal="Make two tier III eggs on RIGHT",questCount="1/3",questReady=true})
    task.wait()
    audit(pick.overlay.layer,label.." picker",116,58)
    local cw,ch=g.cw,g.ch
    local showCard=Picker.compactCard(cw,ch)
    assert(pick.cards[1].tidy.Visible==showCard.tidy and pick.cards[2].button.AbsoluteSize.X==cw,label.." picker cards")
    -- Grips: ridges only on 24+ px grips.
    local grips=pick.overlay.rim:FindFirstChild("Grips")
    assert(grips and grips.Visible==(mg>=24),label.." grips")
    pick:hide()
    res:show({outcome="clear",title="Creek crossing",difficulty="Hard",earned=12,total=12,balance=140,rows={{name="Round win",amount=8},{name="Tidy stack",amount=2},{name="Hard ×1.5",amount=2}},
     goals={{text="Merge II in the centre",short="II centre",done=true},{text="Make III on RIGHT",short="III RIGHT",done=true},{text="Make a tier IV",short="Tier IV"}},
     score=2340,best=2340,chain=4,newBest=true,level=3,questDone="Win 2 rounds",questCount="1/3"},s:view())
    task.wait(.3)
    audit(s.results,label.." results",116,58)
    local o=s.results.AbsolutePosition
    local leave=res.leave.AbsolutePosition-o;local replay=res.replay.AbsolutePosition-o
    assert(leave.X==mg+14 and leave.Y==size.Y-66,label.." Leave bottom left at mg + 14 ("..leave.X..")")
    assert(replay.X+res.replay.AbsoluteSize.X==size.X-mg-14 and replay.Y==size.Y-66,label.." Replay bottom right at W - mg - 14")
    assert(res.difficulty.AbsoluteSize.X==48 and res.difficulty:GetAttribute("AccessibleLabel")=="Change difficulty",label.." change difficulty")
    local picked=0;res:on("picker",function()picked+=1 end)
    res.focus=1;res:move(-1);assert(res.focus==3,"left of Replay is Change difficulty");res:move(-1);assert(res.focus==4,"then the quest shortcut");res:move(-1);assert(res.focus==2)
    res.focus=3;res:confirm();res:confirm();assert(picked>=1,"Change difficulty opens the picker")
    res:hide()
    log:show({day=10,week=2,resetIn=26000,weekResetIn=200000,rerollLeft=1,
     daily={{slot=1,id="a",title="Win 2 rounds",sub="Any difficulty",progress=2,target=2,reward=4,ready=true,pool="play"},{slot=2,id="b",title="Chain 4 merges",sub="In one round",progress=3,target=4,reward=4,pool="craft"},{slot=3,id="c",title="Make a tier IV on Hard",sub="Skill quest",progress=0,target=1,reward=4,canReroll=true,pool="skill"}},
     weekly={{slot=1,id="w1",title="Win 10 rounds",sub="This week",progress=4,target=10,reward=5,pool="play"},{slot=2,id="w2",title="Claim 9 dailies",sub="This week",progress=9,target=9,reward=5,ready=true,pool="craft"},{slot=3,id="w3",title="Clear 3 Hard rounds",sub="This week",progress=3,target=3,reward=5,claimed=true,pool="skill"}},
     bonus={reward=5},history={{d=10,title="Win 2 rounds",s=4},{d=9,title="Chain 4 merges",s=4,weekly=false},{d=9,title="Clear 3 Hard rounds",s=5,weekly=true}}},128,"daily")
    task.wait(.3)
    for _,tab in ipairs({"daily","weekly","history"})do
     log:setTab(tab);task.wait()
     audit(log.overlay.layer,label.." log "..tab,116,58)
    end
    local rh,_,tops=Log.compactRows(size.Y)
    assert(log.rows[2].row.Position.Y.Offset==tops[2]-64 and log.rows[1].row.AbsoluteSize.Y==rh,label.." row pitch")
    assert(log.footer.AbsoluteSize.Y==44 and log.footer.AbsolutePosition.Y-log.overlay.layer.AbsolutePosition.Y==size.Y-62,label.." pinned footer")
    assert(log.footer.AbsolutePosition.X-log.overlay.layer.AbsolutePosition.X==mg+14,label.." log body edge at mg + 14")
    log:hide()
    local host=frame(size);host.Name="ShopHost"
    local shop=Shop.new(host,{});shop:fit(size)
    shop:setContext({equipped="sherbet",wallet=128,facts={faceplates={}}});shop:open("sherbet");task.wait()
    local grid=Shop.compactGrid(size.X-2*off,size.Y)
    assert(shop.columns==grid.cols and shop.tiles[1].button.AbsoluteSize.X==grid.tileW and shop.tiles[1].button.AbsoluteSize.Y==64,label.." grid")
    audit(shop.root,label.." shop",116-off,58,function(node)return node:IsDescendantOf(shop.grid)and(node.AbsolutePosition.Y<shop.grid.AbsolutePosition.Y or node.AbsolutePosition.Y+node.AbsoluteSize.Y>shop.grid.AbsolutePosition.Y+shop.grid.AbsoluteSize.Y)end)
    local action=shop.action.AbsolutePosition-host.AbsolutePosition
    assert(action.X+shop.action.AbsoluteSize.X==size.X-off-32 and action.Y+48==size.Y-18-12,label.." Buy / Equip pinned bottom right")
    host:Destroy();root:Destroy()
   end
  end)
  test("wardrobe insets near the breakpoint come from the probe and never oscillate",function()
   local Device,Core=Enum.ScreenInsets.DeviceSafeInsets,Enum.ScreenInsets.CoreUISafeInsets
   for _,probe in ipairs({Vector2.new(1180,540),Vector2.new(1100,520),Vector2.new(999,560),Vector2.new(1000,500),Vector2.new(640,520),Vector2.new(620,540)})do
    local insets,changes=Core,0
    for _=1,6 do
     local wanted=Kit.compactInsets(probe)
     if wanted~=insets then insets=wanted;changes+=1 end
    end
    assert(changes<=1,"probe rule flipped "..changes.." times at "..tostring(probe))
    assert(insets==(if Kit.compactRule(probe.X,probe.Y)then Device else Core),"settled on the probe's mode at "..tostring(probe))
   end
   local flips=0;local insets=Core
   for _=1,6 do
    local size=if insets==Device then Vector2.new(1180,540)else Vector2.new(1180,482)
    local wanted=Kit.compactInsets(size);if wanted~=insets then insets=wanted;flips+=1 end
   end
   assert(flips>=4,"self-measuring fixture should oscillate (got "..flips..")")
   local probe=Instance.new("ScreenGui");probe.ScreenInsets=Device;probe.Name="_WardrobeProbeSpec";probe.Parent=parent
   local follower=Instance.new("ScreenGui");follower.ScreenInsets=Core;follower.Name="_WardrobeFollowerSpec";follower.Parent=parent
   task.wait()
   local live=0
   for _=1,4 do local w=Kit.compactInsets(probe.AbsoluteSize);if follower.ScreenInsets~=w then follower.ScreenInsets=w;live+=1 end;task.wait()end
   probe:Destroy();follower:Destroy()
   assert(live<=1,"live follower flipped "..live.." times")
  end)
  test("danger text is the lighter #FF8090 on results and 4.5:1 on raised",function()
   assert(Kit.Color.dangerText==Color3.fromHex("#FF8090"))
   local function lum(c)local function ch(v)return if v<=.03928 then v/12.92 else((v+.055)/1.055)^2.4 end;return .2126*ch(c.R)+.7152*ch(c.G)+.0722*ch(c.B)end
   local function contrast(a,b)local x,y=lum(a),lum(b);return(math.max(x,y)+.05)/(math.min(x,y)+.05)end
   for _,theme in ipairs(require(game.ReplicatedStorage.Shared.DeckThemes).Order)do
    local t=require(game.ReplicatedStorage.Shared.DeckThemes).ById[theme]
    assert(contrast(Kit.Color.dangerText,t.ui.raised)>=4.5,theme.." dangerText on raised")
   end
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return #cases.." passed: "..table.concat(cases," | ")
end
