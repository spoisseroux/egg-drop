-- Studio Client. Hatch eggs (UI-SPEC-REDESIGN-MENUS-2026-11-12 section 3): a text-only
-- egg list without the Feature Egg while Features is flagged off, odds rows rendered
-- once in the pane through OddsText.list (whole percentages summing to 100), the disabled Hatch button with "N more
-- Stars needed", the "something inside" egg beat, a pending feature hatch still
-- opening through "Open saved feature", and the reveal-stage exit when Play again is
-- unavailable (B falls through to close, touch gets Close).
-- Usage: require(PlayerScripts.Client.ZZSpecs.HatchEggsList)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Shop=require(client.EggHatchView)
 local OddsText=require(game.ReplicatedStorage.Shared.OddsText)
 local Run=game:GetService("RunService")
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local root=Instance.new("Frame");root.Name="_HatchEggsList";root.BackgroundTransparency=1;root.Size=UDim2.fromOffset(1920,1080);root.Parent=parent
 local function frames()for _=1,3 do Run.Heartbeat:Wait()end end
 local sent={}
 local view=Shop.new(root,{play=function()end,stopOwner=function()end},function()return true end,function(command,value)table.insert(sent,{command,value})end)
 local ok,problem=xpcall(function()
  test("pure: list order drops the Feature Egg while flagged and keeps it with the flag on",function()
   local order=Shop.liveOrder()
   assert(#order==3 and order[1]=="toy"and order[2]=="material"and order[3]=="hue")
   local on=Shop.liveOrder({Features=true});assert(on[2]=="feature"and #on==4)
  end)
  test("pure: odds rows come from OddsText.list (equal thirds read 34%, 33%, 33%)",function()
   local toy=Shop.oddsRows("toy",{});assert(#toy.rows==3 and toy.per=="1 toy per egg")
   local thirds=OddsText.list({1/3,1/3,1/3});assert(thirds[1]=="34%"and thirds[2]=="33%"and thirds[3]=="33%")
   for i,r in ipairs(toy.rows)do assert(r.value==thirds[i])end
   assert(OddsText.format(1/3)=="33%"and OddsText.format(.5)=="50%"and OddsText.format(.15)=="15%"and OddsText.format(.001)=="<1%")
   assert(Shop.oddsRows("toy",{toyUnlocks={ball=true,bone=true,sparkler=true}}).empty=="All toys owned")
   local hue=Shop.oddsRows("hue",{});assert(#hue.rows==4);for _,r in ipairs(hue.rows)do assert(r.value=="25%"and r.id~="reset")end -- Reset Hue jar dropped 2026-11-13
   local material=Shop.oddsRows("material",{materialAvailable=true});assert(#material.rows>=1)
   for _,r in ipairs(material.rows)do assert(r.value:match("%%$"))end
  end)
  test("pure: Hatch is disabled with N more Stars needed; receipts reopen first",function()
   local short=Shop.hatchAction("toy",{nectar=5});assert(not short.enabled and short.need=="3 more Stars needed"and short.text:find("Hatch"))
   local one=Shop.hatchAction("toy",{nectar=7});assert(one.need=="1 more Star needed")
   assert(Shop.hatchAction("toy",{nectar=8}).enabled)
   local feature=Shop.hatchAction("toy",{nectar=0,pendingFeatureResult={id="f"}});assert(feature.text=="Open saved feature"and feature.enabled)
  end)
  test("pure: the egg beat tilts 6-9 degrees, squashes 4% and hops, then rests",function()
   assert(select(1,Shop.eggBeat(0))==0 and select(1,Shop.eggBeat(Shop.BeatLength))==0)
   local peak,minSquash,maxHop=0,1,0
   for i=1,34 do local r,s,h=Shop.eggBeat(i/100,9,1);peak=math.max(peak,math.abs(r));minSquash=math.min(minSquash,s);maxHop=math.max(maxHop,h)end
   assert(peak<=9.01 and peak>=5,"tilt "..peak);assert(minSquash>=.959 and minSquash<1,"squash "..minSquash);assert(maxHop>0)
   assert(Shop.nextBeatGap(0)==2.4 and math.abs(Shop.nextBeatGap(1)-3.6)<1e-9)
  end)
  test("pure: reveal exit is wait / play / close",function()
   assert(Shop.revealExit(false,false)=="wait"and Shop.revealExit(true,true)=="play"and Shop.revealExit(true,false)=="close")
  end)
  for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354)})do
   test(tostring(size).." built list: no Feature Egg row, odds in the pane, selection swaps the preview",function()
    root.Size=UDim2.fromOffset(size.X,size.Y);frames()
    view:open({status="Ready",revision=1,nectar=128,toyUnlocks={},materialUnlocks={},materialAvailable=true});frames()
    assert(view.shopRoot.Visible and not view.card.Visible)
    local column=view.body:FindFirstChild("EggColumn")
    assert(column and column:FindFirstChild("Recipe_toy")and column:FindFirstChild("Recipe_material")and column:FindFirstChild("Recipe_hue"))
    assert(column:FindFirstChild("Recipe_feature")==nil,"Feature Egg row is hidden by the flag")
    assert(not view:selectRecipe("feature"))
    for _,row in ipairs({"Recipe_toy","Recipe_material","Recipe_hue"})do assert(column[row].AbsoluteSize.Y>=44)end
    assert(view:selectRecipe("toy")or view.selected=="toy");frames()
    assert(view.shopPanel:GetAttribute("SelectedEgg")=="toy"and view.eggName.Text=="Toy Egg")
    local odds=view.oddsHolder:GetChildren();assert(#odds==3)
    local shown={};for _,row in ipairs(odds)do table.insert(shown,row:GetAttribute("OddsText"))end;table.sort(shown);assert(table.concat(shown,",")=="33%,33%,34%")
    assert(view:selectRecipe("hue"));frames();assert(view.shopPanel:GetAttribute("OddsRows")==4 and view.eggName.Text=="Hue Egg")
    -- Keyboard W / S / Up / Down move the selection and clamp at the ends.
    assert(view:moveRecipe(-1)and view.selected=="material"and view:moveRecipe(-1)and view.selected=="toy"and not view:moveRecipe(-1))
    assert(view:moveRecipe(1)and view.selected=="material")
    view:close("close")
   end)
  end
  -- Play-forever F2: restricted players (paid random items) see the fixed next item, never odds.
  test("pure: a restricted player's odds block is one Next line from nextFixed",function()
   local UICopy=require(game.ReplicatedStorage.Shared.UICopy)
   local Toys=require(game.ReplicatedStorage.Shared.ToyCatalog)
   local first=Toys.PaidOrder[1]
   local r=Shop.oddsRows("toy",{restricted=true,nextFixed={toy=first}})
   assert(r.restricted and #r.rows==1 and r.rows[1].name==UICopy.get("hatch.next.line",{item=Toys.ById[first].name})and r.rows[1].value=="")
   local done=Shop.oddsRows("toy",{restricted=true,nextFixed={}})
   assert(done.restricted and done.rows[1].name==UICopy.get("hatch.next.done"),"nothing left reads All collected")
   assert(not Shop.oddsRows("toy",{restricted=false,nextFixed={toy=first}}).restricted,"unrestricted players keep the odds")
  end)
  test("built: restricted pane shows Next; the stamp card and stamp row moved to Quests (QA v2)",function()
   local UICopy=require(game.ReplicatedStorage.Shared.UICopy)
   local Toys=require(game.ReplicatedStorage.Shared.ToyCatalog)
   root.Size=UDim2.fromOffset(1920,1080);frames()
   view:open({status="Ready",revision=4,nectar=128,toyUnlocks={},materialUnlocks={},materialAvailable=true,restricted=true,
    nextFixed={toy=Toys.PaidOrder[1]},stamps=6,stampCard={rewards={4,4,5,5,6,6,12},onCard=6,next=7},dailyAvailable=true,dailyDay="20000",dailyBonus=12});frames()
   view:selectRecipe("toy");frames()
   assert(view.shopPanel:GetAttribute("OddsRestricted")==true and view.shopPanel:GetAttribute("OddsRows")==1)
   assert(view.oddsLabel.Text==string.upper(UICopy.get("hatch.next.label")))
   local column=view.body:FindFirstChild("EggColumn")
   assert(column and not column:FindFirstChild("StampCard",true)and not column:FindFirstChild("DailyNectar"),"no daily state on Hatch eggs")
   assert(not view.card:FindFirstChild("Wallet",true),"the card's old Stars chip is gone; the header wallet is the one counter")
   assert(view.shopHeader.wallet and view.shopHeader.wallet.amount.Text~="","header wallet shows the balance")
   view:close("close")
  end)
  test("short on Stars: Hatch disabled with the need line",function()
   root.Size=UDim2.fromOffset(1920,1080);frames()
   view:open({status="Ready",revision=1,nectar=3,toyUnlocks={},materialUnlocks={},materialAvailable=true});frames()
   view:selectRecipe("toy");frames()
   assert(not view.action.Interactable and view.needLine.Visible and view.needLine.Text=="5 more Stars needed")
   local before=#sent;view:actPrimary();assert(#sent==before)
   view:close("close")
  end)
  test("a pending feature hatch still opens through Open saved feature",function()
   local opened
   view.onOpenFeature=function(purchase)opened=purchase end
   view:open({status="Ready",revision=2,nectar=0,pendingFeatureResult={id="feature-1",featureId="horns"},toyUnlocks={},materialUnlocks={}});frames()
   assert(view.action.Text=="Open saved feature"and view.action.Interactable)
   view:actPrimary();assert(opened==false,"Open saved feature routes to the saved receipt without a purchase")
   view.onOpenFeature=nil;view:close("close")
  end)
  test("3D egg: a failed mesh load keeps the 2D shell; a type swap changes the shells' TextureID",function()
   local Preview=require(client.EggPreview3D);local Models=require(game.ReplicatedStorage.Shared.EggModels)
   local real=Preview.createMesh
   local okCase,why=pcall(function()
    Preview.resetCache();Preview.createMesh=function()error("stubbed CreateMeshPartAsync failure")end
    root.Size=UDim2.fromOffset(1920,1080);frames();view.shopKey=nil -- rebuild the pane with the stub
    view:open({status="Ready",revision=3,nectar=128,toyUnlocks={},materialUnlocks={},materialAvailable=true});frames()
    assert(Preview.loadState()=="failed","stubbed load must fail, got "..Preview.loadState())
    assert(view.egg3D and not view.egg3D.loaded and not view.egg3D.viewport.Visible,"3D viewport shown without meshes")
    assert(view.eggHolder.Visible and view.eggArt and view.eggArt.Parent==view.eggHolder,"2D shell fallback missing")
    view:close("close")
    -- Plain MeshParts stand in for the uploaded meshes.
    Preview.resetCache();Preview.createMesh=function()return Instance.new("MeshPart")end
    local well=Instance.new("Frame");well.Size=UDim2.fromOffset(424,152);well.Parent=root
    local egg=Preview.new(well,{});for _=1,10 do if egg.loaded then break end;frames()end
    assert(egg.loaded and egg.viewport.Visible,"3D egg did not build from the templates")
    local top,bottom,core=egg.parts.TopShell,egg.parts.BottomShell,egg.parts.Core
    assert(top.Size==Models.Egg.TopShell.size and core.Material==Enum.Material.Neon and top.Material==Enum.Material.SmoothPlastic,"sizes/materials not applied")
    egg:setType("toy");assert(top.TextureID==Models.Types.toy.colorMap and bottom.TextureID==Models.Types.toy.colorMap and core.Color==Models.Types.toy.core)
    egg:setType("hue");assert(top.TextureID==Models.Types.hue.colorMap and bottom.TextureID==Models.Types.hue.colorMap and core.Color==Models.Types.hue.core,"type swap kept the old ColorMap")
    assert(egg:hatch(),"hatch pop needs a loaded egg")
    egg:setActive(true);frames();egg:setActive(false);assert(egg.connection==nil,"loop keeps running while hidden")
    egg:destroy();well:Destroy()
   end)
   Preview.createMesh=real;Preview.resetCache()
   assert(okCase,why)
  end)
  test("reveal stage: B falls through and Play again becomes Close when play is unavailable",function()
   local stage={backs=0,buttons=nil}
   function stage:back()self.backs+=1;return true end
   function stage:setButtons(states)self.buttons=states end
   function stage:destroy()end
   view.shade.Visible=true;view.reveal=stage;view.state={lastHatch={id="h",petId="pip"},status="Busy"}
   view.ackReady=true;view.action.Interactable=false
   assert(view:revealBack()==false and stage.backs==0,"B must fall through to close() when play is unavailable")
   view:syncRevealButtons();assert(stage.buttons.play.text=="Close"and stage.buttons.play.enabled==true,"touch players need a way out")
   view.action.Interactable=true
   assert(view:revealBack()==true and stage.backs==1)
   view:syncRevealButtons();assert(stage.buttons.play.text~="Close")
   view.ackReady=false;view.action.Interactable=false;assert(view:revealBack()==true,"during the intro B settles the stage")
   view.reveal=nil;view.state={};view.shade.Visible=false
  end)
  test("QA v2: the shop shade is the shared full-screen one, opened once and closed with the screen",function()
   local Kit=require(client.DeckKit)
   for _,size in ipairs({Vector2.new(1920,1080),Vector2.new(812,354)})do
    root.Size=UDim2.fromOffset(size.X,size.Y);frames()
    view:open({status="Ready",revision=5,nectar=20,toyUnlocks={},materialUnlocks={},materialAvailable=true});frames()
    local dim=view.shopDim
    assert(dim and dim:GetAttribute("CoversScreen")and Kit.shadeIsOpen(view),"shade on the stack at "..tostring(size))
    assert(dim.Visible and dim.BackgroundTransparency<1,"it dims on phones too")
    view:close("close");assert(not Kit.shadeIsOpen(view),"closed with the screen")
   end
  end)
  test("QA v2 R1.9: the egg list scrolls once it outgrows its window (offset units, not the scaled size)",function()
   root.Size=UDim2.fromOffset(1920,1080);frames()
   view:open({status="Ready",revision=6,nectar=20,toyUnlocks={},materialUnlocks={},materialAvailable=true});frames()
   assert(view.body.ScrollingEnabled and view.body.ScrollingDirection==Enum.ScrollingDirection.Y)
   assert(Shop.listWindow(view.body)==view.body.Size.Y.Offset,"the window is measured in offsets")
   local probe=Instance.new("Frame");probe.Size=UDim2.new(1,0,0,50);probe.Parent=root
   assert(Shop.listWindow(probe)==50);probe.Size=UDim2.fromScale(1,.5);assert(Shop.listWindow(probe)==probe.AbsoluteSize.Y);probe:Destroy()
   view:close("close")
  end)
  test("QA v2 (R2.5 slice): the footer hints follow the input; the legend shows once a session",function()
   local UICopy=require(game.ReplicatedStorage.Shared.UICopy)
   local pad=Shop.hintPairs("Gamepad");assert(#pad==3 and pad[1][1]=="+"and pad[2][1]=="A"and pad[3][1]=="B")
   local key=Shop.hintPairs("Keyboard");assert(#key==3 and key[2][1]=="ENTER"and key[2][2]==UICopy.get("r1.hatchHints.hatch"))
   assert(#Shop.hintPairs("Touch")==0,"touch reads the legend line, no chips")
   for _,kind in ipairs({"Keyboard","Gamepad","Touch"})do local line=Shop.legendText(kind);assert(type(line)=="string"and line~=""and not line:find("input.legend",1,true))end
   Shop.resetLegend();root.Size=UDim2.fromOffset(1920,1080);frames()
   view:open({status="Ready",revision=7,nectar=20,toyUnlocks={},materialUnlocks={},materialAvailable=true});frames()
   assert(view.hintRow and view.legendLine and view.legendLine.Visible and view.legendLine.TextFits,"legend on the first open")
   assert(view.hintRow:GetAttribute("HintInput")==Shop.inputKind())
   view:close("close")
   view:open({status="Ready",revision=8,nectar=20,toyUnlocks={},materialUnlocks={},materialAvailable=true});frames()
   assert(not view.legendLine.Visible,"once a session");view:close("close")
  end)
  test("QA v2 R1.7: the egg preview measures in offsets (the panel UIScale no longer shifts it right)",function()
   local Preview=require(client.EggPreview3D)
   local w,h=Preview.wellSize(UDim2.fromOffset(424,152),Vector2.new(509,182));assert(w==424 and h==152)
   w,h=Preview.wellSize(UDim2.fromScale(1,1),Vector2.new(300,100));assert(w==300 and h==100)
   local g={cx=212,cy=80,ew=80,eh=104}
   for i=0,20 do local x,y=Preview.sparkleSpot(g,i/20,(i%3)/3)
    assert(math.abs(x-g.cx)<=g.ew*.7 and math.abs(y-g.cy)<=g.eh*.7,"sparkles start on the egg's outline")end
  end)
 end,function(e)return tostring(e).." | "..debug.traceback()end)
 view.shade:Destroy();root:Destroy()
 if not ok then error(problem,0)end
 return{passed=#cases,cases=cases}
end
