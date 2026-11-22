-- Garden Dash on the wire (V3-DASH-BUILD-PLAN-2026-11-22, slice S6). Shared and pure: packet checks, the 10 Hz
-- state buffer and the roster shape, used by the server (DashHost) and the client. Nothing here trusts a packet:
-- it answers a clean copy with known fields only, or nil. Types are exact (whole numbers, strings up to 40).
--
-- Remotes (made by the server the first time Dash is on, in ReplicatedStorage.Remotes):
--   DashRequest  C->S  {kind, seq, petId?, petGeneration?, characterId?, mode?}
--                      kind: "join" (mode "fun"/"stats"), "mode", "trial", "leave", "ping"; seq rises each request
--   DashInput    C->S  {r=raceId, n=seq, t=tick, k=kind}; n only ever rises within a race
--   DashEvent    S->C  one of
--     {kind="reply", request, seq, ok, reason?, raceId?, at?}  every request's answer (a repeated seq repeats it);
--                      reason "Queued" means ok and waiting in line; ping answers with `at`, the server time
--     {kind="joined", raceId, seat?, mode, trial?, promoted?, closer?}  seated (seats may shift until the countdown);
--                      promoted = from the line; closer = too far from the gate, walk up before the countdown
--     {kind="locked", raceId, seat, mode, goAt, plan, levels?, trial?}  countdown: plan is Sim.publicPlan, levels
--                      are the owner's own frozen levels (Stats On only)
--     {kind="refused", raceId?, reason}                        unseated, or dropped from the line, and why
--     {kind="refusedInput", r, n, reason}                      that input did not count: take it out and rebuild
--     {kind="judged", r, jump, result, tick}                   Sim.Result of the owner's own jump
--     {kind="zoom", r, tick}                                   the owner's pet got zoomies on that tick
--     {kind="result", r, trial?, mode, band?, seats={{seat,place,us?}}, seat, place, us?, medal?}
--     {kind="aborted", r, reason}                              unpaid; the pet is free again
--     {kind="cup", cups={ids}, us}                             these pars were beaten for the first time
--   DashState    S->C  unreliable, the buffer below; a race goes to everyone, a trial only to its runner
-- The roster is a JSON attribute (RosterAttribute) beside the garden Snapshot, so late joiners see it.
local Wire={}
Wire.Version=1
Wire.MaxString=40
Wire.MaxSeq=2147483647
Wire.RosterAttribute="Dash"
Wire.MarksAttribute="DashMarks"
Wire.Remotes=table.freeze({request="DashRequest",input="DashInput",event="DashEvent",state="DashState"})
Wire.RequestKinds=table.freeze({join=true,leave=true,mode=true,trial=true,ping=true})
Wire.Modes=table.freeze({fun=true,stats=true})
Wire.InputKinds=table.freeze({jump=true,dashDown=true,dashUp=true,stones=true})
Wire.MaxTick=12000 -- DashSim.MaxTicks

local function whole(value,low,high)
	return type(value)=="number"and value==value and value%1==0 and value>=low and value<=high
end
local function text(value)return type(value)=="string"and #value>=1 and #value<=Wire.MaxString end
Wire.whole,Wire.text=whole,text

-- A clean request, or nil. join and trial must name the pet they were made for.
function Wire.request(packet)
	if type(packet)~="table"or type(packet.kind)~="string"or Wire.RequestKinds[packet.kind]~=true
		or not whole(packet.seq,1,Wire.MaxSeq)then return nil end
	local out={kind=packet.kind,seq=packet.seq}
	if packet.kind=="join"or packet.kind=="trial"then
		if not text(packet.petId)or not whole(packet.petGeneration,0,Wire.MaxSeq)or not whole(packet.characterId,0,Wire.MaxSeq)then return nil end
		out.petId,out.petGeneration,out.characterId=packet.petId,packet.petGeneration,packet.characterId
	end
	if packet.kind=="join"or packet.kind=="mode"then
		local mode=packet.mode
		if mode==nil and packet.kind=="join"then mode="fun"end
		if type(mode)~="string"or Wire.Modes[mode]~=true then return nil end
		out.mode=mode
	end
	return out
end
-- A clean input, or nil. The tick window is the race's own business (Sim.push).
function Wire.input(packet)
	if type(packet)~="table"or not text(packet.r)or not whole(packet.n,1,Wire.MaxSeq)
		or not whole(packet.t,1,Wire.MaxTick)or type(packet.k)~="string"or Wire.InputKinds[packet.k]~=true then return nil end
	return{r=packet.r,n=packet.n,t=packet.t,k=packet.k}
end

