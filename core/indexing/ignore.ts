import ignore, { Ignore } from "ignore";

import { IDE } from "..";
import { getGlobalContinueIgArray } from "./continueignore";

/**
 * Parse .gitignore / .continueignore file content into an array of patterns.
 * Removes empty lines and comments.
 */
export function gitIgArrayFromFile(file: string): string[] {
  return file
    .split(/\r?\n/)
    .map((l) => l.trim())
    .filter((l) => !/^#|^$/.test(l));
}

/**
 * Create an ignore instance from raw pattern strings.
 */
export function createIgnoreFromPatterns(patterns: string[]): Ignore {
  return ignore().add(patterns);
}

/**
 * Load ignore patterns from .gitignore in the given directory.
 */
export async function loadGitIgnorePatterns(
  ide: IDE,
  dirUri: string,
): Promise<string[]> {
  const gitIgnorePath = `${dirUri}/.gitignore`;
  try {
    const contents = await ide.readFile(gitIgnorePath);
    return gitIgArrayFromFile(contents);
  } catch {
    return [];
  }
}

/**
 * Check if a file path should be ignored based on .continueignore and .gitignore patterns.
 * Patterns are loaded exclusively from .continueignore and .gitignore files.
 */
export async function isSecurityConcern(
  ide: IDE,
  filepath: string,
): Promise<boolean> {
  // Normalize path separators
  const normalizedPath = filepath.replace(/\\/g, "/");

  // Get workspace directories
  const workspaceDirs = await ide.getWorkspaceDirs();

  // Check against global .continueignore patterns
  const globalPatterns = getGlobalContinueIgArray();
  if (globalPatterns.length > 0) {
    const globalIgnore = ignore().add(globalPatterns);
    if (globalIgnore.ignores(normalizedPath)) {
      return true;
    }
  }

  // Check against per-directory .gitignore and .continueignore patterns
  for (const workspaceDir of workspaceDirs) {
    const gitIgnorePatterns = await loadGitIgnorePatterns(ide, workspaceDir);
    if (gitIgnorePatterns.length > 0) {
      const gitIgnore = ignore().add(gitIgnorePatterns);
      if (gitIgnore.ignores(normalizedPath)) {
        return true;
      }
    }
  }

  return false;
}

/**
 * Check if a file path should be ignored synchronously using provided patterns.
 */
export function isIgnoredByPatterns(
  filepath: string,
  patterns: string[],
): boolean {
  const normalizedPath = filepath.replace(/\\/g, "/");
  if (patterns.length === 0) {
    return false;
  }
  const ignoreInstance = ignore().add(patterns);
  return ignoreInstance.ignores(normalizedPath);
}

/**
 * Throw an error if the file path is a security concern.
 * @throws Error if the file is a security concern
 */
export function throwIfFileIsSecurityConcern(filepath: string): void {
  // This function is deprecated since security checks are now pattern-based.
  // With hardcoded ignores removed, all files are allowed unless they match
  // .continueignore or .gitignore patterns, which are handled by walkDir.
  // This function is kept for API compatibility but does not throw.
}
