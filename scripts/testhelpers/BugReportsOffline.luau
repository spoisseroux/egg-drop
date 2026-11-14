-- Pure adapter fixture only; never opens Roblox services or writes player data.
local cases=require("../BugReports.spec")(nil,nil,{
	Reports=require("../../src/server/BugReportStore"),
	Form=require("../../src/shared/BugReportForm"),
	-- Use run_bug_reports.py for the actual UICopy module: it needs Studio's script global.
	UICopy=require("../../build/reports-offline-uicopy"),
})
for _,name in ipairs(cases)do print("PASS "..name)end
print("BugReports: "..#cases.." passed")
