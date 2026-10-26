import type { BinaryFileData } from "@excalidraw/excalidraw/types";

import type { ToolId } from "./tools";

/** Messages the page sends to the native shell (`window.webkit…excalibur`). */
export type NativeMessage =
  | { type: "ready" }
  | {
      type: "save";
      boardId: string;
      /** `.excalidraw` JSON without files (they go once, in `files`) */
      scene: string;
      files: BinaryFileData[];
    }
  | {
      type: "state";
      tool: ToolId | null;
      hasSelection: boolean;
      theme: "light" | "dark";
      /** the text tool's default text color */
      strokeColor: string;
      /** zoom factor (1 = 100%) */
      zoom: number;
      /** the text and note tools' default font family */
      fontFamily: number;
      /** the text tool's default marker color; `null` when the marker is off */
      highlightColor: string | null;
      /** the selected text element's properties, if a text is selected */
      text: {
        fontSize: number;
        fontWeight: "normal" | "bold";
        textAlign: "left" | "center" | "right";
        highlighted: boolean;
        backgroundColor: string;
        strokeColor: string;
        fontFamily: number;
      } | null;
      /** every visible element, front-most first */
      layers: {
        id: string;
        label: string;
        type: string;
        selected: boolean;
      }[];
      /** the selected sticky note's properties, if a note is selected */
      sticky: {
        backgroundColor: string;
        fontSize: number;
        fontFamily: number;
      } | null;
      /** style of the selected shapes/arrows/drawings or the shape tool */
      shape: {
        strokeColor: string;
        backgroundColor: string;
        strokeWidth: "thin" | "medium" | "bold" | null;
        fillStyle: string;
        strokeStyle: string;
        fillable: boolean;
      } | null;
      /** element types in the selection */
      selectionTypes: string[];
      /** whether a selected element is locked */
      locked: boolean;
    }
  | { type: "error"; message: string };

type WebKitBridge = {
  messageHandlers?: {
    excalibur?: { postMessage: (message: NativeMessage) => void };
  };
};

const getHandler = () =>
  (window as unknown as { webkit?: WebKitBridge }).webkit?.messageHandlers
    ?.excalibur ?? null;

/** Whether the page runs inside the app (and not in a dev browser tab). */
export const isNativeHost = () => getHandler() !== null;

export const postToNative = (message: NativeMessage) => {
  const handler = getHandler();
  if (handler) {
    handler.postMessage(message);
  } else if (import.meta.env.DEV) {
    // dev browser tab: show what the shell would receive
    console.debug("[excalibur → native]", message.type, message);
  }
};

export const reportError = (context: string, error: unknown) => {
  const detail = error instanceof Error ? error.message : String(error);
  postToNative({ type: "error", message: `${context}: ${detail}` });
};
