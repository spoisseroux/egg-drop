"""Shared data for the 3D egg set: geometry constants and the per-type look.

Pure data, no imports beyond math, so both Blender's Python (scripts/build_egg_models.py,
scripts/render_egg_previews.py) and system Python (scripts/build_egg_textures.py,
scripts/compose_egg_previews.py) can import it.

Type ids and palettes follow src/client/EggArt.lua (companion, toy, material, hue, feature).
"""
import math

# ---- egg geometry (Blender units = studs; up +Z, front -Y; base centre at the origin) ----
HEIGHT = 1.30
WIDTH = 1.00
SEGMENTS = 24            # columns round the egg; two per crack tooth
TEETH = 12               # same twelve-tooth seam as the 2D shells
SEAM_T = 0.551           # profile parameter of the seam centre line (about 58% of the height)
SEAM_AMP_T = 0.035       # zig-zag half height, in profile parameter
SHELL_THICKNESS = 0.035
TOP_ROWS = [0.62, 0.68, 0.74, 0.80, 0.86, 0.91, 0.96]          # outer rings above the seam (then the pole)
BOTTOM_ROWS = [0.48, 0.41, 0.34, 0.27, 0.20, 0.14, 0.09, 0.045]  # outer rings below the seam (then the pole)
TOP_INNER_ROWS = [0.71, 0.86]
BOTTOM_INNER_ROWS = [0.36, 0.19]
CORE_RADIUS = 0.40
CORE_CENTER_Z = 0.70

# ---- UV layout (Blender convention, v = 0 at the bottom of the image) ----
UV_OUTER_V0 = 0.08       # outer shell uses v in [0.08, 1]; v maps linearly to the profile parameter
UV_INNER_V = (0.02, 0.05)  # inside of the shell: pole .. seam
UV_RIM_V = 0.062         # the cut edge of the shell
FRONT_U = 0.5            # u = 0.5 faces the front (-Y in Blender, the camera in the previews)

_K = 0.20                # how much fatter the bottom is than the top


def _raw_r(t):
    p = math.pi * t
    return math.sin(p) * (1.0 + _K * math.cos(p))


_RMAX = max(_raw_r(i / 2000.0) for i in range(2001))


def profile(t):
    """(radius, z) of the outer shell at profile parameter t (0 = bottom pole, 1 = top pole)."""
    return (WIDTH / 2) * _raw_r(t) / _RMAX, (HEIGHT / 2) * (1.0 - math.cos(math.pi * t))


def profile_normal(t):
    """Outward (radial, z) unit normal of the profile at t."""
    e = 1e-4
    r0, z0 = profile(max(t - e, 0.0))
    r1, z1 = profile(min(t + e, 1.0))
    dr, dz = r1 - r0, z1 - z0
    n = math.hypot(dr, dz)
    return dz / n, -dr / n


def direction(u):
    """Unit (x, y) for texture coordinate u; u = FRONT_U points at -Y."""
    a = 2 * math.pi * (u - FRONT_U)
    return math.sin(a), -math.cos(a)


def seam_t(u):
    """Profile parameter of the zig-zag seam at u (triangle wave, TEETH teeth)."""
    ph = (u * TEETH) % 1.0
    return SEAM_T + SEAM_AMP_T * (1.0 - 2.0 * abs(ph * 2.0 - 1.0)) * -1.0


# ---- per-type look. Colours are sRGB hex. ----
TYPES = {
    "companion": {
        "name": "Companion Egg",
        "look": "warm cream shell, big royal-blue polka dots, one lime ribbon round the belly",
        "base": "#FFF0B0", "deep": "#F2C766", "light": "#FFFBE6",
        "accents": ["#3355DA", "#A8C922"],
        "inner": "#FFF7D6",
        "core": "#FFE58A", "bloom": "#FFD86B",
        "particles": ["#FFFFFF", "#FFE58A", "#7C9BFF"],
        "roughness": 0.30,
    },
    "toy": {
        "name": "Toy Egg",
        "look": "sunny yellow toy plastic, two bouncing teal wave stripes, coral and white dots",
        "base": "#FFC94A", "deep": "#F09A1E", "light": "#FFE9A6",
        "accents": ["#1F6F8C", "#F16F65", "#FFFFFF"],
        "inner": "#FFE9B8",
        "core": "#FFB340", "bloom": "#FF9F2E",
        "particles": ["#FFFFFF", "#FFD45C", "#F16F65", "#49C7E0"],
        "roughness": 0.26,
    },
    "material": {
        "name": "Material Egg",
        "look": "polished lavender marble with teal and blue veins and a pearly sheen",
        "base": "#DCD0EF", "deep": "#A893D6", "light": "#F7F2FF",
        "accents": ["#21B6AD", "#527BDC"],
        "inner": "#EFE8FA",
        "core": "#8FF0E4", "bloom": "#6FDCD2",
        "particles": ["#FFFFFF", "#BFF7F0", "#C8B8F5"],
        "roughness": 0.18,
    },
    "hue": {
        "name": "Hue Egg",
        "look": "candy rainbow swirl: pink, yellow, teal, blue and violet ribbons spiralling up the shell",
        "base": "#56D4DD", "deep": "#1C9FB5", "light": "#C9F6F8",
        "accents": ["#FF327A", "#FFCC00", "#56D4DD", "#008DFF", "#9350FF"],
        "inner": "#E3FAFB",
        "core": "#FF7AB8", "bloom": "#FF5FA8",
        "particles": ["#FFFFFF", "#FF7AB8", "#FFDD4A", "#5FD0FF", "#B58BFF"],
        "roughness": 0.26,
    },
    "feature": {
        "name": "Feature Egg",
        "look": "deep plum night-sky shell fading to lavender, mint and white four-point stars, fine glitter",
        "base": "#6E3F8C", "deep": "#3F2259", "light": "#C9A8E8",
        "accents": ["#88D7BD", "#FFFFFF", "#DCD0EF"],
        "inner": "#E9DDF5",
        "core": "#9CFFDD", "bloom": "#74E8C4",
        "particles": ["#FFFFFF", "#9CFFDD", "#E3C8FF"],
        "roughness": 0.24,
    },
}
ORDER = ["companion", "toy", "material", "hue", "feature"]

# ---- the Star token ----
STAR = {
    "outerRadius": 0.62, "innerRadius": 0.315, "tipFillet": 0.075, "valleyFillet": 0.05,
    "rings": [(1.0, 0.075), (0.955, 0.135), (0.84, 0.18), (0.48, 0.21)],  # (outline scale, half depth)
    "apexDepth": 0.225,
    "uvSpan": 1.36,   # texture square covers this many studs
    "paintScale": 0.955,  # painted facets end here; beyond is the amber edge
    "light": "#FFE9A0", "gold": "#FFD069", "mid": "#FFB93A", "deep": "#F0941A", "edge": "#B8650C",
    "roughness": 0.25,
}
