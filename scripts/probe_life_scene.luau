-- Read-only Studio probe for beta 14 garden life (GARDEN-LIFE-BUILD-PLAN [check]s). Run in Play (server or client
-- context with the lounge built) through Studio MCP execute_luau; it changes nothing it does not clean up.
--   1. Chimes: are W7_Chime_1..5 separate movers (WorldMotion "sway", a WorldPivot) under EggDropLounge.World?
--   2. Lamps: the LampOrbs mesh's bounds, and each LifeSceneSim lamp's nearest point on it (the halo height).
--   3. The falls pool: the water mesh's transparency at (64.5, 3.2, -66) and the koi plates' depth.
--   4. Dewdrops: for each lime kit crown, a CanQuery clone raycast up from each stem tip's fruit top: how far the leaves'
--      underside is above the tip (the top third hidden needs the underside below the fruit's top).
local out={}
local function say(...)table.insert(out,table.concat({...}," "))end
local lounge=workspace:FindFirstChild("EggDropLounge")
local world=lounge and lounge:FindFirstChild("World")
say("lounge",tostring(lounge~=nil),"world",tostring(world~=nil))
for k=1,5 do
	local part=world and world:FindFirstChild("W7_Chime_"..k.."__palette")
	say("chime",k,part and"present"or"MISSING",part and tostring(part:GetAttribute("WorldMotion"))or"",
		part and tostring(part:GetAttribute("WorldPivot"))or"",part and tostring(part.Transparency)or"")
end
local orbs=world and world:FindFirstChild("W7_LampOrbs__glow_warm")
say("lamp orbs",orbs and tostring(orbs.Position).." size "..tostring(orbs.Size)or"MISSING")
local Scene=require(game:GetService("Players").LocalPlayer.PlayerScripts.Client.LifeSceneSim)
for i,at in ipairs(Scene.Lamps)do say("lamp",i,tostring(at))end
local pool=world and world:FindFirstChild("W7_Water__water_pool")
say("pool water",pool and("transparency "..pool.Transparency.." material "..tostring(pool.Material))or"MISSING (kit or Aero layer?)")
local kit=lounge and lounge:FindFirstChild("AeroKit")
if kit then
	local Sim=require(game:GetService("Players").LocalPlayer.PlayerScripts.Client.LifeSim)
	local Data=require(game:GetService("ReplicatedStorage").Shared.WorldAeroKit)
	local Kit=require(game:GetService("Players").LocalPlayer.PlayerScripts.Client.AeroKit)
	local crowns=Sim.kitCrowns(Data,Kit.crownFrame,{foliage_blossom=true})
	local scratch=Instance.new("Folder");scratch.Name="_ProbeCrowns";scratch.Parent=workspace
	for i,crown in ipairs(crowns)do
		for _,p in ipairs(kit:GetChildren())do
			local pivot=p:GetAttribute("WorldPivot")
			if typeof(pivot)=="Vector3"and(pivot-crown.pivot).Magnitude<.05 then
				local clone=p:Clone();clone.CanQuery=true;clone.CFrame=p:GetAttribute("WorldRestCFrame")or p.CFrame;clone.Parent=scratch
				local params=RaycastParams.new();params.FilterType=Enum.RaycastFilterType.Include;params.FilterDescendantsInstances={clone}
				for _,slot in ipairs(Sim.fruitStems(i,crown))do
					local top=slot.stem-Vector3.new(0,Sim.Fruit.hang,0)+Vector3.new(0,.5*1.28/2*1.5,0)
					local hit=workspace:Raycast(top-Vector3.new(0,3,0),Vector3.new(0,10,0),params)
					say("crown",crown.tree,"slot",slot.k,"underside above the tip",hit and string.format("%.2f",hit.Position.Y-slot.stem.Y)or"no hit")
				end
			end
		end
	end
	scratch:Destroy()
else
	say("AeroKit folder MISSING (Aero off?)")
end
return table.concat(out,"\n")
