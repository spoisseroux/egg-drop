-- Garden Dash course (V3 slice S5): the generated DashCourse against the walk data the game already ships.
-- Pure shared data; no instances. Usage: require(ServerScriptService.Server.ZZSpecs.DashCourse)()
-- Offline: scripts/run_dash_specs.py (the world checks use the third argument's stand-ins there).
return function(_, shared, offline)
	local Shared = shared or game:GetService("ReplicatedStorage").Shared
	local Course = require(Shared.DashCourse)
	local Stats = require(Shared.DashStats)
	local world
	if offline then world = offline else
		local V7 = require(Shared.HollowWorldLayout).V7
		local Park = require(Shared.ParkLayout)
		local span = V7.WalkableSpans.MainBridge
		world = { groundY = V7.groundY, parks = {}, radius = { Park.Radius.X, Park.Radius.Y },
			span = { span.center.X, span.center.Z, span.size.X, span.size.Z, span.center.Y + span.size.Y * .5 }, lamps = {}, stations = {} }
		for _, site in ipairs(Park.Sites) do table.insert(world.parks, { site.Center.X, site.Center.Z }) end
		for _, lamp in ipairs(V7.Lamps) do table.insert(world.lamps, { lamp.X, lamp.Z }) end
		for _, id in ipairs({ "Eggs", "Journal", "Customize", "ToyLawn" }) do
			table.insert(world.stations, { V7.Stations[id].Position.X, V7.Stations[id].Position.Z })
		end
	end
	local cases = {}
	local function test(name, run) local note = run(); table.insert(cases, if note then name .. ": " .. note else name) end
	local function points(list)
		local out = {}
		for i = 1, #list, 4 do table.insert(out, { d = list[i], x = list[i + 1] / 100, y = list[i + 2] / 100, z = list[i + 3] / 100 }) end
		return out
	end
	local main, branch = points(Course.Main), points(Course.Branch)
	local both = {}
	for _, list in ipairs({ main, branch }) do for _, p in ipairs(list) do table.insert(both, p) end end
	local function near(a, b) return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2) end
	local function inSpan(x, z) return math.abs(x - world.span[1]) <= world.span[3] / 2 and math.abs(z - world.span[2]) <= world.span[4] / 2 end

	test("whole hundredths; distances rise and add up; 200 to 240 studs; the stones save about 14", function()
		for _, list in ipairs({ Course.Main, Course.Branch }) do
			assert(#list % 4 == 0 and list[1] == 0)
			for i, v in ipairs(list) do assert(v % 1 == 0, i) end
			for i = 5, #list, 4 do
				local dx, dz = list[i + 1] - list[i - 3], list[i + 3] - list[i - 1]
				assert(list[i] - list[i - 4] == math.floor(math.sqrt(dx * dx + dz * dz) + .5) and list[i] > list[i - 4], i)
			end
		end
		assert(main[#main].d == Course.Length and Course.Length >= 20000 and Course.Length <= 24000, Course.Length)
		assert(branch[#branch].d == Course.StonesLength)
		assert(Course.Saving == Course.Rejoin - Course.Fork - Course.StonesLength and math.abs(Course.Saving - 1400) <= 50, Course.Saving)
		assert(Course.Fork / Course.Length > .3 and Course.Rejoin / Course.Length < .7, "the fork is about halfway")
	end)
	test("the branch leaves and rejoins the main line on its own points", function()
		for _, pair in ipairs({ { 0, Course.Fork }, { Course.StonesLength, Course.Rejoin } }) do
			local ax, ay, az, ah = Course.at(pair[1], true)
			local bx, by, bz, bh = Course.at(pair[2], false)
			assert(near({ ax, az }, { bx, bz }) < .021 and math.abs(ay - by) < .021)
			assert(math.abs((ah - bh + math.pi) % (2 * math.pi) - math.pi) < .001, "no sharp corner at the fork")
		end
	end)
	test("never within 6 studs of the grove tiles or a park kerb", function()
		local nearest = 1e9
		for _, p in ipairs(both) do
			local gx, gz = math.max(-24 - p.x, 0, p.x + 18), math.max(-50 - p.z, 0, p.z + 30)
			assert(math.sqrt(gx * gx + gz * gz) >= 6, p.d)
			for _, park in ipairs(world.parks) do
				assert(((p.x - park[1]) / world.radius[1]) ^ 2 + ((p.z - park[2]) / world.radius[2]) ^ 2 > 1, p.d)
				for k = 0, 179 do
					local a = k * math.pi / 90
					nearest = math.min(nearest, near({ p.x, p.z }, { park[1] + world.radius[1] * math.cos(a), park[2] + world.radius[2] * math.sin(a) }))
				end
			end
		end
		assert(nearest >= 6, nearest)
	end)
	test("clear of the measured solid things: the leaning tree's base, centre line 3.8 studs and every lane outside it", function()
		local closest = 1e9
		for _, tree in ipairs({ { 38.25, 8, 1.6, 3.8 } }) do -- build_dash_course.py OBSTACLES
			for _, way in ipairs({ { Course.Length, false }, { Course.StonesLength, true } }) do
				for d = 0, way[1], 10 do
					local x, _, z = Course.at(d, way[2])
					closest = math.min(closest, near({ x, z }, tree))
					assert(near({ x, z }, tree) >= tree[4], d)
					for lane = 1, 8 do
						local lx, _, lz = Course.at(d, way[2], lane)
						assert(near({ lx, lz }, tree) >= tree[3] + .4, d)
					end
				end
			end
		end
		return string.format("closest %.2f", closest)
	end)
	test("heights: the bare ground, the deck on the bridge, the stone tops over the stream; no step over 0.8", function()
		for _, p in ipairs(main) do
			local want = if inSpan(p.x, p.z) then world.span[5] else world.groundY(p.x, p.z)
			assert(math.abs(p.y - want) < .012, p.d)
		end
		for _, p in ipairs(branch) do
			local want = world.groundY(p.x, p.z)
			assert(math.abs(p.y - want) < .012 or(p.y == 4 and want < 4), p.d)
		end
		for _, list in ipairs({ main, branch }) do
			for i = 2, #list do assert(math.abs(list[i].y - list[i - 1].y) <= .8, list[i].d) end
		end
	end)
	test("on the deck every lane stays on the deck; lamps and stations keep their room", function()
		for d = 0, Course.Length, 50 do
			local x, _, z = Course.at(d, false)
			if inSpan(x, z) then
				for lane = 1, 8 do
					local _, _, lz = Course.at(d, false, lane)
					assert(math.abs(lz - world.span[2]) <= world.span[4] / 2, d)
				end
			end
			for _, lamp in ipairs(world.lamps) do assert(near({ x, z }, lamp) >= 2.5, d) end
			for _, station in ipairs(world.stations) do assert(near({ x, z }, station) >= 4.4, d) end
		end
	end)
	test("gentle turns: no tighter than a 6-stud circle", function()
		for _, list in ipairs({ main, branch }) do
			for i = 3, #list - 2 do
				local a, b, c = list[i - 2], list[i], list[i + 2]
				local ab, bc, ca = near({ a.x, a.z }, { b.x, b.z }), near({ b.x, b.z }, { c.x, c.z }), near({ c.x, c.z }, { a.x, a.z })
				local area = math.abs((b.x - a.x) * (c.z - a.z) - (c.x - a.x) * (b.z - a.z)) / 2
				assert(area < 1e-6 or ab * bc * ca / (4 * area) >= 5.9, b.d)
			end
		end
	end)
	test("four layouts of six hoops: none between the fork and the rejoin, the right halves, 7 studs apart", function()
		local before = { even = 3, pairs = 3, early = 4, late = 2 }
		assert(#Course.LayoutOrder == 4)
		local fastest = Stats.stride(99) * 150 -- a tick of dash and zoomies at level 99
		for _, id in ipairs(Course.LayoutOrder) do
			local list, count = Course.hurdles(id), 0
			assert(#list == 6, id)
			for i, d in ipairs(list) do
				assert(d % 1 == 0 and d >= 1200 and d <= Course.Length - 1200 and(d <= Course.Fork - 800 or d >= Course.Rejoin + 800), id)
				if d < Course.Fork then count += 1 end
				-- an early press never reaches past the next hoop, however fast the pet runs
				if i > 1 then assert((d - list[i - 1]) * Stats.UnitsPerCs > fastest * 60, id) end
			end
			assert(count == before[id], id)
		end
		assert(Course.hurdles("nope") == Course.Layouts.even)
		local close = 0
		for i = 2, 6 do if Course.Layouts.pairs[i] - Course.Layouts.pairs[i - 1] <= 700 then close += 1 end end
		assert(close == 2)
	end)
	test("three stones in the water, at one hop's spacing, on the branch line", function()
		assert(#Course.Stones == 3)
		for i, stone in ipairs(Course.Stones) do
			local x, _, z = Course.at(stone.d, true)
			assert(near({ x, z }, { stone.x / 100, stone.z / 100 }) < .05 and stone.d >= 1200 and stone.d <= Course.StonesLength - 1200)
			if i > 1 then
				local gap = stone.d - Course.Stones[i - 1].d
				assert(gap >= 280 and gap <= 480, gap)
			end
		end
	end)
	test("at() clamps, moves forward and puts lane 1 and lane 8 3.5 studs apart", function()
		local px, _, pz = Course.at(0, false)
		for d = 25, Course.Length, 25 do
			local x, _, z = Course.at(d, false)
			local moved = near({ x, z }, { px, pz })
			assert(moved > .2 and moved < .27, d)
			px, pz = x, z
		end
		local ax, ay, az = Course.at(-50, false); local bx, by, bz = Course.at(0, false)
		assert(ax == bx and ay == by and az == bz)
		local cx, _, cz = Course.at(5000, false, 1); local dx, _, dz = Course.at(5000, false, 8)
		assert(math.abs(near({ cx, cz }, { dx, dz }) - 3.5) < 1e-6)
	end)
	return { passed = #cases, cases = cases }
end
