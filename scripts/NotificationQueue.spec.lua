-- NotificationQueue, pure. v2 "Toy tickets" (NOTIFICATIONS-SPEC 2026-11-20 section 1): up to
-- 4 timed lines and 1 status line show at once, each timed line on its own clock, admitted at
-- least 0.4 s apart; the status line is pinned left, the rest oldest left; a card holds all.
return function(client)
 local Queue=require(client.NotificationQueue)
 local cases=0
 local function check(ok,message)assert(ok,message);cases+=1 end
 local function ids(list)local out={};for _,item in ipairs(list)do table.insert(out,item.key)end;return table.concat(out,",")end
 local fits=function(d)return d.text~="too long"end
 -- Status fallback, dedupe, deferral, pause, owner cancellation, bounds.
 local q=Queue.new(3);local a,b={},{};local shown,done=0,0
 local status=q:add(a,"park",{text="Games 1/3",active=true},true)
 check(ids(q:step(0,fits))=="park","a status line shows alone")
 local first=q:add(b,"award",{text="Saved",onShown=function()shown+=1 end,onDone=function()done+=1 end})
 check(ids(q:step(0,fits))=="park,award","a notice shows beside the status line, which stays pinned left")
 q:add(b,"award",{text="Saved",onShown=function()shown+=1 end,onDone=function()done+=1 end})
 check(#q.items==1 and shown==1,"dedupe does not duplicate presentation")
 status.data={text="Games 2/3",active=true}
 check(ids(q:step(4,fits))=="park"and status.data.text=="Games 2/3"and done==1 and first.cancelled,"its time ran out; the latest status text stays")
 local deferred=q:add(a,"tip",{text="too long",onShown=function()error("deferred counted as seen")end})
 q:step(9,fits);check(not deferred.shown and deferred.age==0,"a line that cannot be drawn waits without consuming its time")
 local second=q:add(b,"next",{text="Next",paused=true})
 check(ids(q:step(0,fits))=="park,next","admitted")
 q:step(100,fits);check(q:visible(second)and second.age==0,"pause preserves dwell")
 second.data.paused=false;q:step(.25,fits);check(second.age==.25,"its clock runs again")
 q:cancelOwner(b)
 check(ids(q:step(0,fits))=="park"and not q:visible(second),"owner cancellation releases its place")
 q:add(a,"two",{text="Two"});q:add(a,"three",{text="Three"})
 check(q:add(a,"overflow",{text="Overflow"})==nil,"bounded queue")
 q:cancelOwner(a);check(#q:step(0,fits)==0 and #q.items==0 and #q.providers==0,"destroy cancels queue and status line")

 -- 4 timed + 1 status, 0.4 s apart, independent clocks, oldest left.
 local m=Queue.new(24);local o={}
 local st=m:add(o,"status",{text="Status",active=true},true)
 local lines={}
 for i=1,6 do lines[i]=m:add(o,"l"..i,{text="Line "..i,duration=10})end
 check(ids(m:step(0,fits))=="status,l1","one line first, beside the status line")
 check(ids(m:step(.375,fits))=="status,l1","the next line waits 0.4 s")
 check(ids(m:step(.125,fits))=="status,l1,l2","then it is admitted on the right")
 check(ids(m:step(.5,fits))=="status,l1,l2,l3","one more per 0.4 s")
 check(ids(m:step(.5,fits))=="status,l1,l2,l3,l4","four timed lines and the status line")
 check(ids(m:step(.5,fits))=="status,l1,l2,l3,l4"and not lines[5].shown,"a fifth timed line waits")
 check(lines[1].age==2 and lines[2].age==1.5 and lines[3].age==1 and lines[4].age==.5,"every shown line runs its own clock")
 check(ids(m:step(8,fits))=="status,l2,l3,l4,l5"and lines[1].cancelled and lines[2].age==9.5 and lines[4].age==8.5 and lines[5].age==0,
  "the oldest ran out alone; the next waiting line joins on the right")
 -- Held (a tip or notice card is open): every clock stops, nothing is admitted or replaced.
 check(ids(m:step(100,fits,true))=="status,l2,l3,l4,l5"and lines[2].age==9.5 and lines[5].age==0,"held: every clock stops")
 m:cancel(lines[4])
 check(ids(m:step(100,fits,true))=="status,l2,l3,l5"and not lines[6].shown,"held: a cancelled line leaves, nothing new takes its place")
 lines[3].tapped=true;st.tapped=true
 check(ids(m:step(50,fits,true))=="status,l2,l3,l5","a tapped line stays under its card")
 check(ids(m:step(0,fits))=="status,l2,l5"and lines[3].cancelled and not st.tapped and not st.cancelled,"the card closed: the tapped line ends; a tapped status line just stays")
 check(ids(m:step(.25,fits))=="status,l2,l5","admissions still keep their spacing")
 check(ids(m:step(.25,fits))=="status,l5,l6"and lines[2].cancelled,"the oldest ran out; the newest joins on the right")
 -- Priority picks who is admitted first; a line switched off keeps its clock.
 local p=Queue.new(8);local po={}
 p:add(po,"low",{text="Low"});local high=p:add(po,"high",{text="High",priority=2})
 check(ids(p:step(0,fits))=="high","priority picks who is admitted first")
 check(ids(p:step(.5,fits))=="high,low","then the rest, to the right")
 high.data={text="High",priority=2,active=false}
 check(ids(p:step(1,fits))=="low"and high.age==.5 and not high.cancelled,"switched off: off the row, still queued, its clock kept")
 high.data={text="High",priority=2}
 check(ids(p:step(.5,fits))=="low,high"and high.age==.5,"switched on again: back on the right with its time left")
 p:add(po,"status",{text="S"},true)
 check(ids(p:step(0,fits,true))=="low,high","held: no new status line either")
 check(ids(p:step(0,fits))=="status,low,high","then it shows, pinned left")
 return{passed=cases}
end
