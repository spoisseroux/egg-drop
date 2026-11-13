-- Generated from assets/eggs/eggs-manifest.json + Open Cloud uploads (2026-11-13).
-- 3D egg shells/core and the results Star token. Sizes in studs; centres are relative
-- to the egg base centre (egg stands on the origin, +Y up, front +Z).
local M={}
M.Egg={
 TopShell={mesh="rbxassetid://109271813115561",size=Vector3.new(0.9371,0.6238,0.9371),center=Vector3.new(0,0.9881,0)},
 BottomShell={mesh="rbxassetid://136693092325865",size=Vector3.new(0.9949,0.8235,0.9949),center=Vector3.new(0,0.4117,0)},
 Core={mesh="rbxassetid://97136732817875",size=Vector3.new(0.8,0.8,0.8),center=Vector3.new(0,0.7,0)},
 spinPivot=Vector3.new(0,0.546,0),seamHeight=0.7537,
}
M.Star={mesh="rbxassetid://74284933281038",colorMap="rbxassetid://118655103980144",size=Vector3.new(1.0097,0.9714,0.45)}
M.Order={"companion","toy","material","hue","feature"}
M.Types={
 companion={name="Companion Egg",colorMap="rbxassetid://79542364257645",roughness=0.3,core=Color3.fromHex("#FFE58A"),bloom=Color3.fromHex("#FFD86B"),crackLight=Color3.fromHex("#FFFBE6"),particles={Color3.fromHex("#FFFFFF"),Color3.fromHex("#FFE58A"),Color3.fromHex("#7C9BFF")}},
 toy={name="Toy Egg",colorMap="rbxassetid://102395066318876",roughness=0.26,core=Color3.fromHex("#FFB340"),bloom=Color3.fromHex("#FF9F2E"),crackLight=Color3.fromHex("#FFE9A6"),particles={Color3.fromHex("#FFFFFF"),Color3.fromHex("#FFD45C"),Color3.fromHex("#F16F65"),Color3.fromHex("#49C7E0")}},
 material={name="Material Egg",colorMap="rbxassetid://116788417697124",roughness=0.18,core=Color3.fromHex("#8FF0E4"),bloom=Color3.fromHex("#6FDCD2"),crackLight=Color3.fromHex("#F7F2FF"),particles={Color3.fromHex("#FFFFFF"),Color3.fromHex("#BFF7F0"),Color3.fromHex("#C8B8F5")}},
 hue={name="Hue Egg",colorMap="rbxassetid://99992329486875",roughness=0.26,core=Color3.fromHex("#FF7AB8"),bloom=Color3.fromHex("#FF5FA8"),crackLight=Color3.fromHex("#C9F6F8"),particles={Color3.fromHex("#FFFFFF"),Color3.fromHex("#FF7AB8"),Color3.fromHex("#FFDD4A"),Color3.fromHex("#5FD0FF"),Color3.fromHex("#B58BFF")}},
 feature={name="Feature Egg",colorMap="rbxassetid://71347942777030",roughness=0.24,core=Color3.fromHex("#9CFFDD"),bloom=Color3.fromHex("#74E8C4"),crackLight=Color3.fromHex("#C9A8E8"),particles={Color3.fromHex("#FFFFFF"),Color3.fromHex("#9CFFDD"),Color3.fromHex("#E3C8FF")}},
}
return table.freeze(M)
