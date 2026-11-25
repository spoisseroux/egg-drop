-- The curious glance (PetEyeGlance), beta 19: the cute Bear's eye on the viewer's right sank into his head.
-- The straight slide moved the inward eye closer to the head's upright axis (onto the bulge of the face); the turned
-- glance keeps each eye's distance from that axis and lifts it Lift further out, and only the curious face glances.
-- Geometry is the cute Bear's rig (BearRigDefinition Head and EyeL/EyeR), posed as GardenPetVisual poses an imported eye:
-- the template is turned 180 degrees, so the eye part's own +X is the rig's -X.
-- Usage (Client): require(<ZZSpecs copy>)(StarterPlayer.StarterPlayerScripts.Client)
return function(client)
	local Glance=require(client.PetEyeGlance)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,what,eps)assert(math.abs(a-b)<=(eps or 1e-6),string.format("%s: %.6f vs %.6f",what,a,b))end
	local bear={pieces={
		{name="Body",center={0,.45458,.08202}},
		{name="Head",center={0,1.0106,.03051}},
		{name="EyeL",center={-.22632,.97168,.40853}},{name="EyeR",center={.22632,.97168,.40857}},
	}}
	local S=1.3888888888888888*1.2
	local centre=Glance.headCentre(bear,S)
	local function eye(name,head)
		local c=bear.pieces[name=="EyeL"and 3 or 4].center
		return head*CFrame.new(Vector3.new(c[1],c[2],c[3])*S)*CFrame.Angles(0,math.pi,0)
	end
	local function radius(p)return Vector3.new(p.X-centre.X,0,p.Z-centre.Z).Magnitude end
	local heads={CFrame.new(),CFrame.new(12,3,-40)*CFrame.Angles(0,1.1,0)*CFrame.Angles(.07,.2,-.12)}

	test("only the eyes and glints glance, and only while the curious face shows",function()
		for _,name in ipairs({"EyeL","EyeR","GlintL","GlintR"})do assert(Glance.applies(name,"curious","curious"),name)end
		for _,name in ipairs({"MouthSmile","BlushR","Head","EyeSparkleR"})do assert(not Glance.applies(name,"curious","curious"),name)end
		-- A squinting face drawn over a curious garden state (joy, content, a sit, a petting) keeps its eyes still.
		for _,shown in ipairs({"joy","content","pleased","affectionate","sleepy","startled","neutral"})do
			assert(not Glance.applies("EyeR","curious",shown),shown)
		end
		assert(not Glance.applies("EyeR","neutral","curious"),"a curious beat over a neutral state")
	end)

	test("the head centre is the Head piece's, scaled",function()
		near(centre.X,0,"x");near(centre.Y,1.0106*S,"y");near(centre.Z,.03051*S,"z")
		assert(Glance.headCentre({pieces={{name="Body",center={0,0,0}}}},S)==nil,"no Head piece")
	end)

	test("Bear EyeR (viewer's right): the straight slide sank it toward the face; the glance keeps it out and lifts it",function()
		local rest=eye("EyeR",CFrame.new())
		local straight=rest*CFrame.new(Glance.Aside*S,Glance.Up*S,0)
		assert(radius(straight.Position)<radius(rest.Position)-.008*S,"the old slide moved the eye in onto the face")
		local out=Glance.frame(CFrame.new(),rest,centre,S)
		near(radius(out.Position),radius(rest.Position)+Glance.Lift*S,"EyeR distance from the head axis")
		near(out.Position.Y,rest.Position.Y+Glance.Up*S,"up")
		assert(out.Position.X<rest.Position.X-.012*S,"still looks aside toward -X, like the slide")
	end)

	test("Bear EyeL: the same distance rule on the outward eye",function()
		local rest=eye("EyeL",CFrame.new())
		local out=Glance.frame(CFrame.new(),rest,centre,S)
		near(radius(out.Position),radius(rest.Position)+Glance.Lift*S,"EyeL distance from the head axis")
		assert(out.Position.X<rest.Position.X-.012*S,"aside toward -X")
	end)

	test("the eye turns with the glance (faces along the head's curve)",function()
		local rest=eye("EyeR",CFrame.new())
		local out=Glance.frame(CFrame.new(),rest,centre,S)
		local reach=rest.Position.Z-centre.Z
		local turn=math.asin(-Glance.Aside*S/reach)
		local look=rest.Rotation:ToObjectSpace(out.Rotation).LookVector
		near(math.atan2(-look.X,-look.Z),turn,"yaw of the turned eye",1e-5)
	end)

	test("the glance is the same in the head's frame wherever the head is posed",function()
		for _,name in ipairs({"EyeL","EyeR"})do
			local a=CFrame.new():ToObjectSpace(Glance.frame(CFrame.new(),eye(name,CFrame.new()),centre,S))
			local head=heads[2]
			local b=head:ToObjectSpace(Glance.frame(head,eye(name,head),centre,S))
			near((a.Position-b.Position).Magnitude,0,name.." position",1e-5)
			near((a.LookVector-b.LookVector).Magnitude,0,name.." facing",1e-5)
		end
	end)

	test("without a Head piece the eye slides as before",function()
		local rest=eye("EyeR",CFrame.new())
		local out=Glance.frame(CFrame.new(),rest,nil,S)
		local want=rest*CFrame.new(Glance.Aside*S,Glance.Up*S,0)
		near((out.Position-want.Position).Magnitude,0,"fallback slide")
	end)

	return{passed=#cases,cases=cases}
end
