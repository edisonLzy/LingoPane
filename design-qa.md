# Native library window design QA

final result: passed

## Scope and evidence
- Source: `/var/folders/lw/00mw47y55zb84yrfl_xy0qnw0000gn/T/codex-clipboard-36fb8ea8-7e2b-49e7-8df7-ecedcf3d758f.png` (2048 × 1428, includes desktop wallpaper).
- Implementation: `artifacts/library.png` (1120 × 740 native window capture); settings: `artifacts/settings.png`.
- Native SwiftUI app, not a browser application; CSS viewport and browser console are not applicable.
- Source and implementation were opened together in one image comparison tool result. Compared window composition, not wallpaper or absolute pixel positions. The request is style adaptation for a different product, not identical task-list content.
- States: empty library, five preview records, selected word and sentence, filtered results, search empty state, settings, learning tab. Preview records exist in memory only.

## Required visual surfaces
- Typography: system UI fonts, restrained medium-weight headings; serif original text intentionally distinguishes reading content from navigation. Text wraps in details and truncates in the record list.
- Layout: three softly divided columns, capsule selection, generous negative space, independently scrolling content. Wider center column is intentional for translations; reference uses equal task columns.
- Color: warm ivory surface, dark brown text, muted olive chart, small blue/purple/orange category markers. Native material provides background treatment; actual desktop translucency varies with OS settings.
- Assets: SF Symbols used for native icons. Source desert image is desktop wallpaper, not an in-app image asset. No raster assets required.
- Copy: history, detail, and learning labels fit the actual application. Curve explicitly identifies itself as an illustrative model, not a measured personal retention score.
- Full-view images were sufficiently readable for headings, navigation, filters and selected detail; no separate region crop was needed.

## Interaction checks
- Type filter reduces list to sentences and updates detail.
- Unmatched search displays an empty state.
- Recommended review clears search/filter and selects the corresponding record.
- Settings renders inside the same window and retains existing form controls.
- Learning navigation renders the expanded learning area.
- Final refinement: renamed daily metric to 今日词句 to reflect unique items; selecting a history row also navigates back to detail.
- Final rebuilt app reopened and captured after refinements; no actionable P0/P1/P2 visual findings remain.
- `swift test`: 30 tests passed; `git diff --check` passed.

## Remaining validation limits
- Did not perform destructive Vault operations, change credentials/preferences, or call live model services during UI checks.
- Resize extremes and increased accessibility contrast were not exhaustively tested.
- Personal retention scoring and review scheduling require actual review-event data and are not implemented by this UI change.
