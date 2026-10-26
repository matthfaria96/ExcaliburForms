import { getFontString, isTransparent } from "@excalidraw/common";

import { getLineHeightInPx, getLineWidth } from "./textMeasurements";

import type { RenderEnvironment } from "./renderEnvironment";
import type { ExcalidrawTextElement } from "./types";

/** horizontal overshoot of the marker past the glyphs, in font sizes */
const HIGHLIGHT_PADDING_X = 0.2;
/** vertical inset of the marker inside each line box, in line heights */
const HIGHLIGHT_INSET_Y = 0.06;
/** corner radius of the marker, in font sizes */
const HIGHLIGHT_RADIUS = 0.12;

export type TextHighlightRect = Readonly<{
  x: number;
  y: number;
  width: number;
  height: number;
  radius: number;
}>;

/** Whether a text element paints a marker stroke behind its lines. */
export const isHighlightedText = (element: ExcalidrawTextElement) =>
  element.highlighted === true &&
  !element.containerId &&
  !isTransparent(element.backgroundColor);

/**
 * Marker rectangles behind each non-empty line, in the element's local
 * coordinates (origin at `element.x/y`, unrotated). Shared by the canvas and
 * SVG renderers so both exports paint the same strokes.
 */
export const getTextHighlightRects = (
  element: ExcalidrawTextElement,
  env?: RenderEnvironment,
): TextHighlightRect[] => {
  if (!isHighlightedText(element)) {
    return [];
  }
  const font = getFontString(element);
  const lineHeightPx = getLineHeightInPx(element.fontSize, element.lineHeight);
  const padX = element.fontSize * HIGHLIGHT_PADDING_X;
  const insetY = lineHeightPx * HIGHLIGHT_INSET_Y;
  const lines = element.text.replace(/\r\n?/g, "\n").split("\n");

  return lines.flatMap((line, index) => {
    if (!line.trim()) {
      return [];
    }
    const lineWidth = Math.min(getLineWidth(line, font, env), element.width);
    const lineX =
      element.textAlign === "center"
        ? (element.width - lineWidth) / 2
        : element.textAlign === "right"
        ? element.width - lineWidth
        : 0;
    return [
      {
        x: lineX - padX,
        y: index * lineHeightPx + insetY,
        width: lineWidth + padX * 2,
        height: lineHeightPx - insetY * 2,
        radius: element.fontSize * HIGHLIGHT_RADIUS,
      },
    ];
  });
};
