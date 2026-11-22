-- Garden Dash buttons (DashInput.Core, slice S7): holds per touch, fresh presses only, Dash let go on every loss.
-- Usage (Client): require(ZZSpecs.DashInput)(StarterPlayerScripts.Client)
return function(client)
	local Input=require(client.DashInput)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function rig()
		local r={log={},ok=true,stop=false}
		r.core=Input.Core.new({press=function(kind)
			if kind=="dashUp"then table.insert(r.log,kind);return true end
			if not r.ok then return false end
			table.insert(r.log,kind);return true
		end,blocked=function()return r.stop end})
		function r.said()local text=table.concat(r.log,",");table.clear(r.log);return text end
		return r
	end
	test("nothing before GO, and a finger already down is not a press",function()
		local r=rig()
		assert(not r.core:begin("t1","dash")and not r.core:begin("t2","jump"))
		r.core:setOpen(true);r.core:step();assert(r.said()=="")
		r.core:finish("t1");assert(r.said()=="")
		assert(r.core:begin("t3","jump")and r.said()=="jump")
	end)
	test("two thumbs: dash held by one, jumps by the other; each touch is its own",function()
		local r=rig();r.core:setOpen(true)
		r.core:begin("left","dash");r.core:begin("right","jump");r.core:finish("right");r.core:begin("right2","jump")
		assert(r.said()=="dashDown,jump,jump")
		r.core:begin("shift","dash");r.core:finish("left");assert(r.said()=="","still held by another")
		r.core:finish("shift");r.core:finish("shift");assert(r.said()=="dashUp")
		r.core:begin("left","dash");assert(not r.core:begin("left","dash"));r.core:finish("left")
		assert(r.said()=="dashDown,dashUp")
	end)
	test("every loss lets Dash go, once",function()
		for _,loss in ipairs({function(r)r.core:loseAll()end,function(r)r.core:setOpen(false)end})do
			local r=rig();r.core:setOpen(true);r.core:begin("a","dash");r.core:begin("b","dash");r.said()
			loss(r);loss(r);r.core:finish("a");r.core:step()
			assert(r.said()=="dashUp")
		end
		local r=rig();r.core:setOpen(true);r.core:loseAll();assert(r.said()=="","nothing held, nothing said")
	end)
	test("a menu or a text box: nothing new starts; a let go still goes out",function()
		local r=rig();r.core:setOpen(true);r.core:begin("a","dash");r.stop=true
		assert(not r.core:begin("b","jump")and not r.core:begin("c","dash"))
		r.core:finish("a");assert(r.said()=="dashDown,dashUp")
	end)
	test("a paced out dash is tried again while held, and never after",function()
		local r=rig();r.core:setOpen(true);r.ok=false
		r.core:begin("a","dash");r.core:step();assert(r.said()=="")
		r.ok=true;r.core:step();r.core:step();assert(r.said()=="dashDown")
		r.ok=false;r.core:finish("a");assert(r.said()=="dashUp")
		r.core:begin("b","dash");r.core:finish("b");r.ok=true;r.core:step();assert(r.said()=="")
	end)
	test("a refused press is sent again: down while held, up when nobody holds it",function()
		local r=rig();r.core:setOpen(true);r.core:begin("a","dash");r.said()
		r.core.down=false;r.core:step();assert(r.said()=="dashDown") -- the server refused the dashDown
		r.core:finish("a");r.said()
		r.core.down=true;r.core:step();assert(r.said()=="dashUp") -- the server refused the dashUp
	end)
	test("the screen splits in half",function()
		for _,width in ipairs({600,667,844,1280})do
			assert(Input.zone(0,width)=="dash"and Input.zone(width/2-1,width)=="dash"and Input.zone(width/2,width)=="jump"and Input.zone(width,width)=="jump")
		end
	end)
	-- The device, on stand-in services.
	local function device()
		local r=rig()
		local function signal()
			local s={list={}}
			function s:Connect(fn)table.insert(s.list,fn);return{Disconnect=function()table.remove(s.list,table.find(s.list,fn))end}end
			function s:Fire(...)for _,fn in ipairs(table.clone(s.list))do fn(...)end end
			return s
		end
		local user={InputBegan=signal(),InputEnded=signal(),WindowFocusReleased=signal(),TextBoxFocused=signal(),GamepadDisconnected=signal()}
		local actions={BindActionAtPriority=function(_,_,fn)r.act=fn end,UnbindAction=function()r.act=nil end}
		local gui,character={MenuOpened=signal()},signal()
		r.zones={jump={InputBegan=signal()},dash={InputBegan=signal()}}
		r.stones={Activated=signal()}
		r.user,r.gui,r.character=user,gui,character
		r.left=0
		r.api=Input.mount({core=r.core,zones=r.zones,stones=r.stones,leave=function()r.left+=1 end,
			services={UserInputService=user,ContextActionService=actions,GuiService=gui,Players={LocalPlayer={CharacterRemoving=character}}}})
		function r.key(code,state)return r.act("a",Enum.UserInputState[state],{KeyCode=Enum.KeyCode[code]})end
		function r.touch(zone,state)
			local input={UserInputType=Enum.UserInputType.Touch,UserInputState=Enum.UserInputState[state],KeyCode=Enum.KeyCode.Unknown}
			r.zones[zone].InputBegan:Fire(input)
			return input
		end
		return r
	end
	test("a trigger that moves while held keeps Dash down; only End or Cancel lets go",function()
		for _,last in ipairs({"End","Cancel"})do
			local r=device();r.api.open()
			r.key("ButtonR2","Begin");for _=1,20 do r.key("ButtonR2","Change")end
			assert(r.said()=="dashDown",last)
			r.key("ButtonR2",last);assert(r.said()=="dashUp")
			r.key("ButtonR2","Change");assert(r.said()=="")
		end
	end)
	test("a finger that slides over the middle neither jumps nor holds; a fresh touch does",function()
		local r=device();r.api.open()
		r.touch("jump","Change");r.touch("dash","Change");r.touch("dash","End");assert(r.said()=="")
		local held=r.touch("dash","Begin")
		r.zones.jump.InputBegan:Fire({UserInputType=Enum.UserInputType.Touch,UserInputState=Enum.UserInputState.Change});assert(r.said()=="dashDown","it keeps its half")
		r.touch("jump","Begin");r.user.InputEnded:Fire(held);assert(r.said()=="jump,dashUp")
		-- The mouse's own move events never press either.
		r.zones.jump.InputBegan:Fire({UserInputType=Enum.UserInputType.MouseMovement,UserInputState=Enum.UserInputState.Change});assert(r.said()=="")
	end)
	test("window focus, the Roblox menu, a text box, a pulled controller and a respawn each let go; closing unbinds",function()
		for _,fire in ipairs({function(r)r.user.WindowFocusReleased:Fire()end,function(r)r.gui.MenuOpened:Fire()end,function(r)r.user.TextBoxFocused:Fire()end,
			function(r)r.user.GamepadDisconnected:Fire()end,function(r)r.character:Fire()end,function(r)r.api.close()end,function(r)r.api.destroy()end})do
			local r=device();r.api.open();r.key("LeftShift","Begin");r.said();fire(r);assert(r.said()=="dashUp")
		end
		local r=device();r.touch("jump","Begin");assert(r.said()=="","not bound yet")
		r.api.open();r.key("ButtonB","Begin");r.key("ButtonB","End");assert(r.left==1)
		r.api.close();assert(r.act==nil and not r.api.bound)
	end)
	return{passed=#cases,cases=cases}
end
