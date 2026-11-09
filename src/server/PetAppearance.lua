-- Per-owned-pet charm preference. No wallet, inventory or hatch mutation.
local Appearance={Ids={"pip","puddle","wick","orbit","bloom_pip","foxfire_wick","eclipse_orbit"}}
local Hue=require(game:GetService("ReplicatedStorage").Shared.HueCatalog)
local Charms=require(game:GetService("ReplicatedStorage").Shared.PetCharmCatalog)
local supported=Hue.Supported
local function stamp(n)return if type(n)=="number"and n==n and n%1==0 and n>=0 and n<=9007199254740000 then n else 0 end
local function valid(entry)
 return type(entry)=="table"and type(entry.charmVisible)=="boolean"and(entry.charmShape==nil or Charms.validStored(entry.charmShape))and stamp(entry.at)==entry.at and type(entry.writer)=="string"and #entry.writer<=128
end
local function shape(entry)return if entry and entry.charmShape then entry.charmShape else Charms.Default end
function Appearance.decode(value)
 local result={}
 for _,id in ipairs(Appearance.Ids)do
  local entry=type(value)=="table"and value[id]
  if valid(entry)then result[id]=table.clone(entry);result[id].charmShape=shape(entry)end
 end
 return result
end
function Appearance.visible(profile,id)
 local entry=profile.petAppearance and profile.petAppearance[id]
 return if entry then entry.charmVisible else true
end
function Appearance.shape(profile,id)return shape(profile.petAppearance and profile.petAppearance[id])end
function Appearance.public(profile,hues,petHues,petMaterials)
 -- Public attributes and garden snapshots use only storage-confirmed choices.
 -- The desired map remains private while a write is pending or retrying.
 local result={}
 for _,id in ipairs(Appearance.Ids)do
  local entry=profile.petAppearanceSaved and profile.petAppearanceSaved[id]
  result[id]=Hue.appearance(hues,id,petHues)
  result[id].charmVisible=if valid(entry)then entry.charmVisible else true
  result[id].charmShape=if valid(entry)then shape(entry)else Charms.Default
  result[id].finish=if type(petMaterials)=="table"then petMaterials[id]or "standard"else "standard"
 end
 return result
end
function Appearance.merge(previous,changes)
 local result=if type(previous)=="table"then table.clone(previous)else {}
 for id,candidate in pairs(changes)do
  local old=result[id]
  if supported[id]and(not valid(old)or candidate.at>old.at or(candidate.at==old.at and candidate.writer>=old.writer))then
   local entry=if type(old)=="table"then table.clone(old)else {}
   entry.charmVisible,entry.charmShape,entry.at,entry.writer=candidate.visible,candidate.shape or Charms.Default,candidate.at,candidate.writer
   result[id]=entry
  end
 end
 return result
end
function Appearance.matches(entry,candidate)
 return valid(entry)and shape(entry)==(candidate.shape or Charms.Default)and entry.charmVisible==candidate.visible and entry.at==candidate.at and entry.writer==candidate.writer
end
function Appearance.newer(entry,candidate)
 if valid(entry)and(entry.at>candidate.at or(entry.at==candidate.at and entry.writer>candidate.writer))then
  local copy=table.clone(entry);copy.charmShape=shape(entry);return copy
 end
 return nil
end
function Appearance.new(options)
 return{revision=0,requests={},lastAt=-math.huge,lastMalformed=-math.huge,selectionsEnabled=if options and options.selectionsEnabled~=nil then options.selectionsEnabled==true else Charms.SelectionsEnabled==true}
end
local function packet(state,profile,id,seq,status,reason)
 return{petId=id,visible=if supported[id]then Appearance.visible(profile,id)else true,shape=if supported[id]then Appearance.shape(profile,id)else Charms.Default,seq=seq,status=status,reason=reason,revision=state.revision,lastSeq=state.requests[id]and state.requests[id].seq or 0}
end
function Appearance.request(state,profile,value,now,usable,owns,apply)
 if type(value)~="table"or not supported[value.petId]or type(value.visible)~="boolean"or(value.shape~=nil and not Charms.known(value.shape))or(value.shapeVersion~=nil and(value.shapeVersion~=Charms.Version or value.shape==nil))or type(value.seq)~="number"or value.seq~=value.seq or value.seq%1~=0 or value.seq<1 or value.seq>2147483647 then
  if now-state.lastMalformed<.25 then return nil,false end;state.lastMalformed=now
  return packet(state,profile,"",0,"Rejected","Malformed"),false
 end
 local id,seq=value.petId,value.seq;local previous=state.requests[id]
 if previous and seq<=previous.seq then
  if seq==previous.seq and value.visible==previous.visible and value.shape==previous.wireShape and value.shapeVersion==previous.wireShapeVersion then return previous.result,false end
  return packet(state,profile,id,seq,"Rejected",if seq==previous.seq then "SeqConflict"else "Stale"),false
 end
 local reason=if usable~=true then(if type(usable)=="string"then usable else "Unavailable")elseif not owns(id)then "Unowned"else nil
 local selection=value.shapeVersion==Charms.Version
 if not reason and value.shape~=nil and value.shape~=Charms.Default and not selection then reason="ShapeVersionRequired"end
 if not reason and selection and not state.selectionsEnabled then reason="SelectionsDisabled"end
 -- v274 Hide/Show sent Dot unconditionally. Unmarked Dot/nil are visibility-only;
 -- only a marked selection may change the durable shape, including an explicit Dot.
 local selectedShape=if selection then value.shape else nil
 local requestedShape=selectedShape or Appearance.shape(profile,id)
 if not reason and now-state.lastAt<.25 then local result=packet(state,profile,id,seq,"Rejected","Throttled");result.retryAfter=.25-(now-state.lastAt);return result,false end
 local changed=false
 if not reason then
  if Appearance.visible(profile,id)~=value.visible or Appearance.shape(profile,id)~=requestedShape then apply(profile,id,value.visible,selectedShape);state.revision+=1;changed=true end
  state.lastAt=now
 end
 local pending=profile.petAppearanceChanges and profile.petAppearanceChanges[id]
 local status=if reason then "Rejected"elseif pending then "Applied"else "Saved"
 local entry={seq=seq,visible=value.visible,shape=requestedShape,wireShape=value.shape,wireShapeVersion=value.shapeVersion,generation=if pending then pending.generation else(profile.petAppearanceGeneration or 0)}
 state.requests[id]=entry;entry.result=packet(state,profile,id,seq,status,reason)
 return entry.result,changed
end
function Appearance.saved(state,profile,candidate)
 local entry=state.requests[candidate.petId]
 if entry and entry.result.status=="Applied"and entry.generation<=candidate.generation and entry.visible==candidate.visible and entry.shape==(candidate.shape or Charms.Default)and Appearance.visible(profile,candidate.petId)==entry.visible and Appearance.shape(profile,candidate.petId)==entry.shape then
  entry.result=packet(state,profile,candidate.petId,entry.seq,"Saved");return{entry.result}
 end
 return{}
end
function Appearance.superseded(state,profile,candidate)
 local entry=state.requests[candidate.petId];state.revision+=1
 if entry and entry.result.status=="Applied"and entry.generation<=candidate.generation then
  entry.result=packet(state,profile,candidate.petId,entry.seq,"Rejected","Superseded");return{entry.result}
 end
 return{}
end
Appearance.supported=supported
return Appearance
