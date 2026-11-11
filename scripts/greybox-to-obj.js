// Converts a Studio part dump of Workspace.GardenGreybox into an OBJ + MTL underlay.
// Usage: node scripts/greybox-to-obj.js <parts.json> <out-dir>
// Units are studs (Blender: Unit System None, 1 unit = 1 stud). The OBJ is Y-up like
// Roblox, so Blender's default OBJ import (Forward -Z, Up Y) places it correctly.
// The garden is recentred on the greybox origin (Studio X = 1000), so it sits at 0,0,0.
// Labels, invisible walls and the 2000-stud sea are left out; the spawn becomes a marker.
const fs = require("fs");
const path = require("path");

const [input, outDir] = process.argv.slice(2);
if (!input || !outDir) throw new Error("usage: node scripts/greybox-to-obj.js <parts.json> <out-dir>");
const parts = JSON.parse(fs.readFileSync(input, "utf8"));
const ORIGIN = [1000, 0, 0];
const SEGMENTS = 24;

const verts = [];
const lines = ["# Egg Drop garden greybox underlay (studs, Y-up)", "mtllib garden-greybox.mtl"];
const materials = new Map();

function transform(part, x, y, z) {
	const c = part.c;
	// CFrame components: x y z R00 R01 R02 R10 R11 R12 R20 R21 R22
	return [
		c[0] - ORIGIN[0] + c[3] * x + c[4] * y + c[5] * z,
		c[1] - ORIGIN[1] + c[6] * x + c[7] * y + c[8] * z,
		c[2] - ORIGIN[2] + c[9] * x + c[10] * y + c[11] * z,
	];
}

function add(part, local) {
	const start = verts.length + 1;
	for (const [x, y, z] of local) verts.push(transform(part, x, y, z));
	return start;
}

function face(start, ...idx) {
	lines.push("f " + idx.map((i) => start + i).join(" "));
}

function box(part, sx, sy, sz) {
	const s = add(part, [
		[-sx, -sy, -sz], [sx, -sy, -sz], [sx, sy, -sz], [-sx, sy, -sz],
		[-sx, -sy, sz], [sx, -sy, sz], [sx, sy, sz], [-sx, sy, sz],
	]);
	face(s, 0, 3, 2, 1); face(s, 4, 5, 6, 7); face(s, 0, 1, 5, 4);
	face(s, 3, 7, 6, 2); face(s, 0, 4, 7, 3); face(s, 1, 2, 6, 5);
}

// Roblox WedgePart: full height at local +Z, slope down to the bottom edge at -Z.
function wedge(part, sx, sy, sz) {
	const s = add(part, [
		[-sx, -sy, -sz], [sx, -sy, -sz], [-sx, -sy, sz], [sx, -sy, sz], [-sx, sy, sz], [sx, sy, sz],
	]);
	face(s, 0, 1, 3, 2); // bottom
	face(s, 2, 3, 5, 4); // back
	face(s, 0, 4, 5, 1); // slope
	face(s, 0, 2, 4); face(s, 1, 5, 3); // sides
}

// Roblox cylinder: axis along local X, diameter = min(Y, Z).
function cylinder(part, sx, sy, sz) {
	const r = Math.min(sy, sz);
	const ring = [];
	for (const x of [-sx, sx]) for (let i = 0; i < SEGMENTS; i++) {
		const a = (i / SEGMENTS) * Math.PI * 2;
		ring.push([x, Math.cos(a) * r, Math.sin(a) * r]);
	}
	const s = add(part, ring);
	for (let i = 0; i < SEGMENTS; i++) {
		const j = (i + 1) % SEGMENTS;
		face(s, i, j, SEGMENTS + j, SEGMENTS + i);
	}
	face(s, ...[...Array(SEGMENTS).keys()].reverse());
	face(s, ...[...Array(SEGMENTS).keys()].map((i) => SEGMENTS + i));
}

function ball(part, sx, sy, sz) {
	const r = Math.min(sx, sy, sz);
	const rows = SEGMENTS / 2;
	const pts = [];
	for (let v = 0; v <= rows; v++) {
		const phi = (v / rows) * Math.PI;
		for (let u = 0; u < SEGMENTS; u++) {
			const th = (u / SEGMENTS) * Math.PI * 2;
			pts.push([Math.sin(phi) * Math.cos(th) * r, Math.cos(phi) * r, Math.sin(phi) * Math.sin(th) * r]);
		}
	}
	const s = add(part, pts);
	for (let v = 0; v < rows; v++) for (let u = 0; u < SEGMENTS; u++) {
		const a = v * SEGMENTS + u, b = v * SEGMENTS + ((u + 1) % SEGMENTS);
		face(s, a, b, b + SEGMENTS, a + SEGMENTS);
	}
}

let written = 0;
for (const part of parts) {
	const skip = part.n.startsWith("Labels.") || part.n === "Water.Sea" || (part.t >= 1 && part.n !== "GreyboxSpawn");
	if (skip) continue;
	const [sx, sy, sz] = part.s.map((v) => v / 2);
	const mat = "c_" + part.col.join("_") + (part.t > 0 && part.t < 1 ? "_glass" : "");
	materials.set(mat, part);
	lines.push(`o ${part.n.replace(/\./g, "_")}`, `usemtl ${mat}`);
	if (part.k === "Wedge") wedge(part, sx, sy, sz);
	else if (part.k === "Cylinder") cylinder(part, sx, sy, sz);
	else if (part.k === "Ball") ball(part, sx, sy, sz);
	else box(part, sx, sy, sz);
	written++;
}

// Write all vertices first, then the objects and faces (indices are global).
const vLines = verts.map(([x, y, z]) => `v ${x.toFixed(4)} ${y.toFixed(4)} ${z.toFixed(4)}`);
const header = lines.slice(0, 2);
const body = lines.slice(2);
fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, "garden-greybox.obj"), [...header, ...vLines, ...body, ""].join("\n"));

const mtl = ["# Greybox colours from Studio"];
for (const [name, part] of materials) {
	const [r, g, b] = part.col.map((v) => (v / 255).toFixed(4));
	mtl.push(`newmtl ${name}`, `Kd ${r} ${g} ${b}`, `d ${(1 - Math.min(part.t, 0.9)).toFixed(2)}`, "");
}
fs.writeFileSync(path.join(outDir, "garden-greybox.mtl"), mtl.join("\n"));
console.log(`${written} parts, ${verts.length} vertices -> ${outDir}`);
