import ignore, { Ignore } from "ignore";

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
