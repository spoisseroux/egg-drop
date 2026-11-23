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
	test("Studio check beta 12 / FABLE-REVIEW-R1 8: stat rows never overlap; a disc under 150; the rows stop 42 above the pane's foot",function()
		assert(Layout.payoutFoot()==42 and Layout.WalletBottom==8 and Layout.WalletChip==28)
		local function apart(a,b)return a.x+a.w<=b.x or b.x+b.w<=a.x end
		for paneW=96,320,2 do
			local inner=paneW-20
			for _,words in ipairs({{"Heart",22},{"Power",40},{"Energy",60},{"Somewhatlongname",130}})do
				for _,gain in ipairs({"+2","+58","+180"})do
					local gainW=measure(gain,12)
					for _,up in ipairs({false,true})do
						local g=Layout.statRow(paneW,10,words[2],gainW,up)
						assert(g.disc==(paneW<150))
						assert(g.dot.x==0 and g.dot.w==10 and g.name.x>=g.dot.x+g.dot.w)
						assert(g.name.w>=0 and g.name.w<=words[2]and g.name.truncated==(g.name.w<words[2]))
						assert(g.gain.x>=g.name.x+g.name.w,"gain after the name")
						if up then
							assert(g.pill.x+g.pill.w==inner,"the level right-aligned at the padding")
							assert(g.pill.w==(if g.disc then 14 else 34))
							if g.gain.x+g.gain.w<=g.pill.x then
								assert(g.pill.x-(g.gain.x+g.gain.w)>=(if g.disc then 4 else 6)or g.name.w==0,"the gap before the level")
							end
							assert(apart(g.gain,g.pill)or g.name.w==0 and paneW<70,"level over the gain at "..paneW)
							assert(apart(g.name,g.pill),"level over the name at "..paneW)
						else
							assert(g.gain.x+g.gain.w<=inner or g.name.w==0)
						end
					end
				end
			end
		end
		-- Spencer's phone: a 125 pane fits dot, Power, +58 and the disc, about 116 wide, with nothing cut.
		local g=Layout.statRow(125,10,math.ceil(measure("Power",12)),math.ceil(measure("+58",12)),true)
		assert(g.disc and not g.name.truncated and g.gain.x+g.gain.w+4<=g.pill.x)
	end)
	return{passed=#cases,cases=cases}
end
