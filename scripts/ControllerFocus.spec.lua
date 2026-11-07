-- Real LocalScript/ScreenGui host; deterministic post-input queue models held A semantics.
-- Native dispatch is simulated only to count Pass/Sink; root separately tests actual controller input.
return function(client,parent)
	assert(parent:IsA("ScreenGui"),"ScreenGui host required")
	local Focus=require(client.ControllerFocus)
	local U,S,R=Enum.UserInputType,Enum.UserInputState,Enum.ContextActionResult
	local cases,fixtures={},{}
	local function test(name,run)run();table.insert(cases,name)end
	local function settle()game:GetService("RunService").Heartbeat:Wait();game:GetService("RunService").Heartbeat:Wait()end
	local function fixture()
		local layer=Instance.new("ScreenGui");layer.Name="_ControllerFocusSemantic";layer.Parent=parent.Parent
		local frame=Instance.new("Frame");frame.Size=UDim2.fromOffset(600,350);frame.Parent=layer
		local other=frame:Clone();other.Parent=layer
		local function button(owner,x)
			local b=Instance.new("TextButton");b.Size,b.Position=UDim2.fromOffset(44,44),UDim2.fromOffset(x,8)
			b.Selectable,b.Interactable,b.Parent=true,true,owner;return b
		end
		local f={layer=layer,frame=frame,other=other,kind=U.MouseMovement,down={},queue={},writes=0,activations=0,nativePress={}}
		f.target,f.close,f.native=button(frame,4),button(frame,60),button(frame,116)
		f.nextTarget=button(other,4)
		f.owner={root=frame,epoch=1,target=function()return f.target end,fallback=f.close}
		f.context={owner=f.owner};f.playerGui=game.Players.LocalPlayer.PlayerGui
		settle()
		f.co=Focus.new({read=function()return f.context end,playerGui=function()return f.playerGui end,
			input=function()return f.kind end,aDown=function(device)return f.down[device]==true end,
			selected=function()return f.selected end,select=function(target)f.writes+=1;f.selected=target end,
			afterInput=function(run)table.insert(f.queue,run)end})
		function f:flush()local queue=self.queue;self.queue={};for _,run in ipairs(queue)do run()end end
		function f:input(state,device)
			device=device or U.Gamepad1
			if state==S.Begin then self.down[device]=true elseif state==S.End or state==S.Cancel then self.down[device]=false end
			local result=self.co:handleA(state,{KeyCode=Enum.KeyCode.ButtonA,UserInputType=device})
			if result==R.Pass and state==S.Begin then self.nativePress[device]=self.selected
			elseif state==S.End then
				if result==R.Pass and self.nativePress[device] and self.nativePress[device]==self.selected then self.activations+=1 end
				self.nativePress[device]=nil
			elseif state==S.Cancel then self.nativePress[device]=nil end
			return result
		end
		function f:pad(device)self.kind=device or U.Gamepad1;self.co:onInputTypeChanged(self.kind)end
		function f:begin(device)self:pad(device);return self:input(S.Begin,device)end
		table.insert(fixtures,f);return f
	end
	local ok,problem=pcall(function()
		test("first A is focus-only through held release; next fresh A passes to native activation",function()
			local f=fixture();assert(f:begin()==R.Sink);f:flush();assert(not f.selected and f.activations==0)
			assert(f:input(S.Change)==R.Sink and f:input(S.End)==R.Sink and not f.selected)
			f:flush();assert(f.selected==f.target and f.writes==1 and f.activations==0)
			assert(f:input(S.Begin)==R.Pass and f:input(S.End)==R.Pass and f.activations==1)
		end)
		test("actual Gamepad Begin captures before UIS changes and same-device notification preserves it",function()
			local f=fixture();assert(f:input(S.Begin)==R.Sink and f.kind==U.MouseMovement)
			f:pad();f:flush();assert(not f.selected)
			assert(f:input(S.End)==R.Sink);f:flush();assert(f.selected==f.target and f.activations==0)
		end)
		test("release before the delayed UIS notification waits for that current device",function()
			local f=fixture();assert(f:input(S.Begin)==R.Sink and f:input(S.End)==R.Sink)
			f:flush();assert(not f.selected);f:pad();f:flush();assert(f.selected==f.target and f.writes==1)
		end)
		test("native Dpad focus wins before deferred fallback",function()
			local f=fixture();f:pad();f.selected=f.native;f.co:onNavigation({UserInputType=U.Gamepad1});f:flush()
			assert(f.selected==f.native and f.writes==0 and f.activations==0)
		end)
		test("Dpad seeds once when native direction leaves no selection",function()
			local f=fixture();f:pad();f.co:onNavigation({UserInputType=U.Gamepad1});f:flush()
			for _=1,4 do f.co:onNavigation({UserInputType=U.Gamepad1});f:flush()end
			assert(f.selected==f.target and f.writes==1)
		end)
		test("already focused A passes even before input type updates",function()
			local f=fixture();f.selected=f.native
			assert(f:input(S.Begin)==R.Pass and f:input(S.End)==R.Pass and f.activations==1 and f.writes==0)
		end)
		test("repeat and duplicate held Begin never focus before release or dispatch twice",function()
			local f=fixture();assert(f:begin()==R.Sink)
			for _=1,5 do assert(f:input(S.Change)==R.Sink and f:input(S.Begin)==R.Sink);f:flush();assert(not f.selected)end
			f:input(S.End);f:flush();f:input(S.End);f:flush();assert(f.writes==1 and f.activations==0)
		end)
		test("same-instance close and reopen invalidate the captured generation",function()
			local f=fixture();f:begin();f.context.owner=nil;f.co:onOwnerChanged()
			f.owner.epoch+=1;f.context.owner=f.owner;f.co:onOwnerChanged();f:flush()
			assert(f:input(S.End)==R.Sink);f:flush();assert(not f.selected and f.writes==0)
			f:input(S.Begin);f:input(S.End);f:flush();assert(f.selected==f.target)
		end)
		test("sheet switch drains old A without focusing its successor",function()
			local f=fixture();f:begin();f.context.owner={root=f.other,epoch=1,target=function()return f.nextTarget end}
			f.co:onOwnerChanged();f:flush();f:input(S.End);f:flush();assert(not f.selected)
			f:input(S.Begin);f:input(S.End);f:flush();assert(f.selected==f.nextTarget and f.activations==0)
		end)
		test("pointer return cancels focus but drains the original controller gesture",function()
			local f=fixture();f:begin();f.kind=U.Touch;f.co:onInputTypeChanged(f.kind)
			assert(f:input(S.End)==R.Sink);f:flush();assert(not f.selected)
			f:begin();f:input(S.End);f:flush();assert(f.selected==f.target)
		end)
		test("CoreGui or text capture immediately passes A and clears held acquisition",function()
			for _=1,2 do local f=fixture();f:begin();f.context.native=true;f.co:onOwnerChanged()
				assert(f:input(S.End)==R.Pass and next(f.co.holds)==nil);f:flush();assert(not f.selected)
				assert(f:input(S.Begin)==R.Pass and f:input(S.End)==R.Pass and f.writes==0)
			end
		end)
		test("busy transition focus result recap and absent owners cannot acquire or intercept",function()
			for _,excluded in ipairs({"busy","transition","focus","result","recap","board","roam"})do
				local f=fixture();f.context.blocked=true;f.co:onOwnerChanged()
				assert(f:begin()==R.Pass and f:input(S.End)==R.Pass,excluded);f:flush();assert(f.writes==0)
			end
		end)
		test("outside-owner and destroyed targets fall back to neutral close only",function()
			for _,invalid in ipairs({"outside","destroyed","hidden","disabled","unselectable"})do
				local f=fixture()
				if invalid=="outside"then f.target.Parent=f.other elseif invalid=="destroyed"then f.target:Destroy()
				elseif invalid=="hidden"then f.target.Visible=false elseif invalid=="disabled"then f.target.Interactable=false else f.target.Selectable=false end
				f:pad();f:flush();assert(f.selected==f.close,invalid)
			end
		end)
		test("no live target means no focus write and no action",function()
			local f=fixture();f.owner.fallback=nil;f.target.Visible=false;f:pad();f:flush()
			assert(not f.selected and f.writes==0 and f.activations==0)
		end)
		test("hidden ancestor disabled layer and detached PlayerGui reject the owner",function()
			for _,invalid in ipairs({"ancestor","layer","playergui"})do
				local f=fixture();if invalid=="ancestor"then f.frame.Visible=false elseif invalid=="layer"then f.layer.Enabled=false else f.playerGui=Instance.new("Folder")end
				f:pad();f:flush();assert(f.writes==0,invalid)
				if invalid=="playergui"then f.playerGui:Destroy()end
			end
		end)
		test("ensure-visible cannot focus a target after its owner changes synchronously",function()
			local f=fixture();f.owner.ensure=function()
				f.context.owner={root=f.other,epoch=1,target=function()return f.nextTarget end};f.co:onOwnerChanged()
			end
			f:pad();f:flush();assert(f.writes==0 and not f.selected)
		end)
		test("disconnect with no End clears that device hold and reconnect can acquire",function()
			local f=fixture();f:begin();f.co:onGamepadDisconnected(U.Gamepad1);f.down[U.Gamepad1]=false
			assert(next(f.co.holds)==nil);assert(f:begin()==R.Sink);f:input(S.End);f:flush()
			assert(f.selected==f.target and f.activations==0)
		end)
		test("two gamepads retain distinct captured gestures through either release order",function()
			for _,first in ipairs({U.Gamepad1,U.Gamepad2})do
				local f=fixture();assert(f:begin(U.Gamepad1)==R.Sink and f:begin(U.Gamepad2)==R.Sink)
				assert(f.co.holds[U.Gamepad1] and f.co.holds[U.Gamepad2])
				f:input(S.End,first);f:flush();assert(not f.selected)
				f:input(S.End,if first==U.Gamepad1 then U.Gamepad2 else U.Gamepad1);f:flush()
				assert(f.selected==f.target and f.writes==1 and f.activations==0 and next(f.co.holds)==nil)
			end
		end)
		test("disconnecting the older device releases a completed newer-device handoff",function()
			local f=fixture();f:begin(U.Gamepad1);f:begin(U.Gamepad2);f:input(S.End,U.Gamepad2);f:flush();assert(not f.selected)
			f.co:onGamepadDisconnected(U.Gamepad1);f:flush();assert(f.selected==f.target and f.activations==0)
		end)
		test("Cancel drains the old press and permits a fresh focus-only press",function()
			local f=fixture();f:begin();assert(f:input(S.Cancel)==R.Sink);f:flush();assert(not f.selected)
			assert(f:input(S.Begin)==R.Sink);f:input(S.End);f:flush();assert(f.selected==f.target)
		end)
		test("current device change before deferred execution prevents acquisition",function()
			local f=fixture();f:pad();f.kind=U.MouseMovement;f:flush();assert(not f.selected)
		end)
		test("destroy disconnects watches cancels queued tasks and passes subsequent input",function()
			local f=fixture();local event=Instance.new("BindableEvent");f.co:watch(event.Event)
			f:pad();f.co:destroy();event:Fire();f:flush()
			assert(f.writes==0 and #f.co.connections==0 and f:input(S.Begin)==R.Pass);event:Destroy()
		end)
	end)
	for _,f in ipairs(fixtures)do f.co:destroy();f.layer:Destroy()end;assert(ok,problem)
	return{passed=#cases,cases=cases,heldInputIsSemanticFixture=true}
end
