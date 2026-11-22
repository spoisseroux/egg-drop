-- Studio Client. QA 2026-11-13 Q5 machine hub (MachineHub): outside rounds the Pocket
-- menu is one hub with a tile per machine (Hatch eggs, Deck style, Companions) plus
-- Quests, the Collection book and Settings; in a round the deck keeps its pause menu
-- (PocketMenu: Resume, Restart round, Quit to garden, Settings). Pure rules (tiles,
-- locks, status lines, grid geometry, focus steps, keys), the built hub on desktop and
-- the 812 x 354 phone (house style: header tint, lipped tiles, Fredoka names, hint caps),
-- keyboard / controller focus, locked tiles before the first pet, open / back through
-- the callbacks, the shade stack and the slide back in; then the quest log's garden
-- host (QuestLogHost). Nothing is sent.
-- Usage: require(PlayerScripts.Client.ZZSpecs.MachineHub)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Hub=require(client.MachineHub)
 local Pocket=require(client.PocketMenu)
 local Kit=require(client.DeckKit)
 local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_MachineHubSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.IgnoreGuiInset=true;gui.Parent=parent
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local K=Enum.KeyCode
 local function inside(a,b)
  local ap,as,bp,bs=a.AbsolutePosition,a.AbsoluteSize,b.AbsolutePosition,b.AbsoluteSize
  return ap.X>=bp.X-1 and ap.Y>=bp.Y-1 and ap.X+as.X<=bp.X+bs.X+1 and ap.Y+as.Y<=bp.Y+bs.Y+1
 end
 local snapshot={nectar=128,dailyAvailable=true,quests={daily={{ready=true},{ready=false},{claimed=true,ready=true}},weekly={{ready=true}},bonusReady=false},
  book={claimable={"balls.25","eggs.25"}}}
 -- QA 2026-11-14 U2: a fuller snapshot for the progress chips and the tile art.
 local rich={nectar=40,stamps=10,dailyAvailable=true,
  quests={daily={{progress=2,target=2,ready=true},{progress=1,target=3},{claimed=true}},weekly={}},
  book={claimable={},pages={{id="balls",owned=3,total=10,ownedIds={}},{id="faceplates",owned=2,total=10,ownedIds={}},
   {id="wardrobe",owned=5,total=20,ownedIds={}},{id="toys",owned=1,total=4,ownedIds={}},{id="discoveries",owned=0,total=6,ownedIds={}}}}}
 local ok,problem=xpcall(function()
  test("pure: six tiles in order, the machines first, house icons and tints",function()
   local ids,icons={},{}
   for i,tile in ipairs(Hub.Tiles)do ids[i]=tile.id;icons[i]=tile.icon end
   assert(table.concat(ids,",")=="hatch,style,companions,quests,book,settings","tiles "..table.concat(ids,","))
   assert(table.concat(icons,",")=="egg,faceplate,paw,quests,book,settings")
   assert(Hub.Count==6 and Hub.Cols==3)
   for _,tile in ipairs(Hub.Tiles)do
    assert(UICopy.has(tile.name)and UICopy.has(tile.line),tile.id.." copy")
    if tile.tint then assert(Kit.tintColor(tile.tint),tile.id.." tint")end
   end
   assert(UICopy.get(Hub.Tiles[5].name)==UICopy.get("book.title"),"the Collection book tile")
   -- Pause (in a round) and hub (outside) are separate lists; only Settings is in both.
   local pause={};for _,item in ipairs(Pocket.Items)do pause[item.id]=true end
   -- (pause[id]==true): a missing entry is nil, and nil==false is false in Luau.
   for _,tile in ipairs(Hub.Tiles)do assert((pause[tile.id]==true)==(tile.id=="settings"),tile.id.." pause overlap")end
   assert(not pause.trials and not pause.book and not pause.hatch)
  end)
  test("pure: locks before the first pet, status lines with gold dots",function()
   for _,tile in ipairs(Hub.Tiles)do
    assert(Hub.locked(tile.id,0)==(tile.id~="settings"),tile.id.." lock on a fresh save")
    assert(not Hub.locked(tile.id,1),tile.id.." opens with a pet")
   end
   local ctx={owned=1,state=snapshot}
   -- QA v2 R3.8: today's stamp waits on the Quests tile now (claims show first).
   local s=Hub.status("hatch",ctx);assert(s.text==""and not s.dot,"no stamp on Hatch eggs")
   s=Hub.status("quests",{owned=1,state={dailyAvailable=true,quests={daily={},weekly={}}}})
   assert(s.text==UICopy.get("hub.status.stamp")and s.tone=="stars"and s.dot and not s.locked,"stamp ready on Quests")
   assert(Hub.questsReady(snapshot.quests)==2,"ready, not claimed: one daily and one weekly")
   s=Hub.status("quests",ctx);assert(s.text==UICopy.get("book.entry.claimMany",{count=2})and s.dot)
   s=Hub.status("book",ctx);assert(s.text=="2 TO CLAIM"and s.dot)
   assert(Hub.status("style",ctx).text==""and not Hub.status("settings",ctx).dot)
   s=Hub.status("book",{owned=0,state=snapshot});assert(s.locked and s.text==UICopy.get("hub.status.locked")and not s.dot)
   assert(not Hub.status("settings",{owned=0}).locked)
   assert(Hub.status("hatch",{owned=1,state={dailyAvailable=false}}).text=="")
   assert(Hub.questsReady({daily={},weekly={},bonusReady=true})==1 and Hub.questsReady(nil)==0)
  end)
  test("pure: 3 x 2 grid inside the panel / sheet, 44 px targets; focus steps clamp",function()
   for _,case in ipairs({{848,608,false},{812,294,true},{568,260,true},{932,370,true}})do
    local W,H,phone=case[1],case[2],case[3]
    local g=Hub.geometry(W,H,phone)
    assert(g.cols==3 and g.rows==2 and #g.tiles==6)
    local top=if phone then 64 else 84
    local bottom=if phone then H-Hub.PhoneBottomPad else 548
    assert(Hub.PhoneBottomPad>=20,"room under the last row (Spencer 2026-11-21)")
    for i,r in ipairs(g.tiles)do
     assert(r.w>=44 and r.h>=44,W.." tile "..i.." target")
     assert(r.x>=20 and r.x+r.w<=W-20 and r.y>=top and r.y+r.h<=bottom,W.." tile "..i.." inside")
    end
    assert(g.tiles[2].x-(g.tiles[1].x+g.tiles[1].w)>=8 and g.tiles[4].y-(g.tiles[1].y+g.tiles[1].h)>=8,W.." gaps hold the lip")
   end
   local d=Hub.geometry(848,608,false).tiles[1];assert(d.x==24 and d.y==84 and d.w==256 and d.h==224,"desktop tile 256 x 224 (round 3 shortens phone tiles only)")
   assert(Hub.step(1,1,0)==2 and Hub.step(3,1,0)==3 and Hub.step(1,0,1)==4 and Hub.step(6,0,1)==6 and Hub.step(4,-1,0)==4 and Hub.step(5,0,-1)==2)
   assert(Hub.keyAction(K.ButtonA)=="open"and Hub.keyAction(K.Return)=="open"and Hub.keyAction(K.ButtonB)=="back"and Hub.keyAction(K.Escape)=="back")
   assert(Hub.keyAction(K.M)=="back"and Hub.keyAction(K.DPadLeft)=="left"and Hub.keyAction(K.S)=="down"and Hub.keyAction(K.Q)==nil)
  end)
  test("U2 pure: progress chips (quests n/3, the stamp card, book %, owned counts)",function()
   local Stamp=require(game:GetService("ReplicatedStorage").Shared.StampCard)
   local done,total=Hub.questsDone(rich.quests);assert(done==2 and total==3,"ready and claimed count as done: "..done.."/"..total)
   done,total=Hub.questsDone(nil);assert(done==0 and total==0)
   local owned,all=Hub.bookCount(rich.book);assert(owned==11 and all==50,"whole book "..owned.."/"..all)
   owned,all=Hub.bookCount(rich.book,{"faceplates","balls"});assert(owned==5 and all==20)
   local ctx={owned=1,state=rich}
   local q=Hub.chips("quests",ctx)
   assert(#q==2 and q[1].text==UICopy.get("hub.chip.quests",{done=2,total=3})and q[1].kind=="plain","quests chip")
   assert(q[2].text==UICopy.get("hub.chip.stamp",{count=Stamp.onCard(10),total=Stamp.Length}),"stamp chip")
   local b=Hub.chips("book",ctx);assert(#b==1 and b[1].text==UICopy.get("hub.chip.book",{percent=22})and b[1].kind=="plain","book 22%")
   assert(Hub.chips("hatch",ctx)[1].text==UICopy.get("hub.chip.toys",{owned=1,total=4}))
   assert(Hub.chips("style",ctx)[1].text==UICopy.get("hub.chip.styles",{owned=5,total=20}))
   assert(Hub.chips("companions",ctx)[1].text==UICopy.get("hub.chip.outfits",{owned=5,total=20}))
   assert(#Hub.chips("settings",ctx)==0 and #Hub.chips("quests",{owned=0,state=rich})==0,"none on Settings, none while locked")
   assert(#Hub.chips("book",{owned=1,state={}})==0 and #Hub.chips("quests",{owned=1,state={}})==0,"no count, no chip")
   local full=Hub.chips("quests",{owned=1,state={quests={daily={{claimed=true},{ready=true}}}}})
   assert(full[1].kind=="gold","all of today's quests done reads gold")
   for _,key in ipairs({"hub.chip.quests","hub.chip.stamp","hub.chip.book","hub.chip.toys","hub.chip.styles","hub.chip.outfits","hub.week"})do assert(UICopy.has(key),key)end
  end)
  test("U2 pure: tile layout keeps the art well, text and chips inside the tile and apart",function()
   for _,case in ipairs({{256,224,false},{252,105,true},{170,88,true},{290,113,true},{252,70,true}})do
    local w,h,phone=case[1],case[2],case[3]
    local L=Hub.tileLayout(w,h,phone)
    local label=w.."x"..h
    assert(L.well.x>=0 and L.well.y>=0 and L.well.x+L.well.w<=w-8 and L.well.y+L.well.h<=h-8,label.." well inside")
    assert(L.well.w>=36 and L.well.h>=36,label.." well size")
    assert(L.name.x+L.name.w<=w and L.name.w>=40,label.." name")
    if phone then
     assert(L.name.x+L.name.w<=L.well.x and L.status.x+L.status.w<=L.well.x,label.." text left of the well")
     if L.line then assert(L.line.x+L.line.w<=L.well.x and L.line.y+L.line.h<=h,label.." line")end
     if L.chips then assert(L.chips.x+L.chips.w<=L.well.x and L.chips.y+L.chipH<=h-3,label.." chips")end
     if L.line and L.chips then assert(L.chips.y>=L.line.y+L.line.h,label.." chips under the line")end
    else
     assert(L.name.y>=L.well.y+L.well.h and L.line.y>=L.name.y+L.name.h,label.." text under the well")
     assert(L.chips.y>=L.line.y+L.line.h and L.status.y>=L.chips.y+L.chipH and L.status.y+L.status.h<=h,label.." chips, then status")
     assert(L.well.x>=L.pad+L.disc+8,label.." well beside the disc")
    end
   end
   assert(Hub.tileLayout(252,105,true).line and Hub.tileLayout(252,105,true).chips,"812 x 354 shows the line and the chips")
   assert(Hub.tileLayout(170,88,true).chips and not Hub.tileLayout(170,88,true).line,"a short tile keeps the chips")
  end)
  for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354)})do
   test(tostring(size).." U2 built hub: art wells, chips and the weekly shelf highlight",function()
    local Deal=require(client.ShelfDeal)
    local Themes=require(game:GetService("ReplicatedStorage").Shared.DeckThemes)
    local plateId;for id in pairs(Themes.ById)do if plateId==nil or id<plateId then plateId=id end end
    local before=Deal.override
    Deal.override={slots=function(week)return if week==7 then {{kind="faceplate",id=plateId,full=40,price=32}}else {}end,
     price=function()return nil end,weekOfDay=function()return 7 end}
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local hub=Hub.new(host,{})
    local good,why=xpcall(function()
     local state=table.clone(rich);state.shelfWeek=7
     assert(hub:open({owned=1,wallet=40,state=state}));settle()
     for i,entry in ipairs(hub.tileViews)do
      local well=entry.button:FindFirstChild("ArtWell")
      assert(well and inside(well,entry.button),"tile "..i.." art well inside the tile")
      local art=well:FindFirstChild("Art")
      assert(art and art:GetAttribute("TileId")==entry.id and art:GetAttribute("Locked")==false,"tile "..i.." art")
      assert(#art:GetChildren()>0,"tile "..i.." art draws something")
      assert(well:FindFirstChild("Sheen"),"tile "..i.." glass sheen")
      assert(entry.button:FindFirstChild("Go")and inside(entry.button.Go,entry.button),"tile "..i.." chevron badge")
      for _,chip in ipairs(entry.chips)do
       if chip.root.Visible then
        assert(inside(chip.root,entry.button)and chip.label.TextSize>=12,"tile "..i.." chip inside")
        assert(chip.root.AbsolutePosition.X+chip.root.AbsoluteSize.X<=(if hub.view then well.AbsolutePosition.X else entry.button.AbsolutePosition.X+entry.button.AbsoluteSize.X)+1,"tile "..i.." chip clear of the well")
       end
      end
      assert(entry.week.root.Visible==(entry.id=="style"),"tile "..i.." week sticker only on the shelf tile")
      assert(entry.button:GetAttribute("Shelf")==(entry.id=="style"))
     end
     local seam=hub.tileViews[1].button:FindFirstChild("Seam")
     if seam then assert(seam.Visible==(hub.view==nil),"seams only on tall (desktop) cards")end
     assert(hub.tileViews[2].well.Art:GetAttribute("Shows")=="plate:"..plateId,"Deck style shows this week's shelf faceplate")
     assert(hub.tileViews[2].wellStroke.Thickness==2 and hub.tileViews[1].wellStroke.Thickness==1,"gold rim on the shelf tile only")
     assert(string.find(hub.tileViews[4].button:GetAttribute("Chips"),string.upper(UICopy.get("hub.chip.quests",{done=2,total=3})),1,true),"quests chip shown: "..tostring(hub.tileViews[4].button:GetAttribute("Chips")))
     assert(string.find(hub.tileViews[5].button:GetAttribute("Chips"),"22%",1,true),"book chip shown")
     assert(hub.tileViews[6].button:GetAttribute("Chips")=="","no chip on Settings")
     -- A snapshot that moves nothing keeps the same art instance; a new stamp redraws Quests only.
     local questArt,bookArt=hub.tileViews[4].well.Art,hub.tileViews[5].well.Art
     hub:setContext({state=state});assert(hub.tileViews[4].well.Art==questArt and hub.tileViews[5].well.Art==bookArt,"art kept")
     local next=table.clone(state);next.stamps=11
     hub:setContext({state=next});settle()
     assert(hub.tileViews[4].well.Art~=questArt and hub.tileViews[5].well.Art==bookArt,"only the stamp card redraws")
     -- Locked (no pet yet): the art is the dimmed icon, no chips, no sticker.
     hub:close("spec");hub:open({owned=0,wallet=0,state=state});settle()
     assert(hub.tileViews[1].well.Art:GetAttribute("Locked")==true and hub.tileViews[1].well.Art:GetAttribute("Shows")=="icon")
     assert(hub.tileViews[2].button:GetAttribute("Chips")==""and not hub.tileViews[2].week.root.Visible,"locked: no chips, no sticker")
     assert(hub.tileViews[6].well.Art:GetAttribute("Locked")==false,"Settings keeps its sliders")
    end,function(e)return tostring(e).." | "..debug.traceback()end)
    Deal.override=before
    hub:destroy();host:Destroy()
    if not good then error(why,0)end
   end)
  end
  test("QA v775 note 9: pure motion rules for the tile art",function()
   local HubArt=require(client.MachineHubArt)
   for _,id in ipairs({"hatch","style","companions","book"})do assert(HubArt.Animated[id],id.." moves")end
   assert(not HubArt.Animated.quests and not HubArt.Animated.settings,"only the four machine tiles move")
   -- The mini deck's ball: starts at the top, lands, bounces once, rests, fades before the loop.
   local y0,a0,p0=HubArt.deckBall(0);assert(y0==0 and a0==0 and p0==0)
   local last=-1
   for step=1,34 do local y=HubArt.deckBall(step/100);assert(y>=last and y<=1,"falls");last=y end
   local yb=HubArt.deckBall(.42);assert(yb<1 and yb>.7,"one small bounce")
   local yr,ar=HubArt.deckBall(.7);assert(yr==1 and ar==1,"rests on the floor")
   local _,af=HubArt.deckBall(.99);assert(af<.1,"fades out before it loops")
   local _,_,press=HubArt.deckBall(.05);assert(press>.9,"A dips as the ball drops")
   for step=0,100 do local y,alpha,dip=HubArt.deckBall(step/100);assert(y>=0 and y<=1 and alpha>=0 and alpha<=1 and dip>=0 and dip<=1)end
   -- The wave clock: nothing for the first half second, then one wave every WaveEvery.
   assert(HubArt.waveAt(10.2,10,.5)==nil and HubArt.waveAt(10.6,10,.5)==10.5)
   assert(math.abs(HubArt.waveAt(10.5+HubArt.WaveEvery+.1,10,.5)-(10.5+HubArt.WaveEvery))<1e-9)
   local Rules=require(game:GetService("ReplicatedStorage").Shared.PetHelloRules)
   assert(HubArt.WaveEvery>Rules.Duration+1,"a rest between waves")
   assert(HubArt.EggTurn>0 and HubArt.EggTurn<=1,"the eggs turn slowly")
  end)
  for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(750,344)})do
   test(tostring(size).." note 9 built hub: tiles move only while the hub is open and on top; one viewport a tile; Reduced Effects stands still",function()
    local HubArt=require(client.MachineHubArt);local Clock=require(client.PetPeek)
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local reducedNow=false
    local hub=Hub.new(host,{reduced=function()return reducedNow end})
    -- The Companions tile pictures the player's own pet: give this spec one.
    local Pets=require(game:GetService("ReplicatedStorage").Shared.PetCatalog)
    local source=Clock.getSource()
    Clock.setSource(function()return Pets.collection[1].id,{}end)
    local good,why=xpcall(function()
     assert(hub:open({owned=1,wallet=40,state=rich}));settle()
     assert(hub.tileViews[3].art:GetAttribute("Portrait")=="3d","Companions shows the pet in 3D")
     local osReduced=Kit.reduced()
     for _,entry in ipairs(hub.tileViews)do
      assert(entry.art and entry.art.Parent==entry.well,"tile "..entry.id.." keeps its art root")
      assert(HubArt.animated(entry.art)==(HubArt.Animated[entry.id]==true),"tile "..entry.id.." motion")
      local viewports=0
      for _,node in ipairs(entry.art:GetDescendants())do if node:IsA("ViewportFrame")then viewports+=1 end end
      assert(viewports<=1,"tile "..entry.id.." has "..viewports.." viewports")
     end
     assert(hub:motionWanted()==not osReduced and hub.root:GetAttribute("TileMotion")==not osReduced)
     assert(Clock.isSubscribed(hub.motionKey)==not osReduced,"steps while open")
     if not osReduced then
      -- The art really moves: the mini deck rocks and its ball travels.
      local deck=hub.tileViews[2].art:FindFirstChild("MiniDeck");local ball=deck and deck:FindFirstChild("DemoBall",true)
      if deck and ball then
       local seen={}
       for _=1,24 do settle();seen[ball.Position.Y.Offset]=true end
       local n=0;for _ in pairs(seen)do n+=1 end
       assert(n>=2,"the demo ball never moved")
      end
      -- Covered by a machine's screen: paused. Uncovered: running again.
      hub:setCovered(true);assert(not Clock.isSubscribed(hub.motionKey)and hub.root:GetAttribute("TileMotion")==false,"paused while covered")
      hub:setCovered(false);assert(Clock.isSubscribed(hub.motionKey),"resumes on top")
      -- The game's Reduced Effects switched on while open: it stops on the next frame, on the resting pose.
      reducedNow=true;settle()
      assert(not Clock.isSubscribed(hub.motionKey)and not hub:motionWanted(),"Reduced Effects stops the motion")
      if deck then assert(deck.Rotation==0,"the deck rests level")end
      hub:close("spec");hub:open({owned=1,wallet=40,state=rich});settle()
      assert(not Clock.isSubscribed(hub.motionKey),"Reduced Effects: never starts")
      reducedNow=false;hub:close("spec");hub:open({owned=1,wallet=40,state=rich});settle()
      assert(Clock.isSubscribed(hub.motionKey))
     end
     hub:close("spec");assert(not Clock.isSubscribed(hub.motionKey)and hub.root:GetAttribute("TileMotion")==false,"paused when the menu closes")
     -- Locked tiles (no pet yet) show the dimmed icon and nothing moves in them.
     hub:open({owned=0,wallet=0,state=rich});settle()
     for _,entry in ipairs(hub.tileViews)do if entry.id~="settings"then assert(not HubArt.animated(entry.art),"locked "..entry.id.." stands still")end end
    end,function(e)return tostring(e).." | "..debug.traceback()end)
    Clock.setSource(source)
    hub:destroy();host:Destroy()
    assert(not Clock.isSubscribed(hub.motionKey),"nothing left running after destroy")
    if not good then error(why,0)end
   end)
  end
  for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354)})do
   test(tostring(size).." built hub: house style, focus, opens through the caller, Back closes",function()
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local opened,locked,closed={},{},{}
    local hub=Hub.new(host,{open=function(id)table.insert(opened,id);return true end,locked=function(id)table.insert(locked,id)end,
     closed=function(reason)table.insert(closed,reason)end})
    local depth=Kit.shadeDepth()
    assert(hub:open({owned=1,wallet=128,state=snapshot}));settle()
    assert(hub:isOpen()and hub.shade.Visible and Kit.shadeDepth()==depth+1 and Kit.dimmingShades()<=1,"one shade in the stack")
    local phone=size.X<1000
    assert(hub.root:GetAttribute("Layout")==(if phone then "phone"else "regular"))
    assert(#hub.tileViews==6 and hub.root:GetAttribute("FocusedTile")=="hatch","opens on Hatch eggs")
    -- House style: the shared header with its tint, lipped tiles, Fredoka names, hint caps (desktop).
    assert(hub.header.title.Text==UICopy.get("hub.title")and hub.header.root:GetAttribute("Tint")~=nil and hub.header.wallet~=nil)
    for i,entry in ipairs(hub.tileViews)do
     assert(entry.button:GetAttribute("KitTile")==true and entry.button:GetAttribute("KitLip")==(if phone then Kit.Lip.compact else Kit.Lip.tile),"tile "..i.." lip")
     assert(entry.name:GetAttribute("KitRole")=="Name","tile "..i.." name role")
     assert(entry.button.AbsoluteSize.Y>=44 and entry.button.AbsoluteSize.X>=44,"tile "..i.." target")
     assert(inside(entry.button,hub.root),"tile "..i.." inside the panel")
     assert(not entry.button.Selectable,"the hub owns focus, not native selection")
    end
    for _,node in ipairs(hub.root:GetDescendants())do
     -- (Hint caps are glyphs drawn at the Kit's cap size, as on every screen.)
     if node:IsA("TextLabel")and node.Visible and node.Text~=""and not node:FindFirstAncestor("Hints")then assert(node.TextSize>=12,"text under 12 px: "..node:GetFullName())end
    end
    assert((hub.content:FindFirstChild("Hints")~=nil)==not phone,"hint caps on desktop only")
    -- Status: two quests (and the stamp) and two book milestones wait (gold dots); Hatch eggs no longer carries the stamp.
    assert(not hub.tileViews[1].dot.Visible and hub.tileViews[4].dot.Visible and hub.tileViews[5].dot.Visible and not hub.tileViews[2].dot.Visible)
    -- Keyboard / controller focus on the 3 x 2 grid.
    hub:input(K.Right);assert(hub.root:GetAttribute("FocusedTile")=="style")
    hub:input(K.D);assert(hub.root:GetAttribute("FocusedTile")=="companions")
    hub:input(K.Right);assert(hub.root:GetAttribute("FocusedTile")=="companions","stays at the edge")
    hub:input(K.DPadDown);assert(hub.root:GetAttribute("FocusedTile")=="settings")
    hub:input(K.ButtonA);assert(opened[1]=="settings","ButtonA opens the focused tile")
    hub:input(K.A);hub:input(K.A);assert(hub.root:GetAttribute("FocusedTile")=="quests","A on the keyboard moves left")
    hub:input(K.Return);assert(opened[2]=="quests")
    assert(hub.ring.target==hub.tileViews[4].button and hub.ring.root.Visible==require(client.DeckKit).lastInputGamepad(),"the focus ring sits on Quests (drawn for a gamepad only)")
    -- A tap focuses and opens in one go (the tile's Activated handler).
    hub:focusTile(5);hub:act();assert(opened[3]=="book")
    -- Back closes; the shade leaves the stack.
    hub:input(K.ButtonB);assert(not hub:isOpen()and not hub.shade.Visible and closed[1]=="back"and Kit.shadeDepth()==depth)
    -- Locked before the first pet: focus still lands, A says why, Settings still opens.
    table.clear(opened)
    hub:open({owned=0,wallet=0,state={}});settle()
    assert(hub.tileViews[1].button:GetAttribute("Locked")==true and hub.tileViews[6].button:GetAttribute("Locked")==false)
    assert(hub.tileViews[1].status.Text==UICopy.get("hub.status.locked")and hub.tileViews[1].line.Text==UICopy.get("menu.subtitle.locked"))
    hub:focusTile(1);hub:input(K.Return);assert(#opened==0 and locked[1]=="hatch","a locked tile says why instead of opening")
    hub:input(K.S);hub:input(K.Right);hub:input(K.Right);assert(hub.root:GetAttribute("FocusedTile")=="settings")
    hub:input(K.Return);assert(opened[1]=="settings","Settings opens on a fresh save")
    -- Back from a machine: reopen on its tile, sliding in from the left.
    hub:close("machine");hub:open({owned=1,state=snapshot},{focus="book",slideFrom=-Kit.SlideOffset});settle()
    assert(hub.root:GetAttribute("FocusedTile")=="book"and hub:isOpen())
    -- Old garden-menu callers: activate("close"), update(snapshot), setSaveNotice.
    assert(hub:update({nectar=7,book={claimable={}}})and not hub.tileViews[5].dot.Visible)
    assert(hub:setSaveNotice({short="Saving…"})and hub.header.title.Text=="Saving…");hub:setSaveNotice(nil)
    assert(hub.header.title.Text==UICopy.get("hub.title"))
    assert(hub:activate("close")and not hub:isOpen()and closed[#closed]=="back")
    assert(hub:getControllerFocus()==nil,"no native selection owner")
    hub:destroy();host:Destroy()
   end)
  end
  test("covered by a screen opened over it: the panel hides, then slides back",function()
   local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(1920,1080);host.Parent=gui
   local hub=Hub.new(host,{})
   hub:open({owned=1,state=snapshot});settle()
   local other=Kit.modalShade(host,"OtherShade",40);local owner={}
   Kit.shadeOpen(owner,other);settle()
   assert(hub.covered and not hub.root.Visible and hub.shade:GetAttribute("ShadeCovered")==true,"covered")
   Kit.shadeClose(owner);settle()
   assert(not hub.covered and hub.root.Visible and hub:isOpen(),"uncovered")
   hub:destroy();other:Destroy();host:Destroy()
  end)
  test("quest log garden host: desktop LCD glass and the phone sheet, shade with the layer",function()
   local QuestHost=require(client.QuestLogHost);local Log=require(client.QuestLog)
   local l=QuestHost.layoutFor(Vector2.new(1920,1080),58);assert(not l.phone and math.abs(l.scale-math.min(1.2,(1920-24)/848,(1080-24)/608))<1e-6)
   l=QuestHost.layoutFor(Vector2.new(812,354),58);assert(l.phone and l.W==812 and l.H==294 and l.top==60 and l.hx==24)
   for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354)})do
    local root=Instance.new("Frame");root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(size.X,size.Y);root.Parent=gui
    local host=QuestHost.new(root);local claims={}
    local log=Log.new(host.overlay,{claim=function(...)table.insert(claims,{...})end})
    local depth=Kit.shadeDepth()
    local quests={day="1",week="1",rerollLeft=1,daily={{slot=1,id="a",title="Win 2 rounds",progress=2,target=2,ready=true,reward=4}},weekly={},history={}}
    log:show(quests,10,"daily");settle()
    local layer=host.overlay.layer
    assert(log.visible and layer.Visible and host.shade.Visible and Kit.shadeDepth()==depth+1)
    assert(layer:GetAttribute("Layout")==(if size.X<1000 then "phone"else "regular"))
    assert(math.abs(host.shade.BackgroundTransparency-Kit.ShadeAlpha)<1e-4,"R3.1: the quest log dims on phones too")
    assert(log.header and log.header.back and log.header.help,"R3.4: back arrow and ? on the quest log")
    assert(inside(layer,root),"the log stays on screen")
    log:hide();settle()
    assert(not layer.Visible and not host.shade.Visible and Kit.shadeDepth()==depth,"the shade leaves with the log")
    host:destroy();root:Destroy()
   end
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
