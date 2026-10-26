import { exportScene, getNonDeletedElements } from "@excalidraw/excalidraw";

import type { NonDeletedExcalidrawElement } from "@excalidraw/element/types";
import type { ExcalidrawImperativeAPI } from "@excalidraw/excalidraw/types";

export type ExportFormat = "png" | "svg";
/** `auto`: the selection when there is one, else the whole board */
export type ExportScope = "auto" | "board" | "selection" | "viewport";

export type ExportRequest = {
  format: ExportFormat;
  scope: ExportScope;
  /** pixel density of a PNG */
  scale?: number;
  /** paint the canvas color behind the content (default) */
  background?: boolean;
};

export type ExportResult = {
  /** base64 of the PNG bytes or the SVG text */
  base64: string;
  mimeType: string;
  scope: Exclude<ExportScope, "auto">;
};

const EXPORT_PADDING = 16;
const MAX_SCALE = 4;

const blobToBase64 = async (blob: Blob) => {
  const buffer = new Uint8Array(await blob.arrayBuffer());
  let binary = "";
  const CHUNK = 0x8000;
  for (let i = 0; i < buffer.length; i += CHUNK) {
    binary += String.fromCharCode(...buffer.subarray(i, i + CHUNK));
  }
  return btoa(binary);
};

const resolveScope = (
  api: ExcalidrawImperativeAPI,
  scope: ExportScope,
): {
  scope: ExportResult["scope"];
  elements: readonly NonDeletedExcalidrawElement[];
} => {
  const elements = getNonDeletedElements(api.getSceneElements());
  const { selectedElementIds } = api.getAppState();
  const selected = elements.filter(
    (element) =>
      selectedElementIds[element.id] ||
      // a selected container brings its label along
      (element.type === "text" &&
        element.containerId &&
        selectedElementIds[element.containerId]),
  );
  if (scope === "selection" || (scope === "auto" && selected.length)) {
    return { scope: "selection", elements: selected };
  }
  return { scope: scope === "viewport" ? "viewport" : "board", elements };
};

/**
 * Renders the board as the canvas shows it: current theme, canvas color,
 * layer order and crops (the editor's own export pipeline).
 */
export const exportImage = async (
  api: ExcalidrawImperativeAPI,
  request: ExportRequest,
): Promise<ExportResult> => {
  const { scope, elements } = resolveScope(api, request.scope);
  if (!elements.length) {
    throw new Error(
      scope === "selection" ? "Nada selecionado" : "O quadro está vazio",
    );
  }
  const appState = api.getAppState();
  const viewport =
    scope === "viewport"
      ? {
          // the visible part of the canvas, in scene coordinates
          x: -appState.scrollX,
          y: -appState.scrollY,
          width: appState.width / appState.zoom.value,
          height: appState.height / appState.zoom.value,
          padding: 0,
        }
      : { padding: EXPORT_PADDING };
  const common = {
    data: {
      elements,
      appState: { viewBackgroundColor: appState.viewBackgroundColor },
      files: api.getFiles(),
    },
  };
  const theme = appState.theme;
  const background =
    request.background === false ? { canvasBackgroundColor: false as const } : {};

  if (request.format === "svg") {
    const svg = await exportScene({
      type: "svg",
      ...common,
      config: { ...viewport, ...background, theme },
    });
    const text = new XMLSerializer().serializeToString(svg);
    return {
      base64: await blobToBase64(new Blob([text], { type: "image/svg+xml" })),
      mimeType: "image/svg+xml",
      scope,
    };
  }

  const scale = Math.min(Math.max(request.scale ?? 2, 1), MAX_SCALE);
  const blob = await exportScene({
    type: "png",
    ...common,
    config: { ...viewport, ...background, theme, scale },
  });
  return { base64: await blobToBase64(blob), mimeType: "image/png", scope };
};
