return function(client)
 local Policy=require(client.HatchRarityCue);local cases={}
 local function test(name,f)f();table.insert(cases,name)end
 local function advance(c,age,disclosed)
  local events={};while c.lastAge<age-1e-7 do local event=c:step(math.min(age,c.lastAge+1/60),disclosed,true);if event then table.insert(events,event)end end;return events
 end
 test("tiers use canonical authored identities and ignore transient odds and rare booleans",function()
  assert(Policy.tier("material",{finishId="jelly",probability=1,rare=false})=="Rare")
  assert(Policy.tier("material",{finishId="gloss",probability=.001,rare=true})=="Common")
  assert(Policy.tier("material",{finishId="matte"})=="Common"and Policy.tier("material",{finishId="metal"})=="Neutral")
  assert(Policy.tier("feature",{featureId="horns"})=="Common"and Policy.tier("feature",{featureId="claws"})=="Uncommon"and Policy.tier("feature",{featureId="wings"})=="Rare")
  assert(Policy.tier("hue",{itemId="rose",rare=true})=="Neutral"and Policy.tier("toy",{toyId="wobble_top",rare=true})=="Neutral")
  assert(Policy.tier("companion",{petId="pip",rare=true})=="Common"and Policy.tier("material",{finishId="unknown",rare=true})=="Neutral")
 end)
 test("rare emits exactly two modest upward answers after receipt with fixed timing",function()
  local c=Policy.new("material",{finishId="jelly"},2.2);local events=advance(c,3.1,true)
  assert(#events==2 and math.abs(events[1].at-2.32)<1e-8 and math.abs(events[2].at-2.46)<1e-8)
  assert(events[1].speed==1 and math.abs(events[2].speed-2^(3/12))<1e-8 and events[1].gain==.035 and events[2].gain==.035)
  assert(#advance(c,5,true)==0)
 end)
 test("uncommon has one faint answer while common and neutral retain the existing body",function()
  local events=advance(Policy.new("feature",{featureId="claws"},2.2),3.1,true)
  assert(#events==1 and math.abs(events[1].at-2.3)<1e-8 and events[1].gain==.026 and events[1].speed==2^(2/12))
  assert(#advance(Policy.new("material",{finishId="matte"},2.2),3.1,true)==0)
  assert(#advance(Policy.new("hue",{itemId="rose"},2.2),3.1,true)==0)
 end)
 test("undisclosed crossed cues and large jumps never catch up on later frames",function()
  local c=Policy.new("material",{finishId="jelly"},2.2);assert(#advance(c,2.5,false)==0 and #advance(c,3.1,true)==0)
  c=Policy.new("material",{finishId="jelly"},2.2);advance(c,2,true);assert(not c:step(2.6,true,true)and not c:step(2.62,true,true)and c.cursor==3)
 end)
 test("owner loss cancel invalid age and backwards clock permanently consume pending answers",function()
  for _,mode in ipairs({"owner","cancel","nan","backwards"})do
   local c=Policy.new("material",{finishId="jelly"},2.2);advance(c,1,true)
   if mode=="owner"then c:step(1.01,true,false)elseif mode=="cancel"then c:cancel()elseif mode=="nan"then c:step(0/0,true,true)else c:step(.5,true,true)end
   assert(c.cancelled and not c:step(2.32,true,true)and not c:step(2.46,true,true))
  end
 end)
 return{passed=#cases,cases=cases}
end
