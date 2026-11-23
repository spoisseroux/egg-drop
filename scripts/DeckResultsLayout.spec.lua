-- Pocket Deck results in place, the v3 look (beta 12 QA U7): the switch, the panes and the strip under them, the
-- compact action stack (128, or 164 when a label cannot share a row) and its gamepad moves. Pure.
-- Usage (Client): require(ZZSpecs.DeckResultsLayout)(StarterPlayerScripts.Client)
-- Offline: scripts/run_dash_server_specs.py
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Look=require(Shared.DeckLook)
	local Layout=require(client.DeckResultsLayout)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function measure(text,size)return #text*size*.55 end

	test("the switch: the beta place or Studio, under the build ceiling; live never",function()
		assert(Look.on({place=Look.PlaceId,studio=false})and Look.on({place=1,studio=true}))
		assert(not Look.on({place=96451847774961,studio=false}),"the live place keeps the old results")
		assert(not Look.on({place=Look.PlaceId,studio=true,ceiling=false}))
	end)
	test("Spencer's phone: the panes give up 54 pt and the strip spans all three, the whole words fit",function()
		local left,middle,right={x=8,y=10,w=125,h=261},{x=139,y=10,w=162,h=261},{x=307,y=10,w=126,h=261}
		local p=Layout.panes(left,middle,right,true)
		for _,name in ipairs({"left","middle","right"})do assert(p[name].h==261-54 and p[name].w==({left=125,middle=162,right=126})[name])end
		assert(p.strip.x==8 and p.strip.w==425 and p.strip.h==48 and p.strip.y==10+207+6,"under the panes, the full LCD width")
		assert(p.strip.w>=400,"room for the whole words")
		local plain=Layout.panes(left,middle,right,false)
		assert(plain.strip==nil and plain.left.h==261,"no strip: full height")
	end)
	test("the action stack: Replay 44, Difficulty 36, Hatch and Leave halves 40: 128 in all; a long label: 164",function()
		local a=Layout.actions(126,{"Hatch","Leave"},measure)
		assert(a.total==128 and a.paired and a.textSize==13)
		assert(a.rows[1].h==44 and a.rows[3].h==36 and a.rows[5].h==40 and a.rows[2].h==40)
		assert(a.rows[5].y==a.rows[2].y and a.rows[5].x+a.rows[5].w<a.rows[2].x and a.rows[2].x+a.rows[2].w==126-12,"side by side, 4 apart")
		assert(a.rows[3].y==a.rows[1].y+44+4 and a.rows[5].y==a.rows[3].y+36+4)
		local small=Layout.actions(126,{"Hatchling eggs","Leave"},function(text,size)return if size==11 then 40 else #text*size*.55 end)
		assert(small.paired and small.textSize==11,"too long at 13: 11")
		local long=Layout.actions(126,{"Faire éclore des oeufs","Retour au jardin"},measure)
		assert(not long.paired and long.total==164 and long.rows[5].w==long.rows[2].w and long.rows[2].y>long.rows[5].y,"two full rows")
	end)
	test("the gamepad on the stack: down to Hatch, across to Leave and back, up to Difficulty",function()
		assert(Layout.move(3,0,1,true)==5 and Layout.move(5,1,0,true)==2 and Layout.move(2,-1,0,true)==5)
		assert(Layout.move(5,0,-1,true)==3 and Layout.move(2,0,-1,true)==3)
		assert(Layout.move(1,0,1,true)==nil,"Replay keeps the old rule (down to Difficulty)")
		assert(Layout.move(5,0,1,false)==2 and Layout.move(2,0,-1,false)==3,"two full rows: up and down")
	end)
	return{passed=#cases,cases=cases}
end
