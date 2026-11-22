-- Offline Roblox mocks for scripts/run_dash_server_specs.py (appended to its bundle; `trees`, `specs` and `ORDER`
-- are its locals). Enough of the engine for the pure server and shared modules: real Vector2/Vector3 maths, flat
-- attributes and signals, JSON, a seeded Random; anything else (CFrame, Enum, Instance looks) is a stand-in.

-- Values -------------------------------------------------------------------------------------------------------
local nativeType=type
local kinds=setmetatable({},{__mode="k"})
typeof=function(value)
	local kind=nativeType(value)=="table"and getmetatable(value)and kinds[getmetatable(value)]
	return kind or nativeType(value)
end
local function vector(name,axes)
	local meta={};kinds[meta]=name
	local class={}
	local function make(...)
		local args={...}
		local v={}
		for i,axis in ipairs(axes)do v[axis]=args[i]or 0 end
		return setmetatable(v,meta)
	end
	local function map(a,b,op)
		local out={}
		for i,axis in ipairs(axes)do
			local x=if nativeType(a)=="number"then a else a[axis]
			local y=if nativeType(b)=="number"then b else b[axis]
			out[i]=op(x,y)
		end
		return make(table.unpack(out))
	end
	meta.__add=function(a,b)return map(a,b,function(x,y)return x+y end)end
	meta.__sub=function(a,b)return map(a,b,function(x,y)return x-y end)end
	meta.__mul=function(a,b)return map(a,b,function(x,y)return x*y end)end
	meta.__div=function(a,b)return map(a,b,function(x,y)return x/y end)end
	meta.__unm=function(a)return map(a,-1,function(x,y)return x*y end)end
	meta.__eq=function(a,b)for _,axis in ipairs(axes)do if a[axis]~=b[axis]then return false end end return true end
	local methods={}
	function methods.Dot(a,b)local sum=0;for _,axis in ipairs(axes)do sum+=a[axis]*b[axis]end;return sum end
	function methods.Lerp(a,b,t)return a+(b-a)*t end
	function methods.Cross(a,b)return make(a.Y*b.Z-a.Z*b.Y,a.Z*b.X-a.X*b.Z,a.X*b.Y-a.Y*b.X)end
	meta.__index=function(v,key)
		if key=="Magnitude"then return math.sqrt(methods.Dot(v,v))end
		if key=="Unit"then local m=math.sqrt(methods.Dot(v,v));return v/m end
		return methods[key]
	end
	class.new=make;class.zero=make();class.one=make(1,1,1)
	class.xAxis,class.yAxis,class.zAxis=make(1,0,0),make(0,1,0),make(0,0,1)
	return class
end
Vector3=vector("Vector3",{"X","Y","Z"})
Vector2=vector("Vector2",{"X","Y"})
-- A stand-in that answers anything with another stand-in.
local any
local anyMeta={};kinds[anyMeta]="Any"
any=function()return setmetatable({},anyMeta)end
anyMeta.__index=function(self,key)local v=any();rawset(self,key,v);return v end
anyMeta.__call=function()return any()end
anyMeta.__add=function()return any()end;anyMeta.__sub=anyMeta.__add;anyMeta.__mul=anyMeta.__add;anyMeta.__div=anyMeta.__add;anyMeta.__unm=anyMeta.__add
anyMeta.__concat=function()return "any"end;anyMeta.__tostring=function()return "any"end
anyMeta.__lt=function()return false end;anyMeta.__le=function()return false end
local colour={};kinds[colour]="Color3"
colour.__index=function(_,key)
	if key=="ToHSV"then return function()return .5,.5,.5 end end
	if key=="ToHex"then return function()return "ffffff"end end
	if key=="Lerp"then return function(a)return a end end
	return nil
end
local function color(r,g,b)return setmetatable({R=r or 0,G=g or 0,B=b or 0},colour)end
Color3={new=color,fromRGB=function(r,g,b)return color((r or 0)/255,(g or 0)/255,(b or 0)/255)end,
	fromHSV=function(h,s,v)return color(h,s,v)end,
	fromHex=function(hex)hex=string.gsub(hex,"#","");return color(tonumber(string.sub(hex,1,2),16)/255,tonumber(string.sub(hex,3,4),16)/255,tonumber(string.sub(hex,5,6),16)/255)end}
