-- Studio probe for the hill's sound and night (WORLD-FINISH-LOOK slice F; probe 6). Read-only but for the camera. Run
-- through Studio MCP execute_luau in Play mode, in the CLIENT's DataModel if the tool offers it (the frame times and the
-- client's own state live there); on the server it runs the load counts only and says so. It reads instance state
-- only (execute_luau has its own module cache): the shared modules are used for pure positions.
--   probe 6  at CAM-HUB, CAM-BENCH and CAM-DEN-IN (the camera Scriptable, 4 s settle, 5 s sampled): the render load
--            near the camera (parts, mesh parts, lights, particle emitters and beams within 90 studs, the glow-caps and
--            fireflies counted with them) and, on the client, Stats.RenderCPUFrameTime / RenderGPUFrameTime p75 when the
--            engine exposes them (RenderStepped's dt is capped by Studio's frame limit, so it is printed, not judged).
--            PASS when BENCH and DEN-IN are no worse than HUB x 1.1 on each measured number. Spencer's phone is the
--            real gate (the brief: p75 no worse than the Hub's).
--   state    (client) the zone AmbientAudio heard at each spot (workspace.EggDropAmbientAudio:HillZone: den at DEN-IN,
--            terrace at BENCH, home at HUB), and HillNightLocal's HillOn, HillLift, HillCaps.
local RunService=game:GetService("RunService")
local Shared=game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Tier=require(Shared.Tier)
local out={}
local function say(line)table.insert(out,line);print(line)end
local client=RunService:IsClient()
local camera=workspace.CurrentCamera
local K=Tier.T(0,5,Tier.FloorY)
local bench=Tier.T(0,-6,Tier.FloorY)
local spots={
	{"HUB",CFrame.lookAt(Vector3.new(-30,12,4),Vector3.new(-60,29,-96)),"home"},
	{"BENCH",CFrame.lookAt(bench+Vector3.new(0,4.2,0),K+Vector3.new(0,2,0)),"terrace"},
	{"DEN-IN",CFrame.lookAt(Vector3.new(-7,8.5,-97),Vector3.new(-7,7,-113)),"den"},
}
local function load(at)
	local counts={parts=0,meshes=0,lights=0,emitters=0,beams=0}
	local reach=90
	for _,item in ipairs(workspace:GetDescendants())do
		if item:IsA("BasePart")then
			if item.Transparency<1 and(item.Position-at).Magnitude<=reach+item.Size.Magnitude/2 then
				counts.parts+=1
				if item:IsA("MeshPart")then counts.meshes+=1 end
			end
		elseif item:IsA("Light")or item:IsA("ParticleEmitter")or item:IsA("Beam")then
			local host=item.Parent
			local p=if host and host:IsA("BasePart")then host.Position elseif host and host:IsA("Attachment")then host.WorldPosition else nil
			if p and(p-at).Magnitude<=reach then
				if item:IsA("Light")then counts.lights+=1 elseif item:IsA("ParticleEmitter")then counts.emitters+=1 else counts.beams+=1 end
			end
		end
	end
	return counts
end
local function p75(list)
	if #list==0 then return nil end
	table.sort(list)
	return list[math.max(1,math.ceil(#list*.75))]
end
local results={}
local was=camera and{type=camera.CameraType,frame=camera.CFrame}
for _,s in ipairs(spots)do
	local name,frame,want=s[1],s[2],s[3]
	local r={name=name,load=load(frame.Position)}
	if client and camera then
		camera.CameraType=Enum.CameraType.Scriptable
		camera.CFrame=frame
		task.wait(4)
		local dts,cpu,gpu={}, {}, {}
		local stats=game:GetService("Stats")
		local t0=os.clock()
		while os.clock()-t0<5 do
			table.insert(dts,RunService.RenderStepped:Wait()*1000)
			local okC,c=pcall(function()return stats.RenderCPUFrameTime end)
			local okG,g=pcall(function()return stats.RenderGPUFrameTime end)
			if okC and type(c)=="number"then table.insert(cpu,c)end
			if okG and type(g)=="number"then table.insert(gpu,g)end
		end
		r.dt,r.cpu,r.gpu=p75(dts),p75(cpu),p75(gpu)
		local ambience=workspace:FindFirstChild("EggDropAmbientAudio")
		r.zone=ambience and ambience:GetAttribute("HillZone")
		r.zoneOk=r.zone==want or(want=="home"and r.zone==nil)
	end
	results[name]=r
	say(string.format("%s: parts %d (mesh %d), lights %d, emitters %d, beams %d%s%s",name,r.load.parts,r.load.meshes,r.load.lights,
		r.load.emitters,r.load.beams,
		if r.dt then string.format("; frame p75 %.1f ms (capped), cpu %s, gpu %s",r.dt,r.cpu and string.format("%.2f",r.cpu)or "n/a",
			r.gpu and string.format("%.2f",r.gpu)or "n/a")else "",
		if client then string.format("; zone %s (%s)",tostring(r.zone),if r.zoneOk then "PASS"else "FAIL, want "..want)else ""))
end
if client and camera and was then camera.CameraType=was.type;camera.CFrame=was.frame end
local hub=results.HUB
local fails=0
for _,name in ipairs({"BENCH","DEN-IN"})do
	local r=results[name]
	for _,key in ipairs({"parts","lights","emitters","beams"})do
		if r.load[key]>math.max(hub.load[key]*1.1,hub.load[key]+2)then fails+=1;say(string.format("FAIL probe 6 %s %s %d over the Hub's %d",name,key,r.load[key],hub.load[key]))end
	end
	for _,key in ipairs({"cpu","gpu"})do
		if r[key]and hub[key]and r[key]>hub[key]*1.1 then fails+=1;say(string.format("FAIL probe 6 %s render %s p75 %.2f over the Hub's %.2f",name,key,r[key],hub[key]))end
	end
end
say(string.format("%s probe 6 (%s)",if fails==0 then "PASS"else "FAIL",if client then "client: load and render times"else "server: load counts only; run in the client for the frame times"))
if client then
	local local_=workspace:FindFirstChild("HillNightLocal")
	say(string.format("HillNightLocal: %s (HillOn %s, HillLift %s, HillCaps %s)",if local_ then "mounted"else "missing (the scene switch off, or live)",
		tostring(local_ and local_:GetAttribute("HillOn")),tostring(local_ and local_:GetAttribute("HillLift")),tostring(local_ and local_:GetAttribute("HillCaps"))))
end
return table.concat(out,"\n")
