-- Studio Client. Compact (phone landscape) deck screens, UI-SPEC-COMPACT-2026-11-12:
-- the breakpoint rule, the reference-size geometry, the quest drawer, and every
-- built screen at 568x320, 740x360, 844x390 and 932x430 (targets >= 44, nothing
-- interactive in the Roblox keep-out, no overlapping targets, text >= 12 that fits,
-- board aspect, Replay / Leave in the bottom corners).
-- Usage: require(PlayerScripts.Client.ZZSpecs.CompactPhone)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Screen=require(client.DeckScreen);local Kit=require(client.DeckKit)
 local Results=require(client.DeckResults);local Picker=require(client.DifficultyPicker)
 local Log=require(client.QuestLog);local Shop=require(client.FaceplateShop)
 local aspect=(11+.8)/(19+.8)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function same(r,x,y,w,h)return r.x==x and r.y==y and r.w==w and r.h==h end
 local sizes={Vector2.new(568,320),Vector2.new(740,360),Vector2.new(844,390),Vector2.new(932,430)}
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
 local ok,problem=pcall(function()
  test("breakpoint: landscape and (H < 500 or W < 1000) is Compact; desktop, the 1024x768 band and portrait are not",function()
   for _,size in ipairs({Vector2.new(568,320),Vector2.new(740,360),Vector2.new(844,390),Vector2.new(932,430),Vector2.new(999,600),Vector2.new(1400,499),Vector2.new(733,307)})do
    local g=Screen.resolve(size,aspect)
    assert(g.mode=="Compact"and g.phone and Kit.compactRule(size.X,size.Y),"compact "..tostring(size))
   end
   for _,pair in ipairs({{Vector2.new(1920,1080),"Regular"},{Vector2.new(1300,700),"Regular"},{Vector2.new(1024,768),"Small"},{Vector2.new(1000,500),"Small"}})do
    local g=Screen.resolve(pair[1],aspect)
    assert(g.mode==pair[2]and not g.phone and not Kit.compactRule(pair[1].X,pair[1].Y),"not compact "..tostring(pair[1]).." got "..g.mode)
   end
   -- Portrait / square never reach Compact (W < 1.2 H).
   assert(not Kit.compactRule(390,844)and not Kit.compactRule(600,520))
  end)
  test("geometry matches the spec tables at the four reference sizes",function()
   local want={
    [568]={board={193,8,181,304},L1=179,R0=388,D=88,score={12,60,167,44},next={388,8,52,44},eggs={446,8,58,44},dpad={16,224},handle={116,264,63,44},a={508,260},b={422,276},goalsTop=112},
    [740]={board={267,8,205,344},L1=253,R0=486,D=96,score={124,8,129,44},next={486,8,96,44},eggs={588,8,88,44},dpad={16,252},handle={124,304,129,44},a={676,296},b={586,316},goalsTop=60},
    [844]={board={310,8,223,374},L1=296,R0=547,D=104,score={124,8,102,44},chain={232,8,64,44},next={547,8,139,44},eggs={692,8,88,44},dpad={16,274},handle={132,334,164,44},a={776,322},b={682,346},goalsTop=60},
    [932]={board={342,8,247,414},L1=328,R0=603,D=104,score={126,8,132,44},chain={264,8,64,44},next={603,8,140,44},eggs={749,8,88,44},dpad={16,314},handle={132,374,196,44},a={864,362},b={770,386},goalsTop=60},
   }
   for _,size in ipairs(sizes)do
    local g=Screen.resolve(size,aspect,{kx=116,kh=58});local w=want[size.X]
    local function chk(r,t,name)assert(same(r,t[1],t[2],t[3],t[4]),string.format("%d %s: %d,%d,%dx%d",size.X,name,r.x,r.y,r.w,r.h))end
    chk(g.board,w.board,"board");chk(g.score,w.score,"score");chk(g.next,w.next,"next");chk(g.eggs,w.eggs,"eggs");chk(g.handle,w.handle,"handle")
    if w.chain then chk(g.chain,w.chain,"chain");assert(not g.chainInGoals)else assert(g.chain==nil and g.chainInGoals)end
    assert(g.L1==w.L1 and g.R0==w.R0 and g.D==w.D and g.goalsTop==w.goalsTop,size.X.." columns")
    assert(g.dpad.x==w.dpad[1]and g.dpad.y==w.dpad[2]and g.dpad.w==w.D,size.X.." d-pad")
    assert(g.a.X==w.a[1]and g.a.Y==w.a[2]and g.b.X==w.b[1]and g.b.Y==w.b[2],size.X.." A/B")
    -- Board keeps the simulation aspect within a pixel.
    assert(math.abs(g.board.w-g.board.h*aspect)<=.5+1e-6,size.X.." board aspect")
    assert(g.cw==math.floor((size.X-60)/3)and g.ch==size.Y-140 and g.actionY==size.Y-66,size.X.." sheet")
   end
  end)
  test("round HUD at each size: targets, keep-out, text, A/B under the right thumb",function()
   for _,size in ipairs(sizes)do
    local root=frame(size)
    local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true)
    s:setHud({score=2340,chain=3,goals={{text="Merge II in the centre",short="II centre",done=true,progress=2,target=2},{text="Make III on RIGHT",short="III RIGHT",progress=1,target=2},{text="Make a tier IV",short="Tier IV",progress=0,target=1}},
     daily={{title="Win 2 rounds",progress=2,target=2,done=true,ready=true},{title="Chain 4 merges",progress=3,target=4},{title="Tier IV on Hard",progress=0,target=1}},
     next={2,1,1},eggsLeft=14,budget=24,difficulty="Hard",multiplier="×1.5",winPays="9–12"})
    task.wait()
    local label=tostring(size)
    -- The d-pad halves are D/2 wide; with D >= 88 they stay >= 44.
    audit(root,label.." HUD",116,58)
    local a=s.buttons.A.hit.AbsolutePosition+s.buttons.A.hit.AbsoluteSize/2-root.AbsolutePosition
    assert(a.X>size.X*.75 and a.Y>size.Y*.6,label.." A under the right thumb")
    assert(s.lcd.AbsoluteSize.Y==size.Y-16,label.." board at full height")
    assert(s.hud.questDot.Visible,label.." ready dot on the handle")
    assert(s.hud.goalsEyebrow.Text=="GOALS 1/3",label.." goals header")
    root:Destroy()
   end
  end)
  test("quest drawer: opens over the left column only, closes on the close target and on back",function()
   local size=Vector2.new(844,390)
   local root=frame(size)
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true)
   s:setHud({score=0,goals={},daily={{title="Win 2 rounds",progress=2,target=2,done=true},{title="Chain 4 merges",progress=3,target=4}},next={1,1,1},eggsLeft=24,budget=24})
   local h=s.hud
   assert(not h.drawerBezel.Visible and not s.drawerOpen)
   assert(s:setDrawer(true)and h.drawerBezel.Visible and root.PocketDeck:GetAttribute("QuestDrawerOpen")==true)
   task.wait(.2)
   local d=h.drawer;local o=root.AbsolutePosition
   local dx,dy=d.AbsolutePosition.X-o.X,d.AbsolutePosition.Y-o.Y
   assert(dx==12 and dy==60 and d.AbsoluteSize.X==284 and d.AbsoluteSize.Y==318,"drawer rect "..dx..","..dy..","..tostring(d.AbsoluteSize))
   assert(dx+d.AbsoluteSize.X<=s.geometry.board.x-6,"drawer stays off the board")
   -- Covers the d-pad and the handle.
   local dp=s.dpad.AbsolutePosition-o
   assert(dp.Y>=60 and dp.Y+s.dpad.AbsoluteSize.Y<=378,"covers the d-pad")
   assert(h.daily[1].count.Text=="2/2"and h.daily[1].count.TextColor3==Kit.Color.stars and not h.daily[3].name.Visible,"rows from the snapshot")
   audit(root,"drawer",116,58,function(node)return node:IsDescendantOf(root.PocketDeck.CompactHUD.QuestHandle)or node.Name:find("^DPad")~=nil end)
   assert(s:closeDrawer()and not h.drawerBezel.Visible,"back closes it")
   assert(not s:closeDrawer(),"a second back falls through to leave")
   s:setDrawer(true);local close=d:FindFirstChild("Close")
   assert(close and close.AbsoluteSize.X>=44 and close.AbsoluteSize.Y>=44,"44 px close target")
   s:setDrawer(false);assert(not s.drawerOpen)
   -- A rebuild (rotation / resize) starts with the drawer shut.
   s:setDrawer(true);s:layout(Vector2.new(740,360),aspect,{kx=116,kh=58});assert(not s.drawerOpen and not s.hud.drawerBezel.Visible)
   root:Destroy()
  end)
  test("quest drawer closes by itself 6 s after the last touch",function()
   local size=Vector2.new(740,360)
   local root=frame(size)
   local s=Screen.new({parent=root,overlayParent=root,viewRoot=root});s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true)
   s:setHud({score=0,goals={},daily={},next={1,1,1},eggsLeft=24,budget=24})
   s:setDrawer(true);task.wait(3);s.drawerTouched=os.clock();task.wait(4)
   assert(s.drawerOpen,"a touch inside restarts the 6 s")
   task.wait(3);assert(not s.drawerOpen,"closed after 6 s idle")
   root:Destroy()
  end)
  test("menu sheets at each size: picker, results, quest log and shop",function()
   for _,size in ipairs(sizes)do
    local label=tostring(size)
    local root=frame(size)
    local s=Screen.new({parent=root,overlayParent=root,viewRoot=root})
    local pick=Picker.new(s:addOverlay("Picker",32),{})
    local log=Log.new(s:addOverlay("Log",34),{})
    s:layout(size,aspect,{kx=116,kh=58});s:setVisible(true)
    local res=Results.new(s.resultsContent,{})
    -- Picker.
    pick:show({selected="medium",pays={easy={5,6},medium={6,8},hard={9,12}},wallet=128,goal="Make two tier III eggs on RIGHT",questCount="1/3",questReady=true})
    task.wait()
    audit(pick.overlay.layer,label.." picker",116,58)
    local cw,ch=s.geometry.cw,s.geometry.ch
    local show=Picker.compactCard(cw,ch)
    assert(pick.cards[1].tidy.Visible==show.tidy and pick.cards[2].button.AbsoluteSize.X==cw,label.." picker cards")
    pick:hide()
    -- Results.
    res:show({outcome="clear",title="Creek crossing",difficulty="Hard",earned=12,total=12,balance=140,rows={{name="Round win",amount=8},{name="Tidy stack",amount=2},{name="Hard ×1.5",amount=2}},
     goals={{text="Merge II in the centre",short="II centre",done=true},{text="Make III on RIGHT",short="III RIGHT",done=true},{text="Make a tier IV",short="Tier IV"}},
     score=2340,best=2340,chain=4,newBest=true,level=3,questDone="Win 2 rounds",questCount="1/3"},s:view())
    task.wait(.3) -- past the 160 ms open rise
    audit(s.results,label.." results",116,58)
    local o=s.results.AbsolutePosition
    local leave=res.leave.AbsolutePosition-o;local replay=res.replay.AbsolutePosition-o
    assert(leave.X==20 and leave.Y==size.Y-66,label.." Leave bottom left")
    assert(replay.X+res.replay.AbsoluteSize.X==size.X-20 and replay.Y==size.Y-66,label.." Replay bottom right")
    assert(res.difficulty.AbsoluteSize.X==48 and res.difficulty:GetAttribute("AccessibleLabel")=="Change difficulty",label.." change difficulty")
    -- Focus order left to right, and the change-difficulty callback.
    local picked=0;res:on("picker",function()picked+=1 end)
    res.focus=1;res:move(-1);assert(res.focus==3,"left of Replay is Change difficulty");res:move(-1);assert(res.focus==4,"then the quest shortcut");res:move(-1);assert(res.focus==2)
    res.focus=3;res:confirm();res:confirm();assert(picked>=1,"Change difficulty opens the picker")
    res:hide()
    -- Quest log, all three tabs.
    log:show({day=10,week=2,resetIn=26000,weekResetIn=200000,rerollLeft=1,
     daily={{slot=1,id="a",title="Win 2 rounds",sub="Any difficulty",progress=2,target=2,reward=4,ready=true,pool="play"},{slot=2,id="b",title="Chain 4 merges",sub="In one round",progress=3,target=4,reward=4,pool="craft"},{slot=3,id="c",title="Make a tier IV on Hard",sub="Skill quest",progress=0,target=1,reward=4,canReroll=true,pool="skill"}},
     weekly={{slot=1,id="w1",title="Win 10 rounds",sub="This week",progress=4,target=10,reward=5,pool="play"},{slot=2,id="w2",title="Claim 9 dailies",sub="This week",progress=9,target=9,reward=5,ready=true,pool="craft"},{slot=3,id="w3",title="Clear 3 Hard rounds",sub="This week",progress=3,target=3,reward=5,claimed=true,pool="skill"}},
     bonus={reward=5},history={{d=10,title="Win 2 rounds",s=4},{d=9,title="Chain 4 merges",s=4,weekly=false},{d=9,title="Clear 3 Hard rounds",s=5,weekly=true}}},128,"daily")
    task.wait(.3)
    for _,tab in ipairs({"daily","weekly","history"})do
     log:setTab(tab);task.wait()
     audit(log.overlay.layer,label.." log "..tab,116,58)
    end
    local rh,g,tops=Log.compactRows(size.Y)
    assert(log.rows[2].row.Position.Y.Offset==tops[2]-64 and log.rows[1].row.AbsoluteSize.Y==rh,label.." row pitch")
    assert(log.footer.AbsoluteSize.Y==44 and log.footer.AbsolutePosition.Y-log.overlay.layer.AbsolutePosition.Y==size.Y-62,label.." pinned footer")
    log:hide()
    -- Faceplate shop.
    local host=frame(size);host.Name="ShopHost"
    local shop=Shop.new(host,{});shop:fit(size)
    shop:setContext({equipped="sherbet",wallet=128,facts={faceplates={}}});shop:open("sherbet");task.wait()
    local grid=Shop.compactGrid(size.X,size.Y)
    assert(shop.columns==grid.cols and shop.tiles[1].button.AbsoluteSize.X==grid.tileW and shop.tiles[1].button.AbsoluteSize.Y==64,label.." grid")
    audit(shop.root,label.." shop",116,58,function(node)return node:IsDescendantOf(shop.grid)and(node.AbsolutePosition.Y<shop.grid.AbsolutePosition.Y or node.AbsolutePosition.Y+node.AbsoluteSize.Y>shop.grid.AbsolutePosition.Y+shop.grid.AbsoluteSize.Y)end)
    local action=shop.action.AbsolutePosition-shop.root.AbsolutePosition
    assert(action.X+shop.action.AbsoluteSize.X==size.X-32 and action.Y+48==size.Y-18-12,label.." Buy / Equip pinned bottom right")
    host:Destroy();root:Destroy()
   end
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
 end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return #cases.." passed: "..table.concat(cases," | ")
end
