-- Separate charm writer: delayed responses cannot disable another pet or clear newer work.
return function(client,parent)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent);local H=require(game.ReplicatedStorage.Shared.HueCatalog)
 local serial=0;local sent={};local intent=Intent.new({id=function()return "unused"end,send=function()error("No pigment writes")end})
 local view=View.new(parent,intent,{appearance=function()return{charmVisible=true,charmShape="dot"}end,charm=function(id,visible,shape,seq)
  if not seq then serial+=1;seq=serial end;local q={petId=id,visible=visible,shape=shape,seq=seq};table.insert(sent,q);return q
 end})
 local s={revision=1,status="Ready",inventoryMask=127,hueInventory={},petHues={}}
 for _,id in ipairs({"pip","puddle"})do s.petHues[id]={main=H.emptyCounts(),secondary=H.emptyCounts()}end
 local cases={};local ok,err=pcall(function()
  view:open(s,"charm","pip");assert(view:toggleCharm());local old=sent[#sent];view:close("back");view:open(s,"charm","puddle")
  assert(view:toggleCharm());local puddle=sent[#sent]
  assert(view:charmResult({petId="pip",seq=old.seq,shape="dot",visible=false,status="Saved"}));assert(not view.charmRequests.pip and view.charmRequests.puddle)
  assert(view:charmResult({petId="puddle",seq=puddle.seq,shape="dot",visible=false,status="Saved"}));table.insert(cases,"closed switched-pet delayed acknowledgment clears only its captured pet")
  view:open(s,"charm","pip");assert(view:toggleCharm());local current=sent[#sent]
  assert(not view:charmResult({petId="pip",seq=old.seq,shape="dot",visible=false,status="Saved"}));assert(view.charmRequests.pip.seq==current.seq);table.insert(cases,"duplicate old Saved packet cannot clear a newer same-pet request")
  view.charmRequests.pip.retry=true;assert(view:toggleCharm());local retry=sent[#sent];assert(retry.seq==current.seq and retry.petId==current.petId and retry.visible==current.visible and retry.shape==current.shape)
  assert(view:charmResult({petId="pip",seq=current.seq,status="Rejected",reason="Throttled"}));assert(not view.charmRequests.pip and view:toggleCharm());table.insert(cases,"explicit retry preserves exact payload and rejection releases the next choice")
 end)
 view:destroy();assert(ok,err);return cases
end
