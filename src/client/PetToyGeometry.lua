-- Original +Z-facing personal props, normalized to one pet body-height.
-- One builder per toy id (slice D, toy pool 2). A toy ships only when its builder exists
-- here AND its id is in ToyCatalog; Toys.has(id) is the render whitelist for every caller.
-- Sphere primitives only (PetPropGeometry), at most 12 parts a toy (VISUAL-BRIEF 3).
local Prop=require(script.Parent.PetPropGeometry)
local Toys={}
local indigo=Color3.fromHex("#333C78");local brass=Color3.fromHex("#C69A45");local citrine=Color3.fromHex("#F6D759")
local hex=Color3.fromHex
local coral,cream,teal=hex("#EF786B"),hex("#FFF0C9"),hex("#3FB7B0")
local builders={}
builders.sparkler=function(h)
 h:add("IndigoGrip",Vector3.new(.052,.17,.052),CFrame.new(0,-.065,0)*CFrame.Angles(0,0,-.10),indigo,"sphere")
 h:add("OffsetBrassWire",Vector3.new(.016,.12,.016),CFrame.new(.018,.074,0)*CFrame.Angles(0,0,-.24),brass,"sphere")
 for i=-1,1 do h:add("SeedProng"..i,Vector3.new(.025,.082,.025),CFrame.new(.025+i*.026,.145+math.abs(i)*-.015,0)*CFrame.Angles(0,0,-i*.55),citrine,"sphere")end
 -- A glowing tip throws real sparks: one bounded emitter and a small light.
 local tip=h:add("GlowTip",Vector3.new(.034,.034,.034),CFrame.new(.025,.19,0),Color3.fromHex("#FFF1B8"),"sphere")
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
builders.ball=function(h)
 h:add("CoralBall",Vector3.new(.24,.24,.24),CFrame.identity,Color3.fromHex("#EF786B"),"sphere")
 h:add("OffsetCreamEquator",Vector3.new(.244,.055,.244),CFrame.new(0,.018,0)*CFrame.Angles(0,0,.18),Color3.fromHex("#FFF0C9"),"sphere")
 h:add("TealDimple",Vector3.new(.048,.043,.012),CFrame.new(.045,.039,.116),Color3.fromHex("#327E83"),"sphere")
end
builders.bone=function(h)
 h:add("OchreWaist",Vector3.new(.21,.061,.064),CFrame.identity,Color3.fromHex("#C9954A"),"sphere")
 for _,side in ipairs({-1,1})do for _,lobe in ipairs({-1,1})do
  h:add("SeafoamLobe"..side..lobe,Vector3.new(.075,.065,.067),CFrame.new(side*.12,lobe*.026,0)*CFrame.Angles(0,0,side*lobe*.2),Color3.fromHex("#9CE0CC"),"sphere")
 end end
 h:add("OffcenterWrap",Vector3.new(.045,.074,.075),CFrame.new(.027,0,0)*CFrame.Angles(0,0,.16),Color3.fromHex("#E9D29A"),"sphere")
 h:add("WrapNotch",Vector3.new(.013,.018,.008),CFrame.new(.025,.018,.038),Color3.fromHex("#936B3B"),"sphere")
end
-- Wobble Top (VISUAL-BRIEF 3): a fat teal body with a cream equator, a coral foot, a brass
-- stem and a citrine knob, the whole toy tilted 0.18 rad. 5 parts.
builders.wobble_top=function(h)
 local tilt=CFrame.Angles(0,0,.18)
 h:add("TealBody",Vector3.new(.20,.15,.20),tilt,teal,"sphere")
 h:add("CreamEquator",Vector3.new(.205,.04,.205),tilt*CFrame.new(0,.01,0),cream,"sphere")
 h:add("CoralFoot",Vector3.new(.05,.07,.05),tilt*CFrame.new(0,-.09,0),coral,"sphere")
 h:add("BrassStem",Vector3.new(.04,.10,.04),tilt*CFrame.new(0,.11,0),brass,"sphere")
 h:add("CitrineKnob",Vector3.new(.06,.06,.06),tilt*CFrame.new(0,.17,0),citrine,"sphere")
end
-- Squeaky Carrot (VISUAL-BRIEF 3): three stacked orange spheres down a diagonal (centres
-- 0.075 apart), three leaf prongs fanned +-0.5 rad at the fat end and a cream squeaker dot
-- on the side. 7 parts.
builders.squeaky_carrot=function(h)
 local orange,leaf=hex("#FF8A3C"),hex("#58B368")
 local axis=CFrame.Angles(0,0,-.62)
 h:add("CarrotTop",Vector3.new(.085,.11,.085),axis*CFrame.new(0,.075,0),orange,"sphere")
 h:add("CarrotMiddle",Vector3.new(.07,.10,.07),axis,orange,"sphere")
 h:add("CarrotTip",Vector3.new(.05,.09,.05),axis*CFrame.new(0,-.075,0),orange,"sphere")
 for i=-1,1 do
  h:add("LeafProng"..i,Vector3.new(.03,.08,.03),axis*CFrame.new(i*.018,.128,0)*CFrame.Angles(0,0,-i*.5)*CFrame.new(0,.03,0),leaf,"sphere")
 end
 h:add("SqueakerDot",Vector3.new(.03,.03,.03),axis*CFrame.new(0,.02,.034),cream,"sphere")
end
-- How the pet plays with each toy (PetPlayVisual.render): wave = held up and swept,
-- roll = rolled along the ground, chew = brought to the mouth, spin = spun in the hand.
Toys.Play=table.freeze({sparkler="wave",ball="roll",bone="chew",wobble_top="spin",squeaky_carrot="chew"})
Toys.PartLimit=12
function Toys.has(id)return type(id)=="string"and builders[id]~=nil end
function Toys.create(parent,id,scale)
 local build=type(id)=="string"and builders[id]
 if not build then return nil end
 local h=Prop.new(parent,"PersonalToy_"..id,scale);h.id=id
 build(h)
 return h
end
return Toys
