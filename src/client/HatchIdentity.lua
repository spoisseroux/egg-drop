-- Presentation disclosure only. Never infers ownership or accepts a receipt.
local Identity={}
function Identity.ready(reveal,result)
 if not reveal or not result or reveal.resultId~=result.id then return false end
 local c=reveal.cinematic
 if not c or c.presented~=true or not c.getPresentationState then return false end
 local state=c:getPresentationState()
 return state.resultId==result.id and state.receiptReady==true
end
return table.freeze(Identity)
