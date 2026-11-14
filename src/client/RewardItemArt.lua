-- Original passive item silhouettes from the device/play brief.
local Art=require(script.Parent.DeckArt)
local Item={}
local function part(parent,name,x,y,w,h,color,rotation)
 local n=Art.frame(parent,name,Color3.fromHex(color),UDim2.fromScale(x,y),UDim2.fromScale(w,h),parent.ZIndex+1)
 n.Rotation=rotation or 0;Art.corner(n,100);return n
end
function Item.create(parent,result,position,size,z)
 local host=Art.frame(parent,"AwardedItem",Art.Ink,position,size,z or parent.ZIndex+1);host.BackgroundTransparency=1
 local id=result.toyId or result.featureId;host:SetAttribute("AwardedItemId",id)
 local aspect=Instance.new("UIAspectRatioConstraint");aspect.AspectRatio=1;aspect.Parent=host
 local geometry=script.Parent:FindFirstChild(if result.toyId then "PetToyGeometry"else "PetFeatureGeometry")
 if geometry then
  local viewport=Instance.new("ViewportFrame");viewport.Name="AwardedItem3D";viewport.BackgroundTransparency=1;viewport.Size=UDim2.fromScale(1,1);viewport.ZIndex=host.ZIndex+1;viewport.Parent=host
  viewport.Ambient=Color3.fromRGB(190,204,190);viewport.LightColor=Color3.fromRGB(255,244,219);viewport.LightDirection=Vector3.new(-1,-1.4,-3)
  local world=Instance.new("WorldModel");world.Parent=viewport
  local api=require(geometry)
  local handle=if result.toyId then api.create(world,id,1)else api.create(world,id,1,1,Color3.fromHex("#95CDB9"))
  -- An id this build cannot draw (a toy from a later pool) shows the empty slot, never an error.
  if not handle then return host end
  handle:pivot(CFrame.Angles(0,math.rad(-20),0))
  local box,extent=handle.model:GetBoundingBox();local half=math.tan(math.rad(15))
  local distance=math.max(extent.X,extent.Y)*.5/(half*.90)+extent.Z*.5+.02
  local camera=Instance.new("Camera");camera.FieldOfView=30;camera.CFrame=CFrame.lookAt(box.Position+Vector3.new(0,.03,distance),box.Position);camera.Parent=viewport;viewport.CurrentCamera=camera
  host.Destroying:Connect(function()handle:destroy()end);return host
 end
 if id=="ball"then
  part(host,"CoralBall",.18,.18,.64,.64,"F16F65")
  part(host,"CreamEquator",.23,.45,.54,.12,"FFF3D1",-18)
  part(host,"TealDimple",.60,.30,.10,.10,"287C83")
 elseif id=="sparkler"then
  part(host,"IndigoGrip",.39,.55,.17,.32,"363459",-12)
  part(host,"BrassWire",.47,.27,.045,.36,"CCA348",-12)
  for i,angle in ipairs({-34,0,34})do part(host,"CitrineSeed"..i,.43+(i-2)*.09,.19,.08,.22,"E3D254",angle)end
  for i,seat in ipairs({{.18,.22,-35},{.72,.16,28},{.70,.43,55}})do part(host,"WarmSpark"..i,seat[1],seat[2],.04,.12,"FFE59C",seat[3])end
 elseif id=="bone"then
  part(host,"OchreWaist",.24,.43,.52,.14,"BB934D",-12)
  for _,seat in ipairs({{.13,.32},{.15,.49},{.67,.24},{.70,.42}})do part(host,"SeafoamLobe",seat[1],seat[2],.21,.23,"92D7B6")end
  part(host,"OffcenterWrap",.43,.38,.10,.20,"F5DFAC",-12)
 elseif id=="horns"then
  for _,side in ipairs({-1,1})do
   local base=.5+side*.20
   for i=0,5 do
    local t=i/5;part(host,"HornSeed"..side.."_"..i,base+side*t*t*.10-.05,.66-t*.43,.13*(1-t*.65),.15*(1-t*.3),"F5E5BF",side*(-10-t*25))
   end
   part(host,"BasalCollar"..side,base-.07,.67,.17,.08,"78B7A9",side*8)
  end
 elseif id=="claws"then
  for i=0,3 do part(host,"RoundedClaw"..i,.20+i*.15,.34+(i%2)*.05,.12,.36,"F3EBD6",12-i*8)end
  part(host,"ClawBase",.18,.64,.63,.10,"9BC4AD")
 elseif id=="wings"then
  for _,side in ipairs({-1,1})do
   for i=0,3 do part(host,"FoldedFan"..side.."_"..i,.47+side*(.07+i*.055)-.05,.50-i*.045,.11,.33-i*.025,if i==3 then "F3E4C4"else "ACD8BF",side*(25+i*12))end
  end
 end
 return host
end
return Item
