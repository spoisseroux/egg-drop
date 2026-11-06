-- Native UI/visual lifecycle fixtures; no inventory or profile changes.
return function(client, parent)
	local Crest = require(client.FamilyCrest)
	local Prestige = require(client.PetPrestige)
	local Catalog = require(game.ReplicatedStorage.Shared.PetCatalog)
	local Menu = require(client.DeckMenu)
	local root = Instance.new("Frame")
	root.Size, root.BackgroundTransparency, root.Parent = UDim2.fromOffset(360,236), 1, parent
	local cases, models = {}, {}
	local function test(name, run) run(); table.insert(cases,name) end
	local menu
	local ok, problem = pcall(function()
		test("all family ranks render at24px with no text or input capture",function()
			for _, family in ipairs({"pip","puddle","wick","orbit"}) do
				for rank=0,3 do
					local host=Crest.create(root,family,rank,UDim2.fromOffset(0,0),UDim2.fromOffset(24,24))
					assert(host:GetAttribute("Family")==family and host:GetAttribute("Rank")==rank)
					for _, node in ipairs(host:GetDescendants())do
						assert(not node:IsA("TextLabel") and not node:IsA("ImageLabel"))
						if node:IsA("GuiObject")then assert(not node.Active and not node.Selectable)end
					end
					host:Destroy()
				end
			end
		end)
		test("unchanged HUD refresh preserves artwork instances and descendant count",function()
			local host=Crest.create(root,"pip",2,UDim2.fromOffset(0,0),UDim2.fromOffset(24,24))
			local artwork,count=host.Artwork,#host:GetDescendants()
			for _=1,50 do Crest.update(host,"pip",2,false) end
			assert(host.Artwork==artwork and #host:GetDescendants()==count)
			Crest.update(host,"wick",3,false)
			assert(artwork.Parent==nil and host:GetAttribute("Family")=="wick")
			host:Destroy()
		end)
		test("menu refresh keeps family crests and fits all family buttons",function()
			local noop=function()end
			menu=Menu.new(root,{close=noop,eggs=noop,pets=noop,style=noop,play=noop,daily=noop,family=noop})
			local state={status="Ready",inventoryMask=127,masteryRanks={pip=1,puddle=2,wick=3,orbit=0}}
			menu:update(state,"pip","wick",0,0,0,"meadow");menu:setPage("mastery");menu:open();task.wait(.08)
			local artwork=menu.families.pip.FamilyCrest.Artwork
			for _=1,20 do menu:update(state,"pip","wick",0,0,0,"meadow")end
			assert(menu.families.pip.FamilyCrest.Artwork==artwork)
			for _,button in pairs(menu.families)do
				assert(button.TextFits and button.FamilyName.TextFits and button.AbsoluteSize.Y==44)
				assert(button.FamilyCrest.AbsolutePosition.X+24 <= button.FamilyName.AbsolutePosition.X)
			end
		end)
		test("earned pet badge cleanup preserves unranked and legacy effects",function()
			for rank=0,3 do
				local model=Instance.new("Model");local body=Instance.new("Part");body.Anchored=true;body.Parent=model;model.PrimaryPart=body
				model.Parent=workspace;table.insert(models,model)
				local visual={model=model};Prestige.attach(visual,Catalog.byId.foxfire_wick,rank,rank==0)
				assert((body:FindFirstChild("FamilyPrestigeBadge")~=nil)==(rank>0))
				assert((model:FindFirstChild("FamilyAccentFinish")~=nil)==(rank>=2))
				assert((visual.masteryEmitter~=nil)==(rank==0 or rank>=3))
				if visual.masteryEmitter then Prestige.update(visual,10,true);assert(not visual.masteryEmitter.Enabled)end
				model:Destroy();assert(body.Parent==nil)
			end
		end)
	end)
	if menu then menu:close()end
	for _,model in ipairs(models)do model:Destroy()end
	root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases}
end
