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
   assert(Hub.newItems({pendingToyResult={},pendingMaterialResult={}})==2 and Hub.newItems({})==0)
   assert(Hub.ownedCount({petWearables={pip={owned={"a","b","c"}}}},"pip")==3 and Hub.ownedCount({},"pip")==0)
  end)
  test("pure: pane summary rows read Wearing, Charm, Finish, Toy with None for a hidden charm",function()
   local rows=Hub.summary("pip",{charmVisible=false,finish="standard",toyId="none",wearables={}})
   assert(rows[1][1]=="Wearing"and rows[1][2]=="Nothing yet")
   assert(rows[2][1]=="Charm"and rows[2][2]=="None")
   assert(rows[3][1]=="Finish"and rows[4][1]=="Toy")
   assert(Hub.summary("pip",{charmVisible=true,charmShape="ring"})[2][2]=="Ring")
  end)
  test("pure: focus steps clamp, Back goes up one level",function()
   assert(Hub.step(3,0,-1,3,1)==2 and Hub.step(1,0,-1,3,1)==1 and Hub.step(3,0,1,3,1)==3)
   assert(Hub.step(1,1,0,3,2)==2 and Hub.step(2,0,1,3,2)==3)
   assert(Hub.backTarget("pets",false)=="hub"and Hub.backTarget("hub",false)=="close"and Hub.backTarget("pets",true)=="cancel")
   assert(Hub.DefaultRow==3 and Hub.Rows[3].id=="customize"and Hub.Rows[1].icon=="paw"and Hub.Rows[2].icon=="shirt"and Hub.Rows[3].icon=="wand")
   -- QA Q5: three rows again, at the sizes from before the play-forever build.
   assert(#Hub.Rows==3 and Hub.RowPitch.regular==156 and Hub.RowPitch.regularH==140 and Hub.RowPitch.phone==73 and Hub.RowPitch.phoneH==64)
   for _,row in ipairs(Hub.Rows)do assert(row.id~="book","no book row")end
  end)
  for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354)})do
   test(tostring(size).." hub navigation: Customize first, d-pad focus, A opens, Pets selector, Back up a level",function()
    local host=Instance.new("Frame");host.BackgroundTransparency=1;host.Size=UDim2.fromOffset(size.X,size.Y);host.Parent=gui
    local opened,follows,backs={},{},0
    local hub=Hub.new(host,{appearance=function()return{charmVisible=true}end,
     open=function(id)table.insert(opened,id);return true end,follow=function(id)table.insert(follows,id);return true end,back=function()backs+=1 end})
    local state={inventoryMask=127,nectar=128,pendingToyResult={id="t"},petWearables={pip={owned={"x"}}},book={claimable={"balls.25"}}}
    local active=Pets.collection[1].id
    assert(hub:open({wallet=128,state=state,activeId=active}));settle()
    assert(hub:isOpen()and hub.page=="hub"and #hub.rows==3)
    assert(hub.root:GetAttribute("FocusedRow")=="customize","opens on Customize the first time")
    for _,row in ipairs(hub.rows)do assert(row.button.AbsoluteSize.Y>=44,"row target under 44 px")end
    assert(hub.rows[3].status.Text=="1 NEW ITEM"and hub.rows[3].dot~=nil)
    -- Every row stays inside the panel / sheet (three rows under the header), at the
    -- pre-play-forever rects: desktop 456 x 140 on a 156 pitch, phone 64 high on 73.
    local h=if size.X>=1000 then 140 else 64
    local pitch=if size.X>=1000 then 156 else 73
    local scale=hub.scale.Scale
    for i,row in ipairs(hub.rows)do
     assert(math.abs(row.button.AbsoluteSize.Y-h*scale)<=1,"row "..i.." height "..row.button.AbsoluteSize.Y)
     if i>1 then assert(math.abs(row.button.AbsolutePosition.Y-hub.rows[i-1].button.AbsolutePosition.Y-pitch*scale)<=1,"row pitch")end
    end
    for _,row in ipairs(hub.rows)do
     local bottom=row.button.AbsolutePosition.Y+row.button.AbsoluteSize.Y
     assert(bottom<=hub.root.AbsolutePosition.Y+hub.root.AbsoluteSize.Y+.5,"row past the panel bottom")
    end
    assert(hub.header.root:FindFirstChild("Wallet")and hub.header.title.Text=="Companions")
    hub:input(K.Up);assert(hub.root:GetAttribute("FocusedRow")=="wardrobe")
    hub:input(K.Return);assert(opened[#opened]=="wardrobe","A opens the Wardrobe through the caller")
    hub:input(K.S);assert(hub.root:GetAttribute("FocusedRow")=="customize")
    hub:input(K.ButtonA);assert(opened[#opened]=="customize")
    hub:input(K.S);assert(hub.root:GetAttribute("FocusedRow")=="customize","Customize is the last row")
    hub:input(K.W);hub:input(K.W);assert(hub.root:GetAttribute("FocusedRow")=="pets")
    hub:input(K.Return);settle();assert(hub.page=="pets"and hub.header.title.Text=="Pets"and #hub.cardButtons>=1)
    assert(hub.root:GetAttribute("FocusedPet")==active,"selector lands on the pet that follows you")
    assert(hub.cardButtons[1].status.Text=="FOLLOWING")
    local before=#follows
    hub:input(K.Return);assert(#follows==before,"Follow is disabled on the pet already following")
    if #hub.cardButtons>1 then hub:input(K.Right);hub:input(K.Return);assert(#follows==before+1 and hub.pendingFollow~=nil)end
    hub:input(K.Backspace);settle();assert(hub.page=="hub"and hub:isOpen(),"Back from Pets returns to the hub")
    assert(hub.root:GetAttribute("FocusedRow")=="pets")
    hub:input(K.ButtonB);assert(not hub:isOpen()and backs==1,"Back from the hub closes it")
    -- Receipts: assign mode opens straight on the selector and closes on the choice.
    local chosen
    assert(hub:open({wallet=1,state=state,activeId=active},{page="pets",assign={line="Use Gloss on this pet",button="Use here",choose=function(id)chosen=id;return true end}}));settle()
    assert(hub.page=="pets"and hub.root:GetAttribute("Assigning")==true and hub.action.Visible)
    hub:act();assert(chosen==active and not hub:isOpen(),"assign mode chooses the focused pet and closes")
    local cancelled=false
    hub:open({state=state,activeId=active},{page="pets",assign={choose=function()return true end,cancel=function()cancelled=true end}});settle()
    hub:input(K.Backspace);assert(cancelled and not hub:isOpen(),"Back in assign mode cancels")
    hub:destroy();host:Destroy()
   end)
  end
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 gui:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