-- State buffer: version u8, runner count u8, race tag u32, tick u16, then 8 bytes a seat in seat order:
--   cs u16 (the runner's own distance), pace u8 (percent of plain pace), flags u8, bar u16 (0..65535 of its cap),
--   next jump u8, zoom ticks left u8 (halved). 72 bytes for eight runners (the cap is 120).
Wire.Flags=table.freeze({dash=1,tumble=2,stumble=4,puff=8,zoom=16,air=32,stones=64,finished=128})
Wire.SeatBytes=8
Wire.HeaderBytes=8
local FIELDS=table.freeze({"dash","tumble","stumble","puff","zoom","air","stones","finished"})
-- A race id as 32 bits (FNV-1a), so an old race's late packet is never read as this one's.
function Wire.tag(raceId)
	local hash=2166136261
	for i=1,#raceId do
		hash=bit32.bxor(hash,string.byte(raceId,i))
		-- hash * 16777619 mod 2^32 in halves, so every product stays a whole number
		local low,high=hash%65536,hash//65536
		hash=(low*16777619+(high*403%65536)*65536)%4294967296
	end
	return hash
end
local function byte(value)return math.clamp(math.floor(value),0,255)end
-- race: a DashSim race; unitsPerCs: DashStats.UnitsPerCs (passed in, so this module needs no other).
function Wire.encode(raceId,race,unitsPerCs)
	local count=#race.runners
	local out=buffer.create(Wire.HeaderBytes+Wire.SeatBytes*count)
	buffer.writeu8(out,0,Wire.Version);buffer.writeu8(out,1,count)
	buffer.writeu32(out,2,Wire.tag(raceId));buffer.writeu16(out,6,race.tick)
	for seat,r in ipairs(race.runners)do
		local at=Wire.HeaderBytes+Wire.SeatBytes*(seat-1)
		local flags=0
		if r.dash and r.puff==0 then flags+=Wire.Flags.dash end
		if r.tumble>0 then flags+=Wire.Flags.tumble end
		if r.stumble>0 then flags+=Wire.Flags.stumble end
		if r.puff>0 then flags+=Wire.Flags.puff end
		if r.zoom>0 then flags+=Wire.Flags.zoom end
		if r.air>0 then flags+=Wire.Flags.air end
		if r.stones then flags+=Wire.Flags.stones end
		if r.finishUs then flags+=Wire.Flags.finished end
		buffer.writeu16(out,at,math.clamp(r.pos//unitsPerCs,0,65535))
		buffer.writeu8(out,at+2,if r.tumble>0 or r.finishUs then 0 else byte(r.step/r.stride))
		buffer.writeu8(out,at+3,flags)
		buffer.writeu16(out,at+4,math.clamp(r.bar*65535//r.cap,0,65535))
		buffer.writeu8(out,at+6,byte(r.next));buffer.writeu8(out,at+7,byte(r.zoom/2))
	end
	return out
end
-- {tag, tick, seats={{cs,pace,flags,bar (0..1),next,zoom}}}, or nil for anything but a whole, known buffer.
function Wire.decode(value)
	if type(value)~="buffer"then return nil end
	local size=buffer.len(value)
	if size<Wire.HeaderBytes or buffer.readu8(value,0)~=Wire.Version then return nil end
	local count=buffer.readu8(value,1)
	if count<1 or count>8 or size~=Wire.HeaderBytes+Wire.SeatBytes*count then return nil end
	local out={tag=buffer.readu32(value,2),tick=buffer.readu16(value,6),seats={}}
	for seat=1,count do
		local at=Wire.HeaderBytes+Wire.SeatBytes*(seat-1)
		local bits,flags=buffer.readu8(value,at+3),{}
		for _,name in ipairs(FIELDS)do flags[name]=bit32.band(bits,Wire.Flags[name])~=0 end
		out.seats[seat]={cs=buffer.readu16(value,at),pace=buffer.readu8(value,at+2),flags=flags,bar=buffer.readu16(value,at+4)/65535,
			next=buffer.readu8(value,at+6),zoom=buffer.readu8(value,at+7)*2}
	end
	return out
end

-- Roster: {v, phase="idle"|"gather"|"countdown"|"race"|"results", raceId?, mode?, band?, endsAt?, goAt?, plan?,
--   seats={{seat, userId?, petId, pal?, left?, name?=piece ids, tint?}}, queue={userIds}, best?={userId,us}}.
-- plan is Sim.publicPlan: never the seed or the zoomies moments. Levels are never in it.
Wire.Phases=table.freeze({idle=true,gather=true,countdown=true,race=true,results=true})
function Wire.roster(value)
	if type(value)~="table"or value.v~=Wire.Version or Wire.Phases[value.phase]~=true or type(value.seats)~="table"or type(value.queue)~="table"then return nil end
	return value
end
return table.freeze(Wire)
