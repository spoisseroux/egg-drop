-- Real feedback/queue and native belt-chip instances; injected transport, no server writes.
return function(client)
 local Carousel=require(client.ItemCarousel);local Queue=require(client.NotificationQueue);local Kit=require(client.DeckKit)
 local cases={};local function test(name,run)run();table.insert(cases,name)end
 local owners={}
 local function fixture()
  local queue=Queue.new();local owner=Instance.new("Frame");owner.Name="_RailFeedbackOwner";table.insert(owners,owner)
  local chip=Instance.new("Frame");chip.Name="BeltChip";chip.Parent=owner
  local c=setmetatable({host=owner,chip=chip,noticeSerial=0,notifications={
   enqueue=function(host,key,data)return queue:add(host,key,data)end,
   cancelOwner=function(host)queue:cancelOwner(host)end}},Carousel)
  return c,queue,owner
 end
 local ok,problem=pcall(function()
 test("identical item grants preserve two independently timed queue entries",function()
  local c,q,owner=fixture();assert(c:showGrant("magnet")and c:showGrant("magnet"))
  assert(#q.items==2 and q.items[1].key~=q.items[2].key and q.items[1].owner==owner)
  local first=q:step(0,function()return true end);assert(first.data.text=="+ Magnet · From a star ball"and first.data.itemId=="magnet")
  assert(q:step(4,function()return true end)~=first and #q.items==1)
  if not Kit.reduced()then assert(c.chip:FindFirstChild("BoingScale"),"native grant did not exercise belt-chip boing")end
 end)
 test("empty and full feedback defer under narrow free space without owning a board widget",function()
  local c,q=fixture();assert(c:showNote(Carousel.EmptyNote)and c:showNote(Carousel.FullNote))
  assert(q:step(20,function()return false end)==nil and #q.items==2 and q.items[1].age==0)
  assert(q:step(0,function()return true end).data.text==Carousel.EmptyNote)
  assert(not c:showGrant("unknown")and #q.items==2)
 end)
 test("destroy removes queued feedback and rejects late grants and notes",function()
  local c,q,owner=fixture();c:showGrant("pop");c:showNote(Carousel.FullNote)
  c:destroy();assert(c.chip.Parent==nil and #q.items==0 and not c:showGrant("pop")and not c:showNote("late"))
  c:destroy();assert(#q.items==0)
 end)
 end)
 for _,owner in ipairs(owners)do owner:Destroy()end
 assert(ok,problem)
 return{passed=#cases,cases=cases}
end
