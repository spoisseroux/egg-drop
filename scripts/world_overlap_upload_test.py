"""Meaningful negative-case checks for no-delete world upload promotion."""
import copy
import unittest
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
from world_overlap_upload import is_confirmed, validate_proof


class UploadProofTests(unittest.TestCase):
    def setUp(self):
        self.names = ["W7_Test_"+str(i) for i in range(11)]
        self.pending = dict(changed=self.names, added=[], previous={n: {"hash": "0"*16} for n in self.names})
        self.manifest = {"parts": [{"name": n, "hash": format(i+1, "016x")} for i, n in enumerate(self.names)]}
        self.canonical = {n: [str(200+i), 1., 2., 3.] for i, n in enumerate(self.names)}
        self.hashes = dict(fbxSha256="a"*64, manifestSha256="b"*64)
        self.proof = dict(assetId=97399181362990, operationId="25c9378b-cc5f-418f-8663-1dc9b3a348fd",
                          parts=[dict(name=n, meshId=self.canonical[n][0], meshSize=[1., 2., 3.]) for n in self.names],
                          checkpoint=dict(**self.hashes, previousMeshIds={n:str(100+i) for i,n in enumerate(self.names)}))

    def validate(self, proof=None):
        return validate_proof(self.pending, self.manifest, self.canonical, proof or self.proof, self.hashes)

    def test_valid_eleven_and_idempotent_confirmation(self):
        result = self.validate()
        again = validate_proof(result, self.manifest, self.canonical, self.proof, self.hashes)
        self.assertEqual(result, again)
        self.assertEqual(len(result["confirmedImport"]), 11)
        self.assertNotIn("confirmedImport", self.pending)
        self.assertTrue(all(is_confirmed(p["name"], p, self.canonical, result, self.hashes) for p in self.manifest["parts"]))

    def test_previous_ids_rejected_even_equal_size(self):
        proof = copy.deepcopy(self.proof)
        proof["checkpoint"]["previousMeshIds"][self.names[0]] = self.canonical[self.names[0]][0]
        with self.assertRaises(ValueError): self.validate(proof)

    def test_invalid_names_partial_extra_duplicate_unknown(self):
        variants = [self.proof["parts"][:-1], self.proof["parts"]+[self.proof["parts"][0]],
                    [dict(self.proof["parts"][0], name="Unknown")]+self.proof["parts"][1:]]
        for rows in variants:
            proof = copy.deepcopy(self.proof); proof["parts"] = rows
            with self.subTest(rows=len(rows)), self.assertRaises(ValueError): self.validate(proof)

    def test_bad_ids(self):
        for value in ("0", "-1", "1.2", "nan", None, True):
            proof = copy.deepcopy(self.proof); proof["parts"][0]["meshId"] = value
            with self.subTest(value=value), self.assertRaises(ValueError): self.validate(proof)

    def test_bad_dimensions(self):
        for value in (float("nan"), float("inf"), 0, -1, True, "2"):
            proof = copy.deepcopy(self.proof); proof["parts"][0]["meshSize"][0] = value
            with self.subTest(value=value), self.assertRaises(ValueError): self.validate(proof)

    def test_dimension_count_or_mismatch(self):
        for sizes in ([1., 2.], [1., 2., 3., 4.], [1.00001, 2., 3.]):
            proof = copy.deepcopy(self.proof); proof["parts"][0]["meshSize"] = sizes
            with self.subTest(sizes=sizes), self.assertRaises(ValueError): self.validate(proof)

    def test_missing_or_malformed_provenance(self):
        for key, value in (("checkpoint", {}), ("operationId", "wrong"), ("assetId", 0)):
            proof = copy.deepcopy(self.proof); proof[key] = value
            with self.subTest(key=key), self.assertRaises(ValueError): self.validate(proof)

    def test_wrong_uploaded_file_checkpoints(self):
        for key in self.hashes:
            proof = copy.deepcopy(self.proof); proof["checkpoint"][key] = "f"*64
            with self.subTest(key=key), self.assertRaises(ValueError): self.validate(proof)

    def test_stale_geometry_reholds(self):
        confirmed = self.validate()
        part = dict(self.manifest["parts"][0], hash="e"*16)
        self.assertFalse(is_confirmed(part["name"], part, self.canonical, confirmed, self.hashes))

    def test_changed_id_or_size_reholds(self):
        confirmed = self.validate()
        for index, value in ((0, "999"), (1, 1.00001)):
            target = copy.deepcopy(self.canonical); target[self.names[0]][index] = value
            self.assertFalse(is_confirmed(self.names[0], self.manifest["parts"][0], target, confirmed, self.hashes))

    def test_changed_file_or_unbound_old_marker_reholds(self):
        confirmed = self.validate()
        for hashes in (dict(self.hashes, fbxSha256="c"*64), dict(self.hashes, manifestSha256="c"*64)):
            self.assertFalse(is_confirmed(self.names[0], self.manifest["parts"][0], self.canonical, confirmed, hashes))
        old = dict(confirmed); old["upload"] = {"assetId":"123", "operationId":self.proof["operationId"]}
        self.assertFalse(is_confirmed(self.names[0], self.manifest["parts"][0], self.canonical, old, self.hashes))

    def test_builder_new_ids_stale_proof_aborts_without_touching_existing_outputs(self):
        # Execute the actual builder in a disposable fixture tree: real existing
        # output bytes must remain unchanged, rather than mocking away a write.
        with tempfile.TemporaryDirectory(prefix="egg-world-proof-") as temporary:
            root = Path(temporary)
            scripts, world, shared = root/"scripts", root/"assets/world", root/"src/shared"
            for directory in (scripts, world, shared): directory.mkdir(parents=True)
            here = Path(__file__).resolve().parent
            for name in ("build_world_v7_assets.py", "world_overlap_upload.py", "world_native_collision.py"):
                shutil.copy2(here/name, scripts/name)
            fixture = {
                "world-v7-manifest.json": self.manifest,
                "world-v7-walk.json": {},
                "world-v7-studio-import.json": self.canonical,
                "world-v7-uploads.json": {},
                "world-v7-collision.json": {"parts": []},
                "world-v7-collision-studio-import.json": {"parts": {}},
            }
            for name, data in fixture.items(): (world/name).write_text(json.dumps(data))
            (world/"world-v7-declutter.fbx").write_bytes(b"test uploaded fbx")
            hashes = dict(fbxSha256=hashlib.sha256((world/"world-v7-declutter.fbx").read_bytes()).hexdigest(),
                          manifestSha256=hashlib.sha256((world/"world-v7-manifest.json").read_bytes()).hexdigest())
            proof = copy.deepcopy(self.proof); proof["checkpoint"].update(hashes)
            pending = validate_proof(self.pending, self.manifest, self.canonical, proof, hashes)
            # Canonical maps new IDs, but just one geometry binding is stale.
            pending["confirmedImport"][self.names[0]]["hash"] = "f"*16
            (world/"world-v7-pending.json").write_text(json.dumps(pending))
            xml, lua = world/"WorldAssets.rbxmx", shared/"WorldV7Data.lua"
            xml.write_bytes(b"EXISTING_XML_WITH_OLD_VERIFIED_IDS")
            lua.write_bytes(b"EXISTING_LUA")
            result = subprocess.run([sys.executable, str(scripts/"build_world_v7_assets.py")], capture_output=True, text=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Unconfirmed changed meshes; no runtime assets written", result.stderr)
            self.assertEqual(xml.read_bytes(), b"EXISTING_XML_WITH_OLD_VERIFIED_IDS")
            self.assertEqual(lua.read_bytes(), b"EXISTING_LUA")
            self.assertNotIn(self.canonical[self.names[0]][0].encode(), xml.read_bytes())


if __name__ == "__main__":
    unittest.main(verbosity=2)
