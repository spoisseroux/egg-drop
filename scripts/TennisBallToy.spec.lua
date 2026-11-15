-- QA v735 H2: the Ball toy reads as a tennis ball (src/client/PetToyGeometry.lua):
-- optic yellow-green felt and two thin white seam arcs. Geometry only; no remotes.
-- Run (Client): require(Client.ZZSpecs.TennisBallToy)(Client)
return function(client,parent)
 local Toys=require(client.PetToyGeometry)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local root=Instance.new("Folder");root.Name="_TennisBallToy";root.Parent=parent or workspace
 local ok,problem=pcall(function()
  test("three sphere parts, inside the part limit, felt first",function()
   local h=assert(Toys.create(root,"ball",1))
   assert(#h.parts==3 and #h.parts<=Toys.PartLimit,"parts "..#h.parts)
   assert(h.model.PrimaryPart==h.model:FindFirstChild("FeltBall"),"the felt is the primary part")
   for _,p in ipairs(h.parts)do assert(p:FindFirstChildOfClass("SpecialMesh").MeshType==Enum.MeshType.Sphere,p.Name)end
   h:destroy()
  end)
  test("the felt is optic yellow-green, not coral",function()
   local h=assert(Toys.create(root,"ball",1));local hue,sat,val=h.model.FeltBall.Color:ToHSV();h:destroy()
   assert(hue>.15 and hue<.24,"hue "..hue);assert(sat>.6 and val>.8,"saturated and bright")
  end)
  test("two thin white seam arcs break the surface, mirrored and tipped toward the face",function()
   local h=assert(Toys.create(root,"ball",1));local radius=h.model.FeltBall.Size.X/2
   local left,right=assert(h.model:FindFirstChild("SeamArcL")),assert(h.model:FindFirstChild("SeamArcR"))
   for _,arc in ipairs({left,right})do
    local _,sat,val=arc.Color:ToHSV();assert(sat<.1 and val>.95,"the seam is white")
    assert(arc.Size.Y<arc.Size.X*.3,"a thin disc")
    -- The disc's rim pokes just through the felt: a line, not a band or a bump.
    local reach=math.sqrt(arc.Position.Magnitude^2+(arc.Size.X/2)^2)
    assert(reach>radius and reach<radius*1.05,"rim reach "..reach/radius)
    -- Off-centre, so it cuts a small circle (a curve from the front), not an equator.
    assert(arc.Position.Magnitude>radius*.45,"offset "..arc.Position.Magnitude/radius)
    assert(arc.Position.Z>0,"tipped toward +Z")
   end
   assert(left.Position.X<0 and right.Position.X>0)
   h:destroy()
  end)
  test("it scales with the pet and the old coral ball is gone",function()
   local h=assert(Toys.create(root,"ball",2.5))
   assert(math.abs(h.model.FeltBall.Size.X-.6)<1e-4)
   assert(not(h.model:FindFirstChild("CoralBall")or h.model:FindFirstChild("OffsetCreamEquator")or h.model:FindFirstChild("TealDimple")))
   h:destroy()
  end)
  test("play and hold are unchanged",function()
   assert(Toys.Play.ball=="roll"and Toys.has("ball")and Toys.hold("ball")==Toys.Hold.ball)
  end)
 end)
 root:Destroy();assert(ok,problem);return cases
end
