-- Studio Client. Overnight 2026-11-14 slice D (SYSTEMS-SCOPE 4.3): earned charm shapes on the
-- Customize Charm tab (HueEggView). Pure rules only; the built tab is covered by
-- CareMachineUI / CustomizeRedesign.
--  * A shape with a rule shows "Locked" (with how to earn it, and progress for counted
--    rules) until PetCharmCatalog.earned says yes, then "Earned"; free shapes stay "Free".
--  * A locked card can be focused (it previews) but its pane button is disabled.
--  * Without facts (older callers) every shape reads as free, as before.
-- Usage: require(PlayerScripts.Client.ZZSpecs.CharmCards)(PlayerScripts.Client, PlayerGui)
return function(client)
 local Shared=game:GetService("ReplicatedStorage").Shared
 local View=require(client.HueEggView)
 local Charms=require(Shared.PetCharmCatalog)
 local UICopy=require(Shared.UICopy)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function byId(cards)local map={};for _,card in ipairs(cards)do map[card.id]=card end;return map end
 local none={stamps=0,claimed={},stats={},bond={}}
 test("without facts every shape is free (the two-argument call is unchanged)",function()
  local cards=View.charmCards({charmVisible=true,charmShape="ring"},true)
  assert(cards[1].id=="none"and #cards==#Charms.Order+1)
  for _,card in ipairs(cards)do
   assert(not card.locked and card.rule==nil,card.id)
   if card.id~="none"and not card.wearing then assert(card.status=="Free",card.id)end
  end
 end)
 test("free shapes stay Free with facts; the pane offers Wear",function()
  local cards=byId(View.charmCards({charmVisible=true,charmShape="ring"},true,none))
  for _,id in ipairs({"dot","pebble"})do assert(cards[id].status=="Free"and not cards[id].locked and cards[id].rule==nil,id)end
  assert(cards.ring.status=="WEARING"and cards.ring.wearing)
  local pane=View.charmPane(cards.dot,"Bear",nil)
  assert(pane.button=="Wear"and pane.enabled==true)
 end)
 if type(Charms.rule)~="function"or type(Charms.earned)~="function"then
  test("no earned shapes in this catalogue",function()end)
  return{passed=#cases,cases=cases}
 end
 local ruled={}
 for _,id in ipairs(Charms.Order)do if Charms.rule(id)then table.insert(ruled,id)end end
 test("a shape with a rule is Locked until earned, then Earned; its line says how",function()
  assert(#ruled>=1,"the catalogue has earned shapes")
  local locked=byId(View.charmCards({charmVisible=true,charmShape="dot"},true,none))
  for _,id in ipairs(ruled)do
   local card=locked[id]
   assert(card.locked==true and card.status==UICopy.get("pool3.charm.locked")and card.tone=="dim",id.." locked")
   assert(type(card.rule)=="string"and card.rule~=""and not string.find(card.rule,"pool3.",1,true),id.." rule line")
   assert(UICopy.has("pool3.charm."..id..".rule"),id.." has its own rule copy")
   local pane=View.charmPane(card,"Bear",nil)
   assert(pane.button==UICopy.get("pool3.charm.locked")and pane.enabled==false and pane.line==card.rule,id.." pane")
   assert(View.charmPane(card,"Bear",{retry=false}).enabled==false,"never enabled while locked")
  end
  -- Facts that meet every rule: Earned, and wearable.
  local facts={stamps=1000,claimed={},stats={},bond={}}
  for _,id in ipairs(ruled)do
   local rule=Charms.rule(id)
   if rule.kind=="claimed"then table.insert(facts.claimed,rule.id)elseif rule.kind=="stat"then facts.stats[rule.key]=rule.need end
  end
  local earned=byId(View.charmCards({charmVisible=true,charmShape="dot"},true,facts))
  for _,id in ipairs(ruled)do
   assert(Charms.earned(id,facts),id.." earned by the facts")
   local card=earned[id]
   assert(not card.locked and card.status==UICopy.get("pool3.charm.earned")and card.rule~=nil,id.." earned")
   local pane=View.charmPane(card,"Bear",nil);assert(pane.button=="Wear"and pane.enabled==true)
  end
  -- A worn earned shape reads WEARING like any other.
  local worn=byId(View.charmCards({charmVisible=true,charmShape=ruled[1]},true,facts))
  assert(worn[ruled[1]].status=="WEARING"and worn[ruled[1]].wearing and not worn[ruled[1]].locked)
 end)
 test("counted rules show progress; icons resolve for every shape",function()
  for _,id in ipairs(ruled)do
   local rule=Charms.rule(id)
   if rule.kind=="stat"and rule.need>1 then
    local line=View.charmRule(id,{stamps=0,claimed={},stats={[rule.key]=1},bond={}})
    assert(string.find(line,"1/"..rule.need,1,true),id.." progress: "..line)
   end
  end
  assert(View.charmRule("no_such_shape",none)==UICopy.get("pool3.charm.fallback.rule"))
  for _,id in ipairs(Charms.Order)do assert(type(View.charmIcon(id))=="string",id)end
  assert(View.charmIcon("none")=="none"and View.charmIcon("dot")=="sparkle"and View.charmIcon("ring")=="ball"and View.charmIcon("pebble")=="sphere")
 end)
 return{passed=#cases,cases=cases}
end
