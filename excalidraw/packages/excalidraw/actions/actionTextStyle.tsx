import {
  isTextElement,
  newElementWith,
  redrawTextBoundingBox,
} from "@excalidraw/element";

import { CaptureUpdateAction } from "@excalidraw/element";

import type {
  ExcalidrawTextElement,
  FontWeight,
} from "@excalidraw/element/types";

import { RadioSelection } from "../components/RadioSelection";
import {
  FontWeightBoldIcon,
  FontWeightNormalIcon,
  TextHighlightIcon,
  TextNoHighlightIcon,
} from "../components/icons";
import { withCaretPositionPreservation } from "../hooks/useTextEditorFocus";
import { t } from "../i18n";

import {
  changeProperty,
  getFormValue,
  getStylesPanelInfo,
} from "./actionProperties";
import { register } from "./register";

/** free text can carry a marker; labels belong to their container */
const isFreeText = (element: unknown): element is ExcalidrawTextElement =>
  isTextElement(element as ExcalidrawTextElement) &&
  !(element as ExcalidrawTextElement).containerId;

export const actionChangeFontWeight = register<FontWeight>({
  name: "changeFontWeight",
  label: "labels.fontWeight",
  trackEvent: false,
  perform: (elements, appState, value, app) => {
    return {
      elements: changeProperty(
        elements,
        appState,
        (oldElement) => {
          if (!isTextElement(oldElement)) {
            return oldElement;
          }
          const newElement: ExcalidrawTextElement = newElementWith(
            oldElement,
            { fontWeight: value },
          );
          // the weight changes the glyph widths
          redrawTextBoundingBox(
            newElement,
            app.scene.getContainerElement(oldElement),
            app.scene,
            app.renderEnvironment,
          );
          return newElement;
        },
        true,
      ),
      appState: { ...appState, currentItemFontWeight: value },
      captureUpdate: CaptureUpdateAction.IMMEDIATELY,
    };
  },
  PanelComponent: ({ elements, appState, updateData, app, data }) => (
    <fieldset>
      <legend>{t("labels.fontWeight")}</legend>
      <div className="buttonList">
        <RadioSelection<FontWeight | false>
          group="font-weight"
          options={[
            {
              value: "normal",
              text: t("labels.fontWeightNormal"),
              icon: FontWeightNormalIcon,
              testId: "font-weight-normal",
            },
            {
              value: "bold",
              text: t("labels.fontWeightBold"),
              icon: FontWeightBoldIcon,
              testId: "font-weight-bold",
            },
          ]}
          value={getFormValue<FontWeight | false>(
            elements,
            app,
            (element) =>
              isTextElement(element) ? element.fontWeight ?? "normal" : false,
            (element) => isTextElement(element),
            (hasSelection) =>
              hasSelection ? false : appState.currentItemFontWeight,
          )}
          onChange={(value) => {
            if (value === false) {
              return;
            }
            withCaretPositionPreservation(
              () => updateData(value),
              getStylesPanelInfo(app).isCompact,
              !!appState.editingTextElement,
              data?.onPreventClose,
            );
          }}
        />
      </div>
    </fieldset>
  ),
});

export const actionToggleTextHighlight = register<boolean>({
  name: "toggleTextHighlight",
  label: "labels.highlight",
  trackEvent: false,
  perform: (elements, appState, value, app) => {
    const hasTargets = app.scene
      .getSelectedElements({
        selectedElementIds: appState.selectedElementIds,
        includeBoundTextElement: false,
      })
      .some(isFreeText);
    const isEditingFreeText = isFreeText(appState.editingTextElement);

    return {
      elements: changeProperty(elements, appState, (oldElement) => {
        if (!isFreeText(oldElement)) {
          return oldElement;
        }
        return newElementWith(oldElement, {
          highlighted: value,
          // a marker always paints in its own domain's color
          ...(value && {
            backgroundColor: appState.currentItemHighlightColor,
          }),
        });
      }),
      // the tool preset only changes when no text is targeted, so styling one
      // text doesn't turn the plain text tool into a marker
      appState:
        hasTargets || isEditingFreeText
          ? appState
          : { ...appState, currentItemTextHighlight: value },
      captureUpdate: CaptureUpdateAction.IMMEDIATELY,
    };
  },
  PanelComponent: ({ elements, appState, updateData, app }) => {
    const value = getFormValue<boolean | null>(
      elements,
      app,
      (element) => (isFreeText(element) ? element.highlighted === true : null),
      (element) => isFreeText(element),
      (hasSelection) =>
        hasSelection ? null : appState.currentItemTextHighlight,
    );
    // nothing to mark when only labels are selected
    if (value === null && Object.keys(appState.selectedElementIds).length) {
      return null;
    }
    return (
      <fieldset>
        <legend>{t("labels.highlight")}</legend>
        <div className="buttonList">
          <RadioSelection<boolean>
            group="text-highlight"
            options={[
              {
                value: false,
                text: t("labels.highlightOff"),
                icon: TextNoHighlightIcon,
                testId: "text-highlight-off",
              },
              {
                value: true,
                text: t("labels.highlight"),
                icon: TextHighlightIcon,
                testId: "text-highlight-on",
              },
            ]}
            value={value}
            onChange={(next) => updateData(next === true)}
          />
        </div>
      </fieldset>
    );
  },
});
