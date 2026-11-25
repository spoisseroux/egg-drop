-- Park site specs and the Hollow (WORLD-ALIVE-LOOK section 2, 2026-11-25). ParkLayout.makeLayout takes a site spec;
-- the arrival and the old grove (live, and the ParkHollow switch off) must come out as they were: their numbers are
-- pinned here from the module before the refactor (to 1e-3, so a float32 Studio run passes too), and offline they are
-- compared exactly with the base tree. Then the Hollow: Fable's circle and pieces, rigid groups, slots inside the
-- circle less 1, the gaps and bench, the dressing clear of every slot, no kerb data, the place switch.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.ParkSites)(ServerScriptService.Server)
return function(server,offline)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Park=require(Shared.ParkLayout)
	local Data=require(Shared.ParkPoseData)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local PINNED_ARRIVAL={
	["Benches.1.id"]="entrance",
	["Benches.1.length"]=9.5700,
	["Benches.1.mesh"]="Park_BenchLong",
	["Benches.1.position.X"]=36.5000,
	["Benches.1.position.Y"]=4.6113,
	["Benches.1.position.Z"]=57.6000,
	["Benches.1.seats"]=5.0000,
	["Benches.1.yaw"]=-0.0595,
	["Center.X"]=36.0000,
	["Center.Y"]=4.5750,
	["Center.Z"]=66.0000,
	["Enabled"]="true",
	["EnterInset"]=0.5000,
	["Equipment.ball.id"]="ball",
	["Equipment.ball.keepout"]=3.0000,
	["Equipment.ball.position.X"]=45.0000,
	["Equipment.ball.position.Y"]=4.5825,
	["Equipment.ball.position.Z"]=60.0000,
	["Equipment.ball.yaw"]=0.0000,
	["Equipment.sandbox.id"]="sandbox",
	["Equipment.sandbox.keepout"]=3.6000,
	["Equipment.sandbox.position.X"]=26.0000,
	["Equipment.sandbox.position.Y"]=4.4850,
	["Equipment.sandbox.position.Z"]=64.0000,
	["Equipment.sandbox.sandHeight"]=0.2500,
	["Equipment.sandbox.size.X"]=5.0000,
	["Equipment.sandbox.size.Y"]=5.0000,
	["Equipment.sandbox.yaw"]=0.0000,
	["Equipment.seesaw.arm"]=2.6000,
	["Equipment.seesaw.id"]="seesaw",
	["Equipment.seesaw.keepout"]=3.6000,
	["Equipment.seesaw.maxTilt"]=0.2600,
	["Equipment.seesaw.pivotHeight"]=1.1000,
	["Equipment.seesaw.position.X"]=37.0000,
	["Equipment.seesaw.position.Y"]=4.5494,
	["Equipment.seesaw.position.Z"]=73.0000,
	["Equipment.seesaw.yaw"]=0.0000,
	["Equipment.slide.chuteEnd.X"]=45.0000,
	["Equipment.slide.chuteEnd.Y"]=4.5688,
	["Equipment.slide.chuteEnd.Z"]=64.5000,
	["Equipment.slide.deckHeight"]=3.6000,
	["Equipment.slide.id"]="slide",
	["Equipment.slide.keepout"]=2.0000,
	["Equipment.slide.position.X"]=45.0000,
	["Equipment.slide.position.Y"]=4.5550,
	["Equipment.slide.position.Z"]=72.0000,
	["Equipment.slide.yaw"]=3.1416,
	["Equipment.swing.barHeight"]=5.6000,
	["Equipment.swing.id"]="swing",
	["Equipment.swing.keepout"]=4.0000,
	["Equipment.swing.position.X"]=28.0000,
	["Equipment.swing.position.Y"]=4.4488,
	["Equipment.swing.position.Z"]=71.0000,
	["Equipment.swing.seatHeight"]=1.5000,
	["Equipment.swing.yaw"]=3.1416,
	["Gateways.1.angle"]=-0.2600,
	["Gateways.1.id"]="east",
	["Gateways.1.position.X"]=51.4622,
	["Gateways.1.position.Y"]=4.5377,
	["Gateways.1.position.Z"]=63.1721,
	["Gateways.1.width"]=4.0000,
	["Gateways.1.yaw"]=-1.2016,
	["Gateways.2.angle"]=-2.0900,
	["Gateways.2.id"]="southwest",
	["Gateways.2.position.X"]=28.0610,
	["Gateways.2.position.Y"]=4.5865,
	["Gateways.2.position.Z"]=56.4496,
	["Gateways.2.width"]=4.0000,
	["Gateways.2.yaw"]=0.3744,
	["Id"]="arrival",
	["Keepout.1.center.X"]=26.0000,
	["Keepout.1.center.Y"]=64.0000,
	["Keepout.1.radius"]=3.6000,
	["Keepout.10.center.X"]=45.0000,
	["Keepout.10.center.Y"]=72.0000,
	["Keepout.10.radius"]=2.0000,
	["Keepout.2.center.X"]=28.0000,
	["Keepout.2.center.Y"]=71.0000,
	["Keepout.2.radius"]=4.0000,
	["Keepout.3.center.X"]=33.5203,
	["Keepout.3.center.Y"]=57.4226,
	["Keepout.3.radius"]=1.8000,
	["Keepout.4.center.X"]=36.5000,
	["Keepout.4.center.Y"]=57.6000,
	["Keepout.4.radius"]=1.8000,
	["Keepout.5.center.X"]=37.0000,
	["Keepout.5.center.Y"]=73.0000,
	["Keepout.5.radius"]=3.6000,
	["Keepout.6.center.X"]=39.4797,
	["Keepout.6.center.Y"]=57.7774,
	["Keepout.6.radius"]=1.8000,
	["Keepout.7.center.X"]=45.0000,
	["Keepout.7.center.Y"]=60.0000,
	["Keepout.7.radius"]=3.0000,
	["Keepout.8.center.X"]=45.0000,
	["Keepout.8.center.Y"]=64.5000,
	["Keepout.8.radius"]=1.6000,
	["Keepout.9.center.X"]=45.0000,
	["Keepout.9.center.Y"]=68.2500,
	["Keepout.9.radius"]=1.6000,
	["Kerb.height"]=0.3500,
	["Kerb.width"]=0.6000,
	["LeaveOutset"]=1.5000,
	["Radius.X"]=16.0000,
	["Radius.Y"]=11.0000,
	["SeatStepOut"]=1.2500,
	["SlotOrder.1"]="swing1",
	["SlotOrder.2"]="swing2",
	["SlotOrder.3"]="slide",
	["SlotOrder.4"]="seesaw1",
	["SlotOrder.5"]="seesaw2",
	["SlotOrder.6"]="sand1",
	["SlotOrder.7"]="sand2",
	["SlotOrder.8"]="ball1",
	["SlotOrder.9"]="ball2",
	["Slots.ball1.approach.X"]=43.0000,
	["Slots.ball1.approach.Y"]=4.5975,
	["Slots.ball1.approach.Z"]=60.0000,
	["Slots.ball1.ball.X"]=45.0000,
	["Slots.ball1.ball.Y"]=5.0325,
	["Slots.ball1.ball.Z"]=60.0000,
	["Slots.ball1.equipment"]="ball",
	["Slots.ball1.id"]="ball1",
	["Slots.ball1.pose.position.X"]=43.0000,
	["Slots.ball1.pose.position.Y"]=4.5975,
	["Slots.ball1.pose.position.Z"]=60.0000,
	["Slots.ball1.pose.yaw"]=1.5708,
	["Slots.ball1.yaw"]=1.5708,
	["Slots.ball2.approach.X"]=47.0000,
	["Slots.ball2.approach.Y"]=4.5675,
	["Slots.ball2.approach.Z"]=60.0000,
	["Slots.ball2.ball.X"]=45.0000,
	["Slots.ball2.ball.Y"]=5.0325,
	["Slots.ball2.ball.Z"]=60.0000,
	["Slots.ball2.equipment"]="ball",
	["Slots.ball2.id"]="ball2",
	["Slots.ball2.pose.position.X"]=47.0000,
	["Slots.ball2.pose.position.Y"]=4.5675,
	["Slots.ball2.pose.position.Z"]=60.0000,
	["Slots.ball2.pose.yaw"]=-1.5708,
	["Slots.ball2.yaw"]=-1.5708,
	["Slots.sand1.approach.X"]=24.4000,
	["Slots.sand1.approach.Y"]=4.4690,
	["Slots.sand1.approach.Z"]=64.0000,
	["Slots.sand1.castle.X"]=26.0000,
	["Slots.sand1.castle.Y"]=4.7350,
	["Slots.sand1.castle.Z"]=64.0000,
	["Slots.sand1.equipment"]="sandbox",
	["Slots.sand1.id"]="sand1",
	["Slots.sand1.pose.position.X"]=24.4000,
	["Slots.sand1.pose.position.Y"]=4.7190,
	["Slots.sand1.pose.position.Z"]=64.0000,
	["Slots.sand1.pose.yaw"]=1.5708,
	["Slots.sand1.yaw"]=1.5708,
	["Slots.sand2.approach.X"]=27.6000,
	["Slots.sand2.approach.Y"]=4.5050,
	["Slots.sand2.approach.Z"]=64.0000,
	["Slots.sand2.castle.X"]=26.0000,
	["Slots.sand2.castle.Y"]=4.7350,
	["Slots.sand2.castle.Z"]=64.0000,
	["Slots.sand2.equipment"]="sandbox",
	["Slots.sand2.id"]="sand2",
	["Slots.sand2.pose.position.X"]=27.6000,
	["Slots.sand2.pose.position.Y"]=4.7550,
	["Slots.sand2.pose.position.Z"]=64.0000,
	["Slots.sand2.pose.yaw"]=-1.5708,
	["Slots.sand2.yaw"]=-1.5708,
	["Slots.seesaw1.approach.X"]=34.4000,
	["Slots.seesaw1.approach.Y"]=4.5383,
	["Slots.seesaw1.approach.Z"]=71.7500,
	["Slots.seesaw1.arm"]=-2.6000,
	["Slots.seesaw1.equipment"]="seesaw",
	["Slots.seesaw1.id"]="seesaw1",
	["Slots.seesaw1.pivot.X"]=37.0000,
	["Slots.seesaw1.pivot.Y"]=5.6494,
	["Slots.seesaw1.pivot.Z"]=73.0000,
	["Slots.seesaw1.pose.position.X"]=34.4000,
	["Slots.seesaw1.pose.position.Y"]=5.7847,
	["Slots.seesaw1.pose.position.Z"]=73.0000,
	["Slots.seesaw1.pose.yaw"]=1.5708,
	["Slots.seesaw1.seatGround.X"]=34.4000,
	["Slots.seesaw1.seatGround.Y"]=4.5347,
	["Slots.seesaw1.seatGround.Z"]=73.0000,
	["Slots.seesaw1.yaw"]=1.5708,
	["Slots.seesaw2.approach.X"]=39.6000,
	["Slots.seesaw2.approach.Y"]=4.5563,
	["Slots.seesaw2.approach.Z"]=71.7500,
	["Slots.seesaw2.arm"]=2.6000,
	["Slots.seesaw2.equipment"]="seesaw",
	["Slots.seesaw2.id"]="seesaw2",
	["Slots.seesaw2.pivot.X"]=37.0000,
	["Slots.seesaw2.pivot.Y"]=5.6494,
	["Slots.seesaw2.pivot.Z"]=73.0000,
	["Slots.seesaw2.pose.position.X"]=39.6000,
	["Slots.seesaw2.pose.position.Y"]=5.8050,
	["Slots.seesaw2.pose.position.Z"]=73.0000,
	["Slots.seesaw2.pose.yaw"]=-1.5708,
	["Slots.seesaw2.seatGround.X"]=39.6000,
	["Slots.seesaw2.seatGround.Y"]=4.5550,
	["Slots.seesaw2.seatGround.Z"]=73.0000,
	["Slots.seesaw2.yaw"]=-1.5708,
	["Slots.slide.approach.X"]=45.0000,
	["Slots.slide.approach.Y"]=4.5550,
	["Slots.slide.approach.Z"]=73.2000,
	["Slots.slide.chuteEnd.X"]=45.0000,
	["Slots.slide.chuteEnd.Y"]=4.5688,
	["Slots.slide.chuteEnd.Z"]=64.5000,
	["Slots.slide.chuteTop.X"]=45.0000,
	["Slots.slide.chuteTop.Y"]=8.1550,
	["Slots.slide.chuteTop.Z"]=71.2000,
	["Slots.slide.equipment"]="slide",
	["Slots.slide.id"]="slide",
	["Slots.slide.ladderTop.X"]=45.0000,
	["Slots.slide.ladderTop.Y"]=8.1550,
	["Slots.slide.ladderTop.Z"]=72.6000,
	["Slots.slide.pose.position.X"]=45.0000,
	["Slots.slide.pose.position.Y"]=8.1550,
	["Slots.slide.pose.position.Z"]=72.0000,
	["Slots.slide.pose.yaw"]=3.1416,
	["Slots.slide.yaw"]=3.1416,
	["Slots.swing1.amplitude"]=0.5000,
	["Slots.swing1.approach.X"]=26.6000,
	["Slots.swing1.approach.Y"]=4.4372,
	["Slots.swing1.approach.Z"]=69.7500,
	["Slots.swing1.axis"]="X",
	["Slots.swing1.equipment"]="swing",
	["Slots.swing1.id"]="swing1",
	["Slots.swing1.pivot.X"]=26.6000,
	["Slots.swing1.pivot.Y"]=10.0251,
	["Slots.swing1.pivot.Z"]=71.0000,
	["Slots.swing1.pose.position.X"]=26.6000,
	["Slots.swing1.pose.position.Y"]=5.9251,
	["Slots.swing1.pose.position.Z"]=71.0000,
	["Slots.swing1.pose.yaw"]=3.1416,
	["Slots.swing1.rope"]=4.1000,
	["Slots.swing1.seatGround.X"]=26.6000,
	["Slots.swing1.seatGround.Y"]=4.4251,
	["Slots.swing1.seatGround.Z"]=71.0000,
	["Slots.swing1.yaw"]=3.1416,
	["Slots.swing2.amplitude"]=0.5000,
	["Slots.swing2.approach.X"]=29.4000,
	["Slots.swing2.approach.Y"]=4.4822,
	["Slots.swing2.approach.Z"]=69.7500,
	["Slots.swing2.axis"]="X",
	["Slots.swing2.equipment"]="swing",
	["Slots.swing2.id"]="swing2",
	["Slots.swing2.pivot.X"]=29.4000,
	["Slots.swing2.pivot.Y"]=10.0724,
	["Slots.swing2.pivot.Z"]=71.0000,
	["Slots.swing2.pose.position.X"]=29.4000,
	["Slots.swing2.pose.position.Y"]=5.9724,
	["Slots.swing2.pose.position.Z"]=71.0000,
	["Slots.swing2.pose.yaw"]=3.1416,
	["Slots.swing2.rope"]=4.1000,
	["Slots.swing2.seatGround.X"]=29.4000,
	["Slots.swing2.seatGround.Y"]=4.4724,
	["Slots.swing2.seatGround.Z"]=71.0000,
	["Slots.swing2.yaw"]=3.1416,
	["Version"]=1.0000,
	["WalkSpeed"]=4.0000,
	}
	local PINNED_GROVE={
	["Benches.1.id"]="entrance",
	["Benches.1.length"]=9.5700,
	["Benches.1.mesh"]="Park_BenchLong",
	["Benches.1.position.X"]=-38.5000,
	["Benches.1.position.Y"]=4.6130,
	["Benches.1.position.Z"]=-37.6000,
	["Benches.1.seats"]=5.0000,
	["Benches.1.yaw"]=3.0821,
	["Center.X"]=-38.0000,
	["Center.Y"]=4.7650,
	["Center.Z"]=-46.0000,
	["Enabled"]="true",
	["EnterInset"]=0.5000,
	["Equipment.ball.id"]="ball",
	["Equipment.ball.keepout"]=3.0000,
	["Equipment.ball.position.X"]=-47.0000,
	["Equipment.ball.position.Y"]=4.7025,
	["Equipment.ball.position.Z"]=-40.0000,
	["Equipment.ball.yaw"]=3.1416,
	["Equipment.sandbox.id"]="sandbox",
	["Equipment.sandbox.keepout"]=3.6000,
	["Equipment.sandbox.position.X"]=-28.0000,
	["Equipment.sandbox.position.Y"]=4.7400,
	["Equipment.sandbox.position.Z"]=-44.0000,
	["Equipment.sandbox.sandHeight"]=0.2500,
	["Equipment.sandbox.size.X"]=5.0000,
	["Equipment.sandbox.size.Y"]=5.0000,
	["Equipment.sandbox.yaw"]=3.1416,
	["Equipment.seesaw.arm"]=2.6000,
	["Equipment.seesaw.id"]="seesaw",
	["Equipment.seesaw.keepout"]=3.6000,
	["Equipment.seesaw.maxTilt"]=0.2600,
	["Equipment.seesaw.pivotHeight"]=1.1000,
	["Equipment.seesaw.position.X"]=-39.0000,
	["Equipment.seesaw.position.Y"]=4.8225,
	["Equipment.seesaw.position.Z"]=-53.0000,
	["Equipment.seesaw.yaw"]=3.1416,
	["Equipment.slide.chuteEnd.X"]=-47.0000,
	["Equipment.slide.chuteEnd.Y"]=4.7094,
	["Equipment.slide.chuteEnd.Z"]=-44.5000,
	["Equipment.slide.deckHeight"]=3.6000,
	["Equipment.slide.id"]="slide",
	["Equipment.slide.keepout"]=2.0000,
	["Equipment.slide.position.X"]=-47.0000,
	["Equipment.slide.position.Y"]=4.7300,
	["Equipment.slide.position.Z"]=-52.0000,
	["Equipment.slide.yaw"]=6.2832,
	["Equipment.swing.barHeight"]=5.6000,
	["Equipment.swing.id"]="swing",
	["Equipment.swing.keepout"]=4.0000,
	["Equipment.swing.position.X"]=-30.0000,
	["Equipment.swing.position.Y"]=4.7725,
	["Equipment.swing.position.Z"]=-51.0000,
	["Equipment.swing.seatHeight"]=1.5000,
	["Equipment.swing.yaw"]=6.2832,
	["Gateways.1.angle"]=-0.2600,
	["Gateways.1.id"]="east",
	["Gateways.1.position.X"]=-22.5378,
	["Gateways.1.position.Y"]=4.7072,
	["Gateways.1.position.Z"]=-48.8279,
	["Gateways.1.width"]=4.0000,
	["Gateways.1.yaw"]=-1.2016,
	["Gateways.2.angle"]=1.0516,
	["Gateways.2.id"]="southwest",
	["Gateways.2.position.X"]=-30.0610,
	["Gateways.2.position.Y"]=4.4911,
	["Gateways.2.position.Z"]=-36.4496,
	["Gateways.2.width"]=4.0000,
	["Gateways.2.yaw"]=3.5160,
	["Id"]="grove",
	["Keepout.1.center.X"]=-28.0000,
	["Keepout.1.center.Y"]=-44.0000,
	["Keepout.1.radius"]=3.6000,
	["Keepout.10.center.X"]=-47.0000,
	["Keepout.10.center.Y"]=-52.0000,
	["Keepout.10.radius"]=2.0000,
	["Keepout.2.center.X"]=-30.0000,
	["Keepout.2.center.Y"]=-51.0000,
	["Keepout.2.radius"]=4.0000,
	["Keepout.3.center.X"]=-35.5203,
	["Keepout.3.center.Y"]=-37.4226,
	["Keepout.3.radius"]=1.8000,
	["Keepout.4.center.X"]=-38.5000,
	["Keepout.4.center.Y"]=-37.6000,
	["Keepout.4.radius"]=1.8000,
	["Keepout.5.center.X"]=-39.0000,
	["Keepout.5.center.Y"]=-53.0000,
	["Keepout.5.radius"]=3.6000,
	["Keepout.6.center.X"]=-41.4797,
	["Keepout.6.center.Y"]=-37.7774,
	["Keepout.6.radius"]=1.8000,
	["Keepout.7.center.X"]=-47.0000,
	["Keepout.7.center.Y"]=-40.0000,
	["Keepout.7.radius"]=3.0000,
	["Keepout.8.center.X"]=-47.0000,
	["Keepout.8.center.Y"]=-44.5000,
	["Keepout.8.radius"]=1.6000,
	["Keepout.9.center.X"]=-47.0000,
	["Keepout.9.center.Y"]=-48.2500,
	["Keepout.9.radius"]=1.6000,
	["Kerb.height"]=0.3500,
	["Kerb.width"]=0.6000,
	["LeaveOutset"]=1.5000,
	["Radius.X"]=16.0000,
	["Radius.Y"]=11.0000,
	["SeatStepOut"]=1.2500,
	["SlotOrder.1"]="swing1",
	["SlotOrder.2"]="swing2",
	["SlotOrder.3"]="slide",
	["SlotOrder.4"]="seesaw1",
	["SlotOrder.5"]="seesaw2",
	["SlotOrder.6"]="sand1",
	["SlotOrder.7"]="sand2",
	["SlotOrder.8"]="ball1",
	["SlotOrder.9"]="ball2",
	["Slots.ball1.approach.X"]=-45.0000,
	["Slots.ball1.approach.Y"]=4.7075,
	["Slots.ball1.approach.Z"]=-40.0000,
	["Slots.ball1.ball.X"]=-47.0000,
	["Slots.ball1.ball.Y"]=5.1525,
	["Slots.ball1.ball.Z"]=-40.0000,
	["Slots.ball1.equipment"]="ball",
	["Slots.ball1.id"]="ball1",
	["Slots.ball1.pose.position.X"]=-45.0000,
	["Slots.ball1.pose.position.Y"]=4.7075,
	["Slots.ball1.pose.position.Z"]=-40.0000,
	["Slots.ball1.pose.yaw"]=4.7124,
	["Slots.ball1.yaw"]=4.7124,
	["Slots.ball2.approach.X"]=-49.0000,
	["Slots.ball2.approach.Y"]=4.6975,
	["Slots.ball2.approach.Z"]=-40.0000,
	["Slots.ball2.ball.X"]=-47.0000,
	["Slots.ball2.ball.Y"]=5.1525,
	["Slots.ball2.ball.Z"]=-40.0000,
	["Slots.ball2.equipment"]="ball",
	["Slots.ball2.id"]="ball2",
	["Slots.ball2.pose.position.X"]=-49.0000,
	["Slots.ball2.pose.position.Y"]=4.6975,
	["Slots.ball2.pose.position.Z"]=-40.0000,
	["Slots.ball2.pose.yaw"]=1.5708,
	["Slots.ball2.yaw"]=1.5708,
	["Slots.sand1.approach.X"]=-26.4000,
	["Slots.sand1.approach.Y"]=4.7360,
	["Slots.sand1.approach.Z"]=-44.0000,
	["Slots.sand1.castle.X"]=-28.0000,
	["Slots.sand1.castle.Y"]=4.9900,
	["Slots.sand1.castle.Z"]=-44.0000,
	["Slots.sand1.equipment"]="sandbox",
	["Slots.sand1.id"]="sand1",
	["Slots.sand1.pose.position.X"]=-26.4000,
	["Slots.sand1.pose.position.Y"]=4.9860,
	["Slots.sand1.pose.position.Z"]=-44.0000,
	["Slots.sand1.pose.yaw"]=4.7124,
	["Slots.sand1.yaw"]=4.7124,
	["Slots.sand2.approach.X"]=-29.6000,
	["Slots.sand2.approach.Y"]=4.7440,
	["Slots.sand2.approach.Z"]=-44.0000,
	["Slots.sand2.castle.X"]=-28.0000,
	["Slots.sand2.castle.Y"]=4.9900,
	["Slots.sand2.castle.Z"]=-44.0000,
	["Slots.sand2.equipment"]="sandbox",
	["Slots.sand2.id"]="sand2",
	["Slots.sand2.pose.position.X"]=-29.6000,
	["Slots.sand2.pose.position.Y"]=4.9940,
	["Slots.sand2.pose.position.Z"]=-44.0000,
	["Slots.sand2.pose.yaw"]=1.5708,
	["Slots.sand2.yaw"]=1.5708,
	["Slots.seesaw1.approach.X"]=-36.4000,
	["Slots.seesaw1.approach.Y"]=4.8148,
	["Slots.seesaw1.approach.Z"]=-51.7500,
	["Slots.seesaw1.arm"]=-2.6000,
	["Slots.seesaw1.equipment"]="seesaw",
	["Slots.seesaw1.id"]="seesaw1",
	["Slots.seesaw1.pivot.X"]=-39.0000,
	["Slots.seesaw1.pivot.Y"]=5.9225,
	["Slots.seesaw1.pivot.Z"]=-53.0000,
	["Slots.seesaw1.pose.position.X"]=-36.4000,
	["Slots.seesaw1.pose.position.Y"]=6.0705,
	["Slots.seesaw1.pose.position.Z"]=-53.0000,
	["Slots.seesaw1.pose.yaw"]=4.7124,
	["Slots.seesaw1.seatGround.X"]=-36.4000,
	["Slots.seesaw1.seatGround.Y"]=4.8205,
	["Slots.seesaw1.seatGround.Z"]=-53.0000,
	["Slots.seesaw1.yaw"]=4.7124,
	["Slots.seesaw2.approach.X"]=-41.6000,
	["Slots.seesaw2.approach.Y"]=4.8051,
	["Slots.seesaw2.approach.Z"]=-51.7500,
	["Slots.seesaw2.arm"]=2.6000,
	["Slots.seesaw2.equipment"]="seesaw",
	["Slots.seesaw2.id"]="seesaw2",
	["Slots.seesaw2.pivot.X"]=-39.0000,
	["Slots.seesaw2.pivot.Y"]=5.9225,
	["Slots.seesaw2.pivot.Z"]=-53.0000,
	["Slots.seesaw2.pose.position.X"]=-41.6000,
	["Slots.seesaw2.pose.position.Y"]=6.0595,
	["Slots.seesaw2.pose.position.Z"]=-53.0000,
	["Slots.seesaw2.pose.yaw"]=1.5708,
	["Slots.seesaw2.seatGround.X"]=-41.6000,
	["Slots.seesaw2.seatGround.Y"]=4.8095,
	["Slots.seesaw2.seatGround.Z"]=-53.0000,
	["Slots.seesaw2.yaw"]=1.5708,
	["Slots.slide.approach.X"]=-47.0000,
	["Slots.slide.approach.Y"]=4.6925,
	["Slots.slide.approach.Z"]=-53.2000,
	["Slots.slide.chuteEnd.X"]=-47.0000,
	["Slots.slide.chuteEnd.Y"]=4.7094,
	["Slots.slide.chuteEnd.Z"]=-44.5000,
	["Slots.slide.chuteTop.X"]=-47.0000,
	["Slots.slide.chuteTop.Y"]=8.3195,
	["Slots.slide.chuteTop.Z"]=-51.2000,
	["Slots.slide.equipment"]="slide",
	["Slots.slide.id"]="slide",
	["Slots.slide.ladderTop.X"]=-47.0000,
	["Slots.slide.ladderTop.Y"]=8.2805,
	["Slots.slide.ladderTop.Z"]=-52.6000,
	["Slots.slide.pose.position.X"]=-47.0000,
	["Slots.slide.pose.position.Y"]=8.3300,
	["Slots.slide.pose.position.Z"]=-52.0000,
	["Slots.slide.pose.yaw"]=6.2832,
	["Slots.slide.yaw"]=6.2832,
	["Slots.swing1.amplitude"]=0.5000,
	["Slots.swing1.approach.X"]=-28.6000,
	["Slots.swing1.approach.Y"]=4.7573,
	["Slots.swing1.approach.Z"]=-49.7500,
	["Slots.swing1.axis"]="X",
	["Slots.swing1.equipment"]="swing",
	["Slots.swing1.id"]="swing1",
	["Slots.swing1.pivot.X"]=-28.6000,
	["Slots.swing1.pivot.Y"]=10.3594,
	["Slots.swing1.pivot.Z"]=-51.0000,
	["Slots.swing1.pose.position.X"]=-28.6000,
	["Slots.swing1.pose.position.Y"]=6.2594,
	["Slots.swing1.pose.position.Z"]=-51.0000,
	["Slots.swing1.pose.yaw"]=6.2832,
	["Slots.swing1.rope"]=4.1000,
	["Slots.swing1.seatGround.X"]=-28.6000,
	["Slots.swing1.seatGround.Y"]=4.7594,
	["Slots.swing1.seatGround.Z"]=-51.0000,
	["Slots.swing1.yaw"]=6.2832,
	["Slots.swing2.amplitude"]=0.5000,
	["Slots.swing2.approach.X"]=-31.4000,
	["Slots.swing2.approach.Y"]=4.7759,
	["Slots.swing2.approach.Z"]=-49.7500,
	["Slots.swing2.axis"]="X",
	["Slots.swing2.equipment"]="swing",
	["Slots.swing2.id"]="swing2",
	["Slots.swing2.pivot.X"]=-31.4000,
	["Slots.swing2.pivot.Y"]=10.3813,
	["Slots.swing2.pivot.Z"]=-51.0000,
	["Slots.swing2.pose.position.X"]=-31.4000,
	["Slots.swing2.pose.position.Y"]=6.2813,
	["Slots.swing2.pose.position.Z"]=-51.0000,
	["Slots.swing2.pose.yaw"]=6.2832,
	["Slots.swing2.rope"]=4.1000,
	["Slots.swing2.seatGround.X"]=-31.4000,
	["Slots.swing2.seatGround.Y"]=4.7813,
	["Slots.swing2.seatGround.Z"]=-51.0000,
	["Slots.swing2.yaw"]=6.2832,
	["Version"]=1.0000,
	["WalkSpeed"]=4.0000,
	}
	local EXTRA=table.freeze({Sites=true,ById=true,Specs=true,HollowOn=true,HollowPlaceId=true})
	-- {path = number | string} for every data field (functions and the site lists left out).
	local function flatten(site)
		local out={}
		local function walk(path,value)
			local kind=typeof(value)
			if kind=="Vector3"then walk(path..".X",value.X);walk(path..".Y",value.Y);walk(path..".Z",value.Z)
			elseif kind=="Vector2"then walk(path..".X",value.X);walk(path..".Y",value.Y)
			elseif kind=="number"then out[path]=value
			elseif kind=="string"or kind=="boolean"then out[path]=tostring(value)
			elseif kind=="table"then
				for key,v in pairs(value)do
					if type(v)~="function"and not(path==""and EXTRA[key])then walk(if path==""then tostring(key)else path.."."..tostring(key),v)end
				end
			end
		end
		walk("",site)
		return out
	end
	local function compare(site,pinned,label)
		local got=flatten(site)
		for path,want in pairs(pinned)do
			local have=got[path]
			assert(have~=nil,label..": missing "..path)
			if type(want)=="number"then
				assert(type(have)=="number"and math.abs(have-want)<=1e-3,label..": "..path.." is "..tostring(have)..", pinned "..want)
			else assert(have==want,label..": "..path.." is "..tostring(have)..", pinned "..want)end
		end
		for path in pairs(got)do assert(pinned[path]~=nil,label..": new field "..path)end
	end
	local H=Park.build(Park.Specs.hollow)
	local function flat(v)return Vector2.new(v.X,v.Z)end
	local function local2(root,yaw,p)
		local dx,dz=p.X-root.X,p.Z-root.Z
		local c,s=math.cos(-yaw),math.sin(-yaw)
		return Vector2.new(dx*c+dz*s,-dx*s+dz*c)
	end

	test("arrival: every number as pinned before the site specs",function()compare(Park,PINNED_ARRIVAL,"arrival")end)
	test("the old grove (live, and the switch off): every number as pinned",function()
		compare(Park.build(Park.Specs.grove),PINNED_GROVE,"grove")
		if not Park.HollowOn then compare(Park.ById.grove,PINNED_GROVE,"live grove")end
	end)

	if offline and offline.base then
		test("offline: the arrival and the old grove are the base tree's to the last bit, mesh frames too",function()
			local Old=offline.base.require(offline.base.shared.ParkLayout)
			local OldData=offline.base.require(offline.base.shared.ParkPoseData)
			local function same(a,b,path)
				if type(a)=="function"then return end
				if typeof(a)=="Vector3"or typeof(a)=="Vector2"then assert(a==b,path);return end
				if type(a)=="table"then
					assert(type(b)=="table",path)
					for key,value in pairs(a)do if key~="Sites"and key~="ById"then same(value,b[key],path.."."..tostring(key))end end
					for key,value in pairs(b)do if type(value)~="function"and not EXTRA[key]then assert(a[key]~=nil,path..": new "..tostring(key))end end
					return
				end
				assert(a==b,path..": "..tostring(a).." ~= "..tostring(b))
			end
			same(Old,Park,"arrival")
			same(Old.ById.grove,Park.build(Park.Specs.grove),"grove")
			local function frames(a,b,label)
				assert(#a.static==#b.static and #a.colliders==#b.colliders and #a.seats==#b.seats and a.kerbSegments==b.kerbSegments,label)
				for i,entry in ipairs(a.static)do
					local other=b.static[i]
					assert(entry.mesh==other.mesh and entry.cframe.Position==other.cframe.Position and entry.size==other.size,label.." static "..i)
					for k=1,9 do assert(entry.cframe.r[k]==other.cframe.r[k],label.." static turn "..i)end
				end
			end
			frames(OldData.layout(),Data.layout(),"arrival mesh frames")
			frames(OldData.forSite(Old.ById.grove).layout(),Data.forSite(Park.build(Park.Specs.grove)).layout(),"grove mesh frames")
		end)
	end

	test("the switch: the Hollow only with FeatureFlags.ParkHollow, on the beta place or in Studio",function()
		assert(Park.hollowOn({flags={ParkHollow=true},place=Park.HollowPlaceId,studio=false}),"beta place")
		assert(Park.hollowOn({flags={ParkHollow=true},place=1,studio=true}),"Studio")
		assert(not Park.hollowOn({flags={ParkHollow=true},place=96451847774961,studio=false}),"live keeps the grove")
		assert(not Park.hollowOn({flags={ParkHollow=false},place=Park.HollowPlaceId,studio=true}),"the flag off keeps the grove")
		assert(Park.ById.grove.Natural==(if Park.HollowOn then true else nil),"the live second site follows the switch")
		assert(Park.ById.grove.Id=="grove"and Park.Sites[2]==Park.ById.grove,"one site id either way")
	end)

	test("the Hollow: Fable's circle, no kerb, the same five pieces, nine slots, order and capacity",function()
		assert(H.Id=="grove"and H.Natural==true and H.Kerb==nil)
		assert(H.Radius==Vector2.new(14,14)and H.Center.X==-42 and H.Center.Z==-51)
		assert(table.concat(H.SlotOrder,",")==table.concat(Park.SlotOrder,","))
		for id,slot in pairs(Park.Slots)do assert(H.Slots[id]and H.Slots[id].equipment==slot.equipment,id)end
		for id in pairs(H.Slots)do assert(Park.Slots[id],id)end
		for id in pairs(Park.Equipment)do assert(H.Equipment[id],id)end
		for id in pairs(H.Equipment)do assert(Park.Equipment[id],id)end
		assert(#H.Benches==1 and H.Benches[1].seats==5 and H.Benches[1].mesh=="Park_BenchLong")
	end)

	test("every piece is a rigid group: points, heights and turns inside a piece are the arrival's",function()
		for id,slot in pairs(H.Slots)do
			local old=Park.Slots[id]
			local e,oe=H.Equipment[slot.equipment],Park.Equipment[slot.equipment]
			local function check(p,q,name)
				local a,b=local2(e.position,e.yaw,p),local2(oe.position,oe.yaw,q)
				assert((a-b).Magnitude<1e-3,id.."."..name.." moved inside its piece")
				local lift,oldLift=p.Y-H.ground(p.X,p.Z),q.Y-Park.ground(q.X,q.Z)
				assert(math.abs(lift-oldLift)<1e-3,id.."."..name.." height "..lift.." was "..oldLift)
			end
			check(slot.approach,old.approach,"approach");check(slot.pose.position,old.pose.position,"pose")
			for _,key in ipairs({"seatGround","pivot","ladderTop","chuteTop","chuteEnd","castle","ball"})do
				if old[key]then check(slot[key],old[key],key)end
			end
			local turn=(slot.yaw-e.yaw)-(old.yaw-oe.yaw)
			assert(math.abs(math.sin(turn))<1e-6 and math.cos(turn)>0,id.." turned inside its piece")
			assert(math.abs(math.sin((slot.pose.yaw-slot.yaw)-(old.pose.yaw-old.yaw)))<1e-6,id.." pose yaw")
		end
		local chute=(H.Equipment.slide.chuteEnd-H.Equipment.slide.position)
		assert(math.abs(Vector2.new(chute.X,chute.Z).Magnitude-7.5)<1e-3,"the chute's run is 7.5")
	end)

	test("Fable's places (the ball nudged 1.5 from the bench) and every slot approach inside the circle less 1 stud",function()
		local fable={seesaw={-36.3,-58.4},slide={-43.1,-58.6},sandbox={-48.7,-54.7},swing={-51.0,-48.3},ball={-35.5,-46.5}}
		for id,at in pairs(fable)do
			local p=H.Equipment[id].position
			assert((flat(p)-Vector2.new(at[1],at[2])).Magnitude<=1.5+1e-6,id.." nudged more than 1.5")
		end
		for id,slot in pairs(H.Slots)do assert(H.inside(slot.approach,-1),id.." approach too near the rim")end
		assert(H.inside(H.Slots.slide.chuteEnd,-1),"chute foot near the rim")
		-- The toes fan round the palm P (-40, -48), about 11 studs out and 36 degrees apart: the paw from shelf 2.
		local P=Vector2.new(-40,-48)
		local last
		for _,id in ipairs({"seesaw","slide","sandbox","swing"})do
			local d=flat(H.Equipment[id].position)-P
			assert(math.abs(d.Magnitude-11)<=.6,id.." is not a toe ("..d.Magnitude..")")
			local angle=math.atan2(d.Y,d.X)
			if last then local gap=math.deg(last-angle);assert(gap>31 and gap<41,id.." toe spacing "..gap)end
			last=angle
		end
	end)

	test("the slide: ladder foot toward the cliff, the chute lands in the palm; seats face the palm; swing seats too",function()
		local ladder,foot=H.Slots.slide.approach,H.Slots.slide.chuteEnd
		assert((flat(ladder)-Vector2.new(-43.4,-59.8)).Magnitude<.2,"ladder foot "..tostring(ladder))
		assert((flat(foot)-Vector2.new(-41.0,-51.4)).Magnitude<.2,"chute foot "..tostring(foot))
		local P=Vector2.new(-40,-48)
		for _,id in ipairs({"swing1","swing2"})do
			local slot=H.Slots[id];local to=(P-flat(slot.approach)).Unit
			assert(Vector2.new(math.sin(slot.yaw),math.cos(slot.yaw)):Dot(to)>.95,id.." does not face the palm")
		end
		-- See-saw riders wait on the palm side of the beam, like the arrival's wait on its centre side.
		for _,id in ipairs({"seesaw1","seesaw2"})do
			local slot=H.Slots[id]
			assert((flat(slot.approach)-P).Magnitude<(flat(slot.seatGround)-P).Magnitude,id.." waits on the cliff side")
		end
	end)

	test("gaps path and plaza on the rim, 4 wide, 6+ studs from the bench's ends; the bench inside facing the centre",function()
		assert(#H.Gateways==2 and H.Gateways[1].id=="path"and H.Gateways[2].id=="plaza")
		assert((flat(H.Gateways[1].position)-Vector2.new(-28.2,-53.1)).Magnitude<.1)
		assert((flat(H.Gateways[2].position)-Vector2.new(-44.5,-37.2)).Magnitude<.1)
		local bench=H.Benches[1]
		local along=Vector2.new(math.cos(bench.yaw),-math.sin(bench.yaw))
		local toC=(flat(H.Center)-flat(bench.position)).Unit
		assert(Vector2.new(math.sin(bench.yaw),math.cos(bench.yaw)):Dot(toC)>.999,"bench faces the centre")
		for _,side in ipairs({-1,1})do
			local tip=flat(bench.position)+along*side*bench.length*.5
			assert(H.inside(Vector3.new(tip.X,0,tip.Y),-1),"bench end near the rim")
			for _,gate in ipairs(H.Gateways)do assert((tip-flat(gate.position)).Magnitude>=6,"bench end by gap "..gate.id)end
		end
	end)

	test("the dressing: Fable's list, nothing on a slot approach, the ladder, the chute or the bench",function()
		local D=H.Dressing
		assert(D and #D.plates==7 and #D.stones==12 and #D.stumps==3 and #D.flowers==8 and D.log and D.column,"dressing counts")
		local toes=0;for _,plate in ipairs(D.plates)do if string.find(plate.name,"^HollowToe_")then toes+=1 end end
		assert(toes==4,"four toe patches")
		local points={}
		for id,slot in pairs(H.Slots)do points[id]=flat(slot.approach)end
		local deck,foot=flat(H.Equipment.slide.position),flat(H.Equipment.slide.chuteEnd)
		local function toChute(p)
			local d=foot-deck;local t=math.clamp((p-deck):Dot(d)/d:Dot(d),0,1)
			return (p-(deck+d*t)).Magnitude
		end
		local bench=H.Benches[1]
		local function clearOf(p,radius,label)
			for id,q in pairs(points)do assert((p-q).Magnitude>=radius+1,label.." on slot "..id)end
			assert(toChute(p)>=radius+1,label.." on the chute")
			assert((p-flat(bench.position)).Magnitude>=radius+bench.length*.5+.5,label.." on the bench")
			for _,gate in ipairs(H.Gateways)do assert((p-flat(gate.position)).Magnitude>=radius+1.4,label.." blocks gap "..gate.id)end
		end
		for _,stone in ipairs(D.stones)do clearOf(Vector2.new(stone.x,stone.z),stone.size.X*.5,stone.name)end
		for _,stump in ipairs(D.stumps)do clearOf(Vector2.new(stump.x,stump.z),stump.diameter*.5,"stump")end
		local log=D.log
		for k=-4,4 do
			local s=k*D.log.length/8
			clearOf(Vector2.new(log.x+s*math.sin(log.heading),log.z+s*math.cos(log.heading)),log.diameter*.5,"log")
		end
		-- The column lies in the dig spot along its back, clear of the castle (stage 3 is 1.9 across).
		local sand=flat(H.Equipment.sandbox.position)
		local axis=Vector2.new(math.sin(D.column.heading),math.cos(D.column.heading))
		local rel=Vector2.new(D.column.x,D.column.z)-sand
		local across=math.abs(rel.X*axis.Y-rel.Y*axis.X)
		assert(across>=.95+D.column.diameter*.5,"the column touches the castle")
		assert(D.column.y<D.column.sand and D.column.y+D.column.diameter*.5>D.column.sand,"the column is not 60% under the sand")
		-- Pets keep off the log, the stumps and every stone.
		assert(not H.clearOfKeepout(Vector3.new(log.x,0,log.z),0),"log keepout")
		for _,stump in ipairs(D.stumps)do assert(not H.clearOfKeepout(Vector3.new(stump.x,0,stump.z),0),"stump keepout")end
		for _,stone in ipairs(D.stones)do assert(not H.clearOfKeepout(Vector3.new(stone.x,0,stone.z),0),"stone keepout")end
	end)

	test("kerb readers: no kerb segments, star-orb posts or orbs at the Hollow; the log is a player collider",function()
		local layout=Data.forSite(H).layout()
		assert(layout.kerbSegments==0 and layout.gatePosts==0,"kerb data at the Hollow")
		for _,entry in ipairs(layout.static)do
			assert(entry.mesh~="Park_KerbSegment"and entry.mesh~="Park_GatePost"and entry.mesh~="Park_GateStarOrb",entry.mesh)
		end
		local logs=0;for _,box in ipairs(layout.colliders)do if box.group=="Log"then logs+=1 end end
		assert(logs==1,"one log collider")
		local arrival=Data.layout()
		assert(arrival.kerbSegments>=16 and arrival.gatePosts==4,"arrival kerb unchanged")
	end)

	test("the cliff foot: the rim kisses the rock (1.3 past the foot line at angle -2.14), nothing placed is within 2 of it",function()
		local FOOT={Vector2.new(-36,-70),Vector2.new(-46,-66),Vector2.new(-50,-62),Vector2.new(-56,-58),Vector2.new(-64,-54),Vector2.new(-70,-48)}
		local a,b=FOOT[1],FOOT[#FOOT]
		local function side(p)return((b-a).X*(p-a).Y-(b-a).Y*(p-a).X)/(b-a).Magnitude end
		local lawn=if side(flat(H.Center))>0 then 1 else -1 -- the centre is on the lawn
		local function rockSide(p)return-lawn*side(p)end -- > 0 past the line, on the rock
		local worst,at=-math.huge,0
		for k=0,359 do
			local angle=math.rad(k)-math.pi
			local s=rockSide(Vector2.new(H.Center.X+14*math.cos(angle),H.Center.Z+14*math.sin(angle)))
			if s>worst then worst,at=s,angle end
		end
		assert(math.abs(worst-1.31)<.05 and math.abs(at+2.14)<.05,string.format("rim past the foot line %.2f at %.2f",worst,at))
		local function toFoot(p)
			local best=math.huge
			for k=1,#FOOT-1 do
				local s,d=FOOT[k],FOOT[k+1]-FOOT[k]
				local t=math.clamp((p-s):Dot(d)/d:Dot(d),0,1)
				best=math.min(best,(p-(s+d*t)).Magnitude)
			end
			return best
		end
		local function clear(label,p,radius)
			assert(rockSide(p)<0 and toFoot(p)>=2+(radius or 0),string.format("%s (%.1f, %.1f) is %.2f from the cliff foot",label,p.X,p.Y,toFoot(p)))
		end
		for id,e in pairs(H.Equipment)do clear(id,flat(e.position))end
		for id,slot in pairs(H.Slots)do clear(id,flat(slot.approach))end
		clear("bench",flat(H.Benches[1].position))
		local D=H.Dressing
		for _,stone in ipairs(D.stones)do clear(stone.name,Vector2.new(stone.x,stone.z),stone.size.X*.5)end
		for _,stump in ipairs(D.stumps)do clear("stump",Vector2.new(stump.x,stump.z),stump.diameter*.5)end
		clear("log",Vector2.new(D.log.x,D.log.z));clear("column",Vector2.new(D.column.x,D.column.z))
	end)

	test("clear of the cliff path work: everything at z -65 or north (the bank is at z under -80)",function()
		local function north(z,label)assert(z>=-65.001,label.." at z "..z)end
		north(H.Center.Z-H.Radius.Y,"the circle")
		for id,e in pairs(H.Equipment)do north(e.position.Z,id)end
		for id,slot in pairs(H.Slots)do north(slot.approach.Z,id)end
		for _,stone in ipairs(H.Dressing.stones)do north(stone.z-stone.size.X*.5,stone.name)end
	end)

	return {passed=#cases,cases=cases}
end
