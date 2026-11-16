-- Original +Z-facing personal props, normalized to one pet body-height.
-- One builder per toy id (slice D, toy pool 2). A toy ships only when its builder exists
-- here AND its id is in ToyCatalog; Toys.has(id) is the render whitelist for every caller.
-- Toys v2 (QA v760, "this does not look like a bone"): each toy is real meshes, one per
-- colour, modelled in this same frame by scripts/build_pet_toys.py and cloned from
-- ReplicatedStorage.PetToyAssets (assets/toys/PetToyAssets.rbxmx). The sizes and centres
-- below are the manifest's (assets/art-source/toys/pet-toys-manifest.json). Round pieces
-- stay sphere primitives (PetPropGeometry). At most 12 parts a toy.
local Prop=require(script.Parent.PetPropGeometry)
local Replicated=game:GetService("ReplicatedStorage")
local Toys={}
local hex=Color3.fromHex
local indigo,brass,citrine=hex("#333C78"),hex("#C69A45"),hex("#F6D759")
local coral,cream,teal=hex("#EF786B"),hex("#FFF0C9"),hex("#3FB7B0")
-- The uploaded meshes arrive turned half a turn about Y; this faces them +Z again.
local faceFront=CFrame.Angles(0,math.pi,0)
-- One mesh part of a toy: `PetToyAssets.<toy id>__<name>` at `size`, centred on `at`.
-- Registered exactly like Prop:add, so pivot, play, the reveal and destroy treat it the
-- same. Without the asset pack, or while a template has no mesh yet (a MeshPart that Rojo
-- live sync created in Studio arrives with an empty MeshId until it is filled in Edit),
-- the part falls back to a plain sphere of the same size.
local function mesh(h,name,size,at,color)
 local pack=Replicated:FindFirstChild("PetToyAssets");local source=pack and pack:FindFirstChild(h.id.."__"..name)
 if not(source and source:IsA("MeshPart")and source.MeshId~="")then return h:add(name,size,CFrame.new(at),color,"sphere")end
 local p=source:Clone();p.Name=name
 p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.CastShadow=false;p.Material=Enum.Material.SmoothPlastic
 p.Color=color;p.Size=size*h.scale
 local cf=CFrame.new(at*h.scale)*faceFront
 p.CFrame=h.frame*cf;p.Parent=h.model
 table.insert(h.parts,p);table.insert(h.specs,{part=p,frame=cf,size=p.Size})
 if not h.model.PrimaryPart then h.model.PrimaryPart=p end
 return p
end
local V=Vector3.new
local builders={}
-- Sparkler: an indigo grip with a pommel, a brass ferrule and wire, and a spiky citrine
-- spark burst round the glowing tip. 4 parts.
builders.sparkler=function(h)
 mesh(h,"IndigoGrip",V(.06185,.15686,.048),V(-.01002,-.07843,0),indigo)
 mesh(h,"BrassWire",V(.05758,.18591,.058),V(-.00048,.07781,0),brass)
 mesh(h,"SparkBurst",V(.184,.184,.12),V(.02275,.18863,0),citrine)
 -- A glowing tip throws real sparks: one bounded emitter and a small light.
 local tip=h:add("GlowTip",V(.048,.048,.048),CFrame.new(.02275,.18863,0),hex("#FFF1B8"),"sphere")
 tip.Material=Enum.Material.Neon
 local s=h.scale
 local sparks=Instance.new("ParticleEmitter");sparks.Name="Sparks"
 sparks.Texture="rbxasset://textures/particles/sparkles_main.dds"
 sparks.Rate=40;sparks.Lifetime=NumberRange.new(.25,.55);sparks.Speed=NumberRange.new(s*.8,s*1.8)
 sparks.SpreadAngle=Vector2.new(180,180);sparks.Acceleration=Vector3.new(0,-s*7,0);sparks.Drag=2.5
 sparks.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,s*.14),NumberSequenceKeypoint.new(1,0)})
 sparks.Transparency=NumberSequence.new({NumberSequenceKeypoint.new(0,0),NumberSequenceKeypoint.new(1,.6)})
 sparks.Color=ColorSequence.new(Color3.fromHex("#FFF6C8"),Color3.fromHex("#FFA640"))
 sparks.LightEmission=1;sparks.LightInfluence=0;sparks.Rotation=NumberRange.new(0,360);sparks.ZOffset=.2
 sparks.Parent=tip
 local glow=Instance.new("PointLight");glow.Name="SparkGlow";glow.Color=Color3.fromHex("#FFD27A")
 glow.Range=math.max(2,s*3);glow.Brightness=.9;glow.Shadows=false;glow.Parent=tip
 h.tip,h.emitter,h.glow=tip,sparks,glow
end
-- Tennis ball (QA v735 H2): optic yellow-green felt (a true sphere) and the real one-piece
-- white seam, the closed curve that wraps the ball. From the front it shows as two arcs
-- bowing toward each other, and it still reads as a seam from the back and while it
-- rolls. 2 parts.
builders.ball=function(h)
 h:add("FeltBall",V(.24,.24,.24),CFrame.identity,hex("#D0E83A"),"sphere")
 mesh(h,"Seam",V(.2127,.2127,.21749),V(0,0,0),hex("#FCFBEF"))
