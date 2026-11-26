-- Top Lawn toys x1.25 (Fable, ROUND7-LOOK item 7 and player-scale FABLE-REVIEW, 2026-11-26): the Top Lawn's toys read
-- small beside the 18-stud tree and the 7-high outcrops. A site spec's `toyScale` (the Top Lawn's 1.25) scales every toy
-- (frames, swings, slide, see-saw, sand box, castles, ball corner) about its group root, with its seats, ladder, chute,
-- colliders, castle spot and ball homes; the pets are not scaled (they sit on the scaled seats), and the step-out in
-- front of a seat stays pet-sized. Benches, kerbs, gate posts and rim boulders are not toys.
-- Every k = 1 site (the arrival, the old grove, the Hollow, and the Top Lawn spec without its scale) must come out as it
-- was before the scale: offline, a digest of every number of its layout and pose data (motion samples too) is pinned
-- from the module before the change.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.ParkToyScale)(ServerScriptService.Server)
return function(server,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Park=require(Shared.ParkLayout)
	local Data=require(Shared.ParkPoseData)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local EXTRA=table.freeze({Sites=true,ById=true,Specs=true,HollowOn=true,HollowPlaceId=true,TopLawnOn=true,Glade=true})

	-- Rows "path=value" for every data field (functions and the module's site lists left out).
	local function rows(out,path,value)
		local kind=typeof(value)
		if kind=="Vector3"then table.insert(out,string.format("%s=%.17g,%.17g,%.17g",path,value.X,value.Y,value.Z))
		elseif kind=="Vector2"then table.insert(out,string.format("%s=%.17g,%.17g",path,value.X,value.Y))
		elseif kind=="CFrame"then
			rows(out,path..".p",value.Position);rows(out,path..".x",value.RightVector)
			rows(out,path..".y",value.UpVector);rows(out,path..".z",value.LookVector)
		elseif kind=="number"then table.insert(out,string.format("%s=%.17g",path,value))
		elseif kind=="string"or kind=="boolean"then table.insert(out,path.."="..tostring(value))
		elseif kind=="table"then
			for key,v in pairs(value)do
				if type(v)~="function"and not(path=="park"and EXTRA[key])then rows(out,path.."."..tostring(key),v)end
			end
		end
	end
	-- The site's layout, its pose data and motion samples, as one digest (and the row count).
	local function digest(site)
		local D=Data.forSite(site)
		local out={}
		rows(out,"park",site)
		for _,key in ipairs({"Delay","Texture","ModelAsset","Meshes","Moving","ImportTurn","Roots","Swings","SwingSettle","SeeSaw",
			"Slide","Sand","Ball","Lift","BallPickup"})do rows(out,"data."..key,D[key])end
		rows(out,"layout",D.layout())
		for _,name in ipairs({"Park_SwingFrame","Park_SwingA","Park_Slide","Park_SeeSawBeam","Park_Castle3","Park_BallMat","Park_Bench"})do
			rows(out,"pivotOffset."..name,D.pivotOffset(name))
		end
		for i,angle in ipairs({-.5,0,.31})do
			for _,id in ipairs({"swing1","swing2"})do rows(out,"swingSeat."..id..i,D.swingSeat(id,angle))end
			rows(out,"swingFrame"..i,D.frame("Park_SwingB",D.Roots.SwingSet,D.swingMotion(angle)))
		end
		for i,tilt in ipairs({-.26,0,.26})do
			for _,id in ipairs({"seesaw1","seesaw2"})do rows(out,"seesawSeat."..id..i,D.seesawSeat(id,tilt))end
			rows(out,"beamFrame"..i,D.frame("Park_SeeSawBeam",D.Roots.SeeSaw,D.seesawMotion(tilt)))
		end
		local sand={activity="sandbox",startTime=0,session="s"}
		for i,t in ipairs({1,2.5,6,11,12,12.5})do
			local stage,sy,sxz,sink=D.castle(sand,t)
			rows(out,"castle"..i,{stage,sy,sxz,sink})
			if stage>0 then
				rows(out,"castleFrame"..i,D.frame("Park_Castle"..stage,D.Roots.Sandbox,CFrame.new(0,-sink,0),Vector3.new(sxz,sy,sxz)))
			end
		end
		local solo={activity="ball",startTime=0,session="b"}
		local duo1,duo2={activity="ballToss",startTime=0,session="d"},{activity="ballToss",startTime=0,session="d"}
		for i,t in ipairs({.1,1.3,4.6,10.5})do
			rows(out,"ballSolo"..i,{D.balls(solo,nil,t)})
			rows(out,"ballSolo2"..i,{D.balls(nil,solo,t)})
			rows(out,"ballDuo"..i,{D.balls(duo1,duo2,t)})
		end
		for _,id in ipairs({"sand1","sand2","ball1","ball2"})do rows(out,"spot."..id,D.spot(id))end
		rows(out,"ballFront",{D.ballFront("ball1"),D.ballFront("ball2")})
		table.sort(out)
		local h=0
		local text=table.concat(out,"\n")
		for i=1,#text do h=(h*31+string.byte(text,i))%4294967291 end
		return h,#out
	end
	-- The Top Lawn spec without its scale (the k = 1 path for the same places).
	local function unscaled(spec)
		local copy=table.clone(spec);copy.toyScale=nil
		return table.freeze(copy)
	end
	-- The same at Fable's places before the x1.25 moves (see-saw (8, 11.5), dig spot (-9, 0); same yaws): the pinned
	-- digest's input, so the k = 1 code path is proven unchanged.
	local function fablePlaces(spec)
		local Tier=require(Shared.Tier)
		local copy=table.clone(spec);copy.toyScale=nil
		local pieces=table.clone(spec.pieces)
		local function at(id,s,t)local p=Tier.T(s,t);pieces[id]=table.freeze({p.X,p.Z,spec.pieces[id][3]})end
		at("seesaw",8,11.5);at("sandbox",-9,0)
		copy.pieces=table.freeze(pieces)
		return table.freeze(copy)
	end
	local SITES={
		arrival=function()return Park end,
		grove=function()return Park.build(Park.Specs.grove)end,
		hollow=function()return Park.build(Park.Specs.hollow)end,
		topLawn1=function()return Park.build(fablePlaces(Park.Specs.topLawn))end,
	}

	if offline then
		test("offline: every k = 1 site's layout, pose data and motion samples are the ones before the toy scale",function()
			-- Pinned from the module at 54049e0e (before the toy scale), with the offline mocks' doubles.
			local PINNED={arrival={2673115129,1010},grove={987283192,1012},hollow={4141201026,1110},topLawn1={1271333729,978}}
			for name,make in pairs(SITES)do
				local h,n=digest(make())
				assert(h==PINNED[name][1]and n==PINNED[name][2],string.format("%s changed: digest %d (%d rows)",name,h,n))
			end
		end)
	end

	local T=Park.build(Park.Specs.topLawn)
	local T1=Park.build(unscaled(Park.Specs.topLawn))
	local D,D1=Data.forSite(T),Data.forSite(T1)
	local k=1.25
	-- To 1e-3 at least, so a float32 Studio run passes too (every scaled value differs from its x1 one by .05+).
	local function near(a,b,tolerance)
		tolerance=math.max(tolerance or 0,1e-3)
		if typeof(a)=="Vector3"then return(a-b).Magnitude<=tolerance end
		return math.abs(a-b)<=tolerance
	end
	local TOYS={"Park_SwingFrame","Park_SwingA","Park_SwingB","Park_Slide","Park_SeeSawBase","Park_SeeSawBeam","Park_SandboxFrame",
		"Park_Castle1","Park_Castle2","Park_Castle3","Park_SandToys","Park_BallMat","Park_BallA","Park_BallB"}
	local GROUP_ROOT={SwingSet="SwingSet",Slide="Slide",SeeSaw="SeeSaw",Sandbox="Sandbox",BallCorner="BallCorner"}

	test("the switch: the Top Lawn's toys x1.25; every other site carries no scale",function()
		assert(Park.Specs.topLawn.toyScale==k and T.ToyScale==k)
		assert(Park.ToyScale==nil and T1.ToyScale==nil and Park.build(Park.Specs.hollow).ToyScale==nil and Park.build(Park.Specs.grove).ToyScale==nil)
		assert(Park.ById.grove.ToyScale==(if Park.TopLawnOn then k else nil),"the live second site follows the Top Lawn switch")
	end)

	test("meshes: every toy's size, offset, pivot, seat and radius x1.25; benches, kerbs and gate posts as they were",function()
		local toy={};for _,name in ipairs(TOYS)do toy[name]=true end
		for name,m in pairs(D.Meshes)do
			local o=D1.Meshes[name]
			local s=if toy[name]then k else 1
			assert(near(m.size,o.size*s)and near(m.offset,o.offset*s)and near(m.pivot,o.pivot*s),name)
			assert(m.id==o.id and m.stage==o.stage,name)
			if o.seat then assert(near(m.seat,o.seat*s),name.." seat")end
			if o.radius then assert(near(m.radius,o.radius*s),name.." radius")end
		end
		for _,name in ipairs(TOYS)do assert(D.Meshes[name],name)end
	end)

	test("the static meshes and colliders grow about their group roots; the roots stay but the slide's (from its ladder foot)",function()
		for _,group in ipairs({"SwingSet","SeeSaw","Sandbox","BallCorner"})do
			local a,b=D.Roots[group],D1.Roots[group]
			assert(a.Position==b.Position and a.LookVector==b.LookVector,group.." root moved")
		end
		local a,b=D.layout(),D1.layout()
		assert(#a.static==#b.static and #a.colliders==#b.colliders and #a.seats==#b.seats)
		for i,entry in ipairs(a.static)do
			local old=b.static[i]
			assert(entry.mesh==old.mesh and entry.group==old.group,"static "..i)
			local root=GROUP_ROOT[entry.group]
			if root then
				assert(near(entry.size,old.size*k),entry.mesh.." size")
				local p=D.Roots[root]:PointToObjectSpace(entry.cframe.Position)
				local q=D1.Roots[root]:PointToObjectSpace(old.cframe.Position)
				assert(near(p,q*k,1e-5),entry.mesh.." not at x1.25 of its place in the group")
				assert(near(entry.cframe.LookVector,old.cframe.LookVector),entry.mesh.." turned")
			else
				assert(entry.size==old.size and entry.cframe.Position==old.cframe.Position,entry.mesh.." is not a toy")
			end
		end
		-- Colliders sort by position, so match them by group and order of their scaled local points.
		local function groupBoxes(layout,data,scale)
			local out={}
			for _,box in ipairs(layout.colliders)do
				local root=GROUP_ROOT[box.group]
				local p=if root then data.Roots[root]:PointToObjectSpace(box.cframe.Position)/scale else box.cframe.Position
				out[box.group]=out[box.group]or {}
				table.insert(out[box.group],{p=p,size=if root then box.size/scale else box.size,look=box.cframe.LookVector})
			end
			local function r(n)return math.floor(n*1e4+.5)end -- rounding noise must not reorder them
			for _,list in pairs(out)do
				table.sort(list,function(x,y)
					local a,b=x.p,y.p
					return if r(a.Z)~=r(b.Z)then a.Z<b.Z elseif r(a.X)~=r(b.X)then a.X<b.X else a.Y<b.Y
				end)
			end
			return out
		end
		local ga,gb=groupBoxes(a,D,k),groupBoxes(b,D1,1)
		for group,list in pairs(gb)do
			assert(#ga[group]==#list,group)
			for i,box in ipairs(list)do
				local got=ga[group][i]
				assert(near(got.p,box.p,1e-5)and near(got.size,box.size,1e-6)and near(got.look,box.look),group.." collider "..i)
			end
		end
		-- The slide's root: its scaled ladder foot on the slot's approach.
		assert(near(D.Slide.ladder[2],T.Slots.slide.approach,1e-5)and near(D.Slide.ladder[1],T.Slots.slide.approach),"the ladder foot")
	end)

	test("seats, ladder, chute, castle and ball homes move with the frames (x1.25 from their roots)",function()
		for _,id in ipairs({"swing1","swing2"})do
			local s,o=D.Swings[id],D1.Swings[id]
			assert(s.mesh==o.mesh and s.amplitude==o.amplitude and s.period==o.period,id)
			assert(near(D.Roots.SwingSet:PointToObjectSpace(s.pivot.Position),D1.Roots.SwingSet:PointToObjectSpace(o.pivot.Position)*k,1e-5),id.." pivot")
			for _,angle in ipairs({-.5,0,.4})do
				local p=D.Roots.SwingSet:PointToObjectSpace(D.swingSeat(id,angle).Position)
				local q=D1.Roots.SwingSet:PointToObjectSpace(D1.swingSeat(id,angle).Position)
				assert(near(p,q*k,1e-5),id.." seat at "..angle)
			end
		end
		for _,id in ipairs({"seesaw1","seesaw2"})do
			for _,tilt in ipairs({-.26,0,.26})do
				local p=D.Roots.SeeSaw:PointToObjectSpace(D.seesawSeat(id,tilt).Position)
				local q=D1.Roots.SeeSaw:PointToObjectSpace(D1.seesawSeat(id,tilt).Position)
				assert(near(p,q*k,1e-5),id.." seat at "..tilt)
			end
		end
		assert(#D.Slide.ladder==#D1.Slide.ladder and #D.Slide.chute==#D1.Slide.chute)
		local function slideLocal(data,p)return data.Slide.root:PointToObjectSpace(p)end
		for i=2,#D.Slide.ladder do assert(near(slideLocal(D,D.Slide.ladder[i]),slideLocal(D1,D1.Slide.ladder[i])*k,1e-5),"ladder "..i)end
		for i,p in ipairs(D.Slide.chute)do assert(near(slideLocal(D,p),slideLocal(D1,D1.Slide.chute[i])*k,1e-5),"chute "..i)end
		assert(near(slideLocal(D,D.Slide.platform),slideLocal(D1,D1.Slide.platform)*k,1e-5)and near(slideLocal(D,D.Slide.chuteTop),slideLocal(D1,D1.Slide.chuteTop)*k,1e-5))
		assert(near(D.Slide.yaw,D1.Slide.yaw),"the slide keeps its heading")
		assert(near(D.Sand.castle.Position,D1.Sand.castle.Position+Vector3.new(0,.32*(k-1),0),1e-6)and near(D.Sand.height,.4))
		for _,key in ipairs({"homeA","homeB"})do
			assert(near(D.Roots.BallCorner:PointToObjectSpace(D.Ball[key]),D1.Roots.BallCorner:PointToObjectSpace(D1.Ball[key])*k,1e-5),key)
		end
		assert(near(D.Ball.radius,.525)and near(D.Ball.matTop,.1625)and near(D.Lift.sandbox,.4)and near(D.Lift.ball,.1625))
		-- The crumble sinks x1.25 too (the castle is x1.25 tall).
		local sand={activity="sandbox",startTime=0,session="s"}
		local _,_,_,sink=D.castle(sand,12.5);local _,_,_,sink1=D1.castle(sand,12.5)
		assert(sink>0 and near(sink,sink1*k))
	end)

	test("slots agree with the scaled toys: seats, step-outs, the ladder foot and chute end, dig and ball spots",function()
		local function flat(p)return Vector2.new(p.X,p.Z)end
		local function facing(yaw)return Vector2.new(math.sin(yaw),math.cos(yaw))end
		-- Swings: the slot's pivot over its mesh's (ParkPoseData matches them by XZ), the rider waits SeatStepOut in front.
		for _,id in ipairs({"swing1","swing2"})do
			local slot=T.Slots[id];local swing=D.Swings[id]
			assert((flat(slot.pivot)-flat(swing.pivot.Position)).Magnitude<=.05*k+1e-3,id.." slot pivot off its mesh")
			assert(near(slot.pivot.Y-slot.seatGround.Y,7.0,1e-6),id.." bar 7.0 (5.6 x 1.25)")
			local seat=D.swingSeat(id,0).Position
			local out=flat(slot.approach)-flat(seat)
			assert(math.abs(out:Dot(facing(slot.yaw))-T.SeatStepOut)<.06*k,id.." waits "..out.Magnitude.." in front, not the pet-sized "..T.SeatStepOut)
			assert(T.SeatStepOut==T1.SeatStepOut,"the step-out stays pet-sized")
		end
		-- See-saw: the seat grounds under the mesh seats (2.6 vs 2.62, x1.25), the riders wait SeatStepOut off the beam.
		for _,id in ipairs({"seesaw1","seesaw2"})do
			local slot=T.Slots[id]
			local seat=D.seesawSeat(id,0).Position
			assert((flat(slot.seatGround)-flat(seat)).Magnitude<=.02*k+1e-3,id.." seat ground off its mesh seat")
			assert(near((flat(slot.approach)-flat(slot.seatGround)).Magnitude,T.SeatStepOut,1e-6),id.." step-out")
			assert(near(math.abs(slot.arm),2.6*k)and near(slot.pivot.Y-slot.seatGround.Y,1.1*k,1e-6))
		end
		-- Slide: the ladder foot 1.2 x 1.25 behind the deck, the chute's run 7.5 x 1.25, its end by the mesh chute's foot.
		local e=T.Equipment.slide
		assert(near((flat(T.Slots.slide.approach)-flat(e.position)).Magnitude,1.2*k,1e-6),"ladder foot")
		assert(near((flat(e.chuteEnd)-flat(e.position)).Magnitude,7.5*k,1e-6),"chute run")
		local foot=D.Slide.chute[#D.Slide.chute]
		assert((flat(foot)-flat(T.Slots.slide.chuteEnd)).Magnitude<=.15*k+1e-3,"the mesh chute ends off the slot's chute end")
		assert(D.Slide.landing==T.Slots.slide.chuteEnd)
		-- The deck 3.6 x 1.25 up (to the arrival lawn's .001 the arrangement was surveyed on).
		assert(near(T.Slots.slide.ladderTop.Y-T.ground(0,0),3.6*k,.01)and near(T.Slots.slide.chuteTop.Y-T.ground(0,0),3.6*k,.01))
		-- Sand: the dig spots 1.6 x 1.25 off the castle, inside the frame's walls (2.14 x 1.25) and clear of the big castle.
		local castle=flat(D.Sand.castle.Position)
		for _,id in ipairs({"sand1","sand2"})do
			local d=(flat(T.Slots[id].approach)-castle).Magnitude
			assert(near(d,1.6*k,1e-6)and d<2.14*k-.5 and d>D.Meshes.Park_Castle3.size.X*.5+.3,id)
			assert(near(D.spot(id).Y-T.Slots[id].approach.Y,.4,1e-6),id.." stands on the sand")
		end
		-- Ball: the spots 2 x 1.25 out, on the mat; the ball in front keeps its near side .33 in front of the pet.
		for _,id in ipairs({"ball1","ball2"})do
			local slot=T.Slots[id]
			local d=(flat(slot.approach)-flat(T.Equipment.ball.position)).Magnitude
			assert(near(d,2*k,1e-6)and d<=D.Meshes.Park_BallMat.size.X*.5,id.." off the mat")
			local front=D.ballFront(id)
			local gap=(flat(front)-flat(D.spot(id))).Magnitude-D.Ball.radius
			assert(near(gap,.33,1e-6),id.." ball gap "..gap)
			assert(near(front.Y-D.spot(id).Y,D.Ball.radius,1e-6))
		end
		-- Keepouts grow with the toys.
		for id,entry in pairs(T.Equipment)do assert(near(entry.keepout,T1.Equipment[id].keepout*k),id.." keepout")end
	end)

	test("the worn patches x1.25 (the slide's 1.5 x 1.25 down the chute); stones, boulders, flowers and bench as they were",function()
		local a,b=T.Dressing,T1.Dressing
		assert(#a.plates==#b.plates and #a.stones==#b.stones and #a.flowers==#b.flowers)
		for i,plate in ipairs(a.plates)do
			local old=b.plates[i]
			assert(plate.name==old.name and near(plate.size.X,old.size.X*k)and near(plate.size.Y,old.size.Y*k),plate.name)
			if plate.name~="TopLawnPatch_slide"then assert(plate.x==old.x and plate.z==old.z,plate.name.." moved")end
		end
		for i,stone in ipairs(a.stones)do local o=b.stones[i];assert(stone.x==o.x and stone.z==o.z and stone.size==o.size,stone.name)end
		for i,f in ipairs(a.flowers)do local o=b.flowers[i];assert(f.x==o.x and f.z==o.z and f.size==o.size)end
		assert(T.Benches[1].position==T1.Benches[1].position and T.Benches[1].yaw==T1.Benches[1].yaw)
	end)

	-- Footprints on the ground: each toy mesh as a box (static, the beam at rest, the swings at their highest), as 2D OBBs.
	local function boxes(data)
		local out={}
		local function add(group,cframe,size)
			local c=Vector2.new(cframe.Position.X,cframe.Position.Z)
			local x=Vector2.new(cframe.RightVector.X,cframe.RightVector.Z);local z=Vector2.new(cframe.LookVector.X,cframe.LookVector.Z)
			if x.Magnitude<1e-6 then x=Vector2.new(1,0)else x=x.Unit end
			if z.Magnitude<1e-6 then z=Vector2.new(0,1)else z=z.Unit end
			-- Project the box's extents on the ground axes (a tilted box spreads over |cos|).
			local hx=size.X*.5*math.abs(cframe.RightVector.Unit:Dot(Vector3.new(x.X,0,x.Y)))+size.Y*.5*math.abs(cframe.UpVector:Dot(Vector3.new(x.X,0,x.Y)))+size.Z*.5*math.abs(cframe.LookVector:Dot(Vector3.new(x.X,0,x.Y)))
			local hz=size.X*.5*math.abs(cframe.RightVector:Dot(Vector3.new(z.X,0,z.Y)))+size.Y*.5*math.abs(cframe.UpVector:Dot(Vector3.new(z.X,0,z.Y)))+size.Z*.5*math.abs(cframe.LookVector:Dot(Vector3.new(z.X,0,z.Y)))
			out[group]=out[group]or {}
			table.insert(out[group],{c=c,x=x,z=Vector2.new(-x.Y,x.X),hx=hx,hz=hz})
		end
		for _,entry in ipairs(data.layout().static)do if GROUP_ROOT[entry.group]then add(entry.group,entry.cframe,entry.size)end end
		add("SeeSaw",data.frame("Park_SeeSawBeam",data.Roots.SeeSaw,data.seesawMotion(data.SeeSaw.rest)),data.Meshes.Park_SeeSawBeam.size)
		local high=.5*require(Shared.ParkPerks).SwingScale
		for _,name in ipairs({"Park_SwingA","Park_SwingB"})do
			for _,angle in ipairs({-high,high})do add("SwingSet",data.frame(name,data.Roots.SwingSet,data.swingMotion(angle)),data.Meshes[name].size)end
		end
		return out
	end
	local function corners(b)
		local out={}
		for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do table.insert(out,b.c+b.x*b.hx*sx+b.z*b.hz*sz)end end
		return out
	end
	-- Separating-axis gap between two ground boxes (negative = overlap).
	local function gap(a,b)
		local best=-math.huge
		for _,axis in ipairs({a.x,a.z,b.x,b.z})do
			local function span(box)
				local lo,hi=math.huge,-math.huge
				for _,p in ipairs(corners(box))do local d=p:Dot(axis);lo=math.min(lo,d);hi=math.max(hi,d)end
				return lo,hi
			end
			local alo,ahi=span(a);local blo,bhi=span(b)
			best=math.max(best,math.max(blo-ahi,alo-bhi))
		end
		return best
	end

	-- {rim = {group = normalised radius of its outermost corner}, pairs = {"A-B" = gap}, gaps, stones = {name = gap}, bench}.
	local function footprint(site,data)
		local all=boxes(data)
		local out={rim={},pairs={},stones={}}
		local Tier=require(Shared.Tier)
		out.terrace=math.huge
		for group,list in pairs(all)do
			local worst=0
			for _,b in ipairs(list)do
				for _,p in ipairs(corners(b))do
					worst=math.max(worst,site.normalized(Vector3.new(p.X,0,p.Y)))
					local ps,pt=Tier.local2(nil,p.X,p.Y)
					out.terrace=math.min(out.terrace,Tier.Length/2-math.abs(ps),Tier.Width/2-math.abs(pt))
				end
			end
			out.rim[group]=worst
		end
		local groups={"SwingSet","Slide","SeeSaw","Sandbox","BallCorner"}
		for i=1,#groups do
			for j=i+1,#groups do
				local g=math.huge
				for _,a in ipairs(all[groups[i]])do for _,b in ipairs(all[groups[j]])do g=math.min(g,gap(a,b))end end
				out.pairs[groups[i].."-"..groups[j]]=g
			end
		end
		local function circleGap(p,r)
			local g,by=math.huge,nil
			for group,list in pairs(all)do for _,b in ipairs(list)do
				local d=p-b.c;local lx,lz=math.clamp(d:Dot(b.x),-b.hx,b.hx),math.clamp(d:Dot(b.z),-b.hz,b.hz)
				local e=(p-(b.c+b.x*lx+b.z*lz)).Magnitude-r
				if e<g then g,by=e,group end
			end end
			return g,by
		end
		out.gaps=math.huge
		for _,g in ipairs(site.Gateways)do out.gaps=math.min(out.gaps,(circleGap(Vector2.new(g.position.X,g.position.Z),g.width*.5)))end
		for i,s in ipairs(site.Dressing.stones)do
			local g,by=circleGap(Vector2.new(s.x,s.z),s.size.X*.5)
			out.stones[s.name..i.."/"..by]=g
		end
		local bench=site.Benches[1]
		local benchBox={c=Vector2.new(bench.position.X,bench.position.Z),x=Vector2.new(math.cos(bench.yaw),-math.sin(bench.yaw)),
			z=Vector2.new(math.sin(bench.yaw),math.cos(bench.yaw)),hx=bench.length*.5,hz=1.39*.5}
		out.bench=math.huge
		for _,list in pairs(all)do for _,b in ipairs(list)do out.bench=math.min(out.bench,gap(b,benchBox))end end
		return out
	end
	-- Measured 2026-11-26 at x1.25 with the see-saw at (7.6, 10.4) and the dig spot 0.7 nearer K: every toy inside the
	-- circle (r 13; the see-saw's beam end 0.01 in, the sand frame's corner 0.05), the rim boulders touch the frame's
	-- corner by 0.08 at most (0.75 at Fable's places), the gap stones clear by 0.33+.
	test("the Top Lawn footprint: toys clear of each other, the gaps, the bench and the terrace's edge, inside the rim, off the boulders",function()
		local f=footprint(T,D)
		for name,g in pairs(f.pairs)do assert(g>=1.5,name.." too close: "..g)end
		assert(f.gaps>=1 and f.bench>=1.5 and f.terrace>=5,"a toy on a gap, the bench or the terrace's edge")
		for _,group in ipairs({"SwingSet","Slide","BallCorner","SeeSaw","Sandbox"})do assert(f.rim[group]<1,group.." past the rim")end
		for name,g in pairs(f.stones)do
			if string.find(name,"^TopLawnGapStone")then assert(g>=.3,name.." on a toy")
			else assert(g>=-.2,name.." deep in a toy: "..g)end
		end
	end)

	return {passed=#cases,cases=cases}
end
