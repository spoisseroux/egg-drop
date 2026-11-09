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
 test("real host returns an owner-only response and exact retry does not replan",function()
  local f=fixture();local response,packet=f:send(1,"toyStart",1);assert(response.status=="Started"and f.responses[1].owner==1)
  local action=f.g.toy.returnAction;f.now=.01;f.callback(f.players[1],packet)
  assert(f.responses[2].result==response and f.g.toy.returnAction==action)
 end)
 test("real host rejects forged identity and foreign cancellation",function()
  local f=fixture();local response=f:send(1,"toyStart",1,nil,{petGeneration=0});assert(response.reason=="IdentityChanged"and not f.g.toy.returnAction)
  f.now=.3;response=f:send(1,"toyStart",2);assert(response.status=="Started")
  local id=response.actionId;f.now=.6;response=f:send(2,"toyCancel",1,id);assert(response.status=="Rejected"and f.g.toy.returnAction.id==id)
 end)
 test("join refreshes starter character facts before reserving the receiver",function()
  local f=fixture();local response=f:send(1,"toyStart",1);local id=response.actionId
  f.inputs[1].characterId=2;f.boards[f.players[1]].characterGeneration=2;f.now=.3
  response=f:send(2,"toyJoin",1,id);assert(response.status=="Rejected"and not f.g.toy.returnAction)
 end)
 test("rate rejection carries the same request identity without executing a second action",function()
  local f=fixture();local first=f:send(1,"toyStart",1)
  f.now=.01;local second=f:send(1,"toyCancel",2,first.actionId)
  assert(second.reason=="Throttled"and second.seq==2 and f.g.toy.returnAction.id==first.actionId)
 end)
 test("manual Start refreshes an autonomous owner's changed character before retirement",function()
  local f=fixture();f.inputs[2].mode="Board";f.boards[f.players[2]].mode="Board";f.g:syncOne(2,f.inputs[2]);f.now=4;f.g:decide()
  assert(f.g.toy.ownerId==1 and not f.g.toy.returnAction)
  f.inputs[2].mode="Room";f.boards[f.players[2]].mode="Room";f.g:syncOne(2,f.inputs[2])
  local replacement=table.clone(f.inputs[1]);replacement.characterId=2;f.inputs[1]=replacement;f.boards[f.players[1]].characterGeneration=2
  f.now+=.2;local response=f:send(2,"toyStart",1)
  assert(response.status=="Started"and f.g.actors[1].characterId==2 and f.g.toy.returnAction.starterId==2)
  assert(not f.g.actors[1].toyReservation and not f.g.toy.returnAction.participants["1"])
 end)
 return{passed=#cases,cases=cases,realHostListener=true}
end
