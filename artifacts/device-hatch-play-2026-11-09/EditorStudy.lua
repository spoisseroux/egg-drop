-- UI fixtures only; seeded owner data, no remotes or inventory mutations.
local p=game.Players.LocalPlayer;local c=p.PlayerScripts.Client
local Art=require(c.DeckArt);local View=require(c.HueEggView);local Hue=require(c.HueIntent);local Toy=require(c.ToyIntent);local Feature=require(c.FeatureIntent);local H=require(game.ReplicatedStorage.Shared.HueCatalog);local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
local gui=Instance.new("ScreenGui");gui.Name="_DeviceEditorStudy";gui.IgnoreGuiInset=true;gui.DisplayOrder=920;gui.Parent=p.PlayerGui
local root=Instance.new("Frame");root.Name="FixtureBounds";root.BackgroundTransparency=1;root.Position=UDim2.fromScale(.03,.06);root.Size=UDim2.fromScale(.94,.91);root.Parent=gui
local function deps()return{id=function()return"study"end,delay=function()end,send=function()error("fixture may not send")end}end
local hue=Hue.new(deps());local toy=Toy.new(deps());local feature=Feature.new(deps())
local s={status="Ready",revision=100,nectar=64,inventoryMask=127,hueInventory={rose=3,tide=2,citrus=1,iris=2,reset=1},petHues={},materialAvailable=true,materialUnlocks={gloss=true,matte=true},toyUnlocks={ball=true,bone=true,sparkler=true},petToys={pip="bone"},featureStock={horns=3,claws=2,wings=1},petFeatures={}}
for _,pet in ipairs(Pets.collection)do s.petHues[pet.id]={main=H.emptyCounts(),secondary=H.emptyCounts()};s.petFeatures[pet.id]={horns={earned=3,visible=2},claws={earned=1,visible=1},wings={earned=2,visible=1}}end
hue:update(s);toy:update(s);feature:update(s)
local view=View.new(root,hue,{toyIntent=toy,featureIntent=feature,canCustomize=function()return true end,reduceEffects=function()return true end,appearance=function()return{charmVisible=true,charmShape="ring"}end})
view:open(s,"pet","pip")
script:GetAttributeChangedSignal("Tab"):Connect(function()view:setTab(script:GetAttribute("Tab")or"pet")end)
script.Destroying:Connect(function()view:destroy();if hue.destroy then hue:destroy()end;toy:destroy();feature:destroy();root:Destroy();gui:Destroy()end)
