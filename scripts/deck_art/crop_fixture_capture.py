"""Crop a Studio screen capture to a forced fixture root.

The Studio client places two 6x6 magenta markers 10 px outside the root's
top-left and 4 px outside its bottom-right (see the compact capture notes in
artifacts/deck-rebuild/studio/compact/README.md). This finds them, maps root px
to image px and writes the root at its own size (W x H).

usage: python crop_fixture_capture.py capture.jpg out.png W H
"""
import sys
from PIL import Image


def markers(img):
    px = img.load()
    w, h = img.size
    hits = []
    for y in range(h):
        for x in range(w):
            r, g, b = px[x, y][:3]
            if r > 200 and g < 70 and b > 200:
                hits.append((x, y))
    if not hits:
        raise SystemExit("no markers found")
    # Split into two clusters by distance to the first hit.
    first = hits[0]
    a = [p for p in hits if abs(p[0] - first[0]) < 40 and abs(p[1] - first[1]) < 40]
    b = [p for p in hits if p not in a]
    def centre(ps):
        return (sum(p[0] for p in ps) / len(ps), sum(p[1] for p in ps) / len(ps))
    ca, cb = centre(a), centre(b)
    return (ca, cb) if ca[0] < cb[0] else (cb, ca)


def main():
    src, out, W, H = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
    img = Image.open(src).convert("RGB")
    (ax, ay), (bx, by) = markers(img)
    # Marker centres in root px: (-7, -7) and (W + 7, H + 7).
    sx = (bx - ax) / (W + 14)
    sy = (by - ay) / (H + 14)
    x0, y0 = ax + 7 * sx, ay + 7 * sy
    box = (round(x0), round(y0), round(x0 + W * sx), round(y0 + H * sy))
    img.crop(box).resize((W, H), Image.LANCZOS).save(out)
    print(f"scale {sx:.3f} {sy:.3f} box {box} -> {out}")


if __name__ == "__main__":
    main()
