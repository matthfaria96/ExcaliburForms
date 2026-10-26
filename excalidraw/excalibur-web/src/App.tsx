import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { Excalidraw, getStrokeWidthByKey } from "@excalidraw/excalidraw";
import {
  DEFAULT_HIGHLIGHT_BG,
  STROKE_WIDTH_KEYS,
  isTransparent,
} from "@excalidraw/common";
import { isHighlightedText } from "@excalidraw/element";

import type {
  AppState,
  ExcalidrawImperativeAPI,
  ExcalidrawInitialDataState,
  UIOptions,
} from "@excalidraw/excalidraw/types";
import type {
  ExcalidrawElement,
  ExcalidrawTextElement,
} from "@excalidraw/element/types";

import { createAutosave } from "./autosave";
import { postToNative, reportError } from "./bridge";
import { getActiveToolId, installToolShortcuts } from "./tools";

import { toInitialData } from "./board";

import type { Autosave } from "./autosave";
import type { BoardPayload } from "./board";

const UI_OPTIONS: Partial<UIOptions> = {
  // the native window brings the toolbar, menus and board list
  minimalUI: true,
  canvasActions: {
    changeViewBackgroundColor: false,
    clearCanvas: false,
    export: false,
    loadScene: false,
    saveToActiveFile: false,
    saveAsImage: false,
    toggleTheme: false,
  },
  tools: { image: true },
};

const DOT_GRID_UI_OPTIONS: Partial<UIOptions> = { ...UI_OPTIONS, dotGrid: true };

type Props = {
  board: BoardPayload;
  theme: "light" | "dark";
  /** whiteboard dots on the canvas (Ajustes › Geral) */
  dotGrid: boolean;
  onApi: (api: ExcalidrawImperativeAPI | null, autosave: Autosave) => void;
};

/** the text element under the selection, if any (drives the native panel) */
const selectedText = (
  appState: AppState,
  elements: readonly ExcalidrawElement[],
): {
  fontSize: number;
  fontWeight: "normal" | "bold";
  textAlign: "left" | "center" | "right";
  highlighted: boolean;
  backgroundColor: string;
  strokeColor: string;
  fontFamily: number;
} | null => {
  const selected = elements.find(
    (element) =>
      appState.selectedElementIds[element.id] &&
      !element.isDeleted &&
      element.type === "text",
  ) as ExcalidrawTextElement | undefined;
  if (!selected) {
    return null;
  }
  return {
    fontSize: selected.fontSize,
    fontWeight: selected.fontWeight ?? "normal",
    textAlign: selected.textAlign as "left" | "center" | "right",
    // free text is marked unless explicitly turned off (see isHighlightedText)
    highlighted: isHighlightedText(selected),
    // what the canvas paints: a transparent marker falls back to the default
    backgroundColor: isTransparent(selected.backgroundColor)
      ? DEFAULT_HIGHLIGHT_BG
      : selected.backgroundColor,
    strokeColor: selected.strokeColor,
    fontFamily: selected.fontFamily,
  };
};

/** a human label for the layers panel */
const layerLabel = (element: ExcalidrawElement): string => {
  switch (element.type) {
    case "text":
      return element.text?.trim().slice(0, 30) || "Texto";
    case "image":
      return "Imagem";
    case "rectangle":
      return "Retângulo";
    case "ellipse":
      return "Elipse";
    case "diamond":
      return "Losango";
    case "arrow":
      return "Seta";
    case "line":
      return "Linha";
    case "freedraw":
      return "Desenho";
    case "stickynote":
      return "Nota";
    case "frame":
      return "Frame";
    case "embeddable":
      return "Embed";
    default:
      return element.type;
  }
};

/** the sticky note under the selection, if any (drives the native panel) */
const selectedSticky = (
  appState: AppState,
  elements: readonly ExcalidrawElement[],
): { backgroundColor: string; fontSize: number; fontFamily: number } | null => {
  const note = elements.find(
    (element) =>
      appState.selectedElementIds[element.id] &&
      !element.isDeleted &&
      element.type === "stickynote",
  );
  if (!note) {
    return null;
  }
  const label = elements.find(
    (element) =>
      element.type === "text" &&
      element.containerId === note.id &&
      !element.isDeleted,
  ) as ExcalidrawTextElement | undefined;
  return {
    backgroundColor: note.backgroundColor,
    fontSize: label?.fontSize ?? 20,
    fontFamily: label?.fontFamily ?? appState.currentItemFontFamily,
  };
};

const SHAPE_TYPES = new Set([
  "rectangle",
  "ellipse",
  "diamond",
  "arrow",
  "line",
  "freedraw",
]);
const FILLABLE_TYPES = new Set(["rectangle", "ellipse", "diamond", "line"]);