-- A rigid CFrame: position and a 3x3 rotation (rows).
do
	local meta={};kinds[meta]="CFrame"
	local IDENTITY={1,0,0,0,1,0,0,0,1}
	local function make(p,r)return setmetatable({Position=p,r=r or IDENTITY,X=p.X,Y=p.Y,Z=p.Z},meta)end
	local function turn(r,v)return Vector3.new(r[1]*v.X+r[2]*v.Y+r[3]*v.Z,r[4]*v.X+r[5]*v.Y+r[6]*v.Z,r[7]*v.X+r[8]*v.Y+r[9]*v.Z)end
	local function mul(a,b)
		local out={}
		for i=0,2 do for j=1,3 do out[i*3+j]=a[i*3+1]*b[j]+a[i*3+2]*b[3+j]+a[i*3+3]*b[6+j]end end
		return out
	end
	local function flip(r)return{r[1],r[4],r[7],r[2],r[5],r[8],r[3],r[6],r[9]}end
	local function look(at,to)
		local back=(at-to).Unit
		local right=Vector3.new(0,1,0):Cross(back);right=if right.Magnitude<1e-6 then Vector3.new(1,0,0)else right.Unit
		local up=back:Cross(right)
		return make(at,{right.X,up.X,back.X,right.Y,up.Y,back.Y,right.Z,up.Z,back.Z})
	end
	local function angles(x,y,z)
		local cx,sx,cy,sy,cz,sz=math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
		return mul(mul({1,0,0,0,cx,-sx,0,sx,cx},{cy,0,sy,0,1,0,-sy,0,cy}),{cz,-sz,0,sz,cz,0,0,0,1})
	end
	local methods={}
	function methods.Inverse(a)local r=flip(a.r);return make(turn(r,a.Position)*-1,r)end
	function methods.PointToWorldSpace(a,v)return a.Position+turn(a.r,v)end
	function methods.PointToObjectSpace(a,v)return turn(flip(a.r),v-a.Position)end
	function methods.VectorToWorldSpace(a,v)return turn(a.r,v)end
	function methods.VectorToObjectSpace(a,v)return turn(flip(a.r),v)end
	function methods.ToWorldSpace(a,b)return a*b end
	function methods.ToObjectSpace(a,b)return methods.Inverse(a)*b end
	function methods.Lerp(a,b,t)return make(a.Position:Lerp(b.Position,t),a.r)end
	meta.__index=function(a,key)
		local r=rawget(a,"r")
		if key=="LookVector"then return Vector3.new(-r[3],-r[6],-r[9])end
		if key=="RightVector"then return Vector3.new(r[1],r[4],r[7])end
		if key=="UpVector"then return Vector3.new(r[2],r[5],r[8])end
		if key=="Rotation"then return make(Vector3.zero,r)end
		return methods[key]
	end
	meta.__mul=function(a,b)
		if typeof(b)=="Vector3"then return a.Position+turn(a.r,b)end
		return make(a.Position+turn(a.r,b.Position),mul(a.r,b.r))
	end
	meta.__add=function(a,v)return make(a.Position+v,a.r)end
	meta.__sub=function(a,v)return make(a.Position-v,a.r)end
	CFrame={identity=make(Vector3.zero),lookAt=look,
		new=function(x,y,z,...)
			if typeof(x)=="Vector3"then return if y then look(x,y)else make(x)end
			return make(Vector3.new(x,y,z),if select("#",...)==9 then{...}else nil)
		end,
		Angles=function(x,y,z)return make(Vector3.zero,angles(x,y,z))end,
		fromEulerAnglesXYZ=function(x,y,z)return make(Vector3.zero,angles(x,y,z))end,
		fromOrientation=function(x,y,z)return make(Vector3.zero,mul(angles(0,y,0),mul(angles(x,0,0),angles(0,0,z))))end,
		fromEulerAnglesYXZ=function(x,y,z)return make(Vector3.zero,mul(angles(0,y,0),mul(angles(x,0,0),angles(0,0,z))))end,
		fromAxisAngle=function()return make(Vector3.zero)end}
end
Enum=any();UDim2=any();UDim=any();Rect=any();NumberRange=any();NumberSequence=any();NumberSequenceKeypoint=any()
ColorSequence=any();ColorSequenceKeypoint=any();TweenInfo=any();Font=any();RaycastParams=any();OverlapParams=any();Content=any();BrickColor=any();Ray=any();Region3=any();PhysicalProperties=any()
DateTime={now=function()return{UnixTimestampMillis=1700000000000}end,fromUnixTimestamp=function()return any()end}
Random={}
Random.__index=Random
function Random.new(seed)return setmetatable({state=bit32.bxor(math.floor(seed or os.clock()*1e6)%4294967296,2463534242)},Random)end
function Random:NextNumber(lo,hi)
	local x=self.state
	x=bit32.bxor(x,bit32.lshift(x,13));x=bit32.bxor(x,bit32.rshift(x,17));x=bit32.bxor(x,bit32.lshift(x,5))
	self.state=x
	local unit=x/4294967296
	return if lo==nil then unit else lo+(hi-lo)*unit
