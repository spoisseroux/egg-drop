-- Geometry fixture only: original production meshes, no grants, inputs or profile writes.
local c=game.Players.LocalPlayer.PlayerScripts.Client
require(game.ReplicatedStorage._DeviceFinalQA.PetAssetsReadyFixture)(c)
local Art=require(c.DeckArt);local Factory=require(c.PetFactory);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog);local Bounds=require(c.PetRigBounds)
local gui=Instance.new("ScreenGui");gui.Name="_PetFeatureStudy";gui.IgnoreGuiInset=true;gui.DisplayOrder=950;gui.Parent=game.Players.LocalPlayer.PlayerGui
local root=Art.frame(gui,"Study",Color3.fromRGB(225,239,242),UDim2.fromScale(.035,.035),UDim2.fromScale(.93,.93),2)
local title=Art.text(root,"Title","",UDim2.fromScale(.02,0),UDim2.fromScale(.96,.065),Color3.fromRGB(15,48,55),22);title.TextXAlignment=Enum.TextXAlignment.Center
local visuals={}
local function rebuild()
 for _,v in visuals do v:destroy()end;table.clear(visuals)
 for _,v in root:GetChildren()do if v.Name:sub(1,4)=="Card"then v:Destroy()end end
 local stage=script:GetAttribute("Stage")or 5;local yaw=math.rad(script:GetAttribute("Yaw")or-20);local high=script:GetAttribute("High")==true;local native=script:GetAttribute("Native")==true;local night=script:GetAttribute("Night")==true
 title.Text="GEOMETRY FIXTURE · all features "..stage.."/5 · "..(if native then "native fallback"else "authored").." · "..(if night then "night portrait lighting"else "day portrait lighting")
 for i,p in ipairs(Pets.collection)do
 local col=(i-1)%4;local row=math.floor((i-1)/4)
 local card=Art.frame(root,"Card"..i,Color3.fromRGB(201,223,227),UDim2.fromScale(.01+col*.247,.075+row*.45),UDim2.fromScale(.237,.43),3);Art.corner(card,10)
 local vp=Instance.new("ViewportFrame");vp.ZIndex=4;vp.Size=UDim2.fromScale(1,.88);vp.BackgroundTransparency=1;vp.Ambient=if night then Color3.fromRGB(50,66,100)else Color3.fromRGB(160,180,185);vp.LightColor=if night then Color3.fromRGB(120,155,205)else Color3.fromRGB(245,245,235);vp.LightDirection=Vector3.new(-1,-1,-2);vp.Parent=card
 local world=Instance.new("WorldModel");world.Parent=vp
 local v=Factory.new(world,Vector3.zero,p,1,{charmVisible=true,charmShape="ring",featureStages={horns=stage,claws=stage,wings=stage},secondaryColor=Color3.fromRGB(128,165,185)},{native=native})
 v.reducedEffects=true;v:update(0);table.insert(visuals,v)
 local cf,size=Bounds.get(v);local cam=Instance.new("Camera");cam.FieldOfView=30;cam.Parent=vp;vp.CurrentCamera=cam
 local aspect=vp.AbsoluteSize.X/math.max(1,vp.AbsoluteSize.Y);local tan=math.tan(math.rad(15));local d=math.max(size.Y,size.X/math.max(.2,aspect))/(2*tan)*1.20+size.Z*.5
 local direction=Vector3.new(math.sin(yaw),if high then .9 else .12,math.cos(yaw)).Unit
 cam.CFrame=CFrame.lookAt(cf.Position+direction*d,cf.Position)
 local label=Art.text(card,"Name",p.name.." · "..v.backend,UDim2.fromScale(.02,.88),UDim2.fromScale(.96,.10),Color3.fromRGB(15,48,55),17);label.TextXAlignment=Enum.TextXAlignment.Center
 end
end
for _,a in ipairs({"Stage","Yaw","High","Native","Night"})do script:GetAttributeChangedSignal(a):Connect(rebuild)end
script.Destroying:Connect(function()for _,v in visuals do v:destroy()end;gui:Destroy()end)
game.RunService.Heartbeat:Wait();rebuild()
