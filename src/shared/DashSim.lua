-- Garden Dash race simulation (V3-SCOPE-2026-11-21 sections 4.3, 4.4, 4.4b and 4.7, slice S5). One pure module
-- for both sides: the server's copy is the result, the client runs the same code to predict its own pet.
--   * fixed 10 ms ticks; every quantity is a whole number far below 2^53 (units in DashStats), so the same plan,
--     levels and inputs give the same finish time everywhere, to the microsecond;
--   * the step path walks arrays only; randomness is a 32-bit xorshift, drawn when the heat is planned (the
--     pals keep one small stream each, for their own button presses);
--   * cost is bounded: at most 8 runners, a few comparisons each a tick, at most MaxQueue waiting inputs.
-- Nothing random touches a jump window, a speed or a result: luck is the course of the day, clovers and zoomies.
-- The server deals with lag by stepping its race LagTicks behind its clock, so an honest input always arrives
-- before its tick is stepped; push() refuses anything older (4.7: 150 ms and no further).
-- Values the scope leaves open are marked [P]. Not required by the live game yet (slice S6 does that).
local Shared=script.Parent
local Course=require(Shared.DashCourse)
local Stats=require(Shared.DashStats)
local Sim={}

Sim.Version=1
Sim.MaxRunners=8
Sim.LagTicks=15
Sim.MaxQueue=64
Sim.InputsPerSecond=10
Sim.MaxAhead=100 -- an input may be stamped at most a second past the simulated tick [P]
Sim.TailTicks=2000 -- the heat ends 20 s after the winner
Sim.MaxTicks=12000
Sim.DashPct=30
Sim.StumblePct=10
Sim.StumbleTicks=40
Sim.TripTicks=120
-- The scope says a 1.5 s climb out AND that one miss makes the stones slower than the bridge. The stones save
-- 13.8 studs (2.3 s at level 1, plus up to two Perfects' dash), so the climb and the shake dry take 2.8 s. [P]
Sim.SplashTicks=280
Sim.PerfectBar=50*Stats.DashTick
-- Dash is a choice (tuned 2026-11-22) [P]: the meter drains four times faster than it refills, a pet that runs it
-- empty is puffed out (10% slower and no dash for 1 s), and a hoop met at a sprint has a 30% shorter window.
-- So: dash on the straights, let go before a hoop and before the meter is empty.
Sim.RefillTick=98
Sim.PuffPct=10
Sim.PuffTicks=100
Sim.AirTicks=25 -- a pet in the air ignores presses [P]
Sim.ReachTicks=60 -- a press this long before the take-off spot but outside the Clear window is a Trip; earlier is a free hop [P]
Sim.SignpostTicks=200
Sim.CloverBar=100*Stats.DashTick
Sim.ZoomPct=20
Sim.ZoomGap=600*Stats.UnitsPerCs
Sim.ZoomTicks=table.freeze({stats=200,fun=300,trial=0})
Sim.BotSkill=table.freeze({400,800}) -- Perfect, parts in a thousand [P]
Sim.BotClear=600 -- of the jumps that are not Perfect, parts in a thousand that are Clear [P]
Sim.BotStones=250 -- how often a pal takes the stones [P]
Sim.Result=table.freeze({Perfect=1,Clear=2,Trip=3})
Sim.Kinds=table.freeze({jump=true,dashDown=true,dashUp=true,stones=true})

local UNIT=Stats.UnitsPerCs
local LENGTH,FORK,SAVING=Course.Length*UNIT,Course.Fork*UNIT,Course.Saving*UNIT
local PERFECT,CLEAR,TRIP=1,2,3
local JUDGE=980000 -- gap * JUDGE <= step * window: gap/step ticks against a window in 1/98 microseconds

-- Random numbers -------------------------------------------------------------------------------------------
local function stream(seed,salt)
	seed=if type(seed)=="number"and seed==seed and seed<math.huge and seed>-math.huge then math.floor(math.abs(seed))%4294967296 else 1
	local state=bit32.bxor(seed,(salt*2654435769)%4294967296)
	return{state=if state==0 then 1831565813 else state}
end
local function below(rng,n)
	local x=rng.state
	x=bit32.bxor(x,bit32.lshift(x,13));x=bit32.bxor(x,bit32.rshift(x,17));x=bit32.bxor(x,bit32.lshift(x,5))
	rng.state=x
	return (x//256)%n -- the low bits are the weak ones
end

-- The plan ---------------------------------------------------------------------------------------------------
-- Everything luck decides, drawn once from the server's seed when joining has closed. `count` runners in seat
-- order; plan.lanes[seat] is the dealt lane.
function Sim.plan(seed,mode,count)
	mode=if mode=="stats"or mode=="trial"then mode else"fun"
	count=math.clamp(math.floor(count),1,Sim.MaxRunners)
	local rng=stream(seed,1)
	for _=1,4 do below(rng,2)end
	local plan={seed=seed,mode=mode,count=count,layout="even",lanes={},clovers={},cloverHurdle=0,zoomies={}}
	local layout=Course.LayoutOrder[1+below(rng,#Course.LayoutOrder)]
	for lane=1,count do plan.lanes[lane]=lane end
	for i=count,2,-1 do
		local j=1+below(rng,i)
		plan.lanes[i],plan.lanes[j]=plan.lanes[j],plan.lanes[i]
	end
	if mode=="trial"or count<2 then return plan end -- no luck alone: par times and ghosts stay comparable
	plan.layout=layout
	plan.cloverHurdle=1+below(rng,6)
	local deck={}
	for lane=1,count do deck[lane]=lane end
	local clovers=if mode=="fun"then math.max(1,count//2)elseif count<4 then 1 else 2
	for i=1,clovers do
		local j=i+below(rng,count-i+1)
		deck[i],deck[j]=deck[j],deck[i]
		plan.clovers[i]=deck[i]
	end
	if mode=="fun"then plan.zoomies={400+below(rng,150),550+below(rng,151)}
	else plan.zoomies={400+below(rng,301)}end
	return plan
end
-- What a client may know: never the seed or the zoomies moments.
function Sim.publicPlan(plan)
	return{mode=plan.mode,count=plan.count,layout=plan.layout,lanes=table.clone(plan.lanes),
		clovers=table.clone(plan.clovers),cloverHurdle=plan.cloverHurdle,zoomies={}}
end

-- The race ---------------------------------------------------------------------------------------------------
-- Jump lists in the runner's own distance: after the stones everything is Saving nearer.
local function lists(layout)
	local main,stones={},{}
	local hurdles=Course.hurdles(layout)
	for index,d in ipairs(hurdles)do
		if d<Course.Fork then
			table.insert(main,{at=d*UNIT,hurdle=index});table.insert(stones,{at=d*UNIT,hurdle=index})
		end
	end
	for _,stone in ipairs(Course.Stones)do table.insert(stones,{at=FORK+stone.d*UNIT,stone=true})end
	for index,d in ipairs(hurdles)do
		if d>=Course.Fork then
			table.insert(main,{at=d*UNIT,hurdle=index});table.insert(stones,{at=d*UNIT-SAVING,hurdle=index})
		end
	end
	for _,list in ipairs({main,stones})do -- half way back to the jump before: no take-off spot is further back than that
		for i,goal in ipairs(list)do goal.room=if i>1 then(goal.at-list[i-1].at)//2 else goal.at end
	end
	return main,stones
end

local function botOf(seed,seat,skill)
	local rng=stream(seed,seat+1)
	for _=1,4 do below(rng,2)end
	local low,high=Sim.BotSkill[1],Sim.BotSkill[2]
	if type(skill)~="number"or skill~=skill then skill=low+below(rng,high-low+1)end
	return{rng=rng,skill=math.clamp(math.floor(skill),0,1000),ready=5+below(rng,20),stones=below(rng,1000)<Sim.BotStones,at=0,press=nil}
end

-- options: seed and mode (or plan), runners = {{speed=,energy=,jump=,bot=true|{skill=}},...} in seat order.
-- Levels are read from the save by the server; Just for Fun and Time Trial ignore them.
function Sim.new(options)
	local runners=options.runners
	local count=#runners
	assert(count>=1 and count<=Sim.MaxRunners,"1 to 8 runners")
	local plan=options.plan or Sim.plan(options.seed,options.mode,count)
	local main,stones=lists(plan.layout)
	local race={plan=plan,tick=0,over=false,winnerTick=nil,moment=1,main=main,stonesList=stones,runners={}}
	for seat,spec in ipairs(runners)do
		local levels=if plan.mode=="stats"then Stats.effective(spec)else nil
		local function level(id)return if levels then levels[id]else Stats.FunLevel end
		local stride,bar=Stats.stride(level("speed")),Stats.bar(level("energy"))
		local lane=plan.lanes[seat]or seat
		local clover=table.find(plan.clovers,lane)~=nil and plan.cloverHurdle>0
		race.runners[seat]={seat=seat,lane=lane,stride=stride,cap=bar,bar=bar,
			perfect=Stats.perfect(level("jump")),clear=Stats.clear(level("jump")),
			pos=0,total=LENGTH,step=stride*100,judge=stride*100,list=main,next=1,results={},doomed=false,
			dash=false,tumble=0,stumble=0,puff=0,zoom=0,air=0,wants=false,stones=false,forked=false,zoomed=false,
			clover=if clover then plan.cloverHurdle else 0,cloverTick=0,zoomTick=0,
			perfects=0,clears=0,trips=0,puffs=0,inputs=0,lastKind=0,lastTick=0,finishUs=nil,
			queue={},head=1,recent={},recentHead=1,stamp=0,
			bot=if spec.bot then botOf(options.seed or plan.seed or seat,seat,if type(spec.bot)=="table"then spec.bot.skill else nil)else nil}
	end
	return race
end

function Sim.remaining(runner)return runner.total-runner.pos end
-- The take-off spot, the middle of the jump window: one late Clear window before the hoop, so a hoop nobody
-- jumped is met exactly as the window closes and the pet trips at the hoop. `judge` is the pace without dash.
function Sim.takeoff(r,goal)
	return goal.at-math.min(r.judge*r.clear//JUDGE,goal.room)
end

local function land(race,r,kind)
	local index=r.next
	r.results[index]=kind
	r.next=index+1
	r.doomed=false
	r.lastKind,r.lastTick=kind,race.tick
	if kind==PERFECT then
		r.perfects+=1;r.bar=math.min(r.cap,r.bar+Sim.PerfectBar)
	elseif kind==CLEAR then
		r.clears+=1;r.stumble=Sim.StumbleTicks
	else
		r.trips+=1;r.stumble=0
		r.tumble=if r.list[index].stone then Sim.SplashTicks else Sim.TripTicks
	end
end
local function jump(race,r)
	if r.tumble>0 or r.air>0 or r.doomed then return end
	r.air=Sim.AirTicks
	local goal=r.list[r.next]
	if not goal then return end
	local gap,judge=Sim.takeoff(r,goal)-r.pos,r.judge
	local size=math.abs(gap)*JUDGE
	if size<=judge*r.perfect then land(race,r,PERFECT)
	elseif size<=judge*r.clear then land(race,r,CLEAR)
	elseif gap>0 and gap<=judge*Sim.ReachTicks then r.doomed=true end -- too early: the tumble comes at the hoop
end
local function apply(race,r,kind)
	if kind=="jump"then jump(race,r)
	elseif kind=="dashDown"then r.dash=true
	elseif kind=="dashUp"then r.dash=false
	elseif kind=="stones"then
		local gap=FORK-r.pos
		if gap>0 and gap<=r.step*Sim.SignpostTicks then r.wants=true end
	end
end

-- A player's button event, stamped with the tick it happened on. The server calls this with whatever a seated
-- player sent; a refused event changes nothing. Returns true, or false and why.
function Sim.push(race,seat,tick,kind)
	local r=race.runners[seat]
	if race.over or not r or r.bot or r.finishUs then return false,"closed"end
	if type(tick)~="number"or tick~=tick or tick%1~=0 or Sim.Kinds[kind]~=true then return false,"bad"end
	if tick<=race.tick then return false,"late"end
	if tick>race.tick+Sim.MaxAhead then return false,"early"end
	if tick<r.stamp then return false,"order"end
	if #r.queue-r.head+1>=Sim.MaxQueue then return false,"flood"end
	local oldest=r.recent[r.recentHead]
	if oldest and tick-oldest<Stats.TicksPerSecond then return false,"flood"end
	r.recent[r.recentHead]=tick
	r.recentHead=r.recentHead%Sim.InputsPerSecond+1
	r.stamp=tick
	r.inputs+=1
	table.insert(r.queue,{tick=tick,kind=kind})
	return true
end
local function drain(race,r)
	local queue=r.queue
	while true do
		local event=queue[r.head]
		if not event then
			if r.head>1 then table.clear(queue);r.head=1 end
			return
		end
		if event.tick>race.tick then return end
		r.head+=1
		apply(race,r,event.kind)
	end
end

-- Garden pals press the same buttons through apply(): no shortcut into speeds or results.
local function think(race,r)
	local bot=r.bot
	if bot.stones and not r.forked and not r.wants and FORK-r.pos<=r.step*(Sim.SignpostTicks//2)then apply(race,r,"stones")end
	local goal=r.list[r.next]
	local gap=if goal then Sim.takeoff(r,goal)-r.pos else LENGTH
	if race.tick>=bot.ready then -- dash on the straights, rest for the hoops and before the meter is empty
		if r.dash then
			if r.bar<=8*Stats.DashTick or gap<=r.judge*30 then apply(race,r,"dashUp")end
		elseif r.bar>=80*Stats.DashTick and r.puff==0 and gap>r.judge*60 then apply(race,r,"dashDown")end
	end
	if not goal then return end
	if bot.at~=r.next then -- one skill roll for each jump
		bot.at,bot.press=r.next,nil
		local rng=bot.rng
		if below(rng,1000)<bot.skill then
			bot.press=r.perfect//1000*(below(rng,1601)-800)
		elseif below(rng,1000)<Sim.BotClear then
			local from=r.perfect//100*115
			bot.press=from+(r.clear//100*90-from)//1000*below(rng,1001)
			if below(rng,2)==0 then bot.press=-bot.press end
		end
	end
	local press=bot.press
	if press and goal.stone then press=math.abs(press)end -- the stones are close together: never late
	if press and gap*JUDGE<=r.judge*press then apply(race,r,"jump")end
end

local function move(race,r)
	if r.air>0 then r.air-=1 end
	local zoom=r.zoom>0
	if zoom then r.zoom-=1 end
	if r.tumble>0 then r.tumble-=1;return end
	local pct=100
	if r.stumble>0 then pct-=Sim.StumblePct;r.stumble-=1 end
	if zoom then pct+=Sim.ZoomPct end
	local dashing=r.dash and r.puff==0 and r.bar>=Stats.DashTick
	if r.puff>0 then pct-=Sim.PuffPct;r.puff-=1 end
	r.judge=r.stride*pct
	if dashing then
		pct+=Sim.DashPct;r.bar-=Stats.DashTick
		if r.bar<Stats.DashTick then r.puff=Sim.PuffTicks;r.puffs+=1 end
	else r.bar=math.min(r.cap,r.bar+Sim.RefillTick)end
	local step=r.stride*pct
	local before=r.pos
	local pos=before+step
	r.step,r.pos=step,pos
	if not r.forked and pos>=FORK then
		r.forked=true
		if r.wants then r.stones,r.list,r.total=true,race.stonesList,LENGTH-SAVING end
	end
	local list=r.list
	local goal=list[r.next]
	if goal and pos>=goal.at then land(race,r,TRIP)end -- pressed too early, or not at all
	if r.clover>0 then
		for index,jumped in ipairs(list)do
			if jumped.hurdle==r.clover then
				local result=r.results[index]
				if result and pos>=jumped.at+Course.CloverPast*UNIT then
					if result~=TRIP then r.bar=math.min(r.cap,r.bar+Sim.CloverBar);r.cloverTick=race.tick end
					r.clover=0
				end
				break
			end
		end
	end
	if pos>=r.total then
		r.finishUs=(race.tick-1)*10000+(r.total-before)*10000//step
		r.pos=r.total
		if not race.winnerTick then race.winnerTick=race.tick end
	end
end

-- Zoomies for one seat. The server's race calls it; a predicting client calls it when the server says so.
function Sim.zoom(race,seat)
	local r=race.runners[seat]
	r.zoom,r.zoomed,r.zoomTick=Sim.ZoomTicks[race.plan.mode],true,race.tick
end
-- At the drawn moment (how far round the last pet is, in thousandths) the last pet gets zoomies if the pet in
-- front is at least 6 studs ahead. One look at each moment; a pet gets them once a heat at most, so in Just for
-- Fun the second go is for somebody else and the luck budget stays under one Trip.
local function luck(race)
	local moment=race.plan.zoomies[race.moment]
	if not moment then return end
	local last,front
	for _,r in ipairs(race.runners)do
		if not last or Sim.remaining(r)>Sim.remaining(last)then front=last;last=r
		elseif not front or Sim.remaining(r)>Sim.remaining(front)then front=r end
	end
	if not front or last.pos*1000<moment*last.total then return end
	race.moment+=1
	if not last.zoomed and not last.finishUs and Sim.remaining(last)-Sim.remaining(front)>=Sim.ZoomGap then Sim.zoom(race,last.seat)end
end

-- One tick. Returns true while the heat is still running.
function Sim.step(race)
	if race.over then return false end
	race.tick+=1
	local running=false
	for _,r in ipairs(race.runners)do
		if not r.finishUs then
			drain(race,r)
			if r.bot then think(race,r)end
			move(race,r)
			if not r.finishUs then running=true end
		end
	end
	luck(race)
	if not running or race.tick>=Sim.MaxTicks or(race.winnerTick and race.tick>=race.winnerTick+Sim.TailTicks)then race.over=true end
	return not race.over
end
function Sim.run(race)
	while Sim.step(race)do end
	return Sim.placings(race)
end

-- Finish order: seats, first to last. Unfinished pets are placed by distance left; a dead heat goes to the
-- lower dealt lane.
function Sim.placings(race)
	local order=table.clone(race.runners)
	table.sort(order,function(a,b)
		if a.finishUs and b.finishUs then
			if a.finishUs~=b.finishUs then return a.finishUs<b.finishUs end
			return a.lane<b.lane
		end
		if a.finishUs or b.finishUs then return a.finishUs~=nil end
		if Sim.remaining(a)~=Sim.remaining(b)then return Sim.remaining(a)<Sim.remaining(b)end
		return a.lane<b.lane
	end)
	local seats={}
	for place,r in ipairs(order)do seats[place]=r.seat end
	return seats
end

-- A player who leaves mid-heat becomes a pal on the spot: same place, same numbers, same bar.
function Sim.toBot(race,seat,skill)
	local r=race.runners[seat]
	if not r or r.bot or r.finishUs then return end
	r.bot=botOf(race.plan.seed or seat,seat,skill)
	r.bot.ready=race.tick+1
	table.clear(r.queue);r.head=1
end

-- Where to draw a runner: DashCourse.at's arguments (cs, onStones, lane).
function Sim.spot(runner)
	local cs=runner.pos/UNIT
	if runner.stones then
		if cs<Course.Fork+Course.StonesLength then return cs-Course.Fork,true,runner.lane end
		return cs+Course.Saving,false,runner.lane
	end
	return cs,false,runner.lane
end
-- The jump in front, for the closing ring: ticks until its take-off spot (negative when past), or nil.
function Sim.nextJump(runner)
	local goal=runner.list[runner.next]
	if not goal then return nil end
	return (Sim.takeoff(runner,goal)-runner.pos)/runner.step
end

return table.freeze(Sim)
