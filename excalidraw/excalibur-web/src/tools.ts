import type {
  AppState,
  ExcalidrawImperativeAPI,
} from "@excalidraw/excalidraw/types";

/**
 * The tools of the native toolbar. Text and marker are the same tool: the
 * marker is a toggle on the text tool (`currentItemTextHighlight`), set by the
 * floating text controls or the `M` key.
 */
export const TOOL_IDS = [
  "selection",
  "hand",
  "image",
  "text",
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

/** The active tool as the native toolbar sees it (text stays "text"). */
export const getActiveToolId = (
  appState: Pick<AppState, "activeTool">,
): ToolId | null => {
  const { type } = appState.activeTool;
  return isToolId(type) ? type : null;
};

export const activateTool = (api: ExcalidrawImperativeAPI, tool: ToolId) => {
  // the text tool keeps its current default (marker on/off and its color)
  api.setActiveTool({
    type: tool,
  } as Parameters<ExcalidrawImperativeAPI["setActiveTool"]>[0]);
};

const isEditableTarget = (target: EventTarget | null) =>
  target instanceof HTMLElement &&
  (target.isContentEditable ||
    target.tagName === "INPUT" ||
    target.tagName === "TEXTAREA");

/**
 * Keys the editor doesn't know: `M` toggles the marker on the text tool.
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
      const highlighted = !api.getAppState().currentItemTextHighlight;
      api.updateScene({ appState: { currentItemTextHighlight: highlighted } });
      api.setActiveTool({ type: "text" });
    }
  };
  window.addEventListener("keydown", onKeyDown, { capture: true });
  return () =>
    window.removeEventListener("keydown", onKeyDown, { capture: true });
};
