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
  -- Overlap is judged on what can be touched: each target clipped to its scrolling lists
  -- (a row scrolled under the pinned footer is not on screen there).
  local function clipped(node)
   local x0,y0=node.AbsolutePosition.X,node.AbsolutePosition.Y
   local x1,y1=x0+node.AbsoluteSize.X,y0+node.AbsoluteSize.Y
   local p=node.Parent
   while p and p~=root do
    if p:IsA("ScrollingFrame")or(p:IsA("GuiObject")and p.ClipsDescendants)then
     x0=math.max(x0,p.AbsolutePosition.X);y0=math.max(y0,p.AbsolutePosition.Y)
     x1=math.min(x1,p.AbsolutePosition.X+p.AbsoluteSize.X);y1=math.min(y1,p.AbsolutePosition.Y+p.AbsoluteSize.Y)
    end
    p=p.Parent
   end
   return Vector2.new(x0,y0),Vector2.new(math.max(0,x1-x0),math.max(0,y1-y0))
  end
  for i=1,#targets do for j=i+1,#targets do
   local a,b=targets[i],targets[j]
   if not a:IsDescendantOf(b)and not b:IsDescendantOf(a)then
    local ap,as=clipped(a);local bp,bs=clipped(b)
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
    [844]={H=390,layout="wide",board={329,68,185,310},score={132,68,117,44},chain={257,68,64,44},goals={132,120,189,132},quests=nil,handle={132,334,189,44},next={522,68,190,64},eggs={522,140,190,44},difficulty={522,192,190,44},winPays={522,244,190,44},controls=nil,dpad={18,154,88,88},dpadLeft={18,154,44,88},dpadRight={62,154,44,88},menu={26,346,72,28},menuHit={20,338,84,44},a={782,191},aHit={732,141,100,100},wordmark={14,64,96,37},mg=40,cw=238,pocketCols=1,pocketFirst={272,115,300,44},pocketLast={272,323,300,44}},
    [740]={H=360,layout="wide",board={286,68,167,280},score={120,68,86,44},chain={214,68,64,44},goals={120,120,158,132},quests=nil,handle={120,304,158,44},next={461,68,159,64},eggs={461,140,159,44},difficulty={461,192,159,44},winPays={461,244,159,44},controls=nil,dpad={16,143,80,80},dpadLeft={12,143,44,80},dpadRight={56,143,44,80},menu={20,316,72,28},menuHit={14,308,84,44},a={684,176},aHit={639,131,90,90},wordmark={14,64,84,33},mg=24,cw=214,pocketCols=2,pocketFirst={146,152,220,44},pocketLast={374,204,220,44}},
    [932]={H=430,layout="wide",board={361,68,209,350},score={132,68,149,44},chain={289,68,64,44},goals={132,120,221,132},quests={132,278,221,140},handle=nil,next={578,68,222,64},eggs={578,140,222,44},difficulty={578,192,222,44},winPays={578,244,222,44},controls={578,304,222,114},dpad={18,174,88,88},dpadLeft={18,174,44,88},dpadRight={62,174,44,88},menu={26,386,72,28},menuHit={20,378,84,44},a={870,211},aHit={820,161,100,100},wordmark={14,64,96,37},mg=40,cw=268,pocketCols=1,pocketFirst={316,135,300,44},pocketLast={316,343,300,44}},
    [568]={H=320,layout="narrow",board={212,68,143,240},score={106,120,98,44},chain={106,68,98,44},goals={106,172,98,108},quests=nil,handle={106,264,98,44},next={363,68,99,44},eggs={363,120,99,44},difficulty={363,172,99,44},winPays={363,224,99,44},controls=nil,dpad={15,129,68,68},dpadLeft={5,129,44,68},dpadRight={49,129,44,68},menu={13,276,72,28},menuHit={7,268,84,44},a={519,157},aHit={480,118,78,78},wordmark={14,64,70,27},mg=6,cw=169,pocketCols=2,pocketFirst={115,132,165,44},pocketLast={288,184,165,44}},
    [667]={H=375,layout="narrow",board={245,68,176,295},score={120,120,117,44},chain={120,68,117,44},goals={120,172,117,132},quests=nil,handle={120,319,117,44},next={429,68,118,64},eggs={429,140,118,44},difficulty={429,192,118,44},winPays={429,244,118,44},controls=nil,dpad={16,150,80,80},dpadLeft={12,150,44,80},dpadRight={56,150,44,80},menu={20,331,72,28},menuHit={14,323,84,44},a={611,184},aHit={566,139,90,90},wordmark={14,64,84,33},mg=6,cw=202,pocketCols=2,pocketFirst={129,159,200,44},pocketLast={337,211,200,44}},
   }
   for _,size in ipairs(sizes)do
    local w=want[size.X];local W,H=size.X,size.Y
    local g=Screen.resolve(size,aspect,{kx=116,kh=58})
    assert(g.layout==w.layout,W.." layout "..tostring(g.layout))
    for _,name in ipairs({"board","score","chain","goals","quests","handle","next","eggs","difficulty","winPays","controls","dpad","dpadLeft","dpadRight","menu","menuHit","aHit","wordmark"})do
     assert(same(g[name],w[name]),string.format("%d %s: %s",W,name,show(g[name])))
    end
    assert(g.a.X==w.a[1]and g.a.Y==w.a[2],W.." A centre")
    assert(g.mg==w.mg and g.cw==w.cw and g.ch==H-g.top-140 and g.actionY==H-g.top-66,W.." sheet")
    assert(g.pocket.cols==w.pocketCols and same(g.pocket.items[1],w.pocketFirst)and same(g.pocket.items[5],w.pocketLast),W.." pocket "..show(g.pocket.items[1]))
    -- Structure: 4 px of plate above and below the glass; every card and the board in the screen;
    -- the d-pad, MENU, back and A on the shoulders; the board H - 24 high at the sim aspect.
    -- QA 2026-11-12: the glass starts 2 px under the Roblox controls (kh 58).
    assert(g.top==60 and g.glass.y==g.top and g.glass.y+g.glass.h==H-4 and g.glass.x==g.SW and g.glass.x+g.glass.w==W-g.SW,W.." glass rims")
    local screen={x=g.x0,y=g.y0,w=g.LW,h=g.LH}
    for _,name in ipairs({"board","score","chain","goals","quests","handle","next","eggs","difficulty","winPays","controls"})do
     if g[name]then assert(inside(g[name],screen),W.." "..name.." outside the screen")end
     if g[name]then assert(not(g[name].x<116 and g[name].y<58),W.." "..name.." in the keep-out")end
    end
    for _,name in ipairs({"dpad","menu","back"})do assert(apart(g[name],g.glass),W.." "..name.." on the glass")end
    assert(apart({x=g.a.X-g.A/2,y=g.a.Y-g.A/2,w=g.A,h=g.A},g.glass),W.." A on the glass")
    assert(g.board.h==H-g.top-20 and math.abs(g.board.w-g.board.h*aspect)<=.5+1e-6,W.." board height and aspect")
    assert(g.board.x-g.x0==g.x1-(g.board.x+g.board.w)or math.abs((g.board.x-g.x0)-(g.x1-g.board.x-g.board.w))<=1,W.." board centred")
    assert(g.quests==nil or g.layout=="wide",W.." quests card only in two text columns")
    assert(g.quests~=nil or g.handle~=nil,W.." a quests route on screen")
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
    assert(s.lcd.AbsoluteSize.Y==size.Y-80,label.." board at H - 80 (under the Roblox controls)")
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
    -- Keyboard: three rows; B is Items in a round (BUILD-PLAN 2026-11-13, leaving is MENU / back arrow).
    if s.hud.controls and #s.hud.controls>=3 then
     local data=table.clone(hudData);data.input="Keyboard";s:setHud(data);task.wait()
     assert(s.hud.controls[3].text.Text=="Items",label.." keyboard B row is Items")
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
  test("Pocket Menu on a fresh save: locked rows take focus and say why (QA 2026-11-12)",function()
   local size=Vector2.new(844,390);local root=frame(size)
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root})
   local calls,locked={},{}
   local function cb(id)return function()table.insert(calls,id)end end
   local menu=Pocket.new(s:addOverlay("Pocket",36,{lcd=true}),{resume=cb("resume"),restart=cb("restart"),quit=cb("quit"),hatch=cb("hatch"),customize=cb("customize"),
    locked=function(id,state)table.insert(locked,id..":"..tostring(state.locked))end})
   s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true)
   menu:open({empty=true,locked=true,canRestart=false,canQuit=false,canHatch=false,canCustomize=false});task.wait(.3)
   assert(menu.subtitle.Text==require(game:GetService("ReplicatedStorage").Shared.UICopy).get("menu.subtitle.locked"),"subtitle explains the lock")
   menu:move(0,1);assert(menu.focusIndex==2,"down moves onto a locked row");menu:move(0,1);menu:move(0,1);assert(menu.focusIndex==4)
   menu:confirm();assert(#calls==0 and locked[1]=="hatch:true","a locked row reports why instead of acting")
   assert(menu.buttons[4].Active and menu.buttons[4].Interactable,"locked rows still take taps")
   menu:move(0,-3);menu:confirm();assert(calls[1]=="resume","Resume still works")
   root:Destroy()
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
    -- Sheets start 60 px down, under the Roblox controls (QA 2026-11-12).
    local rh,_,tops=Log.compactRows(size.Y-60)
    assert(log.rows[2].row.Position.Y.Offset==tops[2]-64 and log.rows[1].row.AbsoluteSize.Y==rh,label.." row pitch")
    assert(log.footer.AbsoluteSize.Y==44 and log.footer.AbsolutePosition.Y-log.overlay.layer.AbsolutePosition.Y==size.Y-62,label.." pinned footer")
    assert(log.footer.AbsolutePosition.X-log.overlay.layer.AbsolutePosition.X==mg+14,label.." log body edge at mg + 14")
    log:hide()
    local host=frame(size);host.Name="ShopHost"
    local shop=Shop.new(host,{});shop:fit(size)
    shop:setContext({equipped="sherbet",wallet=128,facts={faceplates={}}});shop:open("sherbet");task.wait()
    local grid=Shop.compactGrid(size.X-2*off,size.Y-60)
    assert(shop.columns==grid.cols and shop.tiles[1].button.AbsoluteSize.X==grid.tileW and shop.tiles[1].button.AbsoluteSize.Y==64,label.." grid")
    assert(shop.root.AbsolutePosition.Y-host.AbsolutePosition.Y==60,label.." shop sheet under the Roblox controls")
    audit(shop.root,label.." shop",0,0,function(node)return node:IsDescendantOf(shop.grid)and(node.AbsolutePosition.Y<shop.grid.AbsolutePosition.Y or node.AbsolutePosition.Y+node.AbsoluteSize.Y>shop.grid.AbsolutePosition.Y+shop.grid.AbsoluteSize.Y)end)
    local action=shop.action.AbsolutePosition-host.AbsolutePosition
    assert(action.X+shop.action.AbsoluteSize.X==size.X-off-32 and action.Y+48==size.Y-18-12,label.." Buy / Equip pinned bottom right")
    -- Deck style (redesign 0.1 / 4): shared header, 36 capsule and circle on one centre
    -- line, 44 hit; the icon tab row at y 64 over the grid at y 112; no ghost button.
    local top=shop.root.AbsolutePosition
    local disc,wallet=shop.backArrow.disc,shop.wallet.root
    assert(disc.AbsoluteSize.Y==36 and wallet.AbsoluteSize.Y==36 and shop.backArrow.root.AbsoluteSize==Vector2.new(44,44),label.." header heights")
    assert(math.abs((disc.AbsolutePosition.Y+18)-(wallet.AbsolutePosition.Y+18))<=.5 and math.abs(disc.AbsolutePosition.Y+18-top.Y-34)<=.5,label.." header centre y 34")
    assert(math.abs(disc.AbsolutePosition.X+36-(top.X+shop.root.AbsoluteSize.X-20))<=.5,label.." back right edge at W - 20")
    assert(shop.title.AbsolutePosition.X+shop.title.AbsoluteSize.X<=wallet.AbsolutePosition.X-12+.5,label.." title clear of the capsule")
    assert(shop.tabs.root.AbsolutePosition.Y-top.Y==64 and shop.grid.AbsolutePosition.Y-top.Y==112,label.." tab row over the grid")
    for _,node in ipairs(shop.root:GetDescendants())do assert(not(node:IsA("TextButton")and node.Name=="Backgrounds"),label.." ghost Backgrounds button")end
    -- The Backgrounds tab: same sheet, same pane slot, Use pinned bottom right.
    shop:setTab(2);task.wait(.25) -- let the 90 ms tab settle finish
    local backs=shop.backgrounds
    assert(shop.tab==2 and backs.body.Visible and not shop.plates.Visible,label.." backgrounds tab")
    audit(shop.root,label.." backgrounds",0,0,function(node)return node:IsDescendantOf(backs.grid)and(node.AbsolutePosition.Y<backs.grid.AbsolutePosition.Y or node.AbsolutePosition.Y+node.AbsoluteSize.Y>backs.grid.AbsolutePosition.Y+backs.grid.AbsoluteSize.Y)end)
    assert(backs.pane.AbsolutePosition==shop.action.Parent.AbsolutePosition and backs.grid.AbsolutePosition.Y-top.Y==112,label.." backgrounds share the pane and grid slots")
    shop:close()
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
