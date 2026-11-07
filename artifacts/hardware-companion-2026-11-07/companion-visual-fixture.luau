local P=game.Players.LocalPlayer local C=P.PlayerScripts.Client local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
local Prestige=require(C.PetPrestige)local Bounds=require(C.PetRigBounds)local Shot=require(C.PetGreetingShot)
local cam=workspace.CurrentCamera local saved={cf=cam.CFrame,focus=cam.Focus,fov=cam.FieldOfView,type=cam.CameraType}local owned={}
for _,g in P.PlayerGui:GetChildren()do if g:IsA("ScreenGui")and g.Name~="QACompanionSceneLabel"then table.insert(owned,{g,g.Enabled});g.Enabled=false end end
local folder=Instance.new("Folder")folder.Name="_QACompanionScene"folder.Parent=workspace
local ui=Instance.new("ScreenGui")ui.Name="QACompanionSceneLabel"ui.ScreenInsets=Enum.ScreenInsets.CoreUISafeInsets ui.Parent=P.PlayerGui
local label=Instance.new("TextLabel")label.Size=UDim2.new(1,-24,0,44)label.Position=UDim2.fromOffset(12,8)label.BackgroundColor3=Color3.fromRGB(35,42,30)label.BackgroundTransparency=.1 label.TextColor3=Color3.fromRGB(255,242,208)label.Font=Enum.Font.GothamBold label.TextSize=16 label.Parent=ui
local v,wall,id,viewport,desired
local cleaned=false local function cleanup()if cleaned then return end cleaned=true game:GetService('RunService'):UnbindFromRenderStep('QACompanionSceneCamera') if v then v:destroy()end folder:Destroy()ui:Destroy()for _,e in owned do if e[1].Parent then e[1].Enabled=e[2]end end cam.CameraType=saved.type cam.CFrame=saved.cf cam.Focus=saved.focus cam.FieldOfView=saved.fov script:SetAttribute("Cleaned",true)end
script.Destroying:Connect(cleanup)
game:GetService("RunService"):BindToRenderStep("QACompanionSceneCamera",2000,function()if desired then cam.CameraType=Enum.CameraType.Scriptable cam.CFrame=desired.camera cam.Focus=CFrame.new(desired.target)cam.FieldOfView=43 if v then Prestige.updateBadge(v,cam)end end end)
local ok,err=pcall(function()while script.Parent and not script:GetAttribute("Cleanup")do
 local nextID=script:GetAttribute("PetId")or"foxfire_wick"local vs=cam.ViewportSize
 if id~=nextID or viewport~=vs then if v then v:destroy()end if wall then wall:Destroy();wall=nil end id=nextID viewport=vs local pet=Pets.byId[id]local family=pet.family or pet.id local module=if family=="pip"then C.PipVisual elseif family=="puddle"then C.PuddleVisual else C.BonusPetVisual
 v=require(module).new(folder,Vector3.new(30,4.025,15),pet,.72)Prestige.attach(v,pet,3,false)v.greeting=3 v:update(0)local cf,size=Bounds.get(v)
 local plan=Shot.plan({rootPosition=Vector3.new(30,7,28),forward=Vector3.new(0,0,-1),size=size,centerOffset=cf.Position-v.origin,aspect=vs.X/vs.Y,crestPixelReserve=32,viewportHeight=vs.Y,safeTopInset=game:GetService("GuiService"):GetGuiInset().Y,animationTopReserve=.864,floor={cf=CFrame.new(0,3.5,0),size=Vector3.new(112,1,96)},ground=function()return 4.025 end,clear=function()return true end})
 assert(plan,"fixture plan failed")desired=plan v.origin,v.yaw=plan.origin,plan.yaw cam.CameraType=Enum.CameraType.Scriptable cam.CFrame=plan.camera cam.Focus=CFrame.new(plan.target)cam.FieldOfView=43
 end
 v.greeting=script:GetAttribute("Pose")or .5 v.time=1 v:update(0)Prestige.update(v,0,true)
 label.Text="STUDIO VISUAL FIXTURE · "..Pets.byId[id].name.." · world size 72% · rank III"
 if script:GetAttribute("Wall")and not wall then wall=Instance.new("Part")wall.Name="SolidOcclusionFixture"wall.Anchored=true wall.CanCollide=false wall.Size=Vector3.new(9,9,.5)wall.CFrame=CFrame.lookAt(cam.CFrame.Position:Lerp(v.model.PrimaryPart.Position,.55),cam.CFrame.Position)wall.Color=Color3.fromRGB(75,99,64)wall.Parent=folder elseif not script:GetAttribute("Wall")and wall then wall:Destroy();wall=nil end
 local b=v.prestigeBadge local point=cam:WorldToViewportPoint(v.model.PrimaryPart.Position+b.StudsOffsetWorldSpace)script:SetAttribute("BadgeEnabled",b.Enabled)script:SetAttribute("PlateBottom",point.Y+13)
 task.wait(.03)
 end end)
cleanup()if not ok then script:SetAttribute("Failure",tostring(err))end