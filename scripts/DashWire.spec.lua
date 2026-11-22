-- Garden Dash packets and state buffer (V3-DASH-BUILD-PLAN-2026-11-22, S6): exact types, a fuzz, and the codec.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.DashWire)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Wire=require(Shared.DashWire)
	local Sim=require(Shared.DashSim)
	local Stats=require(Shared.DashStats)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local LONG=string.rep("x",41)
	local ODD={false,true,0,-1,.5,0/0,math.huge,-math.huge,2^53,"","x",LONG,{},{1},function()end,buffer.create(4)}
	local function with(base,key,value)local out=table.clone(base);out[key]=value;return out end
	local JOIN={kind="join",seq=1,petId="pip",petGeneration=0,characterId=2,mode="stats"}
	local INPUT={r="race",n=1,t=5,k="jump"}
	test("good requests come back as clean copies with known fields only",function()
		local out=Wire.request(with(JOIN,"levels",{speed=99}));assert(out.kind=="join"and out.mode=="stats"and out.petId=="pip"and out.levels==nil)
		assert(Wire.request(with(JOIN,"mode",nil)).mode=="fun")
		for _,kind in ipairs({"leave","ping"})do assert(Wire.request({kind=kind,seq=3}).kind==kind)end
		assert(Wire.request({kind="mode",seq=1,mode="fun"}).mode=="fun"and Wire.request({kind="mode",seq=1})==nil)
		assert(Wire.request({kind="trial",seq=1,petId="pip",petGeneration=0,characterId=0}))
		local clean=Wire.input(with(INPUT,"seat",3));assert(clean.n==1 and clean.seat==nil)
	end)
	test("every wrong type, size, range or name is refused, one field at a time",function()
		for _,odd in ipairs(ODD)do
			assert(Wire.request(odd)==nil and Wire.input(odd)==nil)
			for _,key in ipairs({"kind","seq","petId","petGeneration","characterId","mode"})do
				local fine=(odd==0 and(key=="petGeneration"or key=="characterId"))or(odd=="x"and key=="petId")
				assert((Wire.request(with(JOIN,key,odd))~=nil)==fine,key)
			end
			for _,key in ipairs({"r","n","t","k"})do
				assert((Wire.input(with(INPUT,key,odd))~=nil)==(odd=="x"and key=="r"),key)
			end
		end
		for _,key in ipairs({"kind","seq","petId","petGeneration","characterId"})do assert(Wire.request(with(JOIN,key,nil))==nil)end
		for _,key in ipairs({"r","n","t","k"})do assert(Wire.input(with(INPUT,key,nil))==nil)end
		assert(Wire.input(with(INPUT,"t",12001))==nil and Wire.request(with(JOIN,"seq",2147483648))==nil and Wire.request(nil)==nil)
	end)
	test("a fuzz of 20,000 packets never errors and never lets a bad one through",function()
		local random=Random.new(11)
		local pool=table.clone(ODD);for _,v in ipairs({1,7,100,"jump","dashUp","join","trial","fun","stats","race","pip"})do table.insert(pool,v)end
		for _=1,20000 do
			local a,b={},{}
			for _,key in ipairs({"kind","seq","petId","petGeneration","characterId","mode"})do a[key]=pool[random:NextInteger(1,#pool)]end
			for _,key in ipairs({"r","n","t","k"})do b[key]=pool[random:NextInteger(1,#pool)]end
			local x,y=Wire.request(a),Wire.input(b)
			if x then assert(Wire.RequestKinds[x.kind]and x.seq%1==0 and x.seq>=1)end
			if y then assert(Wire.InputKinds[y.k]and y.n%1==0 and y.t>=1 and y.t<=12000 and #y.r<=40)end
		end
	end)
	test("state buffer: eight runners in 72 bytes, read back exactly at any moment of a race",function()
		local runners={};for i=1,8 do runners[i]={speed=i*12,energy=i*12,jump=i*12,bot=true}end
		runners[8].bot=nil -- a player who holds Dash: the pals never run the meter empty
		local race=Sim.new({seed=5,mode="stats",runners=runners});assert(Sim.push(race,8,1,"dashDown"))
		local seen={}
		while Sim.step(race)do
			if race.tick%37~=0 then continue end
			local packed=Wire.encode("guid-1",race,Stats.UnitsPerCs);assert(buffer.len(packed)==72)
			local out=Wire.decode(packed);assert(out.tag==Wire.tag("guid-1")and out.tick==race.tick and #out.seats==8)
			for seat,r in ipairs(race.runners)do
				local s=out.seats[seat]
				assert(s.cs==r.pos//Stats.UnitsPerCs and s.next==r.next and s.flags.finished==(r.finishUs~=nil)and s.flags.stones==r.stones)
				assert(s.flags.tumble==(r.tumble>0)and s.flags.air==(r.air>0)and math.abs(s.bar-r.bar/r.cap)<.0001)
				for name,set in pairs(s.flags)do if set then seen[name]=true end end
			end
		end
		for name in pairs(Wire.Flags)do assert(seen[name],name)end
	end)
	test("race tags differ; a buffer of any other shape is refused",function()
		assert(Wire.tag("a")~=Wire.tag("b")and Wire.tag("")==2166136261 and Wire.tag("a")==3826002220,"FNV-1a")
		for _,odd in ipairs(ODD)do assert(Wire.decode(odd)==nil)end
		local packed=Wire.encode("x",Sim.new({seed=1,mode="fun",runners={{}}}),Stats.UnitsPerCs);assert(Wire.decode(packed))
		for size=0,40 do if size~=16 then local b=buffer.create(size);if size>0 then buffer.writeu8(b,0,1)end;if size>1 then buffer.writeu8(b,1,1)end;assert(Wire.decode(b)==nil)end end
		buffer.writeu8(packed,0,9);assert(Wire.decode(packed)==nil)
	end)
	return{passed=#cases,cases=cases}
end
