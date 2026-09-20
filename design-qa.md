# Design QA — expanded original sentence height

- Source visual: `artifacts/design-qa/source-height-reference.png`
- Implementation screenshot: `artifacts/design-qa/source-height-after.png`
- Side-by-side comparison: `artifacts/design-qa/source-height-comparison.png` (reference left, implementation right)
- Surface: native macOS panel, 410 × 560 logical points; captured at 748 × 1048 pixels
- State: English sentence result loaded and pinned, then manually collapsed and expanded again

## QA history

1. Verified the long original sentence wraps to all lines and contributes its measured height to the source section.
2. Collapsed the panel through the header control and expanded it again.
3. Verified the reopened panel still shows the complete original sentence without single-line clipping or overlap.

The mock preview intentionally uses placeholder translated/result content; QA scope is the source-section wrapping and vertical sizing shown in the supplied reference.

## Findings

- P0: none
- P1: none
- P2: none

final result: passed
