## 1.0.5

* Added **Magnet Tool** — a sculpting brush that attracts shape vertices toward the cursor with configurable radius and strength.
* Added **Magnetic Alignment Guides** — dashed magenta guide lines that appear when dragging shapes, showing edge/center alignment with other shapes.
* New `LineSegment` model for alignment guide representation.
* New `DrawingConfig` options: `magnetRadius`, `magnetStrength`, `alignmentGuideThreshold`.
* Added Magnet tool button to the toolbar and dedicated property panel with radius/strength sliders.

## 1.0.4

* Upgraded package dependencies (`cupertino_icons`, `google_fonts`, and `share_plus`) to support their latest stable versions.
* Fixed layout lint warnings in drawing header widget.

## 1.0.3

* Fixed all lints across the codebase (replaced deprecated APIs, resolved `withOpacity` vs `withValues` precision warnings).
* Cleaned up redundant imports and trailing directives.
* Formatted pubspec description to satisfy pub.dev best practices.
* Removed warnings inside the example project directory.

## 1.0.2

* Updated repository links and documentation.

## 1.0.0

* Initial release.
* A high-performance, production-ready vector drawing engine for Flutter.
* Supports 14 shape types, select, move, resize, rotate, duplicate, flip, delete shapes.
* Eraser tool, measurement tool, shape recognition.
* Smart snapping, undo/redo.
* JSON serialization/deserialization and PNG export.
