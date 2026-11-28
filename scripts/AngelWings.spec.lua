-- Angel Wings, lane E of rotation slice 2 (ROTATION-2-BRIEF 3, ARCH-REVIEW-ROTATION-2 2 and 3): the client look's pure
-- rules. The rows the Bear (and the inheriting Bunny) carries on Back for `angelwings` (lane A's; a fixture of the same
-- shape when this tree does not have them yet), the grown wings hidden while worn, the 1.25x about each wing's root, the
-- halo (8 cylinders on the ring's tangent, .12 over the crown, .28 with a Hat, +-.02 on a 3 s sine, still when reduced),
-- the sparkle finish read from a BASE row (no variant tint), the preview pose (35 degrees, 15% back), the closet's
-- owned-only Back cards, and the flap resting under Reduced Motion / Motion: Low.
-- Offline: scripts/run_dash_server_specs.py (client). Studio: require(PlayerScripts.Client.ZZSpecs.AngelWings)(Client).
return function(client)
	local Wings=require(client.AngelWings)
	local Motion=require(client.PetIdleMotion)
	local Finish=require(client.WearableFinish)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Defs=require(Shared.PetRigDefinitions)
	local Rules=require(Shared.PetAttachmentRules)
	local Catalog=require(Shared.WearableCatalog)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function near(a,b,e)return math.abs(a-b)<(e or 1e-6)end
	local bear=Defs.pip

	-- Lane A's rows when merged, else a fixture of the agreed shape (ARCH-REVIEW-ROTATION-2 3: rows on Back pointing at
	-- the stage 5 wing meshes with their own Snow colour).
	local function rowsOf(definition)
		local rows={}
		for _,a in ipairs(definition.attachments or {})do if a.item==Wings.Id then table.insert(rows,a)end end
		return rows
	end
	local laneA=#rowsOf(bear)>0
	local rig=bear
	if not laneA then
		rig=table.clone(bear)
		local list=table.clone(bear.attachments)
		for _,a in ipairs(bear.attachments)do
			if a.feature=="wings"and a.stage==5 then
				table.insert(list,{name="Angel"..a.name,template=a.name,slot="Back",anchor=a.anchor,channel=a.channel,colorRole="own",
					color=Wings.Snow,item=Wings.Id,side=a.side,center=a.center,size=a.size})
			end
		end
		rig.attachments=list
	end

	test("the rows: two on Back, one per wing root, cloning the stage 5 wing meshes",function()
		local rows=rowsOf(rig)
		assert(#rows==2,"two wing rows")
		local sides={}
		for _,a in ipairs(rows)do
			assert(a.slot=="Back"and(a.anchor=="WingL"or a.anchor=="WingR"),"Back, on a wing root")
			assert(Wings.templateName(a)==string.sub(a.anchor,1,5).."_S5","the stage 5 mesh: "..tostring(Wings.templateName(a)))
			sides[a.anchor]=true
		end
		assert(sides.WingL and sides.WingR)
		assert(Wings.templateName({name="WingL_S5"})=="WingL_S5"and Wings.templateName({name="X",template="WingR_S5"})=="WingR_S5")
		assert(Wings.templateName({name="X",template=""})=="X"and Wings.templateName(nil)==nil)
		if laneA then
			-- The Bunny inherits the Bear's attachments (PetRigDefinitions inheritFromBear).
			assert(#rowsOf(Defs.blip)==2,"the Bunny wears them too")
		end
	end)

	test("worn, it hides the grown wings; off, they come back",function()
		local worn=Rules.resolve(rig,{wings=5},{Back=Wings.Id})
		assert(worn.stages.wings==0,"grown wings rest while worn")
		local shown=0
		for _,a in ipairs(worn.show)do
			assert(a.feature~="wings","no grown wing piece shows")
			if a.item==Wings.Id then shown+=1 end
		end
		assert(shown==2,"both angel wings show")
		local bare=Rules.resolve(rig,{wings=5},{})
		assert(bare.stages.wings==5,"taking it off brings them back")
		for _,a in ipairs(bare.show)do assert(a.item~=Wings.Id)end
		-- An older build (no rows) drops the unknown id and keeps everything else.
		assert(Rules.normalize(bear,{Back=Wings.Id,Hat="beanie"}).Hat=="beanie")
	end)

	test("the look: Snow, 1.25x about each wing's own root (the root stays put, the rotation is kept)",function()
		local look=Wings.look(Wings.Id)
		assert(look and look.scale==1.25 and look.color=="#F4F6FB"and look.halo==true and look.finish=="sparkle")
		assert(Wings.look("beanie")==nil and Wings.look(nil)==nil)
		local root=Vector3.new(table.unpack(bear.anchors.WingL))
		local s5;for _,a in ipairs(bear.attachments)do if a.name=="WingL_S5"then s5=a end end
		local center=Vector3.new(table.unpack(s5.center))
		local turned=CFrame.new(center)*CFrame.Angles(0,.4,0)
		local grown=Wings.scaleAbout(turned,root,1.25)
		local want=root+(center-root)*1.25
		assert(near(grown.Position.X,want.X)and near(grown.Position.Y,want.Y)and near(grown.Position.Z,want.Z),"reach x1.25")
		assert(near(grown.LookVector.X,turned.LookVector.X)and near(grown.LookVector.Z,turned.LookVector.Z),"rotation kept")
		local still=Wings.scaleAbout(CFrame.new(root),root,1.25)
		assert(near((still.Position-root).Magnitude,0),"the root stays put")
		assert(Wings.scaleAbout(turned,root,1)==turned and Wings.scaleAbout(turned,nil,1.25)==turned)
	end)

	test("the halo: a true ring of 8 cylinders, radius .13, tube .022, on the tangent, closed",function()
		local H=Wings.Halo
		assert(H.segments==8 and H.radius==.13 and H.tube==.022 and H.color=="#FFE08A"and H.reflectance==.15)
		for _,scale in ipairs({1,1.3888888888888888})do
			local segments=Wings.haloSegments(scale)
			assert(#segments==8)
			local chord=2*H.radius*math.sin(math.pi/8)*scale
			for _,segment in ipairs(segments)do
				local p=segment.frame.Position
				assert(near(p.Y,0)and near(p.Magnitude,H.radius*scale,1e-5),"on the ring")
				local axis=segment.frame.RightVector -- a Cylinder's axis is X
				assert(near(axis.Y,0,1e-6)and near(axis:Dot(p.Unit),0,1e-5),"along the tangent, level")
				assert(near(segment.size.Y,H.tube*2*scale)and near(segment.size.Z,H.tube*2*scale))
				assert(segment.size.X>=chord and segment.size.X<=chord*1.15,"just longer than its chord: no gaps")
			end
		end
	end)

	test("the halo sits .12 over the crown, .28 with a Hat on",function()
		assert(Wings.haloLift({show={}})==.12 and Wings.haloLift(nil)==.12)
		assert(Wings.haloLift({show={{slot="Back",item=Wings.Id}}})==.12)
		assert(Wings.haloLift({show={{slot="Hat",item="beanie"}}})==.28)
		assert(Wings.haloLift({show={{slot="Hat",feature="horns"}}})==.12,"only a worn hat lifts it")
		assert(bear.anchors.HatCrown and Defs.blip.anchors.HatCrown,"both rigs have the crown anchor")
	end)

	test("the halo bobs +-.02 on a 3 s sine; reduced it is still",function()
		assert(Wings.Halo.bob==.02 and Wings.Halo.period==3)
		assert(near(Wings.haloBob(0),0)and near(Wings.haloBob(.75),.02)and near(Wings.haloBob(2.25),-.02)and near(Wings.haloBob(3),0,1e-9))
		for i=0,300 do local b=Wings.haloBob(i*.01);assert(math.abs(b)<=.02+1e-9)end
		assert(Wings.haloBob(.75,true)==0 and Wings.haloBob(0/0)==0)
		assert(Motion.HaloBob==Wings.Halo.bob,"the pose padding covers the bob")
	end)

	test("the sparkle finish comes from the BASE row (no variant tint)",function()
		-- Lane A's catalogue row (an egg-only base under math.huge), or a fixture of its shape.
		local item=Catalog.forPet("pip",math.huge).byId[Wings.Id]
		if item then
			assert(item.slot=="Back"and item.egg==true and item.variant~=true and item.finish=="sparkle","lane A's row")
			assert(Catalog.forPet("pip").byId[Wings.Id]==nil,"never sold (not in this week's list)")
			assert(Catalog.forPet("blip",math.huge).byId[Wings.Id],"the Bunny has it")
		end
		item=item or {id=Wings.Id,slot="Back",egg=true,rarity="legendary",finish="sparkle"}
		local row=Wings.finishRow(item,Wings.Id)
		assert(row and row.finish=="sparkle"and row.color==Wings.Snow,"sparkle, still Snow")
		assert(Finish.kind(row)=="sparkle"and Finish.sparkle(row,false)=="live"and Finish.sparkle(row,true)=="still")
		assert(not Finish.moves(row,false),"the colour stays Snow")
		local still=Finish.still(row);assert(near(still.R,0xF4/255)and near(still.B,0xFB/255))
		-- Without a catalogue finish the look's (the sparkle never hangs on one field); a plain base has none.
		assert(Wings.finishRow({id=Wings.Id,slot="Back",egg=true},Wings.Id).finish=="sparkle")
		assert(Wings.finishRow({id="beanie",slot="Hat"},"beanie")==nil)
		-- Any other base row with a finish keeps its own colour, else the piece's.
		assert(Wings.finishRow({id="x",finish="shimmer",color="#112233"},"x").color=="#112233")
		assert(Wings.finishRow({id="x",finish="sparkle"},"x","#445566").color=="#445566")
		assert(Wings.finishRow({id="x",finish="sparkle",variant=true},"x")==nil,"a variant's finish is its tint's")
	end)

	test("previews: the pet turns 35 degrees and the camera pulls back 15% when it wears them",function()
		local pose=Wings.previewPose({wearables={Back=Wings.Id}})
		assert(pose and near(pose.yaw,-math.rad(35))and near(pose.pull,1.15))
		assert(Wings.previewPose({wearables={Hat="beanie"}})==nil and Wings.previewPose(nil)==nil and Wings.previewPose({})==nil)
		assert(Wings.wears({Back=Wings.Id})and not Wings.wears({Back="backpack"}))
	end)

	test("the closet: an egg-only base is a card only once owned (the Back tab follows)",function()
		local egg={id=Wings.Id,slot="Back",egg=true}
		local row={id="beanie_sky",slot="Hat",variant=true,egg=true}
		local plain={id="beanie",slot="Hat"}
		local list={plain,row,egg}
		local unowned=Wings.ownedOnly(list,{})
		assert(#unowned==2 and unowned[1]==plain and unowned[2]==row,"unowned wings are no card")
		assert(#Wings.ownedOnly(list,{Wings.Id})==3,"owned, they are")
		assert(#Wings.ownedOnly(nil,nil)==0)
		-- Whatever the catalogue lists on Back, an unowned pet sees no Back card.
		assert(#Wings.ownedOnly(Catalog.closetTab("pip","Back",{}),{})==0)
		assert(#Wings.ownedOnly(Catalog.shopTab("pip","Back",{}),{})==0)
	end)

	test("the flap rests under Reduced Motion / Motion: Low; the halo bobs on garden pets only",function()
		local v={scale=1,definition=bear,cosmeticSeed=3}
		local l1=Motion.wings(v,"neutral",.2);local l2=Motion.wings(v,"neutral",.2)
		assert(l1~=0 or l2~=0,"an idle flap")
		v.wingsStill=true
		local a,b=Motion.wings(v,"neutral",.2);assert(a==0 and b==0,"still")
		-- The stepper: a garden pet's halo lifts by bob x scale; reduced (game-wide or the pet's own) it rests.
		local part={Parent={}}
		local entry={part=part,frame=CFrame.new(0,1,0)}
		local pet={worldContext=true,scale=2,cosmeticSeed=0}
		assert(Wings.track(pet,{entry}))
		Wings.step(.75,false);assert(near(entry.frame.Position.Y,1.04),"lifted .02 x 2");assert(pet.wingsStill==nil)
		Wings.step(.75,true);assert(near(entry.frame.Position.Y,1)and pet.wingsStill==true,"Motion: Low")
		pet.reducedEffects=true;Wings.step(.75,false);assert(near(entry.frame.Position.Y,1),"the pet's own reduced")
		assert(not Wings.track({worldContext=false,scale=1},{{part=part,frame=CFrame.new()}}),"a preview stays posed")
		pet.wingsStill=true;part.Parent=nil;Wings.step(.75,false)
		assert(pet.wingsStill==nil,"a gone halo lets go of the flag")
		-- The padding covers the bob.
		local head={name="AngelHalo1",channel="Head",role="attachment",frame=CFrame.new(0,1.5,0),size=Vector3.new(.1,.04,.04)}
		local plain=Motion.padding(v,head);head.halo=true
		assert(near(Motion.padding(v,head).Y-plain.Y,.02),"bob in the pad")
	end)

	return {passed=#cases,cases=cases}
end
