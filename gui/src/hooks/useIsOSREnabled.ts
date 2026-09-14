import { useState } from "react";

// OSR (Off-Screen Rendering) was a JetBrains-specific feature.
// Project is now focused on VS Code only — always return false.
export default function useIsOSREnabled() {
  const [_isOSREnabled] = useState(false);

  return false;
}
