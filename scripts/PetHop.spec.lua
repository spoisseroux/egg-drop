-- Beta (42) note 16, D16: the torso moves with the feet (PetHop's pure rules: the air / ground split, the feet's lift,
-- the planting release, the walk's footfall dip).
-- Usage (Client): require(<client>.ZZSpecs.PetHop)(<client>); offline in scripts/run_dash_server_specs.py.
return function(client)
	local Hop=require(client.PetHop)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-9)end

	test("the hello, reaction, petting and gift hops are air; the bob, boop and idle rise stay on the ground",function()
		local air,ground=Hop.split(.72,1,0,0,0,0,0,0)
		assert(near(air,.11*.72)and near(ground,0),"hello")
		air,ground=Hop.split(.72,0,1,0,0,0,0,0);assert(near(air,.11*.72)and ground==0,"reaction")
		air,ground=Hop.split(.72,0,0,.12,0,0,0,0);assert(near(air,.12*.72),"petting hop")
		air,ground=Hop.split(.72,0,0,0,.3,0,0,0);assert(near(air,.3),"gift hop is already in studs")
		air,ground=Hop.split(.72,0,0,0,0,-.05,1,.02);assert(air==0 and near(ground,(-.05-.05+.02)*.72),"ground only")
		-- the body's total is the old single hop (nothing moved, only split)
		air,ground=Hop.split(.8,.5,.3,.1,.05,-.02,.4,.01)
		assert(near(air+ground,(.5*.11+.3*.11-.4*.05-.02+.01+.1)*.8+.05))
	end)

	test("the feet rise only with an upward air lift, never sink with a crouch",function()
		assert(Hop.feet(.08)==.08 and Hop.feet(0)==0 and Hop.feet(-.05)==0 and Hop.feet(nil)==0)
	end)

	test("planting lets go above 4 mm of air, and only then",function()
		assert(Hop.airborne({airLift=.05})and Hop.airborne({airLift=Hop.Release+1e-4}))
		assert(not Hop.airborne({airLift=Hop.Release})and not Hop.airborne({airLift=0})and not Hop.airborne({})and not Hop.airborne(nil))
	end)

	test("the walk's bob dips at each footfall (phase 0 and pi) and is at rest mid-step; never above rest",function()
		assert(near(Hop.walkBob(0,.07,1,1),-.07)and near(Hop.walkBob(math.pi,.07,1,1),-.07))
		assert(near(Hop.walkBob(math.pi/2,.07,1,1),0)and near(Hop.walkBob(math.pi*1.5,.07,1,1),0))
		local dips,last,falling=0,Hop.walkBob(0,.07,1.3,1),false
		for i=1,250 do
			local b=Hop.walkBob(i/200*math.pi*2,.07,1.3,1)
			assert(b<=1e-12 and b>=-.07*1.3-1e-12,"bob out of range "..b)
			if b>last and falling then dips+=1 end
			falling=b<last;last=b
		end
		assert(dips==2,"two footfalls a stride, dips "..dips)
		assert(Hop.walkBob(0,.07,1,0)==0 and near(Hop.walkBob(0,.07,1,.5),-.035),"weighted by the gait")
		assert(near(Hop.walkBob(0,.07,1.3,1),-.091),"a scamper dips deeper")
	end)

	test("over a whole stride the torso (bob) never rises over planted feet while the feet swing up",function()
		-- The planted foot is on the ground at its own contact; the body's lift there is the bob's deepest, <= 0.
		for i=0,99 do
			local phase=i/100*math.pi*2
			local _,ground=Hop.split(.72,0,0,0,0,Hop.walkBob(phase,.07,1.3,1),0,0)
			assert(ground<=1e-12,"torso above its feet at "..phase)
		end
	end)

	return{passed=#cases,cases=cases}
end
