-- Read-only native Client evidence. No camera, instance, character or world writes.
return function(client,options)
 options=options or {};local Shot=require(client.PetGreetingShot)
 local camera=workspace.CurrentCamera;assert(camera,"Current camera missing")
 local player=game:GetService("Players").LocalPlayer;local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 local pet=options.petModel
 if not pet then for _,node in ipairs(workspace:GetChildren())do
  if node:IsA("Model")and node:GetAttribute("PetFamily")and not node:GetAttribute("CompanionOwnerId")and node:GetAttribute("GreetingAccepted")then pet=node;break end
 end end
 assert(pet and pet:IsA("Model"),"Pass options.petModel if no focused local pet is present")
 local bounds,size=pet:GetBoundingBox();local head=pet:FindFirstChild("Head",true)
 local target=if head and head:IsA("BasePart")then head.Position else bounds.Position
 local points={target}
 for x=-1,1,2 do for y=-1,1,2 do for z=-1,1,2 do table.insert(points,bounds:PointToWorldSpace(size*Vector3.new(x,y,z)*.5))end end end
 local near=.1;pcall(function()near=math.abs(camera.NearPlaneZ)end)
 local aspect=camera.ViewportSize.X/math.max(1,camera.ViewportSize.Y);local h=math.tan(math.rad(camera.FieldOfView)*.5)*near
 local nearPoints={camera.CFrame.Position}
 for x=-1,1,2 do for y=-1,1,2 do table.insert(nearPoints,camera.CFrame:PointToWorldSpace(Vector3.new(x*h*aspect,y*h,-near)))end end
 local function vector(v)return{v.X,v.Y,v.Z}end
 local function frame(cf)return{cf:GetComponents()}end
 local function abs(v)return Vector3.new(math.abs(v.X),math.abs(v.Y),math.abs(v.Z))end
 local function contains(cf,extent,p)local q=cf:PointToObjectSpace(p);return math.abs(q.X)<=extent.X*.5+.08 and math.abs(q.Y)<=extent.Y*.5+.08 and math.abs(q.Z)<=extent.Z*.5+.08 end
 local top={};local scanned,parts,nearby=0,0,0;local limit=options.scanLimit or 8000
 local function inspect(part)
  parts+=1
  if part:IsA("Terrain")then return end -- Terrain's aggregate box is not rendered solid geometry.
  if part:IsDescendantOf(pet)or 1-(1-part.Transparency)*(1-part.LocalTransparencyModifier)>=.99 then return end
  local cf,extent=part.CFrame,part.Size;local mesh=part:FindFirstChildOfClass("SpecialMesh");local unresolved=false
  if mesh then
   cf*=CFrame.new(mesh.Offset)
   if mesh.MeshType==Enum.MeshType.FileMesh then
    -- FileMesh vertex bounds are unavailable here; report both native inputs.
    unresolved=true;local scaled=abs(mesh.Scale)*2
    extent=Vector3.new(math.max(extent.X,scaled.X),math.max(extent.Y,scaled.Y),math.max(extent.Z,scaled.Z))
   else extent*=abs(mesh.Scale)end
  end
  local distance=(cf.Position-camera.CFrame.Position).Magnitude
  if distance>extent.Magnitude*.5+math.max(12,(camera.CFrame.Position-target).Magnitude+4)then return end
  nearby+=1;local proxy={Parent=true,CFrame=cf,Size=extent};local hits=0
  for _,point in ipairs(points)do if Shot.segmentBlocked(camera.CFrame.Position,point,{proxy})then hits+=1 end end
  local nearContains=0;for _,point in ipairs(nearPoints)do if contains(cf,extent,point)then nearContains+=1 end end
  if hits==0 and nearContains==0 then return end
  local entry={path=part:GetFullName(),class=part.ClassName,material=part.Material.Name,color={part.Color.R,part.Color.G,part.Color.B},
   size=vector(part.Size),cframe=frame(part.CFrame),visualSize=vector(extent),visualCFrame=frame(cf),
   canQuery=part.CanQuery,canCollide=part.CanCollide,transparency=part.Transparency,localTransparency=part.LocalTransparencyModifier,
   centerAndBodyCornerHits=hits,nearPlaneContains=nearContains,cameraInside=contains(cf,extent,camera.CFrame.Position),distance=distance,
   boundsKind=if unresolved then "FileMesh estimate; native vertex bounds unresolved"elseif mesh then "primitive SpecialMesh Size*Scale plus Offset"else "BasePart physical bounds"}
  if mesh then entry.specialMesh={kind=mesh.MeshType.Name,scale=vector(mesh.Scale),offset=vector(mesh.Offset),meshId=mesh.MeshId}end
  if part:IsA("MeshPart")then entry.meshId=part.MeshId;entry.meshSize=vector(part.MeshSize)end
  table.insert(top,entry);table.sort(top,function(a,b)
   if a.cameraInside~=b.cameraInside then return a.cameraInside end
   if a.nearPlaneContains~=b.nearPlaneContains then return a.nearPlaneContains>b.nearPlaneContains end
   if a.centerAndBodyCornerHits~=b.centerAndBodyCornerHits then return a.centerAndBodyCornerHits>b.centerAndBodyCornerHits end
   return a.distance<b.distance
  end)
  if #top>15 then table.remove(top)end
 end
 local function visit(node)
  if scanned>=limit then return end;scanned+=1
  if node:IsA("BasePart")then inspect(node)end
  for _,child in ipairs(node:GetChildren())do if scanned>=limit then break end;visit(child)end
 end
 visit(workspace)
 return{readOnly=true,scope="Actual native Client camera/visible scene; top15 only",scanned=scanned,scanTruncated=scanned>=limit,baseParts=parts,nearbyParts=nearby,
  camera={cframe=frame(camera.CFrame),focus=frame(camera.Focus),fov=camera.FieldOfView,viewport=vector(Vector3.new(camera.ViewportSize.X,camera.ViewportSize.Y,0)),kind=camera.CameraType.Name,nearPlane=near},
  ownerRoot=root and vector(root.Position),pet={path=pet:GetFullName(),bounds=frame(bounds),size=vector(size),target=vector(target),bearing=pet:GetAttribute("GreetingStageBearing"),accepted=pet:GetAttribute("GreetingAccepted")},occluders=top}
end
