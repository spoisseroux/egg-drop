return function(client,parent)
 local View=require(client.HueEggView);local Hue=require(client.HueIntent);local Material=require(client.MaterialIntent)
 local Run=game:GetService("RunService");local Catalog=require(game.ReplicatedStorage.Shared.MaterialCatalog)
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(900,720);root.Parent=parent
 local view;local sent,cases={},{};local equips=0;local serial=0
 local function changed()if view then view:refresh()end end
 local hue=Hue.new({id=function()return "unused"end,send=function()error("material UI sent a hue operation")end,changed=changed})
 local material=Material.new({id=function()serial+=1;return "material-ui-"..serial end,send=function(action,value,revision)table.insert(sent,{action=action,value=value,revision=revision})end,changed=changed})
 view=View.new(root,hue,{materialIntent=material,activePet=function()return "pip"end,equipPet=function()equips+=1;return true end,appearance=function()return{charmVisible=false}end})
 local state={revision=1,status="Ready",inventoryMask=127,nectar=64,hueInventory={},petHues={},materialAvailable=true,materialUnlocks={gloss=true},petMaterials={pip="standard",puddle="gloss"}}
 local function frames()for _=1,3 do Run.Heartbeat:Wait()end end
 local function test(name,run)run();table.insert(cases,name)end
 local ok,problem=pcall(function()
  test("Customize icon tabs keep 44 px targets and Materials owns saved preview without a paid selection",function()
   view:open(state,"materials","pip");frames()
   -- Redesign 2.1: Kit.tabs segments (Hue / Charm / Materials / Toys), no rail, no Pet or Wardrobe tab.
   for _,tab in pairs(view.editorTabs)do assert(tab.Visible and tab.AbsoluteSize.X>=44 and tab.AbsoluteSize.Y>=44)end
   assert(view.editorTabs.pet==nil and view.editorTabs.wardrobe==nil and view.tabRail==nil)
   assert(view.tab=="materials"and view.chromeTabs.selected==3 and view.chromeRoot.Visible and not view.card.Visible)
   assert(view.materialPanel.root.Visible and view.portrait.Visible and view:appearance().finish=="standard"and #sent==0 and equips==0)
   assert(view.materialPanel.rows.standard.Visible and view.materialPanel.rows.gloss.Visible and not view.materialPanel.rows.metal.Visible)
  end)
  test("free per-pet material choice stays visually current until exact owner snapshot",function()
   assert(material:equip("pip","gloss")and #sent==1);view:refresh();assert(view:appearance().finish=="standard")
   local q=sent[1].value;local r={id=q.id,action="materialEquip",petId="pip",finishId="gloss",selectedBefore="standard",selectedAfter="gloss",cost=0,catalogVersion=1,revision=2}
   assert(material:receive({id=q.id,action="materialEquip",petId="pip",status="Saved",receipt=r})and material.pending)
   state.revision=2;state.petMaterials.pip="gloss";state.lastMaterialResult=r;hue:update(state);material:update(state);frames()
   assert(not material.pending and view:appearance().finish=="gloss"and state.nectar==64 and equips==0)
  end)
  test("Material receipt Use now chooses recipient without making that pet active",function()
   state.pendingMaterialResult={id="material-paid",finishId="gloss",revision=2,catalogVersion=1};view:open(state,"materials","pip");frames()
   assert(view.page=="materialReceipt"and view.materialPanel.useNow.Visible and view.action.Text=="Keep")
   view.materialAssignment={resultId="material-paid",finishId="gloss"};view.page="palette";view.tab="pet";view:refresh()
   assert(view:choosePet("puddle")and equips==0 and view.petId=="puddle"and view.tab=="materials")
   assert(sent[#sent].value.resultId=="material-paid"and sent[#sent].value.expectedFinish=="gloss"and view:activePet()=="pip")
   material:receive({id=sent[#sent].value.id,action="materialEquip",petId="puddle",status="Rejected",reason="Busy"});state.pendingMaterialResult=nil
  end)
  test("Material receipt fits its round finish sample and adjacent measured actions without a blank footer gap",function()
   for _,size in ipairs({Vector2.new(900,720),Vector2.new(749,381),Vector2.new(568,160),Vector2.new(350,703)})do
    root.Size=UDim2.fromOffset(size.X,size.Y)
    for _,id in ipairs({"gloss","matte"})do
     state.pendingMaterialResult={id="sample-"..id..tostring(size),finishId=id,revision=state.revision,catalogVersion=1}
     view:open(state,"materials","pip");frames()
     local use=view.materialPanel.useNow;local keep=view.action;local sample=view.materialPanel.reveal.jar
     assert(view.card.AbsoluteSize.X<=470 and sample and sample:FindFirstChild("FinishViewport")and sample:FindFirstChild("GroundShadow"))
     local viewport=sample.FinishViewport
     assert(viewport:IsA("ViewportFrame")and viewport.CurrentCamera and viewport:FindFirstChildWhichIsA("WorldModel"))
     assert(math.abs(sample.AbsoluteSize.X-sample.AbsoluteSize.Y)<.1 and sample.AbsoluteSize.X<=view.materialPanel.art.AbsoluteSize.X+.1)
     assert(sample:GetAttribute("FinishId")==id and sample:GetAttribute("PreviewBackend")~=nil)
     assert(use.Parent==view.card and use.AbsolutePosition.Y==keep.AbsolutePosition.Y and use.AbsolutePosition.X+use.AbsoluteSize.X+7<=keep.AbsolutePosition.X)
     for _,node in ipairs({use,keep})do assert(node.TextFits and node.AbsoluteSize.X>=44 and node.AbsoluteSize.Y>=44)end
     if size.Y>=280 then
      local contentBottom=view.body.AbsolutePosition.Y+view.body.CanvasSize.Y.Offset
      assert(math.abs(keep.AbsolutePosition.Y-contentBottom)<=16,"Receipt footer separated from measured result")
      assert(not view.body.ScrollingEnabled,"Unconstrained receipt kept a tall empty scroll sheet")
     end
     view:close("forced");assert(not sample.Parent and not view.materialPanel.reveal.resultId,"Closed receipt retained its finish sample")
    end
   end
   state.pendingMaterialResult=nil
  end)
  test("short landscape Materials starts with complete choices and retires receipt art on Use now",function()
   root.Size=UDim2.fromOffset(749,381);view:open(state,"materials","pip");frames()
   local panel=view.materialPanel
   -- Redesign 2.3: owned finishes are cards in the chrome grid, 3 px in from its edges.
   assert(not panel.title.Visible and not panel.note.Visible and panel.rows.standard.Position.Y.Offset==3)
   local grid=view.chromeGrid
   assert(panel.rows.gloss.AbsolutePosition.Y+panel.rows.gloss.AbsoluteSize.Y<=grid.AbsolutePosition.Y+grid.AbsoluteSize.Y)
   state.pendingMaterialResult={id="sample-retire-target",finishId="gloss",revision=state.revision,catalogVersion=1};view:open(state,"materials","pip");frames()
   local sample=panel.reveal.jar;panel.options.useNow(state.pendingMaterialResult);frames()
   assert(not sample.Parent and not panel.reveal.resultId and not panel.useNow.Visible)
   state.pendingMaterialResult=nil;view:close("forced")
  end)
  test("Materials keeps its live pet fixed during right-pane scrolling at compact and portrait sizes",function()
   for _,size in ipairs({Vector2.new(733,307),Vector2.new(568,160),Vector2.new(812,354)})do
    root.Size=UDim2.fromOffset(size.X,size.Y);view:open(state,"materials","pip");frames();local p=view.portrait.AbsolutePosition
    local tab=view.editorTabs.materials
    assert(tab and tab.AbsoluteSize.Y>=44,"Materials tab under 44 px at "..tostring(size))
    assert(view.chromeGrid.Active,"card grid must claim native wheel input")
    view.chromeGrid.CanvasPosition=Vector2.new(0,100);frames();assert(view.portrait.AbsolutePosition==p,"pinned portrait moved with the grid at "..tostring(size))
    for id,node in pairs(view.materialPanel.rows)do if node.Visible then assert(node.CardParts.CardName.TextFits and node.AbsoluteSize.Y>=44,id.." card clipped at "..tostring(size))end end
   end
  end)
  test("full and unavailable purchase states never offer a paid action",function()
   state.materialUnlocks={};for _,id in ipairs(Catalog.PaidOrder)do state.materialUnlocks[id]=true end;view:open(state,"materialBuy","pip");frames();assert(view.action.Text=="All materials owned"and not view.action.Interactable and not view:activate())
   state.materialUnlocks={};state.materialAvailable=false;view:open(state,"materialBuy","pip");frames();assert(not view.action.Interactable and not view:activate())
  end)
  test("reopened Keep retry resends the captured acknowledgement instead of starting a blocked new one",function()
   state.materialAvailable=true;state.materialUnlocks.gloss=true;state.pendingMaterialResult={id="keep-retry",finishId="gloss",revision=state.revision,catalogVersion=1}
   view:open(state,"materials","pip");assert(view:activate());local packet=sent[#sent]
   assert(packet.action=="materialAck"and packet.value.resultId=="keep-retry")
   assert(material:receive({id=packet.value.id,action="materialAck",status="Retrying"}))
   view:close("forced");view:open(state,"materials","pip");assert(view.action.Text=="Try again"and view:activate())
   assert(sent[#sent].value==packet.value and sent[#sent].revision==packet.revision)
   local r={id=packet.value.id,action="materialAck",revision=state.revision+1,catalogVersion=1,cost=0,acknowledgedResultId="keep-retry"}
   assert(material:receive({id=r.id,action=r.action,status="Saved",receipt=r}));state.revision=r.revision;state.lastMaterialResult=r;state.pendingMaterialResult=nil;hue:update(state);material:update(state)
   assert(not material.pending)
  end)
  test("closing Use now then keeping its receipt cannot hijack later ordinary Pet selection",function()
   state.pendingMaterialResult={id="close-target",finishId="gloss",revision=state.revision,catalogVersion=1};view:open(state,"materials","pip")
   view.materialPanel.options.useNow(state.pendingMaterialResult);assert(view.materialAssignment and view.tab=="pet")
   view:close("forced");view:open(state,"materials","pip");assert(not view.materialAssignment and view.page=="materialReceipt"and view:activate())
   local q=sent[#sent].value;local r={id=q.id,action="materialAck",revision=state.revision+1,catalogVersion=1,cost=0,acknowledgedResultId="close-target"}
   material:receive({id=q.id,action="materialAck",status="Saved",receipt=r});state.revision=r.revision;state.lastMaterialResult=r;state.pendingMaterialResult=nil;hue:update(state);material:update(state)
   view:setTab("pet");assert(view:choosePet("puddle")and view.confirmation.equipPetId=="puddle"and not material.pending and not view.materialAssignment)
   view:cancelConfirmation()
  end)
 end)
 view:destroy();material:destroy();root:Destroy();assert(ok,problem);return {passed=#cases,cases=cases}
end
