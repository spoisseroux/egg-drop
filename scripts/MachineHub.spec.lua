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
   local s=Hub.status("hatch",ctx);assert(s.text==UICopy.get("hub.status.stamp")and s.tone=="stars"and s.dot and not s.locked)
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
    local bottom=if phone then H-12 else 548
    for i,r in ipairs(g.tiles)do
     assert(r.w>=44 and r.h>=44,W.." tile "..i.." target")
     assert(r.x>=20 and r.x+r.w<=W-20 and r.y>=top and r.y+r.h<=bottom,W.." tile "..i.." inside")
    end
    assert(g.tiles[2].x-(g.tiles[1].x+g.tiles[1].w)>=8 and g.tiles[4].y-(g.tiles[1].y+g.tiles[1].h)>=8,W.." gaps hold the lip")
   end
   local d=Hub.geometry(848,608,false).tiles[1];assert(d.x==24 and d.y==84 and d.w==256 and d.h==224,"desktop tile 256 x 224")
   assert(Hub.step(1,1,0)==2 and Hub.step(3,1,0)==3 and Hub.step(1,0,1)==4 and Hub.step(6,0,1)==6 and Hub.step(4,-1,0)==4 and Hub.step(5,0,-1)==2)
   assert(Hub.keyAction(K.ButtonA)=="open"and Hub.keyAction(K.Return)=="open"and Hub.keyAction(K.ButtonB)=="back"and Hub.keyAction(K.Escape)=="back")
   assert(Hub.keyAction(K.M)=="back"and Hub.keyAction(K.DPadLeft)=="left"and Hub.keyAction(K.S)=="down"and Hub.keyAction(K.Q)==nil)
  end)
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
    -- Status: the stamp, two quests and two book milestones wait (gold dots).
    assert(hub.tileViews[1].dot.Visible and hub.tileViews[4].dot.Visible and hub.tileViews[5].dot.Visible and not hub.tileViews[2].dot.Visible)
    -- Keyboard / controller focus on the 3 x 2 grid.
    hub:input(K.Right);assert(hub.root:GetAttribute("FocusedTile")=="style")
    hub:input(K.D);assert(hub.root:GetAttribute("FocusedTile")=="companions")
    hub:input(K.Right);assert(hub.root:GetAttribute("FocusedTile")=="companions","stays at the edge")
    hub:input(K.DPadDown);assert(hub.root:GetAttribute("FocusedTile")=="settings")
    hub:input(K.ButtonA);assert(opened[1]=="settings","ButtonA opens the focused tile")
    hub:input(K.A);hub:input(K.A);assert(hub.root:GetAttribute("FocusedTile")=="quests","A on the keyboard moves left")
    hub:input(K.Return);assert(opened[2]=="quests")
    assert(hub.ring.root.Visible and hub.ring.target==hub.tileViews[4].button,"the focus ring sits on Quests")
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
