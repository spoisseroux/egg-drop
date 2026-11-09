-- Moving owner/fixed lateral offset through the real registered creek layout.
return function(server)
 local Shared=game.ReplicatedStorage.Shared;local A=require(Shared.GardenActivity);local W=require(Shared.GardenWalkability);local P=require(Shared.GardenPathPlanner)
 local Garden=require(server.GardenState);local holder=Instance.new("Folder");local wet={}
 for _,b in ipairs({{16.9,-16,5.6,9.6,-16},{17.8,-10,6.7,10.5,-9},{18.65,-3.6,6.35,10.8,3},{18.05,3.3,6.75,10.6,11},{16.9,9.8,6.2,10.4,8},{16.55,15,5.95,8.3,1}})do
  local part=Instance.new("Part");part.Size=Vector3.new(b[3],.09,b[4]);part.CFrame=CFrame.new(b[1],4.038,b[2])*CFrame.Angles(0,math.rad(b[5]),0);part.Parent=holder;table.insert(wet,part)
 end
 local cases={};local metrics={}
 local ok,problem=pcall(function()
  for _,east in ipairs({true,false})do
   local now=0;local start=if east then 10 else 26;local finish=if east then 25.181 else 10.819
   local direction=if east then 1 else -1
   local function input(x)
    local raw=Vector3.new(x-direction*3,4.025,-9.4+direction*2.66778)
    return{alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,yaw=direction*math.pi/2,
     position=Vector3.new(x,7,-9.4),anchor=W.resolveAnchor(raw,wet)or raw}
   end
   local g=Garden.new({now=function()return now end,
    planPath=function(from,to,v,speed,minimum,yaw,via,terminal)return P.plan(from,to,v,speed,minimum,yaw,via,terminal,wet)end,
    resolveTarget=function(target,from)local resolved,changed=W.resolveAnchor(target,wet);return resolved or from,changed or resolved==nil end})
   g:sync({[1]=input(start)})
   local previous=g:position(g.actors[1],now);local maxSpeed,maxJump,highest=0,0,0
   local arrivalAt,firstIdleAt,playedAt;local arrivalGap=math.huge;local played,rested,crossed=false,false,false
   local stableSeconds=0;local comfortRadius,stableWindow=3,.25
   local ownerStoppedAt=math.abs(finish-start)/16;local goal=input(finish).anchor
   for frame=1,1200 do
    now=frame/60;local x=start+direction*math.min(math.abs(finish-start),now*16)
    local actor=g.actors[1];local before=g:position(actor,now)
    g:step(1/60,{[1]=input(x)})
    if now>=ownerStoppedAt and actor.behavior~="follow"then firstIdleAt=firstIdleAt or now end
    local pose=A.sample(g.actors[1],now);maxJump=math.max(maxJump,(pose.position-before).Magnitude)
    local sampleSpeed=(pose.position-previous).Magnitude*60
    maxSpeed=math.max(maxSpeed,sampleSpeed);highest=math.max(highest,pose.position.Y);previous=pose.position
    if now>=ownerStoppedAt then
     local gap=(pose.position-goal).Magnitude;arrivalGap=math.min(arrivalGap,gap)
     crossed=crossed or(if east then pose.position.X>=goal.X-.1 else pose.position.X<=goal.X+.1)
     -- An idle comfort pause is allowed before the exact lateral offset. The
     -- exact static endpoint is independently checked in GardenWalkability.
     -- Observe a planted near-owner window, then the existing activity loop.
     if crossed and gap<=comfortRadius and sampleSpeed<=.5 and actor.action~="shove"then stableSeconds+=1/60 else stableSeconds=0 end
     if stableSeconds>=stableWindow then arrivalAt=arrivalAt or now-stableSeconds end
     if actor.action=="shove"then playedAt=playedAt or now end
     if arrivalAt then played=played or actor.action=="shove";rested=rested or actor.behavior=="rest"end
    end
   end
   local gap=(previous-goal).Magnitude
   local actor=g.actors[1]
   assert(arrivalAt and crossed and highest>=4.37 and maxSpeed<=18.01 and maxJump<1e-5,string.format("east=%s nearestExactGap=%.6f stableComfortAt=%s firstIdleAt=%s playedAt=%s crossed=%s finalGap=%.6f maxSpeed=%.6f rootJump=%.6f highest=%.6f position=%s goal=%s behavior=%s action=%s target=%s",tostring(east),arrivalGap,tostring(arrivalAt),tostring(firstIdleAt),tostring(playedAt),tostring(crossed),gap,maxSpeed,maxJump,highest,tostring(previous),tostring(goal),tostring(actor.behavior),tostring(actor.action),tostring(A.vector(actor.to))))
   if playedAt then assert(arrivalAt<playedAt,"stable bank comfort window must precede toy play")end
   assert(rested or played,"arrival must still allow subsequent legitimate idle activity")
   table.insert(cases,if east then "eastbound supported crossing has a stable comfort pause then independent idle activity"else "westbound supported crossing has a stable comfort pause then independent idle activity")
   table.insert(metrics,{east=east,nearestExactGap=arrivalGap,stableComfortAt=arrivalAt,comfortRadius=comfortRadius,stableWindow=stableWindow,firstIdleAt=firstIdleAt,playedAt=playedAt,subsequentPlay=played,subsequentRest=rested,finalGap=gap,maxSpeed=maxSpeed,maxRetargetJump=maxJump,highest=highest})
  end
 end)
 holder:Destroy();assert(ok,problem);return{passed=#cases,cases=cases,metrics=metrics}
end