end
function Random:NextInteger(lo,hi)return lo+math.floor(self:NextNumber()*(hi-lo+1))end
function Random:Shuffle(list)for i=#list,2,-1 do local j=self:NextInteger(1,i);list[i],list[j]=list[j],list[i]end end
local quiet={}
warn=function(...)table.insert(quiet,table.concat({tostring((...))}," "))end
task={wait=function()end,spawn=function(fn,...)local co=if nativeType(fn)=="thread"then fn else coroutine.create(fn);local ok,e=coroutine.resume(co,...);if not ok then error(e,0)end return co end,
	defer=function()end,delay=function()end,cancel=function()end}

-- Signals, attributes, instances -------------------------------------------------------------------------------
local function signal()
	local s={list={}}
	function s:Connect(fn)
		local c={Connected=true}
		function c:Disconnect()self.Connected=false;local at=table.find(s.list,fn);if at then table.remove(s.list,at)end end
		table.insert(s.list,fn)
		return c
	end
	function s:Once(fn)return s:Connect(fn)end
	function s:Fire(...)for _,fn in ipairs(table.clone(s.list))do fn(...)end end
	return s
end
local instanceMeta={};kinds[instanceMeta]="Instance"
local methods={}
instanceMeta.__index=function(self,key)
	local m=methods[key];if m then return m end
	local props=rawget(self,"props")
	if props[key]~=nil then return props[key]end
	for _,kid in ipairs(rawget(self,"kids"))do if kid.Name==key then return kid end end
	return nil
end
instanceMeta.__newindex=function(self,key,value)
	local props=rawget(self,"props")
	if key=="Parent"then
		local old=props.Parent
		if old then local kids=rawget(old,"kids");local at=kids and table.find(kids,self);if at then table.remove(kids,at)end end
		props.Parent=value
		if value and rawget(value,"kids")then table.insert(rawget(value,"kids"),self)end
		return
	end
	props[key]=value
end
local function instance(class)
	local self=setmetatable({props={ClassName=class,Name=class},kids={},attrs={},signals={}},instanceMeta)
	if class=="RemoteEvent"or class=="UnreliableRemoteEvent"then
		local p=rawget(self,"props")
		p.OnServerEvent=signal();p.sent={}
	end
	return self
end
function methods:SetAttribute(name,value)
	if self.attrs[name]==value then return end
	self.attrs[name]=value
	local s=self.signals[name];if s then s:Fire()end
end
function methods:GetAttribute(name)return self.attrs[name]end
function methods:GetAttributeChangedSignal(name)self.signals[name]=self.signals[name]or signal();return self.signals[name]end
function methods:FindFirstChild(name)for _,kid in ipairs(self.kids)do if kid.Name==name then return kid end end return nil end
methods.WaitForChild=methods.FindFirstChild
function methods:FindFirstChildOfClass(class)for _,kid in ipairs(self.kids)do if kid.ClassName==class then return kid end end return nil end
function methods:GetChildren()return table.clone(self.kids)end
function methods:GetDescendants()local out={};local function walk(n)for _,k in ipairs(n.kids)do table.insert(out,k);walk(k)end end;walk(self);return out end
function methods:IsA(class)return self.ClassName==class end
function methods:IsDescendantOf(other)local n=self;while n do if n==other then return true end;n=n.Parent end;return false end
function methods:Destroy()self.Parent=nil end
function methods:FireClient(player,packet)table.insert(self.sent,{player=player,packet=packet})end
function methods:FireAllClients(packet)table.insert(self.sent,{packet=packet})end
function methods:GetServerTimeNow()return 0 end
Instance={new=function(class,parent)local i=instance(class);if parent then i.Parent=parent end;return i end}
workspace=instance("Workspace")

-- JSON, services, trees ----------------------------------------------------------------------------------------
local function encode(value)
	local kind=nativeType(value)
	if kind=="number"then assert(value==value and math.abs(value)<math.huge,"JSON number");return if value%1==0 and math.abs(value)<1e15 then string.format("%d",value)else string.format("%.14g",value)end
	if kind=="string"then return '"'..string.gsub(string.gsub(value,'\\','\\\\'),'"','\\"')..'"'end
	if kind=="boolean"then return tostring(value)end
	if kind~="table"then return "null"end
	if #value>0 or next(value)==nil then
		local out={};for i=1,#value do out[i]=encode(value[i])end
		return "["..table.concat(out,",").."]"
	end
	local keys={};for key in pairs(value)do table.insert(keys,tostring(key))end
	table.sort(keys)
	local byName={};for key,v in pairs(value)do byName[tostring(key)]=v end
	local out={};for i,key in ipairs(keys)do out[i]=encode(key)..":"..encode(byName[key])end
	return "{"..table.concat(out,",").."}"
