"""Archive the actual bb8c60b Factory dependency closure for a QA-only same-world comparison."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parents[1]
REVISION = "bb8c60b"
NAMESPACE = "_RigStudyArchive_bb8c60b"


def git(*args):
    return subprocess.check_output(["git", *args], cwd=ROOT).decode("utf-8")


def main():
    revision = git("rev-parse", REVISION).strip()
    pending = [("client", "PetFactory"), ("client", "HollowClock")]
    sources, manifest = {}, []
    while pending:
        kind, name = pending.pop()
        key = f"{kind}/{name}"
        if key in sources:
            continue
        source_path = f"src/{kind}/{name}.lua"
        original = git("show", f"{revision}:{source_path}")
        pending.extend((kind, dep) for dep in re.findall(r"script\.Parent\.([A-Za-z_]\w*)", original))
        pending.extend(("shared", dep) for dep in re.findall(r"(?:Shared|\.Shared)\.([A-Za-z_]\w*)", original))
        archived = original.replace("ReplicatedStorage.Shared", f"ReplicatedStorage.{NAMESPACE}.Shared")
        for quote in ('"', "'"):
            archived = archived.replace(f"game:GetService({quote}ReplicatedStorage{quote}).Shared", f"game:GetService({quote}ReplicatedStorage{quote}).{NAMESPACE}.Shared")
        assert "ReplicatedStorage.Shared" not in archived
        assert 'GetService("ReplicatedStorage").Shared' not in archived
        sources[key] = archived
        manifest.append({"path": source_path, "originalSHA256": hashlib.sha256(original.encode()).hexdigest(), "sandboxSHA256": hashlib.sha256(archived.encode()).hexdigest()})
    payload = json.dumps({"revision": revision, "namespace": NAMESPACE, "sources": sources, "manifest": sorted(manifest, key=lambda row: row["path"])}, separators=(",", ":"))
    digest = hashlib.sha256(payload.encode()).hexdigest()
    assert "]====]" not in payload
    code = '-- QA ONLY. Generated frozen Factory dependency closure; invoke builder in Studio Edit.\n'
    code += 'local archive=game:GetService("HttpService"):JSONDecode([====[' + payload + ']====])\n'
    code += 'local digest="' + digest + '"\n'
    code += """return function(parent)
 assert(not game:GetService("RunService"):IsRunning(),"Archive builder is Edit-only")
 parent=parent or game:GetService("ReplicatedStorage")
 assert(not parent:FindFirstChild(archive.namespace),"Destroy the prior QA archive explicitly before rebuilding")
 local folder=Instance.new("Folder");folder.Name=archive.namespace;folder:SetAttribute("FixtureOnly",true);folder:SetAttribute("SourceRevision",archive.revision);folder:SetAttribute("SourceManifestSHA256",digest)
 local groups={}
 for _,name in ipairs({"client","shared"})do local group=Instance.new("Folder");group.Name=if name=="client"then "Client"else "Shared";group.Parent=folder;groups[name]=group end
 local ok,err=pcall(function()
  for path,source in pairs(archive.sources)do
   local kind,name=string.match(path,"^([^/]+)/(.+)$");local module=Instance.new("ModuleScript");module.Name=name;module.Source=source;module:SetAttribute("FixtureOnly",true);module.Parent=groups[kind]
  end
  folder.Parent=parent
 end)
 if not ok then folder:Destroy();error(err)end
 return folder
end
"""
    (ROOT / "scripts/BuildArchivedRigStudy.lua").write_text(code, encoding="utf-8")
    output = ROOT / "artifacts/aero-garden-2026-11-09/rig-study-archive-manifest.json"
    output.write_text(json.dumps({"revision": revision, "namespace": NAMESPACE, "manifestSHA256": digest, "moduleCount": len(sources), "modules": sorted(manifest, key=lambda row: row["path"])}, indent=2) + "\n", encoding="utf-8")
    print(f"Archived {len(sources)} actual Factory dependencies at {revision}; namespace {NAMESPACE}; no current Shared dependencies remain.")


if __name__ == "__main__":
    main()
