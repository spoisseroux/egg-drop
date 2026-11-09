-- The production GardenIntent listener with isolated users/clock, no network/stores.
return function(server,hostSource)
 local Garden=require(server.GardenState);local L=require(game.ReplicatedStorage.Shared.GardenLayout)
 local first=assert(hostSource:find("gardenIntentRemote.OnServerEvent:Connect",1,true));local last=assert(hostSource:find("for _, player in ipairs(Players:GetPlayers())",first,true))
 local module=Instance.new("ModuleScript");module.Name="_ToyHostFixture";module.Parent=server
 module.Source="return function(e)local boards,os,gardenIntentRemote,garden,gardenInput,gardenToyResult=e.boards,e.os,e.remote,e.garden,e.input,e.result\n"..hostSource:sub(first,last-1).."\nend"
 local install=require(module);module:Destroy()
 local cases={};local function test(name,f)f();table.insert(cases,name)end
 local function fixture()
  local f={now=0,boards={},inputs={},players={},responses={}}
  f.g=Garden.new({now=function()return f.now end})
  for id=1,2 do
   local p={UserId=id};local slot=if id==1 then L.ToyWest else L.ToyEast
   local input={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,position=slot+Vector3.new(0,3,0),anchor=slot,yaw=0}
   f.players[id]=p;f.inputs[id]=input;f.boards[p]={id=id,profile={companionId="pip"},mode="Room",characterGeneration=1,companionGeneration=1}
  end
  f.g:sync(f.inputs)
  install({boards=f.boards,os={clock=function()return f.now end},garden=f.g,input=function(board)return f.inputs[board.id]end,
   remote={OnServerEvent={Connect=function(_,callback)f.callback=callback end}},result={FireClient=function(_,p,result)table.insert(f.responses,{owner=p.UserId,result=result})end}})
  function f:send(id,kind,seq,actionId,overrides)
   local a=self.g.actors[id];local packet={kind=kind,seq=seq,actionId=actionId,petId="pip",characterId=1,petGeneration=1,actorGeneration=a and a.generation}
   for k,v in pairs(overrides or {})do packet[k]=v end
   self.callback(self.players[id],packet);return self.responses[#self.responses]and self.responses[#self.responses].result,packet
  end
  return f
 end
 test("retired production host rejects Start Join Cancel without reserving or moving pets",function()
  local f=fixture();local a,b=f.g.actors[1],f.g.actors[2];local ga,gb=a.generation,b.generation
  for index,kind in ipairs({"toyStart","toyJoin","toyCancel"})do
   local response=f:send(1,kind,index,99)
   assert(response.status=="Rejected"and response.reason=="ActivityRetired"and response.seq==index)
   assert(f.responses[index].owner==1 and not f.g.toy.returnAction and not f.g.toy.ownerId)
   assert(a.generation==ga and b.generation==gb)
  end
 end)
 test("retirement never trusts a forged old-client identity",function()
  local f=fixture();local response=f:send(1,"toyStart",1,nil,{petGeneration=0})
  assert(response.reason=="ActivityRetired"and not f.g.toy.returnAction)
 end)
 return {passed=#cases,cases=cases,realHostListener=true}
end
