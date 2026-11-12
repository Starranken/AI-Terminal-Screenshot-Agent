# Repository Guidelines

## Project Structure & Module Organization

This repository is an asset-only screenshot collection. Image files are stored directly in the repository root and use descriptive timestamped names, for example `Screenshot 2026-11-10 121539.png`. There is currently no application source, test directory, build system, or generated-assets directory. Keep new screenshots at the root unless a future contribution introduces a clearly documented subcategory.

## Build, Test, and Development Commands

No build or test commands are configured. For local review, inspect image dimensions and formats with the operating system's image properties or an image viewer. Before committing, verify that the intended files are present and that no unrelated system files or temporary exports were added.

## Coding Style & Naming Conventions

Code conventions do not apply to the current asset-only contents. Name screenshots with the existing pattern `Screenshot YYYY-MM-DD HHMMSS.png`; preserve the `.png` format when possible. Use spaces and readable timestamps, avoid renaming established files without a clear reason, and do not commit editor thumbnails, caches, or duplicate exports.

## Testing Guidelines

There is no automated test framework or coverage requirement. Manually open new or edited images to confirm they are readable, not corrupted, and saved in the expected format. If scripts or application code are added later, document their test command and naming conventions here.

## Commit & Pull Request Guidelines

No Git history or project-specific commit convention is available in this directory. Use short, imperative commit subjects such as `Add onboarding screenshot` or `Remove duplicate capture`. Pull requests should explain what assets changed, why they changed, and include a visual preview or file list when useful. Keep unrelated cleanup out of the same change.

## Security & Configuration Tips

Review screenshots for passwords, tokens, personal information, private URLs, and other sensitive content before sharing or committing them. Avoid adding `desktop.ini` or other operating-system metadata unless it is intentionally required.
