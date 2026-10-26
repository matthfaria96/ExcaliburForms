import { vi } from "vitest";

import { getDefaultAppState } from "@excalidraw/excalidraw/appState";
import { API } from "@excalidraw/excalidraw/tests/helpers/api";

import type {
  AppState,
  BinaryFileData,
  BinaryFiles,
} from "@excalidraw/excalidraw/types";

import { createAutosave } from "./autosave";
import { parseBoardPayload, toInitialData } from "./board";
import { getActiveToolId, isToolId } from "./tools";

import type { NativeMessage } from "./bridge";

const file = (id: string): BinaryFileData =>
  ({
    id,
    dataURL: "data:image/png;base64,AAAA",
    mimeType: "image/png",
    created: 1,
  } as BinaryFileData);

const posted: NativeMessage[] = [];

beforeEach(() => {
  posted.length = 0;
  (window as any).webkit = {
    messageHandlers: {
      excalibur: { postMessage: (message: NativeMessage) => posted.push(message) },
    },
  };
  vi.useFakeTimers();
});

afterEach(() => {
  vi.useRealTimers();
  delete (window as any).webkit;
});

describe("board payload", () => {
  it("rejects a payload without an id or with a bad scene", () => {
    expect(() => parseBoardPayload(null)).toThrow();
    expect(() => parseBoardPayload({ id: "" })).toThrow();
    expect(() => parseBoardPayload({ id: "a", scene: 42 })).toThrow();
  });

  it("keeps only well-formed files", () => {
    const board = parseBoardPayload({
      id: "a",
      scene: null,
      files: [file("ok"), { id: "broken" }, "junk"],
    });
    expect(board.files.map((f) => f.id)).toEqual(["ok"]);
  });

  it("turns a saved scene into the editor's initial data", () => {
    const element = API.createElement({ type: "rectangle", id: "r" });
    const data = toInitialData({
      id: "a",
      scene: JSON.stringify({ elements: [element], appState: { zoom: 2 } }),
      files: [file("img")],
    });
    expect(data.elements).toHaveLength(1);
    expect(data.files?.img).toBeDefined();
    expect(toInitialData({ id: "b", scene: null, files: [] }).elements).toBe(
      undefined,
    );
  });
});

describe("autosave", () => {
  const snapshot = (
    elements = [API.createElement({ type: "rectangle", id: "r" })],
    files: BinaryFiles = {},
  ) => ({
    elements,
    appState: getDefaultAppState() as AppState,
    files,
  });

  it("writes once after changes settle", () => {
    const autosave = createAutosave("board", []);
    autosave.schedule(snapshot());
    autosave.schedule(snapshot());
    expect(posted).toHaveLength(0);
    vi.advanceTimersByTime(1000);
    expect(posted).toHaveLength(1);
    expect(posted[0]).toMatchObject({ type: "save", boardId: "board" });
  });

  it("skips writes when nothing changed", () => {
    const autosave = createAutosave("board", []);
    const same = snapshot();
    autosave.schedule(same);
    autosave.flush();
    autosave.schedule(same);
    autosave.flush();
    expect(posted).toHaveLength(1);
  });

  it("sends each image once, and never the stored ones", () => {
    const autosave = createAutosave("board", ["stored"]);
    const elements = [API.createElement({ type: "rectangle", id: "r" })];
    autosave.schedule(
      snapshot(elements, { stored: file("stored"), fresh: file("fresh") }),
    );
    autosave.flush();
    const first = posted[0] as Extract<NativeMessage, { type: "save" }>;
    expect(first.files.map((f) => f.id)).toEqual(["fresh"]);

    const moved = [{ ...elements[0], x: 50, version: 2 }];
    autosave.schedule(
      snapshot(moved, { stored: file("stored"), fresh: file("fresh") }),
    );
    autosave.flush();
    const second = posted[1] as Extract<NativeMessage, { type: "save" }>;
    expect(second.files).toEqual([]);
  });

  it("flushes the pending change immediately", () => {
    const autosave = createAutosave("board", []);
    autosave.schedule(snapshot());
    autosave.flush();
    expect(posted).toHaveLength(1);
    vi.advanceTimersByTime(1000);
    expect(posted).toHaveLength(1);
  });
});

describe("tools", () => {
  it("reports the text tool as a single tool regardless of the marker", () => {
    const base = getDefaultAppState();
    const text = { type: "text" as const, customType: null };
    expect(getActiveToolId({ activeTool: text })).toBe("text");
    expect(getActiveToolId({ activeTool: base.activeTool })).toBe("selection");
    expect(
      getActiveToolId({ activeTool: { type: "laser", customType: null } }),
    ).toBe(null);
  });

  it("only accepts toolbar tools", () => {
    expect(isToolId("text")).toBe(true);
    expect(isToolId("highlight")).toBe(false);
    expect(isToolId("frame")).toBe(false);
    expect(isToolId(3)).toBe(false);
  });
});
