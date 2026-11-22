-- Studio Client. The "Stars bought" sound (PurchaseCue) and the pet preview light (Kit.petLight),
-- Spencer 2026-11-22. Pure: fake audio, no sound plays.
-- Usage: require(PlayerScripts.Client.ZZSpecs.PurchaseCue)(PlayerScripts.Client, PlayerGui)
return function(client,parent)
 local Cue=require(client.PurchaseCue);local Kit=require(client.DeckKit);local Shot=require(client.PetHeadshot);local Audio=require(client.BoardAudio)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function rig()
  local r={at=0,ok=true,quiet=false,plays=0,queue={}}
  r.cue=Cue.new({now=function()return r.at end,muted=function()return r.quiet end,
   play=function()if r.ok then r.plays+=1 end;return r.ok end,defer=function(fn)table.insert(r.queue,fn)end})
  function r.flush()local q=r.queue;r.queue={};for _,fn in ipairs(q)do fn()end end
  return r
 end
 test("a grant sounds once; a closing window or focus adds nothing",function()
  local r=rig();assert(r.cue:granted()and r.plays==1);r.cue:resume();r.flush();assert(r.plays==1 and not r.cue:waiting())
 end)
 test("refused under Roblox's window: once when it closes, deferred, not again",function()
  local r=rig();r.ok=false;assert(not r.cue:granted()and r.cue:waiting())
  r.ok=true;r.cue:resume();assert(r.plays==0,"deferred past the listener that wakes the device")
  r.cue:resume();r.flush();assert(r.plays==1 and not r.cue:waiting(),"two signals, one sound")
  r.cue:resume();r.flush();assert(r.plays==1)
 end)
 test("still refused keeps waiting; too late or muted drops it",function()
  local r=rig();r.ok=false;r.cue:granted();r.cue:resume();r.flush();assert(r.cue:waiting())
  r.at=Cue.RetryFor+1;r.ok=true;r.cue:resume();r.flush();assert(r.plays==0 and not r.cue:waiting())
  r=rig();r.quiet=true;r.cue:granted();r.quiet=false;r.cue:resume();r.flush();assert(r.plays==0,"muted is the player's choice")
  r=rig();r.ok=false;r.cue:granted();r.quiet=true;r.ok=true;r.cue:resume();r.flush();assert(r.plays==0 and not r.cue:waiting())
 end)
 test("two grants: the second replaces a waiting first",function()
  local r=rig();r.ok=false;r.cue:granted();r.ok=true;assert(r.cue:granted()and r.plays==1);r.cue:resume();r.flush();assert(r.plays==1)
 end)
 test("the cue has an asset and a gain",function()
  assert(type(Audio.uri(Cue.Name))=="string"and Audio.StarsBoughtGain>0 and Audio.StarsBoughtGain<=1)
 end)
 test("every menu pet preview uses the one light",function()
  local v=Instance.new("ViewportFrame");Kit.petLight(v)
  assert(v.Ambient==Kit.PetLight.ambient and v.LightColor==Kit.PetLight.color and v.LightDirection==Kit.PetLight.direction);v:Destroy()
  assert(Kit.PetLight.ambient.R*255>210 and Kit.PetLight.color.R*255>190,"brighter than 206 / 128")
  for _,name in ipairs({"CardPreviewCache","CompanionsHub","HueEggView","MachineHubArt","PetInspect","PetPeek","WardrobeShop"})do
   local source=client[name].Source
   assert(source:find("petLight(",1,true),name.." uses Kit.petLight")
   assert(not source:find("206,202,194",1,true),name.." still has the old light")
  end
 end)
 test("a pale or grey colour behind a pet is lilac; a real colour stays",function()
  assert(Shot.backdrop("pip",{})==Shot.Lilac,"the default grey disc: "..Shot.backdrop("pip",{}):ToHex())
  assert(Shot.behind(Color3.new(1,1,1))==Shot.Lilac and Shot.behind(Color3.fromHex("#A8A5AE"))==Shot.Lilac)
  for _,hex in ipairs({"#FFD04B","#FF789A","#8E5CFF","#1EA0FF","#202024"})do local c=Color3.fromHex(hex);assert(Shot.behind(c)==c,hex)end
  assert(Shot.behind(nil)==nil)
 end)
 test("every one-jar pastel second colour keeps its own disc",function()
  for _,id in ipairs({"rose","tide","citrus","iris"})do
   local doses={rose=0,tide=0,citrus=0,iris=0};doses[id]=1
   local disc=Shot.backdrop("pip",{secondaryDoses=doses})
   local _,s=disc:ToHSV();print(id,disc:ToHex(),s)
   assert(disc~=Shot.Lilac,id.." one jar became lilac "..disc:ToHex())
  end
 end)
 test("a pale pet's headshot disc is never nearly white",function()
  local limit=Shot.Pale/255
  for _,look in ipairs({{},{secondaryDoses={rose=0,tide=0,citrus=0,iris=3},mainDoses={rose=0,tide=0,citrus=4,iris=0}}})do
   for _,pet in ipairs({"pip","blip"})do
    local disc=Shot.backdrop(pet,look)
    assert(typeof(disc)=="Color3"and not(disc.R>=limit and disc.G>=limit and disc.B>=limit),pet.." "..disc:ToHex())
   end
  end
 end)
 return{passed=#cases,cases=cases}
end
