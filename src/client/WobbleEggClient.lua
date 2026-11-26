-- The Wobble Egg on the crag (Shared.WobbleEgg has the why and the numbers). Client-only and local: the landmark's
-- flat palette egg is hidden with LocalTransparencyModifier and the Companion Egg's two shell meshes take its place,
-- seated in a twig-and-moss collar. Behind the Alive switch `wobble` (beta and Studio only); off puts the landmark back.
local Players=game:GetService("Players")
local RunService=game:GetService("RunService")
local GuiService=game:GetService("GuiService")
local UserInputService=game:GetService("UserInputService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local Egg=require(ReplicatedStorage.Shared.WobbleEgg)
local Alive=require(ReplicatedStorage.Shared.Alive)
local Models=require(ReplicatedStorage.Shared.EggModels)

local Client={};Client.__index=Client
Client.Feature="wobble"
Client.Twig=Color3.fromHex("#6B4A2E")
Client.Moss=Color3.fromHex("#7A9A52")
Client.Sounds=table.freeze({wobble=103643084989292,set={91020394353931,104868695089653,74341448004566}})
Client.Cull=table.freeze({phone=90,desktop=150})

local function createMesh(uri)
	local ok,part=pcall(function()return game:GetService("AssetService"):CreateMeshPartAsync(Content.fromUri(uri))end)
	if ok and part then return part end
	ok,part=pcall(function()return game:GetService("AssetService"):CreateMeshPartAsync(uri)end)
	return if ok then part else nil
end
local function quiet(part)
	part.Anchored=true;part.CanCollide=false;part.CanQuery=false;part.CanTouch=false
	return part
end
local function sound(parent,id,volume)
	local s=Instance.new("Sound");s.SoundId="rbxassetid://"..id;s.Volume=volume or .6
	s.RollOffMode=Enum.RollOffMode.InverseTapered;s.RollOffMinDistance=6;s.RollOffMaxDistance=Egg.Hear
	s.Parent=parent
	return s
end

-- The landmark egg, or nil (only the beta world has it as its own part).
function Client.findLandmark(root)
	root=root or workspace
	local world=root:FindFirstChild("EggDropLounge")and root.EggDropLounge:FindFirstChild("World")
	local part=world and world:FindFirstChild(Egg.LandmarkName)
	if part and part:IsA("BasePart")and Egg.isLandmark(part.Name,part.Position,part.Size)then return part end
	return nil
end

function Client.new(landmark)
	local self=setmetatable({landmark=landmark,phase=math.random(),bigAt=nil,lastBig=nil,axis=Vector3.new(1,0,0)},Client)
	local foot=landmark.CFrame*CFrame.new(0,-landmark.Size.Y/2,0)
	self.foot=CFrame.new(foot.Position)*CFrame.Angles(0,math.random()*math.pi*2,0)
	self.nextBig=Egg.nextBig(os.clock(),math.random())
	local s=Egg.scaleFor(landmark.Size.Y)
	local model=Instance.new("Model");model.Name="WobbleEgg"
	self.model=model
	-- The two shells, at their place over the foot (EggModels centres are from the egg's base).
	self.shells={}
	for _,key in ipairs({"BottomShell","TopShell"})do
		local spec=Models.Egg[key]
		local part=createMesh(spec.mesh)
		if not part then model:Destroy();return nil end
		quiet(part);part.Name=key;part.Size=spec.size*s
		part.TextureID=Models.Types.companion.colorMap
		part.Material=Enum.Material.SmoothPlastic;part.Reflectance=0;part.Color=Color3.new(1,1,1)
		part.CastShadow=true
		part.Parent=model
		self.shells[key]={part=part,offset=CFrame.new(spec.center*s)}
	end
	-- The collar: a moss ring and twelve short twigs leaning on the shell's foot.
	local width=Models.Egg.BottomShell.size.X*s
	local moss=quiet(Instance.new("Part"));moss.Name="Moss";moss.Shape=Enum.PartType.Cylinder
	moss.Size=Vector3.new(.5,width*.95,width*.95);moss.Material=Enum.Material.Grass;moss.Color=Client.Moss
	moss.CFrame=self.foot*CFrame.new(0,.2,0)*CFrame.Angles(0,0,math.pi/2);moss.Parent=model
	for index=1,12 do
		local a=index/12*math.pi*2+(index%2)*.2
		local twig=quiet(Instance.new("Part"));twig.Name="Twig";twig.Shape=Enum.PartType.Cylinder
		twig.Size=Vector3.new(width*.42+(index%3)*.15,.16,.16);twig.Material=Enum.Material.Wood;twig.Color=Client.Twig
		-- Along the ring (a cylinder's axis is X, tangent here), each tipped the other way from its neighbour: a nest weave.
		twig.CFrame=self.foot*CFrame.Angles(0,a,0)*CFrame.new(0,.45+(index%3)*.08,-width*.43)
			*CFrame.Angles(0,0,.35*(if index%2==0 then 1 else -1))
		twig.Parent=model
	end
	-- The night glow and the voices sit at the egg's middle (moved with it).
	local heart=quiet(Instance.new("Part"));heart.Name="Heart";heart.Transparency=1;heart.Size=Vector3.one*.2;heart.Parent=model
	self.heart,self.heartOffset=heart,CFrame.new(0,landmark.Size.Y*.5,0)
	local light=Instance.new("PointLight");light.Color=Egg.Night.colour;light.Range=Egg.Night.range;light.Brightness=0
	light.Shadows=false;light.Parent=heart
	self.light=light
	self.wobbleSound=sound(heart,Client.Sounds.wobble,.55)
	self.setSounds={}
	for _,id in ipairs(Client.Sounds.set)do table.insert(self.setSounds,sound(heart,id,.45))end
	-- Moss flecks shaken loose by a big wobble.
	local flecks=Instance.new("ParticleEmitter");flecks.Name="Flecks";flecks.Rate=0;flecks.Color=ColorSequence.new(Client.Moss)
	flecks.Size=NumberSequence.new(.18);flecks.Lifetime=NumberRange.new(1,1.6);flecks.Speed=NumberRange.new(1,2.5)
	flecks.SpreadAngle=Vector2.new(70,70);flecks.Acceleration=Vector3.new(0,-14,0);flecks.Drag=1.5
	flecks.Rotation=NumberRange.new(0,360);flecks.RotSpeed=NumberRange.new(-90,90);flecks.LightInfluence=1
	flecks.Parent=heart
	self.flecks=flecks
	model.Parent=workspace
	landmark.LocalTransparencyModifier=1
	self:pose(0)
	return self
end

function Client:pose(degrees)
	local tilt=CFrame.fromAxisAngle(self.axis,math.rad(degrees))
	local at=self.foot*tilt
	for _,shell in pairs(self.shells)do shell.part.CFrame=at*shell.offset end
	self.heart.CFrame=at*self.heartOffset
end

function Client:startBig(now,byMe)
	self.bigAt,self.lastBig=now,now
	local a=math.random()*math.pi*2
	self.axis=Vector3.new(math.cos(a),0,math.sin(a))
	self.nextBig=Egg.nextBig(now,math.random())
	self.wobbleSound.PlaybackSpeed=.95+math.random()*.1
	self.wobbleSound:Play()
	self.flecks:Emit(4)
	if byMe then
		local set=self.setSounds[math.random(1,#self.setSounds)]
		set.PlaybackSpeed=.94+math.random()*.12;set:Play()
		pcall(function()require(script.Parent.Haptics).play("settle")end)
	end
end

function Client:step(now,reduced,daylight)
	local character=Players.LocalPlayer and Players.LocalPlayer.Character
	local root=character and character:FindFirstChild("HumanoidRootPart")
	local distance=root and(root.Position-self.foot.Position).Magnitude
	if not reduced then
		if Egg.setOff(distance,now,self.lastBig)then self:startBig(now,true)
		elseif now>=self.nextBig and(self.bigAt==nil or Egg.bigAngle(now-self.bigAt)==nil)then self:startBig(now,false)end
	end
	if self.bigAt and Egg.bigAngle(now-self.bigAt)==nil then
		self.bigAt=nil
		self.axis=Vector3.new(1,0,0)
	end
	self:pose(Egg.angle(now,self.bigAt,self.phase,reduced))
	self.light.Brightness=Egg.Night.brightness*Egg.glow(daylight)
end

function Client:destroy()
	if self.model then self.model:Destroy();self.model=nil end
	if self.landmark then self.landmark.LocalTransparencyModifier=0 end
end

-- The controller: watches the switch, builds when on and the landmark exists, steps only while the camera is near.
function Client.mount()
	if not Alive.ceiling(Client.Feature)then return nil end
	local controller={egg=nil,connections={}}
	local Clock=require(script.Parent.HollowClock)
	local phone=UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	local cull=if phone then Client.Cull.phone else Client.Cull.desktop
	local function stop()
		if controller.egg then controller.egg:destroy();controller.egg=nil end
		if controller.step then controller.step:Disconnect();controller.step=nil end
	end
	local function start()
		if controller.egg or not Alive.on(Client.Feature)then return end
		local landmark=Client.findLandmark()
		if not landmark then return end
		controller.egg=Client.new(landmark)
		if not controller.egg then return end
		controller.step=RunService.Heartbeat:Connect(function()
			local egg=controller.egg
			if not egg then return end
			local camera=workspace.CurrentCamera
			if camera and(camera.CFrame.Position-egg.foot.Position).Magnitude>cull then return end
			local ok,daylight=pcall(Clock.daylight)
			egg:step(os.clock(),GuiService.ReducedMotionEnabled,if ok then daylight else 1)
		end)
	end
	local function refresh()if Alive.on(Client.Feature)then start()else stop()end end
	table.insert(controller.connections,Alive.changed(Client.Feature):Connect(refresh))
	-- The world can arrive after us: try again when pieces land in the lounge, until the egg is built.
	table.insert(controller.connections,workspace.DescendantAdded:Connect(function(node)
		if not controller.egg and node.Name==Egg.LandmarkName then task.defer(refresh)end
	end))
	refresh()
	function controller:destroy()
		stop()
		for _,c in ipairs(self.connections)do c:Disconnect()end
		table.clear(self.connections)
	end
	return controller
end

return Client
