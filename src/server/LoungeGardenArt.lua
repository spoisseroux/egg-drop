-- Purposeful shared lawn, supported crossing and small rest nook; no tasks/lights.
local World=require(game:GetService("ReplicatedStorage").Shared.HollowWorldLayout)
local Layout=require(game:GetService("ReplicatedStorage").Shared.GardenLayout)
local Art={}
function Art.build(room,part)
 local function box(name,position,size,color,collide)
  local p=part(room,name,size,CFrame.new(position),Color3.fromHex(color),collide==true)
  p.CanTouch=false;p.CanQuery=collide==true;return p
 end
 local function support(name,center,size,id)
  local p=box(name,center,size,"72B85B",true);p:SetAttribute("GardenWalkableSpan",id);return p
 end
 -- Continuous invisible deck closes the little gaps between authored planks.
 local bridge=World.WalkableSpans.PrimaryBridge
 local deck=support("GardenBridgeSupport",bridge.center,bridge.size,"PrimaryBridge");deck.Transparency=1
 for _,side in ipairs({-1,1})do
  box("BridgePaleSill",Vector3.new(17.6,4.42,-9.4+side*2.43),Vector3.new(10,.24,.24),"E7DFC8",false)
 end
 -- The arch lies in the YZ plane, so the west/east ball trajectory passes through it.
 local toy=Layout.Toy
 for _,side in ipairs({-1,1})do
  local post=box("ReturnGateGlass",toy+Vector3.new(0,.515,side*1.35),Vector3.new(.20,1.08,.24),"45C5D0",false)
  post.Material=Enum.Material.Glass;post.Transparency=.26;post.CastShadow=false
  box("ReturnGateAmberFoot",toy+Vector3.new(0,.095,side*1.35),Vector3.new(.40,.22,.42),"E9AE64",false)
 end
 local edge=box("ReturnGateEdge",toy+Vector3.new(0,1.035,0),Vector3.new(.22,.16,2.94),"E9AE64",false);edge.CastShadow=false
 for _,slot in ipairs({Layout.ToyWest,Layout.ToyEast})do
  local marker=box("ReturnSlotStone",slot-Vector3.new(0,.0125,0),Vector3.new(.75,.025,.75),"DDCFB2",false);marker.Transparency=.25
 end
 -- Low visual strata frame the lawn without occupying the bench sight corridor.
 for i,stone in ipairs({{-15,-10},{-14,-2},{-13,5},{10,-11},{10,1},{8,7}})do
  local p=box("LawnEdgeStone",Vector3.new(stone[1],4.11,stone[2]),Vector3.new(1.1,.22,.8),if i%2==0 then "B6CBAB"else "DECEAD",false)
  p.CFrame*=CFrame.Angles(0,i*.7,.04)
 end
 -- Nook: a shallow open-front shelter; visible pieces never block camera rays.
 local nook=World.WalkableSpans.RestNook
 local floor=support("NookSupport",nook.center,nook.size,"RestNook");floor.Material=Enum.Material.Grass
 local function oval(name,position,size,color)
  local p=box(name,position,size,color,false)
  local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=p;return p
 end
 oval("NookInterior",Vector3.new(26.35,5.36,-17.1),Vector3.new(7.5,2.7,.42),"554F78")
 -- A cutaway shell and seven overlapping rounded rim strokes make a real arch.
 -- The opening remains wide and the visible roof never becomes a collision lid.
 for _,side in ipairs({-1,1})do
  oval("NookCutaway",Vector3.new(26+side*3.5,5.02,-16.15),Vector3.new(.7,1.75,2.45),"847CAF")
 end
 for i=0,6 do
  local function point(angle)return Vector3.new(26+math.cos(angle)*3.65,4.15+math.sin(angle)*3.20,-14.25)end
  local a,b=point(i*math.pi/7),point((i+1)*math.pi/7)
  local rim=oval("NookArchRim",(a+b)*.5,Vector3.new(.55,.58,(b-a).Magnitude+.32),"847CAF")
  rim.CFrame=CFrame.lookAt((a+b)*.5,b)
 end
 oval("NookGrassBrowL",Vector3.new(24.7,7.28,-15.55),Vector3.new(4.8,.55,3.2),"427E58")
 oval("NookGrassBrowR",Vector3.new(27.55,7.23,-15.8),Vector3.new(3.8,.65,3.0),"579565")
 oval("NookWarmEave",Vector3.new(26.05,7.04,-15.0),Vector3.new(4.5,.23,1.65),"D7B18F")
 oval("NookRestStone",Vector3.new(26.55,4.15,-15.45),Vector3.new(3.0,.05,1.5),"C6C6B6")
 -- Station colors stay identifiable without another prompt or light.
 local journal=room:FindFirstChild("JournalSign")
 if journal then journal.Color=Color3.fromHex("467B9D")end
 local hatch=room:FindFirstChild("EggsSign")
 if hatch then
  local edge=box("HatchGlassEdge",hatch.Position+Vector3.new(0,.39,-.02),Vector3.new(2.65,.14,.20),"45C5D0",false)
  edge.Material=Enum.Material.Glass;edge.Transparency=.22;edge.CastShadow=false
 end
 for _,p in ipairs(room:GetChildren())do
  if p:IsA("BasePart")and p.Name=="GardenBench"then
   box("BenchColorPlane",p.Position+Vector3.new(0,.42,.63),Vector3.new(p.Size.X,.62,.10),"6EA6C1",false)
  end
 end
 local glint=box("HollowAmbient_CreekLawnGlint",Vector3.new(18,4.13,-12),Vector3.new(1.1,.025,.09),"F1EEDB",false)
 local pennant=box("HollowAmbient_BenchPennant",Vector3.new(-12.6,5.8,13.1),Vector3.new(.48,.30,.035),"E7AA91",false)
 for i,p in ipairs({glint,pennant})do
  p.CastShadow=false;p:SetAttribute("HollowRestCFrame",p.CFrame);p:SetAttribute("HollowRestTransparency",p.Transparency)
  p:SetAttribute("HollowAmbientPhase",i*.27);p:SetAttribute("HollowAmbientPeriod",8+i)
  p:SetAttribute("HollowAmbientAmplitude",if i==1 then Vector3.new(.3,0,0)else Vector3.new(.04,.04,0))
  p:SetAttribute("HollowAmbientKind",if i==1 then "water"else "leaf")
 end
end
return Art
