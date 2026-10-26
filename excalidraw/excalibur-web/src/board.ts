import { DEFAULT_HIGHLIGHT_BG } from "@excalidraw/common";

import type {
  BinaryFileData,
  BinaryFiles,
  ExcalidrawInitialDataState,
} from "@excalidraw/excalidraw/types";

/** A board as the native shell hands it over. */
export type BoardPayload = {
  id: string;
  /** `.excalidraw` JSON as last saved; `null` for a new board */
  scene: string | null;
  files: BinaryFileData[];
};

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === "object" && value !== null && !Array.isArray(value);

/** Validates what comes over the bridge before the editor sees it. */
export const parseBoardPayload = (value: unknown): BoardPayload => {
  if (!isRecord(value) || typeof value.id !== "string" || !value.id) {
    throw new Error("Quadro inválido: sem identificador");
  }
  if (value.scene !== null && typeof value.scene !== "string") {
    throw new Error("Quadro inválido: cena em formato inesperado");
  }
  const files = Array.isArray(value.files)
    ? value.files.filter(
        (file): file is BinaryFileData =>
          isRecord(file) &&
          typeof file.id === "string" &&
          typeof file.dataURL === "string" &&
          typeof file.mimeType === "string",
      )
    : [];
  return { id: value.id, scene: value.scene, files };
};

/**
 * The editor restores (validates and migrates) whatever it's given as
 * initial data, so a damaged scene degrades to what can be recovered.
 */
export const toInitialData = (
  board: BoardPayload,
): ExcalidrawInitialDataState => {
  const files: BinaryFiles = Object.fromEntries(
    board.files.map((file) => [file.id, file]),
  );
  if (!board.scene) {
    // new board: text starts as a highlighted marker by default
    return {
      files,
      scrollToContent: true,
      appState: {
        currentItemTextHighlight: true,
        currentItemHighlightColor: DEFAULT_HIGHLIGHT_BG,
      },
    };
  }
  const parsed = JSON.parse(board.scene) as Record<string, unknown>;
  return {
    elements: Array.isArray(parsed.elements) ? parsed.elements : [],
    appState: isRecord(parsed.appState) ? parsed.appState : {},
    files,
  } as ExcalidrawInitialDataState;
};
