# Design QA — Chinese source visibility

- Source visual truth: `artifacts/design-qa/chinese-source-reference.png`
- Normalized source panel: `artifacts/design-qa/chinese-source-reference-panel.png`
- Implementation screenshot: `artifacts/design-qa/chinese-source-after.png`
- Full-view comparison: `artifacts/design-qa/chinese-source-comparison.png` (reported state left, fixed state right)
- Native viewport: 400 × 359 logical points
- Source pixels: 772 × 676; cropped to the 728 × 646 panel region without resampling
- Implementation pixels: 728 × 646
- State: pinned Chinese sentence result, general expression scene, learning disclosure closed

The local mock uses different sentence content from the report; the comparison is intentionally scoped to source visibility, placement, typography, and section sizing rather than translation copy parity.

## Findings and comparison history

1. **Initial P1 — Chinese source was visually missing.** The source value existed, but the AppKit text view painted outside its allocated row and into the title region. This made the source field appear empty in the supplied screenshot.
2. **Fix.** Chinese source content now uses native SwiftUI selectable text with fixed vertical sizing. English source content keeps the AppKit annotation view needed for grammar interactions.
3. **Post-fix evidence.** In the right side of `chinese-source-comparison.png`, the complete Chinese source is visible directly below “原文”, remains inside its section, and does not overlap the title or divider.
4. **English regression check.** The sentence preview still wraps and displays correctly, and the long-source height regression test remains green.

## Fidelity surfaces

- Fonts and typography: source text retains the existing 14-point system font, white foreground, and five-point line spacing.
- Spacing and layout rhythm: the source sits below the section title with the existing panel padding; no overflow or overlap remains.
- Colors and visual tokens: unchanged from the existing panel palette.
- Image and asset fidelity: no raster or icon assets were changed.
- Copy and content: the full Chinese source is visible and selectable; translation content is unchanged.

The full panel is readable at 1:1 normalized size, so a separate focused-region comparison was not needed.

## Remaining findings

- P0: none
- P1: none
- P2: none

final result: passed
