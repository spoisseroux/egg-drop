-- Garden hour slice F (GARDEN-HOUR-BUILD-PLAN-2026-11-23, architect review): night Book finds follow the hour.
-- Book.isNight is unchanged; Book.stateBits takes an optional isNight (a boolean wins, anything else is the real-hour
-- rule), and LifetimeState passes GardenHour.isNight(GardenHour.time()) while the hour is on (server switch, Hour_on,
-- Aero). Same bit 11 (pet_night), one-way, no save change. BookStateBits and CharmRules are unchanged.
-- Usage (Server): require(ServerScriptService.Server.ZZSpecs.GardenHourBook)(ServerScriptService.Server)
return function(server)
	local Shared=game:GetService("ReplicatedStorage").Shared
	local Book=require(Shared.BookCatalog)
	local Daily=require(Shared.DailyContracts)
	local Hour=require(Shared.GardenHour)
	local Aero=require(Shared.Aero)
	local L=require(server.LifetimeState)
	local cases={}
	local function test(name,run)run();table.insert(cases,name)end
	local Bit=Book.DiscoveryById.pet_night.bit
	local function has(mask)return bit32.band(mask,bit32.lshift(1,Bit))~=0 end
	-- The BookStateBits fixtures: 22:00 and 12:00 in the garden's real hour (UTC-5).
	local night,noon=1700017200,1700067600
	local function petted(at)return{operationSeq=7,lastPetAward={id="p",sequence=8,day=Daily.dayOf(at),petId="pip"}}end
	local function save(at,found)
		local state=petted(at)
		state.nectar=10;state.inventoryMask=1;state.stats={};state.book={found=found or 0,claimed={}}
		return state
	end
	local function record(at,signature,found)
		local after=save(at,found)
		L.record({nectar=10,inventoryMask=1},after,signature or "pet:p",at)
		return after.book.found
	end
	-- Runs fn with the hour on (true) or off (false) at `offset` seconds into the hour, restoring after.
	local function withHour(on,offset,fn)
		local names={Hour.Attribute,Aero.Attribute,Hour.OffsetAttribute}
		local saved={}
		for _,name in ipairs(names)do saved[name]=workspace:GetAttribute(name)end
		local ok,problem=pcall(function()
			workspace:SetAttribute(Aero.Attribute,on);workspace:SetAttribute(Hour.Attribute,on);Hour.setSwitch(on)
			-- GetServerTimeNow() is not 0 in Studio: the offset lands the clock on `offset` seconds into the hour.
			workspace:SetAttribute(Hour.OffsetAttribute,offset-workspace:GetServerTimeNow()%Hour.Period+.5)
			fn()
		end)
		Hour.setSwitch(false)
		for _,name in ipairs(names)do workspace:SetAttribute(name,saved[name])end
		assert(ok,problem)
	end

	test("Book.stateBits: a boolean isNight wins; nil or anything else is the real-hour rule",function()
		assert(has(Book.stateBits(petted(noon),noon,"pet:p",true)),"hour night at the real noon")
		assert(not has(Book.stateBits(petted(night),night,"pet:p",false)),"hour day at the real night")
		for _,value in ipairs({"true",1,0/0})do
			assert(has(Book.stateBits(petted(night),night,"pet:p",value)),"real night "..tostring(value))
			assert(not has(Book.stateBits(petted(noon),noon,"pet:p",value)),"real noon "..tostring(value))
		end
		assert(Book.stateBits(petted(night),night,"pet:p")==Book.stateBits(petted(night),night,"pet:p",nil))
		-- The other rules stand: only the pet write, only that day.
		assert(not has(Book.stateBits(petted(noon),noon,"buy:pip:beanie",true)),"a purchase")
		assert(not has(Book.stateBits(petted(noon-86400),noon,"pet:p",true)),"yesterday's pet")
		assert(Book.isNight(night)and not Book.isNight(noon),"Book.isNight unchanged")
	end)
	test("hour off: LifetimeState keeps the real-hour rule",function()
		withHour(false,3100,function()
			assert(L.hourNight()==nil)
			assert(has(record(night)),"real night finds it")
			assert(not has(record(noon)),"real noon does not")
		end)
	end)
	test("hour on: pet_night follows the hour's night (bit 11), not the real hour",function()
		if not Hour.ceiling()then table.insert(cases,"SKIPPED on case: GardenHour ceiling is off in this build");return end
		withHour(true,3100,function()
			assert(Hour.on()and Hour.isNight(Hour.time()),"the hour's night")
			assert(L.hourNight()==true)
			assert(has(record(noon)),"petting in the hour's night at the real noon finds it")
			assert(not has(record(noon,"buy:pip:beanie")),"still only the pet write")
		end)
		withHour(true,1200,function()
			assert(Hour.on()and not Hour.isNight(Hour.time()),"the hour's day")
			assert(L.hourNight()==false)
			assert(not has(record(night)),"petting in the hour's day at the real night does not")
			-- One-way: a found bit stays found whatever the hour says.
			assert(has(record(noon,"pet:p",bit32.lshift(1,Bit))),"found stays found")
		end)
		withHour(true,2880,function()assert(L.hourNight()==true,"night starts at 2880")end)
		withHour(true,2879,function()assert(L.hourNight()==false,"golden is not night")end)
	end)
	test("a partial gate is off: Aero off or a missing Hour_on keeps the real hour",function()
		withHour(true,3100,function()
			workspace:SetAttribute(Aero.Attribute,false);assert(L.hourNight()==nil,"Aero off")
			workspace:SetAttribute(Aero.Attribute,true);workspace:SetAttribute(Hour.Attribute,nil);assert(L.hourNight()==nil,"no Hour_on")
			workspace:SetAttribute(Hour.Attribute,true);Hour.setSwitch(false);assert(L.hourNight()==nil,"server switch off")
		end)
	end)
	return{passed=#cases,cases=cases}
end
