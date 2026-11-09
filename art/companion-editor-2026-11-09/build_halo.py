"""Author the Ring mesh and neutral silhouette from one closed elliptical path."""
import hashlib
import json
import math
import struct
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

HERE = Path(__file__).resolve().parent
STUDY = HERE.parent.parent / "artifacts" / "companion-editor-2026-11-09"
U_COUNT, V_COUNT = 32, 8
RX, RY, TUBE = 0.105, 0.073, 0.0245


def ring_point(theta, phi):
    center = np.array([RX * math.cos(theta), RY * math.sin(theta), 0])
    radial = np.array([math.cos(theta) / RX, math.sin(theta) / RY, 0])
    radial /= np.linalg.norm(radial)
    normal = radial * math.cos(phi) + np.array([0, 0, math.sin(phi)])
    return center + TUBE * normal, normal


def geometry():
    positions, normals, uv, indices = [], [], [], []
    for i in range(U_COUNT + 1):
        for j in range(V_COUNT + 1):
            point, normal = ring_point(math.tau * i / U_COUNT, math.tau * j / V_COUNT)
            positions.append(point)
            normals.append(normal)
            uv.append((i / U_COUNT, j / V_COUNT))
    for i in range(U_COUNT):
        for j in range(V_COUNT):
            a = i * (V_COUNT + 1) + j
            b = a + V_COUNT + 1
            indices.extend((a, b, b + 1, a, b + 1, a + 1))
    return (np.array(positions), np.array(normals), np.array(uv), np.array(indices))


def verify_topology(positions, normals, indices):
    """Weld UV seam duplicates; every edge has one forward and one reverse user."""
    vertex_keys = [tuple(np.rint(point * 1e7).astype(int)) for point in positions]
    edges = {}
    for a, b, c in indices.reshape((-1, 3)):
        face_normal = np.cross(positions[b] - positions[a], positions[c] - positions[a])
        assert np.dot(face_normal, normals[[a, b, c]].sum(axis=0)) > 0
        for start, end in ((a, b), (b, c), (c, a)):
            first, second = vertex_keys[start], vertex_keys[end]
            edge = tuple(sorted((first, second)))
            edges.setdefault(edge, []).append(1 if first == edge[0] else -1)
    assert all(sorted(uses) == [-1, 1] for uses in edges.values())
    assert len(set(vertex_keys)) - len(edges) + len(indices) // 3 == 0


def write_glb(positions, normals, uv, indices):
    binary = bytearray()
    views, accessors = [], []

    def add(array, dtype, component, kind, target, include_bounds=False):
        binary.extend(b"\0" * (-len(binary) % 4))
        data = np.asarray(array, dtype=dtype).tobytes()
        view = {"buffer": 0, "byteOffset": len(binary), "byteLength": len(data), "target": target}
        accessor = {"bufferView": len(views), "componentType": component, "count": len(array), "type": kind}
        if include_bounds:
            accessor.update(min=array.min(axis=0).tolist(), max=array.max(axis=0).tolist())
        views.append(view)
        accessors.append(accessor)
        binary.extend(data)
        return len(accessors) - 1

    attributes = {
        "POSITION": add(positions, "<f4", 5126, "VEC3", 34962, True),
        "NORMAL": add(normals, "<f4", 5126, "VEC3", 34962),
        "TEXCOORD_0": add(uv, "<f4", 5126, "VEC2", 34962),
    }
    triangles = add(indices, "<u2", 5123, "SCALAR", 34963)
    primitive = {"attributes": attributes, "indices": triangles, "material": 0, "mode": 4}
    document = {
        "asset": {"version": "2.0", "generator": "Egg Drop original halo"},
        "scene": 0, "scenes": [{"nodes": [0]}], "nodes": [{"name": "CareHaloRing", "mesh": 0}],
        "meshes": [{"name": "CareHaloRing", "primitives": [primitive]}],
        "materials": [{"name": "SecondaryTint", "pbrMetallicRoughness": {
            "baseColorFactor": [1, 1, 1, 1], "metallicFactor": 0, "roughnessFactor": 0.32}}],
        "buffers": [{"byteLength": len(binary)}], "bufferViews": views, "accessors": accessors,
    }
    encoded = json.dumps(document, separators=(",", ":")).encode()
    encoded += b" " * (-len(encoded) % 4)
    binary.extend(b"\0" * (-len(binary) % 4))
    data = (struct.pack("<4sII", b"glTF", 2, 28 + len(encoded) + len(binary))
            + struct.pack("<I4s", len(encoded), b"JSON") + encoded
            + struct.pack("<I4s", len(binary), b"BIN\0") + binary)
    target = HERE / "care-halo-ring.glb"
    target.write_bytes(data)
    return target


