-- Onboarding v2 step 4 (Onboard "safecard", ONBOARDING-V2.md; Spencer: "the scaling is weird, it doesnt fit under the
-- roblox ui"): every pet reveal card (RevealStage) lays out inside the CoreUISafeInsets rect. At the spec's eight sizes,
-- each with a 58 px top inset and a 44 px side notch (on the left, and on both sides), the headline, the card, the
-- name, the line, the buttons and the hint are all inside the safe rect; the content box scales by its short side and
-- is never cropped; the card's top is at least safeTop + 8; portrait and near-square get the stacked box. Off, the
-- layout is today's to the pixel.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.RevealLayout)(PlayerScripts.Client)
return function(client)
	local Layout=require(client.RevealLayout)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local SIZES={{844,390},{932,430},{1024,768},{1366,768},{1920,1080},{2560,1080},{2560,1440},{390,844}}
	local WORDS={headline="LITTLE WONDER!",description="Soft as a nap. Hugs first, asks questions never."}
	-- A generous width estimate for the display font (wider than the real one), so the check is not flattering.
	local function measure(text,size)return #text*size*.66 end
	local function safes(W,H)
		return{{name="left notch",x=44,y=58,w=W-44,h=H-58},{name="both sides",x=44,y=58,w=W-88,h=H-58}}
	end
	local function show(r)return string.format("{%d,%d,%d,%d}",r.x,r.y,r.w,r.h)end

	test("the eight sizes: every part of the card inside the safe rect, one and two buttons",function()
		for _,size in ipairs(SIZES)do
			local W,H=size[1],size[2]
			for _,safe in ipairs(safes(W,H))do
				for _,clear in ipairs({true,false})do
					local L=Layout.geometry(W,H,clear,safe)
					for buttons=1,2 do
						local rects=Layout.rects(L,WORDS,measure,buttons)
						for name,r in pairs(rects)do
							assert(Layout.inside(r,safe),string.format("%dx%d %s (%s), %s %s outside the safe rect %s",W,H,safe.name,L.mode,name,show(r),show(safe)))
						end
					end
				end
			end
		end
	end)
	test("the box: the authored shape, scaled by the short side, centred, never cropped; the card top at least safeTop + 8",function()
		for _,size in ipairs(SIZES)do
			local W,H=size[1],size[2]
			for _,safe in ipairs(safes(W,H))do
				local box=Layout.box(safe)
				local B=Layout.Boxes[box.mode]
				assert(math.abs(box.s-math.min(safe.w/B.w,safe.h/B.h))<1e-9,"s by the short side")
				assert(Layout.inside(box,safe),W.."x"..H.." box cropped")
				assert(math.abs(box.w/box.h-B.w/B.h)<.02,"the authored shape")
				local L=Layout.geometry(W,H,true,safe)
				local _,top=Layout.wellRect(L)
				assert(top>=safe.y+Layout.CardGap,W.."x"..H.." card top "..top)
				-- positions are box origin + authored * s: nothing measured from the raw screen's right or bottom
				assert(L.boxRight==box.x+box.w and L.boxBottom==box.y+box.h and Layout.right(L)==L.boxRight)
			end
		end
	end)
	test("which box: a computer 1920 x 1080, a phone 812 x 354, portrait and near-square stacked 390 x 700",function()
		local function mode(W,H)return Layout.box({x=44,y=58,w=W-88,h=H-58}).mode end
		assert(mode(1920,1080)=="desktop"and mode(2560,1440)=="desktop"and mode(2560,1080)=="desktop"and mode(1366,768)=="desktop")
		assert(mode(844,390)=="phone"and mode(932,430)=="phone"and mode(1024,768)=="phone")
		assert(mode(390,844)=="stack")
		assert(Layout.mode(1000,900)=="stack","near-square (W < H x 1.2)")
		local L=Layout.geometry(390,844,true,{x=0,y=58,w=390,h=786})
		local _,top,_,h=Layout.wellRect(L)
		assert(L.stack and L.headY<top and L.plateY>=top+h and L.descY>L.plateY and L.btnY>L.descY,"headline, card, plate, line, button")
	end)
	test("a very long headline shrinks to the box, never past it; today's layout keeps its size",function()
		local safe={x=44,y=58,w=302,h=786}
		local L=Layout.geometry(390,844,true,safe)
		local long="A VERY LONG HEADLINE!"
		local size=Layout.headlineSize(L,long,measure)
		assert(size<math.floor(L.lineSize)and L.headX+measure(long,size)+8<=Layout.right(L),"shrunk to fit")
		local off=Layout.geometry(1920,1080,true)
		assert(Layout.headlineSize(off,long,measure)==math.floor(off.lineSize),"off: untouched")
	end)
	test("off: today's numbers to the pixel (desktop and phone, the row rule on and off)",function()
		local D=Layout.geometry(1920,1080,true)
		assert(not D.phone and D.s==1 and D.petX==800 and D.feet==842 and D.headX==88 and D.headY==76 and D.plateX==1010)
		assert(D.btnY==968 and D.meetW==300 and D.margin==88 and D.box==nil and Layout.right(D)==1920)
		local x,top,w,h=Layout.wellRect(D)
		assert(top==16 and w==1190 and x==205 and top+h==math.min(1072,math.floor(842+118)),"the card: "..x..","..top..","..w..","..h)
		local P=Layout.geometry(844,390,false)
		assert(P.phone and P.headY==math.max(64,math.floor(64*P.s))and P.plateY==math.max(100,math.floor(104*P.s)),"the phone's fixed top 60")
		local C=Layout.geometry(844,390,true)
		assert(C.playW<=P.playW,"the row rule gives Back's width first")
		assert(Layout.phoneRule(700,800)and not Layout.phoneRule(1920,1080)and Layout.compactRule(844,390))
	end)
	return{passed=#cases,cases=cases}
end
