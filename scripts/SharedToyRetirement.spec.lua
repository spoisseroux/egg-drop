-- The runtime retirement gate preserves unrelated care/focus sessions.
return function(server)
 local Garden=require(server.GardenState);local L=require(game.ReplicatedStorage.Shared.GardenLayout)
 local now=0;local g=Garden.new({sharedToyEnabled=false,now=function()return now end})
 local inputs={}
 for id=1,2 do inputs[id]={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,position=L.Lawn+Vector3.new(0,3,0),anchor=L.Lawn,yaw=0}end
 g:sync(inputs)
 for _=1,40 do now+=.5;g:decide();assert(not g.toy.ownerId and not g.toy.returnAction)end
 local care={state="Docked",claimId="unchanged"};local a=g.actors[1];a.care=care;a.mode="Docked";a.toyReservation=5
 local generation=a.generation;local focus=g.actors[2];focus.mode="Focus";focus.focusUntil=now+100;local fg=focus.generation
 g.toy={ownerId=1,reservation=5,position={0,0,0}}
 g:retireSharedToy()
 assert(a.care==care and a.generation==generation and a.mode=="Docked"and not a.toyReservation)
 assert(focus.mode=="Focus"and focus.generation==fg)
 assert(not g.toy.ownerId and g:toyRequest(1,{kind="toyStart",seq=1}).reason=="ActivityRetired")
 return {passed=3,cases={"no autonomous shared ball reservations","retirement preserves exact care and focus","start cannot reserve retired activity"}}
end
