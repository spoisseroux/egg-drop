-- The curious glance: the eyes look .018 aside (along the eye part's own X) and .01 up.
-- Pure: GardenPetVisual calls it per eye piece; no instances, no state.
--
-- Beta 16 B4 (the Bunny) and beta 19 (the Bear, Spencer 2026-11-25: "the bears eye is now clipping into his head
-- on the right"). A straight sideways slide carries the inward eye onto the part of a round head that bulges
-- forward, so its outer edge sinks: on the shipped cute Bear (pet-bear-v2-cute.blend, Head + Muzzle) the eye on the
-- viewer's right (EyeR) went 0.0075 under, 12-22 % of the eye, in every curious face (the pet focus view, "Meet Bear").
-- So the sideways part turns the eye round the head's upright axis through the Head piece's centre (the same travel;
-- the eye rides the curve), and the eye lifts Lift straight out from that axis, because the cute Bear's eyes were
-- conformed with only .0035 to spare at rest. Measured, turned + lift .005 (faces, deepest):
--   Bear  EyeR eye 1 / 1.16 / 1.36: +.0046 / +.0085 / +.0090; EyeL +.0001 / +.0061 / +.0072 (was -.0075 straight)
--   Bunny (pre-B4 meshes, the live line) EyeL/EyeR all +.0008 or more; B4 meshes +.0029 or more.
-- The glance belongs to the curious face only: a squinting face shown over a curious garden state (joy, content,
-- a sit) keeps its eyes still; a squint scales the eye toward its centre and already tucks the lower rim in.
local Glance={}
Glance.Aside,Glance.Up,Glance.Lift=.018,.01,.005
Glance.Pieces={EyeL=true,EyeR=true,GlintL=true,GlintR=true}

-- True when this piece glances: `gardenExpression` is the visual's own state (visual.expression), `shownExpression`
-- the face actually drawn this frame (toy, reaction, hello, beat, sit and Expression.name already applied).
function Glance.applies(name,gardenExpression,shownExpression)
 return Glance.Pieces[name]==true and gardenExpression=="curious"and shownExpression=="curious"
end

-- The Head piece's centre in the rig's own frame, scaled (nil when the rig has no Head piece).
function Glance.headCentre(definition,scale)
 for _,def in ipairs(definition and definition.pieces or {})do
  if def.name=="Head"then local c=def.center;return Vector3.new(c[1],c[2],c[3])*scale end
 end
 return nil
end

-- cf: the eye piece's world frame; head: the head channel's world frame (the rig frame, posed); centre: Glance.headCentre.
function Glance.frame(head,cf,centre,scale)
 local s=scale;local inHead=head:ToObjectSpace(cf)
 local aside=inHead:VectorToWorldSpace(Vector3.new(Glance.Aside*s,0,0)).X
 local reach=centre and inHead.Position.Z-centre.Z
 if not reach or reach<=math.abs(aside)then return cf*CFrame.new(Glance.Aside*s,Glance.Up*s,0)end
 local turned=CFrame.new(centre)*CFrame.Angles(0,math.asin(aside/reach),0)*CFrame.new(-centre)*inHead
 local out=Vector3.new(turned.Position.X-centre.X,0,turned.Position.Z-centre.Z)
 local lift=if out.Magnitude>1e-6 then out.Unit*(Glance.Lift*s)else Vector3.zero
 return head*CFrame.new(Vector3.new(0,Glance.Up*s,0)+lift)*turned
end

return Glance
