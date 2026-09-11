import ignore from "ignore";
import type { FileType, IDE } from "../";
import { findUriInDirs, getUriPathBasename } from "../util/uri";
import { getGlobalContinueIgArray } from "./continueignore";
import { getIgnoreContext } from "./walkDir";

/*
    Process:
    1. Walk UP tree from file, checking .continueignore / .gitignore at each level
    2. Also check global .continueignore

    All ignore patterns are controlled exclusively via .continueignore files.
    .gitignore is also respected for compatibility.

    TODO there might be issues with symlinks here
*/
export async function shouldIgnore(
  fileUri: string,
  ide: IDE,
  rootDirCandidates?: string[],
): Promise<boolean> {
  const rootDirUris = rootDirCandidates ?? (await ide.getWorkspaceDirs());
  const { foundInDir: rootDir, uri } = findUriInDirs(fileUri, rootDirUris);

  if (!rootDir) {
    return true;
  }

  const globalIgnores = ignore().add(getGlobalContinueIgArray());

  let currentDir = uri;
  let directParent = true;
  let fileType = 1 as FileType.File as FileType;
  while (currentDir !== rootDir) {
    // Go to parent dir of file
    const splitUri = currentDir.split("/");
    splitUri.pop();
    currentDir = splitUri.join("/");

    // Get all files in the dir
    const dirEntries = await ide.listDir(currentDir);

    // Check if the file is a symbolic link, ignore if so
    if (directParent) {
      directParent = false;
      const baseName = getUriPathBasename(fileUri);
      const entry = dirEntries.find(([name, _]) => name === baseName);
      if (entry) {
        fileType = entry[1];
        if (fileType === (64 as FileType.SymbolicLink)) {
          return true;
        }
      }
    }

    const ignoreContext = await getIgnoreContext(
      currentDir,
      dirEntries,
      ide,
      globalIgnores,
    );

    let relativePath = uri.substring(currentDir.length + 1);
    if (fileType === (2 as FileType.Directory)) {
      relativePath += "/";
    }

    if (ignoreContext.ignores(relativePath)) {
      return true;
    }
  }

  return false;
}
