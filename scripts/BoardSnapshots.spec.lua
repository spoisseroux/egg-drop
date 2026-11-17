-- Deck network rework (deck-network-plan.md, architect review section 6): the snapshot
-- buffer and render clock under synthetic arrival schedules, plus the wire codec.
-- Studio: require(PlayerScripts.Client.ZZSpecs.BoardSnapshots)(PlayerScripts.Client, gui).
-- Offline: luau scripts/run_pure_spec.luau (passes the modules as `modules`).
return function(client,_,modules)
 modules=modules or {}
 local Snapshots=modules.Snapshots or require(client.BoardSnapshots)
 local Codec=modules.Codec or require(game:GetService("ReplicatedStorage").Shared.BoardSnapshotCodec)
 local Random=modules.Random or Random -- offline runner passes a shim
 local cases={};local function test(name,run)run();table.insert(cases,name)end

 local Rate=Snapshots.TickRate
 local Frame=1/60
 -- A ball dropped at sim time 0: falls with gravity for 1.6 s (y 18 -> about -2.5, clamped at 1).
 local function path(tick)
  local s=tick/Rate
  return .3*s,math.max(1,18-8*s*s)
 end
 -- Server sends: every other 60 Hz Heartbeat, ticks advance 2 or 3 per Heartbeat.
 local function sends(duration,options)
  options=options or {}
  local list={}
  local tick=0
  for beat=1,math.floor(duration*60)do
   local t=beat/60
   local paused=options.pause and t>=options.pause[1]and t<options.pause[2]
   if not paused then tick=math.floor(t*Rate+.5)-(options.pauseTicks and t>=options.pause[2]and options.pauseTicks or 0)end
   local every=if paused then 15 else 2
   if beat%every==0 then table.insert(list,{t=t,tick=tick,paused=paused})end
  end
  return list
 end
 -- Run a schedule: lag(k, send) -> one-way seconds or nil (lost). Returns per-frame data.
 local function run(list,lag,options)
  options=options or {}
  local random=Random.new(options.seed or 1)
  local packets={}
  for k,send in ipairs(list)do
   local delay=lag(k,send,random)
   if delay then
    table.insert(packets,{arrival=send.t+delay,send=send})
    if options.duplicates and random:NextNumber()<options.duplicates then table.insert(packets,{arrival=send.t+delay+random:NextNumber(0,.03),send=send})end
   end
  end
  table.sort(packets,function(a,b)return a.arrival<b.arrival end)
  local buffer=Snapshots.new()
  local ids,xs,ys={},{},{}
  local frames={}
  local p=1
  local duration=list[#list].t+(options.tail or .6)
  for f=1,math.floor(duration/Frame)do
   local now=f*Frame
   while packets[p]and packets[p].arrival<=now do
    local send=packets[p].send
    local x,y=path(send.tick)
    local resetId=if options.resetAt and send.t>=options.resetAt then 2 else 1
    local id=if resetId==2 then 7 else 1
    ids[1],xs[1],ys[1]=id,x,y
    buffer:push(packets[p].arrival,resetId,send.tick,if send.paused then Snapshots.PausedFlag else 0,ids,xs,ys,1)
    p+=1
   end
   local tick=buffer:advance(now)
   local resetId=buffer.resetId
   local x,y,where=buffer:sample(if resetId==2 then 7 else 1)
   table.insert(frames,{now=now,tick=tick,x=x,y=y,where=where,starved=tick~=nil and buffer.newestTick~=nil and tick>buffer.newestTick+1,streaming=packets[p]~=nil})
  end
  return frames,buffer
 end
 -- Metrics over frames while the ball is in flight (y between 1.2 and 17).
 local function measure(frames)
  local m={hitches=0,backwards=0,maxStep=0,nonMonotonic=0,longestStill=0}
  local still,lastTick,last=0,nil,nil
  for _,f in ipairs(frames)do
   if f.tick and lastTick and f.tick<lastTick-1e-9 then m.nonMonotonic+=1 end
   lastTick=f.tick or lastTick
   if f.y and f.y<17 and f.y>1.2 and f.where=="live"then
    if last then
     local step=math.sqrt((f.x-last.x)^2+(f.y-last.y)^2)
     if f.y>last.y+1e-6 then m.backwards+=1 end
     if step>m.maxStep then m.maxStep=step end
     if step<1e-6 then still+=Frame else
      if still>=.05 then m.hitches+=1 end
      if still>m.longestStill then m.longestStill=still end
      still=0
     end
    end
    last=f
   end
  end
  return m
 end
 -- The fastest the ball legitimately moves per frame (end of the fall), with the clock's
 -- 1.05x catch-up rate.
 local nominal=0
 for tick=0,1.6*Rate,1 do
  local x0,y0=path(tick);local x1,y1=path(tick+Rate*Frame*1.05)
  nominal=math.max(nominal,math.sqrt((x1-x0)^2+(y1-y0)^2))
 end
 local list=sends(1.8)

 test("codec round-trips ids, ticks, flags and positions within 1/2000 stud",function()
  local ids,xs,ys={1,65535,70000},{-5.4321,0,5.5},{0.0004,18.9996,-1.25}
  local b=Codec.encode(321,123456789,Codec.Paused,ids,xs,ys,3)
  assert(buffer.len(b)==8+6*3,"size")
  local oi,ox,oy={},{},{}
  local resetId,tick,flags,count=Codec.decode(b,oi,ox,oy)
  assert(resetId==321 and tick==123456789 and flags==Codec.Paused and count==3)
  assert(oi[1]==1 and oi[2]==65535 and oi[3]==70000%65536,"ids wrap at 65536")
  for i=1,3 do assert(math.abs(ox[i]-xs[i])<=.0005 and math.abs(oy[i]-ys[i])<=.0005,"quantization "..i)end
  local clamped=Codec.encode(1,1,0,{1},{99},{-99},1)
  local _,_,_,_=Codec.decode(clamped,oi,ox,oy);assert(ox[1]==32.767 and oy[1]==-32.767,"clamped to +/-32.767")
  assert(Codec.decode(buffer.create(5),oi,ox,oy)==nil,"short buffer refused")
  assert(Codec.decode(buffer.create(9),oi,ox,oy)==nil,"count/length mismatch refused")
  assert(Codec.decode("nope",oi,ox,oy)==nil,"non-buffer refused")
  local many,zeros={},{}
  for i=1,Codec.MaxBalls+50 do many[i]=i;zeros[i]=0 end
  local full=Codec.encode(1,1,0,many,zeros,zeros,Codec.MaxBalls+50)
  assert(buffer.len(full)==8+6*Codec.MaxBalls and buffer.len(full)<=900,"capped under the unreliable payload limit")
 end)

 test("constant 100 ms: smooth, no hitch, never backwards, never starved after warm-up",function()
  local frames,buffer=run(list,function()return .1 end)
  local m=measure(frames)
  assert(m.nonMonotonic==0 and m.backwards==0,"monotonic: nonMonotonic="..m.nonMonotonic.." backwards="..m.backwards)
  assert(m.hitches==0,"hitches "..m.hitches)
  assert(m.maxStep<=nominal*1.1,"max step "..m.maxStep.." nominal "..nominal)
  -- One send interval (about 33 ms) above the jitter, so the clock never runs past the data.
  assert(buffer.delay>=Snapshots.DelayMin-1e-9 and buffer.delay<=.07,"delay without jitter: "..buffer.delay)
  local starved,live=0,0
  for _,f in ipairs(frames)do if f.streaming and f.tick and f.now>.6 then live+=1;if f.starved then starved+=1 end end end
  assert(starved<=live*.02,"starved "..starved.." of "..live.." streaming frames")
 end)

 test("150-250 ms jitter with reordering and duplicates: no hitch, no backwards motion",function()
  local frames,buffer=run(list,function(_,_,r)return r:NextNumber(.15,.25)end,{duplicates=.2,seed=3})
  local m=measure(frames)
  assert(m.nonMonotonic==0 and m.backwards==0,"monotonic, backwards "..m.backwards)
  assert(m.hitches==0,"hitches "..m.hitches.." longest still "..m.longestStill)
  assert(m.maxStep<=nominal*1.6,"max step "..m.maxStep.." nominal "..nominal)
  assert(buffer.stats.stale+buffer.stats.duplicates>0,"reordered and duplicate packets were seen and dropped")
  assert(buffer.delay>=.07,"delay grows with the jitter: "..buffer.delay)
 end)

 test("control: drawing each packet as it lands (today's Parts) hitches under the same jitter",function()
  -- Same schedule, no buffer: the newest arrived sample is drawn every frame.
  local random=Random.new(3)
  local arrivals={}
  for _,send in ipairs(list)do table.insert(arrivals,{at=send.t+random:NextNumber(.15,.25),tick=send.tick})end
  table.sort(arrivals,function(a,b)return a.at<b.at end)
  local frames,newest,p={},-1,1
  for f=1,math.floor((list[#list].t+.6)/Frame)do
   local now=f*Frame
   while arrivals[p]and arrivals[p].at<=now do newest=math.max(newest,arrivals[p].tick);p+=1 end
   if newest>=0 then local x,y=path(newest);table.insert(frames,{tick=newest,x=x,y=y,where="live"})end
  end
  local m=measure(frames)
  assert(m.hitches>=5,"the metric must catch today's stutter: "..m.hitches)
 end)

 for _,loss in ipairs({.05,.15,.3})do
  test(string.format("%d%% loss on 150-250 ms jitter: monotonic, never backwards, few holds",loss*100),function()
   local frames=run(list,function(_,_,r)if r:NextNumber()<loss then return nil end;return r:NextNumber(.15,.25)end,{seed=11})
   local m=measure(frames)
   assert(m.nonMonotonic==0 and m.backwards==0,"monotonic, backwards "..m.backwards)
   assert(m.hitches<=(if loss<.2 then 0 else 3),"hitches "..m.hitches.." at "..loss)
  end)
 end

 test("a 1 s spike then a burst: holds, then catches up without running backwards",function()
  local frames,buffer=run(sends(3.5),function(_,send)
   if send.t>=1 and send.t<2 then return .1+(2-send.t)+.05 end -- everything in [1,2) lands at ~2.15 s
   return .1 end)
  local m=measure(frames)
  assert(m.nonMonotonic==0 and m.backwards==0,"monotonic: nonMonotonic="..m.nonMonotonic.." backwards="..m.backwards)
  -- Recovered: a second after the burst the clock renders about delay behind the newest.
  local last=frames[#frames]
  assert(buffer:depth()<=Snapshots.DelayMax+.05,"buffer depth after recovery "..buffer:depth())
  assert(last.tick and last.tick>0,"clock running")
 end)

 test("a paused stream (same tick, paused flag) freezes the clock and resumes without a jump",function()
  local frames,buffer=run(sends(3,{pause={.6,1.6},pauseTicks=math.floor(Rate)}),function()return .1 end)
  local pausedTick
  for _,f in ipairs(frames)do
   if f.now>1.0 and f.now<1.6 then
    pausedTick=pausedTick or f.tick
    assert(f.tick==pausedTick,"render tick moved during the pause")
   end
  end
  local m=measure(frames)
  assert(m.nonMonotonic==0 and m.backwards==0,"monotonic: nonMonotonic="..m.nonMonotonic.." backwards="..m.backwards)
  assert(m.maxStep<=nominal*1.6,"resume jump "..m.maxStep)
  assert(buffer.stats.paused>0,"pause seen")
 end)

 test("a new ResetId mid-buffer flushes the old run and ignores its late packets",function()
  local frames,buffer=run(list,function(_,send,r)return if send.t<.9 then r:NextNumber(.1,.4)else .1 end,{resetAt=.8,seed=5})
  assert(buffer.resetId==2 and buffer.stats.resets==1,"one reset")
  assert(buffer:sample(1)==nil,"old run's ball forgotten")
  assert(buffer.stats.stale>0,"late packets of the old run dropped")
  local m=measure(frames);assert(m.nonMonotonic==0,"monotonic")
 end)

 test("a ball the clock has not reached yet is early (its first sample); a missing id is gone",function()
  local buffer=Snapshots.new()
  buffer:push(1.0,1,100,0,{1},{0},{10},1)
  buffer:push(1.033,1,105,0,{1},{0},{9.9},1)
  local tick=buffer:advance(1.04)
  assert(tick<100,"clock renders behind the newest sample")
  buffer:push(1.066,1,110,0,{1,2},{0,1},{9.8,17.8},2) -- ball 2 appears at tick 110
  local x,y,where=buffer:sample(2)
  assert(where=="early"and x==1 and y==17.8,"early ball holds its first sample")
  buffer:push(1.1,1,115,0,{2},{1},{17.7},1) -- ball 1 left at tick 115
  assert(select(3,buffer:sample(1,114))=="live"and select(3,buffer:sample(1,115))=="gone","removed at its own tick")
  assert(buffer:sample(99)==nil,"unknown id")
 end)

 test("a lone stream (no Parts yet) still clocks; silence reports the gap",function()
  local buffer=Snapshots.new()
  assert(buffer:advance(1)==nil and buffer:silence(1)==math.huge)
  buffer:push(2,1,10,0,{},{},{},0)
  assert(buffer:advance(2.01)~=nil and math.abs(buffer:silence(2.5)-.5)<1e-9)
 end)

 return {passed=#cases,cases=cases,nominalStep=nominal}
end
