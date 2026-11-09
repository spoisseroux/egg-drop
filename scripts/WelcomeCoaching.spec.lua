-- Real LocalScript/ScreenGui metrics at the player's current PreferredTextSize.
-- Uses production DeckLayout bounds and Guide; no board attributes, requests or tutorial flags change.
return function(client,parent)
	assert(parent:IsA("ScreenGui"),"welcome fixture requires a real ScreenGui host")
	local Art,Layout,Guide=require(client.DeckArt),require(client.DeckLayout),require(client.FirstHatchGuide)
	local TextService,GuiService=game:GetService("TextService"),game:GetService("GuiService")
	local Pets=require(game.ReplicatedStorage.Shared.PetCatalog)
	local root=Instance.new("Frame");root.Name="_WelcomeCoaching";root.BackgroundTransparency=1;root.Parent=parent
	local cases={}
	local function settle()for _=1,2 do game:GetService("RunService").Heartbeat:Wait()end end
	local function test(name,run)run();table.insert(cases,name)end
	local function diagnostic(label)return string.format("%q box=%s bounds=%s font=%s/%d preferred=%s",label.Text,tostring(label.AbsoluteSize),tostring(label.TextBounds),label.Font.Name,label.TextSize,GuiService.PreferredTextSize.Name)end
	local function fit(label)assert(label.TextFits,diagnostic(label));assert(not label.TextScaled and label.TextSize>=12,"welcome font was shrunk")end
	local function frame(name,r)return Art.frame(root,name,Art.Ink,UDim2.fromOffset(r.x,r.y),UDim2.fromOffset(r.w,r.h),2)end
	local function fixture(size)
		root:ClearAllChildren();root.Size=UDim2.fromOffset(size.X,size.Y);settle()
		local short=size.X>=350 and size.X>=size.Y*1.2 and size.Y<280
		local cap=if short then 12 else 14
		local utility=TextService:GetTextSize("Lounge",cap,Art.Font.Action,Vector2.new(1000,100)).X+14
		local line=TextService:GetTextSize("Next",12,Art.Font.Body,Vector2.new(1000,100)).Y+4
		local mark=TextService:GetTextSize("III",12,Art.Font.Counter,Vector2.new(1000,100))
		local diameter=math.max(18,math.ceil(math.max(mark.X,mark.Y))+6)
		local wallet=TextService:GetTextSize("0",18,Art.Font.Counter,Vector2.new(1000,100)).Y+4
		local l=Layout.resolve(size,11.8/19.8,{utilityWidth=utility,lineHeight=line,queueHeight=math.max(line+diameter+2,line*2+4),walletLineHeight=wallet,countWidth=TextService:GetTextSize("24/24",12,Art.Font.Counter,Vector2.new(1000,100)).X+4})
		local status=Instance.new("TextLabel");status.Name="Status";status.Position=UDim2.fromOffset(l.quest.x,l.quest.y);status.Size=UDim2.fromOffset(l.quest.w,l.quest.h);status.Parent=root
		local compact=l.short or l.dense or l.quest.h<60
		Art.type(status,"Body",false);status.TextSize=if compact then 12 else 16;status.TextWrapped=true;status.ClipsDescendants=true
		local guide=Guide.new(frame("Rail",l.tray),frame("Rocker",l.dpad),frame("Drop",l.drop),frame("Meter",l.meter),status)
		settle();return guide,status,compact
	end
	local function semantic(value,phase,input,mark)
		if phase==1 then
			if input==Enum.UserInputType.Touch then assert(value:find("Drag",1,true) and (value:find("release",1,true) or value:find("lift",1,true)),value)
			elseif input==Enum.UserInputType.Gamepad1 then assert(value:find("A",1,true) and (value:find("Aim",1,true) or value:find("D-pad",1,true)),value)
			else assert(value:find("←",1,true) and value:find("→",1,true) and value:find("Space",1,true),value)end
		elseif phase==2 then
			local first,last=value:find(mark,1,true);assert(first,value);assert(value:find(mark,last+1,true),"both exact marks required: "..value)
			assert(not value:find("Space",1,true) and not value:find("Aim",1,true),"wrong phase fallback: "..value)
		else assert(value:lower():find(Pets.byId.pip.name:lower(),1,true) and (value:find("Merge",1,true) or value:find("HATCH",1,true)),value)end
	end
	local function show(guide,label,compact,phase,input,mark)
		label.Text=guide:step(if phase==1 then 0 else 1,if phase==3 then 1 else 0,if phase==3 then 1 else 0,0,input,mark,true,compact)
		settle();fit(label);semantic(label.Text,phase,input,mark)
	end
	local ok,problem=pcall(function()
		for _,size in ipairs({Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
			test(tostring(size).." all phases and keyboard controller touch controls fit",function()
				local guide,label,compact=fixture(size)
				for phase=1,3 do
					for _,input in ipairs({Enum.UserInputType.Keyboard,Enum.UserInputType.Gamepad1,Enum.UserInputType.Touch})do
						show(guide,label,compact,phase,input,"III")
					end
				end
			end)
		end
		test("observed 179x104 desktop well measures true padding before optional headings",function()
			local guide,label=fixture(Vector2.new(1649,971));label.Size=UDim2.fromOffset(179,104)
			local padding=Instance.new("UIPadding");padding.PaddingLeft,padding.PaddingRight=UDim.new(0,4),UDim.new(0,4)
			padding.PaddingTop,padding.PaddingBottom=UDim.new(0,2),UDim.new(0,2);padding.Parent=label;settle()
			for phase=1,3 do show(guide,label,false,phase,Enum.UserInputType.Keyboard,"III")end
		end)
		test("phase mark input resize and Ready restoration retain current semantic instruction",function()
			local guide,label,compact=fixture(Vector2.new(568,160))
			for _,mark in ipairs({"I","II","III"})do show(guide,label,compact,2,Enum.UserInputType.Keyboard,mark)end
			show(guide,label,compact,3,Enum.UserInputType.Keyboard,"II")
			label.Text="Retrying load" -- the existing save owner temporarily uses this same well.
			show(guide,label,compact,3,Enum.UserInputType.Touch,"II")
			label.Size=UDim2.fromOffset(179,104);Art.type(label,"Body",false);label.TextSize=16;label.TextWrapped=true;settle()
			show(guide,label,false,2,Enum.UserInputType.Gamepad1,"II")
			assert(guide:step(1,1,1,1,Enum.UserInputType.Keyboard,"II",false,false)==nil)
			assert(not guide.rail.Visible and not guide.rocker.Visible and not guide.drop.Visible and not guide.meter.Visible)
		end)
	end)
	root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases,preference=GuiService.PreferredTextSize.Name}
end
