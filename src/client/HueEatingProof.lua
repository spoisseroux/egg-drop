-- A presentation token for an outstanding visible use, never a save authority.
local Hues=require(game:GetService("ReplicatedStorage").Shared.HueCatalog)
local Proof={};Proof.__index=Proof
local function equal(a,b)
 if type(a)~="table"or type(b)~="table"then return false end
 for _,id in ipairs(Hues.Order)do local key=if type(id)=="table"then id.id else id;if(a[key]or 0)~=(b[key]or 0)then return false end end
 return true
end
function Proof.new()return setmetatable({seen={}},Proof)end
function Proof:capture(p,state,binding)
 if not p or p.action~="hueUse"or p.value.itemId=="reset"or not Hues.ById[p.value.itemId]or self.seen[p.value.id]then return false end
 local q=p.value;local stock=(state.hueInventory or {})[q.itemId]or 0
 if type(q.counts)~="table"or stock<1 or(q.counts[q.itemId]or 0)>=5 then return false end
 self.pending={id=q.id,petId=q.petId,itemId=q.itemId,channel=q.channel,counts=table.clone(q.counts),stock=stock,resultId=q.pendingResultId,revision=p.revision,binding=binding}
 return true
end
function Proof:cancel()self.pending=nil end
function Proof:take(receipt,state,binding)
 local p=self.pending;if not p or self.seen[p.id]then return nil end
 if binding~=p.binding then self:cancel();return nil end
 if type(receipt)~="table"or receipt.id~=p.id then return nil end
 if receipt.action~="hueUse"or receipt.outcome~="Applied"or receipt.cost~=0 or receipt.catalogVersion~=Hues.CatalogVersion
  or receipt.petId~=p.petId or receipt.itemId~=p.itemId or receipt.channel~=p.channel or receipt.acknowledgedResultId~=p.resultId
  or type(receipt.revision)~="number"or receipt.revision<=p.revision or(state.revision or -1)<receipt.revision
  or receipt.inventoryBefore~=p.stock or receipt.inventoryAfter~=p.stock-1 or not equal(receipt.countsBefore,p.counts)then return nil end
 local after=table.clone(p.counts);after[p.itemId]=(after[p.itemId]or 0)+1
 local saved=state.petHues and state.petHues[p.petId];local stock=(state.hueInventory or {})[p.itemId]or 0
 if not equal(receipt.countsAfter,after)or not saved or not equal(saved[p.channel],after)or stock~=p.stock-1 then return nil end
 self.pending=nil;self.seen[p.id]=true
 return {id=p.id,petId=p.petId,itemId=p.itemId,channel=p.channel,revision=receipt.revision,binding=p.binding}
end
return Proof
