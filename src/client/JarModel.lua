-- Customization Egg jar art as 3D models (slice 3, 2026-11-16): hue jars, finish jars and the
-- rare charm capsule, from the approved paint-pot family (scripts/build_customization_jars.py,
-- uploaded Model, ReplicatedStorage.JarAssets, data in JarModelData).
-- JarModel.build(itemId, scale) returns a Model centred on its base, front facing +Z like the toys
-- (the import arrives facing -Z, so it is turned half a turn), or nil
-- when the item has no jar or a template mesh is missing (callers keep their flat art).
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Data=require(script.Parent.JarModelData)
local Jar={}
local turn=CFrame.Angles(0,math.pi,0)
-- Item id -> jar art id: every charm drop shows the capsule.
function Jar.artId(itemId)
 if type(itemId)~="string"then return nil end
 if string.sub(itemId,1,6)=="charm_"or itemId=="charm"then return "charm"end
 return if Data.Items[itemId]then itemId else nil
end
function Jar.known(itemId)return Jar.artId(itemId)~=nil end
local function template(name)
 local pack=ReplicatedStorage:FindFirstChild("JarAssets")
 local part=pack and pack:FindFirstChild(name)
 return if part and part:IsA("MeshPart")and part.MeshId~=""then part else nil
end
function Jar.ready(itemId)
 local art=Jar.artId(itemId);if not art then return false end
 for _,row in ipairs(Data.Items[art])do if not template(row.name)then return false end end
 return true
end
-- `scale` maps studs-in-data to studs (default .01: one unit is one Blender unit).
-- options.turn=false keeps the imported facing (the 3D reveal stage looks from the other side).
function Jar.build(itemId,scale,options)
 local art=Jar.artId(itemId);if not art or not Jar.ready(itemId)then return nil end
 scale=scale or .01
 local model=Instance.new("Model");model.Name="Jar_"..art;model:SetAttribute("ItemId",itemId)
 local facing=if options and options.turn==false then CFrame.identity else turn
 for _,row in ipairs(Data.Items[art])do
  local part=template(row.name):Clone()
  part.Name=row.part;part.Size=row.size*scale;part.CFrame=facing*CFrame.new(row.position*scale)
  part.Color=Color3.fromHex(row.color);part.Transparency=row.transparency;part.Reflectance=row.reflectance
  part.Material=Enum.Material[row.material]or Enum.Material.SmoothPlastic
  part.Anchored=true;part.CanCollide=false;part.CanTouch=false;part.CanQuery=false;part.CastShadow=false
  -- The pigment and jelly cores are half shells seen from their open side through the glass.
  if row.part=="Liquid"or row.part=="Core"or row.part=="Dome"then part.DoubleSided=true end
  part.Parent=model
 end
 -- A charm drop shows what was won: the real charm shape replaces the capsule's gold star.
 local shape=string.match(itemId,"^charm_(.+)$")
 local star=model:FindFirstChild("Charm")
 if shape and star then
  local inner=require(script.Parent.CharmShapeModel).build(shape)
  if inner then
   require(script.Parent.CharmShapeModel).fit(inner,star.CFrame,math.max(star.Size.X,star.Size.Y)*.85)
   for _,part in ipairs(inner:GetChildren())do part.Parent=model end
   inner:Destroy();star:Destroy()
  end
 end
 return model
end
-- A ViewportFrame showing the jar, framed from the front a little above. `host` is any
-- GuiObject; the frame fills it. Returns the frame and the model (nil when not ready).
function Jar.viewport(host,itemId,options)
 options=options or {}
 local model=Jar.build(itemId,1)
 if not model then return nil end
 local frame=Instance.new("ViewportFrame");frame.Name="JarViewport";frame.BackgroundTransparency=1
 frame.Size=UDim2.fromScale(1,1);frame.Active=false;frame.Selectable=false;frame.ZIndex=host.ZIndex+1
 frame.Ambient=Color3.fromRGB(170,170,180);frame.LightColor=Color3.new(1,1,1);frame.LightDirection=Vector3.new(-.4,-1,-.6)
 local camera=Instance.new("Camera");camera.FieldOfView=options.fov or 30;camera.Parent=frame;frame.CurrentCamera=camera
 model.Parent=frame
 local cf,size=model:GetBoundingBox()
 local radius=math.max(size.X,size.Y,size.Z)*.5
 local distance=radius/math.tan(math.rad(camera.FieldOfView*.5))*(options.zoom or 1.3)
 local target=cf.Position
 camera.CFrame=CFrame.lookAt(target+Vector3.new(0,radius*.35,distance),target)
 frame.Parent=host
 return frame,model
end
return Jar
