-- Garden Dash see-through (DashFade): crowns by measured stretch, pillars by ray, every part given back its own value.
-- Usage (Client): require(ZZSpecs.DashFade)(StarterPlayerScripts.Client)
return function(client)
	local Course=require(game:GetService("ReplicatedStorage").Shared.DashCourse)
	local Fade=require(client.DashFade)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local EYE,PET=Vector3.new(0,9,0),Vector3.new(-14,1,0)
	local function world()
		local folder=Instance.new("Folder")
		local function part(name,prior)
			local item=Instance.new("MeshPart");item.Name=name;item.LocalTransparencyModifier=prior or 0;item.Parent=folder
			return item
		end
		return folder,{crown=part("W7_Vegetation__foliage"),pillar=part("W7_Architecture__marble",.2),ground=part("W7_Ground__grass"),cell=part("W7C_Architecture_01"),bridge=part("W7_Bridge__marble")}
	end
	local function rig()
		local folder,parts=world()
		local r={parts=parts,hit=nil,asked=nil}
		r.fade=Fade.new({world=function()return folder end,cast=function(_,_,solids)r.asked=solids;return r.hit end})
		function r.run(seconds,cs,stones)
			for _=1,math.ceil(seconds*60)do r.fade:step(1/60,EYE,PET,cs or 0,stones==true)end
		end
		return r
	end
	local zone=Fade.Zones[1]
	test("a crown is 75% clear inside its stretch, and itself again after it; only on its own way round",function()
		local r=rig()
		r.run(1,0);assert(r.parts.crown.LocalTransparencyModifier==0)
		r.run(.5,zone.from+10);assert(math.abs(r.parts.crown.LocalTransparencyModifier-Fade.Clear)<1e-9)
		r.run(1,zone.to+10);assert(r.parts.crown.LocalTransparencyModifier==0 and next(r.fade.records)==nil)
		r.run(.5,zone.from+10,true);assert(r.parts.crown.LocalTransparencyModifier==0)
	end)
	test("a pillar in the way clears and keeps its own value; the ground, colliders and the bridge are never asked",function()
		local r=rig();r.hit=r.parts.pillar
		r.run(.6);assert(math.abs(r.parts.pillar.LocalTransparencyModifier-Fade.Clear)<1e-9)
		assert(#r.asked==1 and r.asked[1]==r.parts.pillar)
		r.hit=nil;r.run(.1);assert(r.parts.pillar.LocalTransparencyModifier==Fade.Clear,"held for a moment: no flicker")
		r.run(1);assert(r.parts.pillar.LocalTransparencyModifier==.2)
	end)
	test("release gives everything back at once, twice is nothing, and the next race finds its meshes again",function()
		local r=rig();r.hit=r.parts.pillar
		r.run(.6,zone.from+10);r.fade:release();r.fade:release()
		assert(r.parts.pillar.LocalTransparencyModifier==.2 and r.parts.crown.LocalTransparencyModifier==0 and next(r.fade.records)==nil and not r.fade.ready)
		r.run(.6,zone.from+10);assert(r.parts.crown.LocalTransparencyModifier==Fade.Clear);r.fade:release()
		r.run(.6,zone.from+10);r.parts.crown:Destroy();r.run(.6,0);r.fade:release()
	end)
	test("no world yet: nothing happens",function()
		local fade=Fade.new({world=function()return nil end})
		for _=1,30 do fade:step(1/60,EYE,PET,zone.from+10,false)end
		fade:release()
	end)
	test("the measured stretches are short and on the course",function()
		for _,each in ipairs(Fade.Zones)do
			assert(each.from>=0 and each.to>each.from and each.to-each.from<=600 and each.to<=(if each.stones then Course.StonesLength else Course.Length))
		end
		assert(Course.Version==2,"a new line is measured again (scripts/measure_dash_camera.py)")
	end)
	return{passed=#cases,cases=cases}
end
