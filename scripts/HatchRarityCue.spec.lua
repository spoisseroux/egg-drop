-- Studio Client. Rarity presentation policy (QA v685 H2/H3, 2026-11-15): fixed authored
-- tiers, one look and one sound per tier. QA v735 H3: the sound is one original sting per
-- tier (rarity_common / rarity_uncommon / rarity_rare), timed so its pop lands on the burst.
return function(client)
 local Policy=require(client.HatchRarityCue);local Audio=require(client.BoardAudio);local cases={}
 local R=require(client.HatchDisplayPose).ItemReady
 local function test(name,f)f();table.insert(cases,name)end
 local function advance(c,age,disclosed)
  local events={}
  while c.lastAge<age-1e-7 do for _,event in ipairs(c:due(math.min(age,c.lastAge+1/60),disclosed,true))do table.insert(events,event)end end
  return events
 end
 local function line(kind,result)return advance(Policy.new(kind,result,R),3.1,true)end
 test("tiers use canonical authored identities and ignore transient odds and rare booleans",function()
  assert(Policy.tier("material",{finishId="jelly",probability=1,rare=false})=="Rare")
  assert(Policy.tier("material",{finishId="gloss",probability=.001,rare=true})=="Common")
  assert(Policy.tier("material",{finishId="matte"})=="Common"and Policy.tier("material",{finishId="metal"})=="Neutral")
  assert(Policy.tier("feature",{featureId="horns"})=="Common"and Policy.tier("feature",{featureId="claws"})=="Uncommon"and Policy.tier("feature",{featureId="wings"})=="Rare")
  assert(Policy.tier("hue",{itemId="rose",rare=true})=="Neutral"and Policy.tier("toy",{toyId="wobble_top",rare=true})=="Neutral")
  assert(Policy.tier("companion",{petId="pip",rare=true})=="Common"and Policy.tier("material",{finishId="unknown",rare=true})=="Neutral")
 end)
 test("every tier has its own sting: one sound each, three different sounds, louder as it gets rarer",function()
  local common,uncommon,rare=line("material",{finishId="gloss"}),line("feature",{featureId="claws"}),line("material",{finishId="jelly"})
  assert(#common==1 and #uncommon==1 and #rare==1,"one sound per reveal")
  assert(common[1].cue=="rarity_common"and uncommon[1].cue=="rarity_uncommon"and rare[1].cue=="rarity_rare")
  assert(common[1].gain<uncommon[1].gain and uncommon[1].gain<rare[1].gain,"the tiers step up in loudness")
  -- An untiered item sounds like Common, as it looks like Common.
  local neutral=line("hue",{itemId="rose"});assert(#neutral==1 and neutral[1].cue=="rarity_common"and neutral[1].gain==common[1].gain)
  assert(Policy.events("NoSuchTier",R)[1].cue=="rarity_common")
  local S=Policy.Sting
  assert(S.Common.length<S.Uncommon.length and S.Uncommon.length<S.Rare.length,"rarer tiers ring longer")
 end)
 test("the pop lands on the burst: Common and Uncommon start there, Rare leads in with its rise",function()
  for _,tier in ipairs({"Common","Uncommon","Rare","Neutral"})do
   local e=Policy.events(tier,R)[1];local s=Policy.Sting[tier]
   assert(math.abs(e.at+s.hit-Policy.BurstAt)<1e-9,tier.." pop is off the burst")
   assert(e.at>=.1,"it starts after the stage has opened")
  end
  assert(Policy.Sting.Common.hit==0 and Policy.Sting.Uncommon.hit==0 and Policy.Sting.Rare.hit==.70,"hit times match scripts/synth_hatch_rarity.py HIT")
  assert(Policy.events("Rare",R)[1].at<Policy.events("Common",R)[1].at)
 end)
 test("every cue is an uploaded sound, played at its own pitch, audible and never cut",function()
  local ids={}
  for _,tier in ipairs({"Common","Uncommon","Rare","Neutral"})do
   for _,e in ipairs(Policy.events(tier,R))do
    local uri=Audio.uri(e.cue);assert(uri~=nil,"no uploaded sound for "..tostring(e.cue))
    if tier~="Neutral"then assert(not ids[uri],"two tiers share an asset");ids[uri]=true end
    assert(e.gain>=.3 and e.gain<=1 and e.speed==1)
    assert(e.pre==true,"the sting plays before the receipt unlocks")
    -- The accent voice is stopped at R + AnswerEnd: the sting must have ended by then.
    assert(e.at+Policy.Sting[tier].length<=R+Policy.AnswerEnd+1e-9,tier.." would be cut by the answer owner")
   end
  end
  assert(Audio.uri("rarity_common")==Audio.uri("rarity_common")and Audio.uri("rarity_rare")~=Audio.uri("rarity_uncommon"))
 end)
 test("looks differ by tier: colour, beam, rays, shards and flash all grow with rarity",function()
  local c,u,r,n=Policy.Look.Common,Policy.Look.Uncommon,Policy.Look.Rare,Policy.Look.Neutral
  assert(c.rays<u.rays and u.rays<r.rays and c.shards<u.shards and u.shards<r.shards)
  assert(c.flash<u.flash and u.flash<r.flash and c.beam<u.beam and u.beam<r.beam and c.rings<=u.rings and u.rings<r.rings)
  local function hue(color)local h,s=color:ToHSV();return h,s end
  local ch,cs=hue(c.color);local uh,us=hue(u.color);local rh,rs=hue(r.color)
  assert(cs<.25,"Common is a soft white")
  assert(uh>.28 and uh<.45 and us>.5,"Uncommon is green")
  assert(rh>.6 and rh<.75 and rs>.4,"Rare is blue-violet")
  assert(n.color==c.color and n.rays==c.rays,"an untiered item looks like Common")
 end)
 test("pets keep the reveal stage's sound line; items never backfill a crossed note",function()
  assert(#Policy.new("companion",{petId="pip"},2.05).events==0)
  -- A jump over 0.25 s (a pause, a skip) consumes the sting it crossed; it is never played late.
  local c=Policy.new("material",{finishId="jelly"},R);advance(c,.1,false)
  assert(#c:due(.9,false,true)==0,"a jump over 0.25 s played what it crossed")
  assert(#advance(c,3.1,true)==0,"a crossed sting was backfilled")
  -- On the clock it plays once, before the receipt, whether or not the result is disclosed.
  c=Policy.new("material",{finishId="jelly"},R)
  assert(#advance(c,R-.05,false)==1 and #advance(c,3.1,false)==0,"the sting is pre-receipt and plays once")
  c=Policy.new("material",{finishId="gloss"},R)
  assert(#advance(c,Policy.BurstAt-.02,false)==0 and #advance(c,Policy.BurstAt+.05,false)==1,"Common pops at the burst")
 end)
 test("owner loss cancel invalid age and backwards clock permanently consume pending notes",function()
  for _,mode in ipairs({"owner","cancel","nan","backwards"})do
   local c=Policy.new("material",{finishId="jelly"},R);advance(c,.5,true)
   if mode=="owner"then c:due(.51,true,false)elseif mode=="cancel"then c:cancel()elseif mode=="nan"then c:due(0/0,true,true)else c:due(.2,true,true)end
   assert(c.cancelled and #c:due(1.0,true,true)==0 and not c:step(R,true,true))
  end
 end)
 return{passed=#cases,cases=cases}
end
