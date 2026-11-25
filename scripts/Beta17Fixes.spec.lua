-- Beta (17) QA fixes (artifacts/qa-2026-11-25-beta17/FEEDBACK.md), the pure parts:
--   U2 the PC cursor: cards register with ModalCursor and free the mouse while open (no movement lock).
--   U4 the Hatch eggs egg preview: UIScaleSpace takes the panel's UIScale back out of AbsoluteSize.
--   U6 the reveal's contact shadow: HatchAim.footprint is the middle of the item, not its lowest corner.
--   U8 a pet stuck in the air on the cliff: GardenCarePlacement also tries the remembered ground anchor.
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
	return{passed=#cases,cases=cases}
end
