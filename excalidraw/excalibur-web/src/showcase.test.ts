/**
 * Demo boards for the witchmymac.com screenshots (fictional content).
 * Runs only when SHOWCASE_OUT (a folder) and SHOWCASE_IMAGES (folder with
 * landing.png, app.png, palette.png and type.png) are set:
 *
 *   SHOWCASE_OUT=<home>/Library/Application\ Support/ExcaliburForms \
 *   SHOWCASE_IMAGES=<mockups> ./node_modules/.bin/vitest run excalibur-web/src/showcase.test.ts
 *
 * It writes the same layout the app's BoardStore reads (boards.json,
 * Boards/<id>/scene.excalidraw and Boards/<id>/files/<fileId>.json).
 */
import fs from "node:fs";
import path from "node:path";

import { pointFrom } from "@excalidraw/math";
import { serializeAsJSON } from "@excalidraw/excalidraw";
import { getDefaultAppState } from "@excalidraw/excalidraw/appState";
import { API } from "@excalidraw/excalidraw/tests/helpers/api";

import type { LocalPoint } from "@excalidraw/math";
import type { ExcalidrawElement } from "@excalidraw/element/types";
import type { AppState } from "@excalidraw/excalidraw/types";

const OUT = process.env.SHOWCASE_OUT;
const IMAGES = process.env.SHOWCASE_IMAGES;

const HAND = 5;
const NORMAL = 6;

const pngSize = (buffer: Buffer) => ({
  width: buffer.readUInt32BE(16),
  height: buffer.readUInt32BE(20),
});

type Built = { elements: ExcalidrawElement[]; files: Record<string, string> };

const board = () => {
  const elements: ExcalidrawElement[] = [];
  const files: Record<string, string> = {};

  const image = (name: string, x: number, y: number, width: number) => {
    const id = `demo-img-${name}`;
    const buffer = fs.readFileSync(path.join(IMAGES!, `${name}.png`));
    const size = pngSize(buffer);
    const fileId = `demo-${name}`;
    files[fileId] = `data:image/png;base64,${buffer.toString("base64")}`;
    const element = API.createElement({
      type: "image",
      id,
      x,
      y,
      width,
      height: Math.round((width * size.height) / size.width),
      fileId,
      status: "saved",
    });
    elements.push({ ...element, strokeColor: "transparent", roundness: null });
    return element;
  };

  const text = (
    value: string,
    x: number,
    y: number,
    opts: {
      size?: number;
      font?: number;
      bold?: boolean;
      marker?: string | null;
      color?: string;
      angle?: number;
      id?: string;
    } = {},
  ) => {
    const size = opts.size ?? 28;
    const lines = value.split("\n");
    const element = API.createElement({
      type: "text",
      id: opts.id,
      x,
      y,
      text: value,
      fontSize: size,
      fontFamily: opts.font ?? HAND,
      textAlign: "left",
      width: Math.max(...lines.map((line) => line.length)) * size * 0.56,
      height: lines.length * size * 1.25,
      strokeColor: opts.color ?? "#1e1e1e",
      backgroundColor: opts.marker ?? "transparent",
      angle: opts.angle ?? 0,
    });
    const extra: Record<string, unknown> = {};
    if (opts.bold) {
      extra.fontWeight = "bold";
    }
    // free text is marked unless explicitly turned off
    extra.highlighted = opts.marker !== null;
    elements.push({ ...element, ...extra } as ExcalidrawElement);
    return element;
  };

  const note = (
    value: string,
    x: number,
    y: number,
    color: string,
    opts: { size?: number; angle?: number; id?: string } = {},
  ) => {
    const side = opts.size ?? 230;
    const sticky = API.createElement({
      type: "stickynote",
      id: opts.id,
      // the note's footer shows its date
      created: Date.now() - 2 * 24 * 3600_000,
      x,
      y,
      width: side,
      height: side,
      backgroundColor: color,
      angle: opts.angle ?? 0,
    });
    const label = API.createElement({
      type: "text",
      x: x + 16,
      y: y + 16,
      text: value,
      fontSize: 26,
      fontFamily: HAND,
      textAlign: "left",
      verticalAlign: "top",
      containerId: sticky.id,
      width: side - 32,
      height: value.split("\n").length * 33,
      strokeColor: "#1e1e1e",
      angle: opts.angle ?? 0,
    });
    elements.push(
      { ...sticky, boundElements: [{ type: "text", id: label.id }] },
      label,
    );
    return sticky;
  };

  const arrow = (x: number, y: number, points: [number, number][], color = "#1e1e1e") => {
    const local = points.map(([px, py]) => pointFrom<LocalPoint>(px, py));
    elements.push(
      API.createElement({
        type: "arrow",
        x,
        y,
        width: Math.abs(points[points.length - 1][0]),
        height: Math.abs(points[points.length - 1][1]),
        points: local,
        strokeColor: color,
        strokeWidth: 2,
        roundness: { type: 2 },
        endArrowhead: "arrow",
      }),
    );
  };

  const scribble = (cx: number, cy: number, rx: number, ry: number, color: string) => {
    const points: [number, number][] = [];
    for (let step = 0; step <= 64; step++) {
      const t = (step / 60) * Math.PI * 2 - 0.4;
      const wobble = 1 + Math.sin(step * 0.9) * 0.025;
      points.push([Math.cos(t) * rx * wobble + rx, Math.sin(t) * ry * wobble + ry]);
    }
    elements.push(
      API.createElement({
        type: "freedraw",
        x: cx - rx,
        y: cy - ry,
        width: rx * 2,
        height: ry * 2,
        points: points.map(([px, py]) => pointFrom<LocalPoint>(px, py)),
        strokeColor: color,
        strokeWidth: 2,
      }),
    );
  };

  const rect = (
    x: number,
    y: number,
    width: number,
    height: number,
    stroke: string,
    fill = "transparent",
  ) => {
    elements.push(
      API.createElement({
        type: "rectangle",
        x,
        y,
        width,
        height,
        strokeColor: stroke,
        backgroundColor: fill,
        fillStyle: "solid",
        strokeWidth: 2,
        roundness: { type: 3 },
      }),
    );
  };

  return { elements, files, image, text, note, arrow, scribble, rect };
};

