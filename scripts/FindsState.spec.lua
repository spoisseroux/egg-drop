-- Garden finds save field and picker (V3-FINDS-BUILD-PLAN-2026-11-22, S9): the daily cap, fail closed, clock rollback,
-- the proof, a pet not owned, a maxed pet, and the spot picker's rules. Pure tables only.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.FindsState)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local S=require(server.FindsState)
	local Stat=require(server.StatState)
	local C=require(Shared.StatCatalog)
	local Eggs=require(Shared.EggCatalog)
	local Finds=require(Shared.Finds)
	local Spots=require(Shared.FindSpots)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local DAY="19680"
	local PET="pip"
	local function owned()return{inventoryMask=Eggs.bit(PET)}end
	local function claim(state,id,n,day,pet)return S.apply(state,{id=id,petId=pet or PET,n=n or 1},day or DAY)end
	local function smarts(state)return Stat.xp(state,PET,"smarts")end

	test("a find: 8 Smarts XP doubled by today's Bonus, the count, the proof and the receipt",function()
		local state=owned()
		assert(claim(state,"a"))
		assert(state.finds.day==DAY and state.finds.count==1 and S.committed(state,"a")and not S.committed(state,"b"))
		local receipt=S.receipt(state,"a")
		assert(receipt.n==1 and receipt.petId==PET and receipt.xp==smarts(state)and receipt.xp==2*Finds.XP,receipt.xp)
		assert(S.receipt(state,"b")==nil and S.left(state,DAY)==11)
	end)
	test("twelve a day: a batch pays what is left, then DailyLimit writes nothing; the next day pays again",function()
		local state=owned()
		for i=1,3 do assert(claim(state,"b"..i,3))end
		assert(state.finds.count==9)
		assert(claim(state,"c",3)and state.finds.count==12 and S.receipt(state,"c").n==3)
		local before=smarts(state)
		local ok,why=claim(state,"d",1)
		assert(not ok and why=="DailyLimit"and smarts(state)==before and not S.committed(state,"d")and S.left(state,DAY)==0)
		assert(claim(state,"e",1,"19681")and state.finds.count==1 and state.finds.day=="19681")
		local almost={inventoryMask=Eggs.bit(PET),finds={day=DAY,count=11}}
		assert(claim(almost,"f",3)and almost.finds.count==12 and S.receipt(almost,"f").n==1,"only what is left")
	end)
	test("clock rollback: a later saved day is kept and counts on; it never starts again",function()
		local state={inventoryMask=Eggs.bit(PET),finds={day="19690",count=11}}
		assert(claim(state,"r1")and state.finds.day=="19690"and state.finds.count==12)
		assert(not claim(state,"r2")and S.left(state,DAY)==0)
	end)
	test("malformed field: a bad count closes that day only; a bad day reads as no field; never an error",function()
		for _,odd in ipairs({{day=DAY,count=13},{day=DAY,count=-1},{day=DAY,count=1.5},{day=DAY}})do
			local state={inventoryMask=Eggs.bit(PET),finds=odd}
			assert(S.left(state,DAY)==0)
			local ok,why=claim(state,"m")
			assert(not ok and why=="DailyLimit")
			assert(claim(state,"m2",1,"19681")and state.finds.count==1,"the next day starts again")
		end
		for _,odd in ipairs({"x",5,{day=19680,count=1},{day="1e3",count=0},{count=0}})do
			local state={inventoryMask=Eggs.bit(PET),finds=odd}
			assert(S.left(state,DAY)==12)
			assert(claim(state,"m")and state.finds.day==DAY and state.finds.count==1,"repaired by the first find")
		end
		local state={inventoryMask=Eggs.bit(PET),finds={day=DAY,count=2,op="z",receipt={op="z",petId=PET,n="x",xp=1}}}
		assert(S.committed(state,"z")and S.receipt(state,"z")==nil and S.left(state,DAY)==10)
		assert(S.left({},DAY)==12 and S.left(owned(),"bad")==0)
	end)
	test("refused, nothing written: a pet not owned, an unknown pet, a bad batch, a bad day",function()
		local state={inventoryMask=0}
		local ok,why=claim(state,"n")
		assert(not ok and why=="NoPet"and state.finds==nil)
		state=owned()
		assert(select(2,claim(state,"u",1,DAY,"nobody"))=="NoPet")
		for _,n in ipairs({0,4,1.5})do assert(select(2,claim(state,"b",n))=="InvalidFind")end
		assert(select(2,claim(state,"d",1,"x"))=="InvalidFind")
		assert(state.finds==nil)
	end)
	test("a pet at the most Smarts XP still uses up the find: 0 XP, counted, proof written",function()
		local state={inventoryMask=Eggs.bit(PET),petStats={[PET]={smarts=C.MaxXP}}}
		assert(claim(state,"x")and state.finds.count==1 and S.receipt(state,"x").xp==0)
	end)
	test("the spots: 24, six a lawn, whole hundredths, on the ground; pick never repeats a live or recent spot",function()
		local lawns={}
		assert(#Spots==24)
		for _,s in ipairs(Spots)do
			lawns[s.lawn]=(lawns[s.lawn]or 0)+1
			assert(s.x%1==0 and s.y%1==0 and s.z%1==0 and s.y>300 and s.y<600)
		end
		for _,name in ipairs({"south","east","west","grove"})do assert(lawns[name]==6,name)end
		local random=Random.new(7)
		for _=1,400 do
			local live,recent={},{}
			for _=1,random:NextInteger(0,2)do live[#live+1]=random:NextInteger(1,24)end
			for _=1,random:NextInteger(0,6)do recent[#recent+1]=random:NextInteger(1,24)end
			local i=Finds.pick(random,live,recent)
			if i then
				for _,j in ipairs(live)do
					assert(i~=j)
					assert(math.sqrt((Spots[i].x-Spots[j].x)^2+(Spots[i].z-Spots[j].z)^2)/100>=Finds.Spacing)
				end
				for _,j in ipairs(recent)do assert(i~=j)end
			end
		end
		local all={};for i=1,24 do all[i]=i end
		assert(Finds.pick(random,{},all)==nil,"nothing left: nil")
		assert(Finds.position(1).X==Spots[1].x/100 and Finds.position(99)==nil)
	end)
	test("G2 pick near: the NearMin..NearSpot band when it has open spots, else the nearest open one; the old rules hold",function()
		local random=Random.new(3)
		for index=1,24 do
			local at=Vector3.new(Spots[index].x/100+25,5,Spots[index].z/100)
			for _=1,20 do
				local i=Finds.pick(random,{},{},at)
				local d=math.sqrt((Spots[i].x/100-at.X)^2+(Spots[i].z/100-at.Z)^2)
				local band=false
				for j=1,24 do
					local dj=math.sqrt((Spots[j].x/100-at.X)^2+(Spots[j].z/100-at.Z)^2)
					if dj>=Finds.NearMin and dj<=Finds.NearSpot then band=true end
				end
				if band then assert(d>=Finds.NearMin and d<=Finds.NearSpot,"in the band "..d)
				else
					for j=1,24 do assert(d<=math.sqrt((Spots[j].x/100-at.X)^2+(Spots[j].z/100-at.Z)^2)+1e-9,"the nearest")end
				end
			end
		end
		-- Far from everything: the nearest open spot, never a live or recent one.
		local far=Vector3.new(5000,0,5000)
		local i=Finds.pick(random,{1},{2,3},far)
		assert(i and i~=1 and i~=2 and i~=3)
		local all={};for k=1,24 do all[k]=k end
		assert(Finds.pick(random,{},all,far)==nil)
	end)
	test("the switch: ceiling needs the flag and the beta place or Studio; resolve defaults on",function()
		assert(not Finds.ceiling({flags={},place=Finds.PlaceId}))
		assert(not Finds.ceiling({flags={GardenFinds=true},place=96451847774961,studio=false}))
		assert(Finds.ceiling({flags={GardenFinds=true},place=Finds.PlaceId,studio=false}))
		assert(Finds.ceiling({flags={GardenFinds=true},place=1,studio=true}))
		assert(Finds.resolve(nil,nil,true)==true and Finds.resolve("x",nil,true)==true and Finds.resolve(false,nil,true)==false)
		assert(Finds.resolve(false,true,true)==true and Finds.resolve(true,nil,false)==false)
	end)
	return{passed=#cases,cases=cases}
end
