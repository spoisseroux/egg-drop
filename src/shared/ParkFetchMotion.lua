-- Pure fetch-ball sample from the same absolute snapshot clocks for all observers.
local A=require(script.Parent.GardenActivity)
local Motion={Radius=.32}
function Motion.sample(entry,now)
	if type(entry)~="table"then return nil end
	local home=A.vector(entry.home)
	if not home then return nil end
	local lift=Vector3.new(0,Motion.Radius+.03,0)
	if entry.stage=="idle"then return home+lift end
	local landing=A.vector(entry.landing)or home
	if entry.stage=="chase"then
		local t=math.clamp((now-entry.throwStart)/math.max(.001,entry.landTime-entry.throwStart),0,1)
		return home:Lerp(landing,t)+lift+Vector3.new(0,math.sin(math.pi*t)*1.8,0)
	elseif entry.stage=="return"and entry.carrier then
		local sample=A.sample(entry.carrier,now)
		if sample then return sample.position+Vector3.new(math.sin(sample.yaw)*.42,.48,math.cos(sample.yaw)*.42)end
	elseif entry.stage=="home"then
		local drop=A.vector(entry.drop)or landing
		local t=math.clamp((now-entry.homeStart)/math.max(.001,entry.endTime-entry.homeStart),0,1)
		return drop:Lerp(home,t)+lift
	end
	return landing+lift
end
return Motion
