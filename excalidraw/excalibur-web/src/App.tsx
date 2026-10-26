import { useCallback, useEffect, useMemo, useRef, useState } from "react";

import { Excalidraw } from "@excalidraw/excalidraw";

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

type Props = {
  board: BoardPayload;
  theme: "light" | "dark";
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
    textAlign: selected.textAlign,
    highlighted: selected.highlighted === true,
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
  highlightColor: appState.currentItemTextHighlight
    ? appState.currentItemHighlightColor
    : null,
  text: selectedText(appState, elements),
});

export const BoardEditor = ({ board, theme, onApi }: Props) => {
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
      UIOptions={UI_OPTIONS}
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
