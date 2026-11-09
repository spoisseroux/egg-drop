-- Real editor/reference colors. Notches choose one next dose, never their number.
return function(client,parent)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent);local H=require(game.ReplicatedStorage.Shared.HueCatalog)
 local Run=game:GetService("RunService");local root=Instance.new("Frame");root.Size=UDim2.fromOffset(733,307);root.Parent=parent
 local view;local sent,cases={},{};local serial=0
 local intent=Intent.new({id=function()serial+=1;return "notch-"..serial end,send=function(action,value,revision)table.insert(sent,{action=action,value=value,revision=revision})end,changed=function()if view then view:refresh()end end})
 view=View.new(root,intent,{appearance=function()return{charmVisible=false}end})
 local row={main={rose=2,tide=1,citrus=0,iris=5},secondary=H.emptyCounts()}
 local state={status="Ready",revision=1,nectar=24,inventoryMask=127,hues={},petHues={pip=row},hueInventory={rose=3,tide=0,citrus=2,iris=1,reset=1}}
 local function frames()for _=1,3 do Run.Heartbeat:Wait()end end
 local function test(name,run)run();table.insert(cases,name)end
 local ok,problem=pcall(function()
  view:open(state,"palette","pip");frames()
  test("zero through five exist and only the current saved dose is marked",function()
   for _,bar in pairs(view.bars)do assert(#bar.ticks==6 and bar.stages[0]and bar.stages[5])end
   for stage=0,5 do local tick=view.bars.citrus.stages[stage];assert(tick:GetAttribute("SavedStage")== (stage==0));assert(tick.SavedMark.BackgroundTransparency==(if stage==0 then 0 else 1))end
   assert(view.bars.rose.stages[2]:GetAttribute("SavedStage")and view.bars.iris.stages[5]:GetAttribute("SavedStage"))
  end)
  test("every clicked reference notch confirms current two to three without spending or recoloring",function()
   local visual=view.visual;local body=visual.colors.body
   for stage=0,5 do
    assert(view:chooseNotch("rose",stage)and view.confirmation.itemId=="rose")
    assert(view.confirmDelta.Text=="Rose 2 → 3"and view.title.Text=="Use one Rose fruit?"and view.action.Text=="Use one"and #sent==0)
    assert(view.visual==visual and visual.colors.body==body and state.petHues.pip.main.rose==2)
    local illustration=view.confirmJar;assert(illustration and illustration.Parent==view.body)
    assert(view:cancelConfirmation()and illustration.Parent==nil and not view.confirmJar)
   end
  end)
  test("No Items and Max do not send a use and zero never resets a full hue",function()
   assert(view.bars.tide.value.Text=="No Tide fruit"and view.bars.iris.value.Text=="Iris is maxed")
   for stage=0,5 do assert(not view:chooseNotch("tide",stage)and not view:chooseNotch("iris",stage))end
   assert(#sent==0 and state.petHues.pip.main.iris==5)
  end)
  test("cancelled Citrus art retires before any ordinary tab and never returns on reopen",function()
   assert(view:chooseNotch("citrus",5));local illustration=view.confirmJar;assert(illustration)
   assert(view:cancelConfirmation()and illustration.Parent==nil)
   for _,tab in ipairs({"pet","hue","charm","hue"})do assert(view:setTab(tab));frames();assert(not view.confirmJar)end
   view:close("forced");view:open(state,"palette","pip");assert(not view.confirmJar)
  end)
  test("committed Citrus use sends exactly once then retires all confirmation art and success copy",function()
   assert(view:chooseNotch("citrus",0)and view:activate()and not view:activate());assert(#sent==1)
   local packet=sent[1].value;local illustration=view.confirmJar
   assert(packet.itemId=="citrus"and packet.counts.citrus==0 and packet.counts.rose==2 and packet.channel=="main")
   local receipt={id=packet.id,petId="pip",action="hueUse",revision=2}
   assert(intent:receive({id=packet.id,petId="pip",action="hueUse",status="Saved",receipt=receipt})and intent.pending)
   state.revision=2;state.lastHueResult=receipt;state.petHues.pip.main.citrus=1;state.hueInventory.citrus=1;intent:update(state);frames()
   assert(not intent.pending and not view.confirmation and not view.confirmJar and illustration.Parent==nil and not view.status.Visible)
   for _,tab in ipairs({"pet","charm","hue"})do view:setTab(tab);frames();assert(not view.confirmJar and #view.receiptArt:GetChildren()==0)end
   assert(#sent==1 and view.bars.citrus.stages[1]:GetAttribute("SavedStage"))
  end)
  test("all six reference controls keep44px and the fixed saved portrait survives scroll",function()
   for _,size in ipairs({Vector2.new(350,703),Vector2.new(568,160),Vector2.new(733,307),Vector2.new(1649,971)})do
    root.Size=UDim2.fromOffset(size.X,size.Y);frames();view:layout();frames();local position=view.portrait.AbsolutePosition
    for _,bar in pairs(view.bars)do for _,tick in ipairs(bar.ticks)do
     assert(tick.AbsoluteSize.X>=44 and tick.AbsoluteSize.Y>=44 and tick.TextFits)
     local function luminance(color)local function linear(v)return if v<=.04045 then v/12.92 else((v+.055)/1.055)^2.4 end;return .2126*linear(color.R)+.7152*linear(color.G)+.0722*linear(color.B)end
     local ink,fill=luminance(tick.TextColor3),luminance(tick.BackgroundColor3)
     assert((math.max(ink,fill)+.05)/(math.min(ink,fill)+.05)>=4.5,"stage text contrast below4.5:1")
    end end
    view:ensure(view.bars.rose.stages[5]);frames();assert(view.portrait.AbsolutePosition==position)
   end
  end)
 end)
 view:destroy();root:Destroy();assert(ok,problem);return {passed=#cases,cases=cases}
end
