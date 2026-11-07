-- Production Room camera lifecycle with isolated camera values/roots, no avatar movement.
return function(client)
	local Room=require(client.RoomView)
	local Shot=require(client.PetGreetingShot)
	local cases={};local garbage={}
	local function test(name,run)run();table.insert(cases,name)end
	local function root(position)
		local character=Instance.new("Model");table.insert(garbage,character)
		local part=Instance.new("Part");part.Position=position or Vector3.new(2,7,-1);part.Parent=character
		return part
	end
	local function camera()
		return{Parent=true,CameraType=Enum.CameraType.Custom,CFrame=CFrame.lookAt(Vector3.new(9,12,16),Vector3.new(2,8,-1)),
			Focus=CFrame.new(2,8,-1),FieldOfView=71}
	end
	local function fixture()
		local f={root=root(),camera=camera(),humanoid={Health=100}}
		f.room=setmetatable({mode="Room",roamed=true,greetButton={},connections={},
			cameraIdentity=function()return f.camera,f.root,f.humanoid end,
			updateControls=function()end,releaseFocusMovement=function()end},Room)
		return f
	end
	local function same(actual,expected)
		local a,b={actual:GetComponents()},{expected:GetComponents()}
		for index,value in ipairs(a)do assert(math.abs(value-b[index])<.00001,"camera transform component "..index)end
	end
	local ok,problem=pcall(function()
		test("initial Board presentation does not capture a return roam shot",function()
			local f=fixture();local r=f.room;local captures=0
			r.mode,r.target="Board","Board";r.transition={begin=function()return nil end}
			r.show=function()end;r.overlayOpen=function()return false end;r.audio={play=function()end}
			r.captureReturnRoam=function()captures+=1 end
			r:driveModes(true);task.wait()
			assert(not r.busy and captures==0 and r.returnRoamShot==nil)
		end)
		test("actual Room exit captures before the separate pre-Room restore",function()
			local f=fixture();local r=f.room
			local external=CFrame.new(100,101,102)
			r.savedCamera={camera=f.camera,transform=external,focus=CFrame.new(100,100,100),fov=80,type=Enum.CameraType.Custom}
			local roam=f.camera.CFrame
			r.target="Board";r.transition={begin=function()return nil end}
			r.overlayOpen=function()return false end;r.audio={play=function()end}
			r.show=function(self,mode)assert(mode=="Board");self:restoreCamera()end
			r:driveModes(false);task.wait()
			assert(not r.busy and r.mode=="Board" and r.returnRoamShot)
			same(r.returnRoamShot.transform,roam);same(f.camera.CFrame,external)
		end)
		test("repeated Deck trips restore exact roam transform Focus and FOV once per trip",function()
			local f=fixture();local r=f.room
			for trip=1,3 do
				r.mode="Room";f.camera.CFrame=CFrame.lookAt(Vector3.new(trip*3,11,14),Vector3.new(2,8,-1))
				f.camera.Focus=CFrame.new(trip,8,-1);f.camera.FieldOfView=60+trip
				local transform,focus,fov=f.camera.CFrame,f.camera.Focus,f.camera.FieldOfView
				assert(r:captureReturnRoam());r:restoreCamera();r.mode="Board"
				f.camera.CFrame=CFrame.new(-100,200,300);f.camera.FieldOfView=90
				r.mode="Room";r:useRoomCamera(false,true)
				same(f.camera.CFrame,transform);same(f.camera.Focus,focus)
				assert(f.camera.FieldOfView==fov and f.camera.CameraSubject==f.humanoid)
				assert(f.camera.CameraType==Enum.CameraType.Custom and r.returnRoamShot==nil)
			end
		end)
		test("the same root translates the return transform and Focus together",function()
			local f=fixture();local r=f.room;local transform,focus=f.camera.CFrame,f.camera.Focus
			assert(r:captureReturnRoam());local delta=Vector3.new(7,0,-5);f.root.Position+=delta
			r:useRoomCamera(false,true);same(f.camera.CFrame,transform+delta);same(f.camera.Focus,focus+delta)
		end)
		test("active greeting restores underlying roam before capturing the Deck return",function()
			local f=fixture();local r=f.room
			local roam,focus,fov=f.camera.CFrame,f.camera.Focus,f.camera.FieldOfView
			r.greetingCamera=Shot.capture(f.camera,f.root);r.focusing=true
			f.camera.CameraType=Enum.CameraType.Scriptable;f.camera.CFrame=CFrame.new(300,301,302);f.camera.FieldOfView=43
			assert(r:captureReturnRoam() and not r.focusing and r.greetingCamera==nil)
			same(r.returnRoamShot.transform,roam);same(r.returnRoamShot.focus,focus);assert(r.returnRoamShot.fov==fov)
			f.camera.CFrame=CFrame.new(-200,50,40);r:useRoomCamera(false,true);same(f.camera.CFrame,roam)
		end)
		test("Scriptable camera without an accepted greeting and dead root are never captured",function()
			local f=fixture();f.camera.CameraType=Enum.CameraType.Scriptable
			assert(not f.room:captureReturnRoam() and f.room.returnRoamShot==nil)
			f.camera.CameraType=Enum.CameraType.Custom;f.humanoid.Health=0
			assert(not f.room:captureReturnRoam())
		end)
		test("replaced root character or camera rejects old shot and seeds a clear angle",function()
			for _,replacement in ipairs({"root","character","camera"})do
				local f=fixture();local r=f.room;assert(r:captureReturnRoam())
				if replacement=="root" then f.root=root(f.root.Position)
				elseif replacement=="character" then
					local other=Instance.new("Model");table.insert(garbage,other);f.root.Parent=other
				else f.camera=camera()end
				f.camera.CFrame=CFrame.new(300,300,300);r:useRoomCamera(false,true)
				local target=f.root.Position+Vector3.new(0,1,0)
				same(f.camera.CFrame,CFrame.lookAt(target+Vector3.new(5,6,12),target))
				assert(f.camera.FieldOfView==65 and r.returnRoamShot==nil)
			end
		end)
		test("consumed or missing shots seed arrival even after previous roaming",function()
			local f=fixture();local r=f.room;assert(r:captureReturnRoam());r:useRoomCamera(false,true)
			f.camera.CFrame=CFrame.new(400,500,600);r:useRoomCamera(false,true)
			local target=f.root.Position+Vector3.new(0,1,0)
			same(f.camera.CFrame,CFrame.lookAt(target+Vector3.new(5,6,12),target));assert(f.camera.FieldOfView==65)
		end)
		test("ordinary free-roam updates never force the arrival angle or consume a pending shot",function()
			local f=fixture();local r=f.room;assert(r:captureReturnRoam());local pending=r.returnRoamShot
			local transform,focus=f.camera.CFrame,f.camera.Focus
			r:useRoomCamera(false);same(f.camera.CFrame,transform);same(f.camera.Focus,focus)
			assert(r.returnRoamShot==pending)
		end)
		test("missing camera defers arrival without consuming the shot or marking first roam",function()
			local f=fixture();local r=f.room;r.target="Room";r.roamed=nil
			assert(r:captureReturnRoam());local saved=r.returnRoamShot;local available=f.camera
			f.camera=nil;r:useRoomCamera(false,true)
			assert(r.arrivalPlacementPending and r.returnRoamShot==saved and not r.roamed)
			f.camera=available;r:retryArrivalPlacement()
			assert(not r.arrivalPlacementPending and r.returnRoamShot==nil and r.roamed)
			same(f.camera.CFrame,saved.transform);same(f.camera.Focus,saved.focus)
		end)
		test("staggered root availability retries once then ordinary roaming retains its angle",function()
			local f=fixture();local r=f.room;r.target="Room";r.roamed=true
			local available=f.root;f.root=nil;r:useRoomCamera(false,true)
			assert(r.arrivalPlacementPending)
			f.root=available;r:retryArrivalPlacement()
			local target=f.root.Position+Vector3.new(0,1,0)
			same(f.camera.CFrame,CFrame.lookAt(target+Vector3.new(5,6,12),target))
			assert(f.camera.FieldOfView==65 and not r.arrivalPlacementPending)
			f.camera.CFrame=CFrame.lookAt(Vector3.new(-20,9,-5),target)
			local roamed=f.camera.CFrame;r:retryArrivalPlacement();same(f.camera.CFrame,roamed)
		end)
		test("missing humanoid also defers placement until its live subject is available",function()
			local f=fixture();local r=f.room;r.target="Room";local humanoid=f.humanoid
			f.humanoid=nil;r:useRoomCamera(false,true);assert(r.arrivalPlacementPending)
			f.humanoid=humanoid;r:retryArrivalPlacement()
			assert(not r.arrivalPlacementPending and f.camera.CameraSubject==humanoid)
		end)
		test("Board cancellation clears a pending placement so late roots cannot move the camera",function()
			local f=fixture();local r=f.room;r.target="Room";r.transition={refresh=function()end}
			local available=f.root;f.root=nil;r:useRoomCamera(false,true)
			assert(r.arrivalPlacementPending);r.busy=true;r:setMode("Board")
			assert(not r.arrivalPlacementPending and r.returnRoamShot==nil)
			f.root=available;local before=f.camera.CFrame;r:retryArrivalPlacement();same(f.camera.CFrame,before)
		end)
		test("forced busy Board departure cannot capture an unplaced arrival when root appears during cover",function()
			local f=fixture();local r=f.room;r.target="Room"
			local available=f.root;f.root=nil;r:useRoomCamera(false,true)
			assert(r.arrivalPlacementPending and r.arrivalUnplaced)
			local token={};local covered=false
			r.transition={refresh=function()end,begin=function()return token end,owns=function()return true end,
				cover=function()covered=true;f.root=available end,reveal=function()end,hide=function()end}
			r.busy=true;r:setMode("Board")
			assert(not r.arrivalPlacementPending and r.arrivalUnplaced and r.target=="Board")
			r.busy=false;r.overlayOpen=function()return false end;r.audio={play=function()end}
			r.show=function(self,mode)assert(mode=="Board");self:restoreCamera()end
			r:driveModes(false);task.wait()
			assert(covered and r.mode=="Board" and not r.busy and r.returnRoamShot==nil)
			r.mode,r.target="Room","Room";r:useRoomCamera(false,true)
			local target=f.root.Position+Vector3.new(0,1,0)
			same(f.camera.CFrame,CFrame.lookAt(target+Vector3.new(5,6,12),target))
			assert(not r.arrivalUnplaced and r.returnRoamShot==nil)
		end)
		test("teardown invalidates return shot before camera and UI cleanup",function()
			local f=fixture();local r=f.room;assert(r:captureReturnRoam())
			local cancelled,stopped,destroyed=0,0,0
			local contactPet={petting=true};r.petContactActive,r.contactPet=true,contactPet
			r.audio={setPurr=function(_,active)assert(active==false);stopped+=1 end}
			r.companions={clear=function()end}
			r.focusUI={cancelPointer=function()cancelled+=1 end,destroy=function()
				assert(cancelled==1 and stopped==1 and not r.petContactActive and not contactPet.petting,"contact survived UI teardown")
				destroyed+=1
			end}
			r.controls={Destroy=function()end}
			r.transition={hide=function()end,shade={Destroy=function()end}}
			r.arrivalPlacementPending=true
			r:destroy();assert(r.destroyed and not r.arrivalPlacementPending and r.returnRoamShot==nil and not r:captureReturnRoam())
			assert(cancelled==1 and stopped==1 and destroyed==1)
			r:destroy();assert(cancelled==1 and stopped==1 and destroyed==1,"duplicate teardown repeated contact cleanup")
		end)
	end)
	for _,object in ipairs(garbage)do object:Destroy()end
	assert(ok,problem);return{passed=#cases,cases=cases}
end
