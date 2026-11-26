-- Pet walk feel (beta (34) QA: "they're floating around a bit with primitive ai, walking needs to be cuter / more
-- convincing / more natural"). Pure: the server's eased stop-to-stop legs (GardenActivity.cruise: get going, walk
-- steady, settle, in the same time on the same line), the capped turn rate, the smooth walk through corners
-- (GardenActivity.through: velocity continuous, no stop) and the look round / sniff in a pause (PetWalkBeats).
-- Usage (Client): require(<client>.ZZSpecs.PetWalk)(<client>)
return function(client)
	local A=require(game:GetService("ReplicatedStorage").Shared.GardenActivity)
	local Beats=require(client.PetWalkBeats)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function walk(path)
		local total=0;for _,leg in ipairs(path)do total+=leg.duration end
		return {from=path[1].from,to=path[#path].to,path=path,startTime=0,endTime=total,action="wander",behavior="investigate"},total
	end

	test("a stop-to-stop leg gets going in EaseRamp, walks steady and settles, in the plain planner's time",function()
		local from,to=Vector3.new(0,4,0),Vector3.new(0,4,10)
		local path,seconds=A.plan(from,to,Vector3.zero,4,0,0,nil,Vector3.zero)
		assert(#path==1 and math.abs(seconds-7.5)<1e-3,"a 10-stud stroll at 4 still takes 7.5 s ("..seconds..")")
		local actor,total=walk(path)
		local function speed(t)return A.sample(actor,t).velocity.Magnitude end
		local mean=10/total
		-- Steady through the middle (the smoothstep's middle sped up and slowed down all the way).
		for _,t in ipairs({1,2,3.75,5,6.5})do assert(math.abs(speed(t)-speed(3.75))<1e-3,"not steady at "..t)end
		assert(speed(A.EaseRamp+.01)>mean*1.03,"still slow after the ramp")
		assert(speed(.05)<speed(.3)and speed(.3)<speed(.45),"no ramp up")
		assert(speed(0)<1e-6 and speed(total)<1e-6,"starts and ends at rest")
		-- The same line, the same ends, the midpoint at half time, never faster than the old smoothstep's peak.
		assert((A.sample(actor,total*.5).position-from:Lerp(to,.5)).Magnitude<1e-3)
		assert((A.sample(actor,total).position-to).Magnitude<1e-3)
		for t=0,total,.05 do
			local p=A.sample(actor,t).position
			assert(math.abs(p.X)<1e-6 and speed(t)<=mean*1.5+1e-6,"off the line or too fast at "..t)
		end
		-- Position is the integral of the published velocity (no hidden jump).
		local last,distance=A.sample(actor,0).position,0
		for t=.01,total,.01 do distance+=speed(t)*.01 end
		assert(math.abs(distance-10)<.05,"velocity integrates to "..distance)
		local _=last
	end)

	test("a short leg is all ramp, still at rest at both ends and within the speed cap",function()
		local share,rate=A.cruise(.5,.5)
		assert(math.abs(share-.5)<1e-9 and math.abs(rate-2)<1e-9)
		local s0,r0=A.cruise(0,.5);local s1,r1=A.cruise(1,.5)
		assert(math.abs(s0)<1e-9 and math.abs(s1-1)<1e-9 and r0<1e-9 and r1<1e-9)
		for r=.05,.5,.05 do
			local previous=0
			for t=0,1,.01 do
				local s=A.cruise(t,r)
				assert(s>=previous-1e-9 and s<=1+1e-9,"never steps back");previous=s
			end
		end
	end)

	test("turns on the spot run at TurnRate (an about-turn over half a second, never a snap)",function()
		assert(math.abs(A.turnSeconds(math.pi)-math.pi/A.TurnRate)<1e-9 and A.turnSeconds(math.pi)>=.5)
		assert(A.turnSeconds(.05)==A.TurnMin)
		local path=A.plan(Vector3.new(0,4,0),Vector3.new(0,4,-5),Vector3.zero,4,0,0,nil,Vector3.zero)
		assert(path[1].pivot and math.abs(path[1].duration-A.turnSeconds(math.pi))<1e-9,"turns before setting off")
	end)

	test("a walk through corners never stops at them: velocity continuous, heading smooth, ends at rest",function()
		local points={Vector3.new(4,4,0),Vector3.new(4,4,4),Vector3.new(8,4,6)}
		local path,seconds=A.through(Vector3.new(0,4,0),points,Vector3.zero,4,math.pi*.5)
		assert(path and seconds>0)
		for i=2,#path do
			local a,b=path[i-1],path[i]
			if not a.pivot then assert((A.vector(a.v1)-A.vector(b.v0)).Magnitude<1e-6,"velocity jumps at a corner")end
		end
		for i=1,#path-1 do if not path[i].pivot then assert(A.vector(path[i].v1).Magnitude>.2,"stops at corner "..i)end end
		assert(A.vector(path[#path].v1).Magnitude<1e-9)
		local actor,total=walk(path)
		local yaw=A.sample(actor,0).yaw
		for t=.02,total,.02 do
			local next=A.sample(actor,t).yaw
			assert(math.abs(math.atan2(math.sin(next-yaw),math.cos(next-yaw)))<.25,"heading snaps at "..t);yaw=next
		end
		-- About as quick as stopping at each corner (the old way), never slower than twice it.
		local stops=0;local at=Vector3.new(0,4,0)
		for _,p in ipairs(points)do local _,s=A.plan(at,p,Vector3.zero,4,0,0,nil,Vector3.zero);stops+=s;at=p end
		assert(seconds<stops,"through "..seconds.." vs stop-and-go "..stops)
		-- A veto slows the corners and, at last, gives up (the caller then stops at each).
		assert(A.through(Vector3.new(0,4,0),points,Vector3.zero,4,0,function()return false end)==nil)
	end)

	test("the pause after a stroll: a look round or a sniff by action id, the same everywhere, nothing reduced",function()
		local kinds={}
		for id=1,30 do kinds[Beats.kind(id)]=(kinds[Beats.kind(id)]or 0)+1 end
		assert(kinds[0]and kinds[1]and kinds[2],"all three beats occur")
		local look,sniff
		for id=1,30 do if Beats.kind(id)==0 then look=look or id elseif Beats.kind(id)==1 then sniff=sniff or id end end
		local most,least=0,0
		for t=0,3,.05 do
			local yaw=Beats.sample("wanderPause",look,t,false)
			most,least=math.max(most,yaw),math.min(least,yaw)
			assert(Beats.sample("wanderPause",look,t,false)==yaw,"not deterministic")
		end
		assert(most>Beats.LookYaw*.9 and least<-Beats.LookYaw*.9,"looks both ways")
		local yaw,pitch=Beats.sample("wanderPause",look,Beats.Delay+Beats.LookSeconds+.01,false)
		assert(yaw==0 and pitch==0,"back to centre")
		local down=0
		for t=0,3,.05 do local _,p=Beats.sample("wanderPause",sniff,t,false);down=math.max(down,p)end
		assert(down>Beats.SniffPitch*.6,"sniffs")
		for t=0,3,.25 do
			local y,p=Beats.sample("wanderPause",look,t,true);assert(y==0 and p==0,"reduced motion")
			y,p=Beats.sample("wander",look,t,false);assert(y==0 and p==0,"only in the pause")
		end
	end)

	return {passed=#cases,cases=cases}
end
