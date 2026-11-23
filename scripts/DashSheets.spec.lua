-- Garden Dash sheets (beta 12 QA U3 and U6): the mode picker and results layouts on every screen, the results model
-- (place, time, best, Stars, the field), the podium hops and the stage camera. Pure parts only.
-- Usage (Client): require(ZZSpecs.DashSheets)(StarterPlayerScripts.Client)
-- Offline: scripts/run_dash_server_specs.py
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local UICopy=require(Shared.UICopy)
	local Layout=require(client.DashSheetLayout)
	local Results=require(client.DashResults)
	local Pose=require(client.DashPose)
	local Stage=require(client.DashStage)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function inside(b,w,h)return b.x>=0 and b.y>=0 and b.x+b.w<=w and b.y+b.h<=h end
	local function apart(a,b)return a.x+a.w<=b.x or b.x+b.w<=a.x or a.y+a.h<=b.y or b.y+b.h<=a.y end
	-- Spencer's phone, a 667 phone, the smallest phone, the Roblox bar's leftovers, a tablet and desktops.
	local SCREENS={{874,402},{667,375},{568,320},{667,317},{579,317},{844,332},{600,360},{1024,768},{1280,720},{1920,1080}}
	local function onScreen(g,W,H)
		local c=g.card
		return c.x>=0 and c.y>=0 and c.x+g.w*g.scale<=W+1 and c.y+g.h*g.scale<=H+1
	end

	test("the mode picker: on screen, every piece inside the card and apart, tiles big enough to tap",function()
		for _,s in ipairs(SCREENS)do
			local W,H=s[1],s[2]
			local g=Layout.gate(W,H)
			assert(onScreen(g,W,H),"on screen at "..W.."x"..H)
			local pieces={stage=g.stage,title=g.title,close=g.close,stats=g.stats,foot=g.foot,tile1=g.tiles[1],tile2=g.tiles[2],tile3=g.tiles[3],line=g.line}
			local names={}
			for name,b in pairs(pieces)do assert(inside(b,g.w,g.h),name.." at "..W.."x"..H);table.insert(names,name)end
			for i=1,#names do for j=i+1,#names do
				assert(apart(pieces[names[i]],pieces[names[j]]),names[i].." and "..names[j].." at "..W.."x"..H)
			end end
			for _,tile in ipairs(g.tiles)do assert(tile.h>=44 and tile.w>=88,"tile at "..W)end
			assert(inside(g.pedestal,g.stage.w,g.stage.h)and inside(g.name,g.stage.w,g.stage.h)and g.name.y>=g.pedestal.y+g.pedestal.h+6,"name under the pedestal")
			if H<=430 and not g.small then assert(g.w==620 and g.h==276 and g.scale==1 and g.stage.w==196 and g.tiles[1].w==122,"the phone sheet as drawn at "..W)end
			if g.small then assert(g.h==236 and g.line==nil and g.band==nil)end
			if H>430 then assert(g.scale>1 and g.scale<=Layout.Big)end
		end
		assert(not Layout.gate(568,320).tileSub and Layout.gate(667,375).tileSub,"the line under each tile goes below 600")
	end)
	test("the results card: on screen, rows stacked, Race again twice Done, the field only with room",function()
		for _,s in ipairs(SCREENS)do
			local W,H=s[1],s[2]
			for _,opts in ipairs({{earned=true,field=true,strip=true},{earned=true,field=true},{earned=false,field=true},{earned=true},{}})do
				local g=Layout.results(W,H,opts)
				assert(onScreen(g,W,H),"on screen at "..W.."x"..H)
				local rows={g.headline,g.time,g.earned,g.field}
				local last=nil
				for _,b in pairs(rows)do assert(inside(b,g.w,g.h))end
				for _,b in ipairs({g.headline,g.time})do if last then assert(b.y>=last.y+last.h)end;last=b end
				if g.earned then assert(g.earned.y>=g.time.y+g.time.h)end
				if g.field then assert(g.field.y>=(g.earned or g.time).y+40)end
				assert(inside(g.stage,g.w,g.h)and inside(g.again,g.w,g.h)and inside(g.done,g.w,g.h)and apart(g.again,g.done))
				assert(g.again.y>=g.stage.y+g.stage.h and g.again.h>=44 and math.abs(g.again.w-2*g.done.w)<=g.done.w*.1,"two to one at "..W)
				if g.strip then assert(g.strip.y>=g.stage.y+g.stage.h and g.again.y>=g.strip.y+g.strip.h and g.strip.h==48)end
				assert((g.field~=nil)==(opts.field==true and not(W<640 or H<390)),"the field row at "..W.."x"..H)
			end
		end
		local g=Layout.results(874,402,{earned=true,field=true,strip=true})
		assert(g.h==312 and g.again.w==388 and g.done.w==196 and g.stage.h==172,"Spencer's phone, as drawn")
		assert(Layout.results(874,402,{earned=true,field=true}).h==256)
		assert(Layout.results(667,375,{earned=true,field=true,strip=true}).h==272,"H under 390: the field goes")
	end)
	test("the results model: place and medal, time and best, new best, and every Stars case",function()
		local packet={place=2,us=41230000,mode="fun",seat=1,seats={{seat=3,place=1,us=40000000},{seat=1,place=2,us=41230000}}}
		local m=Results.model(packet,nil,nil,{prizes=true})
		assert(m.headline=="You finished 2nd!"and m.time=="41.2"and m.medal.ordinal=="2nd"and m.medal.color=="#DCE5FF"and m.celebrate)
		assert(m.earned.state=="saving"and m.earned.text==UICopy.get("dash.result.saving"),"nothing shown before the save")
		local mine={best=41230000,paid=2,limit=5,last={op="b",stars=3}}
		m=Results.model(packet,mine,"a",{prizes=true,bestBefore=42000000})
		assert(m.earned.state=="paid"and m.earned.stars==3 and m.earned.done==2 and m.earned.total==5 and m.newBest and m.best=="41.2")
		m=Results.model(packet,mine,"b",{prizes=true,bestBefore=41230000})
		assert(m.earned.state=="saving"and not m.newBest,"an old receipt is not this race's; an equal best is not new")
		m=Results.model(packet,{paid=5,limit=5,last={op="b",stars=2}},"b",{prizes=true})
		assert(m.earned.state=="usedUp"and m.earned.text==UICopy.get("dash.result.tomorrow")and m.earned.done==5,"used up: no +0")
		m=Results.model(packet,{paid=2,limit=5,last={op="c",stars=0}},"b",{prizes=true})
		assert(m.earned.state=="none")
		assert(Results.model(packet,mine,"a",{prizes=false}).earned==nil,"prizes off: the row is left out")
		m=Results.model({place=6,us=50000000,seat=1,seats={{seat=1,place=6}}},nil,nil,{})
		assert(not m.celebrate and m.medal.color==Results.Cream and m.field==nil,"a race of one has no field; never a sad screen")
	end)
	test("the field: the top three and you; yours marked; names by seat; a Time Trial has none",function()
		local seats={}
		for place=1,8 do seats[place]={seat=9-place,place=place,us=40000000+place*100000}end
		local names={}
		for seat=1,8 do names[seat]="Pet"..seat end
		for _,mySeat in ipairs({8,6,3})do
			local myPlace=9-mySeat
			local m=Results.model({place=myPlace,us=1,seat=mySeat,seats=seats},nil,nil,{names=names})
			assert(#m.field==4,mySeat)
			for index=1,3 do assert(m.field[index].place==index)end
			local mineCount=0
			for _,chip in ipairs(m.field)do if chip.mine then mineCount+=1;assert(chip.name=="Pet"..mySeat and chip.place==myPlace)end end
			assert(mineCount==1)
			if myPlace<=3 then assert(m.field[4].place==4)else assert(m.field[4].place==myPlace)end
		end
		local m=Results.model({trial=true,place=1,us=29900000,medal="gold",seat=1,seats={{seat=1,place=1}}},nil,nil,{prizes=true})
		assert(m.field==nil and m.medal.cup=="gold"and m.medal.color=="#FFC14D"and m.earned.state=="cup"and m.celebrate)
		m=Results.model({trial=true,place=1,us=39900000,seat=1},nil,nil,{prizes=true})
		assert(m.medal.stopwatch and m.earned.state=="noCup"and m.earned.text==UICopy.get("dash.result.tryAgain")and not m.celebrate)
		assert(Results.key(Results.model(seats[1],nil,nil,{prizes=true}))~=Results.key(Results.model(seats[1],{paid=1,limit=5,last={op="z",stars=2}},nil,{prizes=true})))
	end)
	test("the podium: two hops for 1st to 3rd then one every 3 s, one hop lower down, never under the step; Reduced Motion still",function()
		local function hops(place,seconds)
			local count,up=0,false
			for t=0,seconds,1/120 do
				local lift=Pose.podiumLift(t,place,1,false)
				assert(lift>=0)
				if lift>.05 and not up then count+=1 end
				up=lift>.05
			end
			return count
		end
		assert(hops(1,.9)==2 and hops(4,.9)==1 and hops(6,6)==1)
		assert(hops(2,.84+3.1)==3,"another hop at the end of the next 3 s")
		for t=0,5,.1 do assert(Pose.podiumLift(t,1,1,true)==0)end
	end)
	test("the stage camera: the pet in the middle third, its feet on the pedestal line, looking a little down",function()
		local size=Vector3.new(2,2.4,2)
		local eye,look=Stage.camera(size,1.2,196,248,150)
		assert(eye.Y>look.Y and eye.Z>0 and eye.X>0,"front three-quarter, from the right, from above")
		local away=(eye-look).Magnitude
		local tanH=math.tan(math.rad(Stage.Fov)/2)*196/248
		assert(2/(2*away*tanH)<=Stage.Fill+.05,"fills at most about 60% of the width")
	end)
	test("Studio check beta 12: every pet's whole box (ears, horns, hats) and its highest hop stay inside the stage, feet on the line",function()
		-- Bear with its ears, a horned or hatted pet, a tall thin one, a wide low one, a big one.
		local pets={Vector3.new(1.1,1.75,.95),Vector3.new(1,2.6,1),Vector3.new(.7,2.2,.7),Vector3.new(2.6,1,1.6),Vector3.new(2.4,3.2,2)}
		local stages={}
		for _,screen in ipairs(SCREENS)do
			local W,H=screen[1],screen[2]
			local g=Layout.gate(W,H)
			table.insert(stages,{w=g.stage.w,h=g.stage.h,feet=g.pedestal.y+g.pedestal.h*.45})
			for _,opts in ipairs({{earned=true,field=true,strip=true},{}})do
				local r=Layout.results(W,H,opts)
				table.insert(stages,{w=r.stage.w,h=r.stage.h,feet=r.podium.y+r.podium.h*.45})
			end
		end
		local top=math.max(Stage.Headroom,math.floor(150*.06))
		for _,st in ipairs(stages)do
			local top=math.max(Stage.Headroom,math.floor(st.h*.06))
			for _,size in ipairs(pets)do
				for _,lift in ipairs({0,Pose.JumpHeight})do
					local centre=size.Y/2
					local eye,look=Stage.camera(size,centre,st.w,st.h,st.feet,lift)
					local _,feet=Stage.project(eye,look,Vector3.new(0,0,0),st.w,st.h)
					assert(math.abs(feet-st.feet)<=1,"feet on the line ("..feet.." vs "..st.feet..")")
					for _,rise in ipairs({0,lift})do
						for _,sx in ipairs({-1,1})do for _,sy in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
							local x,y=Stage.project(eye,look,Vector3.new(sx*size.X/2,centre+rise+sy*size.Y/2,sz*size.Z/2),st.w,st.h)
							assert(y>=top-.5,"headroom over a "..tostring(size.Y).."-stud pet in a "..st.w.."x"..st.h.." stage: "..y)
							assert(x>=Stage.Side-.5 and x<=st.w-Stage.Side+.5,"inside the sides")
						end end end
					end
				end
			end
		end
		assert(top>0)
	end)
	test("FABLE-REVIEW-R1 7: the results pet is 84 pt on a tall stage and 62 on a short one, hops 24 or 16, 8 clear at the top",function()
		for _,screen in ipairs(SCREENS)do
			local W,H=screen[1],screen[2]
			for _,opts in ipairs({{earned=true,field=true,strip=true},{earned=true},{}})do
				local r=Layout.results(W,H,opts)
				local tall=r.stage.h>=150
				local pod,pet=r.podium,r.pet
				assert(pod.w==math.min(if tall then 132 else 110,r.stage.w-16)and pod.h==(if tall then 22 else 18))
				assert(r.stage.h-(pod.y+pod.h)==(if tall then 14 else 10),"the step above the bottom")
				assert(pet.height==(if tall then 84 else 62)and pet.hop==(if tall then 24 else 16)and pet.shift==10 and pet.clear==8)
				-- A Bear-sized pet with its ears: the box is pet.height on screen, and the top of its hop stays 8 clear.
				local size=Vector3.new(1.1,1.75,.95)
				local feetY=pod.y+pod.h*.45
				local hop=pet.hop*size.Y/pet.height
				local eye,look=Stage.camera(size,size.Y/2,r.stage.w,r.stage.h,feetY,hop,pet)
				local _,feet=Stage.project(eye,look,Vector3.new(0,0,0),r.stage.w,r.stage.h)
				local _,crown=Stage.project(eye,look,Vector3.new(0,size.Y,0),r.stage.w,r.stage.h)
				assert(math.abs((feet-crown)-pet.height)<=2,"pet "..(feet-crown).." pt on a "..r.stage.h.." stage")
				assert(math.abs(feet-feetY)<=1)
				for _,sx in ipairs({-1,1})do for _,sz in ipairs({-1,1})do
					local _,y=Stage.project(eye,look,Vector3.new(sx*size.X/2,size.Y+hop,sz*size.Z/2),r.stage.w,r.stage.h)
					assert(y>=pet.clear-.5,"clear over the hop: "..y)
				end end
			end
		end
	end)
	return{passed=#cases,cases=cases}
end
