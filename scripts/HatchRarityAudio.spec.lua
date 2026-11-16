-- Actual Cinematic owner clock with an asset-free scene seam; no receipts or purchases.
-- 2026-11-15 (QA v685 H3): each rarity has its own sound line (HatchRarityCue.events).
return function(client,parent)
 local C=require(client.HatchCinematic);local Policy=require(client.HatchRarityCue)
 local R=require(client.HatchDisplayPose).ItemReady
 local root=Instance.new("Frame");root.Size=UDim2.fromOffset(500,350);root.Parent=parent
 local cases,views={},{};local serial=0
 local function test(name,f)f();table.insert(cases,name)end
 local function make(ready)
  local calls,stops={},{};local owner=true;local scene
  local audio={deviceActive=true,deviceEpoch=0}
  function audio:play(cue,speed,gain,token)table.insert(calls,{cue=cue,speed=speed,gain=gain,owner=token})end
  function audio:stopOwner(token)stops[token]=true end
  local c=C.new(root,audio,false,function()return owner end);table.insert(views,c)
  local function create(home)
   scene={ready=ready~=false,root=Instance.new("Frame")};scene.root.Parent=home;ready=true
   function scene:render()end;function scene:layout()end;function scene:destroy()self.root:Destroy()end
   function scene:getItemGraphic()return nil end;return scene
  end
  local function play(packet,extra)
   serial+=1;local result=packet or{id="rarity-audio-"..tostring(os.clock()).."-"..serial,finishId="jelly"}
   local options={nativeDisplay=true,kind="material",sceneFactory=create}
   for key,value in pairs(extra or {})do options[key]=value end
   c:play(result,nil,options);c:disconnectClock()
  end
  local function advance(age)
   while c.active and c.age<age-1e-6 do c:step(math.min(1/60,age-c.age));c:disconnectClock()end
  end
  -- Tier notes: everything on the accent owner (the hatch body has its own owner).
  local function accents()local list={};for _,call in ipairs(calls)do if call.cue~="hatch_display_material"then table.insert(list,call)end end;return list end
  return c,play,advance,calls,accents,stops,function(value)owner=value;c:refreshOwner();c:disconnectClock()end,function()return scene end,audio
 end
 local function names(list)local out={};for _,call in ipairs(list)do table.insert(out,call.cue)end;return table.concat(out,",")end
 local ok,err=pcall(function()
  test("the body stays speed one; the Rare sting leads in to the burst on its own stoppable voice",function()
   local c,play,advance,calls,accents,stops=make();play();assert(#calls==1 and calls[1].cue=="hatch_display_material"and calls[1].speed==1 and calls[1].gain==1)
   local sting=Policy.Sting.Rare;local startAt=Policy.BurstAt-sting.hit
   advance(startAt-.03);assert(#accents()==0,"the Rare sting started early")
   advance(startAt+.05);local notes=accents()
   assert(#notes==1 and notes[1].cue=="rarity_rare"and notes[1].speed==1 and notes[1].gain==sting.gain,"Rare line was "..names(notes))
   assert(notes[1].owner==c.accentOwner and notes[1].owner~=calls[1].owner,"the sting has its own voice, apart from the body")
   -- One sound for the whole reveal: nothing more at the burst, the receipt or after it.
   advance(R+.2);assert(#accents()==1 and c:getPresentationState().receiptReady,"a second note played")
   -- It rings to its end before its voice is retired.
   advance(startAt+sting.length+.02);assert(#accents()==1 and not stops[c.accentOwner],"the Rare chime was cut")
   advance(R+Policy.AnswerEnd+.05);assert(stops[c.accentOwner])
   c:cancel();assert(stops[c.audioOwner]and stops[c.accentOwner])
  end)
  test("Common, Uncommon and Rare are three different sounds on the real owner clock",function()
   local _,playCommon,advanceCommon,_,commonNotes=make();playCommon({id="rarity-common-"..os.clock(),finishId="gloss"});advanceCommon(3.1)
   local _,playRare,advanceRare,_,rareNotes=make();playRare();advanceRare(3.1)
   local common,rare=commonNotes(),rareNotes()
   assert(names(common)=="rarity_common","Common line was "..names(common))
   assert(names(rare)=="rarity_rare","Rare line was "..names(rare))
   assert(common[1].gain<rare[1].gain and common[1].speed==1 and rare[1].speed==1,"Rare is louder; both at their own pitch")
   local seen={}
   for _,tier in ipairs({"Common","Uncommon","Rare"})do
    local cue=Policy.Sting[tier].cue;assert(not seen[cue],"two tiers share "..cue);seen[cue]=true
   end
  end)
  test("skip settled reopen reduced motion and replacement never play deferred notes",function()
   local c,play,advance,_,accents=make();play();advance(.4);local before=#accents();assert(before==1 and c:skip());advance(3.1);assert(#accents()==before)
   play(c.result);advance(3.1);assert(#accents()==before and not c.active,"same saved receipt must not replay")
   c.reduceEffects=true;play();advance(3.1);assert(#accents()==before)
   -- Replaced before its own sting starts: only the replacement's Common pop is heard.
   c.reduceEffects=false;play();advance(.2);local mid=#accents();assert(mid==before);play({id="replacement-"..os.clock(),finishId="matte"});advance(3.1)
   local after=accents();assert(#after==mid+1 and after[#after].cue=="rarity_common","the replacement plays only its own Common sting")
  end)
  test("late preload starts at zero while focus device takeover and long frames drop pending notes",function()
   local c,play,advance,calls,accents,_,setOwner,getScene,audio=make(false);play();assert(not c.presented and #calls==0)
   getScene().ready=true;c:refreshOwner();c:disconnectClock();assert(c.age==0 and #calls==1)
   advance(1.2);local count=#accents();setOwner(false);setOwner(true);advance(3.1);assert(#accents()==count)
   play();advance(1.2);count=#accents();audio.deviceEpoch+=1;c:step(1/60);c:disconnectClock();assert(#accents()==count)
   play();advance(1.2);count=#accents();c:step(.7);c:disconnectClock();assert(#accents()==count)
   play();advance(1.2);count=#accents();audio.deviceActive=false;c:refreshOwner();audio.deviceActive=true;c:refreshOwner();c:disconnectClock();assert(#accents()==count)
  end)
 end)
 for _,c in ipairs(views)do c:destroy()end;root:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
