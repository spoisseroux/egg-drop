-- The Garden Dash line's rope ring and edge (beta 14 QA F2; DashRing shared, DashLine client): the numbers, the rise
-- and sink, who sees it, the root clamp and the push. Offline (scripts/run_dash_server_specs.py); fake root and clock.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.DashLine)(PlayerScripts.Client)
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Ring=require(Shared.DashRing)
	local Course=require(Shared.DashCourse)
	local Line=require(client.DashLine)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<=(e or 1e-6)end
	local centre=Ring.centre()

	test("the ring's numbers: R 4, in at 3.4, out at 6.5 for a second, round the waiting pad",function()
		assert(Ring.Radius==4 and near(Ring.Enter,3.4)and near(Ring.Stray,6.5)and Ring.StraySeconds==1 and Ring.Stakes==10)
		assert(near(centre.X,Course.Pad.x/100)and near(centre.Z,Course.Pad.z/100))
		assert(near(Ring.curve(.22),.22/.75)and near(Ring.curve(.34),.34/.75))
		for k=1,Ring.Stakes do local _,foot=Ring.stake(k);assert(near(Ring.distance(foot),Ring.Radius,1e-4),k)end
	end)
	test("who sees it: a race gathering or anyone in the line; nobody waiting, nothing",function()
		assert(Ring.wanted({phase="gather",queue={}})and Ring.wanted({phase="race",queue={7}})and Ring.wanted({phase="idle",queue={3}}))
		assert(not Ring.wanted({phase="idle",queue={}})and not Ring.wanted({phase="results",queue={}})and not Ring.wanted(nil))
	end)
	test("the server rule: walk in from outside; once in, 6.4 stays, 6.6 for a second leaves; a full ring keeps the old reach",function()
		local rec={}
		assert(Ring.rule(rec,10,3,0,16,10)and not rec.inside,"from the prompt")
		assert(Ring.rule(rec,3.4,3,1,16,10)and rec.inside)
		assert(Ring.rule(rec,6.4,3,2,16,10)and rec.strayAt==nil)
		assert(Ring.rule(rec,6.6,3,3,16,10)and rec.strayAt==3)
		assert(Ring.rule(rec,6.6,3,3.9,16,10))
		local ok,why=Ring.rule(rec,6.6,3,4,16,10);assert(not ok and why=="Strayed")
		rec={strayAt=nil};assert(Ring.rule(rec,15,3,0,16,10));ok,why=Ring.rule(rec,17,3,1,16,10);assert(not ok and why=="Far")
		rec={inside=true};Ring.rule(rec,7,3,0,16,10);assert(Ring.rule(rec,2,3,.9,16,10)and rec.strayAt==nil,"back inside clears it")
	end)
	test("the rise: stakes one after another, then the rope; plain (Reduced Motion, level 2) only fades",function()
		local rise,alpha,rope=Line.pose(0,1,false);assert(rise==0 and alpha==1 and rope==1)
		rise=Line.pose(Ring.Rise,1,false);assert(near(rise,1))
		rise=Line.pose(Ring.Rise,2,false);assert(rise<1 and rise>0)
		rise,alpha,rope=Line.pose(Ring.Rise+9*Ring.RiseLag,10,false);assert(near(rise,1)and alpha==0 and rope==1)
		_,_,rope=Line.pose(Line.Total,10,false);assert(near(rope,0))
		rise,alpha,rope=Line.pose(Ring.ReducedFade/2,1,true);assert(rise==1 and near(alpha,.5)and near(rope,.5))
		assert(Line.sag(nil)==Ring.Sag and near(Line.sag(Ring.Sway/2),Ring.SwaySag)and Line.sag(Ring.Sway)==Ring.Sag)
		local a,b=Line.nearSpans(Vector3.new(1,0,0));assert(a==1 and b==10)
		a,b=Line.nearSpans(Vector3.new(math.cos(.5),0,math.sin(.5)));assert(a==1 and b==2)
	end)
	test("the ring: built when first wanted, local and inert, up after the rise, down 2 s after nobody waits; destroy leaves nothing",function()
		local plain=false
		local line=Line.new({world=workspace,stepped=false,reduced=function()return plain end,level=function()return 0 end})
		line:frame(1/30,false,0);assert(line.folder==nil and line.state=="down","nothing until wanted")
		line:frame(1/30,true,0);assert(line.folder and line.folder.Parent==workspace and line.state=="rising")
		local parts,beams=0,0
		for _,item in ipairs(line.folder:GetChildren())do
			if item.ClassName=="Part"then
				parts+=1;assert(item.Anchored and not item.CanCollide and not item.CanQuery and not item.CanTouch and not item.CastShadow,item.Name)
				for _,kid in ipairs(item:GetChildren())do if kid.ClassName=="Beam"then beams+=1;assert(kid.FaceCamera and kid.Segments==8)end end
			end
		end
		assert(parts==20 and beams==10,parts.." "..beams)
		for _=1,40 do line:frame(1/30,true,0)end;assert(line.state=="up")
		local t=10;line:frame(1/30,false,t);line:frame(1/30,false,t+1.9);assert(line.state=="up","held up for SinkAfter")
		line:frame(1/30,false,t+2);assert(line.state=="sinking")
		for k=1,40 do line:frame(1/30,false,t+2+k/30)end;assert(line.state=="down"and line.folder.Parent==nil)
		line:frame(1/30,true,30);assert(line.state=="rising"and line.folder.Parent==workspace,"up again")
		line:destroy();assert(line.folder==nil and workspace:FindFirstChild(Line.Folder)==nil)
	end)
	test("the edge: no clamp before the root has been in; once in, back on the circle, no outward speed; a push sways and pulses once per 4 s",function()
		local root={Position=centre+Vector3.new(8,3,0),AssemblyLinearVelocity=Vector3.zero}
		root.CFrame=CFrame.new(root.Position)
		local function at(v)root.Position=v;root.CFrame=CFrame.new(v)end
		local humanoid={MoveDirection=Vector3.new(1,0,0)}
		local clock,pushes=0,0
		local line=Line.new({world=workspace,stepped=false,clock=function()return clock end,root=function()return root end,humanoid=function()return humanoid end,
			reduced=function()return false end,level=function()return 0 end,onPush=function()pushes+=1 end})
		line:frame(1/30,true,0)
		assert(not line:clampStep(),"not waiting")
		line:setWaiting(true)
		assert(not line:clampStep()and root.Position.X==centre.X+8,"walking in from the prompt")
		at(centre+Vector3.new(1,3,0));line:clampStep();assert(line.entered)
		at(centre+Vector3.new(5,3,0));root.AssemblyLinearVelocity=Vector3.new(6,-2,1)
		assert(line:clampStep())
		local p=root.CFrame.Position
		assert(near(Ring.distance(p),Ring.Enter,1e-4)and near(p.Y,centre.Y+3,1e-4),"on the Enter circle, height kept")
		assert(near(root.AssemblyLinearVelocity.X,0)and root.AssemblyLinearVelocity.Y==-2 and root.AssemblyLinearVelocity.Z==1,"outward speed gone")
		assert(pushes==1 and next(line.sway)~=nil)
		at(centre+Vector3.new(5,3,0));clock=3;line:clampStep();assert(pushes==1,"once per PushEvery")
		clock=4;at(centre+Vector3.new(5,3,0));line:clampStep();assert(pushes==2)
		humanoid.MoveDirection=Vector3.zero;clock=9;at(centre+Vector3.new(5,3,0));line:clampStep();assert(pushes==2,"no push without walking out")
		line:setWaiting(false);assert(not line.entered)
		at(centre+Vector3.new(5,3,0));assert(not line:clampStep()and root.Position.X==centre.X+5,"not waiting: free")
		line:destroy()
	end)
	return{passed=#cases,cases=cases}
end
