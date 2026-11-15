local p=game.Players.LocalPlayer;local g=Instance.new('ScreenGui');g.Name='_NativeFinishComparison';g.DisplayOrder=11000;g.IgnoreGuiInset=true;g.Parent=p.PlayerGui
local root=Instance.new('Frame');root.Size=UDim2.fromScale(1,1);root.BackgroundColor3=Color3.fromHex('#132F31');root.Parent=g
local Preview=require(p.PlayerScripts.Client.MaterialFinishPreview);local owners={}
for i,mode in ipairs({'fallback','ready'})do
 local pos=UDim2.new(.5,if i==1 then -340 else 40,.5,-155)
 local o=Preview.new(root,{finishId='jelly'},pos,UDim2.fromOffset(300,300),2,{autoLoad=mode~='fallback'});table.insert(owners,o)
 local label=Instance.new('TextLabel');label.BackgroundTransparency=1;label.Text=if mode=='fallback'then 'Round loading fallback'else 'Verified production Jelly';label.Font=Enum.Font.GothamMedium;label.TextSize=20;label.TextColor3=Color3.new(1,1,1);label.Size=UDim2.fromOffset(320,32);label.Position=UDim2.new(.5,if i==1 then -350 else 30,.5,160);label.Parent=root
 o.root.Name=if mode=='fallback'then 'LoadingSample'else 'ReadySample'
end
g.Destroying:Connect(function()for _,o in ipairs(owners)do o:destroy()end end)
