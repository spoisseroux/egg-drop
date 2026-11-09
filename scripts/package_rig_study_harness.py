"""Produce one Edit-only source installer for the bounded QA tools; never mounted by Rojo."""
import hashlib
import json
from pathlib import Path
from generate_rig_study_archive import main as archive_main

ROOT = Path(__file__).resolve().parents[1]
FILES = {"Study": "ItemEggsVisualStudy.lua", "ClockSpec": "ItemEggsVisualStudy.spec.lua", "Comparison": "RigOnlyComparison.lua", "ComparisonSpec": "RigOnlyComparison.spec.lua", "ArchiveBuilder": "BuildArchivedRigStudy.lua"}


def main():
    archive_main()
    sources = {name: (ROOT / "scripts" / file).read_text(encoding="utf-8") for name, file in FILES.items()}
    payload = json.dumps(sources, separators=(",", ":"))
    assert "]======]" not in payload
    digest = hashlib.sha256(payload.encode()).hexdigest()
    code = '-- QA ONLY. Generated Edit installer; remove its temporary folders before publication.\n'
    code += 'local sources=game:GetService("HttpService"):JSONDecode([======[' + payload + ']======])\n'
    code += 'local digest="' + digest + '"\n'
    code += """return function()
 assert(not game:GetService("RunService"):IsRunning(),"Rig QA installation is Edit-only")
 local storage=game:GetService("ReplicatedStorage")
 assert(not storage:FindFirstChild("_RigOnlyQAHarness")and not storage:FindFirstChild("_RigStudyArchive_bb8c60b"),"Remove prior fixture-only QA folders explicitly first")
 local folder=Instance.new("Folder");folder.Name="_RigOnlyQAHarness";folder:SetAttribute("FixtureOnly",true);folder:SetAttribute("HarnessSourceSHA256",digest)
 local archive
 local ok,err=pcall(function()
  for name,source in pairs(sources)do local module=Instance.new("ModuleScript");module.Name=name;module.Source=source;module:SetAttribute("FixtureOnly",true);module.Parent=folder end
  folder.Parent=storage;archive=require(folder.ArchiveBuilder)(storage)
 end)
 if not ok then folder:Destroy();if archive then archive:Destroy()end;error(err)end
 return{harness=folder:GetFullName(),archive=archive:GetFullName(),harnessSHA256=digest,archiveSHA256=archive:GetAttribute("SourceManifestSHA256")}
end
"""
    (ROOT / "scripts/InstallRigStudyHarness.lua").write_text(code, encoding="utf-8")
    print("Packaged one Edit installer for5 QA modules and the21-module archived dependency namespace; SHA256 " + digest)


if __name__ == "__main__":
    main()
