-- Production editor with isolated authoritative snapshots; no profile mutation.
return function(client,parent)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent);local Run=game:GetService("RunService")
 local cases,calls,sent={},{},{};local view;local active="pip";local pickupDone;local pickups=0
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(1200,760);root.Parent=parent
 local intent=Intent.new({id=function()return "care-ui-hue"end,send=function(...)table.insert(sent,{...})end,changed=function()if view then view:refresh()end end})
 view=View.new(root,intent,{shapeSelectionsEnabled=function()return true end,activePet=function()return active end,
  equipPet=function(id)table.insert(calls,id);return true end,
  dismissMachine=function(binding,done)pickups+=1;pickupDone=done;return true end})
 local zero={rose=0,tide=0,citrus=0,iris=0};local state={status="Ready",revision=1,nectar=25,inventoryMask=127,hues={},petHues={pip={main=zero,secondary=zero},puddle={main=zero,secondary=zero}},hueInventory={rose=3,reset=1}}
 local function frames()for _=1,3 do Run.Heartbeat:Wait()end end
 local function test(name,run)run();table.insert(cases,name)end
 local function inside(node,host)local p,s,q,t=node.AbsolutePosition,node.AbsoluteSize,host.AbsolutePosition,host.AbsoluteSize;return p.X>=q.X-.5 and p.Y>=q.Y-.5 and p.X+s.X<=q.X+t.X+.5 and p.Y+s.Y<=q.Y+t.Y+.5 end
 local ok,problem=pcall(function()
  test("ordinary Pet selection confirms and marks Active only after authoritative commit",function()
   view:open(state,"pet","pip");frames()
   assert(not view.machinePickup.Visible and not view.machineSetDown.Visible and not view.targetChange.Visible and not view.wallet.Visible)
   assert(view:choosePet("puddle")and view.petId=="pip"and view.confirmation.equipPetId=="puddle")
   assert(view.title.Text=="Make Ovelle active?"and view:activate()and not view:activate()and calls[1]=="puddle")
   assert(view.gridPreviews.pip.active.Text=="✓ Active"and view.gridPreviews.puddle.active.Text=="")
   active="puddle";view:syncActive();frames();assert(view.petId=="puddle"and not view.confirmation and not view.machineSwitching)
  end)
  test("machine equip waits for saved proof and exact new actor identity in either order",function()
   for _,savedFirst in ipairs({true,false})do
    view:setMachineSession({claimId="bay1",petId="pip"});view:open(state,"pet","pip")
    assert(view:choosePet("puddle")and view:activate());local binding=view:machineBinding();local before=pickups
    view:close("back");assert(view.closeAfterEquip and view.shade.Visible)
    if savedFirst then view:machineEquipFinished("Saved",binding);assert(view.machineSwitching and pickups==before);view:setMachineSession({claimId="bay1",petId="puddle"})
    else view:setMachineSession({claimId="bay1",petId="puddle"});assert(view.machineSwitching);view:machineEquipFinished("Saved",binding)end
    frames();assert(not view.machineSwitching and view.petId=="puddle"and view.exitPending)
    pickupDone({status="Rejected"});assert(view.shade.Visible and not view.exitPending)
    view:close("forced");view:setMachineSession(nil)
   end
  end)
  test("ordinary late save survives timeout feedback and a reopened editor",function()
   view:close("forced");view:setMachineSession(nil);active="pip";view:open(state,"pet","pip")
   assert(view:choosePet("puddle")and view:activate());view.machineSwitching=nil -- retry feedback after transport delay
   view:close("forced");view:open(state,"pet","pip");assert(view.confirmation.equipPetId=="puddle")
   active="puddle";view:syncActive();assert(view.petId=="puddle"and not view.confirmation and not view.equipTargetId)
  end)
  test("explicit machine close coalesces pickup and keeps failure retryable",function()
   view:open(state,"palette","pip");view:setMachineSession({claimId="bay2",petId="pip"});local before=pickups
   view:close("back");view:close("back");assert(view.shade.Visible and view.exitPending and pickups==before+1)
   pickupDone({status="Rejected"});assert(view.shade.Visible and not view.exitPending and view.status.Text:find("retry",1,true))
   view:close("back");assert(pickups==before+2);pickupDone({status="Accepted"});assert(not view.shade.Visible)
  end)
  test("forced exit and cancelling a choice never request pickup",function()
   view:open(state,"pet","pip");view:setMachineSession({claimId="bay3",petId="pip"});local before=pickups
   view:choosePet("orbit");view:close("back");assert(not view.confirmation and view.shade.Visible and pickups==before)
   view:close("forced");assert(not view.shade.Visible and pickups==before);view:setMachineSession(nil)
  end)
  test("fixed tabs portrait and complete channel controls survive constrained layouts",function()
   for _,size in ipairs({Vector2.new(1200,760),Vector2.new(385,703),Vector2.new(733,307),Vector2.new(553,381),Vector2.new(568,160)})do
    root.Size=UDim2.fromOffset(size.X,size.Y);view:open(state,"palette","pip");frames();view:layout();frames()
    assert(view.body.Active and view.body:IsA("ScrollingFrame"),"options scroller must claim native wheel input")
    -- Redesign 2: header back, icon tabs and the pinned pane well replace the card tabs and Charm On/Off.
    assert(view.chromeRoot.Visible and view.portrait.Parent==view.chromeWell and view.portrait.Visible)
    -- Landscape only: portrait windows scale the 848 panel down (the redesign draws desktop and landscape phones).
    if size.X>size.Y then for id,tab in pairs(view.editorTabs)do assert(tab.Visible and tab.AbsoluteSize.Y>=44,id.." tab shrank at "..tostring(size))end end
    local tabY=view.editorTabs.hue.AbsolutePosition.Y
    view.chromeGrid.CanvasPosition=Vector2.new(0,120);frames();assert(view.editorTabs.hue.AbsolutePosition.Y==tabY)
    view:setTab("charm");frames();assert(view.editorTabs.hue.AbsolutePosition.Y==tabY and view.charmToggle==nil and view.charmOff==nil)
    assert(view.charmCards.none.Visible,"None card missing at "..tostring(size))
    if size.X>size.Y then assert(view.charmCards.none.AbsoluteSize.Y>=44,"None card under 44 px at "..tostring(size))end
    if size.X>=500 and size.Y>=220 then
     view:setTab("pet");frames();assert(not view.targetTitle.Visible,"ordinary owned grid retained redundant heading")
     assert(inside(view.targets.pip,view.body),"first complete owned square cannot fit its short-phone viewport")
     assert(inside(view.targets[active],view.body)and view.gridPreviews[active].active.Text=="✓ Active"and view.gridPreviews[active].active.TextFits)
    end
   end
   root.Size=UDim2.fromOffset(900,720);frames();view:layout();frames();assert(view.paneName.Text~=""and view.paneName.TextFits,"size-only return from constrained layout lost the pane name")
  end)
  test("every saved charm shows WEARING on its own card and None on hidden, at constrained size",function()
   root.Size=UDim2.fromOffset(568,160);view:open(state,"charm","pip")
   local appearance=view.options.appearance
   for _,shape in ipairs({"dot","ring","pebble"})do
    view.options.appearance=function()return {charmVisible=true,charmShape=shape}end;view:refresh();frames()
    assert(view.charmCards[shape]:GetAttribute("CardStatus")=="WEARING"and view.charmCards.none:GetAttribute("CardStatus")=="No charm","saved "..shape.." not marked")
   end
   view.options.appearance=function()return {charmVisible=false,charmShape="ring"}end;view:refresh();frames()
   assert(view.charmCards.none:GetAttribute("CardStatus")=="WEARING"and view.charmCards.ring:GetAttribute("CardStatus")=="Free")
   view.options.appearance=appearance;view:refresh()
  end)
  test("owned live grid is bounded and closes visible model generations",function()
   root.Size=UDim2.fromOffset(900,720);view:open(state,"pet","pip");frames();local live=0
   for _,entry in pairs(view.gridPreviews)do if entry.visual then live+=1; end end
   -- The Pet tab moved to the Companions hub (redesign 2026-11-13); Customize no longer
   -- builds the owned grid, so only the bound applies when the view lands elsewhere.
   assert(live<=7,"owned grid over budget: "..live)
   if view.tab=="pet"then assert(live>0 and view.portraitClock,"pet grid empty")end
   view:close("forced");for _,entry in pairs(view.gridPreviews)do assert(not entry.visual)end;assert(not view.portraitClock)
  end)
  test("Use now chooses recipient without equipping and retains pending result identity",function()
   state.pendingHueResult={id="jar-1",itemId="rose",inventoryAfter=3};view:open(state,"palette","pip");assert(view:useResult()and view.tab=="pet")
   local before=#calls;assert(view:choosePet("foxfire_wick")and view.petId=="foxfire_wick"and not view.confirmation and #calls==before and active=="puddle")
   assert(view:chooseChannel("secondary")and view.confirmation.pendingResultId=="jar-1"and view.confirmation.channel=="secondary"and view.action.Text=="Use one")
   assert(view:cancelConfirmation()and view.page=="palette"and view.tab=="hue"and view.assignment.pendingResultId=="jar-1"and #sent==0);state.pendingHueResult=nil;view.assignment=nil
  end)
  test("old bay responses cannot clear new claim or unrelated item confirmation",function()
   view:setMachineSession({claimId="old",petId="pip"});local old=view:machineBinding()
   view:setMachineSession({claimId="new",petId="puddle"});view:open(state,"pet","puddle");view:choosePet("orbit");local q=view.confirmation
   assert(not view:machineEquipFinished("Saved",old)and view.confirmation==q and view.machine.claimId=="new")
   view:cancelConfirmation();view:setMachineSession(nil);view:setTab("hue");assert(view:chooseItem("rose"));q=view.confirmation
   assert(not view:machineEquipFinished("Saved",old)and view.confirmation==q)
  end)
 end)
 view:destroy();root:Destroy();assert(ok,problem);return {passed=#cases,cases=cases}
end
