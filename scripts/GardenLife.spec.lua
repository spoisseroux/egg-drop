-- Studio Client. Garden life, the parts (GardenLife, ALIVE-LIFE-BUILD-PLAN-2026-11-22) with a fake switch, clock, camera,
-- Heartbeat and world: nil with the ceiling off; the switch off is nothing but its signal; on is one folder of inert
-- parts and one Heartbeat; off mid-flight destroys it all in that frame; parked (hatch, board, my race) hides
-- everything and simulates nothing; Reduced Motion; budget level 2 shows nothing; a chirp lands a bird on that perch's
-- crown and the 4th is refused; bubbles refuse a station, a live course and a menu; the round 3 look (beta 12 QA L1-L3,
-- GARDEN-LIFE-NEST-LOOK): eight-part songbirds and butterflies with LifeArt textures, the dusk hand-off to firefly glows
-- (off at once when parked or with Reduced Motion), the leaves round the player under the cap and never under a roof,
-- two fixed-size bubble emitters; Dewdrops (FRUIT-LOOK):
-- 16 billboards made once, hanging caps per level, the same simulated drops on four clients (cameras far apart, budget
-- levels 0 and 1, Reduced Motion), Reduced Motion, parked, a live race, pink crowns skipping the pool,
-- landing rejection and the pet bat. Garden hour slice D: off (daylight nil) and day are today's garden; golden, night
-- and dawn start no bubbles or birds (leaves and fruit as by day), butterflies fly over .30; the ones out finish; the
-- gate is the server clock's, the same on four clients.
-- Usage: require(PlayerScripts.Client.ZZSpecs.GardenLife)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="GardenLife").
return function(client)
	local Life=require(client.GardenLife)
	local Sim=require(client.LifeSim)
	local Wind=require(client.Wind)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local T0=1795300000
	local function signal()
		local s={list={}}
		function s:Connect(fn)
			local c={Connected=true}
			function c:Disconnect()self.Connected=false;local at=table.find(s.list,fn);if at then table.remove(s.list,at)end end
			table.insert(s.list,fn)
			return c
		end
		function s:Fire(...)for _,fn in ipairs(table.clone(s.list))do fn(...)end end
		return s
	end
	local LANDING=Vector3.new(10,14,-20)
	local SPOTS={Perches=6,Landings={[1]=Vector3.new(-10,14,-20),[2]=LANDING,[3]=Vector3.new(20,14,-30),[4]=Vector3.new(-20,14,-30)},
		Crowns={{position=Vector3.new(0,12,-25),size=Vector3.new(8,5,8)},{position=Vector3.new(30,12,-25),size=Vector3.new(8,5,8)}}}
	local rigs={}
	local function rig(options)
		options=options or {}
		local r={on=options.on~=false,ceiling=options.ceiling~=false,now=options.now or T0,level=options.level or 0,hatch=false,mode="Room",
			held=false,phase="idle",menu=false,reduced=false,moves=0,warned={},ambient={}}
		r.changed=signal();r.beat=signal()
		r.camera=CFrame.lookAt(Vector3.new(0,10,10),Vector3.new(0,8,-10))
		r.player=Vector3.new(0,5,8)
		r.pets={}
		r.crownColour="lime"
		r.daylight=options.daylight
		r.world=Instance.new("Folder");r.world.Name="_GardenLifeSpec";r.world.Parent=workspace
		r.dash={held=function()return r.held end,summary=function()return{phase=r.phase}end}
		r.life=Life.mount({ambient=r.ambient,world=r.world,heartbeat=r.beat,seed=7,
			alive={ceiling=function(f)return f=="life"and r.ceiling end,on=function(f)return(f=="life"and r.on)or(f=="scene"and r.on and r.scene==true)end,changed=function()return r.changed end},
			now=function()return r.now end,camera=function()return r.camera end,root=function()return r.player end,
			level=function()return r.level end,hatching=function()return r.hatch end,mode=function()return r.mode end,
			dash=function()return r.dash end,modalOpen=function()return r.menu end,reduced=function()return r.reduced end,
			move=function(parts,frames)r.moves+=1;for i,p in ipairs(parts)do p.CFrame=frames[i]end end,
			spots=options.spots or SPOTS,patches=options.patches or {Vector3.new(4,4,-14),Vector3.new(-6,4,-18),Vector3.new(10,4,-10)},
			stations=options.stations or {Vector3.new(200,4,200)},pad=options.pad or {x=300,z=300,r=3},course=options.course or {400,400,500,400},
			crowns=function()return r.crownColour end,warn=function(text)table.insert(r.warned,text)end,
			groundY=options.groundY or function()return 4 end,safe=options.safe or function()return true end,
			finds=options.finds or {},kerbs=options.kerbs or {},pets=function()return r.pets end,
			cover=options.cover or {},leafGround=options.leafGround,leaves=function()return options.leaves~=false end,
			report=options.report or function()end,banks=options.banks or {},groveCrowns=options.groveCrowns,kitParts=options.kitParts,
			-- The garden hour: r.daylight (nil = the hour off), or r.hour(now) when a case drives the real clock.
			daylight=if options.realHour then nil else function(now)if r.hour then return r.hour(now)end return r.daylight end})
		function r.step(seconds)
			for _=1,math.floor(seconds*30+.5)do r.now+=1/30;r.beat:Fire(1/30)end
		end
		function r.folder()return r.world:FindFirstChild(Life.Folder)end
		function r.parts()
			local folder=r.folder();local out={}
			if folder then for _,p in ipairs(folder:GetChildren())do if p.ClassName=="Part"or p.ClassName=="WedgePart"then table.insert(out,p)end end end
			return out
		end
		function r.flip(on)r.on=on;r.changed:Fire()end
		table.insert(rigs,r)
		return r
	end
	local function hidden(p)return p.CFrame.Position.Y>4000 end
	local function allHidden(r)for _,p in ipairs(r.parts())do if not hidden(p)then return false,p.Name end end return true end
	local function body(r,slot)return r.folder():FindFirstChild("LifeBird"..slot.."_Body")end

	local ok,problem=pcall(function()
		-- Garden hour slice D (GARDEN-HOUR-BUILD-PLAN-2026-11-23; GARDEN-HOUR-LOOK 5): bubbles, butterflies and birds by day.
		local function chirps(r)
			for perch=1,3 do r.life:chirp(perch)end
		end
		test("the hour's day is today: daylight nil (off) and .9 (the day hold) give the same garden, second by second",function()
			local off,day=rig(),rig({daylight=.9})
			for second=1,30 do
				if second==1 or second==24 then chirps(off);chirps(day)end
				off.step(1);day.step(1)
				local a,b=off.life:counts(),day.life:counts()
				for key,value in pairs(a)do assert(b[key]==value,second..": "..key.." "..value.." vs "..tostring(b[key]))end
			end
			local c=day.life:counts()
			assert(c.bubbles>0 and c.butterflies>0 and c.birds>0,"all of it by day: "..c.bubbles.." "..c.butterflies.." "..c.birds)
		end)
		test("golden, night and dawn: no bubbles or birds start, butterflies only over .30; leaves and Dewdrops as by day",function()
			for _,daylight in ipairs({.55,.12,.5})do
				local day,dark=rig(),rig({daylight=daylight})
				for second=1,24 do
					if second==1 or second==12 then
						chirps(day)
						for perch=1,3 do
							local result,why=dark.life:chirp(perch)
							assert(result==nil and why=="night",daylight..": chirp "..tostring(why))
						end
					end
					day.step(1);dark.step(1)
					local a,b=day.life:counts(),dark.life:counts()
					assert(b.bubbles==0 and b.birds==0,daylight..": nothing starts at "..second)
					if daylight<.3 then assert(b.butterflies==0,"no butterflies at night")end
					assert(a.leaves==b.leaves and a.fruit==b.fruit and a.loose==b.loose,daylight..": leaves and fruit unchanged")
				end
				assert(day.life:counts().butterflies>0,"the day rig has them")
				if daylight>.34 then assert(dark.life:counts().butterflies>0,daylight..": golden light and dawn keep butterflies")end
				-- Only leaf anchors and Dewdrops (and butterflies over .30, beta 14 B2 night fireflies under .34) may show.
				for _,p in ipairs(dark.parts())do
					if not hidden(p)then
						assert(string.match(p.Name,"^LifeLeaf")or string.match(p.Name,"^LifeDewdrop")or(daylight>.3 and string.match(p.Name,"^LifeButterfly"))
							or(daylight<.34 and string.match(p.Name,"^LifeFirefly")),p.Name)
					end
				end
			end
		end)
		test("day to night: the ones out finish (bubbles pop on time, butterflies fade past dusk, a bird sits out its stay)",function()
			local r=rig()
			r.step(.2);chirps(r)
			r.step(9)
			local c=r.life:counts()
			assert(c.bubbles>0 and c.butterflies>0 and c.birds>0,"out by day")
			r.daylight=.12
			r.step(2.1) -- the next poll reads the hour
			local bubbles,birds=r.life:counts().bubbles,r.life:counts().birds
			assert(r.life:counts().butterflies<=c.butterflies)
			for _,b in ipairs(r.life.flies.list)do assert(b.fade and not b.hand,"a jump past dusk (.12): wings fade, no glow")end
			for second=1,25 do
				r.step(1)
				local now=r.life:counts()
				assert(now.bubbles<=bubbles and now.birds<=birds,"nothing new")
				bubbles,birds=now.bubbles,now.birds
				if second>=1 then assert(now.butterflies==0 and now.glows==0,"butterflies gone, no glow")end
				if second>=Sim.BubbleLife+1 then assert(now.bubbles==0,"bubbles popped")end
			end
			assert(r.life:counts().birds==0,"the bird left after its stay")
			for slot=1,4 do assert(hidden(r.folder():FindFirstChild("LifeButterfly"..slot.."_Body")),"hidden "..slot)end
			assert(select(2,r.life:chirp(2))=="night")
			r.daylight=.9
			r.step(4.2)
			assert(r.life:counts().butterflies>0 and r.life:chirp(2)=="land","day again")
		end)
		test("the gate comes from the server clock only: four clients (far cameras, levels 0 and 1, Reduced Motion) open it together",function()
			local Hour=require(game:GetService("ReplicatedStorage").Shared.GardenHour)
			-- 30 s before dawn's blend reaches .7: the hold is at s = 360 + ...; start at s = 380.
			local start=T0-T0%Hour.Period+380
			local list={}
			for i=1,4 do
				local r=rig({now=start,level=if i==2 then 1 else 0})
				r.hour=function(now)return Hour.phase(now).daylight end
				if i==3 then r.camera=CFrame.lookAt(Vector3.new(300,40,300),Vector3.new(0,0,0))end
				if i==4 then r.reduced=true end
				list[i]=r
			end
			local flips=0
			local was=nil
			for _=1,60 do
				for _,r in ipairs(list)do r.step(1)end
				local day=list[1].life.day
				for _,r in ipairs(list)do assert(r.life.day==day,"the same gate on every client")end
				if was~=nil and day~=was then flips+=1 end
				was=day
			end
			assert(flips==1 and was==true,"opens once, inside the dawn blend")
		end)
		test("the default daylight is the garden hour's: nil while it is off, or while the Aero look is not painting it",function()
			local Hour=require(game:GetService("ReplicatedStorage").Shared.GardenHour)
			local Clock=require(client.HollowClock)
			local r=rig({realHour=true})
			local value=r.life.daylight(T0)
			local on=Clock.hourOn()==true
			if on then assert(value==Hour.phase(T0+Hour.offset()).daylight)else assert(value==nil,"off: "..tostring(value))end
			r.step(2.2)
			assert(r.life.day==(not on or Sim.day(value)),"the gate follows it")
			-- The gate is HollowClock.hourOn (the hour and Clock.look), not GardenHour.on alone: a client whose AeroWorld
			-- did not start keeps today's garden.
			local real=Clock.hourOn
			local ok,problem=pcall(function()
				Clock.hourOn=function()return false end
				assert(r.life.daylight(T0)==nil,"no Aero look: today's garden")
				Clock.hourOn=function()return true end
				assert(r.life.daylight(T0)==Hour.phase(T0+Hour.offset()).daylight,"on: the hour's daylight")
			end)
			Clock.hourOn=real
			assert(ok,problem)
		end)

		test("the ceiling off: mount is nil and nothing is connected",function()
			local r=rig({ceiling=false})
			assert(r.life==nil and #r.changed.list==0 and #r.beat.list==0 and r.folder()==nil and r.ambient.onChirp==nil)
		end)

		test("the switch off: only its signal, no parts, no Heartbeat, no chirp hook",function()
			local r=rig({on=false})
			assert(r.life and #r.changed.list==1 and #r.beat.list==0 and r.folder()==nil and r.ambient.onChirp==nil)
			r.step(1);assert(r.moves==0)
		end)

		test("on: one EggDropLife folder of anchored parts nothing can touch, one Heartbeat, the chirp hook set",function()
			local r=rig()
			local folder=assert(r.folder())
			assert(folder.Parent==r.world and #r.beat.list==1 and type(r.ambient.onChirp)=="function")
			local parts=r.parts()
			assert(#parts==3*10+4*3+3+2+16+8,"parts "..#parts) -- birds: ten parts each (FABLE-REVIEW-R3 3); 8 night fireflies (B2)
			for _,p in ipairs(parts)do
				assert(p.Anchored==true and p.CanCollide==false and p.CanQuery==false and p.CanTouch==false and p.CastShadow==false,p.Name)
				assert(string.sub(p.Name,1,2)~="W7",p.Name)
				assert(hidden(p),"starts hidden: "..p.Name)
			end
			r.step(2)
			assert(#r.beat.list==1,"still one Heartbeat")
		end)

		test("one move a step, at 30 Hz; 15 Hz at budget level 1",function()
			local r=rig()
			r.step(1)
			local before=r.moves
			for _=1,30 do local m=r.moves;r.now+=1/30;r.beat:Fire(1/30);assert(r.moves-m<=1,"one BulkMoveTo a step")end
			assert(r.moves-before<=30)
			r.level=1
			local steps=0
			local function count()steps+=1 end
			local saved=r.life.move
			r.life.move=function(...)count();return saved(...)end
			r.step(2)
			assert(steps<=31,"15 Hz: "..steps)
		end)

		test("a chirp lands a bird on that perch's crown; a repeat chirp hops; the 4th bird is refused",function()
			local r=rig()
			r.step(.1)
			assert(select(2,r.life:chirp(2,Vector3.zero,"bird_chirp_1"))=="perch","a chirp from another tree")
			assert(r.life:chirp(2,LANDING-Vector3.new(.3,5,.2),"bird_chirp_1")=="land")
			r.ambient.onChirp(1,SPOTS.Landings[1]-Vector3.new(0,6,0),"bird_chirp_2")
			assert(r.life:counts().birds==2,"the hook lands one too")
			r.step(1.2)
			local sitting
			for slot=1,3 do
				local b=body(r,slot)
				if not hidden(b)and(b.CFrame.Position-(LANDING+Vector3.new(0,Sim.Bird.lift,0))).Magnitude<.01 then sitting=b end
			end
			assert(sitting,"a bird sits on perch 2's landing")
			assert(sitting.Color==Life.BirdLooks[2%3].body,"perch 2's colourway")
			assert(r.life:chirp(2)=="hop")
			assert(r.life:chirp(3)=="land")
			local result,why=r.life:chirp(4)
			assert(result==nil and why=="cap","4th: "..tostring(why))
			assert(r.life:chirp(5)==nil and r.life:chirp(6)==nil,"perches with no landing show no bird")
			assert(r.life:counts().birds==3)
		end)

		test("off mid-flight: everything gone in that frame, the hook cleared, nothing left but the signal",function()
			local r=rig()
			r.step(.2)
			r.life:chirp(2);r.life:chirp(1)
			r.step(.3)
			r.flip(false)
			assert(r.folder()==nil and #r.beat.list==0 and r.ambient.onChirp==nil and #r.changed.list==1)
			assert(r.life:counts().birds==0)
			local m=r.moves;r.step(1);assert(r.moves==m,"nothing runs")
			r.flip(true)
			assert(r.folder()and #r.beat.list==1 and r.ambient.onChirp,"back on")
			r.life:destroy()
			assert(r.folder()==nil and #r.beat.list==0 and #r.changed.list==0 and r.ambient.onChirp==nil)
		end)

		test("parked by a hatch, the board or my own race: all hidden, nothing simulated, chirps ignored",function()
			for _,park in ipairs({"hatch","mode","race"})do
				local r=rig()
				r.step(.2)
				r.life:chirp(2)
				r.step(3.2)
				assert(r.life:counts().birds==1 and r.life:counts().butterflies>0,park..": things to hide")
				if park=="hatch"then r.hatch=true elseif park=="mode"then r.mode="Board"else r.held=true end
				r.step(.4)
				local all,name=allHidden(r)
				assert(all,park..": "..tostring(name).." still shown")
				local c=r.life:counts()
				assert(c.birds==0 and c.butterflies==0 and c.petals==0 and c.bubbles==0,park..": nothing simulated")
				local m=r.moves
				r.step(5)
				assert(r.moves==m,park..": no work while parked")
				assert(r.life:chirp(2)==nil,park..": chirp ignored")
				r.hatch,r.mode,r.held=false,"Room",false
				r.step(3)
				assert(r.life:counts().butterflies>0,park..": back on return")
			end
		end)

		test("a menu stops bubbles starting; birds and butterflies keep going",function()
			local r=rig()
			r.menu=true
			r.step(10)
			assert(r.life:counts().bubbles==0,"no bubble in a menu")
			assert(r.life:counts().butterflies>0)
			r.menu=false
			r.step(10)
			assert(r.life:counts().bubbles>=2,"bubbles by the camera: "..r.life:counts().bubbles)
			assert(r.life:counts().bubbles<=8)
		end)

		test("bubbles refuse a station ahead, and the course only while a race is live",function()
			local ahead={Vector3.new(0,4,-3)}
			local r=rig({stations=ahead})
			r.step(12)
			assert(r.life:counts().bubbles==0,"a station ahead")
			local line={-60,-3,60,-3}
			local q=rig({course=line})
			q.phase="live"
			q.step(12)
			assert(q.life:counts().bubbles==0,"a live course ahead")
			q.phase="idle"
			q.step(14)
			assert(q.life:counts().bubbles>0,"an idle course is fine")
		end)

		test("Reduced Motion: no petals, bubbles or butterflies; a chirped bird is just there, still",function()
			local r=rig()
			r.reduced=true
			r.step(.2)
			assert(r.life:chirp(2)=="land")
			r.step(.04)
			local b
			for slot=1,3 do if not hidden(body(r,slot))then b=body(r,slot)end end
			assert(b and(b.CFrame.Position-(LANDING+Vector3.new(0,Sim.Bird.lift,0))).Magnitude<1e-3,"sits at once")
			local at=b.CFrame.Position
			assert(r.life:chirp(2)==nil,"no hop")
			r.step(5)
			assert(b.CFrame.Position==at,"still: no turns, no bob")
			r.step(25)
			local c=r.life:counts()
			assert(c.petals==0 and c.bubbles==0 and c.butterflies==0,"nothing flies")
			assert(c.birds==0 and hidden(b),"gone without an arc once its stay is over")
		end)

		test("budget level 2 shows nothing, from the start or mid-session; level 1 halves the caps",function()
			local r=rig({level=2})
			assert(r.life and r.folder()==nil and #r.beat.list==0 and r.ambient.onChirp==nil)
			local q=rig()
			q.step(.2)
			q.life:chirp(1);q.life:chirp(2);q.life:chirp(3)
			q.step(.2)
			assert(q.life:counts().birds==3)
			q.level=1
			q.step(.2)
			assert(q.life:counts().birds==2,"level 1: two birds")
			assert(q.life:chirp(4)==nil)
			q.level=2
			q.step(.1)
			assert(q.folder()==nil and #q.beat.list==0 and q.ambient.onChirp==nil,"torn down")
			q.flip(false);q.flip(true)
			assert(q.folder()==nil,"never back up")
		end)

		test("round 3 parts: 8 a bird, 3 a butterfly and its glow, the sizes, LifeArt textures on the named faces, all wings preloaded",function()
			local LifeArt=require(game:GetService("ReplicatedStorage").Shared.LifeArt)
			local r=rig()
			local folder=r.folder()
			local Face=Enum.NormalId
			local function decals(p)
				local out={}
				for _,d in ipairs(p:GetChildren())do
					if d.ClassName=="Decal"then
						assert(d.Transparency==0 and d.ZIndex==1,p.Name)
						out[d.Face]=d
					end
				end
				return out
			end
			local function faces(p,want)
				local got=decals(p)
				local n=0
				for _ in pairs(got)do n+=1 end
				local m=0
				for face,texture in pairs(want)do
					m+=1
					assert(got[face]and got[face].Texture==texture,p.Name..": "..tostring(face.Name))
				end
				assert(n==m,p.Name..": "..n.." decals")
				return got
			end
			local function isWhite(c)return c.R==1 and c.G==1 and c.B==1 end
			local wingsLoaded={}
			for slot=1,3 do
				local name="LifeBird"..slot.."_"
				local n=0
				for _,p in ipairs(r.parts())do if string.sub(p.Name,1,#name)==name then n+=1 end end
				assert(n==10,"bird parts "..n)
				local look=Life.BirdLooks[(slot-1)%3]
				local bodyPart=folder:FindFirstChild(name.."Body")
				-- QA-R2-LOOK 3: the songbird's shape (a Sphere-meshed egg, a small head, a wedge beak, narrow wings and tail).
				assert(bodyPart.Size==Vector3.new(.50,.50,.74)and bodyPart.Shape~=Enum.PartType.Ball and bodyPart.Spindle.ClassName=="SpecialMesh")
				assert(bodyPart.Color==look.body and bodyPart.Material==Life.BirdMaterial)
				if LifeArt.id("birdBreast")then faces(bodyPart,{[Face.Front]=LifeArt.id("birdBreast")})else assert(next(decals(bodyPart))==nil,"no breast stand-in")end
				local head=folder:FindFirstChild(name.."Head")
				assert(head.Size==Vector3.new(.38,.38,.38)and head.Material==Life.BirdMaterial and head.Color==look.head)
				for _,side in ipairs({"EyeR","EyeL"})do
					local eye=folder:FindFirstChild(name..side)
					assert(eye.Size==Vector3.new(.09,.09,.09)and eye.Color==Life.EyeInk and eye.Reflectance==0,"no shine")
				end
				local beak=folder:FindFirstChild(name.."Beak")
				assert(beak.ClassName=="Part"and beak.Size==Vector3.new(.14,.12,.26)and beak.Spindle.ClassName=="SpecialMesh"and beak.Color==look.beak,"a horn spindle")
				local function lin(x)return if x<=.04045 then x/12.92 else((x+.055)/1.055)^2.4 end
				local function value(c)return .2126*lin(c.R)+.7152*lin(c.G)+.0722*lin(c.B)end -- relative luminance
				assert(value(look.beak)>=value(look.head)*1.35,"the beak at least 35% brighter than the head")
				for _,side in ipairs({"LegR","LegL"})do
					local leg=folder:FindFirstChild(name..side)
					assert(leg.Size==Vector3.new(.03,.16,.03)and leg.Color==look.beak,"legs in the beak's colour")
				end
				for _,side in ipairs({"WingL","WingR"})do
					local plate=folder:FindFirstChild(name..side)
					assert(plate.Size==Vector3.new(.03,.48,.22)and plate.Transparency==1,"a see-through plate (FABLE-REVIEW-R4 1)")
					for _,d in pairs(faces(plate,{[Face.Left]=LifeArt.id(look.wing),[Face.Right]=LifeArt.id(look.wing)}))do assert(isWhite(d.Color3))end
				end
				wingsLoaded[look.wing]=true
				local tail=folder:FindFirstChild(name.."Tail")
				assert(tail.ClassName=="WedgePart"and tail.Size==Vector3.new(.26,.10,.44)and tail.Transparency==0 and tail.Color==look.tail,"a solid tail wedge")
				for _,d in pairs(faces(tail,{[Face.Bottom]=LifeArt.id("birdTail")}))do assert(d.Color3==look.tail)end
			end
			assert(wingsLoaded.birdWingEmber and wingsLoaded.birdWingSlate and wingsLoaded.birdWingMoss,"all three bird wings written at build")
			for slot=1,4 do
				local name="LifeButterfly"..slot.."_"
				local n=0
				for _,p in ipairs(r.parts())do if string.sub(p.Name,1,#name)==name then n+=1 end end
				assert(n==3,"butterfly parts "..n)
				local bodyPart=folder:FindFirstChild(name.."Body")
				assert(bodyPart.Size==Vector3.new(.04,.035,.18)and bodyPart.Color==Life.ButterflyBody and bodyPart.Reflectance==0)
				assert(bodyPart:FindFirstChild("Spindle")and bodyPart.Spindle.ClassName=="SpecialMesh","a spindle, still 3 parts")
				local left,right=folder:FindFirstChild(name.."WingL"),folder:FindFirstChild(name.."WingR")
				for _,plate in ipairs({left,right})do assert(plate.Size==Vector3.new(.24,.29,.02)and plate.Transparency==1)end
				local file,mirror=LifeArt.id(Life.ButterflyArt[slot][1]),LifeArt.id(Life.ButterflyArt[slot][2])
				for _,d in pairs(faces(left,{[Face.Back]=mirror,[Face.Front]=file}))do assert(isWhite(d.Color3),"full colour")end
				faces(right,{[Face.Back]=file,[Face.Front]=mirror})
				local gui=bodyPart:FindFirstChild("Glow")
				assert(gui and gui.ClassName=="BillboardGui"and gui.Enabled==false and gui.LightInfluence==0 and gui.Brightness==2)
				assert(gui.MaxDistance==110 and gui.AlwaysOnTop==false and bodyPart:FindFirstChildOfClass("PointLight")==nil)
				local dot=gui:FindFirstChild("Dot")
				local want=Color3.fromHex("#E8FF8A")
				assert(dot.Image==LifeArt.id("fireflyDot")and math.abs(dot.ImageColor3.G-want.G)<1e-6 and math.abs(dot.ImageColor3.B-want.B)<1e-6)
			end
			-- A landing paints that perch's colourway: colours, tints, the wing file (perch 2: Moss on slot 1's Ember plates).
			r.step(.1)
			assert(r.life:chirp(2)=="land")
			local bird=r.life.birds:find(2)
			local look=Life.BirdLooks[2%3]
			local pool=r.life.birdPool[bird.slot]
			assert(pool[1].Color==look.body and pool[2].Color==look.head and pool[3].Color==look.beak)
			for _,plate in ipairs({pool[6],pool[7]})do for _,d in pairs(decals(plate))do assert(d.Texture==LifeArt.id(look.wing))end end
			for _,d in pairs(decals(pool[8]))do assert(d.Color3==look.tail)end
		end)

		test("a perched bird that is not moving is not written again",function()
			local r=rig()
			r.reduced=true -- just there, still
			r.step(.1)
			assert(r.life:chirp(2)=="land")
			local writes=0
			local saved=r.life.move
			r.life.move=function(parts,frames)
				for _,p in ipairs(parts)do if string.match(p.Name,"^LifeBird")then writes+=1 end end
				return saved(parts,frames)
			end
			r.step(.1)
			local first=writes
			r.step(3)
			assert(first>0 and writes==first,"one write, then none: "..first.." / "..writes)
		end)

		test("dusk: each butterfly hands off to a glow (at most 4), wings fading; a park or Reduced Motion turns every glow off at once",function()
			local function glowing(r)
				local n=0
				for slot=1,4 do if r.folder():FindFirstChild("LifeButterfly"..slot.."_Body").Glow.Enabled then n+=1 end end
				return n
			end
			for _,ending in ipairs({"park","reduced","none"})do
				local r=rig({daylight=.9})
				r.step(8)
				local out=r.life:counts().butterflies
				assert(out>=2,"out by day: "..out)
				assert(glowing(r)==0,"no glow by day")
				r.daylight=.28
				r.step(2.6) -- the poll reads it; the first hand-off is under way
				local most=0
				for _=1,10 do
					r.step(.3)
					most=math.max(most,glowing(r))
					assert(r.life:counts().glows==glowing(r))
					if ending~="none"and glowing(r)>0 then break end
				end
				assert(most>=1 and most<=4,"glows: "..most)
				if ending=="park"then
					r.mode="Board";r.step(.3)
					assert(glowing(r)==0 and r.life:counts().butterflies==0,"parked: every glow off")
				elseif ending=="reduced"then
					r.reduced=true;r.step(.1)
					assert(glowing(r)==0 and r.life:counts().butterflies==0,"Reduced Motion: every glow off")
				else
					r.step(12)
					assert(glowing(r)==0 and r.life:counts().butterflies==0,"all handed off and gone")
					-- The wing decals faded with them: the last slot written shows transparent wings.
				end
			end
			-- Decal writes at 10 Hz, only on change: a new butterfly's wings fade in from 1.
			local r=rig()
			r.step(.2)
			local entry
			for _,e in ipairs(r.life.flyPool)do if e.owner then entry=e end end
			assert(entry and entry.wing>0,"a new one starts faded: "..tostring(entry and entry.wing))
			r.step(1.5)
			assert(entry.wing==0 and entry.decals[1].Transparency==0,"faded in")
		end)

		test("bubbles: two emitters, one fixed Size each (never written again), the roll picks which one emits",function()
			local r=rig()
			local small=r.folder():FindFirstChild("LifeBubblesSmall")
			local large=r.folder():FindFirstChild("LifeBubblesLarge")
			assert(small and large and small.Transparency==1 and large.Transparency==1)
			local es,el=small:FindFirstChild("BubblesSmall"),large:FindFirstChild("BubblesLarge")
			assert(es and el and es.Rate==0 and el.Rate==0)
			assert(Sim.BubbleSizes.small==.62 and Sim.BubbleSizes.large==.95 and Sim.BubbleSmall==.6)
			local sizes,fades={es.Size,el.Size},{es.Transparency,el.Transparency}
			r.step(90)
			assert(rawequal(es.Size,sizes[1])and rawequal(el.Size,sizes[2]),"Size set once")
			assert(rawequal(es.Transparency,fades[1])and rawequal(el.Transparency,fades[2]),"Transparency set once")
			local a,b=es.emitted or 0,el.emitted or 0
			assert(a>0 and b>0,"both used: "..a.." / "..b)
			assert(a+b>=25 and a+b<=30,"one every 3 s: "..(a+b))
			assert(r.life:counts().bubbles<=Sim.cap("bubbles",0))
		end)

		test("leaves (beta 14 Q5): the sheet, the petal and the scud, anchors moved to each leaf's spot round the player, under the caps at both levels",function()
			local LifeArtR4=require(game:GetService("ReplicatedStorage").Shared.LifeArtR4)
			local r=rig()
			-- FABLE-REVIEW-R4 2: the keys allow for the 1.5 to 1.65 draw factor (drawn long side .25 or less with the envelope).
			assert(Life.LeafDrawn==nil and Life.Leaves[1].size[2]==.135 and Life.Leaves[2].size[2]==.12 and Life.Leaves[3].size[2]==.135)
			local names={"LifeLeafSheet","LifeLeafPetal"}
			local emitters={}
			for i,name in ipairs(names)do
				local anchor=r.folder():FindFirstChild(name)
				assert(anchor and anchor.Transparency==1 and anchor.Size==Life.LeafAnchor,name)
				local e=anchor:FindFirstChild("Leaves")
				assert(e.Rate==0 and e.LockedToPart==false and e.Drag==.5 and e.LightInfluence==1 and e.LightEmission==0,name)
				assert(e.EmissionDirection==Enum.NormalId.Bottom and e.ShapeStyle==Enum.ParticleEmitterShapeStyle.Volume,name)
				emitters[i]=e
			end
			assert(emitters[1].Texture==LifeArtR4.id("leafSheet")and emitters[2].Texture==Life.PetalTexture)
			-- The sheet's grid waits for its own upload (the stand-in is one leaf on the whole image).
			assert((emitters[1].FlipbookLayout~=nil)==LifeArtR4.uploaded("leafSheet"),"the grid only once uploaded")
			-- The scud: its own small anchor, along the wind, flat, no fall.
			local scudAnchor=r.folder():FindFirstChild("LifeLeafSkitter")
			local scud=scudAnchor:FindFirstChild("Leaves")
			assert(scudAnchor.Size==Life.SkitterAnchor and scud.EmissionDirection==Enum.NormalId.Front and scud.Drag==1.2)
			assert(scud.Acceleration==Vector3.zero and scud.Texture==LifeArtR4.id("leafSheet"))
			local most,shown=0,{}
			for _=1,60 do
				r.step(1)
				most=math.max(most,r.life:counts().leaves)
				for _,name in ipairs(names)do
					local anchor=r.folder():FindFirstChild(name)
					if not hidden(anchor)then
						shown[name]=true
						local at=anchor.CFrame.Position
						assert(math.abs(at.X-r.player.X)<=36 and math.abs(at.Z-r.player.Z)<=36 and at.Y>=14-1e-6 and at.Y<=16+1e-6,name..": "..tostring(at))
					end
				end
				if not hidden(scudAnchor)then
					local at=scudAnchor.CFrame.Position
					assert(math.abs(at.Y-4.12)<1e-6,"the scud starts on the ground: "..tostring(at))
					assert(scudAnchor.CFrame.LookVector:Dot(Wind.Direction)>.99,"facing downwind")
				end
			end
			assert(most>=30 and most<=Sim.cap("leaves",0),"level 0: "..most)
			assert(shown.LifeLeafSheet and shown.LifeLeafPetal,"both kinds fall")
			local emitted=0
			for _,e in ipairs(emitters)do emitted+=(e.emitted or 0)end
			assert(emitted>=200 and emitted<=420,"about 4 a second x (1 + 1.5 g), held by the 44 cap: "..emitted)
			assert((scud.emitted or 0)>0 and(scud.emitted or 0)<=60*6*.35,"the scud only near a gust's top: "..tostring(scud.emitted))
			assert(r.life.skitter:count(r.now)<=Sim.cap("skitter",0))
			r.life.leaves:clear();r.level=1
			most=0
			for _=1,40 do r.step(1);most=math.max(most,r.life:counts().leaves)end
			assert(most>=12 and most<=22,"level 1: "..most)
			assert(r.life:counts().petals==r.life:counts().leaves,"petals: the old name")
		end)

		test("leaves: the breath (scene on) triples the rate and runs the scud; scene off, the breath is nothing; the fall's wind is the gust alone",function()
			local base=math.floor(T0/Wind.BreathSlot)
			local function breathAt(r)
				-- The first moment the breath is held at the player.
				return Wind.breathStart(base+1)+r.player:Dot(Wind.Direction)/Wind.Speed+Wind.BreathRise
			end
			local on=rig({now=T0});on.scene=true
			local off=rig({now=T0})
			local t=breathAt(on)
			on.now,off.now=t-.5,t-.5
			on.step(2.2);off.step(2.2) -- a poll reads the switch
			local a0,b0=on.folder():FindFirstChild("LifeLeafSheet").Leaves.emitted or 0,off.folder():FindFirstChild("LifeLeafSheet").Leaves.emitted or 0
			local s0,z0=on.folder():FindFirstChild("LifeLeafSkitter").Leaves.emitted or 0,off.folder():FindFirstChild("LifeLeafSkitter").Leaves.emitted or 0
			on.life.leaves:clear();off.life.leaves:clear()
			on.step(2);off.step(2)
			local a=(on.folder():FindFirstChild("LifeLeafSheet").Leaves.emitted or 0)-a0
			local b=(off.folder():FindFirstChild("LifeLeafSheet").Leaves.emitted or 0)-b0
			local s=(on.folder():FindFirstChild("LifeLeafSkitter").Leaves.emitted or 0)-s0
			local z=(off.folder():FindFirstChild("LifeLeafSkitter").Leaves.emitted or 0)-z0
			assert(on.life.scene==true and off.life.scene==false)
			assert(a>=2*b and a>=15,"x 3 in the breath: "..a.." vs "..b)
			assert(s>=5 and z<=s/2 and on.life.skitter:count(on.now)<=Sim.cap("skitter",0),"the scud runs in the breath (held by its 14 cap): "..s.." vs "..z)
			-- The fall's Acceleration is the gust's, scene or not.
			local accel=on.folder():FindFirstChild("LifeLeafSheet").Leaves.Acceleration
			local g=Wind.gust(on.player,on.now)
			assert((accel-Sim.leafWind(g,on.now)).Magnitude<.6,"the gust's wind, never the breath's")
		end)

		test("leaves: none where the drift reaches a roof, none off the island, none until the cover is checked (beta), the wind at 4 Hz",function()
			local roofed=rig({cover={{name="Everywhere",x=0,z=0,r=500}}})
			roofed.step(30)
			assert(roofed.life:counts().leaves==0,"all under a roof: none")
			local sky=rig({leafGround=function()return nil end})
			sky.step(30)
			assert(sky.life:counts().leaves==0,"off the island: none")
			local beta=rig({leaves=false})
			beta.step(30)
			assert(beta.life:counts().leaves==0,"the gate closed: none")
			for _,name in ipairs({"LifeLeafSheet","LifeLeafPetal","LifeLeafSkitter"})do assert((beta.folder():FindFirstChild(name).Leaves.emitted or 0)==0)end
			-- The Acceleration: written 4 times a second, the same on the sheet and the petal; the scud's stays zero.
			local r=rig()
			local e=r.folder():FindFirstChild("LifeLeafSheet").Leaves
			local writes,last=0,e.Acceleration
			for _=1,60 do
				r.step(1/30)
				if not rawequal(e.Acceleration,last)then writes+=1;last=e.Acceleration end
			end
			assert(writes>=7 and writes<=9,"4 Hz over 2 s: "..writes)
			assert(rawequal(r.folder():FindFirstChild("LifeLeafPetal").Leaves.Acceleration,last))
			assert(r.folder():FindFirstChild("LifeLeafSkitter").Leaves.Acceleration==Vector3.zero)
			-- Lime crowns tint the petal leaves lime; pink crowns pink.
			r.step(2.1)
			assert(r.life.colour==Life.PetalColours.lime)
			r.crownColour="pink";r.step(2.1)
			assert(r.life.colour==Life.PetalColours.pink)
			assert(r.folder():FindFirstChild("LifeLeafPetal").Leaves.Color~=nil)
		end)
		-- Dewdrops (WORLD-PASS item 3; FRUIT-LOOK) -------------------------------------------------------------------
		local function dewdrops(r)
			local out={}
			for slot=1,Sim.Fruit.pool do table.insert(out,r.folder():FindFirstChild("LifeDewdrop"..slot))end
			return out
		end
		local function shownFruit(r)
			local out={}
			for _,p in ipairs(dewdrops(r))do if not hidden(p)then table.insert(out,p)end end
			return out
		end
		-- Steps a second at a time until a Dewdrop is loose (nil after `most` seconds).
		local function untilLoose(r,most)
			for _=1,most or 400 do
				r.step(1)
				if r.life:counts().loose>0 then return r.life.loose.list[1]end
			end
			return nil
		end

		test("Dewdrops: 16 billboards made once (the uploaded texture, FRUIT-LOOK sizes), inert anchors",function()
			local r=rig()
			assert(Life.DewdropTexture=="rbxassetid://82054526707528")
			local list=dewdrops(r)
			assert(#list==16)
			for _,anchor in ipairs(list)do
				assert(anchor.Size==Vector3.new(.2,.2,.2)and anchor.Transparency==1 and hidden(anchor))
				local gui=anchor:FindFirstChild("Dewdrop")
				assert(gui and gui.ClassName=="BillboardGui"and gui.MaxDistance==110 and gui.LightInfluence==.6 and gui.Brightness==1)
				assert(gui.AlwaysOnTop==false and gui.ClipsDescendants==false)
				local label=gui:FindFirstChild("Image")
				assert(label and label.ClassName=="ImageLabel"and label.Image==Life.DewdropTexture and label.BackgroundTransparency==1)
			end
			r.step(60)
			assert(#dewdrops(r)==16 and #r.parts()==3*10+4*3+3+2+16+8,"never made or destroyed in play")
		end)

		test("Dewdrops: hanging under the lime crowns in reach, nearest first: 16 at level 0, 8 still ones at 1, none pink",function()
			local crowns={}
			for i=1,9 do table.insert(crowns,{position=Vector3.new(-40+i*8,12,-30-i),size=Vector3.new(9,5.5,9)})end
			table.insert(crowns,{position=Vector3.new(0,12,-200),size=Vector3.new(9,5.5,9)}) -- out of reach
			local spots={Perches=0,Landings={},Crowns=crowns}
			local total=0
			for i=1,9 do total+=#Sim.fruitStems(i,crowns[i])end
			assert(total>16,"enough fruit to hit the cap: "..total)
			local r=rig({spots=spots})
			r.step(.2)
			assert(r.life:counts().fruit==16 and #shownFruit(r)==16,"the cap: "..r.life:counts().fruit)
			local stems={}
			for i,crown in ipairs(crowns)do for _,slot in ipairs(Sim.fruitStems(i,crown))do stems[slot.key]={slot=slot,i=i}end end
			for _,p in ipairs(shownFruit(r))do
				local best=math.huge
				for _,entry in pairs(stems)do best=math.min(best,(p.CFrame.Position-entry.slot.stem).Magnitude)end
				assert(best<Sim.Fruit.hang+1e-3,"under a stem: "..best)
			end
			for key in pairs(r.life.fruitOf)do if key>0 then assert(stems[key].i<10,"not the far crown")end end
			r.level=1
			r.step(.2)
			assert(r.life:counts().fruit==8,"level 1: 8")
			local before={}
			for _,p in ipairs(shownFruit(r))do before[p]={p.CFrame.Position,p.Dewdrop.Image.Rotation}end
			r.step(1)
			for p,was in pairs(before)do
				assert(p.CFrame.Position==was[1]and p.Dewdrop.Image.Rotation==was[2]and was[2]==0,"level 1: no sway")
			end
			r.crownColour="pink"
			r.step(2.1)
			assert(r.life:counts().fruit==0 and #shownFruit(r)==0,"pink crowns: no fruit")
			assert(next(r.life.fruitOf)==nil and #r.life.loose.list==0,"nothing assigned")
			local entry=r.life.fruitPool[1]
			entry.anchor.CFrame=CFrame.new(1,2,3)
			r.step(.5)
			assert(entry.anchor.CFrame.Position==Vector3.new(1,2,3),"pink: the pool is not walked")
			entry.anchor.CFrame=Life.Hidden
		end)

		test("Dewdrops follow their crown's sway at level 0 (a kit part matched by pivot); static at level 1 or with no match",function()
			local pivot=Vector3.new(0,10,-25)
			local crown={position=Vector3.new(0,12,-25),size=Vector3.new(8,5,8),pivot=pivot}
			local rest=CFrame.new(crown.position)
			local p=Instance.new("Part")
			p.CFrame=rest
			p:SetAttribute("WorldPivot",pivot+Vector3.new(.03,0,0))
			p:SetAttribute("WorldRestCFrame",rest)
			p.Parent=workspace -- a live part (a removed one is not followed)
			local r=rig({groveCrowns={crown},kitParts=function()return{p}end})
			r.step(.2)
			assert(r.life.follow[1]and r.life.follow[1].part==p,"matched within .05")
			local before={}
			for _,a in ipairs(shownFruit(r))do before[a]=a.CFrame.Position end
			assert(next(before),"fruit hangs")
			-- The crown leans: the hanging fruit moves with it.
			p.CFrame=CFrame.new(pivot)*CFrame.Angles(0,0,math.rad(4))*CFrame.new(-pivot)*rest
			r.step(1/30)
			local moved=0
			for a,was in pairs(before)do if(a.CFrame.Position-was).Magnitude>.05 then moved+=1 end end
			assert(moved>0,"moved with the crown")
			-- No match (a part elsewhere): static stems.
			local q=Instance.new("Part")
			q.CFrame=rest;q:SetAttribute("WorldPivot",pivot+Vector3.new(.2,0,0));q:SetAttribute("WorldRestCFrame",rest)
			local s=rig({groveCrowns={crown},kitParts=function()return{q}end})
			s.step(.2)
			assert(s.life.follow[1]==nil,"no match: static")
			p:Destroy()
		end)

		test("Dewdrops: the default crowns are the kit's lime crowns; none in the kit falls back to LifeSpots with one warning",function()
			local Spots=require(client.LifeSpots)
			local warned={}
			local fake={d={},spots=Spots,warn=function(text)table.insert(warned,text)end}
			local crowns=Life.readCrowns(fake)
			assert(#crowns>=6 and crowns[1].cframe~=nil and #warned==0,"the kit's: "..#crowns)
			local kinds=Life.KitKinds
			Life.KitKinds={none=true}
			Life.crownWarned=nil
			local ok,problem=pcall(function()
				local back=Life.readCrowns(fake)
				assert(back==Spots.Crowns and #warned==1,"LifeSpots, one warning")
				Life.readCrowns(fake)
				assert(#warned==1,"only once")
			end)
			Life.KitKinds=kinds
			Life.crownWarned=nil
			assert(ok,problem)
		end)

		test("Dewdrops: every client simulates the same drops: cameras far apart, budget levels 0 and 1, Reduced Motion",function()
			local near=rig()
			local far=rig()
			far.camera=CFrame.lookAt(Vector3.new(0,10,400),Vector3.new(0,8,420)) -- no crown in reach, looking away
			local slow=rig({level=1})
			slow.camera=CFrame.lookAt(Vector3.new(12,10,6),Vector3.new(10,8,-12))
			local still=rig()
			still.reduced=true
			local clients={near,far,slow,still}
			local seen={{},{},{},{}}
			local drawn,most={},0
			for _=1,300 do
				for c,r in ipairs(clients)do
					r.step(1)
					local grove=r.life.grove
					for i=1,#grove.crowns do
						for _,drop in ipairs(grove.drops[i])do if drop.start<=r.now then seen[c][drop.id]=drop end end
					end
				end
				for _,loose in ipairs(near.life.loose.list)do drawn[loose.id]=loose end
				most=math.max(most,near.life:counts().loose)
				assert(far.life:counts().loose==0 and far.life:counts().fruit==0,"far away: nothing drawn")
				assert(still.life:counts().loose==0,"Reduced Motion: nothing drawn falling")
			end
			local n=0
			for id,drop in pairs(seen[1])do
				n+=1
				for c=2,4 do assert(seen[c][id]and seen[c][id].start==drop.start and seen[c][id].p4==drop.p4,"client "..c.." has "..id)end
				assert(Wind.hash(drop.n*16+drop.i,13)<Sim.Fruit.chance)
				assert(math.abs(drop.p4.Y-4.5)<1e-6,"rests .5 over the lawn")
			end
			for c=2,4 do for id in pairs(seen[c])do assert(seen[1][id],"client "..c.." has nothing extra: "..id)end end
			assert(n>=2,"drops in 5 minutes: "..n)
			local d=0
			for id in pairs(drawn)do d+=1;assert(seen[1][id],"drawn only what the grove dropped")end
			assert(d>=1,"and the near one drew them")
			assert(most<=Sim.cap("loose",0))
			assert(near.life:counts().fruit+near.life:counts().loose<=16)
		end)

		test("Dewdrops, Reduced Motion: loose ones gone at once, the rest hang upright and still, none fall",function()
			local r=rig()
			assert(untilLoose(r),"a drop")
			r.reduced=true
			r.step(.1)
			local c=r.life:counts()
			assert(c.loose==0,"gone at once")
			local list=shownFruit(r)
			assert(#list==c.fruit and c.fruit==#Sim.fruitStems(1,SPOTS.Crowns[1])+#Sim.fruitStems(2,SPOTS.Crowns[2]),"every slot just filled")
			local at={}
			for _,p in ipairs(list)do at[p]=p.CFrame.Position;assert(p.Dewdrop.Image.Rotation==0,"upright")end
			for _=1,120 do r.step(1);assert(r.life:counts().loose==0,"none fall")end
			for p,was in pairs(at)do assert(p.CFrame.Position==was,"still")end
		end)

		test("Dewdrops: parked hides every one and forgets the loose; off clears; a live race fades the loose in .3 s, drops none",function()
			local r=rig()
			assert(untilLoose(r))
			r.hatch=true
			r.step(.4)
			assert(#shownFruit(r)==0 and r.life:counts().loose==0 and r.life:counts().fruit==0,"parked")
			r.hatch=false
			r.step(.5)
			assert(r.life:counts().fruit>0,"back on the trees")
			r.flip(false)
			assert(r.folder()==nil and r.life:counts().fruit==0 and r.life:counts().loose==0,"off: nothing")
			local q=rig()
			assert(untilLoose(q))
			q.phase="live"
			q.step(2.5)
			assert(q.life:counts().loose==0,"a live race: faded")
			assert(q.life.live==true)
			for _=1,90 do q.step(1);assert(q.life:counts().loose==0,"no drops in a race")end
		end)

		test("Dewdrops, landing rejection: a kerb, a find spot or the course over the lawn: nothing falls, all stay up",function()
			for _,options in ipairs({{kerbs={{x=0,z=0,rx=500,rz=500}}},{safe=function()return false end}})do
				local r=rig(options)
				for _=1,240 do r.step(1);assert(r.life:counts().loose==0,"skipped")end
				for i=1,#r.life.grove.crowns do assert(#r.life.grove.drops[i]==0,"the fruit stayed on the tree")end
				assert(r.life:counts().fruit>0)
			end
			-- A find spot right where a fruit would rest, and the course through it (idle): that drop is skipped.
			local probe=rig()
			local plan=assert(untilLoose(probe))
			for _,options in ipairs({{finds={plan.p4}},{course={plan.p4.X-5,plan.p4.Z,plan.p4.X+5,plan.p4.Z}}})do
				local r=rig(options)
				local seen=false
				for _=1,math.ceil(plan.start-T0)+2 do
					r.step(1)
					for _,other in ipairs(r.life.loose.list)do
						if other.key==plan.key and other.n==plan.n then seen=true end
						assert(Sim.fruitClear(other.p4,{finds=options.finds,course=options.course}),"no loose fruit rests in the way")
					end
				end
				assert(not seen,"that drop was skipped")
			end
		end)

		test("Dewdrops: a pet within 3 studs of a resting one bats it once, 1 stud away; a pet farther off does nothing",function()
			local r=rig()
			local plan=assert(untilLoose(r))
			local rest=plan.p4
			r.pets={rest+Vector3.new(4,0,0)}
			r.step(math.max(0,plan.t5-r.now)+2.2)
			assert(not plan.bat,"4 studs: nothing")
			r.pets={rest+Vector3.new(0,0,2)}
			r.step(2.2)
			assert(plan.bat and not plan.bat.straight,"batted")
			assert(math.abs(Sim.flat(plan.rest,rest)-1)<1e-6 and(plan.rest-rest):Dot(Vector3.new(0,0,-1))>.99,"straight away from the pet")
			r.step(1)
			local p
			for _,anchor in ipairs(shownFruit(r))do if(anchor.CFrame.Position-plan.rest).Magnitude<1e-3 then p=anchor end end
			assert(p,"the billboard rests where it landed")
			local bat=plan.bat
			r.pets={plan.rest}
			r.step(2.2)
			assert(plan.bat==bat,"once in its life")
		end)

		-- Beta 14 QA B2: night fireflies (GARDEN-LIFE-BUILD-PLAN section 3).
		test("night fireflies: the cap's glows lit by the hour's night (8, 4 at level 1), none by day; parked and Reduced Motion off at once",function()
			local function lit(r)
				local n=0
				for slot=1,Sim.Caps.fireflies[1]do
					local anchor=r.folder():FindFirstChild("LifeFirefly"..slot)
					local gui=anchor and anchor:FindFirstChild("Glow")
					if gui and gui.Enabled and not hidden(anchor)then n+=1 end
				end
				return n
			end
			local day,night,slow=rig({daylight=.9}),rig({daylight=.12}),rig({daylight=.12,level=1})
			for _=1,15 do day.step(1);night.step(1);slow.step(1)end
			assert(lit(day)==0 and day.life:counts().fireflies==0,"none by day")
			assert(lit(night)==8 and night.life:counts().fireflies==8,"8 at night: "..lit(night))
			assert(lit(slow)==4,"4 at level 1: "..lit(slow))
			night.hatch=true;night.step(.5)
			assert(lit(night)==0 and #night.life.fireflies.list==0,"parked: gone")
			night.hatch=false;night.reduced=true;night.step(2)
			assert(lit(night)==0,"Reduced Motion: none")
			night.reduced=false;night.daylight=.9;night.step(12)
			assert(lit(night)==0,"day again: none")
		end)
		test("the budget level is reported once per change (AliveLevel), including the step down to 2",function()
			local seen={}
			local r=rig({report=function(level)table.insert(seen,level)end})
			r.step(1);r.step(1)
			assert(#seen==1 and seen[1]==0,"once at the start")
			r.level=1;r.step(1);r.step(1)
			assert(#seen==2 and seen[2]==1,"once at 1")
			r.level=2;r.step(.2)
			assert(#seen==3 and seen[3]==2 and r.folder()==nil,"reported, then torn down")
		end)
	end)
	for _,r in ipairs(rigs)do
		if r.life then pcall(function()r.life:destroy()end)end
		r.world:Destroy()
	end
	assert(ok,problem)
	for _,r in ipairs(rigs)do assert(#r.warned==0,"stopped: "..tostring(r.warned[1]))end
	return{passed=#cases,cases=cases}
end
