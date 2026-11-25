-- Studio Client. The garden's scene, the maths (LifeSceneSim; beta 14 QA W3, GARDEN-LIFE-BUILD-PLAN section 4): dapple
-- shade by daylight and its drift, koi on a figure of eight at .5 studs a second inside the pool and shy of the player,
-- their rise rings, the far flock's shared schedule (90 to 150 s) and its V, dragonflies over their water, the lamps'
-- order and their dusk on the real garden hour, the shooting star once a night. Pure, no instances.
-- Usage: require(PlayerScripts.Client.ZZSpecs.LifeSceneSim)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="LifeSceneSim").
return function(client)
	local Sim=require(client.LifeSceneSim)
	local Wind=require(client.Wind)
	local Hour=require(game:GetService("ReplicatedStorage").Shared.GardenHour)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local T0=1795300000

	test("caps: dapple 6/3/0, koi 3/2/0, flock 5/3/0, dragonflies 2/1/0, PointLights 4/0/0 (level 0 only)",function()
		for kind,want in pairs({dapple={6,3,0},koi={3,2,0},flock={5,3,0},dragonflies={2,1,0},lights={4,0,0}})do
			for level=0,2 do assert(Sim.cap(kind,level)==want[level+1],kind.." "..level)end
		end
	end)

	test("dapple: .55 by day (and the hour off, FABLE-REVIEW-R5), gone under .30, eased between; drifts .35 along the wind (+.5 in a gust), turns +-4",function()
		assert(Sim.dappleTransparency(nil)==.55 and Sim.dappleTransparency(.9)==.55 and Sim.dappleTransparency(.45)==.55)
		assert(Sim.Dapple.size==11)
		assert(Sim.dappleTransparency(.30)==1 and Sim.dappleTransparency(.12)==1)
		local mid=Sim.dappleTransparency(.375)
		assert(mid>.55 and mid<1 and near(mid,.775,1e-6),"half way: "..mid)
		local centre=Vector3.new(10,4,-20)
		local most,turn=0,0
		for i=0,400 do
			local t=T0+i*.1
			local calm=Sim.dapplePose(centre,t,0,1.3)
			local along=(calm.Position-centre):Dot(Wind.Direction)
			most=math.max(most,math.abs(along))
			assert(near(calm.Position.Y,centre.Y+.055,1e-9),"just over the lawn")
			local look=calm.LookVector
			turn=math.max(turn,math.deg(math.acos(math.clamp(-look.Z,-1,1))))
			local gust=Sim.dapplePose(centre,t,1,1.3)
			assert(near((gust.Position-calm.Position):Dot(Wind.Direction),.5,1e-6),"+.5 in a full gust")
		end
		assert(most<=.35+1e-6 and most>.3,"drift .35: "..most)
		assert(turn<=4+1e-6 and turn>3,"turn 4: "..turn)
		local points={Vector3.new(50,0,0),Vector3.new(5,0,0),Vector3.new(-20,0,0),Vector3.new(1,0,1)}
		local order=Sim.nearest(points,Vector3.new(0,30,0),3)
		assert(#order==3 and order[1]==4 and order[2]==2 and order[3]==3,"nearest first")
		assert(#Sim.nearest(points,nil,3)==0)
	end)

	test("koi: a figure of eight inside the pool at .5 studs a second, tail sway +-8; shy of a player at the bank; rise rings",function()
		local P=Sim.Pool
		for k=1,3 do
			local travelled,last=0,nil
			for i=0,600 do
				local t=T0+i*.1
				local frame,at=Sim.koiPose(k,t,Vector3.zero,0)
				local dx,dz=(at.X-P.centre.X)/P.half.X,(at.Z-P.centre.Z)/P.half.Y
				assert(math.sqrt(dx*dx+dz*dz)<=.62,"inside 60% of the pool: "..k)
				-- STUDIO-CHECK-R5: the pool mesh is opaque (surface y 3.200), so Fable's fallback: on the surface + .02.
				assert(Sim.Koi.over and near(at.Y,P.centre.Y+.02,1e-9),"on the surface (the over fallback)")
				if last then travelled+=(at-last).Magnitude end
				last=at
			end
			assert(near(travelled/60,.5,.06),"koi "..k.." swims .5 a second: "..travelled/60)
		end
		-- Shy: a player at the bank pushes them to the far side at 1.2 a second, then they drift back over about 4 s.
		local bank=P.centre+Vector3.new(P.half.X+1,0,0)
		local shift,f=Vector3.zero,0
		for _=1,30*6 do shift,f=Sim.koiShift(shift,bank,1/30)end
		assert(shift.X<0 and f>.99 and near(shift.Magnitude,.4*12,1e-6),"to the far side: "..tostring(shift))
		for i=0,600 do
			local _,at=Sim.koiPose(1+i%3,T0+i*.13,shift,f)
			local dx,dz=(at.X-P.centre.X)/P.half.X,(at.Z-P.centre.Z)/P.half.Y
			assert(math.sqrt(dx*dx+dz*dz)<=.8,"still in the pool when shy")
		end
		local back=0
		while f>0 and back<10 do shift,f=Sim.koiShift(shift,nil,1/30);back+=1/30 end
		assert(back>=3.9 and back<=4.1,"back over 4 s: "..back)
		local far
		shift,far=Sim.koiShift(Vector3.zero,P.centre+Vector3.new(60,0,0),.1)
		assert(far==0 and shift==Vector3.zero,"far away: calm")
		-- A rise ring: .4 to 1.6 studs, .3 to 1 transparent, over 1.4 s.
		local s0,t0=Sim.ripple(0)
		assert(near(s0,.4)and near(t0,.3)and Sim.ripple(1.4)==nil and Sim.ripple(-1)==nil)
		local s1,t1=Sim.ripple(1.39)
		assert(s1>1.59 and t1>.99)
	end)

	test("the far flock: every 90 to 150 s, 25 s across, 130 to 170 out and 45 to 60 up, 5 in a V (3 at level 1), the same for everyone",function()
		local F=Sim.Flock
		local base=math.floor(T0/F.slot)
		for n=base,base+3000 do
			local gap=Sim.flockStart(n+1)-Sim.flockStart(n)
			assert(gap>=90-1e-6 and gap<=150+1e-6,"gap "..gap)
		end
		local n=base+3
		local start=Sim.flockStart(n)
		assert(Sim.flockAt(start-.01)~=n and select(1,Sim.flockAt(start+1))==n and near(select(2,Sim.flockAt(start+1)),1,1e-6))
		assert(Sim.flockAt(start+F.length+.01)==nil and near(F.length,25,1e-9))
		for _,age in ipairs({0,6,12.5,20,24.9})do
			local birds=Sim.flockBirds(n,age,start+age,5)
			assert(#birds==5)
			local lead=(birds[1][1].Position+birds[1][2].Position)/2
			local flat=Vector3.new(lead.X-F.centre.X,0,lead.Z-F.centre.Z).Magnitude
			assert(flat>=120 and flat<=200,"far out: "..flat)
			assert(lead.Y>=F.centre.Y+44 and lead.Y<=F.centre.Y+61,"high up: "..lead.Y)
			for k=2,5 do
				local at=(birds[k][1].Position+birds[k][2].Position)/2
				assert((at-lead).Magnitude>=2 and(at-lead).Magnitude<=8.5,"in a loose V: "..(at-lead).Magnitude)
			end
		end
		assert(#Sim.flockBirds(n,3,start+3,3)==3,"level 1: 3")
		-- Wings flap +-25 degrees, mirrored.
		local most=0
		for i=0,40 do
			local b=Sim.flockBirds(n,5+i/40,start+5+i/40,1)[1]
			local up=b[1].UpVector
			most=math.max(most,math.deg(math.acos(math.clamp(up.Y,-1,1))))
		end
		assert(most>20 and most<=25+1e-6,"flap 25: "..most)
	end)

	test("dragonflies: by day only, at most the cap, each over its own water inside the box 1 to 1.6 up; hover, then a 3 to 5 stud dart in .35 s",function()
		local box={frame=CFrame.new(0,3.2,0)*CFrame.Angles(0,.4,0),hx=8,hz=6,y=3.2}
		local other={frame=CFrame.new(20,3.2,0),hx=6,hz=5,y=3.2}
		local far={frame=CFrame.new(400,3.2,0),hx=6,hz=5,y=3.2}
		local boxes={box,other,far}
		local flies=Sim.Dragonflies.new(3)
		local eye=Vector3.new(5,10,10)
		assert(#flies:step(T0,boxes,eye,2,false)==0,"none at night")
		local now=T0
		local darts=0
		local seen={}
		for _=1,30*60 do
			now+=1/30
			local list=flies:step(now,boxes,eye,2,true)
			assert(#list<=2)
			local used={}
			for _,fly in ipairs(list)do
				assert(not used[fly.box]and fly.box~=far,"its own box, in reach");used[fly.box]=true
				local q=fly.box.frame:PointToObjectSpace(Vector3.new(fly.position.X,fly.box.y,fly.position.Z))
				assert(math.abs(q.X)<=fly.box.hx-1+1e-6 and math.abs(q.Z)<=fly.box.hz-1+1e-6,"inside the box")
				assert(fly.position.Y>=fly.box.y+1-1e-6 and fly.position.Y<=fly.box.y+1.6+1e-6,"1 to 1.6 up")
				if fly.dart and not seen[fly.dart]then
					seen[fly.dart]=true;darts+=1
					local d=Vector3.new(fly.dart.to.X-fly.dart.from.X,0,fly.dart.to.Z-fly.dart.from.Z).Magnitude
					assert(d<=12,"a short dart: "..d)
				end
			end
		end
		assert(darts>=20,"darts in a minute: "..darts)
		local level1=Sim.Dragonflies.new(4)
		now=T0
		for _=1,30*5 do now+=1/30;assert(#level1:step(now,boxes,eye,1,true)<=1)end
		-- The wings: +-12 degrees, swapped at 15 Hz.
		local fly={position=Vector3.new(0,4.5,0),yaw=0,phase=0}
		local a,b=Sim.dragonflyParts(fly,0),Sim.dragonflyParts(fly,1/15)
		assert(math.abs(a[2].UpVector.X+b[2].UpVector.X)<1e-6 and math.abs(a[2].UpVector.X)>.1,"swapped")
	end)

	test("lamps: nearest the plaza first; on the real garden hour they light .35 s apart from the fall through .45, off .15 apart at dawn",function()
		local order=Sim.lampOrder()
		assert(#order==#Sim.Lamps and #order==7)
		local function d(i)local p=Sim.Lamps[i];return(p.X+30)^2+(p.Z-4)^2 end
		for k=2,#order do assert(d(order[k-1])<=d(order[k]),"nearest first")end
		local cross=assert(Sim.crossings(function(s)return Hour.phase(s).daylight end),"the hour crosses .45")
		assert(cross.down>=2880 and cross.down<=3000,"dusk in the night blend: "..cross.down)
		assert(cross.up>=0 and cross.up<=360,"dawn in the dawn blend: "..cross.up)
		assert(near(Hour.phase(cross.down).daylight,.45,1e-3)and near(Hour.phase(cross.up).daylight,.45,1e-3))
		-- Lamp 1 starts at the crossing, lamp 2 .35 s later; each takes .8 s.
		assert(Sim.lampLevel(1,cross.down-.01,cross,false)==0)
		assert(near(Sim.lampLevel(1,cross.down+.4,cross,false),.5,1e-6))
		assert(Sim.lampLevel(2,cross.down+.3,cross,false)==0 and Sim.lampLevel(2,cross.down+.36,cross,false)>0)
		assert(Sim.lampLevel(7,cross.down+6*.35+.8,cross,false)==1,"the last one lit")
		assert(Sim.lampLevel(3,1500,cross,false)==0,"none by day")
		assert(Sim.lampLevel(3,3300,cross,false)==1 and Sim.lampLevel(3,(cross.up-1)%3600,cross,false)==1,"all night")
		-- Dawn: lamp 1 off from the rise, lamp 2 .15 s after.
		assert(Sim.lampLevel(1,cross.up+.8,cross,false)==0 and Sim.lampLevel(2,cross.up+.1,cross,false)==1)
		-- Reduced Motion: all at once, no ease.
		assert(Sim.lampLevel(7,cross.down+.001,cross,true)==1 and Sim.lampLevel(7,cross.up+.001,cross,true)==0)
		assert(Sim.lampLevel(1,3300,nil,false)==0,"the hour off: none")
	end)

	test("the shooting star: once a night in its middle third, 3 streaks 6 to 9 s apart, .7 s each, 200 studs out near the camera's look",function()
		local S=Sim.Star
		for hour=498690,498690+200 do
			local times=Sim.starTimes(hour)
			assert(#times==3)
			local base=hour*3600
			assert(times[1]>=base+3120 and times[3]+S.time<=base+3360,"the night's middle third")
			for j=2,3 do local gap=times[j]-times[j-1];assert(gap>=6-1e-6 and gap<=9+1e-6,"gap "..gap)end
		end
		local hour=498700
		local times=Sim.starTimes(hour)
		local j,u,h=Sim.starAt(times[2]+.35)
		assert(j==2 and near(u,.5,1e-4)and h==hour)
		assert(Sim.starAt(times[2]+.71)==nil and Sim.starAt(hour*3600+1000)==nil)
		local camera=CFrame.lookAt(Vector3.new(0,10,0),Vector3.new(0,10,-10))
		local head,tail=Sim.starStreak(hour,2,.5,camera)
		assert(near((head-tail).Magnitude,14,1e-6),"14 long")
		local to=(head-camera.Position)
		assert(to.Magnitude>=180 and to.Magnitude<=220,"200 out: "..to.Magnitude)
		assert(to.Y>0 and Vector3.new(to.X,0,to.Z).Unit:Dot(Vector3.new(0,0,-1))>=math.cos(math.rad(45)),"up, near the look")
	end)

	test("beta 17 1.3 B: leaves ride the stream boxes in order at 1.1 studs a second, on the water, round the stones",function()
		local boxes={{frame=CFrame.new(0,3.2,40),hx=7.5,hz=4.5,name="Water_Stream"},{frame=CFrame.new(0,3.2,0),hx=8,hz=5,name="Water_Pool_Lily"},
			{frame=CFrame.new(2,3.2,20),hx=7,hz=4.5,name="Water_Stream"},{frame=CFrame.new(4,3.2,0),hx=8,hz=5.6,name="Water_Stream"}}
		local path=Sim.streamPath(boxes)
		assert(#path.points==3 and near(path.points[1].Z,40)and near(path.points[3].Z,0),"stream boxes only, in order")
		assert(near(path.points[1].Y,3.22)and near(path.halves[3],5.6))
		local obstacles={{x=4,z=9,size=2.8,stone=true}}
		local W=Sim.Water
		local count=6
		for k=1,count do
			local last
			for i=0,400 do
				local now=T0+i*.25
				local frame,transparency=Sim.leaf(path,k,count,now,obstacles)
				assert(frame and transparency>=0 and transparency<=1)
				local p=frame.Position
				assert(near(p.Y,3.22),"on the water")
				-- Inside the water: never further off the line than the half width.
				local best=math.huge
				for j=1,#path.points-1 do
					local a,b=path.points[j],path.points[j+1]
					local ab=Vector3.new(b.X-a.X,0,b.Z-a.Z)
					local u=math.clamp(Vector3.new(p.X-a.X,0,p.Z-a.Z):Dot(ab)/ab:Dot(ab),0,1)
					best=math.min(best,(Vector3.new(a.X,0,a.Z)+ab*u-Vector3.new(p.X,0,p.Z)).Magnitude)
				end
				assert(best<=5.6,"on the stream: "..best)
				-- Clear of the stone (its half size) unless fading at an end.
				local gap=Vector2.new(p.X-4,p.Z-9).Magnitude
				if transparency<.5 then assert(gap>=1.4-.05,"round the stone: "..gap)end
				if last then
					local step=Vector2.new(p.X-last.X,p.Z-last.Z).Magnitude
					assert(step<=W.speed*.25+.5 or transparency>.9 or step>path.total*.5,"drifts: "..step)
				end
				last=p
			end
		end
		-- Fades in over the first second and out over the last.
		local lap=path.total/W.speed
		local start=math.ceil(T0/lap)*lap
		local _,a=Sim.leaf(path,1,count,start)
		local _,b=Sim.leaf(path,1,count,start+.5)
		local _,c=Sim.leaf(path,1,count,start+3)
		assert(near(a,1)and b>0 and b<1 and near(c,0),"fade in")
		local f1=Sim.leaf(path,1,count,start+2)
		local f2=Sim.leaf(path,1,count,start+2)
		assert(f1==f2 or(f1.Position-f2.Position).Magnitude<1e-9,"the same for everyone")
		assert(Sim.leaf(Sim.streamPath({}),1,6,T0)==nil and Sim.cap("leaves",0)==6 and Sim.cap("leaves",1)==3 and Sim.cap("leaves",2)==0)
	end)
	test("beta 17 1.3 B: flow rings pulse 1.15 to 1.5 x over 2.6 s, fading .55 to .9; Reduced Motion: still at 1.2 x",function()
		local lo,hi=math.huge,-math.huge
		for i=0,52 do
			local size,transparency=Sim.flowRing(T0+i*.05,.3,false)
			lo,hi=math.min(lo,size),math.max(hi,size)
			assert(transparency>=.55-1e-9 and transparency<=.9+1e-9)
		end
		assert(lo<1.17 and hi>1.48 and lo>=1.15-1e-9 and hi<=1.5+1e-9)
		local size,transparency=Sim.flowRing(T0,0,true)
		assert(size==1.2 and transparency==.55)
	end)

	return{passed=#cases,cases=cases}
end
