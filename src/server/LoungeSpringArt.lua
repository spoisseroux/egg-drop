-- One dry south-meadow loop and a contained spring backdrop; no new tasks/lights.
local World=require(game:GetService("ReplicatedStorage").Shared.HollowWorldLayout)
local Art={}
function Art.build(room,part)
 local spring=World.Spring
 local function box(name,position,size,hex,collide)
  local p=part(room,"Spring"..name,size,CFrame.new(position),Color3.fromHex(hex),collide==true)
  p.CanTouch=false;p.CanQuery=collide==true;p.Material=Enum.Material.SmoothPlastic;p.Reflectance=0;p:SetAttribute("SpringMeadowPart",true)
  return p
 end
 local function oval(name,position,size,hex,collide)
  local p=box(name,position,size,hex,collide)
  local mesh=Instance.new("SpecialMesh");mesh.MeshType=Enum.MeshType.Sphere;mesh.Parent=p
  return p
 end
 local function trail(points)
  for i=2,#points do
   local a,b=points[i-1],points[i];local count=math.ceil((b-a).Magnitude/5.2)
   for step=1,count do
    local at=a:Lerp(b,(step-.5)/count)
    local stone=oval("TrailStone",Vector3.new(at.X+math.sin(step*1.7)*.13,4.027,at.Y),Vector3.new(2.0+(step%3)*.17,.10,1.4+(i%2)*.15),"B0BA9E")
    stone.CFrame*=CFrame.Angles(0,(i+step)*.53,0);stone.CastShadow=false
   end
  end
 end
 trail(World.Routes.SpringApproach);trail(World.Routes.SpringLoop)
 local lawn=oval("RestLawn",Vector3.new(spring.LawnCenter.X,4.014,spring.LawnCenter.Y),
  Vector3.new(spring.LawnSize.X,.025,spring.LawnSize.Y),"86C65E")
 lawn.Color=Color3.fromHex("#86C474");lawn.CastShadow=false
 oval("LawnShoulder",Vector3.new(-6.2,4.015,88.6),Vector3.new(6.5,.025,8),"86C474").CastShadow=false
 for _,rest in ipairs({spring.RestWest,spring.RestEast})do
  oval("RestPad",rest-Vector3.new(0,.005,0),Vector3.new(1.65,.035,1.2),"A6BC8B").CastShadow=false
 end

 -- Preserve the exact tested solid envelope invisibly. The intersecting
 -- volumetric shoulders are visual only, with no stretched Grass texture.
 for _,shelf in ipairs({
  {Vector3.new(-24,6,100),Vector3.new(11,4,8),"847CAF"},
  {Vector3.new(-14,7.5,105),Vector3.new(13,7,9),"776A9F"},
  {Vector3.new(-4,9.5,105),Vector3.new(8,11,10),"665586"},
 })do
  local at,size,hex=shelf[1],shelf[2],shelf[3]
  local rock=box("Shelf",at,size,hex,true);rock.Transparency=1
 end
 for _,lobe in ipairs({
  {Vector3.new(-25.1,5.6,100.2),Vector3.new(8.6,4.9,7.6),10,-9,"827BAA"},
  {Vector3.new(-21.1,5.5,100.7),Vector3.new(8.5,4.8,7.4),-12,11,"A49BC0"},
  {Vector3.new(-17.2,7.0,104.4),Vector3.new(10.8,7.5,9.2),9,-10,"827BAA"},
  {Vector3.new(-11.9,7.15,104.9),Vector3.new(10.0,7.8,9.3),-8,12,"A49BC0"},
  {Vector3.new(-5.2,9.0,105.7),Vector3.new(7.2,11.3,8.0),10,-8,"827BAA"},
  {Vector3.new(-2.5,7.6,105.2),Vector3.new(6.3,8.8,8.0),-11,12,"A49BC0"},
 })do
  local p=oval("RockShoulder",lobe[1],lobe[2],lobe[5]);p.CFrame*=CFrame.Angles(0,math.rad(lobe[4]),math.rad(lobe[3]))
 end
 for _,cap in ipairs({
  {Vector3.new(-23.3,7.7,100.5),Vector3.new(11.0,1.35,7.3),-5},
  {Vector3.new(-14.5,10.25,104.4),Vector3.new(11.7,1.4,8.6),5},
  {Vector3.new(-5.3,14.2,105.8),Vector3.new(5.3,1.3,6.0),8},
 })do
  local p=oval("ShelfCap",cap[1],cap[2],"A4CA66");p.CFrame*=CFrame.Angles(0,math.rad(cap[3]),math.rad(cap[3]*.35))
 end
 -- Water is a finite, named wet footprint inset between the low sill and
 -- the solid rear shelves. There is no advertised walking route through it.
 local water=box("Water",spring.BasinCenter,spring.BasinSize,"45C5D0")
 water.Material=Enum.Material.Glass;water.Transparency=.12;water:SetAttribute("GardenWetRegion",true)
 local depth=box("WaterDepth",spring.BasinCenter-Vector3.new(0,.07,0),spring.BasinSize-Vector3.new(.5,.02,.4),"267BA0")
 depth.Material=Enum.Material.SmoothPlastic
 box("BasinSill",Vector3.new(-14,4.45,96.5),Vector3.new(9,.9,1),"9A8FB5",true).Transparency=1
 for _,x in ipairs({-18.3,-9.7})do
  box("BasinSide",Vector3.new(x,4.55,99),Vector3.new(.65,1.1,5.2),"847CAF",true).Transparency=1
 end
 for _,lip in ipairs({
  {Vector3.new(-17.0,4.26,97.6),Vector3.new(2.4,.50,2.0),-12},
  {Vector3.new(-10.8,4.26,97.7),Vector3.new(2.3,.48,2.0),14},
 })do
  local p=oval("BasinShoulder",lip[1],lip[2],"A49BC0");p.CFrame*=CFrame.Angles(0,math.rad(lip[3]),0)
 end
 local top,foot=Vector3.new(-14.5,10.2,100.4),Vector3.new(-14,4.32,98.6)
 local fall=box("Fall",(top+foot)*.5,Vector3.new(3.0,(top-foot).Magnitude,.13),"2DAACF")
 fall.CFrame=CFrame.lookAt((top+foot)*.5,foot)*CFrame.Angles(math.pi*.5,0,0);fall.CastShadow=false
 local sheen=box("FallHighlight",(top+foot)*.5,Vector3.new(.22,(top-foot).Magnitude,.035),"9FE7D5")
 sheen.CFrame=fall.CFrame*CFrame.new(-.55,0,-.09);sheen.CastShadow=false
 for _,foam in ipairs({{Vector3.new(-14.5,4.31,98.2),Vector3.new(2.1,.06,.5),"DDECE8"},{Vector3.new(-13.2,4.32,98.6),Vector3.new(1.9,.06,.55),"E8E9D5"}})do
  oval("Foam",foam[1],foam[2],foam[3]).CastShadow=false
 end
 local glint=box("Glint",Vector3.new(-14.4,4.30,98.8),Vector3.new(1.15,.025,.08),"F1EEDB")
 glint.Name="HollowAmbient_SpringGlint";glint.CastShadow=false
 glint:SetAttribute("HollowRestCFrame",glint.CFrame);glint:SetAttribute("HollowRestTransparency",glint.Transparency)
 glint:SetAttribute("HollowAmbientPhase",.37);glint:SetAttribute("HollowAmbientPeriod",9)
 glint:SetAttribute("HollowAmbientAmplitude",Vector3.new(.28,0,0));glint:SetAttribute("HollowAmbientKind","water")
 for _,patch in ipairs({Vector3.new(-25,4.2,84),Vector3.new(12,4.2,82),Vector3.new(-23,4.2,61)})do
  oval("GrassBrow",patch,Vector3.new(4.8,.5,3.1),"427E58")
  oval("GrassTip",patch+Vector3.new(.7,.16,.2),Vector3.new(2.7,.6,2.2),"A4CA66")
 end
 -- The south distant hills were retired by the greybox sea and rim (2026-11-11).
 oval("WarmAccent",Vector3.new(-23.8,4.35,84.5),Vector3.new(.8,.7,.65),"D58B72")
 oval("BlueAccent",Vector3.new(11.4,4.35,82.5),Vector3.new(.75,.65,.7),"779FC9")
end
return Art