end
local ESC={n="\n",t="\t",r="\r",b="\b",f="\f"}
local function decode(text)
	local at=1
	local value
	local function skip()at=string.find(text,"[^ \t\r\n]",at)or #text+1 end
	local function str()
		local parts={}
		at+=1
		while true do
			local stop=string.find(text,'["\\]',at);assert(stop,"JSON string")
			table.insert(parts,string.sub(text,at,stop-1))
			if string.sub(text,stop,stop)=='"'then at=stop+1;return table.concat(parts)end
			local c=string.sub(text,stop+1,stop+1)
			if c=="u"then table.insert(parts,utf8.char(tonumber(string.sub(text,stop+2,stop+5),16)));at=stop+6
			else table.insert(parts,ESC[c]or c);at=stop+2 end
		end
	end
	value=function()
		skip()
		local c=string.sub(text,at,at)
		if c=='"'then return str()end
		if c=="{"or c=="["then
			local out,close={},if c=="{"then "}"else "]"
			at+=1;skip()
			if string.sub(text,at,at)==close then at+=1;return out end
			while true do
				if c=="{"then
					skip();local key=str();skip();at+=1
					out[key]=value()
				else table.insert(out,value())end
				skip()
				local sep=string.sub(text,at,at);at+=1
				if sep==close then return out end
				assert(sep==",","JSON separator")
			end
		end
		local word=string.match(text,"^%a+",at)
		if word then at+=#word;return if word=="true"then true elseif word=="false"then false else nil end
		local number=string.match(text,"^[%-%+%.%deE]+",at);at+=#number
		return tonumber(number)
	end
	return value()
end
local guid=0
local heartbeat=signal()
local services={
	HttpService={JSONEncode=function(_,v)return encode(v)end,JSONDecode=function(_,text)return decode(text)end,GenerateGUID=function()guid+=1;return string.format("guid-%08d",guid)end},
	RunService={IsStudio=function()return true end,IsServer=function()return true end,IsClient=function()return false end,IsRunning=function()return true end,Heartbeat=heartbeat},
	Players={GetPlayerByUserId=function()return nil end,GetPlayers=function()return{}end},
}
local function build(name)
	local sources=trees[name]
	local loaded={}
	local game={PlaceId=0,GameId=0,PlaceVersion=1,JobId="job"}
	local folders={}
	local nodes={}
	local function folder(side)
		local f=setmetatable({},{__index=function(_,key)
			if key=="Parent"then return nil end
			if key=="FindFirstChild"or key=="WaitForChild"then return function(_,child)return folders[side][child]end end
			if key=="GetChildren"then return function()return{}end end
			local path=side.."/"..key
			if not sources[path]then return nil end
			nodes[path]=nodes[path]or setmetatable({path=path,Name=key,Parent=folders[side]},{__index={FindFirstChild=function()return nil end,GetChildren=function()return{}end}})
			return nodes[path]
		end})
		folders[side]=f
		return f
	end
	folder("shared");folder("server");folder("client")
	local replicated=instance("ReplicatedStorage")
	rawget(replicated,"props").Shared=folders.shared
	function game:GetService(service)
		if service=="ReplicatedStorage"then return replicated end
		return services[service]or any()
	end
	game.ReplicatedStorage=replicated
	local requireModule
	requireModule=function(node)
		assert(nativeType(node)=="table"and rawget(node,"path"),"require of a missing module")
		local path=rawget(node,"path")
		if loaded[path]==nil then
			local value=sources[path](node,requireModule,game)
			loaded[path]=if value==nil then true else value
		end
		return loaded[path]
	end
	return{server=folders.server,shared=folders.shared,client=folders.client,game=game,require=requireModule}
end
local new,base,live=build("new"),build("base"),build("live")
local offline={base=base,live=live,new=new,encode=encode,Instance=Instance,signal=signal,heartbeat=heartbeat,services=services,warnings=quiet}
local failed=0
for _,name in ipairs(ORDER)do
	local start=os.clock()
	local ok,result=xpcall(function()
		local spec=specs[name](new.game,new.require)
		if name=="CloseProgress"then return spec(new.require(new.server.CloseProgress))end
		if CLIENT and CLIENT[name]then return spec(new.client,offline)end
		return spec(new.server,offline)
	end,function(e)return tostring(e).."\n"..debug.traceback()end)
	if ok then
		print(string.format("PASS %s (%d cases, %.1f s)",name,result.passed,os.clock()-start))
		for _,case in ipairs(result.cases)do print("  - "..case)end
	else
		failed+=1
		print("FAIL "..name..": "..result)
		for i=math.max(1,#quiet-5),#quiet do print("  warned: "..tostring(quiet[i]))end
	end
end
if failed>0 then error(failed.." spec(s) failed")end