def write_silhouette():
    scale = 4
    width, height = 256, 192
    alpha = Image.new("L", (width * scale, height * scale))
    draw = ImageDraw.Draw(alpha)
    pixels_per_stud = (width - 12) * scale / (2 * (RX + TUBE))
    for phi, value in ((0, 255), (math.pi, 0)):
        boundary = []
        for i in range(256):
            point, _ = ring_point(math.tau * i / 256, phi)
            boundary.append((width * scale / 2 + pixels_per_stud * point[0],
                             height * scale / 2 - pixels_per_stud * point[1]))
        draw.polygon(boundary, fill=value)
    alpha = alpha.resize((width, height), Image.Resampling.LANCZOS)
    image = Image.new("RGBA", (width, height), "white")
    image.putalpha(alpha)
    target = HERE / "care-halo-ring-mask.png"
    image.save(target)
    assert alpha.getpixel((width // 2, height // 2)) == 0 and alpha.getextrema() == (0, 255)
    return target


def render_angle(positions, normals, indices, yaw, pitch):
    width, height, scale = 400, 248, 2
    to_rad = math.radians
    c, s = math.cos(to_rad(yaw)), math.sin(to_rad(yaw))
    yaw_matrix = np.array([[c, 0, s], [0, 1, 0], [-s, 0, c]])
    c, s = math.cos(to_rad(pitch)), math.sin(to_rad(pitch))
    pitch_matrix = np.array([[1, 0, 0], [0, c, -s], [0, s, c]])
    rotation = yaw_matrix @ pitch_matrix
    points = positions @ rotation.T
    shading_normals = normals @ rotation.T
    pixel_scale = 1000 * scale
    xy = np.column_stack((width * scale / 2 + points[:, 0] * pixel_scale,
                          height * scale / 2 - points[:, 1] * pixel_scale))
    canvas = np.zeros((height * scale, width * scale, 3), dtype=np.uint8)
    canvas[:] = (217, 239, 232)
    z_buffer = np.full(canvas.shape[:2], -np.inf)
    light = np.array([-.35, .52, .77])
    light /= np.linalg.norm(light)
    half_vector = light + np.array([0, 0, 1])
    half_vector /= np.linalg.norm(half_vector)
    for ids in indices.reshape((-1, 3)):
        a, b, c = xy[ids]
        left, top = np.floor(xy[ids].min(axis=0)).astype(int)
        right, bottom = np.ceil(xy[ids].max(axis=0)).astype(int) + 1
        y, x = np.mgrid[top:bottom, left:right]
        den = (b[1] - c[1]) * (a[0] - c[0]) + (c[0] - b[0]) * (a[1] - c[1])
        if abs(den) < 1e-9:
            continue
        wa = ((b[1] - c[1]) * (x + .5 - c[0]) + (c[0] - b[0]) * (y + .5 - c[1])) / den
        wb = ((c[1] - a[1]) * (x + .5 - c[0]) + (a[0] - c[0]) * (y + .5 - c[1])) / den
        weights = np.stack((wa, wb, 1 - wa - wb), axis=-1)
        depth = weights @ points[ids, 2]
        region = np.s_[top:bottom, left:right]
        exposed = (weights.min(axis=-1) >= 0) & (depth > z_buffer[region])
        z_buffer[region][exposed] = depth[exposed]
        n = weights @ shading_normals[ids]
        n /= np.maximum(np.linalg.norm(n, axis=-1, keepdims=True), 1e-9)
        diffuse = np.maximum(0, n @ light)
        gloss = np.maximum(0, n @ half_vector) ** 22
        color = np.array([178, 187, 186]) * (.72 + .28 * diffuse[..., None]) + 58 * gloss[..., None]
        canvas[region][exposed] = np.clip(color[exposed], 0, 255)
    return Image.fromarray(canvas).resize((width, height), Image.Resampling.LANCZOS)


def write_study(positions, normals, indices):
    target = STUDY / "halo-original-geometry-study.png"
    STUDY.mkdir(parents=True, exist_ok=True)
    sheet = Image.new("RGB", (1280, 365), "#F7F7ED")
    draw = ImageDraw.Draw(sheet)
    font_path = Path("C:/Windows/Fonts/segoeui.ttf")
    font = ImageFont.truetype(str(font_path), 18) if font_path.exists() else ImageFont.load_default()
    draw.text((25, 14), "Ring  /  original model study", fill="#193F35", font=font)
    for i, (yaw, pitch, caption) in enumerate(((0, 12, "Front"), (42, 12, "Three-quarter"), (84, 12, "Near edge-on"))):
        x = 25 + i * 415
        sheet.paste(render_angle(positions, normals, indices, yaw, pitch), (x, 53))
        draw.text((x, 311), caption, fill="#193F35", font=font)
    sheet.save(target)


def main():
    positions, normals, uv, indices = geometry()
    verify_topology(positions, normals, indices)
    mesh = write_glb(positions, normals, uv, indices)
    silhouette = write_silhouette()
    write_study(positions, normals, indices)
    manifest = {
        "savedShapeId": "ring", "units": "Pet-local before visual.scale; validate imported bounds in Studio.",
        "axes": "X right, Y up, +Z front; origin at center; apply existing dock/float frame and +12deg X tilt once.",
        "sizeXYZ": np.round(np.ptp(positions, axis=0), 5).tolist(),
        "profile": {"centerlineRadiusX": RX, "centerlineRadiusY": RY, "tubeRadius": TUBE},
        "triangles": len(indices) // 3, "segments": [U_COUNT, V_COUNT],
        "topology": "Closed genus-one surface; two opposite incidences on every welded edge, winding verified.",
        "render": "One opaque smooth MeshPart; Secondary tint; preserve visibility, bob and head-relative frame.",
        "fallback": {"silhouette": silhouette.name, "planeSides": ["Front", "Back"],
                     "shape": "Single continuous alpha-cut band with clear center. Near edge-on intentionally thin.",
                     "artInset": "6 px horizontal margin inside 256x192 image. Fit visible ink to mesh XY bounds."},
        "assetHashes": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (mesh, silhouette)},
    }
    (HERE / "halo-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
