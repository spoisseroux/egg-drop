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
  Body=table.freeze({day=.12,night=.46}),
  Eye=table.freeze({day=0,night=0}),
  Charm=table.freeze({day=.25,night=.98}),
  Catchlight=table.freeze({day=.12,night=.48}),
 }),
 LoadTimeout=12,
})