/** the main board: a café redesign moodboard */
const redesign = (): Built => {
  const b = board();
  b.text("Lumen Coffee · website redesign", 0, -120, {
    id: "demo-title",
    size: 44,
    bold: true,
    marker: "#ffe600",
  });
  b.text("Moodboard for the spring launch", 4, -54, {
    size: 24,
    marker: null,
    color: "#5c5f66",
    font: NORMAL,
  });
  b.image("landing", 0, 0, 720);
  b.image("app", 780, -30, 270);
  b.image("palette", 0, 500, 470);
  b.image("type", 510, 500, 380);
  // circle the call to action on the landing page
  b.scribble(84, 298, 82, 32, "#e03131");
  b.text("Make this button pop!", 40, 360, {
    size: 26,
    marker: "#ff4fd8",
    angle: -0.04,
    id: "demo-callout",
  });
  b.text("warmer orange?", 70, 790, { size: 26, marker: "#00e5ff" });
  b.note("Ask Ava for the\nfinal logo files", 1110, -20, "#ffd93d", { angle: 0.03 });
  b.note("Launch on\nMarch 14 ☕", 1110, 260, "#ff6fa5", { angle: -0.025, id: "demo-note-launch" });
  b.note("Plant app:\nreuse the cards", 1110, 540, "#5ce65c", { angle: 0.02 });
  b.arrow(1100, 640, [[0, 0], [-40, -120], [-70, -260]], "#1e1e1e");
  b.text("Serif for headlines ✓", 560, 800, { size: 26, marker: "#00e676" });
  return b;
};

/** a lighter board: weekly planning with notes and shapes */
const planning = (): Built => {
  const b = board();
  b.text("Week 12 — content plan", 0, -110, { size: 44, bold: true, marker: "#00e5ff" });
  const columns = ["To do", "Doing", "Done"];
  columns.forEach((title, index) => {
    const x = index * 330;
    b.rect(x, -30, 300, 620, "#ced4da", "transparent");
    b.text(title, x + 20, -10, { size: 30, bold: true, marker: null });
  });
  b.note("Shoot latte\nart reel", 20, 50, "#ffd93d", { angle: 0.02 });
  b.note("Newsletter:\nnew roasts", 30, 320, "#4cc3ff", { angle: -0.02 });
  b.note("Menu photos\nfor the site", 350, 50, "#ffa14a", { angle: -0.015 });
  b.note("Blog: how we\nroast on\nThursdays", 680, 50, "#5ce65c", { angle: 0.02 });
  b.text("Due Friday!", 365, 330, { size: 30, marker: "#ff4fd8", angle: -0.05 });
  return b;
};

const writeBoard = (root: string, id: string, built: Built, appState: Partial<AppState>) => {
  const folder = path.join(root, "Boards", id);
  fs.mkdirSync(path.join(folder, "files"), { recursive: true });
  const scene = serializeAsJSON(
    built.elements,
    { ...getDefaultAppState(), ...appState } as AppState,
    {},
    "local",
  );
  fs.writeFileSync(path.join(folder, "scene.excalidraw"), scene);
  for (const [fileId, dataURL] of Object.entries(built.files)) {
    fs.writeFileSync(
      path.join(folder, "files", `${fileId}.json`),
      JSON.stringify({ id: fileId, dataURL, mimeType: "image/png", created: Date.now() }),
    );
  }
};

describe.skipIf(!OUT || !IMAGES)("showcase boards", () => {
  it("writes the demo boards", () => {
    const now = new Date();
    const at = (minutesAgo: number) =>
      new Date(now.getTime() - minutesAgo * 60_000).toISOString().replace(/\.\d+Z$/, "Z");
    const boards = [
      { id: "demo-redesign", name: "Lumen redesign", minutes: 2 },
      { id: "demo-planning", name: "Content plan", minutes: 60 * 5 },
      { id: "demo-trip", name: "Lisbon trip", minutes: 60 * 26 },
      { id: "demo-ideas", name: "App ideas", minutes: 60 * 50 },
      { id: "demo-research", name: "Competitor research", minutes: 60 * 80 },
    ];
    fs.mkdirSync(OUT!, { recursive: true });
    const marker = {
      currentItemTextHighlight: true,
      currentItemHighlightColor: "#ffe600",
      currentItemFontFamily: HAND,
    } as Partial<AppState>;
    writeBoard(OUT!, "demo-redesign", redesign(), {
      ...marker,
      scrollX: 110,
      scrollY: 200,
      zoom: { value: 0.62 as any },
    });
    writeBoard(OUT!, "demo-planning", planning(), {
      ...marker,
      scrollX: 200,
      scrollY: 200,
      zoom: { value: 0.8 as any },
    });
    for (const { id } of boards.slice(2)) {
      writeBoard(OUT!, id, { elements: [], files: {} }, marker);
    }
    fs.writeFileSync(
      path.join(OUT!, "boards.json"),
      JSON.stringify(
        boards.map(({ id, name, minutes }) => ({
          id,
          name,
          createdAt: at(minutes + 600),
          updatedAt: at(minutes),
        })),
        null,
        2,
      ),
    );
  });
});
