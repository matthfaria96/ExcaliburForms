import type {
  AppState,
  ExcalidrawImperativeAPI,
  ToolType,
} from "@excalidraw/excalidraw/types";

/**
 * The tools of the native toolbar. Each maps to an editor tool; the marker
 * is the text tool with the highlight preset on.
 */
export const TOOL_IDS = [
  "selection",
  "hand",
  "image",
  "text",
  "highlight",
  "stickynote",
  "rectangle",
  "ellipse",
  "diamond",
  "arrow",
  "line",
  "freedraw",
  "eraser",
] as const;

export type ToolId = typeof TOOL_IDS[number];

export const isToolId = (value: unknown): value is ToolId =>
  typeof value === "string" && (TOOL_IDS as readonly string[]).includes(value);

const toEditorTool = (tool: ToolId): ToolType =>
  tool === "highlight" ? "text" : tool;

/** The toolbar tool that the editor state shows as active. */
export const getActiveToolId = (
  appState: Pick<AppState, "activeTool" | "currentItemTextHighlight">,
): ToolId | null => {
  const { type } = appState.activeTool;
  if (type === "text") {
    return appState.currentItemTextHighlight ? "highlight" : "text";
  }
  return isToolId(type) ? type : null;
};

export const activateTool = (api: ExcalidrawImperativeAPI, tool: ToolId) => {
  // the text tools differ only by the marker preset, set before switching so
  // the properties panel opens with the right controls
  if (tool === "text" || tool === "highlight") {
    api.updateScene({
      appState: { currentItemTextHighlight: tool === "highlight" },
    });
  }
  api.setActiveTool({ type: toEditorTool(tool) } as Parameters<
    ExcalidrawImperativeAPI["setActiveTool"]
  >[0]);
};

const isEditableTarget = (target: EventTarget | null) =>
  target instanceof HTMLElement &&
  (target.isContentEditable ||
    target.tagName === "INPUT" ||
    target.tagName === "TEXTAREA");

/**
 * Keys the editor doesn't know: `M` picks the marker, and the editor's own
 * text keys (`T`, `8`) pick plain text — otherwise they'd keep the marker
 * preset of the last use.
 */
export const installToolShortcuts = (
  getApi: () => ExcalidrawImperativeAPI | null,
) => {
  const onKeyDown = (event: KeyboardEvent) => {
    const api = getApi();
    if (
      !api ||
      event.metaKey ||
      event.ctrlKey ||
      event.altKey ||
      isEditableTarget(event.target)
    ) {
      return;
    }
    const key = event.key.toLowerCase();
    if (key === "m") {
      event.preventDefault();
      event.stopPropagation();
      activateTool(api, "highlight");
    } else if (key === "t" || key === "8") {
      api.updateScene({ appState: { currentItemTextHighlight: false } });
    }
  };
  window.addEventListener("keydown", onKeyDown, { capture: true });
  return () =>
    window.removeEventListener("keydown", onKeyDown, { capture: true });
};
