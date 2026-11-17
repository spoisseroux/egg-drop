-- Customization Egg client, slices 3 and 4 (plan 2026-11-16 §4, §5): pure rules only.
--  * Hatch eggs: the odds come straight from the integer table and add to 100; one Charm row
--    names the missing shapes; the pity line counts down; restricted shows the named next item.
--  * HueIntent: the lookBuy quote binds pool, price, mode, missing charms and the pity counter;
--    finishUse / finishClear packets carry the expected finish row.
--  * Finish tab: look names, card states, refusals at the caps, Original per axis.
--  * Reveal: tiers and banner kinds for finish jars and charms; every item has jar art.
--  * Render: the dose look clamps to the display stops and falls back toward 0.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.LookEggClient)(PlayerScripts.Client, gui)
return function(client,gui)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local Look=require(Shared.LookEggCatalog);local Copy=require(Shared.UICopy)
 local Shop=require(client.EggHatchView);local Intent=require(client.HueIntent);local Finish=require(client.FinishPanel)
 local Cue=require(client.HatchRarityCue);local Stage=require(client.HatchItemStage);local JarModel=require(client.JarModel)
 local Materials=require(client.PetMaterials)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function sum(rows)local total=0;for _,r in ipairs(rows)do if not r.info then total+=tonumber(string.match(r.value,"^(%d+)%%$"))end end;return total end

 test("odds rows are the integer table, add to 100, and carry one Charm row and the pity line",function()
  local all=Shop.lookOdds({lookAvailable=true})
  assert(#all.rows==9 and sum(all.rows)==100 and all.rows[1].id=="rose"and all.rows[1].value=="17%"and all.rows[5].value=="10%")
  local charm=all.rows[8];assert(charm.id=="charm"and charm.value=="6%"and string.find(charm.label,"Snowflake, Ring, Pebble",1,true),charm.label)
  assert(all.note==Copy.get("hatch.look.pity",{count=15})and all.rows[9].info and all.rows[9].name==Copy.get("hatch.look.pityShort",{count=15}),"the pity line is its own row")
  assert(all.shapes==Copy.get("hatch.look.missing",{each="2%",shapes="Snowflake, Ring, Pebble"}))
  local two=Shop.lookOdds({charmUnlocks={dot=true},lookCharmMisses=13,lookAvailable=true})
  assert(sum(two.rows)==100 and two.rows[8].value=="4%"and not string.find(two.rows[8].label,"Snowflake",1,true)and two.note==Copy.get("hatch.look.pity",{count=2}))
  local due=Shop.lookOdds({lookCharmMisses=14});assert(due.note==Copy.get("hatch.look.pityOne"))
  local none=Shop.lookOdds({charmUnlocks={dot=true,ring=true,pebble=true}});assert(#none.rows==8 and none.shapes==nil and sum(none.rows)==100 and none.note==Copy.get("hatch.look.allCharms"))
  assert(Shop.lookOdds({lookAvailable=false}).empty==Copy.get("hatch.look.notReady"))
 end)
 test("restricted accounts see the named next item and the charm countdown",function()
  local r=Shop.lookOdds({restricted=true,lookCharmMisses=3,hueInventory={rose=1}})
  assert(r.restricted and r.rows[1].name==Copy.get("hatch.next.line",{item="Tide"})and r.rows[2].name==Copy.get("hatch.look.restrictedCharm",{count=9}))
  local due=Shop.lookOdds({restricted=true,lookCharmMisses=11});assert(due.rows[1].name==Copy.get("hatch.next.line",{item="Snowflake charm"}))
 end)
 test("the egg list sells the Customization Egg instead of the Hue Egg; pending labels name the result",function()
  local order=Shop.liveOrder({Features=false,MaterialEgg=false});assert(order[2]=="look"and not table.find(order,"hue"))
  assert(Shop.hatchAction("look",{nectar=12,lookAvailable=true}).enabled and not Shop.hatchAction("look",{nectar=11,lookAvailable=true}).enabled)
  assert(not Shop.hatchAction("look",{nectar=99,lookAvailable=false}).enabled)
  assert(Shop.hatchAction("look",{pendingHueResult={id="x",itemId="charm_ring"}}).text==Copy.get("hatch.look.openSaved.charm"))
  assert(Shop.hatchAction("look",{pendingHueResult={id="x",itemId="gloss"}}).text==Copy.get("hatch.look.openSaved.finish"))
  assert(Shop.hatchAction("look",{pendingHueResult={id="x",itemId="rose"}}).text=="Open saved jar")
 end)
 test("the lookBuy quote binds the odds the player saw",function()
  local q=Intent.lookQuote({lookSelectionMode="random",lookPoolVersion=1,charmUnlocks={ring=true},lookCharmMisses=4})
  assert(q.poolVersion==1 and q.price==Look.Price and q.selectionMode=="random"and table.concat(q.missingCharms,",")=="dot,pebble"and q.charmMisses==4 and q.fixedItemId==nil)
  local f=Intent.lookQuote({lookSelectionMode="fixed",lookCharmMisses=11});assert(f.fixedItemId=="charm_dot")
  local sent={}
  local intent=Intent.new({id=function()return "op"end,send=function(action,value)table.insert(sent,{action,value})end})
  intent:update({status="Ready",revision=4,nectar=30,inventoryMask=1,lookAvailable=true,lookSelectionMode="random",petFinish={pip={sheen=1,jelly=0}},finishInventory={gloss=1}})
  assert(intent:lookHatch()and sent[1][1]=="lookBuy"and sent[1][2].id=="4:op"and sent[1][2].price==Look.Price)
  intent.pending=nil
  assert(intent:finishUse("pip","gloss")and sent[2][1]=="finishUse"and sent[2][2].finish.sheen==1 and sent[2][2].itemId=="gloss")
  intent.pending=nil
  assert(intent:finishClear("pip","sheen")and sent[3][1]=="finishClear"and sent[3][2].axis=="sheen")
  intent.pending=nil
  assert(not intent:finishClear("pip","jelly")and intent.message=="Original","Jelly is already original")
  intent:update({status="Ready",revision=5,nectar=30,inventoryMask=1,lookAvailable=false})
  assert(not intent:lookHatch()and intent.message==Copy.get("hatch.look.reason.NotReady"))
 end)
 test("Finish tab: look names, card states and refusals at the caps",function()
  assert(Finish.lookName({sheen=0,jelly=0})=="Original"and Finish.lookName({sheen=3,jelly=0})=="Glassy"and Finish.lookName({sheen=0,jelly=2})=="Jelly")
  assert(Finish.lookName({sheen=-3,jelly=3})=="Clear Jelly Chalky")
  local state={petFinish={pip={sheen=3,jelly=1}},finishInventory={gloss=2,matte=0,jelly=1}}
  local gloss=Finish.card("gloss",state,"pip",true);assert(not gloss.enabled and gloss.reason=="MaxSheen"and gloss.line==Copy.get("r4.customize.finish.maxSheen"))
  local matte=Finish.card("matte",state,"pip",true);assert(not matte.enabled and matte.reason=="EmptyStock")
  local jelly=Finish.card("jelly",state,"pip",true);assert(jelly.enabled and string.find(jelly.line,"→",1,true))
  -- v816 Material tab: pills (Use / Max / ×0), "No Gloss jars", one Back to original for both axes.
  assert(gloss.pill=="max"and matte.pill=="none"and jelly.pill=="use")
  assert(matte.button==Copy.get("r4.customize.finish.noJars",{item="Matte"})and matte.line==Copy.get("r4.customize.finish.eggLink"))
  local clear=Finish.card("original",state,"pip",true);assert(clear.enabled and clear.reset and clear.free and clear.button=="Back to original")
  assert(not Finish.card("original",{petFinish={}},"pip",true).enabled,"already original")
  assert(Finish.canReset({sheen=0,jelly=1})and Finish.canReset({sheen=-1,jelly=0})and not Finish.canReset({sheen=0,jelly=0}))
  assert(Finish.shineWords(0)=="Original"and Finish.shineWords(2)=="Gloss 2/3"and Finish.shineWords(-1)=="Matte 1/3"and Finish.jellyWords(0)=="0/3")
  assert(Finish.noJars({finishInventory={gloss=0,matte=0,jelly=0}})and not Finish.noJars(state))
  assert(not Finish.card("jelly",state,"pip",false).enabled,"never while busy")
 end)
 test("Back to original: Shine then Jelly, and a refused first clear ends it (code review a9960c4, 6)",function()
  local holder=Instance.new("Frame");holder.Parent=gui
  local function rig(status)
   local sent={}
   local intent={status="Ready",pending=nil}
   function intent:finishClear(petId,axis)table.insert(sent,axis);self.pending={action="finishClear"};return true end
   local panel=Finish.new(holder,intent,{canUse=function()return true end})
   local off={petFinish={pip={sheen=2,jelly=1}},finishInventory={}}
   panel:refresh(off,"pip",true)
   assert(panel:act("original")and #sent==1 and sent[1]=="sheen","Shine goes first")
   panel:refresh(off,"pip",true);task.wait();assert(#sent==1,"nothing more while the first is pending")
   intent.pending=nil;intent.status=status
   return panel,sent,intent
  end
  local panel,sent=rig("Rejected")
  panel:refresh({petFinish={pip={sheen=2,jelly=1}},finishInventory={}},"pip",true);task.wait();task.wait()
  assert(#sent==1 and panel.resetQueue==nil,"a refused Shine clear must not clear Jelly")
  panel:destroy()
  local panel2,sent2=rig("Ready")
  panel2:refresh({petFinish={pip={sheen=2,jelly=1}},finishInventory={}},"pip",true);task.wait();task.wait()
  assert(#sent2==1 and panel2.resetQueue==nil,"a Shine clear that did not land ends the reset")
  panel2:destroy()
  local panel3,sent3=rig("Ready")
  panel3:refresh({petFinish={pip={sheen=0,jelly=1}},finishInventory={}},"pip",true);task.wait();task.wait()
  assert(#sent3==2 and sent3[2]=="jelly"and panel3.resetQueue==nil,"Jelly follows a landed Shine clear")
  panel3:destroy();holder:Destroy()
 end)
 test("reveal: finish jars and charms get their tier, banner kind, line and jar art",function()
  assert(Cue.tier("hue",{itemId="gloss"})=="Uncommon"and Cue.tier("hue",{itemId="matte"})=="Uncommon")
  assert(Cue.tier("hue",{itemId="jelly"})=="Rare"and Cue.tier("hue",{itemId="charm_pebble"})=="Rare")
  assert(Stage.resultKind("hue",{itemId="charm_ring"})=="charm"and Stage.resultKind("hue",{itemId="gloss"})=="finish"and Stage.resultKind("hue",{itemId="rose"})=="hue")
  assert(Stage.bannerText("Rare","charm")==Copy.get("hatch.reveal.banner",{tier="RARE",kind="CHARM"}))
  assert(Stage.describe("hue",{itemId="charm_dot"})==Copy.get("hatch.reveal.describe.charm.dot")and Stage.describe("hue",{itemId="jelly"})==Copy.get("hatch.reveal.describe.finishJar.jelly"))
  for _,id in ipairs(Look.ItemOrder)do assert(JarModel.known(id),id.." has jar art")end
  assert(JarModel.artId("charm_ring")=="charm"and JarModel.artId("heart")==nil)
 end)
 test("render: the dose look clamps to the stops and falls back toward 0",function()
  local s,j=Materials.dose({sheen=9,jellyStage=7});assert(s==Look.SheenStops and j==Look.JellyStops)
  s,j=Materials.dose({});assert(s==0 and j==0)
  local pack=Instance.new("Folder")
  local function add(name)local a=Instance.new("SurfaceAppearance");a.Name=name;a:SetAttribute("NativeVerified",true);a:SetAttribute("MaterialVersion",1);a:SetAttribute("MaterialProfile",name);a.Parent=pack end
  add("BodySheenP1");add("BodyJelly")
  assert(Materials.doseProfile(pack,3,0)=="BodySheenP1","+3 and +2 unverified fall back to +1")
  assert(Materials.doseProfile(pack,-2,0)=="Body","no verified Matte stop: Original")
  assert(Materials.doseProfile(pack,0,2)=="BodyJelly"and Materials.doseProfile(pack,1,2)=="BodySheenP1")
  pack:Destroy()
 end)
 return{passed=#cases,cases=cases}
end
