-- Actual host support validator with detached geometry and controlled collision rays.
return function(server,hostSource)
 local Shared=game.ReplicatedStorage.Shared;local W=require(Shared.GardenWalkability);local P=require(Shared.GardenPathPlanner)
 local A=require(Shared.GardenActivity);local L=require(Shared.GardenLayout);local Garden=require(server.GardenState)
 -- The detour fixture is the legacy creek beside the legacy nook. World 1 v7 (2026-11-12) moved the
 -- nook to a creek dais with different wet geometry; v7 walkability is covered by GardenWalkability/GardenGreyboxWorld.
 if require(Shared.HollowWorldLayout).WorldVersion~="legacy"then return{passed=0,cases={},skipped="legacy creek fixture"}end
 local first=assert(hostSource:find("local wanderScene",1,true));local last=assert(hostSource:find("local garden = GardenState.new",first,true))
 local module=Instance.new("ModuleScript");module.Name="_NookHostFixture";module.Parent=server
 module.Source="return function(e)local workspace,GardenWalkability,GardenPathPlanner,GardenActivity,GardenLayout=e.workspace,e.walk,e.planner,e.activity,e.layout;local gardenScene\n"..hostSource:sub(first,last-1).."\nreturn validWander end"
 local install=require(module);module:Destroy()
 local room=Instance.new("Model");room.Name="EggDropLounge"
 local floor=Instance.new("Part");floor.Name="Floor";floor.Size=Vector3.new(160,1,128);floor.CFrame=CFrame.new(0,3.5,0);floor.Parent=room
 local support=Instance.new("Part");support.Name="NookSupport";support:SetAttribute("GardenWalkableSpan","RestNook");support.Parent=room
 local wet={}
 for _,b in ipairs({{16.9,-16,5.6,9.6,-16},{17.8,-10,6.7,10.5,-9},{18.65,-3.6,6.35,10.8,3}})do
  local p=Instance.new("Part");p.Name="Creek";p.Size=Vector3.new(b[3],.09,b[4]);p.CFrame=CFrame.new(b[1],4.038,b[2])*CFrame.Angles(0,math.rad(b[5]),0);p.Parent=room;table.insert(wet,p)
 end
 local env={blocked=false}
 local fakeWorkspace={FindFirstChild=function(_,name)return if name=="EggDropLounge"then room else nil end}
 function fakeWorkspace:Raycast(origin,direction)
  if math.abs(direction.X)<1e-8 and math.abs(direction.Z)<1e-8 and direction.Y<0 then return{Position=Vector3.new(L.Nook.X,L.Nook.Y-.025,L.Nook.Z),Material=Enum.Material.Grass,Instance=support}end
  if env.blocked then return{Instance=floor,Position=origin}end
  return nil
 end
 local validate=install({workspace=fakeWorkspace,walk=W,planner=P,activity=A,layout=L})
 local input={alive=true,owned=true,mode="Room",petId="pip",characterId=1,petGeneration=1,position=Vector3.new(24.181,7.148,-13.796),anchor=Vector3.new(21.5,4.38,-11.35),yaw=0}
 local cases={};local function test(name,f)f();table.insert(cases,name)end
 local ok,problem=pcall(function()
  test("nearby real owner may reach registered nook through a safe detour despite wet chord",function()
   assert(not W.segmentAllowed(input.anchor,L.Nook,wet),"fixture must exercise supported detour")
   local target=validate(input,L.Nook,input.anchor);assert(target and(target-L.Nook).Magnitude<1e-6)
  end)
  test("far owner cannot use the special nook detour",function()
   local far=table.clone(input);far.position+=Vector3.new(10,0,0)
   assert(validate(far,L.Nook,input.anchor)==nil)
  end)
  test("any collision along a detour leg rejects the nook approach",function()
   env.blocked=true;assert(validate(input,L.Nook,input.anchor)==nil);env.blocked=false
  end)
  test("an unregistered ray hit cannot masquerade as nook support",function()
   support:SetAttribute("GardenWalkableSpan",nil);assert(validate(input,L.Nook,input.anchor)==nil);support:SetAttribute("GardenWalkableSpan","RestNook")
  end)
  test("safety hold from an unsupported start is rejected rather than treated as arrival",function()
   assert(validate(input,L.Nook,Vector3.new(21,4.025,-11.8))==nil)
  end)
  test("real coordinator plus real host validator approach and settle after offset-anchor discovery",function()
   local now=0;local g=Garden.new({now=function()return now end,validWander=validate,
    planPath=function(from,to,v,speed,minimum,yaw,via,terminal)return P.plan(from,to,v,speed,minimum,yaw,via,terminal,wet)end})
   g:sync({[1]=input});now=4;g:decide();local a=g.actors[1]
   assert(a.action=="nookApproach"and(A.vector(a.path[#a.path].to)-L.Nook).Magnitude<.1)
   now=a.endTime+.01;g:decide();assert(a.action=="nookRest"and(g:position(a,now)-L.Nook).Magnitude<.1)
  end)
 end)
 room:Destroy();assert(ok,problem);return{passed=#cases,cases=cases,actualHostValidator=true}
end
