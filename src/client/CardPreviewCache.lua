-- QA v2 R4.3: card previews for Customize ("no previews for anything"). The Wardrobe
-- card-preview pattern (QA Q2.3) as a reusable owner: each visible card shows the pet
-- with that colour / finish / toy in its own ViewportFrame. Built lazily (at most one
-- per pump, visible cards only), cached by key while the screen is open, at most
-- `live` previews on cards at once; a card scrolled off screen gives its viewport up
-- and, past `size` cached entries, the least recently shown detached one is destroyed.
-- The card's colour tile stays as the fallback when a rig cannot be built.
-- Previews are posed once and never animate (cheap, and calm under Reduced Motion).
local Factory=require(script.Parent.PetFactory)
local Bounds=require(script.Parent.PetRigBounds)
local Cache={Live=8,Size=16}
Cache.__index=Cache

-- Pure: is a card (top y, height) inside the scroll window (top y, height), with a margin.
function Cache.visible(cardY,cardH,windowY,windowH)
 return cardY+cardH>=windowY-8 and cardY<=windowY+windowH+8
end
-- Pure: a stable key for one card's look (pet, card id and the appearance it shows).
local function serialize(value,depth)
 if type(value)~="table"then return tostring(value)end
 if depth>4 then return "{}"end
 local keys={};for k in pairs(value)do table.insert(keys,tostring(k))end;table.sort(keys)
 local parts={}
 for _,k in ipairs(keys)do
  local v=value[k];if v==nil then v=value[tonumber(k)]end
  table.insert(parts,k.."="..serialize(v,depth+1))
 end
 return "{"..table.concat(parts,",").."}"
end
function Cache.key(petId,cardId,appearance)
 return tostring(petId)..":"..tostring(cardId)..":"..serialize(appearance or {},0)
end

-- options: live, size
function Cache.new(options)
 options=options or {}
 return setmetatable({live=options.live or Cache.Live,size=options.size or Cache.Size,entries={},count=0,attached={}},Cache)
end

local function frame(entry)
 local v=entry.visual;if not v or v.destroyed then return end
 v.yaw=-.35;v.reducedEffects=true;v.poseDirty=true;v:update(0)
 entry.rig=v.rigRevision
 local box,size=Bounds.get(v)
 local half=math.tan(math.rad(entry.camera.FieldOfView/2))
 local distance=(math.max(size.Y,size.X)*.5/half+size.Z*.5+.3)*(entry.zoom or .95)
 local center=box.Position
 entry.camera.CFrame=CFrame.lookAt(center+Vector3.new(0,.1,distance),center)
end
-- Builds one pet preview (or false when the rig cannot be built). decorate(world,
-- visual) may add a prop beside the posed pet (a toy) and return a handle with :destroy().
function Cache.buildPet(pet,appearance,zoom,decorate)
 if not pet then return false end
 local viewport=Instance.new("ViewportFrame");viewport.Name="CardPreview";viewport.BackgroundTransparency=1;viewport.Size=UDim2.fromScale(1,1)
 viewport.Ambient=Color3.fromRGB(175,184,183);viewport.LightColor=Color3.fromRGB(255,250,231);viewport.LightDirection=Vector3.new(-1,-1.4,-3)
 local world=Instance.new("WorldModel");world.Parent=viewport
 local camera=Instance.new("Camera");camera.FieldOfView=30;camera.Parent=viewport;viewport.CurrentCamera=camera
 local ok,visual=pcall(Factory.new,world,Vector3.zero,pet,nil,appearance)
 if not ok or not visual then viewport:Destroy();return false end
 local entry={viewport=viewport,camera=camera,visual=visual,zoom=zoom}
 if not pcall(frame,entry)then visual:destroy();viewport:Destroy();return false end
 if decorate then local ok2,handle=pcall(decorate,world,visual);if ok2 then entry.extra=handle end end
 return entry
end

local function destroyEntry(entry)
 if entry.extra then pcall(function()entry.extra:destroy()end)end
 if entry.visual and not entry.visual.destroyed then entry.visual:destroy()end
 entry.viewport:Destroy()
end
-- One holder loses its preview (the entry stays cached).
function Cache:detach(holder)
 local key=self.attached[holder];if not key then return end
 self.attached[holder]=nil
 local entry=self.entries[key]
 if entry then entry.viewport.Parent=nil;entry.shownAt=os.clock();entry.holder=nil end
 if holder.Parent then holder:SetAttribute("Preview",nil)end
 if self.onDetach then self.onDetach(holder)end
end
function Cache:detachAll()for holder in pairs(table.clone(self.attached))do self:detach(holder)end end
function Cache:evict()
 local oldestKey,oldest=nil,nil
 for key,entry in pairs(self.entries)do
  if entry and entry.viewport.Parent==nil and(oldest==nil or(entry.shownAt or 0)<(oldest.shownAt or 0))then oldestKey,oldest=key,entry end
 end
 if not oldest then return false end
 destroyEntry(oldest);self.entries[oldestKey]=nil;self.count-=1
 return true
end
function Cache:clear()
 self:detachAll()
 for _,entry in pairs(self.entries)do if entry then destroyEntry(entry)end end
 self.entries,self.count={},0
end
function Cache:liveCount()local n=0;for _ in pairs(self.attached)do n+=1 end;return n end

-- cards: {{holder=Frame, key=string, visible=bool, build=function()->entry|false}}.
-- Holders not listed (or not visible) give their preview up; cached entries attach at
-- once; at most one missing entry is built per call. onAttach(holder, entry) lets the
-- owner hide what the preview replaces.
function Cache:pump(cards,onAttach)
 local wanted={}
 for _,card in ipairs(cards)do if card.visible then wanted[card.holder]=card.key end end
 for holder,key in pairs(table.clone(self.attached))do
  if wanted[holder]~=key or not holder.Parent then self:detach(holder)end
 end
 local now=os.clock();local built=false
 for _,card in ipairs(cards)do
  if card.visible then
   local holder,key=card.holder,card.key
   local entry=self.entries[key]
   if self.attached[holder]==key then
    if entry then entry.shownAt=now
     local v=entry.visual
     if v and not v.destroyed and v.rigRevision~=entry.rig then pcall(frame,entry)end
    end
   elseif self:liveCount()<self.live and entry~=false then
    if entry==nil and not built then
     while self.count>=self.size and self:evict()do end
     if self.count<self.size then
      built=true
      entry=card.build();self.entries[key]=entry
      if entry then self.count+=1 end
     end
    end
    if entry and entry.viewport.Parent==nil then
     entry.viewport.ZIndex=holder.ZIndex+1;entry.viewport.Parent=holder;entry.shownAt=now;entry.holder=holder
     self.attached[holder]=key;holder:SetAttribute("Preview",true)
     if onAttach then onAttach(holder,entry)end
    end
   end
  end
 end
end

return Cache
