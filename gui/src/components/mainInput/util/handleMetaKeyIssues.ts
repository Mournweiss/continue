import { Editor } from "@tiptap/react";
import { KeyboardEvent } from "react";
import { isWebEnvironment } from "../../../util";

const isWebEnv = isWebEnvironment();

/**
 * This handles various keypress issues when working with .ipynb files in VS Code.
 * In VS Code, copy/paste/cut operations can affect the actual notebook cells
 * even when performed in the GUI.
 */
export const handleVSCMetaKeyIssues = async (
  e: KeyboardEvent,
  editor: Editor,
) => {
  const text = editor.state.doc.textBetween(
    editor.state.selection.from,
    editor.state.selection.to,
  );

  const handlers: Record<string, () => Promise<void>> = {
    x: () => handleCutOperation(text, editor),
    c: () => handleCopyOperation(text),
    v: () => handlePasteOperation(editor),
    z: () => {
      return e.shiftKey
        ? handleRedoOperation(editor)
        : handleUndoOperation(editor);
    },
  };

  if (e.key in handlers) {
    e.stopPropagation();
    e.preventDefault();
    await handlers[e.key]();
  }
};

const deleteSingleWord = (editor: Editor) => {
  const textContent =
    editor.state.doc.resolve(editor.state.selection.from).parent.textContent ??
    "";

  const cursorPosition = editor.state.selection.from;
  const nodeStartPosition = editor.state.doc.resolve(cursorPosition).start();

  const textBeforeCursor = textContent.slice(
    0,
    cursorPosition - nodeStartPosition,
  );

  // Match the last word including any trailing whitespace
  const lastWordMatch = textBeforeCursor.match(/\S+\s*$/);

  if (lastWordMatch) {
    const lastWordWithSpace = lastWordMatch[0];
    editor.commands.deleteRange({
      from: editor.state.selection.from - lastWordWithSpace.length,
      to: editor.state.selection.from,
    });
  }
};

export const handleCutOperation = async (text: string, editor: Editor) => {
  if (isWebEnv) {
    await navigator.clipboard.writeText(text);
    editor.commands.deleteSelection();
  } else {
    document.execCommand("cut");
  }
};

export const handleCopyOperation = async (text: string) => {
  if (isWebEnv) {
    await navigator.clipboard.writeText(text);
  } else {
    document.execCommand("copy");
  }
};

export const handlePasteOperation = async (editor: Editor) => {
  if (isWebEnv) {
    const clipboardText = await navigator.clipboard.readText();
    editor.commands.insertContent(clipboardText);
  } else {
    document.execCommand("paste");
  }
};

export const handleUndoOperation = async (editor: Editor) => {
  editor.commands.undo();
};

export const handleRedoOperation = async (editor: Editor) => {
  editor.commands.redo();
};
