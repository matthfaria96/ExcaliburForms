import { clearAppStateForLocalStorage } from "@excalidraw/excalidraw/appState";
import { serializeAsJSON } from "@excalidraw/excalidraw";

import type { ExcalidrawElement } from "@excalidraw/element/types";
import type {
  AppState,
  BinaryFileData,
  BinaryFiles,
} from "@excalidraw/excalidraw/types";

import { postToNative, reportError } from "./bridge";

/** quiet time after the last change before writing */
const SAVE_DELAY_MS = 400;

type Snapshot = {
  elements: readonly ExcalidrawElement[];
  appState: AppState;
  files: BinaryFiles;
};

/**
 * Saves one board: the scene (elements, view position, styles) as
 * `.excalidraw` JSON whenever it changes, and each image file once — images
 * are by far the biggest part of a board and never change after insertion.
 */
export const createAutosave = (
  boardId: string,
  storedFileIds: Iterable<string>,
) => {
  const sentFileIds = new Set<string>(storedFileIds);
  let lastScene: string | null = null;
  let pending: Snapshot | null = null;
  let timer: ReturnType<typeof setTimeout> | null = null;

  const write = (snapshot: Snapshot) => {
    // the scene keeps the view (scroll, zoom) and the current styles, so a
    // board reopens as it was left
    const scene = serializeAsJSON(
      snapshot.elements,
      clearAppStateForLocalStorage(snapshot.appState),
      {},
      "local",
    );
    const newFiles: BinaryFileData[] = Object.values(snapshot.files).filter(
      (file) => !sentFileIds.has(file.id),
    );
    if (scene === lastScene && !newFiles.length) {
      return;
    }
    postToNative({ type: "save", boardId, scene, files: newFiles });
    lastScene = scene;
    newFiles.forEach((file) => sentFileIds.add(file.id));
  };

  const flush = () => {
    if (timer) {
      clearTimeout(timer);
      timer = null;
    }
    if (!pending) {
      return;
    }
    const snapshot = pending;
    pending = null;
    try {
      write(snapshot);
    } catch (error) {
      reportError("Falha ao salvar o quadro", error);
    }
  };

  return {
    /** the first scene the editor reports is the one just loaded */
    markLoaded: (snapshot: Snapshot) => {
      lastScene = serializeAsJSON(
        snapshot.elements,
        clearAppStateForLocalStorage(snapshot.appState),
        {},
        "local",
      );
    },
    schedule: (snapshot: Snapshot) => {
      pending = snapshot;
      if (timer) {
        clearTimeout(timer);
      }
      timer = setTimeout(flush, SAVE_DELAY_MS);
    },
    flush,
  };
};

export type Autosave = ReturnType<typeof createAutosave>;
