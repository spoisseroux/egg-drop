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
 return{passed=8}
end
