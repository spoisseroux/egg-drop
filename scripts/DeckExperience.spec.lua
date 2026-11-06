return function(client,parent)
	local Layout=require(client.DeckLayout)
	local Dispenser=require(client.DropDispenser)
	local Config=require(game.ReplicatedStorage.Shared.BoardConfig)
	local cases={}
	local function test(name,fn)fn();table.insert(cases,name)end
	local function intersects(a,b)
		return a.x<b.x+b.w-.01 and b.x<a.x+a.w-.01 and a.y<b.y+b.h-.01 and b.y<a.y+a.h-.01
	end
	for _,size in ipairs({Vector2.new(568,160),Vector2.new(568,198),Vector2.new(350,279),Vector2.new(844,330),Vector2.new(844,390),Vector2.new(390,740),Vector2.new(1650,972)})do
		test(tostring(size).." distinct screen, grips and controls",function()
			local l=Layout.resolve(size,(Config.Width+.8)/(Config.Height+.8))
			for _,name in ipairs({"wallet","quest","queue","meter","menu","lounge","dpad","drop"})do
				local r=l[name];assert(r.w>0 and r.h>0,name.." negative")
				assert(not intersects(r,l.bezel),name.." crosses LCD")
				assert(r.x>=0 and r.y>=0 and r.x+r.w<=size.X and r.y+r.h<=size.Y,name.." outside safe content")
			end
			for _,name in ipairs({"menu","lounge","dpad","drop"})do assert(l[name].w>=44 and l[name].h>=44)end
			assert(not intersects(l.quest,l.menu)and not intersects(l.quest,l.lounge),"quest covers utility")
			assert(not intersects(l.menu,l.lounge),"utility hit areas overlap")
			assert(not intersects(l.queue,l.meter)and not intersects(l.meter,l.drop),"queue/dispenser overlaps A")
		end)
	end
	local root=Instance.new("Frame");root.Size=UDim2.fromOffset(220,56);root.Parent=parent
	local reduced=false;local d=Dispenser.new(root,function()return reduced end)
	test("accepted drops pulse once; duplicate HUD and rejected taps cannot pulse",function()
		d:update(1,0,24,true);d:update(1,1,24,true);assert(d.pulses==1 and d.remaining==23)
		for _=1,12 do d:update(1,1,24,true)end;assert(d.pulses==1)
	end)
	test("rolling copy leaves the occupied slot on wide grips and the final drop",function()
		for _,remaining in ipairs({23,1})do
			d:update(100+remaining,24-remaining,24,true)
			local slot=d.balls[math.min(8,remaining)]
			local expected=d.channel.Position+slot.Position
			d:update(100+remaining,25-remaining,24,true)
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
	end)
	root:Destroy()
	return{passed=#cases,cases=cases}
end