end
-- Bone: the classic cartoon dog bone, a straight shaft with two round knobs on each end,
-- in one soft cream skin. 1 part.
builders.bone=function(h)
 mesh(h,"BoneBody",V(.30757,.15223,.0749),V(0,0,0),hex("#FFF1D6"))
end
-- Wobble Top: a fat teal body that tapers to a coral point, a cream belly band, a brass
-- stem and a citrine knob, the whole toy tilted 0.18 rad. 5 parts.
builders.wobble_top=function(h)
 mesh(h,"TealBody",V(.19704,.16681,.2),V(-.00157,-.00908,0),teal)
 mesh(h,"CreamEquator",V(.20491,.08625,.208),V(-.00157,.00841,0),cream)
 mesh(h,"CoralFoot",V(.03792,.04919,.03705),V(.01763,-.1033,0),coral)
 mesh(h,"BrassStem",V(.05059,.09078,.048),V(-.01386,.10442,0),brass)
 h:add("CitrineKnob",V(.062,.054,.062),CFrame.new(-.03008,.16529,0)*CFrame.Angles(0,0,.18),citrine,"sphere")
end
-- Squeaky Carrot: one plump tapered body with three shallow rings on a diagonal, a tuft
-- of three leaves at the fat end and a cream squeaker button on its side. 3 parts.
builders.squeaky_carrot=function(h)
 mesh(h,"CarrotBody",V(.17526,.21985,.096),V(.00617,.00029,0),hex("#FF8A3C"))
 mesh(h,"CarrotLeaves",V(.08982,.09999,.02942),V(.09636,.1315,0),hex("#58B368"))
 h:add("SqueakerDot",V(.025,.025,.014),CFrame.new(.02615,.03662,.042),cream,"sphere")
end
-- Pocket Deck (QA v685 R7): a tiny pill-shaped handheld in the deck's house colours. A
-- cream shell, a dark bezel with a mint screen, an indigo plus d-pad and coral and
-- citrine buttons. 6 parts; the screen is the only Neon part (no emitter, no light).
builders.pocket_deck=function(h)
 mesh(h,"DeckShell",V(.255,.105,.036),V(0,0,0),hex("#F3E9D2"))
 mesh(h,"DeckBezel",V(.11,.076,.008),V(0,.004,.0175),hex("#1B2330"))
 local screen=mesh(h,"DeckScreen",V(.092,.058,.006),V(0,.004,.0215),hex("#76F6B0"))
 screen.Material=Enum.Material.Neon
 mesh(h,"DeckPad",V(.037,.037,.01),V(-.088,-.004,.02),indigo)
 mesh(h,"DeckButtonA",V(.023,.023,.011),V(.098,.008,.02),coral)
 mesh(h,"DeckButtonB",V(.023,.023,.011),V(.078,-.016,.02),citrine)
 h.screen=screen
end
-- How the pet plays with each toy (PetPlayVisual.render): wave = held up and swept,
-- roll = rolled along the ground, chew = brought to the mouth, spin = spun in the hand,
-- tap = held up to the face in both hands with little button presses.
Toys.Play=table.freeze({sparkler="wave",ball="roll",bone="chew",wobble_top="spin",squeaky_carrot="chew",pocket_deck="tap"})
Toys.PartLimit=12
-- How each toy is carried between plays (QA v685 R8; PetPlayVisual.renderHeld): the pet
-- always has its equipped toy in its right hand while it idles or walks. In pet body
-- heights from the holding hand, in the pet's own frame (x to its right, y up, z forward);
-- `turn` orients the toy and `fold` raises the holding arm (radians). Tuned per toy:
--   sparkler        upright in the fist, tipped a little forward (unlit until it is played)
--   ball            hugged in front of the hand, low against the tummy
--   bone            across the body, one end up
--   wobble_top      standing on the raised palm
--   squeaky_carrot  leaves up, like a little bouquet
--   pocket_deck     screen tipped up toward the face
Toys.Hold=table.freeze({
 sparkler=table.freeze({offset=Vector3.new(.03,.07,.045),turn=CFrame.Angles(.18,0,-.12),fold=.55}),
 ball=table.freeze({offset=Vector3.new(-.03,-.005,.115),turn=CFrame.identity,fold=.5}),
 bone=table.freeze({offset=Vector3.new(-.01,0,.07),turn=CFrame.Angles(0,.25,.3),fold=.4}),
 wobble_top=table.freeze({offset=Vector3.new(0,.085,.06),turn=CFrame.identity,fold=.6}),
 squeaky_carrot=table.freeze({offset=Vector3.new(0,.03,.065),turn=CFrame.Angles(0,0,.35),fold=.45}),
 pocket_deck=table.freeze({offset=Vector3.new(-.05,.02,.075),turn=CFrame.Angles(-.4,-.2,0),fold=.5}),
})
Toys.DefaultHold=table.freeze({offset=Vector3.new(.035,0,.045),turn=CFrame.identity,fold=.4})
function Toys.hold(id)return Toys.Hold[id]or Toys.DefaultHold end
function Toys.has(id)return type(id)=="string"and builders[id]~=nil end
function Toys.create(parent,id,scale)
 local build=type(id)=="string"and builders[id]
 if not build then return nil end
 local h=Prop.new(parent,"PersonalToy_"..id,scale);h.id=id
 build(h)
 return h
end
return Toys
