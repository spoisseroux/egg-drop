return function(client,parent)
	local Art=require(client.DeckArt)
	local Layout=require(client.DeckLayout)
	local Dispenser=require(client.DropDispenser)
	local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local TextService=game:GetService("TextService")
	local RunService=game:GetService("RunService")
	local cases={}
	local function test(name,fn)fn();table.insert(cases,name)end
	local function intersects(a,b)
		return a.x<b.x+b.w-.01 and b.x<a.x+a.w-.01 and a.y<b.y+b.h-.01 and b.y<a.y+a.h-.01
	end
	for _,size in ipairs({Vector2.new(568,160),Vector2.new(568,198),Vector2.new(350,279),Vector2.new(640,530),Vector2.new(844,330),Vector2.new(844,390),Vector2.new(390,740),Vector2.new(1650,972)})do
		test(tostring(size).." distinct screen, grips and controls",function()
			local l=Layout.resolve(size,(Config.Width+.8)/(Config.Height+.8))
			assert(l.bezel.x>=l.shell.x and l.bezel.y>=l.shell.y and l.bezel.x+l.bezel.w<=l.shell.x+l.shell.w and l.bezel.y+l.bezel.h<=l.shell.y+l.shell.h,"bezel protrudes shell")
			if l.lateral then assert(l.dpad.w+6<=l.left.w,"rocker well protrudes rail") end
			if not l.lateral then
				for _,name in ipairs({"dpad","drop","menu","lounge"}) do
					local r=l[name]
					local extension=if name=="drop" then 6 else 4
					assert(r.x>=l.shell.x+8 and r.x+r.w<=l.shell.x+l.shell.w-8,"portrait side seam "..name)
					assert(r.y+r.h+extension<=l.shell.y+l.shell.h-8,"portrait bottom seam "..name)
				end
			end
			for _,name in ipairs({"wallet","quest","queue","meter","menu","lounge","dpad","drop"})do
				local r=l[name];assert(r.w>0 and r.h>0,name.." negative")
				assert(not intersects(r,l.bezel),name.." crosses LCD")
				assert(r.x>=0 and r.y>=0 and r.x+r.w<=size.X and r.y+r.h<=size.Y,name.." outside safe content")
			end
			for _,name in ipairs({"menu","lounge","dpad","drop"})do assert(l[name].w>=44 and l[name].h>=44)end
			assert(not intersects(l.quest,l.menu)and not intersects(l.quest,l.lounge),"quest covers utility")
			assert(not intersects(l.menu,l.lounge),"utility hit areas overlap")
			assert(not intersects(l.menu,l.dpad) and not intersects(l.lounge,l.dpad),"utility covers arrows")
			assert(not intersects(l.queue,l.meter)and not intersects(l.meter,l.drop),"queue/dispenser overlaps A")
		end)
	end
	for _,size in ipairs({Vector2.new(1649,971),Vector2.new(1280,720),Vector2.new(1024,768)}) do
		test(tostring(size).." tray-first desktop mass and bounded equal rails",function()
			local l=Layout.resolve(size,(Config.Width+.8)/(Config.Height+.8))
			assert(l.regular and l.left.w>=150 and l.left.w<=205 and l.left.w==l.right.w)
			assert(l.tray.w/l.shell.w>=.48 and l.tray.w/l.shell.w<=.55,"excess empty grip")
			assert(l.tray.h>=596 and l.tray.h<=700,"desktop LCD regressed")
			assert(math.abs(l.tray.w/l.tray.h-(Config.Width+.8)/(Config.Height+.8))<.0001)
			assert(not intersects(l.menu,l.dpad) and not intersects(l.lounge,l.dpad))
		end)
	end
	for _,size in ipairs({Vector2.new(568,160),Vector2.new(350,160),Vector2.new(350,279),Vector2.new(568,280),Vector2.new(1649,971)}) do
		test(tostring(size).." measured Large utility requirements select a safe fallback",function()
			for _,width in ipairs({78,106}) do
				local l=Layout.resolve(size,(Config.Width+.8)/(Config.Height+.8),{utilityWidth=width,queueHeight=32})
				assert(not intersects(l.menu,l.lounge) and not intersects(l.menu,l.dpad) and not intersects(l.lounge,l.dpad),"preferred utility collides with aim")
				assert(l.tray.w>=70 and l.tray.h>=120-1e-6,"preferred utility consumed tray")
				assert(l.menu.w>=44 and l.lounge.w>=44 and l.menu.h>=44 and l.lounge.h>=44)
			end
		end)
	end
	test("Largest shallow text gets full info lines beside A and tier-equivalent fallback",function()
		local l=Layout.resolve(Vector2.new(568,160),(Config.Width+.8)/(Config.Height+.8),{utilityWidth=116,lineHeight=32,queueHeight=68,walletLineHeight=38})
		assert(l.dense and l.wallet.h==32 and l.quest.h==32 and l.meter.h==32)
		assert(l.inlineQueue and not intersects(l.queue,l.meter) and not intersects(l.wallet,l.drop) and not intersects(l.meter,l.drop))
		assert(not intersects(l.quest,l.menu) and not intersects(l.menu,l.dpad) and not intersects(l.lounge,l.dpad))
		assert(l.tray.w>=70 and l.tray.h>=120-1e-6 and l.menu.h>=44 and l.lounge.h>=44)
	end)
	test("480px Largest shallow root uses narrow ledger without target overlap",function()
		local l=Layout.resolve(Vector2.new(480,160),(Config.Width+.8)/(Config.Height+.8),{utilityWidth=116,lineHeight=32,queueHeight=68,walletLineHeight=38,countWidth=68})
		assert(l.dense and l.drop.w>=44 and l.inlineQueue)
		for _,pair in ipairs({{"queue","meter"},{"meter","wallet"},{"wallet","drop"},{"menu","dpad"},{"lounge","dpad"},{"quest","menu"}}) do assert(not intersects(l[pair[1]],l[pair[2]]),table.concat(pair,"/")) end
		assert(l.tray.w>=70 and l.tray.h>=120-1e-6)
	end)
	-- The rolling-copy contract needs a visible train; preferred text can legitimately
	-- use the entire old 56px well. Reserve its measured count row plus channel room.
	local countBounds=TextService:GetTextSize("Drops left 24/24",14,Art.Font.Counter,Vector2.new(10000,10000))
	local trainHeight=math.ceil(countBounds.Y)+40
	local root=Instance.new("Frame");root.Size=UDim2.fromOffset(math.max(220,math.ceil(countBounds.X)+12),trainHeight);root.Parent=parent
	local reduced=false;local d=Dispenser.new(root,function()return reduced end)
	RunService.Heartbeat:Wait();RunService.Heartbeat:Wait()
	test("accepted drops pulse once; duplicate HUD and rejected taps cannot pulse",function()
		d:update(1,0,24,true);d:update(1,1,24,true);assert(d.pulses==1 and d.remaining==23)
		for _=1,12 do d:update(1,1,24,true)end;assert(d.pulses==1)
	end)
	test("rolling copy leaves the occupied slot on wide grips and the final drop",function()
		for _,remaining in ipairs({23,1})do
			d:update(100+remaining,24-remaining,24,true)
			assert(d.channel.Visible and d.label.TextFits,"rolling fixture must show the train and count")
			local slot=d.balls[math.min(8,remaining)]
			local expected=d.channel.Position+slot.Position
			d:update(100+remaining,25-remaining,24,true)
			assert(d.channel.Visible and d.rolling.Visible,"accepted drop did not roll from a visible channel")
			assert(d.rolling.Position==expected,"rolling ball detached from train")
		end
	end)
	test("reset, restore and lowered drops seed static counts",function()
		d:update(2,7,24,true);assert(d.pulses==3 and d.remaining==17 and not d.rolling.Visible)
		d:update(2,6,24,true);assert(d.pulses==3 and d.remaining==18)
	end)
	test("reduced effects, hide and cancel retain the authoritative count",function()
		reduced=true;d:update(2,7,24,true);assert(d.pulses==4 and not d.rolling.Visible)
		d:update(2,8,24,false);assert(not d.host.Visible and d.remaining==16 and d.pulses==4)
		d:cancel();assert(not d.rolling.Visible and d.label.Text=="Drops left 16/24")
		-- A short well intentionally yields its decorative channel to the exact counter.
		local compactLine=TextService:GetTextSize("16/24",12,Art.Font.Counter,Vector2.new(10000,10000))
		root.Size=UDim2.fromOffset(math.max(88,math.ceil(compactLine.X)+4),math.ceil(compactLine.Y)+4)
		RunService.Heartbeat:Wait();RunService.Heartbeat:Wait();d:update(2,8,24,true)
		assert(not d.channel.Visible and not d.rolling.Visible and d.label.Text=="16/24" and d.label.TextFits,"compact fallback must retain readable exact count")
		assert(d.remaining==16 and d.pulses==4)
	end)
	test("eight decorative balls retain channel padding at128px rail width",function()
		root.Size=UDim2.fromOffset(128,trainHeight)
		game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()
		d:layout();assert(d.channel.Visible and d.label.TextFits,"padded train fixture must be visible")
		for _,ball in ipairs(d.balls) do
			assert(ball.Position.X.Offset>=6 and ball.Position.X.Offset+ball.Size.X.Offset<=d.channel.AbsoluteSize.X-6,"ball crosses padded channel")
		end
	end)
	root:Destroy()
	return{passed=#cases,cases=cases}
end
