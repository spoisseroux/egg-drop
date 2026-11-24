"""Offline tests for scripts/nest_landmark_assets.py: the gate refuses what it should, and a template generated from a
stand-in readback builds with Rojo (PrimaryPart Ref, PivotOffset, the cylinder Collider, the moon's emissive mask) with
the pivot arithmetic right. Run: python scripts/nest_landmark_assets_test.py
"""
import json
import math
import subprocess
import sys
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import nest_landmark_assets as gate  # noqa: E402

ROOT = Path(__file__).resolve().parents[1]


def manifest():
    return json.loads(gate.MANIFEST.read_text())


def readback(m, scale=11.0):
    parts = [{"name": p["name"], "meshId": f"rbxassetid://{1000 + i}", "meshSize": [v * scale for v in p["size"]]}
             for i, p in enumerate(m["parts"])]
    return {"assetId": "123", "operationId": "op", "moderation": "Approved", "fbxSha256": "f", "manifestSha256": "m",
            "parts": parts}


class Ids:
    def __enter__(self):
        self.saved = gate.TEXTURE, gate.ROUGH, gate.EMISSIVE
        gate.TEXTURE, gate.ROUGH, gate.EMISSIVE = "rbxassetid://11", "rbxassetid://12", "rbxassetid://13"

    def __exit__(self, *a):
        gate.TEXTURE, gate.ROUGH, gate.EMISSIVE = self.saved


class Gate(unittest.TestCase):
    def test_refusals(self):
        m = manifest()
        with Ids():
            gate.validate(m, readback(m), "f", "m")
            for key, value in (("moderation", "Pending"), ("assetId", "x"), ("fbxSha256", "other")):
                rb = readback(m)
                rb[key] = value
                self.assertRaises(gate.GateError, gate.validate, m, rb, "f", "m")
            rb = readback(m)
            rb["parts"][1]["meshSize"] = [v * 1.01 for v in rb["parts"][1]["meshSize"]]
            self.assertRaises(gate.GateError, gate.validate, m, rb, "f", "m")      # not one import scale
            rb = readback(m)
            rb["parts"][1]["meshId"] = rb["parts"][0]["meshId"]
            self.assertRaises(gate.GateError, gate.validate, m, rb, "f", "m")      # repeated id
            rb = readback(m)
            rb["parts"].pop()
            self.assertRaises(gate.GateError, gate.validate, m, rb, "f", "m")      # missing part
        saved = gate.TEXTURE
        gate.TEXTURE = "rbxassetid://0"
        try:
            self.assertRaises(gate.GateError, gate.validate, m, readback(m), "f", "m")  # an id not set
        finally:
            gate.TEXTURE = saved

    def test_template_builds_with_rojo_and_pivots_at_the_origin(self):
        m = manifest()
        with Ids():
            bound = gate.validate(m, readback(m), "f", "m")
            xml = gate.rbxmx(m, bound)
            code = gate.lua(m, readback(m))
        root = ET.fromstring(xml)
        model = root.find("Item")
        items = {i.find("Properties/string[@name='Name']").text: i for i in model.findall("Item")}
        self.assertEqual(set(items), set(gate.NAMES.values()) | {"Collider", "LandmarkVersion"})
        self.assertEqual(model.find("Properties/Ref[@name='PrimaryPart']").text, items["Collider"].attrib["referent"])
        # CFrame * PivotOffset = identity for the collider
        def cf(node):
            v = [float(node.find(k).text) for k in ("X", "Y", "Z", "R00", "R01", "R02", "R10", "R11", "R12", "R20", "R21", "R22")]
            return v[:3], [v[3:6], v[6:9], v[9:12]]
        p, r = cf(items["Collider"].find("Properties/CoordinateFrame[@name='CFrame']"))
        q, s = cf(items["Collider"].find("Properties/CoordinateFrame[@name='PivotOffset']"))
        rot = [[sum(r[i][k] * s[k][j] for k in range(3)) for j in range(3)] for i in range(3)]
        pos = [p[i] + sum(r[i][k] * q[k] for k in range(3)) for i in range(3)]
        for i in range(3):
            self.assertAlmostEqual(pos[i], 0.0)
            for j in range(3):
                self.assertAlmostEqual(rot[i][j], 1.0 if i == j else 0.0)
        # the cylinder's axis (local X) is up and it is radius 2.4, 2.75 high
        self.assertEqual([round(x, 6) for x in (r[0][0], r[1][0], r[2][0])], [0.0, 1.0, 0.0])
        size = items["Collider"].find("Properties/Vector3[@name='size']")
        self.assertEqual([float(size.find(k).text) for k in "XYZ"], [2.75, 4.8, 4.8])
        # only the moon glows; the draped and slipped blankets start hidden; nothing but the collider collides
        for name, item in items.items():
            props = item.find("Properties")
            if item.attrib["class"] == "MeshPart":
                self.assertEqual(props.find("bool[@name='CanCollide']").text, "false")
                sa = item.find("Item[@class='SurfaceAppearance']/Properties")
                self.assertEqual(sa.find("Content[@name='EmissiveMaskContent']") is not None, name == "Moon")
                hidden = float(props.find("float[@name='Transparency']").text) == 1.0
                self.assertEqual(hidden, name in gate.HIDDEN)
        self.assertIn("\"version\":1", code)
        # Rojo takes it (PrimaryPart Ref, PivotOffset, shape, the emissive mask)
        with tempfile.TemporaryDirectory() as tmp:
            (Path(tmp) / "NestLandmark.rbxmx").write_text(xml, encoding="utf-8")
            (Path(tmp) / "t.project.json").write_text(json.dumps({"name": "T", "tree": {"$path": "NestLandmark.rbxmx"}}))
            done = subprocess.run(["rojo", "build", str(Path(tmp) / "t.project.json"), "-o", str(Path(tmp) / "out.rbxm")],
                                  cwd=ROOT, capture_output=True, text=True)
            self.assertEqual(done.returncode, 0, done.stdout + done.stderr)

    def test_manifest_contract(self):
        m = manifest()
        self.assertEqual(m["front"], [0, 0, -1])
        for key in ("Awning", "Moon", "BlanketDraped", "BlanketSlipped", "BlanketFolded"):
            self.assertIn("at", m["pivots"][key])
        axis = m["pivots"]["Awning"]["axis"]
        self.assertAlmostEqual(math.hypot(*axis), 1.0, places=3)
        self.assertAlmostEqual(axis[1], 0.0)
        self.assertLessEqual(m["triangles"]["all"], m["triangles"]["cap"])
        self.assertLessEqual(m["bounds"]["y"][1], 6.6 + 1e-6)
        self.assertEqual(m["egg"]["base"], 2.15)


if __name__ == "__main__":
    unittest.main()
