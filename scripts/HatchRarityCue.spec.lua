-- Studio Client. Rarity presentation policy (QA v685 H2/H3, 2026-11-15): fixed authored
-- tiers, one look and one sound line per tier, built only from existing uploaded cues.
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
 test("every tier has its own sound line: more notes, more layers and a different stinger as it gets rarer",function()
  local common,uncommon,rare=line("material",{finishId="gloss"}),line("feature",{featureId="claws"}),line("material",{finishId="jelly"})
  assert(#common==3 and #uncommon==5 and #rare==9,"note counts changed")
  local function cues(list)local set,count={},0;for _,e in ipairs(list)do if not set[e.cue]then set[e.cue]=true;count+=1 end end;return set,count end
  local c,u,r=cues(common),cues(uncommon),cues(rare)
  -- Stinger at the burst: a soft crack for Common, a shimmer for Uncommon, a higher and louder shimmer plus a fanfare for Rare.
  assert(c.egg_crack_glint and not c.reveal_shimmer and u.reveal_shimmer and r.reveal_shimmer and r.new_best and not u.new_best)
  -- Answer to the name slam: nothing extra, a chime, a long rising total.
  assert(not c.quest_complete and not c.stars_total and u.quest_complete and not u.stars_total and r.stars_total and not r.quest_complete)
  local function shimmer(list)for _,e in ipairs(list)do if e.cue=="reveal_shimmer"then return e end end end
  assert(shimmer(rare).speed>shimmer(uncommon).speed*1.15 and shimmer(rare).gain>=shimmer(uncommon).gain+.2)
  local function slam(list)for _,e in ipairs(list)do if e.cue=="name_slam"then return e end end end
  assert(slam(common).speed==1 and slam(uncommon).speed>1 and slam(rare).speed<1,"the three slams share a pitch")
 end)
 test("rising notes climb: none for Common, two for Uncommon, four over an octave for Rare",function()
  local function rising(list)local out={};for _,e in ipairs(list)do if e.cue=="star_land"then table.insert(out,e)end end;return out end
  assert(#rising(line("material",{finishId="matte"}))==0 and #rising(line("hue",{itemId="rose"}))==0)
  local two,four=rising(line("feature",{featureId="claws"})),rising(line("material",{finishId="jelly"}))
  assert(#two==2 and two[2].speed>two[1].speed and two[2].gain>two[1].gain)
  assert(#four==4 and math.abs(four[4].speed/four[1].speed-2)<1e-6)
  for i=2,4 do assert(four[i].speed>four[i-1].speed and four[i].gain>four[i-1].gain and four[i].at>four[i-1].at)end
  for _,e in ipairs(four)do assert(e.pre and e.at<Policy.BurstAt,"the build-up ends before the burst")end
 end)
 test("every cue is an existing uploaded sound and every gain is audible, never clipped",function()
  for _,tier in ipairs({"Common","Uncommon","Rare","Neutral"})do
   for _,e in ipairs(Policy.events(tier,R))do
    assert(Audio.uri(e.cue)~=nil,"no uploaded sound for "..tostring(e.cue))
    assert(e.gain>=.3 and e.gain<=1 and e.speed>=.5 and e.speed<=2.01)
    assert(e.pre==true or e.at>=R,"an undisclosed note sits before the receipt")
   end
  end
  assert(Policy.AnswerEnd>=Policy.FlourishAfter+1.0,"the Rare total (1.0 s) must not be cut by the answer owner")
  -- The hatch body peaks from 1.5 to 2.0 s; a flourish under it is masked (LOUDNESS.md).
  for _,tier in ipairs({"Uncommon","Rare"})do
   local events=Policy.events(tier,R);local last=events[#events]
   assert(last.cue~="name_slam"and last.at>=2.05 and math.abs(last.at-(R+Policy.FlourishAfter))<1e-9,"flourish sits under the body's peak")
  end
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
  local c=Policy.new("material",{finishId="jelly"},R);advance(c,.5,false)
  assert(#c:due(1.4,false,true)==0,"a jump over 0.25 s played what it crossed")
  assert(#advance(c,3.1,true)==2,"the answers after the jump still play on time")
  c=Policy.new("material",{finishId="jelly"},R)
  assert(#advance(c,R-.05,false)==7 and #advance(c,3.1,false)==2,"build-up notes are pre-receipt; answers follow the clock")
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
