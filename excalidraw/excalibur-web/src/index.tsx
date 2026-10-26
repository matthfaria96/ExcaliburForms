import { StrictMode, useEffect, useRef, useState } from "react";
import { createRoot } from "react-dom/client";

import type { ActionName } from "@excalidraw/excalidraw/actions/types";
import type { ExcalidrawImperativeAPI } from "@excalidraw/excalidraw/types";

import "./styles.css";

import { BoardEditor } from "./App";
import { parseBoardPayload } from "./board";
import { isNativeHost, postToNative, reportError } from "./bridge";
import { exportImage } from "./exporter";
import { activateTool, isToolId } from "./tools";

import type { Autosave } from "./autosave";
import type { BoardPayload } from "./board";
import type { ExportRequest, ExportResult } from "./exporter";

type Theme = "light" | "dark";

/** Commands of the native menus, run as the editor's own actions. */
const COMMANDS: Readonly<Record<string, ActionName>> = {
  undo: "undo",
  redo: "redo",
  zoomIn: "zoomIn",
  zoomOut: "zoomOut",
  resetZoom: "resetZoom",
  zoomToFit: "zoomToFit",
  zoomToSelection: "zoomToFitSelection",
  bringForward: "bringForward",
  sendBackward: "sendBackward",
  bringToFront: "bringToFront",
  sendToBack: "sendToBack",
  toggleLock: "toggleElementLock",
  unlockAll: "unlockAllElements",
  crop: "cropEditor",
  group: "group",
  ungroup: "ungroup",
  duplicate: "duplicateSelection",
  delete: "deleteSelectedElements",
  selectAll: "selectAll",
  shortcuts: "toggleShortcuts",
  toggleGrid: "gridMode",
  toggleSnap: "objectsSnapMode",
};

/** What the native shell calls (via `callAsyncJavaScript`). */
export type ExcaliburHostApi = {
  loadBoard: (payload: unknown) => void;
  /** writes pending changes now; call before switching board or quitting */
  flush: () => void;
  setTool: (tool: string) => boolean;
  setTheme: (theme: string) => void;
  /** sets the text tool's default marker (`null` turns the marker off) */
  setHighlight: (color: string | null) => void;
  command: (name: string) => boolean;
  exportImage: (request: ExportRequest) => Promise<ExportResult>;
};

declare global {
  interface Window {
    excalibur?: ExcaliburHostApi;
  }
}

const DEV_BOARD: BoardPayload = { id: "dev", scene: null, files: [] };

const Root = () => {
  const [board, setBoard] = useState<BoardPayload | null>(
    isNativeHost() ? null : DEV_BOARD,
  );
  const [theme, setTheme] = useState<Theme>(
    window.matchMedia?.("(prefers-color-scheme: dark)").matches
      ? "dark"
      : "light",
  );
  const apiRef = useRef<ExcalidrawImperativeAPI | null>(null);
  const autosaveRef = useRef<Autosave | null>(null);

  useEffect(() => {
    const requireApi = () => {
      if (!apiRef.current) {
        throw new Error("O editor ainda não está pronto");
      }
      return apiRef.current;
    };
    window.excalibur = {
      loadBoard: (payload) => {
        const next = parseBoardPayload(payload);
        autosaveRef.current?.flush();
        apiRef.current = null;
        setBoard(next);
      },
      flush: () => autosaveRef.current?.flush(),
      setTool: (tool) => {
        if (!isToolId(tool) || !apiRef.current) {
          return false;
        }
        activateTool(apiRef.current, tool);
        return true;
      },
      setTheme: (next) => setTheme(next === "dark" ? "dark" : "light"),
      setHighlight: (color) => {
        requireApi().updateScene({
          appState: {
            currentItemTextHighlight: color !== null,
            ...(color !== null ? { currentItemHighlightColor: color } : {}),
          },
        });
      },
      command: (name) => {
        const action = COMMANDS[name];
        return !!action && requireApi().executeAction(action);
      },
      exportImage: (request) => exportImage(requireApi(), request),
    };
    postToNative({ type: "ready" });
    // a page being torn down (reload, quit) still writes its last changes
    const onHide = () => autosaveRef.current?.flush();
    window.addEventListener("pagehide", onHide);
    return () => {
      window.removeEventListener("pagehide", onHide);
      delete window.excalibur;
    };
  }, []);

  if (!board) {
    return null;
  }
  return (
    <BoardEditor
      key={board.id}
      board={board}
      theme={theme}
      onApi={(api, autosave) => {
        apiRef.current = api;
        autosaveRef.current = autosave;
      }}
    />
  );
};

window.addEventListener("error", (event) =>
  reportError("Erro no editor", event.error ?? event.message),
);
window.addEventListener("unhandledrejection", (event) =>
  reportError("Erro no editor", event.reason),
);

createRoot(document.getElementById("root")!).render(
  <StrictMode>
    <Root />
  </StrictMode>,
);
