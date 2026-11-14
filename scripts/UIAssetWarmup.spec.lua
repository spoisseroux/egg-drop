return function(client)
 local Warmup=require(client.UIAssetWarmup)
 local function fixture(options)
  local c={now=0,jobs={},active=0,peak=0}
  local q=Warmup.new({now=function()return c.now end,timeout=1,retryDelay=1,max=options and options.max,
   load=function(ids,done)
    c.active+=1;c.peak=math.max(c.peak,c.active)
    table.insert(c.jobs,{id=ids[1],finish=function(ok)c.active-=1;done(ok,if not ok then "fixture failure"else nil)end})
   end})
  return q,c
 end
 local q,c=fixture();local a,b=0,0
 q:request({"rbxassetid://1","rbxassetid://1"},function(ok)if ok then a+=1 end end)
 q:request({"rbxassetid://1"},function(ok)if ok then b+=1 end end)
 assert(#c.jobs==1,"one in-flight request per asset")
 c.jobs[1].finish(true);assert(a==1 and b==1,"both listeners receive exact resource")
 q:request({"rbxassetid://1"},function(ok)assert(ok);a+=1 end);assert(#c.jobs==1 and a==2,"warm cache synchronous")
 local calls=0;local ticket=q:request({"rbxassetid://2"},function()calls+=1 end);ticket:cancel();c.jobs[2].finish(true);assert(calls==0,"route generation cancellation")
 q,c=fixture();local timeouts=0
 q:request({"rbxassetid://3","rbxassetid://4","rbxassetid://5"},function(ok)if not ok then timeouts+=1 end end)
 assert(#c.jobs==2 and c.peak==2,"concurrency cap")
 c.now=2;q:step();assert(timeouts==1 and c.active==2,"timeout keeps real engine calls in their slots")
 c.now=20;q:step();assert(#c.jobs==2,"hung loader cannot cause a retry storm")
 local retryId=c.jobs[1].id
 c.jobs[1].finish(true);c.jobs[2].finish(true)
 local retried=false
 q:retry({retryId},function(ok)retried=ok end)
 local retryJob;for i=3,#c.jobs do if c.jobs[i].id==retryId then assert(not retryJob,"duplicate explicit resource retry");retryJob=c.jobs[i]end end
 assert(retryJob and c.peak<=2,"explicit retry stays inside engine concurrency cap")
 retryJob.finish(true);assert(retried,"late old success cannot replace required fresh retry")
 q,c=fixture({max=1});local rejected=false
 q:request({"rbxassetid://6"},function()end)
 q:request({"rbxassetid://7"},function(ok,why)rejected=not ok and why=="ContentQueueFull"end)
 assert(rejected and #c.jobs==1,"bounded resource catalogue")
 local invalid=false;q:request({},function(ok)invalid=not ok end);assert(invalid,"empty batch fail closed")
 -- The real default path must preload typed ImageLabels, not raw URI strings.
 local function typed(mode)
  local e={jobs={},timers={},images={},now=0}
  local load,stats,stop
  load,stats,stop=Warmup.imageLoader({timeout=1,successStatus="Success",
   createImage=function(uri)
    local image={Image=uri,kind="ImageLabel",destroyed=false}
    function image:Destroy()assert(not self.destroyed,"image double destroyed");self.destroyed=true end
    table.insert(e.images,image);return image
   end,
   spawn=function(fn)table.insert(e.jobs,fn)end,
   schedule=function(_,fn)local t={run=fn};table.insert(e.timers,t);return t end,
   cancel=function(t)t.cancelled=true end,
   preload=function(items,callback)
    assert(#items==1 and type(items[1])=="table"and items[1].kind=="ImageLabel","raw URI preload regressed")
    if mode=="error"then error("fixture transport error")end
    if mode=="timeout"then e.timers[#e.timers].run();assert(e.q.queue.active==1 and stats.engineActive==1,"cleanup freed stalled engine slot")end
    callback(items[1].Image,if mode=="failure"then "Failure"else "Success")
   end})
  e.stats,e.stop=stats,stop;e.q=Warmup.new({load=load,now=function()return e.now end,timeout=1})
  return e
 end
 local e=typed("success");local cancelled,remaining=0,0
 local first=e.q:request({"rbxassetid://81"},function()cancelled+=1 end)
 e.q:request({"rbxassetid://81"},function(ok)if ok then remaining+=1 end end);first:cancel()
 assert(#e.jobs==1);e.jobs[1]();e.timers[1].run()
 assert(cancelled==0 and remaining==1 and e.images[1].destroyed and e.stats.destroyed==1 and e.stats.callbackSuccess==1,"shared typed image/cancel/success cleanup")
 e.stop()
 for _,mode in ipairs({"failure","error","timeout"})do
  e=typed(mode);local result,reason
  e.q:request({"rbxassetid://82"},function(ok,why)result,reason=ok,why end);e.jobs[1]()
  assert(result==false and reason and e.images[1].destroyed and e.stats.created==e.stats.destroyed and e.stats.engineActive==0,mode.." leaked image or fabricated success")
  if mode=="failure"then assert(e.stats.callbackFailure==1)elseif mode=="error"then assert(e.stats.errors==1)else assert(e.stats.timeoutCleanup==1 and e.stats.callbackSuccess==1,"late real success must not clear timeout")end
  e.stop()
 end
 local workers,timers,clock={},{},0
 local load,stats,stop=Warmup.imageLoader({timeout=1,successStatus="Success",
  createImage=function(uri)return{Image=uri,Destroy=function()end}end,
  spawn=function(fn)local co=coroutine.create(fn);table.insert(workers,co);assert(coroutine.resume(co))end,
  schedule=function(_,fn)local timer={run=fn};table.insert(timers,timer);return timer end,cancel=function(t)t.cancelled=true end,
  preload=function(items,callback)assert(type(items[1])=="table");coroutine.yield();callback(items[1].Image,"Success")end})
 q=Warmup.new({load=load,now=function()return clock end,timeout=1})
 q:request({"rbxassetid://91","rbxassetid://92","rbxassetid://93"},function()end)
 assert(stats.engineActive==2 and stats.enginePeak==2 and #workers==2,"typed engine calls exceed cap")
 clock=2;for _,timer in ipairs(timers)do timer.run()end;q:step()
 assert(stats.created==stats.destroyed and stats.engineActive==2 and #workers==2,"timeout cleanup released actual engine calls")
 for _,co in ipairs(workers)do assert(coroutine.resume(co))end
 assert(stats.engineActive==0 and stats.enginePeak==2,"typed engine slots did not drain")
 stop()
 return{passed=10}
end
