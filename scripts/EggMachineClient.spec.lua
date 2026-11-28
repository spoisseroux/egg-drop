-- The egg machine's client (EggMachineClient; EGG-CORNER-LOOK 2, EGG-CORNER-BUILD-PLAN 7 and the architect's review):
-- the open and buy crank schedules, the streaks, a press during a crank merges and a retried send never starts another,
-- the reveal hold (only the reveal the buy started, only until the landing, never past 1 s from the first press), a
-- refused buy drops nothing, the Stat Egg's egg rolls on schedule, the sounds, and the corner off. No world: the room is
-- nil, the clock is fake, the cinematic is a stand-in table with the same two fields.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.EggMachineClient)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py.
return function(client)
	local Machine=require(client.EggMachineClient)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local function rig(options)
		options=options or {}
		local r={now=100,sounds={},buzz={},on=options.on~=false}
		r.cinematic={}
		r.machine=Machine.new({step=false,clock=function()return r.now end,cinematic=r.cinematic,corner=function()return r.on end,
			room=function()return nil end,random=Random.new(7),rejected=function(action)return r.rejected~=nil and r.rejected[action]==true end,
			audio={play=function(_,name,speed,volume)table.insert(r.sounds,{name=name,speed=speed,volume=volume,at=r.now});return true end},
			haptic=function(strength)table.insert(r.buzz,strength)end})
		function r.advance(seconds,step)
			step=step or 1/60
			local left=seconds
			while left>1e-9 do
				local dt=math.min(step,left)
				r.now+=dt;left-=dt
				r.machine:step(dt)
			end
		end
		function r.count(name)local n=0;for _,s in ipairs(r.sounds)do if s.name==name then n+=1 end end;return n end
		return r
	end

	test("the buy schedules: full turn .6 s (5 clicks), half .45 (3), quarter .25 (1); clunk at the turn's end, lands .25 later (.85 / .70 / .50)",function()
		local one,two,three=Machine.schedule(1),Machine.schedule(2),Machine.schedule(3)
		assert(one.turn==360 and #one.clicks==5 and near(one.clunk,.6)and near(one.roll,.62)and near(one.land,.85))
		assert(two.turn==180 and #two.clicks==3 and near(two.land,.70))
		assert(three.turn==90 and #three.clicks==1 and near(three.land,.50))
		assert(Machine.schedule(9).turn==90 and Machine.schedule(0).turn==360)
		assert(one.clicks[5]==.44 and two.clicks[2]==.15)
	end)
	test("streaks: Hatch another within 20 s of the last landing; later starts again at 1",function()
		assert(Machine.streak(nil,nil,10)==1 and Machine.streak(1,0,19)==2 and Machine.streak(2,0,20)==3 and Machine.streak(3,0,20.5)==1)
	end)
	test("the dial: open eases to 96 (overshoot 6) by .28 and settles to 90; the buy turn is even after 60 ms and springs back 8 at the clunk",function()
		assert(near(Machine.openAngle(.28),96)and near(Machine.openAngle(1),90)and Machine.openAngle(0)==0)
		local s=Machine.schedule(1)
		assert(Machine.buyAngle(s,.03)<360*.03/.6,"resistance at the start")
		assert(near(Machine.buyAngle(s,.6),360,1e-3))
		assert(near(Machine.buyAngle(s,.6+.075),352,1e-3)and near(Machine.buyAngle(s,1),360))
	end)
	test("the roll: out of the belly, then into the cup (no hop: beta 34)",function()
		local a,b,c=Vector3.new(0,1,0),Vector3.new(1,.5,0),Vector3.new(1.2,.3,0)
		assert(Machine.rollAt(a,b,c,0)==a and(Machine.rollAt(a,b,c,Machine.RollSeconds)-c).Magnitude<1e-6)
		assert(Machine.RollHop==0 and(Machine.rollAt(a,b,c,Machine.RollSeconds*.8)-b:Lerp(c,.5)).Magnitude<1e-6)
	end)
	-- Beta (34) "the leaf at the bottom of the spout is clipping into the egg": the leaf chute as
	-- scripts/build_egg_machine.py builds it (build_body: the Bezier, its U trough and curled tip, the .04 underside) and
	-- the dropped egg as it builds it (blunt_egg_profile .66 x .86, 7 rings, at dropScale), machine-local.
	local function leafModel()
		local function baseRadius(y)
			local pts={{1.35,.37},{1.85,.7},{2.1,1.4},{2.0,2.0},{1.8,2.55},{1.6,2.95}}
			for i=1,#pts-1 do
				local r0,y0,r1,y1=pts[i][1],pts[i][2],pts[i+1][1],pts[i+1][2]
				if y>=y0 and y<=y1 then return r0+(r1-r0)*(y-y0)/(y1-y0)end
			end
			return pts[#pts][1]
		end
		local p0=Vector3.new(1.05,1.1,baseRadius(1.1)*(1.8/2.1)*.93)
		local p3=Vector3.new(1.25,.55,1.95)
		local p1,p2=p0+Vector3.new(.15,-.05,.55),p3+Vector3.new(-.05,.35,-.2)
		local function bez(t)return p0*(1-t)^3+p1*3*t*(1-t)^2+p2*3*t*t*(1-t)+p3*t^3 end
		local side=(p3-p0):Cross(Vector3.new(0,1,0)).Unit
		local grid={}
		for k=0,7 do
			local t=k/7
			local c=bez(t)
			local d=(bez(math.min(1,t+.01))-bez(math.max(0,t-.01))).Unit
			local up=side:Cross(d).Unit
			if up.Y<0 then up=-up end
			local row={}
			for s=0,5 do
				local q=s/5*2-1
				local w=.45*math.max(0,1-t)^.7
				row[s]=c+side*(q*w)+up*(.18*q*q-.02+.1*t^3)
			end
			grid[k]=row
		end
		local points={}
		for k=0,6 do for s=0,4 do
			local a,b,c,d=grid[k][s],grid[k][s+1],grid[k+1][s+1],grid[k+1][s]
			for i=0,4 do for j=0,4 do
				local p=a:Lerp(b,i/4):Lerp(d:Lerp(c,i/4),j/4)
				table.insert(points,p);table.insert(points,p-Vector3.new(0,.04,0))
			end end
		end end
		return points
	end
	local function eggProfile(scale)
		local out={}
		for j=0,7 do
			local th=math.pi*j/7
			local r=.66*scale/2*math.sin(th)*(1+.1*math.cos(th))
			out[j+1]={if j==0 or j==7 then 0 else r,-.86*scale/2*math.cos(th)}
		end
		return out
	end
	-- Signed distance from p to the upright egg centred at c (negative: inside it).
	local function eggDistance(profile,c,p)
		local rel=p-c
		local rho,y=Vector2.new(rel.X,rel.Z).Magnitude,rel.Y
		local best,inside=math.huge,false
		for i=1,#profile-1 do
			local a,b=Vector2.new(profile[i][1],profile[i][2]),Vector2.new(profile[i+1][1],profile[i+1][2])
			local e=b-a
			local u=math.clamp((Vector2.new(rho,y)-a):Dot(e)/e:Dot(e),0,1)
			best=math.min(best,(Vector2.new(rho,y)-(a+e*u)).Magnitude)
			if y>=a.Y and y<=b.Y and rho<a.X+(b.X-a.X)*(y-a.Y)/(b.Y-a.Y)then inside=true end
		end
		return if inside then -best else best
	end
	test("beta (34): the dropped egg clears the leaf chute all the way into the cup (the old path ran .35 inside it)",function()
		local Corner=require(game:GetService("ReplicatedStorage").Shared.EggCorner)
		local data=Corner.machineData()
		local leaf=leafModel()
		local profile=eggProfile(Corner.dropScale(data))
		local function clearance(c)
			local best=math.huge
			for _,p in ipairs(leaf)do
				if math.abs(p.X-c.X)<.8 and math.abs(p.Y-c.Y)<.8 and math.abs(p.Z-c.Z)<.8 then best=math.min(best,eggDistance(profile,c,p))end
			end
			return best
		end
		local function worst(a,b,c)
			local least=math.huge
			for i=0,40 do least=math.min(least,clearance(Machine.rollAt(a,b,c,Machine.RollSeconds*i/40)))end
			return least
		end
		local function v3(t)return Vector3.new(t[1],t[2],t[3])end
		local oldSeat=v3(data.cup)+Vector3.new(0,data.egg.size[2]*Corner.dropScale(data)/2,0)
		-- The model sees the leaf: the old seat (the cup's middle) has the tip inside the egg.
		assert(clearance(oldSeat)<-.1,"the old seat: "..clearance(oldSeat))
		local drop=Corner.dropPoints(data)
		-- Beta (36): the leafless build (data.leafless) drops the leaf from the Body; the hole path has its own spec,
		-- so the leaf clearance applies only to a leafed build.
		if not data.leafless then
			local least=worst(drop.from,drop.exit,drop.seat)
			assert(least>=.015,"the new path's least clearance to the leaf: "..least)
			assert(clearance(drop.seat)>=.015,"seated")
		end
		-- Seated in the cup, on its floor: every ring of the egg below the rim inside the woven wall's inner face (the
		-- lathe in build_body: r .5 at .1, .53 at .4, the lip .6 at .45).
		local off=Vector2.new(drop.seat.X-data.cup[1],drop.seat.Z-data.cup[3]).Magnitude
		assert(near(drop.seat.Y-data.egg.size[2]*Corner.dropScale(data)/2,data.cup[2]),"on the floor")
		for _,ring in ipairs(profile)do
			local y=drop.seat.Y+ring[2]
			if y>=.1 and y<=.45 then
				local inner=if y<=.4 then .5+.03*(y-.1)/.3 else .53+.07*(y-.4)/.05
				assert(off+ring[1]<=inner,"the wall at "..y)
			end
		end
	end)
	-- Beta (35) "the leaf is still in the way, can we just make it a hole": the Body rebuilt without the leaf
	-- (build_egg_machine.py LEAF_CHUTE = False writes `leafless`): the egg pops out of a round hole along the belly's
	-- normal and drops into the cup's middle. The egg here is dense (40 rings x 32) so no crossing slips between rings.
	local function eggSurface(scale,centre)
		local out={}
		for i=0,40 do
			local th=math.pi*i/40
			local r=.66*scale/2*math.sin(th)*(1+.1*math.cos(th))
			local y=-.86*scale/2*math.cos(th)
			for k=0,31 do
				local a=2*math.pi*k/32
				table.insert(out,centre+Vector3.new(r*math.cos(a),y,r*math.sin(a)))
			end
		end
		return out
	end
	-- How deep a point is inside the cup's straw (the lathe in build_body, about the cup's centre): 0 outside.
	local function cupDepth(data,q)
		local poly={{0,.08},{.5,.1},{.53,.4},{.6,.45},{.6,.15},{.45,0},{0,0}}
		local rho=Vector2.new(q.X-data.cup[1],q.Z-data.cup[3]).Magnitude
		local p=Vector2.new(rho,q.Y)
		local inside,best=false,math.huge
		for i=1,#poly do
			local a=Vector2.new(poly[i][1],poly[i][2])
			local b=Vector2.new(poly[i%#poly+1][1],poly[i%#poly+1][2])
			if(a.Y>p.Y)~=(b.Y>p.Y)and p.X<a.X+(b.X-a.X)*(p.Y-a.Y)/(b.Y-a.Y)then inside=not inside end
			local e=b-a
			local t=math.clamp((p-a):Dot(e)/e:Dot(e),0,1)
			best=math.min(best,(p-(a+e*t)).Magnitude)
		end
		return if inside then best else 0
	end
	test("beta (35): the leafless Body: out of the round hole (only inside its opening), clear of its rim, the belly and the cup",function()
		local Corner=require(game:GetService("ReplicatedStorage").Shared.EggCorner)
		local mesh=Corner.machineData()
		-- Beta (36): the leafless Body is uploaded (asset 136222877350169) and bound: the hole path is live.
		assert(Corner.leafless(mesh)and Corner.hole(mesh)~=nil,"the uploaded Body is leafless: the hole path")
		-- The drawn hole: the fallback for a leafless Body without the baked mouth (data.mouth unset).
		local data=table.clone(mesh);data.leafless=true;data.mouth=nil
		local hole=Corner.hole(data)
		local drop=Corner.dropPoints(data)
		local scale=Corner.dropScale(data)
		assert(math.abs(Corner.belly(hole.centre))<1e-3,"the hole sits on the belly")
		assert(hole.normal.Z>.6 and hole.normal.X>.3 and hole.normal.Y<0,"facing out, right and a little down, at the cup")
		assert(Corner.belly(drop.from)<0 and Corner.belly(drop.exit)>0,"from inside, out")
		assert((drop.from-hole.centre).Unit:Dot(-hole.normal)>.999,"straight out along the normal")
		local half=data.egg.size[2]*scale/2
		assert(near(drop.seat.X,data.cup[1])and near(drop.seat.Z,data.cup[3])and near(drop.seat.Y-half,data.cup[2]),"seated in the cup's middle, on its floor")
		local n=hole.normal
		local u=n:Cross(Vector3.new(0,1,0)).Unit
		local v=u:Cross(n).Unit
		local ring=hole.radius+hole.rim
		local outside,rimGap,cup=0,math.huge,0
		for i=0,80 do
			local c=Machine.rollAt(drop.from,drop.exit,drop.seat,Machine.RollSeconds*i/80)
			for _,q in ipairs(eggSurface(scale,c))do
				local rel=q-hole.centre
				local lateral=Vector2.new(rel:Dot(u),rel:Dot(v)).Magnitude
				-- Inside the belly only behind the opening: the egg passes through the hole, never through the wall.
				if Corner.belly(q)<0 and lateral>hole.radius then outside+=1 end
				rimGap=math.min(rimGap,Vector2.new(lateral-ring,rel:Dot(n)-Machine.HoleLook.lift).Magnitude-hole.rim)
				cup=math.max(cup,cupDepth(data,q))
			end
		end
		assert(outside==0,"egg points inside the belly outside the opening: "..outside)
		assert(rimGap>=.01,"the egg's least gap to the rim: "..rimGap)
		assert(cup<=.02,"into the cup's straw: "..cup)
		-- Seated: every ring of the egg below the rim inside the woven wall's inner face.
		for _,q in ipairs(eggSurface(scale,drop.seat))do assert(cupDepth(data,q)==0,"seated, in the straw at "..q.Y)end
		-- The hole's pieces stand on the belly (never inside it) and the disc fills the rim.
		local pieces=Machine.holeParts(hole)
		assert(pieces[1].name=="Disc"and near(pieces[1].size.Y,ring*2)and #pieces==1+Machine.HoleLook.segments)
		for _,piece in ipairs(pieces)do assert(Corner.belly(piece.cframe.Position)>=0,piece.name.." is inside the belly")end
	end)
	-- After beta 36 (Spencer, render-path-mouth: "shouldn't it have a hole or something for the egg to come out of"): the
	-- Body bakes a real mouth at Corner.hole (build_egg_machine.py MOUTH writes `mouth`): Corner.Mouth's cavity and throat
	-- behind the hole's centre plane, its lip over the belly. The egg starts inside the dark cavity, leaves through the
	-- throat (never through the wall, never into the lip) and drops into the cup's middle.
	local function mouthModel(Corner,hole)
		local M=Corner.Mouth
		local n=hole.normal
		local u=n:Cross(Vector3.new(0,1,0)).Unit
		local v=u:Cross(n).Unit
		-- The open radius at depth h along the normal (the cavity's profile, then the throat up to the belly), nil behind it.
		local function openRadius(h)
			local cav=M.cavity
			if h<cav[1][2]then return nil end
			for i=1,#cav-1 do
				local a,b=cav[i],cav[i+1]
				if h<=b[2]then return a[1]+(b[1]-a[1])*(h-a[2])/(b[2]-a[2])end
			end
			return M.lip[1][1]
		end
		-- How far along the normal the belly is from the hole's centre plane at this lateral offset.
		local function surface(lateral)
			local lo,hi=-.6,.6
			for _=1,30 do
				local mid=(lo+hi)/2
				if Corner.belly(hole.centre+lateral+n*mid)<0 then lo=mid else hi=mid end
			end
			return(lo+hi)/2
		end
		-- Signed gap from (rho, height over the belly) to the lip's section (negative inside it).
		local function lipGap(rho,hs)
			local lip=M.lip
			local best=math.huge
			for i=1,#lip-1 do
				local a,b=Vector2.new(lip[i][1],lip[i][2]),Vector2.new(lip[i+1][1],lip[i+1][2])
				local e=b-a
				local t=math.clamp((Vector2.new(rho,hs)-a):Dot(e)/e:Dot(e),0,1)
				best=math.min(best,(Vector2.new(rho,hs)-(a+e*t)).Magnitude)
			end
			if rho>=lip[1][1]and rho<=lip[#lip][1]and hs>=0 then
				for i=1,#lip-1 do
					if rho>=lip[i][1]and rho<=lip[i+1][1]then
						local top=lip[i][2]+(lip[i+1][2]-lip[i][2])*(rho-lip[i][1])/(lip[i+1][1]-lip[i][1])
						if hs<top then return -best end
					end
				end
			end
			return best
		end
		return{n=n,u=u,v=v,openRadius=openRadius,surface=surface,lipGap=lipGap}
	end
	test("after beta 36: the baked mouth: the egg starts in the cavity, leaves through the throat clear of the wall and the lip, lands in the cup",function()
		local Corner=require(game:GetService("ReplicatedStorage").Shared.EggCorner)
		local data=table.clone(Corner.machineData());data.leafless=true;data.mouth=true
		assert(Corner.mouth(data)and not Corner.mouth({mouth=true}),"the mouth only on the leafless Body")
		local hole=Corner.hole(data)
		local drop=Corner.dropPoints(data)
		local scale=Corner.dropScale(data)
		local shape=mouthModel(Corner,hole)
		-- The clear opening is the hole's radius: the throat and the lip's inner edge.
		assert(Corner.Mouth.lip[1][1]==Corner.Hole.radius and Corner.Mouth.cavity[#Corner.Mouth.cavity][1]==Corner.Hole.radius)
		-- Deep enough: the cavity's back is behind where the egg starts.
		local n=shape.n
		local start=eggSurface(scale,drop.from)
		local deepest=math.huge
		for _,q in ipairs(start)do
			local h=(q-hole.centre):Dot(n)
			assert(Corner.belly(q)<0 and h<-.1,"the egg starts wholly inside the cavity, behind the opening")
			deepest=math.min(deepest,h)
		end
		assert(deepest>Corner.Mouth.cavity[1][2]+.05,"the cavity's back is behind the egg: "..deepest)
		local wall,lip,cup=math.huge,math.huge,0
		for i=0,80 do
			local c=Machine.rollAt(drop.from,drop.exit,drop.seat,Machine.RollSeconds*i/80)
			for _,q in ipairs(eggSurface(scale,c))do
				local rel=q-hole.centre
				local h=rel:Dot(n)
				local lateral=rel-n*h
				local rho=lateral.Magnitude
				if Corner.belly(q)<0 then
					-- Inside the belly only in the mouth's open space (the cavity, the throat).
					local open=shape.openRadius(h)
					wall=math.min(wall,if open then open-rho else -1)
				elseif rho>.4 and rho<.85 and math.abs(h)<.5 then
					lip=math.min(lip,shape.lipGap(rho,h-shape.surface(lateral)))
				end
				cup=math.max(cup,cupDepth(data,q))
			end
		end
		assert(wall>=.015,"the egg's least gap to the cavity and throat walls: "..wall)
		assert(lip>=.015,"the egg's least gap to the lip: "..lip)
		assert(cup<=.02,"into the cup's straw: "..cup)
		local half=data.egg.size[2]*scale/2
		assert(near(drop.seat.X,data.cup[1])and near(drop.seat.Z,data.cup[3])and near(drop.seat.Y-half,data.cup[2]),"seated in the cup's middle, on its floor")
		for _,q in ipairs(eggSurface(scale,drop.seat))do assert(cupDepth(data,q)==0,"seated, in the straw at "..q.Y)end
		print(string.format("EggMachineClient mouth: least gap to the walls %.3f, to the lip %.3f",wall,lip))
	end)
	test("after beta 36: with the baked mouth the client draws no hole; an older leafless Body keeps the drawn disc and rim",function()
		local Corner=require(game:GetService("ReplicatedStorage").Shared.EggCorner)
		local r=rig()
		local function dressed(mouth)
			local data=table.clone(Corner.machineData());data.leafless=true;data.mouth=mouth
			local model=Instance.new("Model");model.Name="EggMachine"
			r.machine:dressHole({model=model,cup=CFrame.new(1.25,.57,1.75)},data)
			return model:FindFirstChild("EggHole")
		end
		assert(dressed(true)==nil,"the baked mouth: nothing drawn")
		local drawn=dressed(nil)
		assert(drawn~=nil and drawn:FindFirstChild("Disc")~=nil and drawn:FindFirstChild("Rim"..Machine.HoleLook.segments)~=nil,"the drawn hole")
	end)
	test("beta (35) 4: the real egg: the shell meshes stand the dropped egg's height and width, in each type's colorMap",function()
		local Corner=require(game:GetService("ReplicatedStorage").Shared.EggCorner)
		local Models=require(game:GetService("ReplicatedStorage").Shared.EggModels)
		local data=Corner.machineData()
		local h=data.egg.size[2]*Corner.dropScale(data)
		local pose=Machine.shellPose(CFrame.new(1,2,3),h)
		local top=pose.TopShell.cframe.Position.Y+pose.TopShell.size.Y/2
		local bottom=pose.BottomShell.cframe.Position.Y-pose.BottomShell.size.Y/2
		assert(near(top,2+h/2,1e-3)and near(bottom,2-h/2,1e-3),"top "..top..", bottom "..bottom)
		assert(math.abs(pose.BottomShell.size.X-data.egg.size[1]*Corner.dropScale(data))<.02,"as wide as the dropped egg: "..pose.BottomShell.size.X)
		-- In the machine: the shells (deps.shells) replace the plain egg, wearing the bought type's map.
		local lounge=Instance.new("Folder");lounge.Name="EggDropLounge"
		local model=Instance.new("Model");model.Name="EggMachine";model.Parent=lounge
		local body=Instance.new("Part");body.Name="Body";body.Position=Vector3.new(0,3.56,0);body.Size=Vector3.new(4.2,7.12,4.3);body.Parent=model
		local dial=Instance.new("Part");dial.Name="Dial";dial.CFrame=CFrame.new(0,2,1.7);dial.Parent=model
		local pivot=Instance.new("Attachment");pivot.Name="DialPivot";pivot.WorldCFrame=CFrame.new(0,2,1.7);pivot.Parent=body
		local egg=Instance.new("Part");egg.Name="DropEgg";egg.CFrame=CFrame.new();egg.Transparency=1;egg.Parent=model
		for name,at in pairs({ChuteTop=Vector3.new(1,1,.6),ChuteEnd=Vector3.new(1.3,.6,1.3),CupSeat=Vector3.new(1.29,.57,1.56)})do
			local a=Instance.new("Attachment");a.Name=name;a.WorldCFrame=CFrame.new(at);a.Parent=body
		end
		local now=100
		local asked=0
		local machine=Machine.new({step=false,clock=function()return now end,cinematic={},corner=function()return true end,room=function()return lounge end,
			tagged=function()return{}end,camera=function()return Vector3.new(0,5,10)end,warn=function()end,
			shells=function()asked+=1;local t,b=Instance.new("MeshPart"),Instance.new("MeshPart");return{TopShell=t,BottomShell=b}end})
		assert(machine:bought("hueBuy","sh-1"))
		local reveal={}
		machine.cinematic.onPlay(reveal)
		for _=1,90 do now+=1/60;machine:step(1/60)end
		local shell=model:FindFirstChild("DropShell")
		assert(shell and asked==1,"made once")
		local t=shell:FindFirstChild("TopShell")
		assert(t.TextureID==Models.Types.hue.colorMap and t.Transparency<1 and egg.Transparency==1,"the Hue Egg's shell shows, the plain egg hides")
		assert(near(t.Size.Y,pose.TopShell.size.Y),"at the dropped egg's size")
		machine:destroy()
	end)
	test("open crank: clicks at 0 / 90 / 180 ms and one knock; a second press inside it is ignored; the corner off does nothing",function()
		local r=rig()
		assert(r.machine:openCrank())
		assert(not r.machine:openCrank(),"a second press inside the crank")
		r.advance(.5)
		assert(r.count("crank_click_1")==1 and r.count("crank_click_2")==1 and r.count("crank_click_3")==1)
		assert(r.count("egg_tok_1")+r.count("egg_tok_2")+r.count("egg_tok_3")==1)
		assert(#r.buzz==3)
		assert(r.machine:openCrank(),"a new crank once the last is over")
		local off=rig({on=false})
		assert(not off.machine:openCrank()and not off.machine:bought("toyBuy","a"))
	end)
	test("a buy: the crank turns when its reveal starts: 5 clicks rising 4% each, clunk at .6, the landing thud once .85 later",function()
		local r=rig()
		assert(r.machine:bought("toyBuy","id-1"))
		local reveal={}
		r.advance(.2)
		assert(r.count("crank_click_1")==0,"armed only: nothing turns before the buy is confirmed")
		r.cinematic.onPlay(reveal) -- the result came back
		r.advance(1)
		assert(r.count("crank_click_1")==2 and r.count("crank_click_2")==2 and r.count("crank_click_3")==1)
		local pitches={}
		for _,s in ipairs(r.sounds)do if string.match(s.name,"^crank_click")then table.insert(pitches,s.speed)end end
		assert(near(pitches[5],1.16,1e-6),tostring(pitches[5]))
		assert(r.count("crank_clunk")==1 and r.count("egg_roll")==1 and r.count("land")==1)
		local landAt
		for _,s in ipairs(r.sounds)do if s.name=="land"then landAt=s.at end end
		assert(near(landAt-100.2,.85,1/60+1e-6),tostring(landAt))
	end)
	test("the hold: only the reveal that started after the press, only until the landing; others never",function()
		local r=rig()
		local before={}
		r.cinematic.onPlay(before) -- an older reveal (Hatch another's stage) asks too
		r.machine:bought("hueBuy","h-1")
		assert(not r.cinematic.gate(before),"nothing is claimed yet")
		r.advance(.1)
		local mine={}
		r.cinematic.onPlay(mine)
		assert(r.cinematic.gate(mine)and not r.cinematic.gate(before))
		r.advance(.8)
		assert(r.cinematic.gate(mine),"held until the landing (.85 after the confirmation)")
		r.advance(.1)
		assert(not r.cinematic.gate(mine),"released at the landing")
	end)
	test("a late result: the crank and the hold start with it (Fable R8), held until its landing; a refused buy drops nothing",function()
		local r=rig()
		r.machine:bought("toyBuy","t-1")
		r.advance(.95)
		local late={}
		r.cinematic.onPlay(late)
		assert(r.cinematic.gate(late)and r.machine.crank.at==r.now,"the crank and the hold start on the result")
		assert(r.machine.gate.cap==r.now+Machine.Cap)
		r.advance(.8)
		assert(r.cinematic.gate(late),"still held: the egg has not landed")
		r.advance(.1)
		assert(not r.cinematic.gate(late),"released at its landing")
		local refused=rig()
		refused.machine:bought("toyBuy","t-2")
		refused.advance(4)
		assert(#refused.sounds==0 and #refused.buzz==0,"a refused buy turns nothing at all (Studio check R8)")
		assert(refused.machine.crank==nil and refused.machine.armed==nil,"the armed press lapsed")
		assert(refused.machine:bought("toyBuy","t-3"),"the next press arms again")
	end)
	test("a retried send of the same action never starts another crank; a press during a crank merges into it",function()
		local r=rig()
		assert(r.machine:bought("featureBuy","f-1"))
		assert(not r.machine:bought("featureBuy","f-1"),"the retry (FeatureIntent resends p.value)")
		local mine={}
		r.cinematic.onPlay(mine)
		r.advance(.3)
		assert(not r.machine:bought("toyBuy","t-9"),"merged: no second crank or egg")
		r.advance(1)
		assert(r.count("crank_clunk")==1 and r.count("land")==1)
		assert(not r.machine:bought("nameEggBuy","n-1")and not r.machine:bought("wearableBuy","w-1"),"not a machine egg")
	end)
	test("Hatch another within 20 s: a half turn, then a quarter",function()
		local r=rig()
		for index,clicks in ipairs({5,3,1})do
			local before=r.count("crank_click_1")+r.count("crank_click_2")+r.count("crank_click_3")
			assert(r.machine:bought("toyBuy","s-"..index))
			r.cinematic.onPlay({})
			r.advance(8)
			local after=r.count("crank_click_1")+r.count("crank_click_2")+r.count("crank_click_3")
			assert(after-before==clicks,index..": "..(after-before))
		end
		r.advance(25)
		assert(r.machine:bought("toyBuy","s-4"));r.cinematic.onPlay({})
		assert(r.machine.crank.sched.turn==360,"after the window: a full turn again")
	end)
	test("the Stat Egg (its reveal is not the cinematic) turns on its Saved answer (confirm), never on a reveal",function()
		local r=rig()
		r.machine:bought("statEggBuy",nil)
		r.cinematic.onPlay({})
		r.advance(.5)
		assert(r.count("crank_clunk")==0,"a reveal does not confirm the Stat Egg")
		assert(r.machine:confirm(nil))
		r.advance(1)
		assert(r.count("egg_roll")==1 and r.count("land")==1)
	end)
	test("Fable R8: a press the intent says Rejected gets the hello nudge and one click at once: no crank, no streak step",function()
		local r=rig()
		r.machine:bought("toyBuy","n-1");r.cinematic.onPlay({});r.advance(2)
		local before=#r.sounds
		r.machine:bought("toyBuy","n-2")
		r.rejected={toyBuy=true}
		r.advance(.05)
		assert(r.machine.armed==nil and r.machine.crank.landed and r.machine.crank.streak==nil,"no new crank: the last is the first hatch, landed")
		assert(#r.sounds==before+1 and r.sounds[#r.sounds].name=="crank_click_1","one click")
		assert(r.now-r.machine.helloAt<.1,"the hello nudge")
		r.rejected=nil
		r.machine:bought("toyBuy","n-3");r.cinematic.onPlay({})
		assert(r.machine.crank.sched.turn==180,"the refusal did not count: this is the 2nd")
		local stat=rig()
		stat.machine:bought("statEggBuy",nil)
		assert(stat.machine:refuse()and stat.count("crank_click_1")==1 and not stat.machine:confirm(nil))
	end)
	test("Studio check R8: Hatch another refused (no reveal) turns nothing and never uses up a streak step",function()
		local r=rig()
		r.machine:bought("toyBuy","a-1");r.cinematic.onPlay({});r.advance(2) -- the first hatch landed
		local clicks=r.count("crank_click_1")+r.count("crank_click_2")+r.count("crank_click_3")
		r.machine:bought("toyBuy","a-2");r.advance(4)                       -- Hatch another, refused
		assert(r.count("crank_click_1")+r.count("crank_click_2")+r.count("crank_click_3")==clicks and r.count("crank_clunk")==1)
		r.machine:bought("toyBuy","a-3");r.cinematic.onPlay({})             -- the next one that hatches
		assert(r.machine.crank.sched.turn==180,"still the 2nd of the streak: a half turn")
		assert(not r.machine:confirm(nil),"nothing armed any more")
		r.advance(.01)
		r.machine:bought("toyBuy","a-4");r.advance(Machine.ConfirmWindow+.1)
		assert(not r.machine:confirm({}),"an armed press lapses after the confirm window")
	end)
	test("GIFT-ART-BRIEF 1: the ribbon stays tied for a paid crank and unties on the gift crank's first tick; refused, it fades",function()
		local r=rig()
		assert(r.machine:giftRibbon(true,{})==true and r.machine.ribbonView~=nil,"tied on")
		local view=r.machine.ribbonView
		assert(r.machine:bought("toyBuy","paid-1"));r.cinematic.onPlay({});r.advance(2)
		assert(view.untieAt==nil and view.offAt==nil,"a paid crank leaves it tied")
		r.now+=30
		r.machine:giftCrank()
		r.machine:giftRibbon(false) -- GiftChain hides it the moment it cranks
		assert(view.offAt==nil,"armed: it waits for the tick")
		assert(r.machine:bought("toyBuy","gift-1"));r.advance(.2)
		assert(view.untieAt==nil,"no tick before the confirmation")
		r.cinematic.onPlay({});r.advance(1/60)
		assert(view.untieAt~=nil,"the first tick unties it")
		local rustle
		for _,s in ipairs(r.sounds)do if s.name=="blanket_rustle"then rustle=s end end
		assert(rustle and rustle.speed==1.3,"blanket_rustle at 1.3")
		r.machine:destroy()
		local again=rig()
		again.machine:giftRibbon(true,{})
		local second=again.machine.ribbonView
		again.machine:giftCrank();again.machine:giftRibbon(false)
		assert(second.offAt==nil)
		again.machine:giftCrank(false)
		assert(second.offAt~=nil and second.untieAt==nil,"refused: it fades instead")
		-- the dial's face: the ribbon sits on the greybox dial's front, as wide as the dial
		local Ribbon=require(client.GiftRibbon)
		local face,diameter=Ribbon.face({dialPivot=CFrame.new(0,1.95,1.7014),dial={part={Size=Vector3.new(.3,1.7,1.7)},
			rest=CFrame.new(0,1.95,1.8514)*CFrame.Angles(0,math.pi/2,0)}})
		assert(near(diameter,1.7,1e-6)and near(face.Position.Z,1.7014+.3+.03,1e-6),tostring(face.Position.Z))
	end)
	test("destroy takes the hold off the cinematic",function()
		local r=rig()
		assert(type(r.cinematic.gate)=="function"and type(r.cinematic.onPlay)=="function")
		r.machine:destroy()
		assert(r.cinematic.gate==nil and r.cinematic.onPlay==nil)
	end)
	test("review 1: Turn is refused only while an open crank runs or a buy has not landed; a landed egg never blocks it",function()
		local r=rig()
		r.machine:bought("toyBuy","r1-1")
		r.cinematic.onPlay({})
		r.advance(.3)
		assert(r.machine:busy()and not r.machine:openCrank(),"the buy is still turning: init opens the screen at once instead")
		r.advance(.7)
		assert(r.machine.crank.landed and not r.machine.crank.done,"landed, the egg lingers in the cup")
		assert(not r.machine:busy()and r.machine:openCrank(),"Turn works while the egg lingers")
		assert(r.machine.crank.kind=="open")
		assert(r.machine:busy()and not r.machine:openCrank(),"a second press inside the open crank")
		r.advance(.5)
		assert(not r.machine:busy())
	end)
	test("review 1: the egg in the cup fades 1.5 s after the hatch screen closes (revealClosed), not 6 s after landing",function()
		local r=rig()
		r.machine:bought("toyBuy","r1-2")
		r.cinematic.onPlay({})
		r.advance(1)
		assert(r.machine.crank.landed and not r.machine.crank.done)
		r.machine:revealClosed()
		r.advance(Machine.FadeAfter+.5+.05)
		assert(r.machine.crank.done,"faded and done well before Linger")
		local old=rig()
		old.machine:revealClosed() -- a close before the press never counts
		old.advance(.1)
		old.machine:bought("toyBuy","r1-3");old.cinematic.onPlay({});old.advance(3)
		assert(old.machine.crank.landed and not old.machine.crank.done)
	end)
	test("review 2: a Stat Egg buy makes no gate, so a reveal that plays meanwhile is never held",function()
		local r=rig()
		r.machine:bought("statEggBuy",nil)
		assert(r.machine.gate==nil)
		local other={}
		r.cinematic.onPlay(other)
		assert(not r.cinematic.gate(other),"not caught by the Stat Egg's crank")
		assert(r.machine:confirm(nil),"its Saved answer")
		r.advance(1)
		assert(r.count("land")==1,"its own egg still rolls")
	end)
	test("Studio check R9, Fable R10: the machine's attract ring is a 194 degree front arc, every sample on the front side",function()
		local Attract=require(client.StationAttract)
		local Corner=require(game:GetService("ReplicatedStorage").Shared.EggCorner)
		assert(Corner.RingArc==194 and Corner.Ring==3)
		local facing=Corner.facing()
		local want=(Corner.Face-Corner.Spot)
		assert(math.abs(facing:Dot(Vector3.new(want.X,0,want.Z).Unit)-1)<1e-9,"centred on the machine's facing")
		local segments=Attract.arcSegments(Corner.Ring,Corner.RingArc,facing)
		assert(#segments==25,#segments)
		local low,high,covered=math.huge,-math.huge,0
		for _,segment in ipairs(segments)do
			assert(near(segment.offset.Magnitude,Corner.Ring,1e-9)and segment.offset.Y==0)
			-- Both ends of every segment, from the facing: never past +-100 (R9: grass from 105).
			local half=math.deg(segment.length/2/Corner.Ring)
			low=math.min(low,segment.angle-half);high=math.max(high,segment.angle+half)
			local measured=math.deg(math.acos(math.clamp(segment.offset.Unit:Dot(facing),-1,1)))
			assert(near(measured,math.abs(segment.angle),1e-6),"each angle is measured from the facing")
			covered+=math.deg(2*math.asin((segment.length-.04)/2/Corner.Ring))
			-- Every sample along the segment (the R9 probe's 128 rays would land inside these).
			for k=0,8 do
				local a=math.rad(segment.angle)+(k/8-.5)*math.rad(2*half)
				local sample=Vector3.new(math.cos(a),0,math.sin(a))
				local fromFacing=math.deg(math.abs(a))
				assert(fromFacing<=97.8,string.format("%.2f",fromFacing))
				assert(fromFacing<105,"never in R9's grass sector (105 to 167 from the facing)")
				assert(sample.Magnitude>0)
			end
		end
		assert(near(covered,194,1e-6),"the segments cover 194 degrees: "..covered)
		assert(low>=-97.8 and high<=97.8,low..","..high)
		-- At r 3 the whole arc stays well inside the paving (r 15.5 round (-30, -4)).
		for _,radius in ipairs({3,3.6})do
			local worst=0
			for _,segment in ipairs(Attract.arcSegments(radius,Corner.RingArc,facing))do
				local p=Corner.Spot+segment.offset
				worst=math.max(worst,math.sqrt((p.X+30)^2+(p.Z+4)^2))
			end
			-- At 194 degrees r 3.6 would graze the paving's edge (15.47 of 15.5): the ring stays 3.
			if radius==3 then assert(worst<15.2,worst)else assert(worst>15.4,worst)end
		end
	end)
	test("beta (16) B1: a model seen before its parts is never cached half empty; it binds once whole; found by tag too; one warning",function()
		local now,warned=0,{}
		local lounge=Instance.new("Folder");lounge.Name="EggDropLounge"
		local tagged={}
		local machine=Machine.new({step=false,clock=function()return now end,cinematic={},corner=function()return true end,
			room=function()return lounge end,tagged=function()return tagged end,random=Random.new(3),
			warn=function(text)table.insert(warned,text)end,audio={play=function()return true end}})
		local function step(dt)now+=dt;machine:step(dt)end
		step(.1)
		assert(machine.parts==nil and string.find(machine:status(),"no EggMachine"),tostring(machine:status()))
		local model=Instance.new("Model");model.Name="EggMachine"
		local body=Instance.new("Part");body.Name="Body";body.Position=Vector3.new(-41,4,2);body.Parent=model
		model.Parent=lounge
		step(1)
		assert(machine.parts==nil and string.find(machine:status(),"Dial"),"half there: not cached")
		local dial=Instance.new("Part");dial.Name="Dial";dial.CFrame=CFrame.new(-41,6,4);dial.Parent=model
		local pivot=Instance.new("Attachment");pivot.Name="DialPivot";pivot.WorldCFrame=CFrame.new(-41,6,3.7);pivot.Parent=body
		step(1)
		assert(machine.parts~=nil and machine.parts.dial.part==dial and machine:status()==nil,"whole: bound")
		-- Not in the lounge but tagged (another parent): found by its tag.
		local other=Machine.new({step=false,clock=function()return now end,cinematic={},corner=function()return true end,
			room=function()return Instance.new("Folder")end,tagged=function()return{model}end,warn=function(text)table.insert(warned,text)end})
		other:step(.1)
		assert(other.parts~=nil and other.parts.model==model,"found by tag")
		-- Nothing to animate for WarnAfter seconds: one warning, with the reason, and a Turn says why, once.
		local lonely=Machine.new({step=false,clock=function()return now end,cinematic={},corner=function()return true end,
			room=function()return nil end,tagged=function()return{}end,warn=function(text)table.insert(warned,text)end})
		for _=1,30 do now+=1;lonely:step(1)end
		local count=0
		for _,text in ipairs(warned)do if string.find(text,"no machine to animate")then count+=1 end end
		assert(count==1,"one warning, not one a frame: "..count)
		lonely:openCrank();lonely.crank=nil;lonely:openCrank()
		count=0
		for _,text in ipairs(warned)do if string.find(text,"Turn pressed")then count+=1 end end
		assert(count==1)
		machine:destroy();other:destroy();lonely:destroy()
	end)
	test("beta (16) B3: the reveal's camera aims over the egg, never pulled sideways by the item's flight",function()
		local Aim=require(client.HatchAim)
		assert(Aim.target(Vector3.new(1.7,2.5,-.8),3)==Vector3.new(0,2.5,0))
		assert((Aim.target(nil,3)-Vector3.new(0,1.8,0)).Magnitude<1e-9)
	end)
	-- ── The capsule shot (beta 17 U5; CAPSULE-AND-HUD-LOOK 1) ─────────────────────────────────────────────────────────
	local function capsuleRig(options)
		options=options or {}
		local r={now=100,sounds={},pockets={},hud={},ghost={},on=true,capsule=options.capsule~=false,root=Vector3.new(-41,4.13,8),
			blocked=options.blocked or function()return false end}
		r.cinematic={}
		r.statReveal={}
		r.camera={CameraType="Custom",CFrame=CFrame.new(-30,10,20)}
		local lounge=Instance.new("Folder");lounge.Name="EggDropLounge"
		if options.model~=false then
			local model=Instance.new("Model");model.Name="EggMachine"
			local body=Instance.new("Part");body.Name="Body";body.Position=Vector3.new(-41,4.13+3.56,2);body.Size=Vector3.new(4.2,7.12,4.3);body.Parent=model
			local dial=Instance.new("Part");dial.Name="Dial";dial.CFrame=CFrame.new(-41,6,3.7);dial.Parent=model
			local pivot=Instance.new("Attachment");pivot.Name="DialPivot";pivot.WorldCFrame=CFrame.new(-41,6,3.7);pivot.Parent=body
			model.Parent=lounge
		end
		r.machine=Machine.new({step=false,clock=function()return r.now end,cinematic=r.cinematic,statReveal=r.statReveal,corner=function()return r.on end,
			room=function()return lounge end,tagged=function()return{}end,random=Random.new(9),reduced=function()return r.reduced==true end,
			root=function()return r.root end,capsule=function()return r.capsule end,cameraObject=function()return r.camera end,
			hud=function(visible)table.insert(r.hud,visible)end,ghost=function(alpha)table.insert(r.ghost,alpha)end,
			blocked=function(a,b)return r.blocked(a,b)end,pocket=function(kind,sched)table.insert(r.pockets,{kind=kind,sched=sched})end,
			firstOfType=function(kind)return r.first~=nil and r.first[kind]==true end,
			warn=function()end,audio={play=function(_,name)table.insert(r.sounds,{name=name,at=r.now});return true end}})
		function r.advance(seconds,step)
			step=step or 1/60
			local left=seconds
			while left>1e-9 do local dt=math.min(step,left);r.now+=dt;left-=dt;r.machine:step(dt)end
		end
		function r.heard(name)for _,s in ipairs(r.sounds)do if s.name==name then return s.at-r.at end end;return nil end
		function r.buy(id,action)
			r.at=r.now
			assert(r.machine:bought(action or "toyBuy",id))
			local reveal={}
			r.cinematic.onPlay(reveal)
			return reveal
		end
		-- The Stat Egg (init): armed by the send; its Saved answer hands its reveal's show to the machine (SnackHost
		-- present -> deliver, beta 35), which opens it once the egg is in the cup.
		r.opened={}
		function r.buyStat(reveal)
			r.at=r.now
			reveal=reveal or {}
			assert(r.machine:bought("statEggBuy",nil))
			r.cinematic.onPlay({}) -- another reveal starting never confirms it
			assert(r.machine:deliver("Stat",function()table.insert(r.opened,{reveal=reveal,at=r.now-r.at})end,reveal))
			return reveal
		end
		return r
	end
	test("capsule: the schedules: first 2.0 s (roll .40 s, land 1.35), 2nd 1.30, 3rd .95, pocket 1.0, Reduced Motion on the thud",function()
		local S=Machine.Shots
		assert(S.first.start==2.00 and near(S.first.land,1.35)and near(S.first.rollSeconds,.40)and near(S.first.clunk,.90)and #S.first.clicks==5)
		assert(near(S.first.roll+S.first.rollSeconds,S.first.land)and S.first.shine==1.50 and near(S.first.rise+S.first.riseSeconds,S.first.start))
		assert(S.second.start==1.30 and near(S.second.land,.87)and #S.second.clicks==3)
		assert(S.third.start==.95 and near(S.third.land,.62)and #S.third.clicks==1)
		assert(S.pocket.start==1.00 and near(S.pocket.land,.75)and #S.pocket.clicks==3)
		assert(S.reduced.start==S.reduced.land and near(S.reduced.land,.62))
		for _,s in pairs(S)do assert(near(s.turnFrom+s.seconds,s.clunk),s.mode)end
		assert(Machine.shotSchedule("shot",1)==S.first and Machine.shotSchedule("shot",2)==S.second and Machine.shotSchedule("shot",7)==S.third)
		assert(Machine.shotSchedule("pocket",3)==S.pocket and Machine.shotSchedule("reduced",1)==S.reduced)
	end)
	test("capsule: at the machine: the panel tucks, the camera goes A then B, the reveal is held to 2.0 s (cap 2.2), the thud once",function()
		local r=capsuleRig()
		local reveal=r.buy("c-1")
		local shot=r.machine.shot
		assert(shot and shot.mode=="shot"and shot.frames and r.camera.CameraType~="Custom","Scriptable on the confirmation")
		assert(r.hud[1]==false and r.ghost[1]==1,"the dock hides, the player goes see-through")
		assert(r.cinematic.gate(reveal),"the reveal's clock is held")
		r.advance(.3)
		assert((r.camera.CFrame.Position-shot.frames.A.Position).Magnitude<.05,"Shot A by .30")
		r.advance(1.0)
		assert((r.camera.CFrame.Position-shot.frames.B.Position).Magnitude<.05,"Shot B by 1.30")
		r.advance(.6)
		assert(near(r.heard("land")or -1,1.35,.03)and near(r.heard("crank_clunk")or -1,.90,.03)and r.heard("cup_shine"))
		assert(r.cinematic.gate(reveal),"still held at 1.9")
		r.advance(.12)
		assert(not r.cinematic.gate(reveal),"the reveal starts at 2.0")
		assert(shot.panelBack and r.hud[#r.hud]==true,"the panel and the dock are back")
		local lands=0;for _,s in ipairs(r.sounds)do if s.name=="land"then lands+=1 end end
		assert(lands==1,"one egg, one landing")
		r.advance(3)
		assert(r.camera.CameraType~="Custom","the camera holds at Shot B while the reveal is up")
		r.machine:revealClosed();r.advance(.4)
		assert(r.camera.CameraType=="Custom"and r.machine.shot==nil and r.ghost[#r.ghost]==0,"given back on close")
	end)
	test("capsule: Hatch another starts at Shot B (1.30 s, then .95 s); after the camera went back, a first shot again",function()
		local r=capsuleRig()
		r.buy("h-1");r.advance(2.2)
		local second=r.buy("h-2")
		assert(r.machine.shot.sched==Machine.Shots.second)
		r.advance(1.25);assert(r.cinematic.gate(second));r.advance(.1);assert(not r.cinematic.gate(second))
		r.buy("h-3");assert(r.machine.shot.sched==Machine.Shots.third)
		r.advance(1);r.machine:revealClosed();r.advance(.5)
		r.buy("h-4")
		assert(r.machine.shot.sched==Machine.Shots.first,"the camera had gone back: Shot A again")
	end)
	test("capsule: the pocket version: no model, more than 24 studs off, both line checks blocked (the Stat Egg too)",function()
		for _,case in ipairs({{model=false},{far=true},{blocked=function()return true end},{model=false,stat=true}})do
			local r=capsuleRig({model=case.model,blocked=case.blocked})
			if case.far then r.root=Vector3.new(-41,4,40)end
			r.at=r.now
			local reveal
			if case.stat then reveal=r.buyStat()
			else reveal=r.buy("p-1","hueBuy")end
			assert(r.machine.shot.mode=="pocket"and r.camera.CameraType=="Custom"and #r.hud==0,"no camera, no tuck")
			assert(r.pockets[1].kind==(if case.stat then "stat"else "hue"),"the preview well's drop, in the bought type")
			local gate=r.machine.gate
			assert(near(gate.release-r.at,1.0)and gate.owner==reveal,"the reveal at 1.0 s")
		end
		local Corner=require(game:GetService("ReplicatedStorage").Shared.EggCorner)
		local frame=Corner.frame(4.13)
		local mirrored=capsuleRig({blocked=function(_,at)return frame:PointToObjectSpace(at).X>0 end})
		mirrored.buy("m-1")
		assert(mirrored.machine.shot.mode=="shot","the mirrored side is clear: still the shot")
	end)
	test("capsule: Reduced Motion: no tuck, no camera; the static card waits for the thud (.62 s)",function()
		local r=capsuleRig()
		r.reduced=true
		local reveal=r.buy("r-1")
		assert(r.machine.shot.mode=="reduced"and r.camera.CameraType=="Custom"and #r.hud==0)
		r.advance(.6);assert(r.cinematic.gate(reveal));r.advance(.05);assert(not r.cinematic.gate(reveal))
		assert(near(r.heard("land"),.62,.02))
	end)
	-- Beta (34) "the stats egg just cuts straight to the hatching animation": the Stat Egg plays the machine's beat.
	test("beta (34): the Stat Egg plays the same shot: tuck, Shots A and B, its reveal held to 2.0 s, one thud; only its own close ends it",function()
		local r=capsuleRig()
		local reveal=r.buyStat()
		local shot=r.machine.shot
		assert(shot and shot.mode=="shot"and shot.sched==Machine.Shots.first and r.camera.CameraType~="Custom"and r.hud[1]==false and r.ghost[1]==1)
		assert(r.statReveal.gate(reveal),"its reveal's clock is held (its own gate)")
		assert(not r.statReveal.gate({})and not r.cinematic.gate({}),"no other reveal is caught")
		-- SnackHost closes the Hatch eggs screen under the reveal: that never ends the Stat Egg's shot.
		r.machine:revealClosed("screen")
		r.advance(.3)
		assert((r.camera.CFrame.Position-shot.frames.A.Position).Magnitude<.05,"Shot A by .30")
		r.advance(1.6)
		assert(r.machine.shot==shot and r.camera.CameraType~="Custom","the shot plays on")
		assert(near(r.heard("land")or -1,1.35,.03)and near(r.heard("crank_clunk")or -1,.90,.03)and near(r.heard("egg_roll")or -1,.95,.03))
		assert(r.statReveal.gate(reveal),"still held at 1.9")
		-- Beta (35) 1: its reveal was not even on the screen before the egg was in the cup: opened as the panel rose.
		assert(#r.opened==1 and r.opened[1].at>=1.75-1e-9 and r.opened[1].at<1.75+.04,"opened at "..tostring(r.opened[1]and r.opened[1].at))
		r.advance(.12)
		assert(not r.statReveal.gate(reveal),"its hatch starts at 2.0")
		local lands=0;for _,s in ipairs(r.sounds)do if s.name=="land"then lands+=1 end end
		assert(lands==1)
		-- Hatch another on its result card: the 2nd schedule from Shot B.
		r.advance(.5)
		local second=r.buyStat()
		assert(r.machine.shot.sched==Machine.Shots.second and r.statReveal.gate(second))
		r.advance(1.25);assert(r.statReveal.gate(second));r.advance(.1);assert(not r.statReveal.gate(second))
		r.advance(1)
		assert(r.camera.CameraType~="Custom","Shot B while its result is up")
		r.machine:revealClosed("stat");r.advance(.4)
		assert(r.camera.CameraType=="Custom"and r.machine.shot==nil and r.ghost[#r.ghost]==0,"given back on its close")
		r.machine:destroy()
		assert(r.statReveal.gate==nil and r.statReveal.onGateSkip==nil)
	end)
	test("beta (34): the Stat Egg: Reduced Motion holds its hatch to the thud (.62); capsule off, to the .85 landing",function()
		local r=capsuleRig()
		r.reduced=true
		local reveal=r.buyStat()
		assert(r.machine.shot.mode=="reduced"and r.camera.CameraType=="Custom"and #r.hud==0)
		r.advance(.6);assert(r.statReveal.gate(reveal));r.advance(.05);assert(not r.statReveal.gate(reveal))
		assert(near(r.heard("land"),.62,.02))
		local off=capsuleRig({capsule=false})
		local held=off.buyStat()
		assert(off.machine.shot==nil and off.camera.CameraType=="Custom")
		off.advance(.8);assert(off.statReveal.gate(held));off.advance(.1);assert(not off.statReveal.gate(held),"released at the landing")
		-- A regular egg's screen closing never touches the Stat Egg's buy, and the Stat Egg's close never a regular one.
		local toy=capsuleRig()
		toy.buy("x-1");toy.advance(2.2)
		toy.machine:revealClosed("stat");toy.advance(.4)
		assert(toy.camera.CameraType~="Custom","a Stat close leaves a Toy Egg's shot alone")
		toy.machine:revealClosed();toy.advance(.4)
		assert(toy.camera.CameraType=="Custom")
	end)
	test("beta (34): the Stat Egg's skip: never its first drop; then the skip jumps the shot to the landing (beta 35: its reveal opens then)",function()
		local r=capsuleRig()
		r.first={stat=true}
		local reveal=r.buyStat()
		r.advance(.2)
		assert(not r.machine:skipShot()and not r.machine.shot.skipped,"the first Stat Egg plays in full (asked by type: its reveal is not open yet)")
		r.first.stat=false
		assert(r.machine:skipShot()and r.machine.shot.skipped)
		r.advance(.02);assert(r.heard("land")and #r.opened==0,"the thud is never skipped, and comes first")
		r.advance(.08);assert(r.statReveal.gate(reveal));r.advance(.05);assert(not r.statReveal.gate(reveal)and #r.opened==1,"its reveal and hatch .12 s later")
	end)
	test("capsule: skip jumps to the landing (the thud plays, the reveal .12 s later); never the first drop of a type",function()
		local r=capsuleRig()
		local reveal=r.buy("s-1")
		reveal.canSkip=function()return false end
		r.advance(.2)
		assert(r.machine:shotActive()and not r.machine:skipShot(),"the first drop of this type")
		reveal.canSkip=function()return true end
		local before=#r.sounds
		assert(r.machine:skipShot())
		r.advance(.02)
		local clicks=0;for i=before+1,#r.sounds do if string.match(r.sounds[i].name,"^crank_click")then clicks+=1 end end
		assert(clicks==0,"no burst of clicks")
		assert(r.heard("land"),"the thud is never skipped")
		r.advance(.08);assert(r.cinematic.gate(reveal));r.advance(.05);assert(not r.cinematic.gate(reveal),"the reveal .12 s later")
		assert(not r.machine:skipShot(),"once")
		assert(r.cinematic.onGateSkip~=nil,"the reveal's own skip asks the machine")
	end)
	test("capsule: the camera is given back at once when the corner or the capsule switch goes off, or on respawn (returnCamera)",function()
		local r=capsuleRig()
		r.buy("g-1");r.advance(.5)
		r.capsule=false;r.advance(.02)
		assert(r.camera.CameraType=="Custom"and r.machine.shot==nil and r.machine.gate==nil or not r.cinematic.gate({}))
		local again=capsuleRig()
		again.buy("g-2");again.advance(.5);again.machine:returnCamera(true)
		assert(again.camera.CameraType=="Custom")
	end)
	test("capsule off: the crank and its 1 s hold exactly as before",function()
		local r=capsuleRig({capsule=false})
		local reveal=r.buy("o-1")
		assert(r.machine.shot==nil and r.camera.CameraType=="Custom")
		r.advance(.8);assert(r.cinematic.gate(reveal));r.advance(.1);assert(not r.cinematic.gate(reveal),"released at the .85 landing")
	end)
	test("code review of 071d8a6: the camera held at Shot B goes back when the next buy is a pocket one",function()
		local r=capsuleRig()
		r.buy("v-1");r.advance(2.2)
		assert(r.camera.CameraType~="Custom","held at Shot B behind the reveal")
		r.root=Vector3.new(-41,4,60) -- walked off
		r.buy("v-2")
		assert(r.machine.shot.mode=="pocket"and r.camera.CameraType=="Custom"and r.ghost[#r.ghost]==0,"given back at once")
	end)
	test("code review of 071d8a6: a second reveal during the shot waits for the shot's reveal; the skip keys are bound only while it plays",function()
		local r=capsuleRig()
		local bound={}
		r.machine.d.skipInput=function(on)table.insert(bound,on)end
		local first=r.buy("q-1")
		assert(bound[1]==true,"bound with the shot")
		r.advance(.5)
		local second={}
		r.cinematic.onPlay(second)
		assert(r.cinematic.gate(second),"queued behind the shot")
		r.advance(1.4)
		assert(r.cinematic.gate(second)and r.cinematic.gate(first))
		r.advance(.15)
		assert(not r.cinematic.gate(second)and not r.cinematic.gate(first),"both go when the shot's reveal starts")
		assert(bound[#bound]==false,"unbound when the shot is over")
	end)
	test("code review of 071d8a6: the tuck stops at the screen's shade (SafeContent's child), never SafeContent",function()
		local gui=Instance.new("ScreenGui");gui.Name="EggDropOverlays"
		local safe=Instance.new("Frame");safe.Name="SafeContent";safe.Parent=gui
		local shade=Instance.new("Frame");shade.Name="EggHatchView";shade.Parent=safe
		local card=Instance.new("Frame");card.Name="Card";card.Parent=shade
		local frame=Instance.new("Frame");frame.Name="HatchCinematic";frame.Parent=card
		local roots=Machine.panelRoots({frame=frame})
		assert(#roots==1 and roots[1]==shade,tostring(roots[1]and roots[1].Name))
	end)
	test("Fable R13 (4): a reveal stage that opens mid-shot (its waiting egg) tucks with the panel and comes back with it",function()
		local r=capsuleRig()
		local gui=Instance.new("ScreenGui");gui.Name="EggDropOverlays"
		local safe=Instance.new("Frame");safe.Name="SafeContent";safe.Parent=gui
		local shade=Instance.new("Frame");shade.Name="EggHatchView";shade.Parent=safe
		local frame=Instance.new("Frame");frame.Name="HatchCinematic";frame.Parent=shade
		local stageShade=Instance.new("Frame");stageShade.Name="RevealHost";stageShade.Parent=safe
		local stageRoot=Instance.new("Frame");stageRoot.Name="ItemRevealStage";stageRoot.Parent=stageShade
		r.at=r.now
		assert(r.machine:bought("toyBuy","w-1"))
		local reveal={frame=frame}
		r.cinematic.onPlay(reveal)
		r.advance(.1)
		reveal.borrowedStage={root=stageRoot} -- the result landed: the stage opens over the tucked panel
		local shot=r.machine.shot
		local function tucked(gui)for _,entry in ipairs(shot.roots)do if entry.gui==gui then return true end end;return false end
		assert(tucked(shade)and not tucked(stageShade),"the stage was not there at the confirmation")
		r.advance(.2)
		assert(tucked(shade)and tucked(stageShade)and #shot.roots==2,"the stage is tucked with the panel (its shade, once)")
		r.advance(.2);assert(#shot.roots==2)
		r.advance(1.6)
		assert(shot.panelBack,"and comes back with it")
	end)
	test("Studio R15 (1): every reveal stage slides with the panel (all the way off while tucked) and is home when it rises",function()
		local r=capsuleRig()
		local held={}
		r.machine.d.stageHold=function(amount)table.insert(held,amount)end
		r.buy("st-1")
		assert(r.machine:stageAmount()==0,"the tuck starts from home")
		r.advance(.25)
		assert(held[#held]==1 and r.machine:stageAmount()==1,"off the screen once tucked")
		r.advance(1.0);assert(held[#held]==1,"still off during the crank")
		r.advance(.8)
		assert(held[#held]==0 and r.machine:stageAmount()==0,"home with the panel (the reveal starts)")
		local any=false;for _,amount in ipairs(held)do if amount>0 and amount<1 then any=true end end
		assert(any,"it slides, it does not jump")
	end)
	test("Studio R16: the screen the buy was pressed on (deps.screens) slides away with the reveal's host, once each",function()
		local r=capsuleRig()
		local shop=Instance.new("Frame");shop.Name="EggHatchView"
		local host=Instance.new("Frame");host.Name="HueEggView"
		r.machine.d.screens=function()return{shop,host}end
		r.buy("sc-1")
		local roots=r.machine.shot.roots
		assert(#roots==2 and roots[1].gui==shop and roots[2].gui==host,tostring(#roots))
		r.advance(.5);assert(#r.machine.shot.roots==2,"never twice")
	end)
	test("Studio R15 (2): Hatch another's gap keeps the camera at Shot B, so the next buy chains (2nd schedule); no buy: back",function()
		local r=capsuleRig()
		local again=false
		r.machine.d.againPending=function()return again end
		r.buy("ga-1");r.advance(2.4)
		again=true -- Hatch another pressed: the store, then the screen closes while the buy waits
		r.machine:revealClosed()
		assert(r.camera.CameraType~="Custom"and r.machine:cameraHeld(),"held through the gap")
		r.advance(.38)
		assert(r.camera.CameraType~="Custom")
		again=false
		r.buy("ga-2")
		assert(r.machine.shot.sched==Machine.Shots.second,"chained from Shot B")
		r.advance(1.5)
		-- A refused Hatch another: the gap goes quiet and the camera goes back after GapGrace.
		again=true;r.machine:revealClosed();r.advance(.2)
		again=false;r.advance(Machine.GapGrace+.1)
		assert(r.machine.gap==nil);r.advance(Machine.ReturnSeconds+.05)
		assert(r.camera.CameraType=="Custom"and not r.machine:cameraHeld(),"given back")
	end)
	-- Beta (40) note 4 (ARCH-REVIEW-P2 3): "it just got stuck on the looking at the egg machine". Any shot whose owner is
	-- not open gives the camera back; a gift card owner holds it while open and its close returns it.
	test("camera: an owner-less shot returns the camera; the gift card owns its shot while open; a hatch screen up holds it",function()
		assert(Machine.ownerOpen(nil)==false and Machine.ownerOpen({isOpen=function()return true end})==true)
		assert(Machine.ownerOpen({})==true and Machine.ownerOpen({},true)==false,"the cinematic owns its return; a deferred owner that cannot say is not open")
		assert(Machine.watchReturns({})and not Machine.watchReturns({open=true})and not Machine.watchReturns({seenOpen=true}))
		assert(not Machine.watchReturns({screen=true})and not Machine.watchReturns({gap=true}))
		-- owner-less (the gift card before this fix): back StatWatch s after the start, never left Scriptable
		local r=capsuleRig()
		r.at=r.now
		assert(r.machine:bought("giftPaintBuy","g-1"))
		assert(r.machine:deliver("Hue",function()end,nil))
		assert(r.camera.CameraType~="Custom","the shot has the camera")
		r.advance(Machine.Shots.first.start+Machine.StatWatch-.1)
		assert(r.camera.CameraType~="Custom","not before the watch")
		r.advance(.2+Machine.ReturnSeconds+.05)
		assert(r.camera.CameraType=="Custom"and r.machine.shot==nil,"an owner-less shot returns the camera")
		-- the gift card as owner: held while it is up, past the watch; its close (revealClosed "gift") gives it back
		local g=capsuleRig()
		local up=false
		assert(g.machine:bought("giftPaintBuy","g-2"))
		assert(g.machine:deliver("Hue",function()up=true end,{isOpen=function()return up end}))
		g.advance(Machine.Shots.first.start+.1)
		assert(up,"the card opened once the egg was in the cup")
		g.advance(Machine.StatWatch+2)
		assert(g.camera.CameraType~="Custom","held while the card is up")
		up=false;g.advance(1)
		assert(g.camera.CameraType~="Custom","seen open: the card's own close returns it")
		g.machine:revealClosed("gift");g.advance(Machine.ReturnSeconds+.05)
		assert(g.camera.CameraType=="Custom"and g.machine.shot==nil,"given back on the card's close")
		-- a card that never opens: the watch returns it
		local n=capsuleRig()
		assert(n.machine:bought("giftPaintBuy","g-3"))
		assert(n.machine:deliver("Hue",nil,{isOpen=function()return false end}))
		n.advance(Machine.Shots.first.start+Machine.StatWatch+Machine.ReturnSeconds+.2)
		assert(n.camera.CameraType=="Custom","a card that never opened never keeps the camera")
	end)
	return{passed=#cases,cases=cases}
end
