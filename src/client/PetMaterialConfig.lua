-- Immutable uploaded scalar maps; map properties are authored in PetMaterials.rbxm.
return table.freeze({
 Version=1,
 ContentIds=table.freeze({
  "rbxassetid://132217078330162", -- opaque white albedo + emissive mask
  "rbxassetid://114363080604088", -- nonmetal
  "rbxassetid://90822949282078", -- roughness82/255
  "rbxassetid://75946070025172", -- staged Jelly roughness64/255; no activation until native approval
  "rbxassetid://101362074171738", -- roughness36/255
 }),
 Profiles=table.freeze({
  Body=table.freeze({day=.22,night=.46}),
  -- Two-tone bodies: less glow so a white primary keeps its shading and gradient (Spencer, 2026-11-12).
  -- No glow by day; a soft, fairly bright glow at night (Spencer, 2026-11-12). Ramp: Materials.nightGlow.
  BodyTwoTone=table.freeze({day=0,night=.5}),
  Eye=table.freeze({day=0,night=0}),
  Charm=table.freeze({day=.38,night=.98}),
  Catchlight=table.freeze({day=.12,night=.48}),
 }),
 FinishProfiles=table.freeze({standard="Body",gloss="BodyGloss",matte="BodyMatte",metal="BodyMetal",jelly="BodyJelly"}),
 -- Two-tone body variants (ReplicatedStorage.PetMaterialsTwoTone), keyed by the one-colour profile.
 TwoToneProfiles=table.freeze({Body="BodyTwoTone",BodyGloss="BodyTwoToneGloss",BodyMatte="BodyTwoToneMatte",BodyMetal="BodyTwoToneMetal",BodyJelly="BodyTwoToneJelly"}),
 -- Explicit core-piece semantics. Unknown parts, faces, charms and attachments
 -- stay opaque; tint role alone never grants translucency.
 JellyAlphaByPart=table.freeze({Body=.15,Head=.08,HandL=.15,HandR=.15,FootL=.15,FootR=.15,
  EarL=.12,EarR=.12,Tail=.12,CrownL=.12,CrownR=.12,FoldedEar=.12,EarSeam=.12,
  Muzzle=.08,Belly=.08,BellyPatch=.08,EarInnerL=.08,EarInnerR=.08,CuffTrimL=.08,CuffTrimR=.08,
  MittenTipL=.08,MittenTipR=.08,HipFlapL=.08,HipFlapR=.08,CheekFold=.08,BrowFold=.08,
  FinnedCheekL=.08,FinnedCheekR=.08,Cowl=.08,LidFold=.08}),
 LoadTimeout=12,
})
