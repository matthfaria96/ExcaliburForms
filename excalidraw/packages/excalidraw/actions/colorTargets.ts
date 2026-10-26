import {
  COLOR_PALETTE,
  DEFAULT_ELEMENT_BACKGROUND_COLOR_PALETTE,
  DEFAULT_ELEMENT_BACKGROUND_PICKS,
  DEFAULT_ELEMENT_STROKE_COLOR_PALETTE,
  DEFAULT_ELEMENT_STROKE_PICKS,
  DEFAULT_HIGHLIGHT_BG,
  HIGHLIGHT_BACKGROUND_PICKS,
  STICKY_NOTE_BACKGROUND_PICKS,
  STICKY_NOTE_STROKE_PICKS,
  arrayToMap,
  isTransparent,
} from "@excalidraw/common";

import {
  getColorTargetElement,
  hasBackground,
  hasStrokeColor,
  isStickyNoteBoundText,
  isStickyNoteElement,
  isTextElement,
  normalizeStickyNoteBackgroundColor,
  normalizeStickyNoteStrokeColor,
} from "@excalidraw/element";

import type { ColorPaletteCustom, ColorTuple } from "@excalidraw/common";
import type { ElementsMap, ExcalidrawElement } from "@excalidraw/element/types";

import { getSelectedElements } from "../scene";

import type { AppState } from "../types";

export type ColorProperty = "strokeColor" | "backgroundColor";

/**
 * Sticky notes are their own color domain: own defaults, own top picks, no
 * transparent. A pick targets the regular domain, the sticky domain, or both
 * ("mixed" selections write both defaults and use the regular picker).
 * Highlighted text's marker (its background) is a domain of its own as well.
 */
export type ColorTargetKind = "regular" | "sticky" | "mixed" | "highlight";

export type ColorDefaultKey =
  | "currentItemStrokeColor"
  | "currentItemBackgroundColor"
  | "currentItemStickynoteStrokeColor"
  | "currentItemStickynoteBackgroundColor"
  | "currentItemHighlightColor";

export type ColorTargetAppState = Pick<
  AppState,
  | "selectedElementIds"
  | "editingTextElement"
  | "activeTool"
  | "currentItemTextHighlight"
  | ColorDefaultKey
>;

export type ColorTarget = {
  kind: ColorTargetKind;
  property: ColorProperty;
  /** the current-item defaults a pick is written to (normalized per domain) */
  appStateKeys: readonly ColorDefaultKey[];
  /** the default shown when no element is targeted */
  currentValue: string;
  palette: ColorPaletteCustom;
  topPicks: ColorTuple;
  customizableTopPicks: keyof AppState["colorTopPicks"];
  excludedColors: readonly string[] | undefined;
};

const DEFAULT_KEYS: Record<
  ColorProperty,
  Record<"regular" | "sticky", ColorDefaultKey>
> = {
  strokeColor: {
    regular: "currentItemStrokeColor",
    sticky: "currentItemStickynoteStrokeColor",
  },
  backgroundColor: {
    regular: "currentItemBackgroundColor",
    sticky: "currentItemStickynoteBackgroundColor",
  },
};

// transparent is hidden rather than removed from the palette so the remaining
// colors keep their usual hotkeys (same mechanism as the bucket fill picker);
// a module constant so the memoized picker's identity comparison holds
const STICKY_NOTE_EXCLUDED_COLORS: readonly string[] = [
  COLOR_PALETTE.transparent,
];

const isHighlightTextTarget = (element: ExcalidrawElement) =>
  isTextElement(element) && element.highlighted === true && !element.containerId;

const isStickyNoteColorTarget = (
  element: ExcalidrawElement,
  elementsMap: ElementsMap,
) =>
  isStickyNoteElement(element) ||
  (isTextElement(element) && isStickyNoteBoundText(element, elementsMap));

/**
 * Who a stroke/background pick targets. Resolve it from the state an action
 * runs against, at execution time — never capture it in a render closure:
 * the memoized picker keeps a stale `onChange`, and the always-visible top
 * picks fire it without a re-render.
 *
 * Targets are the selected color-capable elements (for stroke incl. bound
 * labels, since a note's visible text is its label) plus the text being
 * edited (`handleTextWysiwyg` deselects while editing) — or, for a
 * background pick on a note's label, the note (see `getColorTargetElement`).
 * With no target, the active tool decides the domain.
 */
