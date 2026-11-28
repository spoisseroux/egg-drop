-- Angel Wings (ROTATION-2-BRIEF 3, ARCH-REVIEW-ROTATION-2 2 and 3): the Outfit Egg's rare Back item, drawn with no new
-- art. Lane A's data: `angelwings`, an egg-only base (WearableCatalog.forPet(pet, math.huge).byId.angelwings: slot Back,
-- egg=true, rarity legendary, finish "sparkle", never sold) and its attachment rows on Back in the Bear's rig (the Bunny
-- inherits them), pointing at the stage 5 wing meshes (WingL_S5 / WingR_S5: a row's `template`, else its `name`).
-- This module holds the look's numbers and pure rules; PetAttachments.build draws it:
--   wings  Snow #F4F6FB, SmoothPlastic, 1.25x about their own WingL / WingR root; the existing gentle idle flap
--          (PetIdleMotion.wings, by the rows' WingL / WingR anchor); the sparkle finish (WearableFinish) on each wing,
--          from the BASE row's finish (no variant tint), garden pets only.
--   halo   a true ring of 8 short cylinders (radius .13, tube .022) .12 over the head top (HatCrown; .28 with a Hat on),
--          #FFE08A SmoothPlastic, Reflectance .15, bobbing +-.02 on a 3 s sine. Never Neon, no light, no Highlight.
-- Grown wings hide while it is worn (PetAttachmentRules: a Back wearable occupies the wings feature's slot).
-- Reduced Motion / Motion: Low: no flap, no bob, the still sparkle (WearableFinish). Previews (ViewportFrames) are posed
-- once: still parts, the pet turned 35 degrees and the camera pulled back 15% so the wings read.
-- Every number is a [PLACEHOLDER] until Fable reviews real renders.
local Wings={}
Wings.Id="angelwings"
Wings.Snow="#F4F6FB"
-- Per item: the look the client adds over the rig rows. Keyed by item id; only egg-only bases are here.
Wings.Looks=table.freeze({
 angelwings=table.freeze({scale=1.25,color="#F4F6FB",halo=true,finish="sparkle"}),
})
Wings.Halo=table.freeze({segments=8,radius=.13,tube=.022,lift=.12,hatLift=.28,color="#FFE08A",reflectance=.15,bob=.02,period=3,
 -- Each segment is a touch longer than its chord so the ring reads closed (no gaps at the joints).
 overlap=1.08})
Wings.Preview=table.freeze({yaw=-math.rad(35),pull=1.15})

-- Pure: the client look for an item id, or nil.
function Wings.look(itemId)
 return if type(itemId)=="string"then Wings.Looks[itemId]else nil
end
-- Pure: the mesh a rig row clones from the attachment template (lane A's rows may name the shared stage 5 mesh).
function Wings.templateName(row)
 if type(row)~="table"then return nil end
 return if type(row.template)=="string"and row.template~=""then row.template else row.name
end
-- Pure: `frame` (rig space) scaled by `k` about `root` (a Vector3, the wing's own anchor): the root stays put, the
-- rotation is kept, the reach grows by k.
function Wings.scaleAbout(frame,root,k)
 if typeof(root)~="Vector3"or type(k)~="number"or k==1 then return frame end
 local p=frame.Position
 return CFrame.new(root+(p-root)*k)*frame.Rotation
end
-- Pure: the halo's lift over the head top: .28 when a Hat shows in `resolved` (PetAttachmentRules.resolve), else .12.
function Wings.haloLift(resolved)
 for _,a in ipairs(type(resolved)=="table"and resolved.show or {})do
  if a.slot=="Hat"and a.item then return Wings.Halo.hatLift end
 end
 return Wings.Halo.lift
end
-- Pure: the ring's segments about its centre, scaled by `scale`: {frame=CFrame, size=Vector3} each, a Cylinder part
-- (its axis is X) laid along the ring's tangent in the horizontal plane.
function Wings.haloSegments(scale)
 scale=if type(scale)=="number"and scale>0 then scale else 1
 local H=Wings.Halo
 local n=H.segments
 local chord=2*H.radius*math.sin(math.pi/n)
 local result={}
 for i=0,n-1 do
  local theta=(i+.5)*2*math.pi/n
  local position=Vector3.new(H.radius*math.cos(theta),0,H.radius*math.sin(theta))*scale
  -- Turn the X axis onto the tangent (-sin, 0, cos): a turn of -(theta + pi/2) about Y.
  table.insert(result,{frame=CFrame.new(position)*CFrame.Angles(0,-(theta+math.pi/2),0),
   size=Vector3.new(chord*H.overlap,H.tube*2,H.tube*2)*scale})
 end
 return result
end
-- Pure: the halo's bob (rig studs at garden size, before the pet's scale) at time `t`: +-.02 on a 3 s sine; 0 reduced.
function Wings.haloBob(t,reduced)
 if reduced==true then return 0 end
 t=if type(t)=="number"and t==t then t else 0
 return Wings.Halo.bob*math.sin(2*math.pi*t/Wings.Halo.period)
end
-- Pure: the finish row (WearableFinish's shape: finish, color, finishHexes) for a BASE item that carries one, or nil.
-- `item`: the catalogue's row (lane A: forPet(pet, math.huge).byId[id]); a variant's finish comes from its tint instead.
-- An egg-only base without a catalogue finish takes the client look's (so the sparkle never depends on one field).
-- The still colour: the item's `color`, else the look's, else `fallback` (the piece's own hex), else Snow.
function Wings.finishRow(item,itemId,fallback)
 local look=Wings.look(itemId or(type(item)=="table"and item.id))
 local finish=type(item)=="table"and item.variant~=true and item.finish or(look and look.finish)
 if type(finish)~="string"then return nil end
 local color=type(item)=="table"and type(item.color)=="string"and item.color or(look and look.color)or(type(fallback)=="string"and fallback)or Wings.Snow
 return {id=itemId or(type(item)=="table"and item.id),finish=finish,color=color,finishHexes=type(item)=="table"and item.finishHexes or nil}
end
-- Pure: does this wearables map wear an item with a look (a slot key -> item id map, variant ids included)?
function Wings.wears(wearables)
 for _,id in pairs(type(wearables)=="table"and wearables or {})do if Wings.look(id)then return true end end
 return false
end
-- Pure: the preview pose for an appearance (its wearables): {yaw, pull} when it wears Angel Wings, else nil.
function Wings.previewPose(appearance)
 local wearables=type(appearance)=="table"and appearance.wearables or nil
 return if Wings.wears(wearables)then Wings.Preview else nil
end
-- Pure: a slot tab's cards without the egg-only bases the pet does not own. An egg-only base (no colours, never sold)
-- is a card only once owned, so the Back tab appears only for a pet that owns a Back item (ROTATION-2-BRIEF 3).
function Wings.ownedOnly(items,owned)
 local mine={};for _,id in ipairs(type(owned)=="table"and owned or {})do mine[id]=true end
 local result={}
 for _,item in ipairs(items or {})do
  local eggBase=type(item)=="table"and item.egg==true and item.variant~=true
  if not eggBase or mine[item.id]then table.insert(result,item)end
 end
 return result
end

-- Runtime (client): the halo's bob on garden pets. tracked: visual -> {entries}; each entry keeps its rest frame
-- (`haloRest`) and the stepper writes `frame` (the renderer poses every piece from it). The same tick marks the visual
-- `wingsStill` under Reduced Motion or Motion: Low, which rests the flap (PetIdleMotion.wings). Viewport pets are never
-- tracked: they stay posed once.
local tracked=setmetatable({},{__mode="k"})
local connection=nil
-- now, global (optional, the specs): the clock and the game-wide reduced flag; by default os.clock() and
-- WearableFinish.reducedNow() (Reduced Motion or Motion: Low).
local function step(now,global)
 if global==nil then global=require(script.Parent.WearableFinish).reducedNow()end
 now=if type(now)=="number"then now else os.clock()
 local any=false
 for visual,record in pairs(tracked)do
  local alive=not visual.destroyed and record.entries[1]~=nil and record.entries[1].part.Parent~=nil
  if not alive then tracked[visual]=nil;visual.wingsStill=nil
  else
   any=true
   local reduced=global or visual.reducedEffects==true
   visual.wingsStill=global or nil
   local lift=Wings.haloBob(now+record.seed,reduced)*(visual.scale or 1)
   for _,entry in ipairs(record.entries)do entry.frame=CFrame.new(0,lift,0)*entry.haloRest end
  end
 end
 if not any and connection then connection:Disconnect();connection=nil end
end
Wings.step=step
-- PetAttachments.build: the halo pieces of one visual. Only a garden pet (worldContext) bobs.
function Wings.track(visual,entries)
 if type(visual)~="table"or visual.worldContext~=true or #entries==0 then return false end
 for _,entry in ipairs(entries)do entry.haloRest=entry.frame end
 tracked[visual]={entries=entries,seed=((visual.cosmeticSeed or 0)%97)/97*Wings.Halo.period}
 if not connection then
  local RunService=game:GetService("RunService")
  if RunService:IsClient()then connection=RunService.Heartbeat:Connect(function()step()end)end
 end
 return true
end
function Wings.count()local n=0;for _ in pairs(tracked)do n+=1 end;return n end
return Wings
