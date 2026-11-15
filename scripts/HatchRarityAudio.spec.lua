-- Actual Cinematic owner clock with an asset-free scene seam; no receipts or purchases.
return function(client,parent)
 local C=require(client.HatchCinematic);local Audio=require(client.BoardAudio)
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
  local function accents()local list={};for _,call in ipairs(calls)do if call.cue=="hatch_finish"then table.insert(list,call)end end;return list end
  return c,play,advance,calls,accents,stops,function(value)owner=value;c:refreshOwner();c:disconnectClock()end,function()return scene end,audio
 end
 local ok,err=pcall(function()
  test("approved opening stays speed one and only post-receipt answers use their own stoppable voice",function()
   assert(Audio.uri("hatch_finish")==Audio.uri("goal_tick"),"answer must reuse the approved body")
   local c,play,advance,calls,accents,stops=make();play();assert(#calls==1 and calls[1].cue=="hatch_display_material"and calls[1].speed==1 and calls[1].gain==1)
   advance(2.3);assert(#accents()==0);advance(2.6);local notes=accents()
   assert(#notes==2 and notes[1].owner==c.accentOwner and notes[1].owner~=calls[1].owner and notes[1].gain==.035 and notes[2].speed>notes[1].speed)
   advance(2.7);assert(stops[c.accentOwner]and c:getPresentationState().receiptReady)
   c:cancel();assert(stops[c.audioOwner]and stops[c.accentOwner])
  end)
  test("skip settled reopen reduced motion and replacement never play deferred answers",function()
   local c,play,advance,_,accents=make();play();advance(.4);assert(c:skip());advance(3.1);assert(#accents()==0)
   play(c.result);advance(3.1);assert(#accents()==0 and not c.active,"same saved receipt must not replay")
   c.reduceEffects=true;play();advance(3.1);assert(#accents()==0)
   c.reduceEffects=false;play();advance(2.25);play({id="replacement-"..os.clock(),finishId="matte"});advance(3.1);assert(#accents()==0)
  end)
  test("late preload starts at zero while focus device takeover and long frames drop pending accents",function()
   local c,play,advance,calls,accents,_,setOwner,getScene,audio=make(false);play();assert(not c.presented and #calls==0)
   getScene().ready=true;c:refreshOwner();c:disconnectClock();assert(c.age==0 and #calls==1)
   advance(2.25);setOwner(false);setOwner(true);advance(3.1);assert(#accents()==0)
   play();advance(2.25);audio.deviceEpoch+=1;c:step(1/60);c:disconnectClock();assert(#accents()==0)
   play();advance(2.25);c:step(.7);c:disconnectClock();assert(#accents()==0)
   play();advance(2.25);audio.deviceActive=false;c:refreshOwner();audio.deviceActive=true;c:refreshOwner();c:disconnectClock();assert(#accents()==0)
  end)
 end)
 for _,c in ipairs(views)do c:destroy()end;root:Destroy();assert(ok,err);return{passed=#cases,cases=cases}
end
