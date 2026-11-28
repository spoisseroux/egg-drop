-- Run in a Client datamodel with the synced Client ModuleScripts. Fixtures never
-- move a player, mutate inventory, replace CurrentCamera, or grant rewards.
return function(client, _parent)
	local Players = game:GetService("Players")
	local GuiService = game:GetService("GuiService")
	local ContextActionService = game:GetService("ContextActionService")
	local Focus = require(client.PetFocusUI)
	local Room = require(client.RoomView)
	local host = Instance.new("ScreenGui")
	host.Name, host.Parent = "_PetFocusSpecHost", Players.LocalPlayer:WaitForChild("PlayerGui")
	local fixture = Instance.new("Folder")
	fixture.Name, fixture.Parent = "_PetFocusSpec", workspace
	local cases, ui = {}, nil
	local function test(name, run) run(); table.insert(cases, name) end
	local function near(a, b) return math.abs(a - b) < 0.0001 end
	local ok, problem = pcall(function()
		test("movement and jumping restore exact prior settings once", function()
			local character = Instance.new("Model")
			character.Parent = fixture
			local humanoid = Instance.new("Humanoid")
			humanoid.Parent = character
			humanoid.WalkSpeed, humanoid.JumpPower, humanoid.JumpHeight, humanoid.AutoRotate = 19, 47, 6.25, false
			humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
			local release = Focus.lockHumanoid(humanoid)
			assert(humanoid.WalkSpeed == 0 and humanoid.JumpPower == 0 and humanoid.JumpHeight == 0 and not humanoid.AutoRotate)
			release()
			assert(humanoid.WalkSpeed == 19 and humanoid.JumpPower == 47 and humanoid.JumpHeight == 6.25 and not humanoid.AutoRotate)
			assert(not humanoid:GetStateEnabled(Enum.HumanoidStateType.Jumping), "disabled jump was accidentally enabled")
			humanoid.WalkSpeed = 22
			release()
			assert(humanoid.WalkSpeed == 22, "duplicate cleanup overwrote newer movement settings")
			local releaseAgain = Focus.lockHumanoid(humanoid)
			character:Destroy()
			releaseAgain()
		end)
		test("petting bounds account for core-safe offset and reject hidden geometry", function()
			local model = Instance.new("Model")
			model.Parent = fixture
			local body = Instance.new("Part")
			body.Size, body.Anchored, body.Parent = Vector3.new(2, 2, 2), true, model
			local root = { AbsolutePosition = Vector2.new(12, 8), AbsoluteSize = Vector2.new(400, 250) }
			local projection = { WorldToScreenPoint = function(_, point) return Vector3.new(200 + point.X * 20, 100 + point.Y * 20, 20 + point.Z) end }
			local position, size = Focus.projectBounds(projection, model, root)
			assert(position and near(position.X, 158) and near(position.Y, 62) and near(size.X, 60) and near(size.Y, 60))
			projection.WorldToScreenPoint = function() return Vector3.new(200, 100, -1) end
			assert(Focus.projectBounds(projection, model, root) == nil, "behind-camera pet accepted input")
			projection.WorldToScreenPoint = function() return Vector3.new(1200, 100, 10) end
			assert(Focus.projectBounds(projection, model, root) == nil, "offscreen pet accepted input")
			model:Destroy()
		end)
		test("focus navigation is safe-sized and input bindings clean up", function()
			local count = { back = 0, greet = 0, pet = 0 }
			ui = Focus.new(host, { back = function() count.back += 1 end, greet = function() count.greet += 1 end,
				pet = function() count.pet += 1 end, canReact = function() return true end })
			assert(ui.back.Size.Y.Offset >= 44 and ui.greet==nil and ui.panel:FindFirstChild("Greet")==nil and ui.gui.DisplayOrder < 10,
				"inactive focus surface blocks lounge navigation")
			ui:setActive(true)
			assert(ui.gui.DisplayOrder >= 40)
			assert(ui.panel.Visible and ContextActionService:GetBoundActionInfo(ui.actionPrefix .. "Back").inputTypes)
			ui.pointer, ui.glove.Visible = {}, true
			ui:setActive(false)
			assert(not ui.panel.Visible and ui.pointer == nil and not ui.glove.Visible and ui.gui.DisplayOrder < 10)
			assert(next(ContextActionService:GetBoundActionInfo(ui.actionPrefix .. "Back")) == nil)
			local old = ui
			ui:destroy(); ui = nil
			old:destroy()
			assert(#old.connections == 0 and old.gui.Parent == nil)
		end)
		test("petting pointer uses core-safe input coordinates exactly once", function()
			local reacted = 0
			local fake = setmetatable({ active = true,
				root = { AbsolutePosition = Vector2.new(12, 8) },
				glove = {}, hit = { Position = UDim2.fromOffset(0, 0), Size = UDim2.fromOffset(400, 250) },
				callbacks = { canReact = function() return true end, pet = function() reacted += 1;return true end },
			}, Focus)
			local input={Position=Vector3.new(200,100,0),UserInputType=Enum.UserInputType.Touch}
			assert(fake:beginPointer(input))
			assert(fake.glove.Position == UDim2.fromOffset(188, 92) and reacted == 0,
				"petting glove has an extra GUI-inset displacement")
		end)
		test("other modals suspend focus UI and receive Back/movement/Greet input", function()
			local modal, backs, greets = true, 0, 0
			ui = Focus.new(host, { back = function() backs += 1 end, greet = function() greets += 1 end,
				pet = function() end, canReact = function() return true end, canOwnInput = function() return not modal end })
			ui:setActive(true)
			ui:update(nil, nil, false)
			assert(not ui.panel.Visible and ui.active and ui.gui.DisplayOrder < 10,
				"modal discarded focus or retained a fullscreen input shield above the modal")
			assert(ui:handleBack(Enum.UserInputState.Begin) == Enum.ContextActionResult.Pass)
			assert(ui:handleGreet(Enum.UserInputState.Begin) == Enum.ContextActionResult.Pass)
			assert(ui:handleMove() == Enum.ContextActionResult.Pass and backs == 0 and greets == 0)
			modal = false
			ui:update(nil, nil, false)
			assert(ui.panel.Visible and ui.active and ui.gui.DisplayOrder >= 40)
			assert(ui:handleGreet(Enum.UserInputState.Begin) == Enum.ContextActionResult.Sink and greets == 1)
			assert(ui:handleBack(Enum.UserInputState.Begin) == Enum.ContextActionResult.Sink and backs == 1)
			ui:destroy(); ui = nil
		end)
		test("short landscape lesson uses safe sky above the feet and keeps portrait placement and retirement",function()
			ui=Focus.new(host,{back=function()end,canReact=function()return true end})
			local surface=Instance.new("Frame");surface.BackgroundTransparency=1;surface.Parent=host
			local helper=ui.helper:Clone();helper.Text="Tap or rub "..utf8.char(0xB7).." hold E to pet";helper.Parent=surface
			for _,size in ipairs({Vector2.new(733,307),Vector2.new(568,160),Vector2.new(385,703)})do
				surface.Size=UDim2.fromOffset(size.X,size.Y)
				local fake={root={AbsoluteSize=size},helper=helper,back={Position=UDim2.fromOffset(12,12),Size=UDim2.fromOffset(44,44)}}
				Focus.layoutSaveHelper(fake);for _=1,3 do game:GetService("RunService").Heartbeat:Wait()end
				assert(helper.TextFits,"preferred-size hint clipped")
				if size.X>size.Y then
					assert(helper.AnchorPoint.Y==0 and helper.Position.Y.Scale==0 and helper.Position.Y.Offset==8)
					assert(size.X*.5-helper.Size.X.Offset*.5>=68 and size.X*.5+helper.Size.X.Offset*.5<=size.X-68,"hint overlaps Back/system-safe lane")
				else assert(helper.AnchorPoint.Y==1 and helper.Position.Y.Scale==1 and helper.Position.Y.Offset==-14)end
			end
			local fake={root={AbsoluteSize=Vector2.new(733,307)},helper=helper,back={Position=UDim2.fromOffset(12,12),Size=UDim2.fromOffset(44,44)},saveNotice={detail="Saved appearance"}}
			Focus.layoutSaveHelper(fake);assert(helper.AnchorPoint.Y==1 and helper.Position.Y.Scale==1,"save notice placement changed")
			-- Beta (12) QA U1: 6 / 4 / 12 padding, and Art.type on a relayout does not wipe it.
			local function padded()
				local inset=helper:FindFirstChildOfClass("UIPadding")
				return inset and inset.PaddingTop.Offset==6 and inset.PaddingBottom.Offset==4 and inset.PaddingLeft.Offset==12 and inset.PaddingRight.Offset==12
			end
			assert(padded(),"hint padding")
			fake.helperLayoutKey=nil;Focus.layoutSaveHelper(fake);assert(padded(),"hint padding after a relayout")
			ui.active=true;ui.focusLessonStarted=true;ui.helper.Visible=true;ui:retireFocusHint();assert(ui.focusLessonRetired and not ui.helper.Visible)
			surface:Destroy();ui:destroy();ui=nil
		end)
		local currentRoot = Players.LocalPlayer.Character and Players.LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		assert(currentRoot and workspace.CurrentCamera, "wait for the local character before running focus lifetime fixtures")
		local function roomFixture(reduced)
			local greeted, sounded, escaped = 0, 0, 0
			local fake = {
				focusing = true, mode = "Room", busy = false, pet = { origin = Vector3.new(7, 4, 8), greet = function() greeted += 1 end },
				greetingCamera = { root = currentRoot, camera = workspace.CurrentCamera }, focusEpoch = 17,
				overlayOpen = function() return false end, reduceEffects = function() return reduced end,
				audio = { play = function() sounded += 1 end }, shownPet = { cue = "pet" },
				useRoomCamera = function() escaped += 1 end,
			}
			return fake, function() return greeted, sounded, escaped end
		end
		test("repeat greeting reacts in the same shot and throttles rubbing", function()
			local fake, counts = roomFixture(false)
			local shot, origin, transform = fake.greetingCamera, fake.pet.origin, workspace.CurrentCamera.CFrame
			assert(Room.reactPet(fake, false))
			assert(not Room.reactPet(fake, true), "immediate rubbing bypassed reaction throttle")
			assert(fake.greetingCamera == shot and fake.focusEpoch == 17 and fake.pet.origin == origin
				and workspace.CurrentCamera.CFrame == transform, "repeat greeting moved/replanned the camera")
			local greeted, sounded, escaped = counts()
			assert(greeted == 1 and sounded == 1 and escaped == 0)
		end)
		test("reduced effects and stale camera/root never animate or keep a lock", function()
			local fake, counts = roomFixture(true)
			assert(Room.reactPet(fake, true))
			local greeted, sounded = counts()
			assert(greeted == 0 and sounded == 0 and fake.pet.affection>0)
			fake.lastReactionAt = -math.huge
			fake.greetingCamera.root = {}
			assert(not Room.reactPet(fake, false))
			local _, _, escaped = counts()
			assert(escaped == 1)
			fake.greetingCamera.root, fake.greetingCamera.camera = currentRoot, Instance.new("Camera")
			assert(not Room.reactPet(fake, false))
			fake.greetingCamera.camera:Destroy()
			local _, _, escapedAgain = counts()
			assert(escapedAgain == 2)
		end)
		test("focus movement release drops the shared focus hold once (QA v2 R2 MovementLock)", function()
			local shared = require(client.MovementLock).shared()
			local before = shared:holds("focus")
			shared:acquire("focus")
			local released = 0
			local fake = { focusLock = { release = function() released += 1 end } }
			Room.releaseFocusMovement(fake)
			Room.releaseFocusMovement(fake)
			assert(fake.focusLock == nil and released == 1 and not shared:holds("focus"))
			if before then shared:acquire("focus") end
		end)
		test("camera teardown invalidates stale greeting epochs without touching a replacement", function()
			local released, cancelled, disconnected, updated = 0, 0, 0, 0
			local oldCamera = Instance.new("Camera")
			oldCamera.CFrame, oldCamera.Parent = CFrame.new(8, 9, 10), fixture
			local original = oldCamera.CFrame
			local fake = setmetatable({ focusEpoch = 31, focusing = true, greetingCamera = {},
				focusMotion = {}, followState = {}, greetButton = { Text = "Roam" },
				focusLock = { release = function() released += 1 end },
				cameraTween = { Cancel = function() cancelled += 1 end },
				viewportChanged = { Disconnect = function() disconnected += 1 end },
				savedCamera = { camera = oldCamera, transform = CFrame.new(1, 2, 3) },
				updateControls = function() updated += 1 end,
			}, Room)
			fake:restoreCamera()
			assert(not fake.focusing and fake.focusEpoch == 32 and fake.focusLock == nil and fake.greetingCamera == nil)
			assert(fake.focusMotion == nil and fake.followState == nil and fake.viewportChanged == nil and fake.savedCamera == nil)
			assert(released == 1 and cancelled == 1 and disconnected == 1 and updated == 1)
			assert(oldCamera.CFrame == original, "stale camera snapshot modified an inactive camera")
			fake:restoreCamera()
			assert(released == 1 and cancelled == 1 and disconnected == 1 and fake.focusEpoch == 33)
			oldCamera:Destroy()
		end)
		test("same-aspect viewport resize has a distinct safe geometry key",function()
			assert(Room.focusGeometryKey({ViewportSize=Vector2.new(400,800)})~=Room.focusGeometryKey({ViewportSize=Vector2.new(300,600)}),"same aspect suppressed pixel headroom reframe")
		end)
		test("blocked resize releases focus through the existing roam restoration path",function()
			local restored=0;local camera=workspace.CurrentCamera
			local fake={focusing=true,mode="Room",pet={},focusGeometry="old geometry",greetingCamera={camera=camera,root=currentRoot},
				planGreeting=function()return nil end,useRoomCamera=function(_,placing)assert(placing==false);restored+=1 end}
			assert(not Room.reframeFocus(fake)and restored==1,"invalid new viewport retained a clipped locked shot")
		end)
		test("viewport reframe preserves original restore shot without greet or recapture", function()
			local camera = Instance.new("Camera")
			camera.Parent = fixture
			local updated, cancelled, pointerCancelled, characterMasked = 0, 0, 0, 0
			local shot = { petOrigin = Vector3.new(2, 4, 3), transform = CFrame.new(3, 7, 12),
				fov = 65, root = currentRoot }
			local fake = { greetingCamera = shot, focusEpoch = 9,
				pet = { update = function() updated += 1 end, greet = function() error("resize greeted pet") end },
				hideFocusCharacter = function(_, character) assert(character == currentRoot.Parent); characterMasked += 1 end,
				cancelCameraTween = function() cancelled += 1 end,
				focusUI = { cancelPointer = function() pointerCancelled += 1 end },
				audio = { play = function() error("resize played greeting audio") end },
			}
			local plan = { origin = Vector3.new(7, 4, 8), yaw = 0.3, target = Vector3.new(7, 5.4, 8),
				camera = CFrame.lookAt(Vector3.new(7, 6, 2), Vector3.new(7, 5.4, 8)), fov = 43 }
			Room.applyFocusPlan(fake, plan, camera)
			assert(fake.greetingCamera == shot and shot.petOrigin == Vector3.new(2, 4, 3)
				and shot.transform == CFrame.new(3, 7, 12) and shot.fov == 65 and fake.focusEpoch == 9)
			assert(fake.pet.origin == plan.origin and fake.pet.yaw == plan.yaw and updated == 1 and cancelled == 1 and pointerCancelled == 1 and characterMasked == 1)
			assert(camera.CFrame == plan.camera and camera.FieldOfView == 43)
			camera:Destroy()
		end)
		test("beta 42 D13: the focus card's name is ink on its light pill; an unnamed pet reads Pet", function()
			local v = Focus.new(host, { back = function() end, greet = function() return true end, pet = function() return true end,
				petContact = function() end, canReact = function() return true end, canOwnInput = function() return true end })
			local okCase, why = pcall(function()
				local Kit = require(client.DeckKit)
				assert(v.bondCard:GetAttribute("ToySurface") == "light" and v.bondName.TextColor3 == Kit.color("ink"), "ink name")
				local UICopy = require(game:GetService("ReplicatedStorage").Shared.UICopy)
				v:setBond({ name = UICopy.get("pet.unnamed"), named = false, species = "Bear", heart = 1 })
				assert(v.bondName.Text == "Pet" and v.bondCard.Visible)
				local Cuddle = require(client.PetCuddleUI)
				assert(Cuddle.callName(v.bondInfo) == "Bear", "the hints still call an unnamed pet by its species")
				assert(Cuddle.callName({ name = "Zivvi", named = true, species = "Bear" }) == "Zivvi")
			end)
			v:destroy(); assert(okCase, why)
		end)
		test("beta 42 D17: the petting box holds the pet's resting body once it settles; a lean never moves it", function()
			local memo = {}
			local pet = { origin = Vector3.new(10, 4, 0), yaw = 0, rigRevision = 1, scale = .72, gaitWeight = 0, greeting = 2 }
			local rest = CFrame.new(10, 5, 0)
			local f, s = Focus.restBounds(memo, pet, rest, Vector3.new(1, 1.5, 1))
			assert(f == rest and s == Vector3.new(1, 1.5, 1) and memo.settled)
			-- The rub's lean moves the posed body: the box stays at rest.
			f, s = Focus.restBounds(memo, pet, CFrame.new(10.3, 5.1, 0) * CFrame.Angles(0, 0, .2), Vector3.new(1.2, 1.6, 1))
			assert((f.Position - rest.Position).Magnitude < 1e-4 and s == Vector3.new(1, 1.5, 1), "posed bounds leaked into the box")
			-- The pet's root moving carries the box with it (its own frame).
			pet.origin = Vector3.new(12, 4, 0)
			f = Focus.restBounds(memo, pet, CFrame.new(99, 0, 0), Vector3.one)
			assert((f.Position - Vector3.new(12, 5, 0)).Magnitude < 1e-4)
			-- A rig swap or a new pet measures again; a walking or hello-hopping pet is followed until it settles.
			pet.rigRevision = 2; pet.greeting = .4
			f = Focus.restBounds(memo, pet, CFrame.new(12, 5.2, 0), Vector3.one)
			assert((f.Position - Vector3.new(12, 5.2, 0)).Magnitude < 1e-4 and not memo.settled)
			pet.greeting = 2
			f = Focus.restBounds(memo, pet, CFrame.new(12, 5, 0), Vector3.one)
			assert((f.Position - Vector3.new(12, 5, 0)).Magnitude < 1e-4 and memo.settled)
			pet.greeting = .2 -- a later hello never moves a settled box
			f = Focus.restBounds(memo, pet, CFrame.new(12, 5.3, 0), Vector3.one)
			assert((f.Position - Vector3.new(12, 5, 0)).Magnitude < 1e-4)
			assert(Focus.restBounds(memo, pet, nil, nil) == nil, "no bounds pass through")
		end)
		test("beta 42 D15: the cuddle vignette has its own ScreenGui with no insets, just below the focus gui", function()
			local Cuddle = require(client.PetCuddleUI)
			local v = Focus.new(host, { back = function() end, greet = function() return true end, pet = function() return true end,
				petContact = function() end, canReact = function() return true end, canOwnInput = function() return true end })
			local okCase, why = pcall(function()
				local c = Cuddle.new(v, {})
				local gui = c.underGui
				assert(gui:IsA("ScreenGui") and gui.ScreenInsets == Enum.ScreenInsets.None and c.under.Parent == gui and gui.Parent == v.gui.Parent)
				assert(not gui.Enabled, "hidden until the screen opens")
				v.active, v.panel.Visible, v.gui.DisplayOrder = true, true, 40
				c:begin()
				assert(gui.Enabled and gui.DisplayOrder == 39 and c.under.Visible)
				v.panel.Visible = false; c:syncUnder(); assert(not gui.Enabled, "hides with the panel")
				v.panel.Visible = true; c:syncUnder(); assert(gui.Enabled)
				c:finish(); assert(not gui.Enabled)
				c:destroy(); assert(gui.Parent == nil)
			end)
			v.active = false; v:destroy(); assert(okCase, why)
		end)
	end)
	if ui then ui:destroy() end
	host:Destroy()
	fixture:Destroy()
	assert(ok, problem)
	return { passed = #cases, cases = cases }
end
