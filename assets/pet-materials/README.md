# Original pet material maps and continuous Ring

Native paired rendering and seven-rig checks passed for the November9 companion-editor candidate. Final evidence and limits are in `artifacts/companion-editor-2026-11-09/VERIFY.md`. The preparation procedure below is retained for reproducing the original pack; future rebuilds need their own render verification.

Four original constant 32×32 maps for the reviewed luminous vinyl trial. Generate with `python scripts/build_pet_material_maps.py`; the generator writes only this directory. `manifest.json` records exact pixels, quantized scalar values, hashes, owned uploaded IDs and Astra's first-trial role strengths. Root uploaded all four maps and exported the four-profile `PetMaterials.rbxm` through native SerializationService; deserialize/round-trip verified the modern emissive Content URLs. The pack is mounted separately from the 122 mesh resources.

Upload these four PNGs through the root-owned Studio image upload tool. The white image serves both opaque albedo and the full emissive mask. All profiles are nonmetal; body/Secondary/charm use roughness 82/255 (target .32), eyes/catchlights 36/255 (target .14). There is no normal map, directional image or added geometry.

After root records actual owned IDs, load the Edit-only `scripts/BuildPetMaterialTemplates.lua` helper in the ordinary approved authoring workflow and call its returned function with an explicit destination and:

```lua
{
 white = "<actual uploaded ID>",
 metalness = "<actual uploaded ID>",
 bodyRoughness = "<actual uploaded ID>",
 eyeRoughness = "<actual uploaded ID>",
}
```

The helper validates all IDs before allocation, refuses to replace an existing `PetMaterials` folder, and removes partial output on failure. It creates four immutable-map `SurfaceAppearance` profiles: Body, Eye, Charm and Catchlight. No runtime map setter or engine-managed texture-pack property is used. Preloading explicit image URIs checks raw fetch/permission only; it cannot certify processed SurfaceAppearance rendering, which remains an actual native-render gate. Runtime binds the valid versioned authored pack directly: the prior raw-URI gate rejected assets that loaded as parented images, and unparented IsLoaded was also misleading. Actual binding errors use bounded primitive/role-fill fallback; actual processed rendering still requires paired native evidence.

Runtime tint must apply the resolved saved role color once through `SurfaceAppearance.Color`. White `EmissiveTint` is the initial trial; compare actual saturated pigments before choosing. Eyes remain nonemissive. Original Zivvi/Ovelle exports lack recorded UVs, so constant-map rendering still requires native proof. Primitive/SpecialMesh fallback does not gain PBR from these maps.

The original continuous32×8 torus is exported by native SerializationService in PetCharmAssets.rbxm (Ring MeshPart) and mounted through PetCharmAssets.rbxmx using the existing production rig pack’s MeshContent/InitialSize recipe, MeshId138583256075565, size .259×.195×.049 before visual scale. A single shared PetAssetReadiness request gates the whole mesh handoff. The independent original alpha mask102662383486040 is applied on both faces of the temporary plane; its alpha opening and edge-on limitation must be verified natively, including ViewportFrame. Hidden forms have neither emission nor hull contribution.

Astra approved strengths at noon/dusk/night: body .12/.29/.46, charm .25/.615/.98, pale catchlight .12/.30/.48; eyes0. GardenPetVisual option emissionEnabled=false retains the exact same surfaces with zero emission for paired controls. materialsEnabled=false removes surfaces for fallback verification.

Native live sync initially retained an empty Ring resource after changing its pack from binary to XML. The cold Rojo build explicitly contains MeshContent URI138583256075565 and InitialSize(.259,.195,.049). Root refreshes the live immutable resource with the exact original imported MeshPart; cold-file/resource rendering and normal published-client checks remain separate from source equality.
