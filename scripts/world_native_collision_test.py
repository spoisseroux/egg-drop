"""Actual-builder regressions for native physics portability and staged promotion."""
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest

from world_native_collision import INPUTS, LUA, NATIVE, PROOF, XML, input_hashes, sha, stage_directory, validate

ROOT = Path(__file__).resolve().parents[1]


class NativeCollisionTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="egg-native-proof-")
        self.root = Path(self.temp.name)
        for name in (*INPUTS, LUA, NATIVE, PROOF, XML, "default.project.json"):
            source = ROOT / name
            if source.is_file():
                target = self.root / name
                target.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(source, target)
        for name in ("world_native_collision.py", "world_overlap_upload.py", "build_world_v7_assets.py"):
            target = self.root / "scripts" / name
            target.parent.mkdir(exist_ok=True)
            shutil.copy2(ROOT / "scripts" / name, target)

    def tearDown(self):
        self.temp.cleanup()

    def canonical(self):
        paths = [p for folder in ("assets", "src") for p in (self.root / folder).rglob("*") if p.is_file()]
        paths.append(self.root / "default.project.json")
        return {p.relative_to(self.root).as_posix(): sha(p.read_bytes()) for p in paths}

    def run_builder(self, *args, success=False):
        before = self.canonical()
        result = subprocess.run([sys.executable, str(self.root / "scripts/build_world_v7_assets.py"), *map(str, args)], capture_output=True, text=True)
        self.assertEqual(result.returncode == 0, success, result.stdout + result.stderr)
        self.assertEqual(before, self.canonical(), "builder changed canonical bytes")
        return result

    def test_current_real_checkpoint_passes_and_builder_is_byte_idempotent(self):
        self.assertEqual(validate(self.root)["nativeBytes"], 325532)  # QA v685 W2 lamp 3 pack
        self.run_builder(success=True)

    def test_binary_and_mount_tampering_refused_without_output_changes(self):
        (self.root / NATIVE).write_bytes(b"not the approved export")
        self.assertIn("native export bytes changed", self.run_builder().stderr)
        shutil.copy2(ROOT / NATIVE, self.root / NATIVE)
        project = json.loads((self.root / "default.project.json").read_text())
        project["tree"]["ServerStorage"]["WorldAssets"]["$path"] = XML
        (self.root / "default.project.json").write_text(json.dumps(project))
        self.assertIn("exact native model", self.run_builder().stderr)

    def test_input_set_change_removal_and_addition_fail_closed(self):
        for name in ("assets/world/world-v7-walk.json", "assets/world/world-dressing-import.json"):
            p = self.root / name
            original = p.read_bytes()
            p.write_bytes(original + b" ")
            self.assertIn("input bindings changed", self.run_builder().stderr)
            p.write_bytes(original)
        optional = self.root / "assets/world/world-dressing.fbx"
        original = optional.read_bytes()
        optional.unlink()  # Disposable test fixture only, never repository content.
        self.assertRaises(RuntimeError, validate, self.root)
        proof = json.loads((self.root / PROOF).read_text())
        proof["inputs"] = input_hashes(self.root)
        (self.root / PROOF).write_text(json.dumps(proof))
        optional.write_bytes(original)
        self.assertRaises(RuntimeError, validate, self.root)

    def test_generated_candidate_drift_refused_before_all_runtime_writes(self):
        builder = self.root / "scripts/build_world_v7_assets.py"
        text = builder.read_text()
        text = text.replace("xml, lua = rbxmx(), lua_data()", "xml, lua = rbxmx() + '<!-- changed -->', lua_data()")
        builder.write_text(text)
        self.assertIn("generated candidate differs", self.run_builder().stderr)

    def test_palette_algorithm_drift_cannot_mutate_bound_palette(self):
        builder = self.root / "scripts/build_world_v7_assets.py"
        builder.write_text(builder.read_text().replace("PALETTE_SATURATION = 1.1", "PALETTE_SATURATION = 1.2"))
        self.assertIn("Generated palette changed", self.run_builder().stderr)

    def test_raw_dimensions_change_rejected_before_upload_confirmation_mutation(self):
        p = self.root / "assets/world/world-v7-studio-import.json"
        data = json.loads(p.read_text()); name = next(iter(data)); data[name][1] += .01
        p.write_text(json.dumps(data))
        self.assertIn("input bindings changed", self.run_builder("--confirm-upload", "unused.json").stderr)

    def proof(self):
        path = self.root / "readback.json"
        proof = json.loads((ROOT / "artifacts/qa-2026-11-14-v685/w2-lamp/upload-readback.json").read_text())
        proof["operationId"] = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
        path.write_text(json.dumps(proof))
        return path

    def test_confirmation_stage_is_memory_only_and_canonical_files_unchanged(self):
        output = self.root / "artifacts/rebuild"
        self.run_builder("--stage-native-rebuild", output, "--confirm-upload", self.proof(), success=True)
        self.assertEqual({p.name for p in output.iterdir()}, {"WorldAssets.rbxmx", "WorldV7Data.lua", "world-v7-pending.json"})
        staged = json.loads((output / "world-v7-pending.json").read_text())
        self.assertEqual(staged["upload"]["operationId"], "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee")
        self.assertNotEqual(staged, json.loads((self.root / "assets/world/world-v7-pending.json").read_text()))

    def test_valid_new_upload_cannot_release_stale_native_checkpoint(self):
        imported = self.root / "assets/world/world-v7-studio-import.json"
        data = json.loads(imported.read_text())
        path = self.proof(); proof = json.loads(path.read_text()); row = proof["parts"][0]
        data[row["name"]][0] = 99999999999999; row["meshId"] = 99999999999999
        imported.write_text(json.dumps(data)); path.write_text(json.dumps(proof))
        self.assertIn("input bindings changed", self.run_builder("--confirm-upload", path).stderr)
        out = self.root / "artifacts/new-upload"
        self.run_builder("--stage-native-rebuild", out, "--confirm-upload", path, success=True)
        self.assertIn("99999999999999", (out / "WorldAssets.rbxmx").read_text())

    def test_watched_destination_and_resolved_alias_refused(self):
        self.assertRaises(ValueError, stage_directory, self.root, self.root / "assets/rebuild")
        self.run_builder("--stage-native-rebuild", self.root / "src/rebuild")
        alias = self.root / "unwatched-alias"
        if os.name == "nt":
            result = subprocess.run(["cmd", "/c", "mklink", "/J", str(alias), str(self.root / "assets")], capture_output=True)
            if result.returncode != 0:
                self.skipTest("junction creation unavailable")
        else:
            alias.symlink_to(self.root / "assets", target_is_directory=True)
        self.assertRaises(ValueError, stage_directory, self.root, alias / "rebuild")
        self.run_builder("--stage-native-rebuild", alias / "rebuild")

    def test_staged_file_symlinks_cannot_write_through_to_canonical(self):
        out = self.root / "artifacts/file-alias"; out.mkdir(parents=True)
        for name, source in (("WorldAssets.rbxmx", XML), ("WorldV7Data.lua", LUA), ("world-v7-pending.json", "assets/world/world-v7-pending.json")):
            link = out / name
            try:
                link.symlink_to(self.root / source)
            except OSError:
                self.skipTest("file symlink creation unavailable")
            self.assertIn("must not be a link/alias", self.run_builder("--stage-native-rebuild", out, "--confirm-upload", self.proof()).stderr)
            link.unlink()  # Disposable link only.

    def test_staged_existing_hardlinks_are_replaced_without_canonical_write(self):
        out = self.root / "artifacts/hardlink"; out.mkdir(parents=True)
        for name, source in (("WorldAssets.rbxmx", XML), ("WorldV7Data.lua", LUA), ("world-v7-pending.json", "assets/world/world-v7-pending.json")):
            os.link(self.root / source, out / name)
        self.run_builder("--stage-native-rebuild", out, "--confirm-upload", self.proof(), success=True)
        self.assertNotEqual(json.loads((out / "world-v7-pending.json").read_text())["upload"]["operationId"], json.loads((self.root / "assets/world/world-v7-pending.json").read_text())["upload"]["operationId"])


if __name__ == "__main__":
    unittest.main(verbosity=2)
