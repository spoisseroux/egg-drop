-- Isolated coordinator checks for public/private transform separation and idle work.
return function(server)
 local Garden=require(server.GardenState);local Activity=require(game.ReplicatedStorage.Shared.GardenActivity)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local function fixture(validate)
  local c={now=0,candidates=0}
  c.input={alive=true,owned=true,petId="pip",characterId=1,petGeneration=2,mode="Room",position=Vector3.new(25,7,25),anchor=Vector3.new(25,4.025,25),yaw=.7}
  c.g=Garden.new({now=function()return c.now end,validFocus=function()return true end,
   validWander=function(input,target,from)c.candidates+=1;return validate and validate(input,target,from)or nil end})
  c.g:syncOne(1,c.input);return c
 end
 test("focus freezes the exact sampled moving public root and yaw, ignoring forged stage",function()
  local c=fixture();local actor=c.g.actors[1]
  c.g:transition(actor,"follow",Vector3.new(29,4.025,25),0);c.now=.4
  local before=Activity.sample(actor,c.now)
  assert(c.g:focus(1,{kind="focus",seq=1,petId="pip",characterId=1,petGeneration=2,position={-500,999,500},yaw=99}))
  for _,offset in ipairs({0,.01,.5,1.5})do
   local pose=Activity.sample(actor,c.now+offset)
   assert((pose.position-before.position).Magnitude<1e-5 and math.abs(pose.yaw-before.yaw)<1e-5)
  end
  assert((c.g:focusAnchor(1,"pip",1,2,c.input.position)-before.position).Magnitude<1e-5)
  c.now+=.6;assert(c.g:focus(1,{kind="focusEnd",seq=1,petId="pip"}))
  assert((Activity.sample(actor,c.now).position-before.position).Magnitude<1e-5)
  assert((Activity.sample(actor,c.now+.01).position-before.position).Magnitude<.02)
 end)
 test("a near forged stage cannot grant care to a distant actual actor",function()
  local c=fixture();local actor=c.g.actors[1]
  actor.from={45,4.025,25};actor.to=actor.from;actor.path=nil
  assert(not c.g:focus(1,{kind="focus",seq=1,petId="pip",position=Activity.pack(c.input.anchor)}))
  assert(actor.mode=="Room"and not c.g:focusAnchor(1,"pip",1,2,c.input.position))
 end)
 test("nearby wander is bounded, pauses, shares a path and walking preempts it",function()
  local c=fixture(function(_,target)return target end);c.now=4;c.g:decide()
  local actor=c.g.actors[1];assert(actor.action=="wander"and actor.path and #actor.path>0)
  local to=Activity.vector(actor.to);local d=(to-c.input.anchor).Magnitude;assert(d>=1.99 and d<=4.01 and c.candidates<=6)
  c.now=actor.endTime;c.g:decide();assert(actor.action=="wanderPause"and actor.behavior=="rest")
  c.input.position+=Vector3.new(1,0,0);c.input.anchor+=Vector3.new(1,0,0);c.g:syncOne(1,c.input)
  assert(actor.behavior=="follow"and actor.action==nil)
  assert(actor.wanderCount==0 and actor.nextWanderAt==nil)
 end)
 test("free reachable toy alternates with nearby wander on the normal decision cadence",function()
  local c=fixture(function(_,target)return target end)
  c.input.position=Vector3.new(-2,7,-1);c.input.anchor=Vector3.new(-2,4.025,-1)
  c.g:remove(1);c.g:syncOne(1,c.input)
  local actor=c.g.actors[1];local choices={};local lastWander;local toyOwned=false
  for tick=1,180 do
   c.now=tick*.5;c.g:decide()
   if actor.action=="wander"and actor.actionId~=lastWander then
    lastWander=actor.actionId;table.insert(choices,"wander")
   end
   local owns=c.g.toy.ownerId==1
   if owns and not toyOwned then table.insert(choices,"toy")end
   toyOwned=owns
   if #choices>=3 then break end
  end
  assert(table.concat(choices,",")=="wander,toy,wander","idle activity order: "..table.concat(choices,","))
  c.input.mode="Board";c.g:syncOne(1,c.input)
  assert(actor.mode=="Board"and actor.action==nil and actor.wanderCount==0 and actor.nextWanderAt==nil and not c.g.toy.ownerId)
  c.input.mode="Room";c.g:syncOne(1,c.input)
  assert(actor.mode=="Room"and actor.behavior=="follow"and actor.idleSince==c.now)
 end)
 test("unsafe candidates are capped and fail to local rest without awards",function()
  local c=fixture(function()return nil end);c.now=6;c.g:decide()
  assert(c.candidates==6 and c.g.actors[1].behavior=="rest")
  assert(c.g.actors[1].action=="wanderPause"and not c.g.toy.ownerId)
 end)
 return{passed=#cases,cases=cases}
end
