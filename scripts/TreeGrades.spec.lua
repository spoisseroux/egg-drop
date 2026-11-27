-- The trees in three grades (GARDEN-B38-BRIEF 4a; Spencer's beta 37 note 16): TreeGrades' grades and +-5%, the trunk
-- pack's data (WorldAeroTrunks: one shared trunk a kind proven on every tree, the landmarks' as one static mesh, the
-- merged trunks' visual hidden), the graded kit data (each crown up its grown trunk, x1.45 wide, starting higher, still
-- seated on its trunk, no player walking into it), and every reader on it: AeroKit's parts, the fruit trees and their
-- trunk reach, the pets' trunk keep-outs, the litter plates. The fall-back: until the pack is confirmed (ready = false,
-- the placeholder) or with `scene` off, everything is today's, and nothing errors.
-- Usage (Client): require(PlayerScripts.Client.ZZSpecs.TreeGrades)(PlayerScripts.Client)
-- Offline: python scripts/run_dash_server_specs.py
return function(client)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Grades=require(Shared.TreeGrades)
	local KitData=require(Shared.WorldAeroKit)
	local Trunks=require(Shared.WorldAeroTrunks)
	local Fruit=require(Shared.GardenFruit)
	local KeepOut=require(Shared.GardenKeepOut)
	local Ground=require(Shared.GroundDressing)
	local Kit=require(client.AeroKit)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local function v(list)return Vector3.new(list[1],list[2],list[3])end
	local function near(a,b,eps)return math.abs(a-b)<=(eps or 1e-6)end
	local PLAYER=4.2 -- the avatar drawn at .8

	test("the grades: 12 shade trees x1.35 (x1.45 wide), the rim three x1.6, 7 blossom x1.15, the two landmarks unchanged, each +-5% and no two alike",function()
		local seen,counts={}, {round=0,tall=0,rim=0,blossom=0,landmark=0}
		for _,crown in ipairs(KitData.crowns)do
			local kind=Grades.kind(crown.tree)
			counts[kind]+=1
			local g=Grades.of(crown.tree)
			local K=Grades.Kinds[kind]
			if kind=="landmark"then
				assert(g.trunk==1 and g.tall==1 and g.wide==1,crown.tree)
			else
				assert(g.trunk>=K.trunk*.95-1e-9 and g.trunk<=K.trunk*1.05+1e-9,crown.tree.." "..g.trunk)
				assert(near(g.tall,g.trunk)and near(g.wide,g.trunk*K.wide,1e-9),crown.tree)
				local key=string.format("%.4f",g.trunk)
				assert(not seen[key],crown.tree.." matches "..tostring(seen[key]));seen[key]=crown.tree
			end
		end
		assert(counts.round+counts.tall==9 and counts.rim==3 and counts.blossom==7 and counts.landmark==2,
			"round+tall "..(counts.round+counts.tall).." rim "..counts.rim.." blossom "..counts.blossom)
		assert(near(Grades.Kinds.round.trunk*Grades.Kinds.round.wide,1.45,1e-9),"x1.45 wide")
		assert(Grades.of("Tree_01_round").trunk>1.5 and Grades.kind("Landmark_HatchTree")=="landmark")
	end)

	test("the trunk pack: three shared trunks proven on all 19 trees (same yaw and scale as their crowns, the root under the pivot), the landmarks' static mesh, the merged trunks hidden; the placeholder is not ready",function()
		local crowns={}
		for _,crown in ipairs(KitData.crowns)do crowns[crown.tree]=crown end
		assert(#Trunks.trunks==19,"trees "..#Trunks.trunks)
		local kinds={}
		for _,row in ipairs(Trunks.trunks)do
			local mesh=Trunks.meshes[row.mesh]
			assert(mesh and mesh.role=="trunk"and mesh.rootToCentre,row.mesh)
			assert(string.sub(row.mesh,1,11)=="W7_Trees38_","template names unique to the slice")
			kinds[row.mesh]=true
			local crown=crowns[row.tree]
			assert(crown and near(crown.yaw,row.yaw,1e-3)and near(crown.scale,row.scale,1e-3),row.tree)
			local root,pivot=v(row.root),v(crown.pivot)
			assert(Vector2.new(root.X-pivot.X,root.Z-pivot.Z).Magnitude<1.5 and pivot.Y-root.Y>5,row.tree.." root under the pivot")
		end
		local n=0;for _ in pairs(kinds)do n+=1 end
		assert(n==3,"three shared trunks")
		local rest=0
		for _,mesh in pairs(Trunks.meshes)do if mesh.role=="rest"then rest+=1;assert(mesh.center)end end
		assert(rest==1,"the landmarks' trunks")
		assert(#Trunks.hides==1 and Trunks.hides[1]=="W7_Trunks__bark")
		assert(Trunks.triangles<=700,"same meshes, no new triangles to speak of ("..Trunks.triangles..")")
		-- Until the upload is confirmed: not ready, so the grades are off whatever `scene` says.
		if Trunks.ready~=true then assert(Grades.ready()==false and Grades.on()==false,"the placeholder is not ready")end
		assert(Grades.ready({ready=true,trunks={},meshes={}})==false and Grades.ready({ready=true,trunks={{}},meshes={}})==true)
		assert(Grades.ready(nil)==Grades.ready(Trunks))
	end)

	local graded=Grades.kit(KitData,true,Trunks)
	test("graded crowns: up their grown trunk, starting higher, still on their trunk, clear of a player's head; the whole tree x its grade; landmarks and the off switch unchanged",function()
		assert(Grades.kit(KitData,false)==KitData,"off: today's data itself")
		assert(graded.graded==true and #graded.crowns==#KitData.crowns)
		local roots={}
		for _,row in ipairs(Trunks.trunks)do roots[row.tree]=row end
		for i,crown in ipairs(graded.crowns)do
			local old=KitData.crowns[i]
			local mesh=KitData.meshes[crown.mesh]
			local row=roots[crown.tree]
			if not row then
				assert(crown.pivot[2]==old.pivot[2]and crown.scale==old.scale and crown.wide==nil,crown.tree.." unchanged")
				continue
			end
			local g=Grades.of(crown.tree)
			local root=v(row.root)
			assert(((v(crown.pivot)-root)-(v(old.pivot)-root)*g.trunk).Magnitude<1e-6,crown.tree.." up its trunk")
			local cf0,size0=Kit.crownFrame(old,mesh)
			local cf1,size1=Kit.crownFrame(crown,mesh)
			assert(near(size1.X,size0.X*g.wide,1e-6)and near(size1.Y,size0.Y*g.tall,1e-6)and near(size1.Z,size0.Z*g.wide,1e-6),crown.tree.." size")
			local bottom0,bottom1=cf0.Position.Y-size0.Y/2,cf1.Position.Y-size1.Y/2
			assert(bottom1>=bottom0-1e-6,crown.tree.." starts higher")
			-- A shade tree's crown clears a player's head (the beta 12 crown clip); the low blossom crowns (the fruit at eye
			-- level) are walked into as today, a little higher, and fade round the camera and the avatar (AeroKit.fader).
			if Grades.kind(crown.tree)~="blossom"then
				assert(bottom1-root.Y>=PLAYER+.5,crown.tree.." over a player's head ("..(bottom1-root.Y)..")")
			end
			-- Seated: the grown trunk's top reaches into the grown crown.
			local tmesh=Trunks.meshes[row.mesh]
			local tcf,tsize=Kit.trunkFrame(row,tmesh,g.trunk)
			local trunkTop=tcf.Position.Y+tsize.Y/2
			assert(trunkTop>bottom1,crown.tree.." on its trunk ("..trunkTop.." vs "..bottom1..")")
			-- The whole tree grows by its trunk's grade (today's shade trees are 11 to 14 over their roots, so 15 to 20
			-- graded, the rim three about 23; Fable's 14 to 17 was from the brief's rounder estimate).
			local top0,top1=cf0.Position.Y+size0.Y/2-root.Y,cf1.Position.Y+size1.Y/2-root.Y
			assert(near(top1/top0,g.trunk,1e-6),crown.tree.." top "..top0.." -> "..top1)
			assert(top1<=25,crown.tree.." top "..top1)
			assert(near(crown.trunk,row.scale*g.trunk,1e-9))
		end
	end)

	test("the trunk frame: at its root, turned with the tree and the import's pi, sized by its scale and grade",function()
		for _,row in ipairs(Trunks.trunks)do
			local mesh=Trunks.meshes[row.mesh]
			local cf,size=Kit.trunkFrame(row,mesh,1.3)
			local back=CFrame.Angles(0,row.yaw,0):VectorToObjectSpace(cf.Position-v(row.root))/(row.scale*1.3)
			assert((back-v(mesh.rootToCentre)).Magnitude<1e-3,row.tree)
			assert((size-v(mesh.size)*row.scale*1.3).Magnitude<1e-3)
			local want=CFrame.Angles(0,row.yaw,0)*Kit.Turn
			assert((cf.LookVector-want.LookVector).Magnitude<1e-3,"the import's pi turn")
		end
	end)

	-- Fixture templates (as AeroKit.spec): one MeshPart a name, for the kit and for the trunk pack.
	local function templates(meshes,missing)
		local made={}
		return{FindFirstChild=function(_,name)
			if name==missing or not meshes[name]then return nil end
			made[name]=made[name]or{IsA=function(_,class)return class=="MeshPart"end,
				Clone=function()local p=Instance.new("MeshPart");p.Name=name;p.CastShadow=true;return p end}
			return made[name]
		end}
	end
	test("AeroKit with the pack whole: 19 graded trunks and the landmarks', inert and shadowed, the merged trunks hidden; a missing template or no pack: today's kit, nothing extra hidden",function()
		local room=Instance.new("Folder");room.Name="TreeGradesSpec";room.Parent=workspace
		local ok,err=pcall(function()
			local function count(built)
				local n=0
				for _,p in ipairs(built.folder:GetChildren())do
					if p:GetAttribute("TreeTrunk")then
						n+=1
						assert(p.Anchored and not p.CanCollide and not p.CanQuery and not p.CanTouch and p:GetAttribute("WorldMesh"),p.Name)
					end
				end
				return n
			end
			local grade=function(tree)return Grades.of(tree).trunk end
			local full=Kit.build({data=graded,templates=templates(KitData.meshes),parent=room,
				trunks={data=Trunks,templates=templates(Trunks.meshes),grade=grade}})
			assert(full.trunks==true and count(full)==20,"19 trunks and the landmarks")
			assert(table.find(full.hides,"W7_Trunks__bark")and #full.hides==#KitData.hides+1,"the merged trunks hide")
			-- A graded tree's trunk at its grade.
			for _,p in ipairs(full.folder:GetChildren())do
				if p.Name=="W7_Trees38_Trunk_Round__bark"then
					local row
					for _,r in ipairs(Trunks.trunks)do
						local cf=Kit.trunkFrame(r,Trunks.meshes[r.mesh],grade(r.tree))
						if (cf.Position-p.CFrame.Position).Magnitude<1e-4 then row=r end
					end
					assert(row,"placed on a row")
				end
			end
			full.destroy()
			local missing=Kit.build({data=KitData,templates=templates(KitData.meshes),parent=room,
				trunks={data=Trunks,templates=templates(Trunks.meshes,"W7_Trees38_Trunk_Tall__bark"),grade=grade}})
			assert(missing.trunks==false and count(missing)==0 and not table.find(missing.hides,"W7_Trunks__bark"),"a missing mesh: today's")
			missing.destroy()
			local none=Kit.build({data=KitData,templates=templates(KitData.meshes),parent=room})
			assert(none.trunks==false and count(none)==0 and #none.hides==#KitData.hides)
			none.destroy()
			assert(Kit.trunksWhole(Trunks,{FindFirstChild=function()return nil end})==false,"the placeholder's empty folder")
		end)
		room:Destroy();assert(ok,err)
	end)

	test("the readers: fruit trees and their trunk reach, the pets' trunk keep-outs and the litter grow with the grades; off they are today's",function()
		local today,big=Fruit.trees(nil,false),Fruit.trees(nil,true)
		assert(#today==#big and #today==8)
		for i,tree in ipairs(today)do
			local g=Grades.of(tree.tree)
			assert(big[i].tree==tree.tree,"the same order")
			if tree.tree=="Landmark_BlossomPointTree"then
				assert(near(big[i].trunk,tree.trunk)and near(big[i].x,tree.x))
			else
				assert(near(big[i].trunk,tree.trunk*g.trunk,1e-9),tree.tree.." trunk radius")
				assert(big[i].centre.Y>tree.centre.Y,tree.tree.." the crown's centre higher")
				assert(Fruit.promptReach(big[i])>=Fruit.promptReach(tree),"the prompt reaches round the bigger trunk")
			end
		end
		assert(Fruit.trees(nil,false)==today,"cached per grade")
		local a,b=KeepOut.all(false),KeepOut.all(true)
		assert(#a==#b)
		local grew=0
		for k,entry in ipairs(a)do
			assert(b[k].id==entry.id)
			if string.sub(entry.id,1,6)=="trunk "and b[k].r>entry.r+1e-9 then grew+=1 end
		end
		assert(grew==19,"19 trunks wider ("..grew..")")
		for _,row in ipairs(Ground.Litter)do
			local size=Grades.litter(row[6],row[4],true)
			assert(size>=row[4]and size<=Grades.LitterMost,row[6])
			assert(Grades.litter(row[6],row[4],false)==row[4])
		end
	end)

	return{passed=#cases,cases=cases}
end