export const resolveColorTarget = (
  appState: ColorTargetAppState,
  elements: readonly ExcalidrawElement[],
  property: ColorProperty,
): ColorTarget => {
  const elementsMap = arrayToMap(elements);
  const supports = (element: ExcalidrawElement) =>
    property === "strokeColor"
      ? hasStrokeColor(element.type)
      : hasBackground(element.type) || isHighlightTextTarget(element);

  const targets: ExcalidrawElement[] = getSelectedElements(elements, appState, {
    includeBoundTextElement: property === "strokeColor",
  }).filter(supports);
  const editingText =
    appState.editingTextElement &&
    elementsMap.get(appState.editingTextElement.id);
  const editing =
    editingText && getColorTargetElement(editingText, property, elementsMap);
  if (
    editing &&
    !editing.isDeleted &&
    supports(editing) &&
    !targets.some((element) => element.id === editing.id)
  ) {
    targets.push(editing);
  }

  let kind: ColorTargetKind;
  const isBackground = property === "backgroundColor";
  if (!targets.length) {
    kind =
      appState.activeTool.type === "stickynote"
        ? "sticky"
        : isBackground &&
          appState.activeTool.type === "text" &&
          appState.currentItemTextHighlight
        ? "highlight"
        : "regular";
  } else if (isBackground && targets.every(isHighlightTextTarget)) {
    kind = "highlight";
  } else {
    const stickyCount = targets.filter((element) =>
      isStickyNoteColorTarget(element, elementsMap),
    ).length;
    kind =
      stickyCount === 0
        ? "regular"
        : stickyCount === targets.length
        ? "sticky"
        : "mixed";
  }

  if (kind === "highlight") {
    return {
      kind,
      property,
      appStateKeys: ["currentItemHighlightColor"],
      currentValue: appState.currentItemHighlightColor,
      palette: DEFAULT_ELEMENT_BACKGROUND_COLOR_PALETTE,
      topPicks: HIGHLIGHT_BACKGROUND_PICKS,
      customizableTopPicks: "highlightBackground",
      excludedColors: STICKY_NOTE_EXCLUDED_COLORS,
    };
  }

  const keys = DEFAULT_KEYS[property];
  const isStroke = property === "strokeColor";

  return {
    kind,
    property,
    appStateKeys: kind === "mixed" ? [keys.regular, keys.sticky] : [keys[kind]],
    currentValue: appState[kind === "sticky" ? keys.sticky : keys.regular],
    palette: isStroke
      ? DEFAULT_ELEMENT_STROKE_COLOR_PALETTE
      : DEFAULT_ELEMENT_BACKGROUND_COLOR_PALETTE,
    topPicks:
      kind === "sticky"
        ? isStroke
          ? STICKY_NOTE_STROKE_PICKS
          : STICKY_NOTE_BACKGROUND_PICKS
        : isStroke
        ? DEFAULT_ELEMENT_STROKE_PICKS
        : DEFAULT_ELEMENT_BACKGROUND_PICKS,
    customizableTopPicks:
      kind === "sticky"
        ? isStroke
          ? "stickyNoteStroke"
          : "stickyNoteBackground"
        : isStroke
        ? "elementStroke"
        : "elementBackground",
    excludedColors: kind === "sticky" ? STICKY_NOTE_EXCLUDED_COLORS : undefined,
  };
};

/** the current-item default updates for a picked color */
export const getColorTargetAppStateUpdates = (
  target: ColorTarget,
  color: string,
): Partial<AppState> => {
  const updates: Partial<AppState> = {};
  for (const key of target.appStateKeys) {
    updates[key] =
      key === "currentItemStickynoteStrokeColor"
        ? normalizeStickyNoteStrokeColor(color)
        : key === "currentItemStickynoteBackgroundColor"
        ? normalizeStickyNoteBackgroundColor(color)
        : key === "currentItemHighlightColor" && isTransparent(color)
        ? DEFAULT_HIGHLIGHT_BG
        : color;
  }
  return updates;
};
