-- Immutable uploaded scalar maps; map properties are authored in PetMaterials.rbxm.
return table.freeze({
 Version=1,
 ContentIds=table.freeze({
  "rbxassetid://132217078330162", -- opaque white albedo + emissive mask
  "rbxassetid://114363080604088", -- nonmetal
  "rbxassetid://90822949282078", -- roughness82/255
  "rbxassetid://101362074171738", -- roughness36/255
 }),
 Profiles=table.freeze({
  Body=table.freeze({day=.22,night=.46}),
  -- Two-tone bodies: less glow so a white primary keeps its shading and gradient (Spencer, 2026-11-12).
  BodyTwoTone=table.freeze({day=.05,night=.28}),
  Eye=table.freeze({day=0,night=0}),
  Charm=table.freeze({day=.38,night=.98}),
  Catchlight=table.freeze({day=.12,night=.48}),
 }),
 FinishProfiles=table.freeze({standard="Body",gloss="BodyGloss",matte="BodyMatte",metal="BodyMetal"}),
 -- Two-tone body variants (ReplicatedStorage.PetMaterialsTwoTone), keyed by the one-colour profile.
 TwoToneProfiles=table.freeze({Body="BodyTwoTone",BodyGloss="BodyTwoToneGloss",BodyMatte="BodyTwoToneMatte",BodyMetal="BodyTwoToneMetal"}),
 LoadTimeout=12,
})
