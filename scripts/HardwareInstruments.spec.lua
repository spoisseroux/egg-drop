-- Native LocalScript + enabled ScreenGui. Isolated presentation, no server/remotes.
return function(client,parent)
	assert(parent:IsA("ScreenGui") and parent.Enabled,"enabled ScreenGui required")
	local Art,Layout,Quest,Dispenser=require(client.DeckArt),require(client.DeckLayout),require(client.BoardQuestHUD),require(client.DropDispenser)
	local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local Themes=require(game.ReplicatedStorage.Shared.DeckThemes)
	local TextService,RunService=game:GetService("TextService"),game:GetService("RunService")
	local root=Instance.new("Frame");root.Name="_HardwareInstruments";root.BackgroundTransparency=1;root.Parent=parent
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function settle()RunService.Heartbeat:Wait();RunService.Heartbeat:Wait()end
	local function fit(label)assert(label.TextFits,label.Name.." "..label.Text.." box="..tostring(label.AbsoluteSize).." bounds="..tostring(label.TextBounds));assert(not label.TextScaled)end
	local function make(name,r)return Art.frame(root,name,Art.Ink,UDim2.fromOffset(r.x,r.y),UDim2.fromOffset(r.w,r.h),2)end
	local function resolved(size)
		local short=size.X>=350 and size.X>=size.Y*1.2 and size.Y<280
		local utility=TextService:GetTextSize("Lounge",if short then 12 else 14,Art.Font.Action,Vector2.new(1000,100)).X+14
		local line=TextService:GetTextSize("Next",12,Art.Font.Body,Vector2.new(1000,100)).Y+4
		local mark=TextService:GetTextSize("III",12,Art.Font.Counter,Vector2.new(1000,100))
		local d=math.max(18,math.ceil(math.max(mark.X,mark.Y))+6)
		local caption=TextService:GetTextSize("Next",if short then 12 else 14,Art.Font.Body,Vector2.new(1000,100)).Y+4
		return Layout.resolve(size,(Config.Width+.8)/(Config.Height+.8),{utilityWidth=utility,lineHeight=line,queueHeight=math.max(caption+d+10,line*2+8),walletLineHeight=TextService:GetTextSize("0",18,Art.Font.Counter,Vector2.new(1000,100)).Y+4,countWidth=TextService:GetTextSize("24/24",12,Art.Font.Counter,Vector2.new(1000,100)).X+4})
	end
	local ok,problem=pcall(function()
		for _,size in ipairs({Vector2.new(1649,971),Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
			test(tostring(size).." field pack keeps control seats and complete instruction",function()
				root:ClearAllChildren();root.Size=UDim2.fromOffset(size.X,size.Y);settle()
				local l=resolved(size);local original={}
				for _,name in ipairs({"shell","tray","bezel","dpad","drop","menu","lounge"})do local r=l[name];original[name]={r.x,r.y,r.w,r.h}end
				local compact=l.short or l.dense or l.quest.h<60
				local host=Art.instrument(make("Quest",l.quest));local quest=Quest.new(host)
				local originalH=l.quest.h;Layout.fitFieldQuest(l,quest:preferredHeight(l.quest.w,l.quest.h,compact));host.Size=UDim2.fromOffset(l.quest.w,l.quest.h);settle()
				assert(l.quest.h<=originalH)
				for name,previous in pairs(original)do local r=l[name];assert(r.x==previous[1] and r.y==previous[2] and r.w==previous[3] and r.h==previous[4],name.." moved")end
				for stage=0,2 do
					quest:update(stage,"Playing",true,compact);settle();fit(quest.title)
					if stage==0 then assert(quest.title.Text:find("LEFT",1,true) or quest.title.Text:find("←",1,true))elseif stage==1 then assert(quest.title.Text:find("RIGHT",1,true) or quest.title.Text:find("→",1,true))end
					if quest.progress.Visible then fit(quest.progress);assert(quest.progress.Position.Y.Offset-(quest.title.Position.Y.Offset+quest.title.Size.Y.Offset)==3,"ticker not beside instruction pack")end
				end
				quest:update(1,"Settling",true,compact);settle();fit(quest.title)
			end)
		end
		test("inset face is clipped passive depth with no action underline or focus stroke",function()
			root:ClearAllChildren();root.Size=UDim2.fromOffset(300,200)
			local face=Art.instrument(make("Face",{x=8,y=8,w=180,h=64}));local count=#face:GetChildren();Art.instrument(face)
			assert(#face:GetChildren()==count and face.ClipsDescendants and not face.Active and not face.Selectable)
			assert(face:FindFirstChildOfClass("UICorner").CornerRadius.Offset==8 and face.InsetShadow.Size.Y.Offset==2 and face.InsetLip.Size.Y.Offset==1)
			assert(not face:FindFirstChild("Accent") and not face:FindFirstChildOfClass("UIStroke"))
			for _,node in ipairs(face:GetDescendants())do assert(not node:IsA("GuiButton"));if node:IsA("GuiObject")then assert(not node.Active and not node.Selectable)end end
		end)
		test("eight-slot capacity stays centered and accepted roll starts at previous visible slot",function()
			root:ClearAllChildren();root.Size=UDim2.fromOffset(240,120);local host=Art.instrument(make("Drops",{x=0,y=0,w=220,h=100}));local reduced=false
			local d=Dispenser.new(host,function()return reduced end);settle();d:update(1,0,24,true)
			assert(d.channel.Visible);fit(d.label)
			local first,last=d.balls[1],d.balls[8]
			local function gutters()
				return first.AbsolutePosition.X-d.channel.AbsolutePosition.X,d.channel.AbsolutePosition.X+d.channel.AbsoluteSize.X-last.AbsolutePosition.X-last.AbsoluteSize.X
			end
			local left,right=gutters()
			-- Odd leftover pixels cannot split evenly; native UDim offsets round them.
			assert(math.abs(left-right)<=1,"unequal rendered train gutters: "..left.." / "..right.." channel="..tostring(d.channel.AbsoluteSize))
			local origin=d.channel.Position+last.Position;d:update(1,1,24,true)
			assert(d.pulses==1 and d.remaining==23 and d.rolling.Visible and d.rolling.Position==origin)
			local position=last.Position;for _=1,5 do d:update(1,1,24,true)end
			assert(d.pulses==1 and last.Position==position)
			d:update(1,23,24,true);assert(d.remaining==1 and first.Visible and not d.balls[2].Visible and last.Position==position)
			reduced=true;d:update(1,24,24,true);assert(d.remaining==0 and not d.rolling.Visible)
			d:update(2,0,24,true);assert(d.remaining==24 and not d.rolling.Visible and last.Position==position)
			d:update(2,0,24,false);assert(not d.host.Visible and d.remaining==24);d:cancel()
			host.Size=UDim2.fromOffset(221,100);settle();d:layout();left,right=gutters()
			assert(math.abs(left-right)<.01,"integer remainder must split exactly: "..left.." / "..right)
		end)
		test("one visible clock closes position and velocity; hidden reduced theme and teardown stay bounded",function()
			root:ClearAllChildren();root.Size=UDim2.fromOffset(300,200);local host=make("Backdrop",{x=0,y=0,w=300,h=200});Art.backdrop(host)
			local art=host.CanopyArt;local floats,bases={},{ }
			for index=1,4 do for _,prefix in ipairs({"Leaf","Seed"})do local n=art[prefix..index];table.insert(floats,n);bases[n]={n.Position,n.Rotation}end end
			local canopy=art.Canopy1.Position
			local function pose()local out={};for _,n in ipairs(floats)do out[n]={n.Position.X.Offset,n.Position.Y.Offset,n.Rotation}end;return out end
			Art.updateBackdrop(host,0,true,false);local a=pose();Art.updateBackdrop(host,.001,true,false);local b=pose()
			Art.updateBackdrop(host,Art.BackdropPeriod,true,false);local c=pose();Art.updateBackdrop(host,Art.BackdropPeriod+.001,true,false);local d=pose()
			for _,n in ipairs(floats)do for k=1,3 do assert(math.abs(a[n][k]-c[n][k])<.0001 and math.abs((b[n][k]-a[n][k])-(d[n][k]-c[n][k]))<.0001,"loop seam")end end
			assert(art.Canopy1.Position==canopy)
			Art.tintBackdrop(host,Themes.ById.brick);local tint=floats[1].BackgroundColor3
			Art.updateBackdrop(host,20,true,true);for _,n in ipairs(floats)do assert(n.Position==bases[n][1] and n.Rotation==bases[n][2])end
			Art.updateBackdrop(host,200,false,false);for _,n in ipairs(floats)do assert(n.Position==bases[n][1])end
			Art.updateBackdrop(host,2000,true,false);local resumed=pose();for _,n in ipairs(floats)do for k=1,3 do assert(math.abs(resumed[n][k]-d[n][k])<.0001,"sampled phase changed on resume: "..n.Name.." component="..k.." before="..d[n][k].." resumed="..resumed[n][k])end end
			assert(floats[1].BackgroundColor3==tint);host:Destroy();Art.updateBackdrop(host,3000,true,false)
		end)
	end)
	root:Destroy();assert(ok,problem)
	return{passed=#cases,cases=cases,preference=game:GetService("GuiService").PreferredTextSize.Name}
end
