-- Show me (ThingsTrail): prints along a way, dry ways and the bridge, the marker alone when there is no way, every ending, and
-- that nothing is left in the world or can be touched. Fake paths; its own folder in the workspace.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.ThingsTrail)(PlayerScripts.Client)
return function(client)
	local Trail=require(client.ThingsTrail)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function V(x,z)return Vector3.new(x,4.5,z)end
	local function straight(a,b)return{a,b}end
	test("prints: at most Parts, evenly spaced, off both ends, left and right",function()
		for _,length in ipairs({10,50,128,240})do
			local prints=Trail.prints({V(0,0),V(length/2,0),V(length,0)},Trail.Parts)
			assert(#prints>0 and #prints<=Trail.Parts,length)
			for i,p in ipairs(prints)do
				assert(p.position.X>=Trail.Step-.01 and p.position.X<=length-.9,"off both ends "..p.position.X)
				assert(math.abs(math.abs(p.position.Z)-Trail.Side)<.01 and(p.position.Z>0)==((i%2==1)==(prints[1].position.Z>0)),"sides")
				if i>1 then assert(p.position.X-prints[i-1].position.X>=Trail.Step-.01)end
			end
		end
		assert(#Trail.prints({V(0,0),V(3,0)},Trail.Parts)==0 and #Trail.prints({V(0,0)},Trail.Parts)==0 and #Trail.prints({V(0,0),V(0,0),V(0,0)},Trail.Parts)==0)
	end)
	test("the garden: spawn to the park and to the race are dry in a line; the far bank goes over the bridge",function()
		local spawnAt=V(96,66)
		assert(Trail.dry({spawnAt,V(51.5,63.2)})and Trail.dry({spawnAt,V(72,-8)}))
		assert(not Trail.dry({V(20,40),V(-20,40)}),"the stream")
		assert(Trail.dry({V(14,21),V(-9,21)}),"the bridge")
		-- The stream has no gaps at its joints (2026-11-22: a stud of bank on every box opened this line, beside the bridge).
		assert(not Trail.dry({V(14.3,14.8),V(-7.4,18.1)}),"the stream beside the bridge")
		assert(Trail.dry({V(55.2,5.7),V(59,4.3)}),"past the Bubble Spring's rim")
		-- The mesh's seam: no straight dry way to the bridge's west end, so by the spelled-out approach.
		local hub=V(-25,0)
		local function seam(from,to)
			if from==hub and math.abs(to.Z-21)<1 then return{from,V(3,10),to}end
			return{from,to}
		end
		local over=Trail.route(seam,hub,V(40,30))
		assert(over and Trail.dry(over)and table.find(over,Trail.West[1])~=nil and table.find(over,Trail.West[2])~=nil,"by the west approach")
		local way=Trail.route(straight,V(20,40),V(-20,40))
		assert(way and #way>=4 and Trail.dry(way),"over the bridge")
		assert(Trail.route(function()return nil end,spawnAt,V(51,63))==nil and Trail.route(function()return{V(0,0)}end,spawnAt,V(51,63))==nil)
		assert(Trail.route(straight,spawnAt,V(51,63),function()return false end)==nil,"never a line over water")
	end)
	test("Garden finds: every spot is dry ground, so Show me can end a trail there (never over water)",function()
		local Finds=require(game:GetService("ReplicatedStorage").Shared.Finds)
		for index=1,#Finds.Spots do
			local at=Finds.position(index)
			for _,step in ipairs({Vector3.new(1,0,0),Vector3.new(0,0,1)})do
				assert(Trail.dry({at-step,at+step}),"spot "..index.." ("..Finds.Spots[index].lawn..")")
			end
		end
	end)
	test("fades: in one after the other, out together; Reduced Motion has none",function()
		assert(Trail.alpha(1,0,20,false)==1 and math.abs(Trail.alpha(1,5,15,false)-Trail.Clear)<.001 and Trail.alpha(1,5,0,false)==1)
		assert(Trail.alpha(30,.5,15,false)>Trail.alpha(1,.5,15,false)and Trail.alpha(1,0,20,true)==Trail.Clear and Trail.alpha(40,0,0,true)==Trail.Clear)
	end)
	local function P(x,z)return V(x+20,z+66)end -- on the dry lawn by the arrival park
	local function rig(extra)
		local r={at=P(0,0),open=true,menu=false}
		local deps={world=workspace,step=false,root=function()return r.at end,free=function()return r.open end,busy=function()return r.menu end,
			compute=straight,reduced=function()return r.still==true end,spawn=function(fn)task.spawn(fn)end}
		for key,value in pairs(extra or {})do deps[key]=value end
		r.trail=Trail.new(deps)
		function r.parts()
			local n=0
			local folder=workspace:FindFirstChild("EggDropShowMe")
			for _,item in ipairs(folder and folder:GetChildren()or {})do if item.Name=="Print"then n+=1 end end
			return n,folder
		end
		return r
	end
	local far={position=P(60,0),name="Pet Park"}
	test("laid: prints and the marker, local parts nothing can touch; every ending takes all of them away",function()
		for reason,finish in pairs({arrived=function(r)r.at=P(53,0)end,left=function(r)r.open=false end,menu=function(r)r.menu=true end,time=function()end})do
			local r=rig()
			assert(r.trail:start(far)and r.trail:active())
			local n,folder=r.parts();assert(n>5 and n<=Trail.Parts and folder:GetAttribute("Way")=="prints")
			for _,item in ipairs(folder:GetChildren())do assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch and not item.CastShadow,item.Name)end
			r.trail:step(1);assert(r.trail:active())
			finish(r)
			for _=1,21 do r.trail:step(1)end
			assert(not r.trail:active()and r.trail.reason==reason,reason.." got "..tostring(r.trail.reason))
			n,folder=r.parts();assert(folder==nil,"nothing left in the world: "..reason)
			r.trail:destroy()
		end
	end)
	test("the menu that started it may take a moment to close; death ends it; a new trail replaces it",function()
		local r=rig();r.menu=true
		assert(r.trail:start(far));r.trail:step(.3);assert(r.trail:active());r.trail:step(.4);assert(not r.trail:active())
		r.menu=false;assert(r.trail:start(far));r.at=nil;r.trail:step(.1);assert(not r.trail:active()and r.trail.reason=="left")
		r.at=P(0,0);assert(r.trail:start(far)and r.trail:start({position=P(0,90),name="x"}))
		local n=r.parts();assert(n<=Trail.Parts);r.trail:destroy();assert(select(2,r.parts())==nil)
	end)
	test("no way: the marker only; a way that comes back late is dropped",function()
		local r=rig({compute=function()return nil end});assert(r.trail:start(far))
		local n,folder=r.parts();assert(n==0 and folder and folder:GetAttribute("Way")=="none"and folder:FindFirstChild("Marker"));r.trail:destroy()
		r=rig({compute=function()error("boom")end});assert(r.trail:start(far)and r.parts()==0);r.trail:destroy()
		local later
		r=rig({spawn=function(fn)later=fn end});assert(r.trail:start(far)and r.parts()==0);r.trail:stop("menu");later();assert(select(2,r.parts())==nil)
		r.trail:destroy()
	end)
	test("the pin (beta 14 Q1): 150 x 48, hidden past 28 studs, fading in to 22, full nearer; with no way, at any distance; a name that changes",function()
		assert(Trail.PinSize==Vector2.new(150,48)and Trail.PinText==15)
		assert(Trail.pinAlpha(30,"prints")==1 and Trail.pinAlpha(28,"prints")==1 and math.abs(Trail.pinAlpha(25,"finding")-.5)<1e-9)
		assert(Trail.pinAlpha(22,"prints")==0 and Trail.pinAlpha(10,"prints")==0 and Trail.pinAlpha(60,"none")==0)
		local ready=false
		local r=rig();assert(r.trail:start({position=P(60,0),name=function()return if ready then "Hatch!"else "Napping egg"end}))
		local pin=r.trail.pin;assert(pin.Size~=nil and not pin.Enabled and r.trail.plate.Text=="Napping egg","60 studs: no pin")
		r.at=P(35,0);r.trail:step(.1);assert(pin.Enabled and math.abs(r.trail.plate.TextTransparency-.5)<1e-6,"25 studs: half")
		ready=true;r.at=P(45,0);r.trail:step(.1);assert(pin.Enabled and r.trail.plate.TextTransparency==0 and r.trail.plate.Text=="Hatch!")
		r.trail:destroy()
		r=rig({compute=function()return nil end});assert(r.trail:start(far));r.trail:step(.1);assert(r.trail.pin.Enabled,"no way: the pin is the guide")
		r.trail:destroy()
	end)
	test("refused: no place, nobody there, not in the garden; on the spot the marker shows a moment",function()
		local r=rig();assert(not r.trail:start({name="x"})and not r.trail:start(nil));r.open=false;assert(not r.trail:start(far));r.open=true;r.at=nil;assert(not r.trail:start(far))
		r.at=P(58,0);assert(r.trail:start(far));assert(r.parts()==0);r.trail:step(1);assert(r.trail:active());r.trail:step(3);assert(not r.trail:active()and r.trail.reason=="arrived")
		r.trail:destroy()
	end)
	return{passed=#cases,cases=cases}
end
