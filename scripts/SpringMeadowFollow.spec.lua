-- Continuous owner walk around both dry loop directions; actual production math.
return function(server)
 local Shared=game.ReplicatedStorage.Shared;local World=require(Shared.HollowWorldLayout)
 local A=require(Shared.GardenActivity);local W=require(Shared.GardenWalkability);local P=require(Shared.GardenPathPlanner);local G=require(server.GardenState)
 local holder=Instance.new("Folder");local water=Instance.new("Part");water.Size=World.Spring.BasinSize;water.CFrame=CFrame.new(World.Spring.BasinCenter);water.Parent=holder
 local cases,metrics={},{}
 local ok,problem=pcall(function()
  for _,reverse in ipairs({false,true})do
   local route={};for _,p in ipairs(World.Routes.SpringLoop)do table.insert(route,Vector3.new(p.X,4.025,p.Y))end
   if reverse then local backwards={};for i=#route,1,-1 do table.insert(backwards,route[i])end;route=backwards end
   local now=0;local inputs={};local wet={water}
   local function makeInput(position,direction)
    local right=Vector3.new(-direction.Z,0,direction.X)
    local raw=position-direction*3+right*2.6
    return{alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,position=position+Vector3.new(0,3,0),anchor=W.resolveAnchor(raw,wet)or raw,yaw=math.atan2(direction.X,direction.Z)}
   end
   local direction=(route[2]-route[1]).Unit;inputs[1]=makeInput(route[1],direction)
   local g=G.new({now=function()return now end,
    planPath=function(from,to,v,speed,minimum,yaw,via,terminal)return P.plan(from,to,v,speed,minimum,yaw,via,terminal,wet)end,
    resolveTarget=function(target,from)local point,clamped=W.resolveAnchor(target,wet);return point or from,clamped or point==nil end})
   g:sync(inputs);local previous=g:position(g.actors[1],now);local maxSpeed,maxJump,maxGap=0,0,0
   local crossedOldEdge=false;local goal=inputs[1].anchor
   local function step(position,heading)
    now+=1/60;inputs[1]=makeInput(position,heading);goal=inputs[1].anchor
    local before=g:position(g.actors[1],now);g:step(1/60,inputs)
    local pose=A.sample(g.actors[1],now)
    maxJump=math.max(maxJump,(pose.position-before).Magnitude);maxSpeed=math.max(maxSpeed,(pose.position-previous).Magnitude*60)
    maxGap=math.max(maxGap,(pose.position-goal).Magnitude);previous=pose.position
    crossedOldEdge=crossedOldEdge or pose.position.Z>70
    assert(W.segmentAllowed(pose.position,pose.position,wet),"follower entered inset spring")
    assert(math.abs(pose.position.Y-4.025)<.001,"dry route changed support height")
   end
   for i=2,#route do
    local from,to=route[i-1],route[i];direction=(to-from).Unit
    local frames=math.ceil((to-from).Magnitude/16*60)
    for frame=1,frames do step(from:Lerp(to,frame/frames),direction)end
   end
   for _=1,150 do step(route[#route],direction)end
   local gap=(previous-goal).Magnitude
   assert(crossedOldEdge and previous.Z<64,"pet must walk out and return through the former wall")
   assert(maxSpeed<=18.001 and maxJump<.001 and gap<3,"continuous loop follow gate speed="..maxSpeed.." jump="..maxJump.." finalGap="..gap)
   table.insert(cases,if reverse then"counterclockwise loop follows continuously across both former-edge branches"else"clockwise loop follows continuously across both former-edge branches")
   table.insert(metrics,{reverse=reverse,maxSpeed=maxSpeed,maxPublicationJump=maxJump,maxGap=maxGap,finalGap=gap,seconds=now})
  end
 end)
 holder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases,metrics=metrics}
end
