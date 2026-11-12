-- Actual default Studio adapters, synthetic key, discarded when Play stops.
return function(server)
	assert(game:GetService("RunService"):IsStudio(), "Studio memory only")
	local Progress,Hatch,Session=require(server.PlayerProgress),require(server.HatchProgress),require(server.SessionProfile)
	local id="fixture-"..game:GetService("HttpService"):GenerateGUID(false)
	local profile=Progress.load(id)
	local first=Hatch.load(id,profile)
	assert(first.status=="Ready"and Session.hydrate(profile,first))
	Progress.equip(profile,"ice","none");Progress.setSetting(profile,"sound","Quiet")
	Progress.setSetting(profile,"reduced",true)
	assert(Progress.flushOnce(profile))
	assert(Hatch.grantStarter(first));local reveal=first.state.lastHatch.id
	assert(Hatch.release(first))
	local nextProfile=Progress.load(id)
	local nextHandle=Hatch.load(id,nextProfile)
	assert(Session.hydrate(nextProfile,nextHandle))
	assert(nextProfile.theme=="ice"and nextProfile.sticker=="none"and nextProfile.sound=="Quiet"and nextProfile.reduced)
	assert(nextProfile.companionId=="pip"and nextHandle.state.lastHatch.id==reveal and nextHandle.state.nectar==6)
	assert(Hatch.command(nextHandle,"ack",reveal,nextHandle.state.revision));assert(Hatch.release(nextHandle))
	return{passed=1,cases={"actual default Studio writers preserve settings and one reveal across reacquisition"},persistentWrites=false}
end
