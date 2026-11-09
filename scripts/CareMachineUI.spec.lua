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
    local tabY=view.hueTab.AbsolutePosition.Y;local portrait=view.portrait.AbsolutePosition
    for _,node in ipairs({view.petTab,view.hueTab,view.charmTab,view.closeButton,view.mainTab,view.secondaryTab})do
     assert(node.Visible and inside(node,view.card),node.Name.." escaped card at "..tostring(size))
     assert(node.AbsoluteSize.X>=44 and node.AbsoluteSize.Y>=44 and node.TextFits,node.Name.." text/gesture shrank at "..tostring(size))
    end
    assert(inside(view.portrait,view.card)and view.portrait.Parent==view.card)
    view.body.CanvasPosition=Vector2.new(0,120);frames();assert(view.portrait.AbsolutePosition==portrait and view.hueTab.AbsolutePosition.Y==tabY)
    view:setTab("charm");frames();assert(view.hueTab.AbsolutePosition.Y==tabY and view.charmToggle.Parent==view.card and view.charmOff.Parent==view.card)
    for _,node in ipairs({view.charmToggle,view.charmOff})do assert(inside(node,view.card)and node.AbsoluteSize.Y>=44 and node.TextFits,node.Name.." clipped")end
    for id,node in pairs(view.shapes)do if node.Visible then
     if size==Vector2.new(553,381)then assert(math.abs(node.AbsoluteSize.X-233)<1,"fixture lost exact233px illustrated row")end
     local icon=view.shapeIcons[id];assert(node.Text==""and inside(icon.tile,node)and inside(icon.label,node)and icon.label.TextFits,"illustrated charm escaped row")
     local p,s,q,t=icon.tile.AbsolutePosition,icon.tile.AbsoluteSize,icon.label.AbsolutePosition,icon.label.AbsoluteSize
     assert(q.X>=p.X+s.X+11.5 or q.Y>=p.Y+s.Y+11.5,"charm name overlaps its icon at "..tostring(size))
     if icon.check.Visible then
      assert(inside(icon.check,node)and icon.check.TextFits,"selected mark clipped")
      local a,b=icon.check.AbsolutePosition,icon.check.AbsoluteSize
      assert(q.X+t.X<=a.X-11.5 or q.Y>=a.Y+b.Y+11.5,"charm name overlaps selected mark")
     end
    end end
    if size.X>=500 and size.Y>=220 then
     view:setTab("pet");frames();assert(not view.targetTitle.Visible,"ordinary owned grid retained redundant heading")
     assert(inside(view.targets.pip,view.body),"first complete owned square cannot fit its short-phone viewport")
     assert(inside(view.targets[active],view.body)and view.gridPreviews[active].active.Text=="✓ Active"and view.gridPreviews[active].active.TextFits)
    end
   end
   root.Size=UDim2.fromOffset(900,720);frames();view:layout();frames();assert(view.petName.Visible and view.petName.TextFits,"size-only return from constrained layout lost the saved pet name")
  end)
  test("every selected charm keeps its own check glyph clear of wrapped names at constrained size",function()
   root.Size=UDim2.fromOffset(568,160);view:open(state,"charm","pip")
   local appearance=view.options.appearance
   for _,shape in ipairs({"dot","ring","pebble"})do
    view.options.appearance=function()return {charmVisible=true,charmShape=shape}end;view:refresh();frames()
    local entry=view.shapeIcons[shape];local label,check=entry.label,entry.check
    assert(check.Visible and check.TextFits and label.TextFits and inside(check,view.shapes[shape]))
    local p,s,q,t=label.AbsolutePosition,label.AbsoluteSize,check.AbsolutePosition,check.AbsoluteSize
    assert(p.X+s.X<=q.X-11.5 or p.Y>=q.Y+t.Y+11.5,"wrapped selected "..shape.." label overlaps its check glyph")
   end
   view.options.appearance=appearance;view:refresh()
  end)
  test("owned live grid is bounded and closes visible model generations",function()
   root.Size=UDim2.fromOffset(900,720);view:open(state,"pet","pip");frames();local live=0
   for _,entry in pairs(view.gridPreviews)do if entry.visual then live+=1;assert(entry.button.Size.X.Offset==entry.button.Size.Y.Offset)end end
   assert(live>0 and live<=7 and view.portraitClock)
   view:close("forced");for _,entry in pairs(view.gridPreviews)do assert(not entry.visual)end;assert(not view.portraitClock)
  end)
  test("Use now chooses recipient without equipping and retains pending result identity",function()
   state.pendingHueResult={id="jar-1",itemId="rose",inventoryAfter=3};view:open(state,"palette","pip");assert(view:useResult()and view.tab=="pet")
   local before=#calls;assert(view:choosePet("foxfire_wick")and view.petId=="foxfire_wick"and not view.confirmation and #calls==before and active=="puddle")
   view:chooseChannel("secondary");assert(view:activate()and view.confirmation.pendingResultId=="jar-1"and view.confirmation.channel=="secondary")
   assert(view:cancelConfirmation()and view.page=="receipt"and #sent==0);state.pendingHueResult=nil
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
