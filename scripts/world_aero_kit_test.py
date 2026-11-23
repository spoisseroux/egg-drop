"""Proof-gate tests for the Aero world kit (scripts/build_world_aero_kit_assets.py).

    python scripts/world_aero_kit_test.py

Every refusal writes nothing; the committed readback passes and reproduces the committed outputs byte for byte; and the
island's native collision checkpoint is untouched by the kit (scripts/world_native_collision.py still validates).
"""
import copy
import json
import shutil
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import build_world_aero_kit_assets as gate  # noqa: E402
import world_native_collision as native  # noqa: E402

KIT = gate.KIT


class Gate(unittest.TestCase):
    def setUp(self):
        self.manifest = json.loads((KIT / "aero-kit-manifest.json").read_text())
        self.readback = json.loads((KIT / "aero-kit-readback.json").read_text())
        self.fbx = gate.sha256(KIT / "aero-kit.fbx")
        self.man = gate.sha256(KIT / "aero-kit-manifest.json")
        self.used = gate.island_ids()

    def check(self, readback=None, fbx=None, man=None, used=None):
        return gate.validate(self.manifest, readback or self.readback, fbx or self.fbx, man or self.man,
                             self.used if used is None else used)

    def refuses(self, readback=None, **kw):
        with self.assertRaises(gate.GateError):
            self.check(readback, **kw)

    def test_committed_readback_passes_and_binds_every_mesh(self):
        bound = self.check()
        self.assertEqual(set(bound), {m["name"] for m in self.manifest["meshes"]})

    def test_missing_extra_duplicate_rows_refused(self):
        rb = copy.deepcopy(self.readback)
        rb["parts"].pop()
        self.refuses(rb)
        rb = copy.deepcopy(self.readback)
        rb["parts"].append(dict(rb["parts"][0], name="W7_Kit_Extra__foliage"))
        self.refuses(rb)
        rb = copy.deepcopy(self.readback)
        rb["parts"][1] = dict(rb["parts"][0])
        self.refuses(rb)

    def test_bad_ids_refused(self):
        for bad in ("rbxassetid://0", "12345", "rbxassetid://-4", "rbxassetid://abc", ""):
            rb = copy.deepcopy(self.readback)
            rb["parts"][0]["meshId"] = bad
            self.refuses(rb)
        rb = copy.deepcopy(self.readback)
        rb["parts"][1]["meshId"] = rb["parts"][0]["meshId"]
        self.refuses(rb)

    def test_an_island_mesh_id_is_refused(self):
        island = next(iter(self.used))
        rb = copy.deepcopy(self.readback)
        rb["parts"][0]["meshId"] = "rbxassetid://" + island
        self.refuses(rb)

    def test_sizes_must_be_one_uniform_import_scale(self):
        for bad in ([1, 2], [0, 1, 1], [float("nan"), 1, 1], [float("inf"), 1, 1], "big"):
            rb = copy.deepcopy(self.readback)
            rb["parts"][0]["meshSize"] = bad
            self.refuses(rb)
        rb = copy.deepcopy(self.readback)
        rb["parts"][0]["meshSize"] = [v * 1.01 for v in rb["parts"][0]["meshSize"]]
        self.refuses(rb)

    def test_stale_files_and_rejected_models_refused(self):
        self.refuses(fbx="0" * 64)
        self.refuses(man="0" * 64)
        for state in ("Rejected", "moderated", "Deleted", "Pending", "approved", ""):
            rb = copy.deepcopy(self.readback)
            rb["moderation"] = state
            self.refuses(rb)
        for key in ("assetId", "operationId", "moderation", "fbxSha256", "manifestSha256", "parts"):
            rb = copy.deepcopy(self.readback)
            del rb[key]
            self.refuses(rb)

    def test_outputs_match_the_committed_files(self):
        xml, lua = gate.generate()
        self.assertEqual(xml, gate.XML_OUT.read_text(encoding="utf-8"))
        self.assertEqual(lua, gate.LUA_OUT.read_text(encoding="utf-8"))

    def test_a_refused_readback_writes_nothing(self):
        work = Path(tempfile.mkdtemp())
        try:
            kit = work / "aero-kit"
            shutil.copytree(KIT, kit)
            rb = json.loads((kit / "aero-kit-readback.json").read_text())
            rb["parts"].pop()
            (kit / "aero-kit-readback.json").write_text(json.dumps(rb))
            with self.assertRaises(gate.GateError):
                gate.generate(kit=kit)
            self.assertEqual(sorted(p.name for p in kit.iterdir()), sorted(p.name for p in KIT.iterdir()))
        finally:
            shutil.rmtree(work)

    def test_kit_placements_are_sane(self):
        crowns = self.manifest["crowns"]
        self.assertEqual(len(crowns), 21)
        self.assertTrue(all(c["fit"] < 0.01 for c in crowns), "every shared crown sits on its own tree's leaves")
        self.assertEqual(sorted(self.manifest["hides"]),
                         ["W7_Vegetation__foliage", "W7_Vegetation__foliage_blossom", "W7_Water__waterfall_tumble"])
        island = {p["name"]: p for p in json.loads((gate.WORLD / "world-v7-manifest.json").read_text())["parts"]}
        kit_tris = sum(m["tris"] for m in self.manifest["meshes"] if m["role"] in ("crown", "rest"))
        crown_meshes = {m["name"]: m["tris"] for m in self.manifest["meshes"]}
        placed = sum(crown_meshes[c["mesh"]] for c in crowns) + sum(m["tris"] for m in self.manifest["meshes"] if m["role"] == "rest")
        self.assertEqual(placed, island["W7_Vegetation__foliage"]["tris"] + island["W7_Vegetation__foliage_blossom"]["tris"],
                         "the split crowns and bushes hold exactly the merged crowns' triangles")
        self.assertGreater(kit_tris, 0)
        falls = sum(m["tris"] for m in self.manifest["meshes"] if m["role"] == "falls")
        self.assertLessEqual(falls - island["W7_Water__waterfall_tumble"]["tris"], 1500, "ALIVE-SAFETY 4: +1,500 triangles")

    def test_the_native_checkpoint_is_untouched(self):
        native.validate(gate.ROOT)  # raises when any bound island input or output changed
        project = json.loads((gate.ROOT / "default.project.json").read_text(encoding="utf-8-sig"))
        self.assertEqual(project["tree"]["ServerStorage"]["AeroKit"], {"$path": "assets/world/AeroKit.rbxmx"})
        self.assertNotIn("AeroKit", project["tree"]["ReplicatedStorage"], "live clients never download the kit")


if __name__ == "__main__":
    unittest.main(verbosity=1)
