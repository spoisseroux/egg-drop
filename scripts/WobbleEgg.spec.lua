-- The Wobble Egg (GARDEN-PLAY-BRIEF section 3): finding the landmark, the scale, the timetable, the motion, the
-- set-off rule and the night glow. Shared and pure.
return function()
	local Egg=require(game:GetService("ReplicatedStorage").Shared.WobbleEgg)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	test("isLandmark: the name, near the measured centre and size; anything else is not the egg",function()
		assert(Egg.isLandmark(Egg.LandmarkName,Vector3.new(17,17.2,-45),Vector3.new(4.7,5.53,4.7)))
		assert(not Egg.isLandmark("W7_CD_Landmarks__marble",Vector3.new(17,17.2,-45),Vector3.new(4.7,5.53,4.7)),"other name")
		assert(not Egg.isLandmark(Egg.LandmarkName,Vector3.new(40,17,-45),Vector3.new(4.7,5.53,4.7)),"far away")
		assert(not Egg.isLandmark(Egg.LandmarkName,Vector3.new(17,17.2,-45),Vector3.new(30,12,30)),"a whole chunk, not the egg")
		assert(not Egg.isLandmark(Egg.LandmarkName,nil,nil))
	end)
	test("scaleFor: as tall as the landmark (5.53 / 1.3); junk is 1",function()
		assert(math.abs(Egg.scaleFor(5.53)*Egg.MeshHeight-5.53)<1e-9)
		assert(Egg.scaleFor(0)==1 and Egg.scaleFor(-2)==1 and Egg.scaleFor(0/0)==1 and Egg.scaleFor(nil)==1)
	end)
	test("nextBig: 35 to 50 s later",function()
		assert(Egg.nextBig(100,0)==135 and Egg.nextBig(100,1)==150 and Egg.nextBig(100,.5)==142.5)
		assert(Egg.nextBig(0,-3)==35 and Egg.nextBig(0,9)==50,"the roll is clamped")
	end)
	test("bigAngle: two swings inside 7 degrees that die away, then nil once settled",function()
		local peak=0
		for i=0,159 do local a=Egg.bigAngle(i/100);assert(a);peak=math.max(peak,math.abs(a))end
		assert(peak<=Egg.Big.degrees and peak>Egg.Big.degrees*.4,peak)
		assert(math.abs(Egg.bigAngle(0))<1e-9,"starts upright")
		assert(Egg.bigAngle(Egg.Big.settle)==nil and Egg.bigAngle(-.1)==nil)
		assert(math.abs(Egg.bigAngle(Egg.Big.settle-.01))<.05,"settles to upright")
	end)
	test("angle: the big wobble replaces the idle rock while it runs; reduced motion is still",function()
		assert(math.abs(Egg.angle(10,nil,0,false)-Egg.idleAngle(10,0))<1e-9)
		assert(math.abs(Egg.angle(10.5,10,0,false)-Egg.bigAngle(.5))<1e-9)
		assert(math.abs(Egg.angle(20,10,0,false)-Egg.idleAngle(20,0))<1e-9,"back to idle after the settle")
		assert(Egg.angle(10.3,10,0,true)==0 and Egg.angle(3,nil,.2,true)==0)
		for t=0,10,.25 do assert(math.abs(Egg.idleAngle(t,.3))<=Egg.Idle.degrees+1e-9)end
	end)
	test("setOff: within 8 studs and not during or just after the last one",function()
		assert(Egg.setOff(5,100,nil))
		assert(not Egg.setOff(9,100,nil),"too far")
		assert(not Egg.setOff(nil,100,nil),"no character")
		assert(not Egg.setOff(5,101,100),"cooldown")
		assert(Egg.setOff(5,100+Egg.Cooldown+Egg.Big.settle+.01,100))
	end)
	test("glow: none by day, full at night, a ramp between",function()
		assert(Egg.glow(1)==0 and Egg.glow(.3)==0 and Egg.glow(.1)==1 and Egg.glow(0)==1)
		assert(math.abs(Egg.glow(.2)-.5)<1e-9 and Egg.glow(nil)==0)
	end)
	return{passed=#cases,cases=cases}
end
