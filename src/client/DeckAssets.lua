-- Uploaded Pocket Deck Slim sprites (assets/deck/, UI-SPEC-2026-11-12 section 4).
-- Rects are deck units from assets/deck/shell/shell.json; multiply by the deck scale.
local Assets={}
Assets.Image={
 shadow="rbxassetid://121434035045264",shoulder="rbxassetid://74863712113210",band="rbxassetid://138363340781362",
 plateOverlay="rbxassetid://106306129867257",wordmark="rbxassetid://139133398634939",glass="rbxassetid://79292415073669",
 glare="rbxassetid://117953857216158",dpadDisc="rbxassetid://106584750721351",dpadArrows="rbxassetid://71446432618436",
 dpadPress="rbxassetid://95661562301496",menuPill="rbxassetid://104999410746636",
 buttonBase="rbxassetid://85052812576271",buttonBasePressed="rbxassetid://112125787028303",
 buttonGloss="rbxassetid://79522605312831",buttonGlossPressed="rbxassetid://126420147674370",
 led="rbxassetid://109638204048831",icons="rbxassetid://78684830466920",focusGlow="rbxassetid://85253701978874",
}
-- Faceplate textures for all 16 plates (ids in assets/deck/faceplates/asset-ids.json;
-- the shared DeckThemes entry carries them so the server's held deck can use them).
local Themes=require(game:GetService("ReplicatedStorage").Shared.DeckThemes)
Assets.Faceplate={}
for id,theme in pairs(Themes.ById)do Assets.Faceplate[id]=theme.texture end
-- Boot sheets (assets/deck/boot/asset-ids.json): fixed art under accent-tinted ink.
Assets.Boot={fixed="rbxassetid://139514431996183",ink="rbxassetid://108875671405895"}
Assets.Layout={
 size=Vector2.new(1600,800),
 shadow={-90,-68+22,1780,980},shoulderL={170,-12,220,24},shoulderR={1210,-12,220,24},
 band={0,0,1600,800},plate={20,20,1560,760},wordmark={67,124,246,96},
 glass={360,80,880,640},lcd={376,96,848,608},lcdRadius=30,
 dpad={center=Vector2.new(190,424),diameter=208},menu={128,618,124,44},
 a={center=Vector2.new(1432,372),diameter=176},b={center=Vector2.new(1318,548),diameter=104},
 led={173,241,34,34},
}
-- 64 px cells in ui/icons.png (ui-assets.json).
local order={"back","quests","star","replay","reroll","lock","bars","faceplate","check","settings","clock","trophy","chain","target","close","egg"}
Assets.Icon={}
for index,name in ipairs(order)do
 Assets.Icon[name]=Vector2.new(((index-1)%8)*64,math.floor((index-1)/8)*64)
end
return Assets
