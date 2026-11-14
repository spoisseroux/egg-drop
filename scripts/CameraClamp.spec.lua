-- QA v2 R2.3 / R2.5 / R2.6: the garden camera clamp (pure resolve and one stepped frame
-- with a fake cast), the device hint glyph table and the lower-right dock placement.
-- No real camera, character or world is moved.
-- Usage: require(PlayerScripts.Client.ZZSpecs.CameraClamp)(PlayerScripts.Client, PlayerGui)
return function(client,_parent)
 local Clamp=require(client.CameraClamp)
 local Glyphs=require(client.HintGlyphs)
 local Room=require(client.RoomView)
 local UICopy=require(game:GetService("ReplicatedStorage").Shared.UICopy)
 local cases={}
 local function test(name,run)run();table.insert(cases,name)end
 local function near(a,b)return(a-b).Magnitude<1e-3 end
 test("clear line: the camera stays put",function()
  assert(Clamp.resolve(Vector3.new(0,5,0),Vector3.new(0,8,12),nil)==nil)
  assert(Clamp.resolve(Vector3.new(0,5,0),Vector3.new(0,8,12),20)==nil,"hit beyond the camera")
 end)
 test("ground or wall in the way: the camera pulls in front of it",function()
  local focus,camera=Vector3.new(0,5,0),Vector3.new(0,-3,6) -- 10 studs away, below the ground
  local out=Clamp.resolve(focus,camera,4,.1,.5)
  assert(out and near(out,focus+(camera-focus).Unit*3.9),tostring(out))
  assert((out-focus).Magnitude<(camera-focus).Magnitude)
 end)
 test("the clamp never goes nearer than the minimum and leaves first person alone",function()
  local focus=Vector3.new(0,5,0)
  local out=Clamp.resolve(focus,Vector3.new(0,5,10),.2,.1,.5)
  assert(out and near((out-focus),Vector3.new(0,0,.5)))
  assert(Clamp.resolve(focus,Vector3.new(0,5,.3),.1,.1,.5)==nil,"first person")
 end)
 test("a step clamps a Custom camera through the injected cast, keeps its rotation",function()
  local camera=workspace.CurrentCamera
  local saved,savedType,savedFocus=camera.CFrame,camera.CameraType,camera.Focus
  local world=Instance.new("Folder")
  local ok,problem=pcall(function()
   local casts=0
   local clamp=Clamp.new({active=function()return true end,world=function()return world end,
    cast=function(origin,radius,direction,params)
     casts+=1;assert(radius==Clamp.Radius and params.FilterType==Enum.RaycastFilterType.Include and params.RespectCanCollide)
     return{Distance=direction.Magnitude*.5}
    end})
   camera.CameraType=Enum.CameraType.Custom
   local look=CFrame.lookAt(Vector3.new(0,1010,20),Vector3.new(0,1000,0))
   camera.CFrame,camera.Focus=look,CFrame.new(0,1000,0)
   local stepped=clamp:step()
   local after=camera.CFrame
   assert(stepped and casts==1 and clamp.clamped==1)
   assert(near(after.LookVector,look.LookVector),"rotation kept")
   local was=(look.Position-Vector3.new(0,1000,0)).Magnitude
   assert(math.abs((after.Position-Vector3.new(0,1000,0)).Magnitude-(was*.5-Clamp.Pad))<1e-3,"pulled to the hit less the pad")
   camera.CameraType=Enum.CameraType.Scriptable
   assert(clamp:step()==false and casts==1,"scripted shots (focus, deck) are never clamped")
   clamp:destroy()
  end)
  camera.CameraType,camera.CFrame,camera.Focus=savedType,saved,savedFocus
  world:Destroy();assert(ok,problem)
 end)
 test("hint glyphs: each device shows its real keys; touch shows none",function()
  assert(Glyphs.glyph("confirm","Gamepad")=="A"and Glyphs.glyph("back","Gamepad")=="B"and Glyphs.glyph("browse","Gamepad")=="+")
  assert(Glyphs.glyph("confirm","Keyboard")=="ENTER"and Glyphs.glyph("back","Keyboard")=="BKSP"and Glyphs.glyph("tab","Keyboard")=="Q/E")
  assert(Glyphs.glyph("confirm","Keyboard")~="A","keyboard A moves left in menus")
  for _,action in ipairs(Glyphs.Actions)do assert(Glyphs.glyph(action,"Touch")==nil)end
  assert(Glyphs.kindOf(Enum.UserInputType.Gamepad1)=="Gamepad"and Glyphs.kindOf(Enum.UserInputType.Touch)=="Touch"
   and Glyphs.kindOf(Enum.UserInputType.MouseButton1)=="Keyboard")
  local rows=Glyphs.rows({{"browse","Browse"},{"confirm","Hatch"},{"back","Back"}},"Keyboard")
  assert(#rows==3 and rows[2][1]=="ENTER"and rows[2][2]=="Hatch"and Glyphs.accent(rows[2][3]))
  assert(#Glyphs.rows({{"confirm","Hatch"}},"Touch")==0)
  for _,kind in ipairs({"Gamepad","Keyboard","Touch"})do assert(UICopy.has(Glyphs.legendKey(kind)),kind)end
  for _,action in ipairs(Glyphs.Actions)do assert(UICopy.has("input.action."..action),action)end
 end)
 test("dock: lower right, above the jump button on touch, never top right",function()
  local pc=Room.dockPlacement(1649,971,false)
  assert(pc.Y.Scale==1 and pc.Y.Offset==-16 and pc.X.Scale==1 and pc.X.Offset==-16)
  local phone=Room.dockPlacement(812,354,true)
  assert(phone.Y.Scale==1 and phone.Y.Offset==-102,"small screen jump 90 + 12")
  local tablet=Room.dockPlacement(1024,768,true)
  assert(tablet.Y.Offset==-152,"large screen jump 140 + 12")
  assert(Room.dockPlacement(812,354,true,77.6).Y.Offset==-89,"measured jump top, integer offset")
  local tiny=Room.dockPlacement(568,160,true,140)
  assert(tiny.Y.Offset==-(160-48-8),"stays on screen")
  for _,p in ipairs({pc,phone,tablet,tiny})do assert(p.X.Offset==math.floor(p.X.Offset)and p.Y.Offset==math.floor(p.Y.Offset))end
 end)
 return{passed=#cases,cases=cases}
end
