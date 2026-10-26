import React from "react";

import {
  COLOR_PALETTE,
  DEFAULT_HIGHLIGHT_BG,
  HIGHLIGHT_BACKGROUND_PICKS,
  getFontString,
  getReadableTextColor,
  getStickyNoteFooterColor,
} from "@excalidraw/common";
import {
  getTextHighlightRects,
  isHighlightedText,
  measureText,
} from "@excalidraw/element";

import type {
  ExcalidrawTextElement,
  NonDeletedExcalidrawElement,
} from "@excalidraw/element/types";

import {
  actionChangeFontWeight,
  actionToggleTextHighlight,
} from "../actions/actionTextStyle";
import {
  getColorTargetAppStateUpdates,
  resolveColorTarget,
} from "../actions/colorTargets";
import { getDefaultAppState } from "../appState";
import { restoreElements } from "../data/restore";
import { Excalidraw } from "../index";
import { exportScene } from "../scene/export";

import { API } from "./helpers/api";
import { act, render } from "./test-utils";

import type { AppState } from "../types";

const { h } = window;

const textElement = (
  overrides: Partial<ExcalidrawTextElement> = {},
): ExcalidrawTextElement =>
  ({
    ...API.createElement({ type: "text", text: "hello" }),
    width: 100,
    fontSize: 20,
    backgroundColor: DEFAULT_HIGHLIGHT_BG,
    highlighted: true,
    ...overrides,
  } as ExcalidrawTextElement);

describe("font weight", () => {
  it("prefixes bold to the font string only when set", () => {
    const base = { fontSize: 20, fontFamily: 5 as const };
    expect(getFontString(base)).toMatch(/^20px /);
    expect(getFontString({ ...base, fontWeight: "normal" })).toMatch(/^20px /);
    expect(getFontString({ ...base, fontWeight: "bold" })).toMatch(
      /^bold 20px /,
    );
  });

  it("measures the height of bold text like regular text", () => {
    const lineHeight = 1.25 as ExcalidrawTextElement["lineHeight"];
    const regular = measureText(
      "a\nb",
      getFontString({ fontSize: 20, fontFamily: 5 }),
      lineHeight,
    );
    const bold = measureText(
      "a\nb",
      getFontString({ fontSize: 20, fontFamily: 5, fontWeight: "bold" }),
      lineHeight,
    );
    expect(bold.height).toBe(regular.height);
    expect(Number.isFinite(bold.height)).toBe(true);
  });
});

describe("text highlight geometry", () => {
  it("marks free text by default, never labels, and respects an explicit off", () => {
    expect(isHighlightedText(textElement())).toBe(true);
    expect(isHighlightedText(textElement({ highlighted: false }))).toBe(false);
    expect(
      isHighlightedText(
        textElement({ backgroundColor: COLOR_PALETTE.transparent }),
      ),
    ).toBe(true);
    expect(
      isHighlightedText(
        textElement({ containerId: "container" as ExcalidrawTextElement["id"] }),
      ),
    ).toBe(false);
  });

  it("paints one marker per non-empty line, overshooting the glyphs", () => {
    const rects = getTextHighlightRects(textElement({ text: "a\n\nb" }));
    expect(rects).toHaveLength(2);
    const [first, second] = rects;
    expect(first.x).toBeLessThan(0);
    expect(second.y).toBeGreaterThan(first.y + first.height);
    expect(first.height).toBeGreaterThan(0);
  });

  it("follows the text alignment", () => {
    const left = getTextHighlightRects(textElement({ textAlign: "left" }))[0];
    const right = getTextHighlightRects(textElement({ textAlign: "right" }))[0];
    const center = getTextHighlightRects(
      textElement({ textAlign: "center" }),
    )[0];
    expect(right.x + right.width).toBeCloseTo(100 - left.x, 5);
    expect(center.x).toBeGreaterThan(left.x);
    expect(center.x).toBeLessThan(right.x);
  });
});

describe("restore", () => {
  it("keeps weight and marker, and drops the marker from labels", () => {
    const container = API.createElement({
      type: "rectangle",
      id: "box",
      boundElements: [{ type: "text", id: "label" }],
    });
    const restored = restoreElements(
      [
        textElement({ id: "free", fontWeight: "bold" }),
        container,
        textElement({
          id: "label",
          containerId: "box" as ExcalidrawTextElement["id"],
        }),
        API.createElement({ type: "text", id: "plain" }),
      ],
      null,
    );
    const byId = (id: string) =>
      restored.find((element) => element.id === id) as ExcalidrawTextElement;
    const [free, label, plain] = [byId("free"), byId("label"), byId("plain")];
    expect(free.fontWeight).toBe("bold");
    expect(free.highlighted).toBe(true);
    expect(label.highlighted).toBeUndefined();
    expect(plain).not.toHaveProperty("fontWeight");
    expect(plain).not.toHaveProperty("highlighted");
  });
});

