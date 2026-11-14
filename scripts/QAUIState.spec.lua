return function(client)
 local Price=require(client.ShopPriceState);local Feedback=require(client.PreviewFeedback);local Row=require(client.FocusRow)
 for _,cost in ipairs({0,8,12,80})do
  for _,balance in ipairs({0,7,8,11,12,79,80,100})do
   assert(Price.shortfall(cost,balance)==math.max(0,cost-balance))
   assert((Price.need(cost,balance)=="")== (balance>=cost))
  end
 end
 for _,width in ipairs({320,390,640,812,1280})do for _,pickup in ipairs({false,true})do
  local g=Row.layout(width,190,pickup)
  assert(g.back.h==48 and g.pickup.h==48 and g.bond.h==48 and g.bond.w>=150 and g.bond.w<=190)
  assert(g.bond.x>=g.back.x+g.back.w+8 and g.bond.x+g.bond.w<=width-12)
  if pickup then assert(g.bond.x+g.bond.w+8==g.pickup.x)end
 end end
 local f=Feedback.new(function()return 0 end);local v={expression="neutral",greet=function(self)self.greeting=0 end}
 assert(f:step(0,true,v)==nil and f:step(6.99,true,v)==nil)
 assert(f:step(7,true,v)=="wave"and v.greeting==0)
 f:step(7.1,false,v);assert(v.greeting==2 and v.expression=="neutral","drag/reduced/close cancels owned cue")
 f:step(100,true,v);assert(f:step(106.9,true,v)==nil,"resume reschedules idle wait")
 assert(f:step(107,true,v)=="wave");v.expression="joy";f:cancel();assert(v.expression=="joy","foreign pose not overwritten")
 return{passed=4}
end
