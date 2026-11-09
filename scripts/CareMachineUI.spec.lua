return function(client,parent)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent);local Run=game:GetService("RunService")
 local cases={};local calls={};local sent={};local view;local root=Instance.new("Frame");root.Size=UDim2.fromOffset(1200,760);root.Parent=parent
 local intent=Intent.new({id=function()return "care-ui-hue"end,send=function(...)table.insert(sent,{...})end,changed=function()if view then view:refresh()end end})
 view=View.new(root,intent,{shapeSelectionsEnabled=function()return true end,equipPet=function(id)table.insert(calls,id);return true end,careAction=function(kind)table.insert(calls,kind)end})
 local zero={rose=0,tide=0,citrus=0,iris=0};local state={status="Ready",revision=1,nectar=25,inventoryMask=127,hues={},petHues={pip={main=zero,secondary=zero},puddle={main=zero,secondary=zero}},hueInventory={rose=3,reset=1}}
 local function frames()for _=1,3 do Run.Heartbeat:Wait()end end
 local function test(name,run)run();table.insert(cases,name)end
 local ok,problem=pcall(function()
  test("ordinary shortcut editor keeps its original target and has no machine actions",function()
   view:open(state,"palette","pip");frames();assert(not view.machinePickup.Visible and not view.machineSetDown.Visible and not view.targetChange.Visible)
   assert(view:choosePet("puddle")and view.petId=="puddle"and not view.confirmation)
  end)
  test("machine switch requires an explicit activation confirmation and preserves saved old pet",function()
   view:setMachineSession({claimId="bay1",petId="pip"});frames();assert(view.targetChange.Visible and view.machinePickup.Visible and view.machineSetDown.Visible)
   assert(view:choosePet("puddle")and view.petId=="pip"and view.confirmation.equipPetId=="puddle"and #calls==0)
   assert(view.title.Text=="Make Ovelle active?"and view.quote.Text:find("No Stars or jars",1,true));assert(view:cancelConfirmation()and #calls==0)
  end)
  test("save pending does not replace portrait and failure keeps old pet and bay",function()
   local v=view.visual;view:choosePet("puddle");assert(view:activate()and not view:activate()and calls[1]=="puddle")
   assert(view.petId=="pip"and view.visual==v and view.machine.claimId=="bay1")
   view:machineEquipFinished("Rejected");assert(view.petId=="pip"and view.machine.claimId=="bay1"and view.confirmation)
  end)
  test("only confirmed new session identity selects the replacement saved pet",function()
   view:machineEquipFinished("Saved");view:setMachineSession({claimId="bay1",petId="puddle"});frames()
   assert(view.petId=="puddle"and view.visualId=="puddle"and not view.confirmation and #sent==0 and state.nectar==25 and state.hueInventory.rose==3)
  end)
  test("desktop phone and short Largest geometry preserve pinned exit actions and first chip row",function()
   for _,size in ipairs({Vector2.new(1200,760),Vector2.new(350,703),Vector2.new(733,307)})do
    root.Size=UDim2.fromOffset(size.X,size.Y);frames();view:layout();frames()
    for _,n in ipairs({view.machinePickup,view.machineSetDown})do
     assert(n.TextFits and n.AbsoluteSize.X>=44 and n.AbsoluteSize.Y>=44)
     assert(n.AbsolutePosition.Y>=view.body.AbsolutePosition.Y+view.body.AbsoluteSize.Y-.5,"machine exit action overlays scroller")
     assert(n.AbsolutePosition.Y+n.AbsoluteSize.Y<=view.card.AbsolutePosition.Y+view.card.AbsoluteSize.Y+.5)
    end
    if size==Vector2.new(733,307)then
     view.body.CanvasPosition=Vector2.zero;view:inspectHue("rose",4);frames()
     local bottom=view.body.AbsolutePosition.Y+view.body.AbsoluteSize.Y
     for _,n in ipairs(view.bars.rose.ticks)do assert(n.AbsolutePosition.Y+n.AbsoluteSize.Y<=bottom+.5,"first machine chip row is cut at fold")end
    end
   end
  end)
  test("leaving machine scope restores shortcut controls without an equip or item request",function()
   view:setMachineSession(nil);view:refresh();frames()
   assert(not view.machinePickup.Visible and not view.machineSetDown.Visible and #sent==0)
   assert(view:choosePet("foxfire_wick")and view.petId=="foxfire_wick"and not view.confirmation)
  end)
  test("short docked Charm keeps complete portrait change-pet and a real control above pinned exits",function()
   root.Size=UDim2.fromOffset(733,307);view:setMachineSession({claimId="charm-phone",petId="pip"});view:open(state,"palette","pip");frames()
   view.body.CanvasPosition=Vector2.new(0,60);view:setTab("charm");frames();view:layout();frames()
   assert(view.body.CanvasPosition.Y==0,"entering compact Charm kept a scrolled Hue canvas")
   local top=view.body.AbsolutePosition.Y;local bottom=top+view.body.AbsoluteSize.Y
   for _,n in ipairs({view.portrait,view.targetChange,view.charmToggle})do
    assert(n.Visible and n.AbsolutePosition.Y>=top-.5 and n.AbsolutePosition.Y+n.AbsoluteSize.Y<=bottom+.5,n.Name.." is cut by the machine footer")
   end
   assert(view.portrait.AbsoluteSize.Y>=96 and view.portrait.AbsoluteSize.Y<=104)
   assert(view.targetChange.TextFits and view.charmToggle.TextFits and view.targetChange.AbsoluteSize.Y>=44 and view.charmToggle.AbsoluteSize.Y>=44)
   assert(view.charmToggle.AbsolutePosition.X>=view.portrait.AbsolutePosition.X+view.portrait.AbsoluteSize.X,"Charm controls did not move into the right column")
   for _,n in pairs(view.shapes)do if n.Visible then
    assert(n.AbsoluteSize.X>=44 and n.AbsoluteSize.Y>=44 and n.TextFits)
    assert(n.AbsolutePosition.Y>=top-.5 and n.AbsolutePosition.Y+n.AbsoluteSize.Y<=bottom+.5,n.Name.." requires scrolling away the portrait")
    assert(n:GetAttribute("AccessibleLabel"):find("Secondary",1,true));view:ensure(n);frames()
    assert(view.portrait.AbsolutePosition.Y>=top-.5 and view.portrait.AbsolutePosition.Y+view.portrait.AbsoluteSize.Y<=bottom+.5,"choosing a charm scrolls away the pet")
   end end
   for _,n in ipairs({view.machinePickup,view.machineSetDown})do assert(n.Visible and n.AbsolutePosition.Y>=bottom-.5 and n.AbsoluteSize.Y>=44)end
   view:setTab("hue");frames()
  end)
  test("late old machine save cannot clear a new bay or an unrelated hue confirmation",function()
   view:setMachineSession({claimId="old",petId="pip"});local old=view:machineBinding()
   view:setMachineSession({claimId="new",petId="puddle"});view:choosePet("orbit");local q=view.confirmation
   assert(not view:machineEquipFinished("Saved",old)and view.confirmation==q and view.machine.claimId=="new")
   view:cancelConfirmation();view:setMachineSession(nil);view:chooseChannel("main");assert(view:chooseItem("rose"));q=view.confirmation
   assert(not view:machineEquipFinished("Saved",old)and view.confirmation==q)
  end)
 end)
 view:destroy();root:Destroy();assert(ok,problem);return {passed=#cases,cases=cases}
end
