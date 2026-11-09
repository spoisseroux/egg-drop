-- Display-only wallet naming/icon/receipt assertions; no remotes or stored-field migration.
return function(client,parent)
 local Stars=require(client.StarText);local EggArt=require(client.EggArt);local Menu=require(client.DeckMenu)
 local Shop=require(client.EggHatchView);local Recap=require(client.RoundRecap);local Affection=require(client.PetAffection)
 local Catalog=require(game.ReplicatedStorage.Shared.EggCatalog);local Gui=game:GetService("GuiService")
 local before=Gui.SelectedObject;local root=Instance.new("Frame");root.Name="_StarsPresentation";root.Size=UDim2.fromOffset(720,580);root.Parent=parent
 local world=Instance.new("Folder");world.Name="_StarsPresentation";world.Parent=workspace
 local cases={};local function test(n,f)f();table.insert(cases,n)end
 local function settle()for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end end
 local menu=Menu.new(root,{});local shop=Shop.new(root,{play=function()end},function()return true end,function()error("presentation must not request")end)
 local recap=Recap.new(root,nil,function()return true end);local affection=Affection.new(world)
 local ok,problem=pcall(function()
  test("single existing wallet uses correct singular plural and no value conversion",function()
   assert(Stars.amount(0)=="0 Stars"and Stars.amount(1)=="1 Star"and Stars.amount(20)=="20 Stars")
   assert(Stars.format("+%d Stars",1)=="+1 Star"and Stars.format("+%d Stars",14)=="+14 Stars")
   local state={status="Ready",revision=10,nectar=1,inventoryMask=3,dailyAvailable=false}
   menu:update(state,"pip","pip",0,0,0,"meadow");menu:open();shop:open(state);settle()
   assert(state.nectar==1 and state.revision==10 and state.inventoryMask==3)
   assert(menu.nectar.Text=="1"and shop.nectar.Text=="1")
   assert(menu.nectar:GetAttribute("AccessibleLabel")=="1 Star"and shop.nectar:GetAttribute("AccessibleLabel")=="1 Star")
  end)
  test("all currency illustrations are passive five-point gold Stars with a light glint",function()
   local icon=EggArt.stars(root,UDim2.fromOffset(0,0),UDim2.fromOffset(20,24),30);settle()
   assert(icon.GoldStar.Text=="★"and icon.StarGlint and not icon.Active and not icon.Selectable and not icon.GoldStar.TextScaled)
   assert(not icon:FindFirstChild("RoundDrop")and not icon:FindFirstChild("DropTip"))
   assert(menu.wallet.NectarDrop:FindFirstChild("GoldStar")and shop.wallet.NectarDrop:FindFirstChild("GoldStar"))
   assert(recap.nectarIcon:FindFirstChild("GoldStar")and not recap.nectarIcon:FindFirstChild("Leaf"))
   assert(#recap.chips==5);for _,chip in ipairs(recap.chips)do assert(chip:FindFirstChild("GoldStar"))end
   icon:Destroy()
  end)
  test("Saved historical receipt keeps exact amount while showing live Stars balance",function()
   recap.frame.Visible=true
   local reward={sequence=71,total=1,base=1,daily=0,family="pip",masteryPoints=0,promotedTo=0,contracts={}}
   local result={sequence=71,status="Saved",success=true,stage=2,reason="Completed",award=1,daily=0,balance=1,recipe=Catalog.ById.meadow,reward=reward}
   recap:updateField(result);assert(recap.earnedGraphic.Text=="+1 Star"and recap.displayBalance==1)
   result.balance=9;recap:updateField(result)
   assert(reward.total==1 and recap.earnedGraphic.Text=="+1 Star"and recap.displayBalance==9)
   assert(recap.receiptLines[1]=="Quest Stars +1"and recap.receiptLines[2]=="Daily contracts total +0")
  end)
  test("accepted care award has single-Star accessibility and unchanged amount",function()
   assert(affection.label.Text=="+1"and affection.label:GetAttribute("AccessibleLabel")=="1 Star saved")
   assert(affection.plate:FindFirstChild("NectarDrop").GoldStar.Text=="★")
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