describe("highlight color domain", () => {
  const appState = (overrides: Partial<AppState> = {}): AppState =>
    ({
      ...getDefaultAppState(),
      selectedElementIds: {},
      editingTextElement: null,
      ...overrides,
    } as AppState);

  it("targets the marker of selected highlighted text", () => {
    const marked = textElement({ id: "marked" });
    const target = resolveColorTarget(
      appState({ selectedElementIds: { marked: true } }),
      [marked],
      "backgroundColor",
    );
    expect(target.kind).toBe("highlight");
    expect(target.topPicks).toBe(HIGHLIGHT_BACKGROUND_PICKS);
    expect(target.appStateKeys).toEqual(["currentItemHighlightColor"]);
    expect(target.excludedColors).toContain(COLOR_PALETTE.transparent);
  });

  it("follows the marker tool preset when nothing is selected", () => {
    const target = resolveColorTarget(
      appState({
        activeTool: {
          ...getDefaultAppState().activeTool,
          type: "text",
          customType: null,
        },
        currentItemTextHighlight: true,
      }),
      [],
      "backgroundColor",
    );
    expect(target.kind).toBe("highlight");
  });

  it("never stores a transparent marker", () => {
    const target = resolveColorTarget(
      appState({ selectedElementIds: { marked: true } }),
      [textElement({ id: "marked" })],
      "backgroundColor",
    );
    expect(
      getColorTargetAppStateUpdates(target, COLOR_PALETTE.transparent),
    ).toEqual({ currentItemHighlightColor: DEFAULT_HIGHLIGHT_BG });
  });
});

describe("text style actions", () => {
  beforeEach(async () => {
    await render(<Excalidraw handleKeyboardGlobally={true} />);
  });

  afterEach(async () => {
    await act(async () => {});
  });

  it("toggles the marker of the selected text without changing the preset", () => {
    const text = API.createElement({ type: "text", id: "t1", text: "hi" });
    API.setElements([text]);
    API.setSelectedElements([text]);

    act(() => {
      h.app.actionManager.executeAction(actionToggleTextHighlight, "ui", true);
    });
    const marked = h.elements[0] as ExcalidrawTextElement;
    expect(marked.highlighted).toBe(true);
    expect(marked.backgroundColor).toBe(h.state.currentItemHighlightColor);
    expect(h.state.currentItemTextHighlight).toBe(false);

    act(() => {
      h.app.actionManager.executeAction(actionToggleTextHighlight, "ui", false);
    });
    expect((h.elements[0] as ExcalidrawTextElement).highlighted).toBe(false);
  });

  it("sets the preset when nothing is selected", () => {
    act(() => {
      h.app.actionManager.executeAction(actionToggleTextHighlight, "ui", true);
    });
    expect(h.state.currentItemTextHighlight).toBe(true);
  });

  it("makes the selected text bold and remembers the weight", () => {
    const text = API.createElement({ type: "text", id: "t2", text: "hi" });
    API.setElements([text]);
    API.setSelectedElements([text]);

    act(() => {
      h.app.actionManager.executeAction(actionChangeFontWeight, "ui", "bold");
    });
    expect((h.elements[0] as ExcalidrawTextElement).fontWeight).toBe("bold");
    expect(h.state.currentItemFontWeight).toBe("bold");
  });
});

describe("svg export", () => {
  it("renders the marker behind the text and the weight", async () => {
    const svg = await exportScene({
      type: "svg",
      data: {
        elements: [
          textElement({ index: "a0", fontWeight: "bold" } as any),
        ] as NonDeletedExcalidrawElement[],
        appState: { viewBackgroundColor: "#ffffff" },
        files: {},
      },
      config: { canvasBackgroundColor: false },
    });
    const marker = svg.querySelector(`rect[fill="${DEFAULT_HIGHLIGHT_BG}"]`);
    const text = svg.querySelector("text");
    expect(marker).not.toBeNull();
    expect(text?.getAttribute("font-weight")).toBe("bold");
    // the marker comes first, so the text paints over it
    expect(
      marker!.compareDocumentPosition(text!) & Node.DOCUMENT_POSITION_FOLLOWING,
    ).toBeTruthy();
  });
});

describe("api.executeAction", () => {
  beforeEach(async () => {
    await render(<Excalidraw handleKeyboardGlobally={true} />);
  });

  it("runs registered actions by name and rejects unknown ones", () => {
    const zoom = h.state.zoom.value;
    let ran = false;
    act(() => {
      ran = h.app.api.executeAction("zoomIn");
    });
    expect(ran).toBe(true);
    expect(h.state.zoom.value).toBeGreaterThan(zoom);
    expect(h.app.api.executeAction("nope" as any)).toBe(false);
  });

  it("undoes through the history action", () => {
    API.setElements([]);
    const text = API.createElement({ type: "text", id: "t3", text: "hi" });
    API.updateScene({
      elements: [text],
      captureUpdate: "IMMEDIATELY",
    });
    act(() => {
      h.app.api.executeAction("undo");
    });
    expect(h.elements.filter((element) => !element.isDeleted)).toHaveLength(0);
  });
});

describe("text color on a marker", () => {
  it("keeps the picked color when it reads on the marker", () => {
    expect(getReadableTextColor("#ff3b30", "#ffe600")).toBe("#ff3b30");
    expect(getReadableTextColor("#007aff", "#ffe600")).toBe("#007aff");
    expect(getReadableTextColor("#af52de", "#00e5ff")).toBe("#af52de");
  });

  it("only adjusts text that nearly vanishes on its marker", () => {
    const adjusted = getReadableTextColor("#ffe600", "#ffe600");
    expect(adjusted).not.toBe("#ffe600");
  });

  it("applies a picked color to the selected text", async () => {
    await render(<Excalidraw handleKeyboardGlobally={true} />);
    const text = API.createElement({ type: "text", id: "c1", text: "hi" });
    API.setElements([text]);
    API.setSelectedElements([text]);
    act(() => {
      h.app.api.executeAction("changeStrokeColor", { color: "#ff3b30" });
    });
    expect(h.elements[0].strokeColor).toBe("#ff3b30");
  });
});

describe("sticky note footer", () => {
  it("follows the note color", () => {
    const yellow = getStickyNoteFooterColor("#ffd93d");
    const pink = getStickyNoteFooterColor("#ff6fa5");
    expect(yellow).not.toBe(pink);
    expect(yellow).not.toBe("#ffd93d");
  });
});
