-- Studio Client, Studio only (the real engine; copy to ZZSpecs). Beta 14 garden life (GARDEN-LIFE-BUILD-PLAN): the parts
-- the offline mocks cannot vouch for. Ground plates (WorldDressingClient) carry a Top-face Decal and sit flat; the leaf
-- sheet emitter takes the 2 x 2 flipbook properties; LifeScene's lamp halos are BillboardGuis on Attachments and its star
-- a Beam between two; GardenLife with `scene` and `snack` on mounts LifeScene in its folder; LifePet's drive and pose
-- leave a real pet visual exactly where PetFollow put it while nothing is taken; the WindClient crowns read the breath only
-- with `scene` on.
-- Usage: require(PlayerScripts.Client.ZZSpecs.GardenLifeStudio)(PlayerScripts.Client), in Play on the beta build.
return function(client)
	local RunService=game:GetService("RunService")
	assert(RunService:IsStudio(),"Studio only")
	local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local made={}
	local ok,problem=pcall(function()
		test("ground plates: a Top-face Decal each, flat, inert, at the look's lift",function()
			local Flowers=require(client.WorldDressingClient)
			local plates=Flowers.groundPlates({scene=true,art=function()return "rbxassetid://129048015089227"end})
			assert(#plates==30,"30 plates: "..#plates)
			for _,plate in ipairs(plates)do
				local p=plate.part
				table.insert(made,p)
				local decal=p:FindFirstChildOfClass("Decal")
				assert(decal and decal.Face==Enum.NormalId.Top,p.Name)
				assert(math.abs(p.CFrame.UpVector.Y-1)<1e-6,"flat")
				assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch)
			end
		end)
		test("the leaf sheet's flipbook: Grid2x2, start random, framerate 0 (each leaf keeps its cell)",function()
			local e=Instance.new("ParticleEmitter")
			e.FlipbookLayout=Enum.ParticleFlipbookLayout.Grid2x2
			e.FlipbookMode=Enum.ParticleFlipbookMode.Loop
			e.FlipbookFramerate=NumberRange.new(0)
			e.FlipbookStartRandom=true
			assert(e.FlipbookLayout==Enum.ParticleFlipbookLayout.Grid2x2 and e.FlipbookStartRandom)
			e:Destroy()
		end)
		test("GardenLife with scene on: LifeScene's parts in its folder; halos on Attachments, the star a Beam",function()
			local Life=require(client.GardenLife)
			local world=Instance.new("Folder");world.Name="_GardenLifeStudioSpec";world.Parent=workspace
			table.insert(made,world)
			local beat=Instance.new("BindableEvent")
			local life=Life.mount({world=world,heartbeat=beat.Event,
				alive={ceiling=function()return true end,on=function()return true end,changed=function()return Instance.new("BindableEvent").Event end},
				level=function()return 0 end,hatching=function()return false end,mode=function()return "Room"end,reduced=function()return false end})
			assert(life and life.sceneParts,"the scene mounted")
			local lamps=world:FindFirstChild(Life.Folder):FindFirstChild("SceneLamps")
			local halo=lamps:FindFirstChildOfClass("Attachment"):FindFirstChildOfClass("BillboardGui")
			assert(halo and halo.Adornee and halo.Adornee:IsA("Attachment"),"a halo on an attachment")
			local star=world:FindFirstChild(Life.Folder):FindFirstChild("SceneStar"):FindFirstChildOfClass("Beam")
			assert(star and star.Attachment0 and star.Attachment1)
			for _=1,30 do beat:Fire(1/30)end
			life:destroy()
		end)
		test("LifePet with nothing taken writes nothing to a real pet visual",function()
			local LifePet=require(client.LifePet)
			local pet=LifePet.new({alive={ceiling=function()return true end,on=function()return true end}})
			local visual={origin=Vector3.new(0,4,0),yaw=1,pieces={},update=function()end}
			assert(pet:drive(visual,{mode="Room",behavior="rest"},workspace:GetServerTimeNow(),1/60)==false)
			assert(pet:pose(visual,1/60)==false and visual.origin==Vector3.new(0,4,0)and visual.yaw==1)
		end)
	end)
	for _,item in ipairs(made)do pcall(function()item:Destroy()end)end
	assert(ok,problem)
	return{passed=#cases,cases=cases}
end
