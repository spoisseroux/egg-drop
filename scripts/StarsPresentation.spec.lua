-- Display-only wallet naming/icon/receipt assertions; no remotes or stored-field migration.
return function(client,parent)
 local Stars=require(client.StarText);local EggArt=require(client.EggArt);local Menu=require(client.DeckMenu)
 local Shop=require(client.EggHatchView);local Results=require(client.DeckResults);local Affection=require(client.PetAffection)
 local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog);local Gui=game:GetService("GuiService")
 local before=Gui.SelectedObject;local root=Instance.new("Frame");root.Name="_StarsPresentation";root.Size=UDim2.fromOffset(720,580);root.Parent=parent
 local world=Instance.new("Folder");world.Name="_StarsPresentation";world.Parent=workspace
 local cases={};local function test(n,f)f();table.insert(cases,n)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local menu=Menu.new(root,{});local shop=Shop.new(root,{play=function()end},function()return true end,function()error("presentation must not request")end)
 local resultsHost=Instance.new("Frame");resultsHost.Size=UDim2.fromOffset(848,608);resultsHost.BackgroundTransparency=1;resultsHost.Parent=root
 local recap=Results.new(resultsHost,{});local affection=Affection.new(world)
 local ok,problem=pcall(function()
  test("single existing wallet uses correct singular plural and no value conversion",function()
   assert(Stars.amount(0)=="0 Stars"and Stars.amount(1)=="1 Star"and Stars.amount(20)=="20 Stars")
   assert(Stars.format("+%d Stars",1)=="+1 Star"and Stars.format("+%d Stars",14)=="+14 Stars")
   local state={status="Ready",revision=10,nectar=1,inventoryMask=3,dailyAvailable=false}
   menu:update(state,"pip","pip",0,0,0,"meadow");menu:open();shop:open(state);settle()
   assert(state.nectar==1 and state.revision==10 and state.inventoryMask==3)
   assert(menu.nectar.Text=="1"and shop.state.nectar==1)
   assert(menu.nectar:GetAttribute("AccessibleLabel")=="1 Star","menu wallet accessible label: "..tostring(menu.nectar:GetAttribute("AccessibleLabel")))
   -- The egg list now shows its balance in the Kit.header wallet (slice D); the
   -- legacy `nectar` label is hidden and no longer carries the accessible copy.
   local shopWallet=shop.shopHeader.wallet.root
   assert(shopWallet:GetAttribute("AccessibleLabel")=="1 Star","shop wallet accessible label: "..tostring(shopWallet:GetAttribute("AccessibleLabel")))
  end)
  test("all currency illustrations are passive five-point gold Stars with a light glint",function()
   local icon=EggArt.stars(root,UDim2.fromOffset(0,0),UDim2.fromOffset(20,24),30);settle()
   assert(icon.GoldStar.Text=="★"and icon.StarGlint and not icon.Active and not icon.Selectable and not icon.GoldStar.TextScaled)
   assert(not icon:FindFirstChild("RoundDrop")and not icon:FindFirstChild("DropTip"))
   assert(menu.wallet.NectarDrop:FindFirstChild("GoldStar"))
   recap:show({outcome="clear",rows={},total=1,earned=1,balance=1,goals={}},false)
   -- The results centrepiece is the 2D Star token (CelebrationKit.star) until the mesh exists.
   assert(recap.star.mode=="gold"and recap.star.main.Text=="★"and recap.star.main.TextColor3==Color3.fromHex("#FFC14D"),"results Star is always gold")
   icon:Destroy()
  end)
  test("Saved historical receipt keeps exact amount while showing live Stars balance",function()
   local data={outcome="clear",rows={{name="Round win",amount=1}},total=1,earned=1,balance=1,goals={}}
   recap:show(data,false);assert(recap.totalText.Text=="+1"and recap.wallet.amount.Text=="1")
   data.balance=9;recap:show(data,false)
   assert(recap.totalText.Text=="+1"and recap.wallet.amount.Text=="9"and recap.wallet.root:GetAttribute("AccessibleLabel")=="9 Stars")
  end)
  test("accepted care award has single-Star accessibility and unchanged amount",function()
   -- QA Q2.7: the plate reads "+1 ★" (UICopy pet.star) in Stars gold; the old drop glyph stays built but hidden.
   local UICopy=require(game.ReplicatedStorage.Shared.UICopy)
   assert(affection.label.Text==UICopy.get("pet.star")and affection.label.Text:find("★",1,true)and affection.label:GetAttribute("AccessibleLabel")=="1 Star saved")
   assert(affection.plate:FindFirstChild("NectarDrop").GoldStar.Text=="★"and not affection.plate.NectarDrop.Visible)
  end)
  test("rendered copy and accessibility contain no retired currency term",function()
   for _,host in ipairs({root,world})do for _,node in ipairs(host:GetDescendants())do
    if node:IsA("TextLabel")or node:IsA("TextButton")then assert(not string.lower(node.Text):find("nectar",1,true),node:GetFullName().." old display copy")end
    local copy=node:GetAttribute("AccessibleLabel");if type(copy)=="string"then assert(not string.lower(copy):find("nectar",1,true),node:GetFullName().." old accessible copy")end
   end end
  end)
 end)
 affection:destroy();root:Destroy();world:Destroy();Gui.SelectedObject=before;assert(ok,problem)
 return{passed=#cases,cases=cases,currencyFieldsRenamed=false,actualWalletMutation=false}
end
