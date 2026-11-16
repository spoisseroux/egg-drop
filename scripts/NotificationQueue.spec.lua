return function(client)
 local Queue=require(client.NotificationQueue)
 local q=Queue.new(3);local a,b={},{};local shown,done=0,0
 local fits=function(d)return d.text~="too long"end
 local status=q:add(a,"park",{text="Games 1/3",active=true},true)
 assert(q:step(0,fits)==status,"persistent fallback")
 local first=q:add(b,"award",{text="Saved",onShown=function()shown+=1 end,onDone=function()done+=1 end})
 assert(q:step(0,fits)==first,"notice preempts status")
 q:add(b,"award",{text="Saved",onShown=function()shown+=1 end,onDone=function()done+=1 end})
 assert(#q.items==1 and shown==1,"dedupe does not duplicate presentation")
 status.data={text="Games 2/3",active=true}
 q:step(4,fits);assert(q.current==status and status.data.text=="Games 2/3"and done==1,"latest fallback resumes")
 local deferred=q:add(a,"tip",{text="too long",onShown=function()error("deferred counted as seen")end})
 q:step(9,fits);assert(not deferred.shown and deferred.age==0,"narrow layout defers without consuming")
 local second=q:add(b,"next",{text="Next",paused=true})
 assert(q:step(0,fits)==second);q:step(100,fits);assert(q.current==second and second.age==0,"pause preserves dwell")
 second.data.paused=false;q:step(.2,fits);q:cancelOwner(b)
 assert(q:step(0,fits)==status,"owner cancellation releases slot")
 q:add(a,"two",{text="Two"});q:add(a,"three",{text="Three"})
 assert(q:add(a,"overflow",{text="Overflow"})==nil,"bounded queue")
 q:cancelOwner(a);assert(q:step(0,fits)==nil and #q.items==0 and #q.providers==0,"destroy cancels queue and fallback")
 -- QA v775, the calm rail: a gap after a line leaves, and a hold while a card is open.
 local c=Queue.new(8);c.gap=3;local o={};local ended=0
 local one=c:add(o,"one",{text="One",onDone=function()ended+=1 end});local two=c:add(o,"two",{text="Two"})
 assert(c:step(0,fits)==one)
 assert(c:step(100,fits,true)==one and one.age==0 and not two.shown and ended==0,"held: its clock stops and nothing replaces it")
 assert(c:step(3.9,fits)==nil and ended==1 and not two.shown,"its time ran out: the rail is empty, not the next line")
 assert(c:step(2.9,fits)==nil and not two.shown,"the gap is still running")
 assert(c:step(100,fits,true)==nil and not two.shown,"held: the gap does not run and nothing appears")
 assert(c:step(2.9,fits)==nil and not two.shown,"the card closed: the gap starts over")
 assert(c:step(.2,fits)==two and two.shown,"one new line once the gap has passed")
 two.tapped=true
 assert(c:step(50,fits,true)==two and two.age==0,"a tapped line stays under its card")
 assert(c:step(0,fits)==nil and two.cancelled,"and ends when the card closes (tapped through)")
 local three=c:add(o,"three",{text="Three"})
 assert(c:step(2.9,fits)==nil and c:step(.2,fits)==three,"the next line waits out the gap again")
 local status2=c:add(o,"status",{text="Status",active=true},true)
 c:cancel(three);assert(c:step(1,fits)==nil and c:step(2.1,fits)==status2,"a status line waits for the gap too")
 status2.tapped=true;c:step(9,fits,true);assert(c:step(0,fits)==status2 and not status2.tapped,"a tapped status line just stays")
 local four=c:add(o,"four",{text="Four"})
 assert(c:step(2.9,fits)==status2 and not four.shown,"its card just closed: a new notice waits out the gap")
 assert(c:step(.2,fits)==four,"then the notice takes the status line's place")
 return{passed=19}
end
