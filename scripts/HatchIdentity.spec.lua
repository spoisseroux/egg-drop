return function(client)
 local Identity=require(client.HatchIdentity);local state={resultId="one",receiptReady=false}
 local c={presented=false,getPresentationState=function()return state end}
 local reveal={resultId="one",cinematic=c};local result={id="one"}
 assert(not Identity.ready(reveal,result));state.receiptReady=true;assert(not Identity.ready(reveal,result),"unpresented loading scene leaked identity")
 c.presented=true;assert(Identity.ready(reveal,result),"settled presented receipt remained mysterious")
 assert(not Identity.ready(reveal,{id="two"}),"new result inherited old disclosure")
 state.resultId="two";assert(not Identity.ready(reveal,result),"cinematic receipt mismatch ignored")
 state.resultId="one";state.receiptReady=false;assert(not Identity.ready(reveal,result),"intro inherited ready identity")
 return{passed=3}
end
