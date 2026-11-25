-- Beta (17) QA fixes (artifacts/qa-2026-11-25-beta17/FEEDBACK.md), the pure parts:
--   U2 the PC cursor: cards register with ModalCursor and free the mouse while open (no movement lock).
--   U4 the Hatch eggs egg preview: UIScaleSpace takes the panel's UIScale back out of AbsoluteSize.
--   U6 the reveal's contact shadow: HatchAim.footprint is the middle of the item, not its lowest corner.
--   U8 a pet stuck in the air on the cliff: GardenCarePlacement also tries the remembered ground anchor.
--   R13 (STUDIO-CHECK-R13): a card turns the world's ProximityPrompts off; Hatch another waits out the
--   server's 0.3 s request spacing and re-sends a Throttled buy once.
-- (GardenCare.spec has U8's forced hold.) Offline: python scripts/run_dash_server_specs.py; Studio: ZZSpecs.
return function(client,offline)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local Cursor=require(client.ModalCursor)
	test("U2: a registered card frees the cursor and sinks the right button, without the movement lock",function()
		local input={MouseBehavior=Enum.MouseBehavior.LockCenter,MouseIconEnabled=false,WindowFocused=offline.signal()}
		local bound,unbound=0,0
		local actions={BindActionAtPriority=function()bound+=1 end,UnbindAction=function()unbound+=1 end}
		local held={}
		local movement={set=function(_,reason,on)held[reason]=on end,enforce=function()end,release=function()end}
		local screen,card=false,false
		local c=Cursor.new({isOpen=function()return screen end,input=input,actions=actions,movement=movement})
		local drop=Cursor.register("SpecCard",function()return card end)
		c:step();assert(input.MouseBehavior==Enum.MouseBehavior.LockCenter and not c.free,"nothing open: the camera keeps the mouse")
		card=true;c:step()
		assert(input.MouseBehavior==Enum.MouseBehavior.Default and input.MouseIconEnabled==true and c.free and bound==1)
		assert(not held.modal,"a card takes no movement lock")
		input.MouseBehavior=Enum.MouseBehavior.LockCenter;c:step();assert(input.MouseBehavior==Enum.MouseBehavior.Default,"shift lock cannot re-take it under a card")
		card=false;c:step();assert(not c.free and unbound==1)
		input.MouseBehavior=Enum.MouseBehavior.LockCenter;c:step();assert(input.MouseBehavior==Enum.MouseBehavior.LockCenter,"closed: left to the camera again")
		screen=true;c:step();assert(c.free and held.modal==true,"a screen still locks movement");screen=false;c:step();assert(held.modal==false)
		drop();card=true;c:step();assert(not c.free,"unregistered");c:destroy()
	end)
	test("U2: the registry (a throwing card is closed; a stale remover cannot drop a newer registration)",function()
		local before=Cursor.registered()
		local dropOld=Cursor.register("SpecTwice",function()return false end)
		Cursor.register("SpecTwice",function()return true end)
		dropOld();local open,key=Cursor.cardOpen();assert(open and key=="SpecTwice")
		Cursor.unregister("SpecTwice")
		local drop=Cursor.register("SpecThrows",function()error("boom")end);assert(not Cursor.cardOpen());drop()
		assert(Cursor.registered()==before)
	end)
	local Space=require(client.UIScaleSpace)
	test("U4: the egg preview's well measures in its own units at any panel scale",function()
		local function node(parent,scale,collector)
			local n={Parent=parent,ui=if scale then{Scale=scale}else nil,collector=collector}
			function n:IsA(kind)return kind=="LayerCollector"and self.collector==true end
			function n:FindFirstChildWhichIsA(kind)return if kind=="UIScale"then self.ui else nil end
			return n
		end
		local gui=node(nil,nil,true);local panel=node(gui,.85);local pane=node(panel);local well=node(pane)
		assert(math.abs(Space.scaleOf(well)-.85)<1e-9)
		local inner=node(node(node(gui,1.2),.5))
		assert(math.abs(Space.scaleOf(inner)-.6)<1e-9,"nested UIScales multiply")
		-- Plain UDim2-shaped tables (the offline mocks have no UDim2).
		local function udim2(xs,xo,ys,yo)return{X={Scale=xs,Offset=xo},Y={Scale=ys,Offset=yo}}end
		local w,h=Space.localSize(udim2(1,-4,1,-4),Vector2.new(255,102),.85)
		assert(math.abs(w-300)<1e-9 and math.abs(h-120)<1e-9,"a Scale-sized well divides the UIScale out")
		w,h=Space.localSize(udim2(0,424,0,152),Vector2.new(509,182),1.2);assert(w==424 and h==152,"offset wells use their offsets")
		w,h=Space.localSize(udim2(1,0,1,0),Vector2.new(300,100),0);assert(w==300 and h==100,"a bad scale reads as 1")
	end)
	local Aim=require(client.HatchAim)
	test("U6: the contact shadow sits under the middle of the item, not its lowest corner",function()
		-- A flat slab tipped down to the right: its lowest corner is at the right end.
		local slab={CFrame=CFrame.new(.3,.2,-.1)*CFrame.Angles(0,0,-.3),Size=Vector3.new(1.6,.2,.6)}
		local x,z=Aim.footprint({slab});assert(math.abs(x-.3)<1e-6 and math.abs(z+.1)<1e-6)
		local two={{CFrame=CFrame.new(-1,0,0),Size=Vector3.new(1,1,1)},{CFrame=CFrame.new(2,0,1),Size=Vector3.new(1,1,1)}}
		x,z=Aim.footprint(two);assert(math.abs(x-.5)<1e-9 and math.abs(z-.5)<1e-9)
		assert(Aim.footprint({})==nil and Aim.footprint(nil)==nil)
	end)
	test("Fable R13 (6): a floating toy (Bone, Ball) keeps only the stage's wide shadow; the Wobble Top keeps its contact one",function()
		assert(Aim.floats({toyId="bone"})and Aim.floats({toyId="ball"}))
		assert(not Aim.floats({toyId="wobble_top"})and not Aim.floats({toyId="sparkler"}))
		assert(not Aim.floats({itemId="bone"})and not Aim.floats(nil),"jars, finishes and pets: unchanged")
	end)
	local Placement=offline.new.require(offline.new.server.GardenCarePlacement)
	test("U8: a set-down looks beside the owner first, then at the remembered ground anchor and around it",function()
		local root={CFrame=CFrame.new(40,30,10)}
		local anchor=Vector3.new(20,4,12)
		local list=Placement.candidates({root=root,anchor=anchor})
		assert(#list==#Placement.Near+#Placement.Ground)
		assert(list[1].Y==anchor.Y and math.abs(list[1].X-42.6)<1e-6,"beside the owner, at the anchor's height")
		assert(list[#Placement.Near+1]==anchor,"then the ground anchor itself")
		for i=#Placement.Near+1,#list do assert((list[i]-anchor).Magnitude<=3.6)end
		assert(#Placement.candidates({root=root})==0,"no anchor: nothing to try")
	end)
	test("R13: while a card is open the world's prompts are off, and back as they were on every close",function()
		local prompts={Enabled=true}
		local card=false
		local c=Cursor.new({isOpen=function()return false end,prompts=prompts})
		local drop=Cursor.register("SpecPromptCard",function()return card end)
		c:step();assert(prompts.Enabled==true)
		card=true;c:step();assert(prompts.Enabled==false,"E reaches the card, not the pet behind it")
		c:step();assert(prompts.Enabled==false)
		card=false;c:step();assert(prompts.Enabled==true,"closed: restored")
		prompts.Enabled=false;card=true;c:step();card=false;c:step();assert(prompts.Enabled==false,"restores the value from before, not true")
		prompts.Enabled=true;card=true;c:step();c:destroy();assert(prompts.Enabled==true,"destroy restores too")
		drop()
	end)
	local Flow=require(client.HatchFlow)
	local function rig()
		local r={now=100,last=nil,timers={},buys=0,pages={}}
		r.state={pendingToyResult={id="t1"}}
		local toy={state=r.state,status="Saved"}
		function toy:buy()r.buys+=1;r.last=r.now;self.pending={action="toyBuy"};self.status="Pending";return true end
		r.toy=toy
		r.flow=Flow.new({intents={toyIntent=toy},state=function()return r.state end,view={},
			openHue=function(page)table.insert(r.pages,page);return true end,
			lastRequest=function()return r.last end,clock=function()return r.now end,
			after=function(seconds,fn)table.insert(r.timers,{at=r.now+seconds,fn=fn})end})
		function r:advance(seconds)
			self.now+=seconds
			local due={};for i=#self.timers,1,-1 do if self.timers[i].at<=self.now then table.insert(due,table.remove(self.timers,i))end end
			for _,t in ipairs(due)do t.fn()end
		end
		function r:stored()self.last=self.now;self.state={};self.toy.state=self.state;self.toy.pending=nil;self.toy.status="Saved"end
		function r:refused(reason)self.toy.pending=nil;self.toy.status="Rejected";self.toy.reason=reason end
		return r
	end
	test("R13: Hatch another buys only after the server's request spacing from the store",function()
		local r=rig()
		assert(r.flow:again("toy"))
		r:advance(.01);r:stored() -- the store request goes and its snapshot lands 20 ms later
		r:advance(.02);r.flow:sync()
		assert(r.buys==0 and r.flow:againPending(),"too soon: held, the card stays up")
		r.flow:sync();assert(#r.timers==1,"one timer")
		r:advance(.2);assert(r.buys==0)
		r:advance(.2);assert(r.buys==1 and r.flow.direct=="toy"and r.flow:againPending(),"sent after the spacing")
		assert(r.last-(r.now-.4)>=Flow.Spacing-.03)
	end)
	test("R13: a buy refused Throttled is sent again once; a second refusal opens the buy page",function()
		local r=rig()
		assert(r.flow:again("toy"));r:advance(.01);r:stored();r:advance(1);r.flow:sync();assert(r.buys==1)
		r:refused("Throttled");r.flow:sync()
		assert(#r.pages==0 and r.flow:againPending(),"no error page; Hatch another still waiting")
		r:advance(Flow.Spacing+.01);assert(r.buys==2 and r.flow.direct=="toy","the one re-send")
		r:refused("Throttled");r.flow:sync()
		assert(r.buys==2 and #r.pages==1 and r.pages[1]=="toyBuy"and not r.flow.direct,"only once")
		r:advance(1);assert(r.buys==2)
		-- Any other refusal is shown at once, as before.
		local q=rig();q.state={};q.toy.state=q.state;assert(q.flow:open("toy",true)and q.buys==1)
		q:refused("NeedStars");q.flow:sync();assert(#q.pages==1 and q.buys==1)
	end)
	return{passed=#cases,cases=cases}
end