/** the stroke-width key whose width this element uses */
const strokeWidthKey = (element: ExcalidrawElement) =>
  STROKE_WIDTH_KEYS.find(
    (key) => getStrokeWidthByKey(element.type, key) === element.strokeWidth,
  ) ?? null;

/**
 * Style of the selected shapes, arrows and drawings (or, with none selected,
 * of the active shape tool's defaults) for the native inspector.
 */
const selectedShape = (
  appState: AppState,
  elements: readonly ExcalidrawElement[],
) => {
  const selected = elements.filter(
    (element) =>
      appState.selectedElementIds[element.id] &&
      !element.isDeleted &&
      SHAPE_TYPES.has(element.type),
  );
  const toolType = appState.activeTool.type;
  if (!selected.length && !SHAPE_TYPES.has(toolType)) {
    return null;
  }
  const first = selected[0];
  return {
    strokeColor: first?.strokeColor ?? appState.currentItemStrokeColor,
    backgroundColor:
      first?.backgroundColor ?? appState.currentItemBackgroundColor,
    strokeWidth: first ? strokeWidthKey(first) : appState.currentItemStrokeWidthKey,
    fillStyle: first?.fillStyle ?? appState.currentItemFillStyle,
    strokeStyle: first?.strokeStyle ?? appState.currentItemStrokeStyle,
    fillable: first
      ? selected.some((element) => FILLABLE_TYPES.has(element.type))
      : FILLABLE_TYPES.has(toolType),
  };
};

/** state the native toolbar mirrors; posted only when it changes */
const toNativeState = (
  appState: AppState,
  elements: readonly ExcalidrawElement[],
) => ({
  tool: getActiveToolId(appState),
  hasSelection: Object.keys(appState.selectedElementIds).length > 0,
  theme: appState.theme,
  strokeColor: appState.currentItemStrokeColor,
  fontFamily: appState.currentItemFontFamily,
  highlightColor: appState.currentItemTextHighlight
    ? appState.currentItemHighlightColor
    : null,
  text: selectedText(appState, elements),
  sticky: selectedSticky(appState, elements),
  shape: selectedShape(appState, elements),
  selectionTypes: [
    ...new Set(
      elements
        .filter(
          (element) =>
            appState.selectedElementIds[element.id] && !element.isDeleted,
        )
        .map((element) => element.type),
    ),
  ],
  locked: elements.some(
    (element) =>
      appState.selectedElementIds[element.id] &&
      !element.isDeleted &&
      element.locked,
  ),
  layers: elements
    .filter((element) => !element.isDeleted)
    .map((element) => ({
      id: element.id,
      label: layerLabel(element),
      type: element.type,
      selected: !!appState.selectedElementIds[element.id],
    }))
    .reverse(),
});

export const BoardEditor = ({ board, theme, dotGrid, onApi }: Props) => {
  const apiRef = useRef<ExcalidrawImperativeAPI | null>(null);
  const autosave = useMemo(
    () => createAutosave(board.id, board.files.map((file) => file.id)),
    [board],
  );
  const lastNativeState = useRef("");
  const [initialData] = useState<ExcalidrawInitialDataState>(() =>
    toInitialData(board),
  );

  useEffect(() => installToolShortcuts(() => apiRef.current), []);
  // leaving the board (switch, reload) writes what's pending
  useEffect(() => () => autosave.flush(), [autosave]);

  const onChange = useCallback(
    (...[elements, appState, files]: Parameters<
      NonNullable<React.ComponentProps<typeof Excalidraw>["onChange"]>
    >) => {
      autosave.schedule({ elements, appState, files });
      const nativeState = toNativeState(appState, elements);
      const key = JSON.stringify(nativeState);
      if (key !== lastNativeState.current) {
        lastNativeState.current = key;
        postToNative({ type: "state", ...nativeState });
      }
    },
    [autosave],
  );

  return (
    <Excalidraw
      key={board.id}
      initialData={initialData}
      theme={theme}
      langCode="pt-BR"
      UIOptions={dotGrid ? DOT_GRID_UI_OPTIONS : UI_OPTIONS}
      handleKeyboardGlobally={true}
      autoFocus={true}
      onExcalidrawAPI={(api) => {
        apiRef.current = api;
        onApi(api, autosave);
      }}
      onInitialize={(api) => {
        try {
          autosave.markLoaded({
            elements: api.getSceneElementsIncludingDeleted(),
            appState: api.getAppState(),
            files: api.getFiles(),
          });
        } catch (error) {
          reportError("Falha ao abrir o quadro", error);
        }
      }}
      onChange={onChange}
    />
  );
};
