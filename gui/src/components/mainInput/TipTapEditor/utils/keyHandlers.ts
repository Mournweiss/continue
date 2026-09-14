import { Editor } from "@tiptap/react";
import { KeyboardEvent, useRef } from "react";
import { isMetaEquivalentKeyPressed } from "../../../../util";
import { handleVSCMetaKeyIssues } from "../../util/handleMetaKeyIssues";

export function useEditorEventHandlers(options: {
  editor: Editor | null;
  editorFocusedRef: React.MutableRefObject<boolean | undefined>;
  setActiveKey: (key: string | null) => void;
}) {
  const { editor, editorFocusedRef, setActiveKey } = options;
  const metaActiveRef = useRef(false);

  /**
   * This handles various issues with meta key actions.
   * In VS Code, while working with .ipynb files there is a problem where copy/paste/cut
   * will affect the actual notebook cells, even when performing them in our GUI.
   *
   * Currently keydown events for a number of keys are not registering if the
   * meta/shift key is pressed, for example "x", "c", "v", "z", etc.
   * Until this is resolved we can't turn on OSR for non-Mac users due to issues
   * with those key actions.
   */
  const handleKeyDown = async (e: KeyboardEvent<HTMLDivElement>) => {
    if (!editor) {
      return;
    }

    if (!editorFocusedRef?.current || !isMetaEquivalentKeyPressed(e)) return;

    // Only set activeKey for Meta/Control/Alt to drive toolbar highlighting
    if (e.key === "Meta" || e.key === "Control" || e.key === "Alt") {
      setActiveKey(e.key);
      metaActiveRef.current = true;
    }

    await handleVSCMetaKeyIssues(e, editor);
  };

  const handleKeyUp = () => {
    if (metaActiveRef.current) {
      setActiveKey(null);
      metaActiveRef.current = false;
    }
  };

  return { handleKeyDown, handleKeyUp };
}
