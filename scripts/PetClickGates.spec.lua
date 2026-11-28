-- Beta (44) note 18, "I can't click my pet": the pure parts of the pet click's gates. A see-through GUI that "handled"
-- a click never eats it (PetClickTarget.drawn / passThrough), a world GUI (a bubble's billboard) or the core GUI still
-- do; the garden's roam gate names its first failing reason (LoungeStations.roamBlock, Studio's PetClickRefused); the
-- need bubble's touch fallback takes only the drawn bubble (NeedBubble.hits with a size), never the clear square round it.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.PetClickGates)(PlayerScripts.Client); offline in
-- scripts/run_dash_server_specs.py.
return function(client)
	local Target=require(client.PetClickTarget)
	local Stations=require(client.LoungeStations)
	local Bubble=require(client.NeedBubble)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	-- A stand-in GUI object: its class (IsA walks a tiny class table) and the drawn properties.
	local parents={TextButton="GuiButton",ImageButton="GuiButton",GuiButton="GuiObject",TextLabel="GuiObject",ImageLabel="GuiObject",
		Frame="GuiObject",ViewportFrame="GuiObject",TextBox="GuiObject",VideoFrame="GuiObject"}
	local function gui(class,props)
		local object={ClassName=class,Visible=true,BackgroundTransparency=1,Image="",ImageTransparency=0,Text="",TextTransparency=0}
		for k,v in pairs(props or {})do object[k]=v end
		function object:IsA(name)
			local at=self.ClassName
			while at do if at==name then return true end;at=parents[at]end
			return false
		end
		return object
	end

	test("drawn: a fill, a visible image or visible text is drawn; a clear frame, an empty button, hidden things are not",function()
		assert(not Target.drawn(gui("Frame")),"a clear frame")
		assert(not Target.drawn(gui("TextButton")),"a clear button with no words (a hit area)")
		assert(not Target.drawn(gui("ImageButton",{Image="rbxassetid://1",ImageTransparency=1})),"an image at full transparency")
		assert(not Target.drawn(gui("TextLabel",{Text="Hi",TextTransparency=1})))
		assert(not Target.drawn(gui("Frame",{BackgroundTransparency=0,Visible=false})),"hidden")
		assert(Target.drawn(gui("Frame",{BackgroundTransparency=.4})),"a dim shade")
		assert(Target.drawn(gui("ImageLabel",{Image="rbxassetid://1"})))
		assert(Target.drawn(gui("TextButton",{Text="Pet"})))
		assert(Target.drawn(gui("ViewportFrame")))
		assert(Target.drawn(setmetatable({},{__index=function()error("locked")end})),"unreadable: drawn, the safe side")
	end)

	test("passThrough: an unhandled tap always; a handled one only under see-through GUI; none (a billboard) keeps it",function()
		assert(Target.passThrough(false,nil)and Target.passThrough(false,{gui("TextButton",{Text="Menu"})}))
		assert(Target.passThrough(true,{gui("Frame"),gui("TextButton")}),"a clear full-screen frame 'handled' it: the pet still gets it")
		assert(not Target.passThrough(true,{gui("Frame"),gui("TextButton",{Text="Shop"})}),"a real button on top keeps it")
		assert(not Target.passThrough(true,{}),"a world GUI or the core GUI took it")
		assert(not Target.passThrough(true,nil))
	end)

	test("roamBlock: nil when the garden can roam; else the first failing check, in canRoam's order",function()
		local free={uiReady=true,mode="Room",viewMode="Room",alive=true}
		assert(Stations.canRoam(free)and Stations.roamBlock(free)==nil)
		local function with(k,v)local s=table.clone(free);s[k]=v;return s end
		assert(Stations.roamBlock(with("uiReady",false))=="uiReady")
		assert(Stations.roamBlock(with("mode","Play"))=="mode"and Stations.roamBlock(with("viewMode","Deck"))=="viewMode")
		assert(Stations.roamBlock(with("alive",false))=="alive"and Stations.roamBlock(with("busy",true))=="busy")
		assert(Stations.roamBlock(with("overlay",true))=="overlay"and Stations.roamBlock(with("textCapture",true))=="textCapture")
		local both=with("uiReady",false);both.busy=true
		assert(Stations.roamBlock(both)=="uiReady","the first one")
		assert(Stations.roamBlock(nil)=="state")
		-- every reason canRoam checks has a name: the two agree on every single-field change
		for _,check in ipairs(Stations.RoamChecks)do
			local name=check[1]
			local bad=with(name,if name=="mode"or name=="viewMode"then "Nope" elseif free[name]~=nil then false else true)
			assert(Stations.canRoam(bad)==false and Stations.roamBlock(bad)==name,name)
		end
	end)

	test("the need bubble's touch fallback: with a size only the drawn bubble (and its tail), never the clear square",function()
		local c=Vector2.new(200,200)
		local size=Vector2.new(72,72)
		assert(Bubble.hits(c+Vector2.new(0,-6),c,size),"its centre (6 px over the anchor)")
		assert(Bubble.hits(c+Vector2.new(35,0),c,size)and not Bubble.hits(c+Vector2.new(40,0),c,size),"its edge, not past it")
		assert(Bubble.hits(c+Vector2.new(0,36),c,size),"the tail under it")
		assert(not Bubble.hits(c+Vector2.new(0,42),c,size),"under the tail: the pet's head")
		assert(Bubble.hits(c+Vector2.new(0,42),c)and not Bubble.hits(c+Vector2.new(0,55),c),"no size: the old 108 px circle")
		local pill=Vector2.new(220,56)
		assert(Bubble.hits(c+Vector2.new(105,0),c,pill)and not Bubble.hits(c+Vector2.new(0,-40),c,pill),"a word pill: its own rect")
	end)

	return{passed=#cases,cases=cases}
end
