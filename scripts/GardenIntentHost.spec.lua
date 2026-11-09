-- Execute the actual host GardenIntent listener against real GardenState and an injected clock.
-- No player, datastore, real remote or world mutation.
return function(server,hostSource)
 local Garden=require(server.GardenState);local Activity=require(game.ReplicatedStorage.Shared.GardenActivity)
 local first=assert(hostSource:find("gardenIntentRemote.OnServerEvent:Connect",1,true))
 local last=assert(hostSource:find("for _, player in ipairs(Players:GetPlayers())",first,true))
 local source=hostSource:sub(first,last-1)
 local module=Instance.new("ModuleScript");module.Name="_GardenIntentHostListener";module.Parent=server
 module.Source="return function(e)local boards,os,gardenIntentRemote,garden,gardenInput=e.boards,e.os,e.remote,e.garden,e.input\n"..source.."\nend"
 local ok,install=pcall(require,module);module:Destroy();assert(ok,install)
 local now=0;local player={UserId=74001};local board={profile={companionId="pip"},mode="Room",characterGeneration=3,companionGeneration=4}
 local input={petId="pip",owned=true,alive=true,mode="Room",position=Vector3.new(0,7,0),anchor=Vector3.new(2,4.025,0),characterId=3,petGeneration=4,yaw=.4}
 local g=Garden.new({now=function()return now end,validFocus=function()return true end});local callback
 local remote={OnServerEvent={Connect=function(_,f)callback=f end}}
 install({boards={[player]=board},os={clock=function()return now end},remote=remote,garden=g,input=function()return input end})
 local cases={};local function test(name,f)f();table.insert(cases,name)end
 local function packet(kind,seq)return{kind=kind,seq=seq,petId="pip",characterId=3,petGeneration=4}end
 test("actual host listener accepts position-free focus and retains sampled public position and facing",function()
  callback(player,packet("focus",1));local actor=g.actors[player.UserId];assert(actor and actor.mode=="Focus"and actor.focusSeq==1,"position-free client request was filtered before GardenState")
  local pose=Activity.sample(actor,now);assert((pose.position-input.anchor).Magnitude<.001 and math.abs(pose.yaw-input.yaw)<.001)
  now=.3;callback(player,packet("focusPulse",1));assert(actor.focusUntil>now)
  now=.6;callback(player,packet("focusEnd",1));assert(actor.mode=="Room")
 end)
 test("client supplied stage is ignored; accepted focus still uses the authoritative actor",function()
  now=1;local request=packet("focus",2);request.position={1000,1000,1000};request.yaw=999
  callback(player,request);local actor=g.actors[player.UserId];assert(actor.mode=="Focus"and actor.focusSeq==2)
  local pose=Activity.sample(actor,now);assert((pose.position-input.anchor).Magnitude<.001 and math.abs(pose.yaw-input.yaw)<.001)
 end)
 test("host retains rate identity sequence pet mode and generation validation",function()
  local actor=g.actors[player.UserId];local expires=actor.focusUntil
  now=1.01;callback(player,packet("focusPulse",2));local firstExpiry=actor.focusUntil
  now=1.02;callback(player,packet("focusPulse",2));assert(actor.focusUntil==firstExpiry)
  for _,change in ipairs({{seq=0},{seq=0/0},{petId="puddle"},{characterId=2},{petGeneration=3}})do
   now+=.3;local request=packet("focus",3);for k,v in pairs(change)do request[k]=v end;callback(player,request);assert(actor.focusSeq==2)
  end
  now+=.3;callback(player,packet("focus",2));assert(actor.focusSeq==2)
  board.mode="Board";now+=.3;callback(player,packet("focus",3));assert(actor.focusSeq==2)
  board.mode="Room";board.closing=true;now+=.3;callback(player,packet("focus",3));assert(actor.focusSeq==2)
  assert(expires>0)
 end)
 return{passed=#cases,cases=cases,realHostListener=true,realGardenState=true,persistentWrites=false}
end
