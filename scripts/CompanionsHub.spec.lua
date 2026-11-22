-- Studio Client. Companions hub (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 1, 0.3, 0.4):
-- pure status / summary / focus rules, then a built hub: three rows with Customize
-- focused first, d-pad focus, A opens a row (Wardrobe and Customize through the
-- caller, Pets in place), Back goes up one level, the Pets selector follows and, in
-- assign mode, chooses a recipient and closes. Desktop and the 812x354 phone sheet.
-- Usage: require(PlayerScripts.Client.ZZSpecs.CompanionsHub)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Hub=require(client.CompanionsHub)
 local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local gui=Instance.new("ScreenGui");gui.Name="_CompanionsHubSpec";gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;gui.Parent=parent
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local K=Enum.KeyCode
 local ok,problem=xpcall(function()
  test("pure: row status lines, new items in gold, owned count, pet name in caps",function()
   assert(Hub.status("pets",{petName="Zivvi"}).text=="ZIVVI")
   assert(Hub.status("wardrobe",{owned=3}).text=="3 OWNED")
   local c=Hub.status("customize",{newItems=1});assert(c.text=="1 NEW ITEM"and c.tone=="stars"and c.dot)
   assert(Hub.status("customize",{newItems=2}).text=="2 NEW ITEMS")
   assert(Hub.status("customize",{newItems=0}).text=="")
   -- QA Q5: the Collection book left the hub (machine hub tile); no book row status.
   assert(Hub.status("book",{bookClaimable=2}).text==""and not Hub.status("book",{bookClaimable=2}).dot)
   -- v816: a waiting toy is the Toys row's NEW badge, not Customize's.
   assert(Hub.newItems({pendingToyResult={},pendingMaterialResult={}})==1 and Hub.newItems({})==0)
   assert(Hub.status("toys",{toys=2}).text=="2 OWNED"and not Hub.status("toys",{toys=2}).dot)
   local t=Hub.status("toys",{toys=3,newToy=true});assert(t.dot and t.tone=="stars"and string.find(t.text,"3 OWNED",1,true))
   assert(Hub.toysOwned({toyUnlocks={none=true,ball=true,bone=true}})==2 and Hub.toysOwned({})==0)
   assert(Hub.ownedCount({petWearables={pip={owned={"a","b","c"}}}},"pip")==3 and Hub.ownedCount({},"pip")==0)
  end)
  test("pure: pane summary rows read Wearing, Charm, Material, Toy with None for a hidden charm",function()
   local rows=Hub.summary("pip",{charmVisible=false,finish="standard",toyId="none",wearables={}})
   assert(rows[1][1]=="Wearing"and rows[1][2]=="Nothing yet")
   assert(rows[2][1]=="Charm"and rows[2][2]=="None")
   assert(rows[3][1]=="Material"and rows[3][2]=="Original"and rows[4][1]=="Toy")
   assert(Hub.summary("pip",{sheen=2,jellyStage=0})[3][2]=="Glossy","the jar look names the Material row")
   assert(Hub.summary("pip",{charmVisible=true,charmShape="ring"})[2][2]=="Ring")
  end)
  test("pure (Levels matter): the Heart level only while the track is on; a worn gated item keeps its name off",function()
   local Levels=require(game.ReplicatedStorage.Shared.Levels)
   local state={petStats={pets={pip={level={heart=14}}}}}
   Levels.inject({flags={},studio=true})
   assert(Hub.heartLevel(state,"pip")==nil)
   assert(Hub.summary("pip",{wearables={Hat="beanie_lime"}})[1][2]=="Lime Pom Beanie")
   Levels.inject({flags={LevelsMatter=true},studio=true,shipped={track=true}})
   assert(Hub.heartLevel(state,"pip")==14 and Hub.heartLevel(state,"blip")==nil and Hub.heartLevel(nil,"pip")==nil)
   Levels.inject(nil)
  end)
  test("pure (v2 Bunny): an active earned pet you do not own is an adopt card at its fixed price",function()
   local Earned=require(game.ReplicatedStorage.Shared.EarnedPets)
   local cards=Hub.petCards({inventoryMask=1,stamps=3},"pip")
   local adopt=cards[#cards]
   if Pets.isActive("blip")then
    assert(#cards==2 and cards[1].id=="pip"and adopt.id=="blip"and adopt.adopt and adopt.price==Earned.Rules.blip.stars and adopt.need==7 and adopt.stamps==3)
   else assert(#cards==1)end
   local owned=Hub.petCards({inventoryMask=1+128},"pip");for _,c in ipairs(owned)do assert(not c.adopt)end
   local card={need=7,stamps=9,price=400}
   local line,button,enabled=Hub.adoptPane(card,500,false,false)
   assert(line=="Free at 7 stamps (7/7), or adopt now"and button=="Adopt for ★ 400"and enabled)
   assert(select(2,Hub.adoptPane(card,500,false,true))=="Press again to adopt for ★ 400")
   local _,short,can=Hub.adoptPane(card,399,false,false);assert(short=="Needs ★ 400"and not can)
   local _,saving,can2=Hub.adoptPane(card,500,true,false);assert(saving=="Adopting…"and not can2)
   -- Earned (7 stamps, the grant not landed yet): free, no Stars needed, no confirm.
   if Pets.isActive("blip")then
    local earned=Hub.petCards({inventoryMask=1,stamps=7},"pip");local f=earned[#earned]
    assert(f.adopt and f.free and not Hub.petCards({inventoryMask=1,stamps=6},"pip")[2].free)
    local fl,fb,fe=Hub.adoptPane(f,0,false,false)
    assert(fl=="7 stamps: yours for free"and fb=="Take home free"and fe,"free with an empty wallet")
   end
  end)
  test("pure: Stats and Name are their own tiles; the hub is a 2 x 3 grid inside the window",function()
   local rows=Hub.rowsFor({})
   assert(#rows==6 and rows[1].id=="pets"and rows[2].id=="stats"and rows[3].id=="name"and rows[4].id=="wardrobe"and rows[5].id=="customize"and rows[6].id=="toys")
   assert(#Hub.rowsFor({stats=false,names=false})==4 and Hub.defaultIndex(Hub.rowsFor({stats=false,names=false}))==3 and Hub.defaultIndex(rows)==5)
   assert(Hub.status("stats",{totalLevel=12}).text=="TOTAL 12"and Hub.status("name",{named=true,shownName="Biscuit"}).text=="BISCUIT")
   local unnamed=Hub.status("name",{named=false});assert(unnamed.dot and unnamed.text=="NOT NAMED YET")
   for _,c in ipairs({{848,608,false},{844,390-62,true},{568,320-50,true}})do
    local W,H,phone=c[1],c[2],c[3]
    local last=Hub.tileRect(6,6,W,H,phone)
    assert(last.h>=44 and last.y+last.h<=(if phone then H-20 else 84+452),"tiles inside the window at "..W.."x"..H)
    local a,b=Hub.tileRect(1,6,W,H,phone),Hub.tileRect(2,6,W,H,phone)
    assert(b.x>a.x+a.w and b.y==a.y,"two columns")
   end
  end)
  test("pure: focus steps clamp, Back goes up one level",function()
   assert(Hub.step(3,0,-1,3,1)==2 and Hub.step(1,0,-1,3,1)==1 and Hub.step(3,0,1,3,1)==3)
   assert(Hub.step(1,1,0,3,2)==2 and Hub.step(2,0,1,3,2)==3)
   assert(Hub.backTarget("pets",false)=="hub"and Hub.backTarget("hub",false)=="close"and Hub.backTarget("pets",true)=="cancel")
   -- 2026-11-20 grid: Pets, Stats / Name, Wardrobe / Customize, Toys; Customize still opens first.
   assert(Hub.DefaultRow==5 and Hub.Rows[5].id=="customize"and Hub.Rows[6].id=="toys"and Hub.Rows[1].icon=="paw"and Hub.Rows[4].icon=="shirt"and Hub.Rows[6].icon=="toy"and Hub.Rows[5].icon=="wand")
   assert(Hub.Rows[5].line=="Hue, charm and material"and Hub.Rows[6].line=="Pick a toy and watch your pet play")
   assert(#Hub.Rows==6 and Hub.Cols==2)
   for _,row in ipairs(Hub.Rows)do assert(row.id~="book","no book row")end
  end)
  for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354)})do
   test(tostring(size).." hub navigation: Customize first, d-pad focus, A opens, Pets selector, Back up a level",function()
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local opened,follows,backs,adopts={},{},0,{}
    local hub=Hub.new(host,{appearance=function()return{charmVisible=true}end,
     open=function(id)table.insert(opened,id);return true end,follow=function(id)table.insert(follows,id);return true end,back=function()backs+=1 end,
     adopt=function(id,price)table.insert(adopts,{id,price});return true end})
    local state={inventoryMask=127,nectar=128,pendingToyResult={id="t"},petWearables={pip={owned={"x"}}},book={claimable={"balls.25"}}}
    local active=Pets.collection[1].id
    assert(hub:open({wallet=128,state=state,activeId=active}));settle()
    assert(hub:isOpen()and hub.page=="hub"and #hub.rows==6)
    assert(hub.root:GetAttribute("FocusedRow")=="customize","opens on Customize the first time")
    for _,row in ipairs(hub.rows)do assert(row.button.AbsoluteSize.Y>=44,"row target under 44 px")end
    -- v816: the waiting toy is the Toys tile's NEW badge; Customize has nothing new.
    assert(hub.rows[6].id=="toys"and string.find(hub.rows[6].status.Text,"NEW",1,true)and hub.rows[6].dot~=nil)
    assert(hub.rows[5].status.Text==""and hub.rows[5].dot==nil)
    assert(hub.rows[5].line.Text=="Hue, charm and material")
    assert(hub.rows[3].name.Text=="Name","the Name tile reads Name (round 3)")
    -- Every tile stays inside the panel / sheet, two columns.
    for _,row in ipairs(hub.rows)do
     local bottom=row.button.AbsolutePosition.Y+row.button.AbsoluteSize.Y
     assert(bottom<=hub.root.AbsolutePosition.Y+hub.root.AbsoluteSize.Y+.5,"tile past the panel bottom")
    end
    assert(math.abs(hub.rows[1].button.AbsolutePosition.Y-hub.rows[2].button.AbsolutePosition.Y)<=1 and hub.rows[2].button.AbsolutePosition.X>hub.rows[1].button.AbsolutePosition.X)
    assert(hub.statsButton==nil and hub.nameButton==nil and hub.viewport.Position.Y.Offset==0,"no buttons over the preview")
    assert(hub.header.root:FindFirstChild("Wallet")and hub.header.title.Text=="Companions")
    hub:input(K.Right);assert(hub.root:GetAttribute("FocusedRow")=="toys")
    hub:input(K.Return);assert(opened[#opened]=="toys","A opens the Toys screen through the caller")
    hub:input(K.S);assert(hub.root:GetAttribute("FocusedRow")=="toys","Toys is the last tile")
    hub:input(K.Up);assert(hub.root:GetAttribute("FocusedRow")=="wardrobe")
    hub:input(K.Return);assert(opened[#opened]=="wardrobe","A opens the Wardrobe through the caller")
    hub:input(K.Left);assert(hub.root:GetAttribute("FocusedRow")=="name")
    hub:input(K.ButtonA);assert(opened[#opened]=="name","the Name tile opens the naming screen")
    hub:input(K.W);hub:input(K.D);assert(hub.root:GetAttribute("FocusedRow")=="stats")
    hub:input(K.ButtonA);assert(opened[#opened]=="stats","the Stats tile opens the stats panel")
    hub:input(K.A);assert(hub.root:GetAttribute("FocusedRow")=="pets")
    hub:input(K.Return);settle();assert(hub.page=="pets"and hub.header.title.Text=="Pets"and #hub.cardButtons>=1)
    assert(hub.root:GetAttribute("FocusedPet")==active,"selector lands on the pet that follows you")
    assert(hub.cardButtons[1].status.Text=="FOLLOWING")
    local before=#follows
    hub:input(K.Return);assert(#follows==before,"Follow is disabled on the pet already following")
    local second=Hub.petCards(state,active)[2]
    if second and not second.adopt then hub:input(K.Right);hub:input(K.Return);assert(#follows==before+1 and hub.pendingFollow~=nil)end
    -- v2 Bunny: the earned pet you do not own is an adopt card; 128 Stars is short of 400.
    if second and second.adopt then
     hub:input(K.Right);settle()
     assert(hub.root:GetAttribute("FocusedPet")=="blip"and hub.cardButtons[2].status.Text=="ADOPT ★ 400")
     assert(string.find(tostring(hub.action:GetAttribute("AccessibleLabel")),"Needs",1,true),"short of Stars: "..tostring(hub.action:GetAttribute("AccessibleLabel")))
     hub:input(K.Return);hub:input(K.Return);assert(#adopts==0 and #follows==before,"no adopt when short, never a follow")
     hub:input(K.Left);settle()
    end
    hub:input(K.Backspace);settle();assert(hub.page=="hub"and hub:isOpen(),"Back from Pets returns to the hub")
    assert(hub.root:GetAttribute("FocusedRow")=="pets")
    hub:input(K.ButtonB);assert(not hub:isOpen()and backs==1,"Back from the hub closes it")
    -- Receipts: assign mode opens straight on the selector and closes on the choice.
    local chosen
    assert(hub:open({wallet=1,state=state,activeId=active},{page="pets",assign={line="Use Gloss on this pet",button="Use here",choose=function(id)chosen=id;return true end}}));settle()
    assert(hub.page=="pets"and hub.root:GetAttribute("Assigning")==true and hub.action.Visible)
    assert(#hub.cardButtons==#Hub.petCards(state,active)-(if Hub.petCards(state,active)[2]and Hub.petCards(state,active)[2].adopt then 1 else 0),"assign mode lists owned pets only")
    hub:act();assert(chosen==active and not hub:isOpen(),"assign mode chooses the focused pet and closes")
    -- v2 Bunny adopt (round 3): the press opens the confirm dialog; its yes sends; the answer clears it.
    if Pets.isActive("blip")then
     hub:open({wallet=500,state=state,activeId=active},{page="pets"});settle()
     hub:input(K.Right);settle();assert(hub.root:GetAttribute("FocusedPet")=="blip")
     assert(string.find(tostring(hub.action:GetAttribute("AccessibleLabel")),"Adopt for",1,true),tostring(hub.action:GetAttribute("AccessibleLabel")))
     local Confirm=require(client.ConfirmDialog)
     hub:input(K.Return);settle();assert(#adopts==0 and Confirm.isOpen(),"the press opens the confirm dialog")
     assert(string.find(Confirm.panel().Title.Text,"Bunny",1,true),Confirm.panel().Title.Text)
     Confirm.close("cancel");settle();assert(#adopts==0 and not Confirm.isOpen(),"cancel sends nothing")
     hub:input(K.Return);settle();Confirm.accept();settle()
     assert(#adopts==1 and adopts[1][1]=="blip"and adopts[1][2]==400 and hub.pendingAdopt=="blip")
     hub:input(K.Return);settle();assert(#adopts==1,"one request while saving")
     assert(hub:adoptResult({kind="adopt",petId="pip",status="Saved"})==nil,"another pet's answer is ignored")
     assert(hub:adoptResult({kind="adopt",petId="blip",status="Saved"})=="Bunny came home with you!"and hub.pendingAdopt==nil)
     hub:input(K.ButtonB);hub:input(K.ButtonB)
    end
    local cancelled=false
    hub:open({state=state,activeId=active},{page="pets",assign={choose=function()return true end,cancel=function()cancelled=true end}});settle()
    hub:input(K.Backspace);assert(cancelled and not hub:isOpen(),"Back in assign mode cancels")
    -- v850: opened by touch, no row is highlighted and no ring shows; the first arrow
    -- press brings the focus back (on the remembered row) without moving it.
    hub:open({wallet=1,state=state,activeId=active},{touch=true});settle()
    -- Toy Shell: rows rest at a 2 px ink outline (Kit.TileRest) and the focused one is lemon and 3 px.
    local Kit=require(client.DeckKit)
    for _,row in ipairs(hub.rows)do assert(row.stroke.Thickness==Kit.TileRest,"a row is highlighted on a touch open")end
    assert(not hub.ring.root.Visible,"the focus ring shows on a touch open")
    local was=hub.rowIndex;hub:input(K.Down);settle()
    assert(hub.rowIndex==was and hub.rows[was].stroke.Thickness==3,"the first key shows the focus where it was")
    hub:input(K.ButtonB)
    hub:destroy();host:Destroy()
   end)
  end
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
