-- Studio Client. Garden life, the parts (GardenLife, ALIVE-LIFE-BUILD-PLAN-2026-11-22) with a fake switch, clock, camera,
-- Heartbeat and world: nil with the ceiling off; the switch off is nothing but its signal; on is one folder of inert
-- parts and one Heartbeat; off mid-flight destroys it all in that frame; parked (hatch, board, my race) hides
-- everything and simulates nothing; Reduced Motion; budget level 2 shows nothing; a chirp lands a bird on that perch's
-- crown and the 4th is refused; bubbles refuse a station, a live course and a menu.
-- Usage: require(PlayerScripts.Client.ZZSpecs.GardenLife)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py (DASH_SPECS="GardenLife").
return function(client)
	local Life=require(client.GardenLife)
	local Sim=require(client.LifeSim)
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
		local r={on=options.on~=false,ceiling=options.ceiling~=false,now=T0,level=options.level or 0,hatch=false,mode="Room",
			held=false,phase="idle",menu=false,reduced=false,moves=0,warned={},ambient={}}
		r.changed=signal();r.beat=signal()
		r.camera=CFrame.lookAt(Vector3.new(0,10,10),Vector3.new(0,8,-10))
		r.player=Vector3.new(0,5,8)
		r.world=Instance.new("Folder");r.world.Name="_GardenLifeSpec";r.world.Parent=workspace
		r.dash={held=function()return r.held end,summary=function()return{phase=r.phase}end}
		r.life=Life.mount({ambient=r.ambient,world=r.world,heartbeat=r.beat,seed=7,
			alive={ceiling=function(f)return f=="life"and r.ceiling end,on=function(f)return f=="life"and r.on end,changed=function()return r.changed end},
			now=function()return r.now end,camera=function()return r.camera end,root=function()return r.player end,
			level=function()return r.level end,hatching=function()return r.hatch end,mode=function()return r.mode end,
			dash=function()return r.dash end,modalOpen=function()return r.menu end,reduced=function()return r.reduced end,
			move=function(parts,frames)r.moves+=1;for i,p in ipairs(parts)do p.CFrame=frames[i]end end,
			spots=SPOTS,patches=options.patches or {Vector3.new(4,4,-14),Vector3.new(-6,4,-18),Vector3.new(10,4,-10)},
			stations=options.stations or {Vector3.new(200,4,200)},pad=options.pad or {x=300,z=300,r=3},course=options.course or {400,400,500,400},
			crowns=function()return "lime"end,warn=function(text)table.insert(r.warned,text)end})
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
			assert(#parts==3*5+4*3+3+1,"parts "..#parts)
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
				if not hidden(b)and(b.CFrame.Position-(LANDING+Vector3.new(0,.56,0))).Magnitude<.01 then sitting=b end
			end
			assert(sitting,"a bird sits .56 over perch 2's landing")
			assert(sitting.Color==Life.BirdColours[2%3].body,"perch 2's colourway")
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
			assert(b and(b.CFrame.Position-(LANDING+Vector3.new(0,.56,0))).Magnitude<1e-3,"sits at once")
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

		test("petals follow the wind under the cap, from lime-tinted emitters at the picked crowns",function()
			local r=rig()
			local most=0
			for _=1,60 do r.step(1);most=math.max(most,r.life:counts().petals)end
			assert(most>0,"a gust drops petals")
			assert(most<=Sim.cap("petals",0))
			local shown=0
			for slot=1,3 do
				local anchor=r.folder():FindFirstChild("LifePetals"..slot)
				if not hidden(anchor)then shown+=1;assert(anchor.Transparency==1)end
			end
			assert(shown==2,"one emitter per crown in reach: "..shown)
			assert(r.life.colours==Life.PetalColours.lime,"lime crowns, lime petals")
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
