-- Separate charm writer: delayed responses cannot disable another pet or clear newer work.
return function(client,parent)
 local View=require(client.HueEggView);local Intent=require(client.HueIntent);local H=require(game.ReplicatedStorage.Shared.HueCatalog)
 local serial=0;local sent={};local timeouts={};local savedShape="dot";local shapesEnabled=false;local intent=Intent.new({id=function()return "unused"end,send=function()error("No pigment writes")end})
 local view=View.new(parent,intent,{delay=function(seconds,run)assert(seconds==8);table.insert(timeouts,run)end,appearance=function()return{charmVisible=true,charmShape=savedShape}end,shapeSelectionsEnabled=function()return shapesEnabled end,charm=function(id,visible,shape,seq,shapeVersion)
  if not seq then serial+=1;seq=serial end;local q={petId=id,visible=visible,shape=shape,shapeVersion=shapeVersion,seq=seq};table.insert(sent,q);return q
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
  view.charmRequests.pip.retry=true;assert(view:toggleCharm());local retry=sent[#sent];assert(retry.seq==current.seq and retry.petId==current.petId and retry.visible==current.visible and retry.shape==current.shape and retry.shapeVersion==current.shapeVersion)
  assert(view:charmResult({petId="pip",seq=current.seq,status="Rejected",reason="Throttled"}));assert(not view.charmRequests.pip and view:toggleCharm());table.insert(cases,"explicit retry preserves exact payload and rejection releases the next choice")
  view:charmResult({petId="pip",seq=sent[#sent].seq,status="Rejected"});view:open(s,"charm","pip")
  assert(not view:selectCharm("ring")and not view.shapes.ring.Visible,"rollout gate bypass")
  savedShape="future_spiral";assert(view:toggleCharm());local opaque=sent[#sent];assert(opaque.shape==nil and opaque.shapeVersion==nil,"visibility overwrote unknown shape")
  view.charmRequests.pip.retry=true;assert(view:toggleCharm());assert(sent[#sent].shape==nil and sent[#sent].seq==opaque.seq)
  assert(view:charmResult({petId="pip",seq=opaque.seq,visible=false,shape="future_spiral",status="Saved"}));table.insert(cases,"closed rollout and opaque saved shape survive visibility/retry")
  shapesEnabled=true;view:refresh();assert(view:selectCharm("ring"));local ring=sent[#sent];assert(ring.shape=="ring"and ring.shapeVersion==2 and ring.visible==true)
  assert(not view:charmResult({petId="pip",seq=ring.seq,visible=true,shape="dot",status="Saved"}))
  assert(view:charmResult({petId="pip",seq=ring.seq,visible=true,shape="ring",status="Saved"}));table.insert(cases,"enabled explicit shape captures complete pair and rejects mismatched saved acknowledgment")
  savedShape="ring";view:refresh();assert(view:selectCharm("dot"));local dot=sent[#sent];assert(dot.shape=="dot"and dot.shapeVersion==2)
  view.charmRequests.pip.retry=true;assert(view:toggleCharm());local markedRetry=sent[#sent]
  assert(markedRetry.seq==dot.seq and markedRetry.shape=="dot"and markedRetry.shapeVersion==2 and markedRetry.visible==dot.visible)
  assert(view:charmResult({petId="pip",seq=dot.seq,visible=true,shape="dot",status="Saved"}));table.insert(cases,"explicit Dot remains a marked v2 selection through exact captured retry")
  savedShape="pebble";view:refresh();assert(view:toggleCharm());local visibility=sent[#sent]
  assert(visibility.shape==nil and visibility.shapeVersion==nil and visibility.visible==false)
  assert(view:charmResult({petId="pip",seq=visibility.seq,visible=false,shape="pebble",status="Saved"}));table.insert(cases,"modern visibility-only intent omits selection protocol and retains the saved nondefault pair")
  assert(not view.status.Visible and not view.charmMessage,"successful charm left a Saved status")
  assert(view:toggleCharm());local waiting=sent[#sent];local beforeApplied=timeouts[#timeouts]
  assert(view:charmResult({petId="pip",seq=waiting.seq,status="Applied"}));local afterApplied=timeouts[#timeouts]
  beforeApplied();assert(not view.charmRequests.pip.retry,"healthy Applied reused an expired retry timer")
  afterApplied();assert(view.charmRequests.pip.retry and view:toggleCharm());assert(sent[#sent].seq==waiting.seq and sent[#sent].visible==waiting.visible)
  assert(view:charmResult({petId="pip",seq=waiting.seq,visible=false,shape="pebble",status="Saved"}));timeouts[#timeouts]();assert(not view.charmRequests.pip and not view.status.Visible)
  table.insert(cases,"healthy Applied extends bounded wait and actual timeout retries exact pair without success copy")
 end)
 view:destroy();assert(ok,err);return cases
end
