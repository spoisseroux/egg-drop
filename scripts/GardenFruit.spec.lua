-- The garden fruit's Heart XP (GARDEN-PLAY-BRIEF-2 section 5; Spencer, beta 35 note 8): the shared rules (GardenFruit),
-- the daily cap on the save (FruitState), the save transaction (Hatching.fruitClaim) and the server's checks (FruitHost)
-- with fake boards, a fake garden and a fake clock. Isolated adapters only; no DataStore or user writes.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.GardenFruit)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Fruit=require(Shared.GardenFruit)
	local Wind=require(Shared.Wind)
	local Alive=require(Shared.Alive)
	local Flags=require(Shared.FeatureFlags)
	local Eggs=require(Shared.EggCatalog)
	local Daily=require(Shared.DailyContracts)
	local C=require(Shared.StatCatalog)
	local S=require(server.FruitState)
	local Stat=require(server.StatState)
	local Host=require(server.FruitHost)
	local H=require(server.HatchProgress)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local DAY="19680"
	local PET="pip"
	local function owned()return{inventoryMask=Eggs.bit(PET)}end
	local function heart(state)return Stat.xp(state,PET,"heart")end
	local function claim(state,id,day,pet)return S.apply(state,{id=id,petId=pet or PET,day=day or DAY},day or DAY)end
	local function copy(v)if type(v)~="table"then return v end;local r={};for k,x in pairs(v)do r[k]=copy(x)end;return r end

	-- A time when tree i let a fruit go within the window, and one when it did not (the shared wind decides).
	local function times(i,centre)
		local yes,no
		local t=1795300000
		for _=1,4000 do
			t+=7
			local dropped=Fruit.dropped(i,centre,t,Fruit.Window,false)
			if dropped and not yes then yes=t elseif not dropped and not no then no=t end
			if yes and no then break end
		end
		return yes,no
	end

	test("the rules: +2 Heart XP a fruit, one a minute, twelve a day; the switch AliveFruit (beta and Studio, never live)",function()
		assert(Fruit.Stat=="heart"and Fruit.XP==2 and Fruit.Gap==60 and Fruit.DailyLimit==12 and S.DailyLimit==12)
		assert(C.ById[Fruit.Stat]~=nil)
		assert(table.find(Alive.Features,Fruit.Feature)and Flags.AliveFruit==true)
		assert(Alive.ceiling("fruit",{AliveFruit=true},Alive.PlaceId,false)==true)
		assert(Alive.ceiling("fruit",{AliveFruit=true},96451847774961,false)==false,"never on live")
		local B=Fruit.Bites
		assert(B.count==5 and B.time==3.2 and #B.scales==6 and B.scales[1]==1 and B.scales[6]==0)
		local last=2
		for k=0,6 do
			local scale,n=Fruit.bite(k*B.time/B.count+.01)
			assert(n==math.min(k,5)and scale==B.scales[math.min(k,5)+1]and scale<last,k)
			last=scale+1e-9
		end
		assert(Fruit.bite(-1)==1 and select(2,Fruit.bite(0))==0)
	end)

	test("the trees: the kit's lime crowns, sorted by tree name; trunks under their pivots; the wind says when one dropped",function()
		local trees=Fruit.trees()
		local Kit=require(Shared.WorldAeroKit)
		local blossom=0
		for _,crown in ipairs(Kit.crowns)do if Kit.meshes[crown.mesh].kind=="foliage_blossom"then blossom+=1 end end
		assert(#trees==blossom and #trees>=8,"trees "..#trees)
		for i,tree in ipairs(trees)do
			assert(tree.i==i and(i==1 or trees[i-1].tree<tree.tree))
			assert(tree.trunk>0 and tree.trunk<2 and typeof(tree.centre)=="Vector3")
			assert(math.abs(tree.centre.X-tree.x)<3 and math.abs(tree.centre.Z-tree.z)<3,"the crown over its trunk")
		end
		local yes,no=times(1,trees[1].centre)
		assert(yes and no,"a window with a drop and one without")
		-- The same rule as the grove's candidate: the seeded chance and the trigger.
		local found=false
		local centre=trees[1].centre
		local offset=centre:Dot(Wind.Direction)/Wind.Speed
		for n=math.floor((yes-Fruit.Window-offset-Wind.Rise-Wind.Jitter)/Wind.Slot),math.ceil((yes-offset+Wind.Jitter)/Wind.Slot)do
			local t=Fruit.trigger(centre,n)
			if t and t<=yes and t>=yes-Fruit.Window and Wind.hash(n*16+1,13)<Fruit.Chance then found=true end
		end
		assert(found)
		assert(not Fruit.dropped(1,centre,0/0)and not Fruit.dropped(nil,centre,yes))
		assert(Fruit.nearTree(trees[1],trees[1].x+Fruit.Reach-.1,trees[1].z)and not Fruit.nearTree(trees[1],trees[1].x+Fruit.Reach+.1,trees[1].z))
		assert(Fruit.shakes(trees[1],trees[1].x+trees[1].trunk+1,trees[1].z,5)and not Fruit.shakes(trees[1],trees[1].x+trees[1].trunk+1,trees[1].z,2),
			"walking into it, not standing by it")
	end)

	test("the save: 2 Heart XP with no Bonus XP and no boosts, the count, the proof; twelve a day; the next day pays again",function()
		local state=owned()
		Stat.queueBoost(state,PET,"heart",2,50)
		assert(claim(state,"a"))
		assert(heart(state)==Fruit.XP,"plain XP: "..heart(state))
		assert(state.statBonus==nil,"the daily Bonus XP is untouched")
		assert(#Stat.boosts(state,PET,"heart")==1 and Stat.boosts(state,PET,"heart")[1].left==50,"a Stat Snack boost is untouched")
		assert(state.fruit.day==DAY and state.fruit.count==1 and S.committed(state,"a")and S.receipt(state,"a").xp==2)
		for k=2,12 do assert(claim(state,"a"..k))end
		-- Review B36: an older write is still known (a late replay of it is AlreadySaved, never paid twice).
		assert(S.committed(state,"a11")and S.committed(state,"a5")and not S.committed(state,"a")and S.committed(state,"a12"))
		assert(#state.fruit.recent==S.Recent)
		assert(heart(state)==24 and S.left(state,DAY)==0)
		local ok,why=claim(state,"over")
		assert(not ok and why=="DailyLimit"and heart(state)==24 and not S.committed(state,"over"))
		assert(claim(state,"next",tostring(tonumber(DAY)+1))and state.fruit.count==1 and heart(state)==26)
	end)

	test("the save, tolerant: a bad count closes that day only; a bad day is no field; a later day is kept; never an error",function()
		for _,odd in ipairs({{day=DAY,count=13},{day=DAY,count=-1},{day=DAY,count=1.5},{day=DAY}})do
			local state={inventoryMask=Eggs.bit(PET),fruit=odd}
			assert(S.left(state,DAY)==0 and select(2,claim(state,"m"))=="DailyLimit")
			assert(claim(state,"m2","19681")and state.fruit.count==1)
		end
		for _,odd in ipairs({"x",5,{day=19680,count=1},{count=0}})do
			local state={inventoryMask=Eggs.bit(PET),fruit=odd}
			assert(S.left(state,DAY)==12 and claim(state,"m")and state.fruit.count==1)
		end
		local later={inventoryMask=Eggs.bit(PET),fruit={day="19690",count=11}}
		assert(claim(later,"r")and later.fruit.day=="19690"and later.fruit.count==12 and not claim(later,"r2"))
		local none={inventoryMask=0}
		assert(select(2,claim(none,"n"))=="NoPet"and none.fruit==nil)
		assert(select(2,claim(owned(),"u",DAY,"nobody"))=="NoPet")
		assert(select(2,S.apply(owned(),{id="b",petId=PET},"bad"))=="InvalidFruit")
		local maxed={inventoryMask=Eggs.bit(PET),petStats={[PET]={heart=C.MaxXP}}}
		assert(claim(maxed,"x")and maxed.fruit.count==1 and S.receipt(maxed,"x").xp==0,"a maxed pet still uses it up")
	end)

	test("the transaction: Hatching.fruitClaim pays once; a replay is AlreadySaved; an ambiguous write resumes and pays once",function()
		local function fixture(start)
			local db,c={},{now=start or 1700000000,serial=0,writes=0}
			local adapter={now=function()return c.now end,guid=function()c.serial+=1;return "op"..c.serial end,random=function()return .1 end,wait=function()end,
				update=function(key,transform)
					if c.down then error("down")end
					local value=transform(copy(db[key]))
					if value then db[key]=copy(value);c.writes+=1 end
					if c.failAfter then c.failAfter=false;error("after commit")end
					return copy(value)
				end}
			local h=H.load(1,{rank=1},adapter)
			db.player_1.hatching.inventoryMask=Eggs.bit(PET);db.player_1.hatching.lease={token="",expiresAt=0}
			h=H.load(1,{rank=1},adapter)
			assert(h.status=="Ready")
			return h,db,c
		end
		local h,db,c=fixture()
		local good,why=H.fruitClaim(h,"f1",PET);assert(good and why=="Saved",why)
		local xp=heart(db.player_1.hatching)
		assert(xp==Fruit.XP and H.fruitCommitted(h,"f1")and H.fruitReceipt(h,"f1").xp==xp and H.fruitLeft(h)==11)
		local writes=c.writes
		good,why=H.fruitClaim(h,"f1",PET);assert(good and why=="AlreadySaved"and c.writes==writes and heart(db.player_1.hatching)==xp)
		assert(select(2,H.fruitClaim(h,"",PET))=="InvalidFruit")
		local start=1700000000
		while Daily.dayOf(start)==Daily.dayOf(start+60)do start+=30 end
		h,db,c=fixture(start)
		c.failAfter=true
		good,why=H.fruitClaim(h,"f1",PET);assert(not good and why=="Retrying"and h.pending and h.pending.signature=="fruit:f1")
		assert(select(2,H.fruitClaim(h,"f2",PET))=="Pending")
		c.now+=60
		good,why=H.fruitClaim(h,"f1",PET);assert(good and why=="Saved",why)
		assert(heart(db.player_1.hatching)==Fruit.XP and db.player_1.hatching.fruit.count==1,"paid once")
	end)

	-- The host with a fake board, garden and save ----------------------------------------------------------------
	local trees=Fruit.trees()
	local tree=trees[1]
	local yes,no=times(1,tree.centre)
	local function rig(options)
		options=options or {}
		local r={clock=1000,now=options.now or no,on=true,fired={},saves=0}
		local player={UserId=7,Name="kid"}
		local spot=Vector3.new(tree.x+3,4,tree.z)
		r.spot=spot
		r.root=Vector3.new(tree.x+tree.trunk+1,4,tree.z)
		local state=owned()
		local handle={state=state,status="Ready",adapter={now=function()return r.now end}}
		r.board={player=player,profileReady=true,nursery=handle,profile={companionId=PET},mode="Room"}
		r.actor={petId=PET,mode="Room",from={spot.X+1,4,spot.Z},to={spot.X+1,4,spot.Z},startTime=0,endTime=1}
		r.garden={actors={[7]=r.actor}}
		r.boards={[player]=r.board}
		r.state=state
		local nursery={
			fruitLeft=function(h)return S.left(h.state,DAY)end,
			fruitClaim=function(h,op,pet)r.saves+=1;return S.apply(h.state,{id=op,petId=pet,day=DAY},DAY)end,
			fruitCommitted=function(h,op)return S.committed(h.state,op)end,
			fruitReceipt=function(h,op)return S.receipt(h.state,op)end,
			retry=function()end}
		r.host=Host.new({boards=r.boards,garden=r.garden,nursery=nursery,canProgress=function()return options.busy~=true end,
			publishNursery=function()end,clock=function()return r.clock end,now=function()return r.now end,
			spawn=function(fn)fn()end,wait=function()r.clock+=1 end,on=function()return r.on end,breath=function()return false end,
			root=function()return r.root end,remote={FireClient=function(_,_,packet)table.insert(r.fired,packet)end}})
		function r.send(packet)r.clock+=.3;return r.host:receive(player,packet)end
		function r.eat(at)at=at or spot;return r.send({kind="eat",tree=1,x=at.X,z=at.Z})end
		return r
	end

	test("the host: a shake by the trunk makes its fruit claimable; eaten, it pays 2 Heart XP once; no shake, no wind: refused",function()
		local r=rig()
		assert(no,"a quiet window")
		local ok,why=r.eat();assert(not ok and why=="NoFruit",why)
		assert(r.fired[#r.fired].kind=="refused"and r.fired[#r.fired].reason=="NoFruit")
		r.root=Vector3.new(tree.x+tree.trunk+Fruit.Shake.reach+Fruit.Shake.slack+.5,4,tree.z)
		assert(select(2,r.send({kind="shake",tree=1}))=="Far","a shake from too far")
		r.root=Vector3.new(tree.x+tree.trunk+1,4,tree.z)
		assert(r.send({kind="shake",tree=1}))
		assert(select(2,r.send({kind="shake",tree=1}))=="Rate","beta 42: at most one shake a tree every Shake.serverGap")
		assert(r.eat())
		assert(heart(r.state)==2 and r.saves==1 and r.fired[#r.fired].kind=="fed"and r.fired[#r.fired].xp==2)
		-- The shake is used up: the next claim (a minute on) needs the wind or another shake.
		r.clock+=61
		assert(select(2,r.eat())=="NoFruit")
		-- With the wind's drop: no shake needed.
		local w=rig({now=yes})
		assert(w.eat()and heart(w.state)==2)
	end)

	test("beta 42 E18: shake again and again, one fruit a shake; claims add up to the tree's slots per regrow, each once, each paid only within the minute's and the day's caps",function()
		assert(Fruit.MaxDrops==1 and Fruit.shakeClaims(nil)==1 and Fruit.shakeClaims(0)==0 and Fruit.shakeClaims(1)==1
			and Fruit.shakeClaims(2)==1 and Fruit.shakeClaims(9)==1 and Fruit.shakeClaims(1.5)==1 and Fruit.shakeClaims(0/0)==1
			and Fruit.shakeClaims(-3)==0)
		assert(Fruit.Shake.every==1.5 and Fruit.Shake.serverGap<=Fruit.Shake.every and Fruit.Shake.serverGap>0)
		local budget=Fruit.shakeBudget(tree)
		assert(budget==Fruit.slotsFor(tree.tree)and Fruit.shakeBudget(tree.tree)==budget)
		local r=rig()
		local function shake(drops)r.clock+=Fruit.Shake.serverGap;return r.send({kind="shake",tree=1,drops=drops})end
		for n=1,budget do assert(shake(1),"shake "..n)end
		assert(select(2,shake(1))=="Rate","past the tree's slots in one regrow: refused")
		local rec=r.host.records[r.board]
		assert(#rec.shaken[1]==budget and #rec.shakeAt[1]==budget,"one claim a shake, added up")
		assert(r.eat(),"the first fruit pays")
		assert(select(2,r.eat())=="Rate","the second inside the minute: the minute's cap")
		assert(#rec.shaken[1]==budget-1,"a refused claim uses nothing")
		rec.paidAt=-math.huge
		assert(r.eat(),"the next fruit (past the minute)")
		assert(#rec.shaken[1]==budget-2 and heart(r.state)==2*Fruit.XP)
		-- an empty shake (nothing fell) opens nothing and spends nothing
		local e=rig()
		e.clock+=Fruit.Shake.serverGap
		assert(e.send({kind="shake",tree=1,drops=0}))
		assert(e.host.records[e.board].shaken[1]==nil and(e.host.records[e.board].shakeAt[1]==nil or #e.host.records[e.board].shakeAt[1]==0))
		assert(select(2,e.eat())=="NoFruit")
		-- claims last Window; the budget comes back after Shake.gap
		local w=rig()
		w.clock+=Fruit.Shake.serverGap;assert(w.send({kind="shake",tree=1}))
		w.clock+=Fruit.Window+1
		assert(select(2,w.eat())=="NoFruit","an old claim is gone")
		local g=rig()
		local function gshake()g.clock+=Fruit.Shake.serverGap;return g.send({kind="shake",tree=1})end
		for _=1,budget do assert(gshake())end
		assert(select(2,gshake())=="Rate")
		g.clock+=Fruit.Shake.gap
		assert(gshake(),"a regrow on: shakes again")
	end)
	test("beta 42 E18: a shake flood never opens more claims than the tree's slots per regrow, and never pays more than one a minute",function()
		local r=rig()
		local budget=Fruit.shakeBudget(tree)
		local random=Random.new(42)
		local accepted={}
		local paidAt={}
		local start=r.clock
		while r.clock-start<600 do
			r.clock+=random:NextNumber(0,1.2)
			if random:NextNumber()<.7 then
				local drops=({nil,0,1,2,50})[random:NextInteger(1,5)]
				if r.send({kind="shake",tree=1,drops=drops})and Fruit.shakeClaims(drops)>0 then table.insert(accepted,r.clock)end
			else
				local before=heart(r.state)
				r.eat()
				if heart(r.state)>before then table.insert(paidAt,r.clock)end
			end
			local open=r.host.records[r.board].shaken[1]
			assert(open==nil or #open<=budget,"open claims "..tostring(open and #open))
		end
		for i,t in ipairs(accepted)do
			local inWindow=0
			for j=i,#accepted do if accepted[j]-t<Fruit.Shake.gap then inWindow+=1 end end
			assert(inWindow<=budget,"accepted shakes in one regrow: "..inWindow)
			if i>1 then assert(t-accepted[i-1]>=Fruit.Shake.serverGap-1e-9,"two shakes too close")end
		end
		for i=2,#paidAt do assert(paidAt[i]-paidAt[i-1]>=Fruit.Gap,"paid twice in a minute")end
		assert(#paidAt>=2 and #accepted>=budget,"the flood did shake and pay ("..#accepted..", "..#paidAt..")")
	end)
	test("the host: one a minute, twelve a day; the pet near the fruit, the player near; busy, no pet, off",function()
		local r=rig({now=yes})
		assert(r.eat())
		assert(select(2,r.eat())=="Rate","a second fruit inside the minute")
		for _=2,12 do r.clock+=61;assert(r.eat())end
		assert(heart(r.state)==24)
		r.clock+=61
		assert(select(2,r.eat())=="DailyLimit"and heart(r.state)==24)
		local p=rig({now=yes})
		p.actor.from={p.spot.X+Fruit.PetReach+1,4,p.spot.Z};p.actor.to=p.actor.from
		assert(select(2,p.eat())=="PetFar")
		local o=rig({now=yes})
		o.root=Vector3.new(o.spot.X+Fruit.OwnerReach+1,4,o.spot.Z)
		assert(select(2,o.eat())=="Far")
		local f=rig({now=yes})
		assert(select(2,f.eat(Vector3.new(tree.x+Fruit.Reach+1,4,tree.z)))=="Far","a spot no fruit of this tree reaches")
		local b=rig({now=yes,busy=true})
		assert(select(2,b.eat())=="Busy")
		local n=rig({now=yes})
		n.actor.petId="blip"
		assert(select(2,n.eat())=="NoPet")
		local c=rig({now=yes})
		c.actor.care=true
		assert(select(2,c.eat())=="Busy")
		local off=rig({now=yes})
		off.on=false
		assert(select(2,off.eat())=="Off"and heart(off.state)==0)
		for _,x in ipairs({b,n,c,off,p,o,f})do assert(heart(x.state)==0,"nothing written")end
	end)

	test("beta 38 (GARDEN-B38-BRIEF 3): the Heart XP rules and the server's shake reach, gap and window unchanged; the prompt reaches no further than the server allows; five slots (Blossom Point seven); three warm varieties; the tree size settles to the ground size on the first bounce; one shake in four drops a second fruit",function()
		-- The rules the server pays and checks by, as before.
		assert(Fruit.XP==2 and Fruit.Gap==60 and Fruit.DailyLimit==12 and Fruit.Window==45 and Fruit.Reach==14)
		assert(Fruit.Shake.reach==1.6 and Fruit.Shake.slack==2 and Fruit.Shake.gap==75 and Fruit.Shake.speed==4)
		assert(Fruit.Shake.hidden+Fruit.Shake.grow>=Fruit.Shake.gap,"the client's rest (the prompt off) outlasts the server's gap")
		-- The look's new numbers.
		assert(Fruit.Shake.leaves==12 and Fruit.Shake.rock==8 and Fruit.Shake.rocks==3 and Fruit.Shake.rockTime==.7)
		-- The prompt: never past the server's shake reach (a prompt shake is never Far), and never past Fable's 6.
		for _,tree in ipairs(Fruit.trees())do
			local reach=Fruit.promptReach(tree)
			assert(reach<=Fruit.Prompt.reach and reach<tree.trunk+Fruit.Shake.reach+Fruit.Shake.slack,tree.tree.." prompt reach")
			assert(reach>tree.trunk+Fruit.Shake.reach,"further than the bump")
			assert(Fruit.promptShakes(tree,tree.x+reach-.01,tree.z)and not Fruit.promptShakes(tree,tree.x+reach+.01,tree.z))
			-- Whatever the prompt allows the server's own check passes.
			assert(Fruit.shakes(tree,tree.x+reach,tree.z,nil,Fruit.Shake.slack),"the server agrees")
			assert(Fruit.slotsFor(tree.tree)==(if tree.tree=="Landmark_BlossomPointTree"then 7 else 5))
		end
		assert(not Fruit.promptShakes(nil,0,0)and not Fruit.promptShakes(Fruit.trees()[1],nil,0))
		-- Three varieties on the seven blossom trees, golden on Blossom Point; every one warm (no green or blue fruit).
		local seen={}
		for _,tree in ipairs(Fruit.trees())do
			local v=Fruit.variety(tree.tree)
			seen[Fruit.VarietyOf[tree.tree]]=(seen[Fruit.VarietyOf[tree.tree]]or 0)+1
			for _,hex in ipairs({v.body,v.blush})do
				local c=Color3.fromHex(hex)
				assert(c.R>=c.G and c.R>c.B+.15,tree.tree.." warm "..hex)
			end
		end
		assert(seen.sunset==3 and seen.berry==3 and seen.pear==1 and seen.golden==1,"3 + 3 + 1 and Blossom Point")
		assert(Fruit.variety("nope")==Fruit.Varieties.sunset and Fruit.Varieties.sunset.body==Fruit.Look.body.colour)
		assert(Fruit.Varieties.pear.tall==1.2)
		-- Size: 1.15 in the tree and through the fall; .9 after the first bounce, eased between.
		local tree=Fruit.Canopy.size/Fruit.Look.body.size
		local function near(a,b)return math.abs(a-b)<1e-6 end
		assert(near(Fruit.sizeAt(10,nil,nil),tree)and near(Fruit.sizeAt(10,11,11.34),tree)and near(Fruit.sizeAt(11,11,11.34),tree))
		assert(near(Fruit.sizeAt(11.34,11,11.34),1)and near(Fruit.sizeAt(20,11,11.34),1))
		local mid=Fruit.sizeAt(11.17,11,11.34)
		assert(mid<tree and mid>1,"eases down")
		-- Drops: on the second swing; beta 42 E18: exactly one a shake.
		for count=1,200 do
			local t=Fruit.dropTimes(100,count)
			assert(#t==1 and near(t[1],100+Fruit.Drops.first),"one, on the second swing")
		end
	end)

	test("beta 42 E20: the leaves' measured face (scripts/crown_fruit_surface.py) for the blossom crown: whole, in range, bilinear, wrapping round; other meshes none",function()
		local s=Fruit.Surface.W7_Kit_Crown_Blossom__foliage_blossom
		assert(s and #s.r==s.lats*s.az and s.lat0==Fruit.Canopy.seatFrom and s.lat0+s.step*(s.lats-1)==Fruit.Canopy.seatTo)
		for _,v in ipairs(s.r)do assert(v>=.5 and v<=1.05,"a share of the ellipsoid: "..v)end
		local mesh="W7_Kit_Crown_Blossom__foliage_blossom"
		local function near(a,b)return math.abs(a-b)<1e-6 end
		assert(near(Fruit.surfaceAt(mesh,0,10),s.r[1])and near(Fruit.surfaceAt(mesh,2*math.pi,10),s.r[1]),"a = 0 and a full turn")
		assert(near(Fruit.surfaceAt(mesh,2*math.pi/s.az,15),s.r[s.az+2]),"the next column of the next row")
		local mid=Fruit.surfaceAt(mesh,math.pi/s.az,12.5)
		assert(near(mid,(s.r[1]+s.r[2]+s.r[s.az+1]+s.r[s.az+2])/4),"bilinear between")
		assert(near(Fruit.surfaceAt(mesh,0,0),s.r[1])and near(Fruit.surfaceAt(mesh,0,90),s.r[(s.lats-1)*s.az+1]),"latitude clamps")
		assert(Fruit.surfaceAt("W7_Kit_Crown_Round__foliage",0,20)==nil and Fruit.surfaceAt(mesh,0/0,20)==nil)
		assert(Fruit.Canopy.hull>=.7 and Fruit.Canopy.hull<=.85,"the fallback near the measured mean")
	end)

	test("the host never errors and never pays a bad packet (a fuzz of 3,000)",function()
		local r=rig({now=yes})
		local random=Random.new(35)
		local odd={nil,0,-1,1.5,0/0,math.huge,"1",{},true,9999}
		for _=1,3000 do
			local packet=({nil,"x",{},{kind="eat"},{kind="shake"},{kind="eat",tree=odd[random:NextInteger(1,#odd)],x=odd[random:NextInteger(1,#odd)],z=0},
				{kind="eat",tree=1,x=odd[random:NextInteger(1,#odd)],z=odd[random:NextInteger(1,#odd)]},{kind="shake",tree=odd[random:NextInteger(1,#odd)]},
				{kind="nope",tree=1}})[random:NextInteger(1,9)]
			local ok,problem=pcall(r.send,packet)
			assert(ok,problem)
		end
		assert(heart(r.state)==0,"nothing paid")
	end)

	return {passed=#cases,cases=cases}
end
